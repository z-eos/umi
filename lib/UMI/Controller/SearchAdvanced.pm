# -*- mode: cperl -*-
#

package UMI::Controller::SearchAdvanced;

use Net::LDAP::Util qw(	ldap_explode_dn );

use Logger;
	    use MIME::Base64;

use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; with 'Tools'; }

use UMI::Form::SearchAdvanced;
use Data::Printer use_prototypes => 1;

has 'form' => ( isa => 'UMI::Form::SearchAdvanced', is => 'rw',
		lazy => 1, default => sub { UMI::Form::SearchAdvanced->new },
		documentation => q{Form for advanced search},
	      );

=head1 NAME

UMI::Controller::SearchAdvanced - Catalyst Controller

=head1 DESCRIPTION

Advanced (low level) Search


=head2 index

=cut

sub index :Path :Args(0) {
  my ( $self, $c ) = @_;
  my $params = $c->req->params;

  $c->stash( template      => 'search/search_advanced.tt',
	     form          => $self->form,
	     final_message => '', );

  if ( keys %{$params} > 0 ) {
    my $init_obj = { base_dn       => $params->{base_dn},
		     search_filter => $params->{search_filter},
		     search_scope  => $params->{search_scope}, };
    return unless $self->form->process( init_object => $init_obj,
					ldap_crud   => $c->model('LDAP_CRUD'), );
  } else {
    # log_debug { np( $params ) };
    return unless $self->form->process( posted    => ($c->req->method eq 'POST'),
					params    => $params,
					ldap_crud => $c->model('LDAP_CRUD'), );

    $self->form->base_dn( $params->{base_dn} );
    $self->form->search_filter( $params->{search_filter} );
    # $params->{action_searchby} = $c->uri_for_action('searchby/index');
  }
}

sub proc :Path(proc) :Args(0) {
    my ( $self, $c ) = @_;
    my $params = $c->req->params;
    # log_debug { np($params) };

    if ( defined $c->user_exists ) {
      my ( $ldap_crud, $basedn, @filter_arr, $filter, $scope, $sort_order );

      $c->stash( template => 'search/search_advanced.tt',
      		 form     => $self->form, );
      return unless
	$self->form->process(
			     posted => ($c->req->method eq 'POST'),
			     params => $params,
			     # ldap_crud => $c->model('LDAP_CRUD'),
			    );

      # $c->stash( template => 'search/searchby.tt', );

      if ( defined $params->{search_history} && $params->{search_history} eq '1' ) {
	$basedn = UMI->config->{ldap_crud_db_log};
	push @filter_arr, '(reqAuthzID=' . $params->{reqAuthzID} . ')'
	  if $params->{reqAuthzID} ne '';
	push @filter_arr, '(reqDn=' . $params->{reqDn} . ')'
	  if $params->{reqDn}    ne '';
	push @filter_arr, '(reqEntryUUID=' . $params->{reqEntryUUID} . ')'
	  if $params->{reqEntryUUID}    ne '';
	push @filter_arr, '(reqEnd=' . $params->{reqEnd} . ')'
	  if $params->{reqEnd}   ne '';
	push @filter_arr, '(reqResult=' . $params->{reqResult} . ')'
	  if $params->{reqResult} ne '';
	push @filter_arr, '(reqMessage=' . $params->{reqMessage} . ')'
	  if $params->{reqMessage} ne '';
	push @filter_arr, '(reqMod=' . $params->{reqMod} . ')'
	  if $params->{reqMod}   ne '';
	push @filter_arr, '(reqOld=' . $params->{reqOld} . ')'
	  if $params->{reqOld}   ne '';
	push @filter_arr, '(reqStart=' . $params->{reqStart} . ')'
	  if $params->{reqStart} ne '';
	push @filter_arr, '(reqType=' . $params->{reqType} . ')'
	  if $params->{reqType}  ne '';
	if ( $#filter_arr > 0 ) {
	  $filter = '(&' . join('', @filter_arr) . ')';
	} elsif ( $#filter_arr == 0 ) {
	  $filter = $filter_arr[0];
	} else {
	  $filter = '(abc stub)';
	}
	$scope = 'sub';
	$sort_order = 'straight';
      } else {
	# log_debug { np($params) };
	$basedn     = $params->{'base_dn'};
	$filter     = $params->{'search_filter'};
	$scope      = $params->{'search_scope'};
	$sort_order = 'reverse';
      }

      if ( ! $c->check_any_user_role( qw/admin coadmin/ ) &&
	   ! $self->may_i({ base_dn => $basedn,
			    filter  => $filter,
			    user    => $c->user, }) ) {
	log_error { sprintf('User roles or Tools->may_i() check does not allow search by base dn: %s and/or filter: %s',
			    $basedn,
			    $filter ) };
	$c->stash( template      => 'ldap_err.tt',
		   final_message => { error => sprintf('Your roles or Tools->may_i() check does not allow search by base dn:<h5>&laquo;<b><em>%s</em></b>&raquo;</h5> and/or filter:<h5>&laquo;<b><em>%s</em></b>&raquo;</h5>ask UMI admin for explanation/s and provide above info.',
						       $basedn,
						       $filter ), }, );
	return 0;
      }

      $c->stats->profile( begin => "searchby_advanced_search" );

      my @attrs = $params->{'show_attrs'} ne '' ?
	split(/,/, $params->{'show_attrs'}) : ( '*' );

      push @attrs,
	'createTimestamp',
      	'creatorsName',
      	'modifiersName',
      	'modifyTimestamp',
#      	'pwdHistory',
      	'entryTtl',
      	'entryExpireTimestamp';

      $ldap_crud = $c->model('LDAP_CRUD');
      my $mesg = $ldap_crud->search({
				     base      => $basedn,
				     filter    => $filter,
				     scope     => $scope,
				     sizelimit => $params->{'search_results'},
				     attrs     => \@attrs,
				    });
      my $return;
      $return->{warning} = $ldap_crud->err($mesg)->{html} if ! $mesg->count;

      my @entries = defined $params->{order_by} &&
	$params->{order_by} ne '' ? $mesg->sorted(split(/,/,$params->{order_by})) : $mesg->sorted('dn');

      my $all_entries = $mesg->as_struct;
      
      $c->stats->profile("search by filter requested");

      my ( $foffs, $ttentries, @ttentries_keys );

      # building sys groups members hash
      my $all_sysgroups;
      my $sysgr_msg = $ldap_crud->search({ base   => $ldap_crud->{cfg}->{base}->{system_group},
					   filter => '(objectClass=*)',
					   attrs  => [ $ldap_crud->{cfg}->{rdn}->{group}, 'memberUid' ], });

      my ($grhash, $grkey);
      if ( $sysgr_msg->is_error() ) {
	$return->{error} .= $ldap_crud->err( $sysgr_msg )->{html};
      } else {
	$grhash = $sysgr_msg->as_struct;
	my %memberuids;
	foreach $grkey (keys (%{$grhash})) {
	  %memberuids = map { $_ => 1 } @{$grhash->{$grkey}->{memberuid}};
	  %{$all_sysgroups->
	      {$grhash->{$grkey}->{$ldap_crud->{cfg}->{rdn}->{group}}->[0]}} = %memberuids;
	  %memberuids = ();
	}
      }

      foreach (@entries) {

	$foffs = $self->factoroff_searchby({
					    all_entries   => $all_entries,
					    all_sysgroups => $all_sysgroups,
					    c_stats       => $c->stats,
					    entry         => $_,
					    ldap_crud     => $ldap_crud,
					    session       => $c->session,
					   });

	$return->{error} .= $foffs->{return}->{error} if exists $foffs->{return}->{error};
	$ttentries->{$_->dn}->{root}   = $foffs->{root};
	$ttentries->{$_->dn}->{mgmnt}  = $foffs->{mgmnt};
	$ttentries->{$_->dn}->{attrs}  = $foffs->{attrs};
	$ttentries->{$_->dn}->{is_arr} = $foffs->{is_arr};

	push @ttentries_keys, $_->dn if $sort_order eq 'reverse'; # for not history searches

      }
      
      # suffix array of dn preparation to respect LDAP objects "inheritance"
      # http://en.wikipedia.org/wiki/Suffix_array
      # this one to be used for all except history requests
      # my @ttentries_keys = map { scalar reverse } sort map { scalar reverse } keys %{$ttentries};
      # this one to be used for history requests
      # my @ttentries_keys = sort { lc $a cmp lc $b } keys %{$ttentries};

      # @ttentries_keys = $sort_order eq 'reverse' ?
      # 	map { scalar reverse } sort map { scalar reverse } keys %{$ttentries} :
      # 	sort { lc $a cmp lc $b } keys %{$ttentries};

      @ttentries_keys = sort { lc $a cmp lc $b } keys %{$ttentries}
	if $sort_order eq 'straight';

      # log_debug { np( $basedn ) };
      $c->stash( attrs               => defined $params->{'show_attrs'} && $params->{'show_attrs'} ne '' ? [ split(/,/, $params->{'show_attrs'}) ] : undef,
		 base_dn             => $basedn,
		 base_icon           => $ldap_crud->cfg->{base}->{icon},
		 entries             => $ttentries,
		 entrieskeys         => \@ttentries_keys,
		 filter              => $filter,
		 final_message       => $return,
		 form                => $self->form,
		 from_searchadvanced => 1,
		 schema              => $c->session->{ldap}->{obj_schema_attr_equality},
		 scope               => $scope,
		 services            => $ldap_crud->cfg->{authorizedService},
		 template            => 'search/searchby.tt',
	       );
    } else {
      $c->stash( template => 'signin.tt', );
    }

    $c->stats->profile( end => "searchby_advanced_search" );
  }

=head1 AUTHOR

Zeus

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;

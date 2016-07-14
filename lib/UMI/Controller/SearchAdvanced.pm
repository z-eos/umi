# -*- mode: cperl -*-
#

package UMI::Controller::SearchAdvanced;
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

Catalyst Controller.

=head1 METHODS

=cut


=head2 index

=cut

sub index :Path :Args(0) {
    my ( $self, $c ) = @_;
    if ( defined $c->session->{"auth_uid"} ) {
      my $params = $c->req->params;
    
      $c->stash( template => 'search/search_advanced.tt',
      		 form => $self->form, );

      return unless
	$self->form->process(
			     posted => ($c->req->method eq 'POST'),
			     params => $params,
			     ldap_crud => $c->model('LDAP_CRUD'),
			    );

      # $c->stash( final_message => '' );
    } else {
      $c->stash( template => 'signin.tt', );
    }
  }

sub proc :Path(proc) :Args(0) {
    my ( $self, $c ) = @_;
    my $params = $c->req->params;

    if ( defined $c->user_exists ) {
      my ( $ldap_crud, $basedn, @filter_arr, $filter, $scope, $sort_order );

      $c->stash( template => 'search/search_advanced.tt',
      		 form => $self->form, );
      return unless
	$self->form->process(
			     posted => ($c->req->method eq 'POST'),
			     params => $params,
			     # ldap_crud => $c->model('LDAP_CRUD'),
			    );

      $c->stash( template => 'search/searchby.tt', );

      if ( defined $params->{search_history} && $params->{search_history} eq '1' &&
	   $c->check_any_user_role( qw/admin coadmin/ ) ) {
	$basedn = UMI->config->{ldap_crud_db_log};
	push @filter_arr, '(reqAuthzID=' . $params->{reqAuthzID} . ')' if $params->{reqAuthzID} ne '';
	push @filter_arr, '(reqDn=' . $params->{reqDn} . ')' if $params->{reqDn} ne '';
	push @filter_arr, '(reqEnd=' . $params->{reqEnd} . ')' if $params->{reqEnd} ne '';
	push @filter_arr, '(reqResult=' . $params->{reqResult} . ')' if $params->{reqResult} ne '';
	push @filter_arr, '(reqMessage=' . $params->{reqMessage} . ')' if $params->{reqMessage} ne '';
	push @filter_arr, '(reqMod=' . $params->{reqMod} . ')' if $params->{reqMod} ne '';
	push @filter_arr, '(reqOld=' . $params->{reqOld} . ')' if $params->{reqOld} ne '';
	push @filter_arr, '(reqStart=' . $params->{reqStart} . ')' if $params->{reqStart} ne '';
	push @filter_arr, '(reqType=' . $params->{reqType} . ')' if $params->{reqType} ne '';
	if ( $#filter_arr > 0 ) {
	  $filter = '(&' . join('', @filter_arr) . ')';
	} elsif ( $#filter_arr == 0 ) {
	  $filter = $filter_arr[0];
	} else {
	  $filter = '(abc stub)';
	}
	$scope = 'sub';
	$sort_order = 'direct';
      } elsif ( $c->check_any_user_role( qw/admin coadmin/ ) ||
		$self->is_searchable({ base_dn => $params->{base_dn},
				       filter => $params->{'search_filter'},
				       roles => [ $c->user->roles ], }) ) {
	$basedn = $params->{'base_dn'};
	$filter = $params->{'search_filter'};
	$scope = $params->{'search_scope'};
	$sort_order = 'reverse';
      } else {
	$c->stash(
		  template => 'ldap_err.tt',
		  final_message => { error
				     => sprintf('you are not permited to search base dn:
<h5>&laquo;<b><em>%s</em></b>&raquo;</h5> and/or filter:
<h5>&laquo;<b><em>%s</em></b>&raquo;</h5>',
						$params->{'base_dn'},
						$params->{'search_filter'} ), },
		 );
	return 0;
      }

      #p $params;
      my @attrs = split(/,/, $params->{'show_attrs'});
      push @attrs,
	'createTimestamp',
	'creatorsName',
	'modifiersName',
	'modifyTimestamp';
      $ldap_crud =
	$c->model('LDAP_CRUD');
      my $mesg = $ldap_crud->search({
				     base => $basedn,
				     filter => $filter,
				     scope => $scope,
				     sizelimit => $params->{'search_results'},
				     attrs => \@attrs,
				    });
      my $return;
      $return->{warning} = $ldap_crud->err($mesg)->{html} if ! $mesg->count;
      my @entries = $mesg->entries;

      my ( $ttentries, $attr, $umilog, $dn_depth );
      foreach (@entries) {
	$umilog = UMI->config->{ldap_crud_db_log};
	if ( $_->dn !~ /$umilog/ ) {
	  $mesg = $ldap_crud->search({
				      base => $ldap_crud->cfg->{base}->{group},
				      filter => sprintf('(&(cn=%s)(memberUid=%s))',
							$ldap_crud->cfg->{stub}->{group_blocked},
							substr( (reverse split /,/, $_->dn)[2], 4 )),
				     });
	  $return->{error} .= $ldap_crud->err( $mesg )->{html}
	    if $mesg->is_error();
	}
	
	$dn_depth = $_->dn =~ /.*,$ldap_crud->{cfg}->{base}->{acc_root}/ ? 1 : 3;
	$dn_depth += split(/,/, $ldap_crud->{cfg}->{base}->{acc_root});

	$ttentries->{$_->dn}->{'mgmnt'} =
	  {
	   is_blocked => $mesg->count,
	   is_dn => scalar split(',', $_->dn) <= $dn_depth ? 1 : 0,
	   is_account => $_->dn =~ /.*,$ldap_crud->{cfg}->{base}->{acc_root}/ ? 1 : 0,
	   is_group => $_->dn =~ /.*,$ldap_crud->{cfg}->{base}->{group}/ ? 1 : 0,
	   is_inventory => $_->dn =~ /.*,$ldap_crud->{cfg}->{base}->{inventory}/ ? 1 : 0,
	   jpegPhoto => $_->dn =~ /.*,$ldap_crud->{cfg}->{base}->{acc_root}/ ? 1 : 0,
	   gitAclProject => $_->exists('gitAclProject') ? 1 : 0,
	   userPassword => $_->exists('userPassword') ? 1 : 0,
	   userDhcp => $_->dn =~ /.*,$ldap_crud->{cfg}->{base}->{acc_root}/ &&
	   scalar split(',', $_->dn) <= 3 ? 1 : 0,
	  };

	my $to_utf_decode;
	foreach $attr (sort $_->attributes) {
	  $to_utf_decode = $_->get_value( $attr, asref => 1 );
	  map { utf8::decode($_); $_} @{$to_utf_decode};
	  $ttentries->{$_->dn}->{attrs}->{$attr} = $to_utf_decode;

	  if ( $attr eq 'jpegPhoto' ) {
	    use MIME::Base64;
	    $ttentries->{$_->dn}->{attrs}->{$attr} =
	      sprintf('img-thumbnail" alt="jpegPhoto of %s" src="data:image/jpg;base64,%s" title="%s" />',
		      $_->dn,
		      encode_base64(join('',@{$ttentries->{$_->dn}->{attrs}->{$attr}})),
		      $_->dn);
	  } elsif ( $attr eq 'userCertificate;binary' ) {
	    $ttentries->{$_->dn}->{attrs}->{$attr} = $self->cert_info({ cert => $_->get_value( $attr ) });
	  } elsif (ref $ttentries->{$_->dn}->{attrs}->{$attr} eq 'ARRAY') {
	    $ttentries->{$_->dn}->{is_arr}->{$attr} = 1;
	  }
	}
      }

      my $base_dn = sprintf('<kbd>%s</kbd>', $basedn);
      my $search_filter = sprintf('<kbd>%s</kbd>', $filter);

    # suffix array of dn preparation to respect LDAP objects "inheritance"
    # http://en.wikipedia.org/wiki/Suffix_array
    # this one to be used for all except history requests
    # my @ttentries_keys = map { scalar reverse } sort map { scalar reverse } keys %{$ttentries};
    # this one to be used for history requests
    # my @ttentries_keys = sort { lc $a cmp lc $b } keys %{$ttentries};

    my @ttentries_keys = $sort_order eq 'reverse' ?
      map { scalar reverse } sort map { scalar reverse } keys %{$ttentries} :
      sort { lc $a cmp lc $b } keys %{$ttentries};
      # p $ttentries;
    $c->stash(
	      template => 'search/searchby.tt',
	      schema => $ldap_crud->attr_equality,
	      base_dn => $base_dn,
	      filter => $search_filter,
	      entrieskeys => \@ttentries_keys,
	      entries => $ttentries,
	      services => $ldap_crud->cfg->{authorizedService},
	      base_ico => $ldap_crud->cfg->{base}->{icon},
	      final_message => $return,
	      form => $self->form,
	     );
    } else {
      $c->stash( template => 'signin.tt', );
    }
  }

=head1 AUTHOR

Zeus

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;

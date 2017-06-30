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

      if ( defined $params->{search_history} && $params->{search_history} eq '1' ) {
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
	$sort_order = 'straight';
      } else {
	$basedn = $params->{'base_dn'};
	$filter = $params->{'search_filter'};
	$scope = $params->{'search_scope'};
	$sort_order = 'reverse';
      }

      if ( ! $c->check_any_user_role( qw/admin coadmin/ ) &&
	   ! $self->may_i({ base_dn => $basedn,
			    filter => $filter,
			    user => $c->user, }) ) {
	$c->stash( template => 'ldap_err.tt',
		   final_message => { error
				      => sprintf('Your roles does not allow search by base dn:<h5>&laquo;<b><em>%s</em></b>&raquo;</h5> and/or filter:<h5>&laquo;<b><em>%s</em></b>&raquo;</h5>ask UMI admin for explanation/s and provide above info.',
						 $basedn,
						 $filter ), }, );
	return 0;
      }

      $c->stats->profile( begin => "searchby_advanced_search" );

      # p $params;
      my @attrs = ( '*' );
      @attrs = split(/,/, $params->{'show_attrs'}) if $params->{'show_attrs'} ne '';
      push @attrs,
	'createTimestamp',
	'creatorsName',
	'modifiersName',
	'modifyTimestamp';
      
      $ldap_crud = $c->model('LDAP_CRUD');
      my $mesg = $ldap_crud->search({
				     base => $basedn,
				     filter => $filter,
				     scope => $scope,
				     sizelimit => $params->{'search_results'},
				     attrs => \@attrs,
				    });
      my $return;
      $return->{warning} = $ldap_crud->err($mesg)->{html} if ! $mesg->count;
      
      my @entries = defined $params->{order_by} &&
	$params->{order_by} ne '' ? $mesg->sorted(split(/,/,$params->{order_by})) : $mesg->sorted('dn');

      $c->stats->profile("search by filter requested");

      my ( $ttentries, @ttentries_keys, $attr, $dn_depth,  $dn_depthes, $to_utf_decode, @root_arr, @root_dn, $root_i, $root_mesg, $root_entry, @root_groups, $obj_item, $tmp );
      my $blocked = 0;
      foreach (@entries) {
	if ( $_->dn =~ /.*,$ldap_crud->{cfg}->{base}->{acc_root}/ ) {
	  $dn_depth = scalar split(/,/, $ldap_crud->{cfg}->{base}->{acc_root}) + 1;
	  $mesg = $ldap_crud->search({
				      base => $ldap_crud->cfg->{base}->{group},
				      filter => sprintf('(&(cn=%s)(memberUid=%s))',
							$ldap_crud->cfg->{stub}->{group_blocked},
							substr( (reverse split /,/, $_->dn)[2], 4 )),
				     });
	  $blocked = $mesg->count;
	  $return->{error} .= $ldap_crud->err( $mesg )->{html}
	    if $mesg->is_error();

	  $c->stats->profile('is-blocked search for <i class="text-muted">' . $_->dn . '</i>');
	
	  @root_arr = split(',', $_->dn); p @root_arr;
	  p $root_i = $#root_arr;
	  @root_dn = splice(@root_arr, -1 * $dn_depth);
	  $ttentries->{$_->dn}->{root}->{dn} = join(',', @root_dn);

	  # here, for each entry we are preparing data of the root object it belongs to
	  $root_i++;
	  if ( $root_i == $dn_depth ) {
	    $ttentries->{$_->dn}->{root}->{givenName} = $_->get_value('givenName');
	    $ttentries->{$_->dn}->{root}->{sn} = $_->get_value('sn');
	    $ttentries->{$_->dn}->{root}->{ $ldap_crud->{cfg}->{rdn}->{acc_root} } =
	      $_->get_value($ldap_crud->{cfg}->{rdn}->{acc_root});
	  } else {
	    $root_mesg = $ldap_crud->search({ dn => $ttentries->{$_->dn}->{root}->{dn}, });
	    $return->{error} .= $ldap_crud->err( $root_mesg )->{html}
	      if $root_mesg->is_error();
	    $root_entry = $root_mesg->entry(0);
	    $ttentries->{$_->dn}->{root}->{givenName} = $root_entry->get_value('givenName');
	    $ttentries->{$_->dn}->{root}->{sn} = $root_entry->get_value('sn');
	    $ttentries->{$_->dn}->{root}->{ $ldap_crud->{cfg}->{rdn}->{acc_root} } =
	      $root_entry->get_value($ldap_crud->{cfg}->{rdn}->{acc_root});
	  }

	  # p $ttentries->{$_->dn}->{root};

	  $to_utf_decode = $ttentries->{$_->dn}->{root}->{givenName};
	  utf8::decode($to_utf_decode);
	  $ttentries->{$_->dn}->{root}->{givenName} = $to_utf_decode;

	  $to_utf_decode = $ttentries->{$_->dn}->{root}->{sn};
	  utf8::decode($to_utf_decode);
	  $ttentries->{$_->dn}->{root}->{sn} = $to_utf_decode;

	  $#root_arr = -1;
	  $#root_dn = -1;

	  # p $ttentries->{$_->dn}->{root};
	  $mesg = $ldap_crud->search({ base => sprintf('ou=group,ou=system,%s', $ldap_crud->cfg->{base}->{db}),
				       filter => sprintf('(memberUid=%s)',
							 $ttentries->{$_->dn}->{root}->{ $ldap_crud->{cfg}->{rdn}->{acc_root} }),
				       attrs => [ $ldap_crud->{cfg}->{rdn}->{group} ], });

	  if ( $mesg->is_error() ) {
	    $return->{error} .= $ldap_crud->err( $mesg )->{html};
	  } else {
	    @root_groups = $mesg->entries;
	    foreach ( @root_groups ) {
	      $ttentries->{$_->dn}->{'mgmnt'}->{root_obj_groups}->{ $_->get_value('cn') } = 1;
	    }
	  }
	  # p $ttentries->{$_->dn}->{'mgmnt'}->{root_obj_groups};
	  # p $ttentries->{$_->dn}->{root};
	  
	} elsif ( $_->dn =~ /.*,$ldap_crud->{cfg}->{base}->{inventory}/ ) {
	  $dn_depth = scalar split(/,/, $ldap_crud->{cfg}->{base}->{inventory}) + 1;
	} else {
	  # !!! HARDCODE how deep dn could be to be considered as some type of object, `3' is for what? :( !!!
	  $dn_depth = $ldap_crud->{cfg}->{base}->{dc_num} + 1;
	}


	$ttentries->{$_->dn}->{'mgmnt'} =
	  {
	   is_blocked => $blocked,
	   is_root => scalar split(',', $_->dn) <= $dn_depth ? 1 : 0,
	   is_account => $_->dn =~ /.*,$ldap_crud->{cfg}->{base}->{acc_root}/ ? 1 : 0,
	   is_group => $_->dn =~ /.*,$ldap_crud->{cfg}->{base}->{group}/ ? 1 : 0,
	   is_inventory => $_->dn =~ /.*,$ldap_crud->{cfg}->{base}->{inventory}/ ? 1 : 0,
	   jpegPhoto => $_->dn =~ /.*,$ldap_crud->{cfg}->{base}->{acc_root}/ ? 1 : 0,
	   gitAclProject => $_->exists('gitAclProject') ? 1 : 0,
	   userPassword => $_->exists('userPassword') ? 1 : 0,
	   userDhcp => $_->dn =~ /.*,$ldap_crud->{cfg}->{base}->{acc_root}/ &&
	   scalar split(',', $_->dn) <= 3 ? 1 : 0,
	  };

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
	push @ttentries_keys, $_->dn if $sort_order eq 'reverse'; # for not history searches
	$blocked = 0;
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

      # p $ttentries;
      $c->stash(
		template => 'search/searchby.tt',
		base_dn => $basedn,
		filter => $filter,
		entrieskeys => \@ttentries_keys,
		entries => $ttentries,
		services => $ldap_crud->cfg->{authorizedService},
		schema => $c->session->{ldap}->{obj_schema_attr_equality},
		base_icon => $ldap_crud->cfg->{base}->{icon},
		final_message => $return,
		form => $self->form,
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

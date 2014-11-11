#-*- cperl -*-
#

package UMI::Controller::Root;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller' }

#
# Sets the actions in this controller to be registered with no prefix
# so they function identically to actions created in MyApp.pm
#
__PACKAGE__->config(namespace => '');

=head1 NAME

UMI::Controller::Root - Root Controller for UMI

=head1 DESCRIPTION

[enter your description here]

=head1 METHODS

=head2 index

The root page (/)

=cut

sub index :Path :Args(0) {
    my ( $self, $c ) = @_;

    # Hello World
    # $c->response->body( $c->welcome_message );
    if ( $c->user_exists() ) {
      $c->stash(
		template => 'welcome.tt',
	       );
    } else {
      $c->stash(
		template => 'signin.tt',
	       );
    }
  }

sub about :Path(about) :Args(0) {
    my ( $self, $c ) = @_;
    $c->stash( template => 'about.tt', );
}

sub gitacl_root :Path(gitacl_root) :Args(0) {
    my ( $self, $c ) = @_;
    $c->stash( template => 'gitacl/gitacl_root.tt', );
}

sub dhcp_root :Path(dhcp_root) :Args(0) {
    my ( $self, $c ) = @_;
    $c->stash( template => 'dhcp/dhcp_root.tt', );
}

sub user_root :Path(user_root) :Args(0) {
    my ( $self, $c ) = @_;
    $c->stash( template => 'user/user_root.tt', );
}

sub group_root :Path(group_root) :Args(0) {
    my ( $self, $c ) = @_;
    $c->stash( template => 'group/group_root.tt', );
}

sub accinfo :Path(accinfo) :Args(0) {
    my ( $self, $c ) = @_;
    $c->stash( template => 'acc_info.tt', );
}

sub user_preferences :Path(user_prefs) :Args(0) {
  my ( $self, $c, $args ) = @_;
  if ( $c->user_exists ) {
    my $ldap_crud = $c->model('LDAP_CRUD');

    use Data::Printer colored => 0;
    # p $c->session->{auth_obj}->{title};

    my ( $arg, $mesg, $return, $entry, $entries, $orgs, $domains, $fqdn );
    $entry = '';
    if ( defined $args->{uid} && $args->{uid} ne '' ) {
      $mesg = $ldap_crud->search( {
				   base => sprintf('uid=%s,%s',
						   $args->{uid},
						   $ldap_crud->{cfg}->{base}->{acc_root}),
				   scope => 'base',
				   attrs => [ qw(givenName
						 sn
						 title
						 mail
						 physicalDeliveryOfficeName
						 telephoneNumber) ],
				  } );
      if ( $mesg->code ) {
	$return->{error} .= '<li>' . $ldap_crud->err($mesg) . '</li>';
      } else {
	$entry = $mesg->entry(0);
	$arg = {
		uid => $args->{uid},
		givenname => $entry->get_value('givenname'),
		sn => $entry->get_value('sn'),
		title => $entry->get_value('title'),
		physicaldeliveryofficename => $entry->get_value('physicaldeliveryofficename'),
		telephonenumber => $entry->get_value('telephonenumber'),
	       };
      }
    } else {
      $arg = {
	      uid => $c->session->{auth_uid},
	      givenname => $c->session->{auth_obj}->{givenname},
	      sn => $c->session->{auth_obj}->{sn},
	      title => $c->session->{auth_obj}->{title},
	      mail => $c->session->{auth_obj}->{mail},
	      physicaldeliveryofficename => $c->session->{auth_obj}->{physicaldeliveryofficename},
	      telephonenumber => $c->session->{auth_obj}->{telephonenumber},
	     };
    }

    #=================================================================
    # user organizations
    #
    my $physicalDeliveryOfficeName;
    if ( ref($arg->{physicaldeliveryofficename}) eq 'ARRAY' ) {
      foreach ( @{$arg->{physicaldeliveryofficename}} ) {
	push @{$physicalDeliveryOfficeName}, $_;
      }
    } else {
      push @{$physicalDeliveryOfficeName}, $arg->{physicaldeliveryofficename};
    }

    foreach ( @{$physicalDeliveryOfficeName} ) {
      # here we need to fetch all org recursively to fill all data absent
      # if current object has no attribute needed (postOfficeBox or postalAddress or
      # any other, than we will use the one from it's ancestor
      $mesg = $ldap_crud->search( { base => $_, scope => 'base', } );
      if ( $mesg->code ) {
	$return->{error} .= '<li>' . $ldap_crud->err($mesg) . '</li>';
      } else {
	$entries = $mesg->as_struct;
	foreach (keys (%{$entries})) {
	  $orgs->{$entries->{$_}->{physicaldeliveryofficename}->[0]} =
	    sprintf('%s, %s, %s, %s',
		    $entries->{$_}->{postofficebox}->[0],
		    $entries->{$_}->{postaladdress}->[0],
		    $entries->{$_}->{l}->[0],
		    $entries->{$_}->{st}->[0]
		   );
	  $mesg = $ldap_crud->search( { base => $_,
					attrs => [ 'associatedDomain' ], } );
	  if ( $mesg->code ) {
	    $return->{error} .= '<li>' . $ldap_crud->err($mesg) . '</li>';
	  } else {
	    $domains = $mesg->as_struct;
	    foreach (keys (%{$domains})) {
	      push @{$fqdn->{$entries->{$_}->{physicaldeliveryofficename}->[0]}},
		$domains->{$_}->{associateddomain}->[0];
	    }
	  }
	}
      }
    }

    #=================================================================
    # user jpegPhoto
    #
    $mesg = $ldap_crud->search( { base => sprintf('uid=%s,%s',
						  $arg->{uid},
						  $ldap_crud->{cfg}->{base}->{acc_root}),
				  scope => 'base', } );
    if ( $mesg->code ) {
      $return->{error} .= '<li>' . $ldap_crud->err($mesg) . '</li>';
    }
    $entry = $mesg->entry(0);
    use MIME::Base64;
    my $jpegPhoto = sprintf('<img alt="jpegPhoto of %s" src="data:image/jpg;base64,%s" class="img-responsive img-thumbnail" title="%s"/>',
			    $entry->dn,
			    encode_base64(join('',$entry->get_value('jpegphoto'))),
			    $entry->dn,
			   );

    #=================================================================
    # user DHCP stuff
    #
    my $dhcp;
    $mesg = $ldap_crud->search( { base => $ldap_crud->{cfg}->{base}->{dhcp},
				  filter => sprintf('uid=%s', $arg->{uid}), } );
    if ( $mesg->code ) {
      $return->{error} .= '<li>' . $ldap_crud->err($mesg) . '</li>';
    }
    $entries = $mesg->as_struct;
    foreach (keys (%{$entries})) {
      push @{$dhcp}, {
		      cn => $entries->{$_}->{cn}->[0],
		      ip => substr($entries->{$_}->{dhcpstatements}->[0], 14),
		      mac => substr($entries->{$_}->{dhcphwaddress}->[0], 9),
		     };
    }

    #=================================================================
    # user services
    #
    my ( @service_arr, $service, $service_details );
    $mesg = $ldap_crud->search( { base => 'uid=' . $arg->{uid} . ',' .
				  $ldap_crud->{cfg}->{base}->{acc_root},
				  scope => 'one',
				  filter => 'authorizedService=*',
				  attrs => [ 'authorizedService'],} );
    if ( $mesg->code ) {
      $return->{error} .= '<li>' . $ldap_crud->err($mesg) . '</li>';
    }

    foreach ($mesg->entries) {
      $mesg = $ldap_crud->search( { base => $_->dn,
				    scope => 'children',
				  attrs => [ 'uid', 'cn' ], });
      if ( $mesg->code ) {
	$return->{error} .= '<li>' . $ldap_crud->err($mesg) . '</li>';
      }
      next if ! $mesg->count;
      $service_details = {
			  branch_dn => $_->dn,
			  authorizedService => $_->get_value('authorizedService'),
			 };

      @service_arr = $mesg->entries;

      foreach (@service_arr) {
	$service_details->{leaf}->{$_->dn} = $_->get_value('uid');
      }
      push @{$service}, $service_details;
      undef $service_details;
    }

    # p $arg;
    $c->stash( template => 'user/user_preferences.tt',
	       auth_obj => $arg,
	       jpegPhoto => $jpegPhoto,
	       orgs => $orgs,
	       fqdn => $fqdn,
	       dhcp => $dhcp,
	       service => $service,
	       session => p($c->session),
	       final_message => $return, );
  } else {
    $c->stash( template => 'signin.tt', );
  }
}

sub org_root :Path(org_root) :Args(0) {
    my ( $self, $c ) = @_;
    $c->stash( template => 'org/org_root.tt', );
}


sub access_denied : Private {
  my ( $self, $c ) = @_;
  $c->stash( template => '403.tt', );
}


=head2 default

Standard 404 error page

=cut

sub default :Path {
    my ( $self, $c ) = @_;
    # $c->response->body( 'Page not found' );
    $c->stash( template => '404.tt', );
    $c->response->status(404);
}

sub auto : Private {
  my ($self, $c) = @_;

  if ( defined $c->session->{"auth_uid"} &&
       defined $c->session->{"auth_pwd"} &&
       $c->authenticate({
			 id       => $c->session->{"auth_uid"},
			 password => $c->session->{"auth_pwd"},
			})) {
    $c->stash( template => 'welcome.tt', );
  } else {
    $c->stash( template => 'signin.tt', );
  }
}


=head2 end

Attempt to render a view, if needed.

=cut

sub end : ActionClass('RenderView') {}

=head1 AUTHOR

Zeus Panchenko

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;

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


sub accinfo :Path(accinfo) :Args(0) {
    my ( $self, $c ) = @_;
    $c->stash( template => 'acc_info.tt', );
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

sub user_preferences :Path(user_prefs) :Args(0) {
  my ( $self, $c ) = @_;
  if ( $c->user_exists ) {
    my $physicalDeliveryOfficeName;
    if ( ref($c->session->{auth_obj}->{physicaldeliveryofficename}) eq 'ARRAY' ) {
      foreach ( @{$c->session->{auth_obj}->{physicaldeliveryofficename}} ) {
	push @{$physicalDeliveryOfficeName}, $_;
      }
    } else {
      push @{$physicalDeliveryOfficeName}, $c->session->{auth_obj}->{physicaldeliveryofficename};
    }
    use Data::Printer;
    # p $c->session->{auth_obj}->{title};

    my ( $mesg, $return, $entries, $orgs, $domains, $fqdn, $dhcp );
    my $ldap_crud = $c->model('LDAP_CRUD');
    foreach ( @{$physicalDeliveryOfficeName} ) {
      # here we need to fetch all org recursively to fill all data absent
      # if current object has no attribute needed (postOfficeBox or postalAddress or
      # any other, than we will use the one from it's ancestor
      $mesg = $ldap_crud->search( { base => $_, scope => 'base', } );
      if ( $mesg->code ) {
	$return->[2] .= '<li>' . $ldap_crud->err($mesg) . '</li>';
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
	    $return->[2] .= '<li>' . $ldap_crud->err($mesg) . '</li>';
	  } else {
	    $domains = $mesg->as_struct;
	    foreach (keys (%{$domains})) {
	      push @{$fqdn->{$entries->{$_}->{physicaldeliveryofficename}->[0]}}, $domains->{$_}->{associateddomain}->[0];
	    }
	  }
	}
      }
    }

    $mesg = $ldap_crud->search( { base => 'uid=' . $c->session->{auth_uid} . ',' . $ldap_crud->{cfg}->{base}->{acc_root},
				  scope => 'base', } );
    if ( $mesg->code ) {
      $return->[2] .= '<li>' . $ldap_crud->err($mesg) . '</li>';
    }
    my $entry = $mesg->entry(0);
    use MIME::Base64;
    my $jpegPhoto = sprintf('<img alt="jpegPhoto of %s" src="data:image/jpg;base64,%s" class="img-responsive img-thumbnail pull-left" title="%s"/>',
			    $entry->dn,
			    encode_base64(join('',$entry->get_value('jpegphoto'))),
			    $entry->dn,
			   );

    # taking all DHCP stuff user relates to
    $mesg = $ldap_crud->search( { base => $ldap_crud->{cfg}->{base}->{dhcp},
				  filter => sprintf('uid=%s', $c->session->{auth_uid}), } );
    if ( $mesg->code ) {
      $return->[2] .= '<li>' . $ldap_crud->err($mesg) . '</li>';
    }
    $entries = $mesg->as_struct;
    foreach (keys (%{$entries})) {
      push @{$dhcp}, {
		      cn => $entries->{$_}->{cn}->[0],
		      ip => substr($entries->{$_}->{dhcpstatements}->[0], 14),
		      mac => substr($entries->{$_}->{dhcphwaddress}->[0], 9),
		     };
    }

    $c->stash( template => 'user/user_preferences.tt',
	       auth_obj => $c->session->{auth_obj},
	       jpegPhoto => $jpegPhoto,
	       orgs => $orgs,
	       fqdn => $fqdn,
	       dhcp => $dhcp, );
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

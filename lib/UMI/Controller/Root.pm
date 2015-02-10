#-*- cperl -*-
#

package UMI::Controller::Root;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; with 'Tools'; }

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

## working sample
# use UMI::Wizard::MultiPage;
# has 'multiform' => ( isa => 'UMI::Wizard::MultiPage', is => 'rw',
# 		     lazy => 1, default => sub { UMI::Wizard::MultiPage->new },
# 		     documentation => q{MultiPage Form},
# 		   );

# sub multipage :Path(multipage) :Args(0) {
#   my ( $self, $c ) = @_;
#   $c->stash( template => 'multipage.tt',
# 	     form => $self->multiform );

#   return unless
#     $self->multiform->process(
# 			      posted => ($c->req->method eq 'POST'),
# 			      params => $c->req->parameters,
# 			     );
# }


=head2 download_from_ldap

action to retrieve PKCS12 certificate from LDAP
now it is now used since we had not agreed yet on
account of whether we wish it ...

=cut

sub download_from_ldap :Path(download_from_ldap) :Args(0) {
  use Data::Printer;

  my ( $self, $c ) = @_;
  # application/x-x509-ca-cert
  # application/x-x509-user-cert
  # application/x-pem-file
  my $params = $c->request->params;
  my $arg = {
	     dn => $params->{dn},
	     attr => $params->{attr} || 'userPKCS12',
	     content_type => $params->{content_type} || 'application/x-pkcs12',
	    };

  my ( $ldap_crud, $mesg, $entry, $file, $authorizedService, $return);
  $ldap_crud = $c->model('LDAP_CRUD');
  $mesg = $ldap_crud->search( {
			       base => $arg->{dn},
			       scope => 'base',
			      } );
  if ( $mesg->code ) {
    $return->{error} .= '<li>file download info: ' .
      $ldap_crud->err($mesg)->{caller} . $ldap_crud->err($mesg)->{html} . '</li>';
  } else {
    $entry = $mesg->entry(0);
    $file = join('', $entry->get_value( $arg->{attr} ));
    $c->response->body($file);
    $c->response->headers->content_type($arg->{content_type});
    $c->response->header( 'Content-Disposition' => sprintf('attachment; filename=%s-%s.p12',
							   (split('=',(split(',', $arg->{dn}))[1]))[1],
							   $entry->get_value('cn')) );
  }
}

sub user_preferences :Path(user_prefs) :Args(0) {
  my ( $self, $c, $args ) = @_;
  if ( $c->user_exists ) {
    my $ldap_crud = $c->model('LDAP_CRUD');

    use Data::Printer colored => 0;
    # p $c->session->{auth_obj}->{title};

    my ( $arg, $mesg, $return, $entry, $entries, $orgs, $domains, $fqdn,
	 @physicaldeliveryofficename, @telephonenumber, @title, @mail, @roles,
	 $physicaldeliveryofficename, $telephonenumber, $title, $mail, $roles, );

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
	$return->{error} .= '<li>personal info' . $ldap_crud->err($mesg)->{caller} . $ldap_crud->err($mesg)->{html} . '</li>';
      } else {
	$entry = $mesg->entry(0);
	@physicaldeliveryofficename = $entry->get_value('physicaldeliveryofficename');
	@telephonenumber = defined $entry->get_value('telephonenumber') ? $entry->get_value('telephonenumber') : 'N/A';
	@title = defined $entry->get_value('title');
	@mail = $entry->get_value('mail');
	$arg = {
		uid => $args->{uid},
		givenname => $entry->get_value('givenname'),
		sn => $entry->get_value('sn'),
		title => \@title,
		physicaldeliveryofficename => \@physicaldeliveryofficename,
		telephonenumber => \@telephonenumber,
		mail => \@mail,
		roles => '<span class="fa fa-exclamation-triangle text-warning">' .
		'<h6><em>to fix roles for non system accounts ' .
		(caller(1))[3] . ' L:' .
		(caller(1))[2] . '</em></h6></span></li>',
	       };
      }
    } else {
      $physicaldeliveryofficename = $c->user->has_attribute('physicaldeliveryofficename') ?
	$c->user->physicaldeliveryofficename : 'N/A';
      $telephonenumber = $c->user->has_attribute('telephonenumber') ?
	$c->user->telephonenumber : 'N/A';
      $title = $c->user->has_attribute('title') ? $c->user->title : 'N/A';
      $mail = $c->user->has_attribute('mail') ? $c->user->mail : 'N/A';
      $roles = $c->user->roles;
      $arg = {
	      uid => $c->user->uid,
	      givenname => $c->user->givenname || 'N/A',
	      sn => $c->user->sn || 'N/A',
	      title => $title,
	      mail => $mail,
	      physicaldeliveryofficename => $physicaldeliveryofficename,
	      telephonenumber => $telephonenumber,
	      roles => $roles || 'N/A',
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
	$return->{error} .= '<li>organization/s<br>' . $ldap_crud->err($mesg)->{caller} . $ldap_crud->err($mesg)->{html} . 
	  '<em>' . (caller(1))[3] . ' @ line:' . (caller(1))[2] . '</em></li>';
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
	    $return->{error} .= '<li>associatedDomain/s' . $ldap_crud->err($mesg)->{caller} . $ldap_crud->err($mesg)->{html} . '</li>';
	  } else {
	    $domains = $mesg->entry(0);
	    @{$fqdn->{$entries->{$_}->{physicaldeliveryofficename}->[0]}} =
		$domains->get_value('associatedDomain');
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
      $return->{error} .= '<li>jpegPhoto' . $ldap_crud->err($mesg)->{caller} . $ldap_crud->err($mesg)->{html} . '</li>';
    }
    $entry = $mesg->entry(0);
    use MIME::Base64;
    my $jpegPhoto = sprintf('<img alt="jpegPhoto of %s" src="data:image/jpg;base64,%s" class="img-responsive img-thumbnail bg-info" title="%s"/>',
			    $entry->dn,
			    encode_base64(join('',$entry->get_value('jpegphoto'))),
			    $entry->dn,
			   );

    #=================================================================
    # user DHCP stuff
    #
    my ( $dhcp, $dhcpOption, @dhcpOption_item, @x, $domain_name );
    $mesg = $ldap_crud->search( { base => $ldap_crud->{cfg}->{base}->{dhcp},
				  filter => sprintf('uid=%s', $arg->{uid}), } );
    if ( $mesg->code ) { $return->{error} .= '<li>DHCP' . $ldap_crud->err($mesg)->{caller} . $ldap_crud->err($mesg)->{html} . '</li>'; }
    $entries = $mesg->as_struct;
    foreach (keys (%{$entries})) {
      @x = split(',', $_);
      splice @x, 0, 1;
      $mesg = $ldap_crud->search( { base => join(',', @x),
				    scope => 'base',
				    attrs => [ 'dhcpOption' ],} );
      if ( $mesg->code ) { $return->{error} .= '<li>DHCP domain-name/s' . $ldap_crud->err($mesg)->{caller} . $ldap_crud->err($mesg)->{html} . '</li>'; }
      $dhcpOption = $mesg->entry(0);
      @dhcpOption_item = $dhcpOption->get_value('dhcpOption');
      foreach ( @dhcpOption_item ) {
	$domain_name = substr($_, 13, -1) if $_ =~ /domain-name /;
      }

      push @{$dhcp}, {
		      dn => $_,
		      cn => $entries->{$_}->{cn}->[0],
		      fqdn => $domain_name,
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
      $return->{error} .= '<li>services list' . $ldap_crud->err($mesg)->{caller} . $ldap_crud->err($mesg)->{html} . '</li>';
    }

    foreach ($mesg->sorted( 'authorizedService' )) {
      $mesg = $ldap_crud->search( { base => $_->dn,
				    scope => 'children',
				  });
      if ( $mesg->code ) {
	$return->{error} .= '<li>each service children' . $ldap_crud->err($mesg)->{caller} . $ldap_crud->err($mesg)->{html} . '</li>';
      }
      next if ! $mesg->count;
      $service_details = {
			  branch_dn => $_->dn,
			  authorizedService => $_->get_value('authorizedService'),
			  icon => $ldap_crud->{cfg}->{authorizedService}
			  ->{(split('@', $_->get_value('authorizedService')))[0]}->{icon},
			  descr => $ldap_crud->{cfg}->{authorizedService}
			  ->{(split('@', $_->get_value('authorizedService')))[0]}->{descr},
			 };

      @service_arr = $mesg->sorted( 'authorizedService' );

      foreach (@service_arr) {
	$service_details->{leaf}->{$_->dn} = defined $_->get_value('uid') ? $_->get_value('uid') : $_->get_value('cn');

	if ( (split('@', $service_details->{authorizedService}))[0] eq 'ovpn' ) {
	  $service_details->{cert}->{$_->dn} =
	    $self->cert_info({ cert => $_->get_value('userCertificate;binary') });
	} elsif ( (split('@', $service_details->{authorizedService}))[0] eq 'ssh' ) {
	  @{$service_details->{sshkey}->{$_->dn}} = $_->get_value('sshPublicKey');
	}
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

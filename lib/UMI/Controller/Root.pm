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
      $c->stash( template => 'welcome.tt', );
    } else {
      $c->stash( template => 'signin.tt', );
    }
  }

sub about :Path(about) :Args(0) {
    my ( $self, $c ) = @_;
    $c->stash( template => 'about.tt', );
}

sub gitacl_root :Path(gitacl_root) :Args(0) {
    my ( $self, $c ) = @_;
    $c->stash( template => 'gitacl/gitacl_wrap.tt', );
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

sub sysinfo :Path(sysinfo) :Args(0) {
  my ( $self, $c ) = @_;
  my $sysinfo;
  my %x = %{$c->session};
  $x{auth_pwd} = 'CENSORED';
  $x{auth_obj}->{userpassword} = 'CENSORED';
  use Data::Printer colored => 0;
  $sysinfo = {
	      session => { title => 'Session',
			   data => np(%x, colored => 0), },
	      LDAP_CRUD_cfg => { title => 'LDAP_CRUD configuration ( $c->model(LDAP_CRUD)->cfg )',
				 data => np($c->model('LDAP_CRUD')->cfg, colored => 0), },
	      # UMI_c => { title => 'UMI c',
	      # 		      data => p($c, colored => 0), },
	     };

  $c->stash( template => 'sysinfo.tt',
	     sysinfo => $sysinfo, );
}

=head2 download_from_ldap

action to retrieve PKCS12 certificate from LDAP
now it is not used since we had not agreed yet on
account of whether we wish it ...

=cut

sub download_from_ldap :Path(download_from_ldap) :Args(0) {
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
  my ( $self, $c, $user_dn ) = @_;
  my @user_rdn = split('=', $user_dn);
  if ( $c->user_exists ) {
    my $ldap_crud = $c->model('LDAP_CRUD');

    my ( $arg, $mesg, $return, $entry, $entries, $orgs, $domains, $fqdn,
	 $physicaldeliveryofficename, $telephonenumber, $title, $mail, );

    #=================================================================
    # user personal data
    #
    $entry = '';
    if ( defined $user_dn && $user_dn ne '' ) {
      $mesg = $ldap_crud->search({ base => $user_dn,
				   scope => 'base',
				   attrs => [ qw( cn
						  uid
						  givenName
						  sn
						  title
						  mail
						  physicalDeliveryOfficeName
						  telephoneNumber) ], });
      if ( $mesg->code ) {
	$return->{error} .= sprintf('<li>personal info %s</li>',
				    $ldap_crud->err($mesg)->{html});
      } else {
	$entry = $mesg->entry(0);
	$arg = {
		uid => $entry->get_value('uid'),
		givenname => $entry->get_value('givenName'),
		sn => $entry->get_value('sn'),
		title => defined $entry->get_value('title') ? \@{[$entry->get_value('title')]} : ['N/A'],
		physicaldeliveryofficename => \@{[$entry->get_value('physicaldeliveryofficename')]},
		telephonenumber => defined $entry->get_value('telephonenumber') ?
		\@{[$entry->get_value('telephonenumber')]} : ['N/A'],
		mail => defined $entry->get_value('mail') ? \@{[$entry->get_value('mail')]} : ['N/A'],
		roles => $entry->get_value( $user_rdn[0] ) eq $c->user ? \@{[$c->user->roles]} : 'a mere mortal',
	       };
	utf8::decode($arg->{givenname});
	utf8::decode($arg->{sn});
      }
    } else {
      $physicaldeliveryofficename = $c->user->has_attribute('physicaldeliveryofficename') ?
	$c->user->physicaldeliveryofficename : 'N/A';
      $telephonenumber = $c->user->has_attribute('telephonenumber') ?
	$c->user->telephonenumber : 'N/A';
      $title = $c->user->has_attribute('title') ? $c->user->title : 'N/A';
      $mail = $c->user->has_attribute('mail') ? $c->user->mail : 'N/A';
      $arg = {
	      uid => $c->user->uid,
	      givenname => $c->user->givenname || 'N/A',
	      sn => $c->user->sn || 'N/A',
	      title => $title,
	      mail => $mail,
	      physicaldeliveryofficename => $physicaldeliveryofficename,
	      telephonenumber => $telephonenumber,
	      roles => \@{[$c->user->roles]} || 'N/A',
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
	$return->{error} .= '<li>organization/s<br>' . $ldap_crud->err($mesg)->{html};
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
	    $return->{error} .= sprintf('<li>associatedDomain/s %s</li>',
					$ldap_crud->err($mesg)->{html});
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
    $mesg = $ldap_crud->search( { base => $user_dn,
				  scope => 'base', } );
    if ( $mesg->code ) {
      $return->{error} .= sprintf('<li>jpegPhoto %s</li>',
				  $ldap_crud->err($mesg)->{html});
    }
    $entry = $mesg->entry(0);
    use MIME::Base64;
    my $jpegPhoto = sprintf('<img alt="jpegPhoto of %s" src="data:image/jpg;base64,%s" class="img-responsive img-thumbnail bg-info" title="%s"/>',
			    $entry->dn,
			    encode_base64($entry->get_value('jpegPhoto')),
			    $entry->dn,
			   );

    #=================================================================
    # user DHCP stuff
    #
    my ( $dhcp, @x, $domain_name );
    $mesg = $ldap_crud->search( { base => $ldap_crud->cfg->{base}->{dhcp},
				  filter => sprintf('uid=%s', $arg->{uid}), } );
    if ( $mesg->code ) { $return->{error} .= sprintf('<li>DHCP %s</li>',
						     $ldap_crud->err($mesg)->{html}); }
    $entries = $mesg->as_struct;
    foreach (keys (%{$entries})) {
      @x = split(',', $_);
      splice @x, 0, 1;
      $mesg = $ldap_crud->search( { base => join(',', @x),
				    scope => 'base',
				    attrs => [ 'dhcpOption' ],} );
      if ( $mesg->code ) { $return->{error} .= sprintf('<li>DHCP domain-name/s %s</li>',
						       $ldap_crud->err($mesg)->{html}); }
      foreach ( @{[$mesg->entry(0)->get_value('dhcpOption')]} ) {
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
    my ( $service, $service_details );
    $mesg = $ldap_crud->search( { base => 'uid=' . $arg->{uid} . ',' .
				  $ldap_crud->cfg->{base}->{acc_root},
				  scope => 'one',
				  filter => 'authorizedService=*',
				  attrs => [ 'authorizedService'],} );
    if ( $mesg->code ) {
      $return->{error} .= sprintf('<li>services list %s</li>',
				  $ldap_crud->err($mesg)->{html});
    }
    foreach ($mesg->sorted( 'authorizedService' )) {
      $mesg = $ldap_crud->search( { base => $_->dn, scope => 'children', });
      if ( $mesg->code ) {
	$return->{error} .= sprintf('<li>each service children %s</li>',
				    $ldap_crud->err($mesg)->{html});
      }
      next if ! $mesg->count;
      $service_details = {
			  branch_dn => $_->dn,
			  authorizedService => $_->get_value('authorizedService'),
			  auth => $ldap_crud->cfg->{authorizedService}
			  ->{(split('@', $_->get_value('authorizedService')))[0]}->{auth},
			  icon => $ldap_crud->cfg->{authorizedService}
			  ->{(split('@', $_->get_value('authorizedService')))[0]}->{icon},
			  descr => $ldap_crud->cfg->{authorizedService}
			  ->{(split('@', $_->get_value('authorizedService')))[0]}->{descr},
			 };

      foreach (@{[$mesg->sorted( 'authorizedService' )]}) {
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

    #=================================================================
    # Inventory assigned to user
    #
    my ( @inventory );
    $mesg = $ldap_crud->search( { base => $ldap_crud->cfg->{base}->{inventory},
				  filter => sprintf('hwAssignedTo=%s', $user_dn), }
			      );
    if ( $mesg->code ) { $return->{error} .= sprintf('<li>Inventory %s</li>',
						     $ldap_crud->err($mesg)->{html}); }
    my ($hwType_l, $hwType_r, $hwObj);
    $entries = $mesg->as_struct;
    foreach (keys (%{$entries})) {
      $hwObj = $ldap_crud->show_inventory_item({ dn => $_ });
      ($hwType_l, $hwType_r) = split('_', $entries->{$_}->{hwtype}->[0]);
      push @inventory, { hwType =>
			 sprintf( '<i title="%s" class="%s"></i> <mark class="h5"><b>I/N: %s</b></mark>',
				  $ldap_crud->{cfg}->{hwType}->{$hwType_l}->{$hwType_r}->{descr},
				  $ldap_crud->{cfg}->{hwType}->{$hwType_l}->{$hwType_r}->{icon},
				  $entries->{$_}->{inventorynumber}->[0] ),
			 dn => $_,
			 hwObj => $hwObj,
		       };
      # push @inventory, { dn => $_, hwType => $entries->{$_}->{hwtype}->[0] };
      p @inventory;
    }

    #=================================================================
    # FINISH
    #
    # $c->stash( template => 'user/user_preferences.tt',
    $c->stash( template => 'user/user_preferences_neo.tt',
	       auth_obj => $arg,
	       jpegPhoto => $jpegPhoto,
	       orgs => $orgs,
	       fqdn => $fqdn,
	       dhcp => $dhcp,
	       inventory => \@inventory,
	       service => $service,
	       session => $c->session,
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
  if ( defined $c->session->{"auth_uid"} &&
       defined $c->session->{"auth_pwd"} ) {
    $c->stash( template => '403.tt', );
  } else {
    $c->stash( template => 'signin.tt', );
  }
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

sub end : ActionClass('RenderView') {
  my ( $self, $c ) = @_;
  my @rep = $c->stats->report;
  my $stats = { debug => UMI->config->{debug}->{level},
		elapsed => $c->stats->elapsed,
		report => \@rep };
  $c->stash( stats => $stats );
  
  # if ( $c->error and $c->error->[-1] eq "access denied" ) {
  #   $c->error(0); # clear the error
  #   # access denied
  # }
}

=head1 AUTHOR

Zeus Panchenko

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;

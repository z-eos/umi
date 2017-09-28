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

sub motto :Path(motto) :Args(0) {
    my ( $self, $c ) = @_;
    $c->stash( template => 'motto.tt', );
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

sub server_mta_root :Path(server/mta/srv_mta_root) :Args(0) {
    my ( $self, $c ) = @_;
    $c->stash( template => 'server/mta/srv_mta_root.tt', );
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

  use Data::Printer colored => 0;

  my $sysinfo;
  my %x = @{$c->dump_these};
  # $x{dump_these} = $c->dump_these;
  $x{calculate_initial_session_expires} = localtime($c->calculate_initial_session_expires);
  $x{get_session_id} = localtime($c->get_session_id);
  $x{session_expires} = localtime($c->session_expires);
  $x{auth_pwd} = 'CENSORED';
  $x{auth_obj}->{userpassword} = 'CENSORED';

  my $return;
  my $ldap_crud = $c->model('LDAP_CRUD');
  my $mesg = $ldap_crud->search({ base => $ldap_crud->{cfg}->{base}->{monitor},
				  scope => 'sub',
				  sizelimit => 0,
				  attrs   => [ '*', '+', ],
				  filter => '(objectClass=*)', });
  if ( $mesg->code ) {
    push @{$return->{error}}, $ldap_crud->err($mesg)->{html};
  }
  my $monitor = $mesg->as_struct;

  $sysinfo = {
	      session => { title => 'Session',
			   data => np(%x, colored => 0), },
	      LDAP_CRUD_cfg => { title => 'LDAP_CRUD configuration ( $c->model(LDAP_CRUD)->cfg )',
				 data => np($c->model('LDAP_CRUD')->cfg, colored => 0), },
	      # look stat_monitor()
	      monitor => { title => 'OpenLDAP daemon monitor',
			   data => np($monitor, colored => 0), },
	      # UMI_c => { title => 'UMI c',
	      # 		      data => p($c, colored => 0), },
	     };

  $c->stash( template => 'sysinfo.tt',
	     sysinfo => $sysinfo,
	     final_message => $return, );
}

=head2 stat_acc

each root account, all services listing

no way to shorten the list to some specific service, yet

=cut

sub stat_acc :Path(stat_acc) :Args(0) {
  my ( $self, $c ) = @_;

  if ( $c->user_exists() ) {  
    my ( $account, $accounts, $utf_givenName, $utf_sn,
	 $svc, @services, $service,
	 $mesg_blk, @mesg_blk_entries,
	 $mesg_svc, @mesg_svc_entries,
	 $authorizedService,
	 $return, );

    my $ldap_crud = $c->model('LDAP_CRUD');
    my $mesg = $ldap_crud->search({ base => $ldap_crud->{cfg}->{base}->{acc_root},
				    scope => 'one',
				    sizelimit => 0,
				    attrs   => [ 'uid', 'givenName', 'sn', ],
				    filter => '(objectClass=*)', });
    if ( $mesg->code ) {
      push @{$return->{error}}, $ldap_crud->err($mesg)->{html};
    } else {
      foreach $account ( @{[$mesg->entries]} ) {
	$utf_givenName = $account->get_value('givenName');
	$utf_sn = $account->get_value('sn');
	utf8::decode($utf_givenName);
	utf8::decode($utf_sn);
	$accounts->{$account->dn} = { uid => $account->get_value('uid'),
				      givenName => $utf_givenName,
				      sn => $utf_sn,
				      authorizedService => {},
				      blocked => 0, };

	$mesg_blk = $ldap_crud->search({ base => $ldap_crud->{cfg}->{base}->{group},
					 scope => 'one',
					 sizelimit => 0,
					 filter => sprintf('(&(cn=blocked)(memberUid=%s))',
							   $accounts->{$account->dn}->{uid}),
					 attrs   => [ 'cn' ] });
	if ( $mesg_blk->code ) {
	  push @{$return->{error}}, $ldap_crud->err($mesg_blk)->{html};
	} else {
	  @mesg_blk_entries = $mesg_blk->entry(0);
	  $accounts->{$account->dn}->{blocked} = 1 if $mesg_blk->count;
	}

	$mesg_svc = $ldap_crud->search({ base => $account->dn,
					 scope => 'one',
					 sizelimit => 0,
					 filter => '(authorizedService=*)',
					 attrs => [ 'authorizedService', ], });
	if ( $mesg_svc->code ) {
	  push @{$return->{error}}, $ldap_crud->err($mesg_svc)->{html};
	} else {
	  @mesg_svc_entries = $mesg_svc->entries;
	  foreach ( @mesg_svc_entries ) {
	    $svc->{ (split('@', $_->get_value('authorizedService')))[0] } = 1;
	  }
	  @services = sort keys %{$svc};

	  $#mesg_svc_entries = -1;
	  foreach $service ( @services ) {
	    $mesg_svc = $ldap_crud->search({ base => $account->dn,
					     scope => 'sub',
					     sizelimit => 0,
					     filter => sprintf('authorizedService=%s@*', $service),
					     attrs => [ 'associatedDomain',
							'authorizedService',
							'cn',
							'uid' ], });
	    if ( $mesg_svc->code ) {
	      push @{$return->{error}}, $ldap_crud->err($mesg_svc)->{html};
	    } else {
	      @mesg_svc_entries = $mesg_svc->entries;
	      if ($mesg_svc->count) {
		foreach ( @mesg_svc_entries ) {
		  next if ! $_->exists('associatedDomain');

		  push @{$accounts->{$account->dn}->{authorizedService}->{$service}
			   ->{$_->get_value('associatedDomain')}},
			   { uid => $_->exists('uid') ? $_->get_value('uid') : 'NA',
			     cn  => $_->exists('cn')  ? $_->get_value('cn')  : 'NA', };
		}
	      }
	    }
	  }
	}
      }
    }

    $c->stash( template => 'stat_acc.tt',
	       accounts => $accounts,
	       final_message => $return,);
  } else {
    $c->stash( template => 'signin.tt', );
  }

}


=head2 stat_monitor

method to provide information about the running status of the slapd(8) daemon

for now it is used in sysinfo()

=cut

sub stat_monitor :Path(stat_monitor) :Args(0) {
  my ( $self, $c ) = @_;
  if ( $c->user_exists() ) {
    my $return;
    my $monitor;
    my $ldap_crud = $c->model('LDAP_CRUD');
    my $mesg = $ldap_crud->search({ base => 'cn=Databases,' . $ldap_crud->{cfg}->{base}->{monitor},
				  scope => 'one',
				  sizelimit => 0,
				  attrs   => [ '*', '+', ],
				  filter => '(objectClass=*)', });
    if ( $mesg->code ) {
      push @{$return->{error}}, $ldap_crud->err($mesg)->{html};
    } else {
      foreach ( @{[$mesg->entries]} ) {
	$monitor->{databases}->{ $_->get_value('cn') } =
	  { monitoredInfo => $_->exists('monitoredInfo') ? $_->get_value('monitoredInfo') : 'NA',
	    namingContexts => $_->exists('namingContexts') ? $_->get_value('namingContexts') : 'NA',
	    entryDN => $_->exists('entryDN') ? $_->get_value('entryDN') : 'NA',
	    olmBDBEntryCache => $_->exists('olmBDBEntryCache') ? $_->get_value('olmBDBEntryCache') : 'NA',
	    olmBDBDNCache => $_->exists('olmBDBDNCache') ? $_->get_value('olmBDBDNCache') : 'NA',
	    olmBDBIDLCache => $_->exists('olmBDBIDLCache') ? $_->get_value('olmBDBIDLCache') : 'NA',
	    olmDbDirectory => $_->exists('olmDbDirectory') ? $_->get_value('olmDbDirectory') : 'NA',
	    # seeAlso => $_->get_value('seeAlso', asref => 1 ),
	    # monitorOverlay => $_->get_value('monitorOverlay', asref => 1 ),
	  };
      }
    }

    $mesg = $ldap_crud->search({ base => 'cn=Connections,' . $ldap_crud->{cfg}->{base}->{monitor},
				 scope => 'one',
				 sizelimit => 0,
				 attrs   => [ '*', '+', ],
				 filter => '(objectClass=*)', });
    if ( $mesg->code ) {
      push @{$return->{error}}, $ldap_crud->err($mesg)->{html};
    } else {
      foreach ( @{[$mesg->entries]} ) {
	$monitor->{connections}->{ $_->get_value('cn') } =
	  { monitorConnectionNumber => $_->exists('monitorConnectionNumber') ? $_->get_value('monitorConnectionNumber') : 'NA',
	    monitorConnectionProtocol => $_->exists('monitorConnectionProtocol') ? $_->get_value('monitorConnectionProtocol') : 'NA',
	    monitorConnectionOpsReceived => $_->exists('monitorConnectionOpsReceived') ? $_->get_value('monitorConnectionOpsReceived') : 'NA',
	    monitorConnectionOpsExecuting => $_->exists('monitorConnectionOpsExecuting') ? $_->get_value('monitorConnectionOpsExecuting') : 'NA',
	    monitorConnectionOpsPending => $_->exists('monitorConnectionOpsPending') ? $_->get_value('monitorConnectionOpsPending') : 'NA',
	    monitorConnectionOpsCompleted => $_->exists('monitorConnectionOpsCompleted') ? $_->get_value('monitorConnectionOpsCompleted') : 'NA',
	    monitorConnectionGet => $_->exists('monitorConnectionGet') ? $_->get_value('monitorConnectionGet') : 'NA',
	    monitorConnectionRead => $_->exists('monitorConnectionRead') ? $_->get_value('monitorConnectionRead') : 'NA',
	    monitorConnectionWrite => $_->exists('monitorConnectionWrite') ? $_->get_value('monitorConnectionWrite') : 'NA',
	    monitorConnectionMask => $_->exists('monitorConnectionMask') ? $_->get_value('monitorConnectionMask') : 'NA',
	    monitorConnectionAuthzDN => $_->exists('monitorConnectionAuthzDN') ? $_->get_value('monitorConnectionAuthzDN') : 'NA',
	    monitorConnectionListener => $_->exists('monitorConnectionListener') ? $_->get_value('monitorConnectionListener') : 'NA',
	    monitorConnectionPeerDomain => $_->exists('monitorConnectionPeerDomain') ? $_->get_value('monitorConnectionPeerDomain') : 'NA',
	    monitorConnectionPeerAddress => $_->exists('monitorConnectionPeerAddress') ? $_->get_value('monitorConnectionPeerAddress') : 'NA',
	    monitorConnectionLocalAddress => $_->exists('monitorConnectionLocalAddress') ? $_->get_value('monitorConnectionLocalAddress') : 'NA',
	    entryDN => $_->exists('entryDN') ? $_->get_value('entryDN') : 'NA', };
      }
    }

    $c->stash( template => 'stat_monitor.tt',
		 monitor => $monitor,
		 final_message => $return, );
  } else {
    $c->stash( template => 'signin.tt', );
  }
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
  if ( $c->user_exists ) {
    # p $c->user->supported_features;
    my @user_rdn = split('=', $user_dn);
    my $ldap_crud = $c->model('LDAP_CRUD');

    my ( $arg, $mesg, $return, $entry, $entries, $orgs, $domains, $fqdn, $o,
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
						  o
						  physicalDeliveryOfficeName
						  telephoneNumber) ], });
      if ( $mesg->code ) {
	$return->{error} .= sprintf('<li>personal info %s</li>',
				    $ldap_crud->err($mesg)->{html});
      } else {
	$entry = $mesg->as_struct;
	$arg = {
		uid => $entry->{$user_dn}->{uid}->[0],
		givenname => $entry->{$user_dn}->{givenname}->[0],
		sn => $entry->{$user_dn}->{sn}->[0],
		title => defined $entry->{$user_dn}->{title} ? $entry->{$user_dn}->{title} : ['N/A'],
		o => $entry->{$user_dn}->{o},
		physicaldeliveryofficename => $entry->{$user_dn}->{physicaldeliveryofficename},
		telephonenumber => defined $entry->{$user_dn}->{telephonenumber} ?
		$entry->{$user_dn}->{telephonenumber} : ['N/A'],
		mail => defined $entry->{$user_dn}->{mail} ? $entry->{$user_dn}->{mail} : ['N/A'],
		roles => $entry->{$user_dn}->{$user_rdn[0]} eq $c->user ? \@{[$c->user->roles]} : 'a mere mortal',
	       };
      }
    } else {
      $o = $c->user->has_attribute('o') ?
	$c->user->o : 'N/A';
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
	      o => [ $o ],
	      physicaldeliveryofficename => $physicaldeliveryofficename,
	      telephonenumber => $telephonenumber,
	      roles => \@{[$c->user->roles]} || 'N/A',
	     };
      undef $o;
    }
    utf8::decode($arg->{givenname});
    utf8::decode($arg->{sn});
    # p $arg;
    #=================================================================
    # user organizations
    #
    if ( ref($arg->{o}) eq 'ARRAY' ) {
      foreach ( @{$arg->{o}} ) {
	push @{$o}, $_;
      }
    } else {
      push @{$o}, $arg->{o};
    }

    foreach ( @{$arg->{o}} ) {
      # here we need to fetch all org recursively to fill all data absent
      # if current object has no attribute needed (postOfficeBox or postalAddress or
      # any other, than we will use the one from it's ancestor
      $mesg = $ldap_crud->search( { base => $_, scope => 'base' } );
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
	  $fqdn->{$entries->{$_}->{physicaldeliveryofficename}->[0]} = defined $entries->{$_}->{associateddomain} ?
	    [ sort @{$entries->{$_}->{associateddomain}} ] : [];
	}
      }
    }
    # p $fqdn;
    #=================================================================
    # user jpegPhoto
    #
    $mesg = $ldap_crud->search( { base => defined $user_dn && $user_dn ne '' ?
				  $user_dn : $c->user->dn,
				  # sprintf('uid=%s,%s', , $ldap_crud->{cfg}->{base}->{acc_root}),
				  scope => 'base',
				  attrs => [ 'jpegPhoto' ], } );
    if ( $mesg->code ) {
      $return->{error} .= sprintf('<li>jpegPhoto %s</li>',
				  $ldap_crud->err($mesg)->{html});
    }
    $entry = $mesg->entry(0); my $tmppp = $entry->get_value('jpegPhoto');
    use MIME::Base64;
    my $jpegPhoto = sprintf(' src="data:image/jpg;base64,%s" alt="jpegPhoto of %s" title="%s"/>',
			    encode_base64($entry->get_value('jpegPhoto')),
			    $entry->dn,
			    $entry->dn );

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
				  sizelimit => 0,
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
			 sprintf( '<i title="%s" class="%s"></i>',
				  $ldap_crud->{cfg}->{hwType}->{$hwType_l}->{$hwType_r}->{descr},
				  $ldap_crud->{cfg}->{hwType}->{$hwType_l}->{$hwType_r}->{icon} ),
			 dn => $_,
			 inventoryNumber => defined $entries->{$_}->{inventorynumber} ? $entries->{$_}->{inventorynumber}->[0] : 'NA',
			 hwObj => $hwObj,
		       };
      # push @inventory, { dn => $_, hwType => $entries->{$_}->{hwtype}->[0] };
      # p @inventory;
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
    # p $c->action->list_extra_info;
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

=head2 test

page to test code snipets

=cut

sub test :Path(test) :Args(0) {
    my ( $self, $c ) = @_;
    my $ldap_crud = $c->model('LDAP_CRUD');

    my $svc;
    my $fqdn;

    ## DHCP
    # $svc = 'dhcp';
    # $fqdn = 'voyager.startrek.in';
    # filter => sprintf('(&(objectClass=dhcpSubnet)(dhcpOption=domain-name "%s"))', $fqdn),
    # attrs => [ 'cn', 'dhcpNetMask', 'dhcpRange' ],
    ## VPN
    # $svc = 'vpn';
    # $fqdn = 'talax.startrek.in';
    # filter => sprintf('(&(authorizedService=ovpn@%s)(cn=*))', $fqdn),
    # attrs => [ 'cn', 'umiOvpnCfgServer', 'umiOvpnCfgRoute' ],

#	       final_message => $ldap_crud->ipam({ svc => 'vpn', fqdn => 'talax.startrek.in', what => 'all', })
#	       testvar => $self->ipam_ip2dec('10.10.10.10')

    # $svc = 'ovpn';
    # $fqdn = 'talax.startrek.in';
    $svc = 'dhcp';
    $fqdn = 'voyager.startrek.in';

    my $iu = $ldap_crud->ipam_used({ svc => $svc,
				     fqdn => $fqdn,
				     base => $ldap_crud->{cfg}->{base}->{$svc},
				     # filter => sprintf('(&(authorizedService=ovpn@%s)(cn=*))', $fqdn),
				     # attrs => [ 'cn', 'umiOvpnCfgServer', 'umiOvpnCfgRoute' ],

				     filter => sprintf('(&(objectClass=dhcpSubnet)(dhcpOption=domain-name "%s"))', $fqdn),
				     attrs => [ 'cn', 'dhcpNetMask', 'dhcpRange' ],


				   });
    
    $c->stash( template => 'test.tt',
	       final_message => $ldap_crud->ipam_first_free({ ipspace => $iu->{ipspace},
	       						      ip_used => $iu->{ip_used},
							      # tgt_net => '10.146.5.0/24',
							      # req_msk => 30,
	       						    }),
	       # final_message => $iu,

	     );
}

=head2 end

Attempt to render a view, if needed.

=cut

sub end : ActionClass('RenderView') {
  my ( $self, $c ) = @_;

  my $size = 0;
  my $navbar_note;
  if ( defined $c->user ) {
    my $r;
    $r->{req} = $c->req->params;
    # $r->{stash} = $c->stash;
    my @a = split(/\//, UMI->config->{session}->{storage});
    my $b = join('/', $a[0],$a[1],$a[2]);
    use POSIX qw(strftime);
    my $now = strftime "%Y%m%d%H%M%S", localtime;
    p my $file = sprintf("%s/store-data_%s_%s_%s.perl-storable",
			 $b,
			 $c->user->uid,
			 $c->req->action eq '/' ? 'reinit' : $c->req->action,
			 $now);
    $c->stats->profile(begin => "store_data in the end");
    $self->store_data({ data => $r, file => $file, });

    use File::Find;
    find(sub { $size += -s if -f $_ }, $b);
    push @{$navbar_note}, { note => sprintf("session storage %.1f Mb", $size / 1024 / 1024),
			    color => $size > UMI->config->{session_storage_size} ? 'danger' : 'info',
			    icon => 'fa-trash-o' };
  }
  
  my @rep = $c->stats->report;
  my $stats = { debug => UMI->config->{debug}->{level},
		elapsed => $c->stats->elapsed,
		report => \@rep };
  $c->stash( stats => $stats,
	     navbar_note => $navbar_note );
  
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

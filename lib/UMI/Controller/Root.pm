#-*- mode: cperl; eval: (follow-mode); -*-
#


package UMI::Controller::Root;
use Moose;
use namespace::autoclean;
use Data::Printer colored => 0;
use JSON;
use Try::Tiny;
# use Net::LDAP;
use Net::LDAP qw( LDAP_COMPARE_FALSE LDAP_COMPARE_TRUE );

use Logger;

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
      # log_debug { np($c->user->attributes('ashash')) };
    } else {
      $c->stash( template => 'signin.tt', );
    }
  }

=head2 healthcheck

docker healthcheck

=cut

sub healthcheck :Path(healthcheck) :Args(0) {
  my ( $self, $c ) = @_;
  my ($ldap, $return, $res, $mesg);

  $res = '';
  $ldap = try {
    Net::LDAP->new( UMI->config->{authentication}->{realms}->{ldap}->{store}->{ldap_server}, version => 3 )
    } catch { $res = 'FAIL'; };

  if ( ! defined $ldap || $res eq 'FAIL' ) {
    $c->res->body( 'FAIL' );
    $c->res->status(500);
  } else {
    if ( defined UMI->config->{ldap_crud_cafile} &&
	 UMI->config->{ldap_crud_cafile} ne '' ) {
      $mesg = try {
	$ldap->start_tls( verify   => 'none',
			  cafile   => UMI->config->{ldap_crud_cafile},
			  checkcrl => 0, );
      }
      catch { $res = 'FAIL'; };
    }
    if ( $res eq 'FAIL' ) {
      $c->res->body( 'FAIL' );
      $c->res->status(500);
    } else {
      $mesg = $ldap->
	bind( UMI->config->{authentication}->{realms}->{ldap}->{store}->{binddn},
	      password => UMI->config->{authentication}->{realms}->{ldap}->{store}->{bindpw},
	      version  => 3, );
      if ( $mesg->is_error ) {
	$c->res->body( 'FAIL' );
	$c->res->status(500);
      } else {
	$mesg = $ldap->compare( UMI->config->{healthcheck_dn},
				attr  => UMI->config->{healthcheck_attr},
				value => UMI->config->{healthcheck_value} );
	if ( $mesg->code == LDAP_COMPARE_TRUE ) {
	  $c->res->body( 'OK' );
	  $c->res->status(200);
	} else {
	  $c->res->body( 'FAIL' );
	  $c->res->status(500);
	}
      }
    }
  }
  # log_debug { np ( $mesg->code ) };
}

sub about :Path(about) :Args(0) {
    my ( $self, $c ) = @_;
    $c->stash( template => 'about.tt',);
}

sub motto : Local {
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

sub sysinfo : Local {
  my ( $self, $c ) = @_;
  my $json = JSON->new->allow_nonref;
  
  my $sysinfo;
  my $x;
  my $y = $c->dump_these;
  my %z = %{$y->[1]};
  $x->{$y->[0]} = \%z;

  $x->{calculate_initial_session_expires} =
    $self->ts({ ts => $c->calculate_initial_session_expires, format => "%Y%m%d%H%M%S" });
  $x->{get_session_id}  =  $c->get_session_id;
  $x->{session_expires} = $self->ts({  ts => $c->session_expires, format => "%Y%m%d%H%M%S" });

  $x->{Session}->{auth_pwd} = '*****'
    if exists $x->{Session}->{auth_pwd};

  $x->{Session}->{auth_obj}->{userpassword} = '*****'
    if exists $x->{Session}->{auth_obj} && exists $x->{Session}->{auth_obj}->{userpassword};

  $x->{Session}->{__user}->{user}->{attributes}->{userpassword} = '*****'
    if ref($x->{Session}->{__user}) eq 'HASH' && exists $x->{Session}->{__user}->{user}->{attributes}->{userpassword};

  delete $x->{Session}->{__user}->{user}->{ldap_entry}
    if ref($x->{Session}->{__user}) eq 'HASH' && exists $x->{Session}->{__user}->{user}->{ldap_entry};

  my $return;
  my $ldap_crud = $c->model('LDAP_CRUD');
  my $mesg = $ldap_crud->search({ base => $ldap_crud->{cfg}->{base}->{monitor},
				  scope => 'sub',
				  sizelimit => 0,
				  attrs   => [ '*', '+', ],
				  filter => '(objectClass=*)', });
  push @{$return->{error}}, $ldap_crud->err($mesg)->{html}
    if $mesg->error;
  my $monitor = $mesg->as_struct;

  my $syntaxes;
  my $sch = $ldap_crud->schema;
  foreach my $syn (@{[$sch->all_syntaxes]}) {
    foreach (sort (keys (%{$syn}))) {
      next if $_ eq 'oid';
      $syntaxes->{$syn->{oid}}->{$_} = $syn->{$_};
    }
  }
  my %synsort = map { $_ => $syntaxes->{$_} } sort( keys( %{$syntaxes}));

  $sysinfo = { 'UMI session'    => { title => 'Session',
				     data  => $x, },
	       'LDAP_CRUD->cfg' => { title => 'LDAP_CRUD configuration ( internal UMI $c->model(LDAP_CRUD)->cfg )',
				     data  => $c->model('LDAP_CRUD')->cfg, },
	      'LDAP monitor'    => { title => 'OpenLDAP daemon monitor',
				     data  => $monitor, },
	      'LDAP syntaxes'   => { title => 'LDAP syntaxes',
				     data  => \%synsort, },
	     };

  $c->stash( template      => 'sysinfo.tt',
	     sysinfo       => to_json ( $sysinfo, {utf8 => 1, pretty => 1, allow_blessed => 1,} ),
	     final_message => $return, );
}

=head2 stat_acc

each root account, all services listing

no way to shorten the list to some specific service, yet

=cut

sub stat_acc : Local {
  my ( $self, $c ) = @_;

  if ( $c->user_exists() ) {
    my $ldap_crud = $c->model('LDAP_CRUD');
    my ( $return, $acc, $root_dn, $rest, @dn_arr, $re_dn, $re_svc, $entry, $gr_block, $l, $r, $rdn, $to_utf );

    my $mesg = $ldap_crud->search({ base   => sprintf('cn=%s,%s',
						      $ldap_crud->cfg->{stub}->{group_blocked},
						      $ldap_crud->{cfg}->{base}->{group}),
				    filter => '(objectClass=*)',
				    attrs  => [ 'memberUid' ], });
    if ( $mesg->code ) {
      push @{$return->{error}}, $ldap_crud->err($mesg)->{html};
    } else {
      $entry = $mesg->entry(0);
      $gr_block->{$_} = 1 foreach ( @{$entry->get_value('memberuid', asref => 1)} );
    }

    $mesg = $ldap_crud->search({ base      => $ldap_crud->{cfg}->{base}->{acc_root},
				 scope     => 'sub',
				 sizelimit => 0,
				 # attrs     => [ qw( authorizedService
				 # 		    cn
				 # 		    gidNumber
				 # 		    givenName
				 # 		    mail
				 # 		    sn
				 # 		    uid ) ],
				 filter    => '(objectClass=*)', });
    if ( $mesg->code ) {
      push @{$return->{error}}, $ldap_crud->err($mesg)->{html};
    } else {
      $entry = $mesg->as_struct;
      $re_dn  = sprintf("^%s=.*,%s\$",
			lc($ldap_crud->{cfg}->{rdn}->{acc_root}),
			lc($ldap_crud->{cfg}->{base}->{acc_root}) );
      $re_svc = sprintf("^.*,authorizedservice=.*,%s=.*,%s\$",
			lc($ldap_crud->{cfg}->{rdn}->{acc_root}),
			lc($ldap_crud->{cfg}->{base}->{acc_root}) );
      while (my ($key, $val) = each %{$entry} ) {
	next if $key =~ /^authorized.*/;
	if ( lc($key) =~ /$re_dn/ && lc($key) !~ /$re_svc/) {
	  utf8::decode($val->{givenname}->[0]);
	  $acc->{$key}->{givenName}         = $val->{givenname}->[0];
	  utf8::decode($val->{sn}->[0]);
	  $acc->{$key}->{mail}              = exists $val->{mail} ? $val->{mail}->[0] : 'NA';
	  $acc->{$key}->{sn}                = $val->{sn}->[0];
	  $acc->{$key}->{sshkey}            = exists $val->{graypublickey} ? 1 : 0;
	  $acc->{$key}->{uid}               = $val->{uid}->[0];
	  $acc->{$key}->{authorizedService} = {};
	  $acc->{$key}->{blocked}           = exists $gr_block->{$val->{uid}->[0]} ||
	    $val->{gidnumber}->[0] == $ldap_crud->{cfg}->{stub}->{group_blocked_gid} ? 1 : 0;
	  log_debug { "\n$key\n" . '######## ' . $val->{gidnumber}->[0] . ' ######### ' . $ldap_crud->{cfg}->{stub}->{group_blocked_gid} . "\n" };
	} elsif ( lc($key) =~ /$re_svc/ ) {
	  @dn_arr = split(/,/, $key);
	  shift @dn_arr;
	  shift @dn_arr;
	  $root_dn = join ',', @dn_arr;
	  ( $l, $r) = split /\@/, $val->{authorizedservice}->[0];
	  $rdn = exists $ldap_crud->{cfg}->{rdn}->{"$l"} ? $ldap_crud->{cfg}->{rdn}->{"$l"} : $ldap_crud->{cfg}->{rdn}->{acc_svc_common};
	  # log_debug { np($key) };
	  # log_debug { np($val) };
	  # log_debug { np($val->{ $ldap_crud->{cfg}->{rdn}->{"$l"} }->[0]) };
	  push @{$acc->{$root_dn}->{authorizedService}->{"$l"}->{$r}},
	     { $rdn => $val->{$rdn}->[0] };
	}
      }
    }
     log_debug { np($acc) };
    # log_debug { np($return) };
    $c->stash( template      => 'stat_acc.tt',
    	       accounts      => $acc,
    	       final_message => $return,);
  } else {
    $c->stash( template => 'signin.tt', );
  }


}


=head2 stat_monitor

method to provide information about the running status of the slapd(8) daemon

for now it is used in sysinfo()

=cut

sub stat_monitor : Local {
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
	  { monitorConnectionNumber       => $_->get_value('monitorConnectionNumber')       // 'NA',
	    monitorConnectionProtocol     => $_->get_value('monitorConnectionProtocol')     // 'NA',
	    monitorConnectionOpsReceived  => $_->get_value('monitorConnectionOpsReceived')  // 'NA',
	    monitorConnectionOpsExecuting => $_->get_value('monitorConnectionOpsExecuting') // 'NA',
	    monitorConnectionOpsPending   => $_->get_value('monitorConnectionOpsPending')   // 'NA',
	    monitorConnectionOpsCompleted => $_->get_value('monitorConnectionOpsCompleted') // 'NA',
	    monitorConnectionGet          => $_->get_value('monitorConnectionGet')          // 'NA',
	    monitorConnectionRead         => $_->get_value('monitorConnectionRead')         // 'NA',
	    monitorConnectionWrite        => $_->get_value('monitorConnectionWrite')        // 'NA',
	    monitorConnectionMask         => $_->get_value('monitorConnectionMask')         // 'NA',
	    monitorConnectionAuthzDN      => $_->get_value('monitorConnectionAuthzDN')      // 'NA',
	    monitorConnectionListener     => $_->get_value('monitorConnectionListener')     // 'NA',
	    monitorConnectionPeerDomain   => $_->get_value('monitorConnectionPeerDomain')   // 'NA',
	    monitorConnectionPeerAddress  => $_->get_value('monitorConnectionPeerAddress')  // 'NA',
	    monitorConnectionLocalAddress => $_->get_value('monitorConnectionLocalAddress') // 'NA',
	    entryDN                       => $_->get_value('entryDN')                       // 'NA',
	  };
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

sub download_from_ldap : Local {
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

    my ( $arg, $mesg, $uid, $return, $entry, $entries, $orgs, $domains, $fqdn, $o,
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
	# log_debug { np($entry) };
	my $ttmmpp = eval '$entry->{$user_dn}->' . $ldap_crud->{cfg}->{rdn}->{acc_root};
	# log_debug { np( $ttmmpp ) };
	# log_debug { np($c->user->$ldap_crud->{cfg}->{rdn}->{acc_root}) };
	$arg = {
		dn                         => $user_dn,
		uid                        => $entry->{$user_dn}->{uid}->[0],
		givenname                  => $entry->{$user_dn}->{givenname}->[0],
		mail                       => $entry->{$user_dn}->{mail} // [],
		sn                         => $entry->{$user_dn}->{sn}->[0],
		title                      => $entry->{$user_dn}->{title} // ['N/A'],
		o                          => $entry->{$user_dn}->{o},
		physicaldeliveryofficename => $entry->{$user_dn}->{physicaldeliveryofficename},
		telephonenumber            => $entry->{$user_dn}->{telephonenumber} // ['N/A'],
		# roles => [ $c->user->roles ],
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

      $arg = {
	      uid                        => $c->user->uid,
	      givenname                  => $c->user->givenname || 'N/A',
	      sn                         => $c->user->sn || 'N/A',
	      title                      => $title,
	      mail                       => $c->user->has_attribute('mail') ? [ $c->user->mail ] : [ 'N/A' ],
	      o                          => [ $o ],
	      physicaldeliveryofficename => $physicaldeliveryofficename,
	      telephonenumber            => [ $telephonenumber ],
	      # roles => \@{[$c->user->roles]} || 'N/A',
	     };
      undef $o;
    }

    $mesg = $ldap_crud->search({ base   => $ldap_crud->cfg->{base}->{system_group},
				 filter => '(memberUid=' . $arg->{uid} . ')',
				 attrs  => [ 'cn' ], });
    if ( $mesg->code ) {
      $return->{error} .= sprintf('<li>personal info %s</li>',
 				  $ldap_crud->err($mesg)->{html});
    } else {
      if ( $mesg->count > 0 ) {
	push @{$arg->{roles}}, $_->get_value('cn')
	  foreach ( @{[$mesg->entries]});
      }
      else {
	$arg->{roles} = [ 'N/A' ];
      }
    }

    # log_debug { np(@{[$c->user->roles]}) };
    # log_debug { np($arg) };
    utf8::decode($arg->{givenname});
    utf8::decode($arg->{sn});
    # p $arg;
    #=================================================================
    # user groups
    #
    my $groups;
    $mesg = $ldap_crud->search({ base   => $ldap_crud->cfg->{base}->{group},
				 filter => '(memberUid=' . $arg->{uid} . ')',
				 attrs  => [ 'cn' ], });
    if ( $mesg->code ) {
      $return->{error} .= sprintf('<li>personal info %s</li>',
 				  $ldap_crud->err($mesg)->{html});
    } else {
      foreach ( @{[$mesg->entries]} ) {
	push @{$groups->{group}}, $_->get_value('cn');
      }
    }

    $mesg = $ldap_crud->search({ base   => $ldap_crud->cfg->{base}->{netgroup},
				 filter => '(nisNetgroupTriple=*,' . $arg->{uid} . ',*)',
				 attrs  => [ 'cn' ], });
    if ( $mesg->code ) {
      $return->{error} .= sprintf('<li>personal info %s</li>',
 				  $ldap_crud->err($mesg)->{html});
    } else {
      foreach ( @{[$mesg->entries]} ) {
	push @{$groups->{netgroup}}, $_->get_value('cn');
      }
    }

    #=================================================================
    # user ssh
    #
    my $ssh;
    $mesg = $ldap_crud->search({ base   => $ldap_crud->cfg->{base}->{acc_root},
				 filter => '(uid=' . $arg->{uid} . ')',
				 attrs  => [ 'grayPublicKey' ], });
    if ( $mesg->code ) {
      $return->{error} .= sprintf('<li>ssh keys: %s</li>',
 				  $ldap_crud->err($mesg)->{html});
    } else {
      my $entry_ssh = $mesg->as_struct;
      $ssh = $entry_ssh->{'uid=' . $arg->{uid} . ',' . $ldap_crud->cfg->{base}->{acc_root}}->{graypublickey};
    }
    
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
		    $entries->{$_}->{street}->[0],
		    $entries->{$_}->{postaladdress}->[0],
		    $entries->{$_}->{l}->[0]
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
    # log_debug{ np($entries) };
    foreach (keys (%{$entries})) {
      @x = split(',', $_);
      splice @x, 0, 2;
      $mesg = $ldap_crud->search( { base => join(',', @x),
				    scope => 'base',
				    attrs => [ 'dhcpStatements' ], } );
      if ( $mesg->code ) { $return->{error} .= sprintf('<li>DHCP domain-name/s %s</li>',
						       $ldap_crud->err($mesg)->{html}); }


      
      foreach ( @{[$mesg->entry(0)->get_value('dhcpStatements')]} ) {
	$domain_name = substr((split(' ', $_))[1],1,-2) if $_ =~ /ddns-domainname /;
      }

      push @{$dhcp}, {
		      dn =>   $_,
		      cn =>   $entries->{$_}->{cn}->[0],
		      fqdn => $domain_name,
		      ip =>   (split(' ', $entries->{$_}->{dhcpstatements}->[0]))[1],
		      mac =>  (split(' ', $entries->{$_}->{dhcphwaddress}->[0]))[1],
		      desc => $entries->{$_}->{dhcpcomments}->[0],
		     };
    }

    #=================================================================
    # user services
    #
    # log_debug { np($arg) };

    my ( $svc_entry, $service, $service_details );
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
    foreach $svc_entry (@{[$mesg->sorted( 'authorizedService' )]}) {
      $mesg = $ldap_crud->search( { base => $svc_entry->dn,
				    scope => 'children', });
      if ( $mesg->code ) {
	$return->{error} .= sprintf('<li>each service children %s</li>',
				    $ldap_crud->err($mesg)->{html});
      }
      next if ! $mesg->count;
      $service_details = {
			  branch_dn => $svc_entry->dn,
			  authorizedService => $svc_entry->get_value('authorizedService'),
			  auth => $ldap_crud->cfg->{authorizedService}
			  ->{(split('@', $svc_entry->get_value('authorizedService')))[0]}->{auth},
			  icon => $ldap_crud->cfg->{authorizedService}
			  ->{(split('@', $svc_entry->get_value('authorizedService')))[0]}->{icon},
			  descr => $ldap_crud->cfg->{authorizedService}
			  ->{(split('@', $svc_entry->get_value('authorizedService')))[0]}->{descr},
			 };

      foreach (@{[$mesg->sorted( 'authorizedService' )]}) {
	$service_details->{leaf}->{$_->dn} = $_->get_value('uid') // $_->get_value('cn');

	if ( (split('@', $service_details->{authorizedService}))[0] eq 'ovpn' ) {
	  $service_details->{cert}->{$_->dn} =
	    $self->cert_info({ cert => $_->get_value('userCertificate;binary') });
	  $service_details->{cert}->{$_->dn}->{'ifconfig-push'} = $_->get_value('umiOvpnCfgIfconfigPush');
	  $service_details->{cert}->{$_->dn}->{'OS'}            = $_->get_value('umiOvpnAddDevOS');
	  $service_details->{cert}->{$_->dn}->{'device'}        = $_->get_value('umiOvpnAddDevType');
	  $service_details->{cert}->{$_->dn}->{'status'}        = $_->get_value('umiOvpnAddStatus');
	} elsif ( $service_details->{authorizedService} =~ /^mail\@/ ) {
	  push @{$arg->{mail}}, $_->get_value('uid');
	} elsif ( $service_details->{authorizedService} =~ /^dot1x.*\@/ ) {
	  $service_details->{cert}->{$_->dn} = $self->cert_info({ cert => $_->get_value('userCertificate;binary') })
	    if $service_details->{authorizedService} =~ /^dot1x-eap-tls\@/;

	  my $rgrp = $ldap_crud->search( { base => $ldap_crud->cfg->{base}->{rad_groups},
					   sizelimit => 0,
					   filter => sprintf("member=%s", $_->dn),
					   attrs => [ 'cn'], } );
	  $return->{error} .= sprintf('<li>%s rad group/s %s</li>',
				      $ldap_crud->cfg->{base}->{rad_groups},
				      $ldap_crud->err($rgrp)->{html})
	    if $rgrp->code;
	  
	  if ( $rgrp->count ) {
	    my $rgrps = $rgrp->as_struct;
	    # log_debug { np($rgrps) };
	    foreach my $rg (keys (%{$rgrps})) {
	      # log_debug { np($rgrps->{$rg}) };
	      $service_details->{rad_grp}->{$_->dn} .= 'RAD grp: ' . $rgrps->{$rg}->{cn}->[0] . '; ';
	    }
	  } else {
	    $return->{warning} .= '<li>no rad group found</li>';
	  }
	  
	} elsif ( (split('@', $service_details->{authorizedService}))[0] eq 'ssh-acc' ) {
	  @{$service_details->{sshkey}->{$_->dn}} = $_->get_value('sshPublicKey');
	}
      }
      push @{$service}, $service_details;
      undef $service_details;
    }

    #=================================================================
    # user PGP stuff
    #
    my ( $pgp, $pgp_mail );
    foreach $pgp_mail ( @{$arg->{mail}} ) {
      my $pgp_filter = sprintf("|(pgpUserID=*%s*)(pgpUserID=*%s*)(pgpUserID=*%s*)",
			       $arg->{givenname},
			       $arg->{sn},
			       $pgp_mail);
      # log_debug { np($pgp_filter) };
      $mesg = $ldap_crud->search( { base => $ldap_crud->cfg->{base}->{pgp},
				    filter => $pgp_filter,				} );
      if ( $mesg->code ) {
	$return->{error} .= sprintf('<li>PGP %s</li>',
				    $ldap_crud->err($mesg)->{html}); }
      $entries = $mesg->as_struct;
      # log_debug { np($entries) };
      foreach (keys (%{$entries})) {
	push @{$pgp}, {
		       keyid  => $entries->{$_}->{pgpkeyid}->[0],
		       userid => $entries->{$_}->{pgpuserid},
		       key    => $entries->{$_}->{pgpkey}->[0],
		      };
      }
    }
    log_debug{ np($pgp) };

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
    $c->stash( template      => 'user/user_preferences_neo.tt',
	       auth_obj      => $arg,
	       dhcp          => $dhcp,
	       pgp           => $pgp,
	       fqdn          => $fqdn,
	       groups        => $groups,
	       inventory     => \@inventory,
	       jpegPhoto     => $jpegPhoto,
	       orgs          => $orgs,
	       ssh           => $ssh,
	       service       => $service,
	       session       => $c->session,
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

=head2 settings

save settings

=cut

sub settings_save :Path(settings_save) :Args(0) POST {
  my ( $self, $c ) = @_;

  my $params = $c->req->parameters;
  log_debug { np($params) };

  my $ldap_crud = $c->model('LDAP_CRUD');
  my $replace;

  if ( ! exists $c->session->{settings}->{ui}->{debug} ) {
    log_debug { np($c->session->{settings}->{ui}->{debug}) };
    $c->session->{settings}->{ui} = $ldap_crud->{cfg}->{ui};
    push @{$replace}, add => [ objectClass => 'umiSettings' ];
  }
  log_debug { np($c->session->{settings}->{ui}) };
  # foreach (keys ( %{$c->session->{settings}->{ui}} )) {
  foreach (keys ( %{$ldap_crud->{cfg}->{ui}} )) {
    # log_debug { np($_) };
    if ( $_ eq 'debug' ) {
      $c->session->{settings}->{ui}->{$_} = $params->{$_} // 0;
    } else {
      $c->session->{settings}->{ui}->{$_} = defined $params->{$_} ? 1 : 0;
    }
  }
  # log_debug { np($c->session->{settings}) };

  use JSON;
  my $json = JSON->new->allow_nonref;
  my $json_text   = $json->encode( $c->session->{settings} );
  log_debug { np($json_text) };
  # log_debug { np($c->user->dn) };

  ###
  ### TO BE FINISHED, slapd.conf ACLs need to be adopted
  ### self is unable to write but read ... ???
  ###
  
  push @{$replace},  replace => [ umiSettingsJson => $json_text, ];

  log_debug { np($replace) };

  my $return;
  my $mesg = $ldap_crud->modify( $c->user->dn, $replace );
  if ( $mesg ) {
    $return->{error} .= $mesg->{html};
    log_debug { np($mesg) };
    $c->response->status(401);
  } else {
    $c->response->status(200);
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

  if ( defined $c->session->{"auth_uid"}
       && defined $c->session->{"auth_pwd"}
       # && $c->authenticate({
       # 			 id       => $c->session->{"auth_uid"},
       # 			 password => $c->session->{"auth_pwd"},
       # 			})
     ) {
    $c->stash( template => 'welcome.tt', );
  } else {
    # p $c->error;
    $c->logout();
    $c->delete_session('Forcing SignOut due to some error ... (for forms, one of the reasons is lack of class formajaxer or action set)');
    # $c->response->redirect($c->uri_for('/'));

    $c->stash( template => 'signin.tt', );
  }
}

sub resolve_this : Local {
  my ( $self, $c ) = @_;
  my $params = $c->request->params;
  my $arg = {
	     query                => { A   => $params->{a}   // '',
				       PTR => $params->{ptr} // '',
				       MX  => $params->{mx}  // '', },
	     content_type         => 'text/plain',
	     content_type_charset => 'utf-8',
	    };

  my $res;
  while ( my($k, $v) = each %{$arg->{query}} ) {
    next if $v eq '';
    $res = ref($v) eq 'ARRAY' ? $v : [ $v ];

    push @{$arg->{reply}}, $self->dns_resolver({ type  => $k,
						 debug => $c->session->{settings}->{ui}->{ipamdns},
						 name  => $_ })
      foreach (@{$res});
  }

  foreach (@{$arg->{reply}}) {
    push @{$arg->{body}}, $_->{success}         if exists $_->{success};
    push @{$arg->{body}}, $_->{error}->{errstr} if exists $_->{error};
  }

  # log_debug { np( $c->session->{settings}->{ui}->{ipamdns} ) };

  $c->response->body(join("\n", @{$arg->{body}}));
  $c->response->headers->content_type($arg->{content_type});
  $c->response->headers->content_type_charset($arg->{content_type_charset});
}


=head2 test

page to test code snipets

=cut

sub test : Local {
  my ( $self, $c ) = @_;
  my $ldap_crud = $c->model('LDAP_CRUD');
  my $return;

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

    $svc = 'ovpn';
    $fqdn = '*';
    # $fqdn = 'talax.startrek.in';
    # $svc = 'dhcp';
    # $fqdn = '*';

    # my $iu = $ldap_crud->ipam_used({ svc => $svc,
    # 				     fqdn => $fqdn,
    # 				     base => $ldap_crud->{cfg}->{base}->{acc_root},
    # 				     filter => '(&(objectClass=umiOvpnCfg)(cn=*))',
    # 				     attrs => [ 'cn', 'umiOvpnCfgServer', 'umiOvpnCfgRoute' ],

    # 				     # filter => sprintf('(&(objectClass=dhcpSubnet)(dhcpOption=domain-name "%s"))', $fqdn),
    # 				     # attrs => [ 'cn', 'dhcpNetMask', 'dhcpRange' ],


    # 				   });

  my $ipa = $ldap_crud->ipa;
  
  # log_debug { np( $ipa ) };

    # $c->stash( template => 'test.tt',
    # 	       final_message => $ldap_crud->ipam_first_free({ ipspace => $iu->{ipspace},
    # 	       						      ip_used => $iu->{ip_used},
    # 	       						      # tgt_net => '10.146.5.0/24',
    # 	       						      # req_msk => 30,
    # 	       						    }),
    # 	       final_message => $iu,

    # 	     );


  # use Net::CIDR::Set;

  # my $ipa = Net::CIDR::Set->new;

  # # log_debug { np( $mesg ) };

  # my $dhcp_addresses = $ldap_crud->search({ base   => $ldap_crud->cfg->{base}->{dhcp},
  # 					    filter => '(dhcpStatements=fixed-address *)', });
  
  # foreach my $entry (@{[$dhcp_addresses->entries]}) {
  #   foreach my $val (@{[$entry->get_value('dhcpStatements')]}) {
  #     $ipa->add( (split(/ /, $val))[1] )
  # 	if $val =~ /^fixed-address /;
  #   }
  # }

  # log_debug { $ldap_crud->cfg->{base}->{db} };

  # ---------------------------------------------------------------------

  ### --- NOTOFICATION TEST ---
  # $return = { success => q{Lorem ipsum dolor sit amet.},
  # 	        error   => q{Neque porro quisquam est qui dolorem ipsum quia dolor sit amet},
  # 	        warning => q{consectetur, adipisci velit.}, };
  ### --- NOTOFICATION TEST ---

  $c->stash( template      => q{test.tt},
  	     final_message => $return,
	     ipa           => $ipa, # $iu,
  	     # ipa           => [$ipa->as_address_array],
  	   );

}

=head2 end

Attempt to render a view, if needed.

=cut

sub end : ActionClass('RenderView') {
  my ( $self, $c ) = @_;

  my $size = 0;
  my $navbar_note;
  if ( defined $c->user &&
       exists $c->session->{settings}->{ui}->{storedata} &&
       $c->session->{settings}->{ui}->{storedata} == 1 ) {
    my $r;
    $r->{req} = $c->req->params;
    # $r->{stash} = $c->stash;
    my @a = split(/\//, UMI->config->{session}->{storage});
    # !!! HARDCODE ... need to be rewritten
    my $b = join('/', $a[0],$a[1],$a[2]);
    use POSIX qw(strftime);
    my $now = strftime "%Y%m%d%H%M%S", localtime;
    my $action = $c->req->action;
    
    $action =~ s|/|_|g;
    my $file = sprintf("%s/store-data_%s_%s_%s.perl-storable",
			 $b,
			 $c->user->uid,
			 $action,
			 $now);
    $self->store_data({ data => $r, file => $file, });

    $c->stats->profile("store_data() in end()");

    # EJDU # use File::Find;
    # EJDU # find(sub { $size += -s if -f $_ }, $b);
    # EJDU # push @{$navbar_note}, { note => sprintf("session storage %.1f Mb", $size / 1024 / 1024),
    # EJDU # 			    color => $size > UMI->config->{session_storage_size} ? 'danger' : 'info',
    # EJDU # 			    icon => 'fa-trash' };
  }


  my @rep = $c->stats->report;
  my $stats = { debug   => $c->session->{settings}->{ui}->{debug} // UMI->config->{debug}->{level},
		elapsed => $c->stats->elapsed,
		report  => \@rep };

  # log_debug { np($stats) };
  $c->stash( stats   => $stats,
	     is_ajax => defined $c->request->headers->header('X-Requested-With') &&
	     lc( $c->request->headers->header('X-Requested-With') ) eq lc( 'XMLHttpRequest' ) ? 1 : 0,
	     # EJDU # navbar_note => $navbar_note );
	     navbar_note => undef );

}

=head1 AUTHOR

Zeus Panchenko

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;

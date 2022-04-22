# -*- mode: cperl; mode: follow; -*-
#

package LDAP_CRUD;

use Moose;
use namespace::autoclean;

use Data::Printer colored => 0, caller_info => 0;
use Time::Piece;
use POSIX qw(strftime);
use MIME::Base64;
use MIME::QuotedPrint;
use List::MoreUtils ':all';
use Net::CIDR::Set;

BEGIN { with 'Tools'; }

use Noder;
use Logger;

use utf8;
use Net::LDAP;
use Net::LDAP::LDIF;
use Net::LDAP::Control;
use Net::LDAP::Control::Sort;
use Net::LDAP::Control::SortResult;
use Net::LDAP::Extension::Refresh;
use Net::LDAP::Constant qw(
			    LDAP_SUCCESS
			    LDAP_PROTOCOL_ERROR
			    LDAP_NO_SUCH_OBJECT
			    LDAP_INVALID_DN_SYNTAX
			    LDAP_INSUFFICIENT_ACCESS
			    LDAP_CONTROL_SORTRESULT
			 );
use Net::LDAP::Util qw(
			ldap_error_text
			ldap_error_name
			ldap_error_desc
			ldap_explode_dn
			escape_filter_value
			canonical_dn
			generalizedTime_to_time
			time_to_generalizedTime
		     );

use Try::Tiny;

=head1 NAME

LDAP_CRUD - base class for LDAP related actions

=head1 SYNOPSIS

=head1 DESCRIPTION

LDAP Create, Read, Update and Delete actions

=head1 METHODS and FUNCTIONS

=head2 cfg

Method to store configuration of objects to be processed

I<services are described by hash like this:>

authorizedService => {

       # whether login/password needed or not
       auth => 1 or 0,
       descr => 'Description seen in form select',

       # to process or to not to process this service
       disabled => 1 or 0,

       # some predefined gidNumber
       gidNumber => 10106,
       jpegPhoto_noavatar => UMI->path_to('path', 'to', '/image.jpg'),
       icon => 'fa fa-lightbulb-o',

       # must-contain fields for this service
       data_fields => 'login,password1,password2',

       # element wrapper class, presence of which is
       # applying umi-user-all.js to the element
       data_relation => 'passw',

       # domains which demands prefix (one more level domain) like
       # service dedicated hosts
       associateddomain_prefix =>
           { 'talax.startrek.in' => 'im.', },

       # automatically added for some services
       login_prefix => 'rad-',

},

=cut


has 'cfg' => ( traits => ['Hash'], is => 'ro', isa => 'HashRef', builder => '_build_cfg', );

sub _build_cfg {
  my $self = shift;

  # number of Domain Components for the DB
  my @dc_count = ( UMI->config->{ldap_crud_db} =~ /dc=/g);

  return {
	  base => {
		   db             => UMI->config->{ldap_crud_db},
		   db_log         => UMI->config->{ldap_crud_db_log},
		   dc_num         => $#dc_count + 1,
		   acc_root       => 'ou=People,'              . UMI->config->{ldap_crud_db},
		   acc_svc_branch => 'ou=People,'              . UMI->config->{ldap_crud_db},
		   acc_svc_common => 'ou=People,'              . UMI->config->{ldap_crud_db},
		   alias          => 'ou=alias,'               . UMI->config->{ldap_crud_db},
		   dhcp           => 'ou=DHCP,'                . UMI->config->{ldap_crud_db},
		   gitacl         => 'ou=GitACL,'              . UMI->config->{ldap_crud_db},
		   group          => 'ou=group,'               . UMI->config->{ldap_crud_db},
		   inventory      => 'ou=hw,ou=Inventory,'     . UMI->config->{ldap_crud_db},
		   machines       => 'ou=machines,'            . UMI->config->{ldap_crud_db},
		   mta            => 'ou=Sendmail,'            . UMI->config->{ldap_crud_db},
		   netgroup       => 'ou=Netgroups,'           . UMI->config->{ldap_crud_db},
		   org            => 'ou=Organizations,'       . UMI->config->{ldap_crud_db},
		   ovpn           => 'ou=OpenVPN,'             . UMI->config->{ldap_crud_db},
		   pgp            => 'ou=Keys,ou=PGP,'         . UMI->config->{ldap_crud_db},
		   rad_groups     => 'ou=groups,ou=RADIUS,'    . UMI->config->{ldap_crud_db},
		   rad_profiles   => 'ou=profiles,ou=RADIUS,'  . UMI->config->{ldap_crud_db},
		   sargon         => 'ou=sargon,'              . UMI->config->{ldap_crud_db},
		   sudo           => 'ou=SUDOers,'             . UMI->config->{ldap_crud_db},
		   system_bind    => 'ou=bind,ou=system,'      . UMI->config->{ldap_crud_db},
		   system_group   => 'ou=group,ou=system,'     . UMI->config->{ldap_crud_db},
		   workstations   => 'ou=workstations,'        . UMI->config->{ldap_crud_db},
		   monitor        => 'cn=Monitor',
		   objects        => [ qw( acc_root
					   alias
					   dhcp
					   gitacl
					   group
					   inventory
					   machines
					   monitor
					   mta
					   netgroup
					   org
					   ovpn
					   rad_groups
					   rad_profiles
					   sudo
					   workstations	) ],
		   icon => {
			     DHCP          => 'fas fa-network-wired',
			     GitACL        => 'fab fa-git-square',
			     OpenVPN       => 'fas fa-sitemap',
			     Organizations => 'fas fa-industry',
			     People        => 'fas fa-address-card',
			     default       => 'fas fa-star',
			     group         => 'fas fa-users',
			     history       => 'fas fa-history',
			     inventory     => 'fas fa-tag',
			     mta           => 'fas fa-envelope',
			     netgroup      => 'fas fa-user-friends',
			     pgp           => 'fas fa-key',
			     rad_groups    => 'fas fa-users',
			     rad_profiles  => 'fas fa-cogs',
			   }, },
	  exclude_prefix => 'aux_',
	  sizelimit      => 50,
	  defaults       => { ldap => {
				       attrs               => [ '*' ],
				       deref               => 'never',
				       filter              => '(objectClass=*)',
				       gidNumber_start     => 10000,
				       is_single           => {
							       authorizedService => 1,
							       cn                => 1,
							       givenName         => 1,
							       # objectClass       => 1,
							       sn                => 1,
							       uid               => 1,
							      },
				       scope               => 'sub',
				       sizelimit           => 150,
				       typesonly           => 0,
				       uidNumber_ssh_start => 20100,
				       uidNumber_start     => 10000,
				      },
			      notAvailable => 'NA', },
	  ui => { debug     => 0,
		  aside     => 0,
		  sidebar   => 0,
		  isblock   => 1,
		  ipamdns   => 0,
		  storedata => 0,
		},
	  translit    => "GOST 7.79 RUS",
	  translit_no => {
			  description       => 1,
			  givenName         => 1,
			  l                 => 1,
			  postalAddress     => 1,
			  registeredAddress => 1,
			  sn                => 1,
			  st                => 1,
			  street            => 1,
			  title             => 1,
			 },
	  
	  #=====================================================================
	  ##
	  ### CONFIGURATION STARTS HERE (something you could want to change.
	  ### *all other stuff can be changed ONLY if you understand all consequences*
	  ##
	  #=====================================================================

	  stub => {
		   core_mta          => 'relay.umi',
		   gidNumber         => UMI->config->{default}->{gidNumber},
		   group             => UMI->config->{default}->{group},
		   group_blocked     => 'blocked',
		   group_blocked_gid => 20001,
		   homeDirectory     => '/usr/local/home',
		   icon              => 'fas fa-user-circle',
		   icon_error        => 'fas fa-exclamation-circle',
		   icon_success      => 'fas fa-check-circle',
		   icon_warning      => 'fas fa-exclamation-triangle',
		   loginShell        => '/usr/bin/false',
		   noavatar_mgmnt    => UMI->path_to('root', 'static', 'images', '/avatar-mgmnt.png'),
		  },
	  rdn => {
		  acc_root        => UMI->config->{authentication}->{realms}->{ldap}->{store}->{user_field},
		  acc_svc_branch  => 'authorizedService',
		  acc_svc_common  => 'uid',
		  gitacl          => 'cn',
		  group           => 'cn',
		  org             => 'ou',
		  ovpn            => 'cn',
		 },
	  objectClass =>
	  {
	   acc_root              => [ qw(
					  grayAccount
					  inetLocalMailRecipient
					  inetOrgPerson
					  organizationalPerson
					  person
					  posixAccount
					  top
				       ) ], # umiSettings
	   acc_svc_branch        => [ qw(
					  account
					  domainRelatedObject
					  authorizedServiceObject
				       ) ],
	   acc_svc_dot1x         => [ qw(
					  account
					  authorizedServiceObject
					  domainRelatedObject
					  radiusprofile
					  simpleSecurityObject
				       ) ],
	   acc_svc_dot1x_eap_tls => [ qw(
					  account
					  authorizedServiceObject
					  domainRelatedObject
					  pkiUser
					  radiusprofile
					  simpleSecurityObject
					  umiUserCertificate
				       ) ],
	   acc_svc_common        => [ qw(
					  authorizedServiceObject
					  domainRelatedObject
					  inetOrgPerson
					  posixAccount
					  shadowAccount
				       ) ],
	   acc_svc_email         => [ qw(
					  mailutilsAccount
				       ) ],
	   acc_svc_web           => [ qw(
					  account
					  authorizedServiceObject
					  domainRelatedObject
					  simpleSecurityObject
					  uidObject
				       ) ],
	   acc_svc_gitlab        => [ qw(
					  applicationProcess
					  authorizedServiceObject
					  domainRelatedObject
					  inetLocalMailRecipient
					  simpleSecurityObject
					  uidObject
				       ) ],
	   acc_svc_ssh           => [ qw(
					  ldapPublicKey
				       ) ],
	   gitacl                => [ qw(
					  gitACL
					  top
				       ) ],
	   group                 => [ qw(
					  posixGroup
					  top
				       ) ],
	   dhcp                  => [ qw(
					  dhcpHost
					  top
					  uidObject
				       ) ],
	   netgroup              => [ qw(
					  domainRelatedObject
					  nisNetgroup
				       ) ],
	   ovpn                  => [ qw(
					  authorizedServiceObject
					  domainRelatedObject
					  organizationalRole
					  pkiUser
					  top
					  umiOvpnCfg
					  umiUserCertificate
				       ) ],
	   org                   => [ qw(
					  domainRelatedObject
					  organizationalUnit
					  top
				       ) ],
	   sargon                => [ qw(
					  sargonACL
				       ) ],
	   ssh                   => [ qw(
					  account
					  ldapPublicKey
					  top
				       ) ],
	   sudo                  => [ qw(
					  top
					  sudoRole
				       ) ],
	   inventory             => [ qw(
					  hwInventory
					  top
				       ) ],
	  },
	  jpegPhoto => {
			'stub' => 'user-6-128x128.jpg',
		       },
	  authorizedService =>
	  {
	   'mail'          => {
			       auth                 => 1,
			       delim_mandatory      => 1,
			       descr                => 'Email',
			       disabled             => 0,
			       login_delim          => '@',
			       homeDirectory_prefix => '/mail/fast/imap/',
			       gidNumber            => 26,
			       icon                 => 'fas fa-envelope',
			       data_fields          => 'login,login_complex,password1,password2',
			       data_relation        => 'passw',
			      },
	   'xmpp'          => {
			       auth                    => 1,
			       delim_mandatory         => 1,
			       descr                   => 'XMPP (Jabber)',
			       disabled                => 0,
			       login_delim             => '@',
			       gidNumber               => 10106,
			       jpegPhoto_noavatar      => UMI->path_to('root', 'static', 'images', '/avatar-xmpp.png'),
			       icon                    => 'fas fa-lightbulb',
			       data_fields             => 'login,login_complex,password1,password2',
			       data_relation           => 'passw',
			       associateddomain_prefix => {
							   'talax.startrek.in' => 'im.',
							  },
			      },
	   'dot1x-eap-md5' => {
			       auth          => 1,
			       descr         => 'auth 802.1x EAP-MD5 (MAC)',
			       disabled      => 0,
			       icon          => 'fas fa-shield-alt',
			       data_fields   => 'login,radiusgroupname,radiusprofile',
			       data_relation => 'dot1x',
			      },
	   'dot1x-eap-tls' => {
			       auth          => 1,
			       descr         => 'auth 802.1x EAP-TLS',
			       disabled      => 0,
			       icon          => 'fas fa-shield-alt',
			       data_fields   => 'login,password1,password2,radiusgroupname,radiusprofile,userCertificate',
			       data_relation => 'dot1x-eap-tls',
			       login_prefix  => 'rad-',
			      },
	   'gitlab'        => {
			       auth          => 1,
			       descr         => 'GitLab Account',
			       disabled      => 0,
			       icon          => 'fab fa-gitlab',
			       login_delim   => '@',
			       data_fields   => 'login,login_complex,password1,password2',
			       data_relation => 'passw',
			      },
	   'otrs'          => {
			       auth          => 1,
			       descr         => 'OTRS',
			       disabled      => 1,
			       icon          => 'fas fa-ticket-alt',
			       data_fields   => 'login,password1,password2',
			      },
	   'web'           => {
			       auth          => 1,
			       descr         => 'Web Account',
			       disabled      => 0,
			       icon          => 'fas fa-globe-europe',
			       login_delim   => '@',
			       data_fields   => 'login,login_complex,password1,password2',
			       data_relation => 'passw',
			      },
	   'sms'           => {
			       auth          => 1,
			       descr         => 'SMSter',
			       disabled      => 1,
			       data_fields   => 'login,password1,password2',
			      },
	   'comm-acc'      => {
			       auth          => 1,
			       descr         => 'CISCO Commutators',
			       disabled      => 0,
			       icon          => 'fas fa-terminal',
			       data_fields   => 'login,login_complex,password1,password2',
			       data_relation => 'passw',
			      },
	   'ssh-acc'       => {
			       auth                 => 1,
			       login_delim          => '_',
			       homeDirectory_prefix => '/usr/local/home',
			       icon                 => 'fas fa-key',
			       loginShell           => '/usr/bin/false',
			       descr                => 'SSH',
			       disabled             => 0,
			       gidNumber            => 11102,
			       uidNumberShift       => 10000,
			       icon                 => 'fas fa-terminal',
			       data_fields          => 'login,login_complex,password1,password2,sshkey,sshkeyfile,sshhome,sshshell,sshgid',
			       data_relation        => 'sshacc',
			      },
	   'gpg'           => {
			       auth     => 0,
			       descr    => 'GPG key',
			       disabled => 1,
			       icon     => 'fas fa-key',
			      },
	   'ovpn'          => {
			       auth     => 0,
			       descr    => 'OpenVPN client',
			       disabled => 0,
			       icon     => 'fas fa-certificate',
			       # data_fields => 'block_crt',
			      },
	  },
	  
	  hwType =>
	  {
	   singleboard => {
			   dn_sfx => 'ou=SingleBoard,ou=hw,',
			   ap => {
				  descr    => 'singleboard inventory item, Access Point',
				  disabled => 0,
				  icon     => 'fas fa-lg fa-cog',
				 },
			   com  => {
				    descr    => 'singleboard inventory item, commutator',
				    disabled => 0,
				    icon     => 'fas fa-lg fa-cog',
				   },
			   wrt => {
				   descr    => 'singleboard inventory item, WRT',
				   disabled => 0,
				   icon     => 'fas fa-lg fa-cog',
				  },
			   monitor => {
				       descr    => 'singleboard inventory item, monitor',
				       disabled => 0,
				       icon     => 'fas fa-lg fa-cog',
				      },
			   prn => {
				   descr    => 'singleboard inventory item, printer',
				   disabled => 0,
				   icon     => 'fas fa-lg fa-cog',
				  },
			   mfu => {
				   descr    => 'singleboard inventory item, MFU',
				   disabled => 0,
				   icon     => 'fas fa-lg fa-cog',
				  },
			  },
	   composite => {
			 dn_sfx => 'ou=Composite,ou=hw,',
			 ws => {
				descr    => 'composite inventory item, workstation',
				disabled => 0,
				icon     => 'fas fa-lg fa-desktop',
			       },
			 srv => {
				 descr    => 'composite inventory item, server',
				 disabled => 0,
				 icon     => 'fas fa-lg fa-desktop',
				},
			},
	   consumable => {
			  dn_sfx => 'ou=Consumable,ou=hw,',
			  kbd => {
				  descr    => 'consumable inventory item, keyboard',
				  disabled => 0,
				  icon     => 'fas fa-lg fa-recycle',
				 },
			  ms => {
				 descr    => 'consumable inventory item, mouse',
				 disabled => 0,
				 icon     => 'fas fa-lg fa-recycle',
				},
			  hs => {
				 descr    => 'consumable inventory item, headset',
				 disabled => 0,
				 icon     => 'fas fa-lg fa-recycle',
				},
			 },
	   compart => {
		       dn_sfx => 'ou=Compart,ou=hw,',
		       mb => {
			      descr    => 'compart inventory item, motherboard',
			      disabled => 0,
			      icon     => 'fas fa-lg fa-cogs',
			     },
		       cpu => {
			       descr    => 'compart inventory item, CPU',
			       disabled => 0,
			       icon     => 'fas fa-lg fa-cogs',
			      },
		       ram => {
			       descr    => 'compart inventory item, RAM',
			       disabled => 0,
			       icon     => 'fas fa-lg fa-cogs',
			      },
		       disk => {
			       descr    => 'compart inventory item, disk',
			       disabled => 0,
			       icon     => 'fas fa-lg fa-cogs',
			      },
		      },
	   furniture => {
			 dn_sfx => 'ou=Furniture,ou=hw,',
			 tbl => {
				 descr    => 'furniture inventory item, table',
				 disabled => 0,
				 icon     => 'fas fa-lg fa-bed',
				},
			 chr => {
				 descr    => 'furniture inventory item, chair',
				 disabled => 0,
				 icon     => 'fas fa-lg fa-wheelchair',
				},
			},
	  },
	  err => {
		  0  => '<div class="alert alert-success" role="alert"><i class="fas fa-info-circle fa-lg"></i>&nbsp;<b>Your request returned no result. Try to change query parameter/s.</b></div>',
		  50 => 'Do not panic! This situation needs your security officer and system administrator attention, please contact them to solve the issue.',
		 },

	  #=====================================================================
	  ##
	  ### CONFIGURATION STOPS HERE
	  ##
	  #=====================================================================
	 };
}

has 'host'    => ( is => 'ro', isa => 'Str', required => 1,
		   default => UMI->config->{authentication}->{realms}->{ldap}->{store}->{ldap_server});
has 'dry_run'    => ( is => 'ro', isa => 'Bool', default => 0 );

# these ones are declared in Model/LDAP_CRUD.pm
has 'uid'        => ( is => 'ro', isa => 'Str', required => 1 );
has 'pwd'        => ( is => 'ro', isa => 'Str', required => 1 );
has 'user'       => ( is => 'ro', required => 1 );
has 'role_admin' => ( is => 'ro', required => 1 );

# has 'path_to_images' => ( is => 'ro', isa => 'Str', required => 1 );

has '_ldap' => (
	is       => 'rw',
	isa      => 'Net::LDAP',
	required => 0, lazy => 1,
	builder  => '_build_ldap',
	clearer  => 'reset_ldap',
	reader   => 'ldap',
);
sub _build_ldap {
	my $self = shift;
	my ( $ldap, $mesg );


#	log_error { UMI->config->{debug}->{level} };
	
	$ldap = try {
	  Net::LDAP->new( $self->host );
	} catch {
	  warn "Net::LDAP->new problem, error: $_";    # not $@
	};
	
	# START TLS if defined
	if ( defined UMI->config->{ldap_crud_cafile} &&
	     UMI->config->{ldap_crud_cafile} ne '' ) {
	  $mesg = try {
	    $ldap->start_tls(
			     verify   => 'none',
			     cafile   => UMI->config->{ldap_crud_cafile},
			     checkcrl => 0,
			    );
	  } catch {
	    warn "Net::LDAP start_tls error: $@" if $mesg->error;
	  }
	}
	
	return $ldap;
}

around 'ldap' =>
  sub {
    my $orig = shift;
    my $self = shift;

    my $ldap = $self->$orig(@_);

    # my $dn = sprintf( "%s=%s,%s",
    # 		      $self->cfg->{rdn}->{acc_root},
    # 		      $self->uid,
    # 		      $self->cfg->{base}->{acc_root} );

    my $mesg = $ldap->bind( sprintf( "%s=%s,%s",
				     $self->cfg->{rdn}->{acc_root},
				     $self->uid,
				     $self->cfg->{base}->{acc_root} ),
			    password => $self->pwd,
			    version  => 3, );

    if ( $mesg->is_error ) {
      my $err = sprintf( "%s\nUMI WARNING: Net::LDAP->bind related problem occured!\nerror_name: %s \nerror_desc: %s \nerror_text: %s \nserver_error: %s",
			 '#' x 60,
			 $mesg->error_name,
			 $mesg->error_desc,
			 $mesg->error_text,
			 $mesg->server_error );
      log_fatal { $err };
    }

    return $ldap;
  };

=head2 filter_users_org

Method to get filter part to be used in searches, to restrict search
result by organizations, logged in user belongs to

=cut

has 'filter_users_org' => ( is       => 'ro',
			    isa      => 'Str',
			    required => 0, lazy => 1,
			    builder  => 'build_filter_users_org', );

sub build_filter_users_org {
  my $self = shift;
  return ref($self->user->o) eq 'ARRAY' ?
      '(|' . join('', map { '(o=*' . $_ . ')' } @{$self->user->o} ) .')' : '(o=*' . $self->user->o . ')';
}

=head2 last_uidNumber

Method to get last uidNumber for base ou=People,dc=umidb

=cut

has 'last_uidNumber' => ( is       => 'ro',
			  isa      => 'Num',
			  required => 0, lazy => 1,
			  builder  => 'build_last_uidNumber', );

sub build_last_uidNumber {
  my $self = shift;
  return $self->last_seq_val({ base  => $self->cfg->{base}->{acc_root},
			       attr  => 'uidNumber', })
    // $self->cfg->{defaults}->{ldap}->{uidNumber_start};
}

=head2 last_uidNumber_ssh

Method to get last uidNumber for SSH accounts

=cut

has 'last_uidNumber_ssh' => ( is       => 'ro',
			      isa      => 'Num',
			      required => 0, lazy => 1,
			      builder  => 'build_last_uidNumber_ssh', );

sub build_last_uidNumber_ssh {
  my $self = shift;
  return $self->last_seq_val({ base   => $self->cfg->{base}->{acc_root},
			       filter => '(&(authorizedService=ssh-acc@*)(uidNumber=*))',
			       scope  => 'sub',
			       attr   => 'uidNumber', })
    // $self->cfg->{defaults}->{ldap}->{uidNumber_ssh_start};
}

=head2 last_gidNumber

Method to get last gidNumber for base ou=group,dc=umidb

it uses sub last_seq_val()

=cut

has 'last_gidNumber' => ( is       => 'ro', isa => 'Num',
			  required => 0,   lazy => 1,
			  builder  => 'build_last_gidNumber', );

sub build_last_gidNumber {
  my $self = shift;
  return $self->last_seq_val({ base  => $self->cfg->{base}->{group},
			       attr  => 'gidNumber', })
    // $self->cfg->{defaults}->{ldap}->{gidNumber_start};
}


=head2 last_seq_val

find the latest number in sequence for one single attribute requested

like for uidNumber or gidNumber

on input it expects hash

    base   => base to search in (mandatory)
    attr   => attribute name to search for the latest seq number for (mandatory)
    filter => filter (optional, default is `(ATTRIBUTE=*)')
    scope  => scope (optional, default is `one')
    deref  => deref (optional, default is `never')

return value in success is the last number in sequence of the attribute values

return value in error is message from method err()

=cut

sub last_seq_val {
  my ($self, $args) = @_;
  my $arg = { base   => $args->{base},
	      attrs  => $args->{attr},
	      filter => $args->{filter} // sprintf("(%s=*)", $args->{attr}),
	      scope  => $args->{scope}  // 'one',
	      deref  => $args->{deref}  // 'never', };
  log_debug { np($arg) };
  my $callername = (caller(1))[3];
  $callername = 'main' if ! defined $callername;
  my $return = 'call to LDAP_CRUD->last_seq_val from ' . $callername . ': ';

  $self->reset_ldap;
  my $mesg =
    $self->ldap->search( base   => $arg->{base},
			 scope  => $arg->{scope},
			 filter => $arg->{filter},
			 attrs  => [ $arg->{attrs} ],
			 deref  => $arg->{deref}, );

  if ( $mesg->code ) {
    $return .= $self->err( $mesg );
  } else {
    if ( $mesg->count ) {
      my @arr = $mesg->sorted ( $arg->{attrs} );
      $return = $arr[$#arr]->get_value( $arg->{attrs} );
    } else {
      return;
    }
  }
  return $return;
}

=head2 last_seq

find the latest index for sequential, complex R/DNs given

for objects with RDN notation like: objectSuperName-XXX

where objectSuperName is the name of the object class (like
ram/cpu/mb/e.t.c. for inventory) and XXX is incremental index

for example RAM modules has DNs like cn=ram-17,ou=Comparts,ou=hw,ou=Inventory,dc=umidb

to find the latest RAM module we will search with

    base => 'ou=Comparts,ou=hw,ou=Inventory,dc=umidb'
    attr => 'cn',
    filter => 'ram-*',

if ram-17 is the last one, then number 17 will be returned

=cut

sub last_seq {
  my ($self, $args) = @_;
  my $arg = { base    => $args->{base},
	      attr    => $args->{attr}, # one single attribute sequence of we calculate
	      scope   => $args->{scope} || 'one',
	      filter  => $args->{filter} || '(objectClass=*)',
	      seq_pfx => $args->{seq_pfx},
	      seq_cnt => 0, };

  my $mesg = $self->ldap->search( base   => $arg->{base},
				  scope  => $arg->{scope},
				  filter => $arg->{filter},
				  attrs  => [ $arg->{attr} ], );
  if ( $mesg->count ) {
    @{$arg->{entries}} = $mesg->entries;
    foreach my $i ( @{$arg->{entries}} ) {
      push @{$arg->{seq}}, substr( $i->get_value( $arg->{attr} ), length $arg->{seq_pfx} );
    }
    @{$arg->{seq_sorted_desc}} = sort {$b <=> $a} @{$arg->{seq}};
  }
  return $arg->{seq_sorted_desc}[0];
}

=head2 err

Net::LDAP errors handling

Net::LDAP::Message is expected as first input argument

second argument is debug level, which expected to be greater than 0

returns hash with formatted details

=cut

sub err {
  my ($self, $mesg, $debug, $dn) = @_;

  my $caller = (caller(1))[3];
  my $err = {
	     code          => $mesg->code // 'NA',
	     name          => ldap_error_name($mesg),
	     text          => ldap_error_text($mesg),
	     desc          => ldap_error_desc($mesg),
	     srv           => $mesg->server_error,
	     caller        => $caller // 'main',
	     matchedDN     => $mesg->{matchedDN},
	     dn            => $dn // '',
	     supplementary => '',
	    };

  $err->{supplementary} .= sprintf('<li><h6><b>matchedDN:</b><small> %s</small><h6></li>', $err->{matchedDN})
    if $err->{matchedDN} ne '';

  $err->{supplementary} = '<div class=""><ul class="list-unstyled">' . $err->{supplementary} . '</ul></div>'
    if $err->{supplementary} ne '';
  
  $err->{html} = sprintf( 'call from <b><em>%s</em></b>: <dl class="row">
  <dt class="col-2 text-right">DN</dt>                <dd class="col-10 text-monospace">%s</dd>
  <dt class="col-2 text-right">admin note</dt>        <dd class="col-10 text-monospace">%s</dd>
  <dt class="col-2 text-right">supplementary data</dt><dd class="col-10 text-monospace">%s</dd>
  <dt class="col-2 text-right">code</dt>              <dd class="col-10 text-monospace">%s</dd>
  <dt class="col-2 text-right">error name</dt>        <dd class="col-10 text-monospace">%s</dd>
  <dt class="col-2 text-right">error text</dt>        <dd class="col-10 text-monospace"><em><small><pre><samp>%s</samp></pre></small></em></dd>
  <dt class="col-2 text-right">error description</dt> <dd class="col-10 text-monospace">%s</dd>
  <dt class="col-2 text-right">server_error</dt>      <dd class="col-10 text-monospace">%s</dd>
</dl>',
			  $caller,
			  $err->{dn},

			  defined $self->{cfg}->{err}->{$mesg->code} &&
			  $self->{cfg}->{err}->{$mesg->code} ne '' ?
			  $self->{cfg}->{err}->{$mesg->code} : '',

			  $err->{supplementary},
			  $mesg->code,
			  ldap_error_name($mesg),
			  ldap_error_text($mesg),
			  ldap_error_desc($mesg),
			  $mesg->server_error
			 );

  log_error { np($err) } if defined $debug && $debug > 0;
  # p $err if defined $debug && $debug > 0;
  return $err; # if $mesg->code;
}

sub unbind {
  my $self = shift;
  $self->ldap->unbind;
}

sub schema {
  my $self = shift;
  my $schema = $self->ldap->schema ( );

  return $schema;
}


=head2 search

Net::LDAP->search wrapper which expects hash on input
    { 
      dn => ...,
      base  => ...,
      scope => 'base',
      ... e.t.c.
    }

if `dn' provided, then it is used to construct the `filter' and `base'
(values of which will be overwriten), scope in that case will be set
to `one'

it returns just what Net::LDAP->search returns and in most cases
should be processed with $self->err()

=cut

sub search {
  my ($self, $args) = @_;

  # log_debug { np($args) };

  if ( defined $args->{dn} && $args->{dn} ne '' ) {
    $args->{base}  = $args->{dn};
    $args->{scope} = 'base';
  }

  my $arg = {
  	     base      => $args->{base}      // $self->{cfg}->{base}->{db},
  	     scope     => $args->{scope}     // $self->{cfg}->{defaults}->{ldap}->{scope},
  	     filter    => $args->{filter}    // $self->{cfg}->{defaults}->{ldap}->{filter},
  	     deref     => $args->{deref}     // $self->{cfg}->{defaults}->{ldap}->{deref},
  	     attrs     => $args->{attrs}     // $self->{cfg}->{defaults}->{ldap}->{attrs},
  	     sizelimit => $args->{sizelimit} // $self->{cfg}->{defaults}->{ldap}->{sizelimit},
  	    };

  $arg->{typesonly} = 1                           if defined $args->{typesonly};
  $arg->{callback}  = $args->{callback}           if exists  $args->{callback};
  $arg->{control}   = [ $self->control_sync_req ] if exists  $args->{control};

  my $mesg = $self->ldap->search( %{$arg} );

  return $mesg;
}


=head2 add

Net::LDAP->add wrapper

=cut

sub add {
  my ($self, $dn, $attrs) = @_;
  # log_debug { $dn };
  # log_debug { np($attrs) };
  my $callername = (caller(1))[3];
  $callername = 'main' if ! defined $callername;
  my $return;
  my $msg;
  if ( ! $self->dry_run ) {
    $msg = $self->ldap->add ( $dn, attrs => $attrs, );
    if ($msg->is_error()) {
      $return = $self->err( $msg, 0, $dn );
      $return->{caller} = 'call to LDAP_CRUD->add from ' . $callername . ': ';
    } else {
      log_info { 'DN: ' . $dn . ' was successfully added.' };
      $return = 0;
    }
  } else {
    $return = $msg->ldif;
  }
  return $return;
}


=head2 moddn

Net::LDAP->moddn wrapper

=cut

sub moddn {
  my ($self, $args) = @_;
  my $arg = { dn           => $args->{src_dn},
	      newrdn       => $args->{newrdn},
	      deleteoldrdn => $args->{deleteoldrdn} || '1',
	      newsuperior  => $args->{newsuperior}  || undef };
  # log_debug { np($arg) };
  my $callername = (caller(1))[3];
  $callername = 'main' if ! defined $callername;
  my $return;
  my $msg;

  $msg = defined $arg->{newsuperior} ?
    $self->ldap->moddn ( $arg->{dn},
			 newrdn       => $arg->{newrdn},
			 deleteoldrdn => $arg->{deleteoldrdn},
			 newsuperior  => $arg->{newsuperior} ) :
			   $self->ldap->moddn ( $arg->{dn},
						newrdn       => $arg->{newrdn},
						deleteoldrdn => $arg->{deleteoldrdn} );

  if ($msg->is_error()) {
    $return = $self->err( $msg );
    $return->{caller} = 'call to LDAP_CRUD->moddn from ' . $callername . ': ';
  } else {
    log_info { 'DN: ' . $arg->{dn} . ' was successfully modified.' };
    $return = 0;
  }
  return $return;
}


=head2 refresh

Net::LDAP::Extension::Refresh wrapper

=cut

sub refresh {
  my ($self, $entryName, $requestTtl) = @_;
  # p $entryName; p $requestTtl;
  my $callername = (caller(1))[3];
  $callername = 'main' if ! defined $callername;
  my ($return, $msg);

  $msg = $self->ldap->refresh ( entryName => $entryName, requestTtl => $requestTtl );
  if ($msg->code) {
    $return->{error} = $msg->error;
    $return->{caller} = 'call to LDAP_CRUD->refresh from ' . $callername . ': ';
  } else {
    # log_info { sprintf("TTL for DN: %s was set to %d hours from now, UTC", $entryName, int($requestTtl/3600 + 0.05) };
    $return->{success} = sprintf("TTL for DN: <b>%s</b> was set to %d hours from now UTC",
				 $entryName, int($requestTtl/3600 + 0.005));
  }
  return $return;
}


=head2 ldif_read

LDIF processing from input file or ldif code

=cut

sub ldif_read {
  my ($self, $args) = @_;
  my $arg = {
	     file => $args->{file} || undef,
	     ldif => $args->{ldif} || '',
	    };
  my ( $entry, $mesg, $file );
  if ( $arg->{ldif} ) {
    try {
      open( $file, "<", \$arg->{ldif});
    } catch {
      log_error { "Cannot open data from variable: $arg->{ldif} for reading: $_" };
      return $arg->{final_message} = { error => [ "Cannot open data from variable: $arg->{ldif} for reading: $_", ] };
    };
  } else {
    $file = $arg->{file};
  }
  my $ldif = Net::LDAP::LDIF->new( $file, "r", onerror => 'warn' );
  while ( not $ldif->eof ) {
    $entry = $ldif->read_entry;
    if ( $ldif->error ) {
      push @{$arg->{final_message}->{error}},
	sprintf('Error msg: %s\nError lines:\n%s\n',
		$ldif->error,
		$ldif->error_lines );
    } else {
      $mesg = $entry->update($self->ldap);
      if ( $mesg->code ) {
	log_error { $self->err($mesg)->{desc} . ' while processing DN: ' . $entry->dn };
	push @{$arg->{final_message}->{error}}, $self->err($mesg)->{html};
      } else {
	log_info { 'DN: ' . $entry->dn . ' was successfully processed.' };
	push @{$arg->{final_message}->{success}},
	  $self->search_result_item_as_button( { uri     => UMI->uri_for_action('searchby/index'),
						 dn      => $entry->dn,
						 btn_txt => $entry->dn,
						 css_btn => 'btn-link',
						 pfx     => 'successfully added: '} );
      }
    }
  }
  $ldif->done;
  if ( $arg->{file} ) {
    try {
      close $file;
    } catch {
      return $arg->{final_message} = { error => "Cannot close file: $arg->{ldif} error: $_" };
    };
  }

  return $arg->{final_message};
}

=head2 reassign

reassign method

    src => { # dn to reassign (branch or leaf)
        arr   [ # splitted by `,'
            [0] ...,
            [n] ...
        ],
        str => "as string"
    },
    src_branch_dn => {
        arr   [
            [0] ...,
            [n] ...
        ],
        str   "as string"
    },
    src_is_branch => is src a branch?


    dst => { # dn to reassign to (root account object)
        arr =>  [ # splitted by `,'
            [0] ...,
            [n] ...
        ],
        str => "as string"
    },
    dst_branch_dn => {
        arr   [
            [0] ...,
            [n] ...
        ],
        str   "as string"
    },

    dst_has_branch => is there src branch in dst subtree?

=cut

sub reassign {
  my ($self, $args) = @_;
  my ( $arg, $return, $y, $result, $mesg, $entry, $clone, $attrs, $key, $val );

  if ( $args->{src_dn} =~ /.*,ou=People/ ) {
    $arg->{type} = 'people';
  } elsif ( $args->{src_dn} =~ /.*,ou=Inventory/ ) {
    $arg->{type} = 'inventory';
  } else {
    $arg->{type} = '';
  }

  $arg->{dst} = { str =>
		  # is DN?
		  $args->{dst_uid} =~ /.*ou=.*dc=/ ?
		  # what type is it?
		  $args->{dst_uid} : $arg->{type} eq 'people' ?
		  sprintf('uid=%s,%s', $args->{dst_uid}, $self->cfg->{base}->{acc_root}) :
		  sprintf('cn=%s,ou=Composite,ou=hw,%s', $args->{dst_uid}, $self->cfg->{base}->{inventory}),
		};
  $arg->{src} = { str => $args->{src_dn},
		  is_branch => $args->{src_dn} =~ /^.*,authorizedService=/ ? 0 : 1, };

  $arg->{dst}->{str} = $self->lrtrim( { str => $arg->{dst}->{str},
					tosplit => 1, } );

  # return error if dst DN not exist
  $arg->{garbage} = $self->search( { base  => $arg->{dst}->{str}, scope => 'base' } ); p $arg;
  if ( $arg->{garbage}->code ) {
    push @{$return->{error}}, $self->err($arg->{garbage});
    $return->{error}->[0]->{html} = '<h3>dst DN does not exist!</h3>' . $return->{error}->[0]->{html};p $arg;
    return $return if $arg->{garbage}->code;
  }

  @{$arg->{src}->{arr}} = split(/,/, $arg->{src}->{str});
  @{$arg->{dst}->{arr}} = split(/,/, $arg->{dst}->{str});

  if ( $arg->{type} eq 'people' ) {
    my @x;		  # array to pick src authorizedService branch
    $y = 0; # flag to use all rest array elements to form src authorizedService branch DN
    foreach my $z ( @{$arg->{src}->{arr}} ) {
      push @x, $z if $z =~ /^authorizedService=/ || $y == 1;
      $y = 1 if $z =~ /^authorizedService=/;
    }
  
    # src authorizedService branch DN and DN elements array
    $arg->{src}->{branch_dn}->{str} = join(',', @x);
    $arg->{src}->{branch_dn}->{arr} = \@x;

    $arg->{dst}->{branch_dn}->{str} = sprintf('%s,%s',
					      $arg->{src}->{branch_dn}->{arr}->[0],
					      $arg->{dst}->{str});
    @{$arg->{dst}->{branch_dn}->{arr}} = split(/,/, $arg->{dst}->{branch_dn}->{str});

    # is there dst branch?
    $result = $self->ldap->search( base   => $arg->{dst}->{str},
				   filter => sprintf('(%s)', $arg->{src}->{branch_dn}->{arr}->[0]),
				   scope  => 'base' );
    $arg->{dst}->{has_branch} = $result->count;
  } else {
    $arg->{dst}->{has_branch} = 1; # it is rather than it has
    $arg->{dst}->{branch_dn}->{str} = $arg->{dst}->{str};
  }

  $result = $self->search( { base  => $arg->{dst}->{str}, scope => 'base', } );
  $entry  = $result->entry(0);
  foreach ( $entry->attributes ) {
      $arg->{dst}->{data}->{$_} = $entry->get_value( $_, asref => 1 )
      if $_ ne 'jpegPhoto';
  }
  
  # CREATE dst BRANCH if not exists in dst subtree
  if ( $arg->{type} eq 'people' && ! $arg->{dst}->{has_branch} ) {
    $result = $self->search( { base  => $arg->{src}->{branch_dn}->{str}, scope => 'base', } );
    push @{$return->{error}}, $self->err($result) if $result->code;
    $clone = $result->entry(0)->clone;
    $mesg = $clone->dn($arg->{dst}->{branch_dn}->{str}); # !!! error handling

    $mesg = $clone->
      replace( uid =>
	       sprintf('%s@%s.%s',
		       # dst uid value
		       (split(/=/, $arg->{dst}->{arr}->[0]))[1],
		       # left part of src branch dn authorizedService value
		       (split(/@/, (split(/=/, $arg->{src}->{branch_dn}->{arr}->[0]))[1]))[0],
		       # right part of src branch dn authorizedService value
		       (split(/@/, (split(/=/, $arg->{src}->{branch_dn}->{arr}->[0]))[1]))[1]
		      ) );

    push @{$attrs}, map { $_ => $clone->get_value( $_, asref => 1 ) } $clone->attributes;

    $mesg = $self->add( $clone->dn, $attrs );
    if ( $mesg && $mesg->{name} eq 'LDAP_ALREADY_EXISTS' ) {
      push @{$return->{warning}}, $mesg if $mesg;
    } else {
      push @{$return->{error}}, $mesg if $mesg;
    }
  }
  undef $attrs;

  # src BRANCH already EXISTS in dst subtree and here
  # we process all objects bellow it (bellow src branch)
  if ( $arg->{type} eq 'people' && $arg->{src}->{is_branch} ) {
    $result = $self->search( { base  => $arg->{src}->{str}, scope => 'children', } );

    ### FINISH
    ## *first* we must delete src subtree, to avoid collision/s
    ## with any tool which process LDAP_SYNC_ events (if any)
    ## we delete src subtree recursively if @{$return->{error}} is empty
    $self->delr( $arg->{src}->{str} )
      if ref($return) ne "HASH" ||
      ( ref($return) eq "HASH" && $#{$return->{error}} < 0);

    foreach $entry ( $result->entries ) {
      $clone = $entry->clone;
      $mesg  = $clone->dn(sprintf('%s,%s',
				 (split(/,/, $entry->dn))[0],
				 $arg->{dst}->{branch_dn}->{str}));

      foreach ( $clone->attributes ) {
	if ( $_ eq 'givenName' ) {
	  $val = $arg->{dst}->{data}->{givenName}->[0];
	} elsif ( $_ eq 'sn' ) {
	  $val = $arg->{dst}->{data}->{sn}->[0];
	} else {
	  $val = $clone->get_value( $_, asref => 1 )
	}
	push @{$attrs}, $_ => $val;
      }
      $mesg = $self->add( $clone->dn, $attrs );
      undef $attrs;
      push @{$return->{error}}, $mesg if $mesg;
    }

  } else {
    $result = $self->search( { base  => $arg->{src}->{str}, scope => 'base', } );
    $clone = $result->entry(0)->clone;

    $mesg = $clone->dn(sprintf('%s,%s',
			       $arg->{src}->{arr}->[0],
			       $arg->{dst}->{branch_dn}->{str}));

      foreach ( $clone->attributes ) {
	if ( $_ eq 'givenName' ) {
	  $val = $arg->{dst}->{data}->{givenName}->[0];
	} elsif ( $_ eq 'sn' ) {
	  $val = $arg->{dst}->{data}->{sn}->[0];
	} else {
	  $val = $clone->get_value( $_, asref => 1 )
	}
	push @{$attrs}, $_ => $val;
      }

    ### FINISH
    ## *first* we must delete, to avoid collision with any tool which
    ## process LDAP_SYNC_ events
    ## we delete src dn if @{$return->{error}} is empty
    # $self->del( $arg->{src}->{str} ) if $return != 0 && $#{$return->{error}} > -1;
    $self->del( $arg->{src}->{str} )
      if ref($return) ne "HASH" ||
      ( ref($return) eq "HASH" && $#{$return->{error}} < 0);

    $mesg = $self->add( $clone->dn, $attrs );
    undef $attrs;
    push @{$return->{error}}, $mesg if $mesg;
  }
  return $return;
}


=head2 del

non recursive deletion

=cut


sub del {
  my ($self, $dn) = @_;
  my $callername = (caller(1))[3] // 'main';
  my $return;

  my $g_mod = $self->del_from_groups($dn);
  push @{$return->{error}}, $g_mod->{error} if defined $g_mod->{error};

  my $msg = $self->ldap->delete ( $dn );
  # log_debug { np($msg) };
  if ( $msg->code == LDAP_SUCCESS ) {
    log_info { 'DN: ' . $dn . ' successfully deleted.' };
    $return = 0;
  } elsif ( $msg->code == LDAP_NO_SUCH_OBJECT ) {
    log_error { sprintf("%s has happened while deleting DN: %s", $self->err($msg)->{desc}, $dn) };
    push @{$return->{error}}, $self->err( $msg );
  } else {
    log_error { sprintf("%s has happened while deleting DN: %s", $self->err($msg)->{desc}, $dn) };
    push @{$return->{error}}, $self->err( $msg ) if $msg;
  }
  return $return;
}


=head2 delr

recursive deletion

=cut


sub delr {
  my ($self, $dn) = @_;

  my $callername = (caller(1))[3] // 'main';
  # remove after above row confirmed # $callername = 'main' if ! defined $callername;
  my $return;
  my $msg;

  my $g_mod = $self->del_from_groups($dn);
  push @{$return->{error}}, $g_mod->{error} if defined $g_mod->{error};

  my $search = $self->ldap->search( base => $dn, filter => '(objectclass=*)' );
  ## taken from perl-ldap/contrib/recursive-ldap-delete.pl
  # delete the entries found in a sorted way:
  # those with more "," (= more elements) in their DN, which are deeper in the DIT, first
  # trick for the sorting: tr/,// returns number of , (see perlfaq4 for details)
  foreach my $e (sort { $b->dn =~ tr/,// <=> $a->dn =~ tr/,// } $search->entries()) {
    $msg = $self->ldap->delete($e);
    if ( $msg->code == LDAP_SUCCESS ) {
      log_info { 'DN: ' . $dn . ' successfully deleted.' };
      $return = 0;
    } elsif ( $msg->code == LDAP_NO_SUCH_OBJECT ) {
      log_error { sprintf("%s has happened while deleting DN: %s", $self->err($msg)->{desc}, $e) };
      push @{$return->{error}}, $self->err( $msg );
    } else {
      log_error { sprintf("%s has happened while deleting DN: %s", $self->err($msg)->{desc}, $e) };
      push @{$return->{error}}, $self->err( $msg ) if $msg;
    }
  }

  return $return;
}

=head2 get_root_obj_dn

method to determine root object DN

in general it is the last coma separated fragment of the
string after $self->{conf}->{base}->{acc_root} removal from the end of
the string and the very $self->{conf}->{base}->{acc_root} joined with coma

for example, if

=over

=item I<DN>

authorizedService=xmpp@im.talax.startrek.in,uid=taf.taf,ou=People,dc=umidb

=item I<$self-{conf}-{base}-{acc_root}>

ou=People,dc=umidb

=item I<the last coma separated fragment of the string>

uid=taf.taf

=item I<method returns>

uid=taf.taf,ou=People,dc=umidb

=back

=cut

sub get_root_obj_dn {
  my ($self, $dn) = @_;
  my @dn_arr = split(/,/, substr( $dn, 0, -1 * length($self->{cfg}->{base}->{acc_root}) ));
  push my @root_obj_dn_arr, $self->{cfg}->{base}->{acc_root};
  push @root_obj_dn_arr, pop @dn_arr;
  return join(',', reverse @root_obj_dn_arr);
}


=head2 del_from_groups

delete user from all

=over

=item I<posixGroup>

if DN to delete is DN of the root object (now, memberUid is expected to be
uid of the root object)

=item I<groupOfNames>

if DN to delete is DN of service or branch

=back

=cut

sub del_from_groups {
  my ($self, $dn) = @_;
  my ($return, $mesg, $entry, $attr, $filter, $to_del, $del);
  # log_debug { np( $dn ) };
  # log_debug { np( $self->get_root_obj_dn($dn) ) };
  if ( $dn eq $self->get_root_obj_dn($dn) ) { # posixGroup first
    # get uid from the root object
    $mesg = $self->ldap->search( base   => $dn,
				 filter => "(objectClass=*)",
				 scope  => 'base',
				 attrs  => [ 'uid' ] );
    $entry  = $mesg->entry(0);
    $to_del = $entry->get_value( 'uid' );
    $filter = sprintf("(&(objectClass=posixGroup)(memberUid=%s))", $to_del);
    $attr   = 'memberUid';
  } else { # groupOfNames is second
    $to_del = $dn;
    $filter = sprintf("(&(objectClass=groupOfNames)(member=%s))", $dn);
    $attr   = 'member';
  }
  # get all groups DN belongs to
  $mesg = $self->ldap->search( base   => $self->{cfg}->{base}->{db},
			       filter => $filter,
			       attrs  => [ 'cn' ]);
  foreach ( $mesg->entries ) {
    $del = $self->modify( $_->dn, [ delete => [ $attr => $to_del ]] );
    if ( $del ) {
      push @{$return->{error}}, $del->{html};
    } else {
      push @{$return->{success}}, sprintf("Group %s was modified.", $_->get_value('cn'));
    }
  }
  # log_debug { np( $return ) };
  return $return;
}


=head2 block

block all user accounts (via password change and ssh-key modification)
to make it impossible to use any of them

unblock is possible only via password change, ssh-key modification and
removal from the special group for blocked users

=cut


sub block {
  my ($self, $args) = @_;
  my $callername = (caller(1))[3];
  $callername = 'main' if ! defined $callername;
  my $return; # = 'call to LDAP_CRUD->block from ' . $callername . ': ';
  my $attr;
  my $userPassword;
  my @userPublicKeys;
  my @keys;
  my ( $msg, $msg_usr, $msg_add, $msg_chg, $ent_svc, $ent_chg, @blockgr );

  log_debug { np( $args ) };

  $msg = $self->modify( $args->{dn},
			[ replace => [ gidNumber => $self->cfg->{stub}->{group_blocked_gid}, ],	], );

  if ( ref($msg) eq 'HASH' ) {
    $return->{error} .= $msg->{html};
  } else {
    $return->{success} .= $ent_svc->dn . "\n";
  }

  $msg_usr = $self->search ( { base      => $args->{dn},
			       sizelimit => 0, } );
  if ( $msg_usr->is_error() ) {
    $return->{error} = $self->err( $msg_usr )->{html};
  } else {
    # bellow we are blocking services
    my @ent_toblock = $msg_usr->entries;
    foreach $ent_svc ( @ent_toblock ) {
      if ( $ent_svc->exists('userPassword') &&
	 $ent_svc->get_value('userPassword') !~ /^\!-disabled-on-/) {
	# before 20210419 # $userPassword = $self->pwdgen;
	$msg = $self->modify( $ent_svc->dn,
			      [ replace =>
				[ userPassword =>
				  sprintf("!-disabled-on-%s-by-%s-%s",
					  $self->user,
					  $self->ts({ format => "%Y%m%d%H%M%S" }),
					  $ent_svc->get_value('userPassword')),	],
			      ], );
# before 20210419 #	      [ replace => [ userPassword => $userPassword->{ssha}, ], ], );
	if ( ref($msg) eq 'HASH' ) {
	  $return->{error} .= $msg->{html};
	} else {
	  $return->{success} .= $ent_svc->dn . "\n";
	}
      }

      if ( $ent_svc->exists('sshPublicKey') ) {
	@userPublicKeys = $ent_svc->get_value('sshPublicKey');
	@keys = map { $_ !~ /^from="127.0.0.1" / ? sprintf('from="127.0.0.1" %s', $_) : $_ } @userPublicKeys;
	$msg = $self->modify( $ent_svc->dn,
			      [ replace => [ sshPublicKey => \@keys, ],], );
	if ( ref($msg) eq 'HASH' ) {
	  $return->{error} .= $msg->{html};
	} else {
	  $return->{success} .= $ent_svc->dn . "\n";
	}
      }

      if ( $ent_svc->exists('grayPublicKey') ) {
	@userPublicKeys = $ent_svc->get_value('grayPublicKey');
	@keys = map { $_ !~ /^from="127.0.0.1" / ? sprintf('from="127.0.0.1" %s', $_) : $_ } @userPublicKeys;
	$msg = $self->modify( $ent_svc->dn,
			      [ replace => [ grayPublicKey => \@keys, ],], );
	if ( ref($msg) eq 'HASH' ) {
	  $return->{error} .= $msg->{html};
	} else {
	  $return->{success} .= $ent_svc->dn . "\n";
	}
      }

      if ( $ent_svc->exists('umiOvpnAddStatus') ) {
	$msg = $self->modify( $ent_svc->dn,
			      [ replace => [ umiOvpnAddStatus => 'disabled', ], ], );
	if ( ref($msg) eq 'HASH' ) {
	  $return->{error} .= $msg->{html};
	} else {
	  $return->{success} .= $ent_svc->dn . "\n";
	}
      }

    }
  }

  # is this user in block group?
  my $blockgr_dn =
    sprintf('cn=%s,%s',
	    $self->cfg->{stub}->{group_blocked},
	    $self->cfg->{base}->{group});

  $msg = $self->search ( { base   => $self->cfg->{base}->{group},
			   filter => sprintf('(&(cn=%s)(memberUid=%s))',
					     $self->cfg->{stub}->{group_blocked},
					     substr( (split /,/, $args->{dn})[0], 4 )),
			   sizelimit => 0, } );
  if ( $msg->is_error() ) {
    $return->{error} .= $self->err( $msg )->{html};
  } elsif ( $msg->count == 0) {
    $msg_chg = $self->search ( { base => $blockgr_dn, } );
    if ( $msg_chg->is_error() ) {
      $return->{error} .= $self->err( $msg_chg )->{html};
    } else {
      $ent_chg = $self->modify( $blockgr_dn,
				[ add =>
				  [ memberUid => substr( (split /,/, $args->{dn})[0], 4 ), ], ], );
      if ( ref($ent_chg) eq 'HASH' ) {
	$return->{error} .= $ent_chg->{html};
      } else {
	$return->{success} .= $args->{dn} . " successfully blocked.\n";
      }
    }
  }

  log_debug { np( $return ) };

  return $return;
}


=head2 modify

Net::LDAP->modify( changes => ... ) wrapper

NOTE: it returns hash of $self->err rather than Net::LDAP::Message !

=cut

sub modify {
  my ($self, $dn, $changes ) = @_;
  my ( $return, $msg );
  if ( ! $self->dry_run ) {
    $msg = $self->ldap->modify ( $dn, changes => $changes, );
    if ($msg->is_error()) {
      $return = $self->err( $msg );
    } else {
      log_info { 'DN: ' . $dn . ' was successfully modified.' };
      $return = 0;
    }
  } else { $return = $msg->ldif; }
  # log_debug { np($dn ) };
  # log_debug { np($changes ) };
  # log_debug { np($return ) };
  return $return;
}

=head2 ldif

LDIF export

    attrs - is expected to be array ref

=cut

sub ldif {
  my ($self, $args) = @_;
  my $arg = {
	     dn     => $args->{dn}     // undef,
	     base   => $args->{base}   // undef,
	     filter => $args->{filter} // 'objectClass=*',
	     attrs  => defined $args->{attrs} ? $args->{attrs} : [ '*' ],
	     scope  => $args->{scope},
	     # scope  => $args->{recursive}  ? 'sub' : 'base',
	    };

  if ( defined $args->{sysinfo} && $args->{sysinfo} ne '0' ) {
    push @{$arg->{attrs}}, 'createTimestamp',
      'creatorsName',
      'entryCSN',
      'entryDN',
      'entryUUID',
      'hasSubordinates',
      'modifiersName',
      'modifyTimestamp',
      'structuralobjectclass',
      'subschemaSubentry';
  }
  
  # log_debug{np($args)};
  log_debug{np($arg)};
  my $ts = strftime "%Y-%m-%d %H:%M:%S", localtime;
  my $return->{ldif} = sprintf("
## LDIF export DN: \"%s\"
##   Search Scope: \"%s\"
##  Search Filter: \"%s\"
##   Search Attrs: \"%s\"
##
## LDIF generated on %s, by UMI user %s\n##\n",
			       $arg->{base} // $arg->{dn} // '',
			       $arg->{scope},
			       $arg->{filter},
			       join(',', @{$arg->{attrs}}),
			       $ts,
			       $self->uid);

    my $msg = $self->search ({ base      => $arg->{base} // $arg->{dn},
			       scope     => $arg->{scope},
			       filter    => '(' . $arg->{filter} . ')',
			       sizelimit => 0,
			       attrs     => $arg->{attrs}, });
  if ($msg->is_error()) {
    $return->{error} .= $self->err( $msg )->{html};
  } else {
    my @entries = $msg->entries;
    foreach my $entry ( @entries ) {
      $return->{ldif} .= $entry->ldif;
    }
    $return->{success} .= sprintf('LDIF for object with DN:<blockquote class="mono">%s</blockquote> generated including%s recursion and including%s system data.',
				  $arg->{dn},
				  ! $args->{recursive} ? ' no' : '',
				  ! $args->{sysinfo}   ? ' no' : '' );
  }
  $return->{outfile_name} = defined $arg->{dn} ?
    join('_', split(/,/,canonical_dn( $arg->{dn},casefold => 'none', reverse => 1, ))) :
    sprintf("search-result-by-%s-on-%s", $self->uid, strftime("%Y%m%d%H%M%S", localtime));
  $return->{dn}        = $arg->{dn};
  $return->{recursive} = $args->{recursive} ? 1 : 0;
  $return->{sysinfo}   = $args->{sysinfo} ? 1 : 0;
  return $return;
}


=head2 vcard

vCard export

on input we expect

    - user DN vCard to be created for
    - vCard type to generate (onscreen or file)
    - non ASCII fields transliterated or not

=cut

sub vcard_neo {
  my ($self, $args) = @_;

  my $ts = strftime "%Y%m%dT%H%M%SZ", localtime;
  my $arg = { dn       => $args->{vcard_dn},
	      type     => $args->{vcard_type},
	      translit => $args->{vcard_translit} || 0, };

  my (@vcf, $msg, $branch, @branches, $branch_entry, $leaf, @leaves, $leaf_entry, $entry, @entries, @vcard, $return, $tmp);
  $msg = $self->ldap->search ( base => $arg->{dn}, scope => 'base', filter => 'objectClass=*', );
  if ($msg->is_error()) {
    $return->{error} .= $self->err( $msg )->{html};
  } else {
    $entry = $msg->as_struct;

    push @vcf, 'BEGIN:VCARD', 'VERSION:2.1';

    $arg->{vcard}->{sn}        = $self->utf2lat($entry->{$arg->{dn}}->{sn}->[0]);
    $arg->{vcard}->{givenName} = $self->utf2lat($entry->{$arg->{dn}}->{givenname}->[0]);
    push @vcf, sprintf('N:%s;%s;;;', $arg->{vcard}->{sn}, $arg->{vcard}->{givenName});
    $arg->{vcard}->{fn}        = sprintf('%s %s',
					 $entry->{$arg->{dn}}->{sn}->[0],
					 $arg->{vcard}->{givenName});
    push @vcf, sprintf('FN:%s', $self->utf2lat($arg->{vcard}->{fn}));
    push @vcf, sprintf('TITLE:%s', $self->utf2lat($entry->{$arg->{dn}}->{title}->[0]));

    # --- ORGANIZATION ------------------------------------------------
    if ( exists $entry->{$arg->{dn}}->{o} ) {
      ## https://tools.ietf.org/html/rfc6350#section-6.6.4
      ## so we take the first one
      $tmp = $self->search ( { base => $entry->{$arg->{dn}}->{o}->[0], scope => 'base', } );
      if ($tmp->is_error()) {
	$return->{error} .= $self->err( $tmp )->{html};
      } else {
	my $org = $tmp->as_struct;
	utf8::decode($org->{$entry->{$arg->{dn}}->{o}->[0]}->{physicaldeliveryofficename}->[0]);
	push @vcf, sprintf('ORG:%s', $org->{$entry->{$arg->{dn}}->{o}->[0]}->{physicaldeliveryofficename}->[0]);
      }
    }

    # --- TELEPHONENUMBER ---------------------------------------------
    my $tel_prefix = 'TEL;WORK:';
    if ( exists $entry->{$arg->{dn}}->{telephonenumber} ) {
      log_debug { np( $entry->{$arg->{dn}}->{telephonenumber} ) };
      push @vcf, sprintf('%s%s', $tel_prefix, $_)
	foreach (@{$entry->{$arg->{dn}}->{telephonenumber}});
    }
    if ( exists $entry->{$arg->{dn}}->{mobiletelephonenumber} ) {
      log_debug { np( $entry->{$arg->{dn}}->{mobiletelephonenumber} ) };
      push @vcf, sprintf('%s%s', $tel_prefix, $_)
	foreach (@{$entry->{$arg->{dn}}->{mobiletelephonenumber}});
    }
    if ( exists $entry->{$arg->{dn}}->{mobile} ) {
      log_debug { np( $entry->{$arg->{dn}}->{mobile} ) };
      push @vcf, sprintf('%s%s', $tel_prefix, $_)
	foreach (@{$entry->{$arg->{dn}}->{mobile}});
    }
    if ( exists $entry->{$arg->{dn}}->{facsimiletelephonenumber} ) {
      log_debug { np( $entry->{$arg->{dn}}->{facsimiletelephonenumber} ) };
      push @vcf, sprintf('%s%s', $tel_prefix, $_)
	foreach (@{$entry->{$arg->{dn}}->{facsimiletelephonenumber}});
    }

    log_debug { np(@vcf) };
    
    my $scope = $arg->{dn} =~ /^.*=.*,authorizedService.*$/ ? 'sub' : 'one';

    # --- EMAIL -------------------------------------------------------
    if ( $entry->{$arg->{dn}}->{mail} ) {
      push @vcf, sprintf('EMAIL:%s', $_)
	foreach (@{$entry->{$arg->{dn}}->{mail}});
    }

    $branch = $self->ldap->search ( base   => $arg->{dn},
				    scope  => $scope,
				    filter => 'authorizedService=mail@*', );
    if ($branch->is_error()) {
      $return->{error} .= $self->err( $branch )->{html};
    } elsif ( $branch->count) {
      foreach $branch_entry ( $branch->entries ) {
	$leaf = $self->search ( { base  => $branch_entry->dn,
				  scope => $scope ne 'one' ? 'base' : 'one', } );
	if ($leaf->is_error()) {
	  $return->{error} .= $self->err( $leaf )->{html};
	} else {
	  if ( $leaf->count ) {
	    push @vcf, sprintf('EMAIL:%s', $_->get_value('uid'))
	      foreach ( $leaf->entries );
	  }
	}
      }
    }

    # --- XMPP --------------------------------------------------------
    $branch = $self->ldap->search ( base   => $arg->{dn},
    				    scope  => $scope,
    				    filter => 'authorizedService=xmpp@*', );
    if ($branch->is_error()) {
      $return->{error} .= $self->err( $branch )->{html};
    } elsif ( $branch->count) {
      foreach $branch_entry ( $branch->entries ) {
    	$leaf = $self->search ( { base  => $branch_entry->dn,
    				  scope => $scope ne 'one' ? 'base' : 'one', } );
    	if ($leaf->is_error()) {
    	  $return->{error} .= $self->err( $leaf )->{html};
    	} else {
    	  if ( $leaf->count ) {
    	    push @vcf, sprintf('X-JABBER;HOME:%s', $_->get_value('uid'))
    	      foreach ( $leaf->entries );
    	  }
    	}
      }
    }

    if ( $arg->{type} eq 'file' ) {
      # push @vcf, sprintf('PHOTO:data:image/jpeg;base64,%s',
      my $meta_photo = encode_base64( $entry->{$arg->{dn}}->{jpegphoto}->[0] );
      $meta_photo =~ s/\n/\n /g;
      $meta_photo = substr $meta_photo, 0, -1;
      # log_debug { np( $meta_photo ) };
      push @vcf, sprintf('PHOTO;ENCODING=BASE64;JPEG:%s', $meta_photo)
	if $entry->{$arg->{dn}}->{jpegphoto};
    }

    push @vcf, 'END:VCARD';

    
    $return->{success} .= sprintf('vCard generated for object with DN: <b class="mono"><em>%s</em></b>.', $arg->{dn} );
    
    $return->{dn}           = $arg->{dn};
    $return->{type}         = $arg->{type};
    $return->{vcard}        = join("\n", @vcf);
    $return->{outfile_name} = $entry->{$arg->{dn}}->{uid}->[0];
  }

  if ( $arg->{type} ne 'file' ) {
    my $qr;
    for ( my $i = 0; $i < 41; $i++ ) {
      $qr = $self->qrcode({ txt => $return->{vcard}, ver => $i, mod => 5 });
      last if ! exists $qr->{error};
    }
    
    $return->{qr} =
      sprintf('<img alt="QR for DN %s" src="data:image/jpg;base64,%s" class="img-responsive img-thumbnail" title="QR for DN %s"/>',
	      $arg->{dn}, $qr->{qr}, $arg->{dn} );
  }

  # p @vcard; p $return->{vcard};
  return $return;
}






sub vcard {
  my ($self, $args) = @_;

  my $ts = strftime "%Y%m%d%H%M%S", localtime;
  my $arg = { dn => $args->{vcard_dn},
	      type => $args->{vcard_type},
	      translit => $args->{vcard_translit} || 0, };

  my ($msg, $branch, @branches, $branch_entry, $leaf, @leaves, $leaf_entry, $entry, @entries, @vcard, $return, $tmp);
  $msg = $self->ldap->search ( base => $arg->{dn}, scope => 'base', filter => 'objectClass=*', );
  if ($msg->is_error()) {
    $return->{error} .= $self->err( $msg )->{html};
  } else {
    push @vcard, 'BEGIN:VCARD', 'VERSION:3.0';
    $entry = $msg->as_struct;

    $arg->{sn} = $self->utf2qp( $entry->{$arg->{dn}}->{sn}->[0], $arg->{translit} );
    $arg->{givenName} = $self->utf2qp( $entry->{$arg->{dn}}->{givenname}->[0], $arg->{translit} );
    
    push @vcard, sprintf('N%s:%s;%s;;;',
			 $arg->{sn}->{type} eq 'qp' ? ';CHARSET=UTF-8;ENCODING=QUOTED-PRINTABLE' : '',
			 $arg->{givenName}->{str}, $arg->{sn}->{str} );

    $tmp = $arg->{sn}->{type} eq 'qp' || $arg->{givenNme}->{type} eq 'qp' ?
      encode_qp( sprintf('%s %s', $entry->{$arg->{dn}}->{givenname}->[0], $entry->{$arg->{dn}}->{sn}->[0]), '' ) :
      sprintf('%s %s', $arg->{givenName}->{str}, $arg->{sn}->{str});

    # $tmp = $self->utf2qp( sprintf('%s %s',
    # 				  $entry->{$arg->{dn}}->{givenname}->[0],
    # 				  $entry->{$arg->{dn}}->{sn}->[0]),
    # 			  $arg->{translit} );
    
    push @vcard,
      sprintf('FN%s:%s',
	      # $tmp->{type} eq 'qp' ?
	      $arg->{sn}->{type} eq 'qp' || $arg->{givenNme}->{type} eq 'qp' ?
	      ';CHARSET=UTF-8;ENCODING=QUOTED-PRINTABLE' : '',
	      $tmp); # ->{str});

    # --- TITLE -------------------------------------------------------
    if ( $entry->{$arg->{dn}}->{title} ) {
      ## alas, for many cases vCard contains only one title per contact
      # remove? #  foreach ( @{$entry->{$arg->{dn}}->{title}} ) {
      # remove? #  	$arg->{title} = $self->utf2qp( $_, $arg->{translit} );
      # remove? #  	push @{$arg->{vcard}->{title}},
      # remove? #  	  sprintf('TITLE%s:%s',
      # remove? #  		  $arg->{title}->{type} eq 'qp' ? ';CHARSET=UTF-8;ENCODING=QUOTED-PRINTABLE' : '',
      # remove? #  		  $arg->{title}->{str}, $arg->{title}->{str} );
      # remove? #  }
      $arg->{title} = $self->utf2qp( $entry->{$arg->{dn}}->{title}->[0], $arg->{translit} );
      push @vcard, 
	sprintf('TITLE%s:%s',
		$arg->{title}->{type} eq 'qp' ? ';CHARSET=UTF-8;ENCODING=QUOTED-PRINTABLE' : '',
		$arg->{title}->{str}, $arg->{title}->{str} );
    }

    # --- ORGANIZATION ------------------------------------------------
    if ( $entry->{$arg->{dn}}->{o} ) {
      ## alas, for many cases vCard contains only one organization per contact
      # remove? # foreach ( @{$entry->{$arg->{dn}}->{o}} ) {
      # remove? # 	$tmp = $self->search ( { base => $_, scope => 'base', } );
      # remove? # 	if ($tmp->is_error()) {
      # remove? # 	  $return->{error} .= $self->err( $tmp )->{html};
      # remove? # 	} else {
      # remove? # 	  my $org = $tmp->as_struct;
      # remove? # 	  $arg->{o} = $self->utf2qp( $org->{$_}->{physicaldeliveryofficename}->[0], $arg->{translit} );
      # remove? # 	  push @{$arg->{vcard}->{o}},
      # remove? # 	    sprintf('ORG%s:%s',
      # remove? # 		    $arg->{o}->{type} eq 'qp' ? ';CHARSET=UTF-8;ENCODING=QUOTED-PRINTABLE' : '',
      # remove? # 		    $arg->{o}->{str}, $arg->{o}->{str} );
      # remove? # 	}
      # remove? # }
      # remove? # $arg->{vcard}->{o} = join("\n", @{$arg->{vcard}->{o}});
      # remove? # push @vcard, $arg->{vcard}->{o};

      $tmp = $self->search ( { base => $entry->{$arg->{dn}}->{o}->[0], scope => 'base', } );
      if ($tmp->is_error()) {
	$return->{error} .= $self->err( $tmp )->{html};
      } else {
	my $org = $tmp->as_struct;
	$arg->{o} = $self->utf2qp( $org->{$entry->{$arg->{dn}}->{o}->[0]}->{physicaldeliveryofficename}->[0], $arg->{translit} );
	push @vcard,
	  sprintf('ORG%s:%s',
		  $arg->{o}->{type} eq 'qp' ? ';CHARSET=UTF-8;ENCODING=QUOTED-PRINTABLE' : '',
		  $arg->{o}->{str}, $arg->{o}->{str} );
      }
    }

    # --- TELEPHONENUMBER ---------------------------------------------
    if ( $entry->{$arg->{dn}}->{telephonenumber} ) {
      push @{$arg->{vcard}->{telephonenumber}},
	map { sprintf('TEL;TYPE=WORK:%s', $_) } @{$entry->{$arg->{dn}}->{telephonenumber}};

      $arg->{vcard}->{telephonenumber} = join("\n", @{$arg->{vcard}->{telephonenumber}});
      push @vcard, $arg->{vcard}->{telephonenumber};
    }
    if ( $entry->{$arg->{dn}}->{mobiletelephonenumber} ) {
      push @{$arg->{vcard}->{mobiletelephonenumber}},
	map { sprintf('TEL;TYPE=CELL:%s', $_) } @{$entry->{$arg->{dn}}->{mobiletelephonenumber}};

      $arg->{vcard}->{mobiletelephonenumber} = join("\n", @{$arg->{vcard}->{mobiletelephonenumber}});
      push @vcard, $arg->{vcard}->{mobiletelephonenumber};
    }
    if ( $entry->{$arg->{dn}}->{mobile} ) {
      push @{$arg->{vcard}->{mobile}},
	map { sprintf('TEL;TYPE=CELL:%s', $_) } @{$entry->{$arg->{dn}}->{mobile}};

      $arg->{vcard}->{mobile} = join("\n", @{$arg->{vcard}->{mobile}});
      push @vcard, $arg->{vcard}->{mobile};
    }

    
    my $scope = $arg->{dn} =~ /^.*=.*,authorizedService.*$/ ? 'sub' : 'one';
    
    # --- EMAIL -------------------------------------------------------
    if ( $entry->{$arg->{dn}}->{mail} ) {
      push @{$arg->{vcard}->{email}},
	map { sprintf('EMAIL;TYPE=WORK:%s', $_) } @{$entry->{$arg->{dn}}->{mail}};

      $arg->{vcard}->{email} = join("\n", @{$arg->{vcard}->{email}});
      push @vcard, $arg->{vcard}->{email};
    }
    $branch = $self->ldap->search ( base => $arg->{dn}, scope => $scope, filter => 'authorizedService=mail@*', );
    if ($branch->is_error()) {
      $return->{error} .= $self->err( $branch )->{html};
    } elsif ( $branch->count) {
      @branches = $branch->entries;
      foreach $branch_entry ( @branches ) {
	$leaf = $self->search ( { base => $branch_entry->dn, scope => $scope ne 'one' ? 'base' : 'one', } );
	if ($leaf->is_error()) {
	  $return->{error} .= $self->err( $leaf )->{html};
	} else {
	  if ( $leaf->count ) {
	    @leaves = $leaf->entries;
	    foreach $leaf_entry ( @leaves ) {
	      {
		push @{$arg->{email}}, 'EMAIL;TYPE=WORK:' . $leaf_entry->get_value('uid');
	      }
	    }
	  }
	}
      }
      push @vcard, join("\n", @{$arg->{email}});
    }
    
    # --- XMPP --------------------------------------------------------
    $branch = $self->ldap->search ( base => $arg->{dn}, scope => $scope, filter => 'authorizedService=xmpp@*', );
    if ($branch->is_error()) {
      $return->{error} .= $self->err( $branch )->{html};
    } elsif ( $branch->count) {
      @branches = $branch->entries;
      foreach $branch_entry ( @branches ) {
	$leaf = $self->search ( { base => $branch_entry->dn, scope => $scope ne 'one' ? 'base' : 'one', } );
	if ($leaf->is_error()) {
	  $return->{error} .= $self->err( $leaf )->{html};
	} else {
	  if ( $leaf->count ) {
	    @leaves = $leaf->entries;
	    foreach $leaf_entry ( @leaves ) {
	      {
		push @{$arg->{xmpp}}, 'X-JABBER;TYPE=WORK:' . $leaf_entry->get_value('uid');
	      }
	    }
	  }
	}
      }
      push @vcard, join("\n", @{$arg->{xmpp}});
    }

    $return->{success} .= sprintf('vCard generated for object with DN: <b class="mono"><em>%s</em></b>.', $arg->{dn} );
  }
  $return->{outfile_name} = join('_', split(/,/,canonical_dn($arg->{dn}, casefold => 'none', reverse => 1, )));
  $return->{dn} = $arg->{dn};
  $return->{type} = $arg->{type};

  if ( $arg->{type} eq 'file' ) {
    push @vcard,
      sprintf('PHOTO;ENCODING=BASE64;JPEG:%s',
	      encode_base64( $entry->{$arg->{dn}}->{jpegphoto}->[0] ))
      if $entry->{$arg->{dn}}->{jpegphoto};
  }

  push @vcard, 'REV:' . $ts . 'Z', 'END:VCARD';
  $return->{vcard} = join("\n", @vcard);

  if ( $arg->{type} ne 'file' ) {
    my $qr;
    for ( my $i = 0; $i < 41; $i++ ) {
      $qr = $self->qrcode({ txt => $return->{vcard}, ver => $i, mod => 5 });
      last if ! exists $qr->{error};
    }
    
    $return->{qr} =
      sprintf('<img alt="QR for DN %s" src="data:image/jpg;base64,%s" class="img-responsive img-thumbnail" title="QR for DN %s"/>',
	      $arg->{dn}, $qr->{qr}, $arg->{dn} );
  }
  # p @vcard; p $return->{vcard};
  return $return;
}


=head2 obj_schema

!!! DEPRECATED !!! moved to the session data (in Controller/Auth.pm)


LDAP object schema and data

returned structure is hash of all mandatory and optional attributes of
all objectClass-es of the object:

    $VAR1 = {
      'DN1' => {
        'objectClass1' => {
          'must' => {
            'mustAttr1' => {
              'equality' => ...,
              'desc' => ...,
              'single-value' => ...,
              'attr_value' => ...,
              'max_length' => ...,
            },
            'mustAttrN' {
            ...
            },
           },
           'may' => {
             'mayAttr1' => {
               'equality' => ...,
               'desc' => ...,
               'single-value' => ...,
               'attr_value' => ...,
               'max_length' => ...,
             },
             'mayAttrN' {
             ...
             },
           },
        },
        'objectClass2' => {
        ...
        },
      },
      'DN2' => {
      ...
      },
    }

Commonly, we will wish to use it for the single object to build the
form to add or modify

TODO

to add error correction

=cut

sub obj_schema {
  my ($self, $args) = @_;

  if ( defined $args->{dn} &&
       $args->{dn} ne '' ) {
    my @args_arr = split(/,/, $args->{dn});
    $args->{filter} = shift @args_arr;
    $args->{base} = join(',', @args_arr);
    $args->{scope} = 'one';
  }

  my $arg = {
  	     base   => $args->{base},
  	     scope  => $args->{scope} || 'one',
  	     filter => $args->{filter},
  	    };

  my $mesg  =
    $self->ldap->search(
			base   => $arg->{base},
			scope  => $arg->{scope},
			filter => $arg->{filter},
		       );

  my @entries = $mesg->entries;

  my ( $must, $may, $obj_schema, $names, $syntmp );
  foreach my $entry ( @entries ) {
    foreach my $objectClass ( $entry->get_value('objectClass') ) {
      next if $objectClass eq 'top';
      foreach $must ( $self->schema->must ( $objectClass ) ) {
	$syntmp = $self->schema->attribute_syntax($must->{'name'});
	$obj_schema->{$entry->dn}->{$objectClass}->{'must'}
	  ->{ $must->{'name'} } =
	    {
	     'attr_value'   => $entry->get_value( $must->{'name'} ) || undef,
	     'desc'         => $must->{'desc'} || undef,
	     'single-value' => $must->{'single-value'} || undef,
	     'max_length'   => $must->{'max_length'} || undef,
	     'equality'     => $must->{'equality'} || undef,
	     'syntax'       => { desc => $syntmp->{desc},
				 oid =>  $syntmp->{oid}, },
	     # 'syntax' => $must->{'syntax'} || undef,
	     # 'attribute' => $self->schema->attribute($must->{'name'}) || undef,
	    };
	# $obj_schema->{$entry->dn}->{'equality'}->{$must->{'name'}} =
	#   $obj_schema->{$entry->dn}->{$objectClass}->{'must'}->{$must->{'name'}}->{'equality'};
      }

      foreach $may ( $self->schema->may ( $objectClass ) ) {
	$syntmp = $self->schema->attribute_syntax($may->{'name'});
	$obj_schema->{$entry->dn}->{$objectClass}->{'may'}
	  ->{$may->{'name'}} =
	    {
	     'attr_value'   => $entry->get_value( $may->{'name'} ) || undef ,
	     'desc'         => $may->{'desc'} || undef ,
	     'single-value' => $may->{'single-value'} || undef ,
	     'max_length'   => $may->{'max_length'} || undef ,
	     'equality'     => $may->{'equality'} || undef ,
	     'syntax'       => { desc => $syntmp->{desc},
				 oid =>  $syntmp->{oid}, },
	     # 'syntax' => $may->{'syntax'} || undef,
	     # 'attribute' => $self->schema->attribute($may->{'name'}) || undef,
	    };
	# $obj_schema->{$entry->dn}->{'equality'}->{$may->{'name'}} =
	#   $obj_schema->{$entry->dn}->{$objectClass}->{'may'}->{$may->{'name'}}->{'equality'};
      }
    }
  }
  return $obj_schema;
}

=head2 select_key_val

returns ref on hash (mostly aimed for select form elements `options_'
method. It expects each ldapsearch result entry to be single value.

ldapsearch option `attrs' is expected to be single, lowercased
(otherwise, ->search fails, do not know why but need to verify!) value
of the attribyte for which hash to be built, DN will be the key and
the attributes value, is the value

$VAR1 = {
          'dn1' => 'attributeValue 1',
          ...
          'dnN' => 'attributeValue 1',
        }

TODO:

to add error correction

=cut

sub select_key_val {
  my ($self, $args) = @_;
  my $arg = {
	     base   => $args->{'base'},
	     filter => $args->{'filter'},
	     scope  => $args->{'scope'},
	     attrs  => $args->{'attrs'},
	    };
  my $mesg =
    $self->ldap->search(
			base   => $arg->{'base'},
			filter => $arg->{'filter'},
			scope  => $arg->{'scope'},
			attrs  => [ $arg->{'attrs'} ],
			deref  => 'never',
		       );

  my $entries = $mesg->as_struct;

  my %results;
  foreach my $key (sort (keys %{$entries})) {
    foreach my $val ( @{$entries->{$key}->{$arg->{'attrs'}}} ) {
      # $results{"$key"} = $val if ! $val =~ /[^[:ascii:]]/;
      $results{"$key"} = $val;
    }
  }
  return \%results;
}



=head2 obj_add

simple, attributes-bunch add, according the object type configured
above

returns hash with results: either success or error

=cut

sub obj_add {
  my ( $self, $args ) = @_;
  my $type   = $args->{'type'};
  my $params = $args->{'params'};

  my $attrs = $self->params2attrs({
				   type   => $type,
				   params => $params,
				  });
  my $mesg = $self->add( $attrs->{dn}, $attrs->{attrs} );

  my $callername = (caller(1))[3];
  $callername = 'main' if ! defined $callername;
  my $return;
  if ($mesg) {
      $return->{error} = $mesg->{html};
    } else {
      $return->{success} = $attrs->{dn} . " created successfully";
    }
  $return->{caller} = 'call to LDAP_CRUD->add from ' . $callername . ': ';
  return $return;
}


=head2 obj_mod

=cut

sub obj_mod {
  my ( $self, $args ) = @_;
  my $type = $args->{'type'};
  my $params = $args->{'params'};

  return '' unless %{$params};

  my $attrs = $self->params2attrs({
				   type   => $type,
				   params => $params,
				  });

  my $mesg = $self->mod(
			$attrs->{'dn'},
			$attrs->{'attrs'}
		       );
  my $message;
  if ( $mesg ) {
    $message .= '<div class="alert alert-danger">' .
      '<span style="font-size: 140%" class="icon_error-oct" aria-hidden="true"></span>&nbsp;' .
	'Error during ' . $type . ' object modify occured: ' . $mesg . '</div>';

    warn sprintf('object dn: %s wasn notmodified! errors: %s', $attrs->{'dn'}, $mesg);
  } else {
    $message .= '<div class="alert alert-success">' .
      '<span style="font-size: 140%" class="fas fa-check-circle"></span>' .
	'&nbsp;Object <em>&laquo;' . $self->utf2lat( $params->{'physicalDeliveryOfficeName'} ) .
	    '&raquo;</em> of type <em>&laquo;' . $type .
	      '&raquo;</em> was successfully modified.</div>';
  }

  # warn 'FORM ERROR' . $final_message if $final_message;
  # $self->unbind;

  warn 'LDAP ERROR' . $mesg if $mesg;
  return { message => $message };
}


=head2 params2attrs

??? candidate for removal ???

crawls all $c->req->params and prepares attrs hash ref of dn and attrs
to be fed to ->add for object creation

=cut

sub params2attrs {
  my ( $self, $args ) = @_;

  my $arg = {
	     type   => $args->{'type'},
	     params => $args->{'params'},
	    };

  my ( $key, $val, $dn, $base, $attrs );

  $base = ( defined $arg->{'params'}->{'aux_parent'} &&
	    $arg->{'params'}->{'aux_parent'} ne '' ) ?
    $arg->{'params'}->{'aux_parent'} :
      $self->{'cfg'}->{'base'}->{$arg->{'type'}};

  push @{$attrs}, objectClass => $self->{'cfg'}->{'objectClass'}->{$arg->{'type'}};

  foreach my $key (keys %{$arg->{'params'}}) {
    next if $key =~ /^$self->{'cfg'}->{'exclude_prefix'}/;
    next if $arg->{'params'}->{$key} eq '';
    next if $key eq ( 'org' || 'act' );

    #
    ## TODO
    ## to add multivalue fields processing
    ## to process upload fields
    $val = $self->is_ascii( $arg->{params}->{$key} ) &&
      ! $self->{cfg}->{translit_no}->{$key} ?
      $self->utf2lat( $arg->{params}->{$key} ) : $arg->{params}->{$key};

    # build DN for org
    if ( $arg->{type} eq 'org' && $key eq 'ou' ) {
      $dn = sprintf('%s=%s,%s', $key, $val, $base);
    }

    $val =~ s/^\s+|\s+$//g;
    push @{$attrs}, $key => $val;
  }
  # warn 'attributes prepared, dn: ' . $dn . '; $attrs:' . Dumper($attrs);
  return { dn    => $dn,
	   attrs => $attrs };
}

=head2 dhcp_lease

!!! TO BE REPLACED WITH ipam_used

method to stat used static DHCP leases (isc-dhcpd layout)

info gathered:

    - available (unused) IP addresses
    - used leases

the base for leases is DHCP network object generated by isc-dhcpd
script `dhcpd-conf-to-ldap'

    cn=172.16.0.0,cn=XXX01 DHCP Config,ou=XXX01,...,ou=ZZZ,ou=DHCP,dc=umidb

each net expected to contain own uniq domain-name, if not specified
then net DN is expected to be set

logic for lease assignment is:

user -> org of user -> domain/s of org of user -> DHCP net for the domain
     |                                         ^
     +-----------------------------------------|

arguments method expects

    fqdn  => fqdn of the network
    netdn => DN of the network to pick the lease up from
    what  => keyword, one of: used, ip, mac, hostname, all (the type of data to return)

method returns such a hash:

for `what' equal to `all':

    {
        available   [
            [0]  2886744327,
            ...
            [78] 2886744419
        ],
        net_dn      "cn=172.16.57.0,cn=cube01 DHCP Config,ou=cube01,ou=borg,ou=DHCP,dc=umidb",
        used        {
            hostname   {
                host001   {
                    ip    2886744325,
                    mac   "00:24:21:9c:37:2a"
                },
                ...,
                zd_av02        {
                    ip    2886744363,
                    mac   "70:71:bc:6d:50:59"
                }
            },
            ip         {
                2886744322   {
                    hostname   "sw",
                    mac        "00:23:cd:19:32:03"
                },
                ...,
                2886744574   {
                    hostname   "wrt54gl",
                    mac        "00:25:9c:4b:b6:95"
                }
            },
            mac        {
                1c:c1:de:ca:46:a5   {
                    hostname   "hplj2055",
                    ip         2886744350
                },
                ...,
                e8:b7:48:16:4b:f2   {
                    hostname   "ipp431",
                    ip         2886744335
                }
            }
        }
    }

where key

`available' is a list of unused IP addresses in form of IPv4-to-decimal

`used' is hash of hashes with all details for each IP address used


=cut


sub dhcp_lease {
  my ( $self, $args ) = @_;
  my ($return, $mesg);
  my $arg = {
	     net_addr => $args->{net_addr} || '',
	     net_mask => $args->{net_mask} || '',
	     net_rnge => $args->{net_rnge} || '',
	     netdn    => $args->{netdn} || '',
	     net      => $args->{net} || '',
	     fqdn     => $args->{fqdn} || '',
	     what     => $args->{what} || 'stub', # used, ip, mac, hostname, all
	    };

  my ( $i, $net_addr, $addr_num, $rnge, @leases, $lease, $ip, $mac, $hostname );
  $return->{net_dn} = $arg->{netdn};
  $net_addr = $self->ipam_ip2dec( $arg->{net_addr} );
  $addr_num = 2 ** ( 32 - $arg->{mask});
  ( $rnge->{l}, $rnge->{r} ) = split(" ", $arg->{range});
  $rnge->{l} = $self->ipam_ip2dec( $rnge->{l} );
  $rnge->{r} = $self->ipam_ip2dec( $rnge->{r} );

  $mesg = $self->search({ base      => $arg->{netdn},
			  scope     => 'children',
			  attrs     => [ 'cn', 'dhcpStatements', 'dhcpHWAddress' ],
			  sizelimit => 0, });

  @leases = $mesg->sorted('dhcpStatements');
  foreach ( @leases ) {
    $ip = $self->ipam_ip2dec( (split(/\s+/, $_->get_value('dhcpStatements')))[1] );
    $mac = (split(/\s+/, $_->get_value('dhcpHWAddress')))[1];
    $hostname = $_->get_value('cn');

    $return->{used}->{ip}->{$ip}->{mac} = $mac;
    $return->{used}->{ip}->{$ip}->{hostname} = $hostname;
    $return->{used}->{mac}->{$mac}->{ip} = $ip;
    $return->{used}->{mac}->{$mac}->{hostname} = $hostname;
    $return->{used}->{hostname}->{$hostname}->{ip} = $ip;
    $return->{used}->{hostname}->{$hostname}->{mac} = $mac;
  }
  ## ip counting starts from the *second* assignable (not the net
  ## address and not broadcast) the first address is reserved for
  ## the very DHCP server needs
  for ($i = $net_addr + 1 + 1; $i < ($net_addr + $addr_num - 1); $i++) {
    next if $return->{used}->{ip}->{$i} || ( $i >= $rnge->{l} && $i <= $rnge->{r} );
    push @{$return->{available}}, $i;
  }

  if ( defined $arg->{what} && $arg->{what} eq 'ip' ) {
    return $return->{used}->{ip};
  } elsif ( defined $arg->{what} && $arg->{what} eq 'mac' ) {
    return $return->{used}->{mac};
  } elsif ( defined $arg->{what} && $arg->{what} eq 'hostname' ) {
    return $return->{used}->{hostname};
  } elsif ( defined $arg->{what} && $arg->{what} eq 'all' ) {
    return $return;
  } elsif ( defined $arg->{what} && $arg->{what} eq 'used' ) {
    return $return->{used};
  } else {
    return [ map $self->ipam_dec2ip( $_ ), sort(@{$return->{available}}) ]; # decimal to IPv4
  }
}

=head2 ipam_used

!!! TO BE FIXED

method to find all IP Addresses Used for a network requested

info gathered:

    - available (unused) IP addresses
    - used ip addresses

arguments (returned with results as well) expected:

     svc: type STRING
          service identificator

   netdn: DN of the network to process

    fqdn: fqdn of the network provided by `svc' service

    base: type STRING
          base to do search against, in general it is LDAP_CRUD::cfg->{base}->{...}

  filter: type STRING
          filter to do search with
          for DHCP
          (&(objectClass=dhcpSubnet)(dhcpOption=domain-name "FQDN related to the subnet"))
          for OpenVPN
          (&(authorizedService=ovpn@FQDN.related.to.the.subnet)(cn=*))

   attrs: type ARRAYREF
          attributes to return

the method returns hash like this:

    {
      arg       {
        attrs    [
          [0] "cn",
          [1] "umiOvpnCfgServer",
          [2] "umiOvpnCfgRoute"
        ],
        base     "ou=OpenVPN,dc=umidb",
        filter   "(&(authorizedService=ovpn@talax.startrek.in)(cn=*))",
        fqdn     "talax.startrek.in",
        svc      "ovpn"
      },
      ip_used   [
        [0] "10.34.5.5/30"
      ],
      ipspace   [
        [0] "10.32.0.0/16",
        [1] "10.32.0.0/12"
      ]
    }

=cut

sub ipam_used {
  my ( $self, $args ) = @_;
  my $arg = { svc    => $args->{svc}   // 'ovpn',
	      netdn  => $args->{netdn},
	      fqdn   => $args->{fqdn}  // '',
	      base   => $args->{base},
	      filter => $args->{filter},
	      scope  => $args->{scope} // 'base',
	      attrs  => $args->{attrs},
	    };
  log_debug { np($arg) };
  my $return;
  $return->{arg} = $arg;

  my ( $key, $val, $k, $v, $l, $r, $tmp, $entry_svc, $entry_dhcp, $entry_ovpn, $ipspace, $ip_used );

  if ( $arg->{svc} ne 'dhcp' && $arg->{svc} ne 'ovpn' ) {
    $return->{error} = 'ipam_used(): incorrect value of option: svc.';
    return $return;
  }

  my $mesg_svc = $self->search({ base   => $arg->{base},
				 filter => $arg->{filter},
				 scope  => $arg->{scope},
				 attrs  => $arg->{attrs}, });
  if ( $mesg_svc->code ) {
    #    $return->{error} = sprintf("ipam_used(): No %s configuration for %s found .", uc( $arg->{svc} ), $arg->{netdn});
    push @{$return->{error}}, $self->err($mesg_svc)->{html};
    log_error { sprintf("%s : %s : %s", $self->err($mesg_svc)->{name},
			$self->err($mesg_svc)->{desc},
			$self->err($mesg_svc)->{text}) };
    return $return;
  } else {
    # !!! TODO case when no host configured yet
    foreach $entry_svc (@{[ $mesg_svc->as_struct ]}) {
      # log_debug { np($entry_svc) };
      while ( ($key, $val) = each %{$entry_svc} ) {

	#--- SERVICE: DHCP -------------------------------------------------------------------------
	if ( $arg->{svc} eq 'dhcp' ) {
	  push @{$return->{ipspace}}, $val->{cn}->[0] . '/'. $val->{dhcpnetmask}->[0];

	  # declare each dhcpRange as used space
	  my $mesg_rnge = $self->search({ base   => $arg->{base},
					  filter => '(dhcpRange=*)',
					  attrs  => [ qw( cn dhcpRange ) ], });
	  if ( $mesg_rnge->code ) {
	    push @{$return->{error}}, $self->err($mesg_rnge)->{html};
	    log_error { sprintf("%s : %s : %s", $self->err($mesg_rnge)->{name},
				$self->err($mesg_rnge)->{desc},
				$self->err($mesg_rnge)->{text}) };
	    return $return;
	  } else {
	    foreach ( @{[ $mesg_rnge->entries ]} ) {
	      ($l, $r) = split(/ /, $_->get_value('dhcpRange'));
	      $return->{iprange}->{l} = $l;
	      $return->{iprange}->{r} = $r;
	      for ( my $i = $self->ipam_ip2dec( $l ); $i < $self->ipam_ip2dec( $r ) + 1; $i++ ) {
		push @{$return->{ip_used}}, $self->ipam_dec2ip( $i ) . '/32';
	      }
	    }
	  }

	  # declare each existent lease as used ip
	  my $mesg_dhcp = $self->search({ base      => $key,
					  filter    => 'dhcpStatements=fixed-address*',
					  sizelimit => 0,
					  attrs     => [ 'dhcpStatements', 'dhcpHWAddress' ], });
	  if ( $mesg_dhcp->code ) {
	    push @{$return->{error}}, sprintf("ipam_used(): problems with DN: %s; error: %s", $key, $self->err($mesg_dhcp)->{html});
	    log_error { sprintf("%s : %s : %s", $self->err($mesg_dhcp)->{name},
				$self->err($mesg_dhcp)->{desc},
				$self->err($mesg_dhcp)->{text}) };
	    return $return;
	  } else {
	    foreach $entry_dhcp ( @{[ $mesg_dhcp->as_struct ]} ) {
	      while ( ($k, $v) = each %{$entry_dhcp} ) {
		foreach ( @{$v->{dhcpstatements}} ) {
		  next if $_ !~ /fixed-address/;
		  log_debug { $_ };
		  push @{$return->{ip_used}}, (split(/ /, $_))[1] . '/32';
		}
	      }
	    }
	  }
	}

	# SERVICE: OpenVPN -------------------------------------------------------------------------
	elsif ( $arg->{svc} eq 'ovpn' ) {
	  ($l, $r) = split(/ /, $val->{umiovpncfgserver}->[0]);

	  push @{$return->{ipspace}}, $l . '/' . $self->ipam_msk_ip2dec($r);

	  foreach (@{ $val->{umiovpncfgroute} }) {
	    ($l, $r) = split(/ /, $val->{umiovpncfgroute}->[0]);
	    push @{$return->{ipspace}}, $l . '/' . $self->ipam_msk_ip2dec($r);
	  }

	  my $mesg_ovpn = $self->search({ base   => $self->{cfg}->{base}->{acc_root},
					  filter => sprintf('(&(authorizedService=ovpn@%s)(cn=*))',
							    $arg->{fqdn}),
					  attrs  => [ 'umiOvpnCfgIfconfigPush', 'umiOvpnCfgIroute' ], });
	  if (! $mesg_ovpn->count) {
	    $return->{error} = sprintf("ipam_used(): Some %s dn: %s configuration missed or incorrect.", uc( $arg->{svc} ), $key);
	    return $return;
	  } else {
	    foreach $entry_ovpn (@{[ $mesg_ovpn->as_struct ]}) {
	      log_debug { np($entry_ovpn) };
	      while ( ($k, $v) = each %{$entry_ovpn} ) {
		($l, $r) = split(/ /, $v->{umiovpncfgifconfigpush}->[0]);

		push
		  @{$return->{ip_used}},
		  $self->ipam_ip2dec($r) - $self->ipam_ip2dec($l) == 1 ?
		  $l . '/30' : $l . '/32';
		if ( defined $v->{umiovpncfgiroute} ) {
		  foreach (@{ $v->{umiovpncfgiroute} }) {
		    ($l, $r) = split(/ /, $_);
		    push @{$return->{ip_used}}, $l . '/' . $self->ipam_msk_ip2dec($r);
		  }
		}
	      }
	    }
	  }
	}
	#log_debug { np($return) };
      } # while end
    } # foreach end
  }
  return $return;
}

=head2 ipa

method to retieve IP addresses used and unused

if option naddr is passed, then unused addresses are returned (naddr
is expected to be first 3 bytes of one single /24 network)

=cut

sub ipa {
  my ( $self, $args ) = @_;
  my $arg = { svc    => $args->{svc}    // 'ovpn',
	      naddr  => $args->{naddr}  // '',
	      fqdn   => $args->{fqdn}   // '*',
	      base   => $args->{base}   // $self->{cfg}->{base}->{ovpn},,
	      filter => $args->{filter} // '(&(objectClass=umiOvpnCfg)(cn=*))',
	      scope  => $args->{scope}  // 'base',
	      attrs  => $args->{attrs}  // [ 'cn', 'umiOvpnCfgServer', 'umiOvpnCfgRoute' ],
	    };
  # log_debug { np($arg) };
  my $return;
  $return->{arg} = $arg;

  my ( $key, $val, $k, $v, $l, $r, $f, $tmp, $entry_svc, $entry_dhcp, $entry_ovpn, $ipspace, $ip_used );

  my $ipa = Net::CIDR::Set->new;

  if ( $arg->{naddr} =~ /$self->{a}->{re}->{net2b}/ || $arg->{naddr} =~ /$self->{a}->{re}->{net3b}/ ) {
    $f = sprintf('(|(umiOvpnCfgIfconfigPush=*%s.*)(umiOvpnCfgIroute=%s.*)(dhcpStatements=fixed-address %s.*)(ipHostNumber=%s.*))',
		 $arg->{naddr},
		 $arg->{naddr},
		 $arg->{naddr},
		 $arg->{naddr},
		 $arg->{fqdn});
  } else {
    $f = sprintf('(|(&(authorizedService=ovpn@%s)(cn=*))(dhcpStatements=fixed-address *)(ipHostNumber=*))',
		 $arg->{fqdn});
  }

  my $mesg_ovpn = $self->search({ base      => $self->{cfg}->{base}->{db},
				  sizelimit => 0,
  				  filter    => $f,
  				  attrs     => [ qw( umiOvpnCfgIfconfigPush
						     umiOvpnCfgIroute
						     ipHostNumber
						     dhcpStatements ) ], });
  if (! $mesg_ovpn->count) {
    $return->{error} = sprintf("ipa(): Some %s dn: %s configuration missed or incorrect.",
			       uc( $arg->{svc} ), $key);
    # log_debug { np($return) };
    return $return;
  } else {
    $val = $mesg_ovpn->as_struct;
    # log_debug { np($val) };
    foreach $key (keys ( %{$val} )) {
      undef $l;
      undef $r;

      # log_debug { np($key) };
      # log_debug { np($val->{$key}) };

      # OpenVPN option --ifconfig-push local remote-netmask [alias]
      if ( exists $val->{$key}->{umiovpncfgifconfigpush} ) {
	foreach ( @{$val->{$key}->{umiovpncfgifconfigpush}} ) {
	  # log_debug { np($_) };
	  ($l, $r, $tmp) = split(/ /, $_);
	  if ( $self->ipam_ip2dec($r) - $self->ipam_ip2dec($l) == 1 ) {
	    $ipa->add($l . '/30');
	  } else {
	    $ipa->add($l);
	  }
	}
	undef $tmp;
      }

      # OpenVPN option  --iroute network [netmask]
      # Generate an internal route to a specific client.
      # The netmask parameter, if omitted, defaults to 255.255.255.255.
      if ( exists $val->{$key}->{umiovpncfgiroute} ) {
	foreach ( @{$val->{$key}->{umiovpncfgiroute}} ) {
	  next if $_ eq 'NA';
	  # log_debug { np($_) };
	  ($l, $r) = split(/ /, $_);
	  if ( length($r) == 0 ) {
            $ipa->add($l);
          } else {
            $ipa->add($l . '/' . $self->ipam_msk_ip2dec($r));
          }
	}
      }

      # ISC DHCP Manual Pages - dhcpd.conf
      # The fixed-address declaration `fixed-address address [, address ... ];`
      # The fixed-address declaration is used to assign one or more fixed IP addresses to a client.
      # BUT WE EXPECT ONE SINGLE IP ADDRESS
      if ( exists $val->{$key}->{dhcpstatements} ) {
      	foreach ( @{$val->{$key}->{dhcpstatements}} ) {
      	  next if $_ !~ /^fixed-address/;
	  # log_debug { np($_) };
      	  ($l, $r) = split(/ /, $_);
      	  $ipa->add($r);
      	}
      }

      if ( exists $val->{$key}->{iphostnumber} ) {
	foreach ( @{$val->{$key}->{iphostnumber}} ) {
	  next if $_ eq 'NA' || ! $self->is_ip($_);
	  # log_debug { np($_) };
	  $ipa->add($_);
	}
      }

    }
  }

  # log_debug { np(@{[$ipa->as_address_array]}) };

  # log_debug { np($arg) };
  if ( length($arg->{naddr}) > 0 ) {
    my $re_net3b = $self->{a}->{re}->{net3b};
    my $net_sufix;
    if ( $arg->{naddr} =~ /$self->{a}->{re}->{net3b}/ ) {
      $net_sufix = '.0/24';
    } elsif ( $arg->{naddr} =~ /$self->{a}->{re}->{net2b}/ ) {
      $net_sufix = '.0.0/16';
    }
    # log_debug { $arg->{naddr} . ' - ' . $net_sufix };
    my $ipa_this = Net::CIDR::Set->new;
    $ipa_this->add($arg->{naddr} . $net_sufix);
    my $xset = $ipa_this->diff($ipa);
    # log_debug { np(@{[$xset->as_address_array]}) };
    $ipa = $xset;
  }

  my $ipa_tree = Noder->new();
  foreach ( @{[ $ipa->as_address_array ]} ) {
    $tmp = join(',', reverse split(/\./, $_));
    # log_debug{ np($tmp) };
    $key = $ipa_tree->insert($tmp);
    # log_debug{ np($key->dn) };
  }
  # my $as_str = $ipa_tree->as_string;
  # log_debug { np($as_str) };
  my $as_hash = $ipa_tree->as_json_ipa(1);
  # log_debug { np($as_hash) };
  $return->{ipa} = length($arg->{naddr}) > 0 ? $as_hash->{children}->[0]->{children}->[0]->{children}->[0] : $as_hash;
  $return->{ipa} = {} if ! defined $return->{ipa};
  # log_debug { np( $return->{ipa} ) };
  return $return->{ipa};
}



######################################################################
# SELECT elements options builders
######################################################################

=head2 select_authorizedservice

options builder for select element of authorizedservice

only services with auth attribute set to 1 are considered

if they have data_fields attribute, then it is added (to implement
selective field de/activation in form

=cut

has 'select_authorizedservice' => ( traits => ['Array'],
	       is => 'ro', isa => 'ArrayRef', required => 0, lazy => 1,
	       builder => '_build_select_authorizedservice',
	     );

sub _build_select_authorizedservice {
  my $self = shift;
  my @services;

  foreach my $key ( sort {$a cmp $b} keys %{$self->cfg->{authorizedService}}) {
    if ( $self->cfg->{authorizedService}->{$key}->{auth} &&
	 defined $self->cfg->{authorizedService}->{$key}->{data_relation} &&
	 $self->cfg->{authorizedService}->{$key}->{data_relation} ne '' ) {
      push @services, {
		       value => $key,
		       label => $self->cfg->{authorizedService}->{$key}->{descr},
		       attributes =>
		       { 'data-relation' => $self->cfg->{authorizedService}->{$key}->{data_relation} },
		      } if ! $self->cfg->{authorizedService}->{$key}->{disabled};
    } elsif ( $self->cfg->{authorizedService}->{$key}->{auth} ) {
      push @services, {
		       value => $key,
		       label => $self->cfg->{authorizedService}->{$key}->{descr},
		      } if ! $self->cfg->{authorizedService}->{$key}->{disabled};
    }

  }
  return \@services;
}


=head2 select_organizations

options builder for select element of organizations

=cut

has 'select_organizations' => ( traits => ['Array'],
	       is => 'ro', isa => 'ArrayRef', required => 0, lazy => 1,
	       builder => '_build_select_organizations',
	     );

sub _build_select_organizations {
  my $self = shift;
  my (@branches, @office, $to_utfy);

  # all head offices
  my $mesg = $self->search({
			    base      => $self->{'cfg'}->{'base'}->{'org'},
			    scope     => 'one',
			    attrs     => [ qw(ou physicaldeliveryofficename l) ],
			    sizelimit => 0
			   });
  my @headOffices = $mesg->sorted('physicaldeliveryofficename');
  # branch offices
  foreach my $headOffice (@headOffices) {
    $mesg = $self->search({
			   base      => $headOffice->dn,
			   # filter    => '*',
			   attrs     => [ qw(ou physicaldeliveryofficename l) ],
			   sizelimit => 0
			  });
    my @branchOffices = $mesg->sorted( 'ou' );
    foreach my $branchOffice (@branchOffices) {
      $to_utfy = sprintf("%s (%s @ %s)",
			 $branchOffice->get_value ('ou'),
			 $branchOffice->get_value ('physicaldeliveryofficename'),
			 $branchOffice->get_value ('l')
			);
      utf8::decode($to_utfy);
      push @branches, {
		       value => $branchOffice->dn,
		       label => $to_utfy,
		      };
    }
    push @office, {
		   group => $headOffice->get_value ('physicaldeliveryofficename'),
		   options => [ @branches ],
		  };
    undef @branches;
  }
  return \@office;
}

=head2 select_associateddomains

Method, options builder for select element of associateddomains

uses sub bld_select()

=cut

has 'select_associateddomains' => ( traits => ['Array'],
	       is => 'ro', isa => 'ArrayRef', required => 0, lazy => 1,
	       builder => '_build_select_associateddomains',
	     );

sub _build_select_associateddomains {
  my $self   = shift;
  my $base   = [ $self->cfg->{base}->{org} ];
  
  # bld_select has to be fixed to deal with associatedDomains # return $self->bld_select({ base => $self->cfg->{base}->{org},
  # bld_select has to be fixed to deal with associatedDomains # 			     attr => [ 'associatedDomain', 'associatedDomain', ],
  # bld_select has to be fixed to deal with associatedDomains # 			     scope => 'sub',
  # bld_select has to be fixed to deal with associatedDomains # 			     filter => '(associatedDomain=*)', });

  my @domains; # = ( {value => '0', label => '--- select domain ---', selected => 'selected'} );

  # log_debug { np($self->user->has_attribute('o')) };
  if ( ! $self->role_admin ) {
    $base = ref($self->user->has_attribute('o')) ne 'ARRAY' ? [ $self->user->has_attribute('o') ] : $self->user->has_attribute('o');
  }

  my ($org, $mesg, $entry, @i, @j);
  my $err_message = '';
  my $return = [];
  foreach $org ( @{$base} ) {


    
    $mesg = $self->search( { base      => $org,
			     filter    => 'associatedDomain=*',
			     sizelimit => 0,
			     attrs     => ['associatedDomain' ], } );
    $err_message .= '<div class="alert alert-danger">' .
      '<i class="' . $self->{cfg}->{stub}->{icon_error} . '"></i><ul>' .
      $self->err($mesg) . '</ul></div>'
      if ! $mesg->count;

    foreach $entry ( @{[$mesg->sorted('associatedDomain')]} ) {
      @i = $entry->get_value('associatedDomain');
      push @j, $_ foreach (@i);
    }

    @domains = map { { value => $_, label => $_ } } sort @j;
    $return = [ @{$return}, @domains ];
  }
  return $return;
}

=head2 select_uid

Method, options builder for select element of uids

uses sub bld_select()

=cut

has 'select_uid' => ( traits => ['Array'], builder => '_build_select_uid',
		      is => 'ro', isa => 'ArrayRef', required => 0, lazy => 1, );

sub _build_select_uid {
  my $self = shift;
  my $mesg = $self->search( { base      => $self->cfg->{base}->{acc_root},
			      sizelimit => 0,
			      attrs     => [ 'uid' ], } );
  my $err_message = '';
  $err_message = sprintf("<div class=\"alert alert-danger\"><i class=\"%s\"></i><ul>%s</ul></div>",
			 $self->{cfg}->{stub}->{icon_error},
			 $self->err($mesg) )
    if ! $mesg->count || $mesg->is_error;

  my ($i, @i, @j);
  foreach my $entry ( $mesg->sorted('uid') ) {
    $i = $entry->get_value('uid',  asref => 1);
    push @j, $_ foreach (@{$i});
  }
  my @uids = map { { value => $_, label => $_ } } uniq sort grep {!/^.*\@.*$/} @j;

  return \@uids;
}

=head2 select_dhcp_nets

Method, options builder for select element of networks served by dhcp

=cut

has 'select_dhcp_nets' => ( traits => ['Array'],
	       is => 'ro', isa => 'ArrayRef', required => 0, lazy => 1,
	       builder => '_build_select_dhcp_nets',
	     );

sub _build_select_dhcp_nets {
  my $self = shift;
  my (@domains, @dhcp_cfg_arr, $dhcp_cfg, $dhcp_comment, @net_arr, $net);
  my $err_message = '';

  my $mesg = $self->search( { base      => $self->cfg->{base}->{dhcp},
			      filter    => '(&(objectClass=dhcpService)(cn=*))',
			      sizelimit => 0,
			      attrs     => [ qw( cn ) ],
			    } );
  if ( ! $mesg->count ) {
    $err_message =
      $self->msg2html({ type => 'panel', data => $self->err($mesg)->{html} });
  } else {
    @dhcp_cfg_arr = $mesg->sorted('cn');
    foreach $dhcp_cfg ( @dhcp_cfg_arr ) {
      $mesg = $self->search( { base      => $dhcp_cfg->dn,
			       filter    => '(&(objectClass=dhcpSubnet)(cn=*))',
			       sizelimit => 0,
			       attrs     => [ qw(cn dhcpOption dhcpNetMask dhcpComments) ],
			    } );
      if ( ! $mesg->count ) {
	$err_message =
	  $self->msg2html({ type => 'panel', data => $self->err($mesg)->{html} });
      } else {
	@net_arr = $mesg->sorted('cn');
	push @domains, { value => '--- select network assigned domain ---',
			 label => '--- select network assigned domain ---'};
	foreach $net ( @net_arr ) {
	  $dhcp_comment = $net->exists('dhcpComments') ? ' - ' . $net->get_value('dhcpComments') : '';
	  push @domains, { value => $net->dn,
			   label => sprintf("[%s]: %s %18s/%s",
					    $dhcp_cfg->get_value('cn'),
					    $net->get_value('dhcpComments') // '',
					    $net->get_value('cn'),
					    $net->get_value('dhcpNetMask')
					   )};
	}
      }
    }
  }
  return \@domains;
}

=head2 select_dhcp_associateddomains

Method, options builder for select element of dhcp domain names
assigned to networks served by dhcp

Here we assume: one dhcpSubnet -> one dhcpOption=domain-name "*"

=cut

has 'select_dhcp_associateddomains' => ( traits => ['Array'],
	       is => 'ro', isa => 'ArrayRef', required => 0, lazy => 1,
	       builder => '_build_select_dhcp_associateddomains',
	     );

sub _build_select_dhcp_associateddomains {
  my $self = shift;
  my ($net, $mask);
  
  my @domains;
  my $mesg = $self->search( { base      => $self->cfg->{base}->{dhcp},
			      filter    => '(&(objectClass=dhcpSubnet)(dhcpOption=domain-name *))',
			      sizelimit => 0,
			      attrs     => [ qw(cn dhcpOption dhcpNetMask) ],
			    } );
  my $err_message = '';

  $err_message = $self->msg2html({ type => 'panel',
				   data => $self->err($mesg)->{html} })
    if ! $mesg->count;

  my @entries = $mesg->sorted('cn');
  my (@i, @j);
  foreach my $entry ( @entries ) {
    @i = $entry->get_value('dhcpOption');
    foreach (@i) { # log_info { $_ };
      # to skip underlying objects dhcpOption values different from `domain-name'
      push @j, substr((split(/ /, $_))[1], 1, -1)
    	if $_ =~ /domain-name ".*"/;
    }
  }
  unshift @j, '--- select network assigned domain ---';
  @domains = map { { value => $_, label => $_ } } @j;

  return \@domains;
}

# to be used for service differentiated resources # =head2 select_authorizedservice_associateddomains
# to be used for service differentiated resources # 
# to be used for service differentiated resources # Method, options builder for select element of associateddomains for definite authorizedservice
# to be used for service differentiated resources # 
# to be used for service differentiated resources # uses sub bld_select()
# to be used for service differentiated resources # 
# to be used for service differentiated resources # =cut
# to be used for service differentiated resources # 
# to be used for service differentiated resources # has 'select_authorizedservice_associateddomains' => ( traits => ['Array'],
# to be used for service differentiated resources # 	       is => 'ro', isa => 'ArrayRef', required => 0, lazy => 1,
# to be used for service differentiated resources # 	       builder => '_build_select_authorizedservice_associateddomains',
# to be used for service differentiated resources # 	     );
# to be used for service differentiated resources # 
# to be used for service differentiated resources # sub _build_select_authorizedservice_associateddomains {
# to be used for service differentiated resources #   my $self = shift;
# to be used for service differentiated resources #   my (@domains, $mesg);
# to be used for service differentiated resources #   $mesg = $self->search( { base => sprintf('ou=%s,%s', $self->{cfg}->{stub}->{core_mta}, $self->{cfg}->{base}->{mta}),
# to be used for service differentiated resources # 			   filter => '(&(sendmailMTAMapName=mailer)(sendmailMTAKey=*))',
# to be used for service differentiated resources # 			   sizelimit => 0,
# to be used for service differentiated resources # 			   attrs => ['sendmailMTAKey' ],
# to be used for service differentiated resources # 			 } );
# to be used for service differentiated resources #   my $err_message = '';
# to be used for service differentiated resources #   if ( ! $mesg->count ) {
# to be used for service differentiated resources #     $err_message = '<div class="alert alert-danger">' .
# to be used for service differentiated resources #       '<span style="font-size: 140%" class="icon_error-oct" aria-hidden="true"></span><ul>' .
# to be used for service differentiated resources #       $self->err($mesg) . '</ul></div>';
# to be used for service differentiated resources #   }
# to be used for service differentiated resources # 
# to be used for service differentiated resources #   my @entries = $mesg->sorted('sendmailMTAKey');
# to be used for service differentiated resources #   my (@i, @j);
# to be used for service differentiated resources #   foreach my $entry ( @entries ) {
# to be used for service differentiated resources #     @i = $entry->get_value('sendmailMTAKey');
# to be used for service differentiated resources #     foreach (@i) {
# to be used for service differentiated resources #       push @j, $_;
# to be used for service differentiated resources #     }
# to be used for service differentiated resources #   }
# to be used for service differentiated resources #   @domains = map { { value => $_, label => $_ } } sort @j;
# to be used for service differentiated resources # 
# to be used for service differentiated resources #   return \@domains;
# to be used for service differentiated resources # }

=head2 select_group

Method, options builder for select element of groups

uses sub bld_select()

=cut

has 'select_group' => ( traits  => ['Array'],
			is      => 'ro', isa => 'ArrayRef', required => 0, lazy => 1,
			builder => '_build_select_group', );

sub _build_select_group {
  my $self = shift;
  return $self->bld_select({ base => $self->cfg->{base}->{group}, });
}


=head2 select_radprofile

Method, options builder for select element of rad-profiles

uses sub bld_select()

=cut

has 'select_radprofile' => ( traits => ['Array'],
	       is       => 'ro', isa => 'ArrayRef', required => 0, lazy => 1,
	       builder  => '_build_select_radprofile',
	     );

sub _build_select_radprofile {
  my $self = shift;
  return $self->bld_select({ base => $self->cfg->{base}->{rad_profiles}, });
}

=head2 select_radgroup

Method, options builder for select element of rad-groups

uses sub bld_select()

=cut

has 'select_radgroup'  => ( traits => ['Array'],
	       is      => 'ro', isa => 'ArrayRef', required => 0, lazy => 1,
	       builder => '_build_select_radgroup',
	     );

sub _build_select_radgroup {
  my $self = shift;
  return $self->bld_select({ base => $self->cfg->{base}->{rad_groups}, });
}


=head2 select_offices

Method, options builder for selecting offices user can be assigned to

uses sub bld_select()

=cut

has 'select_offices' => ( traits => ['Array'],
			is => 'ro', isa => 'ArrayRef', required => 0, lazy => 1,
			builder => '_build_select_offices', );

sub _build_select_offices {
  my $self = shift;
  return $self->bld_select({ base => $self->cfg->{base}->{org},
			     scope => 'sub',
#			     attr => [ 'destinationIndicator', ]});
			     attr => [ 'destinationIndicator', 'physicalDeliveryOfficeName' ]});
}


=head2 bld_select

select options builder for select element, where this select form
field needs only two attributes values

    1. cn
    2. description

it constructs array for options generation like this

    [0] { label   "bind --- Bind Users",
          value   "cn=bind,ou=group,dc=umidb" },
    [1] { label   "blocked --- blocked users",
          value   "cn=blocked,ou=group,dc=umidb" },

DEFAULTS:

      attr  => [ 'cn', 'description' ]
      filter => '(objectClass=*)'
      scope => 'one'
      sizelimit => 0

=cut

sub bld_select {
  my ($self, $args) = @_;
  my $arg = { base      => $args->{base},
	      attr      => $args->{attr}      // [ 'cn', 'description' ],
	      filter    => $args->{filter}    // '(objectClass=*)',
	      scope     => $args->{scope}     // 'one',
	      sizelimit => $args->{sizelimit} // 0,
	      empty_row => $args->{empty_row} // 0,
	      a2v       => $args->{a2v}       // 0, };

  my $callername = (caller(1))[3];
  $callername    = 'main' if ! defined $callername;
  my $return     = 'call to LDAP_CRUD->bld_select from ' . $callername . ': ';

  $self->reset_ldap;
  my $mesg =
    $self->search({ base      => $arg->{base},
		    scope     => $arg->{scope},
		    attrs     => $arg->{attr},
		    filter    => $arg->{filter},
		    sizelimit => $arg->{sizelimit}, });

  my $err_message = '';
  if ( ! $mesg->count ) {
    $err_message = '<div class="alert alert-danger">' .
      '<i class="' . $self->{cfg}->{stub}->{icon_error} . '"></i><ul>' .
	$self->err($mesg)->{html} . '</ul></div>';
  }

  my @entries = $mesg->sorted( $arg->{attr}->[0] );
  my ( @arr, @arr_meta, $hash_uniq );

  # !!! TO FINISH (need to do)
  # attr0_val : attr0_val
  # attr0_val : attr1_val
  # dn : attr0_val
  # dn : attr0_val + ... + attrX_val

  # my $sel_val = $arg->{a2v} ? $arg->{attr}->[0] : ;
  push @arr, { value    => 'stub',
	       label    => '--- select an option ---',
	       selected => 'selected' }
    if $arg->{empty_row};

  # log_debug { np($#{$arg->{attr}}) };
  if ( $#{$arg->{attr}} == 0 ) {
    @arr_meta = map { $_->get_value( $arg->{attr}->[0] ) } @entries;
    $hash_uniq->{$_} = 1 foreach ( @arr_meta );
    @arr = map { value => $_, label => $_, }, sort keys %{$hash_uniq};
    # log_debug { np(@arr) };
  } else {
    foreach ( @entries ) {
      $arg->{toutfy} = sprintf('%s%s',
			       $_->get_value( $arg->{attr}->[0] ),
			       $_->exists($arg->{attr}->[1]) ? ' --- ' . $_->get_value( $arg->{attr}->[1] ) : '');
      utf8::decode($arg->{toutfy});
      push @arr, { value => $_->dn,
		   label => $arg->{toutfy}, }; # here it occures Missing argument in sprintf at 
    }
  }

  return \@arr;
}


=head2 org_domains

returns all associatedDomains of all org dn-s passed as array ref
argument

=cut

sub org_domains {
  my ($self, $org_dn) = @_;
  # log_debug { np($org_dn) };
  my $return = {};
  push @{$return->{error}}, { html => 'org is not defined' }
    if ! defined $org_dn;
  $org_dn = [ $org_dn ] if ref($org_dn) ne 'ARRAY';
  $return->{success} = [];
  my (@domain, $org);
  foreach my $dn ( @{$org_dn} ) {
    # log_debug { np($dn) };
    $org = $self->search( { base      => $dn,
			    scope     => 'base',
			    sizelimit => 0,
			    attrs     => [ 'associatedDomain' ], } );

    if ( ! $org->count ) {
      push @{$return->{error}},
	{ html => sprintf("org dn: <b>%s</b> is incorrect", $dn) },
	$self->err($org);
    } else {
      push @{$return->{success}},
	grep { defined && length }
	map { @{$_->get_value('associatedDomain', asref => 1)}
	      if $_->exists('associatedDomain') } $org->entries;
    }
  }
  # log_debug { np($return) };
  @{$return->{success}} = sort @{$return->{success}};
  return $return;
}

=head2 create_account_branch

creates branch for service accounts like

    dn: authorizedService=mail@foo.bar,uid=john.doe,ou=People,dc=umidb
    authorizedService: mail@foo.bar
    uid: john.doe@mail
    objectClass: account
    objectClass: authorizedServiceObject

returns hash
    {
      dn => '...', # DN of the oject created
      success => '...', # success message
      warning => '...', # warning message
      error => '...', # error message
    }

=cut

sub create_account_branch {
  my  ( $self, $args ) = @_;
  my %arg =
    ( $self->cfg->{rdn}->{acc_root} => $args->{$self->cfg->{rdn}->{acc_root}},
      authorizedservice => $args->{authorizedservice},
      associateddomain =>
      sprintf('%s%s',
	      defined $self->cfg->{authorizedService}->{$args->{authorizedservice}}->{associateddomain_prefix}
	      ->{$args->{associateddomain}} ?
	      $self->cfg->{authorizedService}->{$args->{authorizedservice}}->{associateddomain_prefix}
	      ->{$args->{associateddomain}} : '',
	      $args->{associateddomain}),
      objectclass => $args->{objectclass},
    );

  my $t = localtime;
  $arg{requestttl} = defined $args->{requestttl} &&
    $args->{requestttl} ? Time::Piece->strptime( $args->{requestttl}, "%Y.%m.%d %H:%M")->epoch - $t->epoch : 0;
  
  $arg{dn} =
    sprintf("authorizedService=%s@%s,%s=%s,%s",
	    $arg{authorizedservice},
	    $arg{associateddomain},
	    $self->cfg->{rdn}->{acc_root},
	    $args->{$self->cfg->{rdn}->{acc_root}},
	    $self->cfg->{base}->{acc_root});
  # p $arg;
  my ( $return, $if_exist);
  $arg{add_attrs} =
    [ uid => sprintf('%s@%s', $arg{$self->cfg->{rdn}->{acc_root}}, $arg{authorizedservice}),
      objectClass       => [ @{$self->cfg->{objectClass}->{acc_svc_branch}},
			     @{$arg{objectclass}} ],
      associatedDomain  => $arg{associateddomain},
      authorizedService =>
      sprintf('%s@%s%s', $arg{authorizedservice},
	      defined $self->cfg->{authorizedService}->{$args->{authorizedservice}}
	      ->{associateddomain_prefix}->{$args->{associateddomain}} ?
	      $self->cfg->{authorizedService}->{$args->{authorizedservice}}
	      ->{associateddomain_prefix}->{$args->{associateddomain}} : '',
	      $arg{associateddomain}), ];
  # p $arg{add_attrs};
  $if_exist =
    $self->search( { base => $arg{dn}, scope => 'base', attrs => [ 'authorizedService' ], } );
  if ( $if_exist->count ) {
    $return->{warning} = 'branch DN: <b>&laquo;' . $arg{dn} . '&raquo;</b> '
      . 'was not created since it <b>already exists</b>, I will use it further.';
    $return->{dn} = $arg{dn};
  } else {
    my $mesg = $self->add( $arg{dn}, $arg{add_attrs} );
    if ( $mesg ) {
      $return->{error} =
	sprintf('Error during %s branch (dn: %s) creation occured: %s<br><b>srv: </b><pre>%s</pre><b>text: </b>%s',
		uc($arg{authorizedservice}), $arg{dn}, $mesg->{html}, $mesg->{srv}, $mesg->{text});
    } else {
      if ( $arg{requestttl} ) {
	my $t = localtime;
	my $refresh = $self->refresh( $arg{dn}, $arg{requestttl} );
	if ( defined $refresh->{success} ) {
	  $return->{success} = $refresh->{success};
	} elsif ( defined $refresh->{error} ) {
	  $return->{error} = $refresh->{error};
	}
      }
      $return->{dn} = $arg{dn};
      $return->{associateddomain_prefix} = $arg{associateddomain_prefix};
    }
  }
  # p $return;
  return $return;
}


=head2 create_account_branch_leaf

creates leaves for service account branch like

    dn: uid=john.doe@foo.bar,authorizedService=mail@foo.bar,uid=U012C01-john.doe,ou=People,dc=umidb
    authorizedService: mail@foo.bar
    associatedDomain: foo.bar
    uid: john.doe@foo.bar
    cn: john.doe@foo.bar
    givenName: John
    sn: Doe
    uidNumber: 10738
    loginShell: /sbin/nologin
    objectClass: posixAccount
    objectClass: shadowAccount
    objectClass: inetOrgPerson
    objectClass: authorizedServiceObject
    objectClass: domainRelatedObject
    objectClass: mailutilsAccount
    userPassword: ********
    gecos: MAIL: john.doe @ foo.bar
    description: MAIL: john.doe @ foo.bar
    homeDirectory: /var/mail/IMAP_HOMES/foo.bar/john.doe@foo.bar
    mu-mailBox: maildir:/var/mail/foo.bar/john.doe@foo.bar
    gidNumber: 10006

returns reference to hash of arrays
    { success => [...],
      warning => [...],
      error => [...], }

=cut

sub create_account_branch_leaf {
  my  ( $self, $args ) = @_;
  # log_debug { np( $args )};
  my %arg =
    (
     basedn                 => $args->{basedn},
     service                => $args->{authorizedservice},
     associatedDomain       => sprintf('%s%s',
				       $self->cfg->{authorizedService}->{$args->{authorizedservice}}
				       ->{associateddomain_prefix}->{$args->{associateddomain}} // '',
				       $args->{associateddomain}),
     uidNumber              => $args->{uidNumber},
     givenName              => $args->{givenName},
     sn                     => $args->{sn},
     login                  => $args->{login},
     login_complex          => $args->{login_complex},
     password               => $args->{password},
     gecos                  => $self->utf2lat( sprintf('%s %s', $args->{givenName}, $args->{sn}) ),

     telephoneNumber        => $args->{telephoneNumber}        // '666',
     jpegPhoto              => $args->{jpegPhoto}              // undef,

     to_sshkeygen           => $args->{to_sshkeygen}           // undef,
     sshpublickey           => $args->{sshpublickey}           // undef,
     sshpublickeyfile       => $args->{sshpublickeyfile}       // undef,
     sshkeydescr            => $args->{sshkeydescr}            // undef,
     sshkey                 => $args->{sshkey}                 // undef,
     sshkeyfile             => $args->{sshkeyfile}             // undef,
     sshgid                 => $args->{sshgid}                 // undef,
     sshhome                => $args->{sshhome}                // undef,
     sshshell               => $args->{sshshell}               // undef,

     # !!! here we much need check for cert existance !!!
     userCertificate        => $args->{userCertificate}        // '',
     umiOvpnCfgIfconfigPush => $args->{umiOvpnCfgIfconfigPush} // 'NA',
     umiOvpnCfgIroute       => $args->{umiOvpnCfgIroute}       // 'NA',
     umiOvpnCfgPush         => $args->{umiOvpnCfgPush}         // 'NA',
     umiOvpnCfgConfig       => $args->{umiOvpnCfgConfig}       // '',
     umiOvpnAddStatus       => $args->{umiOvpnAddStatus}       // 'blocked',
     umiOvpnAddDevType      => $args->{umiOvpnAddDevType}      // 'NA',
     umiOvpnAddDevMake      => $args->{umiOvpnAddDevMake}      // 'NA',
     umiOvpnAddDevModel     => $args->{umiOvpnAddDevModel}     // 'NA',
     umiOvpnAddDevOS        => $args->{umiOvpnAddDevOS}        // 'NA',
     umiOvpnAddDevOSVer     => $args->{umiOvpnAddDevOSVer}     // 'NA',

     radiusgroupname        => $args->{radiusgroupname}        // '',
     radiusprofiledn        => $args->{radiusprofiledn}        // '',

     objectclass            => $args->{objectclass},
    );

  my $t = localtime;
  $arg{requestttl} = defined $args->{requestttl} && $args->{requestttl} ?
    Time::Piece->strptime( $args->{requestttl}, "%Y.%m.%d %H:%M")->epoch - $t->epoch : 0;

  my ( $return, $if_exist );

  $arg{prefixed_uid} =
    sprintf('%s%s',
	    $self->cfg->{authorizedService}->{$arg{service}}->{login_prefix} // '',
	    $arg{login});

  $arg{uid} = sprintf('%s%s%s',
			$arg{prefixed_uid},

			$self->cfg->{authorizedService}->{$arg{service}}->{delim_mandatory} ||
			$arg{login_complex} == 1 ?
			$self->cfg->{authorizedService}->{$arg{service}}->{login_delim} : '',

			$self->cfg->{authorizedService}->{$arg{service}}->{delim_mandatory} ||
			$arg{login_complex} == 1 ? $arg{associatedDomain} : ''
		       );

  $arg{dn} = sprintf('uid=%s,%s', $arg{uid}, $arg{basedn});

  # log_debug { np(%arg) };
  
  my ($authorizedService, $sshkey, $authorizedService_add, $jpegPhoto_file, $description );
  my $sshPublicKey = [];
  
  if ( $arg{service}   eq 'ovpn' ||
       $arg{service}   eq 'ssh'  ||
       ( $arg{service} eq 'dot1x-eap-md5' ||
	 $arg{service} eq 'dot1x-eap-tls' ) ||
       $arg{service}   eq 'gitlab'  ||
       $arg{service} eq 'web' ) {
    $authorizedService = [];
  } else {
    $authorizedService = [
			  objectClass       => [ @{$self->cfg->{objectClass}->{acc_svc_common}},
						 @{$arg{objectclass}} ],
			  authorizedService => $arg{service} . '@' . $arg{associatedDomain},
			  associatedDomain  => $arg{associatedDomain},
			  uid               => $arg{uid},
			  cn                => $arg{uid},
			  givenName         => $arg{givenName},
			  sn                => $arg{sn},
# moved to each svc	  uidNumber => $arg{uidNumber},
# moved to ssh-acc        loginShell => $self->cfg->{stub}->{loginShell},
			  gecos             => $self->utf2lat( sprintf('%s %s', $args->{givenName}, $args->{sn}) ),
			 ];
  }
  
  $description = $args->{description} ne '' ? $args->{description} :
    sprintf('%s: %s @ %s', uc($arg{service}), $arg{'login'}, $arg{associatedDomain});

  #=== SERVICE: mail =================================================
  if ( $arg{service} eq 'mail') {
    push @{$authorizedService},
      homeDirectory => $self->cfg->{authorizedService}->{$arg{service}}->{homeDirectory_prefix} .
      $arg{associatedDomain} . '/' . $arg{uid},
      'mu-mailBox'  => 'maildir:/var/mail/' . $arg{associatedDomain} . '/' . $arg{uid},
      gidNumber     => $self->cfg->{authorizedService}->{$arg{service}}->{gidNumber},
      loginShell    => $self->cfg->{stub}->{loginShell},
      uidNumber     => $arg{uidNumber},
      userPassword  => $arg{password}->{$arg{service}}->{'ssha'},
      objectClass   => [ @{$self->cfg->{objectClass}->{acc_svc_email}} ];
    
  #=== SERVICE: xmpp =================================================
  } elsif ( $arg{service} eq 'xmpp') {
    if ( defined $arg{jpegPhoto} ) {
      $jpegPhoto_file = $arg{jpegPhoto}->{'tempname'};
    } else {
      $jpegPhoto_file = $self->cfg->{authorizedService}->{$arg{service}}->{jpegPhoto_noavatar};
    }

    push @{$authorizedService},
      homeDirectory   => $self->cfg->{stub}->{homeDirectory},
      gidNumber       => $self->cfg->{authorizedService}->{$arg{service}}->{gidNumber},
      loginShell      => $self->cfg->{stub}->{loginShell},
      uidNumber       => $arg{uidNumber},
      userPassword    => $arg{password}->{$arg{service}}->{'ssha'},
      telephonenumber => $arg{telephoneNumber},
      jpegPhoto       => [ $self->file2var( $jpegPhoto_file, $return) ];

  #=== SERVICE: 802.1x ===============================================
  } elsif ( $arg{service} eq 'dot1x-eap-md5' ||
	    $arg{service} eq 'dot1x-eap-tls' ) {
    undef $authorizedService;

    if ( $arg{service} eq 'dot1x-eap-md5' ) {
      $arg{dn} = sprintf('%s=%s,%s',
			   $self->cfg->{rdn}->{acc_root},
			   $self->macnorm({ mac => $arg{login} }),
			   $arg{basedn});
      push @{$authorizedService},
	objectClass => [ @{$self->cfg->{objectClass}->{acc_svc_dot1x}}, @{$arg{objectclass}} ],
	uid         => $self->macnorm({ mac => $arg{login} }),
	cn          => $self->macnorm({ mac => $arg{login} });
    }

    push @{$authorizedService},
      authorizedService => $arg{service} . '@' . $arg{associatedDomain},
      associatedDomain  => $arg{associatedDomain},
      userPassword      => $arg{password}->{$arg{service}}->{clear};

    push @{$authorizedService}, radiusprofiledn => $arg{radiusprofiledn}
      if $arg{radiusprofiledn} ne '';

    push @{$authorizedService}, radiusgroupname => $arg{radiusgroupname}
      if $arg{radiusgroupname} ne '';

    if ( $arg{service} eq 'dot1x-eap-tls' ) {
      $arg{cert_info} =
	$self->cert_info({ cert => $self->file2var($arg{userCertificate}->{'tempname'}, $return),
			   ts   => "%Y%m%d%H%M%S", });

      $arg{dn} = sprintf('%s=%s,%s', $self->cfg->{rdn}->{acc_root}, $arg{cert_info}->{'CN'}, $arg{basedn});

      push @{$authorizedService},
	objectClass                 => [ @{$self->cfg->{objectClass}->{acc_svc_dot1x_eap_tls}}, @{$arg{objectclass}} ],
	uid                         => '' . $arg{cert_info}->{'CN'},
	cn                          => '' . $arg{cert_info}->{'CN'},
	umiUserCertificateSn        => '' . $arg{cert_info}->{'S/N'},
	umiUserCertificateNotBefore => '' . $arg{cert_info}->{'Not Before'},
	umiUserCertificateNotAfter  => '' . $arg{cert_info}->{'Not  After'},
	umiUserCertificateSubject   => '' . $arg{cert_info}->{'Subject'},
	umiUserCertificateIssuer    => '' . $arg{cert_info}->{'Issuer'},
	'userCertificate;binary'    => $arg{cert_info}->{cert};
    }

  #=== SERVICE: ssh-acc ==============================================
  } elsif ( $arg{service} eq 'ssh-acc' ) {
    if ( defined $arg{sshkeyfile} ) {
      $sshPublicKey = $self->file2var( $arg{sshkeyfile}->{tempname}, $return, 1);
      # log_debug { np($arg{sshkeyfile}) };
      # log_debug { np($sshPublicKey) };
      # log_debug { np($return) };
      $description = $self->utf2lat( sprintf("%s ;\nkey file: %s ( %s bytes)",
					     $description,
					     $arg{sshkeyfile}->{filename},
					     $arg{sshkeyfile}->{size}) );
    }
    push @{$sshPublicKey}, $arg{sshkey}
      if defined $arg{sshkey} && $arg{sshkey} ne '';
    push @{$authorizedService}, sshPublicKey => [ @$sshPublicKey ],
      gidNumber     => $arg{sshgid}   // $self->cfg->{authorizedService}->{$arg{service}}->{gidNumber},
#      uidNumber => $arg{uidNumber} + $self->cfg->{authorizedService}->{$arg{service}}->{uidNumberShift},
      uidNumber     => $self->last_uidNumber_ssh + 1,
      userPassword  => $arg{password}->{$arg{service}}->{'ssha'},
      loginShell    => $arg{sshshell} // $self->cfg->{authorizedService}->{$arg{service}}->{loginShell},
      homeDirectory => $arg{sshhome}  // sprintf("%s/%s",
						   $self->cfg->{authorizedService}->{$arg{service}}->{homeDirectory_prefix},
						   $arg{uid});
    # ,
    #   homeDirectory => $self->cfg->{authorizedService}->{$arg{service}}->{homeDirectory_prefix} . '/' . $arg{uid};
    # log_debug { np( $arg ) };

  #=== SERVICE: ovpn =================================================
  } elsif ( $arg{service} eq 'ovpn' ) {
    $arg{dn} = 'cn=' . substr($arg{userCertificate}->{filename},0,-4) . ',' . $arg{basedn};
    $arg{cert_info} =
      $self->cert_info({ cert => $self->file2var($arg{userCertificate}->{'tempname'}, $return),
			 ts   => "%Y%m%d%H%M%S", });
    $authorizedService = [
			  cn                          => '' . $arg{cert_info}->{CN},
			  associatedDomain            => $arg{associatedDomain},
			  authorizedService           => $arg{service} . '@' . $arg{associatedDomain},
			  objectClass                 => [ @{$self->cfg->{objectClass}->{ovpn}},
						           @{$arg{objectclass}} ],
			  umiOvpnCfgIfconfigPush      => $arg{umiOvpnCfgIfconfigPush},
			  umiOvpnCfgIroute            => $arg{umiOvpnCfgIroute},
			  umiOvpnCfgPush              => $arg{umiOvpnCfgPush},
			  umiOvpnCfgConfig            => $arg{umiOvpnCfgConfig},
			  umiOvpnAddStatus            => $arg{umiOvpnAddStatus},
			  umiUserCertificateSn        => '' . $arg{cert_info}->{'S/N'},
			  umiUserCertificateNotBefore => '' . $arg{cert_info}->{'Not Before'},
			  umiUserCertificateNotAfter  => '' . $arg{cert_info}->{'Not  After'},
			  umiUserCertificateSubject   => '' . $arg{cert_info}->{'Subject'},
			  umiUserCertificateIssuer    => '' . $arg{cert_info}->{'Issuer'},
			  umiOvpnAddDevType           => $arg{umiOvpnAddDevType},
			  umiOvpnAddDevMake           => $arg{umiOvpnAddDevMake},
			  umiOvpnAddDevModel          => $arg{umiOvpnAddDevModel},
			  umiOvpnAddDevOS             => $arg{umiOvpnAddDevOS},
			  umiOvpnAddDevOSVer          => $arg{umiOvpnAddDevOSVer},
			  'userCertificate;binary'    => $arg{cert_info}->{cert},
			 ];

    push @{$return->{error}}, $arg{cert_info}->{error} if defined $arg{cert_info}->{error};
    
  #=== SERVICE: web ==================================================
  } elsif ( $arg{service} eq 'web' ) {
    $authorizedService = [
			  objectClass       => [ @{$self->cfg->{objectClass}->{acc_svc_web}},
						 @{$arg{objectclass}} ],
			  authorizedService => $arg{service} . '@' . $arg{associatedDomain},
			  associatedDomain  => $arg{associatedDomain},
			  uid               => $arg{uid},
			  userPassword      => $arg{password}->{$arg{service}}->{'ssha'},
			 ];
  #=== SERVICE: gitlab ==================================================
  } elsif ( $arg{service} eq 'gitlab' ) {
    $authorizedService = [
			  objectClass       => [ @{$self->cfg->{objectClass}->{acc_svc_gitlab}},
						 @{$arg{objectclass}} ],
			  authorizedService => $arg{service} . '@' . $arg{associatedDomain},
			  associatedDomain  => $arg{associatedDomain},
			  cn                => sprintf("%s %s", $arg{givenName}, $arg{sn}),
			  mailLocalAddress  => $args->{mail} // 'NA',
			  uid               => $arg{uid},
			  userPassword      => $arg{password}->{$arg{service}}->{'ssha'},
			 ];
  }

  push @{$authorizedService}, description => $description;
  
  # p $arg{dn};
  # p $authorizedService;
  # p $sshPublicKey;
  my $mesg;
  # for an existent SSH object we have to modify rather than add
  $if_exist = $self->search( { base => $arg{dn}, scope => 'base', } );
  if ( $arg{service} eq 'ssh' && $if_exist->count ) {
    $mesg = $self->modify( $arg{dn},
				[ add => [ sshPublicKey => $sshPublicKey, ], ], );
    if ( $mesg ) {
      push @{$return->{error}},
	sprintf('Error during %s service modification: %s<br><b>srv: </b><pre>%s</pre><b>text: </b>%s',
		$arg{service}, $mesg->{html}, $mesg->{srv}, $mesg->{text});
    } else {
      push @{$return->{success}},
	sprintf('<i class="%s fa-fw"></i>&nbsp;<em>key was added</em>',
		$self->cfg->{authorizedService}->{$arg{service}}->{icon} );
    }
  } else {
    # for nonexistent SSH object and all others
    $mesg = $self->add( $arg{dn}, $authorizedService, );
    if ( $mesg ) {
      push @{$return->{error}},
	sprintf('Error during %s account creation occured: %s<br><b>srv: </b><pre>%s</pre><b>text: </b>%s',
		uc($arg{service}), $mesg->{html}, $mesg->{srv}, $mesg->{text});
    } else {
      if ( $arg{requestttl} ) {
	my $refresh = $self->refresh( $arg{dn}, $arg{requestttl});
	if ( defined $refresh->{success} ) {
	  push @{$return->{success}}, $refresh->{success};
	} elsif ( defined $refresh->{error} ) {
	  push @{$return->{error}}, $refresh->{error};
	}
      }
      push @{$return->{success}},
	sprintf('<i class="%s fa-fw"></i>&nbsp;<em>%s account login:</em> <strong class="text-success">%s</strong> <em>password:</em> <strong class="text-success text-monospace">%s</strong>',
		$self->cfg->{authorizedService}->{$arg{service}}->{icon},
		$arg{service},
		(split(/=/,(split(/,/,$arg{dn}))[0]))[1], # taking RDN value
		$arg{password}->{$arg{service}}->{'clear'});


      ### !!! RADIUS group modify with new member add if 802.1x
      if ( $arg{service} eq 'dot1x-eap-md5' || $arg{service} eq 'dot1x-eap-tls' &&
	   defined $arg{radiusgroupname} && $arg{radiusgroupname} ne '' ) {
	$if_exist = $self->search( { base => $arg{radiusgroupname},
					  scope => 'base',
					  filter => '(' . $arg{dn} . ')', } );
	if ( ! $if_exist->count ) {
	  $mesg = $self->modify( $arg{radiusgroupname},
				      [ add => [ member => $arg{dn}, ], ], );
	  if ( $mesg && $mesg->{code} == 20 ) {
	    push @{$return->{warning}},
	      sprintf('Warning during %s group modification: %s<br><b>srv: </b><pre>%s</pre><b>text: </b>%s',
		      $arg{radiusgroupname}, $mesg->{html}, $mesg->{srv}, $mesg->{text});
	  } elsif ( $mesg ) {
	    push @{$return->{error}},
	      sprintf('Error during %s group modification: %s<br><b>srv: </b><pre>%s</pre><b>text: </b>%s',
		      $arg{radiusgroupname}, $mesg->{html}, $mesg->{srv}, $mesg->{text});
	  }

	}
      }
    }
  }
  return $return;
}



=head2 attr_equality

!!! DEPRECATED !!! moved to the session data (in Controller/Auth.pm)

each attribute equality of the whole schema, hash

=cut

has 'attr_equality' 
  => ( traits => ['Hash'],
       is => 'ro',
       isa => 'HashRef',
       required => 0, lazy => 1,
       builder  => 'build_attr_equality',
     );

sub build_attr_equality {
  my $self = shift;
  my $return;

  my $schema = $self->ldap->schema;
  
  foreach ( $schema->all_attributes ) {
    if ( defined $_->{equality} ) {
      $return->{$_->{name}} = $_->{equality};
    } elsif ( defined $_->{sup}) {
      $return->{$_->{name}} = $_->{sup}->[0];
    }
    #p $_ if ! defined $_->{equality};
  }
  # p $return;
  return $return;
}


=head2 show_inventory_item

returns inventory item data array ref of hashes where values are array
refs too

for composite object it is:

    dn                "cn=ws-3,ou=Composite,ou=hw,ou=Inventory,dc=umidb",
    hwObj             {
        success   {
            CPU    [
                [0] {
                    descr   "AMD A10-7800 Radeon R7, 12 Compute Cores 4C+8G ",
                    dn      "cn=cpu-3,ou=Comparts,ou=hw,ou=Inventory,dc=umidb"
                    inum    "NA"
                }
            ],
            DISK   [
                [0] {
                    descr   "SSD: KINGSTON SHFS37A240G, [240 GB]",
                    dn      "cn=disk-3,ou=Comparts,ou=hw,ou=Inventory,dc=umidb"
                    inum    "N123"
                }
            ],
            IF     [
                [0] {
                    descr   "eth_in, RTL8111/8168/8411 PCI Express Gigabit Ethernet Controller, Realtek Semiconductor Co., Ltd.",
                    dn      "cn=if-3,ou=Comparts,ou=hw,ou=Inventory,dc=umidb"
                    inum    "A456"
                }
            ],
            MB     [
                [0] {
                    descr   "MSI: A78M-E45 V2 (MS-7721)",
                    dn      "cn=mb-3,ou=Comparts,ou=hw,ou=Inventory,dc=umidb"
                    inum    "NA"
                }
            ],
            RAM    [
                [0] {
                    descr   "DIMM 0: 8192 MB, 1333 MHz, A1_Manufacturer0, GY1600D364L10/8G",
                    dn      "cn=ram-7,ou=Comparts,ou=hw,ou=Inventory,dc=umidb"
                    inum    "R0A9M8"
                },
                [1] {
                    descr   "DIMM 0: 8192 MB, 1333 MHz, A1_Manufacturer2, GY1600D364L10/8G",
                    dn      "cn=ram-8,ou=Comparts,ou=hw,ou=Inventory,dc=umidb"
                    inum    "NA"
                }
            ]
        }
    },
    hwType            "<i title="composite inventory item, workstation" class="fas fa-lg fa-desktop"></i>",
    inventoryNumber   "234-xdfsg8"

for compart object it is:

for singlrboard object it is:

for furniture object it is:


=cut

sub show_inventory_item {
  my ($self, $args) = @_;
  my $arg = { inventory_dn => $args->{dn}, };
  my $mesg =
    $self->search({ base   => $arg->{inventory_dn},
		    scope  => 'base', });
  my ( $entry, $hwType, $res, $return, $tmp_m, $tmp_e, $a, $b, $c, $d);
  $return->{error} = $self->err($mesg)->{html} if ! $mesg->count;
  $entry = $mesg->entry(0);
  # removing from DN, all the rest up to the hwType
  $hwType =
    ldap_explode_dn( substr( $arg->{inventory_dn}, 0, -1 * (1 + length $self->{cfg}->{base}->{inventory})),
		     reverse => 1);

  if ( $hwType->[0]->{OU} eq 'Composite' ) {
    $res = { CPU  => [],
	     DISK => [],
	     IF   => [],
	     MB   => [],
	     RAM  => [], };

    $a = $entry->get_value( 'hwCpu', asref => 1 );
    foreach $b ( @{$a} ) {
      $tmp_m = $self->search({ base  => $b, scope => 'base', });
      if ( ! $tmp_m->count ) {
	push @{$return->{error}}, $self->err($tmp_m)->{html};
      } else {
	$tmp_e = $tmp_m->entry(0);
	push @{$res->{CPU}},
	  { dn => $b,
	    descr => $tmp_e->get_value('hwVersion'),
	    inum => $tmp_e->exists('inventoryNumber') ? $tmp_e->get_value('inventoryNumber') : 'NA' };
      }
    }

    $a = $entry->get_value( 'hwMb', asref => 1 );
    foreach $b ( @{$a} ) {
      $tmp_m = $self->search({ base  => $b, scope => 'base', });
      if ( ! $tmp_m->count ) {
	push @{$return->{error}}, $self->err($tmp_m)->{html};
      } else {
	$tmp_e = $tmp_m->entry(0);
	push @{$res->{MB}},
	  { dn => $b,
	    descr => sprintf('%s: %s',
			     $tmp_e->get_value('hwManufacturer'),
			     $tmp_e->get_value('hwProductName')),
	    inum => $tmp_e->exists('inventoryNumber') ? $tmp_e->get_value('inventoryNumber') : 'NA' };
      }
    }

    $a = $entry->get_value( 'hwIf', asref => 1 );
    foreach $b ( @{$a} ) {
      $tmp_m = $self->search({ base  => $b, scope => 'base', });
      if ( ! $tmp_m->count ) {
	push @{$return->{error}}, $self->err($tmp_m)->{html};
      } else {
	$tmp_e = $tmp_m->entry(0);
	push @{$res->{IF}},
	  { dn => $b,
	    descr => sprintf('%s, %s, %s, %s',
			     $tmp_e->get_value('hwTypeIf'),
			     $tmp_e->get_value('hwMac'),
			     $tmp_e->get_value('hwModel'),
			     $tmp_e->get_value('hwManufacturer')),
	    inum => $tmp_e->exists('inventoryNumber') ? $tmp_e->get_value('inventoryNumber') : 'NA' };

      }
    }

    $a = $entry->get_value( 'hwDisk', asref => 1 );
    foreach $b ( @{$a} ) {
      $tmp_m = $self->search({ base  => $b, scope => 'base', });
      if ( ! $tmp_m->count ) {
	push @{$return->{error}}, $self->err($tmp_m)->{html};
      } else {
	$tmp_e = $tmp_m->entry(0);
	($c,$d) = split(' bytes ', $tmp_e->get_value('hwSize'));
	
	push @{$res->{DISK}},
	  { dn => $b, descr =>
	    sprintf('%s: %s, %s',
		    $tmp_e->get_value('hwTypeDisk'),
		    $tmp_e->get_value('hwModel'),
		    $d ),
	    inum => $tmp_e->exists('inventoryNumber') ? $tmp_e->get_value('inventoryNumber') : 'NA' };

      }
    }

    $a = $entry->get_value( 'hwRam', asref => 1 );
    foreach $b ( @{$a} ) {
      $tmp_m = $self->search({ base  => $b, scope => 'base', });
      if ( ! $tmp_m->count ) {
	push @{$return->{error}}, $self->err($tmp_m)->{html};
      } else {
	$tmp_e = $tmp_m->entry(0);
	push @{$res->{RAM}},
	  { dn => $b, descr =>
	    sprintf('%s: %s, %s, %s, %s',
		    $tmp_e->get_value('hwLocator'),
		    $tmp_e->get_value('hwSizeRam'),
		    $tmp_e->get_value('hwSpeedRam'),
		    $tmp_e->get_value('hwManufacturer'),
		    $tmp_e->get_value('hwPartNumber') ),
	    inum => $tmp_e->exists('inventoryNumber') ? $tmp_e->get_value('inventoryNumber') : 'NA' };
      }
    }
    
    # push @{$return->{success}},
    #   { CPU  => { dn => $a  }, },
    #   { DISK => { dn => $entry->get_value( 'hwDisk', asref => 1 ) }, },
    #   { IF   => { dn => $entry->get_value( 'hwIf', asref => 1 )   }, },
    #   { MB   => { dn => $entry->get_value( 'hwMb', asref => 1 )   }, },
    #   { RAM  => { dn => $entry->get_value( 'hwRam', asref => 1 )  }, };
  } else {
    $res = { DESCRIPTION  => [], };

    push @{$res->{DESCRIPTION}},
      { dn => $entry->dn,
	descr => sprintf('model: %s; manufacturer: %s',
			 $entry->exists('hwModel') ? $entry->get_value('hwModel') : 'NA',
			 $entry->exists('hwManufacturer') ? $entry->get_value('hwManufacturer') : 'NA' ),
	inum => $entry->exists('inventoryNumber') ? $entry->get_value('inventoryNumber') : 'NA' };
  }
  $return->{success} = $res;
  # p $res;
  return $return;
}



######################################################################
# temporary stuff
######################################################################

sub canonical_dn_rev {
  my ($self, $dn) = @_;
  return canonical_dn($dn, reverse => 1);
}


######################################################################

__PACKAGE__->meta->make_immutable;

no Moose;

1;

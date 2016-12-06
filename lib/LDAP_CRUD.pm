# -*- mode: cperl; mode: follow; -*-
#

package LDAP_CRUD;

use Moose;
use namespace::autoclean;

use Data::Printer  colored => 1;

BEGIN { with 'Tools'; }

use utf8;
use Net::LDAP;
use Net::LDAP::LDIF;
use Net::LDAP::Control;
use Net::LDAP::Control::Sort;
use Net::LDAP::Control::SortResult;
use Net::LDAP::Constant qw(LDAP_CONTROL_SORTRESULT);
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

  return {
	  base => {
		   db => UMI->config->{ldap_crud_db},
		   acc_root =>       'ou=People,' . UMI->config->{ldap_crud_db},
		   acc_svc_branch => 'ou=People,' . UMI->config->{ldap_crud_db},
		   acc_svc_common => 'ou=People,' . UMI->config->{ldap_crud_db},
		   alias =>          'ou=alias,' . UMI->config->{ldap_crud_db},
		   dhcp =>           'ou=DHCP,' . UMI->config->{ldap_crud_db},
		   gitacl =>         'ou=GitACL,' . UMI->config->{ldap_crud_db},
		   group =>          'ou=group,' . UMI->config->{ldap_crud_db},
		   inventory =>      'ou=hw,ou=Inventory,' . UMI->config->{ldap_crud_db},
		   machines =>       'ou=machines,' . UMI->config->{ldap_crud_db},
		   netgroup =>       'ou=Netgroups,' . UMI->config->{ldap_crud_db},
		   org =>            'ou=Organizations,' . UMI->config->{ldap_crud_db},
		   rad_groups =>     'ou=groups,ou=RADIUS,' . UMI->config->{ldap_crud_db},
		   rad_profiles =>   'ou=profiles,ou=RADIUS,' . UMI->config->{ldap_crud_db},
		   workstations =>   'ou=workstations,' . UMI->config->{ldap_crud_db},
		   monitor =>        'cn=Monitor',
		   icon => {
			    People => 'fa fa-user',
			    DHCP => 'fa fa-sitemap',
			    GitACL => 'fa fa-gavel',
			    group => 'fa fa-group',
			    inventory => 'fa fa-tag',
			    Organizations => 'fa fa-industry',
			    rad_groups => 'fa fa-group',
			    rad_profiles => 'fa fa-cogs',
			   },
		  },
	  exclude_prefix => 'aux_',
	  sizelimit => 50,
	  translit => "ALA-LC RUS",
	  translit_no => {
			  description => 1,
			  givenName => 1,
			  l => 1,
			  postalAddress => 1,
			  registeredAddress => 1,
			  sn => 1,
			  st => 1,
			  street => 1,
			  title => 1,
			 },
	  
	  #=====================================================================
	  ##
	  ### CONFIGURATION STARTS HERE (something you could want to change.
	  ### *all other stuff can be changed ONLY if you understand what for*
	  ##
	  #=====================================================================

	  stub => {
		   homeDirectory => '/nonexistent',
		   loginShell => '/sbin/nologin',
		   gidNumber => 10012,
		   group => 'employee',
		   noavatar_mgmnt => UMI->path_to('root', 'static', 'images', '/avatar-mgmnt.png'),
		   icon => 'fa fa-user',
		   icon_error => 'fa fa-exclamation-circle',
		   icon_warning => 'fa fa-exclamation-triangle',
		   icon_success => 'fa fa-check-circle',
		   group_blocked => 'blocked',
		  },
	  rdn => {
		  org =>            'ou',
		  acc_root =>       UMI->config->{authentication}->{realms}->{ldap}->{store}->{user_field},
		  acc_svc_branch => 'authorizedService',
		  acc_svc_common => 'uid',
		  gitacl =>         'cn',
		  group =>          'cn',
		 },
	  objectClass => {
			  acc_root => [ qw(
					    top
					    posixAccount
					    inetOrgPerson
					    organizationalPerson
					    person
					    inetLocalMailRecipient
					    grayAccount
					 ) ],
			  acc_svc_branch => [ qw(
						  account
						  authorizedServiceObject
					       ) ],
			  acc_svc_802_1x => [ qw(
						  account
						  simpleSecurityObject
						  authorizedServiceObject
						  radiusprofile
					       ) ],
			  acc_svc_802_1x_eaptls => [ qw(
							 account
							 simpleSecurityObject
							 authorizedServiceObject
							 radiusprofile
							 strongAuthenticationUser
							 umiUserCertificate
						      ) ],
			  acc_svc_common => [ qw(
						  posixAccount
						  shadowAccount
						  inetOrgPerson
						  authorizedServiceObject
						  domainRelatedObject
					       ) ],
			  acc_svc_web => [ qw(
					       account
					       simpleSecurityObject
					       uidObject
					       authorizedServiceObject
					       domainRelatedObject
					    ) ],
			  gitacl => [ qw(
				    	  top
				    	  gitACL
				       ) ],
			  group =>  [ qw(
				    	  top
				    	  posixGroup
				       ) ],
			  dhcp => [ qw(
					top
					dhcpHost
					uidObject
				     ) ],
			  netgroup =>  [ qw(
					     top
					     nisNetgroup
					  ) ],
			  ovpn => [ qw(
					top
					organizationalRole
					domainRelatedObject
					strongAuthenticationUser
					umiUserCertificate
					umiOvpnCfg
				     ) ],
			  org => [ qw(
				       top
				       organizationalUnit
				       domainRelatedObject
				    ) ],
			  ssh => [ qw(
				       top
				       account
				       ldapPublicKey
				    ) ],
			  inventory => [ qw(
					     top
					     hwInventory
					  ) ],
			 },
	  jpegPhoto => {
			'stub' => 'user-6-128x128.jpg',
		       },
	  authorizedService =>
	  {
	   'mail' => {
		      auth => 1,
		      descr => 'Email',
		      disabled => 0,
		      homeDirectory_prefix => '/var/mail/IMAP_HOMES/',
		      gidNumber => 10006,
		      icon => 'fa fa-envelope',
		      data_fields => 'login,logindescr,password1,password2',
		      data_relation => 'passw',
		     },
	   'xmpp' => {
		      auth => 1,
		      descr => 'XMPP (Jabber)',
		      disabled => 0,
		      gidNumber => 10106,
		      jpegPhoto_noavatar => UMI->path_to('root', 'static', 'images', '/avatar-xmpp.png'),
		      icon => 'fa fa-lightbulb-o',
		      data_fields => 'login,logindescr,password1,password2',
		      data_relation => 'passw',
		      associateddomain_prefix =>
		      {
		       'talax.startrek.in' => 'im.',
		      },
		     },
	   '802.1x-mac' => {
			    auth => 1,
			    descr => 'auth 802.1x EAP-MD5 (MAC)',
			    disabled => 0,
			    icon => 'fa fa-shield',
			    data_fields => 'login,radiusgroupname,radiusprofile',
			    data_relation => '8021x',
			   },
	   '802.1x-eap-tls' => {
				auth => 1,
				descr => 'auth 802.1x EAP-TLS',
				disabled => 0,
				icon => 'fa fa-shield',
				data_fields => 'login,password1,password2,radiusgroupname,radiusprofile,userCertificate',
				data_relation => '8021xeaptls',
				login_prefix => 'rad-',
			       },
	   'otrs' => {
		      auth => 1,
		      descr => 'OTRS',
		      disabled => 1,
		      icon => 'fa fa-file-code-o',
		      data_fields => 'login,password1,password2',
		     },
	   'web' => {
		     auth => 1,
		     descr => 'Web Account',
		     disabled => 0,
		     icon => 'fa fa-puzzle-piece',
		     data_fields => 'login,logindescr,password1,password2',
		     data_relation => 'passw',
		    },
	   'sms' => {
		     auth => 1,
		     descr => 'SMSter',
		     disabled => 1,
		     data_fields => 'login,password1,password2',
		    },
	   'comm-acc' => {
			  auth => 1,
			  descr => 'CISCO Commutators',
			  disabled => 0,
			  icon => 'fa fa-terminal',
			  data_fields => 'login,logindescr,password1,password2',
			  data_relation => 'passw',
			 },
	   'ssh-acc' => {
			 auth => 1,
			 descr => 'SSH',
			 disabled => 0,
			 icon => 'fa fa-key',
			 data_fields => 'login,logindescr,password1,password2',
			 data_relation => 'passw',
			},
	   'ssh' => {
		     auth => 0,
		     descr => 'SSH key',
		     disabled => 0,
		     icon => 'fa fa-key',
		     # data_fields => 'key,keyfile,associateddomain',
		     # data_relation => 'sshpubkey',
		    },
	   'gpg' => {
		     auth => 0,
		     descr => 'GPG key',
		     disabled => 1,
		     icon => 'fa fa-key',
		    },
	   'ovpn' => {
		      auth => 0,
		      descr => 'OpenVPN client',
		      disabled => 0,
		      icon => 'fa fa-certificate',
		      # data_fields => 'block_crt',
		     },
	  },
	  
	  hwType =>
	  {
	   singleboard => {
			   dn_sfx => 'ou=SingleBoard,ou=hw,',
			   ap => {
				  descr => 'singleboard inventory item, Access Point',
				  disabled => 0,
				  icon => 'fa fa-lg fa-cog',
				 },
			   com  => {
				    descr => 'singleboard inventory item, commutator',
				    disabled => 0,
				    icon => 'fa fa-lg fa-cog',
				   },
			   wrt => {
				   descr => 'singleboard inventory item, WRT',
				   disabled => 0,
				   icon => 'fa fa-lg fa-cog',
				  },
			   monitor => {
				       descr => 'singleboard inventory item, monitor',
				       disabled => 0,
				       icon => 'fa fa-lg fa-cog',
				      },
			   prn => {
				   descr => 'singleboard inventory item, printer',
				   disabled => 0,
				   icon => 'fa fa-lg fa-cog',
				  },
			   mfu => {
				   descr => 'singleboard inventory item, MFU',
				   disabled => 0,
				   icon => 'fa fa-lg fa-cog',
				  },
			  },
	   composite => {
			 dn_sfx => 'ou=Composite,ou=hw,',
			 ws => {
				descr => 'composite inventory item, workstation',
				disabled => 0,
				icon => 'fa fa-lg fa-desktop',
			       },
			 srv => {
				 descr => 'composite inventory item, server',
				 disabled => 0,
				 icon => 'fa fa-lg fa-desktop',
				},
			},
	   consumable => {
			  dn_sfx => 'ou=Consumable,ou=hw,',
			  kbd => {
				  descr => 'consumable inventory item, keyboard',
				  disabled => 0,
				  icon => 'fa fa-lg fa-recycle',
				 },
			  ms => {
				 descr => 'consumable inventory item, mouse',
				 disabled => 0,
				 icon => 'fa fa-lg fa-recycle',
				},
			  hs => {
				 descr => 'consumable inventory item, headset',
				 disabled => 0,
				 icon => 'fa fa-lg fa-recycle',
				},
			 },
	   compart => {
		       dn_sfx => 'ou=Compart,ou=hw,',
		       mb => {
			      descr => 'compart inventory item, motherboard',
			      disabled => 0,
			      icon => 'fa fa-lg fa-cogs',
			     },
		       cpu => {
			       descr => 'compart inventory item, CPU',
			       disabled => 0,
			       icon => 'fa fa-lg fa-cogs',
			      },
		       ram => {
			       descr => 'compart inventory item, RAM',
			       disabled => 0,
			       icon => 'fa fa-lg fa-cogs',
			      },
		       disk => {
			       descr => 'compart inventory item, disk',
			       disabled => 0,
			       icon => 'fa fa-lg fa-cogs',
			      },
		      },
	   furniture => {
			 dn_sfx => 'ou=Furniture,ou=hw,',
			 tbl => {
				 descr => 'furniture inventory item, table',
				 disabled => 0,
				 icon => 'fa fa-lg fa-bed',
				},
			 chr => {
				 descr => 'furniture inventory item, chair',
				 disabled => 0,
				 icon => 'fa fa-lg fa-wheelchair',
				},
			},
	  },
	  err => {
		  0 => '<i class="fa fa-search-minus fa-lg text-warning "></i>&nbsp;Looks like your request returned no result. Try to change query parameter/s.',
		  50 => 'Do not panic! This situation needs your security officer and system administrator attention, please contact them to solve the issue.',
		 },

	  #=====================================================================
	  ##
	  ### CONFIGURATION STOPS HERE
	  ##
	  #=====================================================================
	 };
}

has 'host' => ( is => 'ro', isa => 'Str', required => 1, default => UMI->config->{ldap_crud_host});
has 'uid' => ( is => 'ro', isa => 'Str', required => 1 );
has 'pwd' => ( is => 'ro', isa => 'Str', required => 1 );
has 'dry_run' => ( is => 'ro', isa => 'Bool', default => 0 );
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

	$ldap = try {
	  Net::LDAP->new( $self->host, async => 1, debug => 0 );
	} catch {
	  warn "Net::LDAP->new problem, error: $_";    # not $@
	};

	# START TLS if defined
	if ( defined UMI->config->{ldap_crud_cafile} &&
	     UMI->config->{ldap_crud_cafile} ne '' ) {
	  $mesg = try {
	    $ldap->start_tls(
			     verify => 'none',
			     cafile => UMI->config->{ldap_crud_cafile},
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

    my $mesg = $ldap->bind(
			   sprintf( "%s=%s,%s",
				    $self->cfg->{rdn}->{acc_root},
				    $self->uid,
				    $self->cfg->{base}->{acc_root} ),
			   password => $self->pwd,
			   version  => 3,
			   # start_tls => 1,
			   # start_tls_options   => { verify => 'none',
			   # 			    cafile => '/usr/local/etc/openldap/norse.digital.pem',
			   # 			    checkcrl => 0,
			   # 			  },
			  );
    
    if ( $mesg->is_error ) {
      warn '#' x 60 . "\nUMI WARNING: Net::LDAP->bind related problem occured!" .
    	"\nerror_name: " . $mesg->error_name .
    	"\nerror_desc: " . $mesg->error_desc .
    	"\nerror_text: " . $mesg->error_text .
    	"\nserver_error: " . $mesg->server_error;
    }
    return $ldap;
  };


=head2 last_uidNumber

Method to get last uidNumber for base ou=People,dc=umidb

it uses sub last_seq_val()

=cut

has 'last_uidNumber' => ( is       => 'ro',
			  isa      => 'Str',
			  required => 0, lazy => 1,
			  builder  => 'build_last_uidNumber', );

sub build_last_uidNumber {
  my $self = shift;
  return $self->last_seq_val({ base => $self->cfg->{base}->{acc_root},
			       attr => 'uidNumber', });
}

=head2 last_gidNumber

Method to get last gidNumber for base ou=group,dc=umidb

it uses sub last_seq_val()

=cut

has 'last_gidNumber' => ( is       => 'ro',
			  isa      => 'Str',
			  required => 0, lazy => 1,
			  builder  => 'build_last_gidNumber', );

sub build_last_gidNumber {
  my $self = shift;
  return $self->last_seq_val({ base => $self->cfg->{base}->{acc_root},
			       attr => 'gidNumber', });
}


=head2 last_seq_val

find the latest number in sequence for one single attribute requested

like for uidNumber or gidNumber

on input it expects hash

    base => base to search in (mandatory)
    attr => attribute name to search for the latest seq number for (mandatory)
    scope => scope (optional, default is `one')
    deref => deref (optional, default is `never')

return value in success is the last number in sequence of the attribute values

return value in error is message from method err()

=cut

sub last_seq_val {
  my ($self, $args) = @_;
  my $arg = { base  => $args->{base},
	      attr  => $args->{attr},
	      scope => $args->{scope} || 'one',
	      deref => $args->{deref} || 'never', };

  my $callername = (caller(1))[3];
  $callername = 'main' if ! defined $callername;
  my $return = 'call to LDAP_CRUD->last_gidNumber from ' . $callername . ': ';

  $self->reset_ldap;
  my $mesg =
    $self->ldap->search( base   => $arg->{base},
			 scope  => $arg->{scope},
			 filter => '(' . $arg->{attr} . '=*)',
			 attrs  => [ $arg->{attr} ],
			 deref => $arg->{deref}, );

  if ( $mesg->code ) {
    $return .= $self->err( $mesg );
  } else {
    my @arr = $mesg->sorted ( $arg->{attr} );
    $return = $arr[$#arr]->get_value( $arg->{attr} );
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
  my $arg = { base => $args->{base},
	      attr => $args->{attr}, # one single attribute sequence of we calculate
	      scope => $args->{scope} || 'one',
	      filter => $args->{filter} || '(objectClass=*)',
	      seq_pfx => $args->{seq_pfx},
	      seq_cnt => 0, };

  my $mesg = $self->ldap->search( base => $arg->{base},
				  scope => $arg->{scope},
				  filter => $arg->{filter},
				  attrs => [ $arg->{attr} ], );
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
  my ($self, $mesg, $debug) = @_;
  # p $mesg;
# to finish #   use Log::Contextual qw( :log :dlog set_logger with_logger );
# to finish #   use Log::Contextual::SimpleLogger;
# to finish # 
# to finish #   my $logger = Log::Contextual::SimpleLogger->new({
# to finish # 						   levels => [qw( trace debug )]
# to finish # 						  });
# to finish # 
# to finish #   set_logger $logger;
# to finish # 
# to finish #   log_debug { Dumper($self) . "\n" . $self->err( $mesg ) };

  my $caller = (caller(1))[3];
  my $err = {
	     code => defined $mesg->code ? $mesg->code : 'NA',
	     name => ldap_error_name($mesg),
	     text => ldap_error_text($mesg),
	     desc => ldap_error_desc($mesg),
	     srv => $mesg->server_error,
	     caller => $caller ? $caller : 'main',
	     matchedDN => $mesg->{matchedDN},
	     supplementary => '',
	    };

  $err->{supplementary} .= sprintf('<li><h6><b>matchedDN:</b><small> %s</small><h6></li>', $err->{matchedDN})
    if $err->{matchedDN} ne '';

  $err->{supplementary} = '<div class="well well-sm"><ul class="list-unstyled">' . $err->{supplementary} . '</ul></div>'
    if $err->{supplementary} ne '';
  
  $err->{html} = sprintf( 'call from <em>%s</em>: <dl class="dl-horizontal">
  <dt>admin note</dt><dd>%s</dd>
  <dt>supplementary data</dt><dd>%s</dd>
  <dt>code</dt><dd>%s</dd>
  <dt>error name</dt><dd>%s</dd>
  <dt>error text</dt><dd><em><small><pre>%s</pre></small></em></dd>
  <dt>error description</dt><dd>%s</dd>
  <dt>server_error</dt><dd>%s</dd>
</dl>',
			   $caller,
			   defined $self->cfg->{err}->{$mesg->code} && $self->cfg->{err}->{$mesg->code} ne '' ?
			   $self->cfg->{err}->{$mesg->code} : '',
			   $err->{supplementary},
			   $mesg->code,
			   ldap_error_name($mesg),
			   ldap_error_text($mesg),
			   ldap_error_desc($mesg),
			   $mesg->server_error
			 );

  p $err if defined $debug && $debug > 0;
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

  if ( defined $args->{dn} &&
       $args->{dn} ne '' ) {
    my @args_arr = split(/,/, $args->{dn});
    $args->{filter} = shift @args_arr;
    $args->{base} = join(',', @args_arr);
    $args->{scope} = 'one';
  }

  my $arg = {
  	     base   => $args->{base},
  	     scope  => $args->{scope} || 'sub',
  	     filter => $args->{filter} || '(objectClass=*)',
  	     deref  => $args->{deref} || 'never',
  	     attrs  => $args->{attrs} || [ '*' ],
  	     sizelimit => defined $args->{sizelimit} ? $args->{sizelimit} : 20,
  	    };

  return $self->ldap->search( base => $arg->{base},
			      scope => $arg->{scope},
			      filter => $arg->{filter},
			      deref => $arg->{deref},
			      attrs => $arg->{attrs},
			      sizelimit => $arg->{sizelimit},
			    );
}


=head2 add

Net::LDAP->add wrapper

=cut

sub add {
  my ($self, $dn, $attrs) = @_;

  my $callername = (caller(1))[3];
  $callername = 'main' if ! defined $callername;
  my $return;
  my $msg;
  if ( ! $self->dry_run ) {
    $msg = $self->ldap->add ( $dn, attrs => $attrs, );
    if ($msg->is_error()) {
      $return = $self->err( $msg );
      $return->{caller} = 'call to LDAP_CRUD->add from ' . $callername . ': ';
    } else {
      $return = 0;
    }
  } else {
    $return = $msg->ldif;
  }
  return $return;
}


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
	push @{$arg->{final_message}->{error}}, $self->err($mesg)->{html};
      } else {
	push @{$arg->{final_message}->{success}},
	  '<form role="form" method="POST" action="' . UMI->uri_for_action("searchby/index") . '">' .
	  '<button type="submit" class="btn btn-link btn-xs" title="click to open this object" name="ldap_subtree" value="' .
	  $entry->dn . '">successfully added: ' . $entry->dn . '</button></form>';
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
				   scope => 'base' );
    $arg->{dst}->{has_branch} = $result->count;
  } else {
    $arg->{dst}->{has_branch} = 1; # it is rather than it has
    $arg->{dst}->{branch_dn}->{str} = $arg->{dst}->{str};
  }

  $result = $self->search( { base  => $arg->{dst}->{str}, scope => 'base', } );
  $entry = $result->entry(0);
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
    foreach ( $clone->attributes ) {
      push @{$attrs}, $_ => $clone->get_value( $_, asref => 1 );
    }
    $mesg = $self->add( $clone->dn, $attrs );
    if ( $mesg && $mesg->{name} eq 'LDAP_ALREADY_EXISTS' ) {
      push @{$return->{warning}}, $mesg if $mesg;
    } else {
      push @{$return->{error}}, $mesg if $mesg;
    }
  }
  undef $attrs;

  # src BRANCH already EXISTS in dst subtree and here
  # we are to process all objects bellow it (bellow src branch)
  if ( $arg->{type} eq 'people' && $arg->{src}->{is_branch} ) {
    $result = $self->search( { base  => $arg->{src}->{str}, scope => 'children', } );
    foreach $entry ( $result->entries ) {
      $clone = $entry->clone;
      $mesg = $clone->dn(sprintf('%s,%s',
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

    ### FINISH
    # here we have to delete src subtree recursively if @{$return->{error}} is empty
    $self->delr( $arg->{src}->{str} )
      if ref($return) ne "HASH" ||
      ( ref($return) eq "HASH" && $#{$return->{error}} < 0);
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
    $mesg = $self->add( $clone->dn, $attrs );
    undef $attrs;
    push @{$return->{error}}, $mesg if $mesg;

    ### FINISH
    # here we have to delete src dn if @{$return->{error}} is empty
    # $self->del( $arg->{src}->{str} ) if $return != 0 && $#{$return->{error}} > -1;
    $self->del( $arg->{src}->{str} )
      if ref($return) ne "HASH" ||
      ( ref($return) eq "HASH" && $#{$return->{error}} < 0);
  }
  return $return;
}


=head2 del

TODO

to backup entry deleted

https://metacpan.org/pod/Net::LDAP::Control::PreRead

=cut


sub del {
  my ($self, $dn) = @_;

  my $callername = (caller(1))[3];
  $callername = 'main' if ! defined $callername;
  my $return; # = 'call to LDAP_CRUD->del from ' . $callername . ': ';

  my $g_mod = $self->del_from_groups($dn);
  push @{$return->{error}}, $g_mod->{error} if defined $g_mod->{error};

  if ( ! $self->dry_run ) {
    my $msg = $self->ldap->delete ( $dn );
    if ($msg->code) {
      # $return .= $self->err( $msg );
      if ( $msg && $msg->error_name eq 'LDAP_NO_SUCH_OBJECT' ) {
	push @{$return->{warning}}, $self->err( $msg ) if $msg;
      } else {
	push @{$return->{error}}, $self->err( $msg ) if $msg;
      }
    } else {
      $return = 0;
    }
  } else {
    $return = 0;
  }
  return $return;
}


=head2 delr

recursive deletion

=cut


sub delr {
  my ($self, $dn) = @_;

  my $callername = (caller(1))[3];
  $callername = 'main' if ! defined $callername;
  my $return; # = 'call to LDAP_CRUD->del from ' . $callername . ': ';

  my $g_mod = $self->del_from_groups($dn);
  push @{$return->{error}}, $g_mod->{error} if defined $g_mod->{error};

  if ( ! $self->dry_run ) {
    my $result = $self->ldap->search( base   => $dn,
				      filter => "(objectclass=*)" );
    my @dnlist;
    foreach my $entry ( $result->all_entries ) {
      push @dnlist, $entry->dn;
    }
    # explode dn into an array and push them to indexed hash of arrays
    my %HoL;
    my $i = 0;
    my $base = join('', pop [ split(",", $dn) ]);

    for ( @dnlist ) {
      s/,$base//;
      $HoL{$i} = [ split(",", $_) ];
      $i++;
    }

    # !!!
    # here we need to clean all attributes of the different objects which
    # could contain DN of any object to be deleted
    # !!!
    
    my $msg;
    # sorted descending by number of members (leaf nodes last)
    foreach my $key ( sort { @{$HoL{$b}} <=> @{$HoL{$a}} } keys %HoL ) {
      my $dn2del = join(",", @{ $HoL{$key} }).",$base";
      $msg = $self->ldap->delete($dn2del);
      if ($msg->code) {
	# $return .= $self->err( $msg );
	if ( $msg && $msg->error_name eq 'LDAP_NO_SUCH_OBJECT' ) {
	  push @{$return->{warning}}, $self->err( $msg ) if $msg;
	} else {
	  push @{$return->{error}}, $self->err( $msg ) if $msg;
	}
      } else {
	$return = 0;
      }
    }
    # $self->ldap->update;
    # $self->ldap->unbind;
  } else {
    $return = 0;
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

  my $callername = (caller(1))[3];
  $callername = 'main' if ! defined $callername;
  my $return; # = 'call to LDAP_CRUD->del_from_groups from ' . $callername . ': ';

  my ($result, $res_entry, $group, $g_dn, $g_res, @g_memb_old, @g_memb_new, $mesg);
  # p $dn;
  # p $self->get_root_obj_dn($dn);
  if ( $dn eq $self->get_root_obj_dn($dn) ) { # posixGroup first
    # get uid from the root object
    $result = $self->ldap->search( base   => $dn,
				   filter => "(objectClass=*)",
				   scope  => 'base',
				   attrs  => [ 'uid' ] );
    $res_entry = $result->entry(0);
    my $uid = $res_entry->get_value( 'uid' );

    # get all posixGroup-s where this uid is member
    $result = $self->ldap->search( base   => $self->{cfg}->{base}->{db},
				   filter => "(&(objectClass=posixGroup)(memberUid=$uid))",
				   attrs  => [ 'cn' ],);
    foreach $group ( $result->all_entries ) {
      $g_dn = $group->dn;
      $g_res = $self->ldap->search( base   => $g_dn,
				    filter => "(objectClass=*)",
				    scope  => 'base' );
      @g_memb_old = $g_res->entry(0)->get_value('memberUid');
      @g_memb_new = grep {$_ ne $uid} @g_memb_old;
      # &p(\"$dn is root and belongs to posixGroup group $g_dn:");
      # p @g_memb_old; p @g_memb_new;
      $mesg = $self->modify( $g_dn,
			     [ replace => [ memberUid => \@g_memb_new ] ], );
      if ( $mesg ) {
	push @{$return->{error}}, $mesg->{html};
      } else {
	$return->{success} = 'Group was modified.';
      }
    }
  } else { # groupOfNames is second
    # get all groupOfNames where this dn is member
    $result = $self->ldap->search( base   => $self->{cfg}->{base}->{db},
				   filter => "(&(objectClass=groupOfNames)(member=$dn))",
				   attrs  => [ 'cn' ],);
    foreach $group ( $result->all_entries ) {
      $g_dn = $group->dn;
      $g_res = $self->ldap->search( base   => $g_dn,
				    filter => "(objectClass=*)",
				    scope  => 'base' );
      @g_memb_old = $g_res->entry(0)->get_value('member');
      @g_memb_new = grep {$_ ne $dn} @g_memb_old;
      # &p(\"$dn belongs to groupOfNames $g_dn:");
      # p @g_memb_old; p @g_memb_new;
      $mesg = $self->modify( $g_dn,
			     [ replace => [ member => \@g_memb_new ] ], );
      if ( $mesg ) {
	push @{$return->{error}}, $mesg->{html};
      } else {
	$return->{success} = 'Group was modified.';
      }
    }
  }
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

  $msg_usr = $self->search ( { base => $args->{dn},
			       sizelimit => 0, } );
  if ( $msg_usr->is_error() ) {
    $return->{error} = $self->err( $msg_usr )->{html};
  } else {
    # bellow we are blocking services
    my @ent_toblock = $msg_usr->entries;
    foreach $ent_svc ( @ent_toblock ) {
      if ( $ent_svc->exists('userPassword') ) {
	$userPassword = $self->pwdgen;
	$msg = $self->modify( $ent_svc->dn,
			      [ replace => [ userPassword => $userPassword->{ssha}, ], ], );
	$return->{error} .= $self->err( $msg )->{html} if ref($msg) eq 'HASH';
      }

      if ( $ent_svc->exists('sshPublicKey') ) {
	@userPublicKeys = $ent_svc->get_value('sshPublicKey');
	@keys = map { $_ !~ /^from="127.0.0.1" / ? sprintf('from="127.0.0.1" %s', $_) : $_ } @userPublicKeys;
	$msg = $self->modify( $ent_svc->dn,
			      [ replace => [ sshPublicKey => \@keys, ],], );
	$return->{error} .= $self->err( $msg )->{html} if ref($msg) eq 'HASH';
      }
      $return->{success} .= $ent_svc->dn . "\n";
    }

    # is this user in block group?
    my $blockgr_dn =
      sprintf('cn=%s,%s',
	      $self->cfg->{stub}->{group_blocked},
	      $self->cfg->{base}->{group});

    $msg = $self->search ( { base => $self->cfg->{base}->{group},
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
	$ent_chg = $msg_chg->entry(0);
	@blockgr = $ent_chg->get_value('memberUid');
	push @blockgr, substr( (split /,/, $args->{dn})[0], 4 );
	$ent_chg = $self->modify( $blockgr_dn,
				  [ replace => [ memberUid => \@blockgr, ],], );
	if ( $ent_chg != 0 && defined $ent_chg->{error} ) {
	  $return->{error} .= $self->err( $ent_chg )->{html};
	}
      }
    }
  }
  # p $return;
  return $return;
}


=head2 modify

Net::LDAP->modify( changes => ... ) wrapper

=cut

sub modify {
  my ($self, $dn, $changes ) = @_;
  my ( $return, $msg );
  if ( ! $self->dry_run ) {
    $msg = $self->ldap->modify ( $dn, changes => $changes, );
    if ($msg->is_error()) {
      $return = $self->err( $msg );
    } else { $return = 0; }
  } else { $return = $msg->ldif; }
  # p [ $dn, $changes, $return];
  return $return;
}

=head2 ldif

LDIF export

=cut

sub ldif {
  my ($self, $dn, $recursive, $sysinfo) = @_;
  use POSIX qw(strftime);
  my $ts = strftime "%Y-%m-%d %H:%M:%S", localtime;
  my $return->{ldif} = sprintf("
## LDIF export DN: \"%s\"
##   Search Scope: \"base\"
##  Search Filter: \"(objectClass=*)\"
##
## LDIF generated on %s, by UMI user %s\n##\n", $dn, $ts, $self->uid);

    my $msg = $self->ldap->search ( base => $dn,
				    scope => $recursive ? 'sub' : 'base',
				    filter => 'objectClass=*',
				    attrs => $sysinfo ? [ '*',
							  'createTimestamp',
							  'creatorsName',
							  'entryCSN',
							  'entryDN',
							  'entryUUID',
							  'hasSubordinates',
							  'modifiersName',
							  'modifyTimestamp',
							  'structuralobjectclass',
							  'subschemaSubentry',
							] : [ '*' ], );
  if ($msg->is_error()) {
    $return->{error} .= $self->err( $msg );
  } else {
    my @entries = $msg->sorted;
    foreach my $entry ( @entries ) {
      $return->{ldif} .= $entry->ldif;
    }
    $return->{success} .= sprintf('LDIF for object with DN:<blockquote class="mono">%s</blockquote> generated including%s recursion and including%s system data.',
				  $dn,
				  ! $recursive ? ' no' : '',
				  ! $sysinfo ? ' no' : '' );
  }
  $return->{outfile_name} = join('_', split(/,/,canonical_dn($dn, casefold => 'none', reverse => 1, )));
  $return->{dn} = $dn;
  $return->{recursive} = $recursive;
  $return->{sysinfo} = $sysinfo;
  return $return;
}

=head2 vcard

vCard export

on input we expect

    - user DN vCard to be created for
    - vCard type to generate (onscreen or file)
    - non ASCII fields transliterated or not

=cut

sub vcard {
  my ($self, $args) = @_;
  use POSIX qw(strftime);
  use MIME::Base64;

  my $ts = strftime "%Y%m%d%H%M%S", localtime;
  my $arg = { dn => $args->{vcard_dn},
	      type => $args->{vcard_type},
	      translit => $args->{vcard_translit} || 0, };

  my ($msg, $branch, @branches, $branch_entry, $leaf, @leaves, $leaf_entry, $entry, @entries, @vcard, $return, $tmp);
  $msg = $self->ldap->search ( base => $arg->{dn}, scope => 'base', filter => 'objectClass=*', );
  if ($msg->is_error()) {
    $return->{error} .= $self->err( $msg )->{html};
  } else {
    push @vcard, 'BEGIN:VCARD', 'VERSION:2.1';
    $entry = $msg->as_struct;

    $arg->{sn} = $self->utf2qp( $entry->{$arg->{dn}}->{sn}->[0], $arg->{translit} );
    $arg->{givenName} = $self->utf2qp( $entry->{$arg->{dn}}->{givenname}->[0], $arg->{translit} );
    
    push @vcard, sprintf('N%s:%s;%s;;;',
			 $arg->{sn}->{type} eq 'qp' ? ';CHARSET=UTF-8;ENCODING=QUOTED-PRINTABLE' : '',
			 $arg->{givenName}->{str}, $arg->{sn}->{str} );
  use MIME::QuotedPrint;

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
      foreach ( @{$entry->{$arg->{dn}}->{telephonenumber}} ) {
	push @{$arg->{vcard}->{telephonenumber}}, sprintf('TEL;TYPE=work:%s', $_);
      }
      $arg->{vcard}->{telephonenumber} = join("\n", @{$arg->{vcard}->{telephonenumber}});
      push @vcard, $arg->{vcard}->{telephonenumber};
    }

    my $scope = $arg->{dn} =~ /^.*=.*,authorizedService.*$/ ? 'sub' : 'one';
    
    # --- EMAIL -------------------------------------------------------
    if ( $entry->{$arg->{dn}}->{mail} ) {
      foreach ( @{$entry->{$arg->{dn}}->{mail}} ) {
	push @{$arg->{email}}, 'EMAIL;WORK:' . $_;
      }
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
		push @{$arg->{email}}, 'EMAIL;TYPE=work:' . $leaf_entry->get_value('uid');
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
		push @{$arg->{xmpp}}, 'X-JABBER;TYPE=work:' . $leaf_entry->get_value('uid');
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
	     'attr_value' => $entry->get_value( $must->{'name'} ) || undef,
	     'desc' => $must->{'desc'} || undef,
	     'single-value' => $must->{'single-value'} || undef,
	     'max_length' => $must->{'max_length'} || undef,
	     'equality' => $must->{'equality'} || undef,
	     'syntax' => { desc => $syntmp->{desc},
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
	     'attr_value' => $entry->get_value( $may->{'name'} ) || undef ,
	     'desc' => $may->{'desc'} || undef ,
	     'single-value' => $may->{'single-value'} || undef ,
	     'max_length' => $may->{'max_length'} || undef ,
	     'equality' => $may->{'equality'} || undef ,
	     'syntax' => { desc => $syntmp->{desc},
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
	     base => $args->{'base'},
	     filter => $args->{'filter'},
	     scope => $args->{'scope'},
	     attrs => $args->{'attrs'},
	    };
  my $mesg =
    $self->ldap->search(
			base => $arg->{'base'},
			filter => $arg->{'filter'},
			scope => $arg->{'scope'},
			attrs => [ $arg->{'attrs'} ],
			deref => 'never',
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
  my $type = $args->{'type'};
  my $params = $args->{'params'};

  my $attrs = $self->params2attrs({
				   type => $type,
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
				   type => $type,
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
      '<span style="font-size: 140%" class="glyphicon glyphicon-ok-sign"></span>' .
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

crawls all $c->req->params and prepares attrs hash ref of dn and attrs
to be fed to ->add for object creation

=cut

sub params2attrs {
  my ( $self, $args ) = @_;

  my $arg = {
	     type => $args->{'type'},
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
  return { dn => $dn,
	   attrs => $attrs };
}

=head2 dhcp_lease

method to stat used static DHCP leases (isc-dhcpd layout)

info gathered:

    - available (unused) IP addresses
    - used leases

the base for leases is DHCP network object generated by isc-dhcpd
script `dhcpd-conf-to-ldap'

    cn=172.16.0.0,cn=XXX01 DHCP Config,ou=XXX01,...,ou=ZZZ,ou=DHCP,dc=umidb

each net contains own uniq domain-name

logic for lease assignment is:

user -> org of user -> domain/s of org of user -> DHCP net for the domain

arguments method expects

    fqdn => fqdn of the network
    what => keyword, one of: used, ip, mac, hostname, all (the type of data to return)

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
  my $return;
  my $arg = {
	     fqdn => $args->{net},
	     what => $args->{what} || 'stub', # used, ip, mac, hostname, all
	    };

  my $mesg =
    $self->search({ base => $self->cfg->{base}->{dhcp},
		    filter => sprintf('dhcpOption=domain-name "%s"', $arg->{fqdn}),
		    attrs => [ 'cn', 'dhcpNetMask', 'dhcpRange' ], });

  if (! $mesg->count) {
    $return->{error} = 'DHCP configuration for net choosen, looks absent.';
    return $return;
  } else {
    my ( $i, $net_addr, $addr_num, $range_left, $range_right, @leases, $lease, $ip, $mac, $hostname );
    my @net = $mesg->entries;
    foreach (@net) {
      $return->{net_dn} = $_->dn;
      $net_addr = unpack('N', pack ('C4', split('\.', $_->get_value('cn')))); # IPv4 to decimal
      $addr_num = 2 ** ( 32 - $_->get_value('dhcpNetMask'));
      ( $range_left, $range_right ) = split(" ", $_->get_value('dhcpRange'));
      $range_left = unpack('N', pack ('C4', split('\.', $range_left)));
      $range_right = unpack('N', pack ('C4', split('\.', $range_right)));

      $mesg =
	$self->search({ base => $_->dn,
			scope => 'children',
			attrs => [ 'cn', 'dhcpStatements', 'dhcpHWAddress' ],
			sizelimit => 256, });

      @leases = $mesg->sorted('dhcpStatements');
      foreach ( @leases ) {
	$ip = unpack('N', pack ('C4', split('\.', (split(/\s+/, $_->get_value('dhcpStatements')))[1])));
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
	next if $return->{used}->{ip}->{$i} || ( $i >= $range_left && $i <= $range_right );
	push @{$return->{available}}, $i;
      }
    }
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
    return [ map join(".",unpack("C4", pack("N",$_))), sort(@{$return->{available}}) ]; # decimal to IPv4
  }
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

  my $mesg = $self->search({
			    base => $self->{'cfg'}->{'base'}->{'org'},
			    scope => 'one',
			    attrs => [ qw(ou physicaldeliveryofficename l) ],
			    sizelimit => 0
			   });
  my @headOffices = $mesg->sorted('physicaldeliveryofficename');
  foreach my $headOffice (@headOffices) {
    $mesg = $self->search({
			   base => $headOffice->dn,
			   # filter => '*',
			   attrs => [ qw(ou physicaldeliveryofficename l) ],
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
  my $self = shift;
  # bld_select has to be fixed to deal with associatedDomains # return $self->bld_select({ base => $self->cfg->{base}->{org},
  # bld_select has to be fixed to deal with associatedDomains # 			     attr => [ 'associatedDomain', 'associatedDomain', ],
  # bld_select has to be fixed to deal with associatedDomains # 			     scope => 'sub',
  # bld_select has to be fixed to deal with associatedDomains # 			     filter => '(associatedDomain=*)', });

  my @domains; # = ( {value => '0', label => '--- select domain ---', selected => 'selected'} );
  my $mesg = $self->search( { base => $self->cfg->{base}->{org},
			      filter => 'associatedDomain=*',
			      sizelimit => 0,
			      attrs => ['associatedDomain' ],
			    } );
  my $err_message = '';
  if ( ! $mesg->count ) {
    $err_message = '<div class="alert alert-danger">' .
      '<span style="font-size: 140%" class="icon_error-oct" aria-hidden="true"></span><ul>' .
      $self->err($mesg) . '</ul></div>';
  }

  my @entries = $mesg->sorted('associatedDomain');
  my (@i, @j);
  foreach my $entry ( @entries ) {
    @i = $entry->get_value('associatedDomain');
    foreach (@i) {
      push @j, $_;
    }
  }
  @domains = map { { value => $_, label => $_ } } sort @j;
  
  return \@domains;
}

=head2 select_group

Method, options builder for select element of groups

uses sub bld_select()

=cut

has 'select_group' => ( traits => ['Array'],
			is => 'ro', isa => 'ArrayRef', required => 0, lazy => 1,
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
	       is => 'ro', isa => 'ArrayRef', required => 0, lazy => 1,
	       builder => '_build_select_radprofile',
	     );

sub _build_select_radprofile {
  my $self = shift;
  return $self->bld_select({ base => $self->cfg->{base}->{rad_profiles}, });
}

=head2 select_radgroup

Method, options builder for select element of rad-groups

uses sub bld_select()

=cut

has 'select_radgroup' => ( traits => ['Array'],
	       is => 'ro', isa => 'ArrayRef', required => 0, lazy => 1,
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
			     attr => [ 'destinationIndicator', ]});
  # 'physicalDeliveryOfficeName' ]});
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
  my $arg = { base  => $args->{base},
	      attr  => $args->{attr} || [ 'cn', 'description' ],
	      filter => $args->{filter} || '(objectClass=*)',
	      scope => $args->{scope} || 'one',
	      sizelimit => $args->{sizelimit} || 0, };

  my $callername = (caller(1))[3];
  $callername = 'main' if ! defined $callername;
  my $return = 'call to LDAP_CRUD->bld_select from ' . $callername . ': ';

  $self->reset_ldap;
  my $mesg =
    $self->search({ base   => $arg->{base},
		    scope  => $arg->{scope},
		    attrs  => $arg->{attr},
		    filter => $arg->{filter},
		    sizelimit => $arg->{sizelimit}, });

  my $err_message = '';
  if ( ! $mesg->count ) {
    $err_message = '<div class="alert alert-danger">' .
      '<span style="font-size: 140%" class="icon_error-oct" aria-hidden="true"></span><ul>' .
	$self->err($mesg)->{html} . '</ul></div>';
  }

  my @entries = $mesg->sorted( $arg->{attr}->[0] );
  my ( @arr, @arr_meta, $hash_uniq );

  # !!! TO FINISH (need to do)
  # attr0_val : attr0_val
  # attr0_val : attr1_val
  # dn : attr0_val
  # dn : attr0_val + ... + attrX_val
  
  if ( $#{$arg->{attr}} == 0 ) {
    @arr_meta = map { $_->get_value( $arg->{attr}->[0] ) } @entries;
    $hash_uniq->{$_} = 1 foreach ( @arr_meta );
    @arr = map { value => $_, label => $_, }, sort keys %{$hash_uniq};
  } else {
    foreach ( @entries ) {
      $arg->{toutfy} = sprintf('%s%s',
			       $_->get_value( $arg->{attr}->[0] ),
			       $_->exists($arg->{attr}->[1]) ? ' --- ' . $_->get_value( $arg->{attr}->[1] ) : '');
      utf8::decode($arg->{toutfy});
      push @arr, { value => $_->dn,
		   label => $arg->{toutfy}, };
    }
  }

  return \@arr;
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
  my $arg =
    { $self->cfg->{rdn}->{acc_root} => $args->{$self->cfg->{rdn}->{acc_root}},
      authorizedservice => $args->{authorizedservice},
      associateddomain =>
      sprintf('%s%s',
	      defined $self->cfg->{authorizedService}->{$args->{authorizedservice}}->{associateddomain_prefix}
	      ->{$args->{associateddomain}} ?
	      $self->cfg->{authorizedService}->{$args->{authorizedservice}}->{associateddomain_prefix}
	      ->{$args->{associateddomain}} : '',
	      $args->{associateddomain}), };

  $arg->{dn} =
    sprintf("authorizedService=%s@%s,%s=%s,%s",
	    $arg->{authorizedservice},
	    $arg->{associateddomain},
	    $self->cfg->{rdn}->{acc_root},
	    $args->{$self->cfg->{rdn}->{acc_root}},
	    $self->cfg->{base}->{acc_root});

  my ( $return, $if_exist);
  $arg->{add_attrs} =
    [ uid => sprintf('%s@%s', $arg->{$self->cfg->{rdn}->{acc_root}}, $arg->{authorizedservice}),
      objectClass => $self->cfg->{objectClass}->{acc_svc_branch},
      authorizedService =>
      sprintf('%s@%s%s', $arg->{authorizedservice},
	      defined $self->cfg->{authorizedService}->{$args->{authorizedservice}}
	      ->{associateddomain_prefix}->{$args->{associateddomain}} ?
	      $self->cfg->{authorizedService}->{$args->{authorizedservice}}
	      ->{associateddomain_prefix}->{$args->{associateddomain}} : '',
	      $arg->{associateddomain}), ];

  $if_exist =
    $self->search( { base => $arg->{dn}, scope => 'base', attrs => [ 'authorizedService' ], } );
  if ( $if_exist->count ) {
    $return->{warning} = 'branch DN: <b>&laquo;' . $arg->{dn} . '&raquo;</b> '
      . 'was not created since it <b>already exists</b>, I will use it further.';
    $return->{dn} = $arg->{dn};
  } else {
    my $mesg = $self->add( $arg->{dn}, $arg->{add_attrs} );
    if ( $mesg ) {
      $return->{error} =
	sprintf('Error during %s branch (dn: %s) creation occured: %s<br><b>srv: </b><pre>%s</pre><b>text: </b>%s',
		uc($arg->{authorizedservice}), $arg->{dn}, $mesg->{html}, $mesg->{srv}, $mesg->{text});
    } else {
      $return->{dn} = $arg->{dn};
      $return->{associateddomain_prefix} = $arg->{'associateddomain_prefix'};
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
  my $arg =
    { basedn => $args->{basedn},
      service => $args->{authorizedservice},
      associatedDomain =>
      sprintf('%s%s',
	      defined $self->cfg->{authorizedService}->{$args->{authorizedservice}}
	      ->{associateddomain_prefix}->{$args->{associateddomain}} ?
	      $self->cfg->{authorizedService}->{$args->{authorizedservice}}
	      ->{associateddomain_prefix}->{$args->{associateddomain}} : '',
	      $args->{associateddomain}),
      uidNumber => $args->{uidNumber},
      givenName => $args->{givenName},
      sn => $args->{sn},
      login => $args->{login},
      password => $args->{password},
      description => $args->{description} || 'no description yet',
      gecos => $self->utf2lat( sprintf('%s %s', $args->{givenName}, $args->{sn}) ),
      telephoneNumber => $args->{telephoneNumber} || '666',
      jpegPhoto => $args->{jpegPhoto} || undef,
	     
      to_sshkeygen => $args->{to_sshkeygen} || undef,
      sshpublickey => $args->{sshpublickey} || undef,
      sshpublickeyfile => $args->{sshpublickeyfile} || undef,
      sshkeydescr => $args->{sshkeydescr} || undef,
      # !!! here we much need check for cert existance !!!
      userCertificate => $args->{userCertificate} || '',
      umiOvpnCfgIfconfigPush => $args->{umiOvpnCfgIfconfigPush} || 'NA',
      umiOvpnAddStatus => $args->{umiOvpnAddStatus} || 'blocked',
      umiOvpnAddDevType => $args->{umiOvpnAddDevType} || 'NA',
      umiOvpnAddDevMake => $args->{umiOvpnAddDevMake} || 'NA',
      umiOvpnAddDevModel => $args->{umiOvpnAddDevModel} || 'NA',
      umiOvpnAddDevOS => $args->{umiOvpnAddDevOS} || 'NA',
      umiOvpnAddDevOSVer => $args->{umiOvpnAddDevOSVer} || 'NA',
	     
      radiusgroupname => $args->{radiusgroupname} || '',
      radiusprofiledn => $args->{radiusprofiledn} || '', };
  my ( $return, $if_exist );

  $arg->{prefixed_uid} =
    sprintf('%s%s',
	    defined $self->cfg->{authorizedService}->{$arg->{service}}->{login_prefix} ?
	    $self->cfg->{authorizedService}->{$arg->{service}}->{login_prefix} : '',
	    $arg->{login});
  
  $arg->{uid} = sprintf('%s@%s',
			$arg->{prefixed_uid},
			$arg->{associatedDomain});
  $arg->{dn} = sprintf('uid=%s,%s',
		       $arg->{uid},
		       $arg->{basedn});

  my ($authorizedService, $sshkey, $authorizedService_add, $jpegPhoto_file, $sshPublicKey );

  if ( $arg->{service} eq 'ovpn' ||
       $arg->{service} eq 'ssh' ||
       ( $arg->{service} eq '802.1x-mac' ||
	 $arg->{service} eq '802.1x-eap-tls' ) ||
       $arg->{service} eq 'web' ) {
    $authorizedService = [];
    $authorizedService = [ description => $arg->{description}, ]; # ??? looks like it is not needed ... except web may be ...
  } else {
    $authorizedService = [
			  objectClass => $self->cfg->{objectClass}->{acc_svc_common},
			  authorizedService => $arg->{service} . '@' . $arg->{associatedDomain},
			  associatedDomain => $arg->{associatedDomain},
			  uid => $arg->{uid},
			  cn => $arg->{uid},
			  givenName => $arg->{givenName},
			  sn => $arg->{sn},
			  uidNumber => $arg->{uidNumber},
			  loginShell => $self->cfg->{stub}->{loginShell},
			  gecos => $self->utf2lat( sprintf('%s %s', $args->{givenName}, $args->{sn}) ),
			  description => $arg->{description} ne '' ? $arg->{description} :
			  sprintf('%s: %s @ %s', uc($arg->{service}), $arg->{'login'}, $arg->{associatedDomain}),
			 ];
  }

  #=== SERVICE: mail =================================================
  if ( $arg->{service} eq 'mail') {
    push @{$authorizedService},
      homeDirectory => $self->cfg->{authorizedService}->{$arg->{service}}->{homeDirectory_prefix} .
      $arg->{associatedDomain} . '/' . $arg->{uid},
      'mu-mailBox' => 'maildir:/var/mail/' . $arg->{associatedDomain} . '/' . $arg->{uid},
      gidNumber => $self->cfg->{authorizedService}->{$arg->{service}}->{gidNumber},
      userPassword => $arg->{password}->{$arg->{service}}->{'ssha'},
      objectClass => [ 'mailutilsAccount' ];
  #=== SERVICE: xmpp =================================================
  } elsif ( $arg->{service} eq 'xmpp') {
    if ( defined $arg->{jpegPhoto} ) {
      $jpegPhoto_file = $arg->{jpegPhoto}->{'tempname'};
    } else {
      $jpegPhoto_file = $self->cfg->{authorizedService}->{$arg->{service}}->{jpegPhoto_noavatar};
    }

    push @{$authorizedService},
      homeDirectory => $self->cfg->{stub}->{homeDirectory},
      gidNumber => $self->cfg->{authorizedService}->{$arg->{service}}->{gidNumber},
      userPassword => $arg->{password}->{$arg->{service}}->{'ssha'},
      telephonenumber => $arg->{telephoneNumber},
      jpegPhoto => [ $self->file2var( $jpegPhoto_file, $return) ];

  #=== SERVICE: 802.1x ===============================================
  } elsif ( $arg->{service} eq '802.1x-mac' ||
	    $arg->{service} eq '802.1x-eap-tls' ) {
    undef $authorizedService;

    if ( $arg->{service} eq '802.1x-mac' ) {
      $arg->{dn} = sprintf('uid=%s,%s',
			   $self->macnorm({ mac => $arg->{login} }),
			   $arg->{basedn}); # DN for MAC AUTH differs
      push @{$authorizedService},
	objectClass => $self->cfg->{objectClass}->{acc_svc_802_1x},
	uid => $self->macnorm({ mac => $arg->{login} }),
	cn =>  $self->macnorm({ mac => $arg->{login} });
    } else {
      $arg->{dn} = sprintf('uid=%s,%s', $arg->{prefixed_uid}, $arg->{basedn}); # DN for EAP-TLS differs
      push @{$authorizedService},
	objectClass => $self->cfg->{objectClass}->{acc_svc_802_1x_eaptls},
	uid => $arg->{prefixed_uid},
	cn => $arg->{prefixed_uid};
    }

    push @{$authorizedService},
      authorizedService => $arg->{service} . '@' . $arg->{associatedDomain},
      userPassword => $arg->{password}->{$arg->{service}}->{clear},
      description => $arg->{description} ne '' ? $arg->{description} : sprints('%s: %s', uc($arg->{service}), $arg->{'login'});

    push @{$authorizedService},
      radiusprofiledn => $arg->{radiusprofiledn}
      if $arg->{radiusprofiledn} ne '';

    if ( $arg->{service} eq '802.1x-eap-tls' ) {
      $arg->{cert_info} =
	$self->cert_info({
			  cert => $self->file2var($arg->{userCertificate}->{'tempname'}, $return),
			  ts => "%Y%m%d%H%M%S",
			 });
      push @{$authorizedService},
	umiUserCertificateSn => '' . $arg->{cert_info}->{'S/N'},
	umiUserCertificateNotBefore => '' . $arg->{cert_info}->{'Not Before'},
	umiUserCertificateNotAfter => '' . $arg->{cert_info}->{'Not  After'},
	umiUserCertificateSubject => '' . $arg->{cert_info}->{'Subject'},
	umiUserCertificateIssuer => '' . $arg->{cert_info}->{'Issuer'},
	'userCertificate;binary' => $arg->{cert_info}->{cert};
    }

  #=== SERVICE: ssh ==================================================
  } elsif ( $arg->{service} eq 'ssh' ) {
    $sshPublicKey = $self->file2var( $arg->{sshpublickeyfile}->{tempname}, $return, 1)
      if defined $arg->{sshpublickeyfile};
    push @{$sshPublicKey}, $arg->{sshpublickey}
      if defined $arg->{sshpublickey} && $arg->{sshpublickey} ne '';

    $authorizedService = [
			  objectClass => $self->cfg->{objectClass}->{ssh},
			  sshPublicKey => [ @$sshPublicKey ],
			  uid => $arg->{uid},
			 ];

    push @{$authorizedService},
      description => $arg->{description} ne 'no description yet' ?
      $self->utf2lat( sprintf("%s\nNote: %s bytes file \"%s\" was uploaded",
			      $arg->{description},
			      $arg->{sshpublickeyfile}->{size},
			      $arg->{sshpublickeyfile}->{filename}) ) :
      $self->utf2lat( sprintf("Note: %s bytes file %s was uploaded",
			      $arg->{sshpublickeyfile}->{size},
			      $arg->{sshpublickeyfile}->{filename}) )
		      if defined $arg->{sshpublickeyfile};

  #=== SERVICE: ovpn =================================================
  } elsif ( $arg->{service} eq 'ovpn' ) {
    $arg->{dn} = 'cn=' . substr($arg->{userCertificate}->{filename},0,-4) . ',' . $arg->{basedn};
    $arg->{cert_info} =
      $self->cert_info({ cert => $self->file2var($arg->{userCertificate}->{'tempname'}, $return),
			 ts => "%Y%m%d%H%M%S", });
    $authorizedService = [
			  cn => substr($arg->{userCertificate}->{filename},0,-4),
			  associatedDomain => $arg->{associatedDomain},
			  objectClass => $self->cfg->{objectClass}->{ovpn},
			  umiOvpnCfgIfconfigPush => $arg->{umiOvpnCfgIfconfigPush},
			  umiOvpnAddStatus => $arg->{umiOvpnAddStatus},
			  umiUserCertificateSn => '' . $arg->{cert_info}->{'S/N'},
			  umiUserCertificateNotBefore => '' . $arg->{cert_info}->{'Not Before'},
			  umiUserCertificateNotAfter => '' . $arg->{cert_info}->{'Not  After'},
			  umiUserCertificateSubject => '' . $arg->{cert_info}->{'Subject'},
			  umiUserCertificateIssuer => '' . $arg->{cert_info}->{'Issuer'},
			  umiOvpnAddDevType => $arg->{umiOvpnAddDevType},
			  umiOvpnAddDevMake => $arg->{umiOvpnAddDevMake},
			  umiOvpnAddDevModel => $arg->{umiOvpnAddDevModel},
			  umiOvpnAddDevOS => $arg->{umiOvpnAddDevOS},
			  umiOvpnAddDevOSVer => $arg->{umiOvpnAddDevOSVer},
			  'userCertificate;binary' => $arg->{cert_info}->{cert},
			 ];
    push @{$return->{error}}, $arg->{cert_info}->{error} if defined $arg->{cert_info}->{error};
    
  #=== SERVICE: web ==================================================
  } elsif ( $arg->{service} eq 'web' ) {
    $authorizedService = [
			  objectClass => $self->cfg->{objectClass}->{acc_svc_web},
			  authorizedService => $arg->{service} . '@' . $arg->{associatedDomain},
			  associatedDomain => $arg->{associatedDomain},
			  uid => $arg->{uid},
			  userPassword => $arg->{password}->{$arg->{service}}->{'ssha'},
			 ];
  }

  # p $arg->{dn};
  # p $authorizedService;
  # p $sshPublicKey;
  my $mesg;
  # for an existent SSH object we have to modify rather than add
  $if_exist = $self->search( { base => $arg->{dn}, scope => 'base', } );
  if ( $arg->{service} eq 'ssh' && $if_exist->count ) {
    $mesg = $self->modify( $arg->{dn},
				[ add => [ sshPublicKey => $sshPublicKey, ], ], );
    if ( $mesg ) {
      push @{$return->{error}},
	sprintf('Error during %s service modification: %s<br><b>srv: </b><pre>%s</pre><b>text: </b>%s',
		$arg->{service}, $mesg->{html}, $mesg->{srv}, $mesg->{text});
    } else {
      push @{$return->{success}},
	sprintf('<i class="%s fa-fw"></i>&nbsp;<em>key was added</em>',
		$self->cfg->{authorizedService}->{$arg->{service}}->{icon} );
    }
  } else {
    # for nonexistent SSH object and all others
    $mesg = $self->add( $arg->{dn}, $authorizedService, );
    if ( $mesg ) {
      push @{$return->{error}},
	sprintf('Error during %s account creation occured: %s<br><b>srv: </b><pre>%s</pre><b>text: </b>%s',
		uc($arg->{service}), $mesg->{html}, $mesg->{srv}, $mesg->{text});
    } else {
      push @{$return->{success}},
	sprintf('<i class="%s fa-fw"></i>&nbsp;<em>%s account login:</em> &laquo;<strong class="text-success">%s</strong>&raquo; <em>password:</em> &laquo;<strong class="text-success mono">%s</strong>&raquo;',
		$self->cfg->{authorizedService}->{$arg->{service}}->{icon},
		$arg->{service},
		(split(/=/,(split(/,/,$arg->{dn}))[0]))[1], # taking RDN value
		$arg->{password}->{$arg->{service}}->{'clear'});


      ### !!! RADIUS group modify with new member add if 802.1x
      if ( $arg->{service} eq '802.1x-mac' || $arg->{service} eq '802.1x-eap-tls' &&
	   defined $arg->{radiusgroupname} && $arg->{radiusgroupname} ne '' ) {
	$if_exist = $self->search( { base => $arg->{radiusgroupname},
					  scope => 'base',
					  filter => '(' . $arg->{dn} . ')', } );
	if ( ! $if_exist->count ) {
	  $mesg = $self->modify( $arg->{radiusgroupname},
				      [ add => [ member => $arg->{dn}, ], ], );
	  if ( $mesg && $mesg->{code} == 20 ) {
	    push @{$return->{warning}},
	      sprintf('Warning during %s group modification: %s<br><b>srv: </b><pre>%s</pre><b>text: </b>%s',
		      $arg->{radiusgroupname}, $mesg->{html}, $mesg->{srv}, $mesg->{text});
	  } elsif ( $mesg ) {
	    push @{$return->{error}},
	      sprintf('Error during %s group modification: %s<br><b>srv: </b><pre>%s</pre><b>text: </b>%s',
		      $arg->{radiusgroupname}, $mesg->{html}, $mesg->{srv}, $mesg->{text});
	  }

	}
      }
    }
  }
  return $return;
}



=head2 attr_equality

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
    hwType            "<i title="composite inventory item, workstation" class="fa fa-lg fa-desktop"></i>",
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

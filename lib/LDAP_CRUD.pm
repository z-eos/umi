# -*- cperl -*-
#

package LDAP_CRUD;

use Moose;
use namespace::autoclean;

BEGIN { with 'Tools'; }

use Net::LDAP;
use Net::LDAP::Control;
use Net::LDAP::Control::Sort;
use Net::LDAP::Constant qw(LDAP_CONTROL_SORTRESULT);
use Net::LDAP::Util qw(
			ldap_error_text
			ldap_error_name
			ldap_error_desc
			ldap_explode_dn
			escape_filter_value
			canonical_dn
		     );

use Data::Dumper;
use Data::Printer;
use Try::Tiny;


=head2 cfg

Related to LDAP DB objects configuration. Attempt to reach some sort of DB
topology independence was undertaken.

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
		   dhcp =>           'ou=DHCP,' . UMI->config->{ldap_crud_db},
		   gitacl =>         'ou=GitACL,' . UMI->config->{ldap_crud_db},
		   group =>          'ou=group,' . UMI->config->{ldap_crud_db},
		   org =>            'ou=Organizations,' . UMI->config->{ldap_crud_db},
		   rad_profile =>    'ou=rad-profiles,' . UMI->config->{ldap_crud_db},
		  },
	  exclude_prefix => 'aux_',

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
		   noavatar_mgmnt => UMI->path_to('root', 'static', 'images', '/avatar-mgmnt.png'),
		   icon => 'fa fa-user',
		   group_blocked => 'blocked',
		  },
	  rdn => {
		  org =>            'ou',
		  acc_root =>       'uid',
		  acc_svc_branch => 'authorizedService',
		  acc_svc_common => 'uid',
		  gitacl =>         'cn',
		  group =>          'cn',
		 },
	  objectClass => {
			  acc_root =>       [ qw(
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
			  acc_svc_common => [ qw(
						  posixAccount
						  shadowAccount
						  inetOrgPerson
						  authorizedServiceObject
						  domainRelatedObject
					       ) ],
			  gitacl =>         [ qw(
						  top
						  gitACL
					       ) ],
			  group =>          [ qw(
						  top
						  posixGroup
					       ) ],
			  dhcp =>           [ qw(
						  top
						  dhcpHost
						  uidObject
					       ) ],
			  ovpn =>       [ qw(
					      top
					      inetOrgPerson
					   ) ],
			  org =>            [ qw(
						  top
						  organizationalUnit
					       ) ],
			  ssh =>            [ qw(
						  top
						  account
						  ldapPublicKey
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
		      data_fields => 'login,password1,password2',
		     },
	   'xmpp' => {
		      auth => 1,
		      descr => 'XMPP (Jabber)',
		      disabled => 0,
		      gidNumber => 10106,
		      jpegPhoto_noavatar => UMI->path_to('root', 'static', 'images', '/avatar-xmpp.png'),
		      icon => 'fa fa-lightbulb-o',
		      data_fields => 'login,password1,password2',
		     },
	   '802.1x-mac' => {
			    auth => 1,
			    descr => 'auth 802.1x MAC',
			    disabled => 0,
			    icon => 'fa fa-shield',
			    data_fields => 'login,password1,password2,radiusgroupname,radiustunnelprivategroup',
			    data_relation => '8021x',
			   },
	   '802.1x-eap' => {
			    auth => 1,
			    descr => 'auth 802.1x EAP',
			    disabled => 0,
			    icon => 'fa fa-shield',
			    data_fields => 'login,password1,password2,radiusgroupname,radiustunnelprivategroup',
			    data_relation => '8021x',
			   },
	   'otrs' => {
		      auth => 1,
		      descr => 'OTRS',
		      disabled => 1,
		      icon => 'fa fa-file-code-o',
		      data_fields => 'login,password1,password2',
		     },
	   'noc' => {
		     auth => 1,
		     descr => 'NOC',
		     disabled => 1,
		     icon => 'fa fa-file-code-o',
		     data_fields => 'login,password1,password2',
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
			  data_fields => 'login,password1,password2',
			 },
	   'ssh-acc' => {
			 auth => 1,
			 descr => 'SSH',
			 disabled => 0,
			 icon => 'fa fa-key',
			 data_fields => 'login,password1,password2',
			},
	   'ssh' => {
		     auth => 0,
		     descr => 'SSH key',
		     disabled => 0,
		     icon => 'fa fa-key',
		     # data_fields => 'block_ssh',
		    },
	   'gpg' => {
		     auth => 0,
		     descr => 'GPG key',
		     disabled => 1,
		     icon => 'fa fa-key',
		    },
	   'ovpn' => {
		      auth => 0,
		      descr => 'OpenVPN',
		      disabled => 0,
		      icon => 'fa fa-certificate',
		      # data_fields => 'block_crt',
		     },
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

	my $ldap = try {
		Net::LDAP->new( $self->host, async => 1, debug => 0 );
	}
	catch {
		warn "Net::LDAP->new problem, error: $_";    # not $@
	};

	return $ldap;
}

around 'ldap' =>
  sub {
    my $orig = shift;
    my $self = shift;

    my $ldap = $self->$orig(@_);

    my $mesg = $ldap->bind(
			   sprintf( "uid=%s,%s", $self->uid, $self->{cfg}->{base}->{acc_root} ),
			   password => $self->pwd,
			   version  => 3,
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

Last uidNumber for base ou=People,dc=umidb

to add error correction

=cut

has 'last_uidNumber' => (
	is       => 'ro',
	isa      => 'Str',
	required => 0, lazy => 1,
	builder  => 'build_last_uidNumber',
);

sub build_last_uidNumber {
  my $self = shift;

  my $callername = (caller(1))[3];
  $callername = 'main' if ! defined $callername;
  my $return = 'call to LDAP_CRUD->last_uidNumber from ' . $callername . ': ';

  $self->reset_ldap;
  my $mesg =
    $self->ldap->search(
			base   => $self->{cfg}->{base}->{acc_root},
			scope  => 'one',
			filter => '(uidNumber=*)',
			attrs  => [ 'uidNumber' ],
			deref => 'never',
		       );

  if ( $mesg->code ) {
    $return .= $self->err( $mesg );
  } else {
    # my @uids_arr = sort { $a <=> $b } map { $_->get_value('uidNumber') } $mesg->entries;
    my @uids_arr = $mesg->sorted ( 'uidNumber' );
    $return = $uids_arr[$#uids_arr]->get_value( 'uidNumber' );
  }
  return $return;
}

=head2 last_gidNumber

Last gidNumber for base ou=group,dc=umidb

to add error correction

=cut

has 'last_gidNumber' => (
			 is       => 'ro',
			 isa      => 'Str',
			 required => 0, lazy => 1,
			 builder  => 'build_last_gidNumber',
			);

sub build_last_gidNumber {
  my $self = shift;

  my $callername = (caller(1))[3];
  $callername = 'main' if ! defined $callername;
  my $return = 'call to LDAP_CRUD->last_gidNumber from ' . $callername . ': ';

  $self->reset_ldap;
  my $mesg =
    $self->ldap->search(
			base   => $self->{cfg}->{base}->{group},
			scope  => 'one',
			filter => '(gidNumber=*)',
			attrs  => [ 'gidNumber' ],
			deref => 'never',
		       );

  if ( $mesg->code ) {
    $return .= $self->err( $mesg );
  } else {
    # my @gids_arr = sort { $a <=> $b } map { $_->get_value('gidNumber') } $mesg->entries;
    my @gids_arr = $mesg->sorted ( 'gidNumber' );
    $return = $gids_arr[$#gids_arr]->get_value( 'gidNumber' );
  }
  return $return;
}

=head2 err

Net::LDAP errors handling

Net::LDAP::Message is expected as single input argument

=cut

sub err {
  my ($self, $mesg) = @_;

# to finish #   use Data::Dumper;
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

  # return sprintf( '<dl class="dl-horizontal"><dt>code</dt><dd>%s</dd><dt>error_name</dt><dd>%s</dd><dt>error_text</dt><dd><b><i><pre>%s</pre></i></b></dd><dt>error_desc</dt><dd>%s</dd><dt>server_error</dt><dd>%s</dd></dl>',
  # 		  $mesg->code,
  # 		  $mesg->error_name,
  # 		  $mesg->error_text,
  # 		  $mesg->error_desc,
  # 		  $mesg->server_error)
  #   if $mesg->code;

  my $caller = (caller(1))[3];
  my $err = {
	     html => ldap_error_name($mesg) ne 'LDAP_SUCCESS' ?
	     sprintf( '<dl class="dl-horizontal">
  <dt>code</dt><dd>%s</dd>
  <dt>error name</dt><dd>%s</dd>
  <dt>error text</dt>
  <dd>
    <em><small><pre>%s</pre></small></em>
  </dd>
  <dt>error description</dt><dd>%s</dd>
  <dt>server_error</dt><dd>%s</dd>
</dl>',
		      $mesg->code,
		      ldap_error_name($mesg),
		      ldap_error_text($mesg),
		      ldap_error_desc($mesg),
		      $mesg->server_error
			    ) :
	     'Your request returned no result. Try to change query parameter/s.',
	     code => $mesg->code,
	     name => ldap_error_name($mesg),
	     text => ldap_error_text($mesg),
	     desc => ldap_error_desc($mesg),
	     srv => $mesg->server_error,
	     caller => $caller ? $caller : 'main',
	    };
  # use Data::Printer;
  # p $err;
  return $err; # if $mesg->code;
}

sub unbind {
  my $self = shift;
  $self->ldap->unbind;
}

sub schema {
  my $self = shift;
  $self->ldap->schema;
}

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

  # use Data::Printer;
  # p $arg;

  return $self->ldap->search( base => $arg->{base},
			      scope => $arg->{scope},
			      filter => $arg->{filter},
			      deref => $arg->{deref},
			      attrs => $arg->{attrs},
			      sizelimit => $arg->{sizelimit},
			    );
}


=head2 add

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

=head2 del

TODO

to backup entry deleted

https://metacpan.org/pod/Net::LDAP::Control::PreRead

=cut


sub del {
  my ($self, $dn) = @_;
p $dn;
  my $callername = (caller(1))[3];
  $callername = 'main' if ! defined $callername;
  my $return = 'call to LDAP_CRUD->del from ' . $callername . ': ';

  if ( ! $self->dry_run ) {
    my $msg = $self->ldap->delete ( $dn );
    if ($msg->code) {
      $return .= $self->err( $msg );
    } else {
      $return = 0;
    }
  } else {
    $return = 0;
  }
  return $return;
}


=head2 delr

TODO

to backup entries deleted

https://metacpan.org/pod/Net::LDAP::Control::PreRead

to care recursively of subtree of the object to be deleted if exist

=cut


sub delr {
  my ($self, $dn) = @_;

  my $callername = (caller(1))[3];
  $callername = 'main' if ! defined $callername;
  my $return = 'call to LDAP_CRUD->del from ' . $callername . ': ';

  if ( ! $self->dry_run ) {
    my $result      = $self->ldap->search( base   => $dn,
					   filter => "(objectclass=*)" );
    my @dnlist;
    foreach my $entry ( $result->all_entries ) {
      push @dnlist, $entry->dn;
    }

    # explode dn into an array and push
    # arrays to indexed hash of arrays
    my %HoL;
    my $i   = 0;

    my $base = join('', pop [ split(",", $dn) ]);

    for ( @dnlist ) {
      s/,$base//;
      $HoL{$i} = [ split(",", $_) ];
      $i++;
    }

    my $msg;
    # sorted descending by number of members (leaf nodes last)
    foreach my $key ( sort { @{$HoL{$b}} <=> @{$HoL{$a}} } keys %HoL ) {
      my $dn2del = join(",", @{ $HoL{$key} }).",$base";
      $msg = $self->ldap->delete($dn2del);
      if ($msg->code) {
	$return .= $self->err( $msg );
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

  $msg_usr = $self->search ( { base => $args->{dn}, } );
  if ( $msg_usr->is_error() ) {
    $return->{error} = $self->err( $msg_usr )->{html};
  } else {
    # bellow we are blocking services
    my @ent_toblock = $msg_usr->entries;
    foreach $ent_svc ( @ent_toblock ) {
      if ( $ent_svc->exists('userPassword') ) {
	$userPassword = $self->pwdgen;
	$msg = $self->mod( $ent_svc->dn,
			   { userPassword => $userPassword->{ssha}, }, );
	$return->{error} .= $self->err( $msg )->{html} if ref($msg) eq 'HASH';
      }

      if ( $ent_svc->exists('sshPublicKey') ) {
	@userPublicKeys = $ent_svc->get_value('sshPublicKey');
	@keys = map { $_ !~ /^from="127.0.0.1" / ? sprintf('from="127.0.0.1" %s', $_) : $_ } @userPublicKeys;
	$msg = $self->mod( $ent_svc->dn,
			   { sshPublicKey => \@keys, }, );
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
			   } );
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
	$ent_chg = $self->mod( $blockgr_dn,
			       { memberUid => \@blockgr } );
	if ( $ent_chg != 0 && defined $ent_chg->{error} ) {
	  $return->{error} .= $self->err( $ent_chg )->{html};
	}
      }
    }
  }
  return $return;
}


=head2 mod

modify method

=cut

sub mod {
  my ($self, $dn, $replace) = @_;

  my $callername = (caller(1))[3];
  $callername = 'main' if ! defined $callername;
  my $return = 'call to LDAP_CRUD->mod from ' . $callername . ': ';
  my $msg;
  if ( ! $self->dry_run ) {
    $msg = $self->ldap->modify ( $dn, replace => $replace, );
    if ($msg->is_error()) {
      $return .= $self->err( $msg )->{html};
    } else {
      $return = 0;
    }
  } else {
    $return = $msg->ldif;
  }
  # p $dn; p $replace;
  return $return;
}

=head2 modify

modify method

=cut

sub modify {
  my ($self, $dn, $changes) = @_;
p [ $dn, $changes ];
  my $callername = (caller(1))[3];
  $callername = 'main' if ! defined $callername;
  my $return = 'call to LDAP_CRUD->modify from ' . $callername . ': ';
  my $msg;
  if ( ! $self->dry_run ) {
    $msg = $self->ldap->modify ( $dn, changes => $changes, );
    if ($msg->is_error()) {
      $return .= $self->err( $msg );
    } else {
      $return = 0;
    }
  } else {
    $return = $msg->ldif;
  }
  return $return;
}

=head2 ldif

LDIF export

=cut

sub ldif {
  my ($self, $dn, $recursive, $sysinfo) = @_;
  use POSIX qw(strftime);
  my $ts = strftime "%Y-%m-%d %H:%M:%S", localtime;
  my $return->{success} = sprintf("
## LDIF export for  \"%s\"
## Search Scope: \"base\"
## Search Filter: \"(objectClass=*)\"
##
## LDIF generated on %s, by UMI\n",
		       $dn,
		       $ts);

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
      $return->{success} .= $entry->ldif;
    }
  }
  use Data::Printer;
  my $a = ldap_explode_dn($dn, casefold => 'none');
  pop $a;
  pop $a;
  # p $a;
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

  my ( $must, $may, $obj_schema );
  foreach my $entry ( @entries ) {
    foreach my $objectClass ( $entry->get_value('objectClass') ) {
      next if $objectClass eq 'top';
      foreach $must ( $self->schema->must ( $objectClass ) ) {
	$obj_schema->{$entry->dn}->{$objectClass}->{'must'}
	  ->{ $must->{'name'} } =
	    {
	     'attr_value' => $entry->get_value( $must->{'name'} ) || undef,
	     'desc' => $must->{'desc'} || undef,
	     'single-value' => $must->{'single-value'} || undef,
	     'max_length' => $must->{'max_length'} || undef,
	     'equality' => $must->{'equality'} || undef,
#	     'attribute' => $self->schema->attribute($must->{'name'}) || undef,
	    };
      }

      foreach $may ( $self->schema->may ( $objectClass ) ) {
	$obj_schema->{$entry->dn}->{$objectClass}->{'may'}
	  ->{$may->{'name'}} =
	    {
	     'attr_value' => $entry->get_value( $may->{'name'} ) || undef ,
	     'desc' => $may->{'desc'} || undef ,
	     'single-value' => $may->{'single-value'} || undef ,
	     'max_length' => $may->{'max_length'} || undef ,
	     'equality' => $may->{'equality'} || undef ,
#	     'attribute' => $self->schema->attribute($may->{'name'}) || undef,
	    };
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

=cut

sub obj_add {
  my ( $self, $args ) = @_;
  my $type = $args->{'type'};
  my $params = $args->{'params'};

  # return '' unless %{$params};

#
## TODO
## HERE, MAY BE, WE NEED TO SET FLAG TO CREATE BRANCH FOR LOCALIZED
## VERSION OF DATA
## associatedService=localization-ru,uid=U...-user01,ou=People,dc=umidb
## associatedService=localization-uk,uid=U...-user01,ou=People,dc=umidb

  my $attrs = $self->params2attrs({
				   type => $type,
				   params => $params,
				  });

  my $mesg = $self->add(
			$attrs->{'dn'},
			$attrs->{'attrs'}
		       );
  my $message;
  if ( $mesg ) {
    $message .= '<div class="alert alert-danger">' .
      '<span style="font-size: 140%" class="icon_error-oct" aria-hidden="true"></span>&nbsp;' .
	'Error during ' . $type . ' object creation occured: ' . $mesg . '</div>';

    warn sprintf('object dn: %s wasn not created! errors: %s', $attrs->{'dn'}, $mesg);
  } else {
    $message .= '<div class="alert alert-success">' .
      '<span style="font-size: 140%" class="glyphicon glyphicon-ok-sign"></span>' .
	'&nbsp;Object <em>&laquo;' . $self->utf2lat( $params->{'physicalDeliveryOfficeName'} ) .
	    '&raquo;</em> of type <em>&laquo;' . $type .
	      '&raquo;</em> was successfully created.</div>';
  }

  # warn 'FORM ERROR' . $final_message if $final_message;

  # $self->unbind;

  warn 'LDAP ERROR' . $mesg if $mesg;

  return { message => $message };
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
	    $arg->{'params'}->{'aux_parent'} ne "0" ) ?
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
    $val = $self->is_ascii( $arg->{'params'}->{$key} ) ?
      $self->utf2lat( $arg->{'params'}->{$key} ) :
	$arg->{'params'}->{$key};

    # build DN for org
    if ( $arg->{'type'} eq 'org' && $key eq 'ou' ) {
      $dn = sprintf('%s=%s,%s', $key, $val, $base);
    }

    push @{$attrs}, $key => $val;
  }
  # warn 'attributes prepared, dn: ' . $dn . '; $attrs:' . Dumper($attrs);
  return {
	  dn => $dn,
	  attrs => $attrs
	 };
}

=head2 dhcp_lease

here we suppose each net relates to uniq domain-name

=cut


sub dhcp_lease {
  my ( $self, $args ) = @_;
  my $return;
  my $arg = {
	     net => $args->{net},
	     what => $args->{what} || 'stub', # used, ip, mac, hostname, all
	    };

  my $mesg =
    $self->search({
		   base => $self->{cfg}->{base}->{dhcp},
		   filter => sprintf('dhcpOption=domain-name "%s"', $arg->{net}),
		   attrs => [ 'cn', 'dhcpNetMask', 'dhcpRange' ],
		  });

  if (! $mesg->count) {
    $return->{error} = '<span class="glyphicon glyphicon-exclamation-sign">&nbsp;</span>' .
      'Net choosen, DHCP configuration looks absent.';
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
	$self->search({
		       base => $_->dn,
		       scope => 'children',
		       attrs => [ 'cn', 'dhcpStatements', 'dhcpHWAddress' ],
		       sizelimit => 256,
		      });

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

  foreach my $key ( sort {$a cmp $b} keys %{$self->{cfg}->{authorizedService}}) {
    if ( $self->{cfg}->{authorizedService}->{$key}->{auth} &&
	 defined $self->{cfg}->{authorizedService}->{$key}->{data_relation} &&
	 $self->{cfg}->{authorizedService}->{$key}->{data_relation} ne '' ) {
      push @services, {
		       value => $key,
		       label => $self->{cfg}->{authorizedService}->{$key}->{descr},
		       attributes =>
		       { 'data-relation' => $self->{cfg}->{authorizedService}->{$key}->{data_relation} },
		      } if ! $self->{cfg}->{authorizedService}->{$key}->{disabled};
    } elsif ( $self->{cfg}->{authorizedService}->{$key}->{auth} ) {
      push @services, {
		       value => $key,
		       label => $self->{cfg}->{authorizedService}->{$key}->{descr},
		      } if ! $self->{cfg}->{authorizedService}->{$key}->{disabled};
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
  my (@branches, @office);

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
    my @branchOffices = $mesg->entries;
    foreach my $branchOffice (@branchOffices) {
      push @branches, {
		       value => $branchOffice->dn,
		       label => sprintf("%s (%s @ %s)",
					$branchOffice->get_value ('ou'),
					$branchOffice->get_value ('physicaldeliveryofficename'),
					$branchOffice->get_value ('l')
				       ),
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

options builder for select element of associateddomains

=cut

has 'select_associateddomains' => ( traits => ['Array'],
	       is => 'ro', isa => 'ArrayRef', required => 0, lazy => 1,
	       builder => '_build_select_associateddomains',
	     );

sub _build_select_associateddomains {
  my $self = shift;
  my @domains; # = ( {value => '0', label => '--- select domain ---', selected => 'selected'} );
  my $mesg = $self->search( { base => $self->{cfg}->{base}->{org},
			      filter => 'associatedDomain=*',
			      attrs => ['associatedDomain' ],
			    } );
  my $err_message = '';
  if ( ! $mesg->count ) {
    $err_message = '<div class="alert alert-danger">' .
      '<span style="font-size: 140%" class="icon_error-oct" aria-hidden="true"></span><ul>' .
	$self->err($mesg) . '</ul></div>';
  }

  my @entries = $mesg->sorted('associatedDomain');
  my @i;
  foreach my $entry ( @entries ) {
    @i = $entry->get_value('associatedDomain');
    foreach (@i) {
      push @domains, { value => $_, label => $_, };
    }
  }
  return \@domains;
}

=head2 select_radprofile

options builder for select element of rad-profiles

=cut

has 'select_radprofile' => ( traits => ['Array'],
	       is => 'ro', isa => 'ArrayRef', required => 0, lazy => 1,
	       builder => '_build_select_radprofile',
	     );

sub _build_select_radprofile {
  my $self = shift;
  my @rad_profiles;
  my $mesg = $self->search( { base => $self->{cfg}->{base}->{rad_profile},
			      attrs => ['cn' ],
			    } );
  my $err_message = '';
  if ( ! $mesg->count ) {
    $err_message = '<div class="alert alert-danger">' .
      '<span style="font-size: 140%" class="icon_error-oct" aria-hidden="true"></span><ul>' .
	$self->err($mesg) . '</ul></div>';
  }

  my @entries = $mesg->sorted('cn');
  my @i;
  foreach my $entry ( @entries ) {
    @i = $entry->get_value('cn');
    foreach (@i) {
      push @rad_profiles, { value => $_, label => $_, };
    }
  }
  return \@rad_profiles;
}


######################################################################
# temporary stuff
######################################################################

sub canonical_dn_rev {
  my ($self, $dn) = @_;
  return canonical_dn($dn, reverse => 1);
}


######################################################################

no Moose;
__PACKAGE__->meta->make_immutable;

1;

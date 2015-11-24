# -*- mode: cperl; mode: follow; -*-
#

package LDAP_CRUD;

use Moose;
use namespace::autoclean;

use Data::Printer  colored => 1;

BEGIN { with 'Tools'; }

use Net::LDAP;
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
		     );

use Try::Tiny;

=head2 cfg

Related to LDAP DB objects configuration.

each service described by hash like this:
    I<service> => {
       # whether login/password needed or not
       I<auth> => 1 or 0,
       I<descr> => 'Description seen in form select',
       # to process or to not to process this service
       I<disabled> => 1 or 0,
       # some predefined gidNumber
       I<gidNumber> => 10106,
       I<jpegPhoto_noavatar> => UMI->path_to('path', 'to', '/image.jpg'),
       I<icon> => 'fa fa-lightbulb-o',
       # must-contain fields for this service
       I<data_fields> => 'login,password1,password2',
       # element wrapper class, presence of which is
       # applying umi-user-all.js to the element
       I<data_relation> => 'passw',
       # domains which demands prefix (one more level domain) like
       # service dedicated hosts
       I<associateddomain_prefix> =>
       {
        'talax.startrek.in' => 'im.',
       },
       # automatically added for some services
       I<login_prefix> => 'rad-',
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
		   machines =>       'ou=machines,' . UMI->config->{ldap_crud_db},
		   org =>            'ou=Organizations,' . UMI->config->{ldap_crud_db},
		   rad_groups =>     'ou=groups,ou=RADIUS,' . UMI->config->{ldap_crud_db},
		   rad_profiles =>   'ou=profiles,ou=RADIUS,' . UMI->config->{ldap_crud_db},
		   workstations =>   'ou=workstations,' . UMI->config->{ldap_crud_db},
		   icon => {
			    People => 'fa fa-user',
			    DHCP => 'fa fa-sitemap',
			    GitACL => 'fa fa-gavel',
			    group => 'fa fa-group',
			    Organizations => 'fa fa-industry',
			    rad_groups => 'fa fa-group',
			    rad_profiles => 'fa fa-cogs',
			   },
		  },
	  exclude_prefix => 'aux_',
	  sizelimit => 50,
	  translit => "ALA-LC RUS",
	  
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
		   icon_error => 'fa fa-exclamation-circle',
		   icon_warning => 'fa fa-exclamation-triangle',
		   icon_success => 'fa fa-check-circle',
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
				    ) ],
			  ssh => [ qw(
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
		      data_relation => 'passw',
		     },
	   'xmpp' => {
		      auth => 1,
		      descr => 'XMPP (Jabber)',
		      disabled => 0,
		      gidNumber => 10106,
		      jpegPhoto_noavatar => UMI->path_to('root', 'static', 'images', '/avatar-xmpp.png'),
		      icon => 'fa fa-lightbulb-o',
		      data_fields => 'login,password1,password2',
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
		     data_fields => 'login,password1,password2',
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
			  data_fields => 'login,password1,password2',
			  data_relation => 'passw',
			 },
	   'ssh-acc' => {
			 auth => 1,
			 descr => 'SSH',
			 disabled => 0,
			 icon => 'fa fa-key',
			 data_fields => 'login,password1,password2',
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
	  err => {
		  0 => '<i class="fa fa-search-minus fa-lg text-warning "></i>&nbsp;Looks like your request returned no result. Try to change query parameter/s.',
		  50 => 'This situation needs your security officer and system administrator attention, please contact them to solve the issue.',
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
			   sprintf( "uid=%s,%s", $self->uid, $self->cfg->{base}->{acc_root} ),
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
			base   => $self->cfg->{base}->{acc_root},
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
			base   => $self->cfg->{base}->{group},
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
  $self->ldap->schema;
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

  my $arg = {
	     dst => { str => sprintf('uid=%s,%s',
					     $args->{dst_uid},
					     $self->cfg->{base}->{acc_root}), },
	     src => { str => $args->{src_dn},
		      is_branch => $args->{src_dn} =~ /^authorizedService=/ ? 1 : 0, },
	    };
  @{$arg->{src}->{arr}} = split(/,/, $arg->{src}->{str});
  @{$arg->{dst}->{arr}} = split(/,/, $arg->{dst}->{str});

  my ( $return, $y, $result, $mesg, $entry, $clone, $attrs, @x, $key, $val );
  $y = 0;
  foreach my $z ( @{$arg->{src}->{arr}} ) {
    push @x, $z if $z =~ /^authorizedService=/ || $y == 1;
    $y = 1 if $z =~ /^authorizedService=/;
  }

  $arg->{src}->{branch_dn}->{str} = join(',', @x);
  $arg->{src}->{branch_dn}->{arr} = \@x;

  $arg->{dst}->{branch_dn}->{str} = sprintf('%s,%s',
					  $arg->{src}->{branch_dn}->{arr}->[0],
					  $arg->{dst}->{str});
  @{$arg->{dst}->{branch_dn}->{arr}} = split(/,/, $arg->{dst}->{branch_dn}->{str});

  $result = $self->ldap->search( base   => $arg->{dst}->{str},
				 filter => sprintf('(%s)', $arg->{src}->{branch_dn}->{arr}->[0]),
				 scope => 'base' );

  $arg->{dst}->{has_branch} = $result->count;

  $result = $self->search( { base  => $arg->{dst}->{str}, scope => 'base', } );
  $entry = $result->entry(0);
  foreach ( $entry->attributes ) {
      $arg->{dst}->{data}->{$_} = $entry->get_value( $_, asref => 1 )
      if $_ ne 'jpegPhoto';
  }
  
  # src BRANCH does'n exist in dst subtree and here we
  # CREATE it
  if ( ! $arg->{dst}->{has_branch} ) {
    $result = $self->search( { base  => $arg->{src}->{branch_dn}->{str}, scope => 'base', } );
    # !!! we need to pick up this error in json somehow ...
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
    # !!! we need to pick up this error in json somehow ...
    if ( $mesg && $mesg->{name} eq 'LDAP_ALREADY_EXISTS' ) {
      push @{$return->{warning}}, $mesg if $mesg;
    } else {
      push @{$return->{error}}, $mesg if $mesg;
    }
  }
  undef $attrs;

  # src BRANCH already EXISTS in dst subtree and here
  # we are to process all objects bellow it (bellow src branch)
  if ( $arg->{src}->{is_branch} ) {
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
      # !!! we need to pick up this error in json somehow ...
      push @{$return->{error}}, $mesg if $mesg;
    }

    ### FINISH
    # here we have to delete src subtree recursively if
    # @{$return->{error}} is empty
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
    # !!! we need to pick up this error in json somehow ...
    push @{$return->{error}}, $mesg if $mesg;

    ### FINISH
    # here we have to delete src dn if
    # @{$return->{error}} is empty
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
	$ent_chg = $self->modify( $blockgr_dn,
				  [ replace => [ memberUid => \@blockgr, ],], );
	if ( $ent_chg != 0 && defined $ent_chg->{error} ) {
	  $return->{error} .= $self->err( $ent_chg )->{html};
	}
      }
    }
  }
  return $return;
}


=head2 mod

!!! DEPRECATED !!!

modify method

!!! DEPRECATED !!!

=cut

# sub mod {
#   my ($self, $dn, $replace) = @_;

#   my $callername = (caller(1))[3];
#   $callername = 'main' if ! defined $callername;
#   my $return = 'call to LDAP_CRUD->mod from ' . $callername . ': ';
#   my $msg;
#   if ( ! $self->dry_run ) {
#     $msg = $self->ldap->modify ( $dn, replace => $replace, );
#     if ($msg->is_error()) {
#       $return .= $self->err( $msg )->{html};
#     } else {
#       $return = 0;
#     }
#   } else {
#     $return = $msg->ldif;
#   }
#   return $return;
# }

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
## LDIF export for  \"%s\"
## Search Scope: \"base\"
## Search Filter: \"(objectClass=*)\"
##
## LDIF generated on %s, by UMI\n", $dn, $ts);

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

=cut

sub vcard {
  my ($self, $args) = @_;
  use POSIX qw(strftime);
  my $ts = strftime "%Y%m%d%H%M%S", localtime;
  my $arg = {
	     dn => $args->{vcard_dn},
	     type => $args->{vcard_type},
	    };
  my ($msg, $branch, @branches, $branch_entry, $leaf, @leaves, $leaf_entry, $entry, @entries, $return, $tmp);
  $msg = $self->ldap->search ( base => $arg->{dn}, scope => 'base', filter => 'objectClass=*', );
  if ($msg->is_error()) {
    $return->{error} .= $self->err( $msg )->{html};
  } else {
    $entry = $msg->entry(0);
    $arg->{vcard}->{n} = sprintf('N:%s;%s;;;',
				 $entry->get_value('sn'),
				 $entry->get_value('givenName') );
    $arg->{vcard}->{fn} = sprintf('FN:%s %s',
				  $entry->get_value('givenName'),
				  $entry->get_value('sn') );
    $arg->{vcard}->{title} = sprintf('TITLE:%s', $entry->get_value('title') );

    $arg->{vcard}->{o} = '';
    if ( $entry->exists('o') ) {
      my $orgs = $entry->get_value('o', asref => 1);
      foreach ( @{$orgs} ) {
	$tmp = $self->search ( { base => $_ } );
	if ($tmp->is_error()) {
	  $return->{error} .= $self->err( $tmp )->{html};
	} else {
	  my $org = $tmp->entry(0);
	  $arg->{vcard}->{o} .= sprintf("ORG:%s\n", $org->get_value('physicalDeliveryOfficeName') );
	}
      }
    }

    $arg->{vcard}->{telephonenumber} = '';
    if ( $entry->exists('telephoneNumber') ) {
      $tmp = $entry->get_value( 'telephoneNumber', asref => 1 );
      foreach ( @{$tmp} ) {
	$arg->{vcard}->{telephonenumber} .= 'TEL;TYPE=work:' . $_ . "\n";
      }
    }

    my $scope = $arg->{dn} =~ /^.*authorizedService.*$/ ? 'sub' : 'one';

    $arg->{vcard}->{email} = '';
    if ( $entry->exists('email') ) {
      $tmp = $entry->get_value( 'email', asref => 1 );
      foreach ( @{$tmp} ) {
	$arg->{vcard}->{email} .= 'EMAIL;WORK:' . $_ . "\n";
      }
    }
    $branch = $self->ldap->search ( base => $arg->{dn}, scope => $scope, filter => 'authorizedService=mail@*', );
    if ($branch->is_error()) {
      $return->{error} .= $self->err( $branch )->{html};
    } else {
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
		$arg->{vcard}->{email} .= 'EMAIL;TYPE=work:' . $leaf_entry->get_value('uid') . "\n";
	      }
	    }
	  }
	}
      }
    }
    
    $arg->{vcard}->{xmpp} = '';
    $msg = $self->ldap->search ( base => $arg->{dn}, scope => $scope, filter => 'authorizedService=xmpp@*', );
    if ($msg->is_error()) {
      $return->{error} .= $self->err( $msg )->{html};
    } else {
      @entries = $msg->entries;
      foreach $entry ( @entries ) {
	$msg = $self->search ( { base => $entry->dn, scope => $scope ne 'one' ? 'base' : 'one', } );
	if ($msg->is_error()) {
	  $return->{error} .= $self->err( $msg )->{html};
	} else {
	  if ( $msg->count ) {
	    my $a = $msg->entry(0);
	    $arg->{vcard}->{xmpp} .= 'X-JABBER;TYPE=work:' . $a->get_value('uid') . "\n";
	  }
	}
      }
    }
    
    $return->{vcard} = sprintf("\nBEGIN:VCARD\nVERSION:2.1\n%s\n%s\n%s\n",
			       $arg->{vcard}->{n},
			       $arg->{vcard}->{fn},
			       $arg->{vcard}->{title}
			      );

    $return->{vcard} .= $arg->{vcard}->{telephonenumber} if $arg->{vcard}->{telephonenumber} ne '';
    $return->{vcard} .= $arg->{vcard}->{email} if $arg->{vcard}->{email} ne '';
    $return->{vcard} .= $arg->{vcard}->{xmpp} if $arg->{vcard}->{xmpp} ne '';
    $return->{vcard} .= $arg->{vcard}->{o} if $arg->{vcard}->{o} ne '';

    $return->{success} .= sprintf('vCard generated for object with DN: <b class="mono"><em>%s</em></b>.', $arg->{dn} );
  }
  $return->{outfile_name} = join('_', split(/,/,canonical_dn($arg->{dn}, casefold => 'none', reverse => 1, )));
  $return->{dn} = $arg->{dn};
  $return->{type} = $arg->{type};
  use MIME::Base64;
  if ( $arg->{type} ne 'file' ) {
    use GD::Barcode::QRcode;
    $return->{qr} =
      sprintf('<img alt="QR for DN %s" src="data:image/jpg;base64,%s" class="img-responsive img-thumbnail" title="QR for DN %s"/>',
	      $arg->{dn},
	      encode_base64(GD::Barcode::QRcode
			    ->new( $return->{vcard},
				   { Ecc => 'Q', Version => 24, ModuleSize => 4 } )->plot->png ),
	      $arg->{dn}
	     );
  } else {
    $return->{vcard} .= "PHOTO;ENCODING=BASE64;JPEG:" . encode_base64($entry->get_value('jpegPhoto'))
      if $entry->exists('jpegPhoto');
  }

  $return->{vcard} .= "REV:" . $ts . "Z\nEND:VCARD\n";
  # p $return;
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
    ## to process uplod fields
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

  # DHCP network objects like: cn=172.16.57.0,cn=cube01 DHCP Config,ou=cube01,ou=borg,ou=DHCP,dc=umidb
  my $mesg =
    $self->search({ base => $self->cfg->{base}->{dhcp},
		    filter => sprintf('dhcpOption=domain-name "%s"', $arg->{net}),
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
  my @i;
  foreach my $entry ( @entries ) {
    @i = $entry->get_value('associatedDomain');
    foreach (@i) {
      push @domains, { value => $_, label => $_, };
    }
  }
  return \@domains;
}

=head2 select_group

options builder for select element of groups

=cut

has 'select_group' => ( traits => ['Array'],
			is => 'ro', isa => 'ArrayRef', required => 0, lazy => 1,
			builder => '_build_select_group',
	     );

sub _build_select_group {
  my $self = shift;
  my @groups;
  my $mesg = $self->search( { base => $self->cfg->{base}->{group},
			      attrs => ['cn', 'description' ],
			      sizelimit => 0,
			      scope => 'one', } );
  my $err_message = '';
  $err_message = '<div class="alert alert-danger">' .
    '<span style="font-size: 140%" class="icon_error-oct" aria-hidden="true"></span><ul>' .
    $self->err($mesg) . '</ul></div>'
    if ! $mesg->count;

  my @entries = $mesg->sorted('cn');
  foreach my $entry ( @entries ) {
    push @groups, { value => substr( (split /,/, $entry->dn)[0], 3),
			label => sprintf('%s%s',
					 $entry->get_value('cn'),
					 $entry->exists('description') ? ' --- ' . $entry->get_value('description') : ''),
		      };
  }
  return \@groups;
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
  my $mesg = $self->search( { base => $self->cfg->{base}->{rad_profiles},
			      attrs => ['cn', 'description' ],
			      sizelimit => 0,
			      scope => 'one',
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
    push @rad_profiles, { value => $entry->dn,
			  label => sprintf('%s%s',
					   $entry->get_value('cn'),
					   $entry->exists('description') ? ' ---> ' . $entry->get_value('description') : ''),
			};
  }
  return \@rad_profiles;
}

=head2 select_radgroup

options builder for select element of rad-groups

=cut

has 'select_radgroup' => ( traits => ['Array'],
	       is => 'ro', isa => 'ArrayRef', required => 0, lazy => 1,
	       builder => '_build_select_radgroup',
	     );

sub _build_select_radgroup {
  my $self = shift;
  my @rad_groups;
  my $mesg = $self->search( { base => $self->cfg->{base}->{rad_groups},
			      attrs => ['cn', 'description' ],
			      sizelimit => 0,
			      scope => 'one',
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
    push @rad_groups, { value => $entry->dn,
			label => sprintf('%s%s',
					 $entry->get_value('cn'),
					 $entry->exists('description') ? ' --- ' . $entry->get_value('description') : ''),
		      };
  }
  return \@rad_groups;
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
    { uid => $args->{uid},
      authorizedservice => $args->{authorizedservice},
      associateddomain =>
      sprintf('%s%s',
	      defined $self->cfg->{authorizedService}->{$args->{authorizedservice}}->{associateddomain_prefix}
	      ->{$args->{associateddomain}} ?
	      $self->cfg->{authorizedService}->{$args->{authorizedservice}}->{associateddomain_prefix}
	      ->{$args->{associateddomain}} : '',
	      $args->{associateddomain}), };

  $arg->{dn} =
    sprintf("authorizedService=%s@%s,uid=%s,%s",
	    $args->{authorizedservice}, $arg->{associateddomain}, $args->{uid}, $self->cfg->{base}->{acc_root});

  my ( $return, $if_exist);
  $arg->{add_attrs} =
    [ uid => sprintf('%s@%s', $arg->{uid}, $arg->{authorizedservice}),
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
	sprintf('Error during %s branch creation occured: %s<br><b>srv: </b><pre>%s</pre><b>text: </b>%s',
		uc($arg->{service}), $mesg->{html}, $mesg->{srv}, $mesg->{text});
    } else {
      $return->{dn} = $arg->{dn};
      $return->{associateddomain_prefix} = $arg->{'associateddomain_prefix'};
    }
  }
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
      gecos => sprintf('%s %s', $args->{givenName}, $args->{sn}),
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
  $arg->{dn} = sprintf('uid=%s,%s', $arg->{uid}, $arg->{basedn});

  my ($authorizedService, $sshkey, $authorizedService_add, $jpegPhoto_file, $sshPublicKey );

  if ( $arg->{service} eq 'ovpn' ||
       $arg->{service} eq 'ssh' ||
       ( $arg->{service} eq '802.1x-mac' ||
	 $arg->{service} eq '802.1x-eap-tls' ) ||
       $arg->{service} eq 'web' ) {
    $authorizedService = [];
    $authorizedService = [ description => $arg->{description}, ];
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
			  gecos => sprintf('%s %s', $args->{givenName}, $args->{sn}),
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
      description => uc($arg->{service}) . ': ' . $arg->{'login'};

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

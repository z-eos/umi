# -*- mode: cperl -*-
#

package UMI::Controller::UserAll;
use Moose;
use namespace::autoclean;
use Data::Printer;

BEGIN { extends 'Catalyst::Controller'; with 'Tools'; }

use UMI::Form::UserAll;
has 'form' => ( isa => 'UMI::Form::UserAll', is => 'rw',
		lazy => 1, default => sub { UMI::Form::UserAll->new },
		documentation => q{Complex Form to add new, nonexistent user account/s},
	      );


=head1 NAME

UMI::Controller::UserAll - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 index

=cut

sub index :Path :Args(0) {
    my ( $self, $c, $ldapadduser_id ) = @_;
    if ( $c->check_user_roles('wheel') ||
	 $c->check_user_roles('email') ||
	 $c->check_user_roles('xmpp') ||
	 $c->check_user_roles('802.1x-mac') ||
	 $c->check_user_roles('802.1x-eap') ) {
      my $params = $c->req->parameters;
      my $final_message;
      $params->{'avatar'} = $c->req->upload('avatar') if $params->{'avatar'};

      $c->stash( template => 'user/user_all.tt',
		 form => $self->form,
		 final_message => $final_message, );

      return unless $self->form->process(
					 posted => ($c->req->method eq 'POST'),
					 params => $params,
					 ldap_crud => $c->model('LDAP_CRUD'),
					);

      # $final_message = $self->create_account( $c->model('LDAP_CRUD'), $params );
      $c->stash( final_message => $self->create_account( $c->model('LDAP_CRUD'), $params ) );

    } elsif ( defined $c->session->{"auth_uid"} ) {
      if (defined $c->session->{'unauthorized'}->{ $c->action } ) {
	$c->session->{'unauthorized'}->{ $c->action } += 1;
      } else {
	$c->session->{'unauthorized'}->{ $c->action } = 1;
      }
      $c->stash( 'template' => 'unauthorized.tt',
		 'unauth_action' => $c->action, );
    } else {
      $c->stash( template => 'signin.tt', );
    }
}

=head2 create_account

=cut

sub create_account {
  my  ( $self, $ldap_crud, $args ) = @_;
  # my $args = $c->req->parameters;
  # my $ldap_crud = $c->model('LDAP_CRUD');
  my @form_fields = qw{ account loginless_ovpn loginless_ssh groups};
  my $uidNumber = $ldap_crud->last_uidNumber + 1;
  my ( $final_message, $success_message, $warning_message, $error_message );

  $args->{'uid_suffix'} = $self->form->namesake ? $self->form->namesake : '';
  $args->{'person_givenname'} = $self->utf2lat( $args->{'person_givenname'} ) if $self->is_ascii( $args->{'person_givenname'} );
  $args->{'person_sn'} =  $self->utf2lat( $args->{'person_sn'} ) if $self->is_ascii( $args->{'person_sn'} );
  $args->{'person_telephonenumber'} = '666' if $args->{'person_telephonenumber'} eq '';
  my $descr = 'description has to be here';
  if (defined $args->{'descr'} && $args->{'descr'} ne '') {
    $descr = join(' ', $args->{'descr'});
    $descr = $self->utf2lat( $descr ) if $self->is_ascii( $descr );
  }

  my ( $pwd, $file, $jpeg);
  if (defined $args->{'person_avatar'}) {
    $file = $args->{'person_avatar'}->{'tempname'};
  } else {
    $file = $ldap_crud->{cfg}->{stub}->{noavatar_mgmnt};
  }
  $jpeg = $self->file2var( $file, $final_message );

  $pwd = $args->{'person_password1'} eq '' ?
    { root => $self->pwdgen } :
    { root => $self->pwdgen( { pwd => $args->{'person_password1'} } ) };

  ######################################################################
  # Account ROOT Object
  ######################################################################
  # here we need suffix yet if the combination exists
  my $uid = sprintf('%s%s',
		    $self->form->autologin,
		    $self->form->namesake );
  my $root_add_dn = sprintf('uid=%s,%s',
			    $uid,
			    $ldap_crud->{cfg}->{base}->{acc_root});
  my $root_add_options =
    [
     uid => $uid,
     userPassword => $pwd->{root}->{ssha},
     telephoneNumber => $args->{person_telephonenumber},
     physicalDeliveryOfficeName => $args->{'person_office'},
     o => $args->{'person_org'},
     givenName => $args->{person_givenname},
     sn => $args->{person_sn},
     cn => sprintf('%s %s',
		   $args->{person_givenname},
		   $args->{person_sn}),
     uidNumber => $uidNumber,
     gidNumber => $ldap_crud->{cfg}->{stub}->{gidNumber},
     description => $descr,
     gecos => $descr,
     homeDirectory => $ldap_crud->{cfg}->{stub}->{homeDirectory},
     jpegPhoto => [ $jpeg ],
     loginShell => $ldap_crud->{cfg}->{stub}->{loginShell},

     title => $self->is_ascii($args->{'person_title'}) ?
     lc($self->utf2lat($args->{'person_title'})) :
     lc($args->{'person_title'}),

     objectClass => $ldap_crud->{cfg}->{objectClass}->{acc_root},
    ];

  my $ldif = $ldap_crud->add( $root_add_dn, $root_add_options );
  if ( $ldif ) {
    push @{$final_message->{error}},
      '<li>Error during management account creation occured: ' . $ldif->{html} . '</li>';
    push @{$final_message->{error}}, "error during root obj creation: " . $ldif;
  } else {
    push @{$final_message->{success}},
      sprintf('<i class="fa fa-user fa-lg fa-fw"></i>&nbsp;<em>root account login:</em> &laquo;<strong class="text-success">%s</strong>&raquo; <em>password:</em> &laquo;<strong class="text-success mono">%s</strong>&raquo;',
	      $uid,
	      $pwd->{root}->{'clear'}) ;
  }

  my ( $element, $associatedDomain, $authorizedService, $authorizedService_add );
  my ($branch, $leaf);
  my $is_svc_empty = '';
  ######################################################################
  # SERVICE ACCOUNTS PROCESSING START
  ######################################################################
  foreach my $form_field ( @form_fields ) {
    next if $form_field eq 'groups';
    # if ( $form_field eq 'loginless_ovpn' ) {
    #   p my @a = $self->form->field($form_field)->fields;
    #   p $#a;
    # }
    foreach $element ( $self->form->field($form_field)->fields ) {
      foreach ( $element->fields ) { $is_svc_empty .= $_->value if defined $_->value; } # p $is_svc_empty;
      next if $is_svc_empty eq ''; # avoid all empty services

      ######################################################################
      # Account branch of ROOT Object
      ######################################################################
      $branch =
    	$self
	->create_account_branch ( $ldap_crud,
				  {
				   uid => $uid,
				   authorizedservice => $form_field ne 'account' ?
				   substr($form_field, 10) :
				   $element->field('authorizedservice')->value,
				   associateddomain => $element->field('associateddomain')->value,
				  },
				);

      push @{$final_message->{success}}, $branch->{success} if defined $branch->{success};
      push @{$final_message->{warning}}, $branch->{warning} if defined $branch->{warning};
      push @{$final_message->{error}}, $branch->{error} if defined $branch->{error};

      ######################################################################
      # Leaf of the account branch of ROOT Object
      ######################################################################
      my $x =
	{
	 basedn => $branch->{dn},
	 authorizedservice => $form_field ne 'account' ?
	 substr($form_field, 10) : $element->field('authorizedservice')->value,
	 associateddomain => $branch->{associateddomain_prefix} . $element->field('associateddomain')->value,
	 uidNumber => $uidNumber,
	 givenName => $args->{person_givenname},
	 sn => $args->{person_sn},
	 telephoneNumber => $args->{person_telephonenumber},
	 # jpegPhoto => $jpeg,
	};
      if ( $form_field eq 'account' ) {
	if ( $element->field('authorizedservice')->value =~ /^802.1x-.*/ ) {
	  $x->{password} = { $element->field('authorizedservice')->value =>
			     { clear => $self->macnorm({ mac => $element->field('login')->value }) }
			   };
	  $x->{radiusgroupname} = $element->field('radiusgroupname')->value
	    if defined $element->field('radiusgroupname')->value;
	  $x->{radiustunnelprivategroupid} = $element->field('radiustunnelprivategroupid')->value
	    if defined $element->field('radiustunnelprivategroupid')->value;
	} elsif ( ! $element->field('password2')->value &&
		  ! $element->field('password2')->value) {
	  $x->{password} = { $element->field('authorizedservice')->value => $self->pwdgen };
	} else {
	  $x->{password} = { $element->field('authorizedservice')->value =>
			     $self->pwdgen( { pwd => $element->field('password2')->value } ) };
	}

	$x->{login} = defined $element->field('login')->value ? $element->field('login')->value : $uid;

      } elsif ( $x->{authorizedservice} eq 'ssh' ) {
	$x->{sshpublickey} = $element->field('key')->value;
	$x->{login} = $uid;
	$x->{password} = { $x->{authorizedservice} =>
			   { clear => '<del>NOPASSWORD</del>' }
			 };
      } elsif ( $x->{authorizedservice} eq 'ovpn' ) {
      }

      $leaf =
  	$self->create_account_branch_leaf ( $ldap_crud, $final_message, $x, );
    }
    $is_svc_empty = '';
  }
  ######################################################################
  # SERVICE ACCOUNTS PROCESSING STOP
  ######################################################################

  # p $final_message;
  return $final_message;
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
      dn => DN of the oject created
      success => success message
      warning => warning message
      error => error message
    }

=cut


sub create_account_branch {
  my  ( $self, $ldap_crud, $args ) = @_;
  my $arg = {
	     authorizedservice => $args->{authorizedservice},
	     associateddomain => $args->{associateddomain},
	     uid => $args->{uid},
	     dn => sprintf("authorizedService=%s@%s,uid=%s,%s",
			   $args->{authorizedservice},
			   $args->{associateddomain},
			   $args->{uid},
			   $ldap_crud->{cfg}->{base}->{acc_root}),
	    };
  my $return;

  ### !!! STUB !!! here are some exclusions, we need to manage them somewhere in cfg
  $arg->{'associateddomain_prefix'} = $arg->{'associateddomain'} eq 'talax.startrek.in' &&
    $arg->{authorizedservice} eq 'xmpp' ? 'im.' : '';

  $arg->{add_attrs} = [ 'authorizedService' => $arg->{authorizedservice} . '@' .
			$arg->{'associateddomain_prefix'} . $arg->{'associateddomain'},
			'uid' => $arg->{uid} . '@' . $arg->{authorizedservice},
			'objectClass' => $ldap_crud->{cfg}->{objectClass}->{acc_svc_branch}, ];

  my $if_exist = $ldap_crud->search( { base => $arg->{dn},
				       scope => 'base',
				       attrs => [ 'authorizedService' ], } );
  if ( $if_exist->count ) {
    $return->{warning} = 'branch DN: <b>&laquo;' . $arg->{dn} . '&raquo;</b> '
      . 'was not created since it <b>already exists</b>, I will use it further.';
  } else {
    my $mesg = $ldap_crud->add( $arg->{dn}, $arg->{add_attrs} );
    if ( $mesg ) {
      $return->{error} = 'error during ' . uc($arg->{service}) . ' branch creation occured: ' . $mesg;
    } else { # $return->{success} = sprintf('<i class="%s fa-fw"></i> branch object &laquo;<b class="text-success">%s</b>&raquo; was successfully created',
					  # $ldap_crud->{cfg}->{authorizedService}->{$arg->{authorizedservice}}->{icon},
					  # $arg->{dn});
	     $return->{dn} = $arg->{dn};
	     $return->{associateddomain_prefix} = $arg->{'associateddomain_prefix'};
	   }
  }
  return $return;
}

# =head2 create_account_branch_leaf

# creates leaves for service account branch like

#     dn: uid=john.doe@foo.bar,authorizedService=mail@foo.bar,uid=U012C01-john.doe,ou=People,dc=umidb
#     authorizedService: mail@foo.bar
#     associatedDomain: foo.bar
#     uid: john.doe@foo.bar
#     cn: john.doe@foo.bar
#     givenName: John
#     sn: Doe
#     uidNumber: 10738
#     loginShell: /sbin/nologin
#     objectClass: posixAccount
#     objectClass: shadowAccount
#     objectClass: inetOrgPerson
#     objectClass: authorizedServiceObject
#     objectClass: domainRelatedObject
#     objectClass: mailutilsAccount
#     userPassword: ********
#     gecos: MAIL: john.doe @ foo.bar
#     description: MAIL: john.doe @ foo.bar
#     homeDirectory: /var/mail/IMAP_HOMES/foo.bar/john.doe@foo.bar
#     mu-mailBox: maildir:/var/mail/foo.bar/john.doe@foo.bar
#     gidNumber: 10006

# =cut



sub create_account_branch_leaf {
  my  ( $self, $ldap_crud, $final_message, $args ) = @_;
  my $arg = {
	     basedn => $args->{basedn},
	     service => $args->{authorizedservice},
	     associatedDomain => $args->{associateddomain},
	     uidNumber => $args->{uidNumber},
	     givenName => $args->{givenName},
	     sn => $args->{sn},
	     login => $args->{login},
	     password => $args->{password},
	     telephoneNumber => $args->{telephoneNumber} || '666',
	     jpegPhoto => $args->{jpegPhoto} || undef,
	     to_sshkeygen => $args->{to_sshkeygen} || undef,
	     sshpublickey => $args->{sshpublickey} || undef,
	     sshkeydescr => $args->{sshkeydescr} || undef,
	     userCertificate => $args->{userCertificate} || undef,
	     radiusgroupname => $args->{radiusgroupname} || 'ip-phone',
	     radiustunnelprivategroupid => $args->{radiustunnelprivategroupid} || 3,
	    };
  my $return;

  $arg->{uid} = $arg->{'login'} . '@' . $arg->{associatedDomain};
  $arg->{dn} = 'uid=' . $arg->{uid} . ',' . $arg->{basedn};

  ### !!! STUB !!! here are some exclusions, we need to manage them somewhere in cfg
  $arg->{associatedDomain} = 'im.' . $arg->{associatedDomain}
    if $arg->{associatedDomain} eq 'talax.startrek.in' && $arg->{service} eq 'xmpp';

  my ($authorizedService, $sshkey);

  if ( $arg->{service} eq 'ovpn' ) {
    $authorizedService = [];
  } elsif ( $arg->{service} eq 'ssh' ) {
    $authorizedService = [];
  } elsif ( $arg->{service} eq '802.1x-mac' ||
	    $arg->{service} eq '802.1x-eap' ) {
    $authorizedService = [];
  } else {
    $authorizedService = [
			  authorizedService => $arg->{service} . '@' . $arg->{associatedDomain},
			  associatedDomain => $arg->{associatedDomain},
			  uid => $arg->{uid},
			  cn => $arg->{uid},
			  givenName => $arg->{givenName},
			  sn => $arg->{sn},
			  uidNumber => $arg->{uidNumber},
			  loginShell => $ldap_crud->{cfg}->{stub}->{loginShell},
			  objectClass => $ldap_crud->{cfg}->{objectClass}->{acc_svc_common},
			  gecos => uc($arg->{service}) . ': ' . $arg->{'login'} . ' @ ' .
			  $arg->{associatedDomain},
			  description => uc($arg->{service}) . ': ' . $arg->{'login'} . ' @ ' .
			  $arg->{associatedDomain},
			 ];
  }

  my ($authorizedService_add, $success_mesage, $error_message, $jpegPhoto_file);
  if ( $arg->{service} eq 'mail') {
    push @{$authorizedService},
      homeDirectory => $ldap_crud->{cfg}->{authorizedService}->{$arg->{service}}->{homeDirectory_prefix} .
      $arg->{associatedDomain} . '/' . $arg->{uid},
      'mu-mailBox' => 'maildir:/var/mail/' . $arg->{associatedDomain} . '/' . $arg->{uid},
      gidNumber => $ldap_crud->{cfg}->{authorizedService}->{$arg->{service}}->{gidNumber},
      userPassword => $arg->{password}->{$arg->{service}}->{'ssha'},
      objectClass => [ 'mailutilsAccount' ];
  } elsif ( $arg->{service} eq 'xmpp') {
    if ( defined $arg->{jpegPhoto} ) {
      $jpegPhoto_file = $arg->{jpegPhoto}->{'tempname'};
    } else {
      $jpegPhoto_file = $ldap_crud->{cfg}->{authorizedService}->{$arg->{service}}->{jpegPhoto_noavatar};
    }

    push @{$authorizedService},
      homeDirectory => $ldap_crud->{cfg}->{stub}->{homeDirectory},
      gidNumber => $ldap_crud->{cfg}->{authorizedService}->{$arg->{service}}->{gidNumber},
      userPassword => $arg->{password}->{$arg->{service}}->{'ssha'},
      telephonenumber => $arg->{telephoneNumber},
      jpegPhoto => [ $self->file2var( $jpegPhoto_file, $final_message) ];
  } elsif ( $arg->{service} eq '802.1x-mac' ||
	    $arg->{service} eq '802.1x-eap' ) {
    $arg->{dn} = 'uid=' . $self->macnorm({ mac => $arg->{login} }) . ',' . $arg->{basedn};
    undef $authorizedService;
    push @{$authorizedService},
      authorizedService => $arg->{service} . '@' . $arg->{associatedDomain},
      uid => $self->macnorm({ mac => $arg->{login} }),
      cn => $self->macnorm({ mac => $arg->{login}}),
      objectClass => $ldap_crud->{cfg}->{objectClass}->{acc_svc_802_1x},
      userPassword => $arg->{password}->{$arg->{service}}->{clear},
      description => uc($arg->{service}) . ': ' . $arg->{'login'},
      radiusgroupname => $arg->{radiusgroupname},
      radiustunnelmediumtype => 6,
      radiusservicetype => 'Framed-User',
      radiustunnelprivategroupid => $arg->{radiustunnelprivategroupid},
      radiustunneltype => 13;
  } elsif ( $arg->{service} eq 'ssh' ) {
    ## I failed to figure out how to do that neither with Crypt::RSA nor with
    ## Net::SSH::Perl::Key, so leaving it for better times
    # if ( $arg->{to_sshkeygen} ) {
    #   use Crypt::RSA;
    #   $sshkey->{chain} = new Crypt::RSA::Key;
    #   ($sshkey->{pub}, $sshkey->{pvt}) =
    #   	$sshkey->{chain}->generate (
    #   				KF => 'SSH',
    #   				Identity  => 'Lord Macbeth <macbeth@glamis.com>',
    #   				Size      => 2048,
    #   				Verbosity => 1,
    #   			       ) or die $sshkey->{chain}->errstr();
    #   p $sshkey;
    # } else {
    # }
    my $sshPublicKey;
    if ( ref($arg->{sshpublickey}) eq 'ARRAY' ) {
      foreach ( @{$arg->{sshpublickey}} ) {
	push @{$sshPublicKey}, $_;
      }
    } else {
      push @{$sshPublicKey}, $arg->{sshpublickey};
    }

    $authorizedService = [
			  objectClass => $ldap_crud->{cfg}->{objectClass}->{ssh},
			  sshPublicKey => [ @$sshPublicKey ],
			  uid => $arg->{uid},
			 ];
  } elsif ( $arg->{service} eq 'ovpn' ) {

    my $usercertificate = file2var($arg->{userCertificate}->{'tempname'}, $final_message);
    $arg->{dn} = 'cn=' . substr($arg->{userCertificate}->{filename},0,-4) . ',' . $arg->{basedn};
    $authorizedService = [
			  cn => substr($arg->{userCertificate}->{filename},0,-4),
			  # here `sn' is "missused" since we use it as
			  # Serial Number rather than last (family)
			  # name(s) for which the entity is known by
			  sn => '' . $self->cert_info({ cert => $usercertificate })->{'S/N'},
			  objectClass => $ldap_crud->{cfg}->{objectClass}->{ovpn},
			  'userCertificate;binary' => $usercertificate,
			 ];
  }

  p $arg->{dn};
  p $authorizedService;

  my $mesg =
    $ldap_crud->add(
    		    $arg->{dn},
    		    $authorizedService,
    		   );
  if ( $mesg ) {
    push @{$final_message->{error}}, 'Error during ' . uc($arg->{service}) .
      ' account creation occured:</h4><strong><em>' . $mesg->{caller} . $mesg->{html} .
      '</em></strong>service account was not created, you need take care of it!';
  } else {
    push @{$final_message->{success}},
      sprintf('<i class="%s fa-fw"></i>&nbsp;<em>%s account login:</em> &laquo;<strong class="text-success">%s</strong>&raquo; <em>password:</em> &laquo;<strong class="text-success mono">%s</strong>&raquo;',
	      $ldap_crud->{cfg}->{authorizedService}->{$arg->{service}}->{icon},
	      $arg->{service},
	      substr((split(/,/,$arg->{dn}))[0],4),
	      $arg->{password}->{$arg->{service}}->{'clear'});
  }
}


sub file2var {
  my  ( $self, $file, $final_message ) = @_;
  local $/ = undef;
  open(my $fh, "<", $file) or push @{$final_message->{error}}, "Can not open $file: $!";
  my $file_in_var = <$fh>;
  close($fh) or push @{$final_message->{error}}, "$!";
  return $file_in_var;
}



=head1 AUTHOR

Zeus

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;

# -*- mode: cperl -*-
#

package UMI::Controller::User;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; with 'Tools'; }

use UMI::Form::User;
has 'form' => ( isa => 'UMI::Form::User', is => 'rw',
		lazy => 1, default => sub { UMI::Form::User->new },
		documentation => q{Form to add new, nonexistent user account/s},
	      );

use UMI::Form::UserAll;
has 'form_user_all' => ( isa => 'UMI::Form::UserAll', is => 'rw',
		lazy => 1, default => sub { UMI::Form::UserAll->new },
		documentation => q{Complex Form to add new, nonexistent user account/s},
	      );


=head1 NAME

UMI::Controller::User - Catalyst Controller

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
	 $c->check_user_roles('802.1x-eap-tls') ) {
      my $params = $c->req->parameters;
      $params->{'avatar'} = $c->req->upload('avatar') if $params->{'avatar'};

      use Data::Printer;
      # p $params;

      $c->stash( template => 'user/user_wrap.tt',
		 form => $self->form );

      return unless $self->form->process( # item_id => $ldapadduser_id,
					  posted => ($c->req->method eq 'POST'),
					  params => $params,
					  ldap_crud => $c->model('LDAP_CRUD'),
					);

      my $res = $self->create_account( $c );
      $c->log->debug( "create_account (from umi_add) error: " . $res) if $res;
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
    my  ( $self, $c ) = @_;
    my $args = $c->req->parameters;

    my $ldap_crud =
      $c->model('LDAP_CRUD');

    my $uidNumber = $ldap_crud->last_uidNumber;
    $uidNumber++;

    if ( $args->{'associateddomain'} eq 'ibs.dn.ua' ) {
      $args->{'associateddomain_prefix'} = 'im.';
    } else {
      $args->{'associateddomain_prefix'} = '';
    }

    my $descr = 'description has to be here';
    if (defined $args->{'descr'} && $args->{'descr'} ne '') {
      $descr = join(' ', $args->{'descr'});
      $descr = $self->utf2lat( $descr ) if $self->is_ascii( $descr );
    }

    my $telephoneNumber = '666';
    if (defined $args->{'telephonenumber'} && $args->{'telephonenumber'} ne '') {
      $telephoneNumber = $args->{'telephonenumber'};
    }

    #
    ## HERE WE NEED TO:
    ### set flag to create branch for localized version of data
    ###  associatedService=localization-ru,uid=U...-user01,ou=People,dc=ibs
    ###  associatedService=localization-uk,uid=U...-user01,ou=People,dc=ibs
    ### check value of each field to avoid non ASCII in ASCII dedicated fields
    ### like `shell', `home' e.t.c.
    ##
    #

    my $givenName = $self->is_ascii( $args->{'givenname'} ) ?
      $self->utf2lat( $args->{'givenname'} ) : $args->{'givenname'};

    my $sn = $self->is_ascii( $args->{'sn'} ) ?
      $self->utf2lat( $args->{'sn'} ) : $args->{'sn'};

    my $cn = $givenName . ' ' . $sn;

    my $o = $self->is_ascii( $args->{'org'} ) ?
      $self->utf2lat( $args->{'org'} ) : $args->{'org'};

    my ( $pwd, $file, $jpeg);
    if (defined $args->{'avatar'}) {
      $file = $args->{'avatar'}->{'tempname'};
    } else {
      $file = $c->path_to('root','static','images','avatar-mgmnt.png');
    }
    local $/ = undef;
    open(my $fh, "<", $file) or $c->log->debug("Can not open $file: $!" );
    $jpeg = <$fh>;
    close($fh) or $c->log->debug($!);

    # my $uid_prefix = sprintf("U%sC%04d-", time(), int(rand(1000)));
    my $uid_prefix = '';

    my $success_message;

    if ( ! defined $args->{'password1'} or $args->{'password1'} eq '' ) {
      $pwd = { root => $self->pwdgen };
    } else {
      $pwd = { root => $self->pwdgen( { pwd => $args->{'password1'} } ) };
    }

    ######################################################################
    # Account ROOT Object
    ######################################################################
    my $ldif =
      $ldap_crud->add(
		      'uid=' . $uid_prefix . $args->{'login'} .
		      ',' . $ldap_crud->cfg->{base}->{acc_root},
		      [
		       uid => $uid_prefix . $args->{'login'},
		       userPassword => $pwd->{root}->{ssha},
		       mail => $args->{'login'} . '@' . $args->{'associateddomain'},
		       telephoneNumber => $telephoneNumber,
		       physicalDeliveryOfficeName => $args->{'office'},
		       givenName => $givenName,
		       sn => $sn,
		       cn => $cn,
		       uidNumber => $uidNumber,
		       gidNumber => $ldap_crud->cfg->{stub}->{gidNumber},
		       description => $descr,
		       gecos => $descr,
		       homeDirectory => $ldap_crud->cfg->{stub}->{homeDirectory},
		       jpegPhoto => [ $jpeg ],
		       loginShell => $ldap_crud->cfg->{stub}->{loginShell},
		       title => $self->is_ascii($args->{'title'}) ? $self->utf2lat($args->{'title'}) : $args->{'title'},
		       objectClass => [ qw(top
					   posixAccount
					   inetOrgPerson
					   organizationalPerson
					   person
					   inetLocalMailRecipient
					 ) ],
		      ],
		     );

    my $error_message;
    if ( $ldif ) {
      $error_message = '<li>Error during management account creation occured: ' . $ldif . '</li>';
      $c->log->debug("error during root obj creation: " . $ldif);
    } else {
      $success_message .= '<li><em>MANAGEMENT account login:</em> &laquo;<strong>' .
	$uid_prefix . $args->{'login'} . '</strong>&raquo; <em>password:</em> &laquo;<strong>' .
	  $pwd->{root}->{'clear'} . '</strong>&raquo;</li>';
    }

    my ( $associatedDomain, $authorizedService, $authorizedService_add );

    # if it was choosen only one single service we have to be sure we
    # pass through the array, not the string
    my @services;
    if ( ref( $args->{'authorizedservice'} ) eq 'ARRAY' ) {
      @services = @{$args->{'authorizedservice'}};
    } else {
      push @services, $args->{'authorizedservice'};
    }
    my ($create_account_branch_return, $create_account_branch_leaf_return);
    foreach my $service ( @services ) {
      $ldif = 0;
      # next if $service =~ /^802.1x-.*/;

      if ( ! defined $args->{'password1'} or $args->{'password1'} eq '' ) {
    	$pwd = { $service => $self->pwdgen };
      } elsif ( $service =~ /^802.1x-.*/ ) {
	$pwd->{service}->{clear} = $args->{login};
      } else {
    	$pwd = { $service => $self->pwdgen( { pwd => $args->{'password1'} } ) };
      }

      if ( $service eq 'xmpp' && $args->{'associateddomain_prefix'} ne '' ) {
    	$associatedDomain = $args->{'associateddomain_prefix'} . $args->{'associateddomain'};
      } else {
    	$associatedDomain = $args->{'associateddomain'};
      }

      ######################################################################
      # Account branch of ROOT Object
      ######################################################################
      $create_account_branch_return =
	$self->create_account_branch ( $ldap_crud,
				{
				 uid_prefix => $uid_prefix,
				 login => $args->{login},
				 service => $service,
				 associatedDomain => $associatedDomain,
				},
			      );

      $success_message .= $create_account_branch_return->[1] if defined $create_account_branch_return->[1];
      $error_message .= $create_account_branch_return->[0] if defined $create_account_branch_return->[0];

      ######################################################################
      # Leaf of the account branch of ROOT Object
      ######################################################################

      $create_account_branch_leaf_return =
	create_account_branch_leaf ( $c,
			      $ldap_crud,
			      {
			       basedn => sprintf("uid=%s%s,%s",
						 $uid_prefix,
						 $args->{'login'},
						 $ldap_crud->cfg->{base}->{acc_root}),
			       service => $service,
			       associatedDomain => $associatedDomain,
			       uidNumber => $uidNumber,
			       givenName => $givenName,
			       sn => $sn,
			       login => $args->{login},
			       password => $pwd->{$service},
			       telephoneNumber => $telephoneNumber,
			       jpegPhoto => $args->{avatar},
			       radiusgroupname => $args->{radiusgroupname} || 'ip-phone',
			       radiustunnelprivategroupid => defined $args->{radiustunnelprivategroupid} ? $args->{radiustunnelprivategroupid} : 3,
			      },
			    );

      $success_message .= $create_account_branch_leaf_return->[1] if defined $create_account_branch_leaf_return->[1];
      $error_message .= $create_account_branch_leaf_return->[0] if defined $create_account_branch_leaf_return->[0];

    }

    my $final_message;
    $final_message = '<div class="alert alert-success">' .
      '<span style="font-size: 140%" class="glyphicon glyphicon-ok-sign"></span>' .
	'&nbsp;<em>Passwords for newly created accounts are (without quotatin characters:' .
	  ' &laquo; and &raquo;):</em><ul>' . $success_message . '<ul></div>' if $success_message;

    $final_message .= '<div class="alert alert-danger">' .
      '<span style="font-size: 140%" class="icon_error-oct" aria-hidden="true"></span><ul>' .
	$error_message . '</ul></div>' if $error_message;

    $self->form->info_message( $final_message ) if $final_message;

    # $ldap_crud->unbind;
    return $ldif;
}



=head2 create_account_branch

creates branch for service accounts like

    dn: authorizedService=mail@foo.bar,uid=U012C01-john.doe,ou=People,dc=umidb
    authorizedService: mail@foo.bar
    uid: U012C01-john.doe@mail
    objectClass: account
    objectClass: authorizedServiceObject

=cut



sub create_account_branch {
  my  ( $self, $ldap_crud, $args ) = @_;

  my $arg = {
	     service => $args->{service},
	     associatedDomain => $args->{associatedDomain},
	     uid_prefix => $args->{uid_prefix} || '',
	     login => $args->{login} || undef,
	     base_uid => $args->{base_uid},
	    };

  $arg->{dn} = $arg->{base_uid} ?
    sprintf("authorizedService=%s@%s,uid=%s,%s",
	    $arg->{service}, $arg->{associatedDomain},
	    $arg->{base_uid},
	    $ldap_crud->cfg->{base}->{acc_root}) :
    sprintf("authorizedService=%s@%s,uid=%s%s,%s",
	    $arg->{service}, $arg->{associatedDomain},
	    $arg->{uid_prefix},
	    $arg->{login},
	    $ldap_crud->cfg->{base}->{acc_root});

  $arg->{ldapadd_arg} = [
			 'authorizedService' => $arg->{service} . '@' . $arg->{'associatedDomain'},
			 'uid' => $arg->{base_uid} ? $arg->{base_uid} . '@' . $arg->{service} :
			                             $arg->{uid_prefix} . $arg->{'login'} . '@' . $arg->{service},
			 'objectClass' => [ qw(account authorizedServiceObject) ],
			];

  my $if_exist = $ldap_crud->search( { base => $arg->{dn},
				       scope => 'base',
				       attrs => [ 'authorizedService' ],
				     } );
  my $return;
  if ( $if_exist->count ) {
    $return->[2] = '<li>branch DN: <b>&laquo;' . $arg->{dn} .'&raquo;</b> was not created since it <b>already exists</b>, I will use it further.</li>';
  } else {
    my $mesg = $ldap_crud->add( $arg->{dn}, $arg->{ldapadd_arg} );
    if ( $mesg ) {
      $return->[0] = '<li>error during ' . uc($arg->{service}) .
	' branch creation occured: ' . $mesg . '</li>';
    } else { $return->[1] = undef; }
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

=cut



sub create_account_branch_leaf {
  my  ( $self, $ldap_crud, $args ) = @_;

  my $arg = {
	     service => $args->{service},
	     associatedDomain => $args->{associatedDomain},
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

  $arg->{basedn} = 'authorizedService=' . $args->{service} . '@' . $args->{associatedDomain} .
    ',' . $args->{basedn};

  $arg->{uid} = $arg->{'login'} . '@' . $arg->{associatedDomain};

  $arg->{dn} = 'uid=' . $arg->{uid} . ',' . $arg->{basedn};

  my ($authorizedService, $sshkey);

  if ( $arg->{service} eq 'ovpn' ) {
    # left empty for latter amendations
  } elsif ( $arg->{service} eq 'ssh' ) {
    # left empty for latter amendations
  } elsif ( $arg->{service} eq '802.1x-mac' ||
	    $arg->{service} eq '802.1x-eap-tls' ) {
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
			  loginShell => $ldap_crud->cfg->{stub}->{loginShell},
			  objectClass => $ldap_crud->cfg->{objectClass}->{acc_svc_common},
			  userPassword => $arg->{password}->{'ssha'},
			  gecos => uc($arg->{service}) . ': ' . $arg->{'login'} . ' @ ' .
			  $arg->{associatedDomain},
			  description => uc($arg->{service}) . ': ' . $arg->{'login'} . ' @ ' .
			  $arg->{associatedDomain},
			 ];
  }

  my ($authorizedService_add, $success_mesage, $error_message, $jpegPhoto_file);
  if ( $arg->{service} eq 'mail') {
    $authorizedService_add =
      [
       homeDirectory => $ldap_crud->cfg->{authorizedService}->{$arg->{service}}->{homeDirectory_prefix} .
       $arg->{associatedDomain} . '/' .
       $arg->{uid},
       'mu-mailBox' => 'maildir:/var/mail/' .
       $arg->{associatedDomain} . '/' .
       $arg->{uid},
       gidNumber => $ldap_crud->cfg->{authorizedService}->{$arg->{service}}->{gidNumber},
       objectClass => [ 'mailutilsAccount' ],
      ];
  } elsif ( $arg->{service} eq 'xmpp') {
    if ( $arg->{jpegPhoto} ) {
      $jpegPhoto_file = $arg->{jpegPhoto}->{'tempname'};
    } else {
      $jpegPhoto_file = $ldap_crud->cfg->{authorizedService}->{$arg->{service}}->{jpegPhoto_noavatar};
    }
    # p $arg->{jpegPhoto};
    local $/ = undef;
    open(my $fh, "<", $jpegPhoto_file) or warn "Can not open $arg->{jpegPhoto}: $!";
    my $jpeg = <$fh>;
    close($fh) or warn "Can not close $arg->{jpegPhoto}: $!";

    $authorizedService_add =
      [
       homeDirectory => $ldap_crud->cfg->{stub}->{homeDirectory},
       gidNumber => $ldap_crud->cfg->{authorizedService}->{$arg->{service}}->{gidNumber},
       telephonenumber => $arg->{telephoneNumber},
       jpegPhoto => [ $jpeg ],
      ];
  } elsif ( $arg->{service} eq '802.1x-mac' ||
	    $arg->{service} eq '802.1x-eap-tls' ) {
    $arg->{uid} = $arg->{'login'};
    $authorizedService_add =
      [
       authorizedService => $arg->{service} . '@' . $arg->{associatedDomain},
       uid => $self->macnorm({ mac => $arg->{uid} }),
       cn => $self->macnorm({ mac => $arg->{uid}}),
       objectClass => $ldap_crud->cfg->{objectClass}->{acc_svc_802_1x},
       userPassword => $arg->{password}->{clear},
       description => uc($arg->{service}) . ': ' . $arg->{'login'},
       radiusgroupname => $arg->{radiusgroupname},
       radiustunnelmediumtype => 6,
       radiusservicetype => 'Framed-User',
       radiustunnelprivategroupid => $arg->{radiustunnelprivategroupid},
       radiustunneltype => 13,
      ];
    # p $authorizedService_add;
    undef $authorizedService;
    $authorizedService = [];
    $arg->{dn} = 'uid=' . $arg->{'login'} . ',' . $arg->{basedn};
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
			  objectClass => $ldap_crud->cfg->{objectClass}->{ssh},
			  sshPublicKey => [ @$sshPublicKey ],
			 ];
    $authorizedService_add = [];
  } elsif ( $arg->{service} eq 'ovpn' ) {
    # p $arg->{userCertificate};
    local $/ = undef;
    open(my $fh, "<", $arg->{userCertificate}->{'tempname'}) or warn "Can not open $arg->{userCertificate}: $!";
    my $usercertificate = <$fh>;
    close($fh) or warn "Can not close $arg->{userCertificate}: $!";
    $arg->{dn} = 'cn=' . substr($arg->{userCertificate}->{filename},0,-4) . ',' . $arg->{basedn};
    $authorizedService = [
			  cn => substr($arg->{userCertificate}->{filename},0,-4),
			  # here `sn' is "missused" since we use it as
			  # Serial Number rather than last (family)
			  # name(s) for which the entity is known by
			  sn => '' . $self->cert_info({ cert => $usercertificate })->{'S/N'},
			  objectClass => $ldap_crud->cfg->{objectClass}->{ovpn},
			  'userCertificate;binary' => $usercertificate,
			 ];
    $authorizedService_add = [];
  }

  my $mesg =
    $ldap_crud->add(
		    $arg->{dn},
		    [ @$authorizedService, @$authorizedService_add ],
		   );
  my $return;
  if ( $mesg ) {
    $return->[0] = '<li><h4 class="text-danger">Error during ' . uc($arg->{service}) .
      ' account creation occured:</h4><strong><em>' . $mesg->{caller} . $mesg->{html} .
	'</em></strong>service account was not created, you need take care of it!</li>';

  } else {
    $return->[1] = '<li><em>' . uc( $arg->{service} ) . ' account login:</em> &laquo;<strong>' .
      $arg->{uid} . '</strong>&raquo; <em>password:</em> &laquo;<strong>' .
	  $arg->{password}->{'clear'} . '</strong>&raquo;</li>';
  }
  return $return;
}

sub modpwd :Path(modpwd) :Args(0) {
    my ( $self, $c, $ldapadduser_id ) = @_;
    if ( $c->check_user_roles('wheel')) {
      # use Data::Dumper;

      $c->stash( template => 'user/user_modpwd.tt',
		 form => $self->form );

      my $params = $c->req->parameters;

      use Data::Printer;
      p $params;

      # Validate and insert/update database
      return unless $self->form->process( item_id => $ldapadduser_id,
					  posted => ($c->req->method eq 'POST'),
					  params => $params,
					  ldap_crud => $c->model('LDAP_CRUD'),
					);

      # $c->log->debug("Moose::Role test:\n" . $self->is_ascii("latin1"));

      my $res = $self->create_account( $c );
      $c->log->debug( "create_account (from umi_add) error: " . $res) if $res;
    } else { 
      $c->response->body('Unauthorized!');
    }

}


sub user_add_svc_new :Path(user_add_svc_new) :Args(0) {
  my ( $self, $c ) = @_;
  my ( @office, @branches, $final_message );

  my $params = $c->req->parameters;

  $c->stash(
	    template => 'user/user_all.tt',
	    form => $self->form_user_all,
	    params => $params,
	   );

  use Data::Printer;
  $final_message->{warning} = '<pre>' . p($params) . '</pre>';

  return $self->form_user_all->process(
				       posted => ($c->req->method eq 'POST'),
				       params => $params,
				       ldap_crud => $c->model('LDAP_CRUD'),
				      ); # if ! $self->form_user_all->has_errors;

  # p $final_message->{danger} = join('<br>', $self->form_user_all->errors);
  # p $params;
  # $c->stash( final_message => $final_message, );

}


=head1 AUTHOR

Zeus

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;

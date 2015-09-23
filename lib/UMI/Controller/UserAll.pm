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
      my $params = $c->req->parameters;
      $self->form->add_svc_acc( defined $params->{add_svc_acc} ? $params->{add_svc_acc} : '' );
      my $final_message;

      # here we initialize repeatable fields to be rendered when the form is called from
      # another one
      if ( defined $self->form->add_svc_acc &&
      	   $self->form->add_svc_acc ne '' &&
      	   ! defined $params->{'account.0.associateddomain'} ) {
      	$params->{'account.0.associateddomain'} = '' if ! $params->{'account.0.associateddomain'};
      # 	$params->{'account.0.authorizedservice'} = '' if ! $params->{'account.0.aut# horizedservice'};
      # 	$params->{'account.0.login'} = '' if ! $params->{'account.0.login'};
      # 	$params->{'account.0.password1'} = '' if ! $params->{'account.0.password1'};
      # 	$params->{'account.0.password2'} = '' if ! $params->{'account.0.password2'};
      # 	$params->{'account.0.radiusgroupname'} = '' if ! $params->{'account.0.radiusgroupname'};
      # 	$params->{'account.0.radiusprofiledn'} = '' if ! $params->{'account.0.radiusprofiledn'};
      # 	$params->{'account.0.usercertificate'} = '' if ! $params->{'account.0.usercertificate'};
      }
      if ( defined $self->form->add_svc_acc &&
      		$self->form->add_svc_acc ne '' &&
      		! defined $params->{'loginless_ovpn.0.associateddomain'} ) {
      	$params->{'loginless_ovpn.0.associateddomain'} = '' if ! $params->{'loginless_ovpn.0.associateddomain'};
      # 	$params->{'loginless_ovpn.0.devmake'} = '' if ! $params->{'loginless_ovpn.0.devmake'};
      # 	$params->{'loginless_ovpn.0.devmodel'} = '' if ! $params->{'loginless_ovpn.0.devmodel'};
      # 	$params->{'loginless_ovpn.0.devos'} = '' if ! $params->{'loginless_ovpn.0.devos'};
      # 	$params->{'loginless_ovpn.0.devosver'} = '' if ! $params->{'loginless_ovpn.0.devosver'};
      # 	$params->{'loginless_ovpn.0.devtype'} = '' if ! $params->{'loginless_ovpn.0.devtype'};
      # 	$params->{'loginless_ovpn.0.ifconfigpush'} = '' if ! $params->{'loginless_ovpn.0.ifconfigpush'};
      # 	$params->{'loginless_ovpn.0.status'} = '' if ! $params->{'loginless_ovpn.0.status'};
      # 	$params->{'loginless_ovpn.0.userCertificate'} = '' if ! $params->{'loginless_ovpn.0.userCertificate'};
      }
      if ( defined $self->form->add_svc_acc &&
      	   $self->form->add_svc_acc ne '' &&
      	   ! defined $params->{'loginless_ssh.0.associateddomain'} ) {
      	$params->{'loginless_ssh.0.associateddomain'} = '' if ! $params->{'loginless_ssh.0.associateddomain'};
      # 	$params->{'loginless_ssh.0.key'} = '' if ! $params->{'loginless_ssh.0.key'};
      }

      $params->{'person_avatar'} = $c->req->upload('person_avatar') if $params->{'person_avatar'};

      my $i = 0;
      #foreach ( $self->form->field('account')->fields ) {
      for ( ; $i < 10; ) {
	$params->{'account.' . $i . '.userCertificate'} =
	  $c->req->upload('account.' . $i . '.userCertificate')
	  if defined $params->{'account.' . $i . '.userCertificate'} &&
	  $params->{'account.' . $i . '.userCertificate'} ne '';
	$i++;
      }
      $i = 0;
      foreach ( $self->form->field('loginless_ovpn')->fields ) {
	$params->{'loginless_ovpn.' . $i . '.userCertificate'} =
	  $c->req->upload('loginless_ovpn.' . $i . '.userCertificate')
	  if defined $params->{'loginless_ovpn.' . $i . '.userCertificate'} &&
	  $params->{'loginless_ovpn.' . $i . '.userCertificate'} ne '';
	$i++;
      }

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

}

=head2 create_account

=cut

sub create_account {
  my  ( $self, $ldap_crud, $args ) = @_;
  my ( @form_fields,
       $uid,
       $uidNumber,
       $descr,
       $pwd,
       $file,
       $jpeg,
       $final_message,
       $success_message,
       $warning_message,
       $error_message );

  ###################################################################################
  # NEW ACCOUNT, not additional service one
  ###################################################################################
  # NEW/ADDITIONAL acoount start
  if ( defined $self->form->add_svc_acc && $self->form->add_svc_acc eq '' ) {
    @form_fields = defined $args->{person_simplified} &&
      $args->{person_simplified} eq "1" ? qw{ account } : qw{ account loginless_ovpn loginless_ssh groups };
    $uidNumber = $ldap_crud->last_uidNumber + 1;

    $args->{'uid_suffix'} = $self->form->namesake ? $self->form->namesake : '';
    $args->{'person_givenname'} = $self->utf2lat( $args->{'person_givenname'} )
      if $self->is_ascii( $args->{'person_givenname'} );
    $args->{'person_sn'} =  $self->utf2lat( $args->{'person_sn'} )
      if $self->is_ascii( $args->{'person_sn'} );
    $args->{'person_telephonenumber'} = '666'
      if $args->{'person_telephonenumber'} eq '';

    if (defined $args->{'person_description'} && $args->{'person_description'} ne '') {
      $descr = join(' ', $args->{'person_description'});
      $descr = $self->utf2lat( $descr ) if $self->is_ascii( $descr );
    } else {
      $descr = 'description has to be here';
    }

    $args->{'person_title'} = 'employee'
      if ! defined $args->{'person_title'} || $args->{'person_title'} eq '';

    if (defined $args->{'person_avatar'}) {
      $file = $args->{'person_avatar'}->{'tempname'};
    } else {
      $file = $ldap_crud->cfg->{stub}->{noavatar_mgmnt};
    }
    $jpeg = $self->file2var( $file, $final_message );

    $pwd = $args->{'person_password1'} eq '' ?
      { root => $self->pwdgen } :
      { root => $self->pwdgen( { pwd => $args->{'person_password1'} } ) };

    #---------------------------------------------------------------------
    # Account ROOT Object
    #---------------------------------------------------------------------
    # here we need suffix yet if the combination exists
    $uid = sprintf('%s%s',
		   $self->form->autologin,
		   $self->form->namesake );

    my $root_add_dn = sprintf('uid=%s,%s',
			      $uid,
			      $ldap_crud->cfg->{base}->{acc_root});
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
       gidNumber => $ldap_crud->cfg->{stub}->{gidNumber},
       description => $descr,
       gecos => sprintf('%s %s',
			$args->{person_givenname},
			$args->{person_sn}),
       homeDirectory => $ldap_crud->cfg->{stub}->{homeDirectory},
       jpegPhoto => [ $jpeg ],
       loginShell => $ldap_crud->cfg->{stub}->{loginShell},

       title => $self->is_ascii($args->{'person_title'}) ?
       lc($self->utf2lat($args->{'person_title'})) :
       lc($args->{'person_title'}),

       objectClass => $ldap_crud->cfg->{objectClass}->{acc_root},
      ];

    my $ldif = $ldap_crud->add( $root_add_dn, $root_add_options );
    if ( $ldif ) {
      push @{$final_message->{error}},
	sprintf('Error during management account creation occured: %s<br><b>srv: </b><pre>%s</pre><b>text: </b>%s' .
		$ldif->{html},
		$ldif->{srv},
		$ldif->{text});
    } else {
      push @{$final_message->{success}},
	sprintf('<i class="fa fa-user fa-lg fa-fw"></i>&nbsp;<em>root account login:</em> &laquo;<strong class="text-success">%s</strong>&raquo; <em>password:</em> &laquo;<strong class="text-success mono">%s</strong>&raquo;',
		$uid,
		$pwd->{root}->{'clear'}) ;
    }

  } else {
    #####################################################################################
    # ADDITIONAL service account (no root account creation, but using the existent one)
    #####################################################################################

    my $add_to = $ldap_crud->search( { base => $self->form->add_svc_acc, scope => 'base', } );
    if ( ! $add_to->count ) {
      $final_message->{error} = 'no root object with DN: <b>&laquo;' .
	$self->form->add_svc_acc . '&raquo;</b> found!';
    }
    my $add_to_obj = $add_to->entry(0);

    $uidNumber = $add_to_obj->get_value('uidNumber');
    $args->{'person_givenname'} = $add_to_obj->get_value('givenName');
    $args->{'person_sn'} = $add_to_obj->get_value('sn');
    $args->{'person_telephonenumber'} = $add_to_obj->exists('telephonenumber') ?
      $add_to_obj->get_value('telephonenumber') : '666';
    $descr = $add_to_obj->exists('description') ?
      $add_to_obj->get_value('description') : 'description has to be here';

    $uid = $add_to_obj->get_value('uid');
  }
  # NEW/ADDITIONAL acoount stop

  my ( $element, $associatedDomain, $authorizedService, $authorizedService_add, $branch, $leaf);
  my $is_svc_empty = '';

  ######################################################################
  # SERVICE ACCOUNTS PROCESSING START
  ######################################################################

  #================================================================================
  # person_simplified checkbox is *CHECKED*, we continue with SIMPLIFIED form
  #================================================================================
  if ( defined $args->{person_simplified} && $args->{person_simplified} eq '1' ) {
      
    #---------------------------------------------------------------------
    # Simplified Account mail branch of ROOT Object Creation
    #---------------------------------------------------------------------
    $branch =
      $self
      ->create_account_branch ( $ldap_crud,
				{
				 uid => $uid,
				 authorizedservice => 'mail',
				 associateddomain => $args->{person_associateddomain},
				},
			      );

    push @{$final_message->{success}}, $branch->{success} if defined $branch->{success};
    push @{$final_message->{warning}}, $branch->{warning} if defined $branch->{warning};
    push @{$final_message->{error}}, $branch->{error} if defined $branch->{error};

    #---------------------------------------------------------------------
    # Simplified Leaf of the account mail branch of ROOT Object
    #---------------------------------------------------------------------
    my $x =
      {
       basedn => $branch->{dn},
       authorizedservice => 'mail',
       associateddomain => $branch->{associateddomain_prefix} . $args->{person_associateddomain},
       uidNumber => $uidNumber,
       givenName => $args->{person_givenname},
       sn => $args->{person_sn},
       telephoneNumber => $args->{person_telephonenumber},
       login => defined $args->{person_login} &&
       $args->{person_login} ne '' ? $args->{person_login} : $uid,
      };

    if ( ! $args->{person_password1} &&
	 ! $args->{person_password2} ) {
      $x->{password}->{mail} = $self->pwdgen;
      $x->{password}->{xmpp} = $self->pwdgen;
    } else {
      $x->{password}->{mail} = $self->pwdgen( { pwd => $args->{person_password2} } );
      $x->{password}->{xmpp} = $self->pwdgen( { pwd => $args->{person_password2} } );
    }

    $leaf =
      $self->create_account_branch_leaf ( $ldap_crud, $x, );
    push @{$final_message->{success}}, @{$leaf->{success}} if defined $leaf->{success};
    push @{$final_message->{warning}}, @{$leaf->{warning}} if defined $leaf->{warning};
    push @{$final_message->{error}}, @{$leaf->{error}} if defined $leaf->{error};

    #---------------------------------------------------------------------
    # Simplified Account xmpp branch of ROOT Object Creation
    #---------------------------------------------------------------------
    $branch =
      $self
      ->create_account_branch ( $ldap_crud,
				{
				 uid => $uid,
				 authorizedservice => 'xmpp',
				 associateddomain => $args->{person_associateddomain},
				},
			      );

    push @{$final_message->{success}}, $branch->{success} if defined $branch->{success};
    push @{$final_message->{warning}}, $branch->{warning} if defined $branch->{warning};
    push @{$final_message->{error}}, $branch->{error} if defined $branch->{error};

    #---------------------------------------------------------------------
    # Simplified Leaf of the account email branch of ROOT Object
    #---------------------------------------------------------------------
    $x->{basedn} = $branch->{dn};
    $x->{authorizedservice} = 'xmpp';

    $leaf =
      $self->create_account_branch_leaf ( $ldap_crud, $x, );
    push @{$final_message->{success}}, @{$leaf->{success}} if defined $leaf->{success};
    push @{$final_message->{warning}}, @{$leaf->{warning}} if defined $leaf->{warning};
    push @{$final_message->{error}}, @{$leaf->{error}} if defined $leaf->{error};

      
    #===========================================================================
    # person_simplified checkbox is *not* checked, we continue with GENERAL form
    #===========================================================================
  } else {
    @form_fields = qw{ account loginless_ovpn loginless_ssh groups };
    foreach my $form_field ( @form_fields ) {
      next if $form_field eq 'groups'; # groups we are skiping now
      foreach $element ( $self->form->field($form_field)->fields ) {
	# p @{[$self->form->field($form_field)->fields]};
	foreach ( $element->fields ) {
	  $is_svc_empty .= $_->value if defined $_->value;
	}			     # p $is_svc_empty;
	next if $is_svc_empty eq ''; # avoid all empty services

	#---------------------------------------------------------------------
	# Account branch of ROOT Object
	#---------------------------------------------------------------------
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

	#---------------------------------------------------------------------
	# LEAF of the account BRANCH of ROOT Object
	#---------------------------------------------------------------------
	my $x =
	  {
	   basedn => $branch->{dn},
	   authorizedservice => $form_field ne 'account' ?
	   substr($form_field, 10) : $element->field('authorizedservice')->value,
	   associateddomain => sprintf('%s%s',
					 defined $ldap_crud->cfg
					 ->{authorizedService}
				       ->{$form_field ne 'account' ?
					  substr($form_field, 10) : $element->field('authorizedservice')->value}
					 ->{associateddomain_prefix}
					 ->{$element->field('associateddomain')->value} ?
					 $ldap_crud->cfg
					 ->{authorizedService}
				       ->{$form_field ne 'account' ?
					  substr($form_field, 10) : $element->field('authorizedservice')->value}
					 ->{associateddomain_prefix}
					 ->{$element->field('associateddomain')->value} : '',
					 $element->field('associateddomain')->value),
	   uidNumber => $uidNumber,
	   description => defined $element->field('description')->value ?
	   $element->field('description')->value : '',
	   gecos => sprintf('%s %s',),
	   givenName => $args->{person_givenname},
	   sn => $args->{person_sn},
	   telephoneNumber => $args->{person_telephonenumber},
	   # jpegPhoto => $jpeg,
	  };
	if ( $form_field eq 'account' ) {
	  if ( $element->field('authorizedservice')->value =~ /^802.1x-.*/ ) {
	    if ( $element->field('authorizedservice')->value eq '802.1x-mac' ) {
	      $x->{password} = { $element->field('authorizedservice')->value =>
				 { clear => $self->macnorm({ mac => $element->field('login')->value }) }
			       };
	    } elsif ( $element->field('authorizedservice')->value eq '802.1x-eap-tls' ) {
	      $x->{password} = { $element->field('authorizedservice')->value =>
				 { clear => sprintf('%s%s',
						    defined $ldap_crud
						    ->cfg
						    ->{authorizedService}
						    ->{$element->field('authorizedservice')->value}
						    ->{login_prefix} ?
						    $ldap_crud->cfg
						    ->{authorizedService}
						    ->{$element->field('authorizedservice')->value}
						    ->{login_prefix} : '',
						    defined $element->field('login')->value ?
						    $element->field('login')->value : $uid ) }
			       };
	    }

	    $x->{radiusgroupname} = $element->field('radiusgroupname')->value
	      if defined $element->field('radiusgroupname')->value;
	    $x->{radiusprofiledn} = $element->field('radiusprofiledn')->value
	      if defined $element->field('radiusprofiledn')->value;
	  } elsif ( ! $element->field('password1')->value &&
		    ! $element->field('password2')->value) {
	    $x->{password} = { $element->field('authorizedservice')->value => $self->pwdgen };
	  } else {
	    $x->{password} = { $element->field('authorizedservice')->value =>
			       $self->pwdgen( { pwd => $element->field('password2')->value } ) };
	  }

	  $x->{login} = defined $element->field('login')->value ? $element->field('login')->value : $uid;

	  $x->{userCertificate} = $element->field('userCertificate')->value
	    if defined $element->field('userCertificate')->value &&
	    $element->field('userCertificate')->value ne '';
	  
	} elsif ( $x->{authorizedservice} eq 'ssh' ) {
	  $x->{sshpublickey} = $element->field('key')->value;
	  $x->{login} = $uid;
	  $x->{password} = { $x->{authorizedservice} =>
			     { clear => '<del>NOPASSWORD</del>' }
			   };
	} elsif ( $x->{authorizedservice} eq 'ovpn' ) {
	  $x->{userCertificate} = $element->field('userCertificate')->value
	    if defined $element->field('userCertificate')->value;
	  $x->{password} = { $x->{authorizedservice} =>
			     { clear => '<del>NOPASSWORD</del>' } };
	  $x->{associateddomain} = $element->field('associateddomain')->value;
	  $x->{umiOvpnCfgIfconfigPush} = $element->field('ifconfigpush')->value || 'NA';
	  $x->{umiOvpnAddStatus} = $element->field('status')->value || 'blocked';
	  $x->{umiOvpnAddDevType} = $element->field('devtype')->value || 'NA';
	  $x->{umiOvpnAddDevMake} = $element->field('devmake')->value || 'NA';
	  $x->{umiOvpnAddDevModel} = $element->field('devmodel')->value || 'NA';
	  $x->{umiOvpnAddDevOS} = $element->field('devos')->value || 'NA';
	  $x->{umiOvpnAddDevOSVer} = $element->field('devosver')->value || 'NA';
	}

	$leaf =
	  $self->create_account_branch_leaf ( $ldap_crud, $x, );
	push @{$final_message->{success}}, @{$leaf->{success}} if defined $leaf->{success};
	push @{$final_message->{warning}}, @{$leaf->{warning}} if defined $leaf->{warning};
	push @{$final_message->{error}}, @{$leaf->{error}} if defined $leaf->{error};
      }
      $is_svc_empty = '';
    }
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
      dn => '...', # DN of the oject created
      success => '...', # success message
      warning => '...', # warning message
      error => '...', # error message
    }

=cut


sub create_account_branch {
  my  ( $self, $ldap_crud, $args ) = @_;
  my $arg = {
	     authorizedservice => $args->{authorizedservice},
	     associateddomain => sprintf('%s%s',
					 defined $ldap_crud
					 ->cfg
					 ->{authorizedService}
					 ->{$args->{authorizedservice}}
					 ->{associateddomain_prefix}
					 ->{$args->{associateddomain}} ?
					 $ldap_crud->cfg
					 ->{authorizedService}
					 ->{$args->{authorizedservice}}
					 ->{associateddomain_prefix}
					 ->{$args->{associateddomain}} : '',
					 $args->{associateddomain}),
	     uid => $args->{uid},
	    };

  $arg->{dn} = sprintf("authorizedService=%s@%s,uid=%s,%s",
		       $args->{authorizedservice},
		       $arg->{associateddomain},
		       $args->{uid},
		       $ldap_crud->cfg->{base}->{acc_root}),
  my ( $return, $if_exist);

  $arg->{add_attrs} = [ 'authorizedService'
			=> sprintf('%s@%s%s',
				   $arg->{authorizedservice},
				   defined $ldap_crud
				   ->cfg
				   ->{authorizedService}
				   ->{$args->{authorizedservice}}
				   ->{associateddomain_prefix}
				   ->{$args->{associateddomain}} ?
				   $ldap_crud
				   ->cfg
				   ->{authorizedService}
				   ->{$args->{authorizedservice}}
				   ->{associateddomain_prefix}
				   ->{$args->{associateddomain}} : '',
				   $arg->{associateddomain}),
			'uid' => $arg->{uid} . '@' . $arg->{authorizedservice},
			'objectClass' => $ldap_crud->cfg->{objectClass}->{acc_svc_branch}, ];

  $if_exist = $ldap_crud->search( { base => $arg->{dn},
				       scope => 'base',
				       attrs => [ 'authorizedService' ], } );
  if ( $if_exist->count ) {
    $return->{warning} = 'branch DN: <b>&laquo;' . $arg->{dn} . '&raquo;</b> '
      . 'was not created since it <b>already exists</b>, I will use it further.';
    $return->{dn} = $arg->{dn};
  } else {
    my $mesg = $ldap_crud->add( $arg->{dn}, $arg->{add_attrs} );
    if ( $mesg ) {
      $return->{error} = sprintf('Error during %s branch creation occured: %s<br><b>srv: </b><pre>%s</pre><b>text: </b>%s',
				 uc($arg->{service}),
				 $mesg->{html},
				 $mesg->{srv},
				 $mesg->{text});
    } else { # $return->{success} = sprintf('<i class="%s fa-fw"></i> branch object &laquo;<b class="text-success">%s</b>&raquo; was successfully created',
					  # $ldap_crud->cfg->{authorizedService}->{$arg->{authorizedservice}}->{icon},
					  # $arg->{dn});
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
    {
      success => [...],
      warning => [...],
      error => [...],
    }

=cut

sub create_account_branch_leaf {
  my  ( $self, $ldap_crud, $args ) = @_;
  my $arg = {
	     basedn => $args->{basedn},
	     service => $args->{authorizedservice},
	     associatedDomain => sprintf('%s%s',
					 defined $ldap_crud
					 ->cfg
					 ->{authorizedService}
					 ->{$args->{authorizedservice}}
					 ->{associateddomain_prefix}
					 ->{$args->{associateddomain}} ?
					 $ldap_crud->cfg
					 ->{authorizedService}
					 ->{$args->{authorizedservice}}
					 ->{associateddomain_prefix}
					 ->{$args->{associateddomain}} : '',
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
	     radiusprofiledn => $args->{radiusprofiledn} || '',
	    };
  my ( $return, $if_exist );

  $arg->{prefixed_uid} =
    sprintf('%s%s',
	    defined $ldap_crud->cfg->{authorizedService}->{$arg->{service}}->{login_prefix} ?
	    $ldap_crud->cfg->{authorizedService}->{$arg->{service}}->{login_prefix} : '',
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
			  objectClass => $ldap_crud->cfg->{objectClass}->{acc_svc_common},
			  authorizedService => $arg->{service} . '@' . $arg->{associatedDomain},
			  associatedDomain => $arg->{associatedDomain},
			  uid => $arg->{uid},
			  cn => $arg->{uid},
			  givenName => $arg->{givenName},
			  sn => $arg->{sn},
			  uidNumber => $arg->{uidNumber},
			  loginShell => $ldap_crud->cfg->{stub}->{loginShell},
			  gecos => sprintf('%s %s', $args->{givenName}, $args->{sn}),
			  description => $arg->{description} ne '' ? $arg->{description} :
			  sprintf('%s: %s @ %s', uc($arg->{service}), $arg->{'login'}, $arg->{associatedDomain}),
			 ];
  }

  #=== SERVICE: mail =================================================
  if ( $arg->{service} eq 'mail') {
    push @{$authorizedService},
      homeDirectory => $ldap_crud->cfg->{authorizedService}->{$arg->{service}}->{homeDirectory_prefix} .
      $arg->{associatedDomain} . '/' . $arg->{uid},
      'mu-mailBox' => 'maildir:/var/mail/' . $arg->{associatedDomain} . '/' . $arg->{uid},
      gidNumber => $ldap_crud->cfg->{authorizedService}->{$arg->{service}}->{gidNumber},
      userPassword => $arg->{password}->{$arg->{service}}->{'ssha'},
      objectClass => [ 'mailutilsAccount' ];
  #=== SERVICE: xmpp =================================================
  } elsif ( $arg->{service} eq 'xmpp') {
    if ( defined $arg->{jpegPhoto} ) {
      $jpegPhoto_file = $arg->{jpegPhoto}->{'tempname'};
    } else {
      $jpegPhoto_file = $ldap_crud->cfg->{authorizedService}->{$arg->{service}}->{jpegPhoto_noavatar};
    }

    push @{$authorizedService},
      homeDirectory => $ldap_crud->cfg->{stub}->{homeDirectory},
      gidNumber => $ldap_crud->cfg->{authorizedService}->{$arg->{service}}->{gidNumber},
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
	objectClass => $ldap_crud->cfg->{objectClass}->{acc_svc_802_1x},
	uid => $self->macnorm({ mac => $arg->{login} }),
	cn =>  $self->macnorm({ mac => $arg->{login} });
    } else {
      $arg->{dn} = sprintf('uid=%s,%s', $arg->{prefixed_uid}, $arg->{basedn}); # DN for EAP-TLS differs
      push @{$authorizedService},
	objectClass => $ldap_crud->cfg->{objectClass}->{acc_svc_802_1x_eaptls},
	uid => $arg->{prefixed_uid},
	cn => $arg->{prefixed_uid};
    }

    push @{$authorizedService},
      authorizedService => $arg->{service} . '@' . $arg->{associatedDomain},
      userPassword => $arg->{password}->{$arg->{service}}->{clear},
      description => uc($arg->{service}) . ': ' . $arg->{'login'};

    # we decided to not to put radiusGroupName to the obj
    # push @{$authorizedService},
    #   radiusgroupname => $arg->{radiusgroupname}
    #   if $arg->{radiusgroupname} ne '';
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
			  uid => $arg->{uid},
			 ];

  #=== SERVICE: ovpn =================================================
  } elsif ( $arg->{service} eq 'ovpn' ) {
    $arg->{dn} = 'cn=' . substr($arg->{userCertificate}->{filename},0,-4) . ',' . $arg->{basedn};
    $arg->{cert_info} =
      $self->cert_info({ cert => $self->file2var($arg->{userCertificate}->{'tempname'}, $return),
			 ts => "%Y%m%d%H%M%S", });
    $authorizedService = [
			  cn => substr($arg->{userCertificate}->{filename},0,-4),
			  associatedDomain => $arg->{associatedDomain},
			  objectClass => $ldap_crud->cfg->{objectClass}->{ovpn},
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
			  objectClass => $ldap_crud->cfg->{objectClass}->{acc_svc_web},
			  authorizedService => $arg->{service} . '@' . $arg->{associatedDomain},
			  associatedDomain => $arg->{associatedDomain},
			  uid => $arg->{uid},
			  userPassword => $arg->{password}->{$arg->{service}}->{'ssha'},
			 ];
  }

  # p $arg->{dn};
  # p $authorizedService;
  
  my $mesg;
  if ( $arg->{service} eq 'ssh' ) {
    # for an existent SSH object we have to modify rather than add
    $if_exist = $ldap_crud->search( { base => $arg->{dn}, scope => 'base', } );
    if ( $if_exist->count ) {
      $mesg = $ldap_crud->modify( $arg->{dn},
				  [ add => [ sshPublicKey => $sshPublicKey, ], ], );
      if ( $mesg ) {
	push @{$return->{error}},
	  sprintf('Error during %s service modification: %s<br><b>srv: </b><pre>%s</pre><b>text: </b>%s',
		  $arg->{service}, $mesg->{html}, $mesg->{srv}, $mesg->{text});
      }
    }
  } else {
    # for nonexistent SSH object and all others
    $mesg = $ldap_crud->add( $arg->{dn}, $authorizedService, );
    if ( $mesg ) {
      push @{$return->{error}},
	sprintf('Error during %s account creation occured: %s<br><b>srv: </b><pre>%s</pre><b>text: </b>%s',
		uc($arg->{service}), $mesg->{html}, $mesg->{srv}, $mesg->{text});
    } else {
      push @{$return->{success}},
	sprintf('<i class="%s fa-fw"></i>&nbsp;<em>%s account login:</em> &laquo;<strong class="text-success">%s</strong>&raquo; <em>password:</em> &laquo;<strong class="text-success mono">%s</strong>&raquo;',
		$ldap_crud->cfg->{authorizedService}->{$arg->{service}}->{icon},
		$arg->{service},
		(split(/=/,(split(/,/,$arg->{dn}))[0]))[1], # taking RDN value
		$arg->{password}->{$arg->{service}}->{'clear'});


      ### !!! RADIUS group modify with new member add if 802.1x
      if ( $arg->{service} eq '802.1x-mac' || $arg->{service} eq '802.1x-eap-tls' &&
	   defined $arg->{radiusgroupname} && $arg->{radiusgroupname} ne '' ) {
	$if_exist = $ldap_crud->search( { base => $arg->{radiusgroupname},
					  scope => 'base',
					  filter => '(' . $arg->{dn} . ')', } );
	if ( ! $if_exist->count ) {
	  $mesg = $ldap_crud->modify( $arg->{radiusgroupname},
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



=head1 AUTHOR

Zeus

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;

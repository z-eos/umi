# -*- mode: cperl -*-
#

package UMI::Controller::UserAll;
use Moose;
use namespace::autoclean;
use Data::Printer;
use Time::Piece;

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
  my ( $self, $c ) = @_;
  my $params = $c->req->parameters;
  # p $self->form->add_svc_acc( defined $params->{add_svc_acc} && $params->{add_svc_acc} ne '' ? $params->{add_svc_acc} : '' );
  
  my $final_message;

  # here we initialize repeatable fields to be rendered when the form is called from
  # another one
  if ( defined $self->form->add_svc_acc &&
       $self->form->add_svc_acc ne '' &&
       ! defined $params->{'account.0.associateddomain'} ) {
    $params->{'account.0.associateddomain'} = '' if ! $params->{'account.0.associateddomain'};
  }
  if ( defined $self->form->add_svc_acc &&
       $self->form->add_svc_acc ne '' &&
       ! defined $params->{'loginless_ovpn.0.associateddomain'} ) {
    $params->{'loginless_ovpn.0.associateddomain'} = '' if ! $params->{'loginless_ovpn.0.associateddomain'};
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
  foreach ( $self->form->field('loginless_ssh')->fields ) {
    $params->{'loginless_ssh.' . $i . '.keyfile'} =
      $c->req->upload('loginless_ssh.' . $i . '.keyfile')
      if defined $params->{'loginless_ssh.' . $i . '.keyfile'} &&
      $params->{'loginless_ssh.' . $i . '.keyfile'} ne '';
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

  if ( keys %{$params} == 1 ) {
  # if ( defined $params->{add_svc_acc} && $params->{add_svc_acc} ne '' ) {
    my $init_obj = { add_svc_acc => $params->{add_svc_acc} };
    return unless $self->form
      ->process( init_object => $init_obj,
		 ldap_crud => $c->model('LDAP_CRUD'), );
  } else {
    # p $params;
    return unless $self->form
      ->process( posted => ($c->req->method eq 'POST'),
		 params => $params,
		 ldap_crud => $c->model('LDAP_CRUD'), );

    $self->form->add_svc_acc( defined $params->{add_svc_acc} && $params->{add_svc_acc} ne '' ? $params->{add_svc_acc} : '' );
    $self->form->dynamic_object( $params->{dynamic_object} );
    $params->{action_searchby} = $c->uri_for_action('searchby/index');
    $c->stash( final_message => $self->create_account( $c->model('LDAP_CRUD'), $params ), );
  }
}

=head2 create_account

=cut

sub create_account {
  my  ( $self, $ldap_crud, $args ) = @_;
  my ( @form_fields,
       $attr_hash,
       $uid,
       $uidNumber,
       $descr,
       $pwd,
       $file,
       $jpeg,
       $objectClass,
       $final_message,
       $success_message,
       $warning_message,
       $error_message );

  my $is_person_exp = defined $args->{person_exp} && $args->{person_exp} ne '' && $args->{person_exp} ne '____.__.__ __:__' ? 1 : 0;
  
  ###################################################################################
  # NEW ACCOUNT, not additional service one
  ###################################################################################
  # NEW/ADDITIONAL acoount start
  if ( defined $self->form->add_svc_acc && $self->form->add_svc_acc eq '' ) {
    @form_fields = defined $args->{person_simplified} &&
      $args->{person_simplified} eq "1" ? qw{ account } : qw{ account loginless_ovpn loginless_ssh groups };
    $uidNumber = $ldap_crud->last_uidNumber + 1;

    $args->{'uid_suffix'} = $self->form->namesake ? $self->form->namesake : '';
    # $args->{'person_givenname'} = $self->utf2lat( $args->{'person_givenname'} )
    #   if $self->is_ascii( $args->{'person_givenname'} );
    # $args->{'person_sn'} =  $self->utf2lat( $args->{'person_sn'} )
    #   if $self->is_ascii( $args->{'person_sn'} );
    $args->{'person_telephonenumber'} = '666'
      if $args->{'person_telephonenumber'} eq '';

    if (defined $args->{'person_description'} && $args->{'person_description'} ne '') {
      $descr = join(' ', $args->{'person_description'});
      # $descr = $self->utf2lat( $descr ) if $self->is_ascii( $descr );
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
    # here we need suffix in addition, if the combination exists
    $uid = sprintf('%s%s',
		   $self->form->autologin,
		   $self->form->namesake );

    my $root_add_dn = sprintf('%s=%s,%s',
			      $ldap_crud->cfg->{rdn}->{acc_root},
			      $ldap_crud->cfg->{rdn}->{acc_root} eq 'uid' ?
			      $uid : sprintf('%s %s',
					     $args->{person_givenname},
					     $args->{person_sn}),
			      $ldap_crud->cfg->{base}->{acc_root});

    # my $schema = $ldap_crud->schema;
    # p my $schemattr = $schema->attribute('gecos');

    $objectClass = $ldap_crud->cfg->{objectClass}->{acc_root};
    push @{$objectClass}, 'dynamicObject' if $is_person_exp;
    
    my $root_add_options =
      [
       uid  => $uid, # $ldap_crud->cfg->{rdn}->{acc_root} => $uid,
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
       gidNumber => $args->{person_gidnumber},
       description => $descr,
       gecos => $self->utf2lat( sprintf('%s %s',
					$args->{person_givenname},
					$args->{person_sn}) ),
       homeDirectory => $ldap_crud->cfg->{stub}->{homeDirectory},
       jpegPhoto => [ $jpeg ],
       loginShell => $ldap_crud->cfg->{stub}->{loginShell},

       title => lc($args->{'person_title'}),

       objectClass => $objectClass,
      ];

    my $ldif = $ldap_crud->add( $root_add_dn, $root_add_options );
    if ( $ldif ) {
      push @{$final_message->{error}},
	sprintf('Error during management account creation occured: %s<br><b>srv: </b><pre>%s</pre><b>text: </b>%s' .
		$ldif->{html},
		$ldif->{srv},
		$ldif->{text});
    } else {
      if ( $is_person_exp ) {
	my $t = localtime;
	my $refresh = $ldap_crud->refresh( $root_add_dn,
					   Time::Piece->strptime( $args->{person_exp}, "%Y.%m.%d %H:%M")->epoch - $t->epoch );
	if ( defined $refresh->{success} ) {
	  push @{$final_message->{success}}, $refresh->{success};
	} elsif ( defined $refresh->{error} ) {
	  push @{$final_message->{error}}, $refresh->{error};
	}
      }
      
      push @{$final_message->{success}},
	sprintf('<i class="fa fa-user fa-lg fa-fw"></i>&nbsp;<em>root account login:</em> <strong class="text-success">%s</strong> <em>password:</em> <strong class="text-success mono">%s</strong>%s',
		$uid,
		$pwd->{root}->{'clear'},
		$self->search_result_item_as_button({ uri => $args->{action_searchby},
						      dn => $root_add_dn,
						      css_btn => 'btn-success',
						      css_frm => 'pull-right' }) ) ;
    }
    # p $final_message->{success};
  } else {
    #####################################################################################
    # ADDITIONAL service account (no root account creation, but using the existent one)
    #####################################################################################

    my $add_to = $ldap_crud->search( { base => $self->form->add_svc_acc, scope => 'base', } );
    $final_message->{error} = 'no root object with DN: <b>&laquo;' .
      $self->form->add_svc_acc . '&raquo;</b> found!' if ! $add_to->count;

    my $add_to_obj = $add_to->entry(0);

    $uidNumber = $add_to_obj->get_value('uidNumber');
    $args->{'person_givenname'} = $add_to_obj->get_value('givenName');
    $args->{'person_sn'} = $add_to_obj->get_value('sn');
    $args->{'person_telephonenumber'} = $add_to_obj->exists('telephonenumber') ?
      $add_to_obj->get_value('telephonenumber') : '666';
    $descr = $add_to_obj->exists('description') ?
      $add_to_obj->get_value('description') : 'description has to be here';

    $uid = $add_to_obj->get_value($ldap_crud->cfg->{rdn}->{acc_root});
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
    $attr_hash = { uid => $uid,
		   authorizedservice => 'mail',
		   associateddomain => $args->{person_associateddomain},
		   objectclass => $args->{dynamic_object} || $is_person_exp ? [ 'dynamicObject' ] : [],
		   requestttl => $is_person_exp ? $args->{person_exp} : '', };
    $branch =
      $ldap_crud
      ->create_account_branch ( $attr_hash );

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
       objectclass => $args->{dynamic_object} || $is_person_exp ? [ 'dynamicObject' ] : [],
       requestttl => $is_person_exp ? $args->{person_exp} : '',
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
      $ldap_crud->create_account_branch_leaf ( $x );
    push @{$final_message->{success}}, @{$leaf->{success}} if defined $leaf->{success};
    push @{$final_message->{warning}}, @{$leaf->{warning}} if defined $leaf->{warning};
    push @{$final_message->{error}}, @{$leaf->{error}} if defined $leaf->{error};

    #---------------------------------------------------------------------
    # Simplified Account xmpp branch of ROOT Object Creation
    #---------------------------------------------------------------------
    $attr_hash = { uid => $uid,
		   authorizedservice => 'xmpp',
		   associateddomain => $args->{person_associateddomain},
		   objectclass => $args->{dynamic_object} || $is_person_exp ? [ 'dynamicObject' ] : [],
		   requestttl => $is_person_exp ? $args->{person_exp} : '', };
    $branch = $ldap_crud->create_account_branch ( $attr_hash );

    push @{$final_message->{success}}, $branch->{success} if defined $branch->{success};
    push @{$final_message->{warning}}, $branch->{warning} if defined $branch->{warning};
    push @{$final_message->{error}}, $branch->{error} if defined $branch->{error};

    #---------------------------------------------------------------------
    # Simplified Leaf of the account email branch of ROOT Object
    #---------------------------------------------------------------------
    $x->{basedn} = $branch->{dn};
    $x->{authorizedservice} = 'xmpp';
    $x->{objectclass} = $args->{dynamic_object} || $is_person_exp ? [ 'dynamicObject' ] : [];
    $x->{requestttl} = $is_person_exp ? $args->{person_exp} : '';

    $leaf = $ldap_crud->create_account_branch_leaf ( $x );
    
    push @{$final_message->{success}}, @{$leaf->{success}} if defined $leaf->{success};
    push @{$final_message->{warning}}, @{$leaf->{warning}} if defined $leaf->{warning};
    push @{$final_message->{error}}, @{$leaf->{error}} if defined $leaf->{error};

      
    #===========================================================================
    # person_simplified checkbox is *not* checked, we continue with GENERAL form
    #===========================================================================
  } else {
    @form_fields = qw{ account loginless_ovpn loginless_ssh groups };
    foreach my $form_field ( @form_fields ) {
      next if $form_field eq 'groups'; # groups we are skiping for now
      foreach $element ( $self->form->field($form_field)->fields ) {

=pod

we skip empty (criteria is a concatenation of each field value) repeatable elements

=cut

	foreach ( $element->fields ) {
	  # p $_->name;
	  # p $_->value;
	  next if $_->name =~ /aux_/ || $_->name eq 'remove';
	  $is_svc_empty .= $_->value if defined $_->value;
	}
	next if $is_svc_empty eq ''; # avoid all empty services

	#---------------------------------------------------------------------
	# Account branch of ROOT Object
	#---------------------------------------------------------------------
	$attr_hash = {
		      $ldap_crud->cfg->{rdn}->{acc_root} => $uid,
		      authorizedservice => $form_field ne 'account'
		      ? substr($form_field, 10) : $element->field('authorizedservice')->value,
		      associateddomain => $element->field('associateddomain')->value,
		      objectclass => ( defined $args->{dynamic_object} && $args->{dynamic_object} eq '1')
		      || ( defined $args->{person_exp} && $args->{person_exp} ne '' ) ? [ 'dynamicObject' ] : [],
		      requestttl => defined $args->{person_exp} && $args->{person_exp} ne '' ? $args->{person_exp} : '',
		     };

	$branch = $ldap_crud->create_account_branch ( $attr_hash );

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
	   gecos => $self->utf2lat( sprintf('%s %s',
					    $args->{person_givenname},
					    $args->{person_sn}) ),
	   givenName => $args->{person_givenname},
	   sn => $args->{person_sn},
	   telephoneNumber => $args->{person_telephonenumber},
	   # jpegPhoto => $jpeg,
	   requestttl => defined $args->{person_exp} && $args->{person_exp} ne '' ? $args->{person_exp} : '',
	  };

	$x->{description} =
	  defined $element->field('description') ? $element->field('description')->value : '';

	$x->{objectclass} = ( defined $args->{dynamic_object} && $args->{dynamic_object} eq '1')
	  || ( defined $args->{person_exp} && $args->{person_exp} ne '' ) ? [ 'dynamicObject' ] : [];

	if ( $form_field eq 'account' ) {
	  if ( $element->field('authorizedservice')->value =~ /^802.1x-.*/ ) {
	    if ( $element->field('authorizedservice')->value eq '802.1x-mac' ) {
	      $x->{password} = { $element->field('authorizedservice')->value =>
				 { clear => $self->macnorm({ mac => $element->field('login')->value }) }
			       };
	    } elsif ( $element->field('authorizedservice')->value eq '802.1x-eap-tls' ) {
	      $x->{password} = { $element->field('authorizedservice')->value =>
				 { clear =>
				   sprintf('%s%s',
					   defined $ldap_crud->cfg->{authorizedService}
					   ->{$element->field('authorizedservice')->value}
					   ->{login_prefix} ?
					   $ldap_crud->cfg->{authorizedService}->{$element->field('authorizedservice')->value}
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
	  $x->{sshpublickeyfile} = $element->field('keyfile')->value;
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
	  $ldap_crud->create_account_branch_leaf ( $x );
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





=head1 AUTHOR

Zeus

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;

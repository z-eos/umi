# -*- cperl -*-
#

package UMI::Controller::SearchBy;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; with 'Tools'; }

use UMI::Form::ModPwd;
has 'form_mod_pwd' => ( isa => 'UMI::Form::ModPwd', is => 'rw',
			lazy => 1, default => sub { UMI::Form::ModPwd->new },
			documentation => q{Form to modify userPassword},
		      );

use UMI::Form::ModJpegPhoto;
has 'form_jpegphoto' => ( isa => 'UMI::Form::ModJpegPhoto', is => 'rw',
		      lazy => 1, default => sub { UMI::Form::ModJpegPhoto->new },
		      documentation => q{Form to add/modify jpegPhoto},
		    );

use UMI::Form::ModUserGroup;
has 'form_mod_groups' => ( isa => 'UMI::Form::ModUserGroup', is => 'rw',
		      lazy => 1, default => sub { UMI::Form::ModUserGroup->new },
		      documentation => q{Form to add/modify group/s of the user.},
		    );

use UMI::Form::AddServiceAccount;
has 'form_add_svc_acc' => ( isa => 'UMI::Form::AddServiceAccount', is => 'rw',
			    lazy => 1, default => sub { UMI::Form::AddServiceAccount->new },
			    documentation => q{Form to add service account},
			  );


=head1 NAME

UMI::Controller::SearchBy - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


######################################################################


=head2 index

=cut

sub index :Path :Args(0) {
  my ( $self, $c ) = @_;

  if ( defined $c->session->{"auth_uid"} ) {
    my ( $params, $ldap_crud, $filter, $filter_meta, $filter_show, $base );

    $params = $c->req->params;

    $ldap_crud =
      $c->model('LDAP_CRUD');

    $filter_meta = $params->{'ldapsearch_filter'} ne '' ? $params->{'ldapsearch_filter'} : '*';

    if ( defined $params->{'ldapsearch_by_email'} ) {
      $filter = sprintf("mail=%s", $filter_meta);
      $filter_show = sprintf("mail=<kbd>%s</kbd>", $filter_meta);
      $base = $ldap_crud->{cfg}->{base}->{acc_root};
      $params->{'ldapsearch_base'} = $base;
    } elsif ( defined $params->{'ldapsearch_by_name'} ) {
      $filter = sprintf("|(givenName=%s)(sn=%s)(uid=%s)",
			$filter_meta, $filter_meta, $filter_meta);
      $filter_show = sprintf("|(givenName=<kbd>%s</kbd>)(sn=<kbd>%s</kbd>)(uid=<kbd>%s</kbd>)",
			     $filter_meta, $filter_meta, $filter_meta);
      $base = $ldap_crud->{cfg}->{base}->{acc_root};
      $params->{'ldapsearch_base'} = $base;
    } elsif ( defined $params->{'ldapsearch_by_telephone'} ) {
      $filter = sprintf("|(telephoneNumber=%s)(mobile=%s)(homePhone=%s)",
			$filter_meta, $filter_meta, $filter_meta);
      $filter_show = sprintf("|(telephoneNumber=<kbd>%s</kbd>)(mobile=<kbd>%s</kbd>)(homePhone=<kbd>%s</kbd>)",
			     $filter_meta, $filter_meta, $filter_meta);
      $base = $ldap_crud->{cfg}->{base}->{acc_root};
      $params->{'ldapsearch_base'} = $base;
    } elsif ( defined $params->{'ldapsearch_filter'} &&
	      $params->{'ldapsearch_filter'} ne '' ) {
      $filter = $params->{'ldapsearch_filter'};
      $base = $params->{'ldapsearch_base'};
    } else {
      $filter = 'objectClass=*';
      $filter_show = $filter;
      $base = $params->{'ldapsearch_base'};
    }

    $params->{'filter'} = '(' . $filter_show . ')';
    my $mesg = $ldap_crud->search(
				  {
				   base => $base,
				   filter => '(' . $filter . ')',
				   sizelimit => 50,
				  }
				 );

    my @entries = $mesg->entries;

    my $err_message = '';
    my $info_message = '';
    if ( ! $mesg->is_error && ! $mesg->count ) {
      $info_message = '<div class="alert alert-warning">' .
	'<span style="font-size: 140%" class="glyphicon glyphicon-warning-sign"></span>&nbsp;Nothing was found by your request, we encourage you to inspect your search parameter/s</div>';
    } elsif ( $mesg->is_error ) {
      $err_message = '<div class="alert alert-danger">' .
	'<span style="font-size: 140%" class="icon_error-oct" aria-hidden="true"></span><ul>' .
	  $ldap_crud->err($mesg) . '</ul></div>';
    }

    use Data::Printer;
    my ( $ttentries, $attr );
    foreach (@entries) {
      $ttentries->{$_->dn}->{'mgmnt'} =
	{
	 is_dn => scalar split(',', $_->dn) <= 3 ? 1 : 0,
	 is_account => $_->dn =~ /.*,$ldap_crud->{cfg}->{base}->{acc_root}/ ? 1 : 0,
	 jpegPhoto => $_->dn =~ /.*,$ldap_crud->{cfg}->{base}->{acc_root}/ ? 1 : 0,
	 gitAclProject => $_->exists('gitAclProject') ? 1 : 0,
	 userPassword => $_->exists('userPassword') ? 1 : 0,
	};
      foreach $attr (sort $_->attributes) {
	$ttentries->{$_->dn}->{attrs}->{$attr} = $_->get_value( $attr, asref => 1 );
	if ( $attr eq 'jpegPhoto' ) {
	  use MIME::Base64;
	  $ttentries->{$_->dn}->{attrs}->{$attr} =
	    sprintf('img-thumbnail" alt="jpegPhoto of %s" src="data:image/jpg;base64,%s" title="%s" />',
		    $_->dn,
		    encode_base64(join('',@{$ttentries->{$_->dn}->{attrs}->{$attr}})),
		    $_->dn);
	} elsif (ref $ttentries->{$_->dn}->{attrs}->{$attr} eq 'ARRAY') {
	  $ttentries->{$_->dn}->{is_arr}->{$attr} = 1;
	}
      }
    }
    # p $ttentries;
    $c->stash(
	      template => 'search/searchby.tt',
	      base_dn => $base,
	      filter => $filter_show,
	      entries => $ttentries,
	      # entries => \@entries,
	      err => $err_message,
	      info => $info_message,
	     );
  } else {
    $c->stash( template => 'signin.tt', );
  }
}


######################################################################
# SearchBy main processing logics
######################################################################


=head1 proc

SearchBy main processing logics

=cut


sub proc :Path(proc) :Args(0) {
  my ( $self, $c ) = @_;

  use Data::Printer use_prototypes => 0;

  if ( defined $c->session->{"auth_uid"} ) {
    my $params = $c->req->parameters;

#=====================================================================
# LDIF generation
#=====================================================================
    if (defined $params->{'ldap_ldif'} &&
      	$params->{'ldap_ldif'} ne '') {
	$self->ldif(
		    $c,
		    {
		     ldif_dn => $params->{'ldap_ldif'},
		     recursive => defined $params->{'ldap_ldif_recursive'} ?
		                          $params->{'ldap_ldif_recursive'} : undef,
		     sysinfo => defined $params->{'ldap_ldif_sysinfo'} ?
		                        $params->{'ldap_ldif_sysinfo'} : undef,
		    }
		   );

#=====================================================================
# Delete
#=====================================================================
    } elsif (defined $params->{'ldap_delete'} &&
	     $params->{'ldap_delete'} ne '') {
      my $err;
      if ( defined $params->{'ldap_delete_recursive'} &&
	   $params->{'ldap_delete_recursive'} eq 'on' ) {
		$err = $c->model('LDAP_CRUD')->delr($params->{ldap_delete});
      } else {
		$err = $c->model('LDAP_CRUD')->del($params->{ldap_delete});
      }

      $c->stash(
		template => 'search/delete.tt',
		delete => $params->{'ldap_delete'},
		recursive => defined $params->{'ldap_delete_recursive'} &&
		$params->{'ldap_delete_recursive'} eq 'on' ? '1' : '0',
		err => $err,
	       );

#=====================================================================
# Modify (all fields form)
#=====================================================================
    } elsif (defined $params->{'ldap_modify'} &&
	     $params->{'ldap_modify'} ne '') {
      my $ldap_crud =
	$c->model('LDAP_CRUD');
      my $mesg = $ldap_crud->search( { dn => $params->{ldap_modify} } );
      my $schema = $ldap_crud->obj_schema( { dn => $params->{ldap_modify} } );
      my $err_message = '';
      if ( ! $mesg->count ) {
	$err_message = '<div class="alert alert-danger">' .
	  '<span style="font-size: 140%" class="icon_error-oct" aria-hidden="true"></span><ul>' .
	    $ldap_crud->err($mesg) . '</ul></div>';
      }

      my ($is_single, $attr);
      foreach my $objectClass (sort (keys $schema->{"$params->{'ldap_modify'}"})) {
	foreach $attr (sort (keys %{$schema->{"$params->{'ldap_modify'}"}->{$objectClass}->{'must'}} )) {
	  next if $attr eq "objectClass";
	  $is_single->{$attr} =
	    $schema->{$params->{'ldap_modify'}}->{$objectClass}->{'must'}->{$attr}->{'single-value'};
	}
	foreach $attr (sort (keys %{$schema->{"$params->{'ldap_modify'}"}->{$objectClass}->{'may'}} )) {
	  next if $attr eq "objectClass";
	  $is_single->{$attr} =
	    $schema->{$params->{'ldap_modify'}}->{$objectClass}->{'may'}->{$attr}->{'single-value'};
	}
      }

      p $mesg->entry(0);
      ## here we work with the only one, single entry!!
      $c->session->{modify_entries} = $mesg->entry(0);
      $c->session->{modify_dn} = $params->{ldap_modify};
      $c->session->{modify_schema} = $is_single;

      $c->stash(
		template => 'search/modify.tt',
		modify => $params->{'ldap_modify'},
		# entries => \@entries,
		## entries => $c->session->{modify_entries},
		entries => $mesg->entry(0),
		schema => $c->session->{modify_schema},
		err => $err_message,
		rdn => $ldap_crud->{cfg}->{rdn}->{acc},
	       );

#=====================================================================
# Modify Groups
#=====================================================================
    } elsif ( defined $params->{'ldap_modify_group'} &&
	      $params->{'ldap_modify_group'} ne '') {

      $c->stash(
		template => 'user/user_mod_group.tt',
		form => $self->form_mod_groups,
		ldap_modify_group => $params->{'ldap_modify_group'},
	       );
      p $params;
      return unless $self->form_mod_groups
      	->process(
      		  posted => ($c->req->method eq 'POST'),
      		  params => $params,
      		  ldap_crud => $c->model('LDAP_CRUD'),
      		 ) && defined $params->{groups};

      $c->stash( final_message => $self
		 ->mod_groups(
			      $c->model('LDAP_CRUD'),
			      {
			       mod_groups_dn => $params->{ldap_modify_group},
			       groups => $params->{groups},
			      }
			     ),
	       );

#=====================================================================
# Modify userPassword
#=====================================================================
    } elsif (defined $params->{'ldap_modify_password'} &&
	     $params->{'ldap_modify_password'} ne '') {

      $c->stash(
		template => 'user/user_modpwd.tt',
		form => $self->form_mod_pwd,
		ldap_modify_password => $params->{ldap_modify_password},
	       );

      return unless $self->form_mod_pwd->process(
						 posted => ($c->req->method eq 'POST'),
						 params => $params,
						) &&
						  ( defined $params->{password_init} ||
						    defined $params->{password_cnfm} );

      $c->stash(
		final_message => $self->mod_pwd(
						$c->model('LDAP_CRUD'),
						{
						 mod_pwd_dn => $params->{ldap_modify_password},
						 password_init => $params->{password_init},
						 password_cnfm => $params->{password_cnfm},
						}),
	       ) if $self->form_mod_pwd->ran_validation;

#=====================================================================
# Modify jpegPhoto
#=====================================================================
    } elsif ( defined $params->{'ldap_modify_jpegphoto'} &&
	      $params->{'ldap_modify_jpegphoto'} ne '') {
      # p $params;
      $params->{avatar} = $c->req->upload('avatar') if defined $params->{avatar};
      # p $params;

      $c->stash(
		template => 'user/user_modjpegphoto.tt',
		form => $self->form_jpegphoto,
		ldap_modify_jpegphoto => $params->{'ldap_modify_jpegphoto'},
	       );

      return unless $self->form_jpegphoto->process(
						   posted => ($c->req->method eq 'POST'),
						   params => $params,
						  ) && defined $params->{avatar} && $params->{avatar} ne '';

      my $ldap_crud = $c->model('LDAP_CRUD');

      $c->stash( final_message => $self
		 ->mod_jpegPhoto(
				 $ldap_crud,
				 {
				  mod_jpegPhoto_dn => $params->{ldap_modify_jpegphoto},
				  jpegPhoto => $params->{avatar},
				  jpegPhoto_stub => $c
				  ->path_to('root',
					    'static',
					    'images',
					    $ldap_crud->{cfg}->{jpegPhoto}->{stub}),
				 }
				),
	       );

#=====================================================================
# Add Service Account
#=====================================================================
    } elsif ( defined $params->{'add_svc_acc'} &&
	      $params->{'add_svc_acc'} ne '') {

      my $ldap_crud = $c->model('LDAP_CRUD');
      my ( $arr, $login, $uid, $pwd, $error_message, $success_message, $warn_message );
      my @id = split(',', $params->{'add_svc_acc'});
      $params->{'add_svc_acc_uid'} = substr($id[0], 21); # $params->{'login'} =
      $c->stash(
		template => 'user/user_add_svc.tt',
		form => $self->form_add_svc_acc,
		add_svc_acc => $params->{'add_svc_acc'},
		add_svc_acc_uid => $params->{'add_svc_acc_uid'},
	       );

      return unless $self->form_add_svc_acc->process(
						     posted => ($c->req->method eq 'POST'),
						     params => $params,
						     ldap_crud => $ldap_crud,
						    ) &&
						      defined $params->{'associateddomain'} &&
							defined $params->{'authorizedservice'};

      if ( $self->form_add_svc_acc->validated ) {
	if ( $params->{login} ne '' ) {
	  $login = $params->{login};
	} else {
	  $login = $params->{'add_svc_acc_uid'};
	}

	if ( ref( $params->{'authorizedservice'} ) eq 'ARRAY' ) {
	  $arr = $params->{'authorizedservice'};
	} else {
	  $arr->[0] = $params->{'authorizedservice'};
	}

	my ($create_account_branch_return, $create_account_branch_leaf_return, $create_account_branch_leaf_params );
	foreach ( @{$arr} ) {
	  next if ! $_;

	  $uid = $_ =~ /^802.1x-/ ? $login : sprintf('%s@%s', $login, $params->{'associateddomain'});

	  if ( ! defined $params->{'password1'} or $params->{'password1'} eq '' ) {
	    $pwd = { $_ => $self->pwdgen };
	  # } elsif ( $_ =~ /^802.1x-.*/ ) {
	  #   $pwd->{service}->{clear} = $params->{login};
	  } else {
	    $pwd = { $_ => $self->pwdgen( { pwd => $params->{'password1'} } ) };
	  }

	  # $success_message .= sprintf('<tr class=mono><td>%s@%s</td><td>%s</td><td>%s</td></tr>',
	  # 			      $_,
	  # 			      $params->{'associateddomain'},
	  # 			      $uid,
	  # 			      $pwd->{$_}->{clear});

	  push @{$success_message}, {
				     authorizedservice => $_,
				     associateddomain => $params->{'associateddomain'},
				     service_uid => $uid,
				     service_pwd => $pwd->{$_}->{clear},
				    };

	  $create_account_branch_return =
	    $c->controller('User')
	      ->create_account_branch ( $ldap_crud,
					{
					 base_uid => substr($id[0], 4),
					 service => $_,
					 associatedDomain => $params->{associateddomain},
					},
				      );

	  # $success_message .= $create_account_branch_return->[1] if defined $create_account_branch_return->[1];
	  $error_message .= $create_account_branch_return->[0] if defined $create_account_branch_return->[0];
	  $warn_message .= $create_account_branch_return->[2] if defined $create_account_branch_return->[2];

	  # takingdata to be used in create_account_branch_leaf()
	  my $mesg = $ldap_crud->search( { base => $params->{'add_svc_acc'},
					   scope => 'base',
					   attrs => [ 'uidNumber', 'givenName', 'sn' ],
					 } );
	  if ( ! $mesg->count ) {
	    $error_message .= $ldap_crud->err($mesg);
	  }

	  my @entry = $mesg->entries;

	  my ($file, $jpeg);
	  if (defined $params->{'avatar'}) {
	    $params->{avatar} = $c->req->upload('avatar');
	    $file = $params->{'avatar'}->{'tempname'};
	  } else {
	    $file = undef;
	  }

	  $create_account_branch_leaf_params
	    = {
	       basedn => $params->{'add_svc_acc'},
	       service => $_,
	       associatedDomain => $params->{associateddomain},
	       uidNumber => $entry[0]->get_value('uidNumber'),
	       givenName => $entry[0]->get_value('givenName'),
	       sn => $entry[0]->get_value('sn'),
	       login => $login,
	       password => $pwd->{$_},
	       telephoneNumber => defined $params->{telephoneNumber} ? $params->{telephoneNumber} : undef,
	       jpegPhoto => $file,
	      };
	  p $create_account_branch_leaf_params;
	  $create_account_branch_leaf_return =
	    $c->controller('User')
	      ->create_account_branch_leaf (
					    $ldap_crud,
					    $create_account_branch_leaf_params,
					   );

	  # $success_message .= $create_account_branch_leaf_return->[1] if defined $create_account_branch_leaf_return->[1];
	  $error_message .= $create_account_branch_leaf_return->[0] if defined $create_account_branch_leaf_return->[0];

	}
      } else { # form was not validated
	$error_message = '<em>service was not added</em>' .
	  $error_message if $error_message;
      }

      $c->stash(
		message_success => $success_message,
		message_warning => $warn_message,
		message_error => $error_message,
	       );
    }
  } else {
    $c->stash( template => 'signin.tt', );
  }
}


#=====================================================================

=head1 mod_jpegPhoto

modify jpegPhoto method

=cut


sub mod_jpegPhoto {
  my ( $self, $ldap_crud, $args ) = @_;

  my $arg = {
	     mod_jpegPhoto_dn => $args->{mod_jpegPhoto_dn},
	     jpegPhoto => $args->{jpegPhoto},
	     jpegPhoto_stub => $args->{jpegPhoto_stub},
	    };

  my ($file, $jpeg);
  if (defined $arg->{jpegPhoto}) {
    $file = $arg->{jpegPhoto}->{'tempname'};
  } else {
    $file = $arg->{jpegPhoto_stub};
  }
  local $/ = undef;
  open(my $fh, "<", $file) or p $!;
  $jpeg = <$fh>;
  close($fh);

  my ( $error_message, $success_message, $final_message );
  if ( defined $arg->{jpegPhoto} ) {
    my $mesg = $ldap_crud->mod(
			       $arg->{mod_jpegPhoto_dn},
			       { 'jpegPhoto' => [ $jpeg ], }
			      );

    if ( $mesg ne '0' ) {
      $error_message = '<li>Error during jpegPhoto add/change occured: ' . $mesg . '</li>';
    } else {
      $success_message .= $arg->{jpegPhoto}->{'filename'} .
	'</kbd> of type ' . $arg->{jpegPhoto}->{'type'} . ' and ' .
	  $arg->{jpegPhoto}->{'size'} . ' bytes size.';
    }
  }
  if ( $self->form_jpegphoto->validated ) {
    $final_message = '<div class="alert alert-success" role="alert">' .
      '<span style="font-size: 140%" class="glyphicon glyphicon-ok-sign">&nbsp;</span>' .
	'<em>jpegPhoto attribute is added/changed from file: </em>&nbsp;' .
	  '<kbd style="font-size: 110%; font-family: monospace;">' .
	    $success_message . '</div>' if $success_message;
  }

  $final_message .= '<div class="alert alert-danger" role="alert">' .
    '<span style="font-size: 140%" class="icon_error-oct" aria-hidden="true"></span><ul>' .
      $error_message . '</ul></div>' if $error_message;

  return $final_message;
}


#=====================================================================

=head1 mod_pwd 

modify password method

=cut


sub mod_pwd {
  my ( $self, $ldap_crud, $args ) = @_;

  my $arg = {
	     mod_pwd_dn => $args->{mod_pwd_dn},
	     password_init => $args->{password_init},
	     password_cnfm => $args->{password_cnfm},
	    };

  my ( $error_message, $success_message, $final_message );
  if ( $self->form_mod_pwd->validated && $self->form_mod_pwd->ran_validation ) {

    if ( $arg->{'password_init'} eq '' && $arg->{'password_cnfm'} eq '' ) {
      $arg->{password_gen} = $self->pwdgen;
    } elsif ( $arg->{'password_init'} ne '' && $arg->{'password_cnfm'} ne '' ) {
      $arg->{password_gen} = $self->pwdgen({ pwd => $arg->{'password_cnfm'} });
    }
    my $mesg = $ldap_crud->mod(
			       $arg->{mod_pwd_dn},
			       {
				'userPassword' => $arg->{password_gen}->{ssha}, },
			      );

    if ( $mesg ne '0' ) {
      $error_message = '<li>Error during password change occured: ' . $mesg . '</li>';
    } else {
      $success_message .= $arg->{password_gen}->{'clear'};
    }

    $final_message = '<div class="alert alert-success" role="alert">' .
      '<span style="font-size: 140%" class="glyphicon glyphicon-ok-sign">&nbsp;</span>' .
	'<em>Password is changed and is:</em>&nbsp;' .
	  '<kbd style="font-size: 150%; font-family: monospace;">' .
	    $success_message . '</kbd></div>' if $success_message;
  }

  $final_message .= '<div class="alert alert-danger" role="alert">' .
    '<span style="font-size: 140%" class="icon_error-oct" aria-hidden="true"></span><ul>' .
      $error_message . '</ul></div>' if $error_message;

  return $final_message;
}


#=====================================================================

=head1 mod_groups

modify user's groups method

=cut


sub mod_groups {
  my ( $self, $ldap_crud, $args ) = @_;

  my $arg = {
	     mod_groups_dn => $args->{mod_groups_dn},
	     groups => $args->{groups},
	     uid => substr( (split /,/, $args->{mod_groups_dn})[0], 4 ),
	    };

  # push @{$arg->{groups}}, $args->{groups};

  my $return;
  if ( $self->form_mod_groups->validated && $self->form_mod_groups->ran_validation ) {
    my $mesg = $ldap_crud->search( { base => 'ou=group,dc=umidb',
				     scope => 'one',
				     attrs => ['cn'], } );

    if ( ! $mesg->count ) {
      push @{$return->{error}}, $ldap_crud->err($mesg);
    }

    my @groups_all = $mesg->sorted('cn');

    foreach ( @groups_all ) {
      $arg->{groups_mod}->{$_->get_value('cn')} = 0;
    }

    $mesg = $ldap_crud->search( { base => 'ou=group,dc=umidb',
				  filter => 'memberUid=' . $arg->{uid},
				  attrs => ['cn'], } );

    if ( ! $mesg->count ) {
      push @{$return->{error}}, $ldap_crud->err($mesg);
    }

    my @groups_usr = $mesg->sorted('cn');

    foreach ( @groups_usr ) {
      $arg->{groups_mod}->{$_->get_value('cn')}++;
    }

    foreach (@{$arg->{groups}}) {
      $arg->{groups_mod}->{$_}++;
    }

    # $mesg = $ldap_crud->mod(
    # 			    $arg->{mod_groups_dn},
    # 			    { 'memberUid' => $arg->{groups}, },
    # 			   );

    # if ( $mesg ne '0' ) {
    #   $return->{error} = $mesg;
    # } else {
    #   $return->{success} = $arg->{groups};
    # }
  }
p $arg;
  return $return;
}

#=====================================================================

=head1 ldif

get LDIF, recursive or not, for the DN given

=cut


sub ldif {
  my ( $self, $c, $args ) = @_;
  my $arg = {
	     ldif_dn => $args->{ldif_dn},
	     recursive => $args->{recursive} eq 'on' ? 1 : 0,
	     sysinfo => $args->{sysinfo} eq 'on' ? 1 : 0,
	    };
  $c->stash(
	    template => 'search/ldif.tt',
	    ldif => $c->model('LDAP_CRUD')->ldif(
						 $arg->{ldif_dn},
						 $arg->{recursive},
						 $arg->{sysinfo}
						),
	  );
}

sub ldif_gen :Path(ldif_gen) :Args(0) {
  my ( $self, $c ) = @_;
  my $ldap_crud =
    $c->model('LDAP_CRUD');
  my $params = $c->req->parameters;
  use Data::Printer;
  p $params;
  $c->stash(
	    template => 'search/ldif.tt',
	    ldif => $c->model('LDAP_CRUD')
	    ->ldif(
		   $params->{ldap_ldif},
		   defined $params->{ldap_ldif_recursive}
		   && $params->{ldap_ldif_recursive} ne '' ? 1 : 0,
		   defined $params->{ldap_ldif_sysinfo}
		   && $params->{ldap_ldif_sysinfo} ne '' ? 1 : 0
		  ),
	  );
}


#=====================================================================

=head1 modify

modify whole form (all present fields except RDN)

=cut


sub modify :Path(modify) :Args(0) {
  my ( $self, $c ) = @_;
  use Data::Printer;

  my $ldap_crud =
    $c->model('LDAP_CRUD');
  my $params = $c->req->parameters;
  # p $params;

  my ($attr, $val, $mod, $orig);
  foreach $attr ( sort ( keys %{$params} )) {
    next if ( $attr =~ /$ldap_crud->{cfg}->{exclude_prefix}/ ||
	      $attr =~ /userPassword/ );
    if ( $attr eq "jpegPhoto" ) {
      $params->{jpegPhoto} = $c->req->upload('jpegPhoto');
    }

    $val = $c->session->{modify_entries}->get_value ( $attr, asref => 1  );

    $orig = ref($val) eq "ARRAY" && scalar @{$val} == 1 ? $val->[0] : $val;
    $val = $params->{$attr};
    # removing all empty array elements if any
    if ( ref($val) eq "ARRAY" ) {
      @{$val} = grep { $_ ne '' } @{$val};
    }

    # SMARTMATCH: recurse on paired elements of ARRAY1 and ARRAY2
    # if identical then next
    next if $val ~~ $orig;

    if ( $attr eq 'jpegPhoto' && $val ne "" ) {
      my ($file, $jpeg);
      $file = $val->{'tempname'};
      local $/ = undef;
      open(my $fh, "<", $file) or $c->log->debug("Can not open $file: $!" );
      $jpeg = <$fh>;
      close($fh) or $c->log->debug($!);
      $mod->{$attr} = [ $jpeg ];
    } elsif ( $val ne "" or $val ne "0" ) { # && $val ne $orig ) {
      $mod->{$attr} = $val;
    }
  }
  p $mod;
  my $mesg = $ldap_crud->mod( $c->session->{modify_dn},
			      $mod );

  my $err_message;
  if ( $mesg ne "0" ) {
    $err_message = '<div class="alert alert-danger">' .
      '<span style="font-size: 140%" class="icon_error-oct" aria-hidden="true"></span><ul>' .
	$mesg . '</ul></div>';
  }

  # p $ldap_crud->{cfg}->{rdn}->{acc};

  $c->stash(
	    template => 'stub.tt',
	    params => $params,
	    err => $err_message,
	    rdn => $ldap_crud->{cfg}->{rdn}->{acc},
	   );
}


=head1 AUTHOR

Zeus Panchenko

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;

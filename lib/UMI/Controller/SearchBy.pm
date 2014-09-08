# -*- cperl -*-
#

package UMI::Controller::SearchBy;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; with 'Tools'; }

=head1 NAME

UMI::Controller::SearchBy - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 index

=cut

sub index :Path :Args(0) {
  my ( $self, $c ) = @_;

  if ( defined $c->session->{"auth_uid"} ) {
    my ( $params, $filter, $filter_meta, $filter_show, $base );

    $params = $c->req->params;
    $filter_meta = $params->{'ldapsearch_filter'} ne '' ? $params->{'ldapsearch_filter'} : '*';

    if ( defined $params->{'ldapsearch_by_email'} ) {
      $filter = sprintf("mail=%s", $filter_meta);
      $filter_show = sprintf("mail=<kbd>%s</kbd>", $filter_meta);
      $base = 'ou=People,dc=umidb';
      $params->{'ldapsearch_base'} = $base;
    } elsif ( defined $params->{'ldapsearch_by_name'} ) {
      $filter = sprintf("|(givenName=%s)(sn=%s)(uid=%s)",
			$filter_meta, $filter_meta, $filter_meta);
      $filter_show = sprintf("|(givenName=<kbd>%s</kbd>)(sn=<kbd>%s</kbd>)(uid=<kbd>%s</kbd>)",
			     $filter_meta, $filter_meta, $filter_meta);
      $base = 'ou=People,dc=umidb';
      $params->{'ldapsearch_base'} = $base;
    } elsif ( defined $params->{'ldapsearch_by_telephone'} ) {
      $filter = sprintf("|(telephoneNumber=%s)(mobile=%s)(homePhone=%s)",
			$filter_meta, $filter_meta, $filter_meta);
      $filter_show = sprintf("|(telephoneNumber=<kbd>%s</kbd>)(mobile=<kbd>%s</kbd>)(homePhone=<kbd>%s</kbd>)",
			     $filter_meta, $filter_meta, $filter_meta);
      $base = 'ou=People,dc=umidb';
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

    my $ldap_crud =
      $c->model('LDAP_CRUD');

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
    if ( ! $mesg->is_error &&
	 ! $mesg->count ) {
      $info_message = '<div class="alert alert-warning">' .
	'<span style="font-size: 140%" class="glyphicon glyphicon-warning-sign"></span>&nbsp;Nothing was found by your request, we encourage you to inspect your search parameter/s</div>';
    } elsif ( $mesg->is_error ) {
      $err_message = '<div class="alert alert-danger">' .
	'<span style="font-size: 140%" class="icon_error-oct" aria-hidden="true"></span><ul>' .
	  $ldap_crud->err($mesg) . '</ul></div>';
    }

    $c->stash(
	      template => 'search/searchby.tt',
	      params => $c->req->params,
	      entries => \@entries,
	      err => $err_message,
	      info => $info_message,
	     );
  } else {
    $c->stash( template => 'signin.tt', );
  }
}

sub proc :Path(proc) :Args(0) {
  my ( $self, $c, $searchby_id ) = @_;

  use Data::Printer;

  if ( defined $c->session->{"auth_uid"} ) {
    my $params = $c->req->parameters;

    if (defined $params->{'ldap_ldif'} &&
	$params->{'ldap_ldif'} ne '') {
      my $recursive = defined $params->{'ldap_ldif_recursive'} &&
	$params->{'ldap_ldif_recursive'} eq 'on' ? 1 : 0;

      $c->stash(
		template => 'search/ldif.tt',
		ldif => $c->model('LDAP_CRUD')->ldif($params->{ldap_ldif}, $recursive),
	       );
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
		recursive => defined $params->{'ldap_delete_recursive'} && $params->{'ldap_delete_recursive'} eq 'on' ? '1' : '0',
		err => $err,
	       );
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

      use Data::Printer;
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

      ## here we work with the only one, single entry!!
      # $c->session->{modify_entries} = $mesg->entry(0);
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
    } elsif (defined $params->{'ldap_modify_password'} &&
	     $params->{'ldap_modify_password'} ne '') {

      use UMI::Form::ModPwd;
      has 'form' => ( isa => 'UMI::Form::ModPwd', is => 'rw',
		      lazy => 1, default => sub { UMI::Form::ModPwd->new },
		      documentation => q{Form to modify password},
		    );

      if ( defined $params->{'password_init'} &&
	   defined $params->{'password_cnfm'} &&
	   $params->{'password_init'} eq '' &&
	   $params->{'password_cnfm'} eq '' ) {
	$params->{password_gen} = $self->pwdgen;
      } elsif ( defined $params->{'password_init'} &&
		defined $params->{'password_cnfm'} &&
		$params->{'password_init'} ne '' &&
		$params->{'password_cnfm'} ne '' ) {
	$params->{password_gen} = $self->pwdgen( { pwd => $params->{'password_init'} } );
      }

      my ( $error_message, $success_message, $final_message );
      if ( defined $params->{password_gen} ) {
	my $ldap_crud =
	  $c->model('LDAP_CRUD');
	my $mesg = $ldap_crud->mod( $params->{ldap_modify_password},
				    {
				     'userPassword' => $params->{password_gen}->{ssha}, }
				  );

	if ( $mesg ne '0' ) {
	  $error_message = '<li>Error during password change occured: ' . $mesg . '</li>';
	} else {
	  $success_message .= $params->{password_gen}->{'clear'};
	}
      }
      p $params;
      p $self->form->validated;
      if ( $self->form->validated ) {
	$final_message = '<div class="alert alert-success" role="alert">' .
	  '<span style="font-size: 140%" class="glyphicon glyphicon-ok-sign">&nbsp;</span>' .
	    '<em>Password is changed and is:</em>&nbsp;' .
	      '<kbd style="font-size: 150%; font-family: monospace;">' .
		$success_message . '</kbd></div>' if $success_message;
      } else {
	$final_message = '<div class="alert alert-warning" role="alert">' .
	  '<span style="font-size: 140%" class="glyphicon glyphicon-warning-sign">&nbsp;</span>' .
	    '<em>Password was not changed, it was:</em>&nbsp;' .
	      '<kbd style="font-size: 150%; font-family: monospace;">' .
		$success_message . '</kbd></div>' if $success_message;
      }

      $final_message .= '<div class="alert alert-danger" role="alert">' .
	'<span style="font-size: 140%" class="icon_error-oct" aria-hidden="true"></span><ul>' .
	  $error_message . '</ul></div>' if $error_message;

      # $self->form->info_message( $final_message ) if $final_message && defined $params->{password_gen}->{clear};
      p $final_message;

      $c->stash(
		template => 'user/user_modpwd.tt',
		form => $self->form,
		final_message => $final_message,
		ldap_modify_password => $params->{'ldap_modify_password'},
	       );

      # Validate and insert/update database
      return unless $self->form->process( # item_id => $searchby_id,
					 posted => ($c->req->method eq 'POST'),
					 params => $params,
					);

    } elsif ( defined $params->{'ldap_modify_jpegphoto'} &&
	      $params->{'ldap_modify_jpegphoto'} ne '') {

      use UMI::Form::ModJpegPhoto;
      has 'form_jpegphoto' => ( isa => 'UMI::Form::ModJpegPhoto', is => 'rw',
		      lazy => 1, default => sub { UMI::Form::ModJpegPhoto->new },
		      documentation => q{Form to add/modify jpegPhoto},
		    );
      $params->{'avatar'} = $c->req->upload('avatar') if defined $params->{'avatar'};
      use Data::Printer;
      p $params;
      my ($file, $jpeg);
      if (defined $params->{'avatar'}) {
	$file = $params->{'avatar'}->{'tempname'};
      } else {
	$file = $c->path_to('root','static','images','user-6-128x128.jpg');
      }
      local $/ = undef;
      open(my $fh, "<", $file) or $c->log->debug("Can not open $file: $!" );
      $jpeg = <$fh>;
      close($fh) or $c->log->debug($!);

      my ( $error_message, $success_message, $final_message );
      if ( defined $params->{'avatar'} ) {
	my $ldap_crud =
	  $c->model('LDAP_CRUD');
	my $mesg = $ldap_crud->mod( $params->{ldap_modify_jpegphoto},
				    {
				     'jpegPhoto' => [ $jpeg ],
				    }
				  );

	if ( $mesg ne '0' ) {
	  $error_message = '<li>Error during jpegPhoto add/change occured: ' . $mesg . '</li>';
	} else {
	  $success_message .= $params->{'avatar'}->{'filename'} .
	    '</kbd> of type ' . $params->{'avatar'}->{'type'};
	}
      }
      if ( $self->form_jpegphoto->validated ) {
	$final_message = '<div class="alert alert-success" role="alert">' .
	  '<span style="font-size: 140%" class="glyphicon glyphicon-ok-sign">&nbsp;</span>' .
	    '<em>jpegPhoto attribute is added/changed from file: </em>&nbsp;' .
	      '<kbd style="font-size: 120%; font-family: monospace;">' .
		$success_message . '</div>' if $success_message;
      } else {
	$final_message = '<div class="alert alert-warning" role="alert">' .
	  '<span style="font-size: 140%" class="glyphicon glyphicon-warning-sign">&nbsp;</span>' .
	    '<em>jpegPhoto was not added/changed from file:</em>&nbsp;' .
	      '<kbd style="font-size: 120%; font-family: monospace;">' .
		$error_message . '</div>' if $error_message;
      }

      $final_message .= '<div class="alert alert-danger" role="alert">' .
	'<span style="font-size: 140%" class="icon_error-oct" aria-hidden="true"></span><ul>' .
	  $error_message . '</ul></div>' if $error_message;

      # $self->form->info_message( $final_message ) if $final_message && defined $params->{password_gen}->{clear};
      p $final_message;


      $c->stash( template => 'user/user_modjpegphoto.tt',
		 form => $self->form_jpegphoto,
		 final_message => $final_message,
		 ldap_modify_jpegphoto => $params->{'ldap_modify_jpegphoto'},
	       );
      # Validate and insert/update database
      return unless $self->form_jpegphoto->process( # item_id => $searchby_id,
						   posted => ($c->req->method eq 'POST'),
						   params => $params,
						  );
    } elsif ( defined $params->{'add_svc_acc'} &&
	      $params->{'add_svc_acc'} ne '') {
      use UMI::Form::AddServiceAccount;
      has 'form_add_svc_acc' => ( isa => 'UMI::Form::AddServiceAccount', is => 'rw',
		      lazy => 1, default => sub { UMI::Form::AddServiceAccount->new },
		      documentation => q{Form to add service account},
		    );

      $c->stash( template => 'user/user_add_svc.tt',
		 form => $self->form_add_svc_acc,
#		 final_message => $final_message,
		 add_svc_acc => $params->{'add_svc_acc'},
	       );
    }
  } else {
    $c->stash( template => 'signin.tt', );
  }
}

sub modify :Path(modify) :Args(0) {
  my ( $self, $c ) = @_;
  use Data::Printer;

  my $ldap_crud =
    $c->model('LDAP_CRUD');
  my $params = $c->req->parameters;
  # p $params;

  $params->{jpegPhoto} = $c->req->upload('jpegPhoto');

  # p $params;
  my ($attr, $val, $mod, $orig);
  # foreach $attr ( sort $c->session->{modify_entries}->attributes ) {
  #   $val = $c->session->{modify_entries}->get_value ( $attr, asref => 1  );
  #   $orig->{$attr} = scalar @{$val} == 1 ? $val->[0] : $val;
  # }
  foreach $attr ( sort ( keys %{$params} )) {
    next if ( $attr =~ /$ldap_crud->{cfg}->{exclude_prefix}/ ||
	      $attr =~ /userPassword/ );
    $val = $c->session->{modify_entries}->get_value ( $attr, asref => 1  );
    # if ref ARRAY needed
    $orig = ref($val) eq "ARRAY" && scalar @{$val} == 1 ? $val->[0] : $val;
    $val = $params->{$attr};
    next if $val ~~ $orig;

    if ( $attr eq 'jpegPhoto' && $val ne "" ) {
      my ($file, $jpeg);
      $file = $val->{'tempname'};
      local $/ = undef;
      open(my $fh, "<", $file) or $c->log->debug("Can not open $file: $!" );
      $jpeg = <$fh>;
      close($fh) or $c->log->debug($!);
      $mod->{$attr} = [ $jpeg ];
    } elsif ( $val ne "" &&
	      $val ne $orig ) {
      $mod->{$attr} = $val;
    }
  }

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

#__PACKAGE__->meta->make_immutable;

1;

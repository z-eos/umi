# -*- mode: cperl -*-
#

package UMI::Form::UserAll;

use HTML::FormHandler::Moose;
BEGIN { extends 'UMI::Form::LDAP'; with 'Tools'; }

use HTML::FormHandler::Types ('NoSpaces', 'WordChars', 'NotAllDigits', 'Printable', 'StrongPassword' );

has '+item_class' => ( default =>'UserAll' );
has '+enctype' => ( default => 'multipart/form-data');

sub build_form_element_class { [ 'form-horizontal', 'tab-content' ] }

######################################################################
#== PERSONAL DATA ====================================================
######################################################################
has_field 'avatar' => ( type => 'Upload',
			label => 'Photo User ID',
			label_class => [ 'col-xs-2', ],
			element_wrapper_class => [ 'col-xs-2', 'col-lg-3', ],
			element_class => [ 'btn', 'btn-default', ],
			max_size => '50000' );

has_field 'givenname' => ( apply => [ NoSpaces ],
			   label => 'First Name',
			   label_class => [ 'col-xs-2', ],
			   element_wrapper_class => [ 'col-xs-10', 'col-lg-5', ],
			   element_attr => { placeholder => 'John' },
			   required => 1 );

has_field 'sn' => ( apply => [ NoSpaces ],
		    label => 'Last Name',
		    label_class => [ 'col-xs-2', ],
		    element_wrapper_class => [ 'col-xs-10', 'col-lg-5', ],
		    element_attr => { placeholder => 'Doe' },
		    required => 1 );

has_field 'office' => ( type => 'Select',
			label => 'Office',
			label_class => [ 'col-xs-2' ],
			element_wrapper_class => [ 'col-xs-10', 'col-lg-5', ],
			required => 1 );

sub options_office {
  my $self = shift;

  return unless $self->ldap_crud;

  my $ldap_crud = $self->ldap_crud;
  my $mesg = $ldap_crud->search(
				{
				 base => $ldap_crud->{'cfg'}->{'base'}->{'org'},
				 scope => 'children',
				 filter => 'ou=*',
				 attrs => [ qw(ou physicaldeliveryofficename l) ],
				 sizelimit => 0
				}
			       );
  my @orgs = ( { value => '0', label => '--- select parent office ---', selected => 'on' } );
  my @entries = $mesg->entries;
  my ( $a, $i, @dn_arr, $dn, $label );
  foreach my $entry ( @entries ) {
    @dn_arr = split(',',$entry->dn);
    if ( scalar @dn_arr < 4 ) {
      $label = sprintf("%s (head office %s @ %s)",
		       $entry->get_value ('ou'),
		       $entry->get_value ('physicaldeliveryofficename'),
		       $entry->get_value ('l'),
		      );
    } elsif ( scalar @dn_arr == 4 ) {
      $label = sprintf("%s (%s @ %s) branch of %s",
		       $entry->get_value ('ou'),
		       $entry->get_value ('physicaldeliveryofficename'),
		       $entry->get_value ('l'),
		       substr($dn_arr[1],3)
		      );
    } else {
      for ( $i = 1, $dn = ''; $i < scalar @dn_arr - 2; $i++ ) {
	$dn .= $dn_arr[$i];
      }
      $a = $dn =~ s/ou=/ -> /g;
      $label = sprintf("%s (%s @ %s) branch of %s",
		       $entry->get_value ('ou'),
		       $entry->get_value ('physicaldeliveryofficename'),
		       $entry->get_value ('l'),
		       $dn
		      );
    }

    push @orgs, {
		 value => $entry->dn,
		 label => $label
		};
  }
  return \@orgs;
}

has_field 'title' => ( label => 'Position',
		       label_class => [ 'col-xs-2', ],
		       element_wrapper_class => [ 'col-xs-10', 'col-lg-5', ],
		       element_attr => { placeholder => 'manager' },
		       required => 1 );

has_field 'telephonenumber' => ( apply => [ NoSpaces ],
				 label => 'SIP/Cell',
				 label_class => [ 'col-xs-2', ],
				 element_wrapper_class => [ 'col-xs-10', 'col-lg-5', ],
				 wrapper_attr => { id => 'items' },
				 element_attr => { name => 'telephonenumber\[\]',
						   placeholder => '123@pbx0.ibs +380xxxxxxxxx' });

has_field 'person_tel_comment' => ( type => 'Display',
				    html => '<small class="text-muted col-xs-offset-2"><em>' .
				    'comma or space delimited if many, international format for tel.</em></small><p>&nbsp;</p>',
				  );

######################################################################
#== SERVICES WITH LOGIN ==============================================
######################################################################
has_field 'login' => ( apply => [ NoSpaces, NotAllDigits, Printable ],
		       label => 'Login',
		       label_class => [ 'col-xs-2', ],
		       element_wrapper_class => [ 'col-xs-10', 'col-lg-5', ],
		       element_attr => { placeholder => 'john.doe' },
		     );

has_field 'password1' => ( type => 'Password',
			   # minlength => 7, maxlength => 16,
			   label => 'Password',
			   label_class => [ 'col-xs-2', ],
			   element_wrapper_class => [ 'col-xs-10', 'col-lg-5', ],
			   ne_username => 'login',
			   apply => [ NoSpaces, NotAllDigits, Printable, StrongPassword ],
			   element_attr => { placeholder => 'Password', },
			 );

has_field 'password2' => ( type => 'Password',
			   # minlength => 7, maxlength => 16,
			   label => '',
			   label_class => [ 'col-xs-2', ],
			   element_wrapper_class => [ 'col-xs-10', 'col-lg-5', ],
			   ne_username => 'login',
			   apply => [ NoSpaces, NotAllDigits, Printable, StrongPassword ],
			   element_attr => { placeholder => 'Confirm Password', },
			 );

has_field 'pwdcomment' => ( type => 'Display',
			    html => '<small class="text-muted col-xs-offset-2"><em>' .
			    'leave empty password fields to autogenerate password</em></small><p>&nbsp;</p>',
			  );

has_field 'associateddomain' => ( type => 'Select',
				  label => 'Domain Name',
				  label_class => [ 'col-xs-2', ],
				  element_wrapper_class => [ 'col-xs-10', 'col-lg-5', ],
				  required => 0 );

sub options_associateddomain {
  my $self = shift;

  return unless $self->ldap_crud;

  my @domains = ( { value => '0', label => '--- select domain ---', selected => 'selected' } );
  my $ldap_crud = $self->ldap_crud;
  my $mesg = $ldap_crud->search( { base => $ldap_crud->{cfg}->{base}->{org},
				   filter => 'associatedDomain=*',
				   attrs => ['associatedDomain' ],
				 } );
  my $err_message = '';
  if ( ! $mesg->count ) {
    $err_message = '<div class="alert alert-danger">' .
      '<span style="font-size: 140%" class="icon_error-oct" aria-hidden="true"></span><ul>' .
	$ldap_crud->err($mesg) . '</ul></div>';
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

has_field 'authorizedservice' => ( type => 'Select',
				   label => 'Service', label_class => [ 'required' ],
				   label_class => [ 'col-xs-2', ],
				   element_wrapper_class => [ 'col-xs-10', 'col-lg-5', ],
				   required => 0,
				 );

sub options_authorizedservice {
  my $self = shift;

  return unless $self->ldap_crud;

  push my @services, {
  		      value => '0',
  		      label => '--- select service ---',
  		      selected => 'selected',
  		     };

  foreach my $key ( sort {$a cmp $b} keys %{$self->ldap_crud->{cfg}->{authorizedService}}) {
    if ( $self->ldap_crud->{cfg}->{authorizedService}->{$key}->{auth} ) {
      push @services, {
		       value => $key,
		       label => $self->ldap_crud->{cfg}->{authorizedService}->{$key}->{descr},
		      };
    }
  }
  return \@services;
}

######################################################################
#== SERVICES WITHOUT LOGIN ===========================================
######################################################################
has_field 'associateddomain_ssh' => ( type => 'Select',
				      label => 'Domain Name',
				      label_class => [ 'col-xs-2', ],
				      element_wrapper_class => [ 'col-xs-10', 'col-lg-5', ],
				    );

sub options_associateddomain_ssh {
  my $self = shift;

  return unless $self->ldap_crud;

  my @domains = ( { value => '0', label => '--- select domain ---', selected => 'selected' } );
  my $ldap_crud = $self->ldap_crud;
  my $mesg = $ldap_crud->search( { base => $ldap_crud->{cfg}->{base}->{org},
				   filter => 'associatedDomain=*',
				   attrs => ['associatedDomain' ],
				 } );
  my $err_message = '';
  if ( ! $mesg->count ) {
    $err_message = '<div class="alert alert-danger">' .
      '<span style="font-size: 140%" class="icon_error-oct" aria-hidden="true"></span><ul>' .
	$ldap_crud->err($mesg) . '</ul></div>';
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

has_field 'ssh' => ( type => 'TextArea',
		     label => 'SSH Pub Key',
		     label_class => [ 'col-xs-2', ],
		     element_wrapper_class => [ 'col-xs-10', 'col-lg-8', ],
		     element_attr => { placeholder => 'Paste SSH key' },
		     cols => 30, rows => 4);


has_field 'associateddomain_ovpn' => ( type => 'Select',
				      label => 'Domain Name',
				      label_class => [ 'col-xs-2', ],
				      element_wrapper_class => [ 'col-xs-10', 'col-lg-5', ],
				    );

sub options_associateddomain_ovpn {
  my $self = shift;

  return unless $self->ldap_crud;

  my @domains = ( { value => '0', label => '--- select domain ---', selected => 'selected' } );
  my $ldap_crud = $self->ldap_crud;
  my $mesg = $ldap_crud->search( { base => $ldap_crud->{cfg}->{base}->{org},
				   filter => 'associatedDomain=*',
				   attrs => ['associatedDomain' ],
				 } );
  my $err_message = '';
  if ( ! $mesg->count ) {
    $err_message = '<div class="alert alert-danger">' .
      '<span style="font-size: 140%" class="icon_error-oct" aria-hidden="true"></span><ul>' .
	$ldap_crud->err($mesg) . '</ul></div>';
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

has_field 'ovpn_cert' => ( type => 'Upload',
		      label => 'OpenVPN Certificate',
		      label_class => [ 'col-xs-2', ],
		      element_wrapper_class => [ 'col-xs-2', 'col-lg-3', ],
		      element_class => [ 'btn', 'btn-default', ],
		    );

has_field 'ovpn_comment' => ( type => 'Display',
			    html => '<small class="text-muted col-xs-offset-2"><em>' .
			    'certificate in DER format</em></small><p>&nbsp;</p>',
			  );

has_field 'ovpn_device' => ( apply => [ NoSpaces, NotAllDigits, Printable ],
		       label => 'Device',
		       label_class => [ 'col-xs-2', ],
		       element_wrapper_class => [ 'col-xs-10', 'col-lg-5', ],
		       element_attr => { placeholder => 'Lenovo P780' },
		     );


has_field 'groups' => ( type => 'Multiple',
			label => '',
			element_wrapper_class => [ 'col-xs-12', ],
			element_class => [ 'multiselect', ],
			# required => 1,
		      );

sub options_groups {
  my $self = shift;
  my ( @groups, $return );

  return unless $self->ldap_crud;

  my $ldap_crud = $self->ldap_crud;
  my $mesg = $ldap_crud->search( { base => $ldap_crud->{cfg}->{base}->{group},
				   scope => 'one',
				   attrs => ['cn' ], } );

  if ( ! $mesg->count ) {
    push @{$return->{error}}, $ldap_crud->err($mesg);
  }

  my @groups_all = $mesg->sorted('cn');

  foreach ( @groups_all ) {
    push @groups, { value => $_->get_value('cn'), label => $_->get_value('cn'), };
  }
  return \@groups;
}

has_field 'groupspace' => ( type => 'Display',
			    html => '<p>&nbsp;</p>',
			  );


# has_field 'reset' => ( type => 'Reset',
# #			wrapper_class => [ 'pull-left', ],
# 			element_class => [ 'btn', 'btn-default', 'btn-block', ],
# 			element_wrapper_class => [ 'col-xs-2' ],
# 		        value => 'Reset All Tabs' );


has_field 'submit' => ( type => 'Submit',
#			wrapper_class => [ 'pull-right', ],
			element_class => [ 'btn', 'btn-default', 'btn-block', ],
			element_wrapper_class => [ 'col-xs-12' ],
			value => 'Submit' );



has_block 'person' => ( tag => 'div',
			render_list => [ 'avatar',
					 'givenname',
					 'sn',
					 'office',
					 'title',
					 'telephonenumber',
					 'person_tel_comment', ],
			class => [ 'tab-pane', 'fade', 'in', 'active', ],
			attr => { id => 'person',
				  'aria-labelledby' => "person-tab",
				  role => "tabpanel",
				},
		      );

has_block 'gensvc' => ( tag => 'div',
			render_list => [ 'associateddomain',
					 'authorizedservice',
					 'login',
					 'password1',
					 'password2',
					 'pwdcomment' ],
			class => [ 'tab-pane', 'fade', ],
			attr => { id => 'gensvc',
				  'aria-labelledby' => "gensvc-tab",
				  role => "tabpanel",
				},
		       );

has_block 'sshkey' => ( tag => 'div',
			render_list => [ 'associateddomain_ssh', 'ssh', ],
			class => [ 'tab-pane', 'fade', ],
			attr => { id => 'ssh',
				  'aria-labelledby' => "ssh-tab",
				  role => "tabpanel",
				},
		      );

has_block 'ovpn' => ( tag => 'div',
		      render_list => [ 'associateddomain_ovpn',
				       'ovpn_device',
				       'ovpn_cert',
				       'ovpn_comment', ],
			  class => [ 'tab-pane', 'fade', ],
			  attr => { id => 'ovpn',
				    'aria-labelledby' => "ovpn-tab",
				    role => "tabpanel",
				  },
			);

has_block 'groupsselect' => ( tag => 'div',
			render_list => [ 'groups', 'groupspace', ],
			class => [ 'tab-pane', 'fade', ],
			attr => { id => 'groups',
				  'aria-labelledby' => "groups-tab",
				  role => "tabpanel",
				},
		      );

has_block 'submitit' => ( tag => 'fieldset',
			  render_list => [ 'groupspace', 'submit'],
			  label => '&nbsp;',
			  class => [ '' ]
			);

sub build_render_list {[ 'person', 'gensvc', 'sshkey', 'ovpn', 'groupsselect', 'submitit' ]}

sub html_attributes {
  my ( $self, $field, $type, $attr ) = @_;
  push @{$attr->{class}}, 'required'
    if ( $type eq 'label' && $field->required );
}

sub validate {
  my $self = shift;

  if ( defined $self->field('password1')->value and defined $self->field('password2')->value
       and ($self->field('password1')->value ne $self->field('password2')->value) ) {
    $self->field('password2')->add_error('Password doesn\'t match Confirmation');
  }

  if ( defined $self->field('associateddomain')->value &&
       $self->field('associateddomain')->value eq '0' ) {
    $self->field('associateddomain')->add_error('Domain Name is mandatory!');
  }

  if ( defined $self->field('authorizedservice')->value &&
       $self->field('authorizedservice')->value eq '0') {
    $self->field('authorizedservice')->add_error('At least one service is required!');
  }

  if ( defined $self->field('office')->value &&
       $self->field('office')->value eq '0' ) {
    $self->field('office')->add_error('Office is mandatory!');
  }

  my $ldap_crud = $self->ldap_crud;
  my $mesg =
    $ldap_crud->search({
			scope => 'one',
			filter => '(uid=' .
			$self->field('login')->value . ')',
			base => $ldap_crud->{cfg}->{base}->{acc_root},
			attrs => [ 'uid' ],
		       });
  my ( $err, $error );
  if ($mesg->count) {
    $err = '<span class="glyphicon glyphicon-exclamation-sign"></span> Root uid <em>&laquo;' .
      $self->field('login')->value . '&raquo;</em> exists';
    $self->field('login')->add_error($err);

    $err = '<div class="alert alert-danger">' .
      '<span style="font-size: 140%" class="glyphicon glyphicon-exclamation-sign"></span>' .
      '&nbsp;Account with the same root uid <strong>&laquo;' . $self->field('login')->value . '&raquo;</strong>,' .
      ' already exists!</div>';
  }
  # else {
  #    $mesg =
  #      $ldap_crud->search(
  # 			 {
  # 			  scope => 'one',
  # 			  filter => '(&(givenname=' .
  # 			  $self->utf2lat({ to_translate => $self->field('givenname')->value }) . ')(sn=' .
  # 			  $self->utf2lat({ to_translate => $self->field('sn')->value }) . ')(uid=' .
  # 			  $self->field('login')->value . '))',
  # 			  base => 'ou=People,dc=umidb',
  # 			  attrs => [ 'uid' ],
  # 			 }
  # 			);

  #    if ($mesg->count) {
  #      $err = '<span class="glyphicon glyphicon-exclamation-sign"></span> Fname+Lname+Login exists';
  #      $self->field('givenname')->add_error($err);
  #      $self->field('sn')->add_error($err);
  #      $self->field('login')->add_error($err);

  #      $err = '<div class="alert alert-danger">' .
  # 	'<span style="font-size: 140%" class="icon_error-oct" aria-hidden="true"></span>' .
  # 	  '&nbsp;Account with the same fields &laquo;<strong>First Name&raquo;</strong>,' .
  # 	    ' &laquo;<strong>Last Name&raquo;</strong> and &laquo;<strong>Login&raquo;</strong>' .
  # 	      ' already exists!<br>Consider one of:<ul>' .
  # 		'<li>change Login in case you need another account for the same person</li>' .
  # 		  '<li>add service account to the existent one</li></ul></div>';
  #    }
  #  }
  # $error = $self->form->success_message & $self->form->success_message : '';
  # $self->form->error_message('');
  # $self->form->add_form_error(sprintf('%s%s',
  # 				      $self->form->success_message ? $self->form->success_message : '',
  # 				      $err ? $err : ''
  # 				     ));
}

######################################################################

no HTML::FormHandler::Moose;

__PACKAGE__->meta->make_immutable;

1;

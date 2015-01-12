# -*- mode: cperl -*-
#

package UMI::Form::UserAll;

use HTML::FormHandler::Moose;
BEGIN { extends 'UMI::Form::LDAP'; with 'Tools'; }

use HTML::FormHandler::Types ('NoSpaces', 'WordChars', 'NotAllDigits', 'Printable', 'StrongPassword' );

use Data::Printer;

has '+item_class' => ( default =>'UserAll' );
has '+enctype' => ( default => 'multipart/form-data');

sub build_form_element_class { [ 'form-horizontal', 'tab-content' ] }

######################################################################
#== PERSONAL DATA ====================================================
######################################################################
has_field 'person[avatar]' => ( type => 'Upload',
				label => 'Photo User ID',
				label_class => [ 'col-xs-2', ],
				element_wrapper_class => [ 'col-xs-2', 'col-lg-3', ],
				element_class => [ 'btn', 'btn-default', ],
				max_size => '50000' );

has_field 'person[givenname]' => ( apply => [ NoSpaces ],
				   label => 'First Name',
				   label_class => [ 'col-xs-2', ],
				   element_wrapper_class => [ 'col-xs-10', 'col-lg-5', ],
				   element_attr => { placeholder => 'John' },
				   required => 1 );

has_field 'person[sn]' => ( apply => [ NoSpaces ],
			    label => 'Last Name',
			    label_class => [ 'col-xs-2', ],
			    element_wrapper_class => [ 'col-xs-10', 'col-lg-5', ],
			    element_attr => { placeholder => 'Doe' },
			    required => 1 );

has_field 'person[office]' => ( type => 'Select',
				label => 'Office',
				label_class => [ 'col-xs-2' ],
				element_wrapper_class => [ 'col-xs-10', 'col-lg-5', ],
				# name => 'person[office]',
				options_method => \&offices,
				required => 1 );

has_field 'person[title]' => ( label => 'Position',
			       label_class => [ 'col-xs-2', ],
			       element_wrapper_class => [ 'col-xs-10', 'col-lg-5', ],
			       element_attr => { placeholder => 'manager' },
			       required => 1 );

has_field 'person[telephonenumber]' => ( apply => [ NoSpaces ],
					 label => 'SIP/Cell',
					 label_class => [ 'col-xs-2', ],
					 element_wrapper_class => [ 'col-xs-10', 'col-lg-5', ],
					 wrapper_attr => { id => 'items' },
					 element_attr => { name => 'telephonenumber\[\]',
							   placeholder => '123@pbx0.ibs +380xxxxxxxxx' });

has_field 'person[telcomment]' => ( type => 'Display',
				    html => '<small class="text-muted col-xs-offset-2"><em>' .
				    'comma or space delimited if many, international format for tel.</em></small>',
				  );

has_block 'group_person' => ( tag => 'div',
			      render_list => [ 'person[avatar]',
					       'person[givenname]',
					       'person[sn]',
					       'person[office]',
					       # 'office',
					       'person[title]',
					       'person[telephonenumber]',
					       'person[telcomment]', ],
			      attr => { id => 'group_person', },
			    );

has_block 'person' => ( tag => 'div',
			render_list => [ 'group_person', ],
			class => [ 'tab-pane', 'fade', 'in', 'active', ],
			attr => { id => 'person',
				  'aria-labelledby' => "person-tab",
				  role => "tabpanel",
				},
		      );

######################################################################
#== SERVICES WITH LOGIN ==============================================
######################################################################
has_field 'auth[0][login]' => ( apply => [ NoSpaces, NotAllDigits, Printable ],
		       label => 'Login',
		       label_class => [ 'col-xs-2', ],
		       element_wrapper_class => [ 'col-xs-10', 'col-lg-5', ],
		       element_attr => { placeholder => 'john.doe' },
		     );

has_field 'auth[0][password1]' => ( type => 'Password',
			   # minlength => 7, maxlength => 16,
			   label => 'Password',
			   label_class => [ 'col-xs-2', ],
			   element_wrapper_class => [ 'col-xs-10', 'col-lg-5', ],
			   ne_username => 'login',
			   apply => [ NoSpaces, NotAllDigits, Printable, StrongPassword ],
			   element_attr => { placeholder => 'Password', },
			 );

has_field 'auth[0][password2]' => ( type => 'Password',
			   # minlength => 7, maxlength => 16,
			   label => '',
			   label_class => [ 'col-xs-2', ],
			   element_wrapper_class => [ 'col-xs-10', 'col-lg-5', ],
			   ne_username => 'login',
			   apply => [ NoSpaces, NotAllDigits, Printable, StrongPassword ],
			   element_attr => { placeholder => 'Confirm Password', },
			 );

has_field 'auth[0][pwdcomment]' => ( type => 'Display',
			    html => '<small class="text-muted col-xs-offset-2"><em>' .
			    'leave empty password fields to autogenerate password</em></small><p>&nbsp;</p>',
			  );

has_field 'auth[0][associateddomain]' => ( type => 'Select',
				  label => 'Domain Name',
				  label_class => [ 'col-xs-2', ],
				  element_wrapper_class => [ 'col-xs-10', 'col-lg-5', ],
				  options_method => \&associateddomains,
				  required => 0 );

has_field 'auth[0][authorizedservice]' => ( type => 'Select',
				   label => 'Service', label_class => [ 'required' ],
				   label_class => [ 'col-xs-2', ],
				   element_wrapper_class => [ 'col-xs-10', 'col-lg-5', ],
				   options_method => \&authorizedservice,
				   required => 0,
				 );

has_block 'group_auth' => ( tag => 'div',
			    render_list => [ 'auth[0][associateddomain]',
					     'auth[0][authorizedservice]',
					     'auth[0][login]',
					     'auth[0][password1]',
					     'auth[0][password2]',
					     'auth[0][pwdcomment]' ],
			    attr => { id => 'group_auth', },
			  );

has_block 'auth' => ( tag => 'div',
		      render_list => [ 'group_auth', ],
		      class => [ 'tab-pane', 'fade', ],
		      attr => { id => 'auth',
				'aria-labelledby' => "auth-tab",
				role => "tabpanel",
			      },
		    );

######################################################################
#== SERVICES WITHOUT LOGIN ===========================================
######################################################################
has_field 'ssh[0][associateddomain]' => ( type => 'Select',
				      label => 'Domain Name',
				      label_class => [ 'col-xs-2', ],
				      element_wrapper_class => [ 'col-xs-10', 'col-lg-5', ],
				      options_method => \&associateddomains,
				    );

has_field 'ssh[0][key]' => ( type => 'TextArea',
		     label => 'SSH Pub Key',
		     label_class => [ 'col-xs-2', ],
		     element_wrapper_class => [ 'col-xs-10', 'col-lg-8', ],
		     element_attr => { placeholder => 'Paste SSH key' },
		     cols => 30, rows => 4);


has_block 'group_ssh' => ( tag => 'div',
			   render_list => [ 'ssh[0][associateddomain]', 'ssh[0][key]', ],
			   attr => { id => 'group_ssh', },
			 );

has_block 'ssh' => ( tag => 'div',
		      render_list => [ 'group_ssh', ],
		      class => [ 'tab-pane', 'fade', ],
		      attr => { id => 'ssh',
				'aria-labelledby' => "ssh-tab",
				role => "tabpanel",
			      },
		    );

#=====================================================================

has_field 'ovpn[0][associateddomain]' => ( type => 'Select',
				       label => 'Domain Name',
				       label_class => [ 'col-xs-2', ],
				       element_wrapper_class => [ 'col-xs-10', 'col-lg-5', ],
				       options_method => \&associateddomains,
				     );

has_field 'ovpn[0][cert]' => ( type => 'Upload',
		      label => 'OpenVPN Certificate',
		      label_class => [ 'col-xs-2', ],
		      element_wrapper_class => [ 'col-xs-2', 'col-lg-3', ],
		      element_class => [ 'btn', 'btn-default', ],
		    );

has_field 'ovpn[0][comment]' => ( type => 'Display',
			    html => '<small class="text-muted col-xs-offset-2"><em>' .
			    'certificate in DER format</em></small><p>&nbsp;</p>',
			  );

has_field 'ovpn[0][device]' => ( apply => [ NoSpaces, NotAllDigits, Printable ],
		       label => 'Device',
		       label_class => [ 'col-xs-2', ],
		       element_wrapper_class => [ 'col-xs-10', 'col-lg-5', ],
		       element_attr => { placeholder => 'Lenovo P780' },
		     );

has_block 'group_ovpn' => ( tag => 'div',
			    render_list => [ 'ovpn[0][associateddomain]',
					     'ovpn[0][device]',
					     'ovpn[0][cert]',
					     'ovpn[0][comment]', ],
			    attr => { id => 'group_ovpn', },
			);

has_block 'ovpn' => ( tag => 'div',
		      render_list => [ 'group_ovpn', ],
		      class => [ 'tab-pane', 'fade', ],
		      attr => { id => 'ovpn',
				'aria-labelledby' => "ovpn-tab",
				role => "tabpanel",
			      },
		    );

#=====================================================================

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

has_block 'groupsselect' => ( tag => 'div',
			render_list => [ 'groups', 'groupspace', ],
			class => [ 'tab-pane', 'fade', ],
			attr => { id => 'groups',
				  'aria-labelledby' => "groups-tab",
				  role => "tabpanel",
				},
		      );

has_block 'submitit' => ( tag => 'div',
			  render_list => [ 'groupspace', 'submit'],
			  # class => [ '' ]
			);

sub build_render_list {[ 'person', 'auth', 'ssh', 'ovpn', 'groupsselect', 'submitit' ]}

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

sub offices {
  my $self = shift;
  my ( @office, @branches );

  return unless $self->form->ldap_crud;

  my $ldap_crud = $self->form->ldap_crud;
  my $mesg = $ldap_crud->search({
				 base => $ldap_crud->{'cfg'}->{'base'}->{'org'},
				 scope => 'one',
				 # filter => 'ou=*',
				 attrs => [ qw(ou physicaldeliveryofficename l) ],
				 sizelimit => 0
				});
  my @headOffices = $mesg->sorted('physicaldeliveryofficename');
  foreach my $headOffice (@headOffices) {
    $mesg = $ldap_crud->search({
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
  return @office;
}

sub associateddomains {
  my $self = shift;

  return unless $self->form->ldap_crud;

  my @domains = ( { value => '0', label => '--- select domain ---', selected => 'selected', } );
  my $ldap_crud = $self->form->ldap_crud;
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
  return @domains;
}

sub authorizedservice {
  my $self = shift;

  return unless $self->form->ldap_crud;

  push my @services, { value => '0',
		       label => '--- select service ---',
		       selected => 'selected', };

  foreach my $key ( sort {$a cmp $b} keys %{$self->form->ldap_crud->{cfg}->{authorizedService}}) {
    if ( $self->form->ldap_crud->{cfg}->{authorizedService}->{$key}->{auth} ) {
      push @services, { value => $key,
			label => $self->form->ldap_crud->{cfg}->{authorizedService}->{$key}->{descr}, };
    }
  }
  return @services;
}

######################################################################

no HTML::FormHandler::Moose;

__PACKAGE__->meta->make_immutable;

1;

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
has_field 'person_avatar' => ( type => 'Upload',
				label => 'Photo User ID',
				label_class => [ 'col-xs-2', ],
				element_wrapper_class => [ 'col-xs-2', 'col-lg-3', ],
				element_class => [ 'btn', 'btn-default', 'btn-sm', ],
				max_size => '50000' );

has_field 'person_givenname' => ( apply => [ NoSpaces ],
				   label => 'First Name',
				   label_class => [ 'col-xs-2', ],
				   element_wrapper_class => [ 'col-xs-10', 'col-lg-5', ],
					   element_class => [ 'input-sm', ],
				   element_attr => { placeholder => 'John' },
				   required => 1 );

has_field 'person_sn' => ( apply => [ NoSpaces ],
			    label => 'Last Name',
			    label_class => [ 'col-xs-2', ],
			    element_wrapper_class => [ 'col-xs-10', 'col-lg-5', ],
					   element_class => [ 'input-sm', ],
			    element_attr => { placeholder => 'Doe' },
			    required => 1 );

has_field 'person_office' => ( type => 'Select',
				label => 'Office',
				label_class => [ 'col-xs-2' ],
				element_wrapper_class => [ 'col-xs-10', 'col-lg-5', ],
					   element_class => [ 'input-sm', ],
				options_method => \&offices,
				required => 1 );

has_field 'person_title' => ( label => 'Position',
			       label_class => [ 'col-xs-2', ],
			       element_wrapper_class => [ 'col-xs-10', 'col-lg-5', ],
					   element_class => [ 'input-sm', ],
			       element_attr => { placeholder => 'manager' },
			       required => 1 );

has_field 'person_telephonenumber' => ( apply => [ NoSpaces ],
					 label => 'SIP/Cell',
					 label_class => [ 'col-xs-2', ],
					 element_wrapper_class => [ 'col-xs-10', 'col-lg-5', ],
					   element_class => [ 'input-sm', ],
					 wrapper_attr => { id => 'items' },
					 element_attr => { name => 'telephonenumber\[\]',
							   placeholder => '123@pbx0.ibs +380xxxxxxxxx' });

has_field 'person_telcomment' => ( type => 'Display',
				    html => '<small class="text-muted col-xs-offset-2"><em>' .
				    'comma or space delimited if many, international format for tel.</em></small>',
				  );

has_block 'group_person' => ( tag => 'div',
			      render_list => [ 'person_avatar',
					       'person_givenname',
					       'person_sn',
					       'person_office',
					       'person_title',
					       'person_telephonenumber',
					       'person_telcomment', ],
			      attr => { id => 'group_person', },
			    );

has_block 'person' => ( tag => 'fieldset',
			label => 'Personal Data',
			render_list => [ 'group_person', ],
			class => [ 'tab-pane', 'fade', 'in', 'active', ],
			attr => { id => 'person',
				  'aria-labelledby' => "person-tab",
				  role => "tabpanel",
				},
		      );

######################################################################
#== SERVICES =========================================================
######################################################################
# has_field 'rm-duplicate' => ( type => 'Display',
# 			      html => '<span class="fa fa-times-circle col-xs-offset-2 btn btn-link text-danger hidden" title="Delete this section."></span>',
# 			    );

has_field 'rm-duplicate' => ( type => 'Display',
			      html => '<div class="col-xs-12 rm-duplicate hidden"><div class="col-xs-1">' .
			      '<button type="button" class="btn btn-danger btn-xs">' .
			      '<span class="fa fa-times-circle"></span> Delete this section' .
			      '</button></div></div>',
			    );

# has_field 'rm-duplicate' => ( type => 'Button',
# 			      do_label => 0,
# 			      element_class => [ 'btn', 'btn-danger', 'btn-xs', ],
# 			      element_wrapper_class => [ 'col-xs-1', ],
# 			      wrapper_class => [ 'col-xs-12', ' rm-duplicate', 'hidden' ],
# 			      value => '<span class="fa fa-times-circle"></span>' );


######################################################################
#== SERVICES WITH LOGIN ==============================================
######################################################################
has_field 'account' => ( type => 'Repeatable',
                         setup_for_js => 1,
                         do_wrapper => 1,
                         tags => { controls_div => 1 },
                         init_contains => { wrapper_attr => { class => ['hfh', 'repinst'] } },
                       );

has_field 'account.login' => ( apply => [ NoSpaces, NotAllDigits, Printable ],
				label => 'Login',
				do_id => 'no',
				label_class => [ 'col-xs-2', ],
				element_wrapper_class => [ 'col-xs-10', 'col-lg-5', ],
					   element_class => [ 'input-sm', ],
				element_attr => { placeholder => 'john.doe',
						  'data-name' => 'login',
						  'data-group' => 'account', },
			      );

has_field 'account.password1' => ( type => 'Password',
				    # minlength => 7, maxlength => 16,
				    label => 'Password',
				    label_class => [ 'col-xs-2', ],
				    element_wrapper_class => [ 'col-xs-10', 'col-lg-5', ],
					   element_class => [ 'input-sm', ],
				    ne_username => 'login',
				    apply => [ NoSpaces, NotAllDigits, Printable, StrongPassword ],
				    element_attr => { placeholder => 'Password',
						      'data-name' => 'password1',
						      'data-group' => 'account', },
				  );

has_field 'account.password2' => ( type => 'Password',
				    # minlength => 7, maxlength => 16,
				    label => '',
				    label_class => [ 'col-xs-2', ],
				    element_wrapper_class => [ 'col-xs-10', 'col-lg-5', ],
					   element_class => [ 'input-sm', ],
				    ne_username => 'login',
				    apply => [ NoSpaces, NotAllDigits, Printable, StrongPassword ],
				    element_attr => { placeholder => 'Confirm Password',
						      'data-name' => 'password2',
						      'data-group' => 'account',
						    },
				  );

has_field 'account.pwdcomment' => ( type => 'Display',
				     html => '<small class="text-muted col-xs-offset-2"><em>' .
				     'leave empty password fields to autogenerate password</em></small><p>&nbsp;</p>',
				   );

has_field 'account.associateddomain' => ( type => 'Select',
					   label => 'Domain Name',
					   label_class => [ 'col-xs-2', ],
					   element_wrapper_class => [ 'col-xs-10', 'col-lg-5', ],
					   element_class => [ 'input-sm', ],
					   options_method => \&associateddomains,
					   element_attr => {
							    'data-name' => 'associateddomain',
							    'data-group' => 'account',
							   },
					   required => 0 );

has_field 'account.authorizedservice' => ( type => 'Select',
					   label => 'Service', label_class => [ 'required' ],
					   label_class => [ 'col-xs-2', ],
					   element_wrapper_class => [ 'col-xs-10', 'col-lg-5', ],
					   element_class => [ 'input-sm', ],
					   options_method => \&authorizedservice,
					   element_attr => {
							    'data-name' => 'authorizedservice',
							    'data-group' => 'account',
							   },
					   required => 0,
					  );

has_block 'group_auth' => ( tag => 'div',
			    render_list => [ 'rm-duplicate',
					     'account',
					     # 'account.associateddomain',
					     # 'account.authorizedservice',
					     # 'account.login',
					     # 'account.password1',
					     # 'account.password2',
					     # 'account.pwdcomment',
					   ],
			    class => [ 'duplicate' ],
			  );

has_block 'auth' => ( tag => 'fieldset',
		      label => 'Service Account <a href="#" title="Add another Login/Password Dependent Service" data-duplicate="duplicate"><span class="fa fa-plus-circle"></span></a>',
		      # label_class => [ 'col-xs-offset-2', 'text-left'],
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

has_field 'loginless_ssh' => ( type => 'Repeatable',
			  setup_for_js => 1,
			  do_wrapper => 1,
			  tags => { controls_div => 1 },
			  init_contains => { wrapper_attr => { class => ['hfh', 'repinst'] } },
			);

has_field 'loginless_ssh.associateddomain' => ( type => 'Select',
					  label => 'Domain Name',
					  label_class => [ 'col-xs-2', ],
					  element_wrapper_class => [ 'col-xs-10', 'col-lg-5', ],
					   element_class => [ 'input-sm', ],
					  options_method => \&associateddomains,
					  element_attr => {
							   'data-name' => 'associateddomain',
							   'data-group' => 'loginless_ssh',
							  },
					);

has_field 'loginless_ssh.key' => ( type => 'TextArea',
			     label => 'SSH Pub Key',
			     label_class => [ 'col-xs-2', ],
			     element_wrapper_class => [ 'col-xs-10', 'col-lg-8', ],
					   element_class => [ 'input-sm', ],
			     element_attr => { placeholder => 'Paste SSH key',
					       'data-name' => 'key',
					       'data-group' => 'loginless_ssh', },
			     cols => 30, rows => 4);


has_block 'group_ssh' => ( tag => 'div',
			   render_list => [ 'rm-duplicate',
					    'loginless_ssh',
					    'loginless_ssh.associateddomain',
					    'loginless_ssh.key', ],
			   class => [ 'duplicate' ],
			 );

has_block 'ssh' => ( tag => 'fieldset',
		     label => 'SSH Key <a href="#" title="Add another SSH Key" data-duplicate="duplicate"><span class="fa fa-plus-circle"></span></a>',
		     # label_class => [ 'col-xs-offset-2', 'text-left'],
		     render_list => [ 'group_ssh', ],
		     class => [ 'tab-pane', 'fade', ],
		     attr => { id => 'ssh',
			       'aria-labelledby' => "ssh-tab",
			       role => "tabpanel",
			     },
		   );

#=====================================================================

has_field 'loginless_ovpn' => ( type => 'Repeatable',
			      setup_for_js => 1,
			      do_wrapper => 1,
			      tags => { controls_div => 1 },
			      init_contains => { wrapper_attr => { class => ['hfh', 'repinst'] } },
			);

has_field 'loginless_ovpn.associateddomain' => ( type => 'Select',
					   label => 'Domain Name',
					   label_class => [ 'col-xs-2', ],
					   element_wrapper_class => [ 'col-xs-10', 'col-lg-5', ],
					   element_class => [ 'input-sm', ],
					   options_method => \&associateddomains,
					   element_attr => {
							    'data-name' => 'associateddomain',
							    'data-group' => 'loginless_ovpn',
							   },
					 );

has_field 'loginless_ovpn.cert' => ( type => 'Upload',
			       label => 'OpenVPN Certificate (DER format)',
			       label_class => [ 'col-xs-2', ],
			       element_wrapper_class => [ 'col-xs-2', 'col-lg-3', ],
			       element_class => [ 'btn', 'btn-default', 'btn-sm',],
			       element_attr => {
						'data-name' => 'cert',
						'data-group' => 'loginless_ovpn',
					       },
			     );

# has_field 'loginless_ovpn.comment' => ( type => 'Display',
# 				  html => '<small class="text-muted form-group"><em>' .
# 				  'certificate in DER format</em></small><p>&nbsp;</p>',
# 				);

has_field 'loginless_ovpn.device' => ( apply => [ NoSpaces, NotAllDigits, Printable ],
				 label => 'Device',
				 label_class => [ 'col-xs-2', ],
				 element_wrapper_class => [ 'col-xs-10', 'col-lg-5', ],
					   element_class => [ 'input-sm', ],
				 element_attr => { placeholder => 'Lenovo P780',
						   'data-name' => 'device',
						   'data-group' => 'loginless_ovpn', },
			       );

has_field 'loginless_ovpn.ip' => ( apply => [ NoSpaces, NotAllDigits, Printable ],
				   label => 'IP',
				   label_class => [ 'col-xs-2', ],
				   element_wrapper_class => [ 'col-xs-10', 'col-lg-5', ],
				   element_class => [ 'input-sm', ],
				   element_attr => { placeholder => '192.168.0.1',
						   'data-name' => 'ip',
						   'data-group' => 'loginless_ovpn', },
			       );

has_block 'group_ovpn' => ( tag => 'div',
			    render_list => [ 'rm-duplicate',
					     'loginless_ovpn',
					     'loginless_ovpn.associateddomain',
					     'loginless_ovpn.device',
					     'loginless_ovpn.ip',
					     'loginless_ovpn.cert',
					     # 'loginless_ovpn.comment',
					   ],
			    class => [ 'duplicate' ],
			  );

has_block 'ovpn' => ( tag => 'fieldset',
		      label => 'OpenVPN configuration <a href="#" title="Add another OpenVPN Certificate" data-duplicate="duplicate"><span class="fa fa-plus-circle"></span></a>',
		      # label_class => [ 'col-xs-offset-2', 'text-left'],
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
			element_class => [ 'multiselect', 'input-sm', ],
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


has_block 'groupsselect' => ( tag => 'fieldset',
			      label => 'Groups user belongs to',
			      render_list => [ 'groups', ], # 'groupspace', ],
			      class => [ 'tab-pane', 'fade', ],
			      attr => { id => 'groups',
					'aria-labelledby' => "groups-tab",
					role => "tabpanel",
				      },
			    );

######################################################################
#== SERVICES WITHOUT LOGIN ===========================================
######################################################################

has_field 'aux_reset' => ( type => 'Reset',
			   element_class => [ 'btn', 'btn-default', 'btn-block', ],
			   element_wrapper_class => [ 'col-xs-12', ],
			   wrapper_class => [ 'col-xs-1' ],
			   value => 'Reset All' );


has_field 'aux_submit' => ( type => 'Submit',
			    element_class => [ 'btn', 'btn-default', 'btn-block', ],
			    # element_wrapper_class => [ 'col-xs-12', ],
			    wrapper_class => [ 'col-xs-11', ], # 'pull-right' ],
			    value => 'Submit' );

has_block 'submitit' => ( tag => 'fieldset',
			  render_list => [ 'groupspace', 'aux_reset', 'aux_submit'],
			  class => [ 'container-fluid', ]
			);

sub build_render_list {[ 'person', 'auth', 'ssh', 'ovpn', 'groupsselect', 'submitit' ]}

sub html_attributes {
  my ( $self, $field, $type, $attr ) = @_;
  push @{$attr->{class}}, 'required'
    if ( $type eq 'label' && $field->required );
}

sub validate {
  my $self = shift;

  # if ( defined $self->field('password1')->value and defined $self->field('password2')->value
  #      and ($self->field('password1')->value ne $self->field('password2')->value) ) {
  #   $self->field('password2')->add_error('Password doesn\'t match Confirmation');
  # }

  # if ( defined $self->field('associateddomain')->value &&
  #      $self->field('associateddomain')->value eq '0' ) {
  #   $self->field('associateddomain')->add_error('Domain Name is mandatory!');
  # }

  # if ( defined $self->field('authorizedservice')->value &&
  #      $self->field('authorizedservice')->value eq '0') {
  #   $self->field('authorizedservice')->add_error('At least one service is required!');
  # }

  # if ( defined $self->field('office')->value &&
  #      $self->field('office')->value eq '0' ) {
  #   $self->field('office')->add_error('Office is mandatory!');
  # }

  # my $ldap_crud = $self->ldap_crud;
  # my $mesg =
  #   $ldap_crud->search({
  # 			scope => 'one',
  # 			filter => '(uid=' .
  # 			$self->field('login')->value . ')',
  # 			base => $ldap_crud->{cfg}->{base}->{acc_root},
  # 			attrs => [ 'uid' ],
  # 		       });
  # my ( $err, $error );
  # if ($mesg->count) {
  #   $err = '<span class="glyphicon glyphicon-exclamation-sign"></span> Root uid <em>&laquo;' .
  #     $self->field('login')->value . '&raquo;</em> exists';
  #   $self->field('login')->add_error($err);

  #   $err = '<div class="alert alert-danger">' .
  #     '<span style="font-size: 140%" class="glyphicon glyphicon-exclamation-sign"></span>' .
  #     '&nbsp;Account with the same root uid <strong>&laquo;' . $self->field('login')->value . '&raquo;</strong>,' .
  #     ' already exists!</div>';
  # }


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
  return unless $self->form->ldap_crud;
  return $self->form->ldap_crud->select_organizations;
}

sub associateddomains {
  my $self = shift;
  return unless $self->form->ldap_crud;
  return $self->form->ldap_crud->select_associateddomains;
}

sub authorizedservice {
  my $self = shift;
  return unless $self->form->ldap_crud;
  return $self->form->ldap_crud->select_authorizedservice;
}

######################################################################

no HTML::FormHandler::Moose;

__PACKAGE__->meta->make_immutable;

1;

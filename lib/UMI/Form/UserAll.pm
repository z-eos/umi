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

sub build_update_subfields {
  by_flag => { repeatable => { do_wrapper => 1, do_label => 1 } }
}

sub html_attributes {
  my ( $self, $field, $type, $attr ) = @_;
  push @{$attr->{class}}, 'required'
    if ( $type eq 'label' && $field->required );

  $attr->{class} = ['hfh', 'repinst']
    if $type eq 'wrapper' && $field->has_flag('is_contains');

  return $attr;
}

######################################################################
#== PERSONAL DATA ====================================================
######################################################################
has_field 'person_givenname' => ( apply => [ NoSpaces ],
				  label => 'First Name',
				  label_class => [ 'col-xs-1', ],
				  element_wrapper_class => [ 'col-xs-11', 'col-lg-5', ],
				  element_class => [ 'input-sm', ],
				  element_attr => { placeholder => 'John' },
				  required => 1 );

has_field 'person_sn' => ( apply => [ NoSpaces ],
			   label => 'Last Name',
			   label_class => [ 'col-xs-1', ],
			   element_wrapper_class => [ 'col-xs-11', 'col-lg-5', ],
			   element_class => [ 'input-sm', ],
			   element_attr => { placeholder => 'Doe' },
			   required => 1 );

has_field 'nav' => ( type => 'Display',
			      html => '<nav class="navbar navbar-default">
<ul role="tablist" class="nav navbar-nav" id="myTab">
  <li role="presentation">&nbsp;</li>
  <li class="active" role="presentation">
    <a aria-controls="person"
       data-toggle="tab" role="tab"
       id="person-tab"
       href="#person"
       title="Personal Data"
       aria-expanded="true">
      <span class="fa fa-list"></span>
      <span class="sr-only">Person</span>
    </a>
  </li>

  <li role="presentation">
    <a aria-controls="auth"
       data-toggle="tab" role="tab"
       id="auth-tab"
       href="#auth"
       title="Login/Password Dependent Services"
       aria-expanded="false">
      <span class="fa fa-user-plus"></span>
      <!-- <span class="fa-stack">
	    <i class="fa fa-folder-o fa-stack-2x"></i>
	    <i class="fa fa-user fa-stack-1x"></i>
	    </span> -->
      <!-- <span class="fa-stack fa-lg">
	<i class="fa fa-cog fa-stack-2x"></i>
	<i class="fa fa-user-plus fa-stack-1x text-info"></i>
      </span> -->
    </a>
  </li>

  <li class="dropdown" role="presentation">
    <a aria-controls="sec-contents"
       data-toggle="dropdown"
       class="dropdown-toggle"
       id="umiSec"
       href="#"
       title="Services Without Login/Password"
       aria-expanded="false">
      <!-- <span class="fa-stack fa-lg">
	<i class="fa fa-square-o fa-stack-2x"></i>
	<i class="fa fa-user-times fa-stack-1x"></i>
      </span> -->
      <span class="fa fa-user-times"></span>
      <span class="caret"></span>
    </a>
    <ul id="umiSec-contents"
	aria-labelledby="umiSec"
	role="menu"
	class="dropdown-menu">
      <li>
	<a aria-controls="ovpn"
	   data-toggle="tab"
	   id="ovpn-tab"
	   role="tab"
	   tabindex="-1"
	   href="#ovpn"
	   aria-expanded="false">
	  <span class="fa fa-certificate"></span>
	  OpenVPN Certificate
	</a>
      </li>
      <li>
	<a aria-controls="ssh"
	   data-toggle="tab"
	   id="ssh-tab"
	   role="tab"
	   tabindex="-1"
	   href="#ssh"
	   aria-expanded="false">
	  <span class="fa fa-key"></span>
	  SSH Key
	</a>
      </li>
    </ul>
  </li>

  <li role="presentation">
    <a aria-controls="groups"
       data-toggle="tab"
       id="groups-tab"
       role="tab"
       href="#ms-groups"
       title="Group/s User Belongs to"
       aria-expanded="false">
      <span class="fa fa-group"></span>
    </a>
  </li>
</ul>
</nav>', );



has_field 'person_avatar' => ( type => 'Upload',
			       label => 'User Photo ID',
			       label_class => [ 'col-xs-2', ],
			       element_wrapper_class => [ 'col-xs-2', 'col-lg-3', ],
			       element_class => [ 'btn', 'btn-default', 'btn-sm', ],
			       max_size => '50000' );

has_field 'person_office' => ( type => 'Select',
			       label => 'Office',
			       label_class => [ 'col-xs-2' ],
			       empty_select => '--- Choose an Organization ---',
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
							  placeholder => '123@pbx0.ibs, +380xxxxxxxxx' });

has_field 'person_telcomment' => ( type => 'Display',
				   html => '<small class="text-muted col-xs-offset-2"><em>' .
				   'comma or space delimited if many, international format for tel.</em></small>',
				 );

has_block 'group_person' => ( tag => 'div',
			      render_list => [ 'person_office',
					       'person_title',
					       'person_avatar',
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

# need to be moved to rep # has_field 'rm-duplicate' => ( type => 'Display',
# need to be moved to rep # 			      html => '<div class="col-xs-12 rm-duplicate hidden"><div class="col-xs-1">' .
# need to be moved to rep # 			      '<a class="btn btn-danger btn-xs" href="#">' .
# need to be moved to rep # 			      '<span class="fa fa-trash-o"></span> Delete this section</a>' .
# need to be moved to rep # 			      '</div></div>',
# need to be moved to rep # 			    );

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
                         # setup_for_js => 1,
                         do_wrapper => 1,
			 wrapper_attr => { class => 'no-has-error' },
			 wrap_repeatable_element_method => \&wrap_account_elements,
                       );

# has_field 'account.rm-duplicate' => ( type => 'Display',
# 				      html => '<div class="col-xs-12 rm-duplicate hidden"><div class="col-xs-1">' .
# 				      '<a class="btn btn-danger btn-xs" href="#">' .
# 				      '<span class="fa fa-trash-o"></span> Delete this section</a>' .
# 				      '</div></div>',
# 				    );

has_field 'account.rm-duplicate' => ( type => 'Display',
				      html => '<div class="col-xs-offset-1 rm-duplicate hidden"><a class="btn btn-link text-danger" href="#" title="Delete this section">' .
				      '<span class="fa fa-trash text-danger">Delete this section</span></a></div>',
				    );

has_field 'account.associateddomain' => ( type => 'Select',
					  label => 'Domain Name',
					  label_class => [ 'col-xs-2', ],
					  empty_select => '--- Choose Domain ---',
					  element_wrapper_class => [ 'col-xs-10', 'col-lg-5', ],
					  element_class => [ 'input-sm', ],
					  options_method => \&associateddomains,
					  element_attr => { 'data-name' => 'associateddomain',
							    'data-group' => 'account', },
					  required => 0 );

has_field 'account.authorizedservice' => ( type => 'Select',
					   label => 'Service', label_class => [ 'required' ],
					   label_class => [ 'col-xs-2', ],
					   empty_select => '--- Choose Service ---',
					   element_wrapper_class => [ 'col-xs-10', 'col-lg-5', ],
					   element_class => [ 'input-sm', ],
					   options_method => \&authorizedservice,
					   element_attr => { 'data-name' => 'authorizedservice',
							     'data-group' => 'account', },
					   required => 0,
					 );

has_field 'account.login' => ( apply => [ NoSpaces, NotAllDigits, Printable ],
			       label => 'Login',
			       do_id => 'no',
			       label_class => [ 'col-xs-2', ],
			       element_wrapper_class => [ 'col-xs-10', 'col-lg-5', ],
			       element_class => [ 'input-sm', ],
			       element_attr => { placeholder => 'john.doe',
						 'autocomplete' => 'off',
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
						     'autocomplete' => 'off',
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
						     'autocomplete' => 'off',
						     'data-name' => 'password2',
						     'data-group' => 'account', },
				 );

has_field 'account.radiusgroupname' => ( apply => [ NoSpaces, NotAllDigits, Printable ],
					 label => 'RADIUS Group Name',
					 do_id => 'no',
					 label_class => [ 'col-xs-2', ],
					 wrapper_class => [  'hidden', '8021x', 'relation', ],
					 element_wrapper_class => [ 'col-xs-10', 'col-lg-5', ],
					 element_class => [ 'input-sm', ],
					 element_attr => { placeholder => 'ip-phone, wifi-123',
							   'autocomplete' => 'off',
							   'data-name' => 'radiusgroupname',
							   'data-group' => 'account', },
				       );

has_field 'account.radiustunnelprivategroup' => ( apply => [ NoSpaces, Printable ],
						  label => 'RADIUS Tunnel Private Group',
						  wrapper_class => [  'hidden', '8021x', 'relation', ],
						  do_id => 'no',
						  label_class => [ 'col-xs-2', ],
						  element_wrapper_class => [ 'col-xs-10', 'col-lg-5', ],
						  element_class => [ 'input-sm', ],
						  element_attr => { placeholder => 'VLAN this 802.1x authenticates to',
								    'autocomplete' => 'off',
								    'data-name' => 'radiustunnelprivategroup',
								    'data-group' => 'account', },
						);

# has_field 'account.pwdcomment' => ( type => 'Display',
# 				     html => '<small class="text-muted col-xs-offset-2"><em>' .
# 				     'leave empty password fields to autogenerate password</em></small><p>&nbsp;</p>',
# 				   );

sub wrap_account_elements {
  my ( $self, $input, $subfield ) = @_;
  my $output = sprintf('%s%s%s', ! $subfield ? qq{\n<div class="duplicate">} : qq{\n<div class="duplicated">},
		       $input,
		       qq{</div>});
}

    
# has_block 'group_auth' => ( tag => 'div',
# 			    render_list => [ 'rm-duplicate',
# 					     # 'account.associateddomain',
# 					     # 'account.authorizedservice',
# 					     # 'account.login',
# 					     # 'account.password1',
# 					     # 'account.password2',
# 					     # 'account.radiusgroupname',
# 					     # 'account.radiustunnelprivategroup',
# 					     'account',
# 					     # 'account.pwdcomment',
# 					   ],
# 			    # class => [ 'duplicate' ],
# 			  );

has_block 'auth' => ( tag => 'fieldset',
		      label => '<a href="#" class="btn btn-link btn-lg" data-duplicate="duplicate"><span class="fa fa-plus-circle text-success"></span></a>Service Account&nbsp;<small class="text-muted"><em>(' .
		      'leave empty login and password fields to autogenerate them all)</em></small>',
		      
		      # '<div class="col-xs-12"><div class="col-xs-1">' .
		      # '<a href="#" class="btn btn-success btn-xs" data-duplicate="duplicate">' .
		      # '<span class="fa fa-plus-circle rm-duplicate"></span> Duplicate this section</a>' .
		      # '</div></div>',
		      
		      # label_class => [ 'col-xs-offset-2', 'text-left'],
		      render_list => [ 'account', ],
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
			       #setup_for_js => 1,
			       do_wrapper => 1,
			       wrap_repeatable_element_method => \&wrap_loginless_ssh_elements,
			       #tags => { controls_div => 1 },
			       # init_contains => { wrapper_attr => { class => ['hfh', 'repinst'] } },
			     );

has_field 'loginless_ssh.rm-duplicate' => ( type => 'Display',
					    html => '<div class="col-xs-12 rm-duplicate hidden"><div class="col-xs-1">' .
					    '<a class="btn btn-danger btn-xs" href="#">' .
					    '<span class="fa fa-trash-o"></span> Delete this section</a>' .
					    '</div></div>',
					  );

has_field 'loginless_ssh.associateddomain' => ( type => 'Select',
						label => 'Domain Name',
						label_class => [ 'col-xs-2', ],
						empty_select => '--- Choose Domain ---',
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


sub wrap_loginless_ssh_elements {
  my ( $self, $input, $subfield ) = @_;
  my $output = sprintf('%s%s%s', ! $subfield ? qq{\n<div class="duplicate">} : qq{\n<div class="duplicated">},
		       $input,
		       qq{</div>});
}

# has_block 'group_ssh' => ( tag => 'div',
# 			   render_list => [ 'rm-duplicate',
# 					    'loginless_ssh',
# 					    'loginless_ssh.associateddomain',
# 					    'loginless_ssh.key', ],
# 			   class => [ 'duplicate' ],
# 			 );

has_block 'ssh' => ( tag => 'fieldset',
		     label => 'SSH Key&nbsp;<small class="text-muted"><em>()</em></small>' .
		      
		     '<div class="col-xs-12"><div class="col-xs-1">' .
		     '<a href="#" class="btn btn-success btn-xs" data-duplicate="duplicate">' .
		     '<span class="fa fa-plus-circle rm-duplicate"></span> Duplicate this section</a>' .
		     '</div></div>',
		      
		     # label_class => [ 'col-xs-offset-2', 'text-left'],
		     render_list => [ 'loginless_ssh', ],
		     class => [ 'tab-pane', 'fade', ],
		     attr => { id => 'ssh',
			       'aria-labelledby' => "ssh-tab",
			       role => "tabpanel",
			     },
		   );

#=====================================================================

has_field 'loginless_ovpn' => ( type => 'Repeatable',
				#setup_for_js => 1,
				do_wrapper => 1,
				wrap_repeatable_element_method => \&wrap_loginless_ovpn_elements,
				#tags => { controls_div => 1 },
				# init_contains => { wrapper_attr => { class => ['hfh', 'repinst'] } },
			      );

has_field 'loginless_ovpn.rm-duplicate' => ( type => 'Display',
					     html => '<div class="col-xs-12 rm-duplicate hidden"><div class="col-xs-1">' .
					     '<a class="btn btn-danger btn-xs" href="#">' .
					     '<span class="fa fa-trash-o"></span> Delete this section</a>' .
					     '</div></div>',
					   );

has_field 'loginless_ovpn.associateddomain' => ( type => 'Select',
						 label => 'Domain Name',
						 label_class => [ 'col-xs-2', ],
						 empty_select => '--- Choose Domain ---',
						 element_wrapper_class => [ 'col-xs-10', 'col-lg-5', ],
						 element_class => [ 'input-sm', ],
						 options_method => \&associateddomains,
						 element_attr => { 'data-name' => 'associateddomain',
								   'data-group' => 'loginless_ovpn', },
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

sub wrap_loginless_ovpn_elements {
  my ( $self, $input, $subfield ) = @_;
  my $output = sprintf('%s%s%s', ! $subfield ? qq{\n<div class="duplicate">} : qq{\n<div class="duplicated">},
		       $input,
		       qq{</div>});
}

# has_block 'group_ovpn' => ( tag => 'div',
# 			    render_list => [ 'rm-duplicate',
# 					     'loginless_ovpn',
# 					     'loginless_ovpn.associateddomain',
# 					     'loginless_ovpn.device',
# 					     'loginless_ovpn.ip',
# 					     'loginless_ovpn.cert',
# 					     # 'loginless_ovpn.comment',
# 					   ],
# 			    class => [ 'duplicate' ],
# 			  );

has_block 'ovpn' => ( tag => 'fieldset',
		      label => 'OpenVPN configuration&nbsp;<small class="text-muted"><em>()</em></small>' .
		      
		      '<div class="col-xs-12"><div class="col-xs-1">' .
		      '<a href="#" class="btn btn-success btn-xs" data-duplicate="duplicate">' .
		      '<span class="fa fa-plus-circle rm-duplicate"></span> Duplicate this section</a>' .
		      '</div></div>',
		      
		      # label_class => [ 'col-xs-offset-2', 'text-left'],
		      render_list => [ 'loginless_ovpn', ],
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
			   element_class => [ 'btn', 'btn-danger', 'btn-block', ],
			   element_wrapper_class => [ 'col-xs-12', ],
			   wrapper_class => [ 'col-xs-2' ],
			   # value => 'Reset All'
			 );

has_field 'aux_submit' => ( type => 'Submit',
			    element_class => [ 'btn', 'btn-success', 'btn-block', ],
			    # element_wrapper_class => [ 'col-xs-12', ],
			    wrapper_class => [ 'col-xs-10', ], # 'pull-right' ],
			    value => 'Submit' );

has_block 'submitit' => ( tag => 'fieldset',
			  render_list => [ 'groupspace', 'aux_reset', 'aux_submit'],
			  class => [ 'container-fluid', ]
			);


sub build_render_list {[ 'person_givenname', 'person_sn', 'nav', 'person', 'auth', 'ssh', 'ovpn', 'groupsselect', 'submitit' ]}

sub validate {
  my $self = shift;
  my ( $element, $field, $ldap_crud, $mesg, $autologin, $loginpfx, $logintmp );
  # p $self->value;
  # p $self->field('account.0');

  $ldap_crud = $self->ldap_crud;
  # my $mesg =
  #   $ldap_crud->search({
  # 			scope => 'one',
  # 			filter => '(uid=' .
  # 			$self->utf2lat({ to_translate => $self->field('givenname')->value }) . '.' .
  # 			$self->utf2lat({ to_translate => $self->field('sn')->value }) . ')',
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

  $autologin = lc($self->utf2lat( $self->field('person_givenname')->value ) . '.' .
		  $self->utf2lat( $self->field('person_sn')->value ));


  my $i = 0;
  foreach $element ( $self->field('account')->fields ) {
    if ( ! defined $element->field('authorizedservice')->value &&
	 ! defined $element->field('associateddomain')->value ) {
      $element->field('associateddomain')->add_error('Domain Name is mandatory!');
      $element->field('authorizedservice')->add_error('Service is mandatory!');
    } elsif ( defined $element->field('authorizedservice')->value &&
	      ! defined $element->field('associateddomain')->value ) {
      $element->field('associateddomain')->add_error('Domain Name is mandatory!');
    } elsif ( defined $element->field('associateddomain')->value &&
	      ! defined $element->field('authorizedservice')->value ) {
      $element->field('authorizedservice')->add_error('Service is mandatory!');
    }

    if ( ( defined $element->field('password1')->value &&
	   ! defined $element->field('password2')->value ) ||
	 ( defined $element->field('password2')->value &&
	   ! defined $element->field('password1')->value ) ) {
      $element->field('password1')->add_error('Both or none passwords have to be defined!');
      $element->field('password2')->add_error('Both or none passwords have to be defined!');
    }

    $element->field('login')->add_error('MAC address is mandatory!')
      if $element->field('authorizedservice')->value =~ /^802.1x-mac$/ &&
      ! defined $element->field('login')->value;

    $element->field('login')->add_error('MAC address is not valid!')
      if $element->field('authorizedservice')->value =~ /^802.1x-mac$/ &&
      ! $self->macnorm({ mac => $element->field('login')->value });

    if ( $element->field('authorizedservice')->value !~ /^802.1x-mac$/) {
      if ( ! defined $element->field('login')->value ) {
	$logintmp = $autologin;
	$loginpfx = 'Login (autogenerated, since empty)';
      } else {
	$logintmp = $element->field('login')->value;
	$loginpfx = 'Login';
      }

      $mesg =
	$ldap_crud->search({
			    filter => '(&(authorizedService=' .
			    $element->field('authorizedservice')->value . '@' . $element->field('associateddomain')->value .
			    ')(uid=' . $logintmp . '@' . $element->field('associateddomain')->value .'))',
			    base => $ldap_crud->{cfg}->{base}->{acc_root},
			    attrs => [ 'uid' ],
			   });
      $element->field('login')->add_error($loginpfx . ' <mark>' . $logintmp . '</mark> is not available!')
	if ($mesg->count);
    }

    $i++;
  }

  $i = 0;
  foreach $element ( $self->field('loginless_ssh')->fields ) {
    if ( defined $element->field('associateddomain')->value &&
	 ! defined $element->field('key')->value ) {
      $element->field('key')->add_error('<span class="fa-li fa fa-key"></span>Key field have to be defined!');
    } elsif ( defined $element->field('key')->value &&
	      ! defined $element->field('associateddomain')->value ) {
      $element->field('associateddomain')->add_error('Domain field have to be defined!');
    }

    $i++;
  }

  $i = 0;
  foreach $element ( $self->field('loginless_ovpn')->fields ) {
    if ( defined $element->field('associateddomain')->value &&
	 ! defined $element->field('cert')->value &&
	 ! defined $element->field('device')->value &&
	 ! defined $element->field('ip')->value ) {
      $element->field('cert')->add_error('Cert field have to be defined!');
      $element->field('device')->add_error('Device field have to be defined!');
      $element->field('ip')->add_error('IP field have to be defined!');
    } elsif ( ! defined $element->field('associateddomain')->value &&
	      defined $element->field('cert')->value &&
	      ! defined $element->field('device')->value &&
	      ! defined $element->field('ip')->value ) {
      $element->field('associateddomain')->add_error('Domain field have to be defined!');
      $element->field('device')->add_error('Device field have to be defined!');
      $element->field('ip')->add_error('IP field have to be defined!');
    } elsif ( ! defined $element->field('associateddomain')->value &&
	      ! defined $element->field('cert')->value &&
	      defined $element->field('device')->value &&
	      ! defined $element->field('ip')->value ) {
      $element->field('cert')->add_error('Cert field have to be defined!');
      $element->field('associateddomain')->add_error('Domain field have to be defined!');
      $element->field('ip')->add_error('IP field have to be defined!');
    } elsif ( ! defined $element->field('associateddomain')->value &&
	      ! defined $element->field('cert')->value &&
	      ! defined $element->field('device')->value &&
	      defined $element->field('ip')->value ) {
      $element->field('cert')->add_error('Cert field have to be defined!');
      $element->field('device')->add_error('Device field have to be defined!');
      $element->field('associateddomain')->add_error('Domain field have to be defined!');
    }

    $i++;
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

  $self->add_form_error('<div class="alert alert-danger" role="alert"><i class="fa fa-exclamation-circle"></i> Form contains error/s! Check all tabs!</div>') if $self->has_error_fields;


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

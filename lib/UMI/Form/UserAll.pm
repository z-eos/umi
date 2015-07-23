# -*- mode: cperl -*-
#

package UMI::Form::UserAll;

use HTML::FormHandler::Moose;
BEGIN { extends 'UMI::Form::LDAP'; with 'Tools'; }

use HTML::FormHandler::Types ('NoSpaces', 'WordChars', 'NotAllDigits', 'Printable', 'StrongPassword' );

use Data::Printer;

# has '+error_message' => ( default => 'There were errors in your form.' );has '+item_class' => ( default =>'UserAll' );
has '+enctype' => ( default => 'multipart/form-data');
has 'namesake' => ( is => 'rw', );
has 'autologin' => ( is => 'rw', );
has 'add_svc_acc' => ( is => 'rw', );

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

has_field 'add_svc_acc' => ( type => 'Hidden', );

######################################################################
#== PERSONAL DATA ====================================================
######################################################################
has_field 'person_givenname'
  => ( apply => [ NoSpaces ],
       label => 'FName',
       label_class => [ 'col-xs-1', ],
       element_wrapper_class => [ 'col-xs-11', 'col-lg-5', ],
       element_class => [ 'input-sm', ],
       element_attr => { placeholder => 'John' },
       required => 1 );

has_field 'person_sn'
  => ( apply => [ NoSpaces ],
       label => 'LName',
       label_class => [ 'col-xs-1', ],
       element_wrapper_class => [ 'col-xs-11', 'col-lg-5', ],
       element_class => [ 'input-sm', ],
       element_attr => { placeholder => 'Doe' },
       required => 1 );

has_field 'person_namesake'
  => ( type => 'Checkbox',
       label => 'namesake',
       label_class => [ 'col-xs-1', ],
       element_attr => { title => 'This new user has the same name/s as of some existent one. Check it if sure this new user does not exist and is not that existent one' },
       # element_wrapper_class => [ 'col-xs-offset-1', 'col-xs-11', 'col-lg-5', 'text-muted', ],
     );

has_field 'person_simplified'
  => ( type => 'Checkbox',
       label => 'simplified',
       label_class => [ 'col-xs-1', ],
       element_attr => { title => 'When checked, this checkbox causes user account been created in a simplified manner. Only Email and XMPP services will be created for FQDN choosen with Domain Name field in section Person bellow.',
		       },
       # element_wrapper_class => [ 'col-xs-offset-1', 'col-xs-11', 'col-lg-5', 'text-muted' ],
       # wrapper_class => [],
     );

has_field 'person_avatar'
  => ( type => 'Upload',
       label => 'User Photo ID',
       label_class => [ 'col-xs-2', ],
       element_wrapper_class => [ 'col-xs-2', 'col-lg-3', ],
       element_class => [ 'btn', 'btn-default', 'btn-sm', ],
       max_size => '50000' );

has_field 'person_org'
  => ( type => 'Select',
       label => 'Organization',
       label_class => [ 'col-xs-2' ],
       empty_select => '--- Choose an Organization ---',
       element_wrapper_class => [ 'col-xs-10', 'col-lg-5', ],
       element_class => [ 'input-sm', ],
       options_method => \&offices,
       required => 1 );

has_field 'person_title'
  => ( label => 'Position',
       label_class => [ 'col-xs-2', ],
       element_wrapper_class => [ 'col-xs-10', 'col-lg-5', ],
       element_class => [ 'input-sm', ],
       element_attr => { placeholder => 'manager' },
       required => 1 );

has_field 'person_office'
  => ( type => 'Select',
       label => 'Office',
       label_class => [ 'col-xs-2' ],
       empty_select => '--- Choose an Office ---',
       element_wrapper_class => [ 'col-xs-10', 'col-lg-5', ],
       element_class => [ 'input-sm', ],
       options_method => \&offices,
       required => 1 );

has_field 'person_telephonenumber'
  => ( apply => [ NoSpaces ],
       label => 'SIP/Cell',
       label_class => [ 'col-xs-2', ],
       element_wrapper_class => [ 'col-xs-10', 'col-lg-5', ],
       element_class => [ 'input-sm', ],
       wrapper_attr => { id => 'items' },
       element_attr => { name => 'telephonenumber\[\]',
			 placeholder => '123@pbx0.umi, +380xxxxxxxxx' });

# has_field 'person_telcomment'
#   => ( type => 'Display',
#        html => '<small class="text-muted col-xs-offset-2"><em>' .
#        'comma or space delimited if many, international format for tel.</em></small>',
#      );

has_field 'person_login'
  => ( apply => [ NoSpaces, NotAllDigits, Printable ],
       label => 'Login',
       label_class => [ 'col-xs-2', ],
       element_wrapper_class => [ 'col-xs-10', 'col-lg-5', ],
       element_class => [ 'input-sm', ],
       element_attr => { placeholder => 'john.doe', },
     );

has_field 'person_associateddomain'
  => ( type => 'Select',
       wrapper_attr => { id => 'simplified', },
       wrapper_class => [ 'simplified', ],
       label => 'Domain Name',
       label_class => [ 'col-xs-2', 'required', ],
       empty_select => '--- Choose Domain ---',
       # element_attr => { disabled => 'dissabled', },
       element_wrapper_class => [ 'col-xs-10', 'col-lg-5', ],
       element_class => [ 'input-sm', ],
       options_method => \&associateddomains,
       required => 0 );

has_field 'person_password1'
  => ( type => 'Password',
       label => 'Password',
       label_class => [ 'col-xs-2', ],
       element_wrapper_class => [ 'col-xs-10', 'col-lg-5', ],
       element_class => [ 'input-sm', ],
       ne_username => 'login',
       apply => [ NoSpaces, NotAllDigits, Printable, StrongPassword ],
       element_attr => { placeholder => 'Password',
			 'autocomplete' => 'off', },
     );

has_field 'person_password2'
  => ( type => 'Password',
       label => '',
       label_class => [ 'col-xs-2', ],
       element_wrapper_class => [ 'col-xs-10', 'col-lg-5', ],
       element_class => [ 'input-sm', ],
       ne_username => 'login',
       apply => [ NoSpaces, NotAllDigits, Printable, StrongPassword ],
       element_attr => { placeholder => 'Confirm Password',
			 'autocomplete' => 'off', },
     );


has_block 'group_person'
  => ( tag => 'div',
       render_list => [ 'person_org',
			'person_title',
			'person_office',
			'person_avatar',
			'person_telephonenumber',
			# 'person_telcomment',
			'person_associateddomain',
			'person_login',
			'person_password1',
			'person_password2',
		      ],
       attr => { id => 'group_person', },
     );

has_block 'person'
  => ( tag => 'fieldset',
       label => 'New User Personal Data',
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
has_field 'account'
  => ( type => 'Repeatable',
       # setup_for_js => 1,
       do_wrapper => 1,
       wrapper_attr => { class => 'no-has-error' },
       wrap_repeatable_element_method => \&wrap_account_elements,
     );

has_field 'account.rm-duplicate'
  => ( type => 'Display',
       html => '<div class="col-xs-offset-1 rm-duplicate hidden">' .
       '<a href="#" class="btn btn-danger btn-sm" title="Delete this section"><span class="fa fa-trash-o fa-lg"></span></a></div>',
     );

has_field 'account.associateddomain'
  => ( type => 'Select',
       label => 'Domain Name',
       label_class => [ 'col-xs-2', 'required', ],
       empty_select => '--- Choose Domain ---',
       element_wrapper_class => [ 'col-xs-10', 'col-lg-5', ],
       element_class => [ 'input-sm', ],
       options_method => \&associateddomains,
       element_attr => { 'data-name' => 'associateddomain',
			 'data-group' => 'account', },
       required => 0 );

has_field 'account.authorizedservice'
  => ( type => 'Select',
       label => 'Service', label_class => [ 'required' ],
       label_class => [ 'col-xs-2', 'required', ],
       empty_select => '--- Choose Service ---',
       element_wrapper_class => [ 'col-xs-10', 'col-lg-5', ],
       element_class => [ 'input-sm', ],
       options_method => \&authorizedservice,
       element_attr => { 'data-name' => 'authorizedservice',
			 'data-group' => 'account', },
       required => 0,
     );

has_field 'account.login'
  => ( apply => [ NoSpaces, NotAllDigits, Printable ],
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

has_field 'account.password1'
  => ( type => 'Password',
       minlength => 7, maxlength => 128,
       label => 'Password',
       label_class => [ 'col-xs-2', ],
       wrapper_class => [  'hidden', 'passw', '8021xeaptls', 'relation', ],
       element_wrapper_class => [ 'col-xs-10', 'col-lg-5', ],
       element_class => [ 'input-sm', ],
       ne_username => 'login',
       apply => [ NoSpaces, NotAllDigits, Printable, StrongPassword ],
       element_attr => { placeholder => 'Password',
			 'autocomplete' => 'off',
			 'data-name' => 'password1',
			 'data-group' => 'account', },
     );

has_field 'account.password2'
  => ( type => 'Password',
       minlength => 7, maxlength => 128,
       label => '',
       label_class => [ 'col-xs-2', ],
       wrapper_class => [  'hidden', 'passw', '8021xeaptls', 'relation', ],
       element_wrapper_class => [ 'col-xs-10', 'col-lg-5', ],
       element_class => [ 'input-sm', ],
       ne_username => 'login',
       apply => [ NoSpaces, NotAllDigits, Printable, StrongPassword ],
       element_attr => { placeholder => 'Confirm Password',
			 'autocomplete' => 'off',
			 'data-name' => 'password2',
			 'data-group' => 'account', },
     );

has_field 'account.radiusgroupname'
  => ( type => 'Select',
       label => 'RADIUS Group Name',
       do_id => 'no',
       label_class => [ 'col-xs-2', 'required', ],
       wrapper_class => [  'hidden', '8021x', '8021xeaptls', 'relation', ],
       element_wrapper_class => [ 'col-xs-10', 'col-lg-5', ],
       element_class => [ 'input-sm', ],
       element_attr => { 'data-name' => 'radiusgroupname',
			 'data-group' => 'account', },
       empty_select => '--- Choose RADIUS Group ---',
       options_method => \&radprofile,
     );

has_field 'account.radiustunnelprivategroupid'
  => ( type => 'Select',
       label => 'RADIUS Tunnel Private Group',
       wrapper_class => [  'hidden', '8021x', '8021xeaptls', 'relation', ],
       do_id => 'no',
       label_class => [ 'col-xs-2', 'required', ],
       element_wrapper_class => [ 'col-xs-10', 'col-lg-5', ],
       element_class => [ 'input-sm', ],
       element_attr => { placeholder => 'VLAN this 802.1x authenticates to',
			 'autocomplete' => 'off',
			 'data-name' => 'radiustunnelprivategroupid',
			 'data-group' => 'account', },
       options => [{ value => '', label => '--- Choose VLAN ---'},
		   { value => '3', label => 'Voice (VLAN3)'},
		   { value => '3498', label => 'Guest (VLAN3498)'},
		   { value => '3499', label => 'Bootp (VLAN3499)'}, ],
     );

has_field 'account.userCertificate'
  => ( type => 'Upload',
       label => 'Cert (.DER)',
       wrapper_class => [  'hidden', '8021xeaptls', 'relation', ],
       do_id => 'no',
       label_class => [ 'col-xs-2', 'required', ],
       element_wrapper_class => [ 'col-xs-2', 'col-lg-3', ],
       element_class => [ 'btn', 'btn-default', 'btn-sm',],
       element_attr => {
			'data-group' => 'account',
			'data-name' => 'userCertificate'
		       },
     );

sub wrap_account_elements {
  my ( $self, $input, $subfield ) = @_;
  my $output = sprintf('%s%s%s', ! $subfield ? qq{\n<div class="duplicate">} : qq{\n<div class="duplicated">},
		       $input,
		       qq{</div>});
}

has_block 'auth'
  => ( tag => 'fieldset',
       label => '<a href="#" class="btn btn-success btn-sm" data-duplicate="duplicate" title="Duplicate this section">' .
       '<span class="fa fa-plus-circle fa-lg"></span></a>&nbsp;' .
       'Login And Password Dependent Service&nbsp;<small class="text-muted"><em>(' .
       'login and password fields are autogenerated if empty, login will be the same as master account login)</em></small>',
       render_list => [ 'account', ],
       class => [ 'tab-pane', 'fade', ],
       attr => { id => 'auth',
		 'aria-labelledby' => "auth-tab",
		 role => "tabpanel", },
     );

######################################################################
#== SERVICES WITHOUT LOGIN ===========================================
######################################################################

#=== SSH =============================================================

has_field 'loginless_ssh'
  => ( type => 'Repeatable',
       #setup_for_js => 1,
       do_wrapper => 1,
       wrap_repeatable_element_method => \&wrap_loginless_ssh_elements,
       #tags => { controls_div => 1 },
       # init_contains => { wrapper_attr => { class => ['hfh', 'repinst'] } },
     );

has_field 'loginless_ssh.rm-duplicate'
  => ( type => 'Display',
       html => '<div class="col-xs-offset-1 rm-duplicate hidden">' .
       '<a href="#" class="btn btn-danger btn-sm" title="Delete this section"><span class="fa fa-trash-o fa-lg"></span></a></div>',
     );

has_field 'loginless_ssh.associateddomain'
  => ( type => 'Select',
       label => 'Domain Name',
       label_class => [ 'col-xs-2', 'required', ],
       empty_select => '--- Choose Domain ---',
       element_wrapper_class => [ 'col-xs-10', 'col-lg-5', ],
       element_class => [ 'input-sm', ],
       options_method => \&associateddomains,
       element_attr => {
			'data-name' => 'associateddomain',
			'data-group' => 'loginless_ssh',
		       },
     );

has_field 'loginless_ssh.key'
  => ( type => 'TextArea',
       label => 'SSH Pub Key',
       label_class => [ 'col-xs-2', 'required', ],
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

has_block 'ssh'
  => ( tag => 'fieldset',
       label => '<a href="#" class="btn btn-success btn-sm" data-duplicate="duplicate" title="Duplicate this section">' .
       '<span class="fa fa-plus-circle fa-lg"></span></a>&nbsp;' .
       'SSH Key&nbsp;<small class="text-muted"><em>( <span class="fa fa-ellipsis-h"></span> )</em></small>',
       render_list => [ 'loginless_ssh', ],
       class => [ 'tab-pane', 'fade', ],
       attr => { id => 'ssh',
		 'aria-labelledby' => "ssh-tab",
		 role => "tabpanel", },
     );

#=== OpenVPN =========================================================

has_field 'loginless_ovpn'
  => ( type => 'Repeatable',
       # setup_for_js => 1,
       # num_when_empty => 0,
       do_wrapper => 1,
       wrap_repeatable_element_method => \&wrap_loginless_ovpn_elements,
       # tags => { controls_div => 1 },
       # init_contains => { wrapper_attr => { class => ['hfh', 'repinst'] } },
     );

has_field 'loginless_ovpn.rm-duplicate'
  => ( type => 'Display',
       html => '<div class="col-xs-offset-1 rm-duplicate hidden">' .
       '<a href="#" class="btn btn-danger btn-sm" title="Delete this section"><span class="fa fa-trash-o fa-lg"></span></a></div>',
     );

has_field 'loginless_ovpn.status'
  => ( type => 'Select',
       label => 'Account status',
       label_class => [ 'col-xs-2', ],
       element_wrapper_class => [ 'col-xs-10', 'col-lg-5', ],
       element_class => [ 'input-sm', ],
       element_attr => { placeholder => 'Initial state of the account',
			 'autocomplete' => 'off',
			 'data-name' => 'status',
			 'data-group' => 'loginless_ovpn', },
       options => [{ value => '', label => '--- Choose State ---'},
		   { value => 'active', label => 'Active'},
		   { value => 'blocked', label => 'Blocked'},
		   { value => 'revoked', label => 'Revoked'}, ],
     );

has_field 'loginless_ovpn.associateddomain'
  => ( type => 'Select',
       label => 'FQDN',
       label_class => [ 'col-xs-2', 'required', ],
       empty_select => '--- Choose Domain ---',
       element_wrapper_class => [ 'col-xs-10', 'col-lg-5', ],
       element_class => [ 'input-sm', ],
       options_method => \&associateddomains,
       element_attr => { 'data-name' => 'associateddomain',
			 'data-group' => 'loginless_ovpn', },
     );

has_field 'loginless_ovpn.userCertificate'
  => ( type => 'Upload',
       label => 'Cert (.DER)',
       label_class => [ 'col-xs-2', 'required', ],
       element_wrapper_class => [ 'col-xs-2', 'col-lg-3', ],
       element_class => [ 'btn', 'btn-default', 'btn-sm',],
       element_attr => {
			'data-name' => 'cert',
			'data-group' => 'loginless_ovpn',
		       },
     );

has_field 'loginless_ovpn.ifconfigpush'
  => ( apply => [ Printable ],
       label => 'Ifconfig',
       label_class => [ 'col-xs-2', 'required', ],
       element_wrapper_class => [ 'col-xs-10', 'col-lg-5', ],
       element_class => [ 'input-sm', ],
       element_attr => { placeholder => '10.0.97.2 10.0.97.1, 10.13.83.192 10.0.97.1',
			 'data-name' => 'ifconfigpush',
			 'data-group' => 'loginless_ovpn', },
     );

has_field 'loginless_ovpn.devtype'
  => ( apply => [ NoSpaces, Printable ],
       label => 'Device Type',
       label_class => [ 'col-xs-2', ],
       element_wrapper_class => [ 'col-xs-10', 'col-lg-5', ],
       element_class => [ 'input-sm', ],
       element_attr => { placeholder => 'notebook, netbook, smartphone',
			 'data-name' => 'dev',
			 'data-group' => 'loginless_ovpn', },
     );

has_field 'loginless_ovpn.devmake'
  => ( apply => [ Printable ],
       label => 'Device Maker',
       label_class => [ 'col-xs-2', ],
       element_wrapper_class => [ 'col-xs-10', 'col-lg-5', ],
       element_class => [ 'input-sm', ],
       element_attr => { placeholder => 'HP, Dell, Asus, Lenovo',
			 'data-name' => 'devmake',
			 'data-group' => 'loginless_ovpn', },
     );

has_field 'loginless_ovpn.devmodel'
  => ( apply => [ Printable ],
       label => 'Device Model',
       label_class => [ 'col-xs-2', ],
       element_wrapper_class => [ 'col-xs-10', 'col-lg-5', ],
       element_class => [ 'input-sm', ],
       element_attr => { placeholder => 'Pavilion dm1',
			 'data-name' => 'devmodel',
			 'data-group' => 'loginless_ovpn', },
     );

has_field 'loginless_ovpn.devos'
  => ( apply => [ Printable ],
       label => 'OS',
       label_class => [ 'col-xs-2', ],
       element_wrapper_class => [ 'col-xs-10', 'col-lg-5', ],
       element_class => [ 'input-sm', ],
       element_attr => { placeholder => 'xNIX, MacOS, Android, Windows',
			 'data-name' => 'devos',
			 'data-group' => 'loginless_ovpn', },
     );

has_field 'loginless_ovpn.devosver'
  => ( apply => [ Printable ],
       label => 'OS version',
       label_class => [ 'col-xs-2', ],
       element_wrapper_class => [ 'col-xs-10', 'col-lg-5', ],
       element_class => [ 'input-sm', ],
       element_attr => { placeholder => '1.2.3',
			 'data-name' => 'devosv',
			 'data-group' => 'loginless_ovpn', },
     );

sub wrap_loginless_ovpn_elements {
  my ( $self, $input, $subfield ) = @_;
  my $output = sprintf('%s%s%s', ! $subfield ? qq{\n<div class="duplicate">} : qq{\n<div class="duplicated">},
		       $input,
		       qq{</div>});
}

has_block 'ovpn'
  => ( tag => 'fieldset',
       label => '<a href="#" class="btn btn-success btn-sm" data-duplicate="duplicate" title="Duplicate this section">' .
       '<span class="fa fa-plus-circle fa-lg"></span></a>&nbsp;' .
       'OpenVPN configuration&nbsp;<small class="text-muted"><em>( <span class="fa fa-ellipsis-h"></span> )</em></small>',
       render_list => [ 'loginless_ovpn', ],
       class => [ 'tab-pane', 'fade', ],
       attr => { id => 'ovpn',
		 'aria-labelledby' => "ovpn-tab",
		 role => "tabpanel",
	       },
     );

#=== GROUPS ==========================================================

has_field 'groups'
  => ( type => 'Multiple',
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
				   sizelimit => 0,
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

has_field 'groupspace'
  => ( type => 'Display',
       html => '<p>&nbsp;</p>',
     );


has_block 'groupsselect'
  => ( tag => 'fieldset',
       label => 'Groups user belongs to',
       render_list => [ 'groups', ], # 'groupspace', ],
       class => [ 'tab-pane', 'fade', ],
       attr => { id => 'groups',
		 'aria-labelledby' => "groups-tab",
		 role => "tabpanel",
	       },
     );

######################################################################
#== REST OF THE FORM =================================================
######################################################################

has_field 'aux_reset'
  => ( type => 'Reset',
       element_class => [ 'btn', 'btn-danger', 'btn-block', ],
       element_wrapper_class => [ 'col-xs-12', ],
       wrapper_class => [ 'col-xs-4' ],
       # value => 'Reset All'
     );

has_field 'aux_submit'
  => ( type => 'Submit',
       element_class => [ 'btn', 'btn-success', 'btn-block', ],
       # element_wrapper_class => [ 'col-xs-12', ],
       wrapper_class => [ 'col-xs-8', ], # 'pull-right' ],
       value => 'Submit' );




######################################################################
# ====================================================================
# == VALIDATION ======================================================
# ====================================================================
######################################################################

before 'validate_form' => sub {
   my $self = shift;
   if( defined $self->params->{add_svc_acc} &&
       $self->params->{add_svc_acc} ne '' ) {
     $self->field('person_givenname')->required(0);
     $self->field('person_sn')->required(0);
     $self->field('person_org')->required(0);
     $self->field('person_office')->required(0);
     $self->field('person_title')->required(0);
   }
 };

sub validate {
  my $self = shift;
  my (
      $cert,
      $cert_msg,
      $element,
      $elementcmp,
      $err,
      $error,
      $field,
      $is_x509,
      $ldap_crud,
      $login_error_pfx,
      $logintmp,
      $mesg,
      $passwd_acc_filter,
      $a1, $b1, $c1
     );

  $ldap_crud = $self->ldap_crud;

  if ( defined $self->field('person_givenname')->value && defined $self->field('person_sn')->value ) {
    $self->autologin( lc($self->utf2lat( $self->field('person_givenname')->value ) . '.' .
			 $self->utf2lat( $self->field('person_sn')->value )));
  } else {
    my $autologin_mesg =
      $ldap_crud->search({ scope => 'base',
			   base => $self->add_svc_acc,
			   attrs => [ 'givenName', 'sn' ], });
    my $autologin_entry = $autologin_mesg->entry(0);
    $self->autologin( lc($autologin_entry->get_value('givenName') . '.' .
			 $autologin_entry->get_value('sn') ));
  }
  
  if ( $self->add_svc_acc eq '' ) {
    $mesg =
      $ldap_crud->search({ scope => 'one',
			   filter => '(uid=' . $self->autologin . '*)',
			   base => $ldap_crud->{cfg}->{base}->{acc_root},
			   attrs => [ 'uid' ], });
    if ( $mesg->count == 1 &&
	 defined $self->field('person_namesake')->value &&
	 $self->field('person_namesake')->value == 1 ) {
      $self->namesake(1);
    } elsif ( $mesg->count &&
	      defined $self->field('person_namesake')->value &&
	      $self->field('person_namesake')->value eq '1' ) {
      my @uids_namesake_suffixes;
      foreach my $uid_namesake ( $mesg->entries ) {
	push @uids_namesake_suffixes, 0+substr( $uid_namesake->get_value('uid'), length($self->autologin));
      }
      my @uids_namesake_suffixes_desc = sort {$b <=> $a} @uids_namesake_suffixes;
      # @uids_namesake_suffixes_desc;
      $self->namesake(++$uids_namesake_suffixes_desc[0]);
    } elsif ( $mesg->count ) {
      $self->field('person_login')->add_error('Auto-generaged variant for login exiscts!');
    } else {
      $self->namesake('');
    }
  } else {
    $self->namesake('');
  }

  # not simplified variant start
  if ( ! defined $self->field('person_simplified')->value ||
       $self->field('person_simplified')->value ne '1' ) {
    #----------------------------------------------------------
    #-- VALIDATION for services with password -----------------
    #----------------------------------------------------------
    my $i = 0;
    foreach $element ( $self->field('account')->fields ) {
      # if ( $#{$self->field('account')->fields} > -1 &&

      if ( $self->add_svc_acc eq '' &&
	   ((! defined $element->field('authorizedservice')->value &&
	     ! defined $element->field('associateddomain')->value ) ||
	    ( $element->field('authorizedservice')->value eq '' &&
	      $element->field('associateddomain')->value eq '' )) ) { # no svc no fqdn
	$element->field('associateddomain')->add_error('Domain Name is mandatory!');
	$element->field('authorizedservice')->add_error('Service is mandatory!');
      } elsif ( defined $element->field('authorizedservice')->value &&
		$element->field('authorizedservice')->value ne '' &&
		( ! defined $element->field('associateddomain')->value ||
		  $element->field('associateddomain')->value eq '' ) ) { # no fqdn
	$element->field('associateddomain')->add_error('Domain Name is mandatory!');
      } elsif ( defined $element->field('associateddomain')->value &&
		$element->field('associateddomain')->value ne '' &&
		( ! defined $element->field('authorizedservice')->value ||
		  $element->field('authorizedservice')->value eq '' )) { # no svc
	$element->field('authorizedservice')->add_error('Service is mandatory!');
      }

      if ( ( defined $element->field('password1')->value &&
	     ! defined $element->field('password2')->value ) ||
	   ( defined $element->field('password2')->value &&
	     ! defined $element->field('password1')->value ) ) { # only one pass
	$element->field('password1')->add_error('Both or none passwords have to be defined!');
	$element->field('password2')->add_error('Both or none passwords have to be defined!');
      }

      #---[ login preparation for check ]------------------------------------------------
      if ( ! defined $element->field('login')->value ||
	   $element->field('login')->value eq '' ) {
	$logintmp = sprintf('%s%s%s',
			    defined $ldap_crud
			    ->{cfg}
			    ->{authorizedService}
			    ->{$element->field('authorizedservice')->value}
			    ->{login_prefix} ?
			    $ldap_crud->{cfg}
			    ->{authorizedService}
			    ->{$element->field('authorizedservice')->value}
			    ->{login_prefix} : '',
			    $self->autologin,
			    $self->namesake);
	$login_error_pfx = 'Login (autogenerated, since empty)';
      } else {
	$logintmp = sprintf('%s%s',
			    defined $ldap_crud
			    ->{cfg}
			    ->{authorizedService}
			    ->{$element->field('authorizedservice')->value}
			    ->{login_prefix} ?
			    $ldap_crud->{cfg}
			    ->{authorizedService}
			    ->{$element->field('authorizedservice')->value}
			    ->{login_prefix} : '',
			    $element->field('login')->value);
	$login_error_pfx = 'Login';
      }

      $passwd_acc_filter = '(uid=' . $logintmp . '@' . $element->field('associateddomain')->value . ')'
	if defined $element->field('associateddomain')->value && $element->field('associateddomain')->value ne '';
      #---[ login preparation for check ]------------------------------------------------

      #---[ 802.1x ]------------------------------------------------
      if ( defined $element->field('authorizedservice')->value &&
	   $element->field('authorizedservice')->value =~ /^802.1x-.*$/ ) {

	if ( $element->field('authorizedservice')->value =~ /^802.1x-mac$/ ) {
	  $element->field('login')->add_error('MAC address is mandatory!')
	    if ! defined $element->field('login')->value || $element->field('login')->value eq '';
	  $element->field('login')->add_error('MAC address is not valid!')
	    if defined $element->field('login')->value && $element->field('login')->value ne '' &&
	    ! $self->macnorm({ mac => $element->field('login')->value });
	  $logintmp = $self->macnorm({ mac => $element->field('login')->value });
	  $login_error_pfx = 'MAC';
	  $passwd_acc_filter = '(cn=' . $logintmp . ')';
	}

	if ( $element->field('authorizedservice')->value eq '802.1x-eap-tls' ) {
	  p $element->field('userCertificate')->value;
	  if ( defined $element->field('userCertificate')->value &&
	       ref($element->field('userCertificate')->value) eq 'HASH' ) {
	    $cert = $self->file2var( $element->field('userCertificate')->value->{tempname}, $cert_msg);
	    $element->field('userCertificate')->add_error($cert_msg->{error})
	      if defined $cert_msg->{error};
	    $is_x509 = $self->cert_info({ cert => $cert });
	    $element->field('userCertificate')->add_error('Certificate file is broken or not DER format!')
	      if defined $is_x509->{error};
	    $element->field('userCertificate')->add_error('Problems with certificate file');
	    $self->add_form_error('<span class="fa-stack fa-fw">' .
				  '<i class="fa fa-cog fa-stack-2x text-muted umi-opacity05"></i>' .
				  '<i class="fa fa-user pull-right fa-stack-1x"></i></span>' .
				  '<b class="visible-lg-inline">&nbsp;Pass&nbsp;</b>' .
				  'Problems with certificate file<br>' .
				  $is_x509->{error})
	      if defined $is_x509->{error};
	  } elsif ( defined $element->field('userCertificate')->value &&
		    ! defined $element->field('userCertificate')->value->{tempname} ) {
	    $element->field('userCertificate')->add_error('userCertificate file was not uploaded');
	    $self->add_form_error('<span class="fa-stack fa-fw">' .
				  '<i class="fa fa-cog fa-stack-2x text-muted umi-opacity05"></i>' .
				  '<i class="fa fa-user pull-right fa-stack-1x"></i></span>' .
				  '<b class="visible-lg-inline">&nbsp;Pass&nbsp;</b>' .
				  'userCertificate file was not uploaded<br>');
	  } elsif ( ! defined $element->field('userCertificate')->value ) {
	    $element->field('userCertificate')->add_error('userCertificate is mandatory!');
	    $self->add_form_error('<span class="fa-stack fa-fw">' .
				  '<i class="fa fa-cog fa-stack-2x text-muted umi-opacity05"></i>' .
				  '<i class="fa fa-user pull-right fa-stack-1x"></i></span>' .
				  '<b class="visible-lg-inline">&nbsp;Pass&nbsp;</b>' .
				  'userCertificate is mandatory!<br>');
	  }

	
	$element->field('radiusgroupname')->add_error('RADIUS group name is mandatory!')
	  if ! defined $element->field('radiusgroupname')->value ||
	  $element->field('radiusgroupname')->value eq '';
	$element->field('radiustunnelprivategroupid')->add_error('RADIUS tunnel private grooup id is mandatory!')
	  if ! defined $element->field('radiustunnelprivategroupid')->value ||
	  $element->field('radiustunnelprivategroupid')->value eq '';
	}
      }
      #---[ 802.1x ]------------------------------------------------


      
      # prepare to know if login+service+fqdn is uniq?
      if ( ! $i ) {   # && defined $element->field('login')->value ) {
	$elementcmp
	  ->{$logintmp .
	     $element->field('authorizedservice')->value .
	     $element->field('associateddomain')->value} = 1;
      } else { #if ( $i && defined $element->field('login')->value ) {
	$elementcmp
	  ->{$logintmp .
	     $element->field('authorizedservice')->value .
	     $element->field('associateddomain')->value}++;
      }

      if ( defined $element->field('authorizedservice')->value && $element->field('authorizedservice')->value ne '' &&
	   defined $element->field('associateddomain')->value && $element->field('associateddomain')->value ne '' ) {
	$mesg =
	  $ldap_crud->search({
			      filter => '(&(authorizedService=' .
			      $element->field('authorizedservice')->value . '@' . $element->field('associateddomain')->value .
			      ')' . $passwd_acc_filter .')',
			      base => $ldap_crud->{cfg}->{base}->{acc_root},
			      attrs => [ 'uid' ],
			     });
	$element->field('login')->add_error($login_error_pfx . ' <mark>' . $logintmp . '</mark> is not available!')
	  if ($mesg->count);
      }

      $self->add_form_error('<span class="fa-stack fa-fw">' .
			    '<i class="fa fa-cog fa-stack-2x text-muted umi-opacity05"></i>' .
			    '<i class="fa fa-user pull-right fa-stack-1x"></i></span>' .
			    '<b class="visible-lg-inline">&nbsp;Pass&nbsp;</b>' .
			    'Has error/s! Correct or remove, please')
	if $self->field('account')->has_error_fields;

      $i++;
    }

    # p $elementcmp;
    # error rising if login+service+fqdn not uniq
    $i = 0;
    foreach $element ( $self->field('account')->fields ) {
      if ( defined $element->field('authorizedservice')->value &&
	   $element->field('authorizedservice')->value ne '' &&
	   defined $element->field('associateddomain')->value &&
	   $element->field('associateddomain')->value ne '' ) {
	$element->field('login')
	  ->add_error(sprintf('%s <mark>%s</mark> defined more than once for the same service and FQDN',
			      $login_error_pfx, $logintmp))
	  if defined $elementcmp->{$logintmp .
				   $element->field('authorizedservice')->value .
				   $element->field('associateddomain')->value} &&
				     $elementcmp->{ $logintmp .
						    $element->field('authorizedservice')->value .
						    $element->field('associateddomain')->value
						  } > 1;
      }
      $i++;
    }
  
    #----------------------------------------------------------
    #== VALIDATION password less ------------------------------
    #----------------------------------------------------------
  
    #---[ ssh + ]------------------------------------------------
    $i = 0;
    foreach $element ( $self->field('loginless_ssh')->fields ) {
      if ( defined $element->field('associateddomain')->value &&
	   ! defined $element->field('key')->value ) { # fqdn but no key
	$element->field('key')->add_error('Key field have to be defined!');
      } elsif ( defined $element->field('key')->value &&
		! defined $element->field('associateddomain')->value ) { # key but no fqdn
	$element->field('associateddomain')->add_error('Domain field have to be defined!');
      } elsif ( ! defined $element->field('key')->value &&
		! defined $element->field('associateddomain')->value &&
		$i > 0 ) {	# empty duplicatee
	$self->add_form_error('<span class="fa-stack fa-fw">' .
			      '<i class="fa fa-cog fa-stack-2x text-muted umi-opacity05"></i>' .
			      '<i class="fa fa-user-times pull-right fa-stack-1x"></i></span>' .
			      '<b class="visible-lg-inline">&nbsp;NoPass&nbsp;</b>' .
			      '<b> <i class="fa fa-arrow-right"></i> SSH:</b> Empty duplicatee! Fill it or remove, please');
      } elsif ( defined $element->field('key')->value &&
		defined $element->field('associateddomain')->value ) {
	# prepare to know if key+fqdn is uniq?
	if ( ! $i ) {
	  $elementcmp->{$element->field('key')->value . $element->field('associateddomain')->value} = 1;
	} else {
	  $elementcmp->{$element->field('key')->value . $element->field('associateddomain')->value}++;
	}
      }
    
      $i++;
    }
  
    $i = 0;
    foreach $element ( $self->field('loginless_ssh')->fields ) {
      if ( defined $element->field('key')->value && $element->field('key')->value ne '' &&
	   defined $element->field('associateddomain')->value && $element->field('associateddomain')->value ne '' ) {
	$element->field('key')->add_error('The same key is defined more than once for the same FQDN')
	  if $elementcmp->{$element->field('key')->value . $element->field('associateddomain')->value} > 1;
      }
      $i++;
    }

    $self->add_form_error('<span class="fa-stack fa-fw">' .
			  '<i class="fa fa-cog fa-stack-2x text-muted umi-opacity05"></i>' .
			  '<i class="fa fa-user-times pull-right fa-stack-1x"></i></span>' .
			  '<b class="visible-lg-inline">&nbsp;NoPass&nbsp;</b>' .
			  '<b> <i class="fa fa-arrow-right"></i> SSH:</b> Has error/s! Correct or remove, please')
      if $self->field('loginless_ssh')->has_error_fields;
  
    #---[ ssh - ]------------------------------------------------

    #---[ OpenVPN + ]--------------------------------------------
    $i = 0;
    foreach $element ( $self->field('loginless_ovpn')->fields ) {
      if ((( defined $element->field('associateddomain')->value &&
	     defined $element->field('userCertificate')->value &&
	     defined $element->field('ifconfigpush')->value &&
	     ( $element->field('associateddomain')->value eq '' ||
	       $element->field('userCertificate')->value eq '' ||
	       $element->field('ifconfigpush')->value eq '' ) ) ||
	   ( ! defined $element->field('associateddomain')->value ||
	     ! defined $element->field('userCertificate')->value ||
	     ! defined $element->field('ifconfigpush')->value  )) && $i > 0 ) {
	$element->field('associateddomain')->add_error('');
	$element->field('userCertificate')->add_error('');
	$element->field('ifconfigpush')->add_error('');
      }
    
      if ( ! defined $element->field('associateddomain')->value &&
	   ! defined $element->field('userCertificate')->value &&
	   ! defined $element->field('ifconfigpush')->value &&
	   $i > 0 ) {	   # empty duplicate (repeatable)
	# $element->add_error('Empty duplicatee!');
	$self->add_form_error('<span class="fa-stack fa-fw">' .
			      '<i class="fa fa-cog fa-stack-2x text-muted umi-opacity05"></i>' .
			      '<i class="fa fa-user-times pull-right fa-stack-1x"></i></span>' .
			      '<b class="visible-lg-inline">&nbsp;NoPass&nbsp;</b>' .
			      '<b> <i class="fa fa-arrow-right"></i> OpenVPN:</b> Empty duplicatee! Fill it or remove, please');
      }

      if ( defined $element->field('associateddomain')->value &&
	   defined $element->field('status')->value &&
	   defined $element->field('ifconfigpush')->value &&
	   ( $element->field('associateddomain')->value ne '' ||
	     $element->field('status')->value ne '' ||
	     $element->field('ifconfigpush')->value ne '' ) ) {
	p $element->field('userCertificate')->value;
	if ( defined $element->field('userCertificate')->value &&
	     ref($element->field('userCertificate')->value) eq 'HASH' ) {
	  $cert = $self->file2var( $element->field('userCertificate')->value->{tempname}, $cert_msg);
	  $element->field('userCertificate')->add_error($cert_msg->{error})
	    if defined $cert_msg->{error};
	  $is_x509 = $self->cert_info({ cert => $cert });
	  $element->field('userCertificate')->add_error('Certificate file is broken or not DER format!')
	    if defined $is_x509->{error};
	  $element->field('userCertificate')->add_error('Problems with certificate file');
	  $self->add_form_error('<span class="fa-stack fa-fw">' .
				'<i class="fa fa-cog fa-stack-2x text-muted umi-opacity05"></i>' .
				'<i class="fa fa-user-times pull-right fa-stack-1x"></i></span>' .
				'<b class="visible-lg-inline">&nbsp;NoPass&nbsp;</b>' .
				'<b> <i class="fa fa-arrow-right"></i> OpenVPN:</b> Problems with certificate file<br>' . $is_x509->{error})
	    if defined $is_x509->{error};
	} elsif ( defined $element->field('userCertificate')->value &&
		  ! defined $element->field('userCertificate')->value->{tempname} ) {
	  $element->field('userCertificate')->add_error('userCertificate file was not uploaded');
	  $self->add_form_error('<span class="fa-stack fa-fw">' .
				'<i class="fa fa-cog fa-stack-2x text-muted umi-opacity05"></i>' .
				'<i class="fa fa-user-times pull-right fa-stack-1x"></i></span>' .
				'<b class="visible-lg-inline">&nbsp;NoPass&nbsp;</b>' .
				'<b> <i class="fa fa-arrow-right"></i> OpenVPN:</b> userCertificate file was not uploaded<br>');
	} elsif ( ! defined $element->field('userCertificate')->value ) {
	  $element->field('userCertificate')->add_error('userCertificate is mandatory!');
	  $self->add_form_error('<span class="fa-stack fa-fw">' .
				'<i class="fa fa-cog fa-stack-2x text-muted umi-opacity05"></i>' .
				'<i class="fa fa-user-times pull-right fa-stack-1x"></i></span>' .
				'<b class="visible-lg-inline">&nbsp;NoPass&nbsp;</b>' .
				'<b> <i class="fa fa-arrow-right"></i> OpenVPN:</b> userCertificate is mandatory!<br>');
	}
      }


      #
      ## !!! add check for this cert existance !!! since when it is absent, PSGI falls
      #

      $i++;
    }

  $self->add_form_error('<span class="fa-stack fa-fw">' .
			'<i class="fa fa-cog fa-stack-2x text-muted umi-opacity05"></i>' .
			'<i class="fa fa-user-times pull-right fa-stack-1x"></i></span>' .
			'<b class="visible-lg-inline">&nbsp;NoPass&nbsp;</b>' .
			'<b> <i class="fa fa-arrow-right"></i> OpenVPN:</b> Has error/s! Correct or remove, please')
    if $self->field('loginless_ovpn')->has_error_fields;
  #---[ OpenVPN - ]--------------------------------------------

  }
  # not simplified variant stop
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

sub radprofile {
  my $self = shift;
  return unless $self->form->ldap_crud;
  return $self->form->ldap_crud->select_radprofile;
}

######################################################################


no HTML::FormHandler::Moose;

__PACKAGE__->meta->make_immutable;

1;

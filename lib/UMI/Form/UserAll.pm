# -*- mode: cperl; mode: follow; -*-
#

package UMI::Form::UserAll;

use HTML::FormHandler::Moose;
BEGIN { extends 'UMI::Form::LDAP';
	with 'Tools', 'HTML::FormHandler::Render::RepeatableJs';
      }

use Logger;

# use HTML::FormHandler::Types ('NoSpaces', 'WordChars', 'NotAllDigits', 'Printable', 'StrongPassword', 'IPAddress' );
use HTML::FormHandler::Types (':all');

use Data::Printer caller_info => 1, colored => 1;

# has '+error_message' => ( default => 'There were errors in your form.' );has '+item_class' => ( default =>'UserAll' );
has '+enctype' => ( default => 'multipart/form-data');
has '+action' => ( default => '/userall');
has 'namesake' => ( is => 'rw', );
has 'autologin' => ( is => 'rw', );
has 'add_svc_acc' => ( is => 'rw', ); # set if we add service account rather than new user
has 'dynamic_object' => ( is => 'rw', );

sub build_form_element_class { [ qw(form-horizontal tab-content formajaxer) ] }

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
has_field 'dynamic_object' => ( type => 'Hidden', );

######################################################################
#== PERSONAL DATA ====================================================
######################################################################
has_field 'person_givenname'
  => ( apply                 => [ NoSpaces ],
       label                 => 'FName',
       label_class           => [ 'col', 'text-right' ],
       element_wrapper_class => [ 'col-8', 'col-md-10' ],
       element_class         => [ 'input-sm', ],
       wrapper_class         => [ 'row' ],
       element_attr          => { placeholder => 'John' },
       required              => 1 );

has_field 'person_sn'
  => ( apply                 => [ NoSpaces ],
       label                 => 'LName',
       label_class           => [ 'col', 'text-right' ],
       element_wrapper_class => [ 'col-8', 'col-md-10' ],
       element_class         => [ 'input-sm', ],
       element_attr          => { placeholder => 'Doe' },
       wrapper_class         => [ 'row' ],
       required              => 1 );

has_field 'person_exp'
  => ( type                  => 'Text',
       label                 => 'Exp.',
       label_attr            => { title => 'Object Expiration', },
       label_class           => [ 'col', 'text-right' ],
       element_wrapper_class => [ 'col-8', 'col-md-10' ],
       element_class         => [ 'input-sm', ],
       element_attr          => { placeholder => 'Expiration on',
				  title       => 'Object Expiration', },
       wrapper_class         => [ 'row' ],
       required              => 0 );

has_field 'person_namesake'
  => ( type                  => 'Checkbox',
       label                 => 'namesake',
       element_attr          => { title => 'This new user has the same name/s as of some existent one. Check it if sure this new user does not exist and is not that existent one' },
       element_class         => [ 'form-check-input' ],
       wrapper_class         => [ 'form-check' ],
     );

has_field 'person_simplified'
  => ( type                  => 'Checkbox',
       label                 => 'simplified',
       element_attr          => { title => 'When checked, this checkbox causes user account been created in a simplified manner. Only Email and XMPP services will be created for FQDN choosen with Domain Name field in section Person bellow.',
				},
       element_class         => [ 'form-check-input' ],
       wrapper_class         => [ 'form-check' ],
     );

has_field 'person_avatar'
  => ( type                  => 'Upload',
       label                 => 'User Photo ID',
       label_class           => [ 'col', 'text-right' ],
       element_wrapper_class => [ 'col-8', 'col-md-10' ],
       element_class         => [ 'btn', 'btn-default', 'btn-sm', ],
       wrapper_class         => [ 'row' ],
       max_size => '50000' );

has_field 'person_gidnumber'
  => ( type                  => 'Select',
       label                 => 'Group',
       label_class           => [ 'col', 'text-right' ],
       # empty_select => $form->ldap_crud->{cfg}->{stub}->{gidNumber},
       element_wrapper_class => [ 'col-8', 'col-md-10' ],
       element_class         => [ 'input-sm', 'custom-select', ],
       element_attr          => { title => 'User primary group. RFC2307: An integer uniquely identifying a group in an administrative domain', },
       wrapper_class         => [ 'row' ],
       options_method        => \&groups,
       # required              => 1,
     );

sub options_person_gidnumber {
  my $self = shift;

  return unless $self->ldap_crud;

  my ( @groups, $return );
  my $ldap_crud = $self->ldap_crud;
  my $mesg = $ldap_crud->search( { base => $ldap_crud->cfg->{base}->{group},
				   scope => 'one',
				   attrs => [ qw{cn description gidNumber} ],
				   sizelimit => 0,} );

  # TO FIX (error is not handled) !!!
  push @{$return->{error}}, $ldap_crud->err($mesg)
    if ! $mesg->count;

  my @gidnumber_all = $mesg->sorted('cn');

  my ( $d, $n );
  foreach ( @gidnumber_all ) {
    $d = $_->get_value('description');
    utf8::decode($d);
    $n = $_->get_value('gidNumber');
    if ( $n == $ldap_crud->{cfg}->{stub}->{gidNumber} ) {
      push @groups, { value => $n,
		      label => sprintf('%s --- %s', $_->get_value('cn'), $d),
		      selected => 'selected', };
    } else {
      push @groups, { value => $n,
		      label => sprintf('%s --- %s', $_->get_value('cn'), $d), };
    }
  }
  return \@groups;
}


has_field 'person_org'
  => ( type                  => 'Select',
       label                 => 'Organization',
       label_class           => [ 'col', 'text-right' ],
       empty_select          => '--- Choose an Organization ---',
       element_wrapper_class => [ 'col-8', 'col-md-10' ],
       element_class         => [ 'input-sm', 'custom-select', ],
       wrapper_class         => [ 'row' ],
       options_method        => \&offices,
       required              => 1 );

has_field 'person_title'
  => ( label                 => 'Position',
       label_class           => [ 'col', 'text-right' ],
       element_wrapper_class => [ 'col-8', 'col-md-10' ],
       element_class         => [ 'input-sm', ],
       element_attr          => { placeholder => 'manager' },
       wrapper_class         => [ 'row' ], );

has_field 'person_office'
  => ( type                  => 'Select',
       label                 => 'Office',
       label_class           => [ 'col', 'text-right' ],
       empty_select          => '--- Choose an Office ---',
       element_wrapper_class => [ 'col-8', 'col-md-10' ],
       element_class         => [ 'input-sm', 'custom-select', ],
       options_method        => \&physicaldeliveryofficename,
       wrapper_class         => [ 'row' ],
       required              => 1 );

has_field 'person_telephonenumber'
  => ( apply                 => [ NoSpaces ],
       label                 => 'SIP/Cell',
       label_class           => [ 'col', 'text-right' ],
       element_wrapper_class => [ 'col-8', 'col-md-10' ],
       element_class         => [ 'input-sm', ],
       wrapper_attr          => { id => 'items' },
       element_attr          => { name => 'telephonenumber\[\]',
				  placeholder => '123@pbx0.umi, +380xxxxxxxxx' },
       wrapper_class         => [ 'row' ], );

# has_field 'person_telcomment'
#   => ( type => 'Display',
#        html => '<small class="text-muted col-xs-offset-2"><em>' .
#        'comma or space delimited if many, international format for tel.</em></small>',
#      );

has_field 'person_login'
  => ( apply                 => [ NoSpaces, NotAllDigits, Printable ],
       label                 => 'Login',
       label_class           => [ 'col', 'text-right' ],
       element_wrapper_class => [ 'col-8', 'col-md-10' ],
       element_class         => [ 'input-sm', ],
       element_attr          => { placeholder => 'john.doe', },
       wrapper_class         => [ 'row' ], );

has_field 'person_associateddomain'
  => ( type                  => 'Select',
       wrapper_attr          => { id => 'simplified', },
       wrapper_class         => [ 'simplified', 'row', ],
       label                 => 'Domain Name',
       label_class           => [ 'col', 'text-right', 'required' ],
       empty_select          => '--- Choose Domain ---',
       # element_attr          => { disabled => 'dissabled', },
       element_wrapper_class => [ 'col-8', 'col-md-10' ],
       element_class         => [ 'input-sm', 'custom-select', ],
       options_method        => \&associateddomains,
       required              => 0 );

has_field 'person_password1'
  => ( type                  => 'Password',
       label                 => 'Password',
       label_class           => [ 'col', 'text-right' ],
       element_wrapper_class => [ 'col-8', 'col-md-10' ],
       element_class         => [ 'input-sm', ],
       ne_username           => 'login',
       apply                 => [ NoSpaces, NotAllDigits, Printable, StrongPassword ],
       element_attr          => { placeholder => 'Password',
				  'autocomplete' => 'off', },
       wrapper_class         => [ 'row' ],
     );

has_field 'person_password2'
  => ( type                  => 'Password',
       label                 => '',
       label_class           => [ 'col', 'text-right' ],
       element_wrapper_class => [ 'col-8', 'col-md-10' ],
       element_class         => [ 'input-sm', ],
       ne_username           => 'login',
       apply                 => [ NoSpaces, NotAllDigits, Printable, StrongPassword ],
       element_attr          => { placeholder => 'Confirm Password',
				  'autocomplete' => 'off', },
       wrapper_class         => [ 'row' ],
     );


has_field 'person_description'
  => ( type                  => 'TextArea',
       label                 => 'Description',
       label_class           => [ 'col', 'text-right' ],
       element_wrapper_class => [ 'col-8', 'col-md-10' ],
       element_class         => [ 'input-sm', ],
       element_attr          => { placeholder => 'Any description.',
				  'autocomplete' => 'off', },
       wrapper_class         => [ 'row' ],
       cols                  => 30,
       rows                  => 1);

has_block 'group_person'
  => ( tag         => 'fieldset',
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
			'person_gidnumber',
			'person_description',
		      ],
       attr        => { id => 'group_person', },
     );

has_block 'person'
  => ( tag => 'fieldset',
       label => 'New User Personal Data',
       render_list => [ 'group_person', ],
       class => [ 'tab-pane', 'fade', 'show', 'active', ],
       attr => { id => 'person',
		 'aria-labelledby' => "person-tab",
		 role => "tabpanel",
	       },
     );

######################################################################
#== SERVICES WITH LOGIN ==============================================
######################################################################
has_field 'aux_add_account'
  => ( type          => 'AddElement',
       repeatable    => 'account',
       value         => 'Add new account',
       element_class => [ 'btn-success', ],
       element_wrapper_class => [ 'col-3', 'offset-md-2', ],
       element_attr  => { title => 'new fields are added to the bottom, bellow existent ones', },
       wrapper_class => [ 'row', ],
     );

has_field 'account'
  => ( type                  => 'Repeatable',
       setup_for_js          => 1,
       do_wrapper            => 1,
       element_wrapper_class => [ qw{controls}, ],
       wrapper_attr          => { class => 'no-has-error' },
       # wrap_repeatable_element_method => \&wrap_account_elements,
       # wrapper_class => [ qw{bg-info}, ],
       # init_contains => { element_class => [ qw{hfh repinst bg-info}], },
     );

# sub wrap_account_elements {
#   my ( $self, $input, $subfield ) = @_;
#   # my $output = sprintf('%s%s%s', ! $subfield ? qq{\n<div class="duplicate">} : qq{\n<div class="duplicated">},
#   # 		       $input,
#   # 		       qq{</div>});
#   my $output = sprintf('%s%s%s', qq{\n<div class="bg-info">}, $input, qq{</div>});
# }

has_field 'account.associateddomain'
  => ( type                  => 'Select',
       label                 => 'Domain Name',
       label_class           => [ 'col', 'text-right' ],
       empty_select          => '--- Choose Domain ---',
       element_wrapper_class => [ 'col-8', 'col-md-10' ],
       element_class         => [ 'input-sm', 'custom-select', ],
       options_method        => \&associateddomains,
       element_attr          => { 'data-name' => 'associateddomain',
				  'data-group' => 'account', },
       wrapper_class         => [ 'row' ],
       required => 0 );

has_field 'account.authorizedservice'
  => ( type                  => 'Select',
       label                 => 'Service',
       label_class           => [ 'col', 'text-right' ],
       empty_select          => '--- Choose Service ---',
       element_wrapper_class => [ 'col-8', 'col-md-10' ],
       element_class         => [ 'input-sm', 'custom-select', ],
       options_method        => \&authorizedservice,
       element_attr          => { 'data-name' => 'authorizedservice',
				  'data-group' => 'account', },
       wrapper_class         => [ 'row' ],
       required => 0,
     );

has_field 'account.login'
  => ( apply                 => [ NoSpaces, NotAllDigits, Printable, NonEmptyStr ],
       label                 => 'Login',
       do_id                 => 'no',
       label_class           => [ 'col', 'text-right' ],
       element_wrapper_class => [ 'col-8', 'col-md-10' ],
       element_class         => [ 'input-sm', ],
       element_attr          => { placeholder => 'john.doe',
				  title => 'login to be added with @domain in the end; root uid is used if not provided.',
				  'autocomplete' => 'off',
				  'data-name' => 'login',
				  'data-group' => 'account', },
       wrapper_class         => [ 'row' ],
     );

has_field 'account.logindescr'
  => ( type          => 'Display',
       html          => '<div class="form-group d-none relation passw row">' .
       '<label class="col"></label>' .
       '<div class="col-8 col-md-10">' .
       '<small class="text-muted"><em>' .
       'login will be added with @domain' .
       '</em></small></div></div>',
       element_attr  => { 'data-name' => 'logindescr',
			  'data-group' => 'account', },
       wrapper_class => [ 'row', ],
     );

has_field 'account.password1'
  => ( type                  => 'Password',
       minlength             => 7, maxlength => 128,
       label                 => 'Password',
       label_class           => [ 'col', 'text-right' ],
       wrapper_class         => [  qw{ d-none passw sshacc
				       dot1x-eap-tls relation row}, ],
       element_wrapper_class => [ 'col-8', 'col-md-10' ],
       element_class         => [ 'input-sm', ],
       ne_username           => 'login',
       apply                 => [ NoSpaces, NotAllDigits, Printable, StrongPassword ],
       element_attr          => { placeholder    => 'Password',
				  'autocomplete' => 'off',
				  'data-name'    => 'password1',
				  'data-group'   => 'account', },
     );

has_field 'account.password2'
  => ( type                  => 'Password',
       minlength             => 7, maxlength => 128,
       label                 => '',
       label_class           => [ 'col', 'text-right' ],
       wrapper_class         => [  qw{ d-none passw sshacc
				       dot1x-eap-tls relation row}, ],
       element_wrapper_class => [ 'col-8', 'col-md-10' ],
       element_class         => [ 'input-sm', ],
       ne_username           => 'login',
       apply                 => [ NoSpaces, NotAllDigits, Printable, StrongPassword ],
       element_attr          => { placeholder    => 'Confirm Password',
				  'autocomplete' => 'off',
				  'data-name'    => 'password2',
				  'data-group'   => 'account', },
     );

has_field 'account.description'
  => ( type                  => 'TextArea',
       label                 => 'Description',
       label_class           => [ 'col', 'text-right' ],
       element_wrapper_class => [ 'col-8', 'col-md-10' ],
       element_class         => [ 'input-sm', ],
       element_attr          => { placeholder    => 'Any description.',
				  'autocomplete' => 'off',
				  'data-group'   => 'account', },
       cols                  => 30, rows => 1,
       wrapper_class         => [ 'row', ], );

has_field 'account.radiusgroupname'
  => ( type                  => 'Select',
       label                 => 'RADIUS Group',
       do_id                 => 'no',
       label_class           => [ 'col', 'text-right', 'atleastone' ],
       element_wrapper_class => [ 'col-8', 'col-md-10' ],
       element_class         => [ 'input-sm', 'custom-select', ],
       element_attr          => { 'data-name'  => 'radiusgroupname',
				  'data-group' => 'account', },
       empty_select          => '--- Choose RADIUS default Group ---',
       options_method        => \&radgroup,
       wrapper_class         => [ qw{d-none dot1x dot1x-eap-tls relation row}, ],
     );

has_field 'account.radiusprofiledn'
  => ( type                  => 'Select',
       label                 => 'RADIUS Profile',
       do_id                 => 'no',
       label_class           => [ 'col', 'text-right', 'atleastone', ],
       element_wrapper_class => [ 'col-8', 'col-md-10' ],
       element_class         => [ 'input-sm', 'custom-select', ],
       element_attr          => { 'autocomplete' => 'off',
				  'data-name'    => 'radiusprofiledn',
				  'data-group'   => 'account', },
       empty_select          => '--- Choose RADIUS Profile ---',
       options_method        => \&radprofile,
       wrapper_class         => [  qw{d-none dot1x dot1x-eap-tls relation row}, ],
     );

has_field 'account.userCertificate'
  => ( type                  => 'Upload',
       label                 => 'Cert (.DER)',
       do_id                 => 'no',
       label_class           => [ 'col', 'text-right', 'required', ],
       element_wrapper_class => [ 'col-8', 'col-md-10' ],
       element_class         => [ 'btn', 'btn-default', 'btn-sm', 'btn-secondary', ],
       element_attr          => {
				 'data-group' => 'account',
				 'data-name'  => 'userCertificate'
				},
       wrapper_class         => [  qw{d-none dot1x-eap-tls relation row}, ],
     );

has_field 'account.sshgid'
  => ( apply                 => [ NoSpaces, NotAllDigits, Printable ],
       label                 => 'gidNumber',
       do_id                 => 'no',
       label_class           => [ 'col', 'text-right' ],
       element_wrapper_class => [ 'col-8', 'col-md-10' ],
       element_class         => [ 'input-sm', 'text-monospaced' ],
       element_attr          => { placeholder    => 'default is 11102 (ssh-ci)',
				  title          => 'Group ID of the user.',
				  'autocomplete' => 'off',
				  'data-name'    => 'sshgid',
				  'data-group'   => 'account', },
       wrapper_class         => [  qw{d-none sshacc relation row}, ],
     );

has_field 'account.sshhome'
  => ( apply                 => [ NoSpaces, NotAllDigits, Printable ],
       label                 => 'homeDir',
       do_id                 => 'no',
       label_class           => [ 'col', 'text-right' ],
       element_wrapper_class => [ 'col-8', 'col-md-10' ],
       element_class         => [ 'input-sm', 'mono' ],
       element_attr          => { placeholder    => '/nonexistent',
				  title          => 'Home directory of the user.',
				  'autocomplete' => 'off',
				  'data-name'    => 'sshhome',
				  'data-group'   => 'account', },
       wrapper_class         => [  qw{d-none sshacc relation row}, ],
     );

has_field 'account.sshshell'
  => ( apply                 => [ NoSpaces, NotAllDigits, Printable ],
       label                 => 'loginShell',
       do_id                 => 'no',
       label_class           => [ 'col', 'text-right' ],
       element_wrapper_class => [ 'col-8', 'col-md-10' ],
       element_class         => [ 'input-sm', 'mono' ],
       element_attr          => { placeholder    => '/bin/bash',
				  title          => 'Shell of the user.',
				  'autocomplete' => 'off',
				  'data-name'    => 'sshshell',
				  'data-group'   => 'account', },
       wrapper_class         => [  qw{d-none sshacc relation row}, ],
     );

has_field 'account.sshkey'
  => ( type                  => 'TextArea',
       do_id                 => 'no',
       label                 => 'SSH Pub Key',
       label_class           => [ 'col', 'text-right', 'required', ],
       element_wrapper_class => [ 'col-8', 'col-md-10' ],
       element_class         => [ 'input-sm', 'text-monospaced', ],
       element_attr          => { title        => 'Paste SSH key (read sshd(8) section AUTHORIZED_KEYS FILE FORMAT for reference)',
				  placeholder  => q{command=&quot;...&quot;, environment=&quot;NAME=value&quot;,...,from=&quot;...&quot; no-agent-forwarding,no-port-forwarding,no-pty,no-user-rc,no-x11-forwarding,permitopen=&quot;host:port&quot;,tunnel=&quot;n&quot; ssh-rsa AAA...bZN Lorem ipsum dolor sit amet potenti},
				  'data-name'  => 'sshkey',
				  'data-group' => 'account', },
       cols                  => 30, rows => 4,
       wrapper_class         => [  qw{d-none sshacc relation row}, ],
     );


has_field 'account.sshkeyfile'
  => ( type                  => 'Upload',
       do_id                 => 'no',
       label                 => 'SSH Pub Key/s File',
       label_class           => [ 'col', 'text-right', 'required', ],
       element_wrapper_class => [ 'col-8', 'col-md-10' ],
       element_class         => [ 'btn', 'btn-default', 'btn-sm', 'btn-secondary', ],
       element_attr          => {title        => 'SSH key file (read sshd(8) section AUTHORIZED_KEYS FILE FORMAT for reference)',
				 'data-name'  => 'sshkeyfile',
				 'data-group' => 'account',
				 # 'onchange' => 'global.triggerTextarea(this)',
				},
       wrapper_class         => [  qw{d-none sshacc relation row}, ],
     );


has_field 'account.remove'
  => ( type                  => 'RmElement',
       value                 => 'Remove this (above fields) account',
       element_class         => [ 'btn-danger', ],
       element_wrapper_class => [ 'col-3', 'pr-0', 'offset-md-2', ],
       wrapper_class         => [ 'row', ],
     );

has_block 'auth'
  => ( tag         => 'fieldset',
       label       => 'Login And Password Dependent Service&nbsp;<small class="text-muted"><em>(' .
       'login and password fields are autogenerated if empty, login will be the same as master account login)</em></small>',
       render_list => [ 'aux_add_account', 'account', ],
       class       => [ qw{tab-pane fade show}, ],
       attr        => { id                => 'auth',
			'aria-labelledby' => 'auth-tab',
			role              => 'tabpanel', },
     );

######################################################################
#== SERVICES WITHOUT LOGIN ===========================================
######################################################################

#=== OpenVPN =========================================================

has_field 'aux_add_loginless_ovpn'
  => ( type          => 'AddElement',
       repeatable    => 'loginless_ovpn',
       value         => 'Add new OpenVPN account',
       element_class => [ 'btn-success', ],
       element_wrapper_class => [ 'col-3', 'offset-md-2', ],
       wrapper_class => [ 'row', ],
     );

has_field 'loginless_ovpn'
  => ( type                  => 'Repeatable',
       setup_for_js          => 1,
       do_wrapper            => 1,
       # element_class         => [ 'btn-success', ],
       element_wrapper_class => [ 'controls', ],
       wrapper_attr          => { class => 'no-has-error' },
       # wrap_repeatable_element_method => \&wrap_loginless_ovpn_elements,
       # tags => { controls_div => 1 },
       # init_contains => { wrapper_attr => { class => ['hfh', 'repinst'] } },
     );

# sub wrap_loginless_ovpn_elements {
#   my ( $self, $input, $subfield ) = @_;
#   my $output = sprintf('%s%s%s', ! $subfield ? qq{\n<div class="duplicate">} : qq{\n<div class="duplicated">},
# 		       $input,
# 		       qq{</div>});
# }

has_field 'loginless_ovpn.status'
  => ( type                  => 'Select',
       label                 => 'Account status',
       label_class           => [ 'col', 'text-right' ],
       element_wrapper_class => [ 'col-8', 'col-md-10' ],
       element_class         => [ 'input-sm', 'custom-select', ],
       element_attr          => { placeholder    => 'Initial state of the account',
				  'autocomplete' => 'off',
				  'data-name'    => 'status',
				  'data-group'   => 'loginless_ovpn', },
       options               => [{ value => '',        label => '--- Choose State ---'},
				 { value => 'enabled', label => 'Enabled'},
				 { value => 'disabled',label => 'Disabled'},
				 { value => 'revoked', label => 'Revoked'}, ],
       wrapper_class         => [ 'row', ],
     );

has_field 'loginless_ovpn.associateddomain'
  => ( type                  => 'Select',
       label                 => 'FQDN',
       label_class           => [ 'col', 'text-right', 'required' ],
       empty_select          => '--- Choose Domain ---',
       element_wrapper_class => [ 'col-8', 'col-md-10' ],
       element_class         => [ 'input-sm', 'custom-select', ],
       options_method        => \&associateddomains,
       element_attr          => { title        => 'FQDN of the VPN server, client is configured for',
				  'data-name'  => 'associateddomain',
				  'data-group' => 'loginless_ovpn', },
       wrapper_class         => [ 'row', ],
     );

has_field 'loginless_ovpn.userCertificate'
  => ( type                  => 'Upload',
       label                 => 'Cert (.DER)',
       label_class           => [ 'col', 'text-right', 'required' ],
       element_wrapper_class => [ 'col-8', 'col-md-10' ],
       element_class         => [ 'btn', 'btn-default', 'btn-sm', 'btn-secondary', ],
       element_attr          => { 'data-name'  => 'cert',
				  'data-group' => 'loginless_ovpn', },
       wrapper_class         => [ 'row', ],
     );

has_field 'loginless_ovpn.ifconfigpush'
  => ( apply                 => [ Printable, ],
       label                 => 'Ifconfig',
       label_class           => [ 'col', 'text-right', 'required', ],
       element_wrapper_class => [ 'col-8', 'col-md-10' ],
       element_class         => [ 'input-sm', ],
       element_attr          => { placeholder  => '10.0.91.1 10.0.91.2 or 10.0.97.135 10.0.97.1 or 10.13.83.192 10.0.97.1',
				  title        => 'openvpn(8) option &#96;--ifconfig l rn&#39; (Set TUN/TAP adapter parameters.  l is the IP address of the local VPN endpoint. rn is the IP address of the remote VPN endpoint.)',
				  'data-name'  => 'ifconfigpush',
				  'data-group' => 'loginless_ovpn', },
       wrapper_class         => [ 'row', ],
     );

has_field 'loginless_ovpn.iroute'
  => ( apply                 => [ Printable, ],
       label                 => 'Iroute',
       label_class           => [ 'col', 'text-right', ],
       element_wrapper_class => [ 'col-8', 'col-md-10' ],
       element_class         => [ 'input-sm', ],
       element_attr          => { placeholder  => '10.0.99.2 255.255.255.0',
				  title        => 'openvpn(8) option &#96;--iroute network [netmask]&#39; (Generate an internal route to a specific client. The netmask parameter, if omitted, defaults to 255.255.255.255.)',
				  'data-name'  => 'iroute',
				  'data-group' => 'loginless_ovpn', },
       wrapper_class         => [ 'row', ],
     );

has_field 'loginless_ovpn.push'
  => ( apply                 => [ Printable, ],
       label                 => 'Push',
       label_class           => [ 'col', 'text-right' ],
       element_wrapper_class => [ 'col-8', 'col-md-10' ],
       element_class         => [ 'input-sm', ],
       element_attr          => { placeholder  => 'route 192.168.222.144 255.255.255.128',
				  title        => 'openvpn(8) option &#96;--push option&#39; (Push a config file option back to the client for remote execution.)',
				  'data-name'  => 'push',
				  'data-group' => 'loginless_ovpn', },
       wrapper_class         => [ 'row', ],
     );

has_field 'loginless_ovpn.devtype'
  => ( apply                 => [ NoSpaces, Printable ],
       label                 => 'Device Type',
       label_class           => [ 'col', 'text-right' ],
       element_wrapper_class => [ 'col-8', 'col-md-10' ],
       element_class         => [ 'input-sm', ],
       element_attr          => { placeholder  => 'notebook, netbook, smartphone',
				  title        => 'OS type (defines which address to assign: /30 for Win like and /32 for XNIX like)',
				  'data-name'  => 'dev',
				  'data-group' => 'loginless_ovpn', },
       wrapper_class         => [ 'row', ],
     );

has_field 'loginless_ovpn.devos'
  => ( apply                 => [ Printable ],
       label                 => 'OS',
       label_class           => [ 'col', 'text-right' ],
       element_wrapper_class => [ 'col-8', 'col-md-10' ],
       element_class         => [ 'input-sm', ],
       element_attr          => { placeholder  => 'xNIX, MacOS, Android, Windows',
				  'data-name'  => 'devos',
				  'data-group' => 'loginless_ovpn', },
       wrapper_class         => [ 'row', ],
     );

has_field 'loginless_ovpn.config'
  => ( apply                 => [ Printable, ],
       label                 => 'Config',
       label_class           => [ 'col', 'text-right' ],
       element_wrapper_class => [ 'col-8', 'col-md-10' ],
       element_class         => [ 'input-sm', ],
       element_attr          => { placeholder  => 'path/to/some/additional/configfile.conf',
				  title        => 'openvpn(8) option &#96;--config&#39; (Load additional config options from file where each line corresponds to one command line option, but with the leading &#39;--&#39; removed.)',
				  'data-name'  => 'config',
				  'data-group' => 'loginless_ovpn', },
       wrapper_class         => [ 'row', ],
     );

has_field 'loginless_ovpn.devmake'
  => ( apply                 => [ Printable ],
       label                 => 'Device Maker',
       label_class           => [ 'col', 'text-right' ],
       element_wrapper_class => [ 'col-8', 'col-md-10' ],
       element_class         => [ 'input-sm', ],
       element_attr          => { placeholder  => 'HP, Dell, Asus, Lenovo',
				  'data-name'  => 'devmake',
				  'data-group' => 'loginless_ovpn', },
       wrapper_class         => [ 'row', ],
     );

has_field 'loginless_ovpn.devmodel'
  => ( apply                 => [ Printable ],
       label                 => 'Device Model',
       label_class           => [ 'col', 'text-right' ],
       element_wrapper_class => [ 'col-8', 'col-md-10' ],
       element_class         => [ 'input-sm', ],
       element_attr          => { placeholder  => 'Pavilion dm1',
				  'data-name'  => 'devmodel',
				  'data-group' => 'loginless_ovpn', },
       wrapper_class         => [ 'row', ],
     );

has_field 'loginless_ovpn.devosver'
  => ( apply                 => [ Printable ],
       label                 => 'OS version',
       label_class           => [ 'col', 'text-right' ],
       element_wrapper_class => [ 'col-8', 'col-md-10' ],
       element_class         => [ 'input-sm', ],
       element_attr          => { placeholder  => '1.2.3',
				  'data-name'  => 'devosv',
				  'data-group' => 'loginless_ovpn', },
       wrapper_class         => [ 'row', ],
     );

has_field 'loginless_ovpn.description'
  => ( type                  => 'TextArea',
       label                 => 'Description',
       label_class           => [ 'col', 'text-right' ],
       element_wrapper_class => [ 'col-8', 'col-md-10' ],
       element_class         => [ 'input-sm', ],
       element_attr          => { placeholder    => 'Any description.',
				  'autocomplete' => 'off',
				  'data-group'   => 'loginless_ovpn', },
       cols                  => 30, rows => 1,
       wrapper_class         => [ 'row', ],
     );

has_field 'loginless_ovpn.remove'
  => ( type                  => 'RmElement',
       value                 => 'Remove this (above fields) account',
       element_class         => [ 'btn-danger', ],
       element_wrapper_class => [ 'col-3', 'pr-0', 'offset-md-2', ],
       wrapper_class         => [ 'row', ],
     );

has_block 'ovpn'
  => ( tag => 'fieldset',
       label       => 'OpenVPN configuration&nbsp;<small class="text-muted"><em>( <span class="fa fa-ellipsis-h"></span> )</em></small>',
       render_list => [ 'aux_add_loginless_ovpn', 'loginless_ovpn', ],
       class       => [ 'tab-pane', 'fade', ],
       attr        => { id                => 'ovpn',
			'aria-labelledby' => 'ovpn-tab',
			role              => 'tabpanel',
		      },
     );

#=== GROUPS ==========================================================

has_field 'groups'
  => ( type                  => 'Multiple',
       label                 => '',
       element_wrapper_class => [ 'col-12', ],
       element_class         => [ 'multiselect', 'input-sm', 'umi-multiselect', ],
       # required => 1,
     );

sub options_groups {
  my $self = shift;
  my ( @groups, $return );

  return unless $self->ldap_crud;

  my $ldap_crud = $self->ldap_crud;
  my $mesg = $ldap_crud->search( { base      => $ldap_crud->cfg->{base}->{group},
				   scope     => 'one',
				   sizelimit => 0,
				   attrs     => [ 'cn' ], } );

  push @{$return->{error}}, $ldap_crud->err($mesg)
    if ! $mesg->count;

  my @groups_all = $mesg->sorted('cn');

  push @groups, { value => $_->get_value('cn'), label => $_->get_value('cn'), }
    foreach @groups_all;

  return \@groups;
}

has_field 'groupspace'
  => ( type => 'Display',
       html => '<p>&nbsp;</p>',
     );


has_block 'groupsselect'
  => ( tag         => 'fieldset',
       label       => 'Groups user belongs to',
       render_list => [ 'groups', ], # 'groupspace', ],
       class       => [ 'tab-pane', 'fade', ],
       attr        => { id                => 'groups',
			'aria-labelledby' => 'groups-tab',
			role              => 'tabpanel',
		      },
     );

######################################################################
#== REST OF THE FORM =================================================
######################################################################

has_field 'aux_reset'
  => ( type          => 'Reset',
       element_class => [ qw( btn
			      btn-danger
			      btn-block
			      font-weight-bold
			      text-uppercase) ],
       wrapper_class => [ 'col-4' ],
       value         => 'Reset' );

has_field 'aux_submit'
  => ( type          => 'Submit',
       element_class => [ qw( btn
			      btn-success
			      btn-block
			      font-weight-bold
			      text-uppercase) ],
       wrapper_class => [ 'col-8', ],
       value         => 'Submit' );

has_block 'aux_submitit'
  => ( tag => 'div',
       render_list => [ 'aux_reset', 'aux_submit'],
       class => [ 'row', ]
     );



######################################################################
# ====================================================================
# == VALIDATION ======================================================
# ====================================================================
######################################################################

before 'validate_form' => sub {
  my $self = shift;
  if ( defined $self->params->{add_svc_acc} &&
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
      $cert, $cert_msg,
      $element, $elementcmp,
      $mesg, $entry,
      $err, $error,
      $field,
      $is_x509,
      $ldap_crud,
      $login_error_pfx,
      $logintmp,
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
			   base  => $self->add_svc_acc,
			   attrs => [ 'givenName', 'sn' ], });
    my $autologin_entry = $autologin_mesg->entry(0);
    log_debug { np($self->add_svc_acc) };
    $self->autologin( lc($autologin_entry->get_value('givenName') . '.' .
			 $autologin_entry->get_value('sn') ));
  }

  if ( $self->add_svc_acc eq '' ) {
    $mesg =
      $ldap_crud->search({ scope  => 'one',
			   filter => '(uid=' . $self->autologin . '*)',
			   base   => $ldap_crud->cfg->{base}->{acc_root},
			   attrs  => [ 'uid' ], });
    my $uid_namesake;
    if ( $mesg->count == 1 &&
	 defined $self->field('person_namesake')->value &&
	 $self->field('person_namesake')->value == 1 ) {
      $self->namesake( 1+substr( $mesg->entry(0)->get_value('uid'), length($self->autologin)) );
    } elsif ( $mesg->count &&
	      defined $self->field('person_namesake')->value &&
	      $self->field('person_namesake')->value eq '1' ) {
      my @uids_namesake_suffixes;
      foreach $uid_namesake ( $mesg->entries ) {
	push @uids_namesake_suffixes, 0+substr( $uid_namesake->get_value('uid'), length($self->autologin));
      }
      my @uids_namesake_suffixes_desc = sort {$b <=> $a} @uids_namesake_suffixes;
      # p @uids_namesake_suffixes_desc;
      $self->namesake(++$uids_namesake_suffixes_desc[0]);
    } elsif ( $mesg->count ) {
      $entry = $mesg->entry(0);
      $self->field('person_login')->add_error('Auto-generaged login exists, object DN: <em class="text-danger">' . $entry->dn . '</em> (consider to use &laquo;namesake&raquo; checkbox)');
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
      # new user, defined neither fqdn nor svc, but login
      if ( $self->add_svc_acc eq '' &&
	   defined $element->field('login')->value &&
	   $element->field('login')->value ne '' &&
	   ((! defined $element->field('authorizedservice')->value &&
	     ! defined $element->field('associateddomain')->value ) ||
	    ( $element->field('authorizedservice')->value eq '' &&
	      $element->field('associateddomain')->value eq '' )) ) {
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
      # elsif ( ! defined $element->field('authorizedservice')->value ) {
      # 	$element->field('authorizedservice')->add_error('Service is mandatory!');
      # }

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
			    $ldap_crud->cfg->{authorizedService}->{$element->field('authorizedservice')->value}->{login_prefix} // '',
			    $self->autologin,
			    $self->namesake);
	$login_error_pfx = 'Login (autogenerated, since empty)';
      } else {
	$logintmp = sprintf('%s%s',
			    $ldap_crud->cfg->{authorizedService}->{$element->field('authorizedservice')->value}->{login_prefix} // '',
			    $element->field('login')->value);
	$login_error_pfx = 'Login';
      }

      $passwd_acc_filter = sprintf("(uid=%s%s%s)",
				   $logintmp,
				   $ldap_crud->cfg->{authorizedService}->{
									  $element->field('authorizedservice')->value
									 }->{login_delim} // '@',
				   $element->field('associateddomain')->value)
	if defined $element->field('associateddomain')->value && $element->field('associateddomain')->value ne '';
      
      #---[ login preparation for check ]------------------------------------------------

      #---[ ssh-acc ]--------------------------------------------------------------------
      if ( defined $element->field('authorizedservice')->value &&
	   $element->field('authorizedservice')->value =~ /^ssh-acc.*$/ ) {

	if ( defined $element->field('associateddomain')->value &&
	     ! defined $element->field('sshkey')->value &&
	     ! defined $element->field('sshkeyfile')->value ) { # fqdn but no key
	  $element->field('sshkey')->add_error('Either Key, KeyFile or both field/s have to be defined!');
	  $element->field('sshkeyfile')->add_error('Either KeyFile, Key or both field/s have to be defined!');
	} elsif ( ( defined $element->field('sshkey')->value ||
		    defined $element->field('sshkeyfile')->value ) &&
		  ! defined $element->field('associateddomain')->value ) { # key but no fqdn
	  $element->field('associateddomain')->add_error('Domain field have to be defined!');
	} elsif ( ! defined $element->field('sshkey')->value &&
		  ! defined $element->field('sshkeyfile')->value &&
		  ! defined $element->field('associateddomain')->value ) { # empty duplicatee
	  $self->add_form_error('<span class="fa-stack fa-fw">' .
				'<i class="fa fa-cog fa-stack-2x text-muted umi-opacity05"></i>' .
				'<i class="fa fa-user-times pull-right fa-stack-1x"></i></span>' .
				'<b class="visible-lg-inline">&nbsp;NoPass&nbsp;</b>' .
				'<b> <i class="fa fa-arrow-right"></i> SSH:</b> Empty duplicatee! Fill it or remove, please');
	}


	  
      }
      #---[ ssh-acc ]--------------------------------------------------------------------

      #---[ 802.1x ]---------------------------------------------------------------------
      if ( defined $element->field('authorizedservice')->value &&
	   $element->field('authorizedservice')->value =~ /^dot1x-.*$/ ) {

	if ( $element->field('authorizedservice')->value eq 'dot1x-eap-md5' ) {
	  $element->field('login')->add_error('MAC address is mandatory!')
	    if ! defined $element->field('login')->value || $element->field('login')->value eq '';
	  $element->field('login')->add_error('MAC address is not valid!')
	    if defined $element->field('login')->value && $element->field('login')->value ne '' &&
	    ! $self->macnorm({ mac => $element->field('login')->value });
	  $logintmp = $self->macnorm({ mac => $element->field('login')->value });
	  $login_error_pfx = 'MAC';
	  $passwd_acc_filter = '(cn=' . $logintmp . ')';
	}

	if ( $element->field('authorizedservice')->value eq 'dot1x-eap-tls' ) {
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
	  $logintmp = 'rad-' . $element->field('login')->value;
	}
	if (( ! defined $element->field('radiusgroupname')->value ||
	      $element->field('radiusgroupname')->value eq '' ) &&
	    ( ! defined $element->field('radiusprofiledn')->value ||
	      $element->field('radiusprofiledn')->value eq '' )) {
	  $element->field('radiusgroupname')->add_error('RADIUS group, profile or both are to be set!');
	  $element->field('radiusprofiledn')->add_error('RADIUS profile, group or both are to be set!');
	}
	if ( defined $element->field('radiusgroupname')->value &&
	     $element->field('radiusgroupname')->value ne '' ) {
	  $mesg =
	    $ldap_crud
	    ->search({ base => $element->field('radiusgroupname')->value,
		       filter => sprintf('member=uid=%s,authorizedService=%s@%s,%s',
					 $logintmp,
					 $element->field('authorizedservice')->value,
					 $element->field('associateddomain')->value,
					 $self->add_svc_acc)
		     });
	  $element->field('radiusgroupname')
	    ->add_error(sprintf('<span class="mono">%s</span> already is in this RADIUS group.<br>This service object <span class="mono">%s</span> either was deleted but not removed from, or is still the member of the group.',
				$logintmp,
				sprintf('uid=%s,authorizedService=%s@%s,%s',
					$logintmp,
					$element->field('authorizedservice')->value,
					$element->field('associateddomain')->value,
					$self->add_svc_acc)))
	    if $mesg->count;
	}
      }
      #---[ 802.1x ]---------------------------------------------------------------------

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
			      filter => sprintf("(&(authorizedService=%s%s%s)%s)",
						$element->field('authorizedservice')->value,
						$ldap_crud->cfg->{authorizedService}->{
										       $element->field('authorizedservice')->value
										      }->{login_delim} // '@',
						$element->field('associateddomain')->value,
						$passwd_acc_filter),
			      base => $ldap_crud->cfg->{base}->{acc_root},
			      attrs => [ 'uid' ],
			     });
	$element->field('login')->add_error($login_error_pfx . ' <mark>' . $logintmp . '</mark> is not available!')
	  if ($mesg->count);
      }

      $self->add_form_error('<span class="fa-stack fa-fw">' .
			    '<i class="fa fa-cog fa-stack-2x text-muted umi-opacity05"></i>' .
			    '<i class="fa fa-key pull-right fa-stack-1x"></i></span>' .
			    '<b class="visible-lg-inline">&nbsp;Pass&nbsp;</b>' .
			    'Has error/s! Correct or remove, please')
	if $self->field('account')->has_error_fields;

      $i++;
    }
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
  
    # to rewrite due to loginless_ssh removal #     #---[ ssh + ]------------------------------------------------
    # to rewrite due to loginless_ssh removal #     my $sshpubkeyuniq;
    # to rewrite due to loginless_ssh removal #     $i = 0;
    # to rewrite due to loginless_ssh removal #     foreach $element ( $self->field('loginless_ssh')->fields ) {
    # to rewrite due to loginless_ssh removal #       if ( defined $element->field('associateddomain')->value &&
    # to rewrite due to loginless_ssh removal # 	   ! defined $element->field('key')->value &&
    # to rewrite due to loginless_ssh removal # 	   ! defined $element->field('keyfile')->value ) { # fqdn but no key
    # to rewrite due to loginless_ssh removal # 	$element->field('key')->add_error('Either Key, KeyFile or both field/s have to be defined!');
    # to rewrite due to loginless_ssh removal # 	$element->field('keyfile')->add_error('Either KeyFile, Key or both field/s have to be defined!');
    # to rewrite due to loginless_ssh removal #       } elsif ( ( defined $element->field('key')->value ||
    # to rewrite due to loginless_ssh removal # 		  defined $element->field('keyfile')->value ) &&
    # to rewrite due to loginless_ssh removal # 		! defined $element->field('associateddomain')->value ) { # key but no fqdn
    # to rewrite due to loginless_ssh removal # 	$element->field('associateddomain')->add_error('Domain field have to be defined!');
    # to rewrite due to loginless_ssh removal #       } elsif ( ! defined $element->field('key')->value &&
    # to rewrite due to loginless_ssh removal # 		! defined $element->field('keyfile')->value &&
    # to rewrite due to loginless_ssh removal # 		! defined $element->field('associateddomain')->value &&
    # to rewrite due to loginless_ssh removal # 		$i > 0 ) {	# empty duplicatee
    # to rewrite due to loginless_ssh removal # 	$self->add_form_error('<span class="fa-stack fa-fw">' .
    # to rewrite due to loginless_ssh removal # 			      '<i class="fa fa-cog fa-stack-2x text-muted umi-opacity05"></i>' .
    # to rewrite due to loginless_ssh removal # 			      '<i class="fa fa-user-times pull-right fa-stack-1x"></i></span>' .
    # to rewrite due to loginless_ssh removal # 			      '<b class="visible-lg-inline">&nbsp;NoPass&nbsp;</b>' .
    # to rewrite due to loginless_ssh removal # 			      '<b> <i class="fa fa-arrow-right"></i> SSH:</b> Empty duplicatee! Fill it or remove, please');
    # to rewrite due to loginless_ssh removal #       }
    # to rewrite due to loginless_ssh removal # 
    # to rewrite due to loginless_ssh removal #       # prepare to know if fqdn+key+keyfile is uniq?
    # to rewrite due to loginless_ssh removal #       $sshpubkeyuniq->{associateddomain} = $element->field('associateddomain')->value // '';
    # to rewrite due to loginless_ssh removal #       $sshpubkeyuniq->{key} =              $element->field('key')->value // '';
    # to rewrite due to loginless_ssh removal #       $sshpubkeyuniq->{keyfile} =          $element->field('keyfile')->value->{filename} // '';
    # to rewrite due to loginless_ssh removal #       $sshpubkeyuniq->{hash} = sprintf('%s%s%s',
    # to rewrite due to loginless_ssh removal # 				       $sshpubkeyuniq->{associateddomain},
    # to rewrite due to loginless_ssh removal # 				       $sshpubkeyuniq->{key},,
    # to rewrite due to loginless_ssh removal # 				       $sshpubkeyuniq->{keyfile});
    # to rewrite due to loginless_ssh removal #       $elementcmp->{$sshpubkeyuniq->{hash}} = ! $i ? 1 : $elementcmp->{$sshpubkeyuniq->{hash}}++;
    # to rewrite due to loginless_ssh removal # 
    # to rewrite due to loginless_ssh removal #       # validate keyfile if provided
    # to rewrite due to loginless_ssh removal #       my $sshpubkey_hash = {};
    # to rewrite due to loginless_ssh removal #       my ( $sshpubkey, $key_file, $key_file_msg );
    # to rewrite due to loginless_ssh removal #       if ( defined $element->field('keyfile')->value &&
    # to rewrite due to loginless_ssh removal # 	   ref($element->field('keyfile')->value) eq 'Catalyst::Request::Upload' ) {
    # to rewrite due to loginless_ssh removal # 	$key_file = $self->file2var( $element->field('keyfile')->value->{tempname}, $key_file_msg, 1);
    # to rewrite due to loginless_ssh removal # 	$element->field('keyfile')->add_error($key_file_msg->{error})
    # to rewrite due to loginless_ssh removal # 	  if defined $key_file_msg->{error};
    # to rewrite due to loginless_ssh removal # 	foreach (@{$key_file}) {
    # to rewrite due to loginless_ssh removal # 	  my $abc = $_;
    # to rewrite due to loginless_ssh removal # 	  if ( ! $self->sshpubkey_parse(\$abc, $sshpubkey_hash) ) {
    # to rewrite due to loginless_ssh removal # 	    $self->add_form_error('<span class="fa-stack fa-fw">' .
    # to rewrite due to loginless_ssh removal # 				  '<i class="fa fa-cog fa-stack-2x text-muted umi-opacity05"></i>' .
    # to rewrite due to loginless_ssh removal # 				  '<i class="fa fa-user-times pull-right fa-stack-1x"></i></span>' .
    # to rewrite due to loginless_ssh removal # 				  '<b class="visible-lg-inline">&nbsp;NoPass&nbsp;</b>' .
    # to rewrite due to loginless_ssh removal # 				  '<b> <i class="fa fa-arrow-right"></i> SSH:</b> ' . $sshpubkey_hash->{error});
    # to rewrite due to loginless_ssh removal # 	  }
    # to rewrite due to loginless_ssh removal # 	  $sshpubkey_hash = {};
    # to rewrite due to loginless_ssh removal # 	}
    # to rewrite due to loginless_ssh removal #       }
    # to rewrite due to loginless_ssh removal #       
    # to rewrite due to loginless_ssh removal #       $sshpubkey = defined $element->field('key')->value ? $element->field('key')->value : undef;
    # to rewrite due to loginless_ssh removal #       if( defined $sshpubkey && ! $self->sshpubkey_parse(\$sshpubkey, $sshpubkey_hash) ) {
    # to rewrite due to loginless_ssh removal # 	$self->add_form_error('<span class="fa-stack fa-fw">' .
    # to rewrite due to loginless_ssh removal # 			      '<i class="fa fa-cog fa-stack-2x text-muted umi-opacity05"></i>' .
    # to rewrite due to loginless_ssh removal # 			      '<i class="fa fa-user-times pull-right fa-stack-1x"></i></span>' .
    # to rewrite due to loginless_ssh removal # 			      '<b class="visible-lg-inline">&nbsp;NoPass&nbsp;</b>' .
    # to rewrite due to loginless_ssh removal # 			      '<b> <i class="fa fa-arrow-right"></i> SSH:</b> ' . $sshpubkey_hash->{error});
    # to rewrite due to loginless_ssh removal #       }
    # to rewrite due to loginless_ssh removal #       $i++;
    # to rewrite due to loginless_ssh removal #     }
    # to rewrite due to loginless_ssh removal # 
    # to rewrite due to loginless_ssh removal #     foreach $element ( $self->field('loginless_ssh')->fields ) {
    # to rewrite due to loginless_ssh removal #       $sshpubkeyuniq->{associateddomain} = defined $element->field('associateddomain')->value ?
    # to rewrite due to loginless_ssh removal # 	$element->field('associateddomain')->value : '';
    # to rewrite due to loginless_ssh removal #       $sshpubkeyuniq->{key} = defined $element->field('key')->value ?
    # to rewrite due to loginless_ssh removal # 	$element->field('key')->value : '';
    # to rewrite due to loginless_ssh removal #       $sshpubkeyuniq->{keyfile} = defined $element->field('keyfile')->value ?
    # to rewrite due to loginless_ssh removal # 	$element->field('keyfile')->value->{filename} : '';
    # to rewrite due to loginless_ssh removal #       $sshpubkeyuniq->{hash} = sprintf('%s%s%s',
    # to rewrite due to loginless_ssh removal # 				       $sshpubkeyuniq->{associateddomain},
    # to rewrite due to loginless_ssh removal # 				       $sshpubkeyuniq->{key},,
    # to rewrite due to loginless_ssh removal # 				       $sshpubkeyuniq->{keyfile});
    # to rewrite due to loginless_ssh removal #       $element->field('key')->add_error('The same key is defined more than once for the same FQDN')
    # to rewrite due to loginless_ssh removal # 	if $elementcmp->{$sshpubkeyuniq->{hash}} > 1 &&
    # to rewrite due to loginless_ssh removal # 	$sshpubkeyuniq->{keyfile} eq '' &&
    # to rewrite due to loginless_ssh removal # 	$sshpubkeyuniq->{key} ne '';
    # to rewrite due to loginless_ssh removal #       $element->field('keyfile')->add_error('The same keyfile is defined more than once for the same FQDN')
    # to rewrite due to loginless_ssh removal # 	if $elementcmp->{$sshpubkeyuniq->{hash}} > 1 &&
    # to rewrite due to loginless_ssh removal # 	$sshpubkeyuniq->{key} eq '' &&
    # to rewrite due to loginless_ssh removal # 	$sshpubkeyuniq->{keyfile} ne '';
    # to rewrite due to loginless_ssh removal #       $element->field('key')->add_error('The same key and keyfile are defined more than once for the same FQDN')
    # to rewrite due to loginless_ssh removal # 	if $elementcmp->{$sshpubkeyuniq->{hash}} > 1 &&
    # to rewrite due to loginless_ssh removal # 	$sshpubkeyuniq->{keyfile} ne '' &&
    # to rewrite due to loginless_ssh removal # 	$sshpubkeyuniq->{key} ne '';
    # to rewrite due to loginless_ssh removal #     }
    # to rewrite due to loginless_ssh removal # 
    # to rewrite due to loginless_ssh removal #     $self->add_form_error('<span class="fa-stack fa-fw">' .
    # to rewrite due to loginless_ssh removal # 			  '<i class="fa fa-cog fa-stack-2x text-muted umi-opacity05"></i>' .
    # to rewrite due to loginless_ssh removal # 			  '<i class="fa fa-user-times pull-right fa-stack-1x"></i></span>' .
    # to rewrite due to loginless_ssh removal # 			  '<b class="visible-lg-inline">&nbsp;NoPass&nbsp;</b>' .
    # to rewrite due to loginless_ssh removal # 			  '<b> <i class="fa fa-arrow-right"></i> SSH:</b> Has error/s! Correct or remove, please')
    # to rewrite due to loginless_ssh removal #       if $self->field('loginless_ssh')->has_error_fields;
    # to rewrite due to loginless_ssh removal #   
    # to rewrite due to loginless_ssh removal #     #---[ ssh - ]------------------------------------------------

    #----------------------------------------------------------
    #== VALIDATION password less ------------------------------
    #----------------------------------------------------------
  
    #---[ OpenVPN + ]--------------------------------------------
    my $ovpn_tmp;
    $i = 0;
    foreach $element ( $self->field('loginless_ovpn')->fields ) {
      # p $_->value foreach ($element->field('userCertificate'));

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
	} elsif ( ! defined $element->field('userCertificate')->value ) {
	  $element->field('userCertificate')->add_error('userCertificate is mandatory!');
	  $self->add_form_error('<span class="fa-stack fa-fw">' .
				'<i class="fa fa-cog fa-stack-2x text-muted umi-opacity05"></i>' .
				'<i class="fa fa-user-times pull-right fa-stack-1x"></i></span>' .
				'<b class="visible-lg-inline">&nbsp;NoPass&nbsp;</b>' .
				'<b> <i class="fa fa-arrow-right"></i> OpenVPN:</b> userCertificate is mandatory!<br>');
	}
      }

      if ( defined $element->field('ifconfigpush')->value &&
	   $element->field('ifconfigpush')->value =~ /^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-5][0-9]) (([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-5][0-9])$/ ) {
	# $ovpn_tmp = $self->vld_ifconfigpush({
	# 				     concentrator_fqdn => $element->field('associateddomain')->value,
	# 				     ifconfigpush => $element->field('ifconfigpush')->value,
	# 				     mode => lc( $element->field('devos')->value ) eq 'windows' ? 'net30' : '',
	# 				    });

	$ovpn_tmp = 0; # HARDCODE !!! logics of vld_ifconfigpush NEED TO BE FIXED !!!
	$mesg =
	  $ldap_crud->search({ filter => '(&(umiOvpnAddStatus=active)(umiOvpnCfgIfconfigPush=' .
			       $element->field('ifconfigpush')->value . '))',
			       base => $ldap_crud->cfg->{base}->{acc_root},
			       attrs => [ 'umiOvpnCfgIfconfigPush' ], });
	
	if ( $mesg->count ) {
	  $entry = $mesg->entry(0);
	  $element->field('ifconfigpush')
	    ->add_error( sprintf('The same addresses are used for account: <span class="mono"><b>%s</b></span>', $entry->dn) );
	} elsif ( $ovpn_tmp ) {
	  $element->field('ifconfigpush')->add_error( $ovpn_tmp->{error} );
	}
      } elsif ( defined $element->field('ifconfigpush')->value &&
		$element->field('ifconfigpush')->value !~ /^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-5][0-9]) (([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-5][0-9])$/ ) {
      	$element->field('ifconfigpush')->add_error( 'The input is not two IP addresses!' );
      }

      #
      ## !!! add check for this cert existance !!! since when it is absent in the input data, PSGI falls
      #

      $i++;
    }

    $self->add_form_error('<span class="fa-stack fa-fw">' .
			  '<i class="fa fa-cog fa-stack-2x text-muted umi-opacity05"></i>' .
			  '<i class="fa fa-lock-open pull-right fa-stack-1x"></i></span>' .
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

sub physicaldeliveryofficename {
  my $self = shift;
  return unless $self->form->ldap_crud;
  return $self->form->ldap_crud->select_offices;
}

# sub groups {
#   my $self = shift;
#   return unless $self->form->ldap_crud;
#   use Data::Printer;
#   p my $groups = $self->form->ldap_crud->select_group;
#   return $groups;
# }

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

sub radgroup {
  my $self = shift;
  return unless $self->form->ldap_crud;
  return $self->form->ldap_crud->select_radgroup;
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

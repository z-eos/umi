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
use POSIX;
use Net::CIDR::Set;

# has '+error_message' => ( default => 'There were errors in your form.' );has '+item_class' => ( default =>'UserAll' );
has '+enctype'       => ( default => 'multipart/form-data');
has '+action'        => ( default => '/userall');
has 'namesake'       => ( is => 'rw', );
has 'autologin'      => ( is => 'rw', );
has 'add_svc_acc'    => ( is => 'rw', ); # set if we add service account rather than new user
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
       label_class           => [ 'col-2', 'text-right', 'font-weight-bold', ],
       element_wrapper_class => [ 'col-8', 'col-md-10' ],
       element_class         => [ 'input-sm', ],
       wrapper_class         => [ 'row' ],
       element_attr          => { placeholder => 'John' },
       required              => 1 );

has_field 'person_sn'
  => ( apply                 => [ NoSpaces ],
       label                 => 'LName',
       label_class           => [ 'col-2', 'text-right', 'font-weight-bold', ],
       element_wrapper_class => [ 'col-8', 'col-md-10' ],
       element_class         => [ 'input-sm', ],
       element_attr          => { placeholder => 'Doe' },
       wrapper_class         => [ 'row' ],
       required              => 1 );

has_field 'person_exp'
  => ( type          => 'Display',
       html          => sprintf('
<div class="form-group row">
  <label class="col-2 text-right font-weight-bold control-label atleastone" title="Object Expiration">
    Exp.
  </label>
  <div class="col-4">
    <div class="">
      <div class="input-group date" id="person_exp" data-target-input="nearest">
        <input name="person_exp" type="text" class="form-control datetimepicker-input" data-target="#person_exp"/>
        <div class="input-group-append" data-target="#person_exp" data-toggle="datetimepicker">
          <div class="input-group-text"><i class="far fa-lg fa-calendar-alt"></i></div>
        </div>
      </div>
    </div>
  </div>
</div>'),
       wrapper_class => [ 'row', ],
     );

# has_field 'person_exp'
#   => ( type                  => 'Text',
#        label                 => 'Exp.',
#        label_attr            => { title => 'Object Expiration', },
#        label_class           => [ 'col-2', 'text-right', 'font-weight-bold', ],
#        element_wrapper_class => [ 'col-8', 'col-md-10' ],
#        element_class         => [ 'input-sm', ],
#        element_attr          => { placeholder => 'Expiration on',
# 				  title       => 'Object Expiration', },
#        wrapper_class         => [ 'row' ],
#        required              => 0 );

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
       label_class           => [ 'col-2', 'text-right', 'font-weight-bold', ],
       element_wrapper_class => [ 'col-8', 'col-md-10' ],
       element_class         => [ 'btn', 'btn-secondary', 'btn-sm', ],
       wrapper_class         => [ 'row' ],
       max_size => '50000' );

has_field 'person_gidnumber'
  => ( type                  => 'Select',
       label                 => 'Group',
       label_class           => [ 'col-2', 'text-right', 'font-weight-bold', ],
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
       label_class           => [ 'col-2', 'text-right', 'font-weight-bold', ],
       empty_select          => '--- Choose an Organization ---',
       element_wrapper_class => [ 'col-8', 'col-md-10' ],
       element_class         => [ 'input-sm', 'custom-select', ],
       wrapper_class         => [ 'row' ],
       options_method        => \&offices,
       required              => 1 );

has_field 'person_title'
  => ( label                 => 'Position',
       label_class           => [ 'col-2', 'text-right', 'font-weight-bold', ],
       element_wrapper_class => [ 'col-8', 'col-md-10' ],
       element_class         => [ 'input-sm', ],
       element_attr          => { placeholder => 'manager' },
       wrapper_class         => [ 'row' ], );

has_field 'person_office'
  => ( type                  => 'Select',
       label                 => 'Office',
       label_class           => [ 'col-2', 'text-right', 'font-weight-bold', ],
       empty_select          => '--- Choose an Office ---',
       element_wrapper_class => [ 'col-8', 'col-md-10' ],
       element_class         => [ 'input-sm', 'custom-select', ],
       options_method        => \&physicaldeliveryofficename,
       wrapper_class         => [ 'row' ],
       required              => 1 );

has_field 'person_telephonenumber'
  => ( apply                 => [ NoSpaces ],
       label                 => 'SIP/Cell',
       label_class           => [ 'col-2', 'text-right', 'font-weight-bold', ],
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
       label_class           => [ 'col-2', 'text-right', 'font-weight-bold', ],
       element_wrapper_class => [ 'col-8', 'col-md-10' ],
       element_class         => [ 'input-sm', ],
       element_attr          => { placeholder => 'john.doe', },
       wrapper_class         => [ 'row' ], );

has_field 'person_associateddomain'
  => ( type                  => 'Select',
       wrapper_attr          => { id => 'simplified', },
       wrapper_class         => [ qw{ simplified row show-on-simplified }, ],
       label                 => 'Domain Name',
       label_class           => [ 'col-2', 'text-right', 'font-weight-bold', 'required' ],
       empty_select          => '--- Choose Domain ---',
       # element_attr          => { disabled => 'dissabled', },
       element_wrapper_class => [ 'col-8', 'col-md-10' ],
       element_class         => [ 'input-sm', 'custom-select', ],
       options_method        => \&associateddomains,
       required              => 0 );

has_field 'person_password1'
  => ( type                  => 'Password',
       label                 => 'Password',
       label_class           => [ 'col-2', 'text-right', 'font-weight-bold', ],
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
       label_class           => [ 'col-2', 'text-right', 'font-weight-bold', ],
       element_wrapper_class => [ 'col-8', 'col-md-10' ],
       element_class         => [ 'input-sm', ],
       ne_username           => 'login',
       apply                 => [ NoSpaces, NotAllDigits, Printable, StrongPassword ],
       element_attr          => { placeholder => 'Confirm Password',
				  'autocomplete' => 'off', },
       wrapper_class         => [ 'row' ],
     );


has_field 'person_mail'
  => ( type                  => 'Email',
       label                 => 'Email',
       label_class           => [ 'col-2', 'text-right', 'font-weight-bold', ],
       element_wrapper_class => [ 'col-8', 'col-md-10' ],
       element_class         => [ 'input-sm', ],
       ne_username           => 'mail',
       apply                 => [ NoSpaces, NotAllDigits, Printable, ],
       element_attr          => { placeholder => 'someuser@example.com',
				  'autocomplete' => 'off', },
       wrapper_class         => [ 'row' ],
     );


has_field 'person_description'
  => ( type                  => 'TextArea',
       label                 => 'Description',
       label_class           => [ 'col-2', 'text-right', 'font-weight-bold', ],
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
			'person_mail',
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
       element_class         => [ qw{ target-container conditional-input }, ],
       element_wrapper_class => [ qw{controls}, ],
       wrapper_attr          => { class => 'no-has-error' },
       # wrap_repeatable_element_method => \&wrap_account_elements,
       # wrapper_class         => [ qw{ target-container conditional-input }, ],
       # init_contains => { element_class => [ qw{hfh repinst target-container conditional-input} ], },
     );

# sub wrap_account_elements {
#   my ( $self, $input, $subfield ) = @_;
#   # my $output = sprintf('%s%s%s', ! $subfield ? qq{\n<div class="duplicate">} : qq{\n<div class="duplicated">},
#   # 		       $input,
#   # 		       qq{</div>});
#   my $output = sprintf('%s%s%s', qq{\n<div class="target-container conditional-input">}, $input, qq{</div>});
# }

has_field 'account.associateddomain'
  => ( type                  => 'Select',
       label                 => 'Domain Name',
       label_class           => [ 'col-2', 'text-right', 'font-weight-bold', ],
       empty_select          => '--- Choose Domain ---',
       element_wrapper_class => [ 'col-8', 'col-md-10' ],
       element_class         => [ 'input-sm', 'custom-select', ],
       options_method        => \&associateddomains,
       wrapper_class         => [ 'row' ],
       required => 0 );

has_field 'account.authorizedservice'
  => ( type                  => 'Select',
       label                 => 'Service',
       label_class           => [ 'col-2', 'text-right', 'font-weight-bold', ],
       empty_select          => '--- Choose Service ---',
       element_wrapper_class => [ 'col-8', 'col-md-10' ],
       element_class         => [ 'input-sm', 'custom-select', ],
       options_method        => \&authorizedservice,
       wrapper_class         => [ 'row' ],
       required => 0,
     );

has_field 'account.login'
  => ( apply                 => [ NoSpaces, NotAllDigits, Printable, NonEmptyStr ],
       label                 => 'Login',
       do_id                 => 'no',
       label_class           => [ 'col-2', 'text-right', 'font-weight-bold', ],
       element_wrapper_class => [ 'col-8', 'col-md-10' ],
       element_class         => [ 'input-sm', ],
       element_attr          => { placeholder => 'john.doe',
				  title => 'login to be added with @domain in the end; root uid is used if not provided.',
				  'autocomplete' => 'off', },
       wrapper_class         => [ 'row' ],
     );

has_field 'account.login_complex'
  => ( type                  => 'Checkbox',
       label                 => 'complex login (example: login @ domain)',
       element_attr          => { title               => 'login will be added with @domain', },
       element_class         => [ 'form-check-input', ],
       element_wrapper_class => [ 'offset-2 col-8', 'col-md-10' ],
       wrapper_class         => [  qw{ form-check row conditional-input on-mail on-ssh-acc}, ],
       checkbox_value        => '1',
     );

has_field 'account.password1'
  => ( type                  => 'Password',
       minlength             => 7, maxlength => 128,
       label                 => 'Password',
       label_class           => [ 'col-2', 'text-right', 'font-weight-bold', ],
       wrapper_class         => [  qw{ row conditional-input on-comm-acc on-xmpp on-gitlab on-web
				       on-mail on-ssh-acc on-dot1x-eap-tls }, ],
       element_wrapper_class => [ 'col-8', 'col-md-10' ],
       element_class         => [ 'input-sm', ],
       ne_username           => 'login',
       apply                 => [ NoSpaces, NotAllDigits, Printable, StrongPassword ],
       element_attr          => { placeholder    => 'Password',
				  'autocomplete' => 'off', },
     );

has_field 'account.password2'
  => ( type                  => 'Password',
       minlength             => 7, maxlength => 128,
       label                 => '',
       label_class           => [ 'col-2', 'text-right', 'font-weight-bold', ],
       wrapper_class         => [  qw{ row conditional-input on-comm-acc on-xmpp on-gitlab on-web
				       on-mail on-ssh-acc on-dot1x-eap-tls }, ],
       element_wrapper_class => [ 'col-8', 'col-md-10' ],
       element_class         => [ 'input-sm', ],
       ne_username           => 'login',
       apply                 => [ NoSpaces, NotAllDigits, Printable, StrongPassword ],
       element_attr          => { placeholder    => 'Confirm Password',
				  'autocomplete' => 'off', },
     );

has_field 'account.radiusgroupname'
  => ( type                  => 'Select',
       label                 => 'RADIUS Group',
       do_id                 => 'no',
       label_class           => [ 'col-2', 'text-right', 'font-weight-bold', 'atleastone' ],
       element_wrapper_class => [ 'col-8', 'col-md-10' ],
       element_class         => [ 'input-sm', 'custom-select', ],
       empty_select          => '--- Choose RADIUS default Group ---',
       options_method        => \&radgroup,
       wrapper_class         => [  qw{ row conditional-input on-dot1x-eap-tls on-dot1x-eap-md5 }, ],
     );

has_field 'account.radiusprofiledn'
  => ( type                  => 'Select',
       label                 => 'RADIUS Profile',
       do_id                 => 'no',
       label_class           => [ 'col-2', 'text-right', 'font-weight-bold', 'atleastone', ],
       element_wrapper_class => [ 'col-8', 'col-md-10' ],
       element_class         => [ 'input-sm', 'custom-select', ],
       element_attr          => { 'autocomplete' => 'off', },
       empty_select          => '--- Choose RADIUS Profile ---',
       options_method        => \&radprofile,
       wrapper_class         => [  qw{ row conditional-input on-dot1x-eap-tls on-dot1x-eap-md5 }, ],
     );

has_field 'account.userCertificate'
  => ( type                  => 'Upload',
       label                 => 'Cert (.DER)',
       do_id                 => 'no',
       label_class           => [ 'col-2', 'text-right', 'font-weight-bold', 'required', ],
       element_wrapper_class => [ 'col-8', 'col-md-10' ],
       element_class         => [ 'btn', 'btn-default', 'btn-sm', 'btn-secondary', ],
       wrapper_class         => [  qw{ row conditional-input on-dot1x-eap-tls on-dot1x-eap-md5 }, ],
     );

has_field 'account.sshgid'
  => ( apply                 => [ PositiveInt ],
       label                 => 'gidNumber',
       do_id                 => 'no',
       label_class           => [ 'col-2', 'text-right', 'font-weight-bold', ],
       element_wrapper_class => [ 'col-8', 'col-md-10' ],
       element_class         => [ 'input-sm', 'text-monospaced' ],
       element_attr          => { placeholder    => 'default is 11102 (ssh-ci)',
				  title          => 'Group ID of the user.',
				  'autocomplete' => 'off', },
       wrapper_class         => [  qw{ row conditional-input on-ssh-acc }, ],
     );

has_field 'account.sshhome'
  => ( apply                 => [ NoSpaces, NotAllDigits, Printable ],
       label                 => 'homeDir',
       do_id                 => 'no',
       label_class           => [ 'col-2', 'text-right', 'font-weight-bold', ],
       element_wrapper_class => [ 'col-8', 'col-md-10' ],
       element_class         => [ 'input-sm', 'mono' ],
       element_attr          => { placeholder    => '/nonexistent',
				  title          => 'Home directory of the user.',
				  'autocomplete' => 'off', },
       wrapper_class         => [  qw{ row conditional-input on-ssh-acc }, ],
     );

has_field 'account.sshshell'
  => ( apply                 => [ NoSpaces, NotAllDigits, Printable ],
       label                 => 'loginShell',
       do_id                 => 'no',
       label_class           => [ 'col-2', 'text-right', 'font-weight-bold', ],
       element_wrapper_class => [ 'col-8', 'col-md-10' ],
       element_class         => [ 'input-sm', 'mono' ],
       element_attr          => { placeholder    => '/bin/bash',
				  title          => 'Shell of the user.',
				  'autocomplete' => 'off', },
       wrapper_class         => [  qw{ row conditional-input on-ssh-acc }, ],
     );

has_field 'account.sshkey'
  => ( type                  => 'TextArea',
       do_id                 => 'no',
       label                 => 'SSH Pub Key',
       label_class           => [ 'col-2', 'text-right', 'font-weight-bold', 'required', ],
       element_wrapper_class => [ 'col-8', 'col-md-10' ],
       element_class         => [ 'input-sm', 'text-monospaced', ],
       element_attr          => { title        => 'Paste SSH key (read sshd(8) section AUTHORIZED_KEYS FILE FORMAT for reference)',
				  placeholder  => q{command=&quot;...&quot;, environment=&quot;NAME=value&quot;,...,from=&quot;...&quot; no-agent-forwarding,no-port-forwarding,no-pty,no-user-rc,no-x11-forwarding,permitopen=&quot;host:port&quot;,tunnel=&quot;n&quot; ssh-rsa AAA...bZN Lorem ipsum dolor sit amet potenti}, },
       cols                  => 30, rows => 4,
       wrapper_class         => [  qw{ row conditional-input on-ssh-acc }, ],
     );


has_field 'account.sshkeyfile'
  => ( type                  => 'Upload',
       do_id                 => 'no',
       label                 => 'SSH Pub Key/s File',
       label_class           => [ 'col-2', 'text-right', 'font-weight-bold', 'required', ],
       element_wrapper_class => [ 'col-8', 'col-md-10' ],
       element_class         => [ 'btn', 'btn-default', 'btn-sm', 'btn-secondary', ],
       element_attr          => {title        => 'SSH key file (read sshd(8) section AUTHORIZED_KEYS FILE FORMAT for reference)', },
       wrapper_class         => [  qw{ row conditional-input on-ssh-acc }, ],
     );


has_field 'account.description'
  => ( type                  => 'TextArea',
       label                 => 'Description',
       label_class           => [ 'col-2', 'text-right', 'font-weight-bold', ],
       element_wrapper_class => [ 'col-8', 'col-md-10' ],
       element_class         => [ 'input-sm', ],
       element_attr          => { placeholder    => 'Any description.',
				  'autocomplete' => 'off', },
       cols                  => 30, rows => 1,
       wrapper_class         => [ 'row', ], );

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
       label_class           => [ 'col-2', 'text-right', 'font-weight-bold', ],
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
       label_class           => [ 'col-2', 'text-right', 'font-weight-bold', 'required' ],
       empty_select          => '--- Choose Domain ---',
       element_wrapper_class => [ 'col-8', 'col-md-10' ],
       element_class         => [ 'input-sm', 'custom-select', ],
       options_method        => \&associateddomains,
       element_attr          => { title        => 'FQDN of the VPN server, client is configured for', },
       wrapper_class         => [ 'row', ],
     );

has_field 'loginless_ovpn.userCertificate'
  => ( type                  => 'Upload',
       label                 => 'Cert (.DER)',
       label_class           => [ 'col-2', 'text-right', 'font-weight-bold', 'required' ],
       element_wrapper_class => [ 'col-8', 'col-md-10' ],
       element_class         => [ 'btn', 'btn-default', 'btn-sm', 'btn-secondary', ],
       wrapper_class         => [ 'row', ],
     );

has_field 'loginless_ovpn.ifconfigpush'
  => ( apply                 => [ Printable, ],
       label                 => 'Ifconfig',
       label_class           => [ 'col-2', 'text-right', 'font-weight-bold', 'required', ],
       element_wrapper_class => [ 'col-8', 'col-md-10' ],
       element_class         => [ 'input-sm', ],
       element_attr          => { placeholder  => '10.0.91.1 10.0.91.2 or 10.0.97.135 10.0.97.1 or 10.13.83.192 10.0.97.1',
				  title        => 'openvpn(8) option &#96;--ifconfig l rn&#39; (Set TUN/TAP adapter parameters.  l is the IP address of the local VPN endpoint. rn is the IP address of the remote VPN endpoint.)', },
       wrapper_class         => [ 'row', ],
     );

has_field 'loginless_ovpn.iroute'
  => ( apply                 => [ Printable, ],
       label                 => 'Iroute',
       label_class           => [ 'col-2', 'text-right', 'font-weight-bold', ],
       element_wrapper_class => [ 'col-8', 'col-md-10' ],
       element_class         => [ 'input-sm', ],
       element_attr          => { placeholder  => '10.0.99.2 255.255.255.0',
				  title        => 'openvpn(8) option &#96;--iroute network [netmask]&#39; (Generate an internal route to a specific client. The netmask parameter, if omitted, defaults to 255.255.255.255.)', },
       wrapper_class         => [ 'row', ],
     );

has_field 'loginless_ovpn.push'
  => ( apply                 => [ Printable, ],
       label                 => 'Push',
       label_class           => [ 'col-2', 'text-right', 'font-weight-bold', ],
       element_wrapper_class => [ 'col-8', 'col-md-10' ],
       element_class         => [ 'input-sm', ],
       element_attr          => { placeholder  => 'route 192.168.222.144 255.255.255.128',
				  title        => 'openvpn(8) option &#96;--push option&#39; (Push a config file option back to the client for remote execution.)', },
       wrapper_class         => [ 'row', ],
     );

has_field 'loginless_ovpn.devtype'
  => ( apply                 => [ NoSpaces, Printable ],
       label                 => 'Device Type',
       label_class           => [ 'col-2', 'text-right', 'font-weight-bold', ],
       element_wrapper_class => [ 'col-8', 'col-md-10' ],
       element_class         => [ 'input-sm', ],
       element_attr          => { placeholder  => 'notebook, netbook, smartphone',
				  title        => 'OS type (defines which address to assign: /30 for Win like and /32 for XNIX like)', },
       wrapper_class         => [ 'row', ],
     );

has_field 'loginless_ovpn.devos'
  => ( apply                 => [ Printable ],
       label                 => 'OS',
       label_class           => [ 'col-2', 'text-right', 'font-weight-bold', 'required', ],
       element_wrapper_class => [ 'col-8', 'col-md-10' ],
       element_class         => [ 'input-sm', ],
       element_attr          => { placeholder  => 'xNIX, MacOS, Android, Windows', },
       wrapper_class         => [ 'row', ],
     );

has_field 'loginless_ovpn.config'
  => ( apply                 => [ Printable, ],
       label                 => 'Config',
       label_class           => [ 'col-2', 'text-right', 'font-weight-bold', ],
       element_wrapper_class => [ 'col-8', 'col-md-10' ],
       element_class         => [ 'input-sm', ],
       element_attr          => { placeholder  => 'path/to/some/additional/configfile.conf',
				  title        => 'openvpn(8) option &#96;--config&#39; (Load additional config options from file where each line corresponds to one command line option, but with the leading &#39;--&#39; removed.)', },
       wrapper_class         => [ 'row', ],
     );

has_field 'loginless_ovpn.devmake'
  => ( apply                 => [ Printable ],
       label                 => 'Device Maker',
       label_class           => [ 'col-2', 'text-right', 'font-weight-bold', ],
       element_wrapper_class => [ 'col-8', 'col-md-10' ],
       element_class         => [ 'input-sm', ],
       element_attr          => { placeholder  => 'HP, Dell, Asus, Lenovo', },
       wrapper_class         => [ 'row', ],
     );

has_field 'loginless_ovpn.devmodel'
  => ( apply                 => [ Printable ],
       label                 => 'Device Model',
       label_class           => [ 'col-2', 'text-right', 'font-weight-bold', ],
       element_wrapper_class => [ 'col-8', 'col-md-10' ],
       element_class         => [ 'input-sm', ],
       element_attr          => { placeholder  => 'Pavilion dm1', },
       wrapper_class         => [ 'row', ],
     );

has_field 'loginless_ovpn.devosver'
  => ( apply                 => [ Printable ],
       label                 => 'OS version',
       label_class           => [ 'col-2', 'text-right', 'font-weight-bold', ],
       element_wrapper_class => [ 'col-8', 'col-md-10' ],
       element_class         => [ 'input-sm', ],
       element_attr          => { placeholder  => '1.2.3', },
       wrapper_class         => [ 'row', ],
     );

has_field 'loginless_ovpn.description'
  => ( type                  => 'TextArea',
       label                 => 'Description',
       label_class           => [ 'col-2', 'text-right', 'font-weight-bold', ],
       element_wrapper_class => [ 'col-8', 'col-md-10' ],
       element_class         => [ 'input-sm', ],
       element_attr          => { placeholder  => 'Any description.',
				  autocomplete => 'off', },
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
       element_wrapper_class => [ '', ],
       element_class         => [ 'input-sm', 'umi-multiselect2', 'w-100', ],
       options_method        => \&group,
       # required => 1,
     );

sub group {
  my $self = shift;
  return unless $self->form->ldap_crud;
  return $self->form->ldap_crud->select_group;
}

# sub options_groups {
#   my $self = shift;
#   my ( @groups, $return );

#   return unless $self->ldap_crud;

#   my $ldap_crud = $self->ldap_crud;
#   my $mesg = $ldap_crud->search( { base      => $ldap_crud->cfg->{base}->{group},
# 				   scope     => 'one',
# 				   sizelimit => 0,
# 				   attrs     => [ 'cn' ], } );

#   push @{$return->{error}}, $ldap_crud->err($mesg)
#     if ! $mesg->count;

#   my @groups_all = $mesg->sorted('cn');

#   push @groups, { value => $_->get_value('cn'), label => $_->get_value('cn'), }
#     foreach @groups_all;

#   return \@groups;
# }

# has_field 'groupspace'
#   => ( type => 'Display',
#        html => '<p>&nbsp;</p>',
#      );


has_block 'groupsselect'
  => ( tag         => 'fieldset',
       label       => 'Groups, user belongs to',
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

sub check_loginless_ovpn_userCertificate {
  my $self      = shift;
  my $ldap_crud = $self->form->ldap_crud;
  my ( $mesg, %return );
  my $cert_info = $self->form
    ->cert_info({ cert => $self->form->file2var($self->value->tempname, \%return), ts => "%s", });

  $self->add_error( $return{error} ) if defined $return{error};

  # log_debug { np($cert_info) };
  # log_debug { np($self->parent->field('associateddomain')->value) };

  my $now = strftime ("%s", localtime);
  $self->add_error( 'Certificate has passed expiration date' )
    if $now > $cert_info->{'Not  After'};
  $self->add_error( 'Certificate activation date in in the future' )
    if $now < $cert_info->{'Not Before'};

  $mesg =
    $ldap_crud
    ->search({ filter => sprintf("(&(authorizedService=ovpn@%s)(cn=%s))",
				 $self->parent->field('associateddomain')->value,
				 $cert_info->{CN}),
  	       base   => $ldap_crud->cfg->{base}->{acc_root},
  	       attrs  => [ 'cn', 'umiUserCertificateSn', ], } );

  if ( $mesg->count > 0 ) {
    $self
      ->add_error( 'Certificate with the same CN for the same domain already exists' );
  } elsif ( $mesg->is_error ) {
    $self->add_error( $ldap_crud->err($mesg)->{html} );
  }

}

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
      $e, $elementcmp,
      $mesg, $entry,
      $err, $error,
      $re,
      $field,
      $is_x509,
      $ldap_crud,
      $login_error_pfx,
      $logintmp,
      $passwd_acc_filter,
      $autologin_mesg,
      $autologin_entry,
      $a1, $b1, $c1, $k, $filter
     );

  $self->add_svc_acc( $self->field('add_svc_acc')->value )
    if defined $self->field('add_svc_acc')->value;

  $ldap_crud = $self->ldap_crud;

  if ( defined $self->field('person_givenname')->value && defined $self->field('person_sn')->value ) {
    $self->autologin( lc($self->utf2lat( $self->field('person_givenname')->value ) . '.' .
			 $self->utf2lat( $self->field('person_sn')->value )));
  } else {
    # log_debug { 'add_svc_acc: ' . np($self->add_svc_acc) };
    $autologin_mesg =
      $ldap_crud->search({ scope => 'base',
			   base  => $self->add_svc_acc,
			   attrs => [ 'givenName', 'sn', 'uid', 'mail', ], });
    $autologin_entry = $autologin_mesg->entry(0);
    $self->autologin( lc( $autologin_entry->get_value('givenName') . '.' .
			  $autologin_entry->get_value('sn') ) );
  }

  # log_debug { 'add_svc_acc: ' . np($self->add_svc_acc) };
  if ( ! defined $self->add_svc_acc || $self->add_svc_acc eq '' ) {
    $mesg =
      $ldap_crud->search({ scope  => 'one',
			   filter => '(uid=' . $self->autologin . '*)',
			   base   => $ldap_crud->cfg->{base}->{acc_root},
			   attrs  => [ 'uid' ], });

    log_debug { "+++ 1 " . '+' x 70 . "\nnamesake checkbox: " .
		  np($self->field('person_namesake')->value) . "\n" .
    		  "namesake count: " . np($mesg->count) . "\n" .
    		  'base: ' . np($ldap_crud->cfg->{base}->{acc_root}) . "\n" .
    		  'filter: (uid=' . $self->autologin . "*)\n"
    		};

    my $uid_namesake;
    if ( $mesg->count == 1 &&
	 defined $self->field('person_namesake')->value &&
	 $self->field('person_namesake')->value == 1 ) {
      ### 1. namesake is checked, one single account with same givenName, sn exists
      $self->namesake( 1+substr( $mesg->entry(0)->get_value('uid'), length($self->autologin)) );
    } elsif ( $mesg->count &&
	      defined $self->field('person_namesake')->value &&
	      $self->field('person_namesake')->value == 1 ) {
      ### 2. namesake is checked, several accounts with same givenName, sn exist
      my @uids_namesake_suffixes;
      foreach $uid_namesake ( $mesg->entries ) {
	push @uids_namesake_suffixes, 0+substr( $uid_namesake->get_value('uid'),
						length($self->autologin));
      }
      my @uids_namesake_suffixes_desc = sort {$b <=> $a} @uids_namesake_suffixes;
      $self->namesake(++$uids_namesake_suffixes_desc[0]);
    } elsif ( $mesg->count ) {
      ### 3. namesake isn't checked, several accounts with same givenName, sn exist
      $entry = $mesg->entry(0);
      $self->field('person_login')->add_error('Auto-generaged login exists, DN: <em class="text-danger">' . $entry->dn . '</em> (consider to use &laquo;namesake&raquo; checkbox)');
    } else {
      ### 4. namesake isn't checked, none accounts with same givenName, sn exists
      $self->namesake('');
    }
  } else {
    ### 5. additional service to existent account is been processed
    $self->namesake('');
  }

  # not simplified variant start
  if ( ! defined $self->field('person_simplified')->value ||
       $self->field('person_simplified')->value ne '1' ) {
    #----------------------------------------------------------
    #-- VALIDATION for services with password -----------------
    #----------------------------------------------------------
    my $i = 0;
    foreach $e ( $self->field('account')->fields ) {

      # foreach ( $e->fields ) {
      # 	my $nnn = $_->name;
      # 	if ( $nnn eq 'login_complex' ) {
      # 	  log_debug { "+++ 0 " . '+' x 70 . "\nrepeatable account No.$i, field $nnn dump:\n" .
      # 			np( $_, max_depth => 0, class => { inherited => 'all' } ) };
      # 	}
      # }

      # new user, defined neither fqdn nor svc, but login
      if ( $self->add_svc_acc eq '' &&
	   defined $e->field('login')->value &&
	   $e->field('login')->value ne '' &&
	   ((! defined $e->field('authorizedservice')->value &&
	     ! defined $e->field('associateddomain')->value ) ||
	    ( $e->field('authorizedservice')->value eq '' &&
	      $e->field('associateddomain')->value eq '' )) ) {
	$e->field('associateddomain')->add_error('Domain Name is mandatory!');
	$e->field('authorizedservice')->add_error('Service is mandatory!');

      } elsif ( defined $e->field('authorizedservice')->value &&
		$e->field('authorizedservice')->value ne '' &&
		( ! defined $e->field('associateddomain')->value ||
		  $e->field('associateddomain')->value eq '' ) ) { # no fqdn
	$e->field('associateddomain')->add_error('Domain Name is mandatory!');
      } elsif ( defined $e->field('associateddomain')->value &&
		$e->field('associateddomain')->value ne '' &&
		( ! defined $e->field('authorizedservice')->value ||
		  $e->field('authorizedservice')->value eq '' )) { # no svc
	$e->field('authorizedservice')->add_error('Service is mandatory!');
      }

      if ( ( defined $e->field('password1')->value &&
	     ! defined $e->field('password2')->value ) ||
	   ( defined $e->field('password2')->value &&
	     ! defined $e->field('password1')->value ) ) { # only one pass
	$e->field('password1')->add_error('Both or none passwords have to be defined!');
	$e->field('password2')->add_error('Both or none passwords have to be defined!');
      }

      #---[ login preparation for check + ]------------------------------------------------
      # log_debug { 'namesake: ' . np($self->namesake) };
      $k = $ldap_crud->{cfg}->{authorizedService}
	->{$e->field('authorizedservice')->value}->{login_prefix} // '';

      if ( ! defined $e->field('login')->value || $e->field('login')->value eq '' ) {
	$logintmp = sprintf('%s%s%s', $k, $self->autologin, $self->namesake);
	$login_error_pfx = 'Login (autogenerated, since field is empty)';
      } else {
	$logintmp = sprintf('%s%s', $k, $e->field('login')->value);
	$login_error_pfx = 'Login';
      }

      log_debug { "+++ 2 " . '+' x 70 . "\nlogin_complex checkbox, repeatable No.$i exists" }
	if exists $self->params->{account}->[$i]->{login_complex};
      
      $passwd_acc_filter =
	sprintf("(uid=%s%s%s)",
		$logintmp,
		exists $self->params->{account}->[$i]->{login_complex} ?
		$ldap_crud->cfg->{authorizedService}
		->{$e->field('authorizedservice')->value}->{login_delim} : '',
		exists $self->params->{account}->[$i]->{login_complex} ?
		$e->field('associateddomain')->value : '')
	if defined $e->field('associateddomain')->value &&
	$e->field('associateddomain')->value ne '';

      #---[ login preparation for check - ]------------------------------------------------

      #---[ gitlab + ]--------------------------------------------------------------------
      if ( defined $e->field('authorizedservice')->value &&
	   $e->field('authorizedservice')->value =~ /^gitlab.*$/ ) {
	log_debug { np($self->field('person_mail')) };
	if ( ( defined $self->field('person_mail')->value &&
	       $self->field('person_mail')->value ne '' ) ||
	     ( defined $autologin_entry && ref($autologin_entry) eq 'Net::LDAP::Entry' &&
	       ( ! $autologin_entry->exists('mail') ||
		 $autologin_entry->get_value('mail') eq '' ||
		 $autologin_entry->get_value('mail') eq 'NA' ) ) ) {
	  $self->add_form_error('<span class="fa-stack fa-fw">' .
				'<i class="fas fa-cog fa-stack-2x text-muted umi-opacity05"></i>' .
				'<i class="fab fa-gitlab pull-right fa-stack-1x"></i></span>' .
				'<b class="visible-lg-inline">&nbsp;NoEmail&nbsp;</b>' .
				'<b> <i class="fa fa-arrow-right"></i> GitLab:</b> Root object has no email address! Provide valid email, please');
	}
      }
      #---[ gitlab - ]--------------------------------------------------------------------

      #---[ ssh-acc + ]--------------------------------------------------------------------
      if ( defined $e->field('authorizedservice')->value &&
	   $e->field('authorizedservice')->value =~ /^ssh-acc.*$/ ) {

	if ( defined $e->field('associateddomain')->value &&
	     ! defined $e->field('sshkey')->value &&
	     ! defined $e->field('sshkeyfile')->value ) { # fqdn but no key
	  $e->field('sshkey')->add_error('Either Key or KeyFile, or both field/s have to be defined!');
	  $e->field('sshkeyfile')->add_error('Either KeyFile or Key, or both field/s have to be defined!');
	} elsif ( ( defined $e->field('sshkey')->value ||
		    defined $e->field('sshkeyfile')->value ) &&
		  ! defined $e->field('associateddomain')->value ) { # key but no fqdn
	  $e->field('associateddomain')->add_error('Domain field have to be defined!');
	} elsif ( defined $e->field('sshkey')->value &&
		  $e->field('sshkey')->value =~ /.*\n.*/g ) { # new line chars
	  $e->field('sshkey')->add_error('Remove all new line characters ...');
	} elsif ( ! defined $e->field('sshkey')->value &&
		  ! defined $e->field('sshkeyfile')->value &&
		  ! defined $e->field('associateddomain')->value ) { # empty duplicatee
	  $self->add_form_error('<span class="fa-stack fa-fw">' .
				'<i class="fa fa-cog fa-stack-2x text-muted umi-opacity05"></i>' .
				'<i class="fa fa-user-times pull-right fa-stack-1x"></i></span>' .
				'<b class="visible-lg-inline">&nbsp;NoPass&nbsp;</b>' .
				'<b> <i class="fa fa-arrow-right"></i> SSH:</b> Empty duplicatee! Fill it or remove, please');
	}

      }
      #---[ ssh-acc - ]--------------------------------------------------------------------

      #---[ 802.1x + ]---------------------------------------------------------------------
      if ( defined $e->field('authorizedservice')->value &&
	   $e->field('authorizedservice')->value =~ /^dot1x-.*$/ ) {

	if ( $e->field('authorizedservice')->value eq 'dot1x-eap-md5' ) {
	  $e->field('login')->add_error('MAC address is mandatory!')
	    if ! defined $e->field('login')->value || $e->field('login')->value eq '';
	  $e->field('login')->add_error('MAC address is not valid!')
	    if defined $e->field('login')->value && $e->field('login')->value ne '' &&
	    ! $self->macnorm({ mac => $e->field('login')->value });
	  $logintmp = $self->macnorm({ mac => $e->field('login')->value });
	  $login_error_pfx = 'MAC';
	  $passwd_acc_filter = '(cn=' . $logintmp . ')';
	}

	if ( $e->field('authorizedservice')->value eq 'dot1x-eap-tls' ) {
	  if ( defined $e->field('userCertificate')->value &&
	       ref($e->field('userCertificate')->value) eq 'HASH' ) {
	    $cert = $self->file2var( $e->field('userCertificate')->value->{tempname}, $cert_msg);
	    $e->field('userCertificate')->add_error($cert_msg->{error})
	      if defined $cert_msg->{error};
	    $is_x509 = $self->cert_info({ cert => $cert });
	    $e->field('userCertificate')->add_error('Certificate file is broken or not DER format!')
	      if defined $is_x509->{error};
	    $e->field('userCertificate')->add_error('Problems with certificate file<br>' .
							  $is_x509->{error})
	      if defined $is_x509->{error};
	  } elsif ( defined $e->field('userCertificate')->value &&
		    ! defined $e->field('userCertificate')->value->{tempname} ) {
	    $e->field('userCertificate')->add_error('userCertificate file was not uploaded');
	  } elsif ( ! defined $e->field('userCertificate')->value ) {
	    $e->field('userCertificate')->add_error('userCertificate is mandatory!');
	  }
	  $logintmp = 'rad-' . $e->field('login')->value;
	}
	if (( ! defined $e->field('radiusgroupname')->value ||
	      $e->field('radiusgroupname')->value eq '' ) &&
	    ( ! defined $e->field('radiusprofiledn')->value ||
	      $e->field('radiusprofiledn')->value eq '' )) {
	  $e->field('radiusgroupname')->add_error('RADIUS group, profile or both are to be set!');
	  $e->field('radiusprofiledn')->add_error('RADIUS profile, group or both are to be set!');
	}
	if ( defined $e->field('radiusgroupname')->value &&
	     $e->field('radiusgroupname')->value ne '' ) {
	  $mesg =
	    $ldap_crud
	    ->search({ base => $e->field('radiusgroupname')->value,
		       filter => sprintf('member=uid=%s,authorizedService=%s@%s,%s',
					 $logintmp,
					 $e->field('authorizedservice')->value,
					 $e->field('associateddomain')->value,
					 $self->add_svc_acc)
		     });
	  $e->field('radiusgroupname')
	    ->add_error(sprintf('%s is already in this RADIUS group.<br>This service object %s either was deleted but not removed from, or is still the member of the group.',
				$logintmp,
				sprintf('uid=%s,authorizedService=%s@%s,%s',
					$logintmp,
					$e->field('authorizedservice')->value,
					$e->field('associateddomain')->value,
					$self->add_svc_acc)))
	    if $mesg->count;
	}
      }
      #---[ 802.1x - ]---------------------------------------------------------------------

      # prepare to know if login+service+fqdn is unique
      $k = sprintf("%s-%s-%s",
		   $logintmp,
		   $e->field('authorizedservice')->value,
		   $e->field('associateddomain')->value);

		   # exists $self->params->{account}->[$i]->{login_complex} ?
		   # $e->field('associateddomain')->value : '');
      
      # log_debug { "+++ 3 " . '+' x 70 . "\nlogin_complex: " . np($e->field('login_complex')->value) };
      ### !!! on submit account.1.login_complex is undefined while it is == 1
      $elementcmp->{$k}++;
      # log_debug { np($elementcmp->{$k}) };
      if ( defined $e->field('authorizedservice')->value &&
	   $e->field('authorizedservice')->value ne '' &&
	   defined $e->field('associateddomain')->value
	   && $e->field('associateddomain')->value ne '' ) {

	$filter = sprintf("(&(authorizedService=%s%s%s)%s)",
			  $e->field('authorizedservice')->value,

			  $ldap_crud->{cfg}->{authorizedService}
			  ->{$e->field('authorizedservice')->value}
			  ->{login_delim} // '',

			  $e->field('associateddomain')->value,
			  $passwd_acc_filter);
	$mesg =
	  $ldap_crud->search({
			      filter => $filter,

			      base => $ldap_crud->cfg->{base}->{acc_root},
			      attrs => [ 'uid' ],
			     });

	log_debug { "+++ 4 " . '+' x 70 . "\niteration: " . $i . "\n" . np($logintmp) };
	log_debug { "+++ 5 " . '+' x 70 . "\n" .
		      "iteration: " . $i . "\n" .
		      "namesake count: " . np($mesg->count) . "\n" .
		      'base: ' . np($ldap_crud->cfg->{base}->{acc_root}) . "\n" .
		      'filter: ' . np($filter) . "\n"
		    };

	$e->field('login')->add_error($login_error_pfx . ' <mark>' . $logintmp . '</mark> is not available!')
	  if ($mesg->count);
      }

      $i++;
    }

    # log_debug { "+++ 6 " . '+' x 70 . "\n" . np($elementcmp) };

    # error rising if login+service+fqdn not uniq
    foreach $e ( $self->field('account')->fields ) {
      if ( defined $e->field('authorizedservice')->value &&
	   $e->field('authorizedservice')->value ne '' &&
	   defined $e->field('associateddomain')->value &&
	   $e->field('associateddomain')->value ne '' ) {
	$e->field('login')
	  ->add_error(sprintf('%s <mark>%s</mark> defined more than once for the same service and FQDN',
			      $login_error_pfx, $logintmp))
	  if exists $elementcmp->{$k} && $elementcmp->{$k} > 1;
      }
    }


    # to rewrite due to loginless_ssh removal #     #---[ ssh + ]------------------------------------------------
    # to rewrite due to loginless_ssh removal #     my $sshpubkeyuniq;
    # to rewrite due to loginless_ssh removal #     $i = 0;
    # to rewrite due to loginless_ssh removal #     foreach $e ( $self->field('loginless_ssh')->fields ) {
    # to rewrite due to loginless_ssh removal #       if ( defined $e->field('associateddomain')->value &&
    # to rewrite due to loginless_ssh removal # 	   ! defined $e->field('key')->value &&
    # to rewrite due to loginless_ssh removal # 	   ! defined $e->field('keyfile')->value ) { # fqdn but no key
    # to rewrite due to loginless_ssh removal # 	$e->field('key')->add_error('Either Key, KeyFile or both field/s have to be defined!');
    # to rewrite due to loginless_ssh removal # 	$e->field('keyfile')->add_error('Either KeyFile, Key or both field/s have to be defined!');
    # to rewrite due to loginless_ssh removal #       } elsif ( ( defined $e->field('key')->value ||
    # to rewrite due to loginless_ssh removal # 		  defined $e->field('keyfile')->value ) &&
    # to rewrite due to loginless_ssh removal # 		! defined $e->field('associateddomain')->value ) { # key but no fqdn
    # to rewrite due to loginless_ssh removal # 	$e->field('associateddomain')->add_error('Domain field have to be defined!');
    # to rewrite due to loginless_ssh removal #       } elsif ( ! defined $e->field('key')->value &&
    # to rewrite due to loginless_ssh removal # 		! defined $e->field('keyfile')->value &&
    # to rewrite due to loginless_ssh removal # 		! defined $e->field('associateddomain')->value &&
    # to rewrite due to loginless_ssh removal # 		$i > 0 ) {	# empty duplicatee
    # to rewrite due to loginless_ssh removal # 	$self->add_form_error('<span class="fa-stack fa-fw">' .
    # to rewrite due to loginless_ssh removal # 			      '<i class="fa fa-cog fa-stack-2x text-muted umi-opacity05"></i>' .
    # to rewrite due to loginless_ssh removal # 			      '<i class="fa fa-user-times pull-right fa-stack-1x"></i></span>' .
    # to rewrite due to loginless_ssh removal # 			      '<b class="visible-lg-inline">&nbsp;NoPass&nbsp;</b>' .
    # to rewrite due to loginless_ssh removal # 			      '<b> <i class="fa fa-arrow-right"></i> SSH:</b> Empty duplicatee! Fill it or remove, please');
    # to rewrite due to loginless_ssh removal #       }
    # to rewrite due to loginless_ssh removal # 
    # to rewrite due to loginless_ssh removal #       # prepare to know if fqdn+key+keyfile is uniq?
    # to rewrite due to loginless_ssh removal #       $sshpubkeyuniq->{associateddomain} = $e->field('associateddomain')->value // '';
    # to rewrite due to loginless_ssh removal #       $sshpubkeyuniq->{key} =              $e->field('key')->value // '';
    # to rewrite due to loginless_ssh removal #       $sshpubkeyuniq->{keyfile} =          $e->field('keyfile')->value->{filename} // '';
    # to rewrite due to loginless_ssh removal #       $sshpubkeyuniq->{hash} = sprintf('%s%s%s',
    # to rewrite due to loginless_ssh removal # 				       $sshpubkeyuniq->{associateddomain},
    # to rewrite due to loginless_ssh removal # 				       $sshpubkeyuniq->{key},,
    # to rewrite due to loginless_ssh removal # 				       $sshpubkeyuniq->{keyfile});
    # to rewrite due to loginless_ssh removal #       $elementcmp->{$sshpubkeyuniq->{hash}} = ! $i ? 1 : $elementcmp->{$sshpubkeyuniq->{hash}}++;
    # to rewrite due to loginless_ssh removal # 
    # to rewrite due to loginless_ssh removal #       # validate keyfile if provided
    # to rewrite due to loginless_ssh removal #       my $sshpubkey_hash = {};
    # to rewrite due to loginless_ssh removal #       my ( $sshpubkey, $key_file, $key_file_msg );
    # to rewrite due to loginless_ssh removal #       if ( defined $e->field('keyfile')->value &&
    # to rewrite due to loginless_ssh removal # 	   ref($e->field('keyfile')->value) eq 'Catalyst::Request::Upload' ) {
    # to rewrite due to loginless_ssh removal # 	$key_file = $self->file2var( $e->field('keyfile')->value->{tempname}, $key_file_msg, 1);
    # to rewrite due to loginless_ssh removal # 	$e->field('keyfile')->add_error($key_file_msg->{error})
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
    # to rewrite due to loginless_ssh removal #       $sshpubkey = defined $e->field('key')->value ? $e->field('key')->value : undef;
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
    # to rewrite due to loginless_ssh removal #     foreach $e ( $self->field('loginless_ssh')->fields ) {
    # to rewrite due to loginless_ssh removal #       $sshpubkeyuniq->{associateddomain} = defined $e->field('associateddomain')->value ?
    # to rewrite due to loginless_ssh removal # 	$e->field('associateddomain')->value : '';
    # to rewrite due to loginless_ssh removal #       $sshpubkeyuniq->{key} = defined $e->field('key')->value ?
    # to rewrite due to loginless_ssh removal # 	$e->field('key')->value : '';
    # to rewrite due to loginless_ssh removal #       $sshpubkeyuniq->{keyfile} = defined $e->field('keyfile')->value ?
    # to rewrite due to loginless_ssh removal # 	$e->field('keyfile')->value->{filename} : '';
    # to rewrite due to loginless_ssh removal #       $sshpubkeyuniq->{hash} = sprintf('%s%s%s',
    # to rewrite due to loginless_ssh removal # 				       $sshpubkeyuniq->{associateddomain},
    # to rewrite due to loginless_ssh removal # 				       $sshpubkeyuniq->{key},,
    # to rewrite due to loginless_ssh removal # 				       $sshpubkeyuniq->{keyfile});
    # to rewrite due to loginless_ssh removal #       $e->field('key')->add_error('The same key is defined more than once for the same FQDN')
    # to rewrite due to loginless_ssh removal # 	if $elementcmp->{$sshpubkeyuniq->{hash}} > 1 &&
    # to rewrite due to loginless_ssh removal # 	$sshpubkeyuniq->{keyfile} eq '' &&
    # to rewrite due to loginless_ssh removal # 	$sshpubkeyuniq->{key} ne '';
    # to rewrite due to loginless_ssh removal #       $e->field('keyfile')->add_error('The same keyfile is defined more than once for the same FQDN')
    # to rewrite due to loginless_ssh removal # 	if $elementcmp->{$sshpubkeyuniq->{hash}} > 1 &&
    # to rewrite due to loginless_ssh removal # 	$sshpubkeyuniq->{key} eq '' &&
    # to rewrite due to loginless_ssh removal # 	$sshpubkeyuniq->{keyfile} ne '';
    # to rewrite due to loginless_ssh removal #       $e->field('key')->add_error('The same key and keyfile are defined more than once for the same FQDN')
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
    $i = 0;

    foreach $e ( $self->field('loginless_ovpn')->fields ) {
      # p $_->value foreach ($e->field('userCertificate'));

      if ((( defined $e->field('associateddomain')->value &&
	     defined $e->field('userCertificate')->value  &&
	     defined $e->field('ifconfigpush')->value       &&
	     ( $e->field('associateddomain')->value eq ''   ||
	       $e->field('userCertificate')->value eq ''    ||
	       $e->field('ifconfigpush')->value eq '' ) )     ||
	   ( ! defined $e->field('associateddomain')->value ||
	     ! defined $e->field('userCertificate')->value  ||
	     ! defined $e->field('ifconfigpush')->value  )) && $i > 0 ) {
	$e->field('associateddomain')->add_error('');
	$e->field('userCertificate')->add_error('');
	$e->field('ifconfigpush')->add_error('');
      }

      ### empty duplicate (repeatable)
      if ( ! defined $e->field('associateddomain')->value &&
	   ! defined $e->field('userCertificate')->value  &&
	   ! defined $e->field('ifconfigpush')->value     &&
	   $i > 0 ) {
	# $e->add_error('Empty duplicatee!');
	$self->add_form_error('<span class="fa-stack fa-fw">' .
			      '<i class="fa fa-cog fa-stack-2x text-muted umi-opacity05"></i>' .
			      '<i class="fa fa-user-times pull-right fa-stack-1x"></i></span>' .
			      '<b class="visible-lg-inline">&nbsp;NoPass&nbsp;</b>' .
			      '<b> <i class="fa fa-arrow-right"></i> OpenVPN:</b> Empty duplicatee! Fill it or remove, please');
      }

      if ( defined $e->field('associateddomain')->value &&
	   defined $e->field('status')->value           &&
	   defined $e->field('ifconfigpush')->value     &&
	   ( $e->field('associateddomain')->value ne '' ||
	     $e->field('status')->value ne ''           ||
	     $e->field('ifconfigpush')->value ne '' ) ) {
	if ( defined $e->field('userCertificate')->value ) {

	  $cert = $self->file2var( $e->field('userCertificate')->value->{tempname}, $cert_msg);
	  $e->field('userCertificate')->add_error($cert_msg->{error})
	    if defined $cert_msg->{error};
	  $is_x509 = $self->cert_info({ cert => $cert, ts => "%s", });
	  $e->field('userCertificate')->
	    add_error('Cert is broken or not DER format!' . $is_x509->{error})
	    if defined $is_x509->{error};

	  my $now = strftime ("%s", localtime);
	  $e->field('userCertificate')->add_error( 'Cert has passed expiration date' )
	    if $now > $is_x509->{'Not  After'};
	  $e->field('userCertificate')->add_error( 'Cert activation date is in the future' )
	    if $now < $is_x509->{'Not Before'};

	  $mesg = $ldap_crud->search({ filter => sprintf("(&(authorizedService=ovpn@%s)(cn=%s))",
							 $e->field('associateddomain')->value,
							 $is_x509->{CN}),
				       base   => $ldap_crud->{cfg}->{base}->{acc_root},
				       attrs  => [ 'cn', 'umiUserCertificateSn', ], } );

	  if ( $mesg->count > 0 ) {
	    $e->field('userCertificate')->
	      add_error( sprintf("Cert CN: %s for domain: %s already exists",
				 $is_x509->{CN},
				 $e->field('associateddomain')->value));
	  } elsif ( $mesg->is_error ) {
	    $e->field('userCertificate')->add_error( $ldap_crud->err($mesg)->{html} );
	  }

	  # ??? # $e->field('userCertificate')->add_error('Problems with certificate file');

	} elsif ( ! defined $e->field('userCertificate')->value ) {
	  $e->field('userCertificate')->add_error('userCertificate is mandatory!');
	}
      }

      $re  = $self->{a}->{re}->{ip};
      if ( defined $e->field('ifconfigpush')->value &&
	   $e->field('ifconfigpush')->value =~ /^($re)\s+($re)$/ ) {
	my $lor = $1;
	my $ror = $2;
	my $l = defined $e->field('devos')->value &&
	  exists $self->{a}->{topology}->{os}->{lc($e->field('devos')->value)} ?
	  sprintf("%s/%s", $lor,
		  $self->{a}->{topology}->{os}->{lc($e->field('devos')->value)}) :
		    sprintf("%s/%s", $lor, $self->{a}->{topology}->{default});

	my $ip = Net::CIDR::Set->new( $l );
	$e->field('ifconfigpush')->
	  add_error( sprintf("ip %s and %s does not belong to %s net as expected for choosen OS %s",
			     $lor,
			     $ror,
			     ($ip->as_cidr_array)[0],
			     $e->field('devos')->value ) )
	  if ! $ip->contains( sprintf("%s/32", $ror) );

	my $fltr = sprintf("(umiOvpnCfgIfconfigPush=%s *)", $ror);
			   # $e->field('ifconfigpush')->value );
	log_debug { np( $fltr ) };
	$mesg = $ldap_crud->search({ filter => $fltr,
				     base   => $ldap_crud->{cfg}->{base}->{db},
				     attrs  => [ 'umiOvpnCfgIfconfigPush' ], } );
	if ( $mesg->count ) {
	  foreach $entry ( $mesg->entries ) {
	    $e->field('ifconfigpush')->
	      add_error( sprintf('addresses %s are used by %s',
				 $e->field('ifconfigpush')->value,
				 $entry->dn) );
	  }
	}
      } elsif ( defined $e->field('ifconfigpush')->value &&
	   $e->field('ifconfigpush')->value !~ /^($re)\s+($re)$/ ) {
	$e->field('ifconfigpush')->add_error( 'The input is not two IP addresses!' );
      }
      $i++;
    }
    #---[ OpenVPN - ]--------------------------------------------
  }
  # not simplified variant stop

  $self->add_form_error("Form didn't pass validation.") if $self->has_error_fields;

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

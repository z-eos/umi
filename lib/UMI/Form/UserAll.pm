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

has_field 'person_avatar'
  => ( type => 'Upload',
       label => 'User Photo ID',
       label_class => [ 'col-xs-2', ],
       element_wrapper_class => [ 'col-xs-2', 'col-lg-3', ],
       element_class => [ 'btn', 'btn-default', 'btn-sm', ],
       max_size => '50000' );

has_field 'person_office'
  => ( type => 'Select',
       label => 'Office',
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

has_field 'person_telephonenumber'
  => ( apply => [ NoSpaces ],
       label => 'SIP/Cell',
       label_class => [ 'col-xs-2', ],
       element_wrapper_class => [ 'col-xs-10', 'col-lg-5', ],
       element_class => [ 'input-sm', ],
       wrapper_attr => { id => 'items' },
       element_attr => { name => 'telephonenumber\[\]',
			 placeholder => '123@pbx0.ibs, +380xxxxxxxxx' });

has_field 'person_telcomment'
  => ( type => 'Display',
       html => '<small class="text-muted col-xs-offset-2"><em>' .
       'comma or space delimited if many, international format for tel.</em></small>',
     );

has_block 'group_person'
  => ( tag => 'div',
       render_list => [ 'person_office',
			'person_title',
			'person_avatar',
			'person_telephonenumber',
			'person_telcomment', ],
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
       html => '<div class="col-xs-offset-1 rm-duplicate hidden"><a class="btn btn-link text-danger" href="#" title="Delete this section">' .
       '<span class="fa fa-trash text-danger"></span>Delete this section</a></div>',
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

has_field 'account.password2'
  => ( type => 'Password',
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

has_field 'account.radiusgroupname'
  => ( type => 'Select',
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
       options => [{ value => '', label => '--- Choose Group ---'},
		   { value => 'ip-phone', label => 'ip-phone'},
		   { value => 'auth-mac', label => 'auth-mac'},
		   { value => 'auth-eap', label => 'auth-eap'}, ],
     );

has_field 'account.radiustunnelprivategroup'
  => ( type => 'Select',
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
       options => [{ value => '', label => '--- Choose VLAN ---'},
		   { value => 'VLAN3', label => 'Voice (VLAN3)'},
		   { value => 'VLAN3498', label => 'Guest (VLAN3498)'},
		   { value => 'VLAN3499', label => 'Bootp (VLAN3499)'}, ],
     );

sub wrap_account_elements {
  my ( $self, $input, $subfield ) = @_;
  my $output = sprintf('%s%s%s', ! $subfield ? qq{\n<div class="duplicate">} : qq{\n<div class="duplicated">},
		       $input,
		       qq{</div>});
}

has_block 'auth' 
  => ( tag => 'fieldset',
       label => '<a href="#" class="btn btn-link btn-lg" data-duplicate="duplicate">' .
       '<span class="fa fa-plus-circle text-success"></span></a>' .
       'Login and Password Dependent Service&nbsp;<small class="text-muted"><em>(' .
       'login and password fields are autogenerated if empty)</em></small>',
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
       html => '<div class="col-xs-offset-1 rm-duplicate hidden"><a class="btn btn-link text-danger" href="#" title="Delete this section">' .
       '<span class="fa fa-trash text-danger"></span>Delete this section</a></div>',
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

has_block 'ssh'
  => ( tag => 'fieldset',
       label => '<a href="#" class="btn btn-link btn-lg" data-duplicate="duplicate">' .
       '<span class="fa fa-plus-circle text-success"></span></a>' .
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
       #setup_for_js => 1,
       do_wrapper => 1,
       wrap_repeatable_element_method => \&wrap_loginless_ovpn_elements,
       #tags => { controls_div => 1 },
       # init_contains => { wrapper_attr => { class => ['hfh', 'repinst'] } },
     );

has_field 'loginless_ovpn.rm-duplicate'
  => ( type => 'Display',
       html => '<div class="col-xs-offset-1 rm-duplicate hidden"><a class="btn btn-link text-danger" href="#" title="Delete this section">' .
       '<span class="fa fa-trash text-danger"></span>Delete this section</a></div>',
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

has_field 'loginless_ovpn.cert'
  => ( type => 'Upload',
       label => 'Cert (.DER)',
       label_class => [ 'col-xs-2', ],
       element_wrapper_class => [ 'col-xs-2', 'col-lg-3', ],
       element_class => [ 'btn', 'btn-default', 'btn-sm',],
       element_attr => {
			'data-name' => 'cert',
			'data-group' => 'loginless_ovpn',
		       },
     );

has_field 'loginless_ovpn.device'
  => ( apply => [ NoSpaces, NotAllDigits, Printable ],
       label => 'Device',
       label_class => [ 'col-xs-2', ],
       element_wrapper_class => [ 'col-xs-10', 'col-lg-5', ],
       element_class => [ 'input-sm', ],
       element_attr => { placeholder => 'Lenovo P780',
			 'data-name' => 'device',
			 'data-group' => 'loginless_ovpn', },
     );

has_field 'loginless_ovpn.ip'
  => ( apply => [ NoSpaces, NotAllDigits, Printable ],
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

has_block 'ovpn'
  => ( tag => 'fieldset',
       label => '<a href="#" class="btn btn-link btn-lg" data-duplicate="duplicate">' .
       '<span class="fa fa-plus-circle text-success"></span></a>' .
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
#== VALIDATION =======================================================
######################################################################

sub validate {
  my $self = shift;
  my ( $element, $field, $ldap_crud, $mesg, $autologin, $loginpfx, $logintmp );

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

  # $self->add_form_error('<div class="alert alert-danger" role="alert"><i class="fa fa-exclamation-circle"></i> Form contains error/s! Check all tabs, please!</div>') if $self->has_error_fields;


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

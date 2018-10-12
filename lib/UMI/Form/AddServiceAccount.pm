# -*- mode: cperl -*-
#

package UMI::Form::AddServiceAccount;

use HTML::FormHandler::Moose;
BEGIN { extends 'UMI::Form::LDAP'; with 'Tools'; }

use HTML::FormHandler::Types ('NoSpaces', 'WordChars', 'NotAllDigits', 'Printable' );

# has '+item_class' => ( default =>'AddServiceAccount' );
has '+enctype' => ( default => 'multipart/form-data');
has '+action' => ( default => '/searchby/proc' );

has_field 'add_svc_acc' => ( type => 'Hidden', );

has_field 'login' => ( apply => [ NoSpaces, NotAllDigits, Printable ],
		       label => 'Login',
		       size => 60,
		       wrapper_class => [ 'col-xs-4' ],
		       # element_attr => { disabled => '', },
		       # element_class => [ 'disabled' ],
		       # init_value => 'add_svc_acc' . '-<service choosen>',
		       element_attr => {
		       			placeholder => 'login to be used for the service/s',
		       		       },
		     );

has_field 'add_svc_acc_uid' => ( type => 'Hidden', );

has_field 'password1' => ( type => 'Password',
			   minlength => 7, maxlength => 16,
			   label => 'Password',
			   wrapper_class => [ 'col-xs-4' ],
#			   ne_username => 'login',
			   apply => [ NoSpaces, NotAllDigits, Printable ],
			   element_attr => 
			   { placeholder => 'Password',
#			     title => 'leave empty password fields to autogenerate password',
			   },
			 );

has_field 'password2' => ( type => 'Password',
			   minlength => 7, maxlength => 16,
			   label => 'Confirm Password',
			   wrapper_class => [ 'col-xs-4' ],
#			   ne_username => 'login',
			   apply => [ NoSpaces, NotAllDigits, Printable ],
			   element_attr => 
			   { placeholder => 'Confirm Password',
#			     title => 'leave empty password fields to autogenerate password',
			   },
			 );

has_field 'pwdcomment' => ( type => 'Display',
			    html => '<small class="text-muted col-xs-12"><em>' .
			    'Leave login and password fields empty to autogenerate them. If empty, login will be equal to &laquo;personal&raquo; part of management account uid.</em></small>',
			  );


has_field 'radiusgroupname' => ( apply => [ NoSpaces, NotAllDigits, Printable ],
		       label => 'RADIUS Group Name',
		       size => 60,
		       wrapper_class => [ 'col-xs-6', 'col-lg-6', ],
		       # element_attr => { disabled => '', },
		       # element_class => [ 'disabled' ],
		       # init_value => 'add_svc_acc' . '-<service choosen>',
		       element_attr => {
		       			placeholder => 'ip-phone, wifi-123',
		       		       },
		     );

has_field 'radiustunnelprivategroupid'
  => ( type => 'Select',
       label => 'RADIUS Tunnel Private Group',
       wrapper_class => [ 'col-xs-6', 'col-lg-6', ],
       options => [
		   { value => '', label => '--- Choose VLAN ---'},
		   { value => '2', label => 'Management (VLAN2)'},
		   { value => '3', label => 'Voice (VLAN3)'},
		   { value => '4', label => 'Video (VLAN4)'},
		   { value => '5', label => 'SmartHouse (VLAN5)'},
		   { value => '6', label => 'PRN (VLAN6)'},
		   { value => '11', label => 'WAN (VLAN11)'},
		   { value => '3480', label => 'Guest WiFi (VLAN3480)'},
		   { value => '3498', label => 'Guest (VLAN3498)'},
		   { value => '3499', label => 'Bootp (VLAN3499)'},
		   { value => '3500', label => 'Guest RG45 (VLAN3500)'},
		  ],
     );

has_field 'descr' => ( type => 'TextArea',
		       label => 'Description',
		       element_attr =>
		       { placeholder =>
			 'Meaningfull, service related description to make it easy to understand who, when, where e.t.c.' },
		       wrapper_class => [ 'col-xs-6', 'col-lg-6', ],
		       cols => 30, rows => 1);

has_field 'sshpublickey' => ( type => 'TextArea',
			      label => 'SSH Public Key',
			      element_attr => { placeholder => 'Paste your key here.' },
			      wrapper_class => [ 'col-lg-12' ],
			      cols => 30, rows => 1);

has_field 'to_sshkeygen' => ( type => 'Checkbox',
			      label => 'Generate SSH Key',
			      # element_attr => { disabled => '', },
			      wrapper_class => [ 'checkbox', 'col-xs-1' ],
			    );

has_field 'sshkeydescr' => ( apply => [ NotAllDigits, Printable ],
			     label => 'SSH Key Description',
			     wrapper_class => [ 'col-xs-11' ],
			     element_attr =>
			     {
			      # disabled => '',
			      placeholder =>
			      'Meaningfull key description like host name for which it is to be used, e.t.c.',
			     },
			   );

has_field 'sshgenfooter' => ( type => 'Display',
			      html => '<small class="text-muted col-xs-11 col-xs-offset-1"><em>' .
			      'RSA, 2048 bit length key will be generated for you automatically.</em></small>',
			      # wrapper_class => [ 'col-xs-11', 'col-xs-offset-1' ],
			  );


has_field 'usercertificate' => ( type => 'Upload',
				 label => 'User Certificate in DER format',
				 element_class => [ 'btn', 'btn-default', ],
				 max_size => '50000', );


has_field 'associateddomain' => ( type => 'Select',
				  label => 'Domain Name', label_class => [ 'required' ],
				  # options => [{ value => '0', label => '--- select domain ---', selected => 'on' }],
				  wrapper_class => [ 'col-xs-6', 'col-lg-6', ],
				  # required => 1,
				);

sub options_associateddomain {
  my $self = shift;
  use Data::Printer;

  return unless $self->ldap_crud;

  push my @domains, { value => '0', label => '--- select domain ---', selected => 'selected', };

  my $ldap_crud = $self->ldap_crud;
  my $mesg = $ldap_crud->search( { base => $ldap_crud->{cfg}->{base}->{org},
				   filter => 'associatedDomain=*',
				   attrs => [ 'associatedDomain' ],
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
  # p @domains;
  return \@domains;
  # $ldap_crud->unbind;
}

has_field 'authorizedservice' => ( type => 'Multiple',
				   label => 'Service', label_class => [ 'required' ],
				   wrapper_class => [ 'col-xs-6', 'col-lg-6', ],
				   size => 7,
				   # required => 1,
				 );

sub options_authorizedservice {
  my $self = shift;
  use Data::Printer;

  return unless $self->ldap_crud;

  my @services; # = ( { value => '0', label => '--- select service ---', selected => 'selected' } );

  foreach my $key ( sort {$a cmp $b} keys %{$self->ldap_crud->{cfg}->{authorizedService}}) {
    if ( defined $self->ldap_crud->{cfg}->{authorizedService}->{$key}->{data_fields} &&
	 $self->ldap_crud->{cfg}->{authorizedService}->{$key}->{data_fields} ne '' ) {
      push @services, {
		       value => $key,
		       label => $self->ldap_crud->{cfg}->{authorizedService}->{$key}->{descr},
		       attributes =>
		       { 'data-fields' => $self->ldap_crud->{cfg}->{authorizedService}->{$key}->{data_fields} },
		      } if ! $self->ldap_crud->{cfg}->{authorizedService}->{$key}->{disabled};
    } else {
      push @services, {
		       value => $key,
		       label => $self->ldap_crud->{cfg}->{authorizedService}->{$key}->{descr},
		      } if ! $self->ldap_crud->{cfg}->{authorizedService}->{$key}->{disabled};
    }
  }
  # p @services;
  return \@services;
}


has_field 'aux_reset' => ( type => 'Reset',
			   wrapper_class => [ 'col-xs-4' ],
			   element_class => [ 'btn', 'btn-danger', 'btn-block', ],
			   element_wrapper_class => [ 'col-xs-12', ], );

has_field 'aux_submit' => ( type => 'Submit',
			    wrapper_class => [ 'col-xs-8'],
			    element_class => [ 'btn', 'btn-success', 'btn-block' ],
			    value => 'Submit' );



has_block 'block_acc' => ( tag => 'fieldset',
			 attr => { id => 'block_acc', },
			 render_list => [
					 'login',
					 'password1',
					 'password2',
					 'pwdcomment'
					],
			 label => '<span class="fa fa-user"></span>&nbsp;account credentials',
			 label_class => [ 'text-info' ],
			 #			 class => [ 'form-inline' ],
		       );

has_block 'block_802' => ( tag => 'fieldset',
			 attr => { id => 'block_802', },
			 render_list => [
					 'radiusgroupname',
					 'radiustunnelprivategroupid',
					],
			 label => '<span class="fa fa-shield"></span>&nbsp;802.1x details',
			 label_class => [ 'text-info' ],
			 #			 class => [ 'form-inline' ],
		       );

has_block 'block_ssh' => ( tag => 'fieldset',
			 attr => { id => 'block_ssh', },
			 render_list => [
					 'to_sshkeygen',
					 'sshkeydescr',
					 'sshgenfooter',
					 'sshpublickey',
					],
			 label => '<span class="fa fa-key"></span>&nbsp;ssh key/s',
			 label_class => [ 'text-info' ],
		       );

has_block 'block_crt' => ( tag => 'fieldset',
			 attr => { id => 'block_crt', },
			 render_list => [
					 'usercertificate',
					],
			 label => '<span class="fa fa-certificate"></span>&nbsp;certificate/s',
			 label_class => [ 'text-info' ],
		       );

has_block 'services' => ( tag => 'fieldset',
			  render_list => [
					  'authorizedservice',
					  'associateddomain',
					  'descr',
					 ],
			  label => '<span class="fa fa-sliders"></span>&nbsp;services',
 			  label_class => [ 'text-info' ],
			  #			  class => [ 'row' ]
			);

has_block 'submitit' => ( tag => 'fieldset',
			  label => '<hr>',
			  render_list => [ 'aux_reset', 'aux_submit', ],
			  class => [ 'row' ]
			);

# sub build_render_list {[ 'services', 'add_svc_acc', 'add_svc_acc_uid', 'account', 'descr', 'sshpublickey', 'usercertificate', 'submitit' ]}

sub build_render_list {[
			'add_svc_acc', 'add_svc_acc_uid',
			'services',
			'block_acc',
			'block_802',
			'block_ssh',
			'block_crt',
			'submitit',
		       ]}

sub html_attributes {
  my ( $self, $field, $type, $attr ) = @_;
  push @{$attr->{class}}, 'required'
    if ( $type eq 'label' && $field->required );
}

sub validate {
  my $self = shift;

  # use Data::Printer use_prototypes => 0;
  # p $self->field('associateddomain')->value;

  if ( defined $self->field('associateddomain')->value &&
       $self->field('associateddomain')->value eq "0" ) {
    $self->field('associateddomain')
      ->add_error('<span class="fa fa-exclamation-circle"></span>&nbsp;associatedDomain is mandatory!');
  }
  # use Data::Printer use_prototypes => 0;
  # p $self->field('authorizedservice')->value;
  if ( $self->field('authorizedservice')->value &&
      ( ! @{$self->field('authorizedservice')->value} ||
	$self->field('authorizedservice')->value->[0] eq "0" )) {
    $self->field('authorizedservice')
      ->add_error('<span class="fa fa-exclamation-circle"></span>&nbsp;authorizedService is mandatory!');
  }

  # p $self->field('login')->value;
  my $login;
  if ( ! defined $self->field('login')->value ||
       $self->field('login')->value eq '' ) {
    my @id = split(',', $self->field('add_svc_acc')->value);
    $login = substr($id[0], 21);
  } else {
    $login = $self->field('login')->value;
  }

  my $ldap_crud = $self->ldap_crud;
  foreach ( @{$self->field('authorizedservice')->value} ) {
    # p [ '(uid=' . $login . '@' . $self->field('associateddomain')->value . ')',
    # 	'authorizedService=' . $_ . '@' . $self->field('associateddomain')->value . ',' .
    # 	$self->field('add_svc_acc')->value ];

    $self->field('login')
      ->add_error('<span class="fa fa-exclamation-circle"></span>&nbsp;MAC address is not valid')
      if $_ =~ /^dot1x-eap-md5$/ && ! $self->macnorm({ mac => $login });

    my $mesg =
      $ldap_crud->search(
			 {
			  scope => 'one',
			  filter => '(uid=' . $login . '@' . $self->field('associateddomain')->value . ')',
			  base => 'authorizedService=' . $_ . '@' . $self->field('associateddomain')->value . ',' .
			          $self->field('add_svc_acc')->value,
			  attrs => [ 'uid' ],
			 }
			);

    if ($mesg->count) {
      my $err_login = '<span class="fa fa-exclamation-circle"></span>&nbsp;' .
	'login <em class="text-primary">' . $login . '</em> is already used for service <em class="text-primary">' .
	  $_ . '@' . $self->field('associateddomain')->value . '</em>';
      $self->field('login')->add_error($err_login);

      my $err_domain = '<span class="fa fa-exclamation-circle"></span>&nbsp;' .
	'domain <em class="text-primary">' . $self->field('associateddomain')->value . '</em> is already used for service <em class="text-primary">' .
	  $_ . '@' . $self->field('associateddomain')->value . '</em> with login <em class="text-primary">' .
	    $login . '</em>';
      $self->field('associateddomain')->add_error($err_domain);

      my $comment = '';
      $comment = '<p>you have left field &laquo;Login&raquo; emty and I have used ' .
	'&laquo;personal&raquo; part of the management account uid, in this case it is <em class="text-primary">' .
	  $login . '</em></p>' if $self->field('login')->value eq '';

      my $err = '<div class="panel panel-warning">
  <div class="panel-heading">
    <h4><span class="fa fa-warning">&nbsp;</span>Warning!</h4>
  </div>
  <div class="panel-body">
    User <em class="text-warning mono">' .
      $self->field('add_svc_acc')->value . '</em> already has service account <em class="text-warning mono">' .
	$_ . '@' . $self->field('associateddomain')->value .
	  '</em> with the same uid <em class="text-warning mono">' . $self->field('login')->value . '</em><br>' . $comment .
	    '</div>
</div>';
      my $error = $self->form->success_message;
      $self->form->error_message('');
      $self->form->add_form_error($error . $err);
    }
  }
  # $ldap_crud->unbind;
}

######################################################################

no HTML::FormHandler::Moose;

__PACKAGE__->meta->make_immutable;

1;

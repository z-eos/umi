# -*- mode: cperl -*-
#

package UMI::Form::AddServiceAccount;

use HTML::FormHandler::Moose;
BEGIN { extends 'UMI::Form::LDAP'; with 'Tools'; }

use HTML::FormHandler::Types ('NoSpaces', 'WordChars', 'NotAllDigits', 'Printable' );

# has '+item_class' => ( default =>'AddServiceAccount' );
has '+action' => ( default => '/searchby/proc' );

has_field 'add_svc_acc' => ( type => 'Hidden', );

has_field 'login' => ( apply => [ NoSpaces, NotAllDigits, Printable ],
		       label => 'Login',
		       size => 60,
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
			   ne_username => 'login',
			   apply => [ NoSpaces, NotAllDigits, Printable ],
			   element_attr => 
			   { placeholder => 'Password',
#			     title => 'leave empty password fields to autogenerate password',
			   },
			 );

has_field 'password2' => ( type => 'Password',
			   minlength => 7, maxlength => 16,
			   label => 'Confirm Password',
			   ne_username => 'login',
			   apply => [ NoSpaces, NotAllDigits, Printable ],
			   element_attr => 
			   { placeholder => 'Confirm Password',
#			     title => 'leave empty password fields to autogenerate password',
			   },
			 );

has_field 'pwdcomment' => ( type => 'Display',
			    html => '<p class="text-muted"><small><em>' .
			    'Leave login and password fields empty to autogenerate them. If empty, login will be equal to &laquo;personal&raquo; part of management account uid.</em></small></p>',
#			    element_class => 'text-muted'
			  );

has_field 'descr' => ( type => 'TextArea',
		       label => 'Description',
		       element_attr => { placeholder => 'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Suspendisse sed dapibus nulla. Mauris vehicula vehicula ligula ac dapibus. Fusce vehicula a turpis sed. ' },
		       cols => 30, rows => 2);

has_field 'associateddomain' => ( type => 'Select',
				  label => 'Domain Name', label_class => [ 'required' ],
				  # options => [{ value => '0', label => '--- select domain ---', selected => 'on' }],
				  wrapper_class => [ 'col-md-6' ],
				  required => 1,
				);

sub options_associateddomain {
  my $self = shift;
  use Data::Printer;

  return unless $self->ldap_crud;

  push my @domains, {
		     value => '0',
		     label => '--- select domain ---',
		     selected => 'selected',
		    };

  my $ldap_crud = $self->ldap_crud;
  my $mesg = $ldap_crud->search( { base => 'ou=Organizations,dc=umidb',
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
  # p @domains;
  return \@domains;
  $ldap_crud->unbind;
}

has_field 'authorizedservice' => ( type => 'Multiple',
				   label => 'Service', label_class => [ 'required' ],
				   wrapper_class => [ 'col-md-6' ],
				   size => 5,
				   required => 1,
				 );

sub options_authorizedservice {
  my $self = shift;
  use Data::Printer;

  return unless $self->ldap_crud;

  my @services = ( { value => '0', label => '--- select service ---', selected => 'selected' } );

  foreach my $key ( sort {$b cmp $a} keys %{$self->ldap_crud->{cfg}->{authorizedService}}) {
    push @services, {
		     value => $key,
		     label => $self->ldap_crud->{cfg}->{authorizedService}->{$key}->{descr},
		    };
  }
  # p @services;
  return \@services;
}



has_field 'reset' => ( type => 'Reset',
			wrapper_class => [ 'pull-left', 'col-md-2' ],
			element_class => [ 'btn', 'btn-default', 'col-md-4' ],
		        value => 'Reset' );

has_field 'submit' => ( type => 'Submit',
			wrapper_class => [ 'pull-right', 'col-md-10' ],
			element_class => [ 'btn', 'btn-default', 'col-md-12' ],
			value => 'Submit' );

has_block 'account' => ( tag => 'fieldset',
			 render_list => [ 'login', 'password1', 'password2', 'pwdcomment' ],
			 label => '<abbr title="User Accounts (Management and Srvice/s) Credentials" class="initialism"><span class="icon_key_alt" aria-hidden="true"></span></abbr>',
			 label_class => [ 'pull-left' ],
			 class => [ 'form-inline' ],
		       );

has_block 'services' => ( tag => 'fieldset',
			  render_list => [ 'associateddomain', 'authorizedservice' ],
			  label => '<abbr title="Services Assigned" class="initialism"><span class="icon_cloud_alt" aria-hidden="true"></span></abbr>',
			  # label => '<span class="icon_menu-square_alt2" aria-hidden="true"></span>',
 			  # label_class => [ 'pull-left' ],
			  class => [ 'row' ]
			);

has_block 'submitit' => ( tag => 'fieldset',
			  render_list => [ 'reset', 'submit'],
			  label => '&nbsp;',
			  class => [ 'row' ]
			);

sub build_render_list {[ 'add_svc_acc', 'add_svc_acc_uid', 'account', 'services', 'descr', 'submitit' ]}

sub html_attributes {
  my ( $self, $field, $type, $attr ) = @_;
  push @{$attr->{class}}, 'required'
    if ( $type eq 'label' && $field->required );
}

sub validate {
  my $self = shift;
  use Data::Printer use_prototypes => 0;

  p $self->field('associateddomain')->value;
  if ( $self->field('associateddomain')->value eq "0" ) {
    $self->field('associateddomain')
      ->add_error('<span class="glyphicon glyphicon-exclamation-sign"></span>&nbsp;associatedDomain is mandatory!');
  }

  p  $self->field('authorizedservice')->value;
  if ( @{$self->field('authorizedservice')->value} < 1 ||
       $self->field('authorizedservice')->value->[0] eq "0" ) {
    $self->field('authorizedservice')
      ->add_error('<span class="glyphicon glyphicon-exclamation-sign"></span>&nbsp;authorizedService is mandatory!');
  }

  my $login;
  if ( $self->field('login')->value eq '' ) {
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
      my $err_login = '<span class="glyphicon glyphicon-exclamation-sign"></span>&nbsp;' .
	'login <em class="text-primary">' . $login . '</em> is already used for service <em class="text-primary">' .
	  $_ . '@' . $self->field('associateddomain')->value . '</em>';
      $self->field('login')->add_error($err_login);

      my $err_domain = '<span class="glyphicon glyphicon-exclamation-sign"></span>&nbsp;' .
	'domain <em class="text-primary">' . $self->field('associateddomain')->value . '</em> is already used for service <em class="text-primary">' .
	  $_ . '@' . $self->field('associateddomain')->value . '</em> with login <em class="text-primary">' .
	    $login . '</em>';
      $self->field('associateddomain')->add_error($err_domain);

      my $comment = '';
      $comment = '<p>you have left field &laquo;Login&raquo; emty and I have used ' .
	'&laquo;personal&raquo; part of the management account uid, in this case it is <em class="text-primary">' .
	  $login . '</em></p>' if $self->field('login')->value eq '';

      my $err = '<div class="alert alert-danger">' .
	'<span style="font-size: 140%" class="glyphicon glyphicon-exclamation-sign"></span>' .
	  '&nbsp;User <strong class="text-primary">' . $self->field('add_svc_acc')->value . '</strong> already has service account <em class="text-primary">' .
	    $_ . '@' . $self->field('associateddomain')->value .
	    '</em> with the same <em>uid</em>' . $comment . '</div>';
      my $error = $self->form->success_message;
      $self->form->error_message('');
      $self->form->add_form_error($error . $err);
    }
  }
  $ldap_crud->unbind;
}

######################################################################

no HTML::FormHandler::Moose;

__PACKAGE__->meta->make_immutable;

1;

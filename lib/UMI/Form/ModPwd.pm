# -*- mode: cperl -*-
#

package UMI::Form::ModPwd;

use HTML::FormHandler::Moose;
BEGIN { extends 'UMI::Form::LDAP'; with 'Tools'; }

use HTML::FormHandler::Types ('NoSpaces', 'WordChars', 'NotAllDigits', 'Printable' );

has '+item_class' => ( default =>'ModPwd' );
# has '+action' => ( default => '/searchby/proc' );

sub build_form_element_class { [ 'form-horizontal' ] }

has_field 'ldap_modify_password' => ( type => 'Hidden', );

has_field 'password_init' => ( type => 'Password',
			       minlength => 7, maxlength => 16,
			       label => 'New Password',
			       label_class => [ 'col-md-5' ],
			       apply => [ NoSpaces, NotAllDigits, Printable ],
			       element_attr => { placeholder => 'Password', },
			       wrapper_class => [ 'col-md-7' ],
			 );

has_field 'password_cnfm' => ( type => 'Password',
			       minlength => 7, maxlength => 16,
			       label => 'Confirm Password',
			       label_class => [ 'col-md-5' ],
			       apply => [ NoSpaces, NotAllDigits, Printable ],
			       element_attr => { placeholder => 'Confirm Password', },
			       wrapper_class => [ 'col-md-7' ],
			     );

has_field 'aux_pwdcomment' => ( type => 'Display',
				html => '<p class="form-group help-block col-md-10 col-md-offset-4 text-center"><em>' .
				'leave, both of password fields empty, to autogenerate 12 character length, strong password</em></p>',
				# element_class => 'text-muted',
				# wrapper_class => [ 'col-md-7', 'col-md-offset-4' ],
			      );

has_field 'aux_reset' => ( type => 'Reset',
			   element_wrapper_class => [ 'col-xs-12' ],
			   element_class => [ 'btn', 'btn-danger', 'btn-block', ],
			   wrapper_class => [ 'col-xs-1' ],
			   value => 'Reset' );

has_field 'aux_submit' => ( type => 'Submit',
			    wrapper_class => [ 'col-xs-11', ],
			    element_class => [ 'btn', 'btn-success', 'btn-block' ],
			    value => 'Submit' );

sub build_render_list {[ 'ldap_modify_password', 'pwd1', 'pwd2', 'pwdcomm', 'submitit' ]}


has_block 'pwd1' => ( tag => 'fieldset',
			 render_list => [ 'password_init', ],
#			 label => '<span class="glyphicon glyphicon-lock"></span>',
			 class => [ 'row' ],
		       );

has_block 'pwd2' => ( tag => 'fieldset',
			 render_list => [ 'password_cnfm', ],
			 class => [ 'row' ],
		       );

has_block 'pwdcomm' => ( tag => 'fieldset',
				render_list => [ 'aux_pwdcomment', ],
				class => [ 'row' ],
			      );

has_block 'submitit' => ( tag => 'fieldset',
			  render_list => [ 'aux_reset', 'aux_submit'],
			  label => '&nbsp;',
			  class => [ 'container-fluid' ]
			);

# sub build_render_list {[ 'pwd1', 'pwd2', 'autogen', 'submitit' ]}

sub html_attributes {
  my ( $self, $field, $type, $attr ) = @_;
  push @{$attr->{class}}, 'required'
    if ( $type eq 'label' && $field->required );
}

# working sample
# sub validate_givenname {
#   my ($self, $field) = @_;
#   unless ( $field->value ne 'Вася' ) {
#     $field->add_error('Such givenName+sn+uid user exists!');
#   }
# }

sub validate {
  my $self = shift;
  # use Data::Printer use_prototypes => 0;
  # p ({ 'password_init' => $self->field('password_init')->value,
  # 	'password_init_is_ascii' => $self->is_ascii($self->field('password_init')->value),
  # 	  'password_cnfm' => $self->field('password_cnfm')->value,
  # 	    'password_cnfm_is_ascii' => $self->is_ascii($self->field('password_cnfm')->value), });

  if ( defined $self->field('password_init')->value &&
       defined $self->field('password_cnfm')->value &&
       ($self->field('password_init')->value ne $self->field('password_cnfm')->value)
     ) {
    $self->field('password_init')
      ->add_error('<span class="glyphicon glyphicon-exclamation-sign"></span>&nbsp;password and confirmation does not match');
  }

  if ( defined $self->field('password_init')->value &&
       defined $self->field('password_cnfm')->value &&
       (($self->field('password_init')->value ne '' &&
	 $self->field('password_cnfm')->value eq '' ) ||
	($self->field('password_init')->value eq '' &&
	 $self->field('password_cnfm')->value ne '' )) ) {
    $self->field('password_init')
      ->add_error('<span class="glyphicon glyphicon-exclamation-sign"></span>&nbsp;password mandatory if confirmation present');
    $self->field('password_cnfm')
      ->add_error('<span class="glyphicon glyphicon-exclamation-sign"></span>&nbsp;confirmation is mandatory if password present');
  }

  # this realized with HTML::FormHandler::Types Printable
  if ( defined $self->field('password_init')->value &&
       defined $self->field('password_cnfm')->value &&
       ( $self->is_ascii($self->field('password_init')->value) ||
	 $self->is_ascii($self->field('password_cnfm')->value) )
     ) {
    $self->field('password_init')
      ->add_error('<span class="glyphicon glyphicon-exclamation-sign"></span>&nbsp;password has to be ASCII only!');
    $self->field('password_cnfm')
      ->add_error('<span class="glyphicon glyphicon-exclamation-sign"></span>&nbsp;confirmation has to be ASCII only!');
  }


#   my $ldap_crud = $self->ldap_crud;
#   my $mesg =
#     $ldap_crud->search(
# 		       {
# 			scope => 'one',
# 			filter => '(&(givenname=' .
# 			$self->utf2lat({ to_translate => $self->field('givenname')->value }) . ')(sn=' .
# 			$self->utf2lat({ to_translate => $self->field('sn')->value }) . ')(uid=*-' .
# 			$self->field('login')->value . '))',
# 			base => 'ou=People,dc=umidb',
# 			attrs => [ 'uid' ],
# 		       }
# 		      );

#   if ($mesg->count) {
#     my $err = '<span class="glyphicon glyphicon-exclamation-sign"></span> Fname+Lname+Login exists';
#     $self->field('givenname')->add_error($err);
#     $self->field('sn')->add_error($err);
#     $self->field('login')->add_error($err);

#     $err = '<div class="alert alert-danger">' .
#       '<span style="font-size: 140%" class="icon_error-oct" aria-hidden="true"></span>' .
# 	'&nbsp;Account with the same fields &laquo;<strong>First Name&raquo;</strong>,' .
# 	  ' &laquo;<strong>Last Name&raquo;</strong> and &laquo;<strong>Login&raquo;</strong>' .
# 	    ' already exists!<br>Consider one of:<ul>' .
# 	      '<li>change Login in case you need another account for the same person</li>' .
# 		'<li>add service account to the existent one</li></ul></div>';
#     my $error = $self->form->success_message;
#     $self->form->error_message('');
#     $self->form->add_form_error($error . $err);
#   }
#   $ldap_crud->unbind;

}

######################################################################

no HTML::FormHandler::Moose;

__PACKAGE__->meta->make_immutable;

1;

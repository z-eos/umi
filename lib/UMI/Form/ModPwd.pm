# -*- mode: cperl -*-
#

package UMI::Form::ModPwd;

use HTML::FormHandler::Moose;
BEGIN { extends 'UMI::Form::LDAP'; with 'Tools'; }

use HTML::FormHandler::Types ('NoSpaces', 'WordChars', 'NotAllDigits', 'Printable', 'PositiveNum' );

has '+item_class' => ( default =>'ModPwd' );
# has '+action' => ( default => '/searchby/proc' );

sub build_form_element_class { [ 'form-horizontal' ] }

has_field 'ldap_modify_password' => ( type => 'Hidden', );

has_field 'password_init'
  => ( type => 'Password',
       apply => [ NoSpaces, NotAllDigits, Printable ],
       minlength => 7, maxlength => 128,
       label => 'New Password',
       label_class => [ 'col-xs-2' ],
       element_wrapper_class => [ 'col-xs-10', 'col-lg-5', ],
       element_attr => { placeholder => 'Password', },
       wrapper_class => [ 'deactivate-bottom', ],
     );

has_field 'password_cnfm'
  => ( type => 'Password',
       apply => [ NoSpaces, NotAllDigits, Printable ],
       minlength => 7, maxlength => 128,
			       label => 'Confirm Password',
       label_class => [ 'col-xs-2' ],
       element_wrapper_class => [ 'col-xs-10', 'col-lg-5', ],
       element_attr => { placeholder => 'Confirm Password', },
       wrapper_class => [ 'deactivate-bottom', ],
     );

has_field 'aux_pwdcomment'
  => ( type => 'Display',
       html => '<div class="form-group"><div class="help-block col-md-10 col-md-offset-2"><em>' .
       'leave, both New/Confirm Password fields empty, to generate strong password according the options bellow</em></div></div>',
       wrapper_class => [ 'deactivate-bottom', ],
     );


has_field 'pronounceable'
  => (
      type => 'Checkbox',
      label => 'Pronounceable',
      label_class => [ 'col-xs-2', ],
      wrapper_class => [ 'checkbox', ],
      element_wrapper_class => [ 'col-xs-3', 'col-xs-offset-2', 'col-lg-1', ],
      element_attr => { title => 'Completely random word if unchecked, othervise max lengh is ' .
			UMI->config->{pwd}->{lenp} },
      wrapper_class => [ 'deactivate-top', ],
     );

has_field 'pwd_len'
  => (
      type => 'Integer',
      apply => [ NoSpaces, PositiveNum ],
      label => 'Password Length',
      label_class => [ 'col-xs-2', ],
      element_wrapper_class => [ 'col-xs-10', 'col-lg-5', ],
      element_attr => { placeholder => 'max ' . UMI->config->{pwd}->{len} . ' for completely random and max ' .
			UMI->config->{pwd}->{lenp} . ' for pronounceable' },
      wrapper_class => [ 'deactivate-top', ],
     );

has_field 'pwd_cap'
  => (
      type => 'Integer',
      apply => [ NoSpaces, PositiveNum ],
      label => 'Capital Characters',
      label_class => [ 'col-xs-2', ],
      element_wrapper_class => [ 'col-xs-10', 'col-lg-5', ],
      element_attr => { placeholder => 'max ' . UMI->config->{pwd}->{cap},
			title => 'up to this many characters will be upper case' },
      wrapper_class => [ 'deactivate-top', ],
     );

has_field 'pwd_num'
  => (
      type => 'Integer',
      apply => [ NoSpaces, PositiveNum ],
      label => 'Numbers And Spec. Characters',
      label_class => [ 'col-xs-2', ],
      element_wrapper_class => [ 'col-xs-10', 'col-lg-5', ],
      element_attr => { placeholder => 'max ' . UMI->config->{pwd}->{num},
			title => 'up to that many, numbers and special characters will occur in the password' },
      wrapper_class => [ 'deactivate-top', ],
     );

has_field 'aux_reset' => ( type => 'Reset',
			   element_wrapper_class => [ 'col-xs-12' ],
			   element_class => [ 'btn', 'btn-danger', 'btn-block', ],
			   wrapper_class => [ 'col-xs-4' ],
			   value => 'Reset' );

has_field 'aux_submit' => ( type => 'Submit',
			    wrapper_class => [ 'col-xs-8', ],
			    element_class => [ 'btn', 'btn-success', 'btn-block' ],
			    value => 'Submit' );

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
      ->add_error('password and confirmation does not match');
  } elsif ( (defined $self->field('password_init')->value &&
	     ! defined $self->field('password_cnfm')->value ) ||
	    (defined $self->field('password_init')->value &&
	     defined $self->field('password_cnfm')->value &&
	     ($self->field('password_init')->value ne '' &&
	      $self->field('password_cnfm')->value eq '' ) ) ) {
    $self->field('password_cnfm')
      ->add_error('confirmation is mandatory if password present');
  } elsif ( (! defined $self->field('password_init')->value &&
	     defined $self->field('password_cnfm')->value ) ||
	    (defined $self->field('password_init')->value &&
	     defined $self->field('password_cnfm')->value &&
	     ($self->field('password_init')->value eq '' &&
	      $self->field('password_cnfm')->value ne '' ) ) ) {
    $self->field('password_init')
      ->add_error('password mandatory if confirmation present');
  }

  # this realized with HTML::FormHandler::Types Printable
  if ( defined $self->field('password_init')->value &&
       defined $self->field('password_cnfm')->value &&
       ( $self->is_ascii($self->field('password_init')->value) ||
	 $self->is_ascii($self->field('password_cnfm')->value) )
     ) {
    $self->field('password_init')
      ->add_error('password has to be ASCII only!');
    $self->field('password_cnfm')
      ->add_error('confirmation has to be ASCII only!');
  }

}

######################################################################

no HTML::FormHandler::Moose;

__PACKAGE__->meta->make_immutable;

1;

# -*- mode: cperl -*-
#

package UMI::Form::ModPwd;

use HTML::FormHandler::Moose;
BEGIN { extends 'UMI::Form::LDAP'; with 'Tools'; }

use HTML::FormHandler::Types ('NoSpaces', 'WordChars', 'NotAllDigits', 'Printable', 'PositiveNum' );

has '+item_class' => ( default =>'ModPwd' );
has '+action' => ( default => '/searchby/modify_userpassword' );

sub build_form_element_class { [ 'form-horizontal formajaxer' ] }

has_field 'ldap_modify_password' => ( type => 'Hidden', );

has_field 'checkonly'
  => (
      type                  => 'Checkbox',
      label                 => 'Check Only',
      element_wrapper_class => [ 'offset-md-2', 'col-10', ],
      element_class         => [ qw( disabler-checkbox
				     disableable
				     disabled-if-pwddefault
				     disabled-if-pwdpronounceable ), ],
      element_attr          => { title => 'Check password against current one.',
				 'data-mode' => "pwdcheckonly", },
      wrapper_class         => [ 'row', 'deactivate-bottom', ],
     );

has_field 'password_init'
  => ( type                  => 'Password',
       apply                 => [ NoSpaces, NotAllDigits, Printable ],
       minlength             => 7, maxlength => 128,
       label                 => 'New Password',
       label_class           => [ 'col', 'text-right', 'font-weight-bold', ],
       element_wrapper_class => [ 'input-sm', 'col-10', ],
       element_class         => [ qw( disabler-input
				      disableable
				      disabled-if-pwdpronounceable ), ],
       element_attr          => { placeholder => 'Password',
				  'data-mode' => 'pwddefault', },
       wrapper_class         => [ 'row', 'deactivate-bottom', ],
     );

has_field 'password_cnfm'
  => ( type                  => 'Password',
       apply                 => [ NoSpaces, NotAllDigits, Printable ],
       minlength             => 7, maxlength => 128,
       label                 => 'Confirm Password',
       label_class           => [ 'col', 'text-right', 'font-weight-bold', ],
       element_wrapper_class => [ 'input-sm', 'col-10', ],
       element_class         => [ qw( disabler-input
				      disableable
			      disabled-if-pwdcheckonly
			      disabled-if-pwdpronounceable ), ],
       element_attr          => { placeholder => 'Confirm Password',
				  'data-mode' => 'pwddefault', },
       wrapper_class         => [ 'row', 'deactivate-bottom', ],
     );

has_field 'aux_pwdcomment'
  => ( type          => 'Display',
       html          => '<div class="form-group"><div class="help-block col-md-10 col-md-offset-2"><em>' .
       'leave, both New/Confirm Password fields empty, to generate strong password according the options bellow</em></div></div>',
       wrapper_class => [ 'deactivate-bottom', ],
     );


has_field 'pronounceable'
  => (
      type                  => 'Checkbox',
      label                 => 'Pronounceable',
      element_wrapper_class => [ 'offset-md-2', 'col-10', ],
      element_class         => [ qw( disabler-checkbox
				     disableable
				     disabled-if-pwdcheckonly
				     disabled-if-pwddefault ) ],
      element_attr          => { title => 'Completely random word if unchecked, othervise max lengh is ' .
				 UMI->config->{pwd}->{lenp} },
      wrapper_class         => [ 'row', 'deactivate-top', 'mt-5', ],
     );

has_field 'pwd_len'
  => ( type          => 'Display',
       html          => sprintf('
<div class="form-group row deactivate-top">
  <label class="col-2 text-right font-weight-bold control-label" title="" for="pwd_len">
    Pwd length: <span id="pwd_len_size" class="text-primary"></span>
  </label>
  <div class="col-9">
    <input id="pwd_len" name="pwd_len" type="range" class="custom-range" min="%s" max="%s" step="1" value="%s" title="min: %s; default common: %s; max common: %s; max pronouceable: %s"/>
  </div>
  <div class="col-1 font-weight-bold">
    <span>%s</span>
  </div>
</div>
<script>
 $(function () {
  var slider = document.getElementById("pwd_len");
  var output = document.getElementById("pwd_len_size");
  output.innerHTML = slider.value;

  slider.oninput = function() {
    output.innerHTML = this.value;
  }
 });
</script>
',
				UMI->config->{pwd}->{len_min},
				UMI->config->{pwd}->{len_max},
				UMI->config->{pwd}->{len},
				UMI->config->{pwd}->{len_min},
				UMI->config->{pwd}->{len},
				UMI->config->{pwd}->{len_max},
				UMI->config->{pwd}->{lenp},
				UMI->config->{pwd}->{len_max}),
     );

# has_field 'pronounceable'
#   => (
#       type                  => 'Checkbox',
#       label                 => 'Pronounceable',
#       element_wrapper_class => [ 'offset-md-2', 'col-10', ],
#       element_class         => [ qw( disabler-checkbox
# 				     disableable
# 				     disabled-if-pwdcheckonly
# 				     disabled-if-pwddefault ) ],
#       element_attr          => { title => 'Completely random word if unchecked, othervise max lengh is ' .
# 				 UMI->config->{pwd}->{lenp},
# 				 'data-mode' => "pwdpronounceable", },
#       wrapper_class         => [ 'row', 'deactivate-top', ],
#      );

# has_field 'pwd_len'
#   => (
#       type                  => 'Integer',
#       apply                 => [ NoSpaces, PositiveNum ],
#       label                 => 'Password Length',
#       label_class           => [ 'col', 'text-right', 'font-weight-bold', ],
#       element_wrapper_class => [ 'input-sm', 'col-10', ],
#       element_class         => [ qw( disabler-input
# 				     disableable
# 				     disabled-if-pwdcheckonly
# 				     disabled-if-pwddefault ) ],
#       element_attr          => { placeholder => 'max ' . UMI->config->{pwd}->{len} .
# 				 ' for completely random and max ' .
# 				 UMI->config->{pwd}->{lenp} . ' for pronounceable',
# 				 'data-mode' => "pwdpronounceable", },
#       wrapper_class         => [ 'row', 'deactivate-top', ],
#      );

has_field 'pwd_cap'
  => ( type          => 'Display',
       html          => sprintf('
<div class="form-group row deactivate-top">
  <label class="col-2 text-right font-weight-bold control-label" title="" for="pwd_cap">
    Capital Chars: <span id="pwd_cap_size" class="text-primary"></span>
  </label>
  <div class="col-9">
    <input id="pwd_cap" name="pwd_cap" type="range" class="custom-range" min="0" max="%s" step="1" value="0"/>
  </div>
  <div class="col-1 font-weight-bold">
    <span>%s</span>
  </div>
</div>
<script>
 $(function () {
  var slider = document.getElementById("pwd_cap");
  var output = document.getElementById("pwd_cap_size");
  output.innerHTML = slider.value;

  slider.oninput = function() {
    output.innerHTML = this.value;
  }
 });
</script>
',
			       UMI->config->{pwd}->{cap},
			       UMI->config->{pwd}->{cap}),
     );

# has_field 'pwd_cap'
#   => (
#       type                  => 'Integer',
#       apply                 => [ NoSpaces, PositiveNum ],
#       label                 => 'Capital Characters',
#       label_class           => [ 'col', 'text-right', 'font-weight-bold', ],
#       element_wrapper_class => [ 'input-sm', 'col-10', ],
#       element_class         => [ qw( disabler-input
# 				     disableable
# 				     disabled-if-pwdcheckonly
# 				     disabled-if-pwddefault ) ],
#       element_attr          => { placeholder => 'max ' . UMI->config->{pwd}->{cap},
# 				 title       => 'up to this many characters will be upper case',
# 				 'data-mode' => "pwdpronounceable", },
#       wrapper_class         => [ 'row', 'deactivate-top', ],
#      );

has_field 'pwd_num'
  => ( type          => 'Display',
       html          => sprintf('
<div class="form-group row deactivate-top">
  <label class="col-2 text-right font-weight-bold control-label" title="" for="pwd_num">
    Num And Spec. Chars: <span id="pwd_num_size" class="text-primary"></span>
  </label>
  <div class="col-9">
    <input id="pwd_num" name="pwd_num" type="range" class="custom-range" min="0" max="%s" step="1" value="0"/>
  </div>
  <div class="col-1 font-weight-bold">
    <span>%s</span>
  </div>
</div>
<script>
 $(function () {
  var slider = document.getElementById("pwd_num");
  var output = document.getElementById("pwd_num_size");
  output.innerHTML = slider.value;

  slider.oninput = function() {
    output.innerHTML = this.value;
  }
 });
</script>
',
			       UMI->config->{pwd}->{num},
			       UMI->config->{pwd}->{num}),
     );

# has_field 'pwd_num'
#   => (
#       type                  => 'Integer',
#       apply                 => [ NoSpaces, PositiveNum ],
#       label                 => 'Numbers And Spec. Characters',
#       label_class           => [ 'col', 'text-right', 'font-weight-bold', ],
#       element_wrapper_class => [ 'input-sm', 'col-10', ],
#       element_class         => [ qw( disabler-input
# 				     disableable
# 				     disabled-if-pwdcheckonly
# 				     disabled-if-pwddefault ) ],
#       element_attr          => { placeholder => 'max ' . UMI->config->{pwd}->{num},
# 				 title       => 'up to that many, numbers and special characters will occur in the password',
# 				 'data-mode' => "pwdpronounceable", },
#       wrapper_class         => [ 'row', 'deactivate-top', ],
#      );

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

sub build_render_list {[ 'checkonly', 'ldap_modify_password', 'password_init', 'password_cnfm', 'pronounceable', 'pwd_len', 'pwd_cap', 'pwd_num', 'aux_submitit' ]}

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
       ! defined $self->field('checkonly')->value &&
       ($self->field('password_init')->value ne $self->field('password_cnfm')->value)
     ) {
    $self->field('password_init')
      ->add_error('password and confirmation does not match');
  } elsif ( ! defined $self->field('checkonly')->value &&
	    (defined $self->field('password_init')->value &&
	     ! defined $self->field('password_cnfm')->value ) ||
	    (defined $self->field('password_init')->value &&
	     defined $self->field('password_cnfm')->value &&
	     ($self->field('password_init')->value ne '' &&
	      $self->field('password_cnfm')->value eq '' ) ) ) {
    $self->field('password_cnfm')
      ->add_error('confirmation is mandatory if password present');
  } elsif ( ! defined $self->field('checkonly')->value &&
	    (! defined $self->field('password_init')->value &&
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

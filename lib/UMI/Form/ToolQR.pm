# -*- mode: cperl; mode: follow; -*-
#

package UMI::Form::ToolQR;

use HTML::FormHandler::Moose;
extends 'UMI::Form::LDAP';

use HTML::FormHandler::Types ('NoSpaces', 'WordChars', 'NotAllDigits', 'Printable' );

use utf8;

has '+action' => ( default => '/toolqr' );

sub build_form_element_class { [ 'form-horizontal formajaxer', ] }

sub html_attributes {
  my ( $self, $field, $type, $attr ) = @_;
  push @{$attr->{'class'}}, 'required'
    if $type eq 'label' && $field->required;
}

has_field 'toqr'
  => ( type                  => 'TextArea',
       label                 => 'Text to QR Code',
       label_class           => [ 'col', 'text-right', 'font-weight-bold', ],
       element_wrapper_class => [ 'input-sm', 'col-10', ],
       element_class         => [ 'input-sm', 'text-monospace', ],
       element_attr          => { placeholder => 'Twas bryllyg, and ye slythy toves; Did gyre and gymble in ye wabe: All mimsy were ye borogoves; And ye mome raths outgrabe. - /Jabberwocky/' },
       maxlength             => 1660,
       # cols => 30,
       rows                  => 4,
       wrapper_class         => [ 'row', 'mt-3', ],
     );


has_field 'mod'
  => ( type          => 'Display',
       html          => sprintf('
<div class="form-group row">
  <label class="col-2 text-right font-weight-bold control-label" title="" for="mod">
    Module Size: <span id="mod_size" class="text-primary"></span>
  </label>
  <div class="col-1 text-right font-weight-bold">
    <span>1</span>
  </div>
  <div class="col-8">
    <input id="mod" name="mod" type="range" class="custom-range" min="1" max="30" step="1" value="5"/>
  </div>
  <div class="col-1 font-weight-bold">
    <span>30</span>
  </div>
</div>
<script>
 $(function () {
  var slider = document.getElementById("mod");
  var output = document.getElementById("mod_size");
  output.innerHTML = slider.value;

  slider.oninput = function() {
    output.innerHTML = this.value;
  }
 });
</script>
'),
       wrapper_class => [ 'row', ],
     );

# has_field 'mod'
#   => ( type                  => 'Select',
#        label                 => 'Module Size',
#        label_class           => [ 'col', 'text-right', 'font-weight-bold', ],
#        element_wrapper_class => [ 'input-sm', 'col-10', ],
#        element_attr          => { title => 'Size of modules (QR code unit)', },
#        element_class         => [ 'input-sm', 'custom-select', ],
#        options               => [{ value =>  '1', label =>  '1', },
# 				 { value =>  '2', label =>  '2', },
# 				 { value =>  '3', label =>  '3', },
# 				 { value =>  '4', label =>  '4', },
# 				 { value =>  '5', label =>  '5', selected => 'on', },
# 				 { value =>  '6', label =>  '6', },
# 				 { value =>  '7', label =>  '7', },
# 				 { value =>  '8', label =>  '8', },
# 				 { value =>  '9', label =>  '9', },
# 				 { value => '10', label => '10', },
# 				 { value => '11', label => '11', },
# 				 { value => '12', label => '12', },
# 				 { value => '13', label => '13', },
# 				 { value => '14', label => '14', },
# 				 { value => '15', label => '15', },
# 				 { value => '16', label => '16', },
# 				 { value => '17', label => '17', },
# 				 { value => '18', label => '18', },
# 				 { value => '19', label => '19', },
# 				 { value => '20', label => '20', },
# 				 { value => '21', label => '21', },
# 				 { value => '22', label => '22', },
# 				 { value => '23', label => '23', },
# 				 { value => '24', label => '24', },
# 				 { value => '25', label => '25', },
# 				 { value => '26', label => '26', },
# 				 { value => '27', label => '27', },
# 				 { value => '28', label => '28', },
# 				 { value => '29', label => '29', },
# 				 { value => '30', label => '30', },],
#        wrapper_class         => [ 'row', ],
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

sub build_render_list {[ 'toqr', 'mod', 'aux_submitit' ]}

######################################################################
# ====================================================================
# == VALIDATION ======================================================
# ====================================================================
######################################################################

sub validate {
  my $self = shift;

  # if ( $self->field('password1')->value ne $self->field('password2')->value ) {
  #   $self->field('password2')->add_error('<span class="fa fa-exclamation-circle"></span>&nbsp;password and its confirmation does not match');
  # }

  # my $ldap_crud = $self->ldap_crud;
  # my $ldap = $ldap_crud->umi_bind({
  # 				   dn => 'uid=' . $self->uid . ',ou=people,dc=ibs',
  # 				   password => $self->pwd,
  # 				  });
  # my $mesg =
  #   $ldap_crud->umi_search( $ldap,
  # 			    {
  # 			     ldap_search_scope => 'sub',
  # 			     ldap_search_filter => '(&(givenname=' . 
  # 			     $self->field('fname')->value . ')(sn=' .
  # 			     $self->field('lname')->value . ')(uid=*-' .
  # 			     $self->field('login')->value . '))',
  # 			     ldap_search_base => 'ou=People,dc=ibs',
  # 			      ldap_search_attrs => [ 'uid' ],
  # 			    }
  # 			  );

  # if ($mesg->count) {
  #   my $err = '<span class="fa fa-exclamation-circle"></span> Fname+Lname+Login exists';
  #   $self->field('fname')->add_error($err);
  #   $self->field('lname')->add_error($err);
  #   $self->field('login')->add_error($err);

  #   $err = '<div class="alert alert-danger">' .
  #     '<span style="font-size: 140%" class="icon_error-oct" aria-hidden="true"></span>' .
  # 	'&nbsp;Account with the same fields &laquo;<strong>First Name&raquo;</strong>,' .
  # 	  ' &laquo;<strong>Last Name&raquo;</strong> and &laquo;<strong>Login&raquo;</strong>' .
  # 	    ' already exists!<br>Consider one of:<ul>' .
  # 	      '<li>change Login in case you need another account for the same person</li>' .
  # 		'<li>add service account to the existent one</li></ul></div>';
  #   my $error = $self->form->success_message;
  #   $self->form->error_message('');
  #   $self->form->add_form_error($error . $err);
  # }
  # $ldap->unbind;
}

######################################################################

######################################################################

no HTML::FormHandler::Moose;

__PACKAGE__->meta->make_immutable;

1;

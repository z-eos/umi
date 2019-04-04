# -*- mode: cperl; mode: follow; -*-
#

package UMI::Form::ToolSshKeyGen;

use HTML::FormHandler::Moose;
extends 'UMI::Form::LDAP';

use utf8;

has '+action' => ( default => '/toolsshkeygen' );

sub build_form_element_class { [ qw(form-horizontal formajaxer), ] }

sub html_attributes {
  my ( $self, $field, $type, $attr ) = @_;
  push @{$attr->{'class'}}, 'required'
    if $type eq 'label' && $field->required;
}

has_field 'key_type'
  => ( type                  => 'Select',
       label                 => 'Type',
       label_class           => [ 'col', 'text-right', 'font-weight-bold', ],
       wrapper_class         => [ 'row', 'mt-4', ],
       element_wrapper_class => [ 'input-sm', 'col-10', ],
       element_class         => [ 'custom-select', ],
       element_attr          => { title => 'SSH key types', },
       options               => [{ value => 'RSA',      label => 'RSA'},
				 { value => 'DSA',      label => 'DSA', disabled => 'disabled' },
				 { value => 'ECDSA256', label => 'ECDSA256', disabled => 'disabled' },
				 { value => 'ECDSA384', label => 'ECDSA384', disabled => 'disabled' },
				 { value => 'ECDSA521', label => 'ECDSA521', disabled => 'disabled'}, ],
       required              => 1 );

has_field 'bits'
  => ( type          => 'Display',
       html          => sprintf('
<div class="form-group row deactivate-top">
  <label class="col-2 text-right font-weight-bold control-label" title="" for="bits">
    Bits: <span id="bits_size" class="text-primary"></span>
  </label>
  <div class="col-9">
    <input id="bits" name="bits" type="range" class="custom-range" min="1024" max="4096" step="1024" value="2048"/>
  </div>
  <div class="col-1 font-weight-bold">
    <span>4096</span>
  </div>
</div>
<script>
 $(function () {
  var slider = document.getElementById("bits");
  var output = document.getElementById("bits_size");
  output.innerHTML = slider.value;

  slider.oninput = function() {
    output.innerHTML = this.value;
  }
 });
</script>
'),
     );

# has_field 'bits'
#   => ( type                  => 'Select',
#        label                 => 'Bits',
#        label_class           => [ 'col', 'text-right', 'font-weight-bold', ],
#        wrapper_class         => [ 'row', ],
#        element_wrapper_class => [ 'input-sm', 'col-10', ],
#        element_attr          => { title => 'Number of bits in the SSH key.', },
#        options               => [{ value => '1024', label => '1024' },
# 				 { value => '2048', label => '2048', selected => 'selected'},
# 				 { value => '3060', label => '3060'},
# 				 { value => '4096', label => '4096'},
# 				 { value => '128',  label =>  '128', disabled => 'disabled'},
# 				 { value => '256',  label =>  '256', disabled => 'disabled'},
# 				 { value => '384',  label =>  '384', disabled => 'disabled'},
# 				 { value => '512',  label =>  '512', disabled => 'disabled'}, ],
#        required              => 1 );

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


sub build_render_list {[ 'key_type', 'bits', 'aux_submitit' ]}


######################################################################

no HTML::FormHandler::Moose;

__PACKAGE__->meta->make_immutable;

1;

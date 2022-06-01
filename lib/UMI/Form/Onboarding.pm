# -*- mode: cperl; mode: follow; -*-
#

package UMI::Form::Onboarding;

use HTML::FormHandler::Moose;
extends 'UMI::Form::LDAP';

use utf8;

has '+action' => ( default => '/onboarding' );

sub build_form_element_class { [ qw(form-horizontal formajaxer), ] }

sub html_attributes {
  my ( $self, $field, $type, $attr ) = @_;
  push @{$attr->{'class'}}, 'required'
    if $type eq 'label' && $field->required;
}

# has_field 'ssh_key_type'
#   => ( type                  => 'Select',
#        label                 => 'SSH Key Type:',
#        label_class           => [ 'col', 'text-right', 'font-weight-bold', ],
#        wrapper_class         => [ 'row', 'mt-4 pt-4', ],
#        element_wrapper_class => [ 'input-sm', 'col-10', ],
#        element_class         => [ 'custom-select', ],
#        element_attr          => { title => 'SSH key types', },
#        options               => [ { value => 'RSA',      label => 'RSA', },
# 				  { value => 'DSA',      label => 'DSA', disabled => 'disabled' },
# 				  { value => 'ECDSA256', label => 'ECDSA256', },
# 				  { value => 'ECDSA384', label => 'ECDSA384', },
# 				  { value => 'ECDSA521', label => 'ECDSA521', },
# 				  { value => 'Ed25519',  label => 'Ed25519',  }, ],
#        required              => 1 );

# has_field 'ssh_key_bits'
#   => ( type => 'Display',
#        html => sprintf('<div class="form-group row deactivate-top mb-5 pb-5">
#   <label class="col-2 text-right font-weight-bold control-label" title="" for="bits">
#     SSH Key Size: <span id="ssh_key_bits_size" class="text-primary"></span>
#   </label>
#   <div class="col-9">
#     <input id="ssh_key_bits" name="ssh_key_bits" type="range" class="custom-range" min="1024" max="4096" step="1024" value="2048"/>
#   </div>
#   <div class="col-1 font-weight-bold">
#     <span>4096 bit</span>
#   </div>
# </div>
# <script>
#  $(function () {
#   var slider = document.getElementById("ssh_key_bits");
#   var output = document.getElementById("ssh_key_bits_size");
#   output.innerHTML = slider.value;
#   slider.oninput = function() { output.innerHTML = this.value; }
#  });
# </script>'),
#      );

# has_field 'gpg_key_bits'
#   => ( type => 'Display',
#        html => sprintf('<div class="form-group row deactivate-top mt-5 pt-5">
#   <label class="col-2 text-right font-weight-bold control-label" title="" for="bits">
#     GPG Key Size: <span id="gpg_key_bits_size" class="text-primary"></span>
#   </label>
#   <div class="col-9">
#     <input id="gpg_key_bits" name="gpg_key_bits" type="range" class="custom-range" min="1024" max="4096" step="1024" value="2048"/>
#   </div>
#   <div class="col-1 font-weight-bold">
#     <span>4096 bit</span>
#   </div>
# </div>
# <script>
#  $(function () {
#   var slider = document.getElementById("gpg_key_bits");
#   var output = document.getElementById("gpg_key_bits_size");
#   output.innerHTML = slider.value;
#   slider.oninput = function() { output.innerHTML = this.value; }
#  });
# </script>'),
#      );

has_field 'aux_submit'
  => ( type          => 'Submit',
       element_class => [ qw( btn btn-success btn-block btn-lg
			      font-weight-bold text-uppercase) ],
       wrapper_class => [ 'px-0', 'my-3', 'col-6', ],
       value         => 'Submit' );

# has_block 'aux_submitit'
#   => ( tag => 'div',
#        render_list => [ 'aux_submit'],
#        class => [ 'row', ]
#      );

# sub build_render_list {[ 'ssh_key_type', 'ssh_key_bits', 'gpg_key_bits', 'aux_submitit' ]}


######################################################################

no HTML::FormHandler::Moose;

__PACKAGE__->meta->make_immutable;

1;

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
  => ( type => 'Select',
       label => 'Type',
       label_class => [ 'col-2', ],
       wrapper_class => [ 'row', ],
       element_wrapper_class => [ 'col-2', ],
       element_class => [ 'input-sm', ],
       element_attr => { title => 'SSH key types', },
       options => [{ value => 'RSA',      label => 'RSA'},
		   { value => 'DSA',      label => 'DSA', disabled => 'disabled' },
		   { value => 'ECDSA256', label => 'ECDSA256', disabled => 'disabled' },
		   { value => 'ECDSA384', label => 'ECDSA384', disabled => 'disabled' },
		   { value => 'ECDSA521', label => 'ECDSA521', disabled => 'disabled'}, ],
       required => 1 );

has_field 'bits'
  => ( type => 'Select',
       label => 'Bits',
       label_class => [ 'col-2', ],
       wrapper_class => [ 'row', ],
       element_wrapper_class => [ 'col-2', ],
       element_class => [ 'input-sm', ],
       element_attr => { title => 'Number of bits in the SSH key.', },
       options => [{ value => '1024', label => '1024' },
		   { value => '2048', label => '2048', selected => 'selected'},
		   { value => '3060', label => '3060'},
		   { value => '4096', label => '4096'},
		   { value => '128',  label =>  '128', disabled => 'disabled'},
		   { value => '256',  label =>  '256', disabled => 'disabled'},
		   { value => '384',  label =>  '384', disabled => 'disabled'},
		   { value => '512',  label =>  '512', disabled => 'disabled'}, ],
       required => 1 );


has_field 'aux_reset' => ( type => 'Reset',
			   wrapper_class => [ 'col-xs-4' ],
			   element_class => [ 'btn', 'btn-danger', 'btn-block', ],
			   element_wrapper_class => [ 'col-xs-12', ],
			   # value => 'Reset'
			 );

has_field 'aux_submit' => (
			   type => 'Submit',
			   wrapper_class => [ 'col-xs-8'],
			   element_class => [ 'btn', 'btn-success', 'btn-block', ],
			   # label_no_filter => 1,
			   value => 'Submit'
			  );

has_block 'submitit' => ( tag => 'fieldset',
			  render_list => [ 'aux_reset', 'aux_submit'],
			  label => '&nbsp;',
			  class => [ 'container-fluid' ]
			);

sub build_render_list {[ 'key_type', 'bits', 'submitit' ]}


######################################################################

no HTML::FormHandler::Moose;

__PACKAGE__->meta->make_immutable;

1;

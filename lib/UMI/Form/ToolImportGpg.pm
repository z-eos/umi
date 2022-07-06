# -*- mode: cperl; mode: follow; -*-
#

package UMI::Form::ToolImportGpg;

use HTML::FormHandler::Moose;
extends 'UMI::Form::LDAP';

use HTML::FormHandler::Types ('NoSpaces', 'WordChars', 'NotAllDigits', 'Printable' );

use utf8;

has '+action' => ( default => '/toolimportgpg' );

sub build_form_element_class { [ 'form-horizontal formajaxer', ] }

sub html_attributes {
  my ( $self, $field, $type, $attr ) = @_;
  push @{$attr->{'class'}}, 'required'
    if $type eq 'label' && $field->required;
}

has '+enctype' => ( default => 'multipart/form-data');

# has_field 'file'
#   => ( type          => 'Display',
#        html          => '<div class="custom-file">
#   <input type="file"
#          class="custom-file-input btn btn-sm btn-secondary"
#          id="file">
#   <label class="custom-file-label col-6 offset-md-2" for="file">Select GPG File</label>
# </div>');

# has_field 'file'
#   => ( type                  => 'File',
#        wrapper_attr          => { id => 'fieldfile', },
#        wrapper_class         => [ 'custom-file', 'ml-1', 'mb-3', 'row', ],
#        label                 => 'Select GPG File',
#        label_class           => [ 'custom-file-label', 'col-6', 'offset-md-2', ],
#        label_attr            => {  'data-browse' => 'Chose File', },
#        element_class         => [ 'btn', 'btn-default', 'btn-secondary', 'custom-file-input', ],
#        element_wrapper_class => [ 'input-sm', ],
#        max_size              => '100000',
#        # required => 1,
#      );

has_field 'key_file'
  => ( type                  => 'Upload',
       wrapper_attr          => { id => 'fieldfile', },
       wrapper_class         => [ 'row', ],
       label                 => 'GPG File',
       label_class           => [ 'col', 'text-right', 'font-weight-bold', ],
       element_class         => [ 'btn', 'btn-default', ],
       element_wrapper_class => [ 'input-sm', 'col-10', ],
       max_size              => undef, # '1000000',
       # required => 1,
     );

has_field 'key_text'
  => ( type                  => 'TextArea',
       wrapper_attr          => { id => 'fieldgpg', },
       wrapper_class         => [ 'row', ],
       label                 => 'GPG Data',
       label_class           => [ 'col', 'text-right', 'font-weight-bold', ],
       element_wrapper_class => [ 'input-sm', 'col-10', ],
       element_class         => [ 'text-monospace' ],
       element_attr          => { placeholder => 'GPG data', },
       # cols => 30,
       rows                  => 20
     );

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

sub build_render_list {[ 'key_file', 'key_text', 'aux_submitit' ]}

######################################################################
# == VALIDATION ======================================================
######################################################################

sub validate {
  my $self = shift;

  if ( ! defined $self->field('key_file')->value && ! defined $self->field('key_text')->value ) {
    $self->field('key_file')->add_error('<span class="fa fa-exclamation-circle"></span>&nbsp;either field <em>GPG file</em> or <em>GPG data</em>, is required!');
    $self->field('key_text')->add_error('<span class="fa fa-exclamation-circle"></span>&nbsp;either field <em>GPG data</em> or <em>GPG file</em>, is required!');
  }

  if ( defined $self->field('key_file')->value && defined $self->field('key_text')->value ) {
    $self->field('key_file')->add_error('<span class="fa fa-exclamation-circle"></span>&nbsp;only one field <em>GPG file</em> or <em>GPG data</em>, is allowed!');
    $self->field('key_text')->add_error('<span class="fa fa-exclamation-circle"></span>&nbsp;only one field <em>GPG data</em> or <em>GPG file</em>, is allowed!');
  }
}

######################################################################

no HTML::FormHandler::Moose;

__PACKAGE__->meta->make_immutable;

1;

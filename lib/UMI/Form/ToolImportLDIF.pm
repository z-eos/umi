# -*- mode: cperl; mode: follow; -*-
#

package UMI::Form::ToolImportLDIF;

use HTML::FormHandler::Moose;
extends 'UMI::Form::LDAP';

use HTML::FormHandler::Types ('NoSpaces', 'WordChars', 'NotAllDigits', 'Printable' );

use utf8;

has '+action' => ( default => '/toolimportldif' );

sub build_form_element_class { [ 'form-horizontal formajaxer', ] }

sub html_attributes {
  my ( $self, $field, $type, $attr ) = @_;
  push @{$attr->{'class'}}, 'required'
    if $type eq 'label' && $field->required;
}

has '+enctype' => ( default => 'multipart/form-data');

has_field 'file'
  => ( type                  => 'File',
       wrapper_attr          => { id => 'fieldfile', },
       wrapper_class         => [ 'custom-file', 'mb-3', 'col-4', 'offset-md-2', ],
       label                 => 'Select LDIF File',
       label_class           => [ 'custom-file-label', ],
       label_attr            => {  'data-browse' => 'Chose File', },
       element_class         => [ 'btn', 'btn-default', 'btn-secondary', 'custom-file-input', ],
       element_wrapper_class => [ 'input-sm', ],
       max_size              => '100000',
       # required => 1,
     );

# has_field 'file'
#   => ( type                  => 'Upload',
#        wrapper_attr          => { id => 'fieldfile', },
#        wrapper_class         => [ 'row', ],
#        label                 => 'LDIF File',
#        label_class           => [ 'col', 'text-right', 'font-weight-bold', ],
#        element_class         => [ 'btn', 'btn-default', 'btn-secondary', ],
#        element_wrapper_class => [ 'input-sm', 'col-10', ],
#        max_size              => '100000',
#        # required => 1,
#      );

has_field 'ldif'
  => ( type                  => 'TextArea',
       wrapper_attr          => { id => 'fieldldif', },
       wrapper_class         => [ 'row', ],
       label                 => 'LDIF Data',
       label_class           => [ 'col', 'text-right', 'font-weight-bold', ],
       element_wrapper_class => [ 'input-sm', 'col-10', ],
       element_class         => [ 'text-monospace' ],
       element_attr          => { placeholder => 'LDIF data', },
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
  => ( tag => 'fieldset',
       render_list => [ 'aux_reset', 'aux_submit'],
       class => [ 'row', ]
     );

sub build_render_list {[ 'file', 'ldif', 'aux_submitit' ]}

######################################################################
# == VALIDATION ======================================================
######################################################################

sub validate {
  my $self = shift;

  if ( ! defined $self->field('file')->value && ! defined $self->field('ldif')->value ) {
    $self->field('file')->add_error('<span class="fa fa-exclamation-circle"></span>&nbsp;either field <em>LDIF file</em> or <em>LDIF data</em>, is required!');
    $self->field('ldif')->add_error('<span class="fa fa-exclamation-circle"></span>&nbsp;either field <em>LDIF data</em> or <em>LDIF file</em>, is required!');
  }

  if ( defined $self->field('file')->value && defined $self->field('ldif')->value ) {
    $self->field('file')->add_error('<span class="fa fa-exclamation-circle"></span>&nbsp;only one field <em>LDIF file</em> or <em>LDIF data</em>, is allowed!');
    $self->field('ldif')->add_error('<span class="fa fa-exclamation-circle"></span>&nbsp;only one field <em>LDIF data</em> or <em>LDIF file</em>, is allowed!');
  }
}

######################################################################

no HTML::FormHandler::Moose;

__PACKAGE__->meta->make_immutable;

1;

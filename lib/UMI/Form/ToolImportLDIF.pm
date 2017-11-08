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
  => ( type => 'Upload',
       wrapper_attr => { id => 'fieldfile', },
       label => 'LDIF File',
       label_class => [ 'col-xs-2' ],
       element_class => [ 'btn', 'btn-default', ],
       element_wrapper_class => [ 'col-xs-10', 'col-lg-5', ],
       max_size => '50000',
       # required => 1,
     );

has_field 'ldif'
  => ( type => 'TextArea',
       wrapper_attr => { id => 'fieldldif', },
       label => 'LDIF Data',
       label_class => [ 'col-xs-2', ],
       element_wrapper_class => [ 'col-xs-10', 'col-lg-7', ],
       element_attr => { placeholder => 'LDIF data', },
       # cols => 30,
       rows => 20
     );

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

sub build_render_list {[ 'file', 'ldif', 'submitit' ]}

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

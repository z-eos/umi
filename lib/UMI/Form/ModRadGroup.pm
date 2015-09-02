# -*- mode: cperl -*-
#

package UMI::Form::ModRadGroup;

use HTML::FormHandler::Moose;
BEGIN { extends 'UMI::Form::LDAP'; with 'Tools'; }

use HTML::FormHandler::Types ('NoSpaces', 'WordChars', 'NotAllDigits', 'Printable' );

has '+action' => ( default => '/searchby/proc' );

sub build_form_element_class { [ 'form-horizontal' ] }
# sub build_form_element_attr { {onsubmit => q{this.is_selected.value = this.groups.value ? 'yes' : 'no'},} }

sub html_attributes {
  my ( $self, $field, $type, $attr ) = @_;
  push @{$attr->{class}}, 'required' if ( $type eq 'label' && $field->required );
}

has_field 'ldap_modify_rad_group' => ( type => 'Hidden', );

has_field 'groups' => ( type => 'Multiple',
			label => '',
			options_method => \&radgroup, );

has_field 'aux_reset' => ( type => 'Reset',
			   wrapper_class => [ 'col-xs-4' ],
			   element_class => [ 'btn', 'btn-danger', 'btn-block', ],
			   element_wrapper_class => [ 'col-xs-12', ],
			   value => 'Reset' );

has_field 'aux_submit' => ( type => 'Submit',
			    wrapper_class => [ 'col-xs-8' ],
			    element_class => [ 'btn', 'btn-success', 'btn-block', ],
			    value => 'Submit' );

sub validate {
  my $self = shift;
}

######################################################################

sub radgroup {
  my $self = shift;
  return unless $self->form->ldap_crud;
  return $self->form->ldap_crud->select_radgroup;
}

######################################################################

no HTML::FormHandler::Moose;

__PACKAGE__->meta->make_immutable;

1;

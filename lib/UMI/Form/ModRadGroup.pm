# -*- mode: cperl -*-
#

package UMI::Form::ModRadGroup;

use HTML::FormHandler::Moose;
BEGIN { extends 'UMI::Form::LDAP'; with 'Tools'; }

use HTML::FormHandler::Types ('NoSpaces', 'WordChars', 'NotAllDigits', 'Printable' );

has '+action' => ( default => '/searchby/proc' );

sub build_form_element_class { [ qw(formajaxer) ] }

sub html_attributes {
  my ( $self, $field, $type, $attr ) = @_;
  push @{$attr->{class}}, 'required' if ( $type eq 'label' && $field->required );
}

has_field 'ldap_modify_rad_group' => ( type => 'Hidden', );
has_field 'aux_runflag'           => ( type => 'Hidden', value => '0' );

has_field 'groups'
  => ( type           => 'Multiple',
       label          => '',
       element_class  => [ 'umi-multiselect2', ],
       element_attr   => { 'data-ico-l'       => 'fa-users-cog',
			   'data-ico-r'       => 'fa-users-cog',
			   'data-placeholder' => 'rad group', },
       options_method => \&radgroup, );

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

sub build_render_list {[ qw( ldap_modify_rad_group
			     aux_runflag
			     groups
			     aux_submitit ) ]}

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

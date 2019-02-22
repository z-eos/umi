# -*- mode: cperl -*-
#

package UMI::Form::abstrNisNetgroup;

use HTML::FormHandler::Moose;
BEGIN { extends 'UMI::Form::LDAP'; with 'Tools'; }

use HTML::FormHandler::Types ('NoSpaces', 'WordChars', 'NotAllDigits', 'Printable' );

has '+action' => ( default => '/abstrnisnetgroup' );

sub build_form_element_class { [ qw(formajaxer) ] }

has '+enctype' => ( default => 'multipart/form-data');

sub html_attributes {
  my ( $self, $field, $type, $attr ) = @_;
  push @{$attr->{class}}, 'required'
    if ( $type eq 'label' && $field->required );

  $attr->{class} = ['hfh', 'repinst']
    if $type eq 'wrapper' && $field->has_flag('is_contains');

  return $attr;
}

has_field 'aux_dn_form_to_modify' => ( type => 'Hidden', );

has_field 'netgroup'
  => ( type                  => 'Select',
       label                 => 'Netgroup',
       label_class           => [ 'col', 'text-right', 'font-weight-bold', ],
       element_wrapper_class => [ 'input-sm', 'col-11' ],
       element_class         => [ 'input-sm', 'custom-select', ],
       wrapper_class         => [ 'row', 'umi-hide', ],
       options_method        => \&netgroup,
       # required              => 1,
     );

has_field 'cn' 
  => ( apply                 => [ NoSpaces, NotAllDigits, Printable ],
       label                 => 'Name',
       label_class           => [ 'col', 'text-right', 'font-weight-bold', ],
       element_wrapper_class => [ 'input-sm', 'col-11', ],
       element_attr          => { placeholder => 'users-allowed-to-fly' },
       wrapper_class         => [ 'row', 'umi-hide', ],
       required              => 1 );


has_field 'uids' 
  => ( type                  => 'Multiple',
       label                 => 'Users',
       label_class           => [ 'font-weight-bold', ],
       element_wrapper_class => [ 'input-sm', ],
       element_class         => [ 'umi-multiselect' ],
       options_method        => \&uids,
       required              => 1,
     );

has_field 'associatedDomain'
  => ( type                  => 'Multiple',
       label                 => 'Hosts',
       label_class           => [ 'font-weight-bold', ],
       element_wrapper_class => [ 'input-sm', ],
       element_class         => [ 'umi-multiselect' ],
       options_method        => \&associatedDomain,
       required              => 1,
     );

has_field 'description'
  => ( type                  => 'TextArea',
       label                 => 'Description',
       label_class           => [ 'col', 'text-right', 'font-weight-bold', ],
       element_wrapper_class => [ 'input-sm', 'col-11', ],
       element_attr          => { placeholder => 'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Suspendisse sed dapibus nulla. Mauris vehicula vehicula ligula ac dapibus. Fusce vehicula a turpis sed. ' },
       wrapper_class         => [ 'row', 'mt-5', ],
       cols                  => 30, rows => 2);

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
       class => [ 'row', 'mt-5', ]
     );


sub build_render_list {[ qw( aux_dn_form_to_modify
			     netgroup
			     cn
			     description
			     uids
			     associatedDomain
			     aux_submitit ) ]}

# sub validate {
#   my $self = shift;
#   my $ldap_crud = $self->ldap_crud;
#   my $mesg = $ldap_crud->search({
# 				 scope => 'one',
# 				 filter => '(cn=' .
# 				 $self->utf2lat( $self->field('cn')->value ) . ')',
# 				 base => $ldap_crud->cfg->{base}->{netgroup},
# 				 attrs => [ 'cn' ],
# 				});
#   $self->field('cn')->add_error('NisNetgroup with name <em>&laquo;' .
#   				$self->utf2lat( $self->field('cn')->value ) . '&raquo;</em> already exists.')
#     if ($mesg->count);
# }

######################################################################

sub netgroup {
  my $self = shift;
  return unless $self->form->ldap_crud;
  return $self->form->ldap_crud->
    bld_select({ base   => $self->form->ldap_crud->cfg->{base}->{netgroup},
		 filter => '(ou=*)',
		 scope  => 'one',
		 attr   => [ 'ou', 'description', ],});
}

sub uids {
  my $self = shift;
  return unless $self->form->ldap_crud;
  return $self->form->ldap_crud->select_uid;
}

sub associatedDomain {
  my $self = shift;
  return unless $self->form->ldap_crud;
  return $self->form->ldap_crud->select_associateddomains;
}



no HTML::FormHandler::Moose;

__PACKAGE__->meta->make_immutable;

1;

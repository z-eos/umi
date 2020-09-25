# -*- mode: cperl -*-
#

package UMI::Form::abstrNisNetgroup;

use HTML::FormHandler::Moose;
BEGIN { extends 'UMI::Form::LDAP'; with 'Tools'; }

use HTML::FormHandler::Types ('NoSpaces', 'WordChars', 'NotAllDigits', 'Printable' );

use Logger;
use Data::Printer;

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
       label_class           => [ 'col-1', 'text-right', 'font-weight-bold', ],
       element_wrapper_class => [ 'input-sm', 'col-11' ],
       element_class         => [ 'input-sm', 'custom-select', ],
       wrapper_class         => [ 'row', ],
       # empty_select          => '--- Choose an Option ---',
       options_method        => \&netgroup,
       # required              => 1,
     );

has_field 'cn'
  => ( apply                 => [ NoSpaces, NotAllDigits, Printable ],
       label                 => 'Name',
       label_class           => [ 'col-1', 'text-right', 'font-weight-bold', ],
       element_wrapper_class => [ 'input-sm', 'col-11', ],
       element_attr          => { placeholder => 'users-allowed-to-fly' },
       wrapper_class         => [ 'row', ],
       required              => 1 );


has_field 'uids'
  => ( type                  => 'Multiple',
       label                 => 'Users',
       label_class           => [ 'col-1', 'text-right', 'font-weight-bold', ],
       element_attr          => { 'data-ico-l'       => 'fa-user',
				  'data-ico-r'       => 'fa-user',
				  'data-placeholder' => 'users', },
       element_wrapper_class => [ 'input-sm', 'col-11' ],
       element_class         => [ 'umi-multiselect2' ],
       options_method        => \&uids,
       wrapper_class         => [ 'row', ],
       required              => 0,
     );

has_field 'associatedDomain'
  => ( type                  => 'Multiple',
       label                 => 'Hosts',
       label_class           => [ 'col-1', 'text-right', 'font-weight-bold', ],
       element_attr          => { 'data-ico-l'       => 'fa-desktop',
				  'data-ico-r'       => 'fa-desktop',
				  'data-placeholder' => 'hosts', },
       element_wrapper_class => [ 'input-sm', 'col-11' ],
       element_class         => [ 'umi-multiselect2' ],
       options_method        => \&associatedDomain,
       wrapper_class         => [ 'row', ],
       required              => 1,
     );

has_field 'ng_access'
  => ( type                  => 'Multiple',
       label                 => 'NG Access',
       label_class           => [ 'col-1', 'text-right', 'font-weight-bold', ],
       element_attr          => { 'data-ico-l'       => 'fa-users',
				  'data-ico-r'       => 'fa-users',
				  'data-placeholder' => 'access netgroups', },
       element_wrapper_class => [ 'input-sm', 'col-11' ],
       element_class         => [ 'umi-multiselect2' ],
       options_method        => \&ng_access,
       wrapper_class         => [ 'row', ],
       required              => 0,
     );

has_field 'ng_category'
  => ( type                  => 'Multiple',
       label                 => 'NG Category',
       label_class           => [ 'col-1', 'text-right', 'font-weight-bold', ],
       element_attr          => { 'data-ico-l'       => 'fa-users',
				  'data-ico-r'       => 'fa-users',
				  'data-placeholder' => 'category netgroups', },
       element_wrapper_class => [ 'input-sm', 'col-11' ],
       element_class         => [ 'umi-multiselect2' ],
       options_method        => \&ng_category,
       wrapper_class         => [ 'row', ],
       required              => 0,
     );

has_field 'description'
  => ( type                  => 'TextArea',
       label                 => 'Description',
       label_class           => [ 'col-1', 'text-right', 'font-weight-bold', ],
       element_wrapper_class => [ 'input-sm', 'col-11', ],
       element_attr          => { placeholder => 'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Suspendisse sed dapibus nulla. Mauris vehicula vehicula ligula ac dapibus. Fusce vehicula a turpis sed. ' },
       wrapper_class         => [ 'row', 'mt-5', ],
       cols                  => 30, rows => 2);

has_field 'aux_submit'
  => ( type          => 'Submit',
       element_class => [ qw( btn
			      btn-success
			      btn-block
			      font-weight-bold
			      text-uppercase) ],
       wrapper_class => [ '', ],
       value         => 'Submit' );

sub build_render_list {[ qw( aux_dn_form_to_modify
			     netgroup
			     cn
			     description
			     uids
			     associatedDomain
			     ng_access
			     ng_category
			     aux_submit ) ]}

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
  my $s = $self->form->ldap_crud->
    bld_select({ base      => $self->form->ldap_crud->cfg->{base}->{netgroup},
		 filter    => '(ou=*)',
		 scope     => 'one',
		 attr      => [ 'ou', 'description', ],
		 empty_row => 1, });
  # log_debug { np($s) };
  return $s;
}

sub ng_access {
  my $self = shift;
  return unless $self->form->ldap_crud;
  my $s = $self->form->ldap_crud->
    bld_select({ base      => 'ou=access,' . $self->form->ldap_crud->cfg->{base}->{netgroup},
		 filter    => '(cn=*)',
		 scope     => 'one',
		 attr      => [ 'cn', ],
		 empty_row => 0, });
  # log_debug { np($s) };
  return $s;
}

sub ng_category {
  my $self = shift;
  return unless $self->form->ldap_crud;
  my $s = $self->form->ldap_crud->
    bld_select({ base      => 'ou=category,' . $self->form->ldap_crud->cfg->{base}->{netgroup},
		 filter    => '(cn=*)',
		 scope     => 'one',
		 attr      => [ 'cn', ],
		 empty_row => 0, });
  # log_debug { np($s) };
  return $s;
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

sub validate {
  my $self = shift;
  
}

no HTML::FormHandler::Moose;

__PACKAGE__->meta->make_immutable;

1;

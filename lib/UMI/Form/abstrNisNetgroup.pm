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

has_field 'cn' => ( apply => [ NoSpaces, NotAllDigits, Printable ],
		    label => 'Name',
		    # label_class => [ 'h2', ],
		    element_attr => { placeholder => 'users-allowed-to-fly' },
		    # wrapper_class => [ 'col-xs-11', 'col-lg-2', ],
		    required => 1 );


has_field 'uids' => ( type           => 'Multiple',
		      label          => 'Users',
		      element_class  => [ 'umi-multiselect' ],
		      options_method => \&uids,
		      required       => 1,
		    );

has_field 'associatedDomain' => ( type           => 'Multiple',
				  label          => 'Hosts',
				  element_class  => [ 'umi-multiselect' ],
				  options_method => \&associatedDomain,
				  required       => 1,
				);

has_field 'description' => ( type => 'TextArea',
			     label => 'Description',
			     element_attr => { placeholder => 'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Suspendisse sed dapibus nulla. Mauris vehicula vehicula ligula ac dapibus. Fusce vehicula a turpis sed. ' },
			     cols => 30, rows => 2);

has_field 'aux_reset' => ( type => 'Reset',
			   wrapper_class => [ 'col-xs-4' ],
			   element_class => [ 'btn', 'btn-danger', 'btn-block' ],
			   element_wrapper_class => [ 'col-xs-12', ],
			   value => 'Reset' );

has_field 'aux_submit' => ( type => 'Submit',
			    wrapper_class => [ 'col-xs-8' ],
			    element_class => [ 'btn', 'btn-success', 'col-xs-12' ],
			    value => 'Submit' );

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

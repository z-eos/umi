# -*- mode: cperl -*-
#

package UMI::Form::ModJpegPhoto;

use HTML::FormHandler::Moose;
BEGIN { extends 'UMI::Form::LDAP'; with 'Tools'; }

use HTML::FormHandler::Types ('NoSpaces', 'WordChars', 'NotAllDigits', 'Printable' );

sub build_form_element_class { [ qw(form-horizontal formajaxer) ] }

# has '+item_class' => ( default =>'ModJpegPhoto' );
has '+enctype' => ( default => 'multipart/form-data');
has '+action' => ( default => '/searchby/proc' );

has_field 'ldap_modify_jpegphoto' => ( type => 'Hidden', );

has_field 'remove' 
  => ( type                  => 'Checkbox',
       label                 => 'Remove Avatar',
       wrapper_class         => [ 'checkbox', ],
       element_wrapper_class => [ 'offset-md-2', 'col-10' ],
       element_attr          => { title => 'When checked, this checkbox causes avatar removal.',}, );

# has_field 'avatar'
#   => ( type                  => 'Upload',
#        label                 => 'Avatar',
#        label_class           => [ 'col', 'text-right', 'font-weight-bold', ],
#        label_attr            => { 'for' => 'avatar' },
#        element_class         => [ 'form-control-file', ],
#        element_wrapper_class => [ 'col-10', ],
#        wrapper_class         => [ 'row', ],
#        max_size              => '100000',
#        # required => 1,
#      );

has_field 'avatar'
  => ( type                  => 'File',
       wrapper_attr          => { id => 'fieldfile', },
       wrapper_class         => [ 'custom-file', 'ml-1', 'mb-3', 'row', ],
       label                 => 'Select GPG File',
       label_class           => [ 'custom-file-label', 'col-10', 'offset-md-2', ],
       label_attr            => {  'data-browse' => 'Chose File', },
       element_class         => [ 'btn', 'btn-default', 'btn-secondary', 'custom-file-input', ],
       element_wrapper_class => [ 'input-sm', ],
       max_size              => '100000',
       # required => 1,
     );


has_field 'aux_reset' 
  => ( type                  => 'Reset',
       wrapper_class         => [ 'col-4' ],
       element_class         => [ 'btn', 'btn-danger', 'btn-block', ],
       value                 => 'Reset' );

has_field 'aux_submit' 
  => ( type          => 'Submit',
       wrapper_class => [ 'col-8', ],
       element_class => [ 'btn', 'btn-success', 'btn-block', ],
       value         => 'Submit' );

has_block 'aux_submitit' 
  => ( tag         => 'div',
       render_list => [ 'aux_reset', 'aux_submit'],
       class       => [ 'row' ]
     );

sub build_render_list {[ 'ldap_modify_jpegphoto', 'remove', 'avatar', 'aux_submitit' ]}

sub html_attributes {
  my ( $self, $field, $type, $attr ) = @_;
  push @{$attr->{class}}, 'required'
    if ( $type eq 'label' && $field->required );
}

# working sample
# sub validate_givenname {
#   my ($self, $field) = @_;
#   unless ( $field->value ne 'Вася' ) {
#     $field->add_error('Such givenName+sn+uid user exists!');
#   }
# }

# sub validate {
#   my $self = shift;
  
# #  $self->field('avatar')->add_error('<span class="fa fa-exclamation-circle"></span>&nbsp;File to be uploaded is mandatory!')
# #    if ! defined $self->field('avatar')->value && defined $self->field('aux_submit')->value && $self->field('aux_submit')->value eq 'Submit';

# # if ( not $self->field('office')->value ) {
# #     $self->field('office')->add_error('<span class="fa fa-exclamation-circle"></span>&nbsp;office is mandatory!');
# #   }


# #   my $ldap_crud = $self->ldap_crud;
# #   my $mesg =
# #     $ldap_crud->search(
# # 		       {
# # 			scope => 'one',
# # 			filter => '(&(givenname=' .
# # 			$self->utf2lat({ to_translate => $self->field('givenname')->value }) . ')(sn=' .
# # 			$self->utf2lat({ to_translate => $self->field('sn')->value }) . ')(uid=*-' .
# # 			$self->field('login')->value . '))',
# # 			base => 'ou=People,dc=umidb',
# # 			attrs => [ 'uid' ],
# # 		       }
# # 		      );

# #   if ($mesg->count) {
# #     my $err = '<span class="fa fa-exclamation-circle"></span> Fname+Lname+Login exists';
# #     $self->field('givenname')->add_error($err);
# #     $self->field('sn')->add_error($err);
# #     $self->field('login')->add_error($err);

# #     $err = '<div class="alert alert-danger">' .
# #       '<span style="font-size: 140%" class="icon_error-oct" aria-hidden="true"></span>' .
# # 	'&nbsp;Account with the same fields &laquo;<strong>First Name&raquo;</strong>,' .
# # 	  ' &laquo;<strong>Last Name&raquo;</strong> and &laquo;<strong>Login&raquo;</strong>' .
# # 	    ' already exists!<br>Consider one of:<ul>' .
# # 	      '<li>change Login in case you need another account for the same person</li>' .
# # 		'<li>add service account to the existent one</li></ul></div>';
# #     my $error = $self->form->success_message;
# #     $self->form->error_message('');
# #     $self->form->add_form_error($error . $err);
# #   }
# #   $ldap_crud->unbind;
# }

######################################################################

no HTML::FormHandler::Moose;

__PACKAGE__->meta->make_immutable;

1;

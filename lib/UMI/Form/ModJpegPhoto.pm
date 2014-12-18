# -*- mode: cperl -*-
#

package UMI::Form::ModJpegPhoto;

use HTML::FormHandler::Moose;
BEGIN { extends 'UMI::Form::LDAP'; with 'Tools'; }

use HTML::FormHandler::Types ('NoSpaces', 'WordChars', 'NotAllDigits', 'Printable' );

has '+item_class' => ( default =>'ModJpegPhoto' );
has '+enctype' => ( default => 'multipart/form-data');
has '+action' => ( default => '/searchby/proc' );

sub build_form_element_class { [ 'form-horizontal' ] }

has_field 'ldap_modify_jpegphoto' => ( type => 'Hidden', );

has_field 'avatar' => ( type => 'Upload',
			label => 'Photo User ID',
			# label_class => [ 'form-group', 'col-md-4' ],
			element_class => [ 'btn', 'btn-default', ],
			# wrapper_class => [ 'col-md-12' ],
			max_size => '50000',
			# required => 1,
		      );

has_field 'reset' => ( type => 'Reset',
#			wrapper_class => [ 'pull-left', 'col-md-2' ],
			element_class => [ 'btn', 'btn-default', ],
		        value => 'Reset' );

has_field 'submit' => ( type => 'Submit',
#			wrapper_class => [ 'pull-right', 'col-md-10' ],
			element_class => [ 'btn', 'btn-default', ],
			value => 'Submit' );

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

sub validate {
  my $self = shift;

  if ( $self->field('avatar')->value eq '' ) {
    $self->field('avatar')->add_error('<span class="fa fa-exclamation-circle"></span>&nbsp;File to be uploaded is mandatory!');
  }

# if ( not $self->field('office')->value ) {
#     $self->field('office')->add_error('<span class="glyphicon glyphicon-exclamation-sign"></span>&nbsp;office is mandatory!');
#   }


#   my $ldap_crud = $self->ldap_crud;
#   my $mesg =
#     $ldap_crud->search(
# 		       {
# 			scope => 'one',
# 			filter => '(&(givenname=' .
# 			$self->utf2lat({ to_translate => $self->field('givenname')->value }) . ')(sn=' .
# 			$self->utf2lat({ to_translate => $self->field('sn')->value }) . ')(uid=*-' .
# 			$self->field('login')->value . '))',
# 			base => 'ou=People,dc=umidb',
# 			attrs => [ 'uid' ],
# 		       }
# 		      );

#   if ($mesg->count) {
#     my $err = '<span class="glyphicon glyphicon-exclamation-sign"></span> Fname+Lname+Login exists';
#     $self->field('givenname')->add_error($err);
#     $self->field('sn')->add_error($err);
#     $self->field('login')->add_error($err);

#     $err = '<div class="alert alert-danger">' .
#       '<span style="font-size: 140%" class="icon_error-oct" aria-hidden="true"></span>' .
# 	'&nbsp;Account with the same fields &laquo;<strong>First Name&raquo;</strong>,' .
# 	  ' &laquo;<strong>Last Name&raquo;</strong> and &laquo;<strong>Login&raquo;</strong>' .
# 	    ' already exists!<br>Consider one of:<ul>' .
# 	      '<li>change Login in case you need another account for the same person</li>' .
# 		'<li>add service account to the existent one</li></ul></div>';
#     my $error = $self->form->success_message;
#     $self->form->error_message('');
#     $self->form->add_form_error($error . $err);
#   }
#   $ldap_crud->unbind;
}

######################################################################

no HTML::FormHandler::Moose;

__PACKAGE__->meta->make_immutable;

1;

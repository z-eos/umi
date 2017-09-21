# -*- mode: cperl -*-
#

package UMI::Form::GitAclReorder;

use HTML::FormHandler::Moose;
BEGIN { extends 'UMI::Form::LDAP'; with 'Tools'; }

has '+item_class' => ( default =>'GitAclReorder' );
has '+action' => ( default => '/searchby/proc' );

has_field 'ldap_gitacl_reorder' => ( type => 'Hidden', );

###
### NOT FINISHED
###

has_field 'gitacls' => ( type => 'Multiple',
			 label => '',
			 # element_class => [ 'multiselect' ],
			 # required => 1,
		       );

sub options_gitacls {
  my $self = shift;
  my ( @groups, $return );
  use Data::Printer;

  return unless $self->ldap_crud;

  my $ldap_crud = $self->ldap_crud;
  my $mesg = $ldap_crud->search( { base => $self->field('ldap_gitacl_reorder')->value,
				   scope => 'base',
				   attrs => ['gitAclProject' ], } );

  if ( ! $mesg->count ) {
    push @{$return->{error}}, $ldap_crud->err($mesg);
  }

  my $gitAclProject = $mesg->entry(0);

  $mesg = $ldap_crud->search( { base => $ldap_crud->cfg->{base}->{gitacl},
				filter => 'gitAclProject=' . $gitAclProj->get_value('gitAclProj'), } );

  my @gitacls = $mesg->sorted('gitAclOrder');

  foreach ( @gitacls ) {
    
  }

  return \@groups;
}


has_field 'reset' => ( type => 'Reset',
		       label => '',
		       wrapper_class => [ 'pull-left', 'col-md-2' ],
		       element_class => [ 'btn', 'btn-default', 'btn-block', ],
		       value => 'Reset' );

has_field 'submit' => ( type => 'Submit',
			wrapper_class => [ 'pull-right', 'col-md-10' ],
			element_class => [ 'btn', 'btn-default', 'btn-block', ],
			value => 'Submit' );

sub html_attributes {
  my ( $self, $field, $type, $attr ) = @_;
  push @{$attr->{class}}, 'required'
    if ( $type eq 'label' && $field->required );
}


sub validate {
  my $self = shift;

  # if ( $self->field('groups')->value eq '' ) {
  #   $self->field('groups')->add_error('<span class="fa fa-exclamation-circle"></span>&nbsp;File to be uploaded is mandatory!');
  # }

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

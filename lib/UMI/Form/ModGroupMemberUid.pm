# -*- mode: cperl -*-
#

package UMI::Form::ModGroupMemberUid;

use HTML::FormHandler::Moose;
BEGIN { extends 'UMI::Form::LDAP'; with 'Tools'; }

use HTML::FormHandler::Types ('NoSpaces', 'WordChars', 'NotAllDigits', 'Printable' );

# has '+item_class' => ( default =>'ModGroupMemberUid' );
has '+action' => ( default => '/searchby/proc' );

sub build_form_element_class { [ 'formajaxer' ] }

has_field 'ldap_modify_memberUid' => ( type => 'Hidden', );

has_field 'memberUid' => ( type => 'Multiple',
			   label => '',
			   element_class => [ 'umi-multiselect2' ],
			   # required => 1,
			 );

sub options_memberUid {
  my $self = shift;

  return unless $self->ldap_crud;

  my ( @memberUid, $return );
  my $ldap_crud = $self->ldap_crud;
  my $mesg = $ldap_crud->search( { base => $ldap_crud->cfg->{base}->{acc_root},
				   scope => 'one',
				   attrs => [ qw{uid givenName sn} ],
				   sizelimit => 0,} );

  push @{$return->{error}}, $ldap_crud->err($mesg)
    if ! $mesg->count;

  my @memberUid_all = $mesg->sorted('uid');

  my ( $gn, $sn);
  foreach ( @memberUid_all ) {
    $gn = $_->get_value('givenName');
    $sn = $_->get_value('sn');
    utf8::decode($gn);
    utf8::decode($sn);
    push @memberUid, { value => $_->get_value('uid'),
		       label => sprintf('%s (%s %s)', $_->get_value('uid'), $gn, $sn), };
  }

  return \@memberUid;
}


has_field 'aux_submit' => ( type                  => 'Submit',
			    wrapper_class         => [ 'col-xs-8' ],
			    element_class         => [ 'btn', 'btn-success', 'btn-block', ],
			    element_wrapper_class => [ 'col-xs-12', ],
			    value                 => 'Submit' );

sub html_attributes {
  my ( $self, $field, $type, $attr ) = @_;
  push @{$attr->{class}}, 'required'
    if ( $type eq 'label' && $field->required );
}


sub validate {
  my $self = shift;

  # if ( $self->field('groups')->value eq '' ) {
  #   $self->field('groups')->add_error('<span class="glyphicon glyphicon-exclamation-sign"></span>&nbsp;File to be uploaded is mandatory!');
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

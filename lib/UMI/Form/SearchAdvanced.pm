# -*- mode: cperl -*-
#

package UMI::Form::SearchAdvanced;

use HTML::FormHandler::Moose;
BEGIN { extends 'UMI::Form::LDAP'; with 'Tools'; }

use HTML::FormHandler::Types ('NoSpaces', 'WordChars', 'NotAllDigits', 'Printable' );

sub build_form_element_class { [ 'form-horizontal', ] }

sub html_attributes {
  my ( $self, $field, $type, $attr ) = @_;
  push @{$attr->{'class'}}, 'required'
    if $type eq 'label' && $field->required;
}

has '+action' => ( default => '/searchadvanced/proc' );

has_field 'search_history'
  => ( type => 'Checkbox',
       # checkbox_value => '0',
       label => 'search history',
       wrapper_class => [ 'checkbox', ],
       element_wrapper_class => [ 'col-xs-3', 'col-xs-offset-2', 'col-lg-1', ],
       element_attr => { title => 'When checked, this checkbox causes additional fields to search in history.',}, );

has_field 'base_dn'
  => ( label => 'Base DN',
       label_class => [ 'col-md-2' ],
       wrapper_class => [ 'searchaccount', ],
       element_wrapper_class => [ 'col-xs-10', 'col-lg-10', ],
       element_attr => { placeholder => UMI->config->{ldap_crud_db}, },
       required => 1 );

has_field 'reqType'
  => ( type => 'Select',
       label => 'reqType',
       label_class => [ 'col-md-2', ],
       wrapper_class => [ 'searchhistory', ],
       element_wrapper_class => [ 'col-xs-5', 'col-lg-2', ],
       options => [{ value => 0, label => '--- cn=umilog search type ---', selected => 'on'},
		   { value => 'add', label => 'add'},
		   { value => 'modify', label => 'modify'},
		   { value => 'delete', label => 'delete'}, ], );

has_field 'reqAuthzID'
  => ( label => 'Action Requester Dn',
       label_class => [ 'col-md-2', ],
       wrapper_class => [ 'searchhistory', ],
       element_wrapper_class => [ 'col-xs-5', 'col-lg-5', ],
       element_attr => { placeholder => 'uid=ACTION-REQUESTED-BY,ou=People,dc=' . UMI->config->{ldap_crud_db_log} },	);

has_field 'reqDn'
  => ( label => 'DN requested',
       label_class => [ 'col-md-2', ],
       wrapper_class => [ 'searchhistory', ],
       element_wrapper_class => [ 'col-xs-5', 'col-lg-5', ],
       element_attr => { placeholder => 'uid=ACTION-REQUESTED-ON,ou=People,dc=' . UMI->config->{ldap_crud_db} }, );

has_field 'reqMod'
  => ( type => 'TextArea',
       label => 'Request Mod',
       label_class => [ 'col-md-2', ],
       wrapper_class => [ 'searchhistory', ],
       element_wrapper_class => [ 'col-xs-10', 'col-lg-10', ],
       element_attr => { placeholder => '*physicalDeliveryOfficeName:= ou=borg,*' },
       rows => 1 );

has_field 'reqOld'
  => ( type => 'TextArea',
       label => 'Request Old',
       label_class => [ 'col-md-2', ],
       wrapper_class => [ 'searchhistory', ],
       element_wrapper_class => [ 'col-xs-10', 'col-lg-10', ],
       element_attr => { placeholder => '*mail: ass2kick@borg.startrek.in*' },
       rows => 1 );

has_field 'reqStart'
  => ( label => 'Request Start Time',
       label_class => [ 'col-md-2', ],
       wrapper_class => [ 'searchhistory', ],
       element_wrapper_class => [ 'col-xs-5', 'col-lg-2', ],
       element_attr => { placeholder => '20141104142246.000014Z' }, );

has_field 'reqEnd'
  => ( label => 'Request End Time',
       label_class => [ 'col-md-2', ],
       wrapper_class => [ 'searchhistory', ],
       element_wrapper_class => [ 'col-xs-5', 'col-lg-2', ],
       element_attr => { placeholder => '20141104142356.000007Z' }, );

has_field 'search_filter'
  => ( type => 'TextArea',
       label => 'Search Filter',
       label_class => [ 'col-md-2', 'required' ],
       wrapper_class => [ 'searchaccount', ],
       element_wrapper_class => [ 'col-xs-10', 'col-lg-10', ],
       element_attr => { placeholder => '(objectClass=*)' },
       rows => 1, );

has_field 'show_attrs' => ( label => 'Show Attributes',
			    label_class => [ 'col-md-2' ],
			    element_wrapper_class => [ 'col-xs-10', 'col-lg-5', ],
			    element_attr => { placeholder => 'cn, uid, mail, authorizedService' });

has_field 'order_by' => ( label => 'Order By',
			  label_class => [ 'col-md-2' ],
			  wrapper_class => [ 'searchaccount', ],
			  element_wrapper_class => [ 'col-xs-5', 'col-lg-5', ],
			  element_attr => { placeholder => 'cn' },
			);

has_field 'search_results' => ( label => 'Search Results',
				label_class => [ 'col-md-2' ],
				element_wrapper_class => [ 'col-xs-2', 'col-lg-1', ],
				element_attr => { placeholder => '50' },);

has_field 'search_scope' => ( type => 'Select',
			      label => 'Search Scope',
			      label_class => [ 'col-md-2' ],
			      wrapper_class => [ 'searchaccount', ],
			      element_wrapper_class => [ 'col-xs-3', 'col-lg-1', ],
			      options => [{ value => 'sub', label => 'Sub', selected => 'on'},
					  { value => 'children', label => 'Children'},
					  { value => 'one', label => 'One'},
					  { value => 'base', label => 'Base'},
					 ],
			    );

has_field 'aux_reset' => ( type => 'Reset',
			   wrapper_class => [ 'col-xs-4' ],
			   element_class => [ 'btn', 'btn-danger', 'btn-block' ],
			   element_wrapper_class => [ 'col-xs-12', ],
		         );

has_field 'aux_submit' => ( type => 'Submit',
			    wrapper_class => [ 'col-md-8' ],
			    element_class => [ 'btn', 'btn-success', 'btn-block' ],
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

#   if ( defined $self->field('password1')->value and defined $self->field('password2')->value
#        and ($self->field('password1')->value ne $self->field('password2')->value) ) {
#     $self->field('password2')->add_error('<span class="glyphicon glyphicon-exclamation-sign"></span>&nbsp;password and its confirmation does not match');
#   }

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

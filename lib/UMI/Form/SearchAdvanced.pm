# -*- mode: cperl -*-
#

package UMI::Form::SearchAdvanced;

use HTML::FormHandler::Moose;
BEGIN { extends 'UMI::Form::LDAP'; with 'Tools'; }

use HTML::FormHandler::Types ('NoSpaces', 'WordChars', 'NotAllDigits', 'Printable' );

has '+item_class' => ( default => 'SearchAdvanced' );
has '+enctype' => ( default => 'multipart/form-data');
has '+action' => ( default => '/searchadvanced/proc' );


has_field 'display_format' => ( type => 'Select',
				label => 'Display Format',
				wrapper_class => [ 'col-md-2' ],
				options => [{ value => 'list', label => 'list', selected => 'on'},
					    { value => 'table', label => 'table'},
					   ],
			      );

has_field 'base_dn' => ( label => 'Base DN',
			 wrapper_class => [ 'col-md-8' ],
			 element_attr => { placeholder => UMI->config->{ldap_crud_db}, },
			 required => 1 );

has_field 'search_scope' => ( type => 'Select',
			      label => 'Search Scope',
			      wrapper_class => [ 'col-md-2' ],
			      options => [{ value => 'sub', label => 'Sub', selected => 'on'},
					  { value => 'children', label => 'Children'},
					  { value => 'one', label => 'One'},
					  { value => 'base', label => 'Base'},
					 ],
			    );

has_field 'search_filter' => ( label => 'Search Filter',
			       wrapper_class => [ 'col-md-12' ],
			       element_attr => { placeholder => '(objectClass=*)' },
			       required => 1 );

has_field 'show_attrs' => ( label => 'Show Attributes',
			    wrapper_class => [ 'col-md-4' ],
			    element_attr => { placeholder => 'cn, uid, mail, authorizedService' });

has_field 'order_by' => ( label => 'Order By',
			  wrapper_class => [ 'col-md-4' ],
			  element_attr => { placeholder => 'cn' },
			);

has_field 'search_results' => ( label => 'Search Results',
				wrapper_class => [ 'col-md-1' ],
				element_attr => { placeholder => '50' },);

has_field 'reset' => ( type => 'Reset',
			wrapper_class => [ 'col-md-1' ],
			element_class => [ 'btn', 'btn-danger', 'btn-block' ],
		        value => 'Reset' );

has_field 'submit' => ( type => 'Submit',
			wrapper_class => [ 'col-md-11' ],
			element_class => [ 'btn', 'btn-success', 'btn-block' ],
			value => 'Submit' );

has_block 'row1' => ( tag => 'fieldset',
		      render_list => [ 'base_dn', 'search_scope', 'display_format' ],
#		      label => '&nbsp;',
		      class => [ 'row' ]
		      );

has_block 'row2' => ( tag => 'fieldset',
		      render_list => [ 'search_filter' ],
		      # label => '<abbr title="Standard LDAP search filter. Example: (&(sn=Smith)(givenName=David))" class="initialism"><span class="glyphicon glyphicon-filter"></span></abbr>',
#		      label => '',
		      class => [ 'row' ]
		    );

has_block 'row3' => ( tag => 'fieldset',
		      render_list => [ 'show_attrs', 'order_by', 'search_results' ],
#		      label => '&nbsp;',
		      class => [ 'row' ]
		    );

has_block 'submitit' => ( tag => 'fieldset',
			  render_list => [ 'reset', 'submit'],
			  label => '&nbsp;',
			  class => [ 'row' ]
			);

sub build_render_list {[ 'row1', 'row2', 'row3', 'submitit' ]}

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

# -*- mode: cperl -*-
#

package UMI::Form::Group;

use HTML::FormHandler::Moose;
BEGIN { extends 'UMI::Form::LDAP'; with 'Tools'; }

use HTML::FormHandler::Types ('NoSpaces', 'WordChars', 'NotAllDigits', 'Printable' );

has '+item_class' => ( default =>'Group' );

has_field 'cn' => ( apply => [ NoSpaces, NotAllDigits, Printable ],
		    label => 'Group Name',
		    element_attr => { placeholder => 'users-allowed-to-fly' },
		    required => 1 );

has_field 'memberUid' => ( type => 'Multiple',
			   label => 'Group Members',
			   # element_class => [ 'multiselect' ],
			   # required => 1,
			 );

sub options_memberUid {
  my $self = shift;
  my ( @memberUid, $return );

  return unless $self->ldap_crud;

  my $ldap_crud = $self->ldap_crud;
  my $mesg = $ldap_crud->search( { base => $ldap_crud->cfg->{base}->{acc_root},
				   scope => 'one',
				   sizelimit => 0,
				   attrs => [ qw{uid givenName sn} ], } );

  if ( ! $mesg->count ) {
    push @{$return->{error}}, $ldap_crud->err($mesg);
  }

  my @memberUid_all = $mesg->sorted('uid');

  foreach ( @memberUid_all ) {
    push @memberUid, { value => $_->get_value('uid'), label => sprintf('%s (%s %s)', $_->get_value('uid'), $_->get_value('givenName'), $_->get_value('sn')), };
  }
  return \@memberUid;
}

has_field 'descr' => ( type => 'TextArea',
		       label => 'Description',
		       element_attr => { placeholder => 'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Suspendisse sed dapibus nulla. Mauris vehicula vehicula ligula ac dapibus. Fusce vehicula a turpis sed. ' },
		       cols => 30, rows => 2);

has_field 'reset' => ( type => 'Reset',
		       wrapper_class => [ 'col-xs-1' ],
		       element_class => [ 'btn', 'btn-danger', 'btn-block' ],
		       element_wrapper_class => [ 'col-xs-12', ],
		       value => 'Reset' );

has_field 'submit' => ( type => 'Submit',
			wrapper_class => [ 'col-xs-11' ],
			element_class => [ 'btn', 'btn-success', 'col-xs-12' ],
			value => 'Submit' );

has_block 'submitit' => ( tag => 'fieldset',
			render_list => [ 'reset', 'submit'],
			label => '&nbsp;',
			class => [ 'row' ]
		      );

sub build_render_list {[ 'cn', 'memberUid', 'descr', 'submitit' ]}

sub html_attributes {
  my ( $self, $field, $type, $attr ) = @_;
  push @{$attr->{class}}, 'required'
    if ( $type eq 'label' && $field->required );
}

sub validate {
  my $self = shift;
  my $ldap_crud = $self->ldap_crud;
  my $mesg =
    $ldap_crud->search({
			scope => 'one',
			filter => '(cn=' .
			$self->utf2lat( $self->field('cn')->value ) . ')',
			base => $ldap_crud->cfg->{base}->{group},
			attrs => [ 'cn' ],
		       });
  $self->field('cn')->add_error('<span class="glyphicon glyphicon-exclamation-sign"></span> Group with name <em>&laquo;' .
				$self->utf2lat( $self->field('cn')->value ) .
				'&raquo;</em> already exists.') if ($mesg->count);
}

######################################################################

no HTML::FormHandler::Moose;

__PACKAGE__->meta->make_immutable;

1;

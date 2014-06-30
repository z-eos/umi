package UMI::Form::LDAP_organization_select;

use HTML::FormHandler::Moose;
extends 'UMI::Form::LDAP';

use HTML::FormHandler::Types ('NoSpaces', 'WordChars', 'NotAllDigits', 'Printable' );

has '+item_class' => ( default =>'LDAP_organization_select' );

has_field 'org' => ( type => 'Select',
		     label => 'Organization',
		     empty_select => '--- new office ---',
		     size => 3,
#		     required => 1 
);

sub options_org {
  my $self = shift;

  return unless $self->ldap_crud;

  my $ldap_crud = $self->ldap_crud;
  my $mesg = $ldap_crud->search({
				 base => 'ou=Organizations,dc=ibs',
				 scope => 'children',
				 filter => 'ou=*',
				 attrs => [ qw(ou physicaldeliveryofficename l) ],
				 sizelimit => 0
				});
  my @entries = $mesg->entries;
  my @orgs; # = ( { value => '0', label => '--- new office ---' } );
  foreach my $entry ( @entries ) {
    push @orgs, {
		 value => $entry->dn,
		 label => sprintf("- %s -, %s @ %s",
				  $entry->get_value ('ou'),
				  $entry->get_value ('physicaldeliveryofficename'),
				  $entry->get_value ('l')
				 )
		};
  }
  return \@orgs;
  $ldap_crud->unbind;
}

has_field 'act' => ( type => 'Select',
#		     wrapper_class => [ 'float-left' ],
		     label => 'Action',
		     options => [{ value => '0', label => 'create', selected => 'on'},
				 { value => '1', label => 'modify',},
				 { value => '2', label => 'delete'},
				],
		     size => 3,
		     required => 1 );

has_field 'submit' => ( type => 'Submit',
			label => '&nbsp;', label_class => [ 'control-label' ],
#			wrapper_class => [ 'pull-right' ],
			element_class => [ 'btn', 'btn-default' ],
			value => 'Submit' );

has_block 'bl-all' => ( tag => 'fieldset',
			class => [ 'form-inline' ],
			render_list => [ 'org', 'act' ],
		      );

has_block 'bl-submit' => ( tag => 'fieldset',
			render_list => [ 'submit' ],
		      );

sub build_render_list {[ 'bl-all', 'bl-submit' ]}

sub validate {
  my $self = shift;

  if ( $self->field('org')->value && ! $self->field('act')->value ) {
    $self->field('org')->add_error('<span class="glyphicon glyphicon-exclamation-sign">' .
				   '</span>&nbsp;You can not create an existent object!');
  } elsif ( ! $self->field('org')->value && $self->field('act')->value > 0 ) {
    $self->field('org')->add_error('<span class="glyphicon glyphicon-exclamation-sign">' .
				   '</span>&nbsp;You can not manipulate an unexistent object!');
  }
}

######################################################################

no HTML::FormHandler::Moose;

__PACKAGE__->meta->make_immutable;

1;

# -*- mode: cperl -*-
#

package UMI::Form::Group;

use HTML::FormHandler::Moose;
BEGIN { extends 'UMI::Form::LDAP'; with 'Tools'; }

use HTML::FormHandler::Types ('NoSpaces', 'WordChars', 'NotAllDigits', 'Printable' );

has '+action' => ( default => '/group' );

sub build_form_element_class { [ qw(formajaxer) ] }

sub html_attributes {
  my ( $self, $field, $type, $attr ) = @_;
  push @{$attr->{class}}, 'required'
    if ( $type eq 'label' && $field->required );
}
has '+item_class' => ( default =>'Group' );

has_field 'branch'
  => ( type                  => 'Select',
       label                 => 'Branch',
       label_class           => [ 'col', 'text-right', 'font-weight-bold', ],
       element_wrapper_class => [ 'input-sm', 'col-10' ],
       element_class         => [ 'input-sm', 'custom-select', ],
       wrapper_class         => [ 'row', 'umi-hide', ],
       options_method        => \&branch,
       # required              => 1,
     );

has_field 'cn'
  => ( apply                 => [ NoSpaces, NotAllDigits, Printable ],
       label                 => 'Group Name',
       label_class           => [ 'col', 'text-right', 'font-weight-bold', ],
       element_wrapper_class => [ 'input-sm', 'col-10', ],
       element_attr          => { placeholder => 'users-allowed-to-fly' },
       wrapper_class         => [ 'row' ],
       required              => 1 );

has_field 'memberUid' 
  => ( type                  => 'Multiple',
       label                 => 'Group Members',
       label_class           => [ 'col', 'text-right', 'font-weight-bold', ],
       element_wrapper_class => [ 'input-sm', 'col-10', ],
       element_class         => [ 'umi-multiselect' ],
       wrapper_class         => [ 'row' ],
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

  my $codepagenorm;
  foreach ( @memberUid_all ) {
    $codepagenorm = sprintf('%s (%s %s)',
			    $_->get_value('uid'),
			    $_->get_value('givenName'),
			    $_->get_value('sn'));
    utf8::decode($codepagenorm);
    push @memberUid, { value => $_->get_value('uid'), label => $codepagenorm, };
  }
  return \@memberUid;
}

has_field 'descr' 
  => ( type                  => 'TextArea',
       label                 => 'Description',
       label_class           => [ 'col', 'text-right', 'font-weight-bold', ],
       element_wrapper_class => [ 'input-sm', 'col-10', ],
       element_attr          => { placeholder => 'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Suspendisse sed dapibus nulla. Mauris vehicula vehicula ligula ac dapibus. Fusce vehicula a turpis sed. ' },
       wrapper_class         => [ 'row' ],
       cols                  => 30, rows => 2);

has_field 'aux_reset'
  => ( type          => 'Reset',
       element_class => [ qw( btn
			      btn-danger
			      btn-block
			      font-weight-bold
			      text-uppercase) ],
       wrapper_class => [ 'col-4' ],
       value         => 'Reset' );

has_field 'aux_submit'
  => ( type          => 'Submit',
       element_class => [ qw( btn
			      btn-success
			      btn-block
			      font-weight-bold
			      text-uppercase) ],
       wrapper_class => [ 'col-8', ],
       value         => 'Submit' );

has_block 'aux_submitit'
  => ( tag => 'fieldset',
       render_list => [ 'aux_reset', 'aux_submit'],
       class => [ 'row', ]
     );

sub build_render_list {[ 'branch', 'cn', 'memberUid', 'descr', 'aux_submitit' ]}


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
  $self->field('cn')->add_error('<span class="fa fa-exclamation-circle"></span> Group with name <em>&laquo;' .
				$self->utf2lat( $self->field('cn')->value ) .
				'&raquo;</em> already exists.') if ($mesg->count);
}

######################################################################

sub branch {
  my $self = shift;
  return unless $self->form->ldap_crud;
  my $branch = $self->form->ldap_crud->
    bld_select({ base   => $self->form->ldap_crud->cfg->{base}->{group},
		 filter => '(ou=*)',
#		 scope  => 'one',
		 attr   => [ 'ou', 'description', ],});

  unshift @{$branch}, { label => "root --- groups in ou=group,dc=umidb", value => "ou=group,dc=umidb"};
  return $branch;
}

no HTML::FormHandler::Moose;

__PACKAGE__->meta->make_immutable;

1;

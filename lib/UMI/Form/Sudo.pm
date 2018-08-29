# -*- mode: cperl -*-
#

package UMI::Form::Sudo;

use HTML::FormHandler::Moose;
BEGIN { extends 'UMI::Form::LDAP';
	with 'Tools', 'HTML::FormHandler::Render::RepeatableJs'; }

use HTML::FormHandler::Types ('NoSpaces', 'WordChars', 'NotAllDigits', 'Printable' );

has '+action' => ( default => '/sudo' );

sub build_form_element_class { [ 'formajaxer', ] }

has '+enctype' => ( default => 'multipart/form-data');

#sub build_form_element_class { [ 'form-horizontal', ] }
# sub build_update_subfields {
#   by_flag => { repeatable => { do_wrapper => 1, do_label => 1, controls_div => 1, } }
# }

sub html_attributes {
  my ( $self, $field, $type, $attr ) = @_;
  push @{$attr->{class}}, 'required'
    if ( $type eq 'label' && $field->required );

  $attr->{class} = ['hfh', 'repinst']
    if $type eq 'wrapper' && $field->has_flag('is_contains');

  return $attr;
}

has_field 'aux_dn_form_to_modify' => ( type => 'Hidden', );

has_field 'cn'
  => ( apply => [ NoSpaces, NotAllDigits, Printable ],
       label => 'Common Name',
       element_attr => { placeholder => '' },
       element_wrapper_class => [ 'input-group', 'input-group-sm', ],
       required => 1 );

has_field 'sudoUser'
  => ( apply => [ NoSpaces, NotAllDigits, Printable ],
       label => 'User Name',
       element_wrapper_class => [ 'input-group', 'input-group-sm', ],
       element_attr => { placeholder => '' }, );

has_field 'sudoHost'
  => ( apply => [ NoSpaces, NotAllDigits, Printable ],
       label => 'Host',
       element_wrapper_class => [ 'input-group', 'input-group-sm', ],
       element_attr => { placeholder => '' }, );

has_field 'sudoRunAsUser'
  => ( apply => [ NoSpaces, NotAllDigits, Printable ],
       label => 'Run As User',
       element_wrapper_class => [ 'input-group', 'input-group-sm', ],
       element_attr => { placeholder => '' }, );

has_field 'sudoRunAsGroup'
  => ( apply => [ NoSpaces, NotAllDigits, Printable ],
       label => 'Run As Group',
       element_wrapper_class => [ 'input-group', 'input-group-sm', ],
       element_attr => { placeholder => '' }, );


has_field 'aux_delim_com'
  => ( type => 'Display',
       html => '<div class="form-group h4">New Command</div>',
     );

has_field 'aux_add_com'
  => ( type => 'AddElement',
       repeatable => 'com',
       value => 'Add new command',
       element_class => [ 'btn-success', 'btn-sm', ],
     );

has_field 'com'
  => ( type => 'Repeatable',
       setup_for_js => 1,
       do_wrapper => 1,
       element_class => [ 'btn-success', ],
       element_wrapper_class => [ 'controls', ],
     );

has_field 'com.sudoCommand'
  => ( apply => [ NoSpaces, NotAllDigits, Printable ],
       do_label => 0,
       label => 'New Command',
       element_attr => { placeholder => '',
			 title => 'command',
			 'data-name' => 'command',
			 'data-group' => 'com', },
       element_wrapper_class => [ 'input-group', 'input-group-sm', ],
       wrapper_class => [ 'col-xs-10', 'col-lg-10', ],
     );

has_field 'com.remove'
  => ( type => 'RmElement',
       value => 'Remove this command',
       element_class => [ 'btn-danger', 'btn-sm', ],
       wrapper_class => [ 'col-xs-2', 'col-lg-2', ],
     );


has_field 'aux_delim_opt'
  => ( type => 'Display',
       html => '<div class="form-group h4">New Option</div>',
     );

has_field 'aux_add_opt'
  => ( type => 'AddElement',
       repeatable => 'opt',
       value => 'Add new option',
       element_class => [ 'btn-success', 'btn-sm', ],
     );

has_field 'opt'
  => ( type => 'Repeatable',
       setup_for_js => 1,
       do_wrapper => 1,
       element_class => [ 'btn-success', 'btn-sm', ],
       element_wrapper_class => [ 'controls', ],
     );

has_field 'opt.sudoOption'
  => ( apply => [ NoSpaces, NotAllDigits, Printable ],
       do_label => 0,
       label => 'New Option',
       element_attr => { placeholder => '',
			 title => 'command', },
       element_wrapper_class => [ 'input-group', 'input-group-sm', ],
       wrapper_class => [ 'col-xs-10', 'col-lg-10', ],
     );

has_field 'opt.remove'
  => ( type => 'RmElement',
       value => 'Remove this option',
       element_class => [ 'btn-danger', 'btn-sm', ],
       wrapper_class => [ 'col-xs-2', 'col-lg-2', ],
     );


has_field 'description' 
  => ( type => 'TextArea',
       label => 'Description',
       element_attr => { placeholder => 'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Suspendisse sed dapibus nulla. Mauris vehicula vehicula ligula ac dapibus. Fusce vehicula a turpis sed. ' },
       element_wrapper_class => [ 'input-group', 'input-group-sm', ],
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


######################################################################

no HTML::FormHandler::Moose;

__PACKAGE__->meta->make_immutable;

1;

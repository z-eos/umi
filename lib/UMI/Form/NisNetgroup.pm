# -*- mode: cperl -*-
#

package UMI::Form::NisNetgroup;

use HTML::FormHandler::Moose;
BEGIN { extends 'UMI::Form::LDAP';
	with 'Tools', 'HTML::FormHandler::Render::RepeatableJs'; }

use HTML::FormHandler::Types ('NoSpaces', 'WordChars', 'NotAllDigits', 'Printable' );

has '+action' => ( default => '/nisnetgroup' );

sub build_form_element_class { [ qw(formajaxer) ] }

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

has_field 'cn' => ( apply => [ NoSpaces, NotAllDigits, Printable ],
		    label => 'Name',
		    # label_class => [ 'h2', ],
		    element_attr => { placeholder => 'users-allowed-to-fly' },
		    # wrapper_class => [ 'col-xs-11', 'col-lg-2', ],
		    required => 1 );


has_field 'description' => ( type => 'TextArea',
		       label => 'Description',
		       element_attr => { placeholder => 'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Suspendisse sed dapibus nulla. Mauris vehicula vehicula ligula ac dapibus. Fusce vehicula a turpis sed. ' },
		       cols => 30, rows => 2);


has_field 'aux_delim_triple'
  => ( type => 'Display',
       html => '<br><h4>Host-User-Domain Triple/s</h4>',
     );

has_field 'aux_add_triple'
  => ( type => 'AddElement',
       repeatable => 'triple',
       value => 'Add new triple',
       element_class => [ 'btn-success', ],
       # wrapper_class => [ 'col-xs-12', 'col-lg-offset-10', 'col-lg-2', ],
     );

has_field 'triple'
  => ( type => 'Repeatable',
       setup_for_js => 1,
       do_wrapper => 1,
       # tags => { controls_div => 1 },
       element_class => [ 'btn-success', ],
       element_wrapper_class => [ 'controls', ],
       # wrapper_attr => { class => [ 'no-has-error', ], },
       # wrap_repeatable_element_method => \&wrap_triple_elements,
     );
# sub wrap_triple_elements {
#   my ( $self, $input, $subfield ) = @_;
#   my $output = sprintf('%s%s%s', qq{\n<div class="controls">},
# 		       $input,
# 		       qq{</div>});
# }
# sub wrap_triple_elements {
#   my ( $self, $input, $subfield ) = @_;
#   my $output = sprintf('%s%s%s', ! $subfield ? qq{\n<div class="duplicate">} : qq{\n<div class="duplicated">},
# 		       $input,
# 		       qq{</div>});
# }

has_field 'triple.host'
  => ( apply => [ NoSpaces, NotAllDigits, Printable ],
       do_label => 0,
       label => 'Host',
       element_attr => { placeholder => 'host01',
			 title => 'host',
			 'data-name' => 'host',
			 'data-group' => 'triple', },
       wrapper_class => [ 'col-xs-11', 'col-lg-3', ],
     );

has_field 'triple.user'
  => ( apply => [ NoSpaces, NotAllDigits, Printable ],
       do_label => 0,
       label => 'User',
       element_attr => { placeholder => 'user06',
			 title => 'user',
			 'data-name' => 'user',
			 'data-group' => 'triple', },
       wrapper_class => [ 'col-xs-11', 'col-lg-3', ],
     );

has_field 'triple.domain'
  => ( apply => [ NoSpaces, NotAllDigits, Printable ],
       do_label => 0,
       label => 'Domain',
       element_attr => { placeholder => 'foo.bar',
			 title => 'domain',
			 'data-name' => 'domain',
			 'data-group' => 'triple', },
       wrapper_class => [ 'col-xs-11', 'col-lg-3', ],
     );

has_field 'triple.remove'
  => ( type => 'RmElement',
       value => 'Remove this triple',
       element_class => [ 'btn-danger', ],
       wrapper_class => [ 'col-xs-11', 'col-lg-3', ],
     );

has_block 'nistriple'
  => ( tag => 'fieldset',
       label => '<a href="#" class="btn btn-success btn-sm" data-duplicate="duplicate" title="Duplicate this section">' .
       '<span class="fa fa-plus-circle fa-lg"></span></a>&nbsp;' .
       'NIS Netgroup Triple&nbsp;<small class="text-muted"><em>(host,user,domain)</em></small>',
       render_list => [ 'triple', ],
       # class => [ 'h6', ],
       # attr => { id => 'auth',
       # 		 'aria-labelledby' => "auth-tab",
       # 	 role => "tabpanel", },
);

has_field 'aux_delim_memberNisNetgroup'
  => ( type => 'Display',
       html => '<br><br><br><br><br><br><h4>NIS Sub Groups</h4>',
     );

has_field 'memberNisNetgroup' => ( type => 'Multiple',
			   label => 'NisNetgroup Subgroups',
			   element_class => [ 'umi-multiselect' ],
			   # required => 1,
			 );

sub options_memberNisNetgroup {
  my $self = shift;
  my ( @memberNisNetgroup, $return );

  return unless $self->ldap_crud;

  my $ldap_crud = $self->ldap_crud;
  my $mesg = $ldap_crud->search( { base => $ldap_crud->cfg->{base}->{netgroup},
				   scope => 'one',
				   sizelimit => 0,
				   attrs => [ qw{cn} ], } );

  push @{$return->{error}}, $ldap_crud->err($mesg) if ! $mesg->count;

  my @memberNisNetgroup_all = $mesg->sorted('cn');

  foreach ( @memberNisNetgroup_all ) {
    push @memberNisNetgroup, { value => $_->get_value('cn'), label => $_->get_value('cn'), };
  }
  return \@memberNisNetgroup;
}


has_field 'aux_reset' => ( type => 'Reset',
			   wrapper_class => [ 'col-xs-4' ],
			   element_class => [ 'btn', 'btn-danger', 'btn-block' ],
			   element_wrapper_class => [ 'col-xs-12', ],
			   value => 'Reset' );

has_field 'aux_submit' => ( type => 'Submit',
			    wrapper_class => [ 'col-xs-8' ],
			    element_class => [ 'btn', 'btn-success', 'col-xs-12' ],
			    value => 'Submit' );

sub validate {
  my $self = shift;
  # my $ldap_crud = $self->ldap_crud;
  # my $mesg =
  #   $ldap_crud->search({
  # 			scope => 'one',
  # 			filter => '(cn=' .
  # 			$self->utf2lat( $self->field('cn')->value ) . ')',
  # 			base => $ldap_crud->cfg->{base}->{group},
  # 			attrs => [ 'cn' ],
  # 		       });
  # $self->field('cn')->add_error('<span class="glyphicon glyphicon-exclamation-sign"></span> NisNetgroup with name <em>&laquo;' .
  # 				$self->utf2lat( $self->field('cn')->value ) .
#				'&raquo;</em> already exists.') if ($mesg->count);
}

######################################################################

no HTML::FormHandler::Moose;

__PACKAGE__->meta->make_immutable;

1;

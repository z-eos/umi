# -*- cperl -*-
#

package UMI::Form::GitACL;

use HTML::FormHandler::Moose;
extends 'UMI::Form::LDAP';

use HTML::FormHandler::Types ('NoSpaces', 'WordChars', 'NotAllDigits', 'Printable', 'CIDR', 'PositiveNum' );

sub html_attributes {
  my ( $self, $field, $type, $attr ) = @_;
  push @{$attr->{'class'}}, 'required'
    if $type eq 'label' && $field->required;
}

# bl-0 ----------------------------------------------------------------------

has_field 'gitAclProject' => (apply => [ NoSpaces ],
			      label => 'Project Name',
			      label_attr => { title => 'gitAclProject field description' },
			      wrapper_class => 'col-md-3',
			      element_attr => { placeholder => 'Horns & Hooves LLC' },
			      required => 1,
			     );

has_field 'gitAclOrder' => (apply => [ NoSpaces, PositiveNum ],
			      label => 'Order',
			      label_attr => { title => 'gitAcl order if many' },
			      wrapper_class => 'col-md-1',
			      element_attr => { placeholder => '321' },
			     );

has_field 'gitAclOp' => ( type => 'Multiple',
			  label => 'Operation/s',
			  wrapper_class => 'col-md-2',
			  options => [
				      {
				       value => 'C', label => 'CREATE', selected => 'on' },
				      {
				       value => 'R', label => 'READ', selected => 'on' },
				      {
				       value => 'U', label => 'UPDATE', selected => 'on' },
				      {
				       value => 'D', label => 'DELETE', selected => 'on' },
				     ],
			  size => 4,
			  required => 1,
			);

has_field 'gitAclVerb' => ( type => 'Select',
			    label => 'Verb',
			    wrapper_class => 'col-md-2',
			    options => [{ value => 'allow', label => 'allow'},
					{ value => 'deny', label => 'deny'},
				       ],
			    required => 1 );

has_field 'gitAclRef' => (apply => [ NoSpaces ],
			  label => 'Reference',
			  label_attr => { title => 'gitAclRef field description' },
			  wrapper_class => 'col-md-3',
			  element_attr => { placeholder => 'Horns/Hooves/Super/Pooper' },
			  # required => 1,
			 );

# bl-1 ----------------------------------------------------------------------

has_field 'gitAclUser_user' => ( type => 'Select',
				 label => 'User',
				 # label_class => [ qw(requiredwhen control-label) ],
				 label_class => [ qw( control-label ) ],
				 label_attr => { title => 'gitAclUser field description' },
				 wrapper_class => 'col-md-2',
				 required_when => { gitAclUser_group => 0 },
			       );

sub options_gitAclUser_user {
  my $self = shift;

  return unless $self->ldap_crud;

  my $ldap_crud = $self->ldap_crud;
  my $mesg = $ldap_crud->search(
				{
				 base => 'ou=People,dc=umidb',
				 scope => 'one',
				 filter => 'uid=*',
				 attrs => [ qw(uid givenName sn) ],
				 sizelimit => 0
				}
			       );
  my @users = ( { value => '0', label => '--- choose user ---' } );
  my @entries = $mesg->sorted('uid');
  foreach my $entry ( @entries ) {
    push @users, {
		 value => $entry->get_value ('uid'),
		 label => sprintf("%s, %10s %s",
				  $entry->get_value ('uid'),
				  $entry->get_value ('givenName'),
				  $entry->get_value ('sn')
				 )
		};
  }
  return \@users;

  # $ldap_crud->unbind;
}

has_field 'gitAclUser_group' => ( type => 'Select',
				  label => 'Group',
				  # label_class => [ 'requiredwhen' ],
				  label_attr => { title => 'gitAclUser group' },
				  wrapper_class => 'col-md-2',
				  required_when => { gitAclUser_user => 0 },
				);

sub options_gitAclUser_group {
  my $self = shift;

  return unless $self->ldap_crud;

  my $ldap_crud = $self->ldap_crud;
  my $mesg = $ldap_crud->search(
				{
				 base => 'ou=group,dc=umidb',
				 scope => 'one',
				 filter => 'cn=*',
				 attrs => [ qw(cn description) ],
				 sizelimit => 0
				}
			       );
  my @groups = ( { value => '0', label => '--- choose group ---' } );
  my @entries = $mesg->sorted('cn');
  foreach my $entry ( @entries ) {
    push @groups, {
		 value => '%' . $entry->get_value ('cn'),
		 label => sprintf("%s, %s",
				  $entry->get_value ('cn'),
				  $entry->get_value ('description')
				 )
		};
  }
  return \@groups;

  # $ldap_crud->unbind;
}

has_field 'gitAclUser_cidr' => (apply => [ CIDR ],
			  label => 'CIDR',
			  label_attr => { title => 'gitAclUser CIDR' },
			  wrapper_class => 'col-md-2',
			  element_attr => { placeholder => '172.16.157.193/32' },
			 );

# bl-2 ----------------------------------------------------------------------

has_field 'aux_reset' => ( type => 'Reset',
			   wrapper_class => [ 'col-md-1' ],
			   element_class => [ 'btn', 'btn-default', 'btn-block', ],
			   value => 'Reset' );

has_field 'aux_submit' => (
			   type => 'Submit',
			   wrapper_class => [ 'pull-right', 'col-md-11'],
			   element_class => [ 'btn', 'btn-default', 'btn-block', ],
			   # label_no_filter => 1,
			   # value => '<span class="glyphicon glyphicon-plus-sign"></span> Submit',
			   value => 'Submit'
			  );

# FIELDSETs -----------------------------------------------------------------

has_block 'bl-0' => ( tag => 'fieldset',
		      render_list => [ 'gitAclProject',
				       'gitAclOrder',
				       'gitAclOp',
				       'gitAclVerb',
				       'gitAclRef' ],
		      label => '<abbr title="gitAcl general options" class="initialism"><span class="glyphicon glyphicon-briefcase"></span></abbr>',
		      class => [ 'row', ]
		    );

has_block 'bl-1' => ( tag => 'fieldset',
		      render_list => [ 'gitAclUser_user', 'gitAclUser_group', 'gitAclUser_cidr' ],
		      label => '<abbr title="gitAclUser notation: <user | group> ~[@CIDR~]" class="initialism"><span class="glyphicon glyphicon-user"></span></abbr>',
		      class => [ 'row', ]
		    );

has_block 'bl-2' => ( tag => 'fieldset',
		      render_list => [ 'aux_reset', 'aux_submit'],
		      # label => '&nbsp;',
		      class => [ 'row', ]
		    );

sub build_render_list {[
			'bl-0',
			'bl-1',
			'bl-2',
		       ]}

sub validate {
  my $self = shift;

  # if ( $self->field('gitAclUser_user')->value eq "0" &&
  #      $self->field('gitAclUser_group')->value eq "0" ) {
  #   $self->field('gitAclUser_user')->add_error('<span class="glyphicon glyphicon-exclamation-sign"></span>&nbsp;Either User or Group has to be defined!');
  #   $self->field('gitAclUser_group')->add_error('<span class="glyphicon glyphicon-exclamation-sign"></span>&nbsp;Either Group or User has to be defined!');
  # }


  # my $ldap_crud = $self->ldap_crud;
  # my $ldap = $ldap_crud->umi_bind({
  # 				   dn => 'uid=' . $self->uid . ',ou=people,dc=ibs',
  # 				   password => $self->pwd,
  # 				  });
  # my $mesg =
  #   $ldap_crud->umi_search( $ldap,
  # 			    {
  # 			     ldap_search_scope => 'sub',
  # 			     ldap_search_filter => '(&(givenname=' . 
  # 			     $self->field('fname')->value . ')(sn=' .
  # 			     $self->field('lname')->value . ')(uid=*-' .
  # 			     $self->field('login')->value . '))',
  # 			     ldap_search_base => 'ou=People,dc=ibs',
  # 			      ldap_search_attrs => [ 'uid' ],
  # 			    }
  # 			  );

  # if ($mesg->count) {
  #   my $err = '<span class="glyphicon glyphicon-exclamation-sign"></span> Fname+Lname+Login exists';
  #   $self->field('fname')->add_error($err);
  #   $self->field('lname')->add_error($err);
  #   $self->field('login')->add_error($err);

  #   $err = '<div class="alert alert-danger">' .
  #     '<span style="font-size: 140%" class="icon_error-oct" aria-hidden="true"></span>' .
  # 	'&nbsp;Account with the same fields &laquo;<strong>First Name&raquo;</strong>,' .
  # 	  ' &laquo;<strong>Last Name&raquo;</strong> and &laquo;<strong>Login&raquo;</strong>' .
  # 	    ' already exists!<br>Consider one of:<ul>' .
  # 	      '<li>change Login in case you need another account for the same person</li>' .
  # 		'<li>add service account to the existent one</li></ul></div>';
  #   my $error = $self->form->success_message;
  #   $self->form->error_message('');
  #   $self->form->add_form_error($error . $err);
  # }
  # $ldap->unbind;
}

# sub update_model {
#     use Data::Printer colored => 1, caller_info => 1;
#     p(@_);

#     my $self = shift;

#     my $item = undef;
#     if ( ! $self->item ) {
#       warn '$$$$$$$$$$$$$$$$$$$$$$$$$$$$ add $$$$$$$$$$$$$$$$$$$$$$$$$$$$' . "\n";
#       $self->add_form_error('<span class="glyphicon glyphicon-exclamation-sign">' .
# 			    '</span>&nbsp;first if');
#       $item = $self->ldap_crud
# 	->obj_add(
# 		  {
# 		   'type' => 'org',
# 		   'params' => $self->{'params'},
# 		  }
# 		 );
#     } elsif ( defined $self->{'item'}->{'act'} ) {
#       $item = $self->item;
#       warn '$$$$$$$$$$$$$$$$$$$$$$$$$$$$ modify $$$$$$$$$$$$$$$$$$$$$$$$$$$$' . "\n";
#       # $self->add_form_error('middle elsif');
#       # item => $c->model('LDAP_CRUD')
#       # 	->obj_mod(
#       # 		  {
#       # 		   'type' => 'org',
#       # 		   'params' => $params,
#       # 		  }
#       # 		 ),

#     } else  {
#       warn '$$$$$$$$$$$$$$$$$$$$$$$$$$$$ other $$$$$$$$$$$$$$$$$$$$$$$$$$$$' . "\n";

#       $item = $self->item;
#       $self->add_form_error('Final else');
#     }

#     return unless $item;

#     $self->add_form_error( $item->{'message'} ) if $item->{'message'};

#     # foreach my $field ( $self->all_fields ) {
#     #     my $name = $field->name;
#     #     next unless $item->can($name);
#     #     $item->$name( $field->value );
#     # }
# }

######################################################################

no HTML::FormHandler::Moose;

__PACKAGE__->meta->make_immutable;

1;

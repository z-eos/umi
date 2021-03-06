# -*- cperl -*-
#

package UMI::Form::GitACL;

use HTML::FormHandler::Moose;
extends 'UMI::Form::LDAP';

use HTML::FormHandler::Types ('NoSpaces', 'WordChars', 'NotAllDigits', 'Printable', 'CIDR', 'PositiveNum' );

has '+action' => ( default => '/gitacl' );

sub build_form_element_class { [ 'form-horizontal', 'formajaxer', ] }

sub html_attributes {
  my ( $self, $field, $type, $attr ) = @_;
  push @{$attr->{'class'}}, 'required'
    if $type eq 'label' && $field->required;
}

has_field 'aux_dn_form_to_modify' => ( type => 'Hidden', );

has_field 'gitAclProject'
  => ( apply                 => [ NoSpaces ],
       label                 => 'Project Name',
       label_class           => [ 'col-2', 'text-right', 'font-weight-bold', ],
       label_attr => { title => 'gitAclProject field description' },
       element_wrapper_class => [ 'input-sm', 'col-10', ],
       element_attr          => { placeholder => 'Horns & Hooves LLC' },
       wrapper_class         => [ 'row', ],
       required              => 1,
     );

has_field 'gitAclOrder'
  => ( apply                 => [ NoSpaces, PositiveNum ],
       label                 => 'Order',
       label_class           => [ 'col-2', 'text-right', 'font-weight-bold', ],
       label_attr            => { title => 'gitAcl order if many' },
       element_wrapper_class => [ 'input-sm', 'col-10', ],
       element_attr          => { placeholder => '321' },
       wrapper_class         => [ 'row', ],
     );

has_field 'gitAclOp' 
  => ( type                  => 'Multiple',
       label                 => 'Operation/s',
       label_class           => [ 'col-2', 'text-right', 'font-weight-bold', ],
       element_wrapper_class => [ 'input-sm', 'col-10', ],
       element_attr          => { 'data-ico-l'       => 'fa-terminal',
				  'data-ico-r'       => 'fa-terminal',
				  'data-placeholder' => 'operation/s', },
       element_class         => [ 'umi-multiselect', ],
       options               => [ { value => 'C', label => 'CREATE', selected => 'on' },
				  { value => 'R', label => 'READ',   selected => 'on' },
				  { value => 'U', label => 'UPDATE', selected => 'on' },
				  { value => 'D', label => 'DELETE', selected => 'on' }, ],
       size                  => 4,
       required              => 1,
       wrapper_class         => [ 'row', ],
     );

has_field 'gitAclVerb'
  => ( type                  => 'Select',
       label                 => 'Verb',
       label_class           => [ 'col-2', 'text-right', 'font-weight-bold', ],
       element_wrapper_class => [ 'input-sm', 'col-10', ],
       element_class         => [ 'custom-select', ],
       options               => [ { value => 'allow', label => 'allow'},
				  { value => 'deny', label => 'deny'}, ],
       wrapper_class         => [ 'row', ],
       required              => 1 );

has_field 'gitAclRef'
  => ( apply                 => [ NoSpaces ],
       label                 => 'Reference',
       label_class           => [ 'col-2', 'text-right', 'font-weight-bold', ],
       label_attr            => { title => 'gitAclRef field description' },
       element_wrapper_class => [ 'input-sm', 'col-10', ],
       element_attr          => { placeholder => 'Horns/Hooves/Super/Pooper' },
       wrapper_class         => [ 'row', ],
       # required              => 1,
     );

has_field 'gitAclUser_user'
  => ( type                  => 'Select',
       label                 => 'User',
       label_class           => [ 'col-2', 'text-right', 'font-weight-bold', ],
       label_attr            => { title => 'gitAclUser field description' },
       element_wrapper_class => [ 'input-sm', 'col-10', ],
       element_class         => [ 'custom-select', ],
       required_when         => { gitAclUser_group => 0 },
       wrapper_class         => [ 'row', ],
     );

sub options_gitAclUser_user {
  my $self = shift;

  return unless $self->ldap_crud;

  my $ldap_crud = $self->ldap_crud;
  my $mesg = $ldap_crud->search({
				 base      => $ldap_crud->cfg->{base}->{acc_root},
				 scope     => 'one',
				 filter    => 'uid=*',
				 attrs     => [ qw(uid givenName sn) ],
				 sizelimit => 0
				});
  my @users = ( { value => '0', label => '--- choose user ---' } );
  my @entries = $mesg->sorted('uid');
  my $label;
  foreach my $entry ( @entries ) {
    $label = sprintf("%s, %10s %s",
		     $entry->get_value ('uid'),
		     $entry->get_value ('givenName'),
		     $entry->get_value ('sn'));
    utf8::decode( $label );

    push @users, {
		 value => $entry->get_value ('uid'),
		 label => $label
		};
  }
  return \@users;
}

has_field 'gitAclUser_group'
  => ( type                  => 'Select',
       label                 => 'Group',
       label_class           => [ 'col-2', 'text-right', 'font-weight-bold', ],
       label_attr            => { title => 'gitAclUser group' },
       element_wrapper_class => [ 'input-sm', 'col-10' ],
       element_class         => [ 'custom-select', ],
       required_when         => { gitAclUser_user => 0 },
       wrapper_class         => [ 'row', ],
     );

sub options_gitAclUser_group {
  my $self = shift;

  return unless $self->ldap_crud;

  my $ldap_crud = $self->ldap_crud;
  my $mesg = $ldap_crud->search({ base      => $ldap_crud->cfg->{base}->{group},
				  scope     => 'one',
				  filter    => 'cn=*',
				  attrs     => [ qw(cn description) ],
				  sizelimit => 0 });
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

has_field 'gitAclUser_cidr'
  => ( apply                 => [ CIDR ],
       label                 => 'CIDR',
       label_class           => [ 'col-2', 'text-right', 'font-weight-bold', ],
       label_attr            => { title => 'gitAclUser CIDR' },
       element_wrapper_class => [ 'input-sm', 'col-10' ],
       element_attr          => { placeholder => '172.16.157.193/32' },
       wrapper_class         => [ 'row', ],
     );

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

sub build_render_list {[ qw( aux_dn_form_to_modify
			     gitAclProject
			     gitAclOrder
			     gitAclOp
			     gitAclVerb
			     gitAclRef
			     gitAclUser_user
			     gitAclUser_group
			     gitAclUser_cidr
                             aux_submitit ) ]}

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

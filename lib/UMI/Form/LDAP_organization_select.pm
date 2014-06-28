package UMI::Form::LDAP_organization_select;

use HTML::FormHandler::Moose;
extends 'HTML::FormHandler';

use HTML::FormHandler::Widget::Theme::Bootstrap3;
use HTML::FormHandler::Widget::Wrapper::Bootstrap3;

has '+item_class' => ( default =>'LDAP_organization_select' );

has '+widget_wrapper' => ( default => 'Bootstrap3');

has 'ldap_crud' => (is => 'rw');
has 'uid' => (is => 'rw');
has 'pwd' => (is => 'rw');

has_field 'org' => ( type => 'Select',
		     label => 'Organization',
		     size => 3,
		     required => 1 );

sub options_org {
  my $self = shift;

  return unless $self->ldap_crud;

  my $ldap_crud = $self->ldap_crud;
  my $ldap = $ldap_crud->umi_bind({
  				   dn => 'uid=' . $self->uid . ',ou=people,dc=ibs',
  				   password => $self->pwd,
  				  });
  my $mesg = $ldap_crud->umi_search( $ldap,
				     {
				      base => 'ou=Organizations,dc=ibs',
				      scope => 'children',
				      filter => 'ou=*',
				      attrs => [ qw(ou physicaldeliveryofficename l) ],
				      sizelimit => 0
				     }
				   );
  my @entries = $mesg->entries;
  push my @orgs, { value => '0', label => '--- new office ---' };
  foreach my $entry ( @entries ) {
    push @orgs, {
		 value => $entry->dn, 
		 label => sprintf("- %s -, %s @ %s",
				  $entry->get_value ('ou'),
				  $entry->get_value ('physicaldeliveryofficename'),
				  $entry->get_value ('l')
				 )
		};
		 # label => $entry->get_value ('physicaldeliveryofficename') .
		 #  ' ( ' . $entry->get_value ('ou') . ' @ ' . $entry->get_value ('l') . ' )' };
  }

  return \@orgs;

  $ldap->unbind;

  # return $ldap_crud->umi_existent_o( $ldap );
  # $ldap->unbind;
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

  if ( $self->field('org')->value and not $self->field('act')->value ) {
    $self->field('org')->add_error('<span class="glyphicon glyphicon-exclamation-sign">' .
				   '</span>&nbsp;You can not create an existent object!');
  } elsif ( not $self->field('org')->value and $self->field('act')->value ) {
    $self->field('org')->add_error('<span class="glyphicon glyphicon-exclamation-sign">' .
				   '</span>&nbsp;You can not manipulate an unexistent object!');
  }

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

######################################################################

no HTML::FormHandler::Moose;

__PACKAGE__->meta->make_immutable;

1;

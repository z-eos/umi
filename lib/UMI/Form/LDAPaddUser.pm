package UMI::Form::LDAPaddUser;

use HTML::FormHandler::Moose;
BEGIN { extends 'HTML::FormHandler'; with 'Tools'; }

use HTML::FormHandler::Types ('NoSpaces', 'WordChars', 'NotAllDigits', 'Printable' );
use HTML::FormHandler::Widget::Theme::Bootstrap3;
use HTML::FormHandler::Widget::Wrapper::Bootstrap3;

has '+item_class' => ( default =>'LDAPaddUser' );
has '+widget_wrapper' => ( default => 'Bootstrap3');
has '+enctype' => ( default => 'multipart/form-data');
#has '+is_html5' => ( default => 1 );

has 'ldap_crud' => (is => 'rw');

has_field 'givenname' => ( apply => [ NoSpaces ],
			   label => 'First Name',
			   element_attr => { placeholder => 'John' },
			   required => 1 );

has_field 'sn' => ( apply => [ NoSpaces ],
		       label => 'Last name',
		       element_attr => { placeholder => 'Doe' },
		       required => 1 );

has_field 'avatar' => ( type => 'Upload',
			label => 'Avatar',
			element_class => [ 'btn', 'btn-default', 'btn-sm' ],
			max_size => '20000' );

has_field 'telephonenumber' => ( apply => [ NoSpaces ],
		       label => 'SIP/Cell',
		       element_attr => { placeholder => '+38062xxxxxxx' });

has_field 'title' => ( label => 'Position',
			  element_attr => { placeholder => 'manager' },
			  required => 1 );

has_field 'office' => ( type => 'Select',
			label => 'Office', label_class => [ '' ],
			required => 1 );

sub options_office {
  my $self = shift;

  return unless $self->ldap_crud;

  my $ldap_crud = $self->ldap_crud;
  my $mesg = $ldap_crud->search(
				{
				 base => 'ou=Organizations,dc=ibs',
				 scope => 'children',
				 filter => 'ou=*',
				 attrs => [ qw(ou physicaldeliveryofficename l) ],
				 sizelimit => 0
				}
			       );
  my @orgs = ( { value => '0', label => '--- choose office ---' } );
  my @entries = $mesg->entries;
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

has_field 'login' => ( apply => [ NoSpaces, NotAllDigits, Printable ],
		       label => 'Login',
		       element_attr => { placeholder => 'john.doe' },
		       required => 1 );

has_field 'password1' => ( type => 'Password',
			   minlength => 7, maxlength => 16,
			   label => '',
			   ne_username => 'login',
			   apply => [ NoSpaces, NotAllDigits, Printable ],
			   element_attr => 
			   { placeholder => 'Password',
			     title => 'leave empty password fields to autogenerate password',
			   },
			 );

has_field 'password2' => ( type => 'Password',
			   minlength => 7, maxlength => 16,
			   label => '',
			   ne_username => 'login',
			   apply => [ NoSpaces, NotAllDigits, Printable ],
			   element_attr => 
			   { placeholder => 'Confirm Password',
			     title => 'leave empty password fields to autogenerate password',
			   },
			 );

has_field 'pwdcomment' => ( type => 'Display',
			    html => '<p class="text-warning"><small><em>' .
			    'leave empty password fields to autogenerate password</em></small></p>',
			    element_class => 'text-warning'
			  );

has_field 'descr' => ( type => 'TextArea',
		       label => 'Description',
		       element_attr => { placeholder => 'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Suspendisse sed dapibus nulla. Mauris vehicula vehicula ligula ac dapibus. Fusce vehicula a turpis sed. ' },
		       cols => 30, rows => 2);

has_field 'associateddomain' => ( type => 'Select',
		      label => 'Domain Name',
		      options => [{ value => 'ibs.dn.ua', label => 'ibs.dn.ua'},
				  { value => 'prozora-kraina.org', label => 'prozora-kraina.org'},
				  { value => 'new-ukraine.org', label => 'new-ukraine.org'},
				  { value => 'falcon-ukraine.com', label => 'falcon-ukraine.com'},
				  { value => 'logistic-ukr.com', label => 'logistic-ukr.com'},
				  { value => 'zik.ua', label => 'zik.ua'},
				  { value => 'greenbank.com.ua', label => 'greenbank.com.ua'},
				 ],
		      size => 3,
		      required => 1 );

has_field 'service' => ( type => 'Multiple',
			 label => 'Service',
			 options => [{ value => 'mail', label => 'Email', selected => 'on'},
				     { value => 'xmpp', label => 'Jabber', selected => 'on'},
				     { value => '802.1x-cable', label => 'LAN RG45'},
				     { value => '802.1x-wifi', label => 'WiFi'},
				    ],
			 size => 3,
			 required => 1 );


has_field 'reset' => ( type => 'Reset',
			element_class => [ 'btn', 'btn-default', 'pull-left' ],
		        value => 'Reset' );

has_field 'submit' => ( type => 'Submit',
			wrapper_class => [ 'pull-right' ],
			element_class => [ 'btn', 'btn-default', 'pull-right' ],
			value => 'Create Account' );



has_block 'person' => ( tag => 'fieldset',
			render_list => [ 'givenname', 'sn', 'avatar', 'telephonenumber'],
			label => '<span class="icon_id" aria-hidden="true"></span>',
			label_class => [ 'pull-left' ],
			class => [ 'form-inline' ]
		      );

has_block 'job' => ( tag => 'fieldset',
		     render_list => [ 'title', 'office' ],
		     label => '<span class="icon_building" aria-hidden="true"></span>',
		     label_class => [ 'pull-left' ],
		     class => [ 'form-inline' ]
		   );

has_block 'account' => ( tag => 'fieldset',
			 render_list => [ 'login', 'password1', 'password2', 'pwdcomment' ],
			 label => '<span class="icon_key_alt" aria-hidden="true"></span>',
			 label_class => [ 'pull-left' ],
			 class => [ 'form-inline' ],
		       );

has_block 'services' => ( tag => 'fieldset',
			  render_list => [ 'associateddomain', 'service', 'descr' ],
			  label => '<span class="icon_cloud_alt" aria-hidden="true"></span>',
			  # label => '<span class="icon_menu-square_alt2" aria-hidden="true"></span>',
			  label_class => [ 'pull-left' ],
			  class => [ 'form-inline' ]
			);

has_block 'submitit' => ( tag => 'fieldset',
			render_list => [ 'reset', 'submit'],
			label => '&nbsp;',
			class => [ 'form-inline' ]
		      );

sub build_render_list {[ 'person', 'account', 'services', 'job', 'submitit' ]}

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

  if ( defined $self->field('password1')->value and defined $self->field('password2')->value
       and ($self->field('password1')->value ne $self->field('password2')->value) ) {
    $self->field('password2')->add_error('<span class="glyphicon glyphicon-exclamation-sign"></span>&nbsp;password and its confirmation does not match');
  }

if ( not $self->field('office')->value ) {
    $self->field('office')->add_error('<span class="glyphicon glyphicon-exclamation-sign"></span>&nbsp;office is mandatory!');
  }


  my $ldap_crud = $self->ldap_crud;
  my $mesg =
    $ldap_crud->search(
		       {
			scope => 'one',
			filter => '(&(givenname=' .
			$self->cyr2lat({ to_translate => $self->field('givenname')->value }) . ')(sn=' .
			$self->cyr2lat({ to_translate => $self->field('sn')->value }) . ')(uid=*-' .
			$self->field('login')->value . '))',
			base => 'ou=People,dc=ibs',
			attrs => [ 'uid' ],
		       }
		      );

  if ($mesg->count) {
    my $err = '<span class="glyphicon glyphicon-exclamation-sign"></span> Fname+Lname+Login exists';
    $self->field('givenname')->add_error($err);
    $self->field('sn')->add_error($err);
    $self->field('login')->add_error($err);

    $err = '<div class="alert alert-danger">' .
      '<span style="font-size: 140%" class="icon_error-oct" aria-hidden="true"></span>' .
	'&nbsp;Account with the same fields &laquo;<strong>First Name&raquo;</strong>,' .
	  ' &laquo;<strong>Last Name&raquo;</strong> and &laquo;<strong>Login&raquo;</strong>' .
	    ' already exists!<br>Consider one of:<ul>' .
	      '<li>change Login in case you need another account for the same person</li>' .
		'<li>add service account to the existent one</li></ul></div>';
    my $error = $self->form->success_message;
    $self->form->error_message('');
    $self->form->add_form_error($error . $err);
  }
  $ldap_crud->unbind;
}

######################################################################

no HTML::FormHandler::Moose;

__PACKAGE__->meta->make_immutable;

1;

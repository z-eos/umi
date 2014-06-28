package UMI::Form::LDAP_organization_add;

use HTML::FormHandler::Moose;
extends 'HTML::FormHandler';

use HTML::FormHandler::Types ('NoSpaces', 'WordChars', 'NotAllDigits', 'Printable' );
use HTML::FormHandler::Widget::Theme::Bootstrap3;
use HTML::FormHandler::Widget::Wrapper::Bootstrap3;

has '+widget_wrapper' => ( default => 'Bootstrap3');

has 'ldap_crud' => (is => 'rw');
has 'uid' => (is => 'rw');
has 'pwd' => (is => 'rw');

    # businessCategory
    # description
    # destinationIndicator
    # facsimileTelephoneNumber
    # internationaliSDNNumber
    # l
    # physicalDeliveryOfficeName
    # postOfficeBox
    # postalAddress
    # postalCode
    # preferredDeliveryMethod
    # registeredAddress
    # searchGuide
    # seeAlso
    # st
    # street
    # telephoneNumber
    # teletexTerminalIdentifier
    # telexNumber
    # userPassword
    # x121Address

has_field 'parent' => ( type => 'Select',
			label => 'Parent Office', label_class => [ 'col-sm-3' ],
			label_attr => { title => 'parent office, the one to be created belong' },
			element_wrapper_class => 'col-sm-8',
		      );

sub options_parent {
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
  push my @orgs, { value => '0', label => '--- no parent office ---', selected => 'on' };
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
		 # label => $entry->get_value ('physicaldeliveryofficename') .
		 #  ' ( ' . $entry->get_value ('ou') . ' @ ' . $entry->get_value ('l') . ' )' };
  }
  return \@orgs;

  $ldap->unbind;
}

has_field 'ou' => ( label => 'Organizational Unit', label_class => [ 'col-sm-3' ],
		    label_attr => { title => 'top level name of the organization as it is used in physicalDeliveryOfficeName value of users' },
		    element_wrapper_class => 'col-sm-8',
		    element_attr => { placeholder => 'fo01' },
		    required => 1 );

has_field 'businessCategory' => ( type => 'Select',
				  label => 'Business Category', label_class => [ 'col-sm-3' ],
				  element_wrapper_class => 'col-sm-8',
				  options => [{ value => 'it', label => 'IT', selected => 'on'},
					      { value => 'trade', label => 'Trade',},
					      { value => 'telephony', label => 'Telephony',},
					      { value => 'fin', label => 'Financial',},
					      { value => 'tv', label => 'TV',},
					      { value => 'logistics', label => 'Logistics'},
					     ],
				);

has_field 'description' => ( type => 'TextArea',
		       label => 'Description', label_class => [ 'col-sm-3' ],
		       element_wrapper_class => 'col-sm-8',
		       element_attr => { placeholder => 'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Suspendisse sed dapibus nulla. Mauris vehicula vehicula ligula ac dapibus. Fusce vehicula a turpis sed. ' },
		       cols => 30, rows => 2);

has_field 'l' => ( label => 'Location', label_class => [ 'col-sm-3' ],
		   label_attr => { title => 'location, commonly the city the office situated at' },
		   element_wrapper_class => 'col-sm-8',
		   element_attr => { placeholder => 'Donetsk' },
		 );

has_field 'physicalDeliveryOfficeName' => ( label => 'physicalDeliveryOfficeName',
					    label_attr => { title => 'official office name as it is known to the world' },
					    label_class => [ 'col-sm-3' ],
					    element_wrapper_class => 'col-sm-8',
					    element_attr => { placeholder => 'Horns & Hooves LLC' });

has_field 'postOfficeBox' => ( label => 'Postoffice Box', label_class => [ 'col-sm-3' ],
			    element_wrapper_class => 'col-sm-8',
			    element_attr => { placeholder => '121' },
			     );

has_field 'postalAddress' => ( label => 'PostalAdress', label_class => [ 'col-sm-3' ],
			       element_wrapper_class => 'col-sm-8',
			       element_attr => { placeholder => '121, 4th floor' },
			     );

has_field 'postalCode' => ( label => 'Postalcode', label_class => [ 'col-sm-3' ],
			    element_wrapper_class => 'col-sm-8',
			    element_attr => { placeholder => '83100' },
			  );

has_field 'registeredAddress' => ( label => 'Registered Adress', label_class => [ 'col-sm-3' ],
				   element_wrapper_class => 'col-sm-8',
				   element_attr => { placeholder => '121, 4th floor' },
				 );

has_field 'st' => ( label => 'State', label_class => [ 'col-sm-3' ],
		    label_attr => { title => 'state, commonly short form of the city' },
		    element_wrapper_class => 'col-sm-8',
		    element_attr => { placeholder => 'DN' },
		  );

has_field 'street' => ( label => 'Street', label_class => [ 'col-sm-3' ],
			element_wrapper_class => 'col-sm-8',
			element_attr => { placeholder => 'Artema' },
		      );

has_field 'telephoneNumber' => ( label => 'telephoneNumber', label_class => [ 'col-sm-3' ],
				 element_wrapper_class => 'col-sm-8',
				 element_attr => { placeholder => '666' },
			       );

has_field 'reset' => ( type => 'Reset',
		       element_wrapper_class => 'col-sm-offset-3 col-sm-8',
		       element_class => [ 'btn', 'btn-default', 'pull-left' ],
		       value => 'Reset' );

has_field 'submit' => ( type => 'Submit',
#			wrapper_class => [ 'float-right' ],
			element_wrapper_class => 'col-sm-offset-3 col-sm-8',
			element_class => [ 'btn', 'btn-default', 'pull-right' ],
			value => 'Submit' );

sub validate {
  my $self = shift;

  # if ( $self->field('password1')->value ne $self->field('password2')->value ) {
  #   $self->field('password2')->add_error('<span class="glyphicon glyphicon-exclamation-sign"></span>&nbsp;password and its confirmation does not match');
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

######################################################################

no HTML::FormHandler::Moose;

__PACKAGE__->meta->make_immutable;

1;

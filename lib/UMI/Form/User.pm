# -*- mode: cperl -*-
#

package UMI::Form::User;

use HTML::FormHandler::Moose;
BEGIN { extends 'UMI::Form::LDAP'; with 'Tools'; }

use HTML::FormHandler::Types ('NoSpaces', 'WordChars', 'NotAllDigits', 'Printable' );

has '+item_class' => ( default =>'User' );
has '+enctype' => ( default => 'multipart/form-data');

has_field 'givenname' => ( apply => [ NoSpaces ],
			   label => 'First Name',
			   element_attr => { placeholder => 'John' },
			   required => 1 );

has_field 'sn' => ( apply => [ NoSpaces ],
		       label => 'Last name',
		       element_attr => { placeholder => 'Doe' },
		       required => 1 );

has_field 'avatar' => ( type => 'Upload',
			label => 'Photo User ID',
			element_class => [ 'btn', 'btn-default', ],
			max_size => '50000' );

has_field 'telephonenumber' => ( apply => [ NoSpaces ],
				 label => 'SIP/Cell',
				 wrapper_attr => { id => 'items' },
				 element_attr => { name => 'telephonenumber\[\]',
						   placeholder => '+38062xxxxxxx' });

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
				 base => $ldap_crud->{'cfg'}->{'base'}->{'org'},
				 scope => 'children',
				 filter => 'ou=*',
				 attrs => [ qw(ou physicaldeliveryofficename l) ],
				 sizelimit => 0
				}
			       );
  my @orgs = ( { value => '0', label => '--- no parent office ---', selected => 'on' } );
  my @entries = $mesg->entries;
  my ( $a, $i, @dn_arr, $dn, $label );
  foreach my $entry ( @entries ) {
    @dn_arr = split(',',$entry->dn);
    if ( scalar @dn_arr < 4 ) {
      $label = sprintf("%s (head office %s @ %s)",
		       $entry->get_value ('ou'),
		       $entry->get_value ('physicaldeliveryofficename'),
		       $entry->get_value ('l'),
		      );
    } elsif ( scalar @dn_arr == 4 ) {
      $label = sprintf("%s (%s @ %s) branch of %s",
		       $entry->get_value ('ou'),
		       $entry->get_value ('physicaldeliveryofficename'),
		       $entry->get_value ('l'),
		       substr($dn_arr[1],3)
		      );
    } else {
      for ( $i = 1, $dn = ''; $i < scalar @dn_arr - 2; $i++ ) {
	$dn .= $dn_arr[$i];
      }
      $a = $dn =~ s/ou=/ -> /g;
      $label = sprintf("%s (%s @ %s) branch of %s",
		       $entry->get_value ('ou'),
		       $entry->get_value ('physicaldeliveryofficename'),
		       $entry->get_value ('l'),
		       $dn
		      );
    }

    push @orgs, {
		 value => $entry->dn,
		 label => $label
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
#			     title => 'leave empty password fields to autogenerate password',
			   },
			 );

has_field 'password2' => ( type => 'Password',
			   minlength => 7, maxlength => 16,
			   label => '',
			   ne_username => 'login',
			   apply => [ NoSpaces, NotAllDigits, Printable ],
			   element_attr => 
			   { placeholder => 'Confirm Password',
#			     title => 'leave empty password fields to autogenerate password',
			   },
			 );

has_field 'pwdcomment' => ( type => 'Display',
			    html => '<p class="text-muted"><small><em>' .
			    'leave empty password fields to autogenerate password</em></small></p>',
#			    element_class => 'text-muted'
			  );

has_field 'descr' => ( type => 'TextArea',
		       label => 'Description',
		       element_attr => { placeholder => 'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Suspendisse sed dapibus nulla. Mauris vehicula vehicula ligula ac dapibus. Fusce vehicula a turpis sed. ' },
		       cols => 30, rows => 4);

has_field 'associateddomain' => ( type => 'Select',
				  label => 'Domain Name',
				  size => 5,
				  required => 1 );

sub options_associateddomain {
  my $self = shift;
  use Data::Printer;

  return unless $self->ldap_crud;

  my @domains = ( { value => '0', label => '--- select domain ---', selected => 'selected' } );

  my $ldap_crud = $self->ldap_crud;
  my $mesg = $ldap_crud->search( { base => 'ou=Organizations,dc=umidb',
				   filter => 'associatedDomain=*',
				   attrs => ['associatedDomain' ],
				 } );
  my $err_message = '';
  if ( ! $mesg->count ) {
    $err_message = '<div class="alert alert-danger">' .
      '<span style="font-size: 140%" class="icon_error-oct" aria-hidden="true"></span><ul>' .
	$ldap_crud->err($mesg) . '</ul></div>';
  }

  my @entries = $mesg->sorted('associatedDomain');
  my @i;
  foreach my $entry ( @entries ) {
    @i = $entry->get_value('associatedDomain');
    foreach (@i) {
      push @domains, { value => $_, label => $_, };
    }
  }
  # p @domains;
  return \@domains;
  $ldap_crud->unbind;
}

# has_field 'service' => ( type => 'Multiple',
# 			 label => 'Service',
# 			 options => [{ value => 'mail', label => 'Email', selected => 'on'},
# 				     { value => 'xmpp', label => 'Jabber', selected => 'on'},
# 				     { value => '802.1x-cable', label => 'LAN RG45'},
# 				     { value => '802.1x-wifi', label => 'WiFi'},
# 				    ],
# 			 size => 3,
# 			 required => 1 );

has_field 'authorizedservice' => ( type => 'Multiple',
				   label => 'Service', label_class => [ 'required' ],
				   size => 5,
				   required => 1,
				 );

sub options_authorizedservice {
  my $self = shift;
  use Data::Printer;

  return unless $self->ldap_crud;

  push my @services, {
		      value => '0',
		      label => '--- select service ---',
		      selected => 'selected',
		     };

  foreach my $key ( sort {$b cmp $a} keys %{$self->ldap_crud->{cfg}->{authorizedService}}) {
    next if $key =~ /^802.1x-.*/;
    # if ( $key eq 'mail' || $key eq 'xmpp' ) {
    #   push @services, {
    # 		       value => $key,
    # 		       label => $self->ldap_crud->{cfg}->{authorizedService}->{$key}->{descr},
    # 		       selected => 'on',
    # 		      };
    # } else {
      push @services, {
		       value => $key,
		       label => $self->ldap_crud->{cfg}->{authorizedService}->{$key}->{descr},
		      };
    # }
  }
  # p @services;
  return \@services;
}


has_field 'reset' => ( type => 'Reset',
			wrapper_class => [ 'pull-left', 'col-md-2' ],
			element_class => [ 'btn', 'btn-default', 'col-md-4' ],
		        value => 'Reset' );

has_field 'submit' => ( type => 'Submit',
			wrapper_class => [ 'pull-right', 'col-md-10' ],
			element_class => [ 'btn', 'btn-default', 'col-md-12' ],
			value => 'Submit' );



has_block 'person' => ( tag => 'fieldset',
			render_list => [ 'givenname', 'sn', 'telephonenumber', 'avatar' ],
			label => '<abbr title="Personal Data" class="initialism"><span class="icon_id" aria-hidden="true"></span></abbr>',
			label_class => [ 'pull-left' ],
			class => [ 'form-inline' ]
		      );

has_block 'job' => ( tag => 'fieldset',
		     render_list => [ 'title', 'office' ],
#		     label => '<abbr title="Job Related Details" class="initialism"><span class="icon_building" aria-hidden="true"></span></abbr>',
		     label_class => [ 'pull-left' ],
		     class => [ 'form-inline' ]
		   );

has_block 'account' => ( tag => 'fieldset',
			 render_list => [ 'login', 'password1', 'password2', 'pwdcomment' ],
			 label => '<abbr title="User Accounts (Management and Srvice/s) Credentials" class="initialism"><span class="icon_key_alt" aria-hidden="true"></span></abbr>',
			 label_class => [ 'pull-left' ],
			 class => [ 'form-inline' ],
		       );

has_block 'services' => ( tag => 'fieldset',
			  render_list => [ 'associateddomain', 'authorizedservice', 'descr' ],
			  label => '<abbr title="Services Assigned" class="initialism"><span class="icon_cloud_alt" aria-hidden="true"></span></abbr>',
			  # label => '<span class="icon_menu-square_alt2" aria-hidden="true"></span>',
			  label_class => [ 'pull-left' ],
			  class => [ 'form-inline' ]
			);

has_block 'submitit' => ( tag => 'fieldset',
			render_list => [ 'reset', 'submit'],
			label => '&nbsp;',
			class => [ 'row' ]
		      );

sub build_render_list {[ 'person', 'job', 'account', 'services', 'submitit' ]}

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
			$self->utf2lat({ to_translate => $self->field('givenname')->value }) . ')(sn=' .
			$self->utf2lat({ to_translate => $self->field('sn')->value }) . ')(uid=*-' .
			$self->field('login')->value . '))',
			base => 'ou=People,dc=umidb',
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

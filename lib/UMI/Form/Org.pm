# -*- mode: cperl; mode: follow; -*-
#

package UMI::Form::Org;

use HTML::FormHandler::Moose;
BEGIN { extends 'UMI::Form::LDAP';
	with 'Tools'; }

use HTML::FormHandler::Types ('NoSpaces', 'WordChars', 'NotAllDigits', 'Printable' );

use Data::Printer;

has '+action' => ( default => '/org');

sub build_form_element_class { [ qw(form-horizontal formajaxer), ] }

sub html_attributes {
  my ( $self, $field, $type, $attr ) = @_;
  push @{$attr->{'class'}}, 'required'
    if $type eq 'label' && $field->required;
}

has_field 'aux_dn_form_to_modify' => ( type => 'Hidden', );

has_field 'aux_parent'
  => (
      type => 'Select',
      label => 'Parent Office',
      label_class => [ 'col-xs-2', ],
      empty_select => '--- Choose a Parent Office if any ---',
      element_wrapper_class => [ 'col-xs-10', 'col-lg-5', ],
      wrapper_class => [ 'hide4update', ],
      options_method => \&parent_offices,
     );

has_field 'physicalDeliveryOfficeName'
  => (
      apply => [ NotAllDigits, Printable, ],
      label => 'physicalDeliveryOfficeName',
      label_class => [ 'col-xs-2', ],
      label_attr => { title => 'official office name as it is known to the world' },
      element_attr => { placeholder => 'Horns & Hooves LLC' },
      element_wrapper_class => [ 'col-xs-10', 'col-lg-5', ],
      required => 1,
     );

has_field 'destinationIndicator'
  => (
      apply => [ NotAllDigits, Printable, ],
      label => 'destinationIndicator',
      label_class => [ 'col-xs-2', ],
      label_attr => { title => 'code name of the office, organization occupies' },
      element_attr => { placeholder => 'example: abc, yz04, kl-01' },
      element_wrapper_class => [ 'col-xs-10', 'col-lg-5', ],
      required => 1,
     );

has_field 'associatedDomain'
  => (
      apply => [ NotAllDigits, Printable,
		 { check => qr/^([a-z0-9]+(-[a-z0-9]+)*\.)+[a-z]{2,}$/,
		   message => 'Must be valid FQDN' }, ],
      label => 'associatedDomain',
      label_class => [ 'col-xs-2', ],
      label_attr => { title => 'FQDN' },
      element_attr => { placeholder => 'orgXXX.foo.bar',
			title => 'FQDN, at least an internal one, something like oXXX.local', },
      element_wrapper_class => [ 'col-xs-10', 'col-lg-5', ],
      required => 1,
     );

has_field 'ou'
  => (
      apply => [ NoSpaces, NotAllDigits, Printable, ],
      label => 'Org Unit',
      label_class => [ 'col-xs-2', ],
      label_attr => { title => 'short name as it is used in object DN' },
      element_wrapper_class => [ 'col-xs-10', 'col-lg-5', ],
      element_attr => { placeholder => 'hrns-n-hvs' },
      required => 1,
     );

has_field 'telephoneNumber'
  => (
      label => 'telephoneNumber',
      label_class => [ 'col-xs-2', ],
      element_wrapper_class => [ 'col-xs-10', 'col-lg-5', ],
      element_attr => { placeholder => '666' },
     );

has_field 'businessCategory'
  => ( type => 'Multiple',
       label => 'Business Category',
       label_class => [ 'col-xs-2', ],
       element_wrapper_class => [ 'col-xs-5', 'col-lg-5', ],
       options => [
		   { value => 'na', label => 'N/A', },
		   { value => 'it', label => 'IT', },
		   { value => 'trade', label => 'Trade', },
		   { value => 'telephony', label => 'Telephony', },
		   { value => 'fin', label => 'Financial', },
		   { value => 'tv', label => 'TV', },
		   { value => 'logistics', label => 'Logistics' },
		  ],
     );

has_field 'postOfficeBox'
  => ( label => 'PB',
       label_class => [ 'col-xs-2', ],
       element_wrapper_class => [ 'col-xs-5', 'col-lg-1', ],
       element_attr => { placeholder => '121' },
     );

has_field 'street'
  => ( label => 'Street',
       label_class => [ 'col-xs-2', ],
       element_wrapper_class => [ 'col-xs-5', 'col-lg-3', ],
       element_attr => { placeholder => 'Shevchenka' },
     );

has_field 'postalCode'
  => (
      label => 'Postalcode',
      label_class => [ 'col-xs-2', ],
      element_wrapper_class => [ 'col-xs-5', 'col-lg-2', ],
      element_attr => { placeholder => '12345' },
     );

has_field 'l'
  => (
      label => 'Location',
      label_class => [ 'col-xs-2', ],
      label_attr => { title => 'location, commonly the city the office situated at' },
      element_wrapper_class => [ 'col-xs-5', 'col-lg-2', ],
      element_attr => { placeholder => 'Kyiv' },
      required => 1,
     );

has_field 'st'
  => ( label => 'State',
       label_class => [ 'col-xs-2', ],
       label_attr => { title => 'state, commonly short form of the city' },
       element_wrapper_class => [ 'col-xs-5', 'col-lg-1', ],
       element_attr => { placeholder => 'KV' },
     );

has_field 'postalAddress'
  => ( label => 'PostalAdress',
       label_class => [ 'col-xs-2', ],
       element_wrapper_class => [ 'col-xs-10', 'col-lg-5', ],
       element_attr => { placeholder => '121, 4th floor' },
     );

has_field 'registeredAddress'
  => ( label => 'Registered Adress',
       label_class => [ 'col-xs-2', ],
       element_wrapper_class => [ 'col-xs-10', 'col-lg-5', ],
       element_attr => { placeholder => '121, 4th floor' },
     );

has_field 'description'
  => ( type => 'TextArea',
       label => 'Description',
       label_class => [ 'col-xs-2', ],
       element_wrapper_class => [ 'col-xs-10', 'col-lg-5', ],
       element_attr => { placeholder => 'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Suspendisse sed dapibus nulla. Mauris vehicula vehicula ligula ac dapibus. Fusce vehicula a turpis sed. ' },
       # cols => 30,
       rows => 2
     );

has_field 'aux_reset' => ( type => 'Reset',
			   wrapper_class => [ 'col-xs-4' ],
			   element_class => [ 'btn', 'btn-danger', 'btn-block', ],
			   element_wrapper_class => [ 'col-xs-12', ],
			   # value => 'Reset'
			 );

has_field 'aux_submit' => (
			   type => 'Submit',
			   wrapper_class => [ 'col-xs-8'],
			   element_class => [ 'btn', 'btn-success', 'btn-block', ],
			   # label_no_filter => 1,
			   value => 'Submit'
			  );

######################################################################
# ====================================================================
# == VALIDATION ======================================================
# ====================================================================
######################################################################

sub validate {
  my $self = shift;
  # use Data::Printer;
  # foreach ( $self->fields ) {
  #   p $_->{name};
  #   p $self->field($_->{name})->value;
  # }
  
  # if ( $self->field('password1')->value ne $self->field('password2')->value ) {
  #   $self->field('password2')->add_error('<span class="fa fa-exclamation-circle"></span>&nbsp;password and its confirmation does not match');
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
  #   my $err = '<span class="fa fa-exclamation-circle"></span> Fname+Lname+Login exists';
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

sub parent_offices {
  my $self = shift;
  return unless $self->form->ldap_crud;
  return $self->form->ldap_crud->select_organizations;
}

######################################################################

no HTML::FormHandler::Moose;

__PACKAGE__->meta->make_immutable;

1;

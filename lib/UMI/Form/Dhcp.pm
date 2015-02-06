# -*- cperl -*-
#

package UMI::Form::Dhcp;

use HTML::FormHandler::Moose;
extends 'UMI::Form::LDAP';

use HTML::FormHandler::Types ('NoSpaces', 'WordChars', 'NotAllDigits', 'Printable', 'IPAddress' );

sub build_form_element_class { [ 'form-horizontal' ] }

sub html_attributes {
  my ( $self, $field, $type, $attr ) = @_;
  push @{$attr->{'class'}}, 'required'
    if $type eq 'label' && $field->required;
}

has_field 'ldap_add_dhcp' => ( type => 'Hidden', );

has_field 'net' => ( type => 'Select',
		     label => 'net',
		     label_class => [ 'col-xs-2' ],
		     wrapper_class => [ 'col-xs-8' ],
		     label_attr => { title => 'net the user assign to' },
		   );

sub options_net {
  my $self = shift;
  use Data::Printer;

  my ( $i, $mesg, @domains, @org, $domain, $return );

  return unless $self->ldap_crud;

  my $ldap_crud = $self->ldap_crud;

  $mesg = $ldap_crud->search({
			      base => $self->field('ldap_add_dhcp')->input,
			      scope => 'base',
			      attrs => [ 'physicalDeliveryOfficeName' ],
			     });

  if ( ! $mesg->count ) {
    push @{$return->{error}}, $ldap_crud->err($mesg);
  }

  @org = $mesg->sorted('physicalDeliveryOfficeName');

  foreach ( @org ) {
    $mesg = $ldap_crud->search({
				base => $_->get_value('physicalDeliveryOfficeName'),
				scope => 'base',
				attrs => [ 'associatedDomain', 'physicalDeliveryOfficeName' ],
			       });
    if ( ! $mesg->count ) {
      push @{$return->{error}}, $ldap_crud->err($mesg);
    }

    $domain = $mesg->as_struct;

    foreach $i ( @{$domain->{$_->get_value('physicalDeliveryOfficeName')}->{associateddomain}} ) {
       	push @domains,
	  {
	   value => $i,
	   label => sprintf('%s (%s)',
			    $i,
			    $domain->{$_->get_value('physicalDeliveryOfficeName')}->{physicaldeliveryofficename}->[0])
	  };
      }
  }

  return \@domains;

}

has_field 'cn' => (
		   label => 'Hostname',
		   label_class => [ 'col-xs-2' ],
		   label_attr => { title => 'hostname in general' },
		   wrapper_class => 'col-xs-8',
		   element_attr => { placeholder => 'r2d2' },
		   # required => 1,
		  );

has_field 'dhcpHWAddress' => (
			      label => 'MAC',
			      label_class => [ 'col-xs-2' ],
			      label_attr => { title => 'MAC address' },
			      wrapper_class => 'col-xs-8',
			      element_attr => { placeholder => '00:11:22:33:44:55' },
			      required => 1,
			     );

has_field 'dhcpStatements' => (
			       apply => [ IPAddress ],
			       label => 'IP',
			       label_class => [ 'col-xs-2' ],
			       label_attr => { title => 'IP address' },
			       wrapper_class => 'col-xs-8',
			       element_attr => { placeholder => '192.168.0.1' },
			       # required => 1,
			      );

has_field 'dhcpComments' => (
			     type => 'TextArea',
			     label => 'Comments',
			     label_class => [ 'col-xs-2' ],
			     wrapper_class => 'col-xs-8',
			     element_attr => { placeholder => 'this static lease any comment (type/purpose/state of the device/user)', },
			     rows => 2,
			    );

has_field 'hspace' => ( type => 'Display',
			html => '<div class="clearfix"></div>',
		      );

has_field 'aux_reset' => ( type => 'Reset',
			   wrapper_class => [ 'col-xs-1' ],
			   element_class => [ 'btn', 'btn-danger', 'btn-block', ],
			   element_wrapper_class => [ 'col-xs-12', ],
			   value => 'Reset' );

has_field 'aux_submit' => (
			   type => 'Submit',
			   wrapper_class => [ 'col-xs-11', ],
			   element_class => [ 'btn', 'btn-success', 'btn-block', ],
			   # label => '&nbsp;',
			   # label_class => [ 'col-xs-2', ],
			   # value => '<span class="glyphicon glyphicon-plus-sign"></span> Submit',
			   value => 'Submit'
			  );

has_block 'submitit' => ( tag => 'div',
			  render_list => [ 'aux_reset', 'aux_submit'],
			  class => [ 'row', ]
			);

sub build_render_list {[ 'net', 'cn', 'dhcpHWAddress', 'dhcpStatements', 'dhcpComments', 'hspace', 'submitit' ]}

sub validate {
  my $self = shift;

  my ( $mesg, $entry, $net );

  ## is IP available
  if ( defined $self->field('dhcpStatements')->value &&
       $self->field('dhcpStatements')->value ne '' ) { # IP is set
    $mesg =
      $self->ldap_crud->search({
			  base => $self->ldap_crud->{cfg}->{base}->{dhcp},
			  filter => sprintf('dhcpStatements=*%s',
					    $self->field('dhcpStatements')->value),
			 });

    if ( $mesg->count ) { # IP is set and not available
      $self->field('dhcpStatements')
	->add_error('<span class="glyphicon glyphicon-exclamation-sign"></span>&nbsp;IP address is not available.');
    }
  }

  my $dhcp = $self->ldap_crud->dhcp_lease({ net => $self->field('net')->value,
					    what => 'used', });
  ## hostname is not available
  $self->field('cn')
    ->add_error('<span class="glyphicon glyphicon-exclamation-sign"></span>&nbsp;Hostname is already used.')
      if defined $self->field('cn')->value &&
	$dhcp->{hostname}->{$self->field('cn')->value}->{ip};

  ## MAC is not available
  $self->field('dhcpHWAddress')
    ->add_error('<span class="glyphicon glyphicon-exclamation-sign"></span>&nbsp;MAC address is already used.')
      if defined $self->field('dhcpHWAddress')->value &&
	$dhcp->{mac}->{$self->field('dhcpHWAddress')->value}->{ip};
}

######################################################################

no HTML::FormHandler::Moose;

__PACKAGE__->meta->make_immutable;

1;

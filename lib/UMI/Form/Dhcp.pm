# -*- cperl -*-
#

package UMI::Form::Dhcp;

use HTML::FormHandler::Moose;
extends 'UMI::Form::LDAP';

use HTML::FormHandler::Types ('NoSpaces', 'WordChars', 'NotAllDigits', 'Printable', 'IPAddress' );

use Data::Printer;

has '+action' => ( default => '/dhcp' );

sub build_form_element_class { [ qw(form-horizontal formajaxer) ] }

sub html_attributes {
  my ( $self, $field, $type, $attr ) = @_;
  push @{$attr->{'class'}}, 'required'
    if $type eq 'label' && $field->required;
}

has_field 'ldap_add_dhcp' => ( type => 'Hidden', );

has_field 'requestttl'
  => ( type          => 'Display',
       html          => sprintf('
<div class="row">
  <label class="col-2 text-right font-weight-bold control-label atleastone" title="Object Expiration">
    Expiration
  </label>
  <div class="col-3">
    <div class="form-group">
      <div class="input-group date" id="requestttl" data-target-input="nearest">
        <input name="requestttl" type="text" class="form-control datetimepicker-input" data-target="#requestttl"/>
        <div class="input-group-append" data-target="#requestttl" data-toggle="datetimepicker">
          <div class="input-group-text"><i class="fas fa-calendar-alt"></i></div>
        </div>
      </div>
    </div>
  </div>
</div>'),
       element_attr  => { 'data-name' => 'logindescr',
			  'data-group' => 'account', },
       wrapper_class => [ 'row', ],
     );




# has_field 'requestttl' 
#   => ( type                  => 'Text',
#        label                 => 'Expiration',
#        label_attr            => { title => 'Object Expiration', },
#        label_class           => [ 'col', 'atleastone', 'text-right', 'font-weight-bold', ],
#        wrapper_class         => [ 'row' ],
#        element_wrapper_class => [ 'input-sm', 'col-10', ],
#        element_attr          => { title => 'Object Expiration', },
#        required              => 0 );

has_field 'net' 
  => ( type                  => 'Select',
       label                 => 'Network',
       label_class           => [ 'col', 'text-right', 'font-weight-bold', ],
       wrapper_class         => [ 'row' ],
       element_wrapper_class => [ 'col-10', ],
       element_class         => [ 'custom-select', ],
       label_attr            => { title => 'net (of the offices) the user assign to' },
       options_method        => \&dhcp_nets,
     );

has_field 'cn' 
  => (
      label                 => 'Hostname',
      label_class           => [ 'col', 'text-right', 'font-weight-bold', ],
      label_attr            => { title => 'hostname in general' },
      element_wrapper_class => [ 'input-sm', 'col-10', ],
      wrapper_class         => [ 'row', ],
      element_attr          => { placeholder => 'r2d2' },
      # required => 1,
     );

has_field 'dhcpHWAddress' 
  => (
      label                 => 'MAC',
      label_class           => [ 'col', 'text-right', 'font-weight-bold', ],
      label_attr            => { title => 'MAC address' },
      element_wrapper_class => [ 'input-sm', 'col-10', ],
      wrapper_class         => [ 'row', ],
      element_attr          => { placeholder => '00:11:22:33:44:55' },
      # required              => 1,
     );

has_field 'dhcpStatements' 
  => (
      apply                 => [ IPAddress ],
      label                 => 'IP',
      label_class           => [ 'col', 'text-right', 'font-weight-bold', ],
      label_attr            => { title => 'IP address, if not set, then first free available is picked up' },
      element_wrapper_class => [ 'input-sm', 'col-10', ],
      wrapper_class         => [ 'row', ],
      element_attr          => { placeholder => '192.168.0.1' },
      # required => 1,
     );

has_field 'dhcpComments' 
  => (
      type                  => 'TextArea',
      label                 => 'Comments',
      label_class           => [ 'col', 'text-right', 'font-weight-bold', ],
      element_wrapper_class => [ 'input-sm', 'col-10', ],
      wrapper_class         => [ 'row', ],
      element_attr          => { placeholder => 'this static lease any comment (type/purpose/state of the device/user)', },
      rows                  => 2,
     );

has_field 'hspace' => ( type => 'Display',
			html => '<div class="clearfix"></div>',
		      );

has_field 'aux_reset' => ( type => 'Reset',
			   wrapper_class => [ 'col' ],
			   element_class => [ 'btn', 'btn-danger', 'btn-block', ],
			   element_wrapper_class => [ 'col-xs-12', ],
			   value => 'Reset' );

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
  => ( tag => 'div',
       render_list => [ 'aux_reset', 'aux_submit'],
       class => [ 'row', ]
     );

sub build_render_list {[ 'ldap_add_dhcp',
			 'requestttl',
			 'net',
			 'cn',
			 'dhcpHWAddress',
			 'dhcpStatements',
			 'dhcpComments',
			 'hspace',
			 'aux_submitit' ]}

sub validate {
  my $self = shift;

  my ( $mesg, $entry, $net );

  ## is IP available
  if ( defined $self->field('dhcpStatements')->value &&
       $self->field('dhcpStatements')->value ne '' ) { # IP is set
    $mesg =
      $self->ldap_crud->search({
				base => $self->ldap_crud->cfg->{base}->{dhcp},
				filter => sprintf('dhcpStatements=*%s',
						  $self->field('dhcpStatements')->value),
			       });

    if ( $mesg->count ) { # IP is set and not available
      $self->field('dhcpStatements')
	->add_error('<span class="fa fa-exclamation-circle"></span>&nbsp;IP address is not available.');
    }
  }

  ## is MAC available
  if ( defined $self->field('dhcpHWAddress')->value &&
       $self->field('dhcpHWAddress')->value ne '' ) { # MAC is set
    $mesg =
      $self->ldap_crud->search({
				base => $self->field('net')->value,
				filter => sprintf('dhcpHWAddress=ethernet %s',
						  $self->field('dhcpHWAddress')->value),
			       });

      $self->field('dhcpHWAddress')
	->add_error('<span class="fa fa-exclamation-circle"></span>&nbsp;MAC address is already used.')
	if $mesg->count;
  }

  ## is HOSTNAME available
  if ( defined $self->field('cn')->value &&
       $self->field('cn')->value ne '' ) { # HOSTNAME is set
    $mesg =
      $self->ldap_crud->search({ base => $self->ldap_crud->cfg->{base}->{dhcp},
				 filter => sprintf('cn=%s', $self->field('cn')->value), });

      $self->field('cn')
	->add_error('<span class="fa fa-exclamation-circle"></span>&nbsp;Hostname is already used.')
	if $mesg->count;
  }

  # my $dhcp = $self->ldap_crud->dhcp_lease({ net => $self->field('net')->value,
  # 					    what => 'used', });
  # $self->add_form_error($dhcp->{error}) if defined $dhcp->{error};

  # ## hostname is not available
  # $self->field('cn')
  #   ->add_error('<span class="fa fa-exclamation-circle"></span>&nbsp;Hostname is already used.')
  #     if defined $self->field('cn')->value &&
  # 	$dhcp->{hostname}->{$self->field('cn')->value}->{ip};

  # ## MAC is not available
  # $self->field('dhcpHWAddress')
  #   ->add_error('<span class="fa fa-exclamation-circle"></span>&nbsp;MAC address is already used.')
  #     if defined $self->field('dhcpHWAddress')->value &&
  # 	$dhcp->{mac}->{$self->field('dhcpHWAddress')->value}->{ip};
}

######################################################################

sub dhcp_nets {
  my $self = shift;
  return unless $self->form->ldap_crud;
  return $self->form->ldap_crud->select_dhcp_nets;
}

######################################################################

no HTML::FormHandler::Moose;

__PACKAGE__->meta->make_immutable;

1;

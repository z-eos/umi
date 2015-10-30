# -*- mode: cperl -*-
#

package UMI::Controller::Dhcp;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; with 'Tools'; }

use UMI::Form::Dhcp;

=head1 NAME

UMI::Controller::Dhcp - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


has 'form' => (
	       isa => 'UMI::Form::Dhcp', is => 'rw',
	       lazy => 1, documentation => q{Form to add DHCP host},
	       default => sub { UMI::Form::Dhcp->new },
	      );


=head2 index

strictly speaking - new object creation (ldapadd1)

=cut


sub index :Path :Args(0) {
  my ( $self, $c ) = @_;
  if ( $c->check_user_roles('wheel')) {
    $c->stash( template => 'dhcp/dhcp_wrap.tt',
	       form => $self->form );

    return unless
      $self->form->process(
			   posted => ($c->req->method eq 'POST'),
			   params => $c->req->parameters,
			   ldap_crud => $c->model('LDAP_CRUD'),
			  );
  } elsif ( defined $c->session->{auth_uid} ) {
    if ( defined $c->session->{'unauthorized'}->{ $c->action } ) {
      $c->session->{'unauthorized'}->{ $c->action } += 1;
    } else {
      $c->session->{'unauthorized'}->{ $c->action } = 1;
    }
    $c->stash( 'template' => 'unauthorized.tt',
	       'unauth_action' => $c->action, );
  } else {
    $c->stash( template => 'signin.tt', );
  }
}


=head2 create_dhcp_host

creates dhcp host configuration object (static dhcp lease)

    dn: cn=ap1,cn=198.51.100.0,cn=ship01 DHCP Config,ou=headquarters,ou=starfleet,ou=DHCP,dc=umidb
    cn: ap1
    dhcphwaddress: ethernet 00:22:b0:62:d1:fb
    dhcpstatements: fixed-address 198.51.100.3
    objectclass: top
    objectclass: dhcpHost
    objectclass: uidObject
    uid: U1408443894C9001-kathryn.janeway

we are taking net (fqdn for ip network assigned to some organization)
and resolving not used ip addresses from it

=cut



sub create_dhcp_host {
  my  ( $self, $ldap_crud, $args ) = @_;
  my $return;

  use Data::Printer;

  my $dhcpStatements = $ldap_crud->dhcp_lease({ net => $args->{net} });
  $return->{error} = sprintf('<li>%s</li>', $dhcpStatements->{error}) if ref($dhcpStatements) eq 'HASH';

  my $arg = {
	     dhcpHWAddress => $args->{dhcpHWAddress},
	     uid => $args->{uid},
	     net => $args->{net}, # FQDN for net new oject have to belong to
	     dhcpStatements => $args->{dhcpStatements} || $dhcpStatements->[0],
	     cn => $args->{cn} || $args->{dhcpHWAddress} =~ tr/://dr,
	     dhcpComments => join(' ', $args->{dhcpComments}) || undef,
	    };

  $arg->{ldapadd_arg} = [
			 dhcpHWAddress => sprintf('ethernet %s', $arg->{dhcpHWAddress}),
			 uid => $arg->{uid},
			 dhcpStatements => sprintf('fixed-address %s', $arg->{dhcpStatements}),
			 cn => $arg->{cn},
			 objectClass => $ldap_crud->cfg->{objectClass}->{dhcp},
			];

  push @{$arg->{ldapadd_arg}}, dhcpComments => $arg->{dhcpComments} if defined $arg->{dhcpComments};

  my $nets = $ldap_crud->search( { base => $ldap_crud->cfg->{base}->{dhcp},
				   filter => 'dhcpOption=domain-name "' . $arg->{net} . '"', } );

  if ( $nets->count > 1 ) {
    $return->{warning} = '<li>network <b>&laquo;' . $arg->{net} .'&raquo;</b> used more than one time in DHCP config!</li>';
  }

  my $net = $nets->entry(0);
  $arg->{dn} = sprintf('cn=%s,%s', $arg->{cn}, $net->dn);

  $nets = $ldap_crud->add( $arg->{dn}, $arg->{ldapadd_arg} );
  if ( $nets ) {
    $return->{error} .= sprintf('<li>error during <b>&laquo;%s&raquo;</b> configuration: %s</li>', $arg->{net}, $nets);
  } else {
    $return->{success} =
      sprintf('user <em><b>%s,%s</b></em> MAC: <em><b>%s</b></em> now bound to IP: <em><b>%s,%s</b></em>',
	      $arg->{uid},
	      $ldap_crud->cfg->{base}->{acc_root},
	      $arg->{dhcpHWAddress},
	      $arg->{dhcpStatements});
  }

  return $return;
}



=head1 AUTHOR

Charlie &

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;

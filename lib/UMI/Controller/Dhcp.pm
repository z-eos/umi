# -*- mode: cperl -*-
#

package UMI::Controller::Dhcp;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; with 'Tools'; }

use UMI::Form::Dhcp;
use Time::Piece;

use Data::Printer { use_prototypes => 0, caller_info => 1 };
use Logger;

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

new object creation

=cut


sub index :Path :Args(0) {
  my ( $self, $c ) = @_;
  my $params = $c->req->parameters;

  $c->stash( template => 'dhcp/dhcp_wrap.tt',
	     form => $self->form );

  return unless
    $self->form->process(
			 posted => ($c->req->method eq 'POST'),
			 params => $c->req->parameters,
			 ldap_crud => $c->model('LDAP_CRUD'),
			);
  $c->stash(
	    final_message => $self->create_dhcp_host ( $c->model('LDAP_CRUD'),
						       {
							dhcpHWAddress  => $params->{dhcpHWAddress},
							uid            => substr((split(',',$params->{ldap_add_dhcp}))[0],4),
							dhcpStatements => $params->{dhcpStatements},
							net            => $params->{net},
							cn             => $params->{cn},
							requestttl     => $params->{requestttl},
							dhcpComments   => $params->{dhcpComments},
						       }
						     ));
}


=head2 create_dhcp_host

creates dhcp host configuration object (static dhcp lease)

    dn: cn=ap1,cn=198.51.100.0,cn=ship01 DHCP Config,ou=headquarters,ou=starfleet,ou=DHCP,dc=umidb
    cn: ap1
    dhcphwaddress: ethernet 00:22:b0:62:d1:fb
    dhcpstatements: fixed-address 198.51.100.3
    dhcpstatements: ddns-hostname U1408443894C9001-kathryn.janeway-0022b062d1fb
    objectclass: top
    objectclass: dhcpHost
    objectclass: uidObject
    uid: U1408443894C9001-kathryn.janeway

we are taking net from the form and resolving it's not used ip addresses

=cut



sub create_dhcp_host {
  my  ( $self, $ldap_crud, $args ) = @_;
  my $return;
  my $dhcpStatements;
  my $nets;
  my @net = split('/', $args->{net});
  
  log_debug { np( $args ) };

  # my $dhcpStatements = $ldap_crud->dhcp_lease({ net => $args->{net} });
  # $return->{error} = sprintf('<li>%s</li>', $dhcpStatements->{error}) if ref($dhcpStatements) eq 'HASH';

  my $iu = $ldap_crud->ipam_used({ svc    => 'dhcp',
				   netdn  => $args->{net},
				   base   => $args->{net},
				   filter => '(objectClass=*)',
				   attrs  => [ 'cn', 'dhcpNetMask', 'dhcpRange' ], });
  # log_debug { np( $iu ) };
  if ( defined $iu->{error} ) {
    push @{$return->{warning}}, $iu->{error};
  } else {
    my $first_free = $self->ipam_first_free({ ipspace => $iu->{ipspace}, ip_used => $iu->{ip_used} });
    if ( ! $first_free ) {
      push @{$return->{warning}}, $self->
	search_result_item_as_button({ pfx     => 'No free address available for the network choosen.',
				       dn      => $args->{net},
				       btn_txt => $args->{net},
				       css_btn => 'btn-warning',
				       sfx     => 'try to narrow dhcpRange/dhcpPool for the network if any.', });
    } else {
      my $t = localtime;
      my $arg = {
		 dhcpHWAddress  => $args->{dhcpHWAddress},
		 uid            => $args->{uid} || 'unknown',
		 netdn          => $args->{net},
		 net            => $args->{net}, # FQDN for net new oject have to belong to
		 dhcpStatements => $args->{dhcpStatements} || $first_free,
		 cn             => $args->{cn} || $args->{uid} . '-' . $args->{dhcpHWAddress} =~ tr/://dr,
		 dhcpComments   => join(' ', $args->{dhcpComments}) || undef,
		};
      my $exp = defined $args->{requestttl} && $args->{requestttl} ne '' && $args->{requestttl} ne '____.__.__ __:__' ? 1 : 0;
      $arg->{requestttl} = $exp ? $self->delta_t({ requestttl => $args->{requestttl}}) : 0;
      # log_debug { np($exp) };

      my $objectClass = $ldap_crud->cfg->{objectClass}->{dhcp};
      push @{$objectClass}, 'dynamicObject' if $exp;

      $arg->{ldapadd_arg} = [
			     cn => $arg->{cn},
			     uid => $arg->{uid},
			     objectClass => $objectClass,
			     dhcpHWAddress => sprintf('ethernet %s', $arg->{dhcpHWAddress}),
			     dhcpStatements => [ sprintf('fixed-address %s', $arg->{dhcpStatements}),
						 sprintf('ddns-hostname "%s"', $arg->{cn}) ],
			    ];

      push @{$arg->{ldapadd_arg}}, dhcpComments => $arg->{dhcpComments} if defined $arg->{dhcpComments};
      # log_debug { np($arg) };

      # $nets = $ldap_crud->search( { base => $ldap_crud->cfg->{base}->{dhcp},
      # 				     filter => 'dhcpOption=domain-name "' . $arg->{net} . '"', } );

      # if ( $nets->count > 1 ) {
      #   $return->{warning} = '<li>network <b>&laquo;' . $arg->{net} .'&raquo;</b> used more than one time in DHCP config!</li>';
      # }
      # my $net = $nets->entry(0);

      $arg->{dn} = sprintf('cn=%s,%s', $arg->{cn}, $arg->{netdn});

      $nets = $ldap_crud->add( $arg->{dn}, $arg->{ldapadd_arg} );
      log_debug { np($nets) };
      if ( $nets ) {
	push @{$return->{error}}, sprintf('<li>error during <b>&laquo;%s&raquo;</b> configuration: %s</li>',
					  $arg->{net},
					  $nets->{html});
      } else {
	if ( $arg->{requestttl} ) {
	  my $refresh = $ldap_crud->refresh( $arg->{dn}, $arg->{requestttl} );
	  if ( defined $refresh->{success} ) {
	    push @{$return->{success}}, $refresh->{success};
	  } elsif ( defined $refresh->{error} ) {
	    push @{$return->{error}}, $refresh->{error};
	  }
      }

	push @{$return->{success}},
	  sprintf('user <em><b>%s,%s</b></em> MAC: <em><b>%s</b></em> now bound to IP: <em><b>%s,%s</b></em>',
		  $arg->{uid},
		  $ldap_crud->cfg->{base}->{acc_root},
		  $arg->{dhcpHWAddress},
		  $arg->{dhcpStatements});
      }
    }
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

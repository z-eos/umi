package UMI::Controller::Mikrotik;
use Moose;
use namespace::autoclean;

use Data::Printer;
use Logger;

BEGIN { extends 'Catalyst::Controller'; with 'Tools'; }

=head1 NAME

UMI::Controller::Mikrotik - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 index

=cut

sub index :Path :Args(0) {
  my ( $self, $c ) = @_;
  my $registrations;
  
  if ( exists UMI->config->{mikrotik}->{caps_host} ) {
    $registrations = $self->ask_mikrotik({ type     => 'registrations',
					   host     => UMI->config->{mikrotik}->{caps_host},
					   username => UMI->config->{mikrotik}->{caps_username},
					   password => UMI->config->{mikrotik}->{caps_password}, });

    my $ldap_crud = $c->model('LDAP_CRUD');
    my ( $mesg, $entry, $key, $val );
    
    foreach my $mac (keys (%{$registrations->{registrats}})) {
      $mesg = $ldap_crud->search({ base   => $ldap_crud->{cfg}->{base}->{dhcp},
				   filter => sprintf("(dhcpHWAddress=ethernet %s)", lc($mac)), });
      next if $mesg->count < 1;
      ( $key, $val ) = each %{$mesg->as_struct};
      # log_debug { np($val) };
      $registrations->{registrats}->{$mac}->{uid} = $val->{uid}->[0];
      foreach (@{$val->{dhcpstatements}}) {
	log_debug { np($_) };
	$registrations->{registrats}->{$mac}->{ip} = (split(/ /, $_))[1] if $_ =~ /^fixed-address .*/;
      }
      log_debug { np($registrations->{registrats}->{$mac}) };
    }
  } else {
    $registrations->{success} = '';
  }
    
  # log_debug { np($registrations) };

  $c->stash( template => 'server/mikrotik.tt',
	     final_message => $registrations, );
}



=encoding utf8

=head1 AUTHOR

zeus

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;

# -*- mode: cperl; mode: follow; -*-
#

package UMI::Controller::MikrotikPsk;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; with 'Tools'; }

use UMI::Form::ToolPwdgen;
has 'form' => (
	       isa => 'UMI::Form::ToolPwdgen', is => 'rw',
	       lazy => 1, documentation => q{Form to translit text},
	       default => sub { UMI::Form::ToolPwdgen->new },
	      );


=head1 NAME

UMI::Controller::ToolPwdgen - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut



=head2 index

new Text Pwdgen

QR version is defined dynamicaly (previous to the one spawning error)


=cut


sub index :Path :Args(0) {
  my ( $self, $c ) = @_;
  my $final_message;
  my $qr;

  if ( exists UMI->config->{mikrotik}->{caps_host} ) {
    my $psks = $self->ask_mikrotik({ type     => 'get_psk',
				     host     => UMI->config->{mikrotik}->{caps_host},
				     username => UMI->config->{mikrotik}->{caps_username},
				     password => UMI->config->{mikrotik}->{caps_password}, });

    $final_message->{success} = '<table class="table table-striped text-center">';
    foreach my $psk (sort (keys (%{$psks}))) {
      next if $psks->{$psk}->{'authentication-types'} !~ /psk/;
      for ( my $i = 0; $i < 41; $i++ ) {
	$qr = $self->qrcode({ txt => $psks->{$psk}->{passphrase}, ver => $i, mod => 5 });
	last if ! exists $qr->{error};
      }
      $final_message->{error} = $qr->{error} if $qr->{error};

      $final_message->{success} .=
	sprintf('<tr><td class="mono h3"><b>%s: </b>%s</td><tr><td><img class="img-thumbnail" alt="PSK: %s" src="data:image/jpg;base64,%s" title="%s"/></td></tr>',
		$psk,
		$psks->{$psk}->{passphrase},
		$psk,
		$qr->{qr},
		$psk);
    }
  
    $final_message->{success} .= '</table>';
  } else {
    $final_message->{success} = '';
  }
  
  $c->stash( template => 'tool/mikrotikpsk.tt',
	     final_message => $final_message );
}

=head1 AUTHOR

Charlie &

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;

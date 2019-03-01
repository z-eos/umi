# -*- mode: cperl; mode: follow; -*-
#

package UMI::Controller::ToolQR;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; with 'Tools'; }

use UMI::Form::ToolQR;
has 'form' => (
	       isa => 'UMI::Form::ToolQR', is => 'rw',
	       lazy => 1, documentation => q{Form to translit text},
	       default => sub { UMI::Form::ToolQR->new },
	      );


=head1 NAME

UMI::Controller::ToolQR - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut



=head2 index

new Text Pwdgen

=cut


sub index :Path :Args(0) {
    my ( $self, $c ) = @_;
    my $params = $c->req->parameters;
    
    $c->stash( template => 'tool/toolqr.tt',
	       form     => $self->form );

    return unless
      $self->form->process(
			   posted => ($c->req->method eq 'POST'),
			   params => $params,
			  );
    use Data::Printer;
    my ($final_message, $qr);

    # $qr = $self->qrcode({ txt => $params->{toqr}, ecc => 'Q', ver => 6, mod => 8 });
    for( my $i = 0; $i < 41; $i++ ) {
      $qr = $self->qrcode({ txt => $params->{toqr}, ver => $i, mod => $params->{mod}, ecc => 'L' });
      last if ! exists $qr->{error};
    }

    if ( exists $qr->{error} ) {
      $final_message->{error} = $qr->{error};
    } else {
      $final_message->{success} = sprintf('<figure class="text-center">
  <figcaption>QR code for input: <span class="text-monospace">%s</span></figcaption>
  <img alt="no QR Code was generated for: %s"
       src="data:image/png;base64,%s"
       title="QR Code for user input"/>
</figure>',
					  $params->{toqr},
					  $params->{toqr},
					  $qr->{qr} );
    }
    $c->stash( final_message => $final_message );
}

=head1 AUTHOR

Charlie &

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;

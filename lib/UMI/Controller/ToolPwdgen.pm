# -*- mode: cperl; mode: follow; -*-
#

package UMI::Controller::ToolPwdgen;
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
  my $params = $c->req->parameters;
    
  $c->stash( template => 'tool/toolpwdgen.tt',
	     form     => $self->form );

  return unless
    $self->form->process( posted => ($c->req->method eq 'POST'),
			  params => $params, );

  my $pwd = $self->pwdgen({ len           => $params->{'pwd_len'}     || undef,
			    num           => $params->{'pwd_num'}     || undef,
			    cap           => $params->{'pwd_cap'}     || undef,
			    pronounceable => $params->{pronounceable} || 0, });

  my $final_message->{success} = '<table class="table table-vcenter table-borderless">' .
    '<tr><td><h1 class="text-monospace text-center">' .
    $pwd->{clear} . '</h1></td><td class="text-center">';

  my $qr;
  for( my $i = 0; $i < 41; $i++ ) {
    $qr = $self->qrcode({ txt => $pwd->{clear}, ver => $i, mod => 5 });
    last if ! exists $qr->{error};
  }

  $final_message->{error} = $qr->{error} if $qr->{error};
  $final_message->{success} .= sprintf('<img alt="password QR" src="data:image/jpg;base64,%s" title="password QR"/>',
				       $qr->{qr} );
  $final_message->{success} .= '</td></tr></table>';

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

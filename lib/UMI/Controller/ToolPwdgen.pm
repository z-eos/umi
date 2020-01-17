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
  my $p = $c->req->parameters;

  $c->stash( template => 'tool/toolpwdgen.tt',
	     form     => $self->form );

  if ( keys %{$p} > 0 ) {
    return unless
      $self->form->process( posted => ($c->req->method eq 'POST'),
			    init_object => { pwd_len       => $p->{pwd_len},
					     pwd_num       => $p->{pwd_num},
					     pwd_cap       => $p->{pwd_cap},
					     pronounceable => $p->{pronounceable}, },
			    params => $p, );
  } else {
    return unless
      $self->form->process( posted      => ($c->req->method eq 'POST'),
			    params      => $p, );
  }

  my $pwd =
    $self->pwdgen({ len => defined $p->{pwd_len} && length($p->{pwd_len}) ? $p->{pwd_len} : undef,
		    num => defined $p->{pwd_num} && length($p->{pwd_num}) ? $p->{pwd_num} : undef,
		    cap => defined $p->{pwd_cap} && length($p->{pwd_cap}) ? $p->{pwd_cap} : undef,
		    pronounceable => $p->{pronounceable} // 0,
		    xk_preset     => $p->{xk_preset}   // undef, });

  my $final_message->{success} = '<div class="row">' .
    '<div class="col-12 h3 text-monospace text-break text-center">' . $pwd->{clear} .
    '</div><div class="col-12 text-center">';

  my $qr;
  for( my $i = 0; $i < 41; $i++ ) {
    $qr = $self->qrcode({ txt => $pwd->{clear}, ver => $i, mod => 5 });
    last if ! exists $qr->{error};
  }

  $final_message->{error} = $qr->{error} if $qr->{error};
  $final_message->{success} .= sprintf('<img alt="password QR" src="data:image/jpg;base64,%s" title="password QR"/>',
				       $qr->{qr} );
  $final_message->{success} .= '</div></div>';

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

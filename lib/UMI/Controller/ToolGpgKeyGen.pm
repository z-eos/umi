# -*- mode: cperl; mode: follow; -*-
#

package UMI::Controller::ToolGpgKeyGen;
use Moose;
use namespace::autoclean;

use Logger;
use Data::Printer;

BEGIN { extends 'Catalyst::Controller'; with 'Tools'; }

use UMI::Form::ToolGpgKeyGen;
has 'form' => (
	       isa => 'UMI::Form::ToolGpgKeyGen', is => 'rw',
	       lazy => 1, documentation => q{Form to generate SSH key},
	       default => sub { UMI::Form::ToolGpgKeyGen->new },
	      );


=head1 NAME

UMI::Controller::ToolGpgKeyGen - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut



=head2 index

new Text Translit

=cut


sub index :Path :Args(0) {
  my ( $self, $c ) = @_;

  if ( defined $c->user_exists && $c->user_exists == 1 ) {
    my $params = $c->req->parameters;

    $c->stash( template => 'tool/toolgpgkeygen.tt',
	       form     => $self->form );

    return unless
      $self->form->process(
			   posted => ($c->req->method eq 'POST'),
			   params => $params,
			  );

    my $key = $self->keygen_gpg({ bits => $params->{bits},
				  name => { real  => $c->session->{__user}->{user}->{attributes}->{gecos} // 'not signed in',
					    email => $c->session->{__user}->{user}->{attributes}->{mail} // 'not signed in',
					  },
				});

    if ( exists $key->{error} ) {
      $key->{html}->{error} = $key->{error};
    }

    $c->stash( final_message => $key->{html},
	       key           => $key );
  } else {
    $c->stash( template => 'signin.tt', );
  }
}

=head1 AUTHOR

Charlie &

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;

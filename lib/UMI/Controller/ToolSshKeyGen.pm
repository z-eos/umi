# -*- mode: cperl; mode: follow; -*-
#

package UMI::Controller::ToolSshKeyGen;
use Moose;
use namespace::autoclean;

use Logger;
use Data::Printer;

BEGIN { extends 'Catalyst::Controller'; with 'Tools'; }

use UMI::Form::ToolSshKeyGen;
has 'form' => (
	       isa => 'UMI::Form::ToolSshKeyGen', is => 'rw',
	       lazy => 1, documentation => q{Form to generate SSH key},
	       default => sub { UMI::Form::ToolSshKeyGen->new },
	      );


=head1 NAME

UMI::Controller::ToolSshKeyGen - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut



=head2 index

new Text Translit

=cut


sub index :Path :Args(0) {
    my ( $self, $c ) = @_;
    my $params = $c->req->parameters;

    $c->stash( template => 'tool/toolsshkeygen.tt',
	       form     => $self->form );

    return unless
      $self->form->process(
			   posted => ($c->req->method eq 'POST'),
			   params => $params,
			  );
    
    my $key = $self->ssh_keygen({ key_type => $params->{key_type}, bits => $params->{bits} });

    if ( exists $key->{error} ) {
      $key->{html}->{error} = $key->{error};
    } else {
      $key->{html}->{success} =
      sprintf('<pre>%s</pre><p class="mono">%s generated by %s on %s via UMI</p>',
	      $key->{private},
	      $key->{public},
	      $c->user,
	      $self->ts({ format => "%Y%m%d%H%M%S" })
	     );
    }

    $c->stash( final_message => $key->{html}, );
}

=head1 AUTHOR

Charlie &

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;

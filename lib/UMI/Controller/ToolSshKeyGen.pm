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

    my $key->{name} = { real  => $c->session->{__user}->{user}->{attributes}->{gecos} // 'not signed in',
			email => $c->session->{__user}->{user}->{attributes}->{mail}  // 'not signed in', };

    $key->{ssh} = $self->keygen_ssh({ type => $params->{key_type},
				      bits => $params->{bits},
				      name => $key->{name} });

    $key->{html}->{error} = $key->{ssh}->{error}
      if exists $key->{ssh}->{error};
    log_debug { np($key) };
    $c->stash( final_message => $key->{html},
	       key           => $key
	     );
}

=head1 AUTHOR

Charlie &

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;

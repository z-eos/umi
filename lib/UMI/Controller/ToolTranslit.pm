# -*- mode: cperl; mode: follow; -*-
#

package UMI::Controller::ToolTranslit;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; with 'Tools'; }

use UMI::Form::ToolTranslit;
has 'form' => (
	       isa => 'UMI::Form::ToolTranslit', is => 'rw',
	       lazy => 1, documentation => q{Form to translit text},
	       default => sub { UMI::Form::ToolTranslit->new },
	      );


=head1 NAME

UMI::Controller::ToolTranslit - Catalyst Controller

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

    $c->stash( template => 'tool/tooltranslit.tt',
	       form => $self->form );

    return unless
      $self->form->process(
			   posted => ($c->req->method eq 'POST'),
			   params => $params,
			  );

    my $final_message->{success} = $self->utf2lat( $params->{totranslit} );
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

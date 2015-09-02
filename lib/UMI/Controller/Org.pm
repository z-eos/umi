# -*- mode: cperl -*-
#

package UMI::Controller::Org;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; with 'Tools'; }

use UMI::Form::Org;
has 'form' => (
	       isa => 'UMI::Form::Org', is => 'rw',
	       lazy => 1, documentation => q{Form to add organization/s},
	       default => sub { UMI::Form::Org->new },
	      );


=head1 NAME

UMI::Controller::Org - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut



=head2 index

new Organization/Office object creation

=cut


sub index :Path :Args(0) {
    my ( $self, $c, $ldap_org_id ) = @_;
    my $params = $c->req->parameters;

    $c->stash( template => 'org/org_wrap.tt',
	       form => $self->form );

    return unless
      $self->form->process(
			   posted => ($c->req->method eq 'POST'),
			   params => $params,
			   ldap_crud => $c->model('LDAP_CRUD'),
			  );

    $c->stash( final_message => $c->model('LDAP_CRUD')
	       ->obj_add(
			 {
			  type => 'org',
			  params => $params,
			 }
			));
}

=head1 AUTHOR

Charlie &

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;

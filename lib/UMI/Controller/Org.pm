# -*- mode: cperl -*-
#

package UMI::Controller::Org;
use Moose;
use namespace::autoclean;
use Data::Printer colored => 0, caller_info => 1;

use Logger;

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

  log_debug { np($c->stash) };
  $c->stash( template => 'org/org_wrap.tt',
	     form => $self->form );

  my $formmodify;
  $formmodify = $params->{aux_dn_form_to_modify}
    if defined $params->{aux_dn_form_to_modify} && $params->{aux_dn_form_to_modify} ne '';
  
  return unless
    $self->form->process(
			 posted => ($c->req->method eq 'POST'),
			 params => $params,
			 ldap_crud => $c->model('LDAP_CRUD'),
			);
    
  if ( defined $params->{aux_dn_form_to_modify} && $params->{aux_dn_form_to_modify} ne '' ) {
    log_info { 'Here we will launch form modify code' };
  } else {
    $c->stash( final_message => $c->model('LDAP_CRUD')
	       ->obj_add({ type => 'org',
			   params => $params,
			 }));
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

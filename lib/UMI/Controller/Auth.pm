# -*- cperl -*-
#

package UMI::Controller::Auth;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; }

=head1 NAME

UMI::Controller::Auth - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 index

=cut

sub index :Path :Args(0) {
  my ( $self, $c ) = @_;

  # signin();
  # $c->response->body('Matched UMI::Controller::Auth in Auth.');
}

sub signin :Path Global {
  my ( $self, $c ) = @_;

  $c->session->{auth_uid} = $c->req->param('auth_uid');
  $c->session->{auth_pwd} = $c->req->param('auth_pwd');

  if ( $c->authenticate({
			 id       => $c->session->{auth_uid},
			 password => $c->session->{auth_pwd},
			})) {
    $c->session->{auth_obj} = $c->user->attributes('ashash');
    delete $c->session->{auth_obj}->{jpegphoto};
    $c->session->{auth_uid} = $c->user->uid;
    push @{$c->session->{auth_roles}}, $c->user->roles;
    $c->cache->set( 'auth_obj', $c->session->{auth_obj} );
    # use Data::Printer;
    # p $c->session;
    # p $c->cache->get( 'auth_obj' );
    $c->stash( template => 'welcome.tt', );
  } else {
    $c->stash( template => 'signin.tt', );
  }
}

sub signout :Path Global {
  my ( $self, $c ) = @_;
  $c->logout();
  $c->delete_session('SignOut');
  $c->response->redirect($c->uri_for('/'));
}


=head1 AUTHOR

Zeus Panchenko

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;

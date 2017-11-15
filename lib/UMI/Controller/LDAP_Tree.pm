#-*- cperl -*-
#

package UMI::Controller::LDAP_Tree;
use Moose;
use namespace::autoclean;
use Data::Printer colored => 0;
use Net::LDAP::Util qw(	ldap_explode_dn canonical_dn );

BEGIN { extends 'Catalyst::Controller'; }

=head1 NAME

UMI::Controller::LDAP_Tree - Catalyst Controller

=head1 DESCRIPTION

LDAP tree crawler


=head1 METHODS

=cut


=head2 index

=cut

# sub index :Chained('/') :PathPart('ldap_tree') :Args(1) {
#   my ( $self, $c, $args) = @_;
sub index :Path :Args(0) {
  my ( $self, $c ) = @_;

  my $return;
  my ( $e, $l, $r, $tree );

  my $ldap_crud = $c->model('LDAP_CRUD');

  $c->stash->{current_view} = 'WebJSON';

  my $params = $c->req->params;
  my $arg = { base => $params->{base} || $ldap_crud->{cfg}->{base}->{db},
	      filter => $params->{filter} || '(objectClass=*)', };

  # initial, one level crawl
  my $mesg = $ldap_crud->search({ base => $arg->{base},
				  scope => 'one',
				  sizelimit => 0,
				  filter => $arg->{filter}, });
  if ( $mesg->code ) {
    push @{$return->{error}}, $ldap_crud->err($mesg)->{html};
    $c->stash( template => 'tree/tree.tt',
	       final_message => $return, );
  } elsif ( $mesg->count ) {
    # each element fetched check whether it is branch or leaf
    my @root = $mesg->sorted;
    foreach $e ( @root ) {
      ( $l, $r ) = split(/,/, $e->dn);
      $tree->{id} = $l;
      $tree->{dn} = $e->dn;
      $mesg = $ldap_crud->search({ base => $e->dn,
				   scope => 'one',
				   sizelimit => 0,
				   filter => '(objectClass=*)', });
      if ( $mesg->code ) {
	push @{$return->{error}}, $ldap_crud->err($mesg)->{html};
	$c->stash( template => 'tree/tree.tt',
		   final_message => $return, );
      } else {
	$tree->{br} = $mesg->count > 0 ? 1 : 0;
      }
      push @{$c->stash->{tree}}, $tree;
      undef $tree;
    }
  } else {
    ( $l, $r ) = split(/,/, $arg->{base});
    $tree->{id} = $l;
    $tree->{dn} = $arg->{base};
    $tree->{br} = 0;
    push @{$c->stash->{tree}}, $tree;
  }
}



=encoding utf8

=head1 AUTHOR

zeus

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;

#-*- cperl -*-
#

package UMI::Controller::LDAP_Tree;
use Moose;
use namespace::autoclean;
use Data::Printer colored => 0;
use Net::LDAP::Util qw(	ldap_explode_dn canonical_dn );
use LDAP_NODE;

use Logger;

BEGIN { extends 'Catalyst::Controller'; }

=head1 NAME

UMI::Controller::LDAP_Tree - Catalyst Controller

=head1 DESCRIPTION

LDAP tree crawler


=head1 METHODS

=cut


=head2 index

on input option base and filter can be present

    http://umi.lan:3000//ldap_tree/ldap_tree_neo/?base=ou=People,dc=umidb&filter=uid=naf*

=cut

sub index_neo :Path(ldap_tree_neo) :Args(0) {
  my ( $self, $c ) = @_;
  $c->stats->profile(begin => 'LDAP tree neo');

  my $ldap_crud = $c->model('LDAP_CRUD');

  my ( $return, $as_hash );
  my $params = $c->req->params;
  my $arg = { base   => $params->{base}   // $ldap_crud->{cfg}->{base}->{db},
	      filter => $params->{filter} // '(objectClass=*)', };

  my $mesg = $ldap_crud->search({ base      => $arg->{base},
				  scope     => 'children',
				  sizelimit => 0,
				  typesonly => 1,
				  attrs     => [ '1.1' ],
				  filter    => $arg->{filter}, });

  if ( $mesg->code ) {
    push @{$return->{error}}, $ldap_crud->err($mesg)->{html};

    $c->stash( template      => 'tree/tree_neo.tt',
	       final_message => $return, );
  } else {
    my $ldap_tree = LDAP_NODE->new();
    $ldap_tree->insert($_->dn) foreach ( $mesg->entries );
    $as_hash = $ldap_tree->as_json_vue;
    # log_debug { np( $as_hash ) };
    
    $c->stats->profile('tree neo, building complete');

    $c->stash( current_view => 'WebJSON_LDAP_Tree',
	       json_tree    => $as_hash, );
  }
  $c->stats->profile(end   => 'LDAP tree neo');
}

# # # oldfashioned, timethirsty variant
sub index :Path :Args(0) {
  my ( $self, $c ) = @_;
  $c->stats->profile(begin => 'LDAP tree');

  my $return;
  my ( $e, $l, $r, $tree, @to_stash );

  my $ldap_crud = $c->model('LDAP_CRUD');

  $c->stash->{current_view} = 'WebJSON_LDAP_Tree';

  my $params = $c->req->params;
  my $arg = { base   => $params->{base}   || $ldap_crud->{cfg}->{base}->{db},
	      filter => $params->{filter} || '(objectClass=*)', };

  # initial, one level crawl
  my $mesg = $ldap_crud->search({ base      => $arg->{base},
				  scope     => 'one',
				  sizelimit => 0,
				  typesonly => 1,
				  attrs     => [ '1.1' ],
				  filter    => $arg->{filter}, });
  if ( $mesg->code ) {
    push @{$return->{error}}, $ldap_crud->err($mesg)->{html};
    $c->stash( template      => 'tree/tree.tt',
	       final_message => $return, );
  } elsif ( $mesg->count ) {
    $c->stats->profile('first level crawl');
    # each entry check, whether it is branch or leaf
    foreach $e ( $mesg->sorted ) {
      # log_debug {np($e)};
      ( $l, $r ) = split(/,/, $e->dn);
      $tree->{id} = $l;
      $tree->{dn} = $e->dn;
      $mesg = $ldap_crud->search({ base      => $e->dn,
				   scope     => 'one',
				   sizelimit => 0,
				   typesonly => 1,
				   attrs     => [ '1.1' ],
				   filter    => '(objectClass=*)', });
      if ( $mesg->code ) {
	push @{$return->{error}}, $ldap_crud->err($mesg)->{html};
	$c->stash( template      => 'tree/tree.tt',
		   final_message => $return, );
      } else {
	$tree->{branch} = $mesg->count > 0 ? 1 : 0;
      }
      push @to_stash, $tree;
      undef $tree;
    # $c->stats->profile('each second level entry');
    }
    $c->stats->profile('second level crawl');
  } else {
    ( $l, $r )      = split(/,/, $arg->{base});
    $tree->{id}     = $l;
    $tree->{dn}     = $arg->{base};
    $tree->{branch} = 0;
    push @to_stash, $tree;
  }

  # log_debug { np(@to_stash) };

  $c->stash->{json_tree} = \@to_stash;

  $c->stats->profile(end   => 'LDAP tree');
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

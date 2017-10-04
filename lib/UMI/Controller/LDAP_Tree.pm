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
  my ( $root, $dn, $branch, $level1, $level2, $root_dn, $root_l, $root_r, $branch_dn, $branch_l, $branch_r );

  my $ldap_crud = $c->model('LDAP_CRUD');

  my $params = $c->req->params;
  my $arg = { base => $params->{base} || $ldap_crud->{cfg}->{base}->{db},
	      filter => $params->{filter} || '(objectClass=*)', };

  # # first we crawl 
  # my $mesg = $ldap_crud->search({ base => $arg->{base},
  # 				  scope => 'sub',
  # 				  sizelimit => 0,
  # 				  attrs => [ 'fakeAttr' ],
  # 				  filter => $arg->{filter}, });
  # p $root = $mesg->as_struct;

  my $mesg = $ldap_crud->search({ base => $arg->{base},
				  scope => 'one',
				  sizelimit => 0,
				  filter => $arg->{filter}, });
  if ( $mesg->code ) {
    push @{$return->{error}}, $ldap_crud->err($mesg)->{html};
    $c->stash( template => 'tree/tree.tt',
	       final_message => $return, );
  } else {
    $c->stash->{current_view} = 'WebJSON';
    $c->stash->{tree}->{dn} = $arg->{base};
    $c->stash->{tree}->{id} = '';
    $root = $mesg->as_struct;
    my $branch_tree;
    foreach $root_dn (keys ( %{$root} ) ) {
      ( $root_l, $root_r ) = split(/,/, $root_dn);
      $branch_tree->{id} = $root_l;
      $branch_tree->{dn} = $root_dn;
      $mesg = $ldap_crud->search({ base => $root_dn,
				   scope => 'one',
				   sizelimit => 0,
				   filter => '(objectClass=*)', });
      if ( $mesg->code ) {
	push @{$return->{error}}, $ldap_crud->err($mesg)->{html};
	$c->stash( template => 'tree/tree.tt',
		   final_message => $return, );
      } else {
	$branch = $mesg->as_struct;
	foreach $branch_dn (keys ( %{$branch} ) ) {
	  ( $branch_l, $branch_r ) = split(/,/, $branch_dn);
	  push @{$branch_tree->{subtree}}, {id => $branch_l, dn => $branch_dn };
	}
      }
      push @{$c->stash->{tree}->{subtree}}, $branch_tree;
      undef $branch_tree;
    }
    #p $c->stash->{tree};
    # $c->stash( template => 'tree/tree.tt', );
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

# -*- cperl -*-
#

package UMI::Controller::Auth;
use Moose;
use namespace::autoclean;
use Data::Printer;

BEGIN { extends 'Catalyst::Controller'; }

=head1 NAME

UMI::Controller::Auth - Catalyst Controller

=head1 DESCRIPTION

Auth Controller.

=head1 METHODS

=cut

=head2 index

=cut

sub index :Path :Args(0) {
  my ( $self, $c ) = @_;

  # signin();
  # $c->response->body('Matched UMI::Controller::Auth in Auth.');
}

=head2 signin

- schema is stored to session->ldap->obj_schema

former, dynamic method, variant is at LDAP_CRUD->obj_schema

- attributes equalities are stored in session->ldap->obj_schema_attr_equality

former, dynamic method, variant is at LDAP_CRUD->attr_equality

=cut

sub signin :Path Global {
  my ( $self, $c ) = @_;

  $c->session->{auth_uid} = $c->req->param('auth_uid');
  $c->session->{auth_pwd} = $c->req->param('auth_pwd');

  if ( $c->authenticate({
			 id       => $c->session->{auth_uid},
			 password => $c->session->{auth_pwd},
			})) {
    ## moving to Session->__user # $c->session->{auth_obj} = $c->user->attributes('ashash');
    ## moving to Session->__user # delete $c->session->{auth_obj}->{jpegphoto};
    # dending of what RDN type is used for auth e.g.uid, cn
    $c->session->{auth_uid} = eval '$c->user->' . UMI->config->{authentication}->{realms}->{ldap}->{store}->{user_field};
    ## moving to Session->__user # delete $c->session->{auth_roles};
    ## moving to Session->__user # push @{$c->session->{auth_roles}}, $c->user->roles;
    ## moving to Session->__user # $c->cache->set( 'auth_obj', $c->session->{auth_obj} );
    # p $c->session;
    # p $c->cache->get( 'auth_obj' );

    my $ldap_crud = $c->model('LDAP_CRUD');
    my ( $meta_schema, $key, $value, $must_meta, $may_meta, $must, $may, $syntmp);
    while ( ($key, $value) = each %{$ldap_crud->{cfg}->{objectClass}}) {
      foreach ( @{$value} ) {
	$meta_schema->{$_} += 1;
      }
    }
    my $schema = $ldap_crud->schema; # ( dn => $ldap_crud->{base}->{db} );
    foreach $key ( sort ( keys %{$meta_schema} )) {
      next if $key eq 'top';
      foreach $must ( $schema->must ( $key ) ) {
	$syntmp = $schema->attribute_syntax($must->{'name'});
	$must_meta =
	  {
	   'desc' => $must->{'desc'} || undef,
	   'single-value' => $must->{'single-value'} || undef,
	   'max_length' => $must->{'max_length'} || undef,
	   'equality' => $must->{'equality'} || undef,
	   'syntax' => { desc => $syntmp->{desc},
			 oid =>  $syntmp->{oid}, },
	  };
	$c->session->{ldap}->{obj_schema}->{$key}->{must}
	  ->{ $must->{'name'} } = $must_meta;
	$must_meta = -1;
      }
      foreach $may ( $schema->may ( $key ) ) {
	$syntmp = $schema->attribute_syntax($may->{'name'});
	$may_meta =
	  {
	   'desc' => $may->{'desc'} || undef,
	   'single-value' => $may->{'single-value'} || undef,
	   'max_length' => $may->{'max_length'} || undef,
	   'equality' => $may->{'equality'} || undef,
	   'syntax' => { desc => $syntmp->{desc},
			 oid =>  $syntmp->{oid}, },
	  };
	$c->session->{ldap}->{obj_schema}->{$key}->{may}
	  ->{ $may->{'name'} } = $may_meta;
	$may_meta = -1;
      }
    }

    foreach ( $schema->all_attributes ) {
      if ( defined $_->{equality} ) {
	$c->session->{ldap}->{obj_schema_attr_equality}->{$_->{name}} = $_->{equality};
      } elsif ( defined $_->{sup}) {
	$c->session->{ldap}->{obj_schema_attr_equality}->{$_->{name}} = $_->{sup}->[0];
      }
    }

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

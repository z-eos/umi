# -*- mode: cperl; mode: follow; -*-
#

package UMI::Controller::Auth;
use Moose;
use namespace::autoclean;
use Data::Printer;
use Try::Tiny;
use Logger;

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
  log_debug { np( @_ ) };
  log_debug { np( $c->req->params ) };

  $c->session->{auth_uid} = $c->req->param('auth_uid');
  $c->session->{auth_pwd} = $c->req->param('auth_pwd');

  try {
    # log_debug { np($c->session) };
    $c->authenticate({ id       => $c->session->{auth_uid},
		       password => $c->session->{auth_pwd}, });

    # depending of what RDN type is used for auth e.g.uid, cn
    $c->session->{auth_uid} = eval '$c->user->' . UMI->config->{authentication}->{realms}->{ldap}->{store}->{user_field};
    # log_debug { np($c->session) };

    my $umiSettingsJson = defined $c->user ? $c->user->has_attribute('umisettingsjson') : '{}';

    if ( defined $umiSettingsJson ) {
      use JSON;
      my $json = JSON->new->allow_nonref;
      $c->session->{settings} = $json->decode( $umiSettingsJson );
      # log_debug { np($c->session->{settings}) };
    }

    $c->session->{settings}->{sidebar}->{mikrotik} = 
      exists UMI->config->{mikrotik} ? 1 : 0;
    
    # log_debug { np( $c->user->ldap_entry->ldif ) };
    my $ldap_crud = $c->model('LDAP_CRUD');
    my ( $meta_schema, $objectclass, $key, $value, $must_meta, $may_meta, $must, $may, $syntmp );
    
    while ( ($key, $value) = each %{$ldap_crud->{cfg}->{objectClass}}) {
      $meta_schema->{$_} += 1 foreach ( @{$value} );
    }

    $meta_schema->{dhcpClass}         = 1;
    $meta_schema->{dhcpDnsZone}       = 1;
    $meta_schema->{dhcpFailOverPeer}  = 1;
    $meta_schema->{dhcpGroup}         = 1;
    $meta_schema->{dhcpHost}          = 1;
    $meta_schema->{dhcpLeases}        = 1;
    $meta_schema->{dhcpLocator}       = 1;
    $meta_schema->{dhcpLog}           = 1;
    $meta_schema->{dhcpOptions}       = 1;
    $meta_schema->{dhcpPool}          = 1;
    $meta_schema->{dhcpServer}        = 1;
    $meta_schema->{dhcpService}       = 1;
    $meta_schema->{dhcpSharedNetwork} = 1;
    $meta_schema->{dhcpSubClass}      = 1;
    $meta_schema->{dhcpSubnet}        = 1;
    $meta_schema->{dhcpTSigKey}       = 1;

    # log_debug { np($meta_schema) };
    my $schema = $ldap_crud->schema; # ( dn => $ldap_crud->{base}->{db} );
    foreach $key ( sort ( keys %{$meta_schema} )) {
      next if $key eq 'top';
      $objectclass = $schema->objectclass ($key);
      # log_debug { np($objectclass) };
      $c->session->{ldap}->{obj_schema}->{$key}->{structural} = $objectclass->{structural} // 0;
      $c->session->{ldap}->{obj_schema}->{$key}->{auxiliary}  = $objectclass->{auxiliary}  // 0;
      $c->session->{ldap}->{obj_schema}->{$key}->{desc}       = $objectclass->{desc} // 'NA';
      # log_debug { np(@{[$schema->must ( $key )]}) } if $key eq 'umiSettings';
      foreach $must ( $schema->must ( $key ) ) {
	# do not remember why it is needed # next if $ldap_crud->{cfg}->{defaults}->{ldap}->{is_single}->{$must->{name}};
	next if $must->{'name'} eq 'objectClass';
	$syntmp = $schema->attribute_syntax($must->{'name'});
	$must_meta =
	  {
	   'desc'         => $must->{'desc'}         || undef,
	   'single-value' => $must->{'single-value'} || undef,
	   'max_length'   => $must->{'max_length'}   || undef,
	   'equality'     => $must->{'equality'}     || undef,
	   'syntax'       => { desc => $syntmp->{desc},
			       oid  => $syntmp->{oid}, },
	  };
	$c->session->{ldap}->{obj_schema}->{$key}->{must}
	  ->{ $must->{'name'} } = $must_meta;
	$must_meta = -1;
      }
      # log_debug { np(@{[$schema->may ( $key )]}) } if $key eq 'umiSettings';
      foreach $may ( $schema->may ( $key ) ) {
	# do not remember why it is needed # next if $ldap_crud->{cfg}->{defaults}->{ldap}->{is_single}->{$may->{name}};
	next if $may->{'name'} eq 'objectClass';
	$syntmp = $schema->attribute_syntax($may->{'name'});
	$may_meta =
	  {
	   'desc'         => $may->{'desc'}         || undef,
	   'single-value' => $may->{'single-value'} || undef,
	   'max_length'   => $may->{'max_length'}   || undef,
	   'equality'     => $may->{'equality'}     || undef,
	   'syntax'       => { desc => $syntmp->{desc},
			       oid  => $syntmp->{oid}, },
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

      if ( exists $ldap_crud->{cfg}->{defaults}->{ldap}->{is_single}->{$_->{name}} ) {
	$c->session->{ldap}->{obj_schema_attr_single}->{$_->{name}} = $ldap_crud->{cfg}->{defaults}->{ldap}->{is_single}->{$_->{name}};
      } else {
	$c->session->{ldap}->{obj_schema_attr_single}->{$_->{name}} = defined $_->{'single-value'} ? 1 : 0;
      }
    }

    $c->session->{ldap}->{base} = $ldap_crud->{cfg}->{base};
    
    log_info { 'user ' . $c->session->{auth_uid} . ' successfully logged in' };

    $c->stash( template => 'welcome.tt', );
  } catch {
    log_fatal { sprintf(" user %s session was not found (expired session or server restarted);\n\n %s \n\n %s\n %s \n ",
			$c->session->{auth_uid},
			'=' x 70,
			$_,
			'=' x 70) };
    my $final_message;
    #$final_message->{error} = 'Server internal error, please inform sysadmin!';
    $c->logout();
    $c->delete_session('SignOut');
    $c->response->status(401);
    # $c->response->redirect($c->uri_for('/'));
    $c->stash( template => 'signin.tt', );
#	       final_message => $final_message, );
  };
}

sub signout :Path Global {
  my ( $self, $c ) = @_;
  $c->logout();
  log_info { 'user ' . $c->session->{auth_uid} . ' successfully logged out' };
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

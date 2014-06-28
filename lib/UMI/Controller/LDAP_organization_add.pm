package UMI::Controller::LDAP_organization_add;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; with 'Tools'; }

use UMI::Form::LDAP_organization_add;

=head1 NAME

UMI::Controller::LDAP_organization_add - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


has 'form' => ( isa => 'UMI::Form::LDAP_organization_add', is => 'rw',
		lazy => 1, 
		default => sub { 
		  UMI::Form::LDAP_organization_add->new('form_element_class' => 'form-horizontal')
		  },
		documentation => q{Form to add organization/s},
	      );


=head2 index

=cut

sub index :Path :Args(0) {
    my ( $self, $c, $ldap_org_id ) = @_;
    if ( $c->check_user_roles('umi-admin')) {
      $c->stash( template => 'ldapact/ldapact_o_add_wrap.tt',
		 form => $self->form );

      # Validate and insert/update database
      return unless $self->form->process( item_id => $ldap_org_id,
					  posted => ($c->req->method eq 'POST'),
					  params => $c->req->parameters,
					  ldap_crud => $c->model(
								 'LDAP_CRUD',
								 uid => $c->session->{umi_ldap_uid},
								 pwd => $c->session->{umi_ldap_password},
								),
					);

      my $res = $self->create_object( $c );
      $c->log->debug( "create_object (from umi_o_add) error: " . $res) if $res;

    } else {
      $c->response->body('Unauthorized!');
    }
}

=head2 create_object

=cut

sub create_object {
  my  ( $self, $c ) = @_;
  my $attrs = $c->req->parameters;

  use Data::Dumper;
  # $c->log->debug( "\$attrs:\n" . Dumper($attrs));

  my $ldap_crud =
    $c->model('LDAP_CRUD', dn => 'uid=' .
	      $c->session->{umi_ldap_uid} .
	      ',ou=people,dc=ibs',
	      password => $c->session->{umi_ldap_password}
	     );

  my $descr = 'description has to be here';
  if (defined $attrs->{'descr'} and $attrs->{'descr'} ne '') {
    $descr = join(' ', $attrs->{'descr'});
  }

  my $telephoneNumber = '666';
  if (defined $attrs->{'telephonenumber'} and $attrs->{'telephonenumber'} ne '') {
    $telephoneNumber = $attrs->{'telephonenumber'};
  }

#
## HERE WE NEED TO SET FLAG TO CREATE BRANCH FOR LOCALIZED VERSION OF DATA
## associatedService=localization-ru,uid=U...-user01,ou=People,dc=ibs
## associatedService=localization-uk,uid=U...-user01,ou=People,dc=ibs
## e.t.c.
#

  my ( $givenName, $sn, $cn, $o, $pwd );
  if ($self->is_ascii($attrs->{'fname'})) {
    $givenName = $self->cyr2lat({ to_translate => $attrs->{'fname'} });
  } else {
    $givenName = $attrs->{'fname'};
  };
  $cn = $givenName;

  if ($self->is_ascii($attrs->{'lname'})) {
    $sn = $self->cyr2lat({ to_translate => $attrs->{'lname'} });
  } else {
    $sn = $attrs->{'lname'};
  };
  $cn .= ' ' . $sn;

  if ($self->is_ascii($attrs->{'org'})) {
    $o = $self->cyr2lat({ to_translate => $attrs->{'org'} });
  } else {
    $o = $attrs->{'org'};
  };

  my $attr_defined = [];
  foreach my $key (keys %{$attrs}) {
    push @{$attr_defined}, $key => $self->cyr2lat({ to_translate => $attrs->{$key}})
      if defined $attrs->{$key} and $attrs->{$key} ne '' and $key ne 'submit' and $key ne 'parent';
  }
  push @{$attr_defined}, objectClass => [ 'top', 'organizationalUnit' ];

#  $c->log->debug( "parent\n: $attrs->{'parent'} \nattr_defined:\n" . Dumper($attr_defined));
  my $success_message;

  ######################################################################
  # ORGANIZATION Object
  ######################################################################
  my $base = defined $attrs->{'parent'} ? $attrs->{'parent'} : 'ou=Organizations,dc=ibs';
  my $ldif =
    $ldap_crud->add(
		    'ou=' . $attrs->{'ou'} . ',' .
		    $base,
		    $attr_defined,
		   );
  my $error_message;
  if ( $ldif ) {
    $error_message = 'Error during organization object creation occured: ' . $ldif;
    $c->log->error('ou=' . $attrs->{'ou'} .
		   ',ou=Organizations,dc=ibs' .
		   " obj wasn not created: " . $ldif);
  }

  my $final_message;
  $final_message = '<div class="alert alert-success">' .
    '<span style="font-size: 140%" class="glyphicon glyphicon-ok-sign"></span>' .
      '&nbsp;<em>Object for organization ' .
	' &laquo;' . $self->cyr2lat({ to_translate => $attrs->{'physicaldeliveryofficename'} }) .
	  '&raquo;</em> successfully created.</div>' if $success_message;

  $final_message .= '<div class="alert alert-danger">' .
    '<span style="font-size: 140%" class="icon_error-oct" aria-hidden="true"></span>&nbsp;' .
      $error_message . '</div>' if $error_message;

  $self->form->info_message( $final_message ) if $final_message;

  $ldap_crud->unbind;
  return $ldif;
}


=head1 AUTHOR

Charlie &

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;

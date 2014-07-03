# -*- mode: cperl -*-
#

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


has 'form' => (
	       isa => 'UMI::Form::LDAP_organization_add', is => 'rw',
	       lazy => 1, documentation => q{Form to add organization/s},
	       default => sub { UMI::Form::LDAP_organization_add->new },
	      );


=head2 index

=cut

sub index :Path :Args(0) {
    my ( $self, $c, $ldap_org_id ) = @_;
    if ( $c->check_user_roles('umi-admin')) {
      $c->stash( template => 'ldapact/ldapact_o_add_node.tt',
		 form => $self->form );

      # Validate and insert/update database
      return unless
	$self->form->process(
			     item => $c->model('LDAP_CRUD')
			     ->obj_add(
			     	       {
			     		'type' => 'org',
			     		'params' => $c->req->parameters,
					'form' => $self->form,
			     	       }
			     	      ),
			     # item_id => $ldap_org_id,
			     posted => ($c->req->method eq 'POST'),
			     params => $c->req->parameters,
			     ldap_crud => $c->model('LDAP_CRUD'),
			     use_defaults_over_obj => 1,
			     defaults => {
					  businessCategory => 'it',
					 },
			    );
      ## $c->response->redirect($c->uri_for('/ldap_organization_add'));
      # my $res = $c->model('LDAP_CRUD')->obj_add(
      # 						{
      # 						 'type' => 'org',
      # 						 'params' => $c->req->parameters
      # 						}
      # 					       );
# moved to LDAP_CRUD # my $res = $self->create_object( $c );
      # $c->log->debug( "create_object (from umi_o_add) error: " . $res) if $res;
    } else {
      $c->response->body('Unauthorized!');
    }
}

=head2 create_object

=cut

# moved to LDAP_CRUD # sub create_object {
# moved to LDAP_CRUD #   my  ( $self, $c ) = @_;
# moved to LDAP_CRUD #   my $attrs = $c->req->parameters;
# moved to LDAP_CRUD # 
# moved to LDAP_CRUD #   use Data::Dumper;
# moved to LDAP_CRUD #   # $c->log->debug( "\$attrs:\n" . Dumper($attrs));
# moved to LDAP_CRUD # 
# moved to LDAP_CRUD #   my $ldap_crud = $c->model('LDAP_CRUD');
# moved to LDAP_CRUD # 
# moved to LDAP_CRUD #   my $descr = 'description has to be here';
# moved to LDAP_CRUD #   if (defined $attrs->{'descr'} && $attrs->{'descr'} ne '') {
# moved to LDAP_CRUD #     $descr = join(' ', $attrs->{'descr'});
# moved to LDAP_CRUD #   }
# moved to LDAP_CRUD # 
# moved to LDAP_CRUD #   my $telephoneNumber = '666';
# moved to LDAP_CRUD #   if (defined $attrs->{'telephonenumber'} && $attrs->{'telephonenumber'} ne '') {
# moved to LDAP_CRUD #     $telephoneNumber = $attrs->{'telephonenumber'};
# moved to LDAP_CRUD #   }
# moved to LDAP_CRUD # 
# moved to LDAP_CRUD # #
# moved to LDAP_CRUD # ## HERE WE NEED TO SET FLAG TO CREATE BRANCH FOR LOCALIZED VERSION OF DATA
# moved to LDAP_CRUD # ## associatedService=localization-ru,uid=U...-user01,ou=People,dc=ibs
# moved to LDAP_CRUD # ## associatedService=localization-uk,uid=U...-user01,ou=People,dc=ibs
# moved to LDAP_CRUD # ## e.t.c.
# moved to LDAP_CRUD # #
# moved to LDAP_CRUD # 
# moved to LDAP_CRUD #   my ( $givenName, $l, $o, $pwd, $tr );
# moved to LDAP_CRUD #   if ($self->is_ascii($attrs->{'fname'})) {
# moved to LDAP_CRUD #     $givenName = $self->cyr2lat({ to_translate => $attrs->{'fname'} });
# moved to LDAP_CRUD #   } else {
# moved to LDAP_CRUD #     $givenName = $attrs->{'fname'};
# moved to LDAP_CRUD #   };
# moved to LDAP_CRUD # 
# moved to LDAP_CRUD #   if ($self->is_ascii($attrs->{'l'})) {
# moved to LDAP_CRUD #     $l = $self->utf2lat({ to_translate => $attrs->{'l'} });
# moved to LDAP_CRUD #   } else {
# moved to LDAP_CRUD #     $l = $attrs->{'l'};
# moved to LDAP_CRUD #   };
# moved to LDAP_CRUD # 
# moved to LDAP_CRUD #   if ($self->is_ascii($attrs->{'org'})) {
# moved to LDAP_CRUD #     $o = $self->cyr2lat({ to_translate => $attrs->{'org'} });
# moved to LDAP_CRUD #   } else {
# moved to LDAP_CRUD #     $o = $attrs->{'org'};
# moved to LDAP_CRUD #   };
# moved to LDAP_CRUD # 
# moved to LDAP_CRUD #   my $attr_defined = [];
# moved to LDAP_CRUD #   foreach my $key (keys %{$attrs}) {
# moved to LDAP_CRUD #     $tr = $self->is_ascii( $attrs->{$key} ) ?
# moved to LDAP_CRUD #       $self->utf2lat( $attrs->{$key} ) : $attrs->{$key};
# moved to LDAP_CRUD #     push @{$attr_defined}, $key => $tr
# moved to LDAP_CRUD #       if defined $attrs->{$key} && $attrs->{$key} ne '' && $key ne 'submit' && $key ne 'parent';
# moved to LDAP_CRUD #   }
# moved to LDAP_CRUD #   push @{$attr_defined}, objectClass => [ 'top', 'organizationalUnit' ];
# moved to LDAP_CRUD # 
# moved to LDAP_CRUD # #  $c->log->debug( "parent\n: $attrs->{'parent'} \nattr_defined:\n" . Dumper($attr_defined));
# moved to LDAP_CRUD #   my $success_message;
# moved to LDAP_CRUD # 
# moved to LDAP_CRUD #   ######################################################################
# moved to LDAP_CRUD #   # ORGANIZATION Object
# moved to LDAP_CRUD #   ######################################################################
# moved to LDAP_CRUD #   my $base = $attrs->{'parent'} != 0 ? $attrs->{'parent'} : 'ou=Organizations,dc=ibs';
# moved to LDAP_CRUD #   my $ldif =
# moved to LDAP_CRUD #     $ldap_crud->add(
# moved to LDAP_CRUD # 		    sprintf('ou=%s,%s', $attrs->{'ou'}, $base),
# moved to LDAP_CRUD # 		    $attr_defined,
# moved to LDAP_CRUD # 		   );
# moved to LDAP_CRUD #   my $error_message;
# moved to LDAP_CRUD #   if ( $ldif ) {
# moved to LDAP_CRUD #     $error_message = 'Error during organization object creation occured: ' . $ldif;
# moved to LDAP_CRUD #     $c->log->error('ou=' . $attrs->{'ou'} .
# moved to LDAP_CRUD # 		   ',ou=Organizations,dc=ibs' .
# moved to LDAP_CRUD # 		   " obj wasn not created: " . $ldif);
# moved to LDAP_CRUD #   }
# moved to LDAP_CRUD # 
# moved to LDAP_CRUD #   my $final_message;
# moved to LDAP_CRUD #   $final_message = '<div class="alert alert-success">' .
# moved to LDAP_CRUD #     '<span style="font-size: 140%" class="glyphicon glyphicon-ok-sign"></span>' .
# moved to LDAP_CRUD #       '&nbsp;<em>Object for organization ' .
# moved to LDAP_CRUD # 	' &laquo;' . $self->cyr2lat({ to_translate => $attrs->{'physicaldeliveryofficename'} }) .
# moved to LDAP_CRUD # 	  '&raquo;</em> successfully created.</div>' if $success_message;
# moved to LDAP_CRUD # 
# moved to LDAP_CRUD #   $final_message .= '<div class="alert alert-danger">' .
# moved to LDAP_CRUD #     '<span style="font-size: 140%" class="icon_error-oct" aria-hidden="true"></span>&nbsp;' .
# moved to LDAP_CRUD #       $error_message . '</div>' if $error_message;
# moved to LDAP_CRUD # 
# moved to LDAP_CRUD #   $self->form->info_message( $final_message ) if $final_message;
# moved to LDAP_CRUD # 
# moved to LDAP_CRUD #   $ldap_crud->unbind;
# moved to LDAP_CRUD #   return $ldif;
# moved to LDAP_CRUD # }


=head1 AUTHOR

Charlie &

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;

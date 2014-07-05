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
      # # $self->form->info_message( $res ) if $res;
      # $self->form->add_form_error( $res ) if $res;
# moved to LDAP_CRUD # my $res = $self->create_object( $c );
      # $c->log->debug( "create_object (from umi_o_add) error: " . $res) if $res;
    } else {
      $c->response->body('Unauthorized!');
    }
}

=head2 create_object

=cut


=head1 AUTHOR

Charlie &

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;

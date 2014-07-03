# -*- mode: cperl -*-
#

package UMI::Controller::LDAP_organization_select;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; with 'Tools'; }

use UMI::Form::LDAP_organization_select;
use UMI::LDAP_CRUD;

has 'form' => ( isa => 'UMI::Form::LDAP_organization_select', is => 'rw',
		lazy => 1,
		default => sub {
		    UMI::Form::LDAP_organization_select->new('form_element_class' => 'form-horizontal') 
		},
		documentation => q{Form to add/mod/del organization/s},
	      );

=head1 NAME

UMI::Controller::LDAP_organization_select - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 index

=cut

sub index :Path :Args(0) {
    my ( $self, $c, $ldap_org_id ) = @_;
    if ( $c->check_user_roles('umi-admin')) {
      $c->stash(
		template => 'ldapact/ldapact_o_node.tt',
		form => $self->form
	       );

      my $ldap_crud =
	$c->model('LDAP_CRUD',
		  uid => $c->session->{umi_ldap_uid},
		  pwd => $c->session->{umi_ldap_password}
		 );

      # Validate and insert/update database
      return unless $self->form->process( item_id => $ldap_org_id,
					  posted => ($c->req->method eq 'POST'),
					  params => $c->req->parameters,
					  ldap_crud => $ldap_crud,
					);


      my ( $error_message, $success_message, $message);

      if ( ! $c->req->param('act') ) {

	$c->log->debug( "we will add new Organization object");
	$c->res->redirect($c->uri_for('/ldap_organization_add'));

      } elsif ( $c->req->param('act') == 1 ) {

	$c->log->debug( "we will modify object " . $c->req->param('org'));
	$c->controller('LDAP_organization_mod')->index($c, ( org => $c->req->param('org') ));

      } elsif ( $c->req->param('act') == 2 ) {

	my $delete_result = $ldap_crud->del( $c->req->param('org') );
	if ($delete_result) {
	  $error_message = '<li>&laquo;<strong>' . $c->req->param('org') .
	    '</strong>&raquo; <em>was not deleted; error is:</em> &laquo;<strong>' .
	      $delete_result  . '</strong>&raquo;</li>';
	  $c->log->debug( $delete_result );
	} else {
	  $success_message = '<li>&laquo;<strong>' . $c->req->param('org') .
	    '</strong>&raquo; <em>was successfully deleted.</em></li>';
	  $self->form->success_message( $success_message );
	  $c->res->redirect($c->uri_for('/ldap_organization_select'));

	}
      }

      $ldap_crud->unbind;

      my $final_message;
      $final_message = '<div class="alert alert-success">' .
	'<span style="font-size: 140%" class="glyphicon glyphicon-ok-sign"></span>' .
	  '&nbsp;<em>Operation complete.</em><ul>' . $success_message . '<ul></div>' if $success_message;

      $final_message .= '<div class="alert alert-danger">' .
	'<span style="font-size: 140%" class="icon_error-oct" aria-hidden="true"></span><ul>' .
	  $error_message . '</ul></div>' if $error_message;

      $self->form->info_message( $final_message ) if $final_message;

    } else {
      $c->response->body('Unauthorized!');
    }
}

=head2 create_account

=cut


sub add :Path(add) :Args(0) {
  my ( $self, $c, $ldap_org_id ) = @_;
  if ( $c->check_user_roles('umi-admin')) {
    # use Data::Dumper;

    $c->stash( template => 'ldapact/ldapact_o_add_node.tt',
	       form => $self->form );

    # Validate and insert/update database
    return unless
      $self->form->process( item_id => $ldap_org_id,
			    posted => ($c->req->method eq 'POST'),
			    params => $c->req->parameters,
			    ldap_crud => $c->model('LDAP_CRUD'),
			  );
  } else {
    $c->response->body('Unauthorized!');
  }
}

=head1 AUTHOR

Zeus

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

no Moose;
__PACKAGE__->meta->make_immutable;

1;

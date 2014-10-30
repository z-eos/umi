# -*- mode: cperl -*-
#

package UMI::Controller::Org;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; with 'Tools'; }

use UMI::Form::Org;

=head1 NAME

UMI::Controller::Org - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


has 'form' => (
	       isa => 'UMI::Form::Org', is => 'rw',
	       lazy => 1, documentation => q{Form to add organization/s},
	       default => sub { UMI::Form::Org->new },
	      );


=head2 index

strictly speaking - new object creation (ldapadd)

=cut


sub index :Path :Args(0) {
    my ( $self, $c, $ldap_org_id ) = @_;
    if ( $c->check_user_roles('wheel')) {
      $c->stash( template => 'org/org_wrap.tt',
		 form => $self->form );

      return unless
	$self->form->process(
			     item_id => $ldap_org_id,
			     posted => ($c->req->method eq 'POST'),
			     params => $c->req->parameters,
			     ldap_crud => $c->model('LDAP_CRUD'),
# to remove after confirm, it is not needed # 	use_defaults_over_obj => 1,
# to remove after confirm, it is not needed # 	defaults => {
# to remove after confirm, it is not needed # 			  businessCategory => 'it',
# to remove after confirm, it is not needed # 			 },
			    );
    } elsif ( defined $c->session->{"auth_uid"} ) {
      if ( defined $c->session->{'unauthorized'}->{ $c->action } ) {
	$c->session->{'unauthorized'}->{ $c->action } += 1;
      } else {
	$c->session->{'unauthorized'}->{ $c->action } = 1;
      }
      $c->stash( 'template' => 'unauthorized.tt',
		 'unauth_action' => $c->action, );
    } else {
      $c->stash( template => 'signin.tt', );
    }
}

=head2 modify

=cut

sub modify :Path(/ldap_organization_add/modify) :Args(0) {
    use Data::Printer; # colored => 1, caller_info => 1;
    warn "########## \@_ ##########\n" . p(@_);

    my ( $self, $c, $key, $val ) = @_;

    if ( $c->check_user_roles('umi-admin')) {
      my $selected = $c->req->parameters;

      my @dn_parts = split(/,/, $selected->{'org'});
      my $filter = splice(@dn_parts, 0, 1);
      my $base = join(',',@dn_parts);
      my $mesg =
	$c->model('LDAP_CRUD')->search(
				       {
					base => $base,
					scope => 'one',
					filter => $filter,
				       }
				      );
      my @entries = $mesg->entries;
      my ( $entry, $attr, $params );
      foreach $entry ( @entries ) {
	foreach $attr ( sort $entry->attributes ) {
	  next if ( $attr =~ /^object/ );
	  next if $attr =~ /^$c->model('LDAP_CRUD')->{'cfg'}->{'exclude_prefix'}/;
	  next if $attr eq ( 'org' || 'act' );
	  $params->{$attr} = $entry->get_value ( $attr );
	}
      }
      if ( $base eq $c->model('LDAP_CRUD')->{'cfg'}->{'base'}->{'org'} ) {
	$params->{'aux_parent'} = 0;
      } else {
	$params->{'aux_parent'} = $base;
      }

      $c->stash( template => 'ldapact/ldapact_o_add_node.tt',
		 form => $self->form );

      return unless
	$self->form->process(
			     item => { act => 'modify' },
			     posted => ($c->req->method eq 'POST'),
			     params => $params,
			     ldap_crud => $c->model('LDAP_CRUD'),
			    );
      # $c->detach('Org', 'modify', org => $c->req->param('org') );
    } else {
      $c->response->body('Unauthorized!');
    }
}




=head1 AUTHOR

Charlie &

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;

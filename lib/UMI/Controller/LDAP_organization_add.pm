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

strictly speaking - new object creation (ldapadd)

=cut


sub index :Path :Args(0) {
    my ( $self, $c, $ldap_org_id ) = @_;
    if ( $c->check_user_roles('umi-admin')) {
      $c->stash( template => 'ldapact/ldapact_o_add_node.tt',
		 form => $self->form );

      return unless
	$self->form->process(
			     item => $c->model('LDAP_CRUD')
			     ->obj_add(
			     	       {
			     		'type' => 'org',
			     		'params' => $c->req->parameters,
			     	       }
			     	      ),
			     posted => ($c->req->method eq 'POST'),
			     params => $c->req->parameters,
			     ldap_crud => $c->model('LDAP_CRUD'),
# to remove after confirm, it is not needed # 	use_defaults_over_obj => 1,
# to remove after confirm, it is not needed # 	defaults => {
# to remove after confirm, it is not needed # 			  businessCategory => 'it',
# to remove after confirm, it is not needed # 			 },
			    );
    } else {
      $c->response->body('Unauthorized!');
    }
}

=head2 modify

=cut

sub modify :Path(/ldap_organization_modify) :Args(0) {
    my ( $self, $c, $ldap_org_id ) = @_;
    if ( $c->check_user_roles('umi-admin')) {
      my $selected = $c->req->parameters;

      my @dn_parts = split(/,/,$selected->{'org'});
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
	  warn 'EACH ATTR: ' . $attr . '; IS: ' . $params->{$attr} . "\n";
	}
      }
      use Data::Dumper;
      warn '$params: ' . Dumper($params);
      if ( $base eq $c->model('LDAP_CRUD')->{'cfg'}->{'base'}->{'org'} ) {
	$params->{'aux_parent'} = 0;
      } else {
	$params->{'aux_parent'} = $base;
      }

      $c->stash( template => 'ldapact/ldapact_o_add_node.tt',
		 form => $self->form );

      return unless
	$self->form->process(
			     item => $c->model('LDAP_CRUD')
			     ->obj_mod(
			     	       {
			     		'type' => 'org',
			     		'params' => $params,
			     	       }
			     	      ),
			     posted => ($c->req->method eq 'POST'),
			     params => $params,
			     ldap_crud => $c->model('LDAP_CRUD'),
			    );
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

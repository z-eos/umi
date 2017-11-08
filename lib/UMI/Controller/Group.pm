# -*- mode: cperl -*-
#

package UMI::Controller::Group;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; with 'Tools'; }

use Data::Printer;

use UMI::Form::Group;

has 'form' => ( isa => 'UMI::Form::Group', is => 'rw',
		lazy => 1, default => sub { UMI::Form::Group->new },
		documentation => q{Form to add new, nonexistent user account/s},
	      );

=head1 NAME

UMI::Controller::Group - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 index

=cut

sub index :Path :Args(0) {
    my ( $self, $c, $ldapadduser_id ) = @_;
    # if ( $c->check_user_roles('wheel')) {
      # use Data::Dumper;

      $c->stash( template => 'group/group_wrap.tt',
		 form => $self->form );

      my $params = $c->req->parameters;

      return unless $self->form->process( item_id => $ldapadduser_id,
					  posted => ($c->req->method eq 'POST'),
					  params => $params,
					  ldap_crud => $c->model('LDAP_CRUD'),
					);

      $c->stash( final_message => $self->create_group($c->model('LDAP_CRUD'),
						      {
						       cn => $params->{cn},
						       descr => $params->{descr},
						       memberUid => $params->{memberUid},
						      }),
	       );

    # } elsif ( defined $c->session->{"auth_uid"} ) {
    #   if (defined $c->session->{'unauthorized'}->{ $c->action } ) {
    # 	$c->session->{'unauthorized'}->{ $c->action } += 1;
    #   } else {
    # 	$c->session->{'unauthorized'}->{ $c->action } = 1;
    #   }
    #   $c->stash( 'template' => 'unauthorized.tt',
    # 		 'unauth_action' => $c->action, );
    # } else {
    #   $c->stash( template => 'signin.tt', );
    # }
}

=head2 create_group

=cut

sub create_group {
    my  ( $self, $ldap_crud, $args ) = @_;

    my $arg = {
	       cn => $args->{cn},
	       description => $args->{descr} || 'description-stub',
	       memberUid => $args->{memberUid} || undef,
	      };

    # p $args;

    my $memberUid;
    if ( ref($arg->{memberUid}) eq 'ARRAY' ) {
      $memberUid = $arg->{memberUid};
    } else {
      push @{$memberUid}, $arg->{memberUid};
    }

    my $group_attrs = [
		       'objectClass' => $ldap_crud->cfg->{objectClass}->{group},
		       'description' => $arg->{description},
		       'gidNumber' => $ldap_crud->last_gidNumber + 1,
		       'memberUid' => $memberUid,
		      ];
    my $mesg =
      $ldap_crud->add(
		      sprintf('cn=%s,%s', $arg->{cn}, $ldap_crud->cfg->{base}->{group}),
		      $group_attrs
    		     );

    my $return;
    if ( $mesg ) {
      $return->{error} = sprintf('group <em><b>%s</b></em> creation error occured %s',
				 $arg->{cn},
				 $mesg);
    } else {
      $return->{success} = sprintf('group <em><b>%s</b></em> was created successfully',
				   $arg->{cn});
    }
    return $return;
}



=head1 AUTHOR

Zeus

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;

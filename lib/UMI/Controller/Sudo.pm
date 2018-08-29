# -*- mode: cperl -*-
#

package UMI::Controller::Sudo;
use Moose;
use namespace::autoclean;
use Data::Printer colored => 0;
use Logger;

BEGIN { extends 'Catalyst::Controller'; with 'Tools'; }

use UMI::Form::Sudo;
has 'form' => ( isa => 'UMI::Form::Sudo', is => 'rw',
		lazy => 1, default => sub { UMI::Form::Sudo->new },
		documentation => q{Form to add SUDOers},
	      );

=head1 NAME

UMI::Controller::Sudo - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 index

=cut

sub index :Path :Args(0) {
    my ( $self, $c ) = @_;
    my $params = $c->req->parameters;
    # log_debug { np($params) };
    my $ldap_crud = $c->model('LDAP_CRUD');

    $c->stash( template => 'sudo/sudo.tt',
	       form     => $self->form );

    return unless $self->form->process(
				       posted => ($c->req->method eq 'POST'),
				       params => $params,
				       ldap_crud => $ldap_crud,
				      );

    my $entry = $self->attributes($ldap_crud->cfg->{objectClass}->{sudo}, $params);
    if ( defined $params->{aux_dn_form_to_modify} && $params->{aux_dn_form_to_modify} ne '' ) {
      $entry->{dn}                    = $params->{aux_dn_form_to_modify};
      $entry->{aux_dn_form_to_modify} = $params->{aux_dn_form_to_modify};
      my $tmp = $c->controller('SearchBy')->modify($c, $entry);
      # log_debug { np($params) };
      $c->stash( final_message => $tmp );
    } else {
      $c->stash( final_message => $self->add( $ldap_crud, $entry), );
    }
}

=head2 attributes

prepare object attributes set, to process

returns hash of the object attributes with values ready to be used
with add

=cut

sub attributes {
    my  ( $self, $objectClass, $args ) = @_;
    # log_debug { np($args) };
    my $attributes = { cn             => $args->{cn},
		       objectClass    => $objectClass, };

    $attributes->{description}    = $args->{description}    if defined $args->{description};
    $attributes->{sudoHost}       = $args->{sudoHost}       if defined $args->{sudoHost};
    $attributes->{sudoRunAsGroup} = $args->{sudoRunAsGroup} if defined $args->{sudoRunAsGroup};
    $attributes->{sudoRunAsUser } = $args->{sudoRunAsUser}  if defined $args->{sudoRunAsUser};
    $attributes->{sudoUser}       = $args->{sudoUser}       if defined $args->{sudoUser};

    foreach my $com ( $self->form->field('com')->fields ) {
      log_debug { np($com) };
      foreach my $com_row ( $com->fields ) {
	push @{$attributes->{sudoCommand}}, $com_row->value // ''
	  if $com_row->name eq 'sudoCommand';
      }
    }

    foreach my $opt ( $self->form->field('opt')->fields ) {
      foreach my $opt_row ( $opt->fields ) {
	push @{$attributes->{sudoOption}}, $opt_row->value // ''
	  if $opt_row->name eq 'sudoOption';
      }
    }

    log_debug { np($attributes) };
    return $attributes;
}

=head2 add

add object

=cut

sub add {
    my  ( $self, $ldap_crud, $args ) = @_;
    my @arr = map { $_ => $args->{$_} } keys(%{$args});
    # log_debug { np( @arr ) };

    my $mesg =
      $ldap_crud->add( sprintf('cn=%s,%s', $args->{cn}, $ldap_crud->cfg->{base}->{sudo}),
		       \@arr );

    my $return;
    if ( $mesg ) {
      $return->{error} = sprintf('netgroup <em><b>%s</b></em> creation error occured %s',
				 $args->{cn},
				 $mesg->{html});
    } else {
      $return->{success} = sprintf('SUDOer <em><b>%s</b></em> was created successfully',
				   $args->{cn});
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

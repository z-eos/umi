# -*- mode: cperl -*-
#

package UMI::Controller::Org;
use Moose;
use namespace::autoclean;
use Data::Printer colored => 0, caller_info => 1;
use Logger;

BEGIN { extends 'Catalyst::Controller'; with 'Tools'; }

use UMI::Form::Org;
has 'form' => ( isa => 'UMI::Form::Org', is => 'rw',
		lazy => 1, documentation => q{Form to add organization/s},
		default => sub { UMI::Form::Org->new },
	      );

=head1 NAME

UMI::Controller::Org - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 index

new Organization/Office object creation

=cut


sub index :Path :Args(0) {
  my ( $self, $c ) = @_;
  my $params = $c->req->parameters;
  my $ldap_crud = $c->model('LDAP_CRUD');

  $c->stash( template => 'org/org_wrap.tt',
	     form     => $self->form );

  return unless $self->form->process(
				     posted => ($c->req->method eq 'POST'),
				     params => $params,
				     ldap_crud => $ldap_crud,
				    );

  my $entry = $self->attributes($ldap_crud->cfg->{objectClass}->{org}, $params);
  log_debug { np($entry) };

  if ( defined $params->{aux_dn_form_to_modify} && $params->{aux_dn_form_to_modify} ne '' ) {
    $entry->{dn}                    = $params->{aux_dn_form_to_modify};
    $entry->{aux_dn_form_to_modify} = $params->{aux_dn_form_to_modify};
    my $tmp = $c->controller('SearchBy')->modify($c, $entry);
    log_debug { np($tmp) };
    # $c->stash( final_message => $tmp );
  } else {
    $c->stash( final_message => $self->add( $ldap_crud, $entry), );
    # $c->stash( final_message => $c->model('LDAP_CRUD')
    # 	       ->obj_add({ type => 'org',
    # 			   params => $params,
    # 			 }));
  }
}

=head2 attributes

prepare object attributes set, to process

returns hash of the object attributes with values

=cut

sub attributes {
    my  ( $self, $objectClass, $args ) = @_;
    my $attributes = { cn          => $args->{cn},
		       description => $args->{description} || 'description-stub',
		       objectClass => $objectClass,
		       memberNisNetgroup => $args->{memberNisNetgroup} || undef, };

    if ( defined $attributes->{memberNisNetgroup} && $attributes->{memberNisNetgroup} ne '' ) {
      my $memberNisNetgroup;
      if ( ref($attributes->{memberNisNetgroup}) eq 'ARRAY' ) {
	$memberNisNetgroup = $attributes->{memberNisNetgroup};
      } else {
	push @{$memberNisNetgroup}, $attributes->{memberNisNetgroup};
      }
      $attributes->{memberNisNetgroup} = $memberNisNetgroup;
    }

    my $triple;
    my $a = undef;
    my $b = undef;
    # log_debug { np($self->form->field('triple')->fields) };
    foreach my $triple_part ( $self->form->field('triple')->fields ) {
      foreach ( $triple_part->fields ) {
	# log_debug { np($_->value) };
	next if $_->name eq 'rm-duplicate' || $_->name eq 'remove';
	push @{$a}, $_->value // '';
      }
      $triple = '(' . join(',', @{$a}) . ')';
      $a = undef;
      push @{$b}, $triple if $triple ne '(,,)';
    }

    $attributes->{nisNetgroupTriple} = $b if defined $b;

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
      $ldap_crud->add( sprintf('ou=%s,%s', $args->{ou}, $ldap_crud->cfg->{base}->{org}),
		       \@arr );

    my $return;
    if ( $mesg ) {
      $return->{error} = sprintf('Org <em><b>%s</b></em> creation error occured %s',
				 $args->{ou},
				 $mesg->{html});
    } else {
      $return->{success} = sprintf('Org <em><b>%s</b></em> was created successfully',
				   $args->{ou});
    }
    return $return;
}

=head1 AUTHOR

Charlie &

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;

# -*- mode: cperl -*-
#

package UMI::Controller::NisNetgroup;
use Moose;
use namespace::autoclean;
use Data::Printer colored => 0;
use Logger;

BEGIN { extends 'Catalyst::Controller'; with 'Tools'; }

use UMI::Form::NisNetgroup;
has 'form' => ( isa => 'UMI::Form::NisNetgroup', is => 'rw',
		lazy => 1, default => sub { UMI::Form::NisNetgroup->new },
		documentation => q{Form to add NIS netGroup},
	      );

=head1 NAME

UMI::Controller::NisNetgroup - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 index

=cut

sub index :Path :Args(0) {
    my ( $self, $c ) = @_;
    my $params = $c->req->parameters;
    my $ldap_crud = $c->model('LDAP_CRUD');

    $c->stash( template => 'nis/nisnetgroup.tt',
	       form     => $self->form );

    return unless $self->form->process(
				       posted => ($c->req->method eq 'POST'),
				       params => $params,
				       ldap_crud => $ldap_crud,
				      );

    my $entry = $self->attributes($ldap_crud->cfg->{objectClass}->{netgroup}, $params);

    if ( defined $params->{aux_dn_form_to_modify} && $params->{aux_dn_form_to_modify} ne '' ) {
      $entry->{dn}                    = $params->{aux_dn_form_to_modify};
      $entry->{aux_dn_form_to_modify} = $params->{aux_dn_form_to_modify};
      my $tmp = $c->controller('SearchBy')->modify($c, $entry);
      log_debug { np($tmp) };
      # $c->stash( final_message => $tmp );
    } else {
      $c->stash( final_message => $self->add( $ldap_crud, $entry), );
    }
    log_debug { np($entry) };
}

=head2 attributes

prepare object attributes set, to process

returns hash of the object attributes with values

=cut

sub attributes {
    my  ( $self, $objectClass, $args ) = @_;
    my $attributes = { cn          => $args->{cn},
		       objectClass => $objectClass,
		       memberNisNetgroup => $args->{memberNisNetgroup} || undef, };

    $attributes->{description} = $args->{description} if defined $args->{description};

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
	log_debug { np($_->name) };
	log_debug { np($_->value) };
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
      $ldap_crud->add( sprintf('cn=%s,%s', $args->{cn}, $ldap_crud->cfg->{base}->{netgroup}),
		       \@arr );

    my $return;
    if ( $mesg ) {
      $return->{error} = sprintf('netgroup <em><b>%s</b></em> creation error occured %s',
				 $args->{cn},
				 $mesg->{html});
    } else {
      $return->{success} = sprintf('netgroup <em><b>%s</b></em> was created successfully',
				   $args->{cn});
    }
    return $return;
}

# sub create_nisnetgroup {
#     my  ( $self, $ldap_crud, $args ) = @_;

#     my $arg = {
# 	       cn => $args->{cn},
# 	       description => $args->{descr} || 'description-stub',
# 	       memberNisNetgroup => $args->{memberNisNetgroup} || undef,
# 	      };

#     my $netgroup_attrs = [
# 			  'objectClass' => $ldap_crud->cfg->{objectClass}->{netgroup},
# 			  'description' => $arg->{description},
# 			 ];

#     if ( defined $arg->{memberNisNetgroup} && $arg->{memberNisNetgroup} ne '' ) {
#       my $memberNisNetgroup;
#       if ( ref($arg->{memberNisNetgroup}) eq 'ARRAY' ) {
# 	$memberNisNetgroup = $arg->{memberNisNetgroup};
#       } else {
# 	push @{$memberNisNetgroup}, $arg->{memberNisNetgroup};
#       }
#       push @{$netgroup_attrs}, 'memberNisNetgroup' => $memberNisNetgroup;
#     }

#     my $netgroup_triple;
#     my $a = undef;
#     my $b = undef;
#     foreach my $element ( $self->form->field('triple')->fields ) {
#       foreach ( $element->fields ) {
# 	next if $_->name eq 'rm-duplicate' || $_->name eq 'remove';
# 	push @{$a}, $_->value;
#       }
#       $netgroup_triple = '(' . join(',', @{$a}) . ')';
#       $a = undef;
#       push @{$b}, $netgroup_triple if $netgroup_triple ne '(,,)';
#     }

#     push @{$netgroup_attrs}, nisNetgroupTriple => $b if defined $b;

#     my $mesg =
#       $ldap_crud->add(
# 		      sprintf('cn=%s,%s', $arg->{cn}, $ldap_crud->cfg->{base}->{netgroup}),
# 		      $netgroup_attrs
#     		     );

#     my $return;
#     if ( $mesg ) {
#       $return->{error} = sprintf('netgroup <em><b>%s</b></em> creation error occured %s',
# 				 $arg->{cn},
# 				 $mesg->{html});
#     } else {
#       $return->{success} = sprintf('netgroup <em><b>%s</b></em> was created successfully',
# 				   $arg->{cn});
#     }
#     return $return;
# }



=head1 AUTHOR

Zeus

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;

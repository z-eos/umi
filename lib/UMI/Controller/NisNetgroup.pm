# -*- mode: cperl -*-
#

package UMI::Controller::NisNetgroup;
use Moose;
use namespace::autoclean;
use Data::Printer colored => 0;

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


    $c->stash( template => 'nis/nisnetgroup.tt',
	       form => $self->form );

    return unless $self->form->process(
				       posted => ($c->req->method eq 'POST'),
				       params => $params,
				       ldap_crud => $c->model('LDAP_CRUD'),
				      );

    $c->stash( final_message => $self->create_nisnetgroup( $c->model('LDAP_CRUD'),
							   $params,
							   ), );
}

=head2 create_group

=cut

sub create_nisnetgroup {
    my  ( $self, $ldap_crud, $args ) = @_;

    my $arg = {
	       cn => $args->{cn},
	       description => $args->{descr} || 'description-stub',
	       memberNisNetgroup => $args->{memberNisNetgroup} || undef,
	      };

    my $memberNisNetgroup;
    if ( ref($arg->{memberNisNetgroup}) eq 'ARRAY' ) {
      $memberNisNetgroup = $arg->{memberNisNetgroup};
    } else {
      push @{$memberNisNetgroup}, $arg->{memberNisNetgroup};
    }

    my $netgroup_attrs = [
		       'objectClass' => $ldap_crud->cfg->{objectClass}->{netgroup},
		       'description' => $arg->{description},
		       'memberNisNetgroup' => $memberNisNetgroup,
			 ];

    my $netgroup_triple;
    my $a = undef;
    my $b = undef;
    foreach my $element ( $self->form->field('triple')->fields ) {
      foreach ( $element->fields ) {
	next if $_->name eq 'rm-duplicate';
	push @{$a}, $_->value;
      }
      $netgroup_triple = '(' . join(',', @{$a}) . ')';
      $a = undef;
      push @{$b}, $netgroup_triple if $netgroup_triple ne '(,,)';
    }

    push @{$netgroup_attrs}, nisNetgroupTriple => $b if defined $b;
    # use Data::Printer colored => 0;
    # my $c;
    # p($netgroup_attrs, colored => 0, output => \$c );
    # return { success => '<pre>' . $c . '</pre>', };

    my $mesg =
      $ldap_crud->add(
		      sprintf('cn=%s,%s', $arg->{cn}, $ldap_crud->cfg->{base}->{netgroup}),
		      $netgroup_attrs
    		     );

    my $return;
    if ( $mesg ) {
      $return->{error} = sprintf('netgroup <em><b>%s</b></em> creation error occured %s',
				 $arg->{cn},
				 $mesg->{html});
    } else {
      $return->{success} = sprintf('netgroup <em><b>%s</b></em> was created successfully',
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

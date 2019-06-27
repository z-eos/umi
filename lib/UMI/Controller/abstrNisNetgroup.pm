# -*- mode: cperl -*-
#

package UMI::Controller::abstrNisNetgroup;
use Moose;
use namespace::autoclean;
use Data::Printer colored => 0;
use Logger;

BEGIN { extends 'Catalyst::Controller'; with 'Tools'; }

use UMI::Form::abstrNisNetgroup;
has 'form' => ( isa => 'UMI::Form::abstrNisNetgroup', is => 'rw',
		lazy => 1, default => sub { UMI::Form::abstrNisNetgroup->new },
		documentation => q{Form to add NIS netGroup},
	      );

=head1 NAME

UMI::Controller::abstrNisNetgroup - Catalyst Controller

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

    $c->stash( template => 'nis/abstr_nis_netgroup.tt',
	       form     => $self->form );

    if ( keys %{$params} > 0 ) {
      return unless
	$self->form->process( posted      => ($c->req->method eq 'POST'),
			      params      => $params,
			      init_object => { aux_dn_form_to_modify => $params->{aux_dn_form_to_modify}, },
			      ldap_crud   => $ldap_crud, );
    } else {
    
      return unless $self->form->process( posted    => ($c->req->method eq 'POST'),
					  params    => $params,
					  ldap_crud => $ldap_crud, );
    }
    my $entry = $self->attributes($ldap_crud->cfg->{objectClass}->{netgroup}, $params);
    # log_debug { np($entry) };
    # log_debug { np($params) };
    if ( defined $params->{aux_dn_form_to_modify} && $params->{aux_dn_form_to_modify} ne '' ) {
      $entry->{dn}                    = $params->{aux_dn_form_to_modify};
      $entry->{aux_dn_form_to_modify} = $params->{aux_dn_form_to_modify};
      delete $entry->{netgroup}; # since no attribute `netgroup' exist

      my $tmp = $c->controller('SearchBy')->modify($c, $entry);
      log_debug { np($tmp) };
      ## $c->stash( final_message => $tmp );
    } else {
      $c->stash( final_message => $self->add( $ldap_crud, $entry), );
    }
    # log_debug { np($entry) };
}

=head2 attributes

prepare object attributes set, to process

returns hash of the object attributes with values

=cut

sub attributes {
  my ( $self, $objectClass, $args ) = @_;
  # log_debug { np($args) };
  my $attributes = { cn          => $args->{cn},
		     objectClass => $objectClass, };
  my ($host_split, $host, $uid);
  $attributes->{description} = $args->{description}
    if defined $args->{description} && $args->{description} ne '';

  $attributes->{associatedDomain} = $args->{associatedDomain};
  $attributes->{netgroup} = $args->{netgroup};
  $attributes->{memberNisNetgroup} = $args->{ng_access}   if exists $args->{ng_access};
  $attributes->{memberNisNetgroup} = $args->{ng_category} if exists $args->{ng_category};

  my $nisNetgroupTriple;
  if ( ref($args->{uids}) eq 'ARRAY' && ref($args->{associatedDomain}) eq 'ARRAY' ) {
    foreach $uid ( @{$args->{uids}} ) {
      foreach $host ( @{$args->{associatedDomain}} ) {
	$host_split = $self->nisnetgroup_host_split($host);
	push @{$attributes->{nisNetgroupTriple}},
	  sprintf("(%s,%s,%s)",
		  $host_split->[0],
		  $uid,
		  $host_split->[1]);
      }
    }
  } elsif ( ref($args->{uids}) eq 'ARRAY' && ref($args->{associatedDomain}) ne 'ARRAY' ) {
    $host_split = $self->nisnetgroup_host_split($args->{associatedDomain});
    foreach ( @{$args->{uids}} ) {
      push @{$attributes->{nisNetgroupTriple}},
	sprintf("(%s,%s,%s)",
		$host_split->[0],
		$_,
		$host_split->[1]);
    }
  } elsif ( ref($args->{uids}) ne 'ARRAY' && ref($args->{associatedDomain}) eq 'ARRAY' ) {
    foreach ( @{$args->{associatedDomain}} ) {
      $host_split = $self->nisnetgroup_host_split($_);
      push @{$attributes->{nisNetgroupTriple}},
	sprintf("(%s,%s,%s)",
		$host_split->[0],
		$args->{uids},
		$host_split->[1]);
    }
    $host_split = $self->nisnetgroup_host_split($args->{associatedDomain});
  } else {
    $host_split = $self->nisnetgroup_host_split($args->{associatedDomain});
    $attributes->{nisNetgroupTriple} = sprintf("(%s,%s,%s)", $host_split->[0], $args->{uids}, $host_split->[1]);
  }

  return $attributes;
}

=head2 add

add nisNetgroup object

=cut

sub add {
  my  ( $self, $ldap_crud, $args ) = @_;
  my $netgroup = $args->{netgroup};
  delete $args->{netgroup}; # since no attribute `netgroup' exist
  my @arr = map { $_ => $args->{$_} } keys(%{$args});
  # log_debug { np( @arr ) };

  my $mesg =
    $ldap_crud->add( sprintf('cn=%s,%s', $args->{cn}, $netgroup),
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


=head1 AUTHOR

Zeus

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;

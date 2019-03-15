# -*- mode: cperl -*-
#

package UMI::Controller::Sargon;
use Moose;
use namespace::autoclean;
use Data::Printer colored => 0;
use Logger;

use Net::LDAP::Util qw(ldap_explode_dn);

BEGIN { extends 'Catalyst::Controller'; with 'Tools'; }

use UMI::Form::Sargon;
has 'form' => ( isa => 'UMI::Form::Sargon', is => 'rw',
		lazy => 1, default => sub { UMI::Form::Sargon->new },
		documentation => q{Form to add NIS netGroup},
	      );

=head1 NAME

UMI::Controller::Sargon - Catalyst Controller

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

    $params->{'mount.0.mount'} = '' if ! $params->{'mount.0.mount'};
    
    my $ldap_crud = $c->model('LDAP_CRUD');

    $c->stash( template => 'sargon/sargon.tt',
	       form     => $self->form );

    if ( keys %{$params} > 0 ) {
      return unless
	$self->form->process( posted      => ($c->req->method eq 'POST'),
			      params      => $params,
			      init_object => { aux_dn_form_to_modify => $params->{aux_dn_form_to_modify}, },
			      ldap_crud => $ldap_crud, );
    } else {
    
      return unless $self->form->process( posted    => ($c->req->method eq 'POST'),
					  params    => $params,
					  ldap_crud => $ldap_crud, );
    }
    my $entry = $self->attributes($ldap_crud->cfg->{objectClass}->{sargon}, $params);
    log_debug { np($entry) };

    if ( defined $params->{aux_dn_form_to_modify} && $params->{aux_dn_form_to_modify} ne '' ) {
      $entry->{dn}                    = $params->{aux_dn_form_to_modify};
      $entry->{aux_dn_form_to_modify} = $params->{aux_dn_form_to_modify};

      my $tmp = $c->controller('SearchBy')->modify($c, $entry);
      # log_debug { np($tmp) };
    } else {
      $c->stash( final_message => $self->add( $ldap_crud,
					      $ldap_crud->cfg->{base}->{sargon},
					      $entry), );
    }
    # log_debug { np($entry) };
}

=head2 attributes

prepare object attributes set, to process

returns hash of the object attributes with values

=cut

sub attributes {
  my  ( $self, $objectClass, $args ) = @_;
  my $attributes;
  my $val;
  $attributes->{objectClass} = $objectClass;
  $attributes->{cn}          = $args->{cn};

  foreach (keys %{$args}) {
    next if $_ eq 'cn' || $_ eq 'priv' || $_ eq 'order' ||
      $_ =~ /^mount/ || $_ =~ /^max/ || $_ =~ /^aux/;
    $args->{$_} = [ $args->{$_} ] if ref($args->{$_}) ne 'ARRAY';
  }

  # log_debug { np($args) };
  
  if      (defined $args->{host}      && defined $args->{netgroups} ) {
    @{$val} = map { "%" . ldap_explode_dn($_, casefold => 'lower')->[0]->{cn} } @{$args->{netgroups}};
    $attributes->{sargonHost} = [ @{$args->{host}}, @{$val} ];
  } elsif (defined $args->{host}      && ! defined $args->{netgroups} ) {
    $attributes->{sargonHost} = $args->{host};
  } elsif (defined $args->{host}      && ! defined $args->{netgroups} ) {
    @{$attributes->{sargonHost}} = map { "%" . ldap_explode_dn($_, casefold => 'lower')->[0]->{cn} } @{$args->{netgroups}};
  }

  if      (defined $args->{uid}      && defined $args->{groups} ) {
    @{$val} = map { "+" . ldap_explode_dn($_, casefold => 'lower')->[0]->{cn} } @{$args->{groups}};
    $attributes->{sargonUser} = [ @{$args->{uid}}, @{$val} ];
  } elsif (defined $args->{uid}      && ! defined $args->{groups} ) {
    $attributes->{sargonUser} = $args->{uid};
  } elsif (defined $args->{uid}      && ! defined $args->{groups} ) {
    @{$attributes->{sargonUser}} = map { "+" . ldap_explode_dn($_, casefold => 'lower')->[0]->{cn} } @{$args->{groups}};
  }

  $attributes->{sargonAllow} = $args->{allow};
  $attributes->{sargonDeny}  = $args->{deny};
  $attributes->{sargonOrder} = $args->{order}
    if defined $args->{order};

  $attributes->{sargonAllowPrivileged} =
    defined $args->{priv} ? 'TRUE' : 'FALSE';

  $attributes->{sargonAllowCapability} = $args->{capab};

  push @{$attributes->{sargonMount}}, $_->field('mount')->value
    foreach ( $self->form->field('mount')->fields );

  return $attributes;
}

=head2 add

add nisNetgroup object

=cut

sub add {
  my  ( $self, $ldap_crud, $base, $attrs ) = @_;
  my @arr = map { $_ => $attrs->{$_} } keys(%{$attrs});
  # log_debug { np( @arr ) };

  my $mesg =
    $ldap_crud->add( sprintf('cn=%s,%s', $attrs->{cn}, $base),
		     \@arr );

  my $return;
  if ( $mesg ) {
    $return->{error} = sprintf('netgroup <em><b>%s</b></em> creation error occured %s',
			       $attrs->{cn},
			       $mesg->{html});
  } else {
    $return->{success} = sprintf('sargon object <em><b>%s</b></em> was created successfully',
				 $attrs->{cn});
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

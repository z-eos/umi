# -*- mode: cperl; mode: follow; -*-
#
## idea and main code is provided by Sergey Poznyakoff
#

package LDAP_NODE;
use Moose;
use namespace::autoclean;

use Carp;

sub has_subnodes { exists(shift->{subnode}) }

sub is_leaf { !shift->has_subnodes() }

sub locate_nearest {
  my $self = shift;
  my $arg;
  while ($arg = pop) {
    if (exists($self->{subnode}) && exists($self->{subnode}{$arg})) {
      $self = $self->{subnode}{$arg};
    } else {
      last;
    }
  }
  return ($self, @_, $arg);
}

sub locate {
  my ($found, @rest) = shift->locate_nearest(@_);
  if (@rest == 0) {
    return $found;
  }
}

sub subnode {
  my $self = shift;
  my $arg;
  while ($arg = shift) {
    if (exists($self->{subnode}) && exists($self->{subnode}{$arg})) {
      $self = $self->{subnode}{$arg};
    } else {
      return;
    }
  }
  return $self;
}

has 'dn'       => ( is => 'rw', isa => 'Str', lazy => 1, default => '' );

sub insert {
  my ($self, $dn) = @_;

  my ($found, @rest) = $self->locate_nearest(split /,/, $dn);
  my $dn_cur;
  if (@rest) {
    while (my $arg = pop @rest) {
      $dn_cur = $found->dn;
      $found->{subnode}{$arg} = LDAP_NODE->new();
      $found = $found->{subnode}{$arg};
      $dn_cur eq '' ? $found->dn($arg) : $found->dn( $arg . ',' . $dn_cur );
    }
  }
  # use Data::Printer;
  # p $self->dn;
  return $found
}

sub nodenames {
  my $self = shift;
  keys(%{$self->{subnode}}) if $self->has_subnodes;
}

sub as_string {
  my $self = shift;
  my $lev  = shift || 0;
  my $s    = '';
  if ($self->has_subnodes) {
    foreach my $k (sort $self->nodenames) {
      $s .= ' ' x $lev if $lev;
      $s .= $k;
      if ($self->{subnode}{$k}->has_subnodes) {
	$s .= ":\n";
	$s .= $self->{subnode}{$k}->as_string($lev + 1);
	chomp($s)
      } else {
	$s .= " (leaf)";
      }
      $s .= "\n";
    }
  }
  return $s
}

sub as_hash {
  my $self  = shift;
  my $map   = shift // sub { shift; @_ };
  my $hroot = {};
  my @ar;

  push @ar, [ '', $self, $hroot ];
  while (my $elt = shift @ar) {
    if ($elt->[1]->has_subnodes) {
      my $hr0 = {};
      my ($name, $hr) = &{$map}('tree', $elt->[0], $hr0);
      $elt->[2]{$name} = $hr0;
      while (my ($kw, $val) = each %{$elt->[1]->{subnode}}) {
	push @ar, [ $kw, $val, $hr ];
      }
    } else {
      my ($name) = &{$map}('leaf', $elt->[0]);
      $elt->[2]{$name} = {};
    }
  }
  return %{$hroot->{''}};
}

=head2 as_hash_vue

returns hash of such structure:

    ...
    "key1": { "branch": {}, "dn": "dn1 string" },
    ou=workstations": {
      "branch": {
        "cn=chakotay": {
          "dn": "cn=chakotay,cn=chakotay,ou=workstations,dc=umidb"
        },
        "cn=tuvok": {
          "dn": "cn=tuvok,cn=tuvok,ou=workstations,dc=umidb"
        }
      },
      "dn": "ou=workstations,dc=umidb"
    },
    ...
    uid=taf.taffij" : {
       "branch" : {
          "authorizedService=mail@borg.startrek.in" : {
             "branch" : {
                "uid=taf.taffij@borg.startrek.in" : {
                   "dn" : "uid=taf.taffij@borg.startrek.in,authorizedService=mail@borg.startrek.in,uid=taf.taffij,ou=People,dc=umidb"
                }
             },
             "dn" : "authorizedService=mail@borg.startrek.in,uid=taf.taffij,ou=People,dc=umidb"
          },
          "authorizedService=xmpp@im.talax.startrek.in" : {
             "branch" : {
                "uid=taf.taffij@im.talax.startrek.in" : {
                   "dn" : "uid=taf.taffij@im.talax.startrek.in,authorizedService=xmpp@im.talax.startrek.in,uid=taf.taffij,ou=People,dc=umidb"
                }
             },
             "dn" : "authorizedService=xmpp@im.talax.startrek.in,uid=taf.taffij,ou=People,dc=umidb"
          }
       },
       "dn" : "uid=taf.taffij,ou=People,dc=umidb"
    },
    ...
    "key2": { "branch": {}, "dn": "dn2 string" },
    ...

=cut

sub as_hash_vue {
  my $self  = shift;
  my $map   = shift // sub { shift; @_ };
  my $hroot = {};
  my @ar;

  push @ar, [ '', $self, $hroot ];
  while (my $elt = shift @ar) {
    if ($elt->[1]->has_subnodes) {
      my $hr0 = {};
      my ($name, $hr) = &{$map}('tree', $elt->[0], $hr0);
      $elt->[2]{"$name"}{branch} = $hr0;
      $elt->[2]{"$name"}{dn} = "$elt->[1]->{dn}";
      while (my ($kw, $val) = each %{$elt->[1]->{subnode}}) {
	push @ar, [ $kw, $val, $hr ];
      }
    } else {
      my ($name) = &{$map}('leaf', $elt->[0]);
      $elt->[2]{"$name"} = { dn => $elt->[1]->{dn}, };
    }
  }
  return %{$hroot->{''}{branch}};
}

sub as_json {
  my $self  = shift;
  my $map   = shift // sub { shift; @_ };
  my $hroot = {};
  my @vue;
  my @ar;

  push @ar, [ '', $self, $hroot ];
  while (my $elt = shift @ar) {
    if ($elt->[1]->has_subnodes) {
      my $hr0 = {};
      my ($name, $hr) = &{$map}('tree', $elt->[0], $hr0);
      push @vue, { id => $name, branch => 1, dn => $elt->[1]->dn };
      while (my ($kw, $val) = each %{$elt->[1]->{subnode}}) {
	push @ar, [ $kw, $val, $hr ];
      }
    } else {
      my ($name) = &{$map}('leaf', $elt->[0]);
      push @vue, { id => $name, branch => 0, dn => $elt->[1]->dn };

    }
  }
  return @vue;
}

sub as_json_vue {
  my $self  = shift;
  my $map   = shift // sub { shift; @_ };
  my $hroot = [];
  my @ar;
  
  push @ar, [ '', $self, $hroot ];
  while (my $e = shift @ar) {
    if ($e->[1]->has_subnodes) {
      my $ch = [];
      push @{$e->[2]}, { name     => $e->[0],
			 dn       => $e->[1]->dn,
			 children => $ch };
      while (my ($k, $v) = each %{$e->[1]->{subnode}}) {
	push @ar, [ $k, $v, $ch ];
      }
    } else {
      push @{$e->[2]}, { name => $e->[0], dn => $e->[1]->dn };
    }
  }
  # use Data::Printer;
  # p $hroot->[0]->{children}->[0];
  # use Logger;
  # log_debug{ np( $hroot ) };
  # my @sorted = sort { $a->{name} cmp $b->{name} } @{$hroot->[0]{children}[0]{children}};
  # log_debug { np( @sorted ) };
  # my $return = { name     => $hroot->[0]->{children}->[0]->{name},
  # 		 children => \@sorted };
  # return $return;
  
  return $hroot->[0]{children}[0];
}

use overload
  '""' => sub { shift->as_string },
  '<>' => sub {
    my $self = shift;
    return if $self->is_leaf;
    each %{$self->{subnode}}
  };

our $AUTOLOAD;

sub AUTOLOAD {
  my $self = shift;
  my $fn   = $AUTOLOAD;
  $fn =~ s/.*:://;
  if ($self->has_subnodes && @_ == 1) {
    my $key = "$fn=$_[0]";
    if (exists($self->{subnode}{$key})) {
      return $self->{subnode}{$key};
    }
  }
  confess "Can't locate method $AUTOLOAD";
}

__PACKAGE__->meta->make_immutable;

1;

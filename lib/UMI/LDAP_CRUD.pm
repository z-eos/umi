package LDAP_CRUD;

use Data::Dumper;
use Net::LDAP;
use Moose;
use Try::Tiny;
use namespace::autoclean;

has 'host' => ( is => 'ro', isa => 'Str', required => 1, default => 'ldaps://ldap1.ibs');
has 'uid' => ( is => 'ro', isa => 'Str', required => 1 );
has 'pwd' => ( is => 'ro', isa => 'Str', required => 1 );

has 'ldap'  => ( is => 'rw',
		 isa => 'Net::LDAP',
		 required => 0, lazy => 1,
		 builder => '_build_ldap',
	       );

sub _build_ldap {
  my $self = shift;

  my $ldap = try {
    Net::LDAP->new ( $self->host, async => 1 );
  } catch {
    warn "Net::LDAP->new problem, error: $_"; # not $@
  };

  return $ldap;
}

has 'ldap_bind' => ( is => 'rw',
		     isa => 'Net::LDAP::Message',
		     lazy => 1,
		     builder => '_build_ldap_bind',
		   );

sub _build_ldap_bind {
    my $self = shift;
    my $ldap = $self->ldap;

    return $ldap->bind (
			sprintf('uid=%s,ou=People,dc=ibs', $self->uid),
			password => $self->pwd,
			version => 3,
		       );

    # my $mesg = try {
    #   $self->ldap->bind ( $arg->{'dn'}, { password => $arg->{'password'} } );
    # } catch {
    #   warn "Net::LDAP->bind error: $_";
    # }
    # return $mesg
}

sub unbind {
  my $self = shift;
  $self->ldap->unbind;
}

sub schema {
  my $self = shift;
  $self->ldap->schema;
}

sub search {
  my ($self, $args) = @_;
  my $arg = {
  	     base   => $args->{base},
  	     scope  => $args->{scope} || 'sub',
  	     filter => $args->{filter} || '(objectClass=*)',
  	     deref  => $args->{deref} || 'never',
  	     attrs  => $args->{attrs} || [ '*' ],
  	     sizelimit => $args->{sizelimit} || 10,
  	    };

  return $self->ldap->search( base => $arg->{base},
  			      scope => $arg->{scope},
  			      filter => $arg->{filter},
  			      deref => $arg->{deref},
  			      attrs => $arg->{attrs},
  			      sizelimit => $arg->{sizelimit},
  			    );
}

=head2 last_uidNumber

Last uidNumber for base ou=People,dc=ibs

to add error correction

=cut

sub last_uidNumber {
  my $self = shift;
  my $mesg =
    $self->ldap->search(
			base   => "ou=People,dc=ibs",
			scope  => "one",
			filter => "uidNumber=*",
			attrs   => [ 'uidNumber' ],
		       );

  my @uids_arr = sort { $a <=> $b } map { $_->get_value('uidNumber') } $mesg->all_entries;
  return $uids_arr[$#uids_arr];
}

=head2 obj_schema

LDAP object schema and data

returned structure is:

$VAR1 = {
  'DN1' => {
    'objectClass1' => {
      'must' => {
        'mustAttr1' => {
          'equality' => ...,
          'desc' => ...,
          'single-value' => ...,
          'attr_value' => ...,
          'max_length' => ...,
        },
        'mustAttrN' {
        ...
        },
       },
       'may' => {
         'mayAttr1' => {
           'equality' => ...,
           'desc' => ...,
           'single-value' => ...,
           'attr_value' => ...,
           'max_length' => ...,
         },
         'mayAttrN' {
         ...
         },
       },
    },
    'objectClass2' => {
    ...
    },
  },
  'DN2' => {
  ...
  },
}

Commonly, we will wish to use it for the single object to build the
form to add or modify

TODO

to add error correction

=cut

sub obj_schema {
  my ($self, $args) = @_;
  my $arg = {
  	     base   => $args->{base},
  	     scope  => $args->{scope} || 'one',
  	     filter => $args->{filter},
  	    };

  my $mesg =
    $self->ldap->search(
			base   => $arg->{base},
			scope  => $arg->{scope},
			filter => $arg->{filter},
		       );
  my @entries = $mesg->entries;

  my ( $must, $may, $obj_schema );
  foreach my $entry ( @entries ) {
    foreach my $objectClass ( $entry->get_value('objectClass') ) {
      next if $objectClass eq 'top';
      foreach $must ( $self->schema->must ( $objectClass ) ) {
	$obj_schema->{$entry->dn}->{$objectClass}->{'must'}
	  ->{ $must->{'name'} } =
	    {
	     'attr_value' => $entry->get_value( $must->{'name'} ) || undef,
	     'desc' => $must->{'desc'} || undef,
	     'single-value' => $must->{'single-value'} || undef,
	     'max_length' => $must->{'max_length'} || undef,
	     'equality' => $must->{'equality'} || undef,
	    };
      }

      foreach $may ( $self->schema->may ( $objectClass ) ) {
	$obj_schema->{$entry->dn}->{$objectClass}->{'may'}
	  ->{$may->{'name'}} =
	    {
	     'attr_value' => $entry->get_value( $may->{'name'} ) || undef ,
	     'desc' => $may->{'desc'} || undef ,
	     'single-value' => $may->{'single-value'} || undef ,
	     'max_length' => $may->{'max_length'} || undef ,
	     'equality' => $may->{'equality'} || undef ,
	    };
      }
    }
  }
  return $obj_schema;
}

######################################################################

#no Moose;
#__PACKAGE__->meta->make_immutable;

1;

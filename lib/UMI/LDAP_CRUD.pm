package LDAP_CRUD;

use Data::Dumper;
use Net::LDAP;
use Moose;
use Try::Tiny;
use namespace::autoclean;

has 'host' => ( is => 'ro', isa => 'Str', required => 1, default => 'ldaps://ldap1.ibs');
has 'uid' => ( is => 'ro', isa => 'Str', required => 1 );
has 'pwd' => ( is => 'ro', isa => 'Str', required => 1 );
has 'dry_run' => ( is => 'ro', isa => 'Bool', );

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

  my $mesg =  $ldap->bind (
			   sprintf('uid=%s,ou=People,dc=ibs', $self->uid),
			   password => $self->pwd,
			   version => 3,
			  );
  if ( $mesg->is_error ) {
    warn "Net::LDAP->bind error_desc: " . $mesg->error_desc . "; server_error: " . $mesg->server_error;
  }
  return $ldap;
}

# has 'ldap_bind' => ( is => 'rw',
# 		     isa => 'Net::LDAP::Message',
# 		     lazy => 1,
# 		     builder => '_build_ldap_bind',
# 		   );

# sub _build_ldap_bind {
#     my $self = shift;
#     my $ldap = $self->ldap;

#     return $ldap->bind (
# 			sprintf('uid=%s,ou=People,dc=ibs', $self->uid),
# 			password => $self->pwd,
# 			version => 3,
# 		       );

#     # my $mesg = try {
#     #   $self->ldap->bind ( $arg->{'dn'}, { password => $arg->{'password'} } );
#     # } catch {
#     #   warn "Net::LDAP->bind error: $_";
#     # }
#     # return $mesg
# }

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

=head2 add

=cut

sub add {
  my ($self, $dn, $attrs, $dryrun) = @_;

  my $callername = (caller(1))[3];
  $callername = 'main' if not defined $callername;
  my $return = 'call to LDAP_CRUD->add from ' . $callername . ': ';
  my $msg;
  if ( not $dryrun ) {
    $msg = $self->ldap->add ( $dn, attrs => $attrs, );
    if ($msg->is_error()) {
      $return = "error_descr: " . $msg->error_desc();
      $return .= "; server_error: " . $msg->server_error() if defined $msg->server_error();
    } else {
      $return = 0;
    }
  } else {
    $return = $msg->ldif;
  }
  return $return;
}

=head2 delete

TODO

to care recursively of subtree of the object to be deleted if exist

=cut

sub del {
  my ($self, $dn, $dryrun) = @_;

  my $callername = (caller(1))[3];
  $callername = 'main' if not defined $callername;
  my $return = 'call to LDAP_CRUD->del from ' . $callername . ': ';

  if ( not $dryrun ) {
    my $msg = $self->ldap->delete ( $dn );
    if ($msg->is_error()) {
      $return .= "error_descr: " . $msg->error_desc;
      $return .= "; server_error: " . $msg->server_error if defined $msg->server_error;
    } else {
      $return = 0;
    }
  } else {
    $return = 0;
  }
  return $return;
}

=head2 mod

modify method

=cut

sub mod {
  my ($self, $dn, $dryrun) = @_;

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

returned structure is hash of all mandatory and optional attributes of
all objectClass-es of the object:

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

=head2 select_key_val

returns ref on hash (mostly aimed for select form elements `options_'
method. It expects each ldapsearch result entry to be single value.

ldapsearch option `attrs' is expected to be single, lowercased
(otherwise, ->search fails, do not know why but need to verify!) value
of the attribyte for which hash to be built, DN will be the key and
the attributes value, is the value

$VAR1 = {
          'dn1' => 'attributeValue 1',
          ...
          'dnN' => 'attributeValue 1',
        }

TODO:

to add error correction

=cut

sub select_key_val {
  my ($self, $args) = @_;
  my $arg = {
	     base => $args->{'base'},
	     filter => $args->{'filter'},
	     scope => $args->{'scope'},
	     attrs => $args->{'attrs'},
	    };
  my $mesg =
    $self->ldap->search(
			base => $arg->{'base'},
			filter => $arg->{'filter'},
			scope => $arg->{'scope'},
			attrs => [ $arg->{'attrs'} ],
			deref => 'never',
		       );

  my $entries = $mesg->as_struct;

  my %results;
  foreach my $key (sort (keys %{$entries})) {
    foreach my $val ( @{$entries->{$key}->{$arg->{'attrs'}}} ) {
      # $results{"$key"} = $val if not $val =~ /[^[:ascii:]]/;
      $results{"$key"} = $val;
    }
  }
  return \%results;
}

######################################################################

#no Moose;
#__PACKAGE__->meta->make_immutable;

1;

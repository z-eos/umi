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
    $self->ldap->search(base   => "ou=People,dc=ibs",
			scope  => "one",
			filter => "uidNumber=*",
			attrs   => [ 'uidNumber' ],
		       );

  my @uids_arr = sort { $a <=> $b } map { $_->get_value('uidNumber') } $mesg->all_entries;
  return $uids_arr[$#uids_arr];
}

######################################################################

#no Moose;
#__PACKAGE__->meta->make_immutable;

1;

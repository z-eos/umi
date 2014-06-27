#!/usr/bin/env perl
# -*- mode: cperl; cperl-indent-level: 2; cperl-continued-statement-offset: 2 -*-
#

#
## script to test schema retrieval and parsing
#

use LDAP_CRUD;

use Data::Dumper;

my $uid = $ARGV[0];
my $pwd = $ARGV[1];
my $org = $ARGV[2];

my $ldap_crud = LDAP_CRUD->new(uid => $uid, pwd => $pwd);

my $mesg = $ldap_crud->ldap_bind;

# print "mesg bind\n" . Dumper($mesg);

$mesg = $ldap_crud
  ->search(
	   {
	    base => 'ou=Organizations,dc=ibs',
	    filter => '(ou=' . $org . ')',
	    scope => 'one',
	   }
	  );

$mesg->code && print "error_text:\n", $mesg->error_text;

my @entries = $mesg->entries;

my $schema = $ldap_crud->schema;

my ( $must, $may, $field, @schema_fields );
@schema_fields = ( qw{ name equality desc single-value max_length } );
foreach my $entry ( @entries ) {
  print "objectClass:\n" . Dumper( $entry->get_value('objectClass') ) . "\n";
  foreach my $objectClass ( $entry->get_value('objectClass') ) {
    print "objectClass: $objectClass\n\nmust:\n";
    # print "dump for must:\n", Dumper(@must);
    # print "may:\n", Dumper(@may);

    foreach $must ( $schema->must ( $objectClass ) ) {
      foreach $field ( @schema_fields ) {
        printf "%15s: %s\n", $field, $must->{$field} if $must->{$field} and $field ne 'equality';
        printf "%15s: %s\n", 'matchingrule',
	  $schema->matchingrule_for_attribute ($must->{'name'},$field )
	    if defined $field and $field eq 'equality';
      }
      print "\n";
    }
    print "may:\n";
    foreach $may ( $schema->may ( $objectClass ) ) {
      foreach $field ( @schema_fields ) {
        printf "%15s: %s\n", $field, $may->{$field} if $may->{$field} and $field ne 'equality';
        printf "%15s: %s\n", 'matchingrule',
	  $schema->matchingrule_for_attribute ($may->{'name'},$field )
	    if defined $field and $field eq 'equality';
      }
      print "\n";
    }
  }
}

#print "mesg search\n" . Dumper($mesg) . "\nentries\n" . Dumper($mesg->entries);

print "last uidNumber is: ", $ldap_crud->last_uidNumber;

$ldap_crud->unbind;

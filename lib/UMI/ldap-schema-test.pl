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
my $base = $ARGV[2];
my $filter = $ARGV[3];

my $ldap_crud = LDAP_CRUD->new(uid => $uid, pwd => $pwd);

my $mesg = $ldap_crud->ldap_bind;

print "schema:\n", 
  Dumper($ldap_crud->obj_schema(
				{
				 base => $base,
				 filter => $filter,
				}
			       )
	);

$ldap_crud->unbind;

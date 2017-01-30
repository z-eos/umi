# -*- mode: cperl; mode: follow; -*-
#

package UMI::Controller::ServerMTA;
use Moose;
use namespace::autoclean;

use Net::DNS;
use Data::Printer;

BEGIN { extends 'Catalyst::Controller'; with 'Tools'; }

=head1 NAME

UMI::Controller::ServerMTA - Catalyst Controller

=head1 DESCRIPTION

MTA related Controller.

IMPORTANT

Here we assume, entire MTA related LDAP branch (in our case:
ou=Sendmail, dc=umidb) has one single core relay host (in our case:
ou=relay.umi) which has attribute 

    host => FQDN as value
    businessCategory => corerelay as value

=head1 METHODS

=cut



=head2 index

page to show all email domains, theirs MX-es and nodes serving as SMARTHOSTs

=cut


sub index :Path :Args(0) {
    my ( $self, $c ) = @_;
    my ( $return, $mta, $entry, $relay, $node, $fqdn, $ip, @mx_arr, $mx );
    my $default = 'default';
    my $reslvr = Net::DNS::Resolver->new;
    my $resolved;
    
    my $ldap_crud = $c->model('LDAP_CRUD');

    my $mesg = $ldap_crud->search({ base => $ldap_crud->{cfg}->{base}->{mta},
				    sub => 'one',
				    sizelimit => 0,
				    attrs   => [ 'host', ],
				    filter => '(businessCategory=corerelay)', });
    if ( $mesg->code ) {
      push @{$return->{error}}, $ldap_crud->err($mesg)->{html};
    } else {
      $entry = $mesg->entry(0);
      $relay = $entry->get_value('host');

      $mesg = $ldap_crud->search({ base => 'sendmailMTAMapName=smarttable,ou=' . $relay . ',' .
				   $ldap_crud->{cfg}->{base}->{mta},
				   sub => 'children',
				   sizelimit => 0,
				   attrs   => [ 'sendmailMTAKey', 'sendmailMTAMapValue', ],
				   filter => '(sendmailMTAKey=*)', });
      if ( $mesg->code ) {
	push @{$return->{error}}, $ldap_crud->err($mesg)->{html};
      } else {
	foreach $entry ( @{[$mesg->entries]} ) {
	  $node = (split(':',$entry->get_value('sendmailMTAMapValue')))[1];
	  $fqdn = substr $entry->get_value('sendmailMTAKey'), 1;

	  @mx_arr = mx( $reslvr, $fqdn );
	  if (@mx_arr) {
	    $mx = $mx_arr[0]->exchange;
	  } else {
	    push @{$return->{error}}, $reslvr->errorstring;
	  }

	  $resolved = $reslvr->search($node);
	  if ($resolved) {
	    foreach my $rr ($resolved->answer) {
	      $ip = $rr->address if $rr->type eq "A";
	    }
	  } else {
	    push @{$return->{error}}, $reslvr->errorstring;
	  }

	  $mta->{$fqdn}->{smarthost} = { fqdn => $node,
					 ip => $ip,
					 mx => $mx, };
	  $#mx_arr = -1;
	}
      }

      $mesg = $ldap_crud->search({ base => 'sendmailMTAMapName=mailer,ou=' . $relay . ',' .
				   $ldap_crud->{cfg}->{base}->{mta},
				   sub => 'children',
				   sizelimit => 0,
				   attrs   => [ 'sendmailMTAKey', ],
				   filter => '(sendmailMTAKey=*)', });
      if ( $mesg->code ) {
	push @{$return->{error}}, $ldap_crud->err($mesg)->{html};
      } else {
	foreach $entry ( @{[$mesg->entries]} ) {
	  $fqdn = $entry->get_value('sendmailMTAKey');
	  $mta->{$fqdn}->{smarthost} = { fqdn => $default, ip => $default, mx => $default }
	    if ! defined $mta->{$fqdn};
	}
      }
    }
    $c->stash( template => 'server/mta/srv_mta_root.tt',
	       mta => $mta,
	       final_message => $return,);

    # p $mta;
    # p $return;
}

=head1 AUTHOR

Charlie &

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;

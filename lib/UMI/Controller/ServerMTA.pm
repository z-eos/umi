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

Here we assume, entire MTA related LDAP branch (in our case:
ou=Sendmail, dc=umidb) has one core in/out-going email host (in our
case: ou=relay.umi) which has attributes:

    host => FQDN of the core relay
    businessCategory => keyword `corerelay'
    destinationIndicator => default SMARTHOST FQDN

This host uses separate SMARTHOSTs to send mail (default one is set
as attribute destinationIndicator value) for mail doains served.

First we crawl all, mail domains served from smarthost table

    sendmailMTAMapName=smarttable,ou=relay.xx,ou=Sendmail,dc=umidb

and initializing hash elements for them with MX/A/PTR and related
smarthost data found

Further we crawl all, mail domains served from mailer table

    sendmailMTAMapName=mailer,ou=relay.xx,ou=Sendmail,dc=umidb

and initializing elements of the same hash, but for mail domais,
lacking from previous step, with the data of MX/A/PTR but default
smarthost.

=head1 METHODS

=cut



=head2 index

page to show all email domains, theirs MX-es and nodes serving as SMARTHOSTs

=cut


sub index :Path :Args(0) {
  my ( $self, $c ) = @_;
  my ( $return, $mta, $mtadescr, $smarthost, $entry, $relay, $ip, $rr, @mx_arr, $mx, $mx_ptr, $mx_a );
  my $node; # smarthost node mail domain served by
  my $fqdn; # mail domain
  $mx = $mx_a = $mx_ptr = '';
  my $default;
  my $reslvr = Net::DNS::Resolver->new;
  # RFC2929
  my $rcode = { # vvvvvvvvvvvvvvvvvvvvvvvvvvvvvv NOERROR + 0 data = one or more resource records exist for this domain but there isn’t a record matching the resource record type (A, AAAA, MX, etc.)
	       NOERROR  => { dec =>  0, RFC => 1035, descr => 'No Error', },
	       FORMERR  => { dec =>  1, RFC => 1035, descr => 'Format Error', },
	       SERVFAIL => { dec =>  2, RFC => 1035, descr => 'Server Failure', },
	       NXDOMAIN => { dec =>  3, RFC => 1035, descr => 'Non-Existent Domain', },
	       NOTIMP   => { dec =>  4, RFC => 1035, descr => 'Not Implemented', },
	       REFUSED  => { dec =>  5, RFC => 1035, descr => 'Query Refused', },
	       YXDOMAIN => { dec =>  6, RFC => 2136, descr => 'Name Exists when it should not',},
	       YXRRSET  => { dec =>  7, RFC => 2136, descr => 'RR Set Exists when it should not',},
	       NXRRSET  => { dec =>  8, RFC => 2136, descr => 'RR Set that should exist does not', },
	       NOTAUTH  => { dec =>  9, RFC => 2136, descr => 'Server Not Authoritative for zone', },
	       NOTZONE  => { dec => 10, RFC => 2136, descr => 'Name not contained in zone', },
	       BADVERS  => { dec => 16, RFC => 2671, descr => 'Bad OPT Version', },
	       BADSIG   => { dec => 16, RFC => 2845, descr => 'TSIG Signature Failure', },
	       BADKEY   => { dec => 17, RFC => 2845, descr => 'Key not recognized', },
	       BADTIME  => { dec => 18, RFC => 2845, descr => 'Signature out of time window', },
	       BADMODE  => { dec => 19, RFC => 2930, descr => 'Bad TKEY Mode', },
	       BADNAME  => { dec => 20, RFC => 2930, descr => 'Duplicate key name', },
	       BADALG   => { dec => 21, RFC => 2930, descr => 'Algorithm not supported', },
	      };

  my ($resolved, $tmp);
    
  my $ldap_crud = $c->model('LDAP_CRUD');

  # core relay details
  my $mesg = $ldap_crud->search({ base => $ldap_crud->{cfg}->{base}->{mta},
				  sub => 'one',
				  sizelimit => 0,
				  attrs   => [ 'destinationIndicator', 'host', 'description' ],
				  filter => '(businessCategory=corerelay)', });
  if ( $mesg->code ) {
    push @{$return->{error}}, $ldap_crud->err($mesg)->{html};
  } else {
    $entry = $mesg->entry(0);
    $relay = $entry->get_value('host');
    $mta->{default}->{smarthost}->{fqdn} = $entry->get_value('destinationIndicator');
    $mta->{default}->{description} = $entry->get_value('description');

    # core SMARTHOST IP address
    $tmp = $self->dns_resolver({fqdn => $fqdn,
				type   => 'A',
				name   => $mta->{default}->{smarthost}->{fqdn},
				legend => 'IP',
				rcode  => $rcode});

    if ( defined $tmp->{success} ) {
      $mta->{default}->{smarthost}->{ip} = $tmp->{success};
    } elsif ( defined $tmp->{error} ) {
      push @{$return->{error}}, @{[$tmp->{error}]};
    }

    # for each smarthost node
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

	# first MX of the node
	$tmp = $self->dns_resolver({fqdn => $fqdn,
				    type   => 'MX',
				    name   => $fqdn,
				    legend => 'MX',
				    rcode  => $rcode});

	if ( defined $tmp->{success} ) {
	  $mx = $tmp->{success};
	} elsif ( defined $tmp->{error} ) {
	  push @{$return->{error}}, @{[$tmp->{error}]};
	}

	# node IP address
	$tmp = $self->dns_resolver({fqdn => $fqdn,
				    type   => 'A',
				    name   => $node,
				    legend => 'IP',
				    rcode  => $rcode});

	if ( defined $tmp->{success} ) {
	  $ip = $tmp->{success};
	} elsif ( defined $tmp->{error} ) {
	  push @{$return->{error}}, @{[$tmp->{error}]};
	}

	# A record (IP address) of MX
	$tmp = $self->dns_resolver({fqdn => $fqdn,
				    type   => 'A',
				    name   => $mx,
				    legend => 'MX A',
				    rcode  => $rcode});

	if ( defined $tmp->{success} ) {
	  $mx_a = $tmp->{success};
	} elsif ( defined $tmp->{error} ) {
	  push @{$return->{error}}, @{[$tmp->{error}]};
	}
	  
	# PTR of MX
	$tmp = $self->dns_resolver({fqdn => $fqdn,
				    type   => 'PTR',
				    name   => $mx_a,
				    legend => 'MX IP',
				    rcode  => $rcode});

	if ( defined $tmp->{success} ) {
	  $mx_ptr = $tmp->{success};
	} elsif ( defined $tmp->{error} ) {
	  push @{$return->{error}}, @{[$tmp->{error}]};
	}

	$mta->{custom}->{$fqdn}->{smarthost} =
	  { fqdn => $node,
	    ip => $ip,
	    mx => { fqdn => $mx ne '' ? $mx : 'No match for domain ' . $fqdn,
		    a => $mx_a,
		    ptr => $mx_ptr,
		    html_class => $mx eq $mx_ptr && $mx ne '' ? 'success' : 'danger',
		    html_title => $mx eq $mx_ptr ? '' : 'revers resolv fails',
		  },
	  };
	$node = $fqdn = $rr = $ip = $mx = $mx_a = $mx_ptr = '';
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

	# first MX of the node
	$tmp = $self->dns_resolver({fqdn => $fqdn,
				    type   => 'MX',
				    name   => $fqdn,
				    legend => 'MX',
				    rcode  => $rcode});

	if ( defined $tmp->{success} ) {
	  $mx = $tmp->{success};
	} elsif ( defined $tmp->{error} ) {
	  push @{$return->{error}}, @{[$tmp->{error}]};
	}

	# node IP address
	$tmp = $self->dns_resolver({fqdn => $fqdn,
				    type   => 'A',
				    name   => $fqdn,
				    legend => 'IP',
				    rcode  => $rcode});

	if ( defined $tmp->{success} ) {
	  $ip = $tmp->{success};
	} elsif ( defined $tmp->{error} ) {
	  push @{$return->{error}}, @{[$tmp->{error}]};
	}

	# A record (IP address) of MX
	$tmp = $self->dns_resolver({fqdn => $fqdn,
				    type   => 'A',
				    name   => $mx,
				    legend => 'MX A',
				    rcode  => $rcode});

	if ( defined $tmp->{success} ) {
	  $mx_a = $tmp->{success};
	} elsif ( defined $tmp->{error} ) {
	  push @{$return->{error}}, @{[$tmp->{error}]};
	}

	# PTR of MX
	$tmp = $self->dns_resolver({fqdn => $fqdn,
				    type   => 'PTR',
				    name   => $mx_a,
				    legend => 'MX IP',
				    rcode  => $rcode});

	if ( defined $tmp->{success} ) {
	  $mx_ptr = $tmp->{success};
	} elsif ( defined $tmp->{error} ) {
	  push @{$return->{error}}, @{[$tmp->{error}]};
	}

	$mta->{custom}->{$fqdn}->{smarthost} =
	  { fqdn => $mta->{default}->{smarthost}->{fqdn},
	    ip => $mta->{default}->{smarthost}->{ip},
	    mx => { fqdn => $mx ne '' ? $mx : 'No match for domain ' . $fqdn,
		    a => $mx_a,
		    ptr => $mx_ptr,
		    html_class => $mx eq $mx_ptr && $mx ne '' ? 'info' : 'danger',
		    html_title => $mx eq $mx_ptr ? 'default relay' : 'revers resolv fails', },
	  } if ! defined $mta->{custom}->{$fqdn};
      }
    }
  }
  $c->stash( template => 'server/mta/srv_mta_root.tt',
	     mta => $mta,
	     final_message => $return, );

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

# -*- mode: cperl; mode: follow; -*-
#

package UMI::Controller::ServerMTA;
use Moose;
use namespace::autoclean;
use Socket;

BEGIN { extends 'Catalyst::Controller'; with 'Tools'; }

=head1 NAME

UMI::Controller::ServerMTA - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut



=head2 index

new Text Pwdgen

=cut


sub index :Path :Args(0) {
    my ( $self, $c ) = @_;
    my ( $return, $final_message, $mta, $entry, $node, $fqdn, $packed_ip, $ip );
    my $default = 'default';
    
    my $ldap_crud = $c->model('LDAP_CRUD');
    my $mesg = $ldap_crud->search({ base => "sendmailMTAMapName=smarttable,ou=relay.umi," .
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
	$packed_ip = gethostbyname $node;
	$ip = defined $packed_ip ? inet_ntoa($packed_ip) : '';
	$mta->{$fqdn}->{smarthost} = { fqdn => $node, ip => $ip };
      }
    }

    $mesg = $ldap_crud->search({ base => "sendmailMTAMapName=mailer,ou=relay.umi," .
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
	$mta->{$fqdn}->{smarthost} = { fqdn => $default, ip => $default }
	  if ! defined $mta->{$fqdn};
      }
    }
    
    $c->stash( template => 'server/mta/srv_mta_root.tt',
	       mta => $mta,
	       final_message => $return,);

    # use Data::Printer;
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

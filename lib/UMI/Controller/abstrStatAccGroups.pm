#-*- mode: cperl; eval: (follow-mode) -*-
#

package UMI::Controller::abstrStatAccGroups;
use Moose;
use namespace::autoclean;

use Data::Printer colored => 0;
use Logger;

BEGIN { extends 'Catalyst::Controller'; with 'Tools'; }

=head1 NAME

UMI::Controller::abstrStatAccGroups - Catalyst Controller

=head1 DESCRIPTION

all account's groups/netgroups (all groups each account is member of)

for each account information of fields bellow is provided

    Last Name, First Name, blocked, root uid, groups, netgroups

blocked field value 1 for accounts with gidNumber set to the
the group `disabled' gidNumber, otherwise it is 0

=head1 METHODS

=cut


=head2 index

=cut

sub index :Path :Args(0) {
  my ( $self, $c ) = @_;

  if ( $c->user_exists() ) {
    my ( $account, $accounts, $utf_givenName, $utf_sn, $gidNumber,
	 $grp, @services, $service,
	 $mesg_blk, @mesg_blk_entries,
	 $mesg_grp, @mesg_grp_entries,
	 $authorizedService,
	 $return, );

    my $params = $c->req->params;

    my $ldap_crud = $c->model('LDAP_CRUD');
    #-- collect all root accounts
    my $mesg = $ldap_crud->search({ base      => $ldap_crud->{cfg}->{base}->{acc_root},
				    scope     => 'one',
				    sizelimit => 0,
				    attrs     => [ 'uid', 'givenName', 'sn', 'gidNumber', ],
				    filter    => '(objectClass=*)', });
    if ( $mesg->code ) {
      push @{$return->{error}}, $ldap_crud->err($mesg)->{html};
    } else {
      foreach $account ( @{[$mesg->entries]} ) {
	$utf_givenName = $account->get_value('givenName');
	$utf_sn = $account->get_value('sn');
	utf8::decode($utf_givenName) if defined $utf_givenName;
	utf8::decode($utf_sn) if defined $utf_sn;
	$gidNumber  = $account->get_value('gidNumber');
	# log_debug { $account->dn };
	$accounts->{$account->dn} =
	  {
	   uid               => $account->get_value('uid'),
	   givenName         => $utf_givenName,
	   sn                => $utf_sn,
	   blocked           => $gidNumber == $ldap_crud->cfg->{stub}->{group_blocked_gid} ? 1 : 0,
	  };

	#-- is current account blocked?
	$mesg_blk = $ldap_crud->search({ base      => $ldap_crud->{cfg}->{base}->{group},
					 scope     => 'one',
					 sizelimit => 0,
					 filter    => sprintf('(&(cn=%s)(memberUid=%s))',
							      $ldap_crud->cfg->{stub}->{group_blocked},
							      $accounts->{$account->dn}->{uid}),
					 attrs     => [ 'cn' ] });
	if ( $mesg_blk->code ) {
	  push @{$return->{error}}, $ldap_crud->err($mesg_blk)->{html};
	} else {
	  @mesg_blk_entries = $mesg_blk->entry(0);
	  $accounts->{$account->dn}->{blocked} = 1 if $mesg_blk->count;
	}

	#-- collect all groups current account is member of
	$mesg_grp = $ldap_crud->search({ base => $ldap_crud->{cfg}->{base}->{group},
					 sizelimit => 0,
					 filter => '(memberUid=' . $account->get_value('uid') . ')', });
	if ( $mesg_grp->code ) {
	  push @{$return->{error}}, $ldap_crud->err($mesg_grp)->{html};
	} else {
	  foreach ( @{[ $mesg_grp->entries ]} ) {
	    push @{$accounts->{$account->dn}->{groups}->{group}->{cn}}, $_->get_value('cn');
	    push @{$accounts->{$account->dn}->{groups}->{group}->{description}}, $_->get_value('description');
	  }
	}

	#-- collect all netgroups current account is member of
	$mesg_grp = $ldap_crud->search({ base => $ldap_crud->{cfg}->{base}->{netgroup},
					 sizelimit => 0,
					 filter => '(nisNetgroupTriple=*,' . $account->get_value('uid') . ',*)', });
	if ( $mesg_grp->code ) {
	  push @{$return->{error}}, $ldap_crud->err($mesg_grp)->{html};
	} else {
	  foreach ( @{[ $mesg_grp->entries ]} ) {
	    push @{$accounts->{$account->dn}->{groups}->{netgroup}->{cn}}, $_->get_value('cn');
	    push @{$accounts->{$account->dn}->{groups}->{netgroup}->{description}}, $_->get_value('description');
	  }
	}

      } #-- foreach $account
    }

    log_debug { np($accounts) };
    $c->stash( template => 'stat/abstr_stat_acc_group.tt',
	       accounts => $accounts,
	       final_message => $return,);
  } else {
    $c->stash( template => 'signin.tt', );
  }

}


=encoding utf8

=head1 AUTHOR

zeus

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;

# -*- cperl -*-
#

package UMI::Controller::SearchBy;

use Net::LDAP::Util qw(	ldap_explode_dn );

use Logger;
use MIME::Base64;

#use utf8;
use Moose;
use namespace::autoclean;

use Data::Printer { use_prototypes => 0, caller_info => 1 };
use Time::Piece;
use List::MoreUtils qw(uniq);

use Crypt::HSXKPasswd;

# use Try::Tiny;

BEGIN { extends 'Catalyst::Controller'; with 'Tools'; }

use UMI::Form::Dhcp;
has 'form_add_dhcp' =>
  ( isa => 'UMI::Form::Dhcp', is => 'rw', lazy => 1,
    default => sub { UMI::Form::Dhcp->new }, );

use UMI::Form::ModPwd;
has 'form_mod_pwd' =>
  ( isa => 'UMI::Form::ModPwd', is => 'rw', lazy => 1,
    default => sub { UMI::Form::ModPwd->new }, );

use UMI::Form::ModJpegPhoto;
has 'form_jpegphoto' =>
  ( isa => 'UMI::Form::ModJpegPhoto', is => 'rw', lazy => 1,
    default => sub { UMI::Form::ModJpegPhoto->new }, );

use UMI::Form::ModUserGroup;
has 'form_mod_groups' =>
  ( isa => 'UMI::Form::ModUserGroup', is => 'rw', lazy => 1,
    default => sub { UMI::Form::ModUserGroup->new }, );

use UMI::Form::ModRadGroup;
has 'form_mod_rad_groups' =>
  ( isa => 'UMI::Form::ModRadGroup', is => 'rw', lazy => 1,
    default => sub { UMI::Form::ModRadGroup->new }, );

use UMI::Form::ModGroupMemberUid;
has 'form_mod_memberUid' =>
  ( isa => 'UMI::Form::ModGroupMemberUid', is => 'rw', lazy => 1,
    default => sub { UMI::Form::ModGroupMemberUid->new }, );

use UMI::Form::AddServiceAccount;
has 'form_add_svc_acc' =>
  ( isa => 'UMI::Form::AddServiceAccount', is => 'rw', lazy => 1,
    default => sub { UMI::Form::AddServiceAccount->new }, );

=head1 NAME

UMI::Controller::SearchBy - Catalyst Controller

=head1 DESCRIPTION

Main search tool. In general it is sophisticated ldapsearch wrapper.

=cut

######################################################################

=head2 index

=cut

sub index :Path :Args(0) {
  my ( $self, $c ) = @_;

  # if ( defined $c->session->{"auth_uid"} ) {
  if ( defined $c->user_exists ) {
    $c->stats->profile(begin => 'PREPARE');

    my ( $params, $ldap_crud, $filter, $filter_meta, $filter_translitall, $base, $sizelimit, $return );
    my $sort_order = 'reverse';
    my $filter_armor = '';

    $params = $c->req->params;
    $ldap_crud = $c->model('LDAP_CRUD');

    #=============================================================
    ### ACCES CONTROL

    my $c_user_d = $ldap_crud->org_domains( $c->user->has_attribute('o'));

    ### ACCES CONTROL
    #=============================================================

    if ( $params->{'ldapsearch_global'} // ! exists $params->{'ldapsearch_base'}) {
      $base = $ldap_crud->{cfg}->{base}->{db};
      $params->{'ldapsearch_base'} = $base;
    } elsif ( $params->{'ldapsearch_by_name'}  //
	      $params->{'ldapsearch_by_email'} //
	      $params->{'ldapsearch_by_jid'}   //
	      $params->{'ldapsearch_by_telephone'} ) {
      $base = $ldap_crud->cfg->{base}->{acc_root};
    } elsif ( defined $params->{'ldap_subtree'} && $params->{'ldap_subtree'} ne '' ) {
      $base = $params->{'ldap_subtree'};
      $sizelimit = 0;
    } else {
      $base = $params->{ldapsearch_base};
    }

    if ( defined $params->{'ldapsearch_filter'} &&
	 $params->{'ldapsearch_filter'} eq '' ) {
      $filter_meta = '*';
    } else {
      $filter_meta = $params->{'ldapsearch_filter'};
    }

    if ( defined $params->{'ldapsearch_by_email'} ) {
      # $filter = sprintf("mail=%s", $filter_meta);
      $filter = sprintf("|(mail=%s)(&(uid=%s)(authorizedService=mail@*))",
			$filter_meta, $filter_meta );
      $base   = $ldap_crud->cfg->{base}->{acc_root};
      $params->{'ldapsearch_base'} = $base;
    } elsif ( defined $params->{'ldapsearch_by_jid'} ) {
      $filter = sprintf("&(authorizedService=xmpp@*)(uid=*%s*)", $filter_meta);
      $base   = $ldap_crud->cfg->{base}->{acc_root};
      $params->{'ldapsearch_base'} = $base;
    } elsif ( defined $params->{'ldapsearch_by_ip'} ) {
      my @narr = split(/\./, $filter_meta);
      pop @narr if scalar @narr == 4;
      $filter = sprintf("|(dhcpStatements=fixed-address %s)(umiOvpnCfgIfconfigPush=%s*)(umiOvpnCfgIroute=%s.*)(ipHostNumber=%s*)",
			$filter_meta, $filter_meta, join('.', @narr), $filter_meta);
      $base   = $ldap_crud->cfg->{base}->{db};
      $params->{'ldapsearch_base'} = $base;
    } elsif ( defined $params->{'ldapsearch_pgp'} ) {
      $filter = sprintf("|(pgpCertID=%s)(pgpKeyID=%s)(pgpUserID=%s)",
			$filter_meta, $filter_meta, $filter_meta);
      $base   = $ldap_crud->cfg->{base}->{pgp};
      $params->{'ldapsearch_base'} = $base;
    } elsif ( defined $params->{'ldapsearch_by_mac'} ) {
      my $mac = $self->macnorm({ mac => $filter_meta });
      log_debug { np($mac) };
      push @{$return->{error}}, 'incorrect MAC address'
	if ! $mac;
      $filter = sprintf("|(dhcpHWAddress=ethernet %s)(&(uid=%s)(authorizedService=dot1x*))(&(cn=%s)(authorizedService=dot1x*))(hwMac=%s)",
			$self->macnorm({ mac => $filter_meta, dlm => ':', }),
			$self->macnorm({ mac => $filter_meta }),
			$self->macnorm({ mac => $filter_meta }),
			$self->macnorm({ mac => $filter_meta }) );

      $base   = $ldap_crud->cfg->{base}->{db};
      $params->{'ldapsearch_base'} = $base;
    } elsif ( defined $params->{'ldapsearch_by_name'} ) {
      $params->{'ldapsearch_base'} = $base = $ldap_crud->cfg->{base}->{acc_root};
      $filter = sprintf("|(givenName=%s)(sn=%s)(uid=%s)(cn=%s)",
			$filter_meta, $filter_meta, $filter_meta, $filter_meta);
    } elsif ( defined $params->{'ldapsearch_by_telephone'} ) {
      $params->{'ldapsearch_base'} = $base = $ldap_crud->cfg->{base}->{acc_root};
      $filter = sprintf("|(telephoneNumber=%s)(mobile=%s)(homePhone=%s)",
			$filter_meta, $filter_meta, $filter_meta);
    } elsif ( defined $params->{'ldapsearch_base'} &&
	      $params->{'ldapsearch_base'} eq $ldap_crud->cfg->{base}->{org} ) {
      # SPECIAL CASE: we wanna each user (except admins) be able to see only org/s he belongs to
      $filter = $params->{'ldapsearch_filter'} ne '' ? $params->{'ldapsearch_filter'} : 'objectClass=*';
      $base   = $params->{'ldapsearch_base'};
      $filter_armor = join('', @{[ map { '(associatedDomain=' . $_ . ')' } @{$c_user_d->{success}} ]} )
	if ! $ldap_crud->role_admin;
    } elsif ( defined $params->{'ldapsearch_filter'} &&
	      $params->{'ldapsearch_filter'} ne '' ) {
      $filter = $params->{'ldapsearch_filter'};
      $base   = $params->{'ldapsearch_base'};
    } elsif ( defined $params->{'ldap_subtree'} &&
	      $params->{'ldap_subtree'} ne '' ) {
      $filter = 'objectClass=*';
      $base   = $params->{'ldap_subtree'};
    } elsif ( defined $params->{'ldap_history'} &&
	      $params->{'ldap_history'} ne '' ) {
      $filter     = 'reqDN=' . $params->{'ldap_history'};
      $sort_order = 'straight';
      $base       = UMI->config->{ldap_crud_db_log};
    } else {
      $filter = 'objectClass=*';
      $base   = $params->{'ldapsearch_base'};
    }

    my $scope = $params->{ldapsearch_scope} // 'sub';

    if ( ! $c->check_any_user_role( qw/admin coadmin/ ) &&
	 ! $self->may_i({ base_dn => $base,
			  filter  => $filter,
			  user    => $c->user, }) ) {
      log_error { sprintf('User roles or Tools->may_i() check does not allow search by base dn: %s and/or filter: %s',
			  $base,
			  $filter ) };
      $c->stash( template => 'ldap_err.tt',
		 final_message => { error
				    => sprintf('Your roles or Tools->may_i() check does not allow search by base dn:<h5>&laquo;<b><em>%s</em></b>&raquo;</h5> and/or filter:<h5>&laquo;<b><em>%s</em></b>&raquo;</h5>ask UMI admin for explanation/s and provide above info.',
					       $base,
					       $filter ), }, );
      return 0;
    }

    my $filter4search = $filter_armor eq '' ? sprintf("(%s)", $filter ) : sprintf("&(%s)(|%s)",
										  $filter,
										  $filter_armor );

    $c->stats->profile(begin => '- LDAP search lasted');

    $params->{'filter'} = '(' . $filter . ')';
    my $mesg =
      $ldap_crud->search({base      => $base,
			  filter    => $filter4search,
			  sizelimit => $sizelimit // $ldap_crud->{cfg}->{defaults}->{sizelimit},
			  scope     => $scope,
			  attrs     => [ '*',
					 'createTimestamp',
					 'creatorsName',
					 'modifiersName',
					 'modifyTimestamp',
					 'entryTtl',
					 'entryExpireTimestamp', ],
			 });

    my @entries =
      defined $params->{order_by} && $params->{order_by} ne '' ?
      $mesg->sorted(split(/,/,$params->{order_by})) :
      $mesg->sorted('dn');

    my $all_entries = $mesg->as_struct;
    # log_debug { np( $all_entries ) };

    if ( ! $mesg->count ) {
      if ( $self->is_ascii($params->{'ldapsearch_filter'}) &&
	   $params->{'ldapsearch_by_name'} ne 1 ) {
	$filter_translitall = $self->utf2lat($params->{'ldapsearch_filter'}, 1);
	push @{$return->{warning}},
	  $ldap_crud->err($mesg)->{html},
	  sprintf('Alternate transliteration: <em>%s, %s, %s</em><br><small><em class="text-info">please note, translit variants above are provided only as examples, in DB only ASCII characters are allowed!</em></small>',
		  $filter_translitall->{'GOST 7.79 RUS'},
		  $filter_translitall->{'DIN 1460 RUS'},
		  $filter_translitall->{'ISO 9'} );
      } else {
	push @{$return->{warning}}, $ldap_crud->err($mesg)->{html};
      }
    }

    $c->stats->profile(end   => '- LDAP search lasted');

    my ( $foffs, $ttentries, @ttentries_keys, $attr, $tmp, $dn, $dn_depth, $dn_depthes, $to_utf_decode, @root_arr, @root_dn_arr, $root_dn, $root_i, $root_mesg, $root_entry, $primary_group_name, @root_groups, $root_gr, $gr_entry, $obj_item, $c_name, $m_name );

    # building sys groups members hash
    my $all_sysgroups;
    my $sysgr_msg = $ldap_crud->search({ base   => $ldap_crud->{cfg}->{base}->{system_group},
					 filter => '(objectClass=*)',
					 attrs  => [ $ldap_crud->{cfg}->{rdn}->{group}, 'memberUid' ], });

    my ($grhash, $grkey);
    if ( $sysgr_msg->is_error() ) {
      $return->{error} .= $ldap_crud->err( $sysgr_msg )->{html};
    } else {
      $grhash = $sysgr_msg->as_struct;
      my %memberuids;
      foreach $grkey (keys (%{$grhash})) {
	%memberuids = map { $_ => 1 } @{$grhash->{$grkey}->{memberuid}};
	%{$all_sysgroups->
	  {$grhash->{$grkey}->{$ldap_crud->{cfg}->{rdn}->{group}}->[0]}} = %memberuids;
	%memberuids = ();
      }
    }

    $c->stats->profile(end   => 'PREPARE');

    foreach (@entries) {
      $dn = $_->dn;

      $c->stats->profile(begin => 'ENTRY', comment => 'dn: ' . $dn);

      $foffs = $self->factoroff_searchby({
					  all_entries   => $all_entries,
					  all_sysgroups => $all_sysgroups,
					  c_stats       => $c->stats,
					  entry         => $_,
					  ldap_crud     => $ldap_crud,
					  session       => $c->session,
					 });

      $return->{error} .= $foffs->{return}->{error} if exists $foffs->{return}->{error};

      $ttentries->{$dn}->{root}   = $foffs->{root};
      $ttentries->{$dn}->{mgmnt}  = $foffs->{mgmnt};
      $ttentries->{$dn}->{attrs}  = $foffs->{attrs};
      $ttentries->{$dn}->{is_arr} = $foffs->{is_arr};


      if ( $dn =~ /.*,$ldap_crud->{cfg}->{base}->{acc_root}/ ) {
	#=============================================================
	### ACCES CONTROL to ou=People,dc=... objects for not admins
	### START
	# the main idea for this, is to intersect user's all-domains-of-all-orgs
	# array against:
	# 1. all-domains-of-root-object-orgs array for each search result entry
	# 2. current search result entry associatedDomain attribute value/s, if any

	if ( ! $ldap_crud->role_admin ) {
	  $c->stats->profile(begin => '- acl check');

	  # !!! TODO !!! to process errors when no "o" attribute exists or it is not DN
	  $ttentries->{$dn}->{root}->{associatedDomain} =
	    $ldap_crud->org_domains( $ttentries->{$dn}->{root}->{o} )
	    if ! exists $ttentries->{$dn}->{root}->{associatedDomain};
	  # log_debug { np( $ttentries->{$dn}->{root} ) };
	
	  if ( exists $ttentries->{$dn}->{root}->{associatedDomain}->{error} ) {
	    push @{$return->{error}}, sprintf("root object of <b>%s</b> has a problem:<br>%s", $dn, $_->{html})
	      foreach (@{$ttentries->{$dn}->{root}->{associatedDomain}->{error}});
	  }

	  use Array::Utils qw(:all);
	  # all-domains-of-root-object-orgs (current search result relates to) array
	  my @l = @{$ttentries->{$dn}->{root}->{associatedDomain}->{success}};
	  # all-domains-of-all-orgs (current user belongs to) array
	  my @r = @{$c_user_d->{success}};
	  my @intersect = intersect( @l, @r );
	
	  # log_debug { sprintf("\n%s\nCURRENT_OBJ_DN: %s\n\nCURRENT_ROOT_OBJ_DOMAINS\n\t%s\nCURRENT_USR_DOMAINS\n\t%s\nINTERSECTION\n\t%s\nIS ADMIN :%s; intersect size: %s\n\n",
	  # 		    '-' x 70,
	  # 		    $dn,
	  # 		    np( $ttentries->{$dn}->{root}->{associatedDomain} ),
	  # 		    np( $ldap_crud->org_domains( $c->user->has_attribute('o')) ),
	  # 		    np( @intersect ),
	  # 		    $ldap_crud->role_admin,
	  # 		    $#intersect ) };

	  # remove current search result entry from the search result list if current user
	  # is not admin and current user org/s domain/s doesn't intersect with
	  # current search result entry root object's org/s domain/s
	  if ( ! $ldap_crud->role_admin && $#intersect < 0) {
	    delete $ttentries->{$dn};
	    next;
	  }

	  # for objects with present associatedDomain attribute (in general services)
	  if ( $_->exists('associatedDomain') ) {
	    $#intersect = -1;
	    @l = @{[$_->get_value('associatedDomain')]};
	    @intersect = intersect( @l, @r );
	
	    # log_debug { sprintf("CURRENT_OBJ_DOMAINS\n\t%s\nINTERSECTION SVC\n\t%s\nIS ADMIN :%s; intersect svc size: %s\n\n",
	    # 		      np( @l ),
	    # 		      np( @intersect ),
	    # 		      $c->check_user_roles( qw/admin/),
	    # 		      $#intersect ) };

	    # skip current search result (the one with present associatedDomain attribute)
	    # entry from the search results if current user
	    # is not admin and current user org/s domain/s doesn't intersect with
	    # current search result entry domain/s
	    if ( ! $ldap_crud->role_admin && $#intersect < 0) {
	      delete $ttentries->{$dn};
	      next;
	    }
	  }
	  $c->stats->profile(end => '- acl check');
	}
	### STOP
	### ACCES CONTROL to ou=People,dc=... objects
	#=============================================================
      }

      push @ttentries_keys, $dn if $sort_order eq 'reverse'; # for not history searches

      $c->stats->profile(end => '- obj mgmnt data');

      # $c->stats->profile('whole entry');
      $c->stats->profile(end => 'ENTRY');

      # log_debug { np( $ttentries->{$dn} ) };

    }

    # log_debug { np($all_entries) };
    
    # suffix array of dn preparation to respect LDAP objects "inheritance"
    # http://en.wikipedia.org/wiki/Suffix_array
    # this one to be used for all except history requests
    # my @ttentries_keys = map { scalar reverse } sort map { scalar reverse } keys %{$ttentries};
    # this one to be used for history requests
    # my @ttentries_keys = sort { lc $a cmp lc $b } keys %{$ttentries};

    # my @ttentries_keys = $sort_order eq 'reverse' ?
    #   map { scalar reverse } sort map { scalar reverse } keys %{$ttentries} :
    #   sort { lc $a cmp lc $b } keys %{$ttentries};

    @ttentries_keys = sort { lc $a cmp lc $b } keys %{$ttentries}
      if $sort_order eq 'straight'; # for history searches

    $c->stash(
	      base_dn       => $base,
	      base_icon     => $ldap_crud->cfg->{base}->{icon},
	      entries       => $ttentries,
	      entrieskeys   => \@ttentries_keys,
	      filter        => $filter,
	      final_message => $return,
	      schema        => $c->session->{ldap}->{obj_schema_attr_equality},
	      scope         => $scope,
	      services      => $ldap_crud->cfg->{authorizedService},
	      template      => 'search/searchby.tt',
	     );
  } else {
    $c->stash( template => 'signin.tt', );
  }

}


######################################################################
# SearchBy main processing logics
######################################################################


=head1 proc

SearchBy main processing logics

=cut


sub proc :Path(proc) :Args(0) {
  my ( $self, $c ) = @_;

  # if ( defined $c->session->{"auth_uid"} ) { 
  if ( defined $c->user_exists ) {
    my $params = $c->req->parameters;

    my ($ldap_crud, $mesg, $return, $attr, $entry_tmp, $entry);
    $ldap_crud = $c->model('LDAP_CRUD');

    # log_debug { np($params) };
    # log_debug { np($c->stash) };
    foreach my $ldap_xxx (keys (%{$c->stash})) {
      next if $ldap_xxx !~ /ldap_/;
      if ( ! exists $params->{$ldap_xxx} ) {
	$params->{$ldap_xxx} = $c->stash->{$ldap_xxx};
	log_info { 'parameter ' . $ldap_xxx . ' is present in stash but was not passed with params => some method (not form) set it' };
      }
    }

#=====================================================================
# Modify (all fields form), here we pass data to a sub modify() bellow
#=====================================================================
    if (defined $params->{'ldap_modify'} && $params->{'ldap_modify'} ne '') {
      # log_debug { np($params) };

      $c->stats->profile( begin => "searchby_modify" );
  
      $mesg = $ldap_crud->search( { dn => $params->{ldap_modify} } );
      $return->{error} = $ldap_crud->err( $mesg )->{html} if ! $mesg->count;
      $entry_tmp = $mesg->entry(0);

      $c->stats->profile('search for <i class="text-light">' . $params->{ldap_modify} . '</i>');
      # log_debug { np($entry_tmp) };
      log_debug { np($return) } if defined $return;
      foreach $attr ( $entry_tmp->attributes ) {
	if ( $entry_tmp->get_value($attr) eq '' ||
	     (ref($entry_tmp->get_value($attr)) eq 'ARRAY' &&
	      $entry_tmp->get_value($attr)->[0] eq '')) {
	  push @{$return->{warning}},
	    sprintf("attribute <i><b>%s</b></i> is empty, it will be deleted on submit", $attr);
	}
	
	if ( $attr =~ /;binary/ or
	   $attr eq "userPKCS12" ) { ## !!! temporary stub !!! 	  next;
	  $entry->{$attr} = "BINARY DATA";
	} elsif ( $attr eq 'jpegPhoto' ) {
	  $entry->{$attr} =
	    sprintf("data:image/jpg;base64,%s",
		    encode_base64(join('', @{$entry_tmp->get_value($attr, asref => 1)}))
		   );
	# } elsif ( $attr eq 'userPassword' ) {
	#   next;	#   $entry->{$attr} = '*' x 8;
	} else {
	  $entry->{$attr} = $entry_tmp->get_value($attr, asref => 1);
	  map { utf8::decode($_),$_ } @{$entry->{$attr}};
	}
      }

      $c->stats->profile('all fields are ready');

      # here we building the list @{$names} of all attributes of each objectClass
      # of the $entry, for each element we investigate, whether the attribute
      # single-value or not
      my ($is_single, $names);
      foreach my $objectClass (sort @{$entry->{objectClass}}) {
	foreach $attr (sort (keys %{$c->session->{ldap}->{obj_schema}->{$objectClass}->{must}} )) {
	  #next if $attr eq "objectClass";
	  $names->{$attr} = 0;
	}
	foreach $attr (sort (keys %{$c->session->{ldap}->{obj_schema}->{$objectClass}->{may}} )) {
	  #next if $attr eq "objectClass";
	  $names->{$attr} = 0;
	}
      }
      # here we remove all attributes already present in the $entry
      delete $names->{$_} foreach ( $entry_tmp->attributes );

      $c->stats->profile('schema is ready');

      # push into $return all things which could be in $c->stash->{final_message}
      if ( exists $c->stash->{final_message} ) {
	push @{$return->{$_}}, @{$c->stash->{final_message}->{$_}}
	  foreach (keys (%{$c->stash->{final_message}}));
      }
      # log_debug { np($is_single) };
      $c->stash(
		attrs_rest    => $names,
		entries       => $entry,
		final_message => $return,
		modify        => $params->{'ldap_modify'},
		rdn           => (split('=', (split(',', $params->{ldap_modify}))[0]))[0],
		schema        => $c->session->{ldap}->{obj_schema_attr_single},
		template      => 'search/modify.tt', # !!! look modify() bellow
	       );

      $c->stats->profile( end => "searchby_modify" );

#=====================================================================
# Modify Groups of the user
#=====================================================================
    } elsif ( defined $params->{'ldap_modify_group'} &&
	      $params->{'ldap_modify_group'} ne '' ) {
      # log_debug { np( $params ) };
      my $groups;
      if ( defined $params->{groups} ) {
	$groups = ref($params->{groups}) eq 'ARRAY' ? $params->{groups} : [ $params->{groups} ];
      } else {
	$groups = undef;
      }

      my $ldap_crud = $c->model('LDAP_CRUD');
      my $id;
      my $mesg = $ldap_crud->search( { base  => $params->{'ldap_modify_group'},
				       scope => 'base',
				       attrs => [ 'uid' ], });
      push @{$return->{error}}, $ldap_crud->err($mesg)->{caller} . $ldap_crud->err($mesg)->{html}
	if $mesg->code != 0;
      $id = $mesg->entry(0)->get_value( $ldap_crud->{cfg}->{rdn}->{acc_root} );

      if ( ! defined $params->{groups} && ! defined $params->{aux_runflag} ) {
	my ( $return, $base, $filter, $dn );
	$mesg = $ldap_crud->search( { base      => $ldap_crud->cfg->{base}->{group},
				      filter    => sprintf('memberUid=%s', $id),
				      sizelimit => 0,
				      attrs     => ['cn'], } );
	push @{$return->{error}}, $ldap_crud->err($mesg)->{caller} . $ldap_crud->err($mesg)->{html}
	  if $mesg->code != 0;

	push @{$params->{groups}}, map { $_->dn } $mesg->sorted('cn');
      }
      log_debug { np( $params ) };

      $c->stash( template          => 'user/user_mod_group.tt',
		 form              => $self->form_mod_groups,
		 ldap_modify_group => $params->{ldap_modify_group}, );

      log_debug { np( $self->form_mod_groups->value ) };
      return unless $self->form_mod_groups
      	->process( posted => ($c->req->method eq 'POST' ),
		   params => $params,
		   ldap_crud => $ldap_crud );
      log_debug { np( $self->form_mod_groups->value ) };

      $c->stash( final_message => $self
      		 ->mod_groups( $ldap_crud,
      			       { mod_groups_dn => $params->{ldap_modify_group},
      				 base          => $ldap_crud->cfg->{base}->{group},
      				 groups        => $groups,
      				 type          => 'posixGroup', } ), ) if defined $params->{aux_runflag}; # !!! otherwise all groups are deleted on the initial run

#=====================================================================
# Modify RADIUS Groups
#=====================================================================
    } elsif ( defined $params->{'ldap_modify_rad_group'} &&
	      $params->{'ldap_modify_rad_group'} ne '') {

      my $groups;
      if ( defined $params->{groups} ) {
	$groups = ref($params->{groups}) eq 'ARRAY' ? $params->{groups} : [ $params->{groups} ];
      } else {
	$groups = undef;
      }

      my $ldap_crud = $c->model('LDAP_CRUD');

      if ( ! defined $params->{groups} && ! defined $params->{aux_runflag} ) {
	my ( $return, $base, $filter, $dn );
	my $mesg = $ldap_crud->search( { base   => $ldap_crud->cfg->{base}->{rad_groups},
					 filter => sprintf('member=%s', $params->{'ldap_modify_rad_group'}),
					 attrs  => ['cn'], } );
	push @{$return->{error}}, $ldap_crud->err($mesg)->{caller} . $ldap_crud->err($mesg)->{html}
	  if $mesg->code != 0;

	push @{$params->{groups}}, map { $_->dn } $mesg->sorted('cn');
      }

      $c->stash( template              => 'user/user_mod_rad_group.tt',
		 form                  => $self->form_mod_rad_groups,
		 ldap_modify_rad_group => $params->{'ldap_modify_rad_group'}, );

      return unless $self->form_mod_rad_groups
      	->process( posted    => ($c->req->method eq 'POST'),
		   params    => $params,
		   ldap_crud => $ldap_crud );

      $c->stash( final_message => $self
		 ->mod_groups( $ldap_crud,
			       { mod_groups_dn => $params->{ldap_modify_rad_group},
				 base          => $ldap_crud->cfg->{base}->{rad_groups},
				 groups        => $groups,
				 type          => 'groupOfNames', } ), ) if defined $params->{aux_runflag}; # !!! otherwise all groups are deleted on the initial run

#=====================================================================
# Modify memberUids of the Group
#=====================================================================
    } elsif ( defined $params->{'ldap_modify_memberUid'} &&
	      $params->{'ldap_modify_memberUid'} ne '') {
      
      $c->stash( template => 'group/group_mod_memberUid.tt',
		 form     => $self->form_mod_memberUid,
		 groupdn  => $params->{ldap_modify_memberUid}, );

      my $ldap_crud = $c->model('LDAP_CRUD');
      
      # first run (coming from searchby)
      if ( keys %{$params} == 1 ) {
	my $init_obj = { ldap_modify_memberUid => $params->{ldap_modify_memberUid} };
	my $return;
	my $mesg = $ldap_crud
	  ->search({ base      => $params->{ldap_modify_memberUid},
		     attrs     => ['memberUid'],
		     sizelimit => 0,});

	push @{$return->{error}}, $ldap_crud->err($mesg)->{html}
	  if $mesg->code ne '0';

	push @{$init_obj->{memberUid}},
	  map { $_->get_value('memberUid') } $mesg->sorted('memberUid');

	# first run, we just have choosen the group to manage and here we
	# render it as it is (no params passed, just init_object)
	return unless $self->form_mod_memberUid
	  ->process( init_object => $init_obj,
		     ldap_crud   => $c->model('LDAP_CRUD'), );
      } else {
	# all next, after-submit runs
	return unless $self->form_mod_memberUid
	  ->process( posted    => ($c->req->method eq 'POST'),
		     params    => $params,
		     ldap_crud => $c->model('LDAP_CRUD'), );

	$c->stash( final_message => $self
		   ->mod_memberUid( $c->model('LDAP_CRUD'),
				    { mod_group_dn => $params->{ldap_modify_memberUid},
				      memberUid    => $params->{memberUid}, }), );
      }

#=====================================================================
# Modify GitACL order
#=====================================================================
    } elsif ( defined $params->{'ldap_gitacl_reorder'} &&
	      $params->{'ldap_gitacl_reorder'} ne '') {

###
### NOT FINISHED
###


      # in general preselected options has to be fed via field value
      # $params->{memberUid} = [ qw( memberUid0 ... memberUidN) ];
      #
      # no submit yet, it is first run
      if ( ! defined $params->{memberUid} ) {
	my ( @memberUid, $return );
	my $ldap_crud =
	  $c->model('LDAP_CRUD');
	my $mesg = $ldap_crud
	  ->search( {
		     base  => $params->{ldap_modify_memberUid},
		     attrs => ['memberUid'],
		    } );

	if ( $mesg->code ne '0' ) {
	  push @{$return->{error}}, $ldap_crud->err($mesg)->{caller} . $ldap_crud->err($mesg)->{html};
	}

	push @{$params->{memberUid}},
	  map { $_->get_value('memberUid') } $mesg->sorted('memberUid');
      }

      $c->stash(
		template              => 'group/group_mod_memberUid.tt',
		form                  => $self->form_mod_memberUid,
		ldap_modify_memberUid => $params->{'ldap_modify_memberUid'},
	       );

      return unless $self->form_mod_memberUid
      	->process(
      		  posted    => ($c->req->method eq 'POST'),
      		  params    => $params,
      		  ldap_crud => $c->model('LDAP_CRUD'),
      		 );

      $c->stash( final_message => $self
		 ->mod_memberUid(
				 $c->model('LDAP_CRUD'),
				 {
				  mod_group_dn => $params->{ldap_modify_memberUid},
				  memberUid    => $params->{memberUid},
				 }
				),
	       );

#=====================================================================
# Add userDhcp
#=====================================================================
    } elsif (defined $params->{'ldap_add_dhcp'} &&
	     $params->{'ldap_add_dhcp'} ne '') {

      $c->stash(
		template      => 'dhcp/dhcp_wrap.tt',
		form          => $self->form_add_dhcp,
		ldap_add_dhcp => $params->{'ldap_add_dhcp'},
	       );

      return unless $self->form_add_dhcp->process(
						  posted    => ($c->req->method eq 'POST'),
						  params    => $params,
						  ldap_crud => $c->model('LDAP_CRUD'),
						 );
      $c->stash(
      		final_message => $c->controller('Dhcp')
		->create_dhcp_host ( $c->model('LDAP_CRUD'),
				     {
				      cn             => $params->{cn},
				      net            => $params->{net},
				      uid            => substr((split(',', $params->{ldap_add_dhcp}))[0], 4),
				      dhcpComments   => $params->{dhcpComments},
				      dhcpHWAddress  => $params->{dhcpHWAddress},
				      dhcpStatements => $params->{dhcpStatements},
				     }
				   ),
      	       ) if $self->form_add_dhcp->validated;

#=====================================================================
# Modify jpegPhoto
#=====================================================================
    } elsif ( defined $params->{'ldap_modify_jpegphoto'} &&
	      $params->{'ldap_modify_jpegphoto'} ne '') {

      $params->{avatar} = $c->req->upload('avatar') if defined $params->{avatar};

      $c->stash(
		template              => 'user/user_modjpegphoto.tt',
		form                  => $self->form_jpegphoto,
		ldap_modify_jpegphoto => $params->{'ldap_modify_jpegphoto'},
	       );

      return unless $self->form_jpegphoto->process(
						   posted => ($c->req->method eq 'POST'),
						   params => $params,
						  ) && (defined $params->{avatar} && $params->{avatar} ne '' ) ||
						    ( defined $params->{remove} && $params->{remove} eq '1' );

      my $ldap_crud = $c->model('LDAP_CRUD');

      $c->stash( final_message => $self
		 ->mod_jpegPhoto(
				 $c->model('LDAP_CRUD'),
				 {
				  mod_jpegPhoto_dn => $params->{ldap_modify_jpegphoto},
				  jpegPhoto        => $params->{avatar},
				  remove           => $params->{remove},
				  jpegPhoto_stub   => $c
				  ->path_to('root', 'static', 'images',
					    $ldap_crud->cfg->{jpegPhoto}->{stub}),
				 }
				),
	       );

#=====================================================================
# Add Service Account
#=====================================================================
    } elsif ( defined $params->{'add_svc_acc'} &&
	      $params->{'add_svc_acc'} ne '') {

      my $ldap_crud = $c->model('LDAP_CRUD');
      my ( $arr, $login, $uid, $pwd, $return );
      my @id = split(',', $params->{'add_svc_acc'});
      $params->{'add_svc_acc_uid'} = substr($id[0], 4); # $params->{'login'} =
      my $dynamic_object = defined $params->{'dynamic_object'} && $params->{'dynamic_object'} ne '' ? 1 : 0;
      
      $c->stash(
		template        => 'user/user_add_svc.tt',
		form            => $self->form_add_svc_acc,
		add_svc_acc     => $params->{'add_svc_acc'},
		dynamic_object  => $dynamic_object,
		add_svc_acc_uid => $params->{'add_svc_acc_uid'},
	       );

      $params->{usercertificate} = $c->req->upload('usercertificate') if defined $params->{usercertificate};
      # p $params->{usercertificate};

      return unless $self->form_add_svc_acc->process(
						     posted    => ($c->req->method eq 'POST'),
						     params    => $params,
						     ldap_crud => $ldap_crud,
						    ) &&
						      defined $params->{'associateddomain'} &&
							defined $params->{'authorizedservice'};

      p $params;

      if ( $self->form_add_svc_acc->validated ) {

	if ( $params->{login} ne '' ) {
	  $login = $params->{login};
	} else {
	  $login = $params->{'add_svc_acc_uid'};
	}

	# fill $arr, all authorizedservice-s array
	if ( ref( $params->{'authorizedservice'} ) eq 'ARRAY' ) {
	  $arr = $params->{'authorizedservice'};
	} else {
	  $arr->[0] = $params->{'authorizedservice'};
	}

	my ($create_account_branch_return, $create_account_branch_leaf_return, $create_account_branch_leaf_params );
	foreach ( @{$arr} ) { # for each authorizedservice choosen
	  next if ! $_;

	  # here we take care of the situations where XMPP domains differs from SMTP
	  # like foo.bar for email and im.foo.bar for XMPP
	  if ( $params->{'associateddomain'} eq 'ibs.dn.ua' ) {
	    $params->{'associateddomain_prefix'} = 'im.';
	  } else {
	    $params->{'associateddomain_prefix'} = '';
	  }

	  $uid = $_ =~ /^dot1x-/ ?
	    $self->macnorm({ mac => $login }) :
	    sprintf('%s@%s',
		    $login,
		    $params->{'associateddomain_prefix'} . $params->{'associateddomain'});

	  if ( ( $_ eq 'mail' || $_ eq 'xmpp' ) &&
	      ( ! defined $params->{'password1'} ||
		$params->{'password1'} eq '' )) {
	    $pwd = { $_ => $self->pwdgen };
	  } elsif ( $_ eq 'ssh' ) {
	    $pwd->{$_}->{clear} = 'N/A';
	  } elsif ( $_ =~ /^dot1x-/ &&
		    $params->{'password0'} eq '' &&
		    $params->{'password1'} eq '' ) {
	    $pwd->{$_}->{clear} = $self->macnorm({ mac => $params->{'login'} });
	    $login = $self->macnorm({ mac => $login });
	  } else {
	    $pwd = { $_ => $self->pwdgen( { pwd => $params->{'password1'} } ) };
	  }

	  push @{$return->{success}}, {
				       authorizedservice => $_,
				       associateddomain  => $params->{'associateddomain_prefix'} . $params->{'associateddomain'},
				       service_uid => $uid,
				       service_pwd => $pwd->{$_}->{clear},
				      };

	  p my $ttl = Time::Piece->strptime( $params->{person_exp}, "%Y.%m.%d %H:%M");

	  $create_account_branch_return =
	    $c->controller('User')
	      ->create_account_branch ( $ldap_crud,
					{
					 base_uid         => substr($id[0], 4),
					 service          => $_,
					 associatedDomain => $params->{'associateddomain_prefix'} . $params->{associateddomain},
					 objectclass      => defined $params->{dynamic_object} && $params->{dynamic_object} ne '' ? 'dynamicObject' : '',
					 requestttl       => defined $params->{person_exp} && $params->{person_exp} ne '' ? $params->{person_exp} : '',
					},
				      );

	  $return->{error} .= $create_account_branch_return->[0] if defined $create_account_branch_return->[0];
	  $return->{warning} .= $create_account_branch_return->[2] if defined $create_account_branch_return->[2];

	  # requesting data to be used in create_account_branch_leaf()
	  my $mesg = $ldap_crud->search( {
					  base  => $params->{'add_svc_acc'},
					  scope => 'base',
					  attrs => [ 'uidNumber', 'givenName', 'sn' ],
					 } );
	  if ( ! $mesg->count ) { $return->{error} .= $ldap_crud->err($mesg)->{caller} . $ldap_crud->err($mesg)->{html}; }

	  my @entry = $mesg->entries;

	  my ($file, $jpeg);
	  if (defined $params->{'avatar'}) {
	    $params->{avatar} = $c->req->upload('avatar');
	    $file = $params->{'avatar'}->{'tempname'};
	  } else {
	    $file = undef;
	  }

	  $create_account_branch_leaf_params
	    = {
	       basedn           => $params->{'add_svc_acc'},
	       service          => $_,
	       associatedDomain => $params->{'associateddomain_prefix'} . $params->{associateddomain},
	       uidNumber       => $entry[0]->get_value('uidNumber'),
	       givenName       => $entry[0]->get_value('givenName'),
	       sn              => $entry[0]->get_value('sn'),
	       login           => $login,
	       password        => $pwd->{$_},
	       telephoneNumber => defined $params->{telephoneNumber} ? $params->{telephoneNumber} : undef,
	       jpegPhoto                  => $file,
	       userCertificate            => $params->{usercertificate},
	       radiusgroupname            => $params->{radiusgroupname},
	       radiustunnelprivategroupid => $params->{radiustunnelprivategroupid},
	       objectclass                => defined $params->{dynamic_object} && $params->{dynamic_object} ne '' ? 'dynamicObject' : '',
	       requestttl                 => defined $params->{person_exp} && $params->{person_exp} ne '' ? $params->{person_exp} : '',
	      };

	  if ( defined $params->{to_sshkeygen} ) {
	    $create_account_branch_leaf_params->{to_sshkeygen} = 1;
	  } elsif ( defined $params->{sshpublickey} &&
		    $params->{sshpublickey} ne '' ) {
	    $create_account_branch_leaf_params->{sshpublickey} = $params->{sshpublickey};
	    $create_account_branch_leaf_params->{sshkeydescr}  = $params->{sshkeydescr};
	  }



	  # p $create_account_branch_leaf_params;
	  $create_account_branch_leaf_return =
	    $c->controller('User')
	      ->create_account_branch_leaf (
					    $ldap_crud,
					    $create_account_branch_leaf_params,
					   );

	  # $success_message .= $create_account_branch_leaf_return->[1] if defined $create_account_branch_leaf_return->[1];
	  $return->{error} .= $create_account_branch_leaf_return->[0] if defined $create_account_branch_leaf_return->[0];

	}
      } else { # form was not validated
	$return->{error} = '<em>service was not added</em>' .
	  $return->{error} if $return->{error};
      }
      # p $success_message;
      $c->stash(
		final_message => $return,
	       );
    }
  } else {
    $c->stash( template => 'signin.tt', );
  }
}


#=====================================================================

=head1 mod_jpegPhoto

modify jpegPhoto method

=cut


sub mod_jpegPhoto {
  my ( $self, $ldap_crud, $args ) = @_;

  my $arg = {
	     mod_jpegPhoto_dn => $args->{mod_jpegPhoto_dn},
	     remove           => $args->{remove} || 0,
	     jpegPhoto        => $args->{jpegPhoto},
	     jpegPhoto_stub   => $args->{jpegPhoto_stub},
	    };

  my ( $fh, $final_message, $file, $jpeg);
  if (defined $arg->{jpegPhoto}) {
    $jpeg = $self->file2var( $arg->{jpegPhoto}->{'tempname'}, $final_message );

    return $jpeg if ref($jpeg) eq 'HASH' && defined $jpeg->{error};

    my $mesg = $ldap_crud->modify( $arg->{mod_jpegPhoto_dn},
				   [ replace => [ jpegPhoto => [ $jpeg ], ], ], );

    if ( $mesg ne '0' ) {
      $final_message->{error} = 'Error during jpegPhoto add/change occured: ' . $mesg->{html};
    } else {
      $final_message->{success} = '<b>jpegPhoto attribute is added/changed from file:</b>' .
	'<dl class="dl-horizontal"><dt>name:</dt><dd>' . $arg->{jpegPhoto}->{'filename'} . '</dd>' .
	'<dt>type:</dt><dd>' . $arg->{jpegPhoto}->{'type'} . '</dd>' .
	'<dt>size:</dt><dd>' . $arg->{jpegPhoto}->{'size'} . ' bytes size.</dd></dl>';
    }
  } elsif ( $arg->{remove} ) {
    my $mesg = $ldap_crud->modify( $arg->{mod_jpegPhoto_dn}, [ delete => [ jpegPhoto => [], ], ], );
    if ( $mesg ne '0' ) {
      $final_message->{error} = 'Error during jpegPhoto deletion occured: ' . $mesg->{html};
    } else {
      $final_message->{success} = 'jpegPhoto attribute was successfully deleted';
    }
  } else {
    $final_message->{success} = 'nothing to do ... neither removal was asked, nor new avatar choosen ...';
  }

  return $final_message;
}


=head1 modify_userpassword

modify userPassword method

if no password provided, then it will be auto-generated

if provided, then the first password field is used

=cut


sub modify_userpassword :Path(modify_userpassword) :Args(0) {
  my ( $self, $c ) = @_;
  my $p = $c->req->parameters;
  my $dc = Crypt::HSXKPasswd->default_config();
  use JSON;
  my $presets = decode_json(Crypt::HSXKPasswd->presets_json());
  push @{$presets->{defined_presets}}, 'CLASSIC';
  $presets->{preset_descriptions}->{CLASSIC} = 'Single-word, improved FIPS-181 NIST standard, password';
  push @{$presets->{defined_presets}}, 'USERDEFINED';
  $presets->{preset_descriptions}->{USERDEFINED} = 'Password provided by user';
  $presets = encode_json $presets;

  $c->stash(
	    template             => 'user/user_modpwd.tt',
	    form                 => $self->form_mod_pwd,
	    ldap_modify_password => $p->{ldap_modify_password},
	    xk_presets           => $presets,
	   );

  return unless $self->form_mod_pwd->process(
					     posted => ($c->req->method eq 'POST'),
					     params => $p,
					    ) &&
  					      ( defined $p->{password_init} ||
  						defined $p->{password_cnfm} ||
  						defined $p->{pwd_cap}       ||
  						defined $p->{pwd_len}       ||
  						defined $p->{pwd_num}       ||
  						defined $p->{checkonly}     ||
  						defined $p->{pronounceable} );

  my $arg = { mod_pwd_dn    => $p->{ldap_modify_password},
	      password_init => $p->{password_init},
	      password_cnfm => $p->{password_cnfm},
	      checkonly     => $p->{checkonly} || 0, };

  # log_debug { np($p) };
  # log_debug { np($arg) };
  # log_debug { np($presets) };

  my ( $return, $pwd, $mesg, $entry );
  my $ldap_crud = $c->model('LDAP_CRUD');
  my ( $is_pwd_msg, $is_pwd, $modify_action );
  $is_pwd_msg = $ldap_crud->search({ base => $arg->{mod_pwd_dn}, attr => [ 'userPassword', ], });
  if ( ! $is_pwd_msg->count ) {
    $return->{error} = 'no object with DN: <b>&laquo;' .
      $arg->{mod_pwd_dn} . '&raquo;</b> found!';
  } else {
    $is_pwd = $is_pwd_msg->entry(0);
    $arg->{pwd_orig} = $is_pwd->get_value('userPassword');
    
    if ( $self->form_mod_pwd->validated && $self->form_mod_pwd->ran_validation ) {

      if ( $arg->{password_init} eq '' && $arg->{password_cnfm} eq '' ) {
	my %xk;
	foreach (sort (keys %{$p})) {
	  next if $_ !~ /^xk_/;
	  next if ! defined $p->{$_} || $p->{$_} eq '';
	  if ( $_ =~ /^.*alphabet.*/ ) {
	    $xk{ substr($_,3) } = [ split(//, $p->{$_})];
	  } else {
	    $xk{ substr($_,3) } = $p->{$_};
	  }
	}

	if ( $xk{separator_character} eq 'CHAR' ) {
	  $xk{separator_character} = $xk{separator_character_char};
	  delete $xk{separator_character_char};
	  delete $xk{separator_character_random};
	} elsif ( $xk{separator_character} eq 'RANDOM' ) {
	  $xk{separator_alphabet} =
	    defined $xk{separator_character_random} && length($xk{separator_character_random}) > 0 ?
	    [ split(//, $xk{separator_character_random}) ] : $dc->{symbol_alphabet};
	  delete $xk{separator_character_random};
	  delete $xk{separator_character_char};
	} elsif ( $xk{separator_character} eq 'NONE' ) {
	  delete $xk{separator_character_char};
	  delete $xk{separator_character_random};
	}

	if ( $xk{padding_type} eq 'NONE' ) {
	  delete $xk{padding_character};
	  delete $xk{padding_character_char};
	  delete $xk{padding_character_random};
	} else {
	  if (  $xk{padding_character} eq 'SEPARATOR' ) {
	    delete $xk{padding_character_char};
	    delete $xk{padding_character_random};
	  } elsif (  $xk{padding_character} eq 'CHAR' ) {
	    $xk{padding_character} = $xk{padding_character_char};
	    delete $xk{padding_character_char};
	    delete $xk{padding_character_random};
	  } elsif ( $xk{padding_character} eq 'RANDOM' ) {
	    $xk{padding_alphabet} =
	      defined $xk{padding_character_random} && length($xk{padding_character_random}) > 0 ?
	      [ split(//, $xk{padding_character_random}) ] : $dc->{symbol_alphabet};
	    delete $xk{padding_character_char};
	    delete $xk{padding_character_random};
	  }
	}

	log_debug { np(%xk) };

	$arg->{password_gen} =
	  $self->
	  pwdgen({ gp => {len => defined $p->{pwd_len} && length($p->{pwd_len}) ? $p->{pwd_len} : undef,
			  num => defined $p->{pwd_num} && length($p->{pwd_num}) ? $p->{pwd_num} : undef,
			  cap => defined $p->{pwd_cap} && length($p->{pwd_cap}) ? $p->{pwd_cap} : undef,
			  pronounceable => $p->{pronounceable} // 0,
			 },
		   pwd_alg       => $p->{pwd_alg}       // undef,
		   xk            => \%xk,});
      } elsif ( $arg->{'password_init'} ne '' ) {
	$arg->{password_gen} = $self->pwdgen({ pwd => $arg->{password_init} });
      }

      # log_debug { np($arg) };

      if ( ! $arg->{checkonly} ) {
	$pwd = $arg->{mod_pwd_dn} =~ /.*authorizedService=dot1x-eap-md5.*/ ? $arg->{password_gen}->{clear} : $arg->{password_gen}->{ssha};
	$modify_action = defined $arg->{pwd_orig} && $arg->{pwd_orig} ne '' ?
	  [ replace => [ 'userPassword' => $pwd, ], ] :
	  [ add => [ 'userPassword' => $pwd, ], ] ;
	$mesg = $ldap_crud->modify( $arg->{mod_pwd_dn}, $modify_action );
      } else {
	$mesg = $ldap_crud->search( { base  => $arg->{mod_pwd_dn},
				      scope => 'base',
				      attrs => [ 'userPassword' ], } );
	$return->{error} .= $ldap_crud->err($mesg)->{caller} . $ldap_crud->err($mesg)->{html}
	  if ! $mesg->count;
	$entry = $mesg->as_struct;
	$arg->{password_match} =
	  $entry->{ $arg->{mod_pwd_dn} }->{userpassword}->[0] eq $arg->{password_gen}->{ssha}
	  ? 1 : 0;
	$mesg = 0;
      }

      my $qr_bg = 'table-success';
      if ( $mesg ne '0' ) {
	$return->{error} = '<li>Error during password change occured: ' . $mesg->{html} . '</li>';
      } else {
	if ( $arg->{checkonly} && $arg->{password_match} ) {
	  $mesg = '<div class="alert alert-success text-center" role="alert"><h3><b>Supplied password matches curent one</b></h3></div>';
	} elsif ( $arg->{checkonly} && ! $arg->{password_match} ) {
	  $qr_bg = 'table-warning';
	  $mesg = '<div class="alert alert-warning text-center" role="alert"><h3><b>Supplied password does not match curent one</b></h3></div>';
	} elsif ( ! $arg->{checkonly} ) {
	  $mesg = 'Password generated:';
	}
	#p $entry;
	#p $arg->{password_gen}->{ssha};

	$return->{success} = sprintf('%s<table class="table table-vcenter">
  <tr><td width="50%%"><h2 class="mono text-center">%s</h2></td>
      <td class="text-center" width="50%%">',
                                     $mesg,
                                     $arg->{password_gen}->{clear},
                                    );

	
	my $qr;
	for ( my $i = 0; $i < 41; $i++ ) {
	  $qr = $self->qrcode({ txt => $arg->{password_gen}->{clear}, ver => $i, mod => 5 });
	  last if ! exists $qr->{error};
	}

	$return->{error} = $qr->{error} if $qr->{error};

	$return->{success} .=
	  sprintf('<div class="row">
  <div class="py-3 col-12 text-center">
    <img alt="password QR" class="img-responsive img-thumbnail %s" src="data:image/jpg;base64,%s" title="password QR"/>
  </div>',
		  $qr_bg,
		  $qr->{qr} );

	$return->{success} .=
	  sprintf('</td><tr><td colspan="2"><div class="py-3 col-12">
  <div class="text-muted text-monospace" aria-label="Statistics" aria-describedby="button-addon2">
    <i class="fas fa-info-circle text-%s"></i>
    Entropy: between <b class="text-%s">%s</b> bits & <b class="text-%s">%s</b> bits blind &
    <b class="text-%s">%s</b> bits with full knowledge
    <small><em>(suggest keeping blind entropy above 78bits & seen above 52bits)</em></small>

    <a class="btn btn-link" data-toggle="collapse" href="#pwdStatus"
        role="button" aria-expanded="false" aria-controls="pwdStatus">
        full status
    </a>
  </div>
  <div class="collapse" id="pwdStatus">
    <div class="card card-body"><small><pre class="text-muted text-monospace">%s</pre></small></div>
  </div>',
		  $arg->{password_gen}->{stats}->{password_entropy_blind_min} < 78 ||
		  $arg->{password_gen}->{stats}->{password_entropy_blind_max} < 78 ||
		  $arg->{password_gen}->{stats}->{password_entropy_seen}      < 52 ? 'danger' : 'success',
		  $arg->{password_gen}->{stats}->{password_entropy_blind_min} > 78 ? 'success' : 'danger',
		  $arg->{password_gen}->{stats}->{password_entropy_blind_min},
		  $arg->{password_gen}->{stats}->{password_entropy_blind_max} > 78 ? 'success' : 'danger',
		  $arg->{password_gen}->{stats}->{password_entropy_blind_max},
		  $arg->{password_gen}->{stats}->{password_entropy_seen}      > 52 ? 'success' : 'danger',
		  $arg->{password_gen}->{stats}->{password_entropy_seen},
		  $arg->{password_gen}->{status})
	  if ! $arg->{checkonly} && $p->{pwd_alg} ne 'CLASSIC';

	$return->{success} .= '</div></td></tr></table>';

      }
    }
  }
  # p $arg;
  $return->{success} .= '</div>';
  $c->stash( final_message => $return,
	     on_post       => encode_json $p );
}


#=====================================================================

=head1 mod_groups

modify groups object is/can belong to, method

on input it expects hash with:
    obj_dn - DN of the object to manage group membership of
    groups - select `groups' passed from the form
    base   - base of the group branch (RADIUS, general, e.t.c.)
    type   - posixGroup or groupOfNames
    is_submit - is it first run or after submit event

=cut


sub mod_groups {
  my ( $self, $ldap_crud, $args ) = @_;
  my $arg = { obj_dn   => $args->{mod_groups_dn},
	      firstrun => $args->{firstrun},
	      groups   => $args->{groups},
	      base     => defined $args->{base} ? $args->{base} : $ldap_crud->cfg->{base}->{group},
	      type     => defined $args->{type} ? $args->{type} : 'posixGroup', };
  log_debug { np( $args ) };
  log_debug { np( $arg ) };
  my ( $mesg, $return);
  $mesg = $ldap_crud->search( { base  => $arg->{obj_dn},
				scope => 'base',
				attrs => [ 'uid' ], });
  push @{$return->{error}}, $ldap_crud->err($mesg)->{caller} . $ldap_crud->err($mesg)->{html}
    if $mesg->code != 0;
  $arg->{uid} = $mesg->entry(0)->get_value( 'uid' );

  # hash with all selected for add/delete group/s
  if ( ref($arg->{groups}) eq 'ARRAY' ) {
    $arg->{groups_sel}->{$_} = 1 foreach (@{$arg->{groups}});
  }
  # $return;
  $mesg =
    $ldap_crud->search( { base      => $arg->{base},
			  filter    => $arg->{type} eq 'posixGroup' ? 'memberUid=' . $arg->{uid} : 'member=' . $arg->{obj_dn},
			  sizelimit => 0,
			  attrs     => ['cn'], } );
  push @{$return->{error}}, $ldap_crud->err($mesg)->{caller} . $ldap_crud->err($mesg)->{html}
    if $mesg->code ne '0';

  my $g = $mesg->as_struct;
  # log_debug { np( $g ) };

  $mesg = $ldap_crud->search( { base      => $arg->{base},
				scope     => 'one',
				sizelimit => 0,
				attrs     => ['cn'], } );
  push @{$return->{error}}, $ldap_crud->err($mesg)->{caller} . $ldap_crud->err($mesg)->{html}
    if ! $mesg->count;

  my @groups_all = $mesg->sorted('cn');
  foreach ( @groups_all ) {
      $arg->{groups_all}->{$_->dn} = 0;
      $arg->{groups_sel}->{$_->dn} = 0
	if ! defined $arg->{groups_sel}->{$_->dn};
      $arg->{groups_old}->{$_->dn} =
	defined $g->{$_->dn} ? 1 : 0;
  }

  # after submit
  my @groups_chg;
  foreach (keys %{$arg->{groups_all}}) {
    # submited data equals to the data from DB - nothing to do
    next if $arg->{groups_old}->{$_} && $arg->{groups_sel}->{$_};
    if (( $arg->{groups_old}->{$_} && ! $arg->{groups_sel}->{$_} ) ||
	( $arg->{groups_old}->{$_} && ref($arg->{groups}) ne 'ARRAY' )) {
      # some group or even all unselected (present in old and absent in selected)
      push @groups_chg, 'delete' => $arg->{type} eq 'posixGroup' ?
	[ 'memberUid' => $arg->{uid} ] : [ 'member' => $arg->{obj_dn} ];
    } elsif ( ! $arg->{groups_old}->{$_} && $arg->{groups_sel}->{$_} ) {
      # old (DB) data lacks of submited (selected) data - add
      push @groups_chg, 'add' => $arg->{type} eq 'posixGroup' ?
	[ 'memberUid' => $arg->{uid} ] : [ 'member' => $arg->{obj_dn} ];
    }
    # log_debug { np(@groups_chg) ];
    if ( $#groups_chg > 0) {
      # p [sprintf('cn=%s,%s', $_, $arg->{base}), @groups_chg]
      # $mesg = $ldap_crud
      #   ->modify( $arg->{type} eq 'posixGroup' ? sprintf('cn=%s,%s', $_, $arg->{base}) : $_,
      # 	    \@groups_chg ); p $mesg;
      $mesg = $ldap_crud->modify( $_, \@groups_chg );
      if ( $mesg ) {
	push @{$return->{error}}, $mesg->{html};
      } else {
	push @{$return->{success}},
	  sprintf('<span class="%s">%s</span>',
		  $groups_chg[0] eq 'add' ? 'text-success" title="added to' : 'text-danger" title="deleted from',
		  $groups_chg[0] eq 'add' ? $_ : '<s>' . $_ . '</s>');
      }
    }
    $#groups_chg = -1;
  }
  log_debug { np( $return ) };
  # log_debug { np( $arg ) };
  return $return;
}

#=====================================================================

=head1 mod_memberUid

modify group members ( memberUid attribute/s )

=cut


sub mod_memberUid {
  my ( $self, $ldap_crud, $args ) = @_;
  use Data::Printer;
  p my $arg = {
	     mod_group_dn => $args->{mod_group_dn},
	     memberUid => ref($args->{memberUid}) eq 'ARRAY' ? $args->{memberUid} : [ $args->{memberUid} ],
	     cn => substr( (split /,/, $args->{mod_group_dn})[0], 3 ),
	    };

  my $return;
  my ( $memberUid, @memberUid_old );

  my $mesg = $ldap_crud->search( { base  => $arg->{mod_group_dn},
				   attrs => ['memberUid'], } );

  push @{$return->{error}}, $ldap_crud->err($mesg)->{caller} . $ldap_crud->err($mesg)->{html}
    if ! $mesg->count;

  push @memberUid_old, map { $_->get_value('memberUid') } $mesg->sorted('memberUid');

  my @a = sort @{$arg->{memberUid}};
  my @b = sort @memberUid_old; p \@b;
  if ( @a ~~ @b ) {
    $return->{success} = 'Nothing changed.';
  } else {
    foreach (@a) {
      push @{$memberUid}, 'memberUid', $_;
    }
    $mesg = $ldap_crud->modify(
			       $arg->{mod_group_dn},
			       [ replace => [ memberUid => \@a ] ],
			      );
    if ( $mesg ) {
      push @{$return->{error}}, $mesg->{html};
    } else {
      $return->{success} = 'Group was modified.';
    }
  }
  return $return;
}

#=====================================================================

=head1 ldif_gen

get LDIF (recursive or not, with or without system data) for the DN
given

Since it is separate action, it is poped out of action proc()

=cut


sub ldif_gen :Path(ldif_gen) :Args(0) {
  my ( $self, $c ) = @_;
  my $params = $c->req->parameters;
  log_debug { np($params) };

  my $attrs;
  if ( defined $params->{ldap_ldif_attrs} && ref($params->{ldap_ldif_attrs}) eq 'ARRAY' ) {
    $attrs = $params->{ldap_ldif_attrs};
  } elsif ( defined $params->{ldap_ldif_attrs} && ref($params->{ldap_ldif_attrs}) eq 'SCALAR' ) {
    $attrs =  [ $params->{ldap_ldif_attrs} ];
  }
  
  my $ldif = $c->model('LDAP_CRUD')->
    ldif({
	   attrs     => $attrs,
	   base      => $params->{ldap_ldif_base},
	   dn        => $params->{ldap_ldif},
	   filter    => $params->{ldap_ldif_filter},
	   recursive => $params->{ldap_ldif_recursive},
	   scope     => $params->{ldap_ldif_scope},
	   sysinfo   => $params->{ldap_ldif_sysinfo},
	 });
  $c->stash(
	    template => 'search/ldif.tt',
	    final_message => $ldif,
	   );
}

=head1 ldif_gen2f

method to download ldif_gen() results as text/plain file

=cut

sub ldif_gen2f :Path(ldif_gen2f) :Args(0) {
  my ( $self, $c ) = @_;
  my $params = $c->req->parameters;
  log_debug { np($params) };

  my $attrs;
  if ( defined $params->{ldap_ldif_attrs} && ref($params->{ldap_ldif_attrs}) eq 'ARRAY' ) {
    $attrs = $params->{ldap_ldif_attrs};
  } elsif ( defined $params->{ldap_ldif_attrs} && ref($params->{ldap_ldif_attrs}) eq 'SCALAR' ) {
    $attrs =  [ $params->{ldap_ldif_attrs} ];
  }

  my $ldif = $c->model('LDAP_CRUD')->
    ldif({
	   attrs     => $attrs,
	   base      => $params->{ldap_ldif_base},
	   dn        => $params->{ldap_ldif},
	   filter    => $params->{ldap_ldif_filter},
	   recursive => $params->{ldap_ldif_recursive},
	   scope     => $params->{ldap_ldif_scope},
	   sysinfo   => $params->{ldap_ldif_sysinfo}
	 });
  # log_debug { np($ldif) };
  $c->stash(
	    current_view => 'Download',
	    download     => 'text/plain',
	    plain        => $ldif->{ldif},
	    outfile_name => $ldif->{outfile_name} . '.ldif',
	   );
  $c->forward('UMI::View::Download');
}


#=====================================================================

=head1 vcard

get vCard (recursive or not, with or without system data) for the DN
given

Since it is separate action, it is poped out of action proc()

=cut


sub vcard_gen :Path(vcard_gen) :Args(0) {
  my ( $self, $c ) = @_;
  my $params = $c->req->parameters;
  my $vcard = $c->model('LDAP_CRUD')->vcard_neo( $params );
  $c->stash(
	    template      => 'search/vcard.tt',
	    final_message => $vcard,
	   );
}

sub vcard_gen2f :Path(vcard_gen2f) :Args(0) {
  my ( $self, $c ) = @_;
  my $params = $c->req->parameters;
  $params->{vcard_type} = 'file';
  my $vcard = $c->model('LDAP_CRUD')->vcard_neo( $params);
  # log_debug { np($vcard) };
  $c->stash(
	    current_view => 'Download',
	    download     => 'text/plain',
	    plain        => $vcard->{vcard},
	    outfile_name => $vcard->{outfile_name} . '.vcf',
	    outfile_ext  => 'vcf',
	   );
  $c->forward('UMI::View::Download');
  # $c->detach('UMI::View::Download');
}


#=====================================================================

=head1 modify

modify whole form (all present fields except RDN)

=cut


sub modify :Path(modify) :Args(0) {
  my ( $self, $c, $params ) = @_;

  log_debug { "modify(): params on start:\n" . np($params) };

  # whether we edit object as is or via creation form
  $params = $c->req->parameters if ! defined $params;
  my $action_detach_to = '/searchby/proc';
  if ( defined $params->{aux_dn_form_to_modify} && $params->{aux_dn_form_to_modify} ne '' ) {
    $params->{dn} = $params->{aux_dn_form_to_modify};
    $action_detach_to = '/searchby/modform';
  }

  log_debug { np($params) };

  my $return;
  my $dn = $params->{dn};

  my $service;
  if ( $dn =~ /^.*authorizedService.*$/ ) {
    if ( defined $params->{authorizedService} && $params->{authorizedService} ne '' ) {
      $service = (split(/\@/, $params->{authorizedService}))[0];
    } else {
      push @{$return->{error}}, 'attribute authorizedService is absent!';
    }
  }

  my $ldap_crud = $c->model('LDAP_CRUD');
  my $mesg = $ldap_crud->search( { base => $dn, scope => 'base' } );
  push @{$return->{error}}, $ldap_crud->err($mesg)->{html}
    if $mesg->code;

  my $entry = $mesg->entry(0);
  # log_debug { np($mesg) };

  my ($jpeg, $binary, $attr, $val_params, $val_entry, $cert_info);
  my $add     = undef;
  my $moddn   = undef;
  my $delete  = undef;
  my $replace = undef;
  # log_debug { np($params) };
  my @ea = $entry->attributes;
  # log_debug { np(@ea) };

  # sanitize $entry in case it has empty attributes
  foreach $attr ( $entry->attributes ) {
    if ( $entry->get_value($attr) eq '' ||
	 (ref($entry->get_value($attr)) eq 'ARRAY' && $entry->get_value($attr)->[0] eq '')) {
      push @{$delete}, $attr => [];
      push @{$return->{warning}},
	sprintf("empty attribute <i><b>%s</b></i> was deleted", $attr);
    }
  }

  foreach $attr ( sort ( keys %{$params} )) {
    next if $attr =~ /$ldap_crud->{cfg}->{exclude_prefix}/ ||
      $attr eq 'dn'; # ||
      # $attr =~ /userPassword/; ## !! stub, not processed yet !!
    if ( $attr eq 'jpegPhoto'                 ||
	 $attr eq 'cACertificate'             ||
	 $attr eq 'certificateRevocationList' ||
	 $attr eq 'userCertificate' ) {
      $params->{$attr} = $c->req->upload($attr);
    }

    # skip equal and undefined data
    $val_params  = $params->{$attr};
    next if ! defined $val_params;
    if ( ref($params->{$attr} ) eq 'ARRAY' ) {
      $val_entry      = $entry->exists($attr) ? $entry->get_value($attr, asref => 1) : [];
      @{$val_params}  = sort( @{$val_params} );
      @{$val_entry}   = sort( @{$val_entry} );
      next if $val_params ~~ $val_entry;
    } else {
      $val_entry = $entry->get_value($attr);
      next if defined $val_entry && $val_params eq $val_entry; # !!! looks like it is not needed && $val_params ne '';
    }

    # removing all empty array elements if any
    if ( ref($val_params) eq "ARRAY" ) {
      @{$val_params} = reverse map { $self->is_ascii($_) &&
			$attr ne 'givenName' && $attr ne 'sn' && $attr ne 'description'	?
			$self->utf2lat($_) : $_ }
	grep { $_ ne '' } @{$val_params};
    } elsif ( $val_params ne '' && defined $entry->get_value($attr) && $val_params ne $entry->get_value($attr) ) {
      $val_params = $self->utf2lat($val_params) if $self->is_ascii($val_params) &&
	$attr ne 'givenName' && $attr ne 'sn' && $attr ne 'description';
    }

    # what to do or to not to do?
    if ( $attr =~ /^add_.*$/ && $val_params ne '' ) {
      # log_debug { $attr . ';' . substr($attr,4) . ';' . $val_params };
      push @{$add}, substr($attr,4) => $val_params;
    } elsif ( $val_params ne '' &&
	      ref($val_params) ne "ARRAY" &&
	      ( $attr eq 'sshPublicKey' || $attr eq 'grayPublicKey') ) {
      log_debug { '%%% ONE val single & not empty & ssh key %%%' };
      # log_debug { np($val_params) };
      $val_params =~ tr/\r\n//d;
      # log_debug { np($val_params) };
      push @{$replace}, $attr => $val_params;
    } elsif ( $attr eq 'jpegPhoto' && $val_params ne '' ) {
      log_debug { '%%% TWO val not empty & photo %%%' };
      $jpeg = $self->file2var( $val_params->{'tempname'}, $return );
      return $jpeg if ref($jpeg) eq 'HASH' && defined $jpeg->{error};
      push @{$replace}, $attr => [ $jpeg ];
    } elsif ( $attr eq 'userCertificate' && $val_params ne '' ) {
      log_debug { '%%% THREE val not empty & cert %%%' };
      $binary = $self->file2var( $val_params->{'tempname'}, $return );
      return $binary if ref($binary) eq 'HASH' && defined $binary->{error};
      push @{$replace}, $attr . ';binary' => [ $binary ];
      $cert_info =
	$self->cert_info({ cert => $binary, ts => "%Y%m%d%H%M%S", });
      push @{$replace}, 'umiUserCertificateSn' => '' . $cert_info->{'S/N'},
	'umiUserCertificateNotBefore' => '' . $cert_info->{'Not Before'},
	'umiUserCertificateNotAfter'  => '' . $cert_info->{'Not  After'},
	'umiUserCertificateSubject'   => '' . $cert_info->{'Subject'},
	'umiUserCertificateIssuer'    => '' . $cert_info->{'Issuer'};

      # !!! TODO: looks like a kludge ...
      # ----------------------------------
      push @{$replace}, 'cn' => '' . $cert_info->{'CN'}, 'userPassword' => '' . $cert_info->{'CN'}
	if defined $service && $service ne 'ovpn';

      $moddn = sprintf("%s=%s",
		       $ldap_crud->{cfg}->{rdn}->{$service} // 'cn',
		       $cert_info->{'CN'});
      # ----------------------------------

    } elsif ( ( $attr eq 'cACertificate' ||
		$attr eq 'certificateRevocationList' ) && $val_params ne '' ) {
      log_debug { '%%% FOUR val not empty & CA or CRL %%%' };
      $binary = $self->file2var( $val_params->{'tempname'}, $return );
      return $binary if ref($binary) eq 'HASH' && defined $binary->{error};
      push @{$replace}, $attr . ';binary' => [ $binary ];
    } elsif ( $val_params eq '' && $entry->exists($attr) ) {
      log_debug { '%%% FIVE val empty & exists in LDAP %%%' };
      push @{$delete}, $attr => [];
    } elsif ( $val_params ne '' && ! defined $entry->get_value($attr) ) {
      log_debug { "%%% SIX val not empty & not in LDAP %%% attr: $attr" };
      # !!! ??? is it necessary here? can we leave it instead of replacing by itself
      if ( $attr eq 'jpegPhoto' ) {
	$jpeg = $self->file2var( $val_params->{'tempname'}, $return );
	return $jpeg if ref($jpeg) eq 'HASH' && defined $jpeg->{error};
	$val_params = [ $jpeg ];
      }
      push @{$add}, $attr => $val_params;
    } elsif ( ref($val_params) eq "ARRAY" && $#{$val_params} >= -1 ) {
      log_debug { "%%% SEVEN val multi & not empty %%% attr: $attr" };
      if ( $attr eq 'sshPublicKey' || $attr eq 'grayPublicKey' ) {
	push @{$replace}, $attr => [ map { $_ =~ tr/\r\n//d; $_ } @{$val_params} ];
      } else {
	push @{$replace}, $attr => $val_params;
      }
    } elsif ( ref($val_params) ne "ARRAY" && $val_params ne "" ) { # && $val_params ne $val_entry ) {
      log_debug { '%%% EIGHT val single & not empty %%%' };
      push @{$replace}, $attr => $val_params;
    }
  }

  my $modx;
  push @{$modx}, delete  => $delete  if defined $delete  && $#{$delete}  > -1;
  push @{$modx}, replace => $replace if defined $replace && $#{$replace} > -1;
  push @{$modx}, add     => $add     if defined $add     && $#{$add}     > -1;

  # log_debug { np($modx) };
  
  if ( defined $modx && $#{$modx} > -1 ) {
    log_debug { np( $modx ) };
    $mesg = $ldap_crud->modify( $params->{dn}, $modx, );
    if ( $mesg ne "0" ) {
      push @{$return->{error}}, $mesg->{html};
    } else {
      if ( defined $moddn && $moddn ne '' ) {
	$mesg = $ldap_crud->moddn({ src_dn => $params->{dn}, newrdn => $moddn, });
	if ( $mesg ne "0" ) {
	  push @{$return->{error}}, $mesg->{html};
	} else {
	  $dn =~ s/^(.+?),/$moddn,/;
	  push @{$return->{success}},
	    sprintf("<div class='alert alert-info border border-info'>
  <b>RDN changed as well</b><hr>
  <dl class='row'>
    <dt class='col-2 text-right'>old DN:</dt><dd class='col-10 text-monospace'>%s</dd>
    <dt class='col-2 text-right'>new DN:</dt><dd class='col-10 text-monospace'>%s</dd>
  </dl></div>", $params->{dn}, $dn);
	}
      }
      push @{$return->{success}}, 'Modification/s made:<pre class="text-monospace">' . "\n" .
	np($modx) . '</pre>';
      # 	  , caller_info    => 0,
      # 	   colored        => 0,
      # 	   hash_separator => ': ',
      # 	   separator      => "\n",
      # 	   multiline      => 0,
      # 	   index          => 0) . '</pre>';
      # log_debug { np ($modx)};
    }
  } else {
    push @{$return->{warning}}, 'No change was performed!';
  }

  log_info { 'here we detach to /searchby/proc with ldap_modify = ' . $dn . ' with return: ' . np($return) };
  $c->stash->{ldap_modify}           = $dn;
  $c->stash->{aux_dn_form_to_modify} = $params->{aux_dn_form_to_modify};
  $c->stash->{final_message}         = $return;
  $c->detach($action_detach_to);
}


#=====================================================================

=head1 modform

modify form as it is (reuse of add form)

=cut


sub modform :Path(modform) :Args(0) {
  my ( $self, $c ) = @_;
  my $params = $c->req->parameters;
  my ( $return, $form, $arg, $init_obj, $tmp, $i );

  $arg->{dn} = $params->{aux_dn_form_to_modify};
  
  my $ldap_crud = $c->model('LDAP_CRUD');

  my $mesg = $ldap_crud->search( { dn => $arg->{dn} } );
  $return->{error} = $ldap_crud->err( $mesg )->{html} if ! $mesg->count;
  my $entry = $mesg->entry(0);

  my ( $attr, $triple, $domain, $host, $user );
  foreach $attr ( $entry->attributes ) {
    next if $attr eq 'objectClass';
    $tmp = $entry->get_value( $attr, asref => 1 );
    map { utf8::decode($_); $_} @{$tmp};
    $init_obj->{$attr} = $#{$tmp} > 0 ? $tmp : $tmp->[0];
  }
  $init_obj->{aux_dn_form_to_modify} = $params->{aux_dn_form_to_modify};

  # log_debug { np($init_obj) };

  ####################################################################
  # TARGETS TO MODIFY
  ####################################################################
  # if ( $params->{aux_dn_form_to_modify} =~ /$ldap_crud->{cfg}->{base}->{acc_root}/ ) { ## ACCOUNTS
  #   $return->{success} = 'Form to be edited is account';
    
  # } els
  if ( $params->{aux_dn_form_to_modify} =~ /$ldap_crud->{cfg}->{base}->{gitacl}/ ) { ## GITACLs
    @{$init_obj->{gitAclOp_arr}} = split(//, $init_obj->{gitAclOp});
    $init_obj->{gitAclOp} = $init_obj->{gitAclOp_arr};
    delete $init_obj->{gitAclOp_arr};
    ( $init_obj->{gitAclUser}, $init_obj->{gitAclUser_cidr} ) = split(/@/, $init_obj->{gitAclUser});
    if ( $init_obj->{gitAclUser} !~ /^%/ ) {
      $init_obj->{gitAclUser_user} = $init_obj->{gitAclUser};
    } else {
      $init_obj->{gitAclUser_group} = $init_obj->{gitAclUser};
    }
    delete $init_obj->{gitAclUser};

    use UMI::Form::GitACL;
    $form = UMI::Form::GitACL->new( init_object => $init_obj, );
    $return->{warning} = 'js has to be refactoried!!!';
    $c->stash( template => 'gitacl/gitacl_wrap.tt',
	       final_message => $return, );

# old, low/middle level variant #   } elsif ( $params->{aux_dn_form_to_modify} =~ /$ldap_crud->{cfg}->{base}->{netgroup}/ ) { ## NIS NETGROUPS
# old, low/middle level variant #     if ( ref($init_obj->{nisNetgroupTriple}) eq 'ARRAY' ) {
# old, low/middle level variant #       $init_obj->{nisNetgroupTriple_arr} = $init_obj->{nisNetgroupTriple};
# old, low/middle level variant #     } else {
# old, low/middle level variant #       push @{$init_obj->{nisNetgroupTriple_arr}}, $init_obj->{nisNetgroupTriple};
# old, low/middle level variant #     }
# old, low/middle level variant # 
# old, low/middle level variant #     foreach $triple ( @{$init_obj->{nisNetgroupTriple_arr}} ) {
# old, low/middle level variant #       # according to the order used in LDAP attr "nisNetgroupTriple" value
# old, low/middle level variant #       ( $host, $user, $domain ) = split(/,/, $triple);
# old, low/middle level variant #       push @{$init_obj->{triple}},
# old, low/middle level variant # 	{ host => substr($host, 1),
# old, low/middle level variant # 	  user => $user,
# old, low/middle level variant # 	  domain => substr($domain, 0, -1), };
# old, low/middle level variant #     }
# old, low/middle level variant #     delete $init_obj->{nisNetgroupTriple_arr};
# old, low/middle level variant #     delete $init_obj->{nisNetgroupTriple};
# old, low/middle level variant # 
# old, low/middle level variant #     use UMI::Form::NisNetgroup;
# old, low/middle level variant #     $form = UMI::Form::NisNetgroup->new( init_object => $init_obj, );
# old, low/middle level variant #     $c->stash( template => 'nis/nisnetgroup.tt', );
# old, low/middle level variant # 
  } elsif ( $params->{aux_dn_form_to_modify} =~ /$ldap_crud->{cfg}->{base}->{netgroup}/ ) { ## NIS NETGROUPS
    my $associatedDomain = exists $init_obj->{associatedDomain} ? 1 : 0;
    if ( ref($init_obj->{nisNetgroupTriple}) eq 'ARRAY' ) {
      $init_obj->{nisNetgroupTriple_arr} = $init_obj->{nisNetgroupTriple};
    } else {
      push @{$init_obj->{nisNetgroupTriple_arr}}, $init_obj->{nisNetgroupTriple};
    }
    foreach $triple ( @{$init_obj->{nisNetgroupTriple_arr}} ) {
      # according to the order used in LDAP attr "nisNetgroupTriple" value
      ( $host, $user, $domain ) = split(/,/, substr($triple,1,-1));
      push @{$init_obj->{uids_raw}}, $user;
      push @{$init_obj->{associatedDomain_raw}}, sprintf("%s.%s", $host, $domain)
	if ! $associatedDomain;
    }

    my @ng = split(/,/, $params->{aux_dn_form_to_modify});
    shift @ng;
    $init_obj->{netgroup} = join(',', @ng);

    my $ngr;
    if ( $init_obj->{netgroup} =~ /access/ ) {
      $ngr = 'ng_access';
    } else {
      $ngr = 'ng_category';
    }
    if ( ref($init_obj->{memberNisNetgroup}) eq 'ARRAY' ) {
      $init_obj->{$ngr} = $init_obj->{memberNisNetgroup};
    } else {
      push @{$init_obj->{$ngr}}, $init_obj->{memberNisNetgroup};
    }
    
    @{$init_obj->{uids}} = uniq( @{$init_obj->{uids_raw}} );
    @{$init_obj->{associatedDomain}} = uniq( @{$init_obj->{associatedDomain_raw}} )
      if ! $associatedDomain;
    delete $init_obj->{nisNetgroupTriple_arr};
    delete $init_obj->{uids_raw};
    delete $init_obj->{associatedDomain_raw};

    # log_debug { np($init_obj) };

    use UMI::Form::abstrNisNetgroup;
    $form = UMI::Form::abstrNisNetgroup->new( init_object => $init_obj, );
    $c->stash( template => 'nis/abstr_nis_netgroup.tt', );

  } elsif ( $params->{aux_dn_form_to_modify} =~ /$ldap_crud->{cfg}->{base}->{sargon}/ ) { ## SARGON
    $init_obj->{cn}            = $init_obj->{cn};
    $init_obj->{priv}          = $init_obj->{sargonAllowPrivileged} eq 'TRUE' ? '1' : '0';
    $init_obj->{order}       //= '' . $init_obj->{sargonOrder};
    $init_obj->{'sargonUser'}  = [ $init_obj->{'sargonUser'} ]
      if ref($init_obj->{'sargonUser'}) ne 'ARRAY';
    $init_obj->{'sargonHost'}  = [ $init_obj->{'sargonHost'} ]
      if ref($init_obj->{'sargonHost'}) ne 'ARRAY';
    $init_obj->{'sargonMount'} = [ $init_obj->{'sargonMount'} ]
      if ref($init_obj->{'sargonMount'}) ne 'ARRAY';

    log_debug { np($init_obj) };

    foreach ( @{$init_obj->{'sargonUser'}} ) {
      if ( $_ =~ /^\+/ ) {
	push @{$init_obj->{groups}},
	  sprintf("cn=%s,%s",substr($_, 1),
		  $ldap_crud->{cfg}->{base}->{group});
      } else {
	push @{$init_obj->{uid}}, $_;
      }
    }

    foreach ( @{$init_obj->{'sargonHost'}} ) {
      if ( $_ =~ /^%/ ) {
	push @{$init_obj->{netgroups}},
	  sprintf("cn=%s,ou=category,%s",substr($_, 1),
		  $ldap_crud->{cfg}->{base}->{netgroup});
      } else {
	push @{$init_obj->{host}}, $_;
      }
    }

    if ( $init_obj->{'sargonMount'} ) {
      my $i = 0;
      foreach ( @{$init_obj->{'sargonMount'}} ) {
	push @{$init_obj->{'mount.'. $i .'.mount'}}, $_;
	$i++;
      }

      if ( ref($init_obj->{sargonMount}) eq 'ARRAY' ) {
	$init_obj->{sargonMount_arr} = $init_obj->{sargonMount};
      } else {
	push @{$init_obj->{sargonMount_arr}}, $init_obj->{sargonMount};
      }

      push @{$init_obj->{mount}}, map { { mount => $_ } } @{$init_obj->{sargonMount_arr}};
      
      delete $init_obj->{sargonMount_arr};
      delete $init_obj->{sargonMount};
    }
    
    $init_obj->{allow}      //= $init_obj->{'sargonAllow'};
    $init_obj->{deny}       //= $init_obj->{'sargonDeny'};
    $init_obj->{capab}      //= $init_obj->{'sargonAllowCapability'};
    $init_obj->{maxmem}     //= $init_obj->{'sargonMaxMemory'};
    $init_obj->{maxkernmem} //= $init_obj->{'sargonMaxKernelMemory'};

    delete $init_obj->{'sargonAllowCapability'};
    delete $init_obj->{'sargonAllow'};
    delete $init_obj->{'sargonDeny'};
    delete $init_obj->{'sargonUser'};
    delete $init_obj->{'sargonMount'};
    delete $init_obj->{'sargonAllowPrivileged'};
    delete $init_obj->{'sargonHost'};
    delete $init_obj->{'sargonOrder'};

    log_debug { np($init_obj) };

    use UMI::Form::Sargon;
    $form = UMI::Form::Sargon->new( init_object => $init_obj, );
    $c->stash( template => 'sargon/sargon.tt', );

  } elsif ( $params->{aux_dn_form_to_modify} =~ /$ldap_crud->{cfg}->{base}->{sudo}/ ) { ## SUDO

    if ( ref($init_obj->{sudoCommand}) eq 'ARRAY' ) {
      $init_obj->{sudoCommand_arr} = $init_obj->{sudoCommand};
    } else {
      push @{$init_obj->{sudoCommand_arr}}, $init_obj->{sudoCommand};
    }
    
    push @{$init_obj->{com}}, map { { sudoCommand => $_ } } @{$init_obj->{sudoCommand_arr}};

    delete $init_obj->{sudoCommand_arr};
    delete $init_obj->{sudoCommand};

    if ( ref($init_obj->{sudoOption}) eq 'ARRAY' ) {
      $init_obj->{sudoOption_arr} = $init_obj->{sudoOption};
    } else {
      push @{$init_obj->{sudoOption_arr}}, $init_obj->{sudoOption};
    }
    
    push @{$init_obj->{opt}}, map { { sudoOption => $_ } } @{$init_obj->{sudoOption_arr}};

    delete $init_obj->{sudoOption_arr};
    delete $init_obj->{sudoOption};

    use UMI::Form::Sudo;
    $form = UMI::Form::Sudo->new( init_object => $init_obj, );
    $c->stash( template => 'sudo/sudo.tt', );

  } elsif ( $params->{aux_dn_form_to_modify} =~ /$ldap_crud->{cfg}->{base}->{org}/ ) { ## ORGANIZATIONs
    use UMI::Form::Org;
    $form = UMI::Form::Org->new( init_object => $init_obj, );
    $c->stash( template => 'org/org_wrap.tt', );
  } else { ## REST
    $return->{warning} = 'Use &laquo;<i class="fa fa-pencil"></i> <b>edit (all)</b>&raquo; menu item instead, please. For now there is only lowlevel edit form for this type of objects.';
    $c->stash( template => 'stub.tt',
	       final_message => $return, );
    $c->detach();
  }

  $c->stash( form => $form, );
  
  # first run (coming from searchby)
  if ( keys %{$params} == 1 ) {
    return unless $form
      ->process( ldap_crud => $c->model('LDAP_CRUD'), );
  } else {
    return unless $form
      ->process( posted    => ($c->req->method eq 'POST'),
		 params    => $params,
		 ldap_crud => $c->model('LDAP_CRUD'), );
  }

  # $arg->{replace} = [];
  # foreach my $ff ( $form->fields ) {
  #   next if ! defined $ff->value ||
  #     $ff->name =~ /aux_/ ||
  #     defined $init_obj->{$ff->name} && $ff->value eq $init_obj->{$ff->name};

  #   # the object to modify is NisNetgroup object and current field is tripple and it is not empty
  #   if ( $form->field('aux_dn_form_to_modify')->value =~ /$ldap_crud->{cfg}->{base}->{netgroup}/ &&
  # 	 $ff->name eq 'triple' && $ff->value ) {
  #     my $triple;
  #     foreach ( @{$ff->value} ) {
  # 	push @{$triple}, sprintf('(%s,%s,%s)', $_->{host}, $_->{user}, $_->{domain});
  #     }
  #     push @{$arg->{replace}}, nisNetgroupTriple => $triple;
  #   } else {
  #     push @{$arg->{replace}}, $ff->name => $ff->value if $ff->value ne 'na' && $ff->value ne '';
  #   }
    
  #   push @{$arg->{replace}}, $ff->name => []
  #     if $ff->value eq ''
  #     && defined $init_obj->{$ff->name}
  #     && $init_obj->{$ff->name} ne '';
    
  # }
  # push @{$arg->{changes}}, replace => $arg->{replace};
  
  # # p $arg;
  
  # if ( $#{$arg->{replace}} > 0 ) {
  #   my $chg = $ldap_crud->modify( $arg->{dn}, $arg->{changes} );
  #   if ( $chg eq '0' ) {
  #     push @{$return->{success}}, "$arg->{dn} was changed";
  #   } else {
  #     $return->{error} = $chg->{html};
  #   }
  # }

  # $c->stash( final_message => $return, );

}


#=====================================================================

=head1 user_preferences

single page with all user data assembled to the convenient view

=cut


sub user_preferences :Path(user_preferences) :Args(0) {
  my ( $self, $c ) = @_;
  my $params = $c->req->parameters;
  $c->controller('Root')->user_preferences( $c, $params->{'user_preferences'} );
}


#=====================================================================

=head1 delete

deletion of the object

=cut


sub delete :Path(delete) :Args(0) {
  my ( $self, $c ) = @_;
  my $params = $c->req->parameters;

  my $err;
  if ( defined $params->{'ldap_delete_recursive'} &&
       $params->{'ldap_delete_recursive'} eq 'on' ) {
    $err = $c->model('LDAP_CRUD')->delr($params->{ldap_delete});
  } else {
    $err = $c->model('LDAP_CRUD')->del($params->{ldap_delete});
  }

  if ( $params->{type} eq 'json' ) {
    $c->stash->{current_view} = 'WebJSON';
    $c->stash->{success} = ref($err) ne 'HASH' ? 1 : 0;
    if ( ref($err) ne 'HASH' ) {
      $c->stash->{message} = 'OK';
    } elsif ( ref($err) eq 'HASH' && $#{$err->{error}} > -1 ) {
      $c->stash->{message} = $self->msg2html({ type => 'alert',
					       data => $err->{error}->[0]->{html} });
    }
  } else {
    $c->stash(
	      template  => 'search/delete.tt',
	      delete    => $params->{'ldap_delete'},
	      recursive => defined $params->{'ldap_delete_recursive'} && $params->{'ldap_delete_recursive'} eq 'on' ? '1' : '0',
	      err       => $err,
	      type      => $params->{'type'},
	     );
  }
}

=head1 reassign

object reassign to another root DN

=cut


sub reassign :Path(reassign) :Args(0) {
  my ( $self, $c ) = @_;
  my $params = $c->req->parameters;

  my $err = $c->model('LDAP_CRUD')->reassign($params);

  if ( $params->{type} eq 'json' ) {
    $c->stash->{current_view} = 'WebJSON';
    $c->stash->{success} = ref($err) ne 'HASH' && ref($err) ne 'ARRAY' ? 1 : 0;

    if ( ref($err) ne 'HASH' && ref($err) ne 'ARRAY' ) {
      $c->stash->{message} = 'OK';
    } elsif ( (ref($err) eq 'HASH' || ref($err) eq 'ARRAY' ) && $#{$err->{error}} > -1 ) {
      $c->stash->{success} = 0;
      $c->stash->{message} = $self->msg2html({ type => 'alert',
					       data => $err->{error}->[0]->{html} });
    }
  } else {
    $c->stash( template => 'stub.tt',
	       params   => $params,
	       err      => $err, );
  }
}

=head1 moddn

moddn

=cut

sub moddn :Path(moddn) :Args(0) {
  my ( $self, $c ) = @_;
  my $params = $c->req->parameters;
  log_debug { np( $params ) };
  my $err = $c->model('LDAP_CRUD')->moddn($params);
  log_debug { np ( $err ) };
  if ( $params->{type} eq 'json' ) {
    $c->stash->{current_view} = 'WebJSON';
    $c->stash->{success} = ref($err) ne 'HASH' && ref($err) ne 'ARRAY' ? 1 : 0;

    if ( ref($err) ne 'HASH' && ref($err) ne 'ARRAY' ) {
      $c->stash->{message} = 'OK';
    } elsif ( (ref($err) eq 'HASH' || ref($err) eq 'ARRAY' ) && $#{$err->{error}} > -1 ) {
      $c->stash->{success} = 0;
      $c->stash->{message} = $self->msg2html({ type => 'panel',
  					       data => $err->{error}->[0]->{html} });
    }
  } else {
    $c->stash( template => 'stub.tt',
  	       params => $params,
  	       err => $err, );
  }
}

=head1 refresh

object TTL refresh ( wrapper of Net::LDAP::Extension::Refresh )

=cut


sub refresh :Path(refresh) :Args(0) {
  my ( $self, $c ) = @_;
  my $params = $c->req->parameters;

  log_debug { np($params) };
  
  # my $err = 0;

  my $t = localtime;
  my $refresh = $c->model('LDAP_CRUD')
    ->refresh( $params->{dn_to_refresh},
	       Time::Piece->strptime( $params->{requestTtl}, "%Y.%m.%d %H:%M")->epoch - $t->epoch );

  if ( $params->{type} eq 'json' ) {
    $c->stash->{current_view} = 'WebJSON';

    if ( defined $refresh->{success} ) {
      $c->stash->{success} = 1;
      $c->stash->{message} = 'OK';
    } else {
      $c->stash->{success} = 0;
      $c->stash->{message} = $self->msg2html({ type => 'panel',
					       data => $refresh->{error}->{html} });
    }
  } else {
    $c->stash( template => 'stub.tt',
	       params => $params,
	       err => $refresh->{error}->{html}, );
  }
}


#=====================================================================

=head1 block

block all user accounts (via password change and ssh-key modification)
to make it impossible to use any of them

=cut


sub block :Path(block) :Args(0) {
  my ( $self, $c ) = @_;
  my $args = $c->req->parameters;
  my $params = { dn => $args->{user_block},
		 type => $args->{type}, };
  my $err = $c->model('LDAP_CRUD')->block( $params );

  if ( $params->{type} eq 'json' ) {
    $c->stash->{current_view} = 'WebJSON';
    if ( ref($err) eq 'HASH' && ! defined $err->{error} ) {
      $c->stash->{success} = 1;
      $c->stash->{message} = 'OK';
    } elsif ( ref($err) eq 'HASH' || ref($err) eq 'ARRAY' ) { # && $#{$err->{error}} > -1 ) {
      $c->stash->{success} = 0;
      $c->stash->{message} = $self->msg2html({ type => 'panel',
					       data => $err->{error} });
    } else {
      $c->stash( template => 'stub.tt',
		 err      => $err,
		 params   => $params, );
    }
  }
}


#=====================================================================

=head1 dhcp_add

DHCP-to-user binding object

=cut


sub dhcp_add :Path(dhcp_add) :Args(0) {
  my ( $self, $c ) = @_;
  my $params = $c->req->parameters;

  $c->stash(
	    template => 'dhcp/dhcp_wrap.tt',
	    form => $self->form_add_dhcp,
#	    ldap_add_dhcp => $params->{'ldap_add_dhcp'},
	   );

  if ( keys %{$params} == 1 ) {
  # if ( defined $params->{add_svc_acc} && $params->{add_svc_acc} ne '' ) {
    my $init_obj = { ldap_add_dhcp => $params->{'ldap_add_dhcp'} };
    return unless $self->form_add_dhcp
      ->process( init_object => $init_obj,
		 ldap_crud => $c->model('LDAP_CRUD'), );
  } else {
    return unless $self->form_add_dhcp->process(
						posted    => ($c->req->method eq 'POST'),
						params    => $params,
						ldap_crud => $c->model('LDAP_CRUD'),
					       );

    # p( $params, caller_info => 1, colored => 1);
    $c->stash(
	      final_message => $c->controller('Dhcp')
	      ->create_dhcp_host ( $c->model('LDAP_CRUD'),
				   {
				    dhcpHWAddress  => $params->{dhcpHWAddress},
				    uid            => substr((split(',',$params->{ldap_add_dhcp}))[0],4),
				    dhcpStatements => $params->{dhcpStatements},
				    net            => $params->{net},
				    cn             => $params->{cn},
				    dhcpComments   => $params->{dhcpComments},
				   }
				 ),
	     ); # if $self->form_add_dhcp->validated;
  }
}




=head1 AUTHOR

Zeus Panchenko

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;

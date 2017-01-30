# -*- cperl -*-
#

package UMI::Controller::SearchBy;

use utf8;
use Moose;
use namespace::autoclean;

use Data::Printer { use_prototypes => 0, caller_info => 1 };

use Try::Tiny;

BEGIN { extends 'Catalyst::Controller'; with 'Tools'; }

use UMI::Form::Dhcp;
has 'form_add_dhcp' => ( isa => 'UMI::Form::Dhcp', is => 'rw',
			lazy => 1, default => sub { UMI::Form::Dhcp->new },
			documentation => q{Form to add userDhcp},
		      );

use UMI::Form::ModPwd;
has 'form_mod_pwd' => ( isa => 'UMI::Form::ModPwd', is => 'rw',
			lazy => 1, default => sub { UMI::Form::ModPwd->new },
			documentation => q{Form to modify userPassword},
		      );

use UMI::Form::ModJpegPhoto;
has 'form_jpegphoto' => ( isa => 'UMI::Form::ModJpegPhoto', is => 'rw',
			  lazy => 1, default => sub { UMI::Form::ModJpegPhoto->new },
			  documentation => q{Form to add/modify jpegPhoto},
			);

use UMI::Form::ModUserGroup;
has 'form_mod_groups' => ( isa => 'UMI::Form::ModUserGroup', is => 'rw',
			   lazy => 1, default => sub { UMI::Form::ModUserGroup->new },
			   documentation => q{Form to add/modify group/s of the user.},
			 );

use UMI::Form::ModRadGroup;
has 'form_mod_rad_groups' => ( isa => 'UMI::Form::ModRadGroup', is => 'rw',
			   lazy => 1, default => sub { UMI::Form::ModRadGroup->new },
			   documentation => q{Form to add/modify RADIUS group/s of the object.},
			 );

use UMI::Form::ModGroupMemberUid;
has 'form_mod_memberUid' => ( isa => 'UMI::Form::ModGroupMemberUid', is => 'rw',
			      lazy => 1, default => sub { UMI::Form::ModGroupMemberUid->new },
			      documentation => q{Form to add/modify memberUid/s of the group.},
			    );

use UMI::Form::AddServiceAccount;
has 'form_add_svc_acc' => ( isa => 'UMI::Form::AddServiceAccount', is => 'rw',
			    lazy => 1, default => sub { UMI::Form::AddServiceAccount->new },
			    documentation => q{Form to add service account},
			  );



=head1 NAME

UMI::Controller::SearchBy - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


######################################################################


=head2 index

=cut

sub index :Path :Args(0) {
  my ( $self, $c ) = @_;

  # if ( defined $c->session->{"auth_uid"} ) {
  if ( defined $c->user_exists ) {
    my ( $params, $ldap_crud, $filter, $filter_meta, $filter_translitall, $base, $return );
    my $sort_order = 'reverse';
    
    $params = $c->req->params;
    $ldap_crud = $c->model('LDAP_CRUD');

    if ( defined $params->{'ldapsearch_by_name'} ||
	 defined $params->{'ldapsearch_by_email'} ||
	 defined $params->{'ldapsearch_by_jid'} ||
	 defined $params->{'ldapsearch_by_telephone'} ) {
      $base = $ldap_crud->cfg->{base}->{acc_root};
    } elsif ( defined $params->{'ldap_subtree'} && $params->{'ldap_subtree'} ne '' ) {
      $base = $params->{'ldap_subtree'};
    } else {
      $base = $params->{ldapsearch_base};
    }

    if ( defined $params->{'ldapsearch_filter'} &&
	 $params->{'ldapsearch_filter'} eq '' ) {
      $filter_meta = '*';
    } else {
      $filter_meta = $params->{'ldapsearch_filter'};
    }
    #   $filter_meta = $self->is_ascii($params->{'ldapsearch_filter'}) ?
    # 	$self->utf2lat($params->{'ldapsearch_filter'}) : $params->{'ldapsearch_filter'};
    # }
    
    if ( defined $params->{'ldapsearch_by_email'} ) {
      # $filter = sprintf("mail=%s", $filter_meta);
      $filter = sprintf("|(mail=%s)(&(uid=%s)(authorizedService=mail@*))",
			$filter_meta, $filter_meta );
      $base = $ldap_crud->cfg->{base}->{acc_root};
      $params->{'ldapsearch_base'} = $base;
    } elsif ( defined $params->{'ldapsearch_by_jid'} ) {
      $filter = sprintf("&(authorizedService=xmpp@*)(uid=*%s*)", $filter_meta);
      $base = $ldap_crud->cfg->{base}->{acc_root};
      $params->{'ldapsearch_base'} = $base;
    } elsif ( defined $params->{'ldapsearch_by_ip'} ) {
      $filter = sprintf("dhcpStatements=fixed-address %s", $filter_meta);
      $base = $ldap_crud->cfg->{base}->{dhcp};
      $params->{'ldapsearch_base'} = $base;
    } elsif ( defined $params->{'ldapsearch_by_mac'} ) {
      push @{$return->{error}}, 'incorrect MAC address'
	if ! $self->macnorm({ mac => $filter_meta });
      $filter = sprintf("|(dhcpHWAddress=ethernet %s)(&(uid=%s)(authorizedService=802.1*))(&(cn=%s)(authorizedService=802.1*))(hwMac=%s)",
			$self->macnorm({ mac => $filter_meta, dlm => ':', }),
			$self->macnorm({ mac => $filter_meta }),
			$self->macnorm({ mac => $filter_meta }),
			$self->macnorm({ mac => $filter_meta }) );

      $base = $ldap_crud->cfg->{base}->{db};
      $params->{'ldapsearch_base'} = $base;
    } elsif ( defined $params->{'ldapsearch_by_name'} ) {
      $filter = 
	sprintf("|(givenName=%s)(sn=%s)(uid=%s)(cn=%s)", $filter_meta, $filter_meta, $filter_meta, $filter_meta);
      $base = $ldap_crud->cfg->{base}->{acc_root};
      $params->{'ldapsearch_base'} = $base;
    } elsif ( defined $params->{'ldapsearch_by_telephone'} ) {
      $filter = sprintf("|(telephoneNumber=%s)(mobile=%s)(homePhone=%s)",
			$filter_meta, $filter_meta, $filter_meta);
      $base = $ldap_crud->cfg->{base}->{acc_root};
      $params->{'ldapsearch_base'} = $base;
    } elsif ( defined $params->{'ldapsearch_filter'} &&
	      $params->{'ldapsearch_filter'} ne '' ) {
      $filter = $params->{'ldapsearch_filter'};
      $base = $params->{'ldapsearch_base'};
    } elsif ( defined $params->{'ldap_subtree'} &&
	      $params->{'ldap_subtree'} ne '' ) {
      $filter = 'objectClass=*';
      $base = $params->{'ldap_subtree'};
    } elsif ( defined $params->{'ldap_history'} &&
	      $params->{'ldap_history'} ne '' ) {
      $filter = 'reqDN=' . $params->{'ldap_history'};
      $sort_order = 'straight';
      $base = UMI->config->{ldap_crud_db_log};
    } else {
      $filter = 'objectClass=*';
      $base = $params->{'ldapsearch_base'};
    }

    if ( ! $c->check_any_user_role( qw/admin coadmin/ ) &&
	 ! $self->may_i({ base_dn => $base,
			  filter => $filter,
			  user => $c->user, }) ) {
      $c->stash( template => 'ldap_err.tt',
		 final_message => { error
				    => sprintf('Your roles does not allow search by base dn:<h5>&laquo;<b><em>%s</em></b>&raquo;</h5> and/or filter:<h5>&laquo;<b><em>%s</em></b>&raquo;</h5>ask UMI admin for explanation/s and provide above info.',
					       $base,
					       $filter ), }, );
      return 0;
    }

    $c->stats->profile(begin => "searchby_search");

    $params->{'filter'} = '(' . $filter . ')';
    my $mesg = $ldap_crud->search({
				   base => $base,
				   filter => '(' . $filter . ')',
				   sizelimit => $ldap_crud->cfg->{sizelimit},
				   attrs => [ '*',
					      'createTimestamp',
					      'creatorsName',
					      'modifiersName',
					      'modifyTimestamp', ],
				  });
    my @entries = defined $params->{order_by} &&
      $params->{order_by} ne '' ? $mesg->sorted(split(/,/,$params->{order_by})) : $mesg->sorted('dn');

    $c->stats->profile("search by filter requested");
    
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

    my ( $ttentries, @ttentries_keys, $attr, $tmp, $dn_depth, $to_utf_decode, @root_arr, @root_dn, $root_i, $root_mesg, $root_entry );
    my $blocked = 0;
    foreach (@entries) {
      # p $ldap_crud->obj_schema({ dn => $_->dn });
      #p $_->dn;

      if ( $_->dn =~ /.*,$ldap_crud->{cfg}->{base}->{acc_root}/ ) {
	$mesg = $ldap_crud->search({ base => $ldap_crud->cfg->{base}->{group},
				     filter => sprintf('(&(cn=%s)(memberUid=%s))',
						       $ldap_crud->cfg->{stub}->{group_blocked},
						       substr( (reverse split /,/, $_->dn)[2], 4 )), });
	$blocked = $mesg->count;
	$return->{error} .= $ldap_crud->err( $mesg )->{html}
	  if $mesg->is_error();

	$c->stats->profile('is-blocked search for <i class="text-muted">' . $_->dn . '</i>');
      }

      # p my $abc1 = $ldap_crud->canonical_dn_rev ( $_->dn );
      # p $abc1 = $ldap_crud->get_root_obj_dn ( $_->dn );
      $tmp = $_->dn;

      # !!! HARDCODE how deep dn could be to be considered as root for each type of objects !!!
      $dn_depth = $tmp =~ /.*,$ldap_crud->{cfg}->{base}->{acc_root}/ ? 1 : 3;
      $dn_depth += split(/,/, $ldap_crud->{cfg}->{base}->{acc_root});

      if ( $tmp =~ /.*,$ldap_crud->{cfg}->{base}->{acc_root}/ ) {
	@root_arr = split(',', $_->dn);
	$root_i = $#root_arr;
	@root_dn = splice(@root_arr, -1 * $dn_depth);
	$ttentries->{$tmp}->{root}->{dn} = join(',', @root_dn);

	$root_i++;
	if ( $root_i == $dn_depth ) {
	  $ttentries->{$tmp}->{root}->{givenName} = $_->get_value('givenName');
	  $ttentries->{$tmp}->{root}->{sn} = $_->get_value('sn');
	} else {
	  $root_mesg = $ldap_crud->search({ dn => $ttentries->{$tmp}->{root}->{dn}, });
	  $return->{error} .= $ldap_crud->err( $root_mesg )->{html}
	    if $root_mesg->is_error();
	  $root_entry = $root_mesg->entry(0);
	  $ttentries->{$tmp}->{root}->{givenName} = $root_entry->get_value('givenName');
	  $ttentries->{$tmp}->{root}->{sn} = $root_entry->get_value('sn');
	}

	# p $ttentries->{$tmp}->{root};

	$to_utf_decode = $ttentries->{$tmp}->{root}->{givenName};
	utf8::decode($to_utf_decode);
	$ttentries->{$tmp}->{root}->{givenName} = $to_utf_decode;

	$to_utf_decode = $ttentries->{$tmp}->{root}->{sn};
	utf8::decode($to_utf_decode);
	$ttentries->{$tmp}->{root}->{sn} = $to_utf_decode;

	$#root_arr = -1;
	$#root_dn = -1;

	# p $ttentries->{$tmp}->{root};
      }

      $ttentries->{$tmp}->{'mgmnt'} =
	{
	 is_blocked => 	  $blocked,
	 is_dn => scalar split(',', $tmp) <= $dn_depth ? 1 : 0,
	 is_account => $tmp =~ /.*,$ldap_crud->{cfg}->{base}->{acc_root}/ ? 1 : 0,
	 is_group => $tmp =~ /.*,$ldap_crud->{cfg}->{base}->{group}/ ? 1 : 0,
	 is_inventory => $tmp =~ /.*,$ldap_crud->{cfg}->{base}->{inventory}/ ? 1 : 0,
	 jpegPhoto => $tmp =~ /.*,$ldap_crud->{cfg}->{base}->{acc_root}/ ? 1 : 0,
	 gitAclProject => $_->exists('gitAclProject') ? 1 : 0,
	 userPassword => $_->exists('userPassword') ? 1 : 0,
	 userDhcp => $tmp =~ /.*,$ldap_crud->{cfg}->{base}->{acc_root}/ &&
	 scalar split(',', $tmp) <= 3 ? 1 : 0,
	};

      $mesg = $ldap_crud->search({ base => sprintf('ou=group,ou=system,%s', $ldap_crud->cfg->{base}->{db}),
				   filter => sprintf('(&(cn=admin)(memberUid=%s))',
						     substr( (reverse split /,/,
							      $ttentries->{$tmp}->{root}->{dn})[2], 4 )), });
      $ttentries->{$tmp}->{'mgmnt'}->{is_admin} = $mesg->count;
      $return->{error} .= $ldap_crud->err( $mesg )->{html}
	if $mesg->is_error();

      foreach $attr (sort $_->attributes) {
	$to_utf_decode = $_->get_value( $attr, asref => 1 );
	map { utf8::decode($_); $_} @{$to_utf_decode};
	$ttentries->{$tmp}->{attrs}->{$attr} = $to_utf_decode;

	if ( $attr eq 'jpegPhoto' ) {
	  use MIME::Base64;
	  $ttentries->{$tmp}->{attrs}->{$attr} =
	    sprintf('img-thumbnail" alt="jpegPhoto of %s" src="data:image/jpg;base64,%s" title="%s" />',
		    $tmp,
		    encode_base64(join('',@{$ttentries->{$tmp}->{attrs}->{$attr}})),
		    $tmp);
	  } elsif ( $attr eq 'userCertificate;binary' ) {
	    $ttentries->{$tmp}->{attrs}->{$attr} = $self->cert_info({ cert => $_->get_value( $attr ) });
	} elsif (ref $ttentries->{$tmp}->{attrs}->{$attr} eq 'ARRAY') {
	  $ttentries->{$tmp}->{is_arr}->{$attr} = 1;
	}
      }
      push @ttentries_keys, $_->dn if $sort_order eq 'reverse'; # for not history searches
      $blocked = 0;
    }

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

    # p $ttentries;

    $c->stash(
	      template => 'search/searchby.tt',
	      base_dn => $base,
	      filter => $filter,
	      entrieskeys => \@ttentries_keys,
	      entries => $ttentries,
	      schema => $ldap_crud->attr_equality,
	      services => $ldap_crud->cfg->{authorizedService},
	      base_ico => $ldap_crud->cfg->{base}->{icon},
	      final_message => $return,
	     );
  } else {
    $c->stash( template => 'signin.tt', );
  }

  $c->stats->profile(end => "searchby_search");

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

    #=====================================================================
    # Modify (all fields form)
    #=====================================================================
    if (defined $params->{'ldap_modify'} && $params->{'ldap_modify'} ne '') {

      $c->stats->profile( begin => "searchby_modify" );
  
      $mesg = $ldap_crud->search( { dn => $params->{ldap_modify} } );
      $return->{error} = $ldap_crud->err( $mesg )->{html} if ! $mesg->count;
      $entry_tmp = $mesg->entry(0);

      $c->stats->profile('search for <i class="text-muted">' . $params->{ldap_modify} . '</i>');

      foreach $attr ( $entry_tmp->attributes ) {
	if ( $attr =~ /;binary/ or
	   $attr eq "userPKCS12" ) { ## !!! temporary stub !!! 	  next;
	  $entry->{$attr} = "BINARY DATA";
	} elsif ( $attr eq 'jpegPhoto' ) {
	  use MIME::Base64;
	  $entry->{$attr} = sprintf('data:image/jpg;base64,%s',
				    encode_base64(join('',
						       @{$entry_tmp->get_value($attr, asref => 1)})
						 )
				   );
	} elsif ( $attr eq 'userPassword' ) {
	  next;
	#   $entry->{$attr} = '*' x 8;
	} else {
	  $entry->{$attr} = $entry_tmp->get_value($attr, asref => 1);
	  map { utf8::decode($_),$_ } @{$entry->{$attr}};
	}
      }
      
      $c->stats->profile('all fields are ready');

      my $schema = $ldap_crud->obj_schema( { dn => $params->{ldap_modify} } );
      my ($is_single, $names);
      foreach my $objectClass (sort (keys %{$schema->{$params->{ldap_modify}}})) {
	foreach $attr (sort (keys %{$schema->{$params->{ldap_modify}}->{$objectClass}->{must}} )) {
	  next if $attr eq "objectClass";
	  $is_single->{$attr} =
	    $schema->{$params->{ldap_modify}}->{$objectClass}->{must}->{$attr}->{'single-value'};
	  $names->{$attr} = 0;
	}
	foreach $attr (sort (keys %{$schema->{$params->{ldap_modify}}->{$objectClass}->{may}} )) {
	  next if $attr eq "objectClass";
	  $is_single->{$attr} =
	    $schema->{$params->{ldap_modify}}->{$objectClass}->{may}->{$attr}->{'single-value'};
	  $names->{$attr} = 0;
	}
      }

      foreach $attr ( $entry_tmp->attributes ) {
	delete $names->{$attr};
      }

      $c->stats->profile('schema is ready');

      ## here we work with the only one, single entry!!
      # p $is_single;
      # p $names;
      # p $entry;
      # $c->session->{modify_entries} = $mesg->entry(0);
      # $c->session->{modify_dn} = $params->{ldap_modify};
      # $c->session->{modify_schema} = $is_single;

      $c->stash(
		template => 'search/modify.tt', # !!! look modify() bellow
		modify => $params->{'ldap_modify'},
		entries => $entry,
		attrs_rest => $names,
		schema => $is_single,
		final_message => $return,
		rdn => (split('=', (split(',', $params->{ldap_modify}))[0]))[0],
	       );

      $c->stats->profile( end => "searchby_modify" );

#=====================================================================
# Modify Groups of the user
#=====================================================================
    } elsif ( defined $params->{'ldap_modify_group'} &&
	      $params->{'ldap_modify_group'} ne '' ) {

      my $groups;
      if ( defined $params->{groups} ) {
	if ( ref($params->{groups}) eq 'ARRAY' ) {
	  $groups = $params->{groups};
	} else {
	  $groups = [ $params->{groups} ];
	}
      } else {
	$groups = '';
      }

      my $ldap_crud = $c->model('LDAP_CRUD');

      my $id;
      # if ( $ldap_crud->{cfg}->{rdn}->{acc_root} ne 'uid' ) {
	my $mesg = $ldap_crud->search( { base => $params->{'ldap_modify_group'},
					 scope => 'base',
					 attrs => [ 'uid' ], });
	push @{$return->{error}}, $ldap_crud->err($mesg)->{caller} . $ldap_crud->err($mesg)->{html}
	  if $mesg->code != 0;
	$id = $mesg->entry(0)->get_value( 'uid' );
      # }

      if ( ! defined $params->{groups} && ! defined $params->{aux_submit} ) {
	my ( $return, $base, $filter, $dn );
	$mesg = $ldap_crud->search( { base => $ldap_crud->cfg->{base}->{group},
				      filter => sprintf('memberUid=%s', $id),
				      sizelimit => 0,
				      attrs => ['cn'], } );
	push @{$return->{error}}, $ldap_crud->err($mesg)->{caller} . $ldap_crud->err($mesg)->{html}
	  if $mesg->code != 0;

	my @groups_usr = $mesg->sorted('cn');
	foreach ( @groups_usr ) { push @{$params->{groups}}, $_->dn; } #  substr( (split /,/, $_->dn)[0], 3); }
	# $params->{groups} = undef;
      }
      # p $params;
      $c->stash( template => 'user/user_mod_group.tt',
		 form => $self->form_mod_groups,
		 ldap_modify_group => $params->{'ldap_modify_group'}, );

      return unless $self->form_mod_groups
      	->process( posted => ($c->req->method eq 'POST'),
		   params => $params,
		   ldap_crud => $ldap_crud );

      $c->stash( final_message => $self
		 ->mod_groups( $ldap_crud,
			       { mod_groups_dn => $params->{ldap_modify_group},
				 base => $ldap_crud->cfg->{base}->{group},
				 groups => $groups,
				 is_submit => defined $params->{aux_submit} &&
				 $params->{aux_submit} eq 'Submit' ? 1 : 0,
				 type => 'posixGroup', } ), );

#=====================================================================
# Modify RADIUS Groups
#=====================================================================
    } elsif ( defined $params->{'ldap_modify_rad_group'} &&
	      $params->{'ldap_modify_rad_group'} ne '') {

      my $groups;
      if ( defined $params->{groups} ) {
	if ( ref($params->{groups}) eq 'ARRAY' ) {
	  $groups = $params->{groups};
	} else {
	  $groups = [ $params->{groups} ];
	}
      } else {
	$groups = '';
      }

      my $ldap_crud = $c->model('LDAP_CRUD');

      if ( ! defined $params->{groups} && ! defined $params->{aux_submit} ) {
	my ( $return, $base, $filter, $dn );
	my $mesg = $ldap_crud->search( { base => $ldap_crud->cfg->{base}->{rad_groups},
					 filter => sprintf('member=%s', $params->{'ldap_modify_rad_group'}),
					 attrs => ['cn'], } );
	push @{$return->{error}}, $ldap_crud->err($mesg)->{caller} . $ldap_crud->err($mesg)->{html}
	  if $mesg->code != 0;

	my @groups_usr = $mesg->sorted('cn');
	foreach ( @groups_usr ) { push @{$params->{groups}}, $_->dn; }
	# $params->{groups} = undef;
      }

      $c->stash( template => 'user/user_mod_rad_group.tt',
		 form => $self->form_mod_rad_groups,
		 ldap_modify_rad_group => $params->{'ldap_modify_rad_group'}, );

      return unless $self->form_mod_rad_groups
      	->process( posted => ($c->req->method eq 'POST'),
		   params => $params,
		   ldap_crud => $ldap_crud );

      $c->stash( final_message => $self
		 ->mod_groups( $ldap_crud,
			       { mod_groups_dn => $params->{ldap_modify_rad_group},
				 base => $ldap_crud->cfg->{base}->{rad_groups},
				 groups => $groups,
				 is_submit => defined $params->{aux_submit} &&
				 $params->{aux_submit} eq 'Submit' ? 1 : 0,
				 type => 'groupOfNames', } ), );

#=====================================================================
# Modify memberUids of the Group
#=====================================================================
    } elsif ( defined $params->{'ldap_modify_memberUid'} &&
	      $params->{'ldap_modify_memberUid'} ne '') {
      
      $c->stash( template => 'group/group_mod_memberUid.tt',
		 form => $self->form_mod_memberUid,
		 groupdn => $params->{ldap_modify_memberUid}, );

      my $ldap_crud = $c->model('LDAP_CRUD');
      
      # first run (coming from searchby)
      if ( keys %{$params} == 1 ) {
	my $init_obj = { ldap_modify_memberUid => $params->{ldap_modify_memberUid} };
	my $return;
	my $mesg = $ldap_crud
	  ->search({ base => $params->{ldap_modify_memberUid},
		     attrs => ['memberUid'],
		     sizelimit => 0,});

	push @{$return->{error}}, $ldap_crud->err($mesg)->{html}
	  if $mesg->code ne '0';

	my @group_memberUids = $mesg->sorted('memberUid');

	foreach ( @group_memberUids ) {
	  push @{$init_obj->{memberUid}}, $_->get_value('memberUid');
	}

	# first run, we just have choosen the group to manage and here we
	# render it as it is (no params passed, just init_object)
	return unless $self->form_mod_memberUid
	  ->process( init_object => $init_obj,
		     ldap_crud => $c->model('LDAP_CRUD'), );
      } else {
	# all next, after-submit runs
	return unless $self->form_mod_memberUid
	  ->process( posted => ($c->req->method eq 'POST'),
		     params => $params,
		     ldap_crud => $c->model('LDAP_CRUD'), );

	$c->stash( final_message => $self
		   ->mod_memberUid( $c->model('LDAP_CRUD'),
				    { mod_group_dn => $params->{ldap_modify_memberUid},
				      memberUid => $params->{memberUid}, }), );
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
		     base => $params->{ldap_modify_memberUid},
		     attrs => ['memberUid'],
		    } );

	if ( $mesg->code ne '0' ) {
	  push @{$return->{error}}, $ldap_crud->err($mesg)->{caller} . $ldap_crud->err($mesg)->{html};
	}

	my @group_memberUids = $mesg->sorted('memberUid');

	foreach ( @group_memberUids ) {
	  push @{$params->{memberUid}}, $_->get_value('memberUid');
	}
      }

      p $params;

      $c->stash(
		template => 'group/group_mod_memberUid.tt',
		form => $self->form_mod_memberUid,
		ldap_modify_memberUid => $params->{'ldap_modify_memberUid'},
	       );

      return unless $self->form_mod_memberUid
      	->process(
      		  posted => ($c->req->method eq 'POST'),
      		  params => $params,
      		  ldap_crud => $c->model('LDAP_CRUD'),
      		 );

      $c->stash( final_message => $self
		 ->mod_memberUid(
				 $c->model('LDAP_CRUD'),
				 {
				  mod_group_dn => $params->{ldap_modify_memberUid},
				  memberUid => $params->{memberUid},
				 }
				),
	       );

#=====================================================================
# Add userDhcp
#=====================================================================
    } elsif (defined $params->{'ldap_add_dhcp'} &&
	     $params->{'ldap_add_dhcp'} ne '') {

      $c->stash(
		template => 'dhcp/dhcp_wrap.tt',
		form => $self->form_add_dhcp,
		ldap_add_dhcp => $params->{'ldap_add_dhcp'},
	       );

      return unless $self->form_add_dhcp->process(
						  posted => ($c->req->method eq 'POST'),
						  params => $params,
						  ldap_crud => $c->model('LDAP_CRUD'),
						 );
      $c->stash(
      		final_message => $c->controller('Dhcp')
		->create_dhcp_host ( $c->model('LDAP_CRUD'),
				     {
				      dhcpHWAddress => $params->{dhcpHWAddress},
				      uid => substr((split(',',$params->{ldap_add_dhcp}))[0],4),
				      dhcpStatements => $params->{dhcpStatements},
				      net => $params->{net},
				      cn => $params->{cn},
				      dhcpComments => $params->{dhcpComments},
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
		template => 'user/user_modjpegphoto.tt',
		form => $self->form_jpegphoto,
		ldap_modify_jpegphoto => $params->{'ldap_modify_jpegphoto'},
	       );

      return unless $self->form_jpegphoto->process(
						   posted => ($c->req->method eq 'POST'),
						   params => $params,
						  ) && defined $params->{avatar} && $params->{avatar} ne '';


      my $ldap_crud = $c->model('LDAP_CRUD');

      $c->stash( final_message => $self
		 ->mod_jpegPhoto(
				 $ldap_crud,
				 {
				  mod_jpegPhoto_dn => $params->{ldap_modify_jpegphoto},
				  jpegPhoto => $params->{avatar},
				  jpegPhoto_stub => $c
				  ->path_to('root',
					    'static',
					    'images',
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

      $c->stash(
		template => 'user/user_add_svc.tt',
		form => $self->form_add_svc_acc,
		add_svc_acc => $params->{'add_svc_acc'},
		add_svc_acc_uid => $params->{'add_svc_acc_uid'},
	       );

      $params->{usercertificate} = $c->req->upload('usercertificate') if defined $params->{usercertificate};
      p $params->{usercertificate};

      return unless $self->form_add_svc_acc->process(
						     posted => ($c->req->method eq 'POST'),
						     params => $params,
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

	  $uid = $_ =~ /^802.1x-/ ?
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
	  } elsif ( $_ =~ /^802.1x-/ &&
		    $params->{'password0'} eq '' &&
		    $params->{'password1'} eq '' ) {
	    $pwd->{$_}->{clear} = $self->macnorm({ mac => $params->{'login'} });
	    $login = $self->macnorm({ mac => $login });
	  } else {
	    $pwd = { $_ => $self->pwdgen( { pwd => $params->{'password1'} } ) };
	  }

	  push @{$return->{success}}, {
				       authorizedservice => $_,
				       associateddomain => $params->{'associateddomain_prefix'} . $params->{'associateddomain'},
				       service_uid => $uid,
				       service_pwd => $pwd->{$_}->{clear},
				      };

	  $create_account_branch_return =
	    $c->controller('User')
	      ->create_account_branch ( $ldap_crud,
					{
					 base_uid => substr($id[0], 4),
					 service => $_,
					 associatedDomain => $params->{'associateddomain_prefix'} . $params->{associateddomain},
					},
				      );

	  $return->{error} .= $create_account_branch_return->[0] if defined $create_account_branch_return->[0];
	  $return->{warning} .= $create_account_branch_return->[2] if defined $create_account_branch_return->[2];

	  # requesting data to be used in create_account_branch_leaf()
	  my $mesg = $ldap_crud->search( {
					  base => $params->{'add_svc_acc'},
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
	       basedn => $params->{'add_svc_acc'},
	       service => $_,
	       associatedDomain => $params->{'associateddomain_prefix'} . $params->{associateddomain},
	       uidNumber => $entry[0]->get_value('uidNumber'),
	       givenName => $entry[0]->get_value('givenName'),
	       sn => $entry[0]->get_value('sn'),
	       login => $login,
	       password => $pwd->{$_},
	       telephoneNumber => defined $params->{telephoneNumber} ? $params->{telephoneNumber} : undef,
	       jpegPhoto => $file,
	       userCertificate => $params->{usercertificate},
	       radiusgroupname => $params->{radiusgroupname},
	       radiustunnelprivategroupid => $params->{radiustunnelprivategroupid},
	      };

	  if ( defined $params->{to_sshkeygen} ) {
	    $create_account_branch_leaf_params->{to_sshkeygen} = 1;
	  } elsif ( defined $params->{sshpublickey} &&
		    $params->{sshpublickey} ne '' ) {
	    $create_account_branch_leaf_params->{sshpublickey} = $params->{sshpublickey};
	    $create_account_branch_leaf_params->{sshkeydescr} = $params->{sshkeydescr};
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
	     jpegPhoto => $args->{jpegPhoto},
	     jpegPhoto_stub => $args->{jpegPhoto_stub},
	    };

  my ( $fh, $final_message, $file, $jpeg);
  if (defined $arg->{jpegPhoto}) {
    $file = $arg->{jpegPhoto}->{'tempname'};
  } else {
    $file = $arg->{jpegPhoto_stub};
  }
  
  $jpeg = $self->file2var( $file, $final_message );

  return $jpeg if ref($jpeg) eq 'HASH' && defined $jpeg->{error};

  if ( defined $arg->{jpegPhoto} ) {
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
  }

  return $final_message;
}


=head1 modify_userpassword

modify userPassword method

if no password provided, then it will be auto-generated

=cut


sub modify_userpassword :Path(modify_userpassword) :Args(0) {
  my ( $self, $c ) = @_;
  my $params = $c->req->parameters;

  $c->stash(
	    template => 'user/user_modpwd.tt',
	    form => $self->form_mod_pwd,
	    ldap_modify_password => $params->{ldap_modify_password},
	   );

  return unless $self->form_mod_pwd->process(
					     posted => ($c->req->method eq 'POST'),
					     params => $params,
					    ) &&
  					      ( defined $params->{password_init} ||
  						defined $params->{password_cnfm} ||
  						defined $params->{pwd_cap} ||
  						defined $params->{pwd_len} ||
  						defined $params->{pwd_num} ||
  						defined $params->{pronounceable} );

  my $arg = {
	     mod_pwd_dn => $params->{ldap_modify_password},
	     password_init => $params->{password_init},
	     password_cnfm => $params->{password_cnfm},
	    };

  my ( $return, $pwd );
  if ( $self->form_mod_pwd->validated && $self->form_mod_pwd->ran_validation ) {

    if ( $arg->{password_init} eq '' && $arg->{password_cnfm} eq '' ) {
      $arg->{password_gen} = $self->pwdgen({ len => $params->{'pwd_len'},
					     num => $params->{'pwd_num'},
					     cap => $params->{'pwd_cap'},
					     pronounceable => defined $params->{pronounceable} ? $params->{pronounceable} : 0, });
    } elsif ( $arg->{'password_init'} ne '' && $arg->{'password_cnfm'} ne '' ) {
      $arg->{password_gen} = $self->pwdgen({ pwd => $arg->{'password_cnfm'} });
    }

    $pwd = $arg->{mod_pwd_dn} =~ /.*authorizedService=802.1x-mac.*/ ? $arg->{password_gen}->{clear} : $arg->{password_gen}->{ssha};
    my $mesg = $c->model('LDAP_CRUD')->modify( $arg->{mod_pwd_dn},
					       [ replace => [ 'userPassword' => $pwd, ], ], );

    if ( $mesg ne '0' ) {
      $return->{error} = '<li>Error during password change occured: ' . $mesg->{html} . '</li>';
    } else {
      $return->{success} = 'Password generated:<table class="table table-vcenter">' .
	'<tr><td width="50%"><h1 class="mono text-center">' .
	$arg->{password_gen}->{clear} . '</h1></td><td class="text-center" width="50%">';

      my $qr;
      for( my $i = 0; $i < 41; $i++ ) {
	$qr = $self->qrcode({ txt => $arg->{password_gen}->{clear}, ver => $i, mod => 5 });
	last if ! exists $qr->{error};
      }

      $return->{error} = $qr->{error} if $qr->{error};
      $return->{success} .= sprintf('<img alt="password QR" src="data:image/jpg;base64,%s" title="password QR"/>',
					   $qr->{qr} );
      $return->{success} .= '</td></tr></table>';


#       my $qr = $self->qrcode({ txt => $arg->{password_gen}->{'clear'}, ver => 2, mod => 5 });
#       if ( exists $qr->{error} ) {
# 	$return->{error} = $qr->{error};
#       } else {
# 	$return->{success} = sprintf('<table class="table table-condensed table-vcenter">
# <tr><td><h1 class="mono text-center">%s</h1></td><td class="text-center">
# <img alt="no QR Code was generated for: %s" 
#        src="data:image/jpg;base64,%s" 
#        class="img-responsive"
#        title="QR Code for user input"/></td></tr></table>',
# 				     $arg->{password_gen}->{'clear'},
# 				     $arg->{password_gen}->{'clear'},
# 				     $qr->{qr} );
#       }

    }
  }
  # p $arg;
  $c->stash( final_message => $return, );
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
  my $arg = { obj_dn => $args->{mod_groups_dn},
	      groups => $args->{groups},
	      base => defined $args->{base} ? $args->{base} : $ldap_crud->cfg->{base}->{group},
	      type => defined $args->{type} ? $args->{type} : 'posixGroup',
	      is_submit => $args->{is_submit}, };

  my ( $mesg, $return);
  # if ( $ldap_crud->{cfg}->{rdn}->{acc_root} ne 'uid' ) {
    $mesg = $ldap_crud->search( { base => $arg->{obj_dn},
				  scope => 'base',
				  attrs => [ 'uid' ], });
    push @{$return->{error}}, $ldap_crud->err($mesg)->{caller} . $ldap_crud->err($mesg)->{html}
      if $mesg->code != 0;
    $arg->{uid} = $mesg->entry(0)->get_value( 'uid' );
  # } else {
  #   $arg->{uid} = substr( (split /,/, $args->{mod_groups_dn})[0], 4 );
  # }

  # hash with all selected for add/delete group/s
  if ( ref($arg->{groups}) eq 'ARRAY' ) {
    foreach (@{$arg->{groups}}) { $arg->{groups_sel}->{$_} = 1; }
  }
  # $return;
  $mesg = $ldap_crud->search( { base => $arg->{base},
				filter => $arg->{type} eq 'posixGroup' ?
				'memberUid=' . $arg->{uid} :
				'member=' . $arg->{obj_dn},
				sizelimit => 0,
				attrs => ['cn'], } );
  push @{$return->{error}}, $ldap_crud->err($mesg)->{caller} . $ldap_crud->err($mesg)->{html}
    if $mesg->code ne '0';

  my $g = $mesg->as_struct;

  $mesg = $ldap_crud->search( { base => $arg->{base},
				scope => 'one',
				sizelimit => 0,
				attrs => ['cn'], } );
  push @{$return->{error}}, $ldap_crud->err($mesg)->{caller} . $ldap_crud->err($mesg)->{html}
    if ! $mesg->count;

  my @groups_all = $mesg->sorted('cn');
  foreach ( @groups_all ) {
    # if ( $arg->{type} eq 'posixGroup' ) {
    #   $arg->{groups_all}->{$_->get_value('cn')} = 0;
    #   $arg->{groups_sel}->{$_->get_value('cn')} = 0
    # 	if ! defined $arg->{groups_sel}->{$_->get_value('cn')};
    #   $arg->{groups_old}->{$_->get_value('cn')} =
    # 	# defined $g->{sprintf('cn=%s,%s',$_->get_value('cn'),$ldap_crud->cfg->{base}->{group})} ?
    # 	defined $g->{$_->dn} ? 1 : 0;
    # } else {
      $arg->{groups_all}->{$_->dn} = 0;
      $arg->{groups_sel}->{$_->dn} = 0
	if ! defined $arg->{groups_sel}->{$_->dn};
      $arg->{groups_old}->{$_->dn} =
	defined $g->{$_->dn} ? 1 : 0;
    # }
  }

  # after submit
  if ( $arg->{is_submit} ) {
    my @groups_chg;
    foreach (keys %{$arg->{groups_all}}) {
      # submited data equals to the data from DB - nothing to do
      next if $arg->{groups_old}->{$_} && $arg->{groups_sel}->{$_};
      if (( $arg->{groups_old}->{$_} && ! $arg->{groups_sel}->{$_} ) ||
	  ( $arg->{groups_old}->{$_} && ref($arg->{groups}) ne 'ARRAY' )) {
	# all submited data absent or lacks of DB data - delete
	push @groups_chg, 'delete' => $arg->{type} eq 'posixGroup' ?
	  [ 'memberUid' => $arg->{uid} ] : [ 'member' => $arg->{obj_dn} ];
      } elsif ( ! $arg->{groups_old}->{$_} && $arg->{groups_sel}->{$_} ) {
	# DB data lacks of submited data - add
	push @groups_chg, 'add' => $arg->{type} eq 'posixGroup' ?
	  [ 'memberUid' => $arg->{uid} ] : [ 'member' => $arg->{obj_dn} ];
      }
      # p [sprintf('cn=%s,%s', $_, $arg->{base}), @groups_chg] if $#groups_chg > 0;
      # p \@groups_chg;
      if ( $#groups_chg > 0) {
	# p [sprintf('cn=%s,%s', $_, $arg->{base}), @groups_chg]
	# $mesg = $ldap_crud
	#   ->modify( $arg->{type} eq 'posixGroup' ? sprintf('cn=%s,%s', $_, $arg->{base}) : $_,
	# 	    \@groups_chg ); p $mesg;
	$mesg = $ldap_crud
	  ->modify( $_, \@groups_chg );
	if ( $mesg ) {
	  push @{$return->{error}}, $ldap_crud->err($mesg)->{html};
	} else {
	  push @{$return->{success}},
	    sprintf('<span class="%s">%s</span>',
		    $groups_chg[0] eq 'add' ? 'text-success" title="added to' : 'text-danger" title="deleted from',
		    $groups_chg[0] eq 'add' ? $_ : '<s>' . $_ . '</s>');
	}
	# p [ $return, $arg ];
      }
      $#groups_chg = -1;
    }
  }
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

  my $mesg = $ldap_crud->search( { base => $arg->{mod_group_dn},
				   attrs => ['memberUid'], } );

  push @{$return->{error}}, $ldap_crud->err($mesg)->{caller} . $ldap_crud->err($mesg)->{html}
    if ! $mesg->count;

  foreach ( $mesg->sorted('memberUid') ) {
    push @memberUid_old, $_->get_value('memberUid');
  }
  my @a = sort @{$arg->{memberUid}};
  my @b = sort @memberUid_old; p \@b;
  if ( @a ~~ @b ) {
    $return->{success} = 'Nothing changed.';
  } else {
    foreach (@a) {
      push @{$memberUid}, 'memberUid', $_ ;
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
  my $ldif = $c->model('LDAP_CRUD')->
    ldif(
	 $params->{ldap_ldif},
	 $params->{ldap_ldif_recursive},
	 $params->{ldap_ldif_sysinfo}
	);
        # looks like they are defined always
	#  defined $params->{ldap_ldif_recursive} && $params->{ldap_ldif_recursive} ne '' ? 1 : 0,
	#  defined $params->{ldap_ldif_sysinfo} && $params->{ldap_ldif_sysinfo} ne '' ? 1 : 0
	# );
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
  my $ldif = $c->model('LDAP_CRUD')->
    ldif(
	 $params->{ldap_ldif},
	 $params->{ldap_ldif_recursive},
	 $params->{ldap_ldif_sysinfo}
	);
        # looks like they are defined always
	#  defined $params->{ldap_ldif_recursive} && $params->{ldap_ldif_recursive} ne '' ? 1 : 0,
	#  defined $params->{ldap_ldif_sysinfo} && $params->{ldap_ldif_sysinfo} ne '' ? 1 : 0
	# );

    $c->stash(
	      current_view => 'Download',
	      download => 'text/plain',
	      plain => $ldif->{ldif},
	      outfile_name => $ldif->{outfile_name} . '.LDIF',
	      outfile_ext => 'ldif',
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
  my $vcard = $c->model('LDAP_CRUD')->vcard( $params );
  $c->stash(
	    template => 'search/vcard.tt',
	    final_message => $vcard,
	   );
}

sub vcard_gen2f :Path(vcard_gen2f) :Args(0) {
  my ( $self, $c ) = @_;
  my $params = $c->req->parameters;
  $params->{vcard_type} = 'file';
  my $vcard = $c->model('LDAP_CRUD')->vcard( $params);

  $c->stash(
	    current_view => 'Download',
	    download => 'text/plain',
	    plain => $vcard->{vcard},
	    outfile_name => $vcard->{outfile_name} . '.vCard',
	    outfile_ext => 'vcard',
	   );
  $c->forward('UMI::View::Download');
}


#=====================================================================

=head1 modify

modify whole form (all present fields except RDN)

=cut


sub modify :Path(modify) :Args(0) {
  my ( $self, $c ) = @_;

  my $params = $c->req->parameters;
  my $ldap_crud = $c->model('LDAP_CRUD');
  my $mesg = $ldap_crud->search( { base => $params->{dn}, scope => 'base' } );
  my $return;
  $return->{error} = $ldap_crud->err($mesg)->{html} if $mesg->code;

  my $entry = $mesg->entry(0);

  my ($jpeg, $attr, $val, $orig, $delete, $add);
  my $replace = undef;
  foreach $attr ( sort ( keys %{$params} )) {
    next if $attr =~ /$ldap_crud->{cfg}->{exclude_prefix}/ ||
      $attr eq 'dn' ||
      $attr =~ /userPassword/; ## !! stub, not processed yet !!
    if ( $attr eq "jpegPhoto" ) {
      $params->{jpegPhoto} = $c->req->upload('jpegPhoto');
    }

    $val  = $params->{$attr};
    $orig = $entry->get_value($attr);
    
    # SMARTMATCH: recurse on paired elements of ARRAY1 and ARRAY2
    # if identical then next
    next if ref($val) eq "ARRAY" && $val ~~ $orig;
    next if defined $entry->get_value($attr) && $val eq $entry->get_value($attr);

    # removing all empty array elements if any
    if ( ref($val) eq "ARRAY" ) {
      @{$val} = reverse map { $self->is_ascii($_) &&
			$attr ne 'givenName' && $attr ne 'sn' && $attr ne 'description'	?
			$self->utf2lat($_) : $_ } grep { $_ ne '' } @{$val};
    } elsif ( $val ne '' && defined $entry->get_value($attr) && $val ne $entry->get_value($attr) ) {
      $val = $self->utf2lat($val) if $self->is_ascii($val) &&
	$attr ne 'givenName' && $attr ne 'sn' && $attr ne 'description';
    }

    # what to do or to not to do?
    if ( $val eq '' && defined $entry->get_value($attr) ) {
      push @{$delete}, $attr => [];
    } elsif ( $val ne '' && ! defined $entry->get_value($attr) ) {
      if ( $attr eq 'jpegPhoto' ) {
	$jpeg = $self->file2var( $val->{'tempname'}, $return );
	return $jpeg if ref($jpeg) eq 'HASH' && defined $jpeg->{error};
	$val = [ $jpeg ];
      }
      push @{$add}, $attr => $val;
    } elsif ( $attr eq 'jpegPhoto' && $val ne "" ) {
      $jpeg = $self->file2var( $val->{'tempname'}, $return );
      return $jpeg if ref($jpeg) eq 'HASH' && defined $jpeg->{error};
      push @{$replace}, $attr => [ $jpeg ];
    } elsif ( ref($val) eq "ARRAY" && $#{$val} > -1 ) {
      push @{$replace}, $attr => $val;
    } elsif ( ref($val) ne "ARRAY" && $val ne "" ) { # && $val ne $orig ) {
      push @{$replace}, $attr => $val;
    }
  }

  my $modx;
  if ( defined $delete && $#{$delete} > -1 ) {
    push @{$modx}, delete => $delete;
  }
  if ( defined $add && $#{$add} > -1 ) {
    push @{$modx}, add => $add;
  }
  if ( defined $replace && $#{$replace} > -1 ) {
    push @{$modx}, replace => $replace;
  }

  if ( defined $modx && $#{$modx} > -1 ) {
    # p $modx;
    $mesg = $ldap_crud->modify( $params->{dn}, $modx, );
    if ( $mesg ne "0" ) {
      $return->{error} .= $mesg->{html};
    } else {
      $return->{success} = 'Modification/s made:<pre>' .
	np($modx, caller_info => 0, colored => 0, index => 0) . '</pre>';
    }
  } else {
    $return->{warning} = 'No change was performed!';
  }

  $c->stash( template => 'search/modify.tt', # stub.tt',
	     params => $params,
	     final_message => $return, );

}


#=====================================================================

=head1 modform

modify form as it is (reuse of add)

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

  } elsif ( $params->{aux_dn_form_to_modify} =~ /$ldap_crud->{cfg}->{base}->{netgroup}/ ) { ## NIS NETGROUPS
    if ( ref($init_obj->{nisNetgroupTriple}) eq 'ARRAY' ) {
      $init_obj->{nisNetgroupTriple_arr} = $init_obj->{nisNetgroupTriple};
    } else {
      push @{$init_obj->{nisNetgroupTriple_arr}}, $init_obj->{nisNetgroupTriple};
    }

    foreach $triple ( @{$init_obj->{nisNetgroupTriple_arr}} ) {
      # according the order of LDAP attr nisNetgroupTriple value
      ( $host, $user, $domain ) = split(/,/, $triple);
      push @{$init_obj->{triple}},
	{ host => substr($host, 1),
	  user => $user,
	  domain => substr($domain, 0, -1), };
    }
    delete $init_obj->{nisNetgroupTriple_arr};
    delete $init_obj->{nisNetgroupTriple};

    use UMI::Form::NisNetgroup;
    $form = UMI::Form::NisNetgroup->new( init_object => $init_obj, );
    $c->stash( template => 'nis/nisnetgroup.tt', );
    
  } elsif ( $params->{aux_dn_form_to_modify} =~ /$ldap_crud->{cfg}->{base}->{org}/ ) { ## ORGANIZATIONs
    use UMI::Form::Org; p $init_obj;
    $form = UMI::Form::Org->new( init_object => $init_obj, );
    $c->stash( template => 'org/org_wrap.tt', );
  } else { ## REST
    $return->{warning} = 'Use &laquo;<i class="fa fa-pencil"></i> <b>edit (all)</b>&raquo; menu item instead, please. For now there is only lowlevel edit form for this type of objects.';
    $c->stash( template => 'stub.tt',
	       final_message => $return, );
    $c->detach();
  }
  # p $init_obj;		# p $form; # ->{index};
  $c->stash( form => $form, );
  
  # first run (coming from searchby)
  if ( keys %{$params} == 1 ) {
    return unless $form
      ->process( ldap_crud => $c->model('LDAP_CRUD'), );
  } else {
    return unless $form
      ->process( posted => ($c->req->method eq 'POST'),
		 params => $params,
		 ldap_crud => $c->model('LDAP_CRUD'), );
  }

  $arg->{rpl} = [];
  foreach my $ff ( $form->fields ) {
    next if ! defined $ff->value ||
      $ff->name =~ /aux_/ ||
      defined $init_obj->{$ff->name} && $ff->value eq $init_obj->{$ff->name};

    # the object to modify is NisNetgroup object and current field is tripple and it is not empty
    if ( $form->field('aux_dn_form_to_modify')->value =~ /$ldap_crud->{cfg}->{base}->{netgroup}/ &&
	 $ff->name eq 'triple' && $ff->value ) {
      my $triple;
      foreach ( @{$ff->value} ) {
	push @{$triple}, sprintf('(%s,%s,%s)', $_->{host}, $_->{user}, $_->{domain});
      }
      push @{$arg->{rpl}}, nisNetgroupTriple => $triple;
    } else {
      push @{$arg->{rpl}}, $ff->name => $ff->value if $ff->value ne 'na' && $ff->value ne '';
    }
    
    push @{$arg->{rpl}}, $ff->name => [] if $ff->value eq ''
      && defined $init_obj->{$ff->name}
      && $init_obj->{$ff->name} ne '';
    
  }
  push @{$arg->{changes}}, replace => $arg->{rpl};
  
  # p $arg;
  
  if ( $#{$arg->{rpl}} > 0 ) {
    my $chg = $ldap_crud->modify( $arg->{dn}, $arg->{changes} );
    if ( $chg eq '0' ) {
      $return->{success} = "$arg->{dn} was changed";
    } else {
      $return->{error} = $chg->{html};
    }
  }

  $c->stash( final_message => $return, );

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
      $c->stash->{message} = sprintf('<div class="panel panel-error text-left text-error"><div class="panel-heading text-center"><b>Error! Just close the window and try again!</b></div><div class="panel-body">%s</div></div><br>',
				     $err->{error}->[0]->{html});
    } elsif ( ref($err) eq 'HASH' && $#{$err->{warning}} > -1 ) {
      $c->stash->{message} = sprintf('<div class="panel panel-warning text-left text-warning"><div class="panel-heading text-center"><b>Warning! Just close the window! Nothing else!</b></div><div class="panel-body">%s</div></div><br>',
				     $err->{warning}->[0]->{html});
    }
  } else {
    $c->stash(
	      template => 'search/delete.tt',
	      delete => $params->{'ldap_delete'},
	      recursive => defined $params->{'ldap_delete_recursive'} &&
	      $params->{'ldap_delete_recursive'} eq 'on' ? '1' : '0',
	      err => $err,
	      type => $params->{'type'},
	     );
  }
}

=head1 reassign

object reassign to another root DN

=cut


sub reassign :Path(reassign) :Args(0) {
  my ( $self, $c ) = @_;
  p my $params = $c->req->parameters;

  p my $err = $c->model('LDAP_CRUD')->reassign($params);
  p ref($err);
  
  if ( $params->{type} eq 'json' ) {
    $c->stash->{current_view} = 'WebJSON';
    $c->stash->{success} = ref($err) ne 'HASH' && ref($err) ne 'ARRAY' ? 1 : 0;

    # !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    if ( ref($err) ne 'HASH' && ref($err) ne 'ARRAY' ) {
      $c->stash->{message} = 'OK';
    } elsif ( (ref($err) eq 'HASH' || ref($err) eq 'ARRAY' ) && $#{$err->{error}} > -1 ) {
      $c->stash->{success} = 0;
      $c->stash->{message} = sprintf('<div class="panel panel-danger text-left text-error">
  <div class="panel-heading text-center"><b>Error! Just close the window and try again!</b></div>
  <div class="panel-body">%s</div>
</div>',
      				     $err->{error}->[0]->{html});
    } elsif ( ( ref($err) eq 'HASH' || ref($err) eq 'ARRAY' ) && $#{$err->{warning}} > -1 ) {
      $c->stash->{success} = $err->{warning}->[0]->{code} == 68 ? 1 : 0;
      $c->stash->{message} = sprintf('<div class="panel panel-warning text-left text-warning">
  <div class="panel-heading text-center"><b>Warning! Just close the window! Nothing else!</b></div>
  <div class="panel-body">%s</div>
</div>',
				     $err->{warning}->[0]->{html});
    }
  } else {
    $c->stash( template => 'stub.tt',
	       params => $params,
	       err => $err, );
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
  my $msg = $c->model('LDAP_CRUD')->block( $params );

  if ( $msg != 0 && defined $msg->{error} ) {
    $c->stash(
	      current_view => 'Web',
  	      template => 'search/delete.tt',
  	      final_message => $msg,
  	     );
    $c->forward('View::TT');
  } else {
    if ( $params->{type} eq 'json' ) {
      $c->stash(
		current_view => 'WebJSON',
		success => 'true',
		message => 'OK',
		final_message => $msg,
	       );
    } else {
      $c->stash(
		# template => 'search/delete.tt',
		# delete => $params->{'ldap_delete'},
		# recursive => defined $params->{'ldap_delete_recursive'} &&
		# $params->{'ldap_delete_recursive'} eq 'on' ? '1' : '0',
		err => $msg,
		type => $params->{'type'},
	       );
    }
  }
}



#=====================================================================

=head1 dhcp_add

DHCP object to user binding

=cut


sub dhcp_add :Path(dhcp_add) :Args(0) {
  my ( $self, $c ) = @_;
  my $params = $c->req->parameters;

  $c->stash(
	    template => 'dhcp/dhcp_wrap.tt',
	    form => $self->form_add_dhcp,
	    ldap_add_dhcp => $params->{'ldap_add_dhcp'},
	   );

  return unless $self->form_add_dhcp->process(
					      posted => ($c->req->method eq 'POST'),
					      params => $params,
					      ldap_crud => $c->model('LDAP_CRUD'),
					     );

  $c->stash(
	    final_message => $c->controller('Dhcp')
	    ->create_dhcp_host ( $c->model('LDAP_CRUD'),
				 {
				  dhcpHWAddress => $params->{dhcpHWAddress},
				  uid => substr((split(',',$params->{ldap_add_dhcp}))[0],4),
				  dhcpStatements => $params->{dhcpStatements},
				  net => $params->{net},
				  cn => $params->{cn},
				  dhcpComments => $params->{dhcpComments},
				 }
			       ),
	   ) if $self->form_add_dhcp->validated;
}




=head1 AUTHOR

Zeus Panchenko

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;

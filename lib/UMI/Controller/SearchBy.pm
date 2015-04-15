# -*- cperl -*-
#

package UMI::Controller::SearchBy;
use Moose;
use namespace::autoclean;

use Data::Printer use_prototypes => 0;

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
    my ( $params, $ldap_crud, $filter, $filter_meta, $filter_show, $base );

    $params = $c->req->params;

    $ldap_crud =
      $c->model('LDAP_CRUD');

    $filter_meta = $params->{'ldapsearch_filter'} ne '' ? $params->{'ldapsearch_filter'} : '*';

    if ( defined $params->{'ldapsearch_by_email'} ) {
      $filter = sprintf("mail=%s", $filter_meta);
      $filter_show = sprintf("mail=<kbd>%s</kbd>", $filter_meta);
      $base = $ldap_crud->{cfg}->{base}->{acc_root};
      $params->{'ldapsearch_base'} = $base;
    } elsif ( defined $params->{'ldapsearch_by_jid'} ) {
      $filter = sprintf("&(authorizedService=xmpp@*)(uid=*%s*)", $filter_meta);
      $filter_show = sprintf("&(authorizedService=xmpp@*)(uid=*<kbd>%s</kbd>*)", $filter_meta);
      $base = $ldap_crud->{cfg}->{base}->{acc_root};
      $params->{'ldapsearch_base'} = $base;
    } elsif ( defined $params->{'ldapsearch_by_ip'} ) {
      $filter = sprintf("dhcpStatements=fixed-address %s", $filter_meta);
      $filter_show = sprintf("dhcpStatements=fixed-address <kbd>%s</kbd>", $filter_meta);
      $base = $ldap_crud->{cfg}->{base}->{dhcp};
      $params->{'ldapsearch_base'} = $base;
    } elsif ( defined $params->{'ldapsearch_by_mac'} ) {

      $filter = sprintf("|(dhcpHWAddress=ethernet %s)(&(uid=%s)(authorizedService=802.1*))(&(cn=%s)(authorizedService=802.1*))",
			$self->macnorm({ mac => $filter_meta, dlm => ':', }),
			$self->macnorm({ mac => $filter_meta }),
			$self->macnorm({ mac => $filter_meta }) );

      $filter_show = sprintf("|(dhcpHWAddress=ethernet <kbd>%s</kbd>)(&(uid=<kbd>%s</kbd>)(authorizedService=802.1*))(&(cn=<kbd>%s</kbd>)(authorizedService=802.1*))",
			     $self->macnorm({ mac => $filter_meta, dlm => ':', }),
			     $self->macnorm({ mac => $filter_meta }),
			     $self->macnorm({ mac => $filter_meta }) );

      $base = $ldap_crud->{cfg}->{base}->{db};
      $params->{'ldapsearch_base'} = $base;
    } elsif ( defined $params->{'ldapsearch_by_name'} ) {
      $filter = sprintf("|(givenName=%s)(sn=%s)(uid=%s)(cn=%s)",
			$filter_meta, $filter_meta, $filter_meta, $filter_meta);
      $filter_show = sprintf("|(givenName=<kbd>%s</kbd>)(sn=<kbd>%s</kbd>)(uid=<kbd>%s</kbd>)(cn=<kbd>%s</kbd>)",
			     $filter_meta, $filter_meta, $filter_meta, $filter_meta);
      $base = $ldap_crud->{cfg}->{base}->{acc_root};
      $params->{'ldapsearch_base'} = $base;
    } elsif ( defined $params->{'ldapsearch_by_telephone'} ) {
      $filter = sprintf("|(telephoneNumber=%s)(mobile=%s)(homePhone=%s)",
			$filter_meta, $filter_meta, $filter_meta);
      $filter_show = sprintf("|(telephoneNumber=<kbd>%s</kbd>)(mobile=<kbd>%s</kbd>)(homePhone=<kbd>%s</kbd>)",
			     $filter_meta, $filter_meta, $filter_meta);
      $base = $ldap_crud->{cfg}->{base}->{acc_root};
      $params->{'ldapsearch_base'} = $base;
    } elsif ( defined $params->{'ldapsearch_filter'} &&
	      $params->{'ldapsearch_filter'} ne '' ) {
      $filter = $params->{'ldapsearch_filter'};
      $base = $params->{'ldapsearch_base'};
    } elsif ( defined $params->{'ldap_subtree'} &&
	      $params->{'ldap_subtree'} ne '' ) {
      $filter_show = $filter = 'objectClass=*';
      $base = $params->{'ldap_subtree'};
    } elsif ( defined $params->{'ldap_history'} &&
	      $params->{'ldap_history'} ne '' ) {
      $filter_show = $filter = 'reqDN=' . $params->{'ldap_history'};
      $base = UMI->config->{ldap_crud_db_log};
    } else {
      $filter = 'objectClass=*';
      $filter_show = $filter;
      $base = $params->{'ldapsearch_base'};
    }

    $params->{'filter'} = '(' . $filter_show . ')';
    my $mesg = $ldap_crud->search(
				  {
				   base => $base,
				   filter => '(' . $filter . ')',
				   sizelimit => 50,
				  }
				 );

    my @entries = $mesg->entries;

    my $return;
    $return->{warning} = $ldap_crud->err($mesg)->{caller} .
      ': ' . $ldap_crud->err($mesg)->{html} if ! $mesg->count;

    my ( $ttentries, $attr, $tmp );
    foreach (@entries) {
      # $tmp = $ldap_crud->canonical_dn_rev ( $_->dn );
      $tmp = $_->dn;
      $ttentries->{$tmp}->{'mgmnt'} =
	{
	 is_dn => scalar split(',', $tmp) <= 3 ? 1 : 0,
	 is_account => $tmp =~ /.*,$ldap_crud->{cfg}->{base}->{acc_root}/ ? 1 : 0,
	 is_group => $tmp =~ /.*,$ldap_crud->{cfg}->{base}->{group}/ ? 1 : 0,
	 jpegPhoto => $tmp =~ /.*,$ldap_crud->{cfg}->{base}->{acc_root}/ ? 1 : 0,
	 gitAclProject => $_->exists('gitAclProject') ? 1 : 0,
	 userPassword => $_->exists('userPassword') ? 1 : 0,
	 userDhcp => $tmp =~ /.*,$ldap_crud->{cfg}->{base}->{acc_root}/ &&
	 scalar split(',', $tmp) <= 3 ? 1 : 0,
	};
      foreach $attr (sort $_->attributes) {
	$ttentries->{$tmp}->{attrs}->{$attr} = $_->get_value( $attr, asref => 1 );
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
    }

    # suffix array of dn preparation to respect LDAP objects "inheritance"
    # http://en.wikipedia.org/wiki/Suffix_array
    my @ttentries_keys = map { scalar reverse } sort map { scalar reverse } keys %{$ttentries};
    $c->stash(
	      template => 'search/searchby.tt',
	      base_dn => $base,
	      filter => $filter_show,
	      entrieskeys => \@ttentries_keys,
	      entries => $ttentries,
	      # entries => \@entries,
	      services => $ldap_crud->{cfg}->{authorizedService},
	      final_message => $return,
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

#=====================================================================
# Modify (all fields form)
#=====================================================================
      if (defined $params->{'ldap_modify'} &&
	     $params->{'ldap_modify'} ne '') {

      my ($return, $attr, $entry_tmp, $entry);
      my $ldap_crud =
	$c->model('LDAP_CRUD');
      my $mesg = $ldap_crud->search( { dn => $params->{ldap_modify} } );
      if ( ! $mesg->count ) {
	$return->{error} = $ldap_crud->err($mesg)->{caller} . $ldap_crud->err($mesg)->{html};
      }
      $entry_tmp = $mesg->entry(0);
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
	}
      }
      my $schema = $ldap_crud->obj_schema( { dn => $params->{ldap_modify} } );
      my ($is_single);
      foreach my $objectClass (sort (keys $schema->{$params->{ldap_modify}})) {
	foreach $attr (sort (keys %{$schema->{$params->{ldap_modify}}->{$objectClass}->{must}} )) {
	  next if $attr eq "objectClass";
	  $is_single->{$attr} =
	    $schema->{$params->{ldap_modify}}->{$objectClass}->{must}->{$attr}->{'single-value'};
	}
	foreach $attr (sort (keys %{$schema->{$params->{ldap_modify}}->{$objectClass}->{may}} )) {
	  next if $attr eq "objectClass";
	  $is_single->{$attr} =
	    $schema->{$params->{ldap_modify}}->{$objectClass}->{may}->{$attr}->{'single-value'};
	}
      }

      p $is_single;
      ## here we work with the only one, single entry!!
      # $c->session->{modify_entries} = $mesg->entry(0);
      # $c->session->{modify_dn} = $params->{ldap_modify};
      # $c->session->{modify_schema} = $is_single;



      $c->stash(
		template => 'search/modify.tt', # look modify() bellow
		modify => $params->{'ldap_modify'},
		entries => $entry,
		schema => $is_single,
		final_message => $return,
		rdn => (split('=', (split(',', $params->{ldap_modify}))[0]))[0],
	       );

#=====================================================================
# Modify Groups
#=====================================================================
    } elsif ( defined $params->{'ldap_modify_group'} &&
	      $params->{'ldap_modify_group'} ne '') {

      # in general preselected options has to be fed via field value
      # $params->{groups} = [ qw( group0 group1 ... groupN) ];
      #
      # no submit yet, it is first run
      if ( ! defined $params->{groups} ) {
	my ( @groups, $return );
	my $ldap_crud =
	  $c->model('LDAP_CRUD');
	my $mesg = $ldap_crud
	  ->search( {
		     base => $ldap_crud->{cfg}->{base}->{group},
		     filter => 'memberUid=' .
		     substr((split /,/, $params->{ldap_modify_group})[0], 4),
		     attrs => ['cn'],
		    } );

	if ( $mesg->code != 0 ) {
	  push @{$return->{error}}, $ldap_crud->err($mesg)->{caller} . $ldap_crud->err($mesg)->{html};
	}

	my @groups_usr = $mesg->sorted('cn');

	foreach ( @groups_usr ) {
	  push @{$params->{groups}}, $_->get_value('cn');
	}
      }

      $c->stash(
		template => 'user/user_mod_group.tt',
		form => $self->form_mod_groups,
		ldap_modify_group => $params->{'ldap_modify_group'},
	       );

      return unless $self->form_mod_groups
      	->process(
      		  posted => ($c->req->method eq 'POST'),
      		  params => $params,
      		  ldap_crud => $c->model('LDAP_CRUD'),
      		 );

      $c->stash( final_message => $self
		 ->mod_groups(
			      $c->model('LDAP_CRUD'),
			      {
			       mod_groups_dn => $params->{ldap_modify_group},
			       groups => $params->{groups},
			      }
			     ),
	       );

#=====================================================================
# Modify memberUids of the Group
#=====================================================================
    } elsif ( defined $params->{'ldap_modify_memberUid'} &&
	      $params->{'ldap_modify_memberUid'} ne '') {

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
      # p $params;
      $params->{avatar} = $c->req->upload('avatar') if defined $params->{avatar};
      # p $params;

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
					    $ldap_crud->{cfg}->{jpegPhoto}->{stub}),
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
	       radiustunnelprivategroup => $params->{radiustunnelprivategroup},
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

  my ($file, $jpeg);
  if (defined $arg->{jpegPhoto}) {
    $file = $arg->{jpegPhoto}->{'tempname'};
  } else {
    $file = $arg->{jpegPhoto_stub};
  }
  local $/ = undef;
  open(my $fh, "<", $file) or p $!;
  $jpeg = <$fh>;
  close($fh);

  my ( $error_message, $success_message, $final_message );
  if ( defined $arg->{jpegPhoto} ) {
    my $mesg = $ldap_crud->mod(
			       $arg->{mod_jpegPhoto_dn},
			       { 'jpegPhoto' => [ $jpeg ], }
			      );

    if ( $mesg ne '0' ) {
      $error_message = '<li>Error during jpegPhoto add/change occured: ' . $mesg . '</li>';
    } else {
      $success_message .= $arg->{jpegPhoto}->{'filename'} .
	'</kbd> of type ' . $arg->{jpegPhoto}->{'type'} . ' and ' .
	  $arg->{jpegPhoto}->{'size'} . ' bytes size.';
    }
  }
  if ( $self->form_jpegphoto->validated ) {
    $final_message = '<div class="alert alert-success" role="alert">' .
      '<span style="font-size: 140%" class="glyphicon glyphicon-ok-sign">&nbsp;</span>' .
	'<em>jpegPhoto attribute is added/changed from file: </em>&nbsp;' .
	  '<kbd style="font-size: 110%; font-family: monospace;">' .
	    $success_message . '</div>' if $success_message;
  }

  $final_message .= '<div class="alert alert-danger" role="alert">' .
    '<span style="font-size: 140%" class="icon_error-oct" aria-hidden="true"></span><ul>' .
      $error_message . '</ul></div>' if $error_message;

  return $final_message;
}


#=====================================================================

=head1 mod_pwd

DEPRECATED?

modify password method

=cut


sub mod_pwd {
  my ( $self, $ldap_crud, $args ) = @_;

  my $arg = {
	     mod_pwd_dn => $args->{mod_pwd_dn},
	     password_init => $args->{password_init},
	     password_cnfm => $args->{password_cnfm},
	    };

  my ( $error_message, $success_message, $final_message );
  if ( $self->form_mod_pwd->validated && $self->form_mod_pwd->ran_validation ) {

    if ( $arg->{'password_init'} eq '' && $arg->{'password_cnfm'} eq '' ) {
      $arg->{password_gen} = $self->pwdgen;
    } elsif ( $arg->{'password_init'} ne '' && $arg->{'password_cnfm'} ne '' ) {
      $arg->{password_gen} = $self->pwdgen({ pwd => $arg->{'password_cnfm'} });
    }
    my $mesg = $ldap_crud->mod(
			       $arg->{mod_pwd_dn},
			       {
				'userPassword' => $arg->{password_gen}->{ssha}, },
			      );

    if ( $mesg ne '0' ) {
      $error_message = '<li>Error during password change occured: ' . $mesg . '</li>';
    } else {
      $success_message .= $arg->{password_gen}->{'clear'};
    }

    $final_message = '<div class="alert alert-success" role="alert">' .
      '<span style="font-size: 140%" class="glyphicon glyphicon-ok-sign">&nbsp;</span>' .
	'<em>Password is changed and is:</em>&nbsp;' .
	  '<kbd style="font-size: 150%; font-family: monospace;">' .
	    $success_message . '</kbd></div>' if $success_message;
  }

  $final_message .= '<div class="alert alert-danger" role="alert">' .
    '<span style="font-size: 140%" class="icon_error-oct" aria-hidden="true"></span><ul>' .
      $error_message . '</ul></div>' if $error_message;

  return $final_message;
}


#=====================================================================

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
						defined $params->{password_cnfm} );

  my $arg = {
	     mod_pwd_dn => $params->{ldap_modify_password},
	     password_init => $params->{password_init},
	     password_cnfm => $params->{password_cnfm},
	    };

  my $return;
  if ( $self->form_mod_pwd->validated && $self->form_mod_pwd->ran_validation ) {

    if ( $arg->{'password_init'} eq '' && $arg->{'password_cnfm'} eq '' ) {
      $arg->{password_gen} = $self->pwdgen;
    } elsif ( $arg->{'password_init'} ne '' && $arg->{'password_cnfm'} ne '' ) {
      $arg->{password_gen} = $self->pwdgen({ pwd => $arg->{'password_cnfm'} });
    }

    my $mesg = $c->model('LDAP_CRUD')->mod(
					   $arg->{mod_pwd_dn},
					   {
					    'userPassword' => $arg->{password_gen}->{ssha}, },
					  );

    if ( $mesg ne '0' ) {
      $return->{error} = '<li>Error during password change occured: ' . $mesg . '</li>';
    } else {
      $return->{success} .= '<table class="table table-condensed table-vcenter"><tr><td><h1 class="mono text-right"><kbd>' .
	$arg->{password_gen}->{'clear'} . '</kbd></h1></td><td class="text-center">';

      use GD::Barcode::QRcode;
      # binmode(STDOUT);
      # print "Content-Type: image/png\n\n";
      # print GD::Barcode::QRcode->new( $arg->{password_gen}->{'clear'} )->plot->png;

      use MIME::Base64;
      my $qr = sprintf('<img alt="password" src="data:image/jpg;base64,%s" class="img-responsive img-thumbnail" title="password"/>',
		       encode_base64(GD::Barcode::QRcode
				     ->new( $arg->{password_gen}->{'clear'},
					    { Ecc => 'Q', Version => 6, ModuleSize => 8 } )
				     ->plot()->png)
		      );
      $return->{success} .= $qr . '</td></tr></table>';
    }
  }

  $c->stash( final_message => $return, );
}


#=====================================================================

=head1 mod_groups

modify user's groups method

=cut


sub mod_groups {
  my ( $self, $ldap_crud, $args ) = @_;

  my $arg = {
	     mod_groups_dn => $args->{mod_groups_dn},
	     groups => ref($args->{groups}) eq 'ARRAY' ? $args->{groups} : [ $args->{groups} ],
	     uid => substr( (split /,/, $args->{mod_groups_dn})[0], 4 ),
	    };

  foreach (@{$arg->{groups}}) {
    $arg->{groups_sel}->{$_} = 1;
  }

  p $arg;

  my $return;
  if ( $self->form_mod_groups->validated ) {
    my $mesg = $ldap_crud->search( { base => $ldap_crud->{cfg}->{base}->{group},
				     scope => 'one',
				     attrs => ['cn'], } );

    if ( ! $mesg->count ) {
      push @{$return->{error}}, $ldap_crud->err($mesg)->{caller} . $ldap_crud->err($mesg)->{html};
    }

    my @groups_all = $mesg->sorted('cn');

    foreach ( @groups_all ) {
      $arg->{groups_all}->{$_->get_value('cn')} = 0;
    }

    $mesg = $ldap_crud->search( { base => $ldap_crud->{cfg}->{base}->{group},
    				  filter => 'memberUid=' . $arg->{uid},
    				  attrs => ['cn'], } );

    if ( $mesg->code ne '0' ) {
      push @{$return->{error}}, $ldap_crud->err($mesg)->{caller} . $ldap_crud->err($mesg)->{html};
    }

    my @groups_usr = $mesg->sorted('cn');

    foreach ( @groups_usr ) {
      $arg->{groups_old}->{$_->get_value('cn')} = 1;
    }

    my @groups_chg;
    foreach (keys %{$arg->{groups_all}}) {
      next if defined $arg->{groups_old}->{$_} &&
	defined $arg->{groups_sel}->{$_}; # user already belongs to the group

      if ( $arg->{groups_old}->{$_} &&
	   ! $arg->{groups_sel}->{$_} ) {
	push @groups_chg, 'delete' => [ 'memberUid' => $arg->{uid} ];
      } elsif ( ! $arg->{groups_old}->{$_} &&
		$arg->{groups_sel}->{$_} ) {
	push @groups_chg, 'add' => [ 'memberUid' => $arg->{uid} ];
      }

      if ( $#groups_chg >= 0) {
	p [ $_, @groups_chg ];
	$mesg = $ldap_crud->modify(
				   'cn=' . $_ . $ldap_crud->{cfg}->{base}->{group},
				   \@groups_chg
				  );
	if ( $mesg ) {
	  push @{$return->{error}}, $ldap_crud->err($mesg)->{caller} . $ldap_crud->err($mesg)->{html};
	} else {
	  $return->{success}->[0] = 1;
	}
	$#groups_chg = -1;
      }
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

  my $arg = {
	     mod_group_dn => $args->{mod_group_dn},
	     memberUid => ref($args->{memberUid}) eq 'ARRAY' ? $args->{memberUid} : [ $args->{memberUid} ],
	     cn => substr( (split /,/, $args->{mod_group_dn})[0], 3 ),
	    };

  my $return;
  if ( $self->form_mod_memberUid->validated ) {

    my ( $memberUid, @memberUid_old );

    my $mesg = $ldap_crud->search( { base => $arg->{mod_group_dn},
				     attrs => ['memberUid'], } );

    if ( ! $mesg->count ) {
      push @{$return->{error}}, $ldap_crud->err($mesg)->{caller} . $ldap_crud->err($mesg)->{html};
    }

    foreach ( $mesg->sorted('memberUid') ) {
      push @memberUid_old, $_->get_value('memberUid');
    }
    my @a = sort @{$arg->{memberUid}};
    my @b = sort @memberUid_old;
    if ( @a ~~ @b ) {
      $return->{success}->[0] = 1;
    } else {
      foreach (@a) {
	push @{$memberUid}, 'memberUid', $_ ;
      }
      $mesg = $ldap_crud->modify(
      				 $arg->{mod_group_dn},
      				 [ replace => [ memberUid => \@a ] ],
      				);
      if ( $mesg ) {
      	push @{$return->{error}}, $ldap_crud->err($mesg)->{caller} . $ldap_crud->err($mesg)->{html};
      } else {
      	$return->{success}->[0] = 1;
      }
    }
  }
  return $return;
}

#=====================================================================

=head1 ldif

get LDIF (recursive or not, with or without system data) for the DN
given

Since it is separate action, it is poped out of action proc()

=cut


sub ldif_gen :Path(ldif_gen) :Args(0) {
  my ( $self, $c ) = @_;
  my $params = $c->req->parameters;

  $c->stash(
	    template => 'search/ldif.tt',
	    final_message => $c->model('LDAP_CRUD')
	    ->ldif(
		   $params->{ldap_ldif},
		   defined $params->{ldap_ldif_recursive} && $params->{ldap_ldif_recursive} ne '' ? 1 : 0,
		   defined $params->{ldap_ldif_sysinfo} && $params->{ldap_ldif_sysinfo} ne '' ? 1 : 0
		  ),
	  );
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
  $return->{error} .= '<li>' . $ldap_crud->err($mesg)->{caller} . $ldap_crud->err($mesg)->{html} . '</li>'
    if $mesg->code;

  my $entry = $mesg->entry(0);

  my ($attr, $val, $orig);
  my $mod = undef;
  foreach $attr ( sort ( keys %{$params} )) {
    next if ( $attr eq 'dn' ||
	      $attr =~ /$ldap_crud->{cfg}->{exclude_prefix}/ ||
	      $attr =~ /userPassword/ ); ## !! stub, not processed yet !!
    if ( $attr eq "jpegPhoto" ) {
      $params->{jpegPhoto} = $c->req->upload('jpegPhoto');
    }

    $val = $entry->get_value ( $attr, asref => 1 );

    $orig = ref($val) eq "ARRAY" && scalar @{$val} == 1 ? $val->[0] : $val;
    p $val = $params->{$attr};
    # removing all empty array elements if any
    if ( ref($val) eq "ARRAY" ) {
      @{$val} = map { $self->is_ascii($_) ? $self->utf2lat($_) : $_ } grep { $_ ne '' } @{$val};
    } elsif ( $val ne '' ) {
      $val = $self->utf2lat($val) if $self->is_ascii($val);
    }

    # SMARTMATCH: recurse on paired elements of ARRAY1 and ARRAY2
    # if identical then next
    next if $val ~~ $orig;

    if ( $attr eq 'jpegPhoto' && $val ne "" ) {
      my ($file, $jpeg);
      $file = $val->{'tempname'};
      local $/ = undef;
      open(my $fh, "<", $file) or $c->log->debug("Can not open $file: $!" );
      $jpeg = <$fh>;
      close($fh) or $c->log->debug($!);
      $mod->{$attr} = [ $jpeg ];
    } elsif ( $val ne "" or $val ne "0" ) { # && $val ne $orig ) {
      $mod->{$attr} = $val;
    }
  }

  if ( defined $mod ) {
    $mesg = $ldap_crud->mod( $params->{dn}, $mod );
    if ( $mesg ne "0" ) {
      $return->{error} .= '<li>' . $mesg . '</li>';
    }
    $return->{success} = p($mod);
  } else {
    $return->{warning} = 'No change was performed!';
  }

  $c->stash(
	    template => 'stub.tt',
	    params => $params,
	    final_message => $return,
	   );
}


#=====================================================================

=head1 user_preferences

single page with all user data assembled to the convenient view

=cut


sub user_preferences :Path(user_preferences) :Args(0) {
  my ( $self, $c ) = @_;
  my $params = $c->req->parameters;

  $c->controller('Root')
    ->user_preferences( $c,
			{
			 uid => substr((split(',', $params->{'user_preferences'}))[0],4),
			}
		      );
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
    $c->stash->{success} = 'true';
    $c->stash->{message} = 'OK';
    # $c->forward('View::JSON');
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

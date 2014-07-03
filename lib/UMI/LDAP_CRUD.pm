# -*- cperl -*-
#

package LDAP_CRUD;

use Data::Dumper;
use Net::LDAP;
use Moose;
use Try::Tiny;
use namespace::autoclean;

with 'Tools';

has 'host' => ( is => 'ro', isa => 'Str', required => 1, default => 'ldaps://ldap1.ibs');
has 'uid' => ( is => 'ro', isa => 'Str', required => 1 );
has 'pwd' => ( is => 'ro', isa => 'Str', required => 1 );
has 'dry_run' => ( is => 'ro', isa => 'Bool', default => 0 );

has 'cfg' => ( traits => ['Hash'],
	       is => 'ro',
	       isa => 'HashRef',
	       builder => '_build_cfg',
	     );

sub _build_cfg {
  return {
	  exclude_prefix => 'aux_',
	  base => {
		   org => 'ou=Organizations,dc=ibs',
		   acc => 'ou=People,dc=ibs',
		  },
	  objectClass => {
			  org => [ qw(
				       top
				       organizationalUnit
				    )
				 ],
			  acc_root => [ qw(
					    top
					    posixAccount
					    inetOrgPerson
					    organizationalPerson
					    person
					    inetLocalMailRecipient
					 )
				      ],
			  acc_svc_branch => [ qw(
						  account
						  authorizedServiceObject
					       )
					    ],
			  acc_svc_common => [ qw(
						  posixAccount
						  shadowAccount
						  inetOrgPerson
						  authorizedServiceObject
						  domainRelatedObject
					       )
					    ],

			 },
	 };
}

has '_ldap' => (
	is       => 'rw',
	isa      => 'Net::LDAP',
	required => 0, lazy => 1,
	builder  => '_build_ldap',
	clearer  => 'reset_ldap',
	reader   => 'ldap',
);
sub _build_ldap {
	my $self = shift;

	my $ldap = try {
		Net::LDAP->new( $self->host, async => 1 );
	}
	catch {
		warn "Net::LDAP->new problem, error: $_";    # not $@
	};

	return $ldap;
}

around 'ldap' =>
  sub {
    my $orig = shift;
    my $self = shift;

    my $ldap = $self->$orig(@_);

    my $mesg = $ldap->bind(
			   sprintf( 'uid=%s,ou=People,dc=ibs', $self->uid ),
			   password => $self->pwd,
			   version  => 3,
			  );
    if ( $mesg->is_error ) {
      warn "Net::LDAP->bind error_desc: " .
	$mesg->error_desc .
	  "; server_error: " .
	    $mesg->server_error;
    }
    return $ldap;
  };


=head2 err

Net::LDAP errors handling

Net::LDAP::Message is expected as single input argument

=cut

sub err {
  my ($self, $mesg) = @_;

# to finish #   use Data::Dumper;
# to finish #   use Log::Contextual qw( :log :dlog set_logger with_logger );
# to finish #   use Log::Contextual::SimpleLogger;
# to finish # 
# to finish #   my $logger = Log::Contextual::SimpleLogger->new({
# to finish # 						   levels => [qw( trace debug )]
# to finish # 						  });
# to finish # 
# to finish #   set_logger $logger;
# to finish # 
# to finish #   log_debug { Dumper($self) . "\n" . $self->err( $mesg ) };

  return sprintf( "<dl class=\"dl-horizontal\"><dt>code</dt><dd>%s</dd><dt>error_name</dt><dd>%s</dd><dt>error_text</dt><dd>%s</dd><dt>error_desc</dt><dd>%s</dd><dt>server_error</dt><dd>%s</dd></dl>",
		  $mesg->code,
		  $mesg->error_name,
		  $mesg->error_text,
		  $mesg->error_desc,
		  $mesg->server_error)
    if $mesg->code;
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

=head2 add

=cut

sub add {
  my ($self, $dn, $attrs) = @_;

  my $callername = (caller(1))[3];
  $callername = 'main' if ! defined $callername;
  my $return = 'call to LDAP_CRUD->add from ' . $callername . ': ';
  my $msg;
  if ( ! $self->dry_run ) {
    $msg = $self->ldap->add ( $dn, attrs => $attrs, );
    if ($msg->is_error()) {
      # $return = "error_descr: " . $msg->error_desc();
      # $return .= "; server_error: " . $msg->server_error() if defined $msg->server_error();
      $return .= $self->err( $msg );
    } else {
      $return = 0;
    }
  } else {
    $return = $msg->ldif;
  }
  return $return;
}

=head2 delete

TODO

to care recursively of subtree of the object to be deleted if exist

=cut

sub del {
  my ($self, $dn) = @_;

  my $callername = (caller(1))[3];
  $callername = 'main' if ! defined $callername;
  my $return = 'call to LDAP_CRUD->del from ' . $callername . ': ';

  if ( ! $self->dry_run ) {
    my $msg = $self->ldap->delete ( $dn );
    if ($msg->code) {
      $return .= "error_descr: " . $msg->error_desc;
      $return .= "; server_error: " . $msg->server_error if defined $msg->server_error;
    } else {
      $return = 0;
    }
  } else {
    $return = 0;
  }
  return $return;
}

=head2 mod

modify method

=cut

sub mod {
  my ($self, $dn) = @_;
  # replace => { ATTR => VALUE, ... }

  # Replace any existing values in each given attribute with
  # VALUE. VALUE should be a string if only a single value is wanted
  # in the attribute, or a reference to an array of strings if
  # multiple values are wanted. A reference to an empty array will
  # remove the entire attribute. If the attribute does not already
  # exist in the entry, it will be created.

  # $mesg = $ldap
  #   ->modify( $dn,
  # 	      replace => {
  # 			  description => 'New List of members', # Change the description
  # 			  member      => [ # Replace whole list with these
  # 					  'cn=member1,ou=people,dc=example,dc=com',
  # 					  'cn=member2,ou=people,dc=example,dc=com',
  # 					 ],
  # 			  seeAlso => [], # Remove attribute
  # 			 }
  # 	    );

}

=head2 last_uidNumber

Last uidNumber for base ou=People,dc=ibs

to add error correction

=cut

sub last_uidNumber {
  my $self = shift;

  my $callername = (caller(1))[3];
  $callername = 'main' if ! defined $callername;
  my $return = 'call to LDAP_CRUD->last_uidNumber from ' . $callername . ': ';

  $self->reset_ldap;
  my $mesg =
    $self->ldap->search(
			base   => 'ou=People,dc=ibs',
			scope  => 'one',
			filter => '(uidNumber=*)',
			attrs  => [ 'uidNumber' ],
			deref => 'never',
		       );

  if ( $mesg->code ) {
    $return .= $self->err( $mesg );
  } else {
    # my @uids_arr = sort { $a <=> $b } map { $_->get_value('uidNumber') } $mesg->entries;
    my @uids_arr = $mesg->sorted ( 'uidNumber' );
    $return = $uids_arr[$#uids_arr]->get_value( 'uidNumber' );
  }
  return $return;
}

=head2 obj_schema

LDAP object schema and data

returned structure is hash of all mandatory and optional attributes of
all objectClass-es of the object:

$VAR1 = {
  'DN1' => {
    'objectClass1' => {
      'must' => {
        'mustAttr1' => {
          'equality' => ...,
          'desc' => ...,
          'single-value' => ...,
          'attr_value' => ...,
          'max_length' => ...,
        },
        'mustAttrN' {
        ...
        },
       },
       'may' => {
         'mayAttr1' => {
           'equality' => ...,
           'desc' => ...,
           'single-value' => ...,
           'attr_value' => ...,
           'max_length' => ...,
         },
         'mayAttrN' {
         ...
         },
       },
    },
    'objectClass2' => {
    ...
    },
  },
  'DN2' => {
  ...
  },
}

Commonly, we will wish to use it for the single object to build the
form to add or modify

TODO

to add error correction

=cut

sub obj_schema {
  my ($self, $args) = @_;
  my $arg = {
  	     base   => $args->{base},
  	     scope  => $args->{scope} || 'one',
  	     filter => $args->{filter},
  	    };

  my $mesg =
    $self->ldap->search(
			base   => $arg->{base},
			scope  => $arg->{scope},
			filter => $arg->{filter},
		       );
  my @entries = $mesg->entries;

  my ( $must, $may, $obj_schema );
  foreach my $entry ( @entries ) {
    foreach my $objectClass ( $entry->get_value('objectClass') ) {
      next if $objectClass eq 'top';
      foreach $must ( $self->schema->must ( $objectClass ) ) {
	$obj_schema->{$entry->dn}->{$objectClass}->{'must'}
	  ->{ $must->{'name'} } =
	    {
	     'attr_value' => $entry->get_value( $must->{'name'} ) || undef,
	     'desc' => $must->{'desc'} || undef,
	     'single-value' => $must->{'single-value'} || undef,
	     'max_length' => $must->{'max_length'} || undef,
	     'equality' => $must->{'equality'} || undef,
	    };
      }

      foreach $may ( $self->schema->may ( $objectClass ) ) {
	$obj_schema->{$entry->dn}->{$objectClass}->{'may'}
	  ->{$may->{'name'}} =
	    {
	     'attr_value' => $entry->get_value( $may->{'name'} ) || undef ,
	     'desc' => $may->{'desc'} || undef ,
	     'single-value' => $may->{'single-value'} || undef ,
	     'max_length' => $may->{'max_length'} || undef ,
	     'equality' => $may->{'equality'} || undef ,
	    };
      }
    }
  }
  return $obj_schema;
}

=head2 select_key_val

returns ref on hash (mostly aimed for select form elements `options_'
method. It expects each ldapsearch result entry to be single value.

ldapsearch option `attrs' is expected to be single, lowercased
(otherwise, ->search fails, do not know why but need to verify!) value
of the attribyte for which hash to be built, DN will be the key and
the attributes value, is the value

$VAR1 = {
          'dn1' => 'attributeValue 1',
          ...
          'dnN' => 'attributeValue 1',
        }

TODO:

to add error correction

=cut

sub select_key_val {
  my ($self, $args) = @_;
  my $arg = {
	     base => $args->{'base'},
	     filter => $args->{'filter'},
	     scope => $args->{'scope'},
	     attrs => $args->{'attrs'},
	    };
  my $mesg =
    $self->ldap->search(
			base => $arg->{'base'},
			filter => $arg->{'filter'},
			scope => $arg->{'scope'},
			attrs => [ $arg->{'attrs'} ],
			deref => 'never',
		       );

  my $entries = $mesg->as_struct;

  my %results;
  foreach my $key (sort (keys %{$entries})) {
    foreach my $val ( @{$entries->{$key}->{$arg->{'attrs'}}} ) {
      # $results{"$key"} = $val if ! $val =~ /[^[:ascii:]]/;
      $results{"$key"} = $val;
    }
  }
  return \%results;
}

=head2 obj_add

=cut

sub obj_add {
  my ( $self, $args ) = @_;
  my $type = $args->{'type'};
  my $params = $args->{'params'};
  my $form = $args->{'form'};

  return '' unless %{$params};

  my $descr = 'description has to be here';
  if (defined $params->{'descr'} && $params->{'descr'} ne '') {
    $descr = join(' ', $params->{'descr'});
  }

#
## TODO
## HERE WE NEED TO SET FLAG TO CREATE BRANCH FOR LOCALIZED VERSION OF DATA
## associatedService=localization-ru,uid=U...-user01,ou=People,dc=ibs
## associatedService=localization-uk,uid=U...-user01,ou=People,dc=ibs
## e.t.c.
#

  my $attr_defined = $self
    ->attrs_crawl({
		   type => $type,
		   params => $params,
		  });

  my $base = $params->{'aux_parent'} ne "0" ? $params->{'aux_parent'} : $self->{'cfg'}->{'base'}->{$type};
  my $ldif =
    $self->add(
	       sprintf('ou=%s,%s', $params->{'ou'}, $base),
	       $attr_defined,
	      );
  my $message;
  if ( $ldif ) {
#    $error_message = 'Error during organization object creation occured: ' . $ldif;
    $message .= '<div class="alert alert-danger">' .
      '<span style="font-size: 140%" class="icon_error-oct" aria-hidden="true"></span>&nbsp;' .
	'Error during organization object creation occured: ' . $ldif . '</div>';

    warn sprintf('object dn: ou=%s,%s wasn not created! errors: %s', $params->{'ou'}, $base, $ldif);
  } else {
    $message .= '<div class="alert alert-success">' .
      '<span style="font-size: 140%" class="glyphicon glyphicon-ok-sign"></span>' .
	'&nbsp;<em>Object for organization ' .
	  ' &laquo;' . $self->utf2lat( $params->{'physicalDeliveryOfficeName'} ) .
	    '&raquo;</em> successfully created.</div>';
  }

  # warn 'FORM ERROR' . $final_message if $final_message;
  $form->info_message( $message );

  # $self->unbind;

  warn 'LDAP ERROR' . $ldif if $ldif;

  return { info_message => $message };
#  return $ldif;
}

=head2 attrs_crawl

crawls all $c->req->params and prepares attrs array ref to be fed to
->add for object creation

=cut

sub attrs_crawl {
  my ( $self, $args ) = @_;

my $arg = {
	   type => $args->{'type'},
	   params => $args->{'params'},
	  };

  my ( $val, $result );

  push @{$result}, objectClass => $self->{'cfg'}->{'objectClass'}->{$arg->{'type'}};

  foreach my $key (keys %{$arg->{'params'}}) {
    next if $key =~ /^$self->{'cfg'}->{'exclude_prefix'}/;
    next if $arg->{'params'}->{$key} eq '';

    #
    ## TODO
    ## to add multivalue fields processing
    $val = $self->is_ascii( $arg->{'params'}->{$key} ) ?
      $self->utf2lat( $arg->{'params'}->{$key} ) :
	$arg->{'params'}->{$key};

    push @{$result}, $key => $val;
  }
  # warn 'attributes prepared $result:' . Dumper($result);
  return $result;
}

######################################################################

no Moose;
__PACKAGE__->meta->make_immutable;

1;

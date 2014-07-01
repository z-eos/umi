package UMI::Controller::LDAPaddUser;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; with 'Tools'; }

use UMI::Form::LDAPaddUser;

has 'form' => ( isa => 'UMI::Form::LDAPaddUser', is => 'rw',
		lazy => 1, default => sub { UMI::Form::LDAPaddUser->new },
		documentation => q{Form to add new, nonexistent user account/s},
	      );

=head1 NAME

UMI::Controller::LDAPaddUser - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 index

=cut

sub index :Path :Args(0) {
    my ( $self, $c, $ldapadduser_id ) = @_;
    if ( $c->check_user_roles('umi-admin')) {
      # use Data::Dumper;

      $c->stash( template => 'ldapact/ldapact_add_user_wrap.tt',
		 form => $self->form );

      my $params = $c->req->parameters;
      $params->{'avatar'} = $c->req->upload('avatar');

      # use Data::Dumper;
      # $c->log->debug( "\$params:\n" . Dumper($params));

      # Validate and insert/update database
      return unless $self->form->process( item_id => $ldapadduser_id,
					  posted => ($c->req->method eq 'POST'),
					  params => $params,
					  ldap_crud => $c->model('LDAP_CRUD'),
					);

      # $c->log->debug("Moose::Role test:\n" . $self->is_ascii("latin1"));

      my $res = $self->create_account( $c );
      $c->log->debug( "create_account (from umi_add) error: " . $res) if $res;
    } else { 
      $c->response->body('Unauthorized!');
    }

}

=head2 create_account

=cut

sub create_account {
    my  ( $self, $c ) = @_;
    my $args = $c->req->parameters;

    use Data::Dumper;
    # $c->log->debug( "\$args:\n" . Dumper($args));

    my $ldap_crud = $c->model('LDAP_CRUD');

    # $c->log->debug( "ldap_crud: " . Dumper($ldap_crud) . "\n");
    my $uidNumber = $ldap_crud->last_uidNumber;

    if ( $args->{'associateddomain'} eq 'ibs.dn.ua' ) {
      $args->{'associateddomain_prefix'} = 'im.';
    } else {
      $args->{'associateddomain_prefix'} = '';
    }

    my $descr = 'description has to be here';
    if (defined $args->{'descr'} && $args->{'descr'} ne '') {
      $descr = join(' ', $args->{'descr'});
    }

    my $telephoneNumber = '666';
    if (defined $args->{'telephonenumber'} && $args->{'telephonenumber'} ne '') {
      $telephoneNumber = $args->{'telephonenumber'};
    }

#
## HERE WE NEED TO SET FLAG TO CREATE BRANCH FOR LOCALIZED VERSION OF DATA
## associatedService=localization-ru,uid=U...-user01,ou=People,dc=ibs
## associatedService=localization-uk,uid=U...-user01,ou=People,dc=ibs
## e.t.c.
#

    my ( $givenName, $sn, $cn, $o, $pwd );
    if ($self->is_ascii($args->{'givenname'})) {
      $givenName = $self->cyr2lat({ to_translate => $args->{'givenname'} });
    } else {
      $givenName = $args->{'givenname'};
    };
    $cn = $givenName;

    if ($self->is_ascii($args->{'sn'})) {
      $sn = $self->cyr2lat({ to_translate => $args->{'sn'} });
    } else {
      $sn = $args->{'sn'};
    };
    $cn .= ' ' . $sn;

    if ($self->is_ascii($args->{'org'})) {
      $o = $self->cyr2lat({ to_translate => $args->{'org'} });
    } else {
      $o = $args->{'org'};
    };

    my ($file, $jpeg);
    if (defined $args->{'avatar'}) {
      $file = $args->{'avatar'}->{'tempname'};
    } else {
      $file = $c->path_to('root','static','images','user-6-128x128.jpg');
    }
    local $/ = undef;
    open(my $fh, "<", $file) or $c->log->debug("Can not open $file: $!" );
    $jpeg = <$fh>;
    close($fh) or $c->log->debug($!);

    my $uid_prefix = sprintf("U%sC%04d-", time(), int(rand(1000)));

    my $success_message;

    if ( ! defined $args->{'password1'} or $args->{'password1'} eq '' ) {
      $pwd = { root => $self->pwdgen };
    } else {
      $pwd = { root => $self->pwdgen( { pwd => $args->{'password1'} } ) };
    }

    my $attrs_defined = [
			 uid => $uid_prefix . $args->{'login'},
			 userPassword => $pwd->{root}->{ssha},
			 mail => $args->{'login'} . '@' . $args->{'associateddomain'},
			 telephoneNumber => $telephoneNumber,
			 physicalDeliveryOfficeName => $args->{'office'},
			 givenName => $givenName,
			 sn => $sn,
			 cn => $cn,
			 uidNumber => $uidNumber,
			 gidNumber => 10012,
			 description => $descr,
			 gecos => $descr,
			 homeDirectory => '/nonexistent',
			 jpegPhoto => [ $jpeg ],
			 loginShell => '/sbin/nologin',
			 title => $args->{'title'},
			 objectClass => [ qw(top
					     posixAccount
					     inetOrgPerson
					     organizationalPerson
					     person
					     inetLocalMailRecipient
					   ) ],
			];

    $c->log->debug("attrs_defined:\n" . Dumper($attrs_defined));

    ######################################################################
    # Account ROOT Object
    ######################################################################
    my $ldif =
      $ldap_crud->add(
		      'uid=' . $uid_prefix . $args->{'login'} .
		      ',ou=People,dc=ibs',
		      $attrs_defined,
		     );
    # $c->log->debug( "\$args:\n" . Dumper($args));

    my $error_message;
    if ( $ldif ) {
      $error_message = '<li>Error during management account creation occured: ' . $ldif . '</li>';
      $c->log->debug("error during root obj creation: " . $ldif);
    } else {
      $success_message .= '<li><em>MANAGEMENT account login:</em> &laquo;<strong>' .
	$uid_prefix . $args->{'login'} . '</strong>&raquo; <em>password:</em> &laquo;<strong>' .
	  $pwd->{root}->{'clear'} . '</strong>&raquo;</li>';
    }

    my ( $basedn, $associatedDomain, $authorizedService, $authorizedService_add );

    # if it was choosen only one single service we have to be sure we
    # pass through the array and not string
    my @services;
    if ( ref( $args->{'service'} ) eq 'ARRAY' ) {
      @services = @{$args->{'service'}};
    } else {
      push @services, $args->{'service'};
    }
    foreach my $service ( @services ) {
      $ldif = 0;
      next if $service =~ /^802.1x-.*/;

      if ( ! defined $args->{'password1'} or $args->{'password1'} eq '' ) {
	$pwd = { $service => $self->pwdgen };
      } else {
	$pwd = { $service => $self->pwdgen( { pwd => $args->{'password1'} } ) };
      }

      if ( $service eq 'xmpp' && $args->{'associateddomain_prefix'} ne '' ) {
	$associatedDomain = $args->{'associateddomain_prefix'} . $args->{'associateddomain'};
      } else {
	$associatedDomain = $args->{'associateddomain'};
      }

      $basedn = 'authorizedService=' . $service . '@' . $associatedDomain .
	',uid=' . $uid_prefix . $args->{'login'} . ',ou=People,dc=ibs';

      ######################################################################
      # Account branch of ROOT Object
      ######################################################################
      $ldif =
	$ldap_crud->add(
			'authorizedService=' . $service . '@' . $associatedDomain .
			',uid=' . $uid_prefix . $args->{'login'} .
			',ou=People,dc=ibs',
			[
			 'authorizedService' => $service .
			 '@' . $args->{'associateddomain'},
			 'uid' => $uid_prefix . $args->{'login'} . '@' . $service,
			 'objectClass' => [ qw(account authorizedServiceObject) ],
			],
		       );
      # to debug on error from umi_add
      if ( $ldif ) {
	$error_message .= '<li>error during ' . uc($service) .
	  ' branch creation occured: ' . $ldif . '</li>';
	$c->log->debug("branch $service: " . $ldif);
      }

      ######################################################################
      # Leaf of the account branch of ROOT Object
      ######################################################################
      $authorizedService = [
			    authorizedService => $service . '@' . $associatedDomain,
			    associatedDomain => $associatedDomain,
			    uid => $args->{'login'} . '@' . $associatedDomain,
			    cn => $args->{'login'} . '@' . $associatedDomain,
			    givenName => $givenName,
			    sn => $sn,
			    uidNumber => $uidNumber,
			    loginshell => '/sbin/nologin',
			    objectClass => [ qw(
						 posixAccount
						 shadowAccount
						 inetOrgPerson
						 authorizedServiceObject
						 domainRelatedObject
					      )
					   ],
			    userPassword => $pwd->{$service}->{'ssha'},
			    gecos => uc($service) . ': ' . $args->{'login'} . ' @ ' .
			    $associatedDomain,
			    description => uc($service) . ': ' . $args->{'login'} . ' @ ' .
			    $associatedDomain,
                           ];

      if ( $service eq 'mail') {
	$authorizedService_add =
	  [
	   homeDirectory => '/var/mail/IMAP_HOMES/' .
	   $associatedDomain . '/' .
	   $args->{'login'} . '@' . $associatedDomain,
	   'mu-mailBox' => 'maildir:/var/mail/' .
	   $associatedDomain . '/' .
	   $args->{'login'} . '@' . $associatedDomain,
	   gidNumber => 10006,
	   objectClass => [ 'mailutilsAccount' ],
	  ];
      } elsif ( $service eq 'xmpp') {
        $authorizedService_add =
	  [
	   homeDirectory => '/nonexistent',
	   gidNumber => 10106,
	   telephonenumber => $telephoneNumber,
	  ];
      }
      # my $attrs = [ @$authorizedService, @$authorizedService_add ];
      # $c->log->debug("$service account branch obj attrs and vals:\nbasedn: $basedn\n" . Dumper($attrs));

      $ldif =
	$ldap_crud->add(
			'uid=' . $args->{'login'} . '@' . $associatedDomain .
			',' . $basedn,
			[ @$authorizedService, @$authorizedService_add ],
		       );
      # to debug on error from umi_add
      if ( $ldif ) {
	$error_message .= '<li>Error during ' . uc($service) .
	  ' account creation occured: &laquo;<strong><em>' . $ldif . 
	    '</em></strong>&raquo;, service account was not created, you need take care of it!</li>';
	$c->log->debug("$service account branch obj: " . $ldif);
      } else {
	$success_message .= '<li><em>' . uc( $service ) . ' account login:</em> &laquo;<strong>' .
	  $args->{'login'} . '@' . $associatedDomain .
	    '</strong>&raquo; <em>password:</em> &laquo;<strong>' .
	      $pwd->{$service}->{'clear'} . '</strong>&raquo;</li>';
      }
    }

    # $c->log->debug("\$self->form: " . Dumper($self));

    my $final_message;
    $final_message = '<div class="alert alert-success">' .
      '<span style="font-size: 140%" class="glyphicon glyphicon-ok-sign"></span>' .
	'&nbsp;<em>Passwords for newly created accounts are (without quotatin characters:' .
	  ' &laquo; and &raquo;):</em><ul>' . $success_message . '<ul></div>' if $success_message;

    $final_message .= '<div class="alert alert-danger">' .
      '<span style="font-size: 140%" class="icon_error-oct" aria-hidden="true"></span><ul>' .
	$error_message . '</ul></div>' if $error_message;

    $self->form->info_message( $final_message ) if $final_message;

    $ldap_crud->unbind;
    return $ldif;
}

=head1 AUTHOR

Zeus

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;

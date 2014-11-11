#-*- cperl -*-
#

package UMI;
use Moose;
use namespace::autoclean;

use Catalyst::Runtime 5.80;

# Set flags and add plugins for the application.
#
# Note that ORDERING IS IMPORTANT here as plugins are initialized in order,
# therefore you almost certainly want to keep ConfigLoader at the head of the
# list if you're using it.
#
#         -Debug: activates the debug mode for very useful log messages
#   ConfigLoader: will load the configuration from a Config::General file in the
#                 application's home directory
# Static::Simple: will serve static files from the application's root
#                 directory

use Catalyst qw/
    -Debug
    ConfigLoader
    Static::Simple

    StackTrace

    Authentication
    Authorization::Roles
    Authorization::ACL

    Session
    Session::Store::FastMmap
    Session::State::Cookie

    StatusMessage
/;

extends 'Catalyst';

our $VERSION = '0.01';

# Configure the application.
#
# Note that settings in umi.conf (or other external
# configuration file that you set up manually) take precedence
# over this when using ConfigLoader. Thus configuration
# details given here can function as a default configuration,
# with an external configuration file acting as an override for
# local deployment.

__PACKAGE__->config(
    name => 'UMI',
    # Disable deprecated behavior needed by old applications
    disable_component_resolution_regex_fallback => 1,
    enable_catalyst_header => 1, # Send X-Catalyst header
    session => { cache_size => '10m', }, # looks like value 100m helps with [error] Caught exception in engine "store_session: data too large"
    'authentication' => {
	default_realm => "ldap",
	realms => {
	    ldap => {
		credential => {
		    class => "Password",
		    password_field => "password",
		    password_type => "self_check",
		},
		store => {
		    binddn              => 'uid=bind@umi,ou=bind,ou=system,dc=umidb',
		    bindpw              => '********',
		    class               => 'LDAP',
		    ldap_server         => 'umi.foo.bar',
		    ldap_server_options => { timeout => 30 },
		    use_roles           => 1,
		    role_basedn         => "ou=group,ou=system,dc=umidb",
		    role_field          => "cn",
		    role_filter         => "(memberUid=%s)",
		    role_scope          => "sub",
		    # role_search_options => { deref => "always" },
		    role_value          => "uid",
		    # role_search_as_user => 0,
		    start_tls           => 0,
		    start_tls_options   => { verify => "none" },
		    # entry_class         => "MyApp::LDAP::Entry",
		    user_basedn         => 'ou=People,dc=umidb',
		    user_field          => "uid",
		    user_filter         => "(uid=%s)",
		    user_scope          => "one", # or "sub" for Active Directory
		    # user_search_options => { deref => "never" },
		    user_results_filter => sub { return shift->pop_entry },
		},
	    },
	},
    },
);


# Start the application
__PACKAGE__->setup();

# .-------------------------------------+--------------------------------------.
# | Path                                | Private                              |
# +-------------------------------------+--------------------------------------+
# | /                                   | /index                               |
# | /...                                | /default                             |
# | /about/                             | /about                               |
# | /accinfo/                           | /accinfo                             |
# | /auth/                              | /auth/index                          |
# | /auth/...                           | /auth/signout                        |
# | /auth/...                           | /auth/signin                         |
# | /dhcp/                              | /dhcp/index                          |
# | /dhcp_root/                         | /dhcp_root                           |
# | /gitacl/                            | /gitacl/index                        |
# | /gitacl_root/                       | /gitacl_root                         |
# | /group/                             | /group/index                         |
# | /group_root/                        | /group_root                          |
# | /ldap_organization_add/modify/      | /org/modify                          |
# | /org/                               | /org/index                           |
# | /org_root/                          | /org_root                            |
# | /searchadvanced/                    | /searchadvanced/index                |
# | /searchadvanced/proc/               | /searchadvanced/proc                 |
# | /searchby/                          | /searchby/index                      |
# | /searchby/ldif_gen/                 | /searchby/ldif_gen                   |
# | /searchby/modify/                   | /searchby/modify                     |
# | /searchby/proc/                     | /searchby/proc                       |
# | /signin/...                         | /auth/signin                         |
# | /signout/...                        | /auth/signout                        |
# | /user/                              | /user/index                          |
# | /user/modpwd/                       | /user/modpwd                         |
# | /user_prefs/                        | /user_preferences                    |
# | /user_root/                         | /user_root                           |
# '-------------------------------------+--------------------------------------'

__PACKAGE__->allow_access_if_any( "/", [ qw/wheel/ ]);

__PACKAGE__->deny_access_unless_any( "/dhcp",           [ qw/wheel admin coadmin/ ]);
__PACKAGE__->deny_access_unless_any( "/dhcp_root",      [ qw/wheel admin coadmin/ ]);
__PACKAGE__->deny_access_unless_any( "/gitacl",         [ qw/wheel admin coadmin/ ]);
__PACKAGE__->deny_access_unless_any( "/gitacl_root",    [ qw/wheel admin coadmin/ ]);
__PACKAGE__->deny_access_unless_any( "/group",          [ qw/wheel admin coadmin/ ]);
__PACKAGE__->deny_access_unless_any( "/group_root",     [ qw/wheel admin coadmin/ ]);
__PACKAGE__->deny_access_unless_any( "/org",            [ qw/wheel admin coadmin/ ]);
__PACKAGE__->deny_access_unless_any( "/org_root",       [ qw/wheel admin coadmin/ ]);
__PACKAGE__->deny_access_unless_any( "/searchadvanced", [ qw/wheel admin coadmin/ ]);
__PACKAGE__->deny_access_unless_any( "/searchby",       [ qw/wheel admin coadmin/ ]);
__PACKAGE__->deny_access_unless_any( "/user",           [ qw/wheel admin coadmin/ ]);
__PACKAGE__->allow_access_if( "/user/modpwd",
			      sub {
				my ( $c, $action ) = @_;
				if ( $c->user_exists ) {
				  die $Catalyst::Plugin::Authorization::ACL::Engine::ALLOWED;
				} else {
				  die $Catalyst::Plugin::Authorization::ACL::Engine::DENIED;
				}
			      } );


=head1 NAME

UMI - Catalyst based application

=head1 SYNOPSIS

    script/umi_server.pl

=head1 DESCRIPTION

[enter your description here]

=head1 SEE ALSO

L<UMI::Controller::Root>, L<Catalyst>

=head1 AUTHOR

Zeus Panchenko

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;

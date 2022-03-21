#-*- cperl -*-
#

package UMI;
use Moose;
use namespace::autoclean;

use Data::Printer  colored => 1;
use Data::Dumper;


use Catalyst::Runtime 5.8;

use Catalyst qw/
    -Debug
    ConfigLoader
    Static::Simple

    StackTrace

    Cache

    Authentication
    Authorization::Roles
    Authorization::ACL

    Session
    Session::Store::FastMmap
    Session::State::Cookie

    StatusMessage
/;

#     Session::Store::File


extends 'Catalyst';

our $VERSION = '0.91';

__PACKAGE__
  ->config({
	    'Plugin::Cache' => { backend => { class => "Cache::Memory", }, },
	    name            => 'UMI',
	    # Disable deprecated behavior needed by old applications
	    disable_component_resolution_regex_fallback => 1,
	    enable_catalyst_header                      => 1, # Send X-Catalyst header
	    default_view                                => "Web",

	    session => {# cookie_name => "umi_cookie",
			cookie_expires => 0,
			cookie_secure  => 0,
		        storage        => "/tmp/umi/umi-session-t$^T-p$>",
			# cache_size     => '10m', # Cache::FastMmap sec. PAGE SIZE AND KEY/VALUE LIMITS
			page_size      => '512k',
			num_pages      => '1000',
			compressor     => 'lz4',
			flash_to_stash => 1,
			# expire_time    => '1d',
			expires        => 86400, # 24 hours
			verify_address => 1,
			unlink_on_exit => 1,
			# init_file => 1, # causes need for re-login if PSGI reloaded during the form filling
		       },

	    authentication =>
	    {
	     default_realm => "ldap",
	     realms => { ldap =>
			 { credential => { class => "Password",
					   password_field => "password",
					   password_type => "self_check", },
			   store => { binddn              => 'uid=binddn,ou=system,dc=foo,dc=bar',
				      bindpw              => 'secret password',
				      class               => 'LDAP',
				      ldap_server         => 'ldap.host.org',
				      ldap_server_options => { timeout => 120,
							       async   => 1,
							       onerror => 'warn',
							       debug   => 0, },
				      use_roles           => 1,
				      role_basedn         => "ou=group,ou=system,dc=foo,dc=bar",
				      role_field          => "cn",
				      role_filter         => "(memberUid=%s)",
				      role_scope          => "sub",
				      role_value          => "uid",
				      # role_search_options => { deref => "always" },
				      # role_search_as_user => 0,
				      start_tls           => 0,
				      start_tls_options   => { verify => "none" },
				      # entry_class         => "MyApp::LDAP::Entry",
				      user_basedn         => 'ou=People,dc=foo,dc=bar',
				      user_field          => "uid",
				      user_filter         => "(uid=%s)",
				      user_scope          => "one", # or "sub" for Active Directory
				      # user_search_options => { deref => "never" },
				      # user_results_filter => sub { return shift->pop_entry },
				    },
			 },
		       },
	    },
	   
	    'View::Web' => { INCLUDE_PATH => [
					      UMI->path_to( 'root', 'src' ),
					      UMI->path_to( 'root', 'lib' )
					     ],
			     # DEBUG          => 'parser, provider, dirs, caller',
			     # DEBUG_FORMAT   => "\n" . '<!-- TT DEBUG - file: $file; L$line; text: [% $text %] -->' . "\n",
			     PRE_PROCESS    => 'config/main',
			     PRE_CHOMP      => 1,
			     POST_CHOMP     => 1,
			     # TAG_STYLE      => 'outline',
			     TRIM           => 1,
			     WRAPPER        => 'site/wrapper',
			     ERROR          => 'error.tt2',
			     TIMER          => 0,
			     EVAL_PERL      => 1,
			     ENCODING       => 'UTF-8',
			     expose_methods => [ qw{ helper_cfg } ], # provided in lib/UMI/View/Web.pm
			     render_die     => 1,
			   },
	   
	    # 'View::Download' => { # default      => 'text/plain',
	    # 			  content_type =>
	    # 			  { 'text/plain' => { outfile_ext => 'ldif',
	    # 					      module      => '+Download::Plain', },},
	    # 			},
	   });


# Start the application
__PACKAGE__->setup();

# __PACKAGE__->allow_access_if( "/", [ qw/admin/ ]);

__PACKAGE__->deny_access_unless_any( "/dhcp",                [ qw/admin coadmin/ ]);
__PACKAGE__->deny_access_unless_any( "/dhcp_root",           [ qw/admin coadmin/ ]);
__PACKAGE__->deny_access_unless_any( "/gitacl",              [ qw/admin coadmin/ ]);
__PACKAGE__->deny_access_unless_any( "/gitacl_root",         [ qw/admin coadmin/ ]);
__PACKAGE__->deny_access_unless_any( "/group",               [ qw/admin coadmin/ ]);
__PACKAGE__->deny_access_unless_any( "/group_root",          [ qw/admin coadmin/ ]);
__PACKAGE__->deny_access_unless_any( "/mikrotik",            [ qw/admin coadmin/ ]);
__PACKAGE__->deny_access_unless_any( "/mikrotikpsk",         [ qw/admin coadmin/ ]);
__PACKAGE__->deny_access_unless_any( "/org",                 [ qw/admin coadmin acl-w-organizations/ ]);
__PACKAGE__->deny_access_unless_any( "/org_root",            [ qw/admin coadmin acl-w-organizations/ ]);
__PACKAGE__->deny_access_unless_any( "/inventory",           [ qw/admin coadmin acl-w-inventory/ ]);
__PACKAGE__->deny_access_unless_any( "/nisnetgroup",         [ qw/admin/ ]);
__PACKAGE__->deny_access_unless_any( "/stat_acc",            [ qw/admin coadmin operator/ ]);
__PACKAGE__->deny_access_unless_any( "/stat_monitor",        [ qw/admin/ ]);
__PACKAGE__->deny_access_unless_any( "/sudo",                [ qw/admin/ ]);

# here we allow search to all members of admin, coadmin and operator groups, while the very permition to
# search some LDAP filter or not is controlled by Tools::is_searchable method in Controller::SearchBy::index
__PACKAGE__->deny_access_unless_any( "/searchadvanced",      [ qw/admin/ ]);
__PACKAGE__->deny_access_unless_any( "/searchby",            [ qw/admin coadmin operator/ ]);

__PACKAGE__->deny_access_unless_any( "/searchby/ldif_gen",   [ qw/admin coadmin/ ]);
__PACKAGE__->deny_access_unless_any( "/searchby/ldif_gen2f", [ qw/admin coadmin/ ]);
__PACKAGE__->deny_access_unless_any( "/servermta",           [ qw/admin coadmin operator/ ]);
__PACKAGE__->deny_access_unless_any( "/sysinfo",             [ qw/admin/ ]);
__PACKAGE__->deny_access_unless_any( "/test",                [ qw/admin/ ]);

__PACKAGE__->deny_access_unless_any( "/toolimportldif",      [ qw/admin/ ]);
__PACKAGE__->deny_access_unless_any( "/user",                [ qw/admin coadmin acl-w-people/ ]);
__PACKAGE__->deny_access_unless_any( "/userall",             [ qw/admin coadmin acl-w-people/ ]);

__PACKAGE__
  ->allow_access_if( "/user/modpwd",
		     sub {
		       my ( $c, $action ) = @_;
		       if ( $c->user_exists ) {
			 die $Catalyst::Plugin::Authorization::ACL::Engine::ALLOWED;
		       } else {
			 die $Catalyst::Plugin::Authorization::ACL::Engine::DENIED;
		       }
		     } );

__PACKAGE__->allow_access("/healthcheck");
__PACKAGE__->allow_access("/searchby/modify_userpassword");
__PACKAGE__->allow_access("/toolpwdgen");
__PACKAGE__->allow_access("/toolqr");
__PACKAGE__->allow_access("/tooltranslit");
__PACKAGE__->allow_access("/toolsshkeygen");


__PACKAGE__->acl_allow_root_internals;



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

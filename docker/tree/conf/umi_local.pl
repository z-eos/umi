# -*- mode: perl; mode: follow; -*-
#

{
    session => { cookie_name => "umi_nxc_cookie",
		 storage => "/tmp/umi/umi-session-t$^T-p$>", },
    authentication =>
    {
	realms => {
	    ldap => {
		store => { # https://metacpan.org/pod/Catalyst::Authentication::Store::LDAP
		    binddn              => 'cn=Client,dc=example,dc=org',
		    bindpw              => q{guessme},
		    class               => 'LDAP',
		    ldap_server         => 'ldap://ldap.example.org',
		    ldap_server_options => { timeout => 120,
					     async   => 1,
					     onerror => 'warn',
					     debug   => 0, },
		    use_roles           => 1,
		    role_basedn         => "ou=group,dc=example,dc=org",
		    role_field          => "cn",
		    role_filter         => "(memberUid=%s)",
		    role_scope          => "sub",
		    role_value          => "uid",
		    start_tls           => 0,
		    start_tls_options   => { },
		    entry_class         => "UMI::LDAP::Entry",
		    user_basedn         => 'ou=People,dc=example,dc=org',
		    user_field          => "uid",
		    user_filter         => "(uid=%s)",
		    user_scope          => "one",
		    user_results_filter => sub { return shift->pop_entry },
		    persist_in_session  => 'all',
		    user_search_options => { attrs => [ 'cn',
							'description',
							'gecos',
							'gidnumber',
							'givenname',
							'homedirectory',
							'l',
							'loginshell',
							'mail',
							'o',
							'objectclass',
							'physicaldeliveryofficename',
							'sn',
							'title',
							'uid',
							'uidnumber',
							'umisettingsjson',
							'userpassword', ], },
		},
	    },
	},
    },
    ldap_crud_host => 'ldap://ldap.example.org',
    # start_tls => 0 if empty (`'), look @ LDAP_CRUD->_build_ldap
    #ldap_crud_cafile => 'ca.pem',
    ldap_crud_db     => 'dc=example,dc=org',
    ldap_crud_db_log => 'cn=accesslog',
    default => {
	gidNumber => 1000,
	group => 'users',
    },
    stub => {
	group_blocked     => 'disabled',
	group_blocked_gid => 2000,
    },
    pwd => {
	alg           => 1,
	cap           => 10,
	cnt           => 1,
	len           => 24,
	len_max       => 100,
	len_min       => 4,
	lenp          => 11,
	num           => 5,
	pronounceable => 0,
	salt          => 'qweRtYui',
	gp            => { # for Crypt::GeneratePassword
	    alg           => 1,
	    cap           => 10,
	    cnt           => 1,
	    len           => 24,
	    len_max       => 100,
	    len_min       => 4,
	    lenp          => 11,
	    num           => 5,
	    pronounceable => 0,
	    salt          => 'qweRtYui',
	},
	xk            => { # for Crypt::HSXKPasswd
	    preset => {
		XKCD      => 'quiet-children-OCTOBER-today-HOPE',
		APPLEID   => '-25,favor,MANY,BEAR,53-',
		DEFAULT   => ' ~~12:settle:SUCCEED:summer:48~~',
		NTLM      => '0=mAYAN=sCART@',
		SECURITYQ => 'Wales outside full month minutes gentle?',
		WEB16     => 'tube+NICE+iron+02',
		WEB32     => '+93-took-CASE-money-AHEAD-31+',
		WIFI      => '2736_ITSELF_PARTIAL_QUICKLY_SCOTLAND_wild_people_7441!!!!!!!!!!',
	    },
	    preset_default => 'XKCD',
	    w_num          => { min => 3, max => 10 },
	    w_len          => { min => 4, max => 13 },
	    w_case         => {
		NONE       => '-none-',
		ALTERNATE  => 'alternating WORD case',
		CAPITALISE => 'Capitalise First Letter',
		INVERT     => 'cAPITALISE eVERY lETTER eXCEPT tHe fIRST',
		LOWER      => 'lower case',
		UPPER      => 'UPPER CASE',
		RANDOM     => 'EVERY word randomly CAPITALISED or NOT',
	    },
	    d_padd         => { min => '0', max => '5' },
	    s_padd         => { min => '0', max => '5',
				type         => [ qw(NONE FIXED ADAPTIVE) ],
				type_default => 'NONE', },
	    sep_alphabeth  => qw( ! @ $ % ^ & * - _ + = : | ~ ? / . ; ),
	},
    },
    debug => {
	level => 2,
	file  => '/umi/log/debug.log',
    },
    log => {
	file => '/umi/log/error.log',	
    },
}

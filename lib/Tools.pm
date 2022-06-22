# -*- mode: cperl; mode: follow; -*-
#

package Tools;

use Moose::Role;

use utf8;
use Data::Printer;
use Try::Tiny;
use Time::Piece;

use IPC::Run qw( run timeout );
use POSIX qw(strftime :sys_wait_h);
use POSIX::Run::Capture qw(:std);
use File::Path qw(make_path remove_tree);
use File::Temp qw/ tempfile tempdir :POSIX /;
use File::Which;

use List::MoreUtils;
use List::Util qw(tail);
use Scalar::Util;

use Storable;
use MIME::Base64;
use Digest::SHA;

use Crypt::X509;
use Crypt::X509::CRL;

use Crypt::HSXKPasswd;
use Crypt::GeneratePassword qw(word word3 chars);

use Net::DNS;
use Net::CIDR::Set;
use Net::SSH::Perl::Key;
use Net::LDAP::Util qw(	generalizedTime_to_time ldap_explode_dn );

use Logger;
if ( UMI->config->{authentication}->{realms}->{ldap}->{store}->{ldap_server_options}->{debug} ) {
  log_info { "LDAP debug option is set, I activate STDERR redirect." };
  use Trapper;
  tie *STDERR, "Trapper";
}


# ??? # use Scalar::Util;
# ??? # use List::Util;

=head2 a

attributes (mostly constant)

=cut

has 'a' => ( traits => ['Hash'], is => 'ro', isa => 'HashRef', builder => '_build_a', );

sub _build_a {
  my $self = shift;

  return {
	  re => {
		 ip        => '(?:(?:[0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}(?:[0-9]|[1-9][0-9]|1[0-9]{2}|2[0-5][0-9])',
		 net3b     => '(?:(?:[0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){2}',
		 net2b     => '(?:(?:[0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){1}',
		 sshpubkey => {
			       type    => qr/ssh-rsa|ssh-dss|ssh-ed25519|ecdsa-\S+/,
			       id      => "[a-zA-Z_][a-zA-Z0-9_-]+",
			       base64  => "[A-Za-z0-9+/]",
			       comment => "by umi for",
			      },
		 gpgpubkey => {
			       expire => '1y',
			       comment => 'by umi',
			       type => {
					1  => 'RSA',
					22 => 'ed25519',
				       },
			      },
		 mac       => {
			       mac48 => '(?:[[:xdigit:]]{2}([-:]))(?:[[:xdigit:]]{2}\1){4}[[:xdigit:]]{2}',
			       # https://stackoverflow.com/a/21457070
			       cisco => '(?:[[:xdigit:]]{4})(?:([\.])[[:xdigit:]]{4}){2}',
			      },
		},
	  topology => {
		       default => 8,
		       os => { windows => 30,
			       unix    => 8,
			       ubuntu  => 8,
			       macos   => 8, },
		      },
	 };
}

=head1 NAME

UMI::Tools

=head1 DESCRIPTION

auxiliary methods

=head1 METHODS

=head2 is_ascii

checks whether the argument is ASCII

returns 0 if it is and 1 if not

=cut

sub is_ascii {
  my ($self, $arg) = @_;
  if ( defined $arg && $arg ne '' && $arg !~ /^[[:ascii:]]+$/ ) {
    return 1;
  } else {
    return 0;
  }
}

=head2 is_ip

checks whether the argument is ASCII

returns 0 if it is and 1 if not

=cut

sub is_ip {
  my ($self, $arg) = @_;
  if ( defined $arg && $arg ne '' && $arg =~ /^$self->{a}->{re}->{ip}$/ ) {
    return 1;
  } else {
    return 0;
  }
}

=head2 ipam_dec2ip

decimal IP to a dotted IP converter

stolen from http://ddiguru.com/blog/25-ip-address-conversions-in-perl

=cut

sub ipam_dec2ip {
  my ($self, $arg) = @_;
  return join '.', unpack 'C4', pack 'N', $arg;
}

=head2 ipam_ip2dec

dotted IP to a decimal IP converter

stolen from http://ddiguru.com/blog/25-ip-address-conversions-in-perl

=cut

sub ipam_ip2dec {
  my ($self, $arg) = @_;
  $arg = '0.0.0.0' if ! defined $arg;
  return unpack N => pack 'C4' => split /\./ => $arg;
}

# pow: exp( log( $self->ip2dec($arg) ) / 2 )
sub ipam_msk_ip2dec {
  my ($self, $arg) = @_;
  $arg = '0.0.0.0' if ! defined $arg;
  return (unpack 'B*' => pack 'N' => $self->ipam_ip2dec($arg)) =~ tr/1/1/;
}


=head2 ipam_first_free

first available CIDR (according the desired network and netmask) from the service ip space

input data is hash

    ipspace: type ARRAYREF
             array reference to CIDRs of the service ip space (VPN pool 
             of the addresses assigned to clients, DHCP networks, e.t.c.)

    ip_used: type ARRAYREF
             array reference to CIDRs of ip addresses used already and/or 
             not to be used for some reason

    tgt_net: type STRING 
             subnet (of I<ipspace>) address in CIDR notation, the free
             address found, to be from. If not set, then the very I<ipspace>
             assumed

    req_msk: type INT
             netmask , in CIDR notation, of the requested ip space (default is 32)

First, we calculate I<free> addresses set, it is new set containing all the
addresses that are present in a I<pool> set but not I<used> yet.

Second, we calculate I<nsec> (from intersection) addresses set, it is
new set that is the intersection of a I<trgt> and I<free> sets. This is
equivalent to a logical AND between sets. It contains only the addresses
present both, in I<trgt> and I<free> sets.

Finaly, we check each of the addresses of the I<free> set in ascending
order, to find the CIDR with netmask requested, available. The first 
match is returned.

Addresses ending with 0 or 255 are ignored in case /32 address is desired.

If no match found, then 0 is returned.

=cut

sub ipam_first_free {
  my ($self, $args) = @_;
  my $arg = { ipspace => $args->{ipspace},
	      ip_used => $args->{ip_used},
	      tgt_net => $args->{tgt_net} || $args->{ipspace}->[0],
	      req_msk => $args->{req_msk} || 32, };
  # log_debug { np($arg) };
  my $pool = Net::CIDR::Set->new;
  $pool->add( $_ )
    foreach (@{ $arg->{ipspace} });

  my $used = Net::CIDR::Set->new;
  $used->add( $_ )
    foreach (@{ $arg->{ip_used} });

  my $free = $pool->diff( $used );

  my $trgt = Net::CIDR::Set->new;
  $trgt->add( $arg->{tgt_net} );

  my $nsec = $trgt->intersection( $free );

  log_debug { np( @{[ $nsec->as_array( $nsec->iterate_addresses ) ]} ) };
  foreach ( $nsec->as_array( $nsec->iterate_addresses ) ) {
    # skip network and broadcast addresses
    next if $arg->{req_msk} == 32 && $_ =~ /^.*\.[0,255]$/;
    # skip until first address belonging to the target network
    next if ! $free->contains( $_ . '/' . $arg->{req_msk} );
    return $_;
  }
  return 0;
}


=head2 utf2lat

utf8 input (cyrillic in particular) to latin1 transliteration

=cut

sub utf2lat {
  my ($self, $to_translit, $allvariants, $as_is) = @_;
  # noLingva # use utf8;
  # noLingva # use Text::Unidecode;
  # noLingva # # Catalyst provides utf8::encoded data! here we need them to
  # noLingva # # utf8::decode to make them suitable for unidecode, since it expects
  # noLingva # # utf8::decode input
  # noLingva # utf8::decode( $to_translit );
  # noLingva # my $a = unidecode( $to_translit );

  # Lingua::Translit::Tables
  # "ALA-LC RUS", "GOST 7.79 RUS", "DIN 1460 RUS"
  my $table = "GOST 7.79 RUS";

  my ($tr, $return);
  use utf8;
  use Lingua::Translit;
  if ( ! defined $allvariants ) {
    $tr = Lingua::Translit->new($table);
    $return = $tr->translit( $to_translit );
    # escape important non ascii
    $return =~ s/ĭ/j/g;
    $return =~ s/ė/e/g;
    $return =~ s/′//g;
    # remove non-alphas (like ' and `)
    $return =~ tr/a-zA-Z0-9\,\.\_\-\ \@\#\%\*\(\)\!//cds if ! defined $as_is;
  } else {
    $tr = Lingua::Translit->new('ALA-LC RUS');
    $return->{'ALA-LC RUS'} = $tr->translit( $to_translit );
    $tr = Lingua::Translit->new('GOST 7.79 RUS');
    $return->{'GOST 7.79 RUS'} = $tr->translit( $to_translit );
    $tr = Lingua::Translit->new('DIN 1460 RUS');
    $return->{'DIN 1460 RUS'} = $tr->translit( $to_translit );
    $tr = Lingua::Translit->new('ISO 9');
    $return->{'ISO 9'} = $tr->translit( $to_translit );
    $tr = Lingua::Translit->new($table);
    $return->{'UMI use ' . $table . ' with non-alphas removed'} = $tr->translit( $to_translit );
    $return->{'UMI use ' . $table . ' with non-alphas removed'} =~ s/ї/i/g;
    $return->{'UMI use ' . $table . ' with non-alphas removed'} =~ s/є/e/g;
    $return->{'UMI use ' . $table . ' with non-alphas removed'} =~ s/і/i/g;
    $return->{'UMI use ' . $table . ' with non-alphas removed'} =~ s/ī/i/g;
    $return->{'UMI use ' . $table . ' with non-alphas removed'} =~ s/′//g;
    $return->{'UMI use ' . $table . ' with non-alphas removed'} =~ tr/a-zA-Z0-9\,\.\_\-\ \@\#\%\*\(\)\!//cds;
  }
  # log_debug { np($return) };
  return $return;
}

=head2 utf2qp

utf8 input (cyrillic in particular) to Quoted Printable

on input we expect:

    1. string to QP
    2. 0 or 1 to denote whether to translit instead of QP

on return is hash 

    {
      str => result string
      type => qp or plain keyword denoting what type str is
    }

=cut

sub utf2qp {
  my ($self, $to_qp, $to_tr) = @_;
  use MIME::QuotedPrint;
  my $return;
  if ( $self->is_ascii($to_qp) && ! $to_tr ) {
    $return->{str} = encode_qp( $to_qp, '' );
    $return->{type} = 'qp';
  } elsif ( $self->is_ascii($to_qp) && $to_tr ) {
    $return->{str} = $self->utf2lat( $to_qp );
    $return->{type} = 'plain';
  } else {
    $return->{str} = $to_qp;
    $return->{type} = 'plain';
  }
  return $return;
}

=head2 msg2html

wrapper to format message to HTML code (to wrap some text (html) with panel/alert)

=cut

sub msg2html {
  my ($self, $args) = @_;
  my $arg =
    { type  => $args->{type}  || 'card',
      color => $args->{color} || 'danger',
      data  => $args->{data},
      title => '<b>Error! Just close the window and inform administrator.</b>',
    };

  $arg->{element} = { card  =>
		      { root   => sprintf("<div class=\"card text-left border border-%s\">",
					   $arg->{color}),
			header => sprintf("<div class=\"card-header text-center alert-%s\">",
					   $arg->{color}),
			body   => '<div class="card-body">', },
		      alert =>
		      { root => sprintf("<div class=\"alert alert-%s\">", $arg->{color}), },
		 },

  my $return;
  if ( $arg->{type} eq 'card' ) {
    $return = sprintf("%s%s%s</div>%s%s</div></div>",
		      $arg->{element}->{card}->{root},
		      $arg->{element}->{card}->{header},
		      $arg->{title},
		      $arg->{element}->{card}->{body},
		      $arg->{data});
  } elsif ( $arg->{type} eq 'alert') {
    $return = sprintf("%s<h4>%s</h4><hr><p>%s</p></div>",
		      $arg->{element}->{alert}->{root},
		      $arg->{title},
		      $arg->{data});
  }

  return $return;
}



sub is_int {
  my ($self, $arg) = @_;
  return $arg !~ /^\d+$/ ? 1 : 0;
}


=head2 pwdgen

http://www.openldap.org/faq/data/cache/347.html

RFC 2307 passwords (http://www.openldap.org/faq/data/cache/346.html)
generation ( {SSHA} ) to be used as userPassword value.

Prepares with Digest::SHA, password provided or autogenerated, to be
used as userPassword attribute value

Password generated (with Crypt::GeneratePassword) is a random
pronounceable word. The length of the returned word is 12 chars. It is
up to 3 numbers and special characters will occur in the password. It
is up to 4 characters will be upper case.

If no password provided, then it will be automatically generated.

        alg - SHA digest algorithms, allowed values are: 1, 224, 256, 384, 
              512, 512224, or 512256. default is 1
        pwd - password string as it provided by user
	len - autogenerated password length
	num - up to that many numbers and special characters will occur in the password
        cap - up to this many characters will be upper case
	cnt - amount of passwords generated (reserved for future feature)
	salt - salt for SSHA1 generation
	pronounceable - if set, then password will be pronounceable (CPU consuming much)


Method returns hash with cleartext and ssha coded password.

=cut


sub pwdgen {
  my ( $self, $args ) = @_;
  my $p =
    {
     pwd => $args->{pwd}           // undef,
     gp  => {
	     alg           => $args->{gp}->{alg}           // UMI->config->{pwd}->{gp}->{alg} || '1',
	     len           => $args->{gp}->{len}           // UMI->config->{pwd}->{gp}->{len},
	     num           => $args->{gp}->{num}           // UMI->config->{pwd}->{gp}->{num},
	     cap           => $args->{gp}->{cap}           // UMI->config->{pwd}->{gp}->{cap},
	     cnt           => $args->{gp}->{cnt}           // UMI->config->{pwd}->{gp}->{cnt},
	     salt          => $args->{gp}->{salt}          // UMI->config->{pwd}->{gp}->{salt},
	     pronounceable => $args->{gp}->{pronounceable} // UMI->config->{pwd}->{gp}->{pronounceable},
	    },
     xk                    => $args->{xk}                  // {
							       allow_accents             => 0,
							       case_transform            => "RANDOM",
							       num_words                 => 5,
							       padding_characters_after  => 0,
							       padding_characters_before => 0,
							       padding_digits_after      => 0,
							       padding_digits_before     => 0,
							       padding_type              => "NONE",
							       separator_character       => "-",
							       word_length_max           => 8,
							       word_length_min           => 4
							      },
     pwd_num               => $args->{pwd_num}             // 1,
     pwd_alg               => $args->{pwd_alg}             // undef,
    };

  $p->{pwd_alg} = UMI->config->{pwd}->{xk}->{preset_default}
    if ! defined $p->{pwd_alg} && ! defined $p->{pwd} && ! defined $p->{xk};
  
  $p->{gp}->{len} = UMI->config->{pwd}->{gp}->{lenp}
    if $p->{gp}->{pronounceable} && $p->{gp}->{len} > UMI->config->{pwd}->{gp}->{lenp};

  if ( defined $p->{pwd_alg} && $p->{pwd_alg} ne 'CLASSIC' ) {

    Crypt::HSXKPasswd->module_config('LOG_ERRORS', 1);
    Crypt::HSXKPasswd->module_config('DEBUG', 0);
    my $default_config = Crypt::HSXKPasswd->default_config();
    # log_debug { "DEFAULT CONFIG: \n" . np($default_config) };
    my $c = Crypt::HSXKPasswd->preset_config( $p->{pwd_alg} );
    # log_debug { 'PRESET ' . $p->{pwd_alg} . " ORIGINAL: \n" . np($c) };
    if ( defined $p->{xk} ) {
      $c->{$_} = $p->{xk}->{$_} foreach (keys %{$p->{xk}});
    }
    # log_debug { 'PRESET ' . $p->{pwd_alg} . " MODIFIED: \n" . np($c) };
    my $xk = Crypt::HSXKPasswd->new( config => $c );
    $p->{pwd}->{clear}    = $xk->password( $p->{pwd_num} );
    %{$p->{pwd}->{stats}} = $xk->stats();
    $p->{pwd}->{status}   = $xk->status();

  } elsif ((! defined $p->{pwd} || $p->{pwd} eq '') && $p->{gp}->{pronounceable} ) {

    $p->{pwd}->{clear} = word3( $p->{gp}->{len},
				$p->{gp}->{len},
				'en',
				$p->{gp}->{num},
				$p->{gp}->{cap} );

  } elsif ((! defined $p->{pwd} || $p->{pwd} eq '') && ! $p->{gp}->{pronounceable} ) {

    $p->{pwd}->{clear} = chars($p->{gp}->{len}, $p->{gp}->{len});

  }

  if ( ref($p->{pwd}) ne 'HASH' ) {
    $p->{tmp} = $p->{pwd};
    delete $p->{pwd};
    $p->{pwd}->{clear} = $p->{tmp};
  }

  my $sha = Digest::SHA->new( $p->{gp}->{alg} );
  $sha->add( $p->{pwd}->{clear}, $p->{gp}->{salt} );
  $p->{return} =
    {
     clear => $p->{pwd}->{clear},
     ssha  => sprintf('{SSHA}%s',
		      $self->pad_base64( encode_base64( $sha->digest . $p->{gp}->{salt}, '' ) ) ),
    };
  $p->{return}->{stats}  = $p->{pwd}->{stats}  if $p->{pwd}->{stats};
  $p->{return}->{status} = $p->{pwd}->{status} if $p->{pwd}->{status};

  # log_debug { np($p) };
  return $p->{return};
}

sub pad_base64 {
  my ( $self, $to_pad ) = @_;
  while (length($to_pad) % 4) {
    $to_pad .= '=';
  }
  return $to_pad;
}

=head2 keygen_ssh

ssh key generator

default key_type is RSA, default bits 2048

wrapper for ssh-keygen(1)

=cut


sub keygen_ssh {
  my ( $self, $args ) = @_;
  my $arg = { type => $args->{type} || 'RSA',
	      bits => $args->{bits} || 2048,
	      name => $args->{name} };

  my (@ssh, $res, $fh, $key_file, $kf);
  my $to_which = 'ssh-keygen';
  my $ssh_bin = which $to_which;
  if ( defined $ssh_bin ) {
    push @ssh, $ssh_bin;
  } else {
    push @{$res->{error}},  "command <code>$to_which</code> not found";
    return $res;
  }

  if ( $arg->{type} eq 'RSA' ) {
    $arg->{type} = 'rsa';
    push @ssh, '-b', $arg->{bits};
  } elsif ( $arg->{type} eq 'Ed25519' ) {
    $arg->{type} = 'ed25519';
  } elsif ( $arg->{type} eq 'ECDSA256' ) {
    $arg->{type} = 'ecdsa';
    push @ssh, '-b', 256;
  } elsif ( $arg->{type} eq 'ECDSA384' ) {
    $arg->{type} = 'ecdsa';
    push @ssh, '-b', 384;
  } elsif ( $arg->{type} eq 'ECDSA521' ) {
    $arg->{type} = 'ecdsa';
    push @ssh, '-b', 521;
  }

  (undef, $key_file) = tempfile('/tmp/.umi-ssh.XXXXXX', OPEN => 0, CLEANUP => 1);
  # my $key_file = tmpnam();
  my $date = strftime("%Y%m%d%H%M%S", localtime);

  push @ssh, '-t', $arg->{type}, '-N', '', '-f', $key_file,
    '-C', qq/$self->{a}->{re}->{sshpubkey}->{comment} $arg->{name}->{real} ( $arg->{name}->{email} ) on $date/;
  $arg->{opt} = \@ssh;
  my $obj = new POSIX::Run::Capture(argv => [ @ssh ] );
  push @{$res->{error}},  $obj->errno if ! $obj->run;
  # log_debug { np($arg) };

    push @{$res->{error}},
      sprintf('<code>%s</code> exited with code: %s
<dl class="row mt-4">
  <dt class="col-2 text-right">STDERR:</dt>
  <dd class="col-10 text-monospace"><small><pre>%s</pre></small></dd>
  <dt class="col-2 text-right">STDOUT:</dt>
  <dd class="col-10 text-monospace"><small><pre>%s</pre></small></dd>
</dl>',
	      join(' ', @{$obj->argv}),
	      WEXITSTATUS($obj->status),
	      join('', @{$obj->get_lines(SD_STDERR)}),
	      join('', @{$obj->get_lines(SD_STDOUT)}) )
      if WIFEXITED($obj->status) && WEXITSTATUS($obj->status) != 0;

  if ( WIFEXITED($obj->status) && WEXITSTATUS($obj->status) == 0 ) {

    open($fh, '<', $key_file) or die "Cannot open file $key_file: $!";
    {
      local $/;
      $arg->{key}->{pvt} = <$fh>;
    }
    close($fh) || die "Cannot close file $key_file: $!";
    unlink $key_file || die "Could not unlink $key_file: $!";;

    open($fh, '<', "$key_file.pub") or die "Cannot open file $key_file.pub: $!";
    {
      local $/;
      $arg->{key}->{pub} = <$fh>;
    }
    close($fh) || die "Cannot close file $key_file.pub: $!";
    unlink "$key_file.pub" || die "Could not unlink $key_file.pub: $!";;

    $res->{private} = $arg->{key}->{pvt};
    $res->{public}  = $arg->{key}->{pub};
    $res->{public}  =~ s/[\n\r]//;
    $res->{date}    = $date;
  }
  # log_debug { np($res) };
  # log_debug { np($arg) };
  return $res;
}

=head2 keygen_gpg

gpg key generator

default key_type is , default bits 2048

wrapper for gpg(1)

this method is supposed to work with the only one single key in keyring

=cut

sub keygen_gpg {
  my ( $self, $args ) = @_;
  my $arg = { bits   => $args->{bits}   // 2048,
	      type   => $args->{type}   // 'default',
	      import => $args->{import} // '',
	      ldap   => $args->{ldap},
	      name   => $args->{name}   // { real  => "not signed in $$",
					     email => "not signed in $$" },
	    };
  # log_debug { np($arg) };
  my $date = strftime('%Y%m%d%H%M%S', localtime);

  $ENV{GNUPGHOME} = tempdir(TEMPLATE => '/tmp/.umi-gnupg.XXXXXX', CLEANUP => 1 );

  my ($key, @gpg, $obj, $gpg_bin, $res, $fh, $tf, $z);
  my $to_which = 'gpg';
  $gpg_bin = which $to_which;
  if ( defined $gpg_bin ) {
    push @gpg, $gpg_bin, '--no-tty', '--quiet', '--yes';
  } else {
    push @{$res->{error}},  "command <code>$to_which</code> not found";
  }

  if ( $arg->{import} ne '' ) {

    if ( defined $arg->{import}->{file} ) {
      $tf = $arg->{import}->{file};
    } elsif ( defined $arg->{import}->{text} ) {
      ($fh, $tf) = tempfile( 'import.XXXXXX', DIR => $ENV{GNUPGHOME} );
      print $fh $arg->{import}->{text};
      close $fh;
    }

    # $obj = new POSIX::Run::Capture(argv    => [ 'stat', '-x', $tf ]);
    # log_debug { np($obj->errno) } if ! $obj->run;
    # $z = join('', @{$obj->get_lines(SD_STDOUT)}); log_debug { np($z) };

    $obj = new POSIX::Run::Capture(argv    => [ @gpg, '--import', $tf ]);
    push @{$res->{error}},  $obj->errno
      if ! $obj->run;

  } else {

    ($fh, $tf) = tempfile( 'batch.XXXXXX', DIR => $ENV{GNUPGHOME} );
    ### https://www.gnupg.org/documentation/manuals/gnupg-devel/Unattended-GPG-key-generation.html
    ### https://lists.gnupg.org/pipermail/gnupg-users/2017-December/059622.html

# Key-Type: default
# Key-Length: $arg->{bits}
# Subkey-Type: default

    my $batch = <<"END_MSG";
%no-protection
Key-Type: eddsa
Key-Curve: Ed25519
Key-Usage: sign
Subkey-Type: ecdh
Subkey-Curve: Curve25519
Subkey-Usage: encrypt
Name-Real: $arg->{name}->{real}
Name-Email: $arg->{name}->{email}
Name-Comment: $self->{a}->{re}->{gpgpubkey}->{comment} on $date
Expire-Date: $self->{a}->{re}->{gpgpubkey}->{expire}
END_MSG

    print $fh $batch;
    close $fh;

    $obj = new POSIX::Run::Capture(argv    => [ @gpg, '--batch', '--gen-key', $tf ] );
    push @{$res->{error}},  $obj->errno if ! $obj->run;

  }

  push @{$res->{error}},
    sprintf('<code>%s</code> exited with code: %s
<dl class="row mt-4">
  <dt class="col-2 text-right">STDERR:</dt>
  <dd class="col-10 text-monospace"><small><pre>%s</pre></small></dd>
  <dt class="col-2 text-right">STDOUT:</dt>
  <dd class="col-10 text-monospace"><small><pre>%s</pre></small></dd>
</dl>',
	    join(' ', @{$obj->argv}),
	    WEXITSTATUS($obj->status),
	    join('', @{$obj->get_lines(SD_STDERR)}),
	    join('', @{$obj->get_lines(SD_STDOUT)}) )
    if WIFEXITED($obj->status) && WEXITSTATUS($obj->status) != 0;

  if ( WIFEXITED($obj->status) && WEXITSTATUS($obj->status) == 0 ) {
    $obj = new POSIX::Run::Capture(argv    => [ @gpg, '--fingerprint' ]);
    push @{$res->{error}},  $obj->errno if ! $obj->run;
    $arg->{fingerprint} = $obj->get_lines(SD_STDOUT)->[3];
    $arg->{fingerprint} =~ tr/ \n//ds;
    # log_debug { np($arg->{fingerprint}) };
  }

  if ( WIFEXITED($obj->status) && WEXITSTATUS($obj->status) == 0 ) {
    $obj = new POSIX::Run::Capture(argv => [ @gpg, '--armor', '--export', $arg->{fingerprint} ]);
    push @{$res->{error}},  $obj->errno if ! $obj->run;
    $arg->{key}->{pub} = join '', @{$obj->get_lines(SD_STDOUT)};
    $res->{public}   = $arg->{key}->{pub};
  }

  if ( WIFEXITED($obj->status) && WEXITSTATUS($obj->status) == 0 ) {
    if ( $arg->{import} eq '' ) {
      $obj = new POSIX::Run::Capture(argv => [ @gpg, '--armor', '--export-secret-key', $arg->{fingerprint} ]);
      push @{$res->{error}},  $obj->errno if ! $obj->run;
      $arg->{key}->{pvt} = join '', @{$obj->get_lines(SD_STDOUT)};
      $res->{private} = $arg->{key}->{pvt};
    }
  }

  if ( WIFEXITED($obj->status) && WEXITSTATUS($obj->status) == 0 ) {
    $obj = new POSIX::Run::Capture(argv   => [ @gpg, '--list-keys', $arg->{fingerprint} ] );
    push @{$res->{error}},  $obj->errno if ! $obj->run;
    $arg->{key}->{lst}->{hr} = join '', @{$obj->get_lines(SD_STDOUT)};
    $res->{list_key} = $arg->{key}->{lst};
  }

    ### gpg2 --keyserver 'ldap://192.168.137.1/ou=Keys,ou=PGP,dc=umidb????bindname=uid=umi-admin%2Cou=People%2Cdc=umidb,password=testtest' --send-keys 79F6E0C65DF4EC16
  if ( WIFEXITED($obj->status) && WEXITSTATUS($obj->status) == 0 && defined $arg->{ldap} ) {
    $arg->{ldap}->{bindname} =~ s/,/%2C/g;
    $obj = new POSIX::Run::Capture(argv   => [ @gpg,
					       '--keyserver',
					       sprintf( 'ldap://%s:389/%s????bindname=%s,password=%s',
						        $arg->{ldap}->{server},
						        $arg->{ldap}->{base},
						        $arg->{ldap}->{bindname},
						        $arg->{ldap}->{password} ),
					       '--send-keys',
					       $arg->{fingerprint} ] );
    push @{$res->{error}},  $obj->errno if ! $obj->run;
    push @{$res->{error}},
      sprintf('<code class="kludge-minus-700px">%s</code>
<dl class="row mt-4">
  <dt class="col-2 text-right">STDERR:</dt>
  <dd class="col-10 text-monospace"><small><pre class="kludge-minus-700px">%s</pre></small></dd>
  <dt class="col-2 text-right">STDOUT:</dt>
  <dd class="col-10 text-monospace kludge-minus-700px"><small><pre>%s</pre></small></dd>
  <dt class="col-2 text-right">WIFEXITED:</dt>
  <dd class="col-10 text-monospace">%s</dd>
  <dt class="col-2 text-right">WIFSIGNALED:</dt>
  <dd class="col-10 text-monospace">%s</dd>
</dl>',
	      join(' ', @{$obj->argv}),
	      join('', @{$obj->get_lines(SD_STDERR)}),
	      join('', @{$obj->get_lines(SD_STDOUT)}),
	      WIFEXITED($obj->status)   ? WEXITSTATUS($obj->status) : '',
	      WIFSIGNALED($obj->status) ? WTERMSIG($obj->status)    : '',
	     )
      if WIFEXITED($obj->status) && WEXITSTATUS($obj->status) != 0;

  } elsif ( WIFEXITED($obj->status) && WEXITSTATUS($obj->status) == 0 && ! defined $arg->{ldap_crud} ) {
    # https://gnupg.org/documentation/manuals/gnupg/GPG-Input-and-Output.html#GPG-Input-and-Output
    # https://github.com/CSNW/gnupg/blob/master/doc/DETAILS
    # $arg->{key}->{lst}->{colons} indexes are -2 from described in DETAILS file
    $obj = new POSIX::Run::Capture(argv => [ @gpg, '--with-colons', '--list-keys', $arg->{fingerprint} ]);
    push @{$res->{error}},  $obj->errno if ! $obj->run;

    %{$arg->{key}->{lst}->{colons}} =
      map { (split(/:/, $_))[0] => [tail(-1, @{[split(/:/, $_)]})] } @{$obj->get_lines(SD_STDOUT)};

    $arg->{key}->{snd} = {
			  objectClass => [ 'pgpKeyInfo' ],
			  pgpSignerID => $arg->{key}->{lst}->{colons}->{pub}->[3],
			  pgpCertID   => $arg->{key}->{lst}->{colons}->{pub}->[3],
			  pgpKeyID    => substr($arg->{key}->{lst}->{colons}->{pub}->[3], 8),
			  pgpKeySize  => sprintf("%05s", $arg->{key}->{lst}->{colons}->{pub}->[1]),
			  pgpKeyType  => $arg->{key}->{lst}->{colons}->{pub}->[2],
			  pgpRevoked  => 0,
			  pgpDisabled => 0,
			  pgpKey      => $arg->{key}->{pub},
			  pgpUserID   => $arg->{key}->{lst}->{colons}->{uid}->[8],
			  pgpSubKeyID => $arg->{key}->{lst}->{colons}->{sub}->[3],
			  pgpKeyCreateTime => strftime('%Y%m%d%H%M%SZ', localtime($arg->{key}->{lst}->{colons}->{pub}->[4])),
			  pgpKeyExpireTime => strftime('%Y%m%d%H%M%SZ', localtime($arg->{key}->{lst}->{colons}->{pub}->[5])),
			 };

    $res->{send_key} = $arg->{key}->{snd};
  }

  File::Temp::cleanup();

  # log_debug { np($res->{error}) };
  return $res;
}

=head2 file2var

reading file to a string or array

TODO: error handling

=cut

sub file2var {
  my ( $self, $file, $final_message, $return_as_arr ) = @_;
  my ( @file_in_arr,$file_in_str, $fh );

  open($fh, '<', "$file") || die "Cannot open file $file: $!";
  {
    local $/;
    if ( defined $return_as_arr && $return_as_arr == 1 ) {
      while (<$fh>) {
	chomp;
	push @file_in_arr, $_;
      }
    } else {
      local $/ = undef;
      $file_in_str = <$fh>;
    }
  }
  close($fh) || die "Cannot close file $file: $!";

  return defined $return_as_arr && $return_as_arr == 1 ? \@file_in_arr : $file_in_str;
}


=head2 cert_info

data taken, generally, from

    openssl x509 -in target.crt -text -noout
    openssl crl  -inform der -in crl.der -text -noout

=cut


sub cert_info {
  my ( $self, $args ) = @_;
  my $arg = {
	     attr => $args->{attr} || 'userCertificate;binary',
	     cert => $args->{cert},
	     ts => defined $args->{ts} && $args->{ts} ? $args->{ts} : "%a %b %e %H:%M:%S %Y",
	    };

  my ( $cert, $key, $hex, $return );
  if ( $arg->{attr} eq 'userCertificate;binary' ||
       $arg->{attr} eq 'cACertificate;binary' ) {
    $cert = Crypt::X509->new( cert => join('', $arg->{cert}) );
    if ( $cert->error ) {
      return { 'error' => sprintf('Error on parsing Certificate: %s', $cert->error) };
    } else {
      return  {
	       'Subject' => join(',',@{$cert->Subject}),
	       'CN' => $cert->subject_cn,
	       'Issuer' => join(',',@{$cert->Issuer}),
	       'S/N' => $cert->serial,
	       'Not Before' => strftime ($arg->{ts}, localtime($cert->not_before)),
	       'Not  After' => strftime ($arg->{ts}, localtime( $cert->not_after)),
	       'cert' => $arg->{cert},
	       'error' => undef,
	      };
    }
  } elsif ( $arg->{attr} eq 'certificateRevocationList;binary' ) {
    $cert = Crypt::X509::CRL->new( crl => $arg->{cert} );
    if ( $cert->error ) {
      return { 'error' => sprintf('Error on parsing CertificateRevocationList: %s', $cert->error) };
    } else {
      $arg->{sn} = $cert->revocation_list;
      foreach $key (sort (keys %{$arg->{sn}} )) {
	$hex = sprintf("%X", $key);
	$hex = length($hex) % 2 ? '0' . $hex : $hex;
	$arg->{sn}->{$key}->{sn_hex} = $hex;
	$arg->{sn}->{$key}->{revocationDate} =
	  strftime ($arg->{ts}, localtime($arg->{sn}->{$key}->{revocationDate}));
      }
      return {
	      'Issuer' => join(',',@{$cert->Issuer}),
	      'AuthIssuer' => join(',',@{$cert->authorityCertIssuer}),
	      'RevokedCertificates' => $arg->{sn},
	      'Update This' => strftime ($arg->{ts}, localtime($cert->this_update)),
	      'Update Next' => strftime ($arg->{ts}, localtime( $cert->next_update)),
	      'error' => undef,
	      'cert' => $arg->{cert},
	     };
    }
  } else {
    return { 'error' => sprintf('Not known to us certificate type'), };
  }

}



=head2 fnorm

HTML::FormHandler field value normalizator. Input is casted to ARRAY if it is
SCALAR.

=cut


sub fnorm {
  my ( $self, $field ) = @_;
  my $field_arr;
  if ( ref( $field ) ne 'ARRAY' ) {
    push @{$field_arr}, $field;
    return $field_arr;
  } else {
    return $field;
  }
}

=head2 hash_denullify

deletes all attributes with empty string values from the given hash

=cut

sub hash_denullify {
  my ($self, $hash) = @_;
  log_debug { np($hash) };
  while (my ($key, $val) = each %{$hash}) {
    delete $hash->{$key} if $hash->{$key} eq '';
  }
  log_debug { np($hash) };
  return;
}

=head2 macnorm

MAC address field value normalizator.

The standard (IEEE 802) format for printing MAC-48 addresses in
human-friendly form is six groups of two hexadecimal digits, separated
by hyphens (-) or colons (:), in transmission order
(e.g. 01-23-45-67-89-ab or 01:23:45:67:89:ab ) is casted to the twelve
hexadecimal digits without delimiter. 


For the examples above it will look: 0123456789ab

=over

=item mac

MAC address to process

=item dlm

I<delimiter>, if defined (allowed characters: `-` and `:`), then returned mac is normalyzed to human-friendly form as six groups of two hexadecimal digits, separated by this I<delimiter>

=back

=cut


sub macnorm {
  my ( $self, $args ) = @_;
  my $arg = {
	     mac => $args->{mac},
	     dlm => $args->{dlm} || '',
	    };

  my $re1 = $self->{a}->{re}->{mac}->{mac48};
  my $re2 = $self->{a}->{re}->{mac}->{cisco};
  if ( ($arg->{mac} =~ /^$re1$/ || $arg->{mac} =~ /^$re2$/) &&
       ($arg->{dlm} eq '' || $arg->{dlm} eq ':' || $arg->{dlm} eq '-') ) {
    my $sep = $1 eq '.' ? '\.' : $1;

    my @mac_arr = split(/$sep/, $arg->{mac});

    @mac_arr = map { substr($_, 0, 2), substr($_, 2) } @mac_arr
      if scalar(@mac_arr) == 3;

    log_debug { np(@mac_arr) };
    return lc( join( $arg->{dlm}, @mac_arr ) );
  } else {
    return 0;
  }
}

=head2 sshpubkey_parse

SSH2 pub key validator

=cut

sub sshpubkey_parse {
  my ($self, $pub_key, $key_hash) = @_;
  my $in = $$pub_key;

  $key_hash->{original} = $in;
  if ( ! $self->sshpubkey_parse_options(\$in, $key_hash) ||
       ( ! defined $key_hash->{type} && ! $self->sshpubkey_parse_type(\$in, $key_hash) ) ||
       ! $self->sshpubkey_parse_body(\$in, $key_hash) ) {
    return 0;
  }
  $key_hash->{comment} = $in;
  return 1;
}

=head2 sshpubkey_parse_options

SSH2 pub key options validator

=cut

sub sshpubkey_parse_options {
  my ($self, $pub_key, $key_hash) = @_;
  my $in = $$pub_key;
  $key_hash->{options} = {};
  my $id = $self->a->{re}->{sshpubkey}->{id}; # "[a-zA-Z_][a-zA-Z0-9_-]+";

  while (1) {
    my $value;
    if ($in =~ /^(?<id>${id})(?<delim>(?:,|\s+))(?<tail>.*)/ ) {
      # boolean option (without `=' sign)
      $in = $+{tail};
      my $is_type = $+{id};
      if ( $is_type =~ /(?<type>$self->{a}->{re}->{sshpubkey}->{type})/ ) {
	$key_hash->{type} = $+{type};
	$value = 'NO_OPTIONS'; # key contains no option, starts just with key type
      } else {
	$value = 1;
      }
    } elsif ($in =~ /^(?<id>${id})=(?<val>[^",]+)(?<delim>(?:,|\s+))(?<tail>.*)/) {
      # option with `=' sign
      $in = $+{tail};
      $value = $+{val};
    } elsif ($in =~ /^(?<id>${id})="(?<val>[^\\"]*)"(?<delim>(?:,|\s+))(?<tail>.*)/) {
      # option with `=' sign and `"' after it
      $in = $+{tail};
      $value = $+{val};
    } elsif ($in =~ /^(?<id>${id})="(?<val>[^\\"]*)\\(?<esc>.)(?<tail>.*)/) {
      # option with `=' sign and escapes after it
      $in = $+{tail};
      $value = $+{val} . $+{esc};
      while (1) {
	if ($in =~ /^(?<part>[^\\"]*)\\(?<esc>.)(?<tail>.*)/) {
	  $value .= $+{part} . $+{esc};
	  $in = $+{tail};
	} elsif ($in =~ /^(?<part>[^\\"]*)"(?<delim>(?:,|\s+))(?<tail>.*)/) {
	  $in = $+{tail};
	  $value .= $+{part};
	  last;
	}
      }
    } else {
      $key_hash->{error} = "Pasing problem, incorrect SSH2 option/s found, failed at: \"... $in\"";
      return 0;
    }
    if ( $+{id} eq 'environment' ) {
      my ( $one, $two ) = split /=/, $value;
      $key_hash->{options}->{environment}->{$one} = $two;
    } elsif ( $+{id} eq 'permitopen' ) {
      my ( $one, $two ) = split /:/, $value;
      $key_hash->{options}->{permitopen}->{$one} = $two;
    } elsif ( $+{id} eq 'from' ) {
      push @{$key_hash->{options}->{from}}, split /,/,$value;
    } else {
      $key_hash->{options}->{$+{id}} = $value if $value ne 'NO_OPTIONS';
    }
    last if $+{delim} ne ",";
  }
  $$pub_key = $in;
  return 1;
}

=head2 sshpubkey_parse_type

SSH2 pub key type validator

=cut

sub sshpubkey_parse_type {
  my ($self, $pub_key, $key_hash) = @_;
  my $in = $$pub_key;

  if ( $in !~ /^.*\s*(?<type>$self->{a}->{re}->{sshpubkey}->{type})\s(?<tail>.*)/ ) {
    $key_hash->{error} = "Parsing problem, no valid SSH2 key type found!";
    return 0;
  } else {
    $in = $+{tail};
    $key_hash->{type} = $+{type};
  }
  $$pub_key = $in;
  return 1;
}

=head2 sshpubkey_parse_body

SSH2 pub key body validator

=cut

sub sshpubkey_parse_body {
  my ($self, $pub_key, $key_hash) = @_;
  my $in = $$pub_key;

  if ( $in !~ /^(?<key>$self->{a}->{re}->{sshpubkey}->{base64}+)\s*(?<tail>.*)/ ) {
    $key_hash->{error} = "Parsing problem, no valid SSH2 key body found!";
    return 0;
  } else {
    $in = $+{tail};
    # !!! STUB !!! here we need base64 validation !!! STUB !!!
    my $x = $+{key};
    my $y = decode_base64($x);
    if ( $y ne '' && length($x) > 100 && $y =~ $self->{a}->{re}->{sshpubkey}->{type} ) {
      $key_hash->{key} = $x;
    } else {
      $key_hash->{error} = "Parsing problem, key body is not base64!";
      return 0;
    }
  }
  $$pub_key = $in;
  return 1;
}

=head2 qrcode

QR Code generator

result image is interlaced and transparent (white color) background

=cut

sub qrcode {
  my ($self, $args) = @_;
  my $arg = {
	     txt => $args->{txt},
	     ecc => $args->{ecc} || 'M',
	     mod => $args->{mod} || 1,
	    };

  utf8::encode($arg->{txt}); # without it non latin in QR is broken

  # log_debug { np($arg->{txt}) };
  $arg->{ops} = {
		 Ecc        => $arg->{ecc},
		 ModuleSize => $arg->{mod},
		};
  if ( defined $args->{ver} ) {
    $arg->{ver}            = $args->{ver};
    $arg->{ops}->{Version} = $arg->{ver};
  }

  use GD::Barcode::QRcode;
  use MIME::Base64;

  try {
    $arg->{gd} = GD::Barcode::QRcode->new( "$arg->{txt}", $arg->{ops} )->plot();
    $arg->{white} = $arg->{gd}->colorClosest(255,255,255);
    $arg->{gd}->transparent($arg->{white});
    $arg->{gd}->interlaced('true');
    $arg->{ret}->{qr} = encode_base64($arg->{gd}->png);
  } catch { $arg->{ret}->{error} = $_ . ' (in general max size is about 1660 characters of Latin1 codepage)'; };

  return $arg->{ret};
}


=head2 lrtrim

remove white space/s from both ends of each string

if string is "delim" delimited, then white space/s could be removed
before and after the delimiter (in most cases str is DN or RDN)

=head3 EXAMPLE

    in: `  uid=abc ,  ou=ABC  ,dc=DDD '
    ou: `uid=abc,ou=ABC,dc=DDD'

    in: `  abcABCDDD '
    ou: `abcABCDDD'

=cut

sub lrtrim {
  my ($self, $args) = @_;
  my $arg = { str => $args->{str},
	      delim => $args->{delim} || ',',
	      tosplit => $args->{tosplit} || 0, };
  if ( $arg->{tosplit} ) {
    my @ar = split(/$arg->{delim}/, $arg->{str});
    $_ =~ s/^\s+|\s+$//g foreach @ar;
    $arg->{res} = join( $arg->{delim}, @ar);
  } else {
    $arg->{str} =~ s/^\s+|\s+$//g;
    $arg->{res} = $arg->{str};
  }
  return $arg->{res};
}


=head2 file_is

Very simple and dumb, file type detector. It detects output of these utilities:

    dmidecode(8)
    lspci(8) on Linux
    pciconf(8) on BSD
    smartctl(8)

=cut

sub file_is {
  my ($self, $args) = @_;
  my $arg = { file => $args->{file}, };
  my ( $return, $fh );

  try {
    open $fh, "<", $arg->{file};
  } catch {
    return $return = { error => "Cannot open file: $arg->{file} for reading: $_", };
  };

  my $first_line = <$fh>;

  try {
    close $fh;
  } catch {
    return $return = { error => "close failed: $_" };
  };

  if ( $first_line =~ /.*dmidecode.*/ ) {
    $return->{success} = 'dmidecode';
  } elsif ( $first_line =~ /..:..\.. .*/ ) {
    $return->{success}  = 'lspci';
  } elsif ( $first_line =~ /.*@.*:.*:.*:.*: .*/ ) {
    $return->{success} = 'pciconf';
  } elsif ( $first_line =~ /^smartctl.*/ ) {
    $return->{success} = 'smartctl';
  } else {
    $return->{warning} = undef;
  }

  return $return;
}


=head2 file_dmi

reading input file ( output of dmidecode(8) ) and extracting DMI data

return hash is:

	{
	 error => [ 'Error message if any', ... ],
	 success => {
	     cpu => [ [0] {...}, ],
	      mb => [ [0] {...}, ],
	     ram => [ [0] {...},
	              [1] {...},
	              [n] {...}, ],
	 warning => [ 'Warning message if any', ... ],
	}

=cut

sub file_dmi {
  my ($self, $args) = @_;
  my $arg = {
	     file => $args->{file},
	     compart => $args->{compart} || 'all', # mb, cpu, ram, all
	     types => { 0 =>  { name => 'BIOS',
				ldap_attrs => { 'hwBiosReleaseDate' => 'Release Date',
						'hwBiosRevision' => 'BIOS Revision',
						'hwBiosVendor' => 'Vendor',
						'hwBiosVersion' => 'Version', }, },
			1 =>  { name => 'System',
				ldap_attrs => { hwFamily => 'Family',
						hwManufacturer => 'Manufacturer',
						'hwProductName' => 'Product Name',
						'hwSerialNumber' => 'Serial Number',
						hwUuid => 'UUID',
						hwVersion => 'Version', }, },
			2 =>  { name => 'Baseboard',
				ldap_attrs => {
					       hwManufacturer => 'Manufacturer',
					       hwProductName => 'Product Name',
					       hwSerialNumber => 'Serial Number',
					       hwVersion => 'Version', }, },
			3 =>  { name => 'Chassis', ldap_attrs => [ qw() ], },
			4 =>  { name => 'Processor',
				ldap_attrs => { hwFamily => 'Family',
						hwManufacturer => 'Manufacturer',
						hwId => 'ID',
						hwSpeedCpu => 'Max Speed',
						hwPartNumber => 'Part Number',
						hwSerialNumber => 'Serial Number',
						hwSignature => 'Signature',
						hwVersion => 'Version', }, },
			5 =>  { name => 'Memory Controller', ldap_attrs => [ qw() ], },
			6 =>  { name => 'Memory Module', ldap_attrs => [ qw() ], },
			7 =>  { name => 'Cache', ldap_attrs => [ qw() ], },
			8 =>  { name => 'Port Connector', ldap_attrs => [ qw() ], },
			9 =>  { name => 'System Slots', ldap_attrs => [ qw() ], },
			10 => { name => 'On Board Devices', ldap_attrs => [ qw() ], },
			11 => { name => 'OEM Strings', ldap_attrs => [ qw() ], },
			12 => { name => 'System Configuration Options', ldap_attrs => [ qw() ], },
			13 => { name => 'BIOS Language', ldap_attrs => [ qw() ], },
			14 => { name => 'Group Associations', ldap_attrs => [ qw() ], },
			15 => { name => 'System Event Log', ldap_attrs => [ qw() ], },
			16 => { name => 'Physical Memory Array', ldap_attrs => [ qw() ], },
			17 => { name => 'Memory Device',
				ldap_attrs => { hwManufacturer => 'Manufacturer',
						hwPartNumber => 'Part Number',
						hwSerialNumber => 'Serial Number',
						hwSizeRam => 'Size',
						hwSpeedRam => 'Speed',
						hwBankLocator => 'Bank Locator',
						hwLocator => 'Locator',
						hwFormFactor => 'Form Factor', }, },
			18 => { name => '32-bit Memory Error', ldap_attrs => [ qw() ], },
			19 => { name => 'Memory Array Mapped Address', ldap_attrs => [ qw() ], },
			20 => { name => 'Memory Device Mapped Address', ldap_attrs => [ qw() ], },
			21 => { name => 'Built-in Pointing Device', ldap_attrs => [ qw() ], },
			22 => { name => 'Portable Battery', ldap_attrs => [ qw() ], },
			23 => { name => 'System Reset', ldap_attrs => [ qw() ], },
			24 => { name => 'Hardware Security', ldap_attrs => [ qw() ], },
			25 => { name => 'System Power Controls', ldap_attrs => [ qw() ], },
			26 => { name => 'Voltage Probe', ldap_attrs => [ qw() ], },
			27 => { name => 'Cooling Device', ldap_attrs => [ qw() ], },
			28 => { name => 'Temperature Probe', ldap_attrs => [ qw() ], },
			29 => { name => 'Electrical Current Probe', ldap_attrs => [ qw() ], },
			30 => { name => 'Out-of-band Remote Access', ldap_attrs => [ qw() ], },
			31 => { name => 'Boot Integrity Services', ldap_attrs => [ qw() ], },
			32 => { name => 'System Boot', ldap_attrs => [ qw() ], },
			33 => { name => '64-bit Memory Error', ldap_attrs => [ qw() ], },
			34 => { name => 'Management Device', ldap_attrs => [ qw() ], },
			35 => { name => 'Management Device Component', ldap_attrs => [ qw() ], },
			36 => { name => 'Management Device Threshold Data', ldap_attrs => [ qw() ], },
			37 => { name => 'Memory Channel', ldap_attrs => [ qw() ], },
			38 => { name => 'IPMI Device', ldap_attrs => [ qw() ], },
			39 => { name => 'Power Supply', ldap_attrs => [ qw() ], },
			40 => { name => 'Additional Information', ldap_attrs => [ qw() ], },
			41 => { name => 'Onboard Devices Extended Information', ldap_attrs => [ qw() ], },
			42 => { name => 'Management Controller Host Interface',} }
	    };
  my ( $file_is, $handle_x_type, $dmi, $fh, $return );

  $file_is = $self->file_is({file => $arg->{file}});
  return $return = { error => [ $file_is->{error} ] } if defined $file_is->{error};
  return $return = { error => [ 'File uploaded is not dmidecode output file!' ] }
    if defined $file_is->{success} && $file_is->{success} ne 'dmidecode';
  
  try {
    open( $fh, "<", $arg->{file});
  } catch {
    return $return = { error => [ "Cannot open file: $arg->{file} for reading: $_", ] };
  };

  my ( $query, $handle, $key, $val, $i, $j, $k, $l, $m,);
  $j = 0;
  while (<$fh>) {
    $return->{file} .= $_;
    next if $. < 5;
    $_ =~ s/^\s+|\n+$//g;
    next if $_ eq '';

    if ( $_ =~ /^Handle/ ) {
      $handle = (split(/ /, (split(/,/, $_))[0]))[1];
      $dmi->{$handle}->{_handle} = $_;
      @{$dmi->{$handle}->{_type_arr}} = split(/,/, substr($_, 24, -6));
      foreach $m (@{$dmi->{$handle}->{_type_arr}}) {
	$m =~ s/^\s+//;
	$dmi->{$handle}->{_type}->{$m} = $arg->{types}->{$m}->{name};
	push @{$handle_x_type->{$m}}, $handle;
      }
      delete $dmi->{$handle}->{_type_arr};
      $j = 0;
    } elsif ( ! $j ) {
      $dmi->{$handle}->{_info} = $_;
      $j++;
    } else {
      ( $key, $val ) = split(/:/, $_);
      $val = '' if ! defined $val;
      $key =~ s/^\s+//g;
      $val =~ s/^\s+//g;
      $dmi->{$handle}->{ $dmi->{$handle}->{_info} }->{$key} = $val;
    }
  }

  try {
    close $fh;
  } catch {
    return $return = { error => "Cannot close file: $arg->{file} error: $_" };
  };
  undef $j;

# LDIF for MB
# data from DMI TYPE 2 will overwrite corresponding data of DMI TYPE 1
  $i = { mb0 => [0, 1, 2], cpu => [4], ram => [17], };
  # comparts related dmidecode sections
  foreach $k ( keys %{$i} ) {
    # each "class" of comparts
    foreach $query ( @{$i->{$k}} ) {
      # each compart
      foreach $handle ( @{$handle_x_type->{$query}} ) {
	$j++;
	
	# here $dmi->{$handle}->{$dmi->{$handle}->{_info}}->{...} are the data from the
	# consequent dmidecode file section (ram, cpu, mb, e.t.c., mapped in $arg->{types} and
	# $i above)
	
	# skip all absent RAM modules (in dmidecode output sloths of them are still present)
	next if $k eq 'ram' &&
	  $dmi->{$handle}->{$dmi->{$handle}->{_info}}->{Size} eq 'No Module Installed';

	while (($key, $val) = each %{$arg->{types}->{$query}->{ldap_attrs}} ) {
	  next if ! defined $dmi->{$handle}->{$dmi->{$handle}->{_info}}->{$val};
	  # here $dmi->{meta} is intermediate hash to accumulate all current compart data
	  next if defined $dmi->{meta}->{$key} &&
	    ( $dmi->{meta}->{$key} eq $dmi->{$handle}->{$dmi->{$handle}->{_info}}->{$val} ||
	      $dmi->{$handle}->{$dmi->{$handle}->{_info}}->{$val} eq 'To Be Filled By O.E.M.' );

	  $dmi->{meta}->{$key} = $dmi->{$handle}->{$dmi->{$handle}->{_info}}->{$val};
	}
	push @{$dmi->{compart}->{$k}}, $dmi->{meta} if defined $dmi->{meta};
	delete $dmi->{meta} if defined $dmi->{meta};
      }
    }
  }

  foreach ( @{$dmi->{compart}->{mb0}} ) {
    while ( ( $key,$val ) = each( %{$_} ) ) {
      $dmi->{compart}->{mb}->[0]->{$key} = $val;
    }
  }
  delete $dmi->{compart}->{mb0};
  $return->{success} = $dmi->{compart};
  return $return;
}


=head2 file_smart

reading input file ( output of `smartctl -i' ) and extracting
S.M.A.R.T. data

in case there are more then one disk, input file have to be
concatenation of all disks data like:
     smartctl -i /dev/ada0 >> smart.txt
     smartctl -i /dev/ada1 >> smart.txt
     e.t.c.

return hash is:

	{
	 error => [ 'Error message if any', ... ],
	 success => {
	    disk => [ [0] {...},
	              [1] {...},
	              [n] {...}, ],
	 warning => [ 'Warning message if any', ... ],
	}

=cut

sub file_smart {
  my ($self, $args) = @_;
  my $arg = {
	     file => $args->{file},
	     file_type => 'smartctl',
	     attrs => {
		       'Model Family' => 'hwManufacturer',
		       'Device Model' => 'hwModel',
		       'Serial Number' => 'hwSerialNumber',
		       'LU WWN Device Id' => 'hwId',
		       'Firmware Version' => 'hwFirmware',
		       'User Capacity' => 'hwSize',
		       'Rotation Rate' => 'hwTypeDisk',
		       # still not used => 'Sector Size',
		       # still not used => 'ATA Version is',
		       # still not used => 'SATA Version is',
		      },
	    };
  my ( $file_is, $smart, $fh, $return );

  $file_is = $self->file_is({file => $arg->{file}});
  return $return = { error => [ $file_is->{error} ] } if defined $file_is->{error};
  return $return = { error => [ 'File uploaded is not $arg->{file_type} output file!' ] }
    if defined $file_is->{success} && $file_is->{success} ne $arg->{file_type};

  try {
    open( $fh, "<", $arg->{file});
  } catch {
    return $return = { error => [ "Cannot open file: $arg->{file} for reading: $_", ] };
  };

  my ( $start, $val, $i, $l, $r );
  $start = 0;
  $i = -1;
  while (<$fh>) {
    if ( $_ =~ /^=== START OF INFORMATION SECTION ===/ ) {
      $start = 1;
      $smart->{disk}->[$i]->{$arg->{attrs}->{hwTypeDisk}} = 'HDD'
	if defined $arg->{tmp} && ! $arg->{tmp}->{hwTypeDisk};
      $i++;
      delete $arg->{tmp};
    }
    next if ! $start;
    $_ =~ s/^\s+|\n+$//g;
    ( $l, $r ) = split(/:/, $_);
    $l =~ s/^\s+|\n+$//g;
    $r =~ s/^\s+|\n+$//g;

    if ( $l eq 'Rotation Rate' &&
	 $r eq 'Solid State Device' ) {
      $val = 'SSD';
    } elsif ( $l eq 'Rotation Rate' &&
	      $r =~ /.*rpm/ ) {
      $val = 'HDD';
    } else {
      $val = $r;
    }
    $smart->{disk}->[$i]->{$arg->{attrs}->{$l}} = $val
      if $arg->{attrs}->{$l};
    $start = 0 if $_ eq '';
  }
  try {
    close $fh;
  } catch {
    return $return = { error => "Cannot close file: $arg->{file} error: $_" };
  };
  $return->{success} = $smart;
  return $return;
}


=head2 may_i

replies a question: "may I do this?"

it checks the match of the search base DN and filter provided against user
roles and user dn

user role name is expected to be constructed as `acl-<r/w>-KEYWORD>
where KEYWORD is the pattern to match against the given search DN and filter

- if KEYWORD for any of user roles matches the search filter or base DN,
the check is cosidered successfull

- if user dn matches search base DN, the check is considered successfull

return 1 if search is allowed (match) and 0 if not

input parameters are

    base_dn - base DN for check
    filter  - filter for check
    skip - pattern to substract from each of the roles of the user
    user => $c->user ( which is Catalyst::Authentication::Store::LDAP::User ) object

=cut

sub may_i {
  my ($self, $args) = @_;
  my $arg = { base_dn => $self->lrtrim({ str => $args->{base_dn} }),
	      filter => $args->{filter},
	      user => $args->{user},
	      dn => $args->{user}->ldap_entry->dn,
	      skip => $args->{skip} || 'acl-.-',
	      return => 0, };

  my %roles = map { $_ => 1 } @{[ $arg->{user}->roles ]};
  $arg->{roles} = \%roles;
  $arg->{dn_arr} = [ split(',', $args->{user}->ldap_entry->dn) ];
  $arg->{dn_left} = shift @{$arg->{dn_arr}};
  $arg->{dn_right} = join(',', @{$arg->{dn_arr}});
  
  foreach my $i ((keys %{$arg->{roles}})) {
    next if $i !~ /$arg->{skip}/is;
    $arg->{regex} = substr( $i, length $arg->{skip});
    $arg->{return}++ if $arg->{filter} =~ /$arg->{regex}/is ||
      $arg->{base_dn} =~ /$arg->{regex}/is ||
      ( $arg->{filter} =~ /$arg->{dn_left}/is && $arg->{base_dn} =~ /$arg->{dn_right}/is ) ||
      $arg->{base_dn} eq $arg->{dn};
    # p $arg->{base_dn}; p $arg->{user}->ldap_entry->dn;
  }
  # p $arg; # delete $arg->{user}; p $arg;
  return $arg->{return};
}


=head2 vld_ifconfigpush

validation of the addresses for ifconfigpush OpenVPN option

    weather it is /30
    or /32

return either error message or 0 if validation has successfully passed

=cut

##
### TO BE REFACTORIED !!! to Net::CIDR::Set
##

sub vld_ifconfigpush {
  my ($self, $args) = @_;
  my $arg = {
	     concentrator_fqdn => $args->{concentrator_fqdn},
	     ifconfigpush => $args->{ifconfigpush},
	     mode => $args->{mode} || 'net30',
	     vpn_net => $args->{vpn_net} || '10.144/16', # !!! NEED TO BE FINISHED, now it is hardcode
	    };

  use Net::Netmask;

  my ( $l, $r ) = split(/ /, $arg->{ifconfigpush});

  $arg->{vpn}->{net} = Net::Netmask->new($arg->{vpn_net});

  if ( $arg->{mode} ne 'net30' && $arg->{vpn}->{net}->nth(1) eq $l ) {
    $arg->{return}->{error} = 'Left address can not be the address of VPN server itself.';
  } elsif ( $arg->{vpn}->{net}->nth(1) eq $r ) {

    $arg->{return} = 0; # $arg->{return}->{error} = 'NONWIN CONFIG';

  } else {
    $arg->{net} = Net::Netmask->new( $l . '/30');
    if ( ! $arg->{net}->match( $r ) ) {
      $arg->{return}->{error} = 'The second address does not belong to the expected ' . $arg->{net}->desc;
    } elsif ( $l eq $r ) {
      $arg->{return}->{error} = 'Local and Remote addresses can not be the same.';
    } elsif ( $arg->{net}->match($r) && $l eq $arg->{net}->nth(1) && $r eq $arg->{net}->nth(-2) ) {

      $arg->{return} = 0; # $arg->{return}->{error} = 'WIN CONFIG';
      
    } elsif ( $arg->{net}->match($r) && $l ne $arg->{net}->nth(1) && $r eq $arg->{net}->nth(-2) ) {
      $arg->{return}->{error} = 'The first address is not a usable/host address of the expected ' . $arg->{net}->desc;
    } elsif ( $arg->{net}->match($r) && $l eq $arg->{net}->nth(1) && $r ne $arg->{net}->nth(-2) ) {
      $arg->{return}->{error} = 'The second address is not a usable/host address of the expected ' . $arg->{net}->desc;
    } elsif ( $arg->{net}->match($r) && $l eq $arg->{net}->nth(-2) && $r eq $arg->{net}->nth(1) ) {
      $arg->{return}->{error} = 'The addresses are missordered for the expected ' . $arg->{net}->desc;
    } elsif ( $arg->{net}->match($r) && $l ne $arg->{net}->nth(1) && $r ne $arg->{net}->nth(-2) ) {
      $arg->{return}->{error} = 'The addresses are not usable/host addresses of the expected ' . $arg->{net}->desc;
    } else {
      $arg->{return}->{error} = 'Addresses does not belong to the same ( ' . $arg->{net}->desc . ' ) subnet.';
    }
  }

  return $arg->{return};
}


=head2 search_result_item_as_button

wrapper to place data to be displayed into a form button

    $self->search_result_item_as_button( { uri => ..., dn => ... } )

        pfx: prefix text to put before the form 
        uri: holds form action, default is `searchby/index'
    css_frm: form CSS
         dn: is object DN to be passed to the action
    css_btn: button CSS
    btn_tit: button title
    btn_txt: button text
        sfx: suffix text to put after the form

=cut

sub search_result_item_as_button {
  my ($self, $args) = @_;

  my $arg = { uri     => $args->{uri} || UMI->uri_for_action('searchby/index'),
	      dn      => $args->{dn},
	      pfx     => $args->{pfx} || '',
	      sfx     => $args->{sfx} || '',
	      btn_txt => $args->{btn_txt} || '',
	      btn_tit => $args->{btn_tit} || '',
	      css_frm => $args->{css_frm} || '',
	      css_btn => $args->{css_btn} || '', };
  
  return sprintf("%s <form method=\"POST\" 
      action=\"%s\" 
      class=\"form-inline formajaxer %s\">
  <input type=\"hidden\" name=\"ldap_subtree\" value=\"%s\">
  <button type=\"submit\" 
          class=\"btn %s\" 
          title=\"%s\">
    %s
  </button>
</form>%s",
		 $arg->{pfx},
		 $arg->{uri}, # $c->uri_for_action('searchby/index'),
		 $arg->{css_frm},
		 $arg->{dn},
		 $arg->{css_btn},
		 $arg->{btn_tit},
		 $arg->{btn_txt},
		 $arg->{sfx} );
}


=head2 ts

timestamp string generation method

input

    format => output format, default "%Y%m%d%H%M%S"
    gmt    => generate UTC timestamp of now
    ts     => desired date to generate timestamp for
              if not set, then generate localtime 
              timestamp of now
    gnrlzd => input is generalizedTime string, in general it match the template 
              "YYYYmmddHH[MM[SS]][(./,)d...](Z|(+/-)HH[MM])"
              if defined, then Net::LDAP::Util generalizedTime_to_time will be used

=cut

sub ts {
  my ($self, $args) = @_;

  my $arg = { format => $args->{format} || "%Y-%m-%d %H:%M:%S",
	      gnrlzd => $args->{gnrlzd} || 0,
	      gmt    => $args->{gmt}    || 0,
	      ts     => $args->{ts}     || undef,
	    };

  if ( ! defined $arg->{ts} ) {
    @{$arg->{timeptr}} = $arg->{gmt} ? gmtime : localtime;
  } elsif ( $arg->{gnrlzd} ) {
    @{$arg->{timeptr}} =
      $arg->{gmt} ? gmtime(generalizedTime_to_time( $arg->{ts} )) : localtime(generalizedTime_to_time( $arg->{ts} ));
  } elsif ( $arg->{ts} ) {
    @{$arg->{timeptr}} = $arg->{gmt} ? gmtime($arg->{ts}) : localtime($arg->{ts});
  }

  return strftime( $arg->{format}, @{$arg->{timeptr}} );
}

sub delta_t {
  my ($self, $args) = @_;
  my $arg = { requestttl => $args->{requestttl},
	      format     => $args->{format} || "%Y.%m.%d %H:%M" };
  my $t = localtime;
  return Time::Piece->strptime( $arg->{requestttl}, $arg->{format})->epoch - $t->epoch;
}

=head2 dns_rcode

DNS RCODEs RFC2929

=cut

has 'dns_rcode' => ( traits => ['Hash'], is => 'ro', isa => 'HashRef', builder => '_build_dns_rcode', );

sub _build_dns_rcode {
  my $self = shift;
  return { NOERROR           => { dec =>  0, RFC => 1035, descr => 'No Error', },
	   FORMERR           => { dec =>  1, RFC => 1035, descr => 'Format Error', },
	   SERVFAIL          => { dec =>  2, RFC => 1035, descr => 'Server Failure', },
	   NXDOMAIN          => { dec =>  3, RFC => 1035, descr => 'Non-Existent Domain', },
	   NOTIMP            => { dec =>  4, RFC => 1035, descr => 'Not Implemented', },
	   REFUSED           => { dec =>  5, RFC => 1035, descr => 'Query Refused', },
	   YXDOMAIN          => { dec =>  6, RFC => 2136, descr => 'Name Exists when it should not',},
	   YXRRSET           => { dec =>  7, RFC => 2136, descr => 'RR Set Exists when it should not',},
	   NXRRSET           => { dec =>  8, RFC => 2136, descr => 'RR Set that should exist does not', },
	   NOTAUTH           => { dec =>  9, RFC => 2136, descr => 'Server Not Authoritative for zone', },
	   NOTZONE           => { dec => 10, RFC => 2136, descr => 'Name not contained in zone', },
	   BADVERS           => { dec => 16, RFC => 2671, descr => 'Bad OPT Version', },
	   BADSIG            => { dec => 16, RFC => 2845, descr => 'TSIG Signature Failure', },
	   BADKEY            => { dec => 17, RFC => 2845, descr => 'Key not recognized', },
	   BADTIME           => { dec => 18, RFC => 2845, descr => 'Signature out of time window', },
	   BADMODE           => { dec => 19, RFC => 2930, descr => 'Bad TKEY Mode', },
	   BADNAME           => { dec => 20, RFC => 2930, descr => 'Duplicate key name', },
	   BADALG            => { dec => 21, RFC => 2930, descr => 'Algorithm not supported', },
	   'query timed out' => { dec => '', RFC => '',   descr => 'query timed out'}, };
}

=head2 dns_resolver

Net::DNS wrapper to resolve A, MX and PTR mainly
on input:

    fqdn   - FQDN to resolve (types A, MX)
    type   - DNS query type (A, MX, PTR)
    name   - IP address to resolve
    legend - part of legend for debug

    Net::DNS::Resolver options
    debug          - default: 0
    force_v4       - default: 1
    persistent_tcp - default: 1
    persistent_udp - default: 1
    recurse        - default: 1
    retry          - default: 1
    tcp_timeout    - default: 1
    udp_timeout    - default: 1

=cut

sub dns_resolver {
  my ($self, $args) = @_;
  my $arg = { name           => $args->{name},
	      fqdn           => $args->{fqdn}           // $args->{name},
	      type           => $args->{type}           // 'PTR',
	      legend         => $args->{legend}         // '',
	      debug          => $args->{debug}          // 0,
	      force_v4       => $args->{force_v4}       // 1,
	      persistent_tcp => $args->{persistent_tcp} // 1,
	      persistent_udp => $args->{persistent_udp} // 1,
	      recurse        => $args->{recurse}        // 1,
	      retry          => $args->{retry}          // 1,
	      tcp_timeout    => $args->{tcp_timeout}    // 1,
	      udp_timeout    => $args->{udp_timeout}    // 1,
	    };

  # log_debug { np( $arg ) };
  
  my $return;

  my $r = new Net::DNS::Resolver(
				  debug          => $arg->{debug},
				  force_v4       => $arg->{force_v4},
				  persistent_tcp => $arg->{persistent_tcp},
				  persistent_udp => $arg->{persistent_udp},
				  recurse        => $arg->{recurse},
				  retry          => $arg->{retry},
				  tcp_timeout    => $arg->{tcp_timeout},
				  udp_timeout    => $arg->{udp_timeout},
				);
  
  if ( defined UMI->config->{network}->{nameservers} ) {
    $r->nameservers( $_ ) foreach ( @{UMI->config->{network}->{nameservers}} );
  }

  my $rr = $r->search($arg->{name});
  $return->{errstr}  = $r->errorstring;

  if ( defined $rr) {
    foreach ($rr->answer) {
      if ( $arg->{type} eq 'PTR' ) {
	$return->{success} = $_->ptrdname if $_->type eq $arg->{type};
      } elsif ( $arg->{type} eq 'A' ) {
	$return->{success} = $_->address if $_->type eq $arg->{type};
      } elsif ( $arg->{type} eq 'MX' ) {
	my @mx_arr = mx( $r, $arg->{fqdn} );
	if (@mx_arr) {
	  $return->{success} = $mx_arr[0]->exchange;
	}
      }

      if ( $return->{errstr} ne 'NOERROR' ) {
	$return->{error}->{html} = sprintf("<i class='h6'>dns_resolver()</i>: %s %s: %s ( %s )",
					   $arg->{fqdn},
					   $arg->{legend},
					   $self->dns_rcode->{ $r->errorstring }->{descr},
					   $r->errorstring );
	$return->{error}->{errdescr} = $self->dns_rcode->{ $r->errorstring }->{descr};
	$return->{error}->{errcode}  = $self->dns_rcode->{ $r->errorstring }->{dec};
	$return->{error}->{errstr}   = $r->errorstring;
      }

    }
  } else {
    if ( $return->{errstr} ne 'NOERROR') {
      $return->{error}->{html} = sprintf("<i class='h6'>dns_resolver()</i>: %s %s: %s ( %s )",
					 $arg->{fqdn},
					 $arg->{legend},
					 $self->dns_rcode->{ $r->errorstring }->{descr} // 'NA',
					 $r->errorstring // 'NA' );
      $return->{error}->{errdescr} = $self->dns_rcode->{ $r->errorstring }->{descr};
      $return->{error}->{errstr}   = $r->errorstring;
    }
  }

  $return->{errcode} = $self->dns_rcode->{ $r->errorstring }->{descr}
    if exists $return->{errstr};

  # p $arg->{fqdn}; p $r;
  # log_debug { np( $return ) };
  return $return;
}


=head2 store_data

dirty hack to store user requst object to disk file

to retrieve data use something like this

    use Storable;
    use Data::Printer;
    my $h = retrieve('file');
    p $h;

=cut

sub store_data {
  my ($self, $args) = @_;
  my $arg = { data => $args->{data},
	      file => $args->{file},
	      mode => $args->{mode} || 0640};
  store $arg->{data}, $arg->{file};
  chmod $arg->{mode}, $arg->{file};
}


=head2 ask_mikrotik

wrapper to get output from MikroTik devices

    'DC:4F:22:10:33:2C' => {
                             'eap-identity' => '',
                             'rx-rate' => '54Mbps',
                             'uptime' => '1h18m8s210ms',
                             'interface' => 'cap-402-h-2-1',
                             'tx-rate' => '72.2Mbps-20MHz/1S/SGI',
                             'tx-rate-set' => 'CCK:1-11 OFDM:6-54 BW:1x-2x SGI:1x HT:0-7',
                             'rx-signal' => '-50',
                             'packets' => '216,226',
                             'ssid' => 'NXC',
                             'mac-address' => 'DC:4F:22:10:33:2C',
                             '.id' => '*44507',
                             'bytes' => '47591,22659'
                           },
    'cap-402-h-2-3' => {
                         'disabled' => 'false',
                         'dynamic' => 'true',
                         'running' => 'false',
                         'bound' => 'true',
                         'master-interface' => 'cap-402-h-2',
                         'current-basic-rate-set' => 'CCK:1-11',
                         'current-state' => 'running-ap',
                         'l2mtu' => '1600',
                         'master' => 'false',
                         '.id' => '*F4',
                         'current-rate-set' => 'CCK:1-11 OFDM:6-54 BW:1x-2x SGI:1x-2x HT:0-15',
                         'mac-address' => '66:D1:54:3C:83:E1',
                         'current-registered-clients' => '0',
                         'configuration' => 'cfg_2_VLAN2101_psk',
                         'name' => 'cap-402-h-2-3',
                         'inactive' => 'false',
                         'radio-mac' => '00:00:00:00:00:00',
                         'arp-timeout' => 'auto',
                         'current-authorized-clients' => '0'
                       },

=cut

sub ask_mikrotik {
  my ($self, $args) = @_;
  my $arg = { host     => $args->{host},
	      username => $args->{username},
	      password => $args->{password},
	      type     => $args->{type} };
  my $return;
  
  use MikroTik::API;

  my $api = MikroTik::API->new({
				host            => $arg->{host},
				username        => $arg->{username},
				password        => $arg->{password},
				use_ssl         => 0,
				new_auth_method => 1,
			       });

  my $ret_code;
  if ( $arg->{type} eq 'registrations' ) {
    my ( @ifs, @usr );
    ( $ret_code, @ifs ) = $api->query( '/caps-man/interface/print' );
    $return->{interfaces}->{$_->{name}} = $_ foreach (@ifs);
    
    ( $ret_code, @usr ) = $api->query( '/caps-man/registration-table/print' );
    $return->{registrats}->{$_->{'mac-address'}} = $_ foreach (@usr);

  } elsif ( $arg->{type} eq 'get_psk' ) {
      my @arr;
      ( $ret_code, @arr ) = $api->query( '/caps-man/security/print' );
      $return->{$_->{name}} = $_ foreach (@arr);
      # log_debug { np(@arr) };
  } else {
    $return = {};
  }
  
  $api->logout();

  # log_debug { np($return) };
  return $return;
}

=head2 nisnetgroup_host_split

split input string by the first dot caracter, to be used like in
memberNisNetgroup attribute

=cut

sub nisnetgroup_host_split {
  my  ( $self, $host ) = @_;
  my $split = $host =~ /^\..*$/ ? [ '', substr($host, 1) ] : [ split(/\./, $host, 2) ];
  log_debug { np($split) };
  return $split;
}

=head2 is_org_uni

number of elements in the intersection of user organization/s and
ou=People,dc=.. root object organization/s

=cut

sub is_org_uni {
  my ($self, $org_usr, $org_obj) = @_;
  #log_debug { np($org_usr) };
  #log_debug { np($org_obj) };
  $org_usr = [ $org_usr ] if ref($org_usr) ne 'ARRAY';
  $org_obj = join('', @{$org_obj});
  #log_debug { np($org_usr) };
  #log_debug { np($org_obj) };
  #my %i;
  #@i{@$org_obj} = ();
  #my $int = grep exists $i{$_}, @$org_usr;
  my $int = grep {$org_obj =~ /.*$_.*/} @$org_usr;
  return $int;
}

sub traverse {
  my ($self, $args) = @_;
  my $arg = { in => $args->{in},
	      ou => $args->{ou}, };
  my $arr = [];

  while (my ($key,$val) = each %{$arg->{in}}) {

    if ( keys %{$val} ) {
      # first iteration
      $arg->{ou}->{name} = $key
	if ref($arg->{ou}) eq "HASH" && keys(%{$arg->{ou}}) == 2;

      $arr = [];
      $self->traverse ({ in => $val,
			 ou => $arr, });

      if ( ref($arg->{ou}) eq "HASH" && keys(%{$arg->{ou}}) == 2 ) {
	# first iteration
	@{$arg->{ou}->{children}} = sort @{$arr};
      } else {
	push @{$arg->{ou}}, { name     => $key,
			      children => sort $arr };
      }

    } elsif ( ref($arg->{ou}) eq 'ARRAY') {
      push @{$arg->{ou}}, { name => $key };
    }

  }
  return;
}

=head2 factoroff_searchby

factor off of search and advanced search

the main place for search result preparation and processing

=cut

sub factoroff_searchby {
  my ($self, $args) = @_;

  my $all_e     = $args->{all_entries};
  my $all_s     = $args->{all_sysgroups};
  my $c_stats   = $args->{c_stats};
  my $e         = $args->{entry};
  my $ldap_crud = $args->{ldap_crud};
  my $sess      = $args->{session};

  my ( $return, $tt_e );

  my $dn          = $e->dn;
  my @dn_as_arr    = split(',', $dn);
  my $current_dn_depth      = $#dn_as_arr + 1;

  my ( $dn_depth, @root_dn_arr, $root_dn, $mesg, @root_attrs_noref, @root_attrs_asref );

  # here, for each entry we are preparing data of the root object it belongs to
  if ( $dn =~ /.*,$ldap_crud->{cfg}->{base}->{acc_root}/ ) {
    $dn_depth = scalar split(/,/, $ldap_crud->{cfg}->{base}->{acc_root}) + 1;
    my @root_dn_arr = splice(@dn_as_arr, -1 * $dn_depth);
    my $root_dn     = join(',', @root_dn_arr);
    my $mesg;
    my @root_attrs_noref = ( 'sn', 'givenName', 'gidNumber', $ldap_crud->{cfg}->{rdn}->{acc_root} );
    my @root_attrs_asref = ( 'o' );

    $tt_e->{root}->{dn} = $root_dn;

    if ( $current_dn_depth == $dn_depth ) { # the very root object
      $c_stats->profile(begin => '- root obj proc');

      $tt_e->{root}->{$_} = $e->get_value($_)             foreach ( @root_attrs_noref );
      $tt_e->{root}->{$_} = $e->get_value($_, asref => 1) foreach ( @root_attrs_asref );

      $c_stats->profile(end   => '- root obj proc');
    } else {			# branches and leaves
      $c_stats->profile(begin => '- root of branch/leaf proc');

      if ( exists $all_e->{$root_dn} ) {
	$tt_e->{root}->{$_} = $all_e->{$root_dn}->{lc($_)}->[0] foreach ( @root_attrs_noref );
	$tt_e->{root}->{$_} = $all_e->{$root_dn}->{lc($_)}      foreach ( @root_attrs_asref );
      } else {
	my $root_mesg = $ldap_crud->search({ dn => $root_dn, scope => 'base', });
	if ( $root_mesg->is_error() ) {
	  $return->{error} .= sprintf("for dn: <b>%s</b><br>%s",
				      $tt_e->{root}->{dn},
				      $ldap_crud->err( $root_mesg )->{html});
	} else {
	  my $root_entry = $root_mesg->entry(0);
	  $tt_e->{root}->{$_} = $root_entry->get_value($_)             foreach ( @root_attrs_noref );
	  $tt_e->{root}->{$_} = $root_entry->get_value($_, asref => 1) foreach ( @root_attrs_asref );
	}
      }

      $c_stats->profile(end   => '- root of branch/leaf proc');
    }

    my @to_utf8ize = ( 'givenName', 'sn' );
    foreach (@to_utf8ize) {
      utf8::decode($tt_e->{root}->{$_}) if exists $tt_e->{root}->{$_};
    }
  } elsif ( $dn =~ /.*,$ldap_crud->{cfg}->{base}->{inventory}/ ) {
    $dn_depth = scalar split(/,/, $ldap_crud->{cfg}->{base}->{inventory}) + 1;
  } else {
    # !!! HARDCODE
    # !!! TODO how deep dn could be to identify the object type, `3' is for what? :( !!!
    $dn_depth = $ldap_crud->{cfg}->{base}->{dc_num} + 1;
  }


  $c_stats->profile(begin => '- obj mgmnt data');

  $tt_e->{mgmnt} =
    {
     gitAclProject   => $_->exists('gitAclProject') ? 1 : 0,
     is_account      => $dn =~ /.*,$ldap_crud->{cfg}->{base}->{acc_root}/ ? 1 : 0,
     is_group        => $dn =~ /.*,$ldap_crud->{cfg}->{base}->{group}/ ? 1 : 0,
     is_inventory    => $dn =~ /.*,$ldap_crud->{cfg}->{base}->{inventory}/ ? 1 : 0,
     is_log          => $dn =~ /.*,$ldap_crud->{cfg}->{base}->{db_log}/ ? $_->get_value( 'reqType' ) : 'no',
     is_root         => scalar split(',', $dn) <= $dn_depth ? 1 : 0,
     jpegPhoto       => $dn =~ /.*,$ldap_crud->{cfg}->{base}->{acc_root}/ ? 1 : 0,
     userDhcp        => $dn =~ /.*,$ldap_crud->{cfg}->{base}->{acc_root}/ &&
     scalar split(',', $dn) <= $dn_depth ? 1 : 0,
    };

  # is this user blocked?
  if ( defined $sess->{settings}->{ui}->{isblock} && $sess->{settings}->{ui}->{isblock} == 1 ) {
    $c_stats->profile(begin => '- is-blocked check');

    if ( defined $tt_e->{root}->{gidNumber} &&
	 $tt_e->{root}->{gidNumber} eq $ldap_crud->{cfg}->{stub}->{group_blocked_gid} ) {
      $tt_e->{mgmnt}->{is_blocked} = 1;
    } elsif ( $dn =~ /^.*authorizedService=.*$/ ) {
      my $is_blocked_filter =
	sprintf('(&(cn=%s)(memberUid=%s))',
		$ldap_crud->{cfg}->{stub}->{group_blocked},
		$tt_e->{root}->{ $ldap_crud->{cfg}->{rdn}->{acc_root} });
      # log_debug { np( $ldap_crud->cfg->{base}->{group} . " | " . $is_blocked_filter ) };
      # log_debug { np($_->dn) };
      $mesg = $ldap_crud->search({ base   => $ldap_crud->cfg->{base}->{group},
				   filter => $is_blocked_filter, });

      $tt_e->{mgmnt}->{is_blocked} = $mesg->count;
      $return->{error} .= $ldap_crud->err( $mesg )->{html}
	if $mesg->is_error();
    } else {
      $tt_e->{mgmnt}->{is_blocked} = 0;
    }

    $c_stats->profile(end => '- is-blocked check');
  }

  $c_stats->profile(begin => '- root-obj-sys-groups check');
  # getting root object sys groups if any
  my $root_gr;
  my $k;
  foreach $k (keys (%{$all_s})) {
    $root_gr->{$k} = 1
      if defined $tt_e->{root}->{$ldap_crud->{cfg}->{rdn}->{acc_root}} &&
      defined $all_s->{$k}->{$tt_e->{root}->{$ldap_crud->{cfg}->{rdn}->{acc_root}}};
    # log_debug { "\n\nkey: $k\n" . np($ldap_crud->{cfg}->{rdn}->{acc_root}) };
  }

  # log_debug { np($tt_e->{root}) };

  $tt_e->{mgmnt}->{root_obj_groups} = defined $root_gr ? $root_gr : undef;

  my $gr_entry;
  # getting name of the primary group
  if ( $e->exists('gidNumber') ) {
    $mesg = $ldap_crud->search({ base   => $ldap_crud->cfg->{base}->{group},
				 filter => sprintf('(gidNumber=%s)',
						   $e->get_value('gidNumber')), });

    if ( $mesg->is_error() ) {
      $return->{error} .= $ldap_crud->err( $mesg )->{html};
    } elsif ( $mesg->count ) {
      $gr_entry = $mesg->entry(0);
      $tt_e->{root}->{PrimaryGroupNameDn} = $gr_entry->dn;
      $tt_e->{root}->{PrimaryGroupName}   = $gr_entry->get_value('cn');
    }
  }
  $c_stats->profile(end => '- root-obj-sys-groups check');

  my $c_name = ldap_explode_dn( $e->get_value('creatorsName'),  casefold => 'none' );
  my $m_name = ldap_explode_dn( $e->get_value('modifiersName'), casefold => 'none' );
  $tt_e->{root}->{ts} =
    {
     createTimestamp => $self->ts({ ts => $e->get_value('createTimestamp'),
				    gnrlzd => 1,
				    gmt => 1,
				    format => '%Y%m%d%H%M' }),
     creatorsName    => $c_name->[0]->{uid} // $c_name->[0]->{cn},
     modifyTimestamp => $self->ts({ ts => $e->get_value('modifyTimestamp'),
				    gnrlzd => 1,
				    gmt => 1,
				    format => '%Y%m%d%H%M' }),
     modifiersName   => $m_name->[0]->{uid} // $m_name->[0]->{cn}, };

  $tt_e->{mgmnt}->{userPassword}  = 0;
  $tt_e->{mgmnt}->{dynamicObject} = 0;
  my $objectClass;
  if ( $e->exists('objectClass') ) {
    $objectClass = $e->get_value('objectClass', asref => 1);
  } else {
    my $msg_e = $ldap_crud->search({ base   => $e->dn,
				     filter => '(objectClass=*)',
				     scope  => 'base',
				     attrs  => [ '(objectClass' ], });
    if ( $msg_e->is_error() ) {
      $return->{error} .= $ldap_crud->err( $msg_e )->{html};
      $objectClass = [];
    } elsif ( $msg_e->count ) {
      my $tmp_e = $msg_e->entry(0);
      $objectClass = $tmp_e->get_value('objectClass', asref => 1);
    }
  }
  foreach $k ( @{$objectClass} ) {
    $tt_e->{mgmnt}->{userPassword} = 1
      if exists $sess->{ldap}->{obj_schema}->{$k}->{may}->{userPassword} ||
      exists $sess->{ldap}->{obj_schema}->{$k}->{must}->{userPassword};
    if ( $k eq 'dynamicObject' ) {
      $tt_e->{mgmnt}->{dynamicObject} = 1;
      $tt_e->{root}->{ts}->{entryExpireTimestamp} =
	$self->ts({ ts => $e->get_value('entryExpireTimestamp'),
		    gnrlzd => 1,
		    gmt => 1 });
    }
  }

  my $diff = undef;
  my $tmp;
  my $to_utf_decode;
  foreach my $attr (sort $e->attributes) {

    # $to_utf_decode = $e->get_value( $attr, asref => 1 );
    # map { utf8::decode($_); $_} @{$to_utf_decode};
    # @{$to_utf_decode} = sort @{$to_utf_decode};
    # $tt_e->{attrs}->{$attr} = $to_utf_decode;

    @{$to_utf_decode} = map { utf8::decode($_); $_} @{$e->get_value( $attr, asref => 1 )};
    @{$tt_e->{attrs}->{$attr}} = sort @{$to_utf_decode};

    if ( $attr eq 'jpegPhoto' ) {
      $tt_e->{attrs}->{$attr} =
	ref($tt_e->{attrs}->{$attr}) eq 'ARRAY'
	? sprintf('img-thumbnail" alt="jpegPhoto of %s" src="data:image/jpg;base64,%s" title="%s" />',
		  $dn,
		  encode_base64(join('',@{$tt_e->{attrs}->{$attr}})),
		  $dn)
	: sprintf('img-thumbnail" alt="%s has empty image set" title="%s" src="holder.js/128x128" />', $dn, $dn);
    } elsif ( $attr eq 'userCertificate;binary' ||
	      $attr eq 'cACertificate;binary'   ||
	      $attr eq 'certificateRevocationList;binary' ) {
      $tt_e->{attrs}->{$attr} = $self->cert_info({ attr => $attr, cert => $e->get_value( $attr ) });
      #} elsif ( $attr eq 'reqMod' || $attr eq 'reqOld' ) {
      #my $ta = $e->get_value( $attr, asref => 1 );
      #my @te = sort @{$ta};
      #p \@te;
      # $tt_e->{attrs}->{$attr} = $e->get_value( $attr, asref => 1 );
    } elsif ( $attr eq 'umiUserCertificateNotAfter' ||
	      $attr eq 'pgpKeyExpireTime' ) {

      $tt_e->{mgmnt}->{cert_expired} =
	Time::Piece->strptime( substr($e->get_value( $attr ), 0, 14),
			       "%Y%m%d%H%M%S" ) < localtime ? 1 : 0;

      $tt_e->{attrs}->{$attr} = $e->get_value( $attr );
    } elsif ( ref( $tt_e->{attrs}->{$attr} ) eq 'ARRAY') {
      $tt_e->{is_arr}->{$attr} = 1;
    }

    if ( $e->get_value( 'objectClass' ) eq 'auditModify' &&
	 ( $attr eq 'reqMod' || $attr eq 'reqOld' ) ) {
      foreach ( @{ $tt_e->{attrs}->{$attr} } ) {
	$diff->{$attr} .= sprintf("%s\n", $_)
	  if $_ !~ /.*entryCSN.*/     &&
	  $_ !~ /.*modifiersName.*/   &&
	  $_ !~ /.*modifyTimestamp.*/ &&
	  $_ !~ /.*creatorsName.*/    &&
	  $_ !~ /.*createTimestamp.*/ ;
      }
    }
  }

  # log_debug { np($tt_e->{attrs}) };

  $tt_e->{attrs}->{jpegPhoto} =
    sprintf('img-thumbnail holder-js" alt="%s has empty image set" title="%s" data-src="holder.js/128x128?theme=stub&text=ABSENT \n \n  ATTRIBUTE" />',
	    $dn, $dn)
    if ! exists $tt_e->{attrs}->{jpegPhoto} &&
    (
     ( $tt_e->{'mgmnt'}->{is_root} &&
       $dn =~ /^uid=.*,$ldap_crud->{cfg}->{base}->{acc_root}/ ) ||
     $dn =~ /^uid=.*,authorizedService=(mail|xmpp).*,$ldap_crud->{cfg}->{base}->{acc_root}/
    );

  use Text::Diff;
  if ( defined $diff->{reqOld} && defined $diff->{reqMod} ) {
    $tmp = diff \$diff->{reqOld}, \$diff->{reqMod}, { STYLE => 'Text::Diff::HTML' };
    $tt_e->{attrs}->{reqOldModDiff} = $tmp;
  }

  undef $diff;

  # log_debug { np($tt_e) };

  return { root   => $tt_e->{root},
	   attrs  => $tt_e->{attrs},
	   is_arr => $tt_e->{is_arr},
	   mgmnt  => $tt_e->{mgmnt},
	   return => $return, };
}

=head1 AUTHOR

Zeus

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

######################################################################

1;

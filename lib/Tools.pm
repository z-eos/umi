# -*- mode: cperl -*-
#

package Tools;
use Moose::Role;

use utf8;
use Data::Printer;
use Try::Tiny;
use Net::CIDR::Set;

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
  return unpack N => pack 'C4' => split /\./ => $arg;
}

# pow: exp( log( $self->ip2dec($arg) ) / 2 )
sub ipam_msk_ip2dec {
  my ($self, $arg) = @_;
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
             address found to be from if not set, then the very I<ipspace>
             assumed

    req_msk: type INT
             netmask, in CIDR notation, of the requested ip space (default is 32)

First, we calculate I<free> addresses set, it is new set containing all the
addresses that are present in I<pool> set but not I<used> set.

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

  foreach ( $nsec->as_array( $nsec->iterate_addresses ) ) {
    next if $arg->{req_msk} == 32 && $_ =~ /^.*\.[0,255]$/;
    next if ! $free->contains( $_ . '/' . $arg->{req_msk} );
    return $_;
  }
  return 0;
}


## todo? # =head2 ldap_date
## todo? # 
## todo? # to and fro LDAP timestamp parser
## todo? # 
## todo? # stolen from https://metacpan.org/pod/Catalyst::Model::LDAP::Entry
## todo? # 
## todo? # =cut
## todo? # 
## todo? # sub ldap_date {
## todo? #   my ($self, $args) = @_;
## todo? #   my $arg = { ts        => $args->{ts},
## todo? # 	      patternp   => $args->{patternp} || '%Y%m%d%H%M%S%Z',
## todo? # 	      patternf   => $args->{patternf} || '%F %T %Z',
## todo? # 	      locale    => $args->{locale} || 'en_US',
## todo? # 	      tz        => $args->{tz} || 'local',
## todo? # 	      on_error  => $args->{on_error} || 'undef',
## todo? # 	    };
## todo? #   use DateTime::Format::Strptime qw(strftime);
## todo? #   my $strp =
## todo? #     DateTime::Format::Strptime->new( pattern   => $arg->{patternp},
## todo? # 				     locale    => $arg->{locale},
## todo? # 				     time_zone => $arg->{tz},
## todo? # 				     on_error  => $arg->{on_error},
## todo? # 				   );
## todo? #   $arg->{ts_parsed} = $strp->strftime($arg->{patternf}, $strp->parse_datetime($arg->{ts}));
## todo? #   p $strp->errmsg if $strp->{on_error} eq 'undef';
## todo? #   p $arg->{ts_parsed};
## todo? #   return $arg->{ts_parsed};
## todo? # }

=head2 regex

regexps and other variables

=cut

has 'regex' => ( traits => ['Hash'], is => 'ro', isa => 'HashRef', builder => '_build_regex', );

sub _build_regex {
  my $self = shift;

  return { sshpubkey => { type => qr/ssh-rsa|ssh-dss|ssh-ed25519|ecdsa-\S+/,
			  id => "[a-zA-Z_][a-zA-Z0-9_-]+",
			  base64 => "[A-Za-z0-9+/]", }, }
}


=head2 utf2lat

utf8 input (cyrillic in particular) to latin1 transliteration

=cut

sub utf2lat {
  my ($self, $to_translit, $allvariants) = @_;
  # noLingva # use utf8;
  # noLingva # use Text::Unidecode;
  # noLingva # # Catalyst provides utf8::encoded data! here we need them to
  # noLingva # # utf8::decode to make them suitable for unidecode, since it expects
  # noLingva # # utf8::decode input
  # noLingva # utf8::decode( $to_translit );
  # noLingva # my $a = unidecode( $to_translit );

  # Lingua::Translit::Tables
  # "ALA-LC RUS", "GOST 7.79 RUS", "DIN 1460 RUS"
  my $table = "ALA-LC RUS";

  my ($tr, $return);
  use utf8;
  use Lingua::Translit;
  if ( ! defined $allvariants ) {
    $tr = new Lingua::Translit($table);
    $return = $tr->translit( $to_translit );
    # escape important non ascii
    $return =~ s/ĭ/j/g;
    $return =~ s/ė/e/g;
    # remove non-alphas (like ' and `)
    $return =~ tr/a-zA-Z0-9\,\.\_\-\ \@\#\%\*\(\)\!//cds;
    return $return;
  } else {
    $tr = new Lingua::Translit('ALA-LC RUS');
    $return->{'ALA-LC RUS'} = $tr->translit( $to_translit );
    $tr = new Lingua::Translit('GOST 7.79 RUS');
    $return->{'GOST 7.79 RUS'} = $tr->translit( $to_translit );
    $tr = new Lingua::Translit('DIN 1460 RUS');
    $return->{'DIN 1460 RUS'} = $tr->translit( $to_translit );
    $tr = new Lingua::Translit('ISO 9');
    $return->{'ISO 9'} = $tr->translit( $to_translit );
    $tr = new Lingua::Translit($table);
    $return->{'UMI use ' . $table . ' with non-alphas removed'} = $tr->translit( $to_translit );
    $return->{'UMI use ' . $table . ' with non-alphas removed'} =~ s/ї/i/g;
    $return->{'UMI use ' . $table . ' with non-alphas removed'} =~ s/є/e/g;
    $return->{'UMI use ' . $table . ' with non-alphas removed'} =~ s/і/i/g;
    $return->{'UMI use ' . $table . ' with non-alphas removed'} =~ s/ī/i/g;
    $return->{'UMI use ' . $table . ' with non-alphas removed'} =~ tr/a-zA-Z0-9\,\.\_\-\ \@\#\%\*\(\)\!//cds;
    return $return;
  }
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




sub is_int {
  my ($self, $arg) = @_;
  return $arg !~ /^\d+$/ ? 1 : 0;
}


=head2 pwdgen

http://www.openldap.org/faq/data/cache/347.html

RFC 2307 passwords (http://www.openldap.org/faq/data/cache/346.html)
generation ( {SSHA} ) to be used as userPassword value.

Prepares with Digest::SHA1, password provided or autogenerated, to be
used as userPassword attribute value

Password generated (with Crypt::GeneratePassword) is a random
pronounceable word. The length of the returned word is 12 chars. It is
up to 3 numbers and special characters will occur in the password. It
is up to 4 characters will be upper case.

If no password provided, then it will be automatically generated.

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
  my $pwdgen =
    {
     pwd => $args->{pwd},
     len => $args->{len} ne '' ? $args->{len} : UMI->config->{pwd}->{len},
     num => $args->{num} ne '' ? $args->{num} : UMI->config->{pwd}->{num},
     cap => $args->{cap} ne '' ? $args->{cap} : UMI->config->{pwd}->{cap},
     cnt => $args->{cnt} ne '' ? $args->{cnt} : UMI->config->{pwd}->{cnt},
     salt => $args->{salt} ne '' ? $args->{salt} : UMI->config->{pwd}->{salt},
     pronounceable => $args->{pronounceable} ne '' ? $args->{pronounceable} : UMI->config->{pwd}->{pronounceable},
    };

  $pwdgen->{len} = UMI->config->{pwd}->{lenp}
    if $pwdgen->{pronounceable} && $pwdgen->{len} > UMI->config->{pwd}->{lenp};

  # p $args;
  # p $pwdgen;
  use Crypt::GeneratePassword qw(word word3 chars);

  if ( ( ! defined $pwdgen->{'pwd'} || $pwdgen->{'pwd'} eq '' )
       && $pwdgen->{'pronounceable'} ) {
    $pwdgen->{'pwd'} = word3( $pwdgen->{'len'},
			    $pwdgen->{'len'},
			    'en',
			    $pwdgen->{'num'},
			    $pwdgen->{'cap'}
			  );
  } elsif ( ( ! defined $pwdgen->{'pwd'} || $pwdgen->{'pwd'} eq '' )
	    && ! $pwdgen->{'pronounceable'} ) {
    $pwdgen->{'pwd'} = chars( $pwdgen->{'len'}, $pwdgen->{'len'} );
  }

  use Digest::SHA1;
  use MIME::Base64;
  my $sha1 = Digest::SHA1->new;
  $sha1->add( $pwdgen->{'pwd'}, $pwdgen->{'salt'} );

  return {
	  clear => $pwdgen->{'pwd'},
	  ssha => '{SSHA}' . encode_base64( $sha1->digest . $pwdgen->{'salt'}, '' )
	 };
}


=head2 file2var

read input file into the returned variable and set final message on
results of the assignment

if $return_as_arr defined and is set to 1, then return array of
strings, rather than scalar variable

=cut


sub file2var {
  my  ( $self, $file, $final_message, $return_as_arr ) = @_;
  my @file_in_arr;
  my $file_in_str;
  binmode FILE;
  
  try {
    open FILE, $file;
  } catch {
    push @{$final_message->{error}}, "Can not open $file: $_";
  };
    
  if ( defined $return_as_arr && $return_as_arr == 1 ) {
    while (<FILE>) {
      chomp;
      push @file_in_arr, $_;
    }
  } else {
    local $/ = undef;
    $file_in_str = <FILE>;
  }

  try {
    close FILE;
  } catch {
    push @{$final_message->{error}}, "$_";
  };
  
  return defined $return_as_arr && $return_as_arr == 1 ? \@file_in_arr : $file_in_str;
}


=head2 cert_info

data taken, generally, from

openssl x509 -in target.crt -text -noout

=cut


sub cert_info {
  my ( $self, $args ) = @_;
  my $arg = {
	     cert => $args->{cert},
	     ts => defined $args->{ts} && $args->{ts} ? $args->{ts} : "%a %b %e %H:%M:%S %Y",
	    };

  use Crypt::X509;
  my $x509 = Crypt::X509->new( cert => join('', $arg->{cert}) );
  use POSIX qw(strftime);
  return {
	  'Subject' => join(',',@{$x509->Subject}),
	  'Issuer' => join(',',@{$x509->Issuer}),
	  'S/N' => $x509->serial,
	  'Not Before' => strftime ($arg->{ts}, localtime($x509->not_before)),
	  'Not  After' => strftime ($arg->{ts}, localtime( $x509->not_after)),
	  'error' => $x509->error ? sprintf('Error on parsing Certificate: %s', $x509->error) : undef,
	  'cert' => $arg->{cert},
	 };
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

=item oct

regex pattern for group of two hexadecimal digits [0-9a-f]{2}

=item sep

pattern for acceptable separator [.:-]

=item dlm

delimiter for concatenation after splitting

=back

=cut


sub macnorm {
  my ( $self, $args ) = @_;
  my $arg = {
	     mac => defined $args->{mac} && $args->{mac} ne '' ? lc($args->{mac}) : '',
	     oct => $args->{oct} || '[0-9a-fA-F]{2}',
	     sep => $args->{sep} || '[.:-]',
	     dlm => $args->{dlm} || '',
	    };
  if (( $arg->{mac} =~ /^$arg->{oct}($arg->{sep})$arg->{oct}($arg->{sep})$arg->{oct}($arg->{sep})$arg->{oct}($arg->{sep})$arg->{oct}($arg->{sep})$arg->{oct}$/ ) &&
      ($1 x 4 eq "$2$3$4$5")) {
    return join( $arg->{dlm}, split(/$arg->{sep}/, $arg->{mac}) );
  } elsif (( $arg->{mac} =~ /^$arg->{oct}$arg->{oct}$arg->{oct}$arg->{oct}$arg->{oct}$arg->{oct}$/ ) &&
	   ($1 x 4 eq "$2$3$4$5")) {
    my @mac_arr = split('', $arg->{mac});
    return join( $arg->{dlm},
		 "$mac_arr[0]$mac_arr[1]",
		 "$mac_arr[2]$mac_arr[3]",
		 "$mac_arr[4]$mac_arr[5]",
		 "$mac_arr[6]$mac_arr[7]",
		 "$mac_arr[8]$mac_arr[9]",
		 "$mac_arr[10]$mac_arr[11]" );
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
  my $id = "[a-zA-Z_][a-zA-Z0-9_-]+";

  while (1) {
    my $value;
    if ($in =~ /^(?<id>${id})(?<delim>(?:,|\s+))(?<tail>.*)/ ) {
      # boolean option (without `=' sign)
      $in = $+{tail};
      my $is_type = $+{id};
      if ( $is_type =~ /(?<type>$self->{regex}->{sshpubkey}->{type})/ ) {
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

  if ( $in !~ /^.*\s*(?<type>$self->{regex}->{sshpubkey}->{type})\s(?<tail>.*)/ ) {
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

  if ( $in !~ /^(?<key>$self->{regex}->{sshpubkey}->{base64}+)\s*(?<tail>.*)/ ) {
    $key_hash->{error} = "Parsing problem, no valid SSH2 key body found!";
    return 0;
  } else {
    $in = $+{tail};
    # !!! STUB !!! here we need base64 validation !!! STUB !!!
    my $x = $+{key};
    my $y = decode_base64($x);
    if ( $y ne '' && length($x) > 100 && $y =~ $self->{regex}->{sshpubkey}->{type} ) {
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

  $arg->{ops} = {
		 Ecc => $arg->{ecc},
		 ModuleSize => $arg->{mod},
		};
  if ( defined $args->{ver} ) {
    $arg->{ver} = $args->{ver};
    $arg->{ops}->{Version} = $arg->{ver};
  }

  use GD::Barcode::QRcode;
  use MIME::Base64;

  try {
    $arg->{gd} = GD::Barcode::QRcode->new( $arg->{txt}, $arg->{ops} )->plot();
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

replies question: "may I do this?"

check the match of the base DN and search filter provided against user
roles and user dn

user role name is expected to be constructed as `acl-<r/w>-KEYWORD>
where KEYWORD is the pattern to match against the given DN and filter

in other words

- if KEYWORD for any of user roles matches the filter or
base DN, the check is successfull

- if user dn matches base DN, the check is suc1cessfull

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

return either error message or 0 if validation has been successfully passed

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

  $arg->{vpn}->{net} = new Net::Netmask ($arg->{vpn_net});

  if ( $arg->{mode} ne 'net30' && $arg->{vpn}->{net}->nth(1) eq $l ) {
    $arg->{return}->{error} = 'Left address can not be the address of VPN server itself.';
  } elsif ( $arg->{vpn}->{net}->nth(1) eq $r ) {

    $arg->{return} = 0; # $arg->{return}->{error} = 'NONWIN CONFIG';

  } else {
    $arg->{net} = new Net::Netmask ( $l . '/30');
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

wrapper to place a form into a button for the data to be displayed

    uri holds form action
    dn is object DN to be passed to the action

=cut

sub search_result_item_as_button {
  my ($self, $args) = @_;

  my $arg = { uri => $args->{uri},
	      dn => $args->{dn},
	      css_frm => $args->{css_frm} || '',
	      css_btn => $args->{css_btn} || '', };
  
  return sprintf('<form role="form" method="POST" action="%s" class="%s"><button type="submit" class="btn %s umi-search" title="account with the same addresses" name="ldap_subtree" value="%s">%s</button></form>',
		 $arg->{uri}, # $c->uri_for_action('searchby/index'),
		 $arg->{css_frm},
		 $arg->{css_btn},
		 $arg->{dn},
		 $arg->{dn});

}

=head1 AUTHOR

Zeus

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

######################################################################

1;

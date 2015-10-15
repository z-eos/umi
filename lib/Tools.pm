# -*- mode: cperl -*-
#

package Tools;
use Moose::Role;



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


=head2 regex

regexps and other variables

=cut

has 'regex' => ( traits => ['Hash'], is => 'ro', isa => 'HashRef', builder => '_build_regex', );

sub _build_regex {
  my $self = shift;

  return {
	  sshpubkey => { type => qr/ssh-rsa|ssh-dss|ssh-ed25519|ecdsa-\S+/,
			 id => "[a-zA-Z_][a-zA-Z0-9_-]+",
			 base64 => "[A-Za-z0-9+/]", },
	 }
}


=head2 utf2lat

utf8 input (cyrillic in particular) to latin1 transliteration

=cut

sub utf2lat {
  my ($self, $to_translit) = @_;
  # noLingva # use utf8;
  # noLingva # use Text::Unidecode;
  # noLingva # # Catalyst provides utf8::encoded data! here we need them to
  # noLingva # # utf8::decode to make them suitable for unidecode, since it expects
  # noLingva # # utf8::decode input
  # noLingva # utf8::decode( $to_translit );
  # noLingva # my $a = unidecode( $to_translit );

  use Lingua::Translit;
  # "ALA-LC RUS", "GOST 7.79 RUS", "DIN 1460 RUS"
  my $tr = new Lingua::Translit("GOST 7.79 RUS");
  $a = $tr->translit( $to_translit );

  # remove non-alphas (like ' and `)
  $a =~ tr/a-zA-Z0-9\,\.\_\-\ \@\#\%\*\(\)\!//cds;
  return $a;
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
  my $pwdgen = {
		pwd => $args->{'pwd'},
		len => $args->{'len'} || UMI->config->{pwd}->{len},
		num => $args->{'num'} || UMI->config->{pwd}->{num},
		cap => $args->{'cap'} || UMI->config->{pwd}->{cap},
		cnt => $args->{'cnt'} || UMI->config->{pwd}->{cnt},
		salt => $args->{'salt'} || UMI->config->{pwd}->{salt},
		pronounceable => $args->{'pronounceable'} || UMI->config->{pwd}->{pronounceable},
	       };

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
  open FILE, $file || do { push @{$final_message->{error}}, "Can not open $file: $!"; exit 1; };
  if ( defined $return_as_arr && $return_as_arr == 1 ) {
    while (<FILE>) {
      chomp;
      push @file_in_arr, $_;
    }
  } else {
    local $/ = undef;
    $file_in_str = <FILE>;
  }
  close FILE || do { push @{$final_message->{error}}, "$!"; exit 1; };
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
    push $field_arr, $field;
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
hexadecimal digits without delimiter. For the examples above it will
look: 0123456789ab

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


=head1 AUTHOR

Zeus

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

######################################################################

1;

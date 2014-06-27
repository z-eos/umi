package Tools;
use Moose::Role;

sub is_ascii {
  my ($self, $arg) = @_;
  # return $arg =~ /[^[:ascii:]]/ ? 1 : 0;
  return $arg =~ /[^[:ascii:]]$/;
}

=head2 cyr2lat

cyrillic input transliteration to latin1

works only for translit table set! so UK input will not be
transliterated correctly for default translit table!

=cut

sub cyr2lat {
  my ($self, $args) = @_;

  my $arg = {
	      to_translate => $args->{'to_translate'},
	      translit_table => $args->{'translit_table'} || 'GOST 7.79 RUS',
	     };

  use Lingua::Translit;
  my $tr = new Lingua::Translit($arg->{'translit_table'});
  return $tr->translit($arg->{'to_translate'});
}

# sub c2l {
#   my ($self, $to_translit) = @_;

#   use utf8;
#   use Text::Unidecode;

#   return utf8::encode( unidecode( $to_translit ));
# }

# sub if_cyr {

# }

sub is_int {
  my ($self, $arg) = @_;
  return $arg !~ /^\d+$/ ? 1 : 0;
}

sub pwdgen {
  my ( $self, $args ) = @_;
  my $pwdgen = {
		pwd => $args->{'pwd'},
		len => $args->{'len'} || 12,
		num => $args->{'num'} || 3,
		cap => $args->{'cap'} || 4,
		cnt => $args->{'cnt'} || 1,
		salt => $args->{'salt'} || '123456789',
		pronounceable => $args->{'pronounceable'} || 1,
	       };

  use Crypt::GeneratePassword qw(word word3 chars);

  if ( not defined $pwdgen->{'pwd'} and defined $pwdgen->{'pronounceable'} ) {
    $pwdgen->{'pwd'} = word3( $pwdgen->{'len'},
			    $pwdgen->{'len'},
			    'en',
			    $pwdgen->{'num'},
			    $pwdgen->{'cap'}
			  );
  } elsif ( not defined $pwdgen->{'pwd'} ) {
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

## !!! to adapt !!!
# sub is_arr_member {
#     my @arr = shift;
#     my $member = shift;
#     my %hash;
#     @hash{@arr} = ();
#     dbgmsg(5, Dumper(@arr));
#     exists $hash{$member} ? return 1 : return 0;
# }

######################################################################

1;

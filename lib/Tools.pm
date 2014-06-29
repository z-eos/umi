package Tools;
use Moose::Role;

has 'equality2type' => ( is => 'ro',
			 isa => 'HashRef',
			 builder => '_build_equality2type',
		       );

sub _build_equality2type {

return {
	bitStringMatch => {
			    field_type => 'Text',
			    validationrule => [ '' ],
			   },
	booleanMatch  => {
			  field_type => 'CheckBox',
			  validationrule => [ '' ],
			 },
	caseExactIA5Match  => {
			       field_type => 'Text',
			       validationrule => [ '' ],
			      },
	caseExactIA5SubstringsMatch  => {
					 field_type => 'Text',
					 validationrule => [ '' ],
					},
	caseExactMatch  => {
			    field_type => 'Text',
			    validationrule => [ '' ],
			   },
	caseExactOrderingMatch  => {
				    field_type => 'Text',
				    validationrule => [ '' ],
				   },
	caseExactSubstringsMatch  => {
				      field_type => 'Text',
				      validationrule => [ '' ],
				     },
	caseIgnoreIA5Match  => {
				field_type => 'Text',
				validationrule => [ '' ],
			       },
	caseIgnoreIA5SubstringsMatch  => {
					  field_type => 'Text',
					  validationrule => [ '' ],
					 },
	caseIgnoreListMatch  => {
				 field_type => 'Text',
				 validationrule => [ '' ],
				},
	caseIgnoreMatch  => {
			     field_type => 'Text',
			     validationrule => [ '' ],
			    },
	caseIgnoreOrderingMatch  => {
				     field_type => 'Text',
				     validationrule => [ '' ],
				    },
	caseIgnoreSubstringsMatch  => {
				       field_type => 'Text',
				       validationrule => [ '' ],
				      },
	certificateExactMatch  => {
				   field_type => 'File',
				   validationrule => [ '' ],
				  },
	certificateListExactMatch  => {
				       field_type => 'File',
				       validationrule => [ '' ],
				      },
	distinguishedNameMatch  => {
				    field_type => 'Text',
				    validationrule => [ '' ],
				   },
	generalizedTimeMatch  => {
				  field_type => 'DateTime',
				  validationrule => [ 'YYYYmmDDHHMMSSZ' ],
				 },
	generalizedTimeOrderingMatch  => {
					  field_type => 'DateTime',
					  validationrule => [ 'YYYYmmDDHHMMSSZ' ],
					 },
	integerBitAndMatch  => {
				field_type => 'Integer',
				validationrule => [ '' ],
			       },
	integerBitOrMatch  => {
			       field_type => 'Integer',
			       validationrule => [ '' ],
			      },
	integerFirstComponentMatch  => {
					field_type => 'Integer',
					validationrule => [ '' ],
				       },
	integerMatch  => {
			  field_type => 'Integer',
			  validationrule => [ '' ],
			 },
	integerOrderingMatch  => {
				  field_type => 'Integer',
				  validationrule => [ '' ],
				 },
	numericStringMatch  => {
				field_type => 'Integer',
				validationrule => [ '' ],
			       },
	numericStringOrderingMatch  => {
					field_type => 'Integer',
					validationrule => [ '' ],
				       },
	numericStringSubstringsMatch  => {
					  field_type => 'Integer',
					  validationrule => [ '' ],
					 },
	octetStringMatch  => {
			      field_type => '',
			      validationrule => [ '' ],
			     },
	octetStringOrderingMatch  => {
				      field_type => '',
				      validationrule => [ '' ],
				     },
	octetStringSubstringsMatch  => {
					field_type => '',
					validationrule => [ '' ],
				       },
	telephoneNumberMatch  => {
				  field_type => 'Text',
				  validationrule => [ '' ],
				 },
	telephoneNumberSubstringsMatch  => {
					    field_type => 'Text',
					    validationrule => [ '' ],
					   },
	uniqueMemberMatch  => {
			       field_type => 'Text',
			       validationrule => [ '' ],
			      },
       };

}

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

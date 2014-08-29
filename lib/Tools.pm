# -*- mode: cperl -*-
#

package Tools;
use Moose::Role;

# has 'equality2type' => ( traits => ['Hash'],
# 			 is => 'ro',
# 			 isa => 'HashRef',
# 			 builder => '_build_equality2type',
# 		       );

# sub _build_equality2type {

# return {
# 	bitStringMatch => {
# 			    field_type => 'Text',
# 			    validationrule => [ '' ],
# 			   },
# 	booleanMatch  => {
# 			  field_type => 'CheckBox',
# 			  validationrule => [ '' ],
# 			 },
# 	caseExactIA5Match  => {
# 			       field_type => 'Text',
# 			       validationrule => [ '' ],
# 			      },
# 	caseExactIA5SubstringsMatch  => {
# 					 field_type => 'Text',
# 					 validationrule => [ '' ],
# 					},
# 	caseExactMatch  => {
# 			    field_type => 'Text',
# 			    validationrule => [ '' ],
# 			   },
# 	caseExactOrderingMatch  => {
# 				    field_type => 'Text',
# 				    validationrule => [ '' ],
# 				   },
# 	caseExactSubstringsMatch  => {
# 				      field_type => 'Text',
# 				      validationrule => [ '' ],
# 				     },
# 	caseIgnoreIA5Match  => {
# 				field_type => 'Text',
# 				validationrule => [ '' ],
# 			       },
# 	caseIgnoreIA5SubstringsMatch  => {
# 					  field_type => 'Text',
# 					  validationrule => [ '' ],
# 					 },
# 	caseIgnoreListMatch  => {
# 				 field_type => 'Text',
# 				 validationrule => [ '' ],
# 				},
# 	caseIgnoreMatch  => {
# 			     field_type => 'Text',
# 			     validationrule => [ '' ],
# 			    },
# 	caseIgnoreOrderingMatch  => {
# 				     field_type => 'Text',
# 				     validationrule => [ '' ],
# 				    },
# 	caseIgnoreSubstringsMatch  => {
# 				       field_type => 'Text',
# 				       validationrule => [ '' ],
# 				      },
# 	certificateExactMatch  => {
# 				   field_type => 'File',
# 				   validationrule => [ '' ],
# 				  },
# 	certificateListExactMatch  => {
# 				       field_type => 'File',
# 				       validationrule => [ '' ],
# 				      },
# 	distinguishedNameMatch  => {
# 				    field_type => 'Text',
# 				    validationrule => [ '' ],
# 				   },
# 	generalizedTimeMatch  => {
# 				  field_type => 'DateTime',
# 				  validationrule => [ 'YYYYmmDDHHMMSSZ' ],
# 				 },
# 	generalizedTimeOrderingMatch  => {
# 					  field_type => 'DateTime',
# 					  validationrule => [ 'YYYYmmDDHHMMSSZ' ],
# 					 },
# 	integerBitAndMatch  => {
# 				field_type => 'Integer',
# 				validationrule => [ '' ],
# 			       },
# 	integerBitOrMatch  => {
# 			       field_type => 'Integer',
# 			       validationrule => [ '' ],
# 			      },
# 	integerFirstComponentMatch  => {
# 					field_type => 'Integer',
# 					validationrule => [ '' ],
# 				       },
# 	integerMatch  => {
# 			  field_type => 'Integer',
# 			  validationrule => [ '' ],
# 			 },
# 	integerOrderingMatch  => {
# 				  field_type => 'Integer',
# 				  validationrule => [ '' ],
# 				 },
# 	numericStringMatch  => {
# 				field_type => 'Integer',
# 				validationrule => [ '' ],
# 			       },
# 	numericStringOrderingMatch  => {
# 					field_type => 'Integer',
# 					validationrule => [ '' ],
# 				       },
# 	numericStringSubstringsMatch  => {
# 					  field_type => 'Integer',
# 					  validationrule => [ '' ],
# 					 },
# 	octetStringMatch  => {
# 			      field_type => '',
# 			      validationrule => [ '' ],
# 			     },
# 	octetStringOrderingMatch  => {
# 				      field_type => '',
# 				      validationrule => [ '' ],
# 				     },
# 	octetStringSubstringsMatch  => {
# 					field_type => '',
# 					validationrule => [ '' ],
# 				       },
# 	telephoneNumberMatch  => {
# 				  field_type => 'Text',
# 				  validationrule => [ '' ],
# 				 },
# 	telephoneNumberSubstringsMatch  => {
# 					    field_type => 'Text',
# 					    validationrule => [ '' ],
# 					   },
# 	uniqueMemberMatch  => {
# 			       field_type => 'Text',
# 			       validationrule => [ '' ],
# 			      },
#        };

# }

sub is_ascii {
  my ($self, $arg) = @_;
  return $arg !~ /^[[:ascii:]]+$/ if defined $arg && $arg ne '';
}

=head2 cyr2lat

cyrillic input transliteration to latin1

works only for translit table set! so UK input will not be
transliterated correctly for default translit table!

=cut

# sub cyr2lat {
#   my ($self, $args) = @_;

#   my $arg = {
# 	      to_translate => $args->{'to_translate'},
# 	      translit_table => $args->{'translit_table'} || 'GOST 7.79 RUS',
# 	     };

#   use Lingua::Translit;
#   my $tr = new Lingua::Translit($arg->{'translit_table'});
#   return $tr->translit($arg->{'to_translate'});
# }

sub utf2lat {
  my ($self, $to_translit) = @_;

  use utf8;
  use Text::Unidecode;

  utf8::decode( $to_translit );

  return unidecode( $to_translit );
}

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

  if ( ! defined $pwdgen->{'pwd'} && defined $pwdgen->{'pronounceable'} ) {
    $pwdgen->{'pwd'} = word3( $pwdgen->{'len'},
			    $pwdgen->{'len'},
			    'en',
			    $pwdgen->{'num'},
			    $pwdgen->{'cap'}
			  );
  } elsif ( ! defined $pwdgen->{'pwd'} ) {
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

# to be removed #   use Digest::SHA1;
# to be removed #   my $sha1 = Digest::SHA1->new;
# to be removed #   $sha1->add(
# to be removed # 	     $pwdgen->{'pwd'},
# to be removed # 	     $pwdgen->{'salt'},
# to be removed # 	    );
# to be removed # 
# to be removed #   return {
# to be removed # 	  clear => $pwdgen->{'pwd'},
# to be removed # 	  ssha => '{SSHA}' . $sha1->b64digest
# to be removed # 	 };
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

# sub meta_options {
#   my ( $self, $args ) = @_;
#   my $arg = {
# 	     dn => $args->[0],
# 	     root => $args->[1],
# 	     root_suffix => $args->[2],
# 	     attr1 => $args->[3],
# 	     attr1_suffix => $args->[4],
# 	     attr2 => $args->[5],
# 	     attr2_suffix => $args->[6],
# 	     attr3 => $args->[5],
# 	     attr3_suffix => $args->[6],
# 	    };

#     @dn_arr = split(',',$arg-{'dn'});
#     if ( scalar @dn_arr < 4 ) {
#       $label = sprintf("%s %s %s %s %s %s)",
# 		       $arg->{'root'},
# 		       $arg->{'root_suffix'},
# 		       $arg->{'attr2'},
# 		       $arg->{'attr2_suffix'},
# 		       $arg->{'attr3'},
# 		       $arg->{'attr3_suffix'},
# 		      );
#     } elsif ( scalar @dn_arr == 4 ) {
#       $label = sprintf("%s %s %s %s %s %s) branch of %s",
# 		       $arg->{'attr1'},
# 		       $arg->{'attr1_suffix'},
# 		       $arg->{'attr2'},
# 		       $arg->{'attr2_suffix'},
# 		       $arg->{'attr3'},
# 		       $arg->{'attr3_suffix'},

# 		       $entry->get_value ('ou'),
# 		       $entry->get_value ('physicaldeliveryofficename'),
# 		       $entry->get_value ('l'),
# 		       substr($dn_arr[1],3)
# 		      );
#     } else {
#       for ( $i = 1, $dn = ''; $i < scalar @dn_arr - 2; $i++ ) {
# 	$dn .= $dn_arr[$i];
#       }
#       $a = $dn =~ s/ou=/ -> /g;
#       $label = sprintf("%s (%s @ %s) branch of %s",
# 		       $entry->get_value ('ou'),
# 		       $entry->get_value ('physicaldeliveryofficename'),
# 		       $entry->get_value ('l'),
# 		       $dn
# 		      );
#     }

# }

######################################################################

1;

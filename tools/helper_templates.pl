#!/usr/bin/env perl

## helper_templates.pl - Description of module
# Created by: Charlie Garrison
#       Orig: 15/02/14
# Copyright:  Copyright (c) 2009 Garrison Computer Services
# 			  All Rights Reserved.
#  $Revision: 244 $
#    $Author: charlie $
#      $Date: 2014-03-24 12:56:25 +1100 (Mon, 24 Mar 2014) $
#-----------------------------------------------------------------------
#    Purpose: 
#    History: 
#-----------------------------------------------------------------------
# $Log: $
#
#-----------------------------------------------------------------------

use common::sense;

use FindBin;
# use lib "$FindBin::Bin/../lib";

use Data::Printer;
use Getopt::Long;
use Pod::Usage;
use Template;

our $VERSION = (qw$Revision: 244 $)[-1];

## Parse options and print usage if there is a syntax error,
## or if usage was explicitly requested.
my %opts = ();
## set default values
$opts{tmpldir}       = './templates/';
$opts{tmplname}      = '';
$opts{outdir}        = '../../MyApp/';
$opts{outname}       = '';
$opts{class_si}      = '';               #singular
$opts{class_pl}      = '';               #plural
$opts{root_dir_part} = '';               #dir part for files under root/
## set list of required values
my @opts_required = qw/ tmpldir tmplname outdir outname class_si class_pl root_dir_part /;

GetOptions(  \%opts,
			 "tmpldir=s",
			 "tmplname=s",
			 "outdir=s",
			 "outname=s",
             "class_si|classsi=s",
			 "class_pl|classpl=s",
			 "root_dir_part|rootdirpart|dir_part|dirpart=s",
			 "force!",
			 "isadmin!",
			 "help|?",
			 "man|manpage",
			 "debug:i",
	      ) || pod2usage(2);

pod2usage(1)              if ( exists($opts{help}) );
pod2usage(-verbose => 2)  if ( exists($opts{man}) );
foreach my $opt (@opts_required) { pod2usage("Option not specified: $opt") unless defined($opts{$opt}); }
pod2usage("Value \"$opts{debug}\" invalid for option debug (number from 1 to 3 expected)") if (defined($opts{debug}) && ($opts{debug} < 0 || $opts{debug} > 3));

$opts{debug}    = 1 if (defined($opts{debug}) && $opts{debug} == 0);
$opts{debug}    ||= 0;	# we need debug to be defined to supress warnings
warn p(%opts)."\n" if $opts{debug} >= 1; 

if (-e "$opts{outdir}/$opts{outname}" && ! $opts{force}) {
	die "Output file already exists: $opts{outdir}/$opts{outname}";
}

## example usage
# ./tools/helper_templates.pl --class_si=Organization --class_pl=Organizations \
#   --tmpldir=./helper-templates       --outdir=. \
#   --tmplname=lib/Forms/PerlClass.pm  --outname=lib/UMI/Forms/${PerlClass}.pm

my $tt = Template->new(
	{
		INCLUDE_PATH => $opts{tmpldir},
		INTERPOLATE  => 0,
		TAG_STYLE   => 'template',
# 		(
# 			$opts{tmplname} =~ m/.*\.tt2$/
# 			? (
# # 				START_TAG => '[@',
# # 				END_TAG   => '@]',
# # 				START_TAG => '[*',
# # 				END_TAG   => '*]',
# 				TAG_STYLE   => 'star',
# 			  )
# 			: ()
# 		),
	}
  )
  || die "$Template::ERROR\n";

my $vars = {
	class_si      => $opts{class_si},
	class_pl      => $opts{class_pl},
	root_dir_part => $opts{root_dir_part},
};

my $output;
$tt->process( $opts{tmplname}, $vars, \$output )
  || die $tt->error(), "\n";

open( my $fh, ">", "$opts{outdir}/$opts{outname}" )
  or die "cannot open > output.txt: $!";

print $fh $output;

close $fh;



exit(0);


1;
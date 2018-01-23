# -*- mode: cperl -*-
#

package Logger;

use utf8;
use Data::Printer;
use Try::Tiny;
use POSIX qw(strftime);

use base 'Log::Contextual';

#use Log::Log4perl ':easy';
#Log::Log4perl->easy_init($DEBUG);

use Log::Log4perl qw(:levels :easy);

my $appender_file = q(
  log4perl.logger                       = DEBUG, LogFileDebug
  log4perl.appender.LogFileDebug            = Log::Log4perl::Appender::File
  log4perl.appender.LogFileDebug.layout     = PatternLayout
  log4perl.appender.LogFileDebug.layout.ConversionPattern = %d{yyyy.MM.DD HH:mm:ss} %p: %F{2}:%L %M:%n%m%n
  log4perl.appender.LogFileDebug.recreate   = 1
  log4perl.appender.LogFileDebug.mkpath     = 1
  log4perl.appender.LogFileDebug.filename   = /tmp/umi/umi.log
  log4perl.appender.LogFileDebug.mode       = append
  log4perl.appender.LogFileDebug.utf8       = 1

  log4perl.logger                       = DEBUG, LogFileInfo
  log4perl.appender.LogFileInfo            = Log::Log4perl::Appender::File
  log4perl.appender.LogFileInfo.layout     = PatternLayout
  log4perl.appender.LogFileInfo.layout.ConversionPattern = %d{yyyy.MM.DD HH:mm:ss} %p: %F{2}:%L %M:%n%m%n
  log4perl.appender.LogFileInfo.recreate   = 1
  log4perl.appender.LogFileInfo.mkpath     = 1
  log4perl.appender.LogFileInfo.filename   = /tmp/umi/umi.log
  log4perl.appender.LogFileInfo.mode       = append
  log4perl.appender.LogFileInfo.utf8       = 1
);

Log::Log4perl::init( \$appender_file );




sub arg_default_logger { $_[1] || Log::Log4perl->get_logger }

sub arg_levels { [qw(debug trace warn info error fatal)] }

sub default_import { ':log' }

# or maybe instead of default_logger
sub arg_package_logger { $_[1] }

# and almost definitely not this, which is only here for completeness
sub arg_logger { $_[1] }




















# use base 'Log::Contextual';
# # use Log::Contextual;
# use Log::Log4perl qw(:levels :easy);

# my $appender_file =
#   Log::Log4perl::Appender->new(
# 			       "Log::Log4perl::Appender::File",
# 			       name       => "umi_log",
# 			       filename   => '/tmp/umi/umi.log',
# 			       mode       => 'append',
# 			       additivity => 0,
# 			       utf8       => 1,
# 			      );

# Log::Log4perl::init( \$appender_file );


# sub arg_default_logger { $_[1] || Log::Log4perl->get_logger }

# sub arg_levels { [qw(debug trace warn info error fatal custom_level)] }

# sub default_import { ':log' }

# # or maybe instead of default_logger
# sub arg_package_logger { $_[1] }

# # and almost definitely not this, which is only here for completeness
# sub arg_logger { $_[1] }


=head1 AUTHOR

Zeus

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

######################################################################

1;

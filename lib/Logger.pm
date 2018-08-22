# -*- mode: cperl -*-
#

package Logger;

use Data::Printer;

use Log::Log4perl qw(:levels :easy);
use Log::Log4perl::Layout;
use Log::Log4perl::Level;
use Log::Log4perl::Filter;
use Log::Log4perl::Filter::LevelRange;
use Log::Log4perl::Filter::LevelMatch;
use Log::Log4perl::InternalDebug;

use base qw(Log::Dispatch::Output);
use base 'Log::Contextual';

### DEBUG, INFO, WARN, ERROR, FATAL

###=== APPENDER FILE ==================================================
my $apn_file =
  Log::Log4perl::Appender->new(
			       "Log::Log4perl::Appender::File",
			       name       => 'appndr_f',
			       filename   => '/var/log/umi/umi-apnd-file.log', # UMI->config->{log}->{file},
			       mode       => 'append',
			       additivity => 0,
			       utf8       => 1,
			       syswrite   => 1,
			       recreate   => 1,
			       mkpath     => 1
			      );

my $flt_file =
  Log::Log4perl::Filter::LevelMatch->new(
					 LevelToMatch  => 'DEBUG',
					 AcceptOnMatch => true
					);
$apn_file->filter($flt_file);

my $layout_file =
  Log::Log4perl::Layout::PatternLayout->new( "%d{yyyy.MM.dd HH:mm:ss} [%p]: L%05L @ %F{2}: %m{chomp}%n%n" );

$apn_file->layout($layout_file);


### === APPENDER SYSLOG ================================================
my $apn_sysl =
  Log::Log4perl::Appender->new(
			       "Log::Dispatch::Syslog",
			       ident      => 'UMI',
			       facility   => 'local2'
			      );

my $flt_sysl =
  Log::Log4perl::Filter::LevelRange->new(
					 LevelMin      => 'INFO',
					 LevelMax      => 'FATAL',
					 AcceptOnMatch => true
					);
$apn_sysl->filter($flt_sysl);

my $layout_sysl =
  Log::Log4perl::Layout::PatternLayout->new( "[%p]: L%05L @ %F{2}: %m{chomp}" );

$apn_sysl->layout($layout_sysl);

### === APPENDER SCREEN ================================================
my $apn_scrn =
  Log::Log4perl::Appender->new(
			       "Log::Log4perl::Appender::ScreenColoredLevels"
			      );

$apn_scrn->filter($flt_sysl);

my $layout_scrn =
  Log::Log4perl::Layout::PatternLayout->new( "%d{yyyy.MM.dd HH:mm:ss} [%p]: L%05L @ %F{2}: %m{chomp}%n%n" );

$apn_scrn->layout($layout_scrn);




get_logger->add_appender($apn_file);
get_logger->add_appender($apn_sysl);
get_logger->add_appender($apn_scrn);

get_logger->level($TRACE);

sub arg_default_logger { $_[1] || Log::Log4perl->get_logger }
sub arg_levels { [qw(off fatal error warn info debug trace all)] }
sub default_import { ':log' }


=head1 AUTHOR

Zeus

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

######################################################################

1;

# -*- mode: cperl -*-
#

package Logger;

use Log::Log4perl qw(:levels :easy);

use base qw(Log::Dispatch::Output);
use base 'Log::Contextual';

### OFF FATAL ERROR WARN INFO DEBUG TRACE ALL
### DEBUG, INFO, WARN, ERROR, FATAL

Log::Log4perl::init(\ <<'EOT');

  log4perl.logger                        = TRACE, apn_sysl, apn_file, apn_scrn

  log4perl.filter.flt_sysl               = Log::Log4perl::Filter::LevelRange
  log4perl.filter.flt_sysl.LevelMin      = INFO
  log4perl.filter.flt_sysl.LevelMax      = FATAL
  log4perl.filter.flt_sysl.AcceptOnMatch = true
  
  log4perl.filter.flt_file               = Log::Log4perl::Filter::LevelMatch
  log4perl.filter.flt_file.LevelToMatch  = DEBUG
  log4perl.filter.flt_file.AcceptOnMatch = true

  log4perl.appender.apn_scrn             = Log::Log4perl::Appender::ScreenColoredLevels  
  log4perl.appender.apn_scrn.layout      = PatternLayout
  log4perl.appender.apn_scrn.layout.ConversionPattern = %d{yyyy.MM.DD HH:mm:ss} [%p]: L%05L @ %F{2}: %m{chomp}%n%n
  log4perl.appender.apn_scrn.Filter      = flt_sysl

  log4perl.appender.apn_file             = Log::Log4perl::Appender::File
  log4perl.appender.apn_file.layout      = PatternLayout
  log4perl.appender.apn_file.layout.ConversionPattern = %d{yyyy.MM.DD HH:mm:ss} [%p]: L%05L @ %F{2}: %m{chomp}%n%n
  log4perl.appender.apn_file.recreate    = 1
  log4perl.appender.apn_file.mkpath      = 1
  log4perl.appender.apn_file.filename    = /tmp/umi/umi-transcript.log
  log4perl.appender.apn_file.mode        = append
  log4perl.appender.apn_file.utf8        = 1
  log4perl.appender.apn_file.additivity  = 0
  log4perl.appender.apn_file.Filter      = flt_file

  log4perl.appender.apn_sysl             = Log::Dispatch::Syslog
  log4perl.appender.apn_sysl.ident       = UMI
  log4perl.appender.apn_sysl.facility    = local2
  log4perl.appender.apn_sysl.layout      = PatternLayout
  log4perl.appender.apn_sysl.layout.ConversionPattern = [%p]: L%05L @ %F{2}: %m{chomp}
  log4perl.appender.apn_sysl.Filter      = flt_sysl

EOT


sub arg_default_logger { $_[1] || Log::Log4perl->get_logger }
sub arg_levels { [qw(fatal error warn info debug)] }
sub default_import { ':log' }


=head1 AUTHOR

Zeus

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

######################################################################

1;

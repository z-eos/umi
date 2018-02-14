# -*- mode: cperl -*-
#

package Trapper;

use Log::Log4perl qw(:levels :easy);
use Log::Log4perl::Layout;
use Log::Log4perl::Level;
use Log::Log4perl::Filter;
use Log::Log4perl::Filter::LevelMatch;

### DEBUG, INFO, WARN, ERROR, FATAL

###=== APPENDER FILE ==================================================
my $apn_file =
  Log::Log4perl::Appender->new(
			       "Log::Log4perl::Appender::File",
			       name       => 'appndr_f',
			       filename   => '/var/log/umi/umi-stderr-redirect.log',
			       mode       => 'append',
			       additivity => 0,
			       utf8       => 1,
			       syswrite   => 0,
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
#  Log::Log4perl::Layout::PatternLayout->new( "%m" );
  Log::Log4perl::Layout::PatternLayout->new( "%d{yyyy.MM.dd HH:mm:ss} [%p]: L%05L @ %M: %F{2}: %m{chomp}%n" );

$apn_file->layout($layout_file);

get_logger->add_appender($apn_file);
get_logger->level($TRACE);

sub TIEHANDLE {
  my $class = shift;
  bless [], $class;
}

sub PRINT {
  my $self = shift;
  $Log::Log4perl::caller_depth++;
  DEBUG @_;
  $Log::Log4perl::caller_depth--;
}

sub PRINTF {
  my $self = shift;
  my $fmt = shift;
  $Log::Log4perl::caller_depth++;
  DEBUG CORE::print sprintf($fmt, @_);
  $Log::Log4perl::caller_depth--;
}

sub BINMODE {
  my $self = shift;

  $Log::Log4perl::caller_depth++;
  DEBUG @_;
  $Log::Log4perl::caller_depth--;
}

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

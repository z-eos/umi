# -*- mode: cperl -*-
#

package Logger;

use utf8;
use Data::Printer;
use Try::Tiny;
use POSIX qw(strftime);

# use base 'Log::Contextual';
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($DEBUG);
my $logger  = Log::Log4perl->get_logger;
set_logger $logger;




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

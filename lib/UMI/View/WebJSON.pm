# -*- mode: cperl; mode: follow; -*-
#

package UMI::View::WebJSON;

use strict;
use base 'Catalyst::View::JSON';

__PACKAGE__->config({
		     # allow_callback  => 1,
		     # callback_param  => 'cb',
		     expose_stash    => [ qw( success message tree ) ],
		    });

=head1 NAME

UMI::View::WebJSON - Catalyst JSON View

=head1 SYNOPSIS

See L<UMI>

=head1 DESCRIPTION

Catalyst JSON View.

=head1 AUTHOR

Zeus Panchenko

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;

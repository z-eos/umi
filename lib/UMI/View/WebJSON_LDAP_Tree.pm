# -*- mode: cperl; mode: follow; -*-
#

package UMI::View::WebJSON_LDAP_Tree;

use strict;
use base 'Catalyst::View::JSON';

__PACKAGE__->config({
		     # json_encoder_args => { utf8      => 1,
		     # 			    pretty    => 1,
		     # 			    canonical => 1, },
		     expose_stash      => qr/^json_/,
#		     expose_stash      => 'tree',
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

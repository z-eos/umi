#-*- cperl -*-
#

package UMI::View::Download;
use Moose;
use namespace::autoclean;

extends 'Catalyst::View::Download';

__PACKAGE__->config(
		    {
		     content_type => {
				       'text/plain' => { outfile_ext => '', },
				      # 'text/vcard' => { outfile_ext => 'vcf',  },
				     },
		    }
		   );

# log_debug { np($c->stash) };

=head1 NAME

UMI::View::Download - Download View for UMI

=head1 DESCRIPTION

Download View as file.

=head1 SEE ALSO

L<UMI>

=head1 AUTHOR

Zeus Panchenko

=head1 LICENSE

This library is free software. You can redistribute it and/or modify it under the same terms as Perl itself.

=cut

1;

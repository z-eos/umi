# -*- mode: cperl; mode: follow; -*-
#

package UMI::Controller::ToolPwdgen;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; with 'Tools'; }

use UMI::Form::ToolPwdgen;
has 'form' => (
	       isa => 'UMI::Form::ToolPwdgen', is => 'rw',
	       lazy => 1, documentation => q{Form to translit text},
	       default => sub { UMI::Form::ToolPwdgen->new },
	      );


=head1 NAME

UMI::Controller::ToolPwdgen - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut



=head2 index

new Text Pwdgen

=cut


sub index :Path :Args(0) {
    my ( $self, $c ) = @_;
    my $params = $c->req->parameters;
    
    $c->stash( template => 'tool/toolpwdgen.tt',
	       form => $self->form );

    return unless
      $self->form->process(
			   posted => ($c->req->method eq 'POST'),
			   params => $params,
			  );

    my $pwd = $self->pwdgen({
			     len => $params->{'pwd_len'},
			     num => $params->{'pwd_num'},
			     cap => $params->{'pwd_cap'},
			     pronounceable => defined $params->{pronounceable} ? $params->{pronounceable} : 0,
			    });

    my $final_message->{success} = 'Password generated:<table class="table table-vcenter"><tr><td width="50%"><h1 class="mono text-center">' .
      $pwd->{clear} . '</h1></td><td class="text-center" width="50%">';

    use GD::Barcode::QRcode;
    use MIME::Base64;
    my $qr = sprintf('<img alt="password" src="data:image/jpg;base64,%s" class="img-responsive" title="password"/>',
		     encode_base64(GD::Barcode::QRcode
				   ->new( $pwd->{clear},
					  { Ecc => 'Q', Version => 6, ModuleSize => 8 } )
				   ->plot()->png)
		    );
    $final_message->{success} .= $qr . '</td></tr></table>';
    $c->stash( final_message => $final_message );
}

=head1 AUTHOR

Charlie &

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;

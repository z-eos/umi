# -*- mode: cperl; mode: follow; -*-
#

package UMI::Controller::ToolImportLDIF;
use Moose;
use namespace::autoclean;

use Data::Printer;

BEGIN { extends 'Catalyst::Controller'; with 'Tools'; }

use UMI::Form::ToolImportLDIF;
has 'form' => (
	       isa => 'UMI::Form::ToolImportLDIF', is => 'rw',
	       lazy => 1, documentation => q{Form to import LDIF},
	       default => sub { UMI::Form::ToolImportLDIF->new },
	      );


=head1 NAME

UMI::Controller::ToolImportLDIF - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut



=head2 index

Import LDIF from file or TextArea field

=cut


sub index :Path :Args(0) {
    my ( $self, $c ) = @_;
    my $params = $c->req->parameters;
    $params->{file} = $c->req->upload('file') if $params->{file};

    $c->stash( template => 'tool/toolimportldif.tt',
	       form => $self->form );

    return unless
      $self->form->process(
			   posted => ($c->req->method eq 'POST'),
			   params => $params,
			  );
    my $final_message;
    $final_message = $c->model('LDAP_CRUD')->ldif_read( { file => $params->{file}->{tempname} } )
      if defined $params->{file};
    $final_message = $c->model('LDAP_CRUD')->ldif_read( { ldif => $params->{ldif} } )
      if defined $params->{ldif};

    # my $final_message;
    # push @{$final_message->{success}}, $params->{ldif} if $params->{ldif} ne '';
    # my $ldif_file = $self->file2var($params->{file}->{tempname}, $final_message) if defined $params->{file};
    # push @{$final_message->{success}}, '<pre>' . $ldif_file . '</pre>' if $ldif_file ne '';

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

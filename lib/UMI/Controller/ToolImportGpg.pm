# -*- mode: cperl; mode: follow; -*-
#

package UMI::Controller::ToolImportGpg;
use Moose;
use namespace::autoclean;

use Logger;
use Data::Printer;

BEGIN { extends 'Catalyst::Controller'; with 'Tools'; }

use UMI::Form::ToolImportGpg;
has 'form' => (
	       isa => 'UMI::Form::ToolImportGpg', is => 'rw',
	       documentation => q{Import GPG key}, lazy => 1,
	       default => sub { UMI::Form::ToolImportGpg->new },
	      );


=head1 NAME

UMI::Controller::ToolImportGPG - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut



=head2 index

Import GPG from file or TextArea field

=cut

sub index :Path :Args(0) {
  my ( $self, $c ) = @_;
  my $params = $c->req->parameters;
  $params->{key_file} = $c->req->upload('key_file') if $params->{key_file};

  $c->stash( template => 'tool/toolimportgpg.tt',
	     form => $self->form );

  return unless
    $self->form->process(
			 posted => ($c->req->method eq 'POST'),
			 params => $params,
			);
  my ( $key, $err );

  if ( defined $params->{key_text} && $params->{key_text} ne '' ) {
    $key->{import}->{text} = $params->{key_text};
  }

  if ( defined $params->{key_file} && $params->{key_file} ne '' ) {
    $key->{import}->{file} = $params->{key_file}->{tempname};
  }

  $key->{gpg} = $self->keygen_gpg({ import => $key->{import}, });

  if ( defined $key->{gpg}->{error} ) {
    push @{$key->{html}->{error}}, @{$key->{gpg}->{error}};
  } else {
    my $ldap_crud = $c->model('LDAP_CRUD');
    my ($add_dn, $add_attrs);
    $add_dn = sprintf("pgpCertID=%s,%s",
		      $key->{gpg}->{send_key}->{pgpCertID},
		      $ldap_crud->cfg->{base}->{pgp});
    @{$add_attrs} = map { $_ => $key->{gpg}->{send_key}->{$_} } keys %{$key->{gpg}->{send_key}};
    my $mesg = $ldap_crud->add( $add_dn, $add_attrs );

    push @{$key->{html}->{error}}, $mesg->{html} if $mesg;
  }

  $c->stash( final_message => $key->{html},
	     key           => $key
	   );
}



=head1 AUTHOR

Charlie &

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;

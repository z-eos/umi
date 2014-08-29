# -*- mode: cperl -*-
#

package UMI::Controller::SearchAdvanced;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; with 'Tools'; }

use UMI::Form::SearchAdvanced;

has 'form' => ( isa => 'UMI::Form::SearchAdvanced', is => 'rw',
		lazy => 1, default => sub { UMI::Form::SearchAdvanced->new },
		documentation => q{Form for advanced search},
	      );

=head1 NAME

UMI::Controller::SearchAdvanced - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 index

=cut

sub index :Path :Args(0) {
    my ( $self, $c ) = @_;
    if ( defined $c->session->{"auth_uid"} ) {
      $c->stash(
		template => 'search/search_advanced.tt',
		form => $self->form,
	       );
    } else {
      $c->stash( template => 'signin.tt', );
    }
  }

sub proc :Path(proc) :Args(0) {
    my ( $self, $c ) = @_;

    if ( $c->check_user_roles('wheel')) {
      my $params = $c->req->params;
      my @attrs = split(/,/, $params->{'show_attrs'});
      my $ldap_crud =
	$c->model('LDAP_CRUD');
      my $mesg = $ldap_crud->search(
				    {
				     base => $params->{'base_dn'},
				     filter => $params->{'search_filter'},
				     scope => $params->{'search_scope'},
				     sizelimit => $params->{'search_results'},
				     attrs => \@attrs,
				    }
				   );
      my $err_message = '';
      if ( ! $mesg->count ) {
	$err_message = '<div class="alert alert-danger">' .
	  '<span style="font-size: 140%" class="icon_error-oct" aria-hidden="true"></span><ul>' .
	    $ldap_crud->err($mesg) . '</ul></div>';
      }

      my @entries = $mesg->entries;

      # use Data::Printer;
      # p @entries;

      $c->stash(
		template => 'search/searchby.tt',
		params => $c->req->params,
		entries => \@entries,
		err => $err_message,
		form => $self->form,
	       );

    } elsif ( defined $c->session->{"auth_uid"} ) {
      if ( defined $c->session->{'unauthorized'}->{ $c->action } ) {
	$c->session->{'unauthorized'}->{ $c->action } += 1;
      } else {
	$c->session->{'unauthorized'}->{ $c->action } = 1;
      }
      $c->stash( 'template' => 'unauthorized.tt',
		 'unauth_action' => $c->action, );
    } else {
      $c->stash( template => 'signin.tt', );
    }
  }

=head1 AUTHOR

Zeus

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;

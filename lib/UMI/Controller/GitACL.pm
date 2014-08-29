# -*- mode: cperl -*-
#

package UMI::Controller::GitACL;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; with 'Tools'; }

use UMI::Form::GitACL;

has 'form' => ( isa => 'UMI::Form::GitACL', is => 'rw',
		lazy => 1, default => sub { UMI::Form::GitACL->new },
		documentation => q{Form to add new, nonexistent GitACL/s},
	      );

=head1 NAME

UMI::Controller::User - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 index

=cut

sub index :Path :Args(0) {
    my ( $self, $c, $gitacl_create_id ) = @_;
    if ( $c->check_user_roles('wheel')) {
      # use Data::Dumper;

      $c->stash( template => 'gitacl/gitacl_wrap.tt',
		 form => $self->form );

      my $params = $c->req->parameters;

      # use Data::Dumper;
      # $c->log->debug( "\$params:\n" . Dumper($params));

      # Validate and insert/update database
      return unless $self->form->process( item_id => $gitacl_create_id,
					  posted => ($c->req->method eq 'POST'),
					  params => $params,
					  ldap_crud => $c->model('LDAP_CRUD'),
					);

      # $c->log->debug("Moose::Role test:\n" . $self->is_ascii("latin1"));

      my $res = $self->create_gitacl( $c );
      $c->log->debug( "create_account (from umi_add) error: " . $res) if $res;
    } elsif ( defined $c->session->{"auth_uid"} ) {
      if (defined $c->session->{'unauthorized'}->{ $c->action } ) {
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

=head2 create_account

=cut

sub create_gitacl {
    my  ( $self, $c ) = @_;
    my $args = $c->req->parameters;

    # use Data::Dumper;
    use Data::Printer;
    # $c->log->debug( "\$args:\n" . Dumper($args));
    # p $args;

    my $gitAcl = {
		  Op => join('', @{$args->{gitAclOp}}),
		  Project => $args->{gitAclProject},
		  Ref => $args->{gitAclRef},
		  Verb => $args->{gitAclVerb},
		  User_user => $args->{gitAclUser_user} || '',
		  User_group => $args->{gitAclUser_group} || '',
		  User_cidr => '@' . $args->{gitAclUser_cidr} || '',
		 };

    if ( $gitAcl->{User_user} ne '' ) {
      $gitAcl->{User} = $gitAcl->{User_user};
    } else {
      $gitAcl->{User} = $gitAcl->{User_group};
    }
    $gitAcl->{User} .= $gitAcl->{User_cidr};

    p $gitAcl;

    my $ldap_crud =
      $c->model('LDAP_CRUD');

#
## HERE WE NEED TO SET FLAG TO CREATE BRANCH FOR LOCALIZED VERSION OF DATA
## associatedService=localization-ru,uid=U...-user01,ou=People,dc=ibs
## associatedService=localization-uk,uid=U...-user01,ou=People,dc=ibs
## e.t.c.
#

    my $attrs_defined = [
			 gitAclOp => $gitAcl->{Op},
			 gitAclProject => $gitAcl->{Project},
			 gitAclRef => $gitAcl->{Ref},
			 gitAclVerb => $gitAcl->{Verb},
			 gitAclUser => $gitAcl->{User},
			 objectClass => [ qw( gitACL ) ],
			];

    ######################################################################
    # GitACL Object
    ######################################################################
    my $ldif =
      $ldap_crud->add(
		      'cn=' . $gitAcl->{Project} .
		      ',ou=GitACL,dc=umidb',
		      $attrs_defined,
		     );
    # $c->log->debug( "\$args:\n" . Dumper($args));

    my ( $success_message, $error_message);
    if ( $ldif ) {
      $error_message = '<li>Error during GitACL creation occured: ' . $ldif . '</li>';
      $c->log->debug("error during GitACL obj creation: " . $ldif);
    } else {
      $success_message .= '<li><em>GitACL for project:</em> &laquo;<strong>' .
	$gitAcl->{Project} . '</strong>&raquo; <em>successfully created</em>';
    }

    my $final_message;
    $final_message = '<div class="alert alert-success">' .
      '<span style="font-size: 140%" class="glyphicon glyphicon-ok-sign"></span>' .
	'&nbsp;<em>' . $success_message . '<ul></div>' if $success_message;

    $final_message .= '<div class="alert alert-danger">' .
      '<span style="font-size: 140%" class="icon_error-oct" aria-hidden="true"></span><ul>' .
	$error_message . '</ul></div>' if $error_message;

    $self->form->info_message( $final_message ) if $final_message;

    $ldap_crud->unbind;
    return $ldif;
}

=head1 AUTHOR

Zeus

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;

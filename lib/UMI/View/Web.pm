package UMI::View::Web;

use strict;
use base 'Catalyst::View::TT';

__PACKAGE__->config(
		    INCLUDE_PATH => [
				     UMI->path_to( 'root', 'src' ),
				     UMI->path_to( 'root', 'lib' )
				    ],
		    PRE_PROCESS  => 'config/main',
		    WRAPPER      => 'site/wrapper',
		    ERROR        => 'error.tt2',
		    TIMER        => 0,
		    render_die   => 1,
		    EVAL_PERL    => 1,
		    ENCODING     => 'utf-8',
		    expose_methods => [ qw{ ldap_crud_cfg } ],
		   );

sub ldap_crud_cfg {
  my ( $self, $c, @cfg_attributes ) = @_;
  my $return = q{ $c->model('LDAP_CRUD')->{cfg} };
  foreach ( @cfg_attributes ) {
    $return .= "->{$_}";
  }
  return eval $return;
}

=head1 NAME

UMI::View::Web - Catalyst TTSite View

=head1 SYNOPSIS

See L<UMI>

=head1 DESCRIPTION

Catalyst TTSite View.

=head1 AUTHOR

Zeus Panchenko

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;


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
		    expose_methods => [ qw{ helper_cfg } ],
		   );

=head1 NAME

UMI::View::Web - Catalyst TTSite View

=head1 SYNOPSIS

See L<UMI>

=head1 DESCRIPTION

Catalyst TTSite View.

=head1 METHODS

=head2 helper_cfg

method to provide possibility to use configuration data from
umi_local.pm and LDAP_CRUD class

usage: helper_cfg('cfg_type','hash_key1',...,'hash_keyN')

=cut

sub helper_cfg {
  my ( $self, $c, $cfg_type, @cfg_attributes ) = @_;
  my $return;

  if ( $cfg_type eq 'cfg_ldap_crud' ) {
    $return = q{$c->model('LDAP_CRUD')->{cfg}};
  } elsif ( $cfg_type eq 'cfg_local' ) {
    $return = q{$c->config};
  }
  foreach ( @cfg_attributes ) {
    $return .= "->{$_}";
  }
  return eval $return;
}


=head1 AUTHOR

Zeus Panchenko

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;


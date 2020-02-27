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

use Crypt::HSXKPasswd;
use Data::Printer;
use Logger;

=head1 NAME

UMI::Controller::ToolPwdgen - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut



=head2 index

new Text Pwdgen

QR version is defined dynamicaly (previous to the one spawning error)


=cut


sub index :Path :Args(0) {
  my ( $self, $c ) = @_;
  my $p = $c->req->parameters;
  my $dc = Crypt::HSXKPasswd->default_config();
  use JSON;
  my $presets = decode_json(Crypt::HSXKPasswd->presets_json());
  push @{$presets->{defined_presets}}, 'CLASSIC';
  $presets->{preset_descriptions}->{CLASSIC} = 'Single-word, improved FIPS-181 NIST standard, password';
  $presets = encode_json $presets;

  # log_debug { np($presets) };

  $c->stash( template   => 'tool/toolpwdgen.tt',
	     form       => $self->form,
	     xk_presets => $presets );

  if ( keys %{$p} > 0 ) {
    return unless
      $self->form->process( posted => ($c->req->method eq 'POST'),
			    init_object => { pwd_len       => $p->{pwd_len},
					     pwd_num       => $p->{pwd_num},
					     pwd_cap       => $p->{pwd_cap},
					     pronounceable => $p->{pronounceable}, },
			    params      => $p, );
  } else {
    return unless
      $self->form->process( posted      => ($c->req->method eq 'POST'),
			    params      => $p, );
  }

  my %xk;
  foreach (sort (keys %{$p})) {
    next if $_ !~ /^xk_/;
    next if ! defined $p->{$_} || $p->{$_} eq '';
    if ( $_ =~ /^.*alphabet.*/ ) {
      $xk{ substr($_,3) } = [ split(//, $p->{$_})];
    } else {
      $xk{ substr($_,3) } = $p->{$_};
    }
  }

  if ( $xk{separator_character} eq 'CHAR' ) {
    $xk{separator_character} = $xk{separator_character_char};
    delete $xk{separator_character_char};
    delete $xk{separator_character_random};
  } elsif ( $xk{separator_character} eq 'RANDOM' ) {
    $xk{separator_alphabet} =
      defined $xk{separator_character_random} && length($xk{separator_character_random}) > 0 ?
      [ split(//, $xk{separator_character_random}) ] : $dc->{symbol_alphabet};
    delete $xk{separator_character_random};
    delete $xk{separator_character_char};
  } elsif ( $xk{separator_character} eq 'NONE' ) {
    delete $xk{separator_character_char};
    delete $xk{separator_character_random};
  }

  if ( $xk{padding_type} eq 'NONE' ) {
    delete $xk{padding_character};
    delete $xk{padding_character_char};
    delete $xk{padding_character_random};
  } else {
    if (  $xk{padding_character} eq 'SEPARATOR' ) {
      delete $xk{padding_character_char};
      delete $xk{padding_character_random};
    } elsif (  $xk{padding_character} eq 'CHAR' ) {
      $xk{padding_character} = $xk{padding_character_char};
      delete $xk{padding_character_char};
      delete $xk{padding_character_random};
    } elsif ( $xk{padding_character} eq 'RANDOM' ) {
      $xk{padding_alphabet} = 
	defined $xk{padding_character_random} && length($xk{padding_character_random}) > 0 ?
	[ split(//, $xk{padding_character_random}) ] :$dc->{symbol_alphabet};
      delete $xk{padding_character_char};
      delete $xk{padding_character_random};
    }
  }

  # log_debug { np(%xk) };

  my $pwd =
    $self->pwdgen({ len => defined $p->{pwd_len} && length($p->{pwd_len}) ? $p->{pwd_len} : undef,
		    num => defined $p->{pwd_num} && length($p->{pwd_num}) ? $p->{pwd_num} : undef,
		    cap => defined $p->{pwd_cap} && length($p->{pwd_cap}) ? $p->{pwd_cap} : undef,
		    pronounceable => $p->{pronounceable} // 0,
		    pwd_alg       => $p->{pwd_alg}       // undef,
		    xk            => \%xk,});

  my $final_message->{success} =
    sprintf('<div class="row">
  <div class="col-12 h3 text-monospace text-break text-center">
    %s
  </div>
  <div class="col-12 text-center">', $pwd->{clear});

  my $qr;
  for( my $i = 0; $i < 41; $i++ ) {
    $qr = $self->qrcode({ txt => $pwd->{clear}, ver => $i, mod => 5 });
    last if ! exists $qr->{error};
  }

  $final_message->{error} = $qr->{error} if $qr->{error};
  $final_message->{success} .=
    sprintf('<img alt="password QR" src="data:image/jpg;base64,%s" title="password QR"/>',
	    $qr->{qr} );
  $final_message->{success} .= '</div>';

  if ( $pwd->{status} ) {
    # log_debug { np($pwd) };
    $final_message->{success} .=
      sprintf('<div class="col-12">
  <div class="text-muted text-monospace" aria-label="Statistics" aria-describedby="button-addon2">
    <i class="fas fa-info-circle text-%s"></i>
    Entropy: between <b class="text-%s">%s</b> bits & <b class="text-%s">%s</b> bits blind &
    <b class="text-%s">%s</b> bits with full knowledge
    <small><em>(suggest keeping blind entropy above 78bits & seen above 52bits)</em></small>

    <a class="btn btn-link" data-toggle="collapse" href="#pwdStatus"
        role="button" aria-expanded="false" aria-controls="pwdStatus">
        full status
    </a>
  </div>
  <div class="collapse" id="pwdStatus">
    <div class="card card-body"><small><pre class="text-muted text-monospace">%s</pre></small></div>
  </div>
</div>',
	      $pwd->{stats}->{password_entropy_blind_min} < 78 ||
	      $pwd->{stats}->{password_entropy_blind_max} < 78 ||
	      $pwd->{stats}->{password_entropy_seen}      < 52 ? 'danger' : 'success',
	      $pwd->{stats}->{password_entropy_blind_min} > 78 ? 'success' : 'danger',
	      $pwd->{stats}->{password_entropy_blind_min},
	      $pwd->{stats}->{password_entropy_blind_max} > 78 ? 'success' : 'danger',
	      $pwd->{stats}->{password_entropy_blind_max},
	      $pwd->{stats}->{password_entropy_seen}      > 52 ? 'success' : 'danger',
	      $pwd->{stats}->{password_entropy_seen},
	      $pwd->{status});
  }
  $final_message->{success} .= '</div>';
  $c->stash( final_message => $final_message,
	     on_post       => encode_json $p );
}

=head1 AUTHOR

Charlie &

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;

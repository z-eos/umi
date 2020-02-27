# -*- mode: cperl -*-
#

package UMI::Form::ModPwd;

use HTML::FormHandler::Moose;
BEGIN { extends 'UMI::Form::LDAP'; with 'Tools'; }

use Data::Printer;
use Logger;

use HTML::FormHandler::Types ('NoSpaces', 'WordChars', 'NotAllDigits', 'Printable', 'PositiveNum' );

has '+item_class' => ( default =>'ModPwd' );
has '+action' => ( default => '/searchby/modify_userpassword' );

sub build_form_element_class { [ 'form-horizontal formajaxer' ] }

has_field 'ldap_modify_password' => ( type => 'Hidden', );

has_field 'checkonly' => ( type => 'Hidden', value => 1 );

has_field 'password_init'
  => ( type                  => 'Password',
       apply                 => [ NoSpaces, NotAllDigits, Printable ],
       minlength             => 7, maxlength => 128,
       label                 => 'Password',
       label_class           => [ 'col', 'text-right', 'font-weight-bold', ],
       element_wrapper_class => [ 'input-sm', 'col-10', ],
       element_class         => [ qw(  ), ],
       element_attr          => { placeholder => 'Password',
				  'data-mode' => 'pwddefault', },
       wrapper_class         => [ 'row', 'deactivate-bottom', ],
     );

has_field 'password_cnfm'
  => ( type                  => 'Password',
       apply                 => [ NoSpaces, NotAllDigits, Printable ],
       minlength             => 7, maxlength => 128,
       label                 => 'Confirm',
       label_class           => [ 'col', 'text-right', 'font-weight-bold', ],
       element_wrapper_class => [ 'input-sm', 'col-10', ],
       element_class         => [ qw(  ), ],
       element_attr          => { placeholder => 'Confirm Password',
				  'data-mode' => 'pwddefault', },
       wrapper_class         => [ qw(row ), ],
     );

has_field 'aux_pwdcomment'
  => ( type          => 'Display',
       html          => '<div class="form-group"><div class="help-block col-md-10 col-md-offset-2"><em>' .
       'leave, both New/Confirm Password fields empty, to generate strong password according the options bellow</em></div></div>',
       wrapper_class => [ 'deactivate-bottom', ],
     );


has_field 'pronounceable'
  => (
      type                  => 'Checkbox',
      label                 => 'Pronounceable',
      element_wrapper_class => [ 'offset-md-2', 'col-10', ],
      element_class         => [ qw( disabler-checkbox
				     disableable
				     disabled-if-pwdcheckonly
				     disabled-if-pwddefault ) ],
      element_attr          => { title => 'Completely random word if unchecked, othervise max lengh is ' .
				 UMI->config->{pwd}->{lenp} },
      wrapper_class         => [ qw( row deactivate-top mt-5 cond on-classic ), ],
     );

has_field 'pwd_len'
  => ( type          => 'Display',
       html          => sprintf('
<div class="form-group row mt-5 cond on-classic">
  <label class="col-2 text-right font-weight-bold control-label" title="" for="pwd_len">
    Pwd length: <span id="pwd_len_size" class="text-primary"></span>
  </label>
  <div class="col-9">
    <input id="pwd_len" name="pwd_len" type="range" class="custom-range" min="%s" max="%s" step="1" value="%s" title="min: %s; default common: %s; max common: %s; max pronouceable: %s"/>
  </div>
  <div class="col-1 font-weight-bold">
    <span>%s</span>
  </div>
</div>
<script>
 $(function () {
  var slider = document.getElementById("pwd_len");
  var output = document.getElementById("pwd_len_size");
  output.innerHTML = slider.value;

  slider.oninput = function() {
    output.innerHTML = this.value;
  }
 });
</script>
',
				UMI->config->{pwd}->{len_min},
				UMI->config->{pwd}->{len_max},
				UMI->config->{pwd}->{len},
				UMI->config->{pwd}->{len_min},
				UMI->config->{pwd}->{len},
				UMI->config->{pwd}->{len_max},
				UMI->config->{pwd}->{lenp},
				UMI->config->{pwd}->{len_max}),
     );

has_field 'pwd_cap'
  => ( type          => 'Display',
       html          => sprintf('
<div class="form-group row mt-5 conditional-input on-classic">
  <label class="col-2 text-right font-weight-bold control-label" title="" for="pwd_cap">
    Capital Chars: <span id="pwd_cap_size" class="text-primary"></span>
  </label>
  <div class="col-9">
    <input id="pwd_cap" name="pwd_cap" type="range" class="custom-range" min="0" max="%s" step="1" value="0"/>
  </div>
  <div class="col-1 font-weight-bold">
    <span>%s</span>
  </div>
</div>
<script>
 $(function () {
  var slider = document.getElementById("pwd_cap");
  var output = document.getElementById("pwd_cap_size");
  output.innerHTML = slider.value;

  slider.oninput = function() {
    output.innerHTML = this.value;
  }
 });
</script>
',
			       UMI->config->{pwd}->{cap},
			       UMI->config->{pwd}->{cap}),
     );

has_field 'pwd_num'
  => ( type          => 'Display',
       html          => sprintf('
<div class="form-group row mt-5 conditional-input on-classic">
  <label class="col-2 text-right font-weight-bold control-label" title="" for="pwd_num">
    Num And Spec. Chars: <span id="pwd_num_size" class="text-primary"></span>
  </label>
  <div class="col-9">
    <input id="pwd_num" name="pwd_num" type="range" class="custom-range" min="0" max="%s" step="1" value="0"/>
  </div>
  <div class="col-1 font-weight-bold">
    <span>%s</span>
  </div>
</div>
<script>
 $(function () {
  var slider = document.getElementById("pwd_num");
  var output = document.getElementById("pwd_num_size");
  output.innerHTML = slider.value;

  slider.oninput = function() {
    output.innerHTML = this.value;
  }
 });
</script>
',
			       UMI->config->{pwd}->{num},
			       UMI->config->{pwd}->{num}),
     );

has_field 'pwd_alg'
  => ( type                  => 'Select',
       label                 => 'Preset',
       label_class           => [ qw(col-2 text-right font-weight-bold text-uppercase) ],
       element_class         => [ qw(custom-select) ],
       element_wrapper_class => [ qw(input-sm col-10), ],
       element_attr          => { title => 'Password algorythm',
				  'aria-describedby' => "pwd_algHelpBlock", },
       # do_wrapper            => 0,
       wrapper_class         => [ qw(row col-12 p-0 pt-5) ],
       options_method        => \&pwd_alg_options, );

sub pwd_alg_options {
  my %p = %{ UMI->config->{pwd}->{xk}->{preset} };
  # log_debug { np(%p) };
  my @o;
  my $opt;
  push @o, { value => 'USERDEFINED', label => '--- USER DEFINED ---', selected => 'selected' };
  foreach (sort ( Crypt::HSXKPasswd->defined_presets() )) {
    $opt = { value => $_,
	     label => sprintf("%9s (example: %s)",
			      $_,
			      Crypt::HSXKPasswd->new(preset => $_)->password() ) };

    $opt->{selected} = '1' if $_ eq UMI->config->{pwd}->{xk}->{preset_default};
    push @o, $opt;
  }
  push @o, { value => 'CLASSIC', label => 'CLASSIC (example: %=PfEgJ1Ord6qFWLM8Ts9e7J)' };
  return @o;
}

has_field 'xk_num_words'
  => ( type                  => 'Select',
       label                 => 'Number Of Words',
       label_class           => [ qw(col-2 text-right font-weight-bold my-1) ],
       element_class         => [ qw(col-1 custom-select my-1 ml-4) ],
       # element_wrapper_class => [ 'input-sm', ],
       element_attr          => { title => 'Number Of Words In Password', },
       do_wrapper            => 0,
       options_method        => \&xk_num_words_options, );

sub xk_num_words_options {
  return map { label => $_, value => $_ },
    UMI->config->{pwd}->{xk}->{w_num}->{min}..UMI->config->{pwd}->{xk}->{w_num}->{max};
}

has_field 'xk_word_length_min'
  => ( type                  => 'Select',
       label                 => 'Len min/max',
       label_class           => [ qw(col-3 text-right font-weight-bold my-1) ],
       element_class         => [ qw(col-2 custom-select my-1) ],
       element_wrapper_class => [ 'input-sm', ],
       element_attr          => { title => 'Word Length Min', },
       do_wrapper            => 0,
       options_method        => \&xk_word_length_min_options, );

sub xk_word_length_min_options {
  return map { label => $_, value => $_ },
    UMI->config->{pwd}->{xk}->{w_len}->{min}..UMI->config->{pwd}->{xk}->{w_len}->{max};
}

has_field 'xk_word_length_max'
  => ( type                  => 'Select',
       label                 => '',
       # label_class           => [ qw(col-2 text-right font-weight-bold mr-5 my-1) ],
       element_class         => [ qw(col-2 custom-select my-1) ],
       element_wrapper_class => [ 'input-sm', ],
       element_attr          => { title => 'Word Length Max', },
       do_wrapper            => 0,
       options_method        => \&xk_word_length_max_options, );

sub xk_word_length_max_options {
  return map { label => $_, value => $_ },
    UMI->config->{pwd}->{xk}->{w_len}->{min}..UMI->config->{pwd}->{xk}->{w_len}->{max};
}

has_field 'xk_case_transform'
  => ( type                  => 'Select',
       label                 => 'Case',
       label_class           => [ qw(col-2 text-right font-weight-bold my-1) ],
       element_class         => [ qw( custom-select my-1 ml-4 ) ],
       # element_wrapper_class => [ 'input-sm col-10 pl-0', ],
       element_attr          => { title => 'Case Transformation', },
       # do_wrapper            => 0,
       wrapper_class         => [ 'row', 'col-12', ],
       options_method        => \&xk_case_transform_options, );

sub xk_case_transform_options {
  my %p = %{ UMI->config->{pwd}->{xk}->{w_case} };
  my @o;
  foreach (sort (keys %p)) {
    $_ ne 'NONE' ?
      push @o, { value    => $_, label => sprintf("%9s (example: %s)", $_, $p{$_}) } :
      push @o, { value    => $_, label => sprintf("%9s (example: %s)", $_, $p{$_}),
		 selected => 'selected' };
  }
  return @o;
}

has_field 'xk_separator_character'
  => ( type                  => 'Select',
       label                 => 'Separator',
       label_class           => [ qw(col-2 text-right font-weight-bold my-1) ],
       element_class         => [ qw(col-2 custom-select my-1 ml-4 input-sm) ],
       # element_wrapper_class => [ 'input-sm col-2', ],
       element_attr          => { title => 'Separator', },
       do_wrapper            => 0,
       # wrapper_class         => [ 'row', ],
       options               => [{ value => 'NONE',   label => 'NONE', selected => 'selected' },
				 { value => 'CHAR',   label => 'Specified Character'},
				 { value => 'RANDOM', label => 'Random Character'}], );

has_field 'xk_separator_character_char'
  => ( type                  => 'Text',
       label                 => '',
       element_class         => [ qw( my-1 text-center text-monospace font-weight-bold ) ],
       element_wrapper_class => [ 'input-sm col-12', ],
       element_attr          => { title => q{Separator Character (one of): !&#34;#$%&'()*+,-./:;&#60;=&#62;?@[\]^_{|}~}, },
       minlength             => 1,
       maxlength             => 1,
       # do_wrapper            => 0,
       wrapper_class         => [ qw(col-2 row form-group csep on-sep-char), ],
     );

has_field 'xk_separator_character_random'
  => ( type                  => 'Text',
#       apply                 => [],
       label                 => '',
       # label_class           => [ qw(col-2 text-right font-weight-bold my-1) ],
       element_class         => [ qw( my-1 text-center text-monospace font-weight-bold ) ],
       element_wrapper_class => [ 'input-sm col-12', ],
       element_attr          => { title => q{Separator Character Alphabet: !&#34;#$%&'()*+,-./:;&#60;=&#62;?@[\]^_{|}~}, },
       wrapper_class         => [ qw(col-5 px-0 row form-group csep on-sep-random), ],
     );

has_field 'xk_padding_digits_before'
  => ( type                  => 'Select',
       label                 => 'Padding Digits',
       label_class           => [ qw(col-3 col-md-2 text-right font-weight-bold my-1) ],
       element_class         => [ qw(col-2 col-md-1 custom-select my-1 ml-4 input-sm mr-3 ) ],
       element_attr          => { title => 'Padding Digits From the Left', },
       do_wrapper            => 0,
       options_method        => \&xk_padding_digits_before_options, );

sub xk_padding_digits_before_options {
  my @o;
  push @o, { value => $_, label => $_ }
    foreach (UMI->config->{pwd}->{xk}->{d_padd}->{min}..UMI->config->{pwd}->{xk}->{d_padd}->{max});
  return @o;
}

has_field 'xk_padding_digits_after'
  => ( type                  => 'Select',
       label                 => '',
       # label_class           => [ qw(col-2 text-right font-weight-bold mr-5 my-1) ],
       element_class         => [ qw(col-2 col-md-1 custom-select my-1 input-sm) ],
       element_attr          => { title => 'Padding Digits From the Right', },
       do_wrapper            => 0,
       options_method        => \&xk_padding_digits_after_options, );

sub xk_padding_digits_after_options {
  my @o;
  push @o, { value => $_, label => $_ }
    foreach (UMI->config->{pwd}->{xk}->{d_padd}->{min}..UMI->config->{pwd}->{xk}->{d_padd}->{max});
  return @o;
}

has_field 'xk_padding_type'
  => ( type                  => 'Select',
       label                 => 'Padding Type',
       label_class           => [ qw(col-2 text-right font-weight-bold my-1) ],
       element_class         => [ qw(custom-select) ],
       element_wrapper_class => [ qw(col-3 my-1 ml-3), ],
       element_attr          => { title => 'Padding Type', },
       # do_wrapper            => 0,
       wrapper_class         => [ 'row', 'col-12', 'form-group', ],
       options_method        => \&xk_padding_type_options, );

sub xk_padding_type_options {
  return map { value => $_, label => $_ }, @{ UMI->config->{pwd}->{xk}->{s_padd}->{type} };
}

has_field 'xk_padding_characters_before'
  => ( type                  => 'Select',
       label                 => 'Symbols left/right',
       label_class           => [ qw(offset-md-1 col-3 col-md-3 text-right font-weight-bold my-1) ],
       element_class         => [ qw(col-2 col-md-1 custom-select input-sm my-1 ml-4 mr-3) ],
       element_attr          => { title => 'Padding Symbols From the Left', },
       do_wrapper            => 0,
       options_method        => \&xk_padding_characters_before_options, );

sub xk_padding_characters_before_options {
  my @o;
  push @o, { value => $_, label => $_ }
    foreach (UMI->config->{pwd}->{xk}->{d_padd}->{min}..UMI->config->{pwd}->{xk}->{d_padd}->{max});
  return @o;
}

has_field 'xk_padding_characters_after'
  => ( type                  => 'Select',
       label                 => '',
       # label_class           => [ qw(col-2 text-right font-weight-bold mr-5 my-1) ],
       element_class         => [ qw(col-2 col-md-1 custom-select my-1 input-sm) ],
       element_attr          => { title => 'Padding Symbols From the Right', },
       do_wrapper            => 0,
       options_method        => \&xk_padding_characters_after_options, );

sub xk_padding_characters_after_options {
  my @o;
  push @o, { value => $_, label => $_ }
    foreach (UMI->config->{pwd}->{xk}->{d_padd}->{min}..UMI->config->{pwd}->{xk}->{d_padd}->{max});
  return @o;
}

has_field 'xk_pad_to_length'
  => ( type                  => 'Integer',
       label                 => 'To Length',
       label_class           => [ qw(offset-md-1 col-3 col-md-3 text-right font-weight-bold my-1) ],
       element_class         => [ qw( my-1 text-center text-monospace font-weight-bold ) ],
       element_wrapper_class => [ 'input-sm col-2', ],
       element_attr          => { title => 'Padding To Length', min => 8, max => 999,},
       minlength             => 1,
       maxlength             => 3,
       size                  => 3,
       wrapper_class         => [ qw(row col-12 form-group cpad on-padd-adaptive)],
       # do_wrapper            => 0,
     );

has_field 'xk_padding_character'
  => ( type                  => 'Select',
       label                 => 'Padding Character',
       label_class           => [ qw(offset-md-1 col-3 text-right font-weight-bold my-1) ],
       element_class         => [ qw(col-2 custom-select my-1 input-sm mx-4) ],
       # element_wrapper_class => [ 'col-12', ],
       element_attr          => { title => 'Separator', },
       do_wrapper            => 0,
       # wrapper_class         => [ 'row', ],
       options               => [{ value => 'SEPARATOR',
				   label => 'Separator Character',
				   selected => 'selected' },
				 { value => 'CHAR',      label => 'Specified Character' },
				 { value => 'RANDOM',    label => 'Random Alphabet' }], );

has_field 'xk_padding_character_separator'
  => ( type                  => 'Text',
       label                 => '',
       element_class         => [ qw( col-2 my-1 text-center text-monospace font-weight-bold ) ],
       element_attr          => { title => 'Padding Character', },
       minlength             => 1,
       maxlength             => 1,
       wrapper_class         => [ qw(col-6 row form-group cpch on-padd-char-char)],
     );

has_field 'xk_padding_character_random'
  => ( type                  => 'Text',
       label                 => '',
       element_class         => [ qw( col my-1 text-center text-monospace font-weight-bold input-sm ) ],
       element_wrapper_class => [ qw(col pl-0), ],
       element_attr          => { title => q{Padding Character Alphabet: !&#34;#$%&'()*+,-./:;&#60;=&#62;?@[\]^_{|}~}, },
       wrapper_class         => [ qw(col-5 row form-group cpch on-padd-char-random)],
     );






has_field 'aux_submit'
  => ( type          => 'Submit',
       element_class => [ qw( btn
			      btn-success
			      col-4 my-5 mr-2
			      font-weight-bold
			      text-uppercase) ],
       # wrapper_class => [ 'col-8', ],
       do_wrapper    => 0,
       value         => 'Submit' );

sub build_render_list {[ 'checkonly', 'ldap_modify_password', 'password_init', 'password_cnfm', 'pronounceable', 'pwd_len', 'pwd_cap', 'pwd_num', 'aux_submit' ]}

sub html_attributes {
  my ( $self, $field, $type, $attr ) = @_;
  push @{$attr->{class}}, 'required'
    if ( $type eq 'label' && $field->required );
}

# working sample
# sub validate_givenname {
#   my ($self, $field) = @_;
#   unless ( $field->value ne 'Вася' ) {
#     $field->add_error('Such givenName+sn+uid user exists!');
#   }
# }

sub validate {
  my $self = shift;
  my ( @arr, $str, $f );
  # log_debug { np($self->field('pronounceable')->value) };

  # use Data::Printer use_prototypes => 0;
  # p ({ 'password_init' => $self->field('password_init')->value,
  # 	'password_init_is_ascii' => $self->is_ascii($self->field('password_init')->value),
  # 	  'password_cnfm' => $self->field('password_cnfm')->value,
  # 	    'password_cnfm_is_ascii' => $self->is_ascii($self->field('password_cnfm')->value), });

  if ( defined $self->field('password_init')->value &&
       defined $self->field('password_cnfm')->value &&
       ! defined $self->field('checkonly')->value &&
       ($self->field('password_init')->value ne $self->field('password_cnfm')->value)
     ) {
    $self->field('password_init')
      ->add_error('password and confirmation does not match');
  } elsif ( ! defined $self->field('checkonly')->value &&
	    (defined $self->field('password_init')->value &&
	     ! defined $self->field('password_cnfm')->value ) ||
	    (defined $self->field('password_init')->value &&
	     defined $self->field('password_cnfm')->value &&
	     ($self->field('password_init')->value ne '' &&
	      $self->field('password_cnfm')->value eq '' ) ) ) {
    $self->field('password_cnfm')
      ->add_error('confirmation is mandatory if password present');
  } elsif ( ! defined $self->field('checkonly')->value &&
	    (! defined $self->field('password_init')->value &&
	     defined $self->field('password_cnfm')->value ) ||
	    (defined $self->field('password_init')->value &&
	     defined $self->field('password_cnfm')->value &&
	     ($self->field('password_init')->value eq '' &&
	      $self->field('password_cnfm')->value ne '' ) ) ) {
    $self->field('password_init')
      ->add_error('password mandatory if confirmation present');
  }

  # this realized with HTML::FormHandler::Types Printable
  if ( defined $self->field('password_init')->value &&
       defined $self->field('password_cnfm')->value &&
       ( $self->is_ascii($self->field('password_init')->value) ||
	 $self->is_ascii($self->field('password_cnfm')->value) )
     ) {
    $self->field('password_init')
      ->add_error('password has to be ASCII only!');
    $self->field('password_cnfm')
      ->add_error('confirmation has to be ASCII only!');
  }




  $f = $self->field('pwd_len');
  $f->add_error('Incorrect password length! It can be greater than ' .
		UMI->config->{pwd}->{len_min} . ' and less than ' .
		UMI->config->{pwd}->{len_max} . ' characters long.')
    if ! $self->field('pronounceable')->value && defined $f->value &&
    $f->value ne '' &&
    ( $f->value < UMI->config->{pwd}->{len_min} || $f->value > UMI->config->{pwd}->{len_max} );

  $f->add_error('Pronounceable max length ' . UMI->config->{pwd}->{lenp})
    if $self->field('pronounceable')->value && $f->value > UMI->config->{pwd}->{lenp};

  $self->field('pwd_cap')
    ->add_error('Incorrect capital characters number! It can be 0 to ' . UMI->config->{pwd}->{cap})
    if defined $self->field('pwd_cap')->value &&
    $self->field('pwd_cap')->value > UMI->config->{pwd}->{cap};

  $self->field('pwd_num')
    ->add_error('Numbers and special characters can occure only 0 to ' .
		UMI->config->{pwd}->{num} . ' times!')
    if defined $self->field('pwd_num')->value &&
    $self->field('pwd_num')->value > UMI->config->{pwd}->{num};


  $f = $self->field('xk_separator_character_random');
  if ( defined $f->value && $f->value ne '' ) {
    @arr = grep { $_ ne ""} map { $_ if $_ =~ m/[^[:punct:]]/ } @{[ split(/ /, $f->value) ]};
    $str = join ', ', @arr;

    $f->add_error( sprintf('<div class="text-danger">Wrong character/s for separator alphabet: %s</div>', $str) )
      if length($str);
  }

  if ( $self->field('xk_padding_type')->value eq 'FIXED' ) {
    $f = $self->field('xk_padding_character_separator');
    $f->add_error('<div class="text-danger">Padding character is required.</div>')
      if $self->field('xk_padding_character')->value eq 'CHAR' && $f->value eq '';

    # $f = $self->field('xk_padding_character_random');
    # $f->add_error('<div class="text-danger">Padding alphabet is required.</div>')
    #   if $self->field('xk_padding_character')->value eq 'RANDOM' && $f->value eq '';
  }

  $f = $self->field('xk_separator_character_char');
  # log_debug { '-->' . np($f) . '<--' };
  $f->add_error('<div class="text-danger">Separator character is required.</div>')
    if defined $f->value && $f->value eq 'CHAR' && length($f->value) != 1;

  $f = $self->field('xk_separator_character_random');
  # log_debug { '-->' . np($f) . '<--' };
  # $f->add_error('<div class="text-danger">Separator alphabet is required.</div>')
  #   if $self->field('xk_separator_character')->value eq 'RANDOM' &&
  #   ( ! defined $f->value && length($f->value) < 1 );

  $f = $self->field('xk_separator_character_char');
  $f->add_error(sprintf('<div class="text-danger">Wrong separator character: %s</div>',$f->value))
    if $self->field('xk_separator_character')->value eq 'CHAR' &&
    $f->value =~ m/[^[:punct:]]/ && $f->value =~ m/[^[:space:]]/;

  $self->field('xk_pad_to_length')->add_error('<div class="text-danger">Length is required!</div>')
    if $self->field('xk_padding_type')->value eq 'ADAPTIVE' &&
    $self->field('xk_pad_to_length')->value eq '';

  if ( defined $self->field('xk_padding_character_random')->value &&
       $self->field('xk_padding_character_random')->value ne '' ) {
    @arr = grep { $_ ne ""} map { $_ if $_ =~ m/[^[:punct:]]/ }
      @{[ split(/ /, $self->field('xk_padding_character_random')->value) ]};
    $str = join ', ', @arr;

    $self->field('xk_padding_character_random')
      ->add_error( sprintf('<div class="text-danger">Wrong character/s for padding alphabet: %s</div>', $str) ) if length($str);
  }

}

######################################################################

no HTML::FormHandler::Moose;

__PACKAGE__->meta->make_immutable;

1;

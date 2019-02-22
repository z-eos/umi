package UMI::HTML::FormHandler::Widget::Wrapper::Bootstrap4;
# ABSTRACT: Twitter Bootstrap 4.0 field wrapper

use Moose::Role;
use namespace::autoclean;
use HTML::FormHandler::Render::Util ('process_attrs');
use List::Util 1.33 ('any');

with 'HTML::FormHandler::Widget::Wrapper::Base';

use Data::Printer caller_info => 1, colored => 1;
use Logger;

sub is_b3 {1}

sub build_wrapper_tags {
    {
        radio_element_wrapper    => 1,
        checkbox_element_wrapper => 1,
    }
}

sub wrap_field {
    my ( $self, $result, $rendered_widget ) = @_;

    my $output;

    # create attribute string for wrapper
    if ( $self->do_wrapper ) {
        my $attr = $self->wrapper_attributes($result);
        # no 'control-group' class for Hidden fields, 'form-actions' for submit/reset
        my $div_class = 'form-group';
        unshift @{$attr->{class}}, $div_class;
        my $attr_str = process_attrs( $attr );
	# log_debug { np("\n" . $attr_str . "\n") };
        # wrapper is always a div
        $output .= $self->get_tag('before_wrapper');
        $output .= qq{\n<div$attr_str>};
    }
    # render the label
    $output .= "\n" . $self->do_render_label($result, undef, ['control-label'] )
        if $self->do_label;
    $output .=  $self->get_tag('before_element');

    # the controls div; used to have 'controls' class. Now it comes from
    # the 'element_wrapper_class'. Used for column layout.
    my $ew_attr = $self->element_wrapper_attributes($result);
    my $element_wrapper_attrs =  process_attrs( $ew_attr );


    # original code
    # ---
    # $output .= qq{\n<div$element_wrapper_attrs>}
    #     unless !$self->do_wrapper;
    # ---
    # is causing emty <div> wrapping Repeatable::Instance objects
    #
    # here the kludge to overcome this behavior, to use element_class
    # of that Repeatable::Instance parent
    
    unless ( !$self->do_wrapper ) {
      if ( $result->field_def->type eq "Repeatable::Instance" &&
	   $result->field_def->is_compound ) {
	$output .= sprintf("\n<div class=\"%s\">",
			   join(' ', @{$result->field_def->parent->element_class}));
      } elsif ( $element_wrapper_attrs ne '' ) {
	$output .= qq{\n<div$element_wrapper_attrs>};
      } else {
	$output .= qq{\n<div>};
      }
    }

    # yet another tag
    $output .= $self->get_tag('before_element_inside_div');
    # handle input-prepend and input-append
    if( $self->get_tag('input_prepend') || $self->get_tag('input_append') ||
            $self->get_tag('input_append_button') ) {
        $rendered_widget = $self->do_prepend_append($rendered_widget);
    }
    elsif( lc $self->widget eq 'checkbox' ) {
        $rendered_widget = $self->wrap_checkbox($result, $rendered_widget, 'b3_label_left')
    }

    $output .= "\n$rendered_widget";
    # various 'help-inline' bits: errors, warnings
    unless( $self->get_tag('no_errors') ) {
        $output .= qq{\n<span class="help-block">$_</span>}
            for $result->all_errors;
        $output .= qq{\n<span class="help-block">$_</span>} for $result->all_warnings;
    }
    # extra after element stuff
    $output .= $self->get_tag('after_element');
    # close element_wrapper 'control' div
    $output .= '</div>' unless !$self->do_wrapper;
    # close wrapper
    if ( $self->do_wrapper ) {
        $output .= "\n</div>";
        $output .= $self->get_tag('after_wrapper');
    }
    return "$output";
}

# don't render label for checkboxes
sub do_render_label {
    my ( $self ) = @_;

    return '' if $self->type_attr eq 'checkbox';
    HTML::FormHandler::Widget::Wrapper::Base::do_render_label(@_);
}

sub add_standard_element_classes {
    my ( $self, $result, $class ) = @_;
    push @$class, 'has-error' if $result->has_errors;
    push @$class, 'has-warning' if $result->has_warnings;
    push @$class, 'disabled' if $self->disabled;
    push @$class, 'form-control'
       if $self->html_element eq 'select' || $self->html_element eq 'textarea' ||
          $self->type_attr eq 'text' || $self->type_attr eq 'password';
}

sub add_standard_wrapper_classes {
    my ( $self, $result, $class ) = @_;
    push @$class, 'has-error' if ( $result->has_error_results || $result->has_errors );
    push @$class, 'has-warning' if $result->has_warnings;
    # TODO: has-success?
}

sub add_standard_label_classes {
    my ( $self, $result, $class ) = @_;
    if ( my $classes = $self->form->get_tag('layout_classes') ) {
        my $label_class = $classes->{label_class};
        if ( $label_class && not any { $_ =~ /^col\-/ } @$class ) {
            push @$class, @{$classes->{label_class}};
        }
    }
}

sub add_standard_element_wrapper_classes {
    my ( $self, $result, $class ) = @_;
    if ( my $classes = $self->form->get_tag('layout_classes') ) {
        if ( exists $classes->{element_wrapper_class} &&
             not any { $_ =~ /^col\-/ } @$class ) {
            push @$class, @{$classes->{element_wrapper_class}};
        }
        if ( exists $classes->{no_label_element_wrapper_class} &&
             ( ! $self->do_label || $self->type_attr eq 'checkbox' ) &&
             not any { $_ =~ /^offset\-.*/ } @$class ) {
            push @$class, @{$classes->{no_label_element_wrapper_class}};
        }
    }
}

sub wrap_checkbox {
    my ( $self, $result, $rendered_widget ) = @_;

    # use the regular label
    my $label =  $self->option_label || $self->label;
    $label = $self->get_tag('label_no_filter') ? $self->_localize($label) : $self->html_filter($self->_localize($label));
    my $id = $self->id;
    my $for = qq{ for="$id"};

    # return unwrapped checkbox with 'checkbox-inline'
    return qq{<label class="checkbox-inline" $for>$rendered_widget\n$label\n</label>}
        if( $self->get_tag('inline') );

    # return wrapped checkbox, either on left or right
    return qq{<div class="checkbox"><label$for>\n$label\n$rendered_widget</label></div>}
        if( $self->get_tag('label_left') );
    return qq{<div class="checkbox"><label$for>$rendered_widget\n$label\n</label></div>};
}

sub do_prepend_append {
    my ( $self, $rendered_widget ) = @_;

    my @class;
    if( my $ip_tag = $self->get_tag('input_prepend' ) ) {
        $rendered_widget = qq{<div class="input-group-prepend"><span class="input-group-text">$ip_tag</span></div>$rendered_widget};
        push @class, 'input-group';
    }
    if ( my $ia_tag = $self->get_tag('input_append' ) ) {
        $rendered_widget = qq{$rendered_widget<div class="input-group-prepend"><span class="input-group-text">$ia_tag</span></div>};
        push @class, 'input-group';
    }
    if ( my $iab_tag = $self->get_tag('input_append_button') ) {
        my $iab_element_attr_tag = $self->get_tag('input_append_button_element_attr');

        my ($btn_class, $attr);
        if (ref $iab_element_attr_tag eq 'HASH') {
          $btn_class = ref $iab_element_attr_tag->{class} eq 'ARRAY' ? shift @{$iab_element_attr_tag->{class}} : $iab_element_attr_tag->{class};
          $attr = process_attrs( $iab_element_attr_tag );
        }

        my @buttons = ref $iab_tag eq 'ARRAY' ? @$iab_tag : ($iab_tag);
        my $group = qq{<span class="input-group-btn">};
        foreach my $btn ( @buttons ) {
            $group .= qq{<button type="button" class="btn $btn_class"$attr>$btn</button>};
        }
        $group .= qq{</span>};
        $rendered_widget = qq{$rendered_widget$group};
        push @class, 'input-group';
    }
    my $attr = process_attrs( { class => \@class } );
    $rendered_widget =
qq{<div$attr>
  $rendered_widget
</div>};
    return $rendered_widget;
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

HTML::FormHandler::Widget::Wrapper::Bootstrap3 - Twitter Bootstrap 3.0 field wrapper

=head1 VERSION

version 0.40068

=head1 SYNOPSIS

Wrapper to implement Bootstrap 3.0 style form element rendering.

=head1 DESCRIPTION

Differences from the Bootstrap 2.0 wrapper:

   The wrapper class is 'form-group' instead of 'control-group'
   The div wrapping the form element does not
       have the 'controls' class. Used for sizing css classes.
   Input prepend & append use different classes
   The input elements have a 'form-control' class

Tags supported:

   label_no_filter -- don't html filter the label
   label_after -- useful for putting a colon, or other trailing formatting
   before_element -- insert tag before input, outside element's control div
   before_element_inside_div -- insert tag before input element, inside control div
   input_prepend -- for Bootstrap 'input-prepend' class
   input_append -- for Bootstrap 'input-append' class
   input_append_button -- 'input-append' with button instead of span
   no_errors -- don't append error to field rendering
   after_element -- insert tag after input element

=head1 AUTHOR

FormHandler Contributors - see HTML::FormHandler

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2017 by Gerda Shank.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

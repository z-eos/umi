package UMI::Form::[% class_pl %];
use Moose;
use namespace::autoclean;

use HTML::FormHandler::Types ('NoSpaces', 'WordChars', 'NotAllDigits', 'Printable' );
use HTML::FormHandler::Widget::Theme::Bootstrap3;
use HTML::FormHandler::Widget::Wrapper::Bootstrap3;
use Try::Tiny;
use Data::Printer;

extends 'UMI::Form::Base'; 

#use UMI::HTML::FormHandler::Form::Query::[% class_si %];

has '+widget_wrapper' => ( default => 'Bootstrap3');

has 'ldap_crud' => (is => 'rw');


has "form_model_class" => (
	is      => 'rw',
	default => '[% class_si %]',
);

has "all_attributes" => (
	traits  => ['Hash'],
	is      => 'rw',
	isa     => 'HashRef',
	default => sub {
		{
			businessCategory         => 'Text',
			description              => 'Text',
			destinationIndicator     => 'Integer',
			facsimileTelephoneNumber => 'Text',

		};
	},
);



has_field 'ou' => (
	label                 => '[% class_si %]',
	label_class           => ['col-sm-3'],
	label_attr            => { title => 'top level name of the [% class_si | lower %]' },
	element_wrapper_class => 'col-sm-8',
	element_attr          => { placeholder => 'fo01' },
	required              => 1,
);



__PACKAGE__->meta->make_immutable;

1;


package UMI::Form::LDAP;

use HTML::FormHandler::Moose;
extends 'HTML::FormHandler';

use UMI::HTML::FormHandler::Types ('NoSpaces', 'WordChars', 'NotAllDigits', 'Printable' );
use UMI::HTML::FormHandler::Widget::Theme::Bootstrap4;
use UMI::HTML::FormHandler::Widget::Wrapper::Bootstrap4;

#use HTML::FormHandler::Widget::Theme::Bootstrap3;
#use HTML::FormHandler::Widget::Wrapper::Bootstrap3;


#has '+widget_wrapper' => ( default => 'Bootstrap3');
has '+widget_wrapper' => ( default => 'Bootstrap4');
has '+widget_name_space' => ( default => sub { ['UMI::HTML::FormHandler::Widget'] } );

has 'ldap_crud' => (is => 'rw');

no HTML::FormHandler::Moose;

__PACKAGE__->meta->make_immutable;

1;

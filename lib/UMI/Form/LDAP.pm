package UMI::Form::LDAP;

use HTML::FormHandler::Moose;
extends 'HTML::FormHandler';

use HTML::FormHandler::Types ('NoSpaces', 'WordChars', 'NotAllDigits', 'Printable' );
use HTML::FormHandler::Widget::Theme::Bootstrap3;
use HTML::FormHandler::Widget::Wrapper::Bootstrap3;

has '+widget_wrapper' => ( default => 'Bootstrap3');

has 'ldap_crud' => (is => 'rw');




no HTML::FormHandler::Moose;

__PACKAGE__->meta->make_immutable;

1;

#!/usr/bin/env perl
# IMPORTANT: if you delete this file your app will not work as
# expected.  You have been warned.
use inc::Module::Install 1.02;
use Module::Install::Catalyst; # Complain loudly if you don't have
                               # Catalyst::Devel installed or haven't said
                               # 'make dist' to create a standalone tarball.

name 'UMI';
all_from 'lib/UMI.pm';

requires 'Catalyst::Runtime' => '5.90114';
requires 'Catalyst::Plugin::ConfigLoader';
requires 'Catalyst::Plugin::Static::Simple';
requires 'Catalyst::Action::RenderView';
requires 'Moose';
requires 'namespace::autoclean';
requires 'Config::General'; # This should reflect the config file format you've chosen
                            # See Catalyst::Plugin::ConfigLoader for supported formats

requires 'Catalyst::View::TT';
requires 'Catalyst::View::JSON';
requires 'Catalyst::Plugin::Unicode';
requires 'Catalyst::Plugin::Authentication';
requires 'Catalyst::Plugin::Session::Store::FastMmap';
requires 'Catalyst::Authentication::Store::LDAP';

requires 'Log::Log4perl'
requires 'Log::Contextual'
requires 'Log::Dispatch'
    
requires 'BSD::Resource';
requires 'Cache::FastMmap';
requires 'Compress::LZ4';
requires 'Crypt::GeneratePassword';
requires 'Crypt::RSA';
requires 'Data::Printer';
requires 'Digest::SHA';
requires 'GD::Barcode::QRcode';
requires 'Lingua::Translit';
requires 'MIME::Base64';
requires 'Net::CIDR::Set'
requires 'Net::LDAP';
requires 'Net::Netmask';
requires 'Net::SSH::Perl';
requires 'Text::Unidecode';
requires 'Text::Diff::HTML';
requires 'Time::Piece';

test_requires 'Test::More' => '1.001014';
catalyst;

install_script glob('script/*.pl');
auto_install;
WriteAll;

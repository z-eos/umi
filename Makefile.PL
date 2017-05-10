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
requires 'Net::LDAP';
requires 'Lingua::Translit';
requires 'Text::Unidecode';
requires 'Crypt::GeneratePassword'; # it is required but looks not available with `pkg install'
requires 'Crypt::RSA';
requires 'Digest::SHA1';
requires 'MIME::Base64';
requires 'GD::Barcode::QRcode';
requires 'Net::SSH::Perl';
requires 'Net::Netmask';
requires 'Compress::LZ4';
requires 'Cache::FastMmap';
requires 'BSD::Resource';

test_requires 'Test::More' => '1.001014';
catalyst;

install_script glob('script/*.pl');
auto_install;
WriteAll;

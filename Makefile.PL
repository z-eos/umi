#!/usr/bin/env perl
# IMPORTANT: if you delete this file your app will not work as
# expected.  You have been warned.
use lib '.';
use inc::Module::Install 1.02;
use Module::Install::Catalyst; # Complain loudly if you don't have
                               # Catalyst::Devel installed or haven't said
                               # 'make dist' to create a standalone tarball.

name 'UMI';
all_from 'lib/UMI.pm';

requires 'Catalyst::Runtime' => '5.90128';
requires 'Catalyst::Plugin::ConfigLoader';
requires 'Catalyst::Plugin::Static::Simple';
requires 'Catalyst::Action::RenderView';
requires 'Moose';
requires 'namespace::autoclean';
requires 'Config::General'; # This should reflect the config file format you've chosen
                            # See Catalyst::Plugin::ConfigLoader for supported formats

#--- uni related stuff ------------------------------------------------

requires 'Catalyst::Authentication::Store::LDAP';
requires 'Catalyst::Plugin::Authentication';
requires 'Catalyst::Plugin::Session::Store::FastMmap';
requires 'Catalyst::Plugin::Unicode';
requires 'Catalyst::View::Download';
requires 'Catalyst::View::JSON';
requires 'Catalyst::View::TT';

requires 'Log::Log4perl';
requires 'Log::Contextual';
requires 'Log::Dispatch';
    
requires 'Cache::FastMmap';
requires 'Compress::LZ4';
requires 'Crypt::GeneratePassword';
requires 'Crypt::HSXKPasswd';
requires 'Crypt::RSA';
requires 'Data::Entropy';
requires 'Data::Printer';
# ??? # requires 'DateTime::Format::Duration';
requires 'Digest::SHA';
requires 'File::Which';
requires 'GD';
requires 'GD::Barcode::QRcode';
requires 'Lingua::Translit';
# ??? # requires 'MikroTik::API';
requires 'Math::Random::Secure';
requires 'MIME::Base64';
requires 'Net::CIDR::Set';
requires 'Net::LDAP';
requires 'Net::Netmask';
requires 'POSIX::Run::Capture';
requires 'Template::Plugin::JSON';
requires 'Text::Unidecode';
requires 'Text::Diff::HTML';
requires 'Time::Piece';

#--- uni related stuff ------------------------------------------------

test_requires 'Test::More' => '0.88';
catalyst;

install_script glob('script/*.pl');
auto_install;
WriteAll;

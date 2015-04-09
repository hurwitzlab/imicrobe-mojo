use inc::Module::Install;

name           'IMicrobe';
abstract       'Mojolicious engine for iMicrobe';
author         'Ken Youens-Clark <kyclark@gmail.com>';
version        '0.01';
license        'GPL';

requires 'namespace::autoclean';
requires 'common::sense';
requires 'Captcha::reCAPTCHA';
requires 'DBD::mysql'                      => '';
requires 'DBI'                             => '1.630';
requires 'DBIx::Class'                     => '';
requires 'Data::Dump'                      => '1.22';
requires 'Email::Valid';
requires 'HTML::LinkExtractor';
requires 'Mail::Sendmail';
requires 'Mail::SpamAssassin';
requires 'Mojolicious'                     => '5.60.1';
requires 'Mojolicious::Plugin::JSONConfig' => '';
requires 'Mojolicious::Plugin::TtRenderer' => '1.50';
requires 'Moose'                           => '2.1005';
requires 'Template'                        => '2.25';
requires 'Template::Plugin::Comma'         => '0.04';
requires 'YAML'                            => '';
requires 'MooseX::MarkAsMethods'           => '';
requires 'MooseX::NonMoose'                => '';
requires 'Captcha::reCAPTCHA'              => '';
requires 'Email::Valid'                    => '';
requires 'HTML::LinkExtractor'             => '';
requires 'Mail::Sendmail'                  => '';
requires 'Mail::SpamAssassin'              => '';

test_requires 'Test::More'                 => '0.98';

WriteAll;

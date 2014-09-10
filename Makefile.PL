use inc::Module::Install;

name           'IMicrobe';
abstract       'Mojolicious engine for iMicrobe';
author         'Ken Youens-Clark <kyclark@gmail.com>';
version        '0.01';
license        'GPL';

requires 'DBI'                             => '1.630';
requires 'Data::Dump'                      => '1.22';
requires 'Mojolicious'                     => '4.87';
requires 'Mojolicious::Plugin::TtRenderer' => '1.50';
requires 'Mojolicious::Plugin::YamlConfig' => '0.1.5';
requires 'Moose'                           => '2.1005';
requires 'Template'                        => '2.25';
requires 'Template::Plugin::Comma'         => '0.04';

test_requires 'Test::More'                 => '0.98';

WriteAll;

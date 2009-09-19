use inc::Module::Install;

name 'DBIx-Thin';
perl_version '5.005';
all_from 'lib/DBIx/Thin.pm';

requires 'Class::Accessor' => '0.25';
requires 'DBI' => '1.38';
requires 'File::Spec';
requires 'UNIVERSAL::require';
#requires 'Digest::SHA1';

author_tests('xt');

build_requires 'Test::More' => '0.42';
build_requires 'FindBin::libs';

auto_include;
#auto_set_repository;

WriteAll;

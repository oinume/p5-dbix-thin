use inc::Module::Install;

name 'DBIx-Thin';
perl_version '5.005';
all_from 'lib/DBIx/Thin.pm';

requires 'Class::Accessor' => '0.25';
requires 'DBI' => '1.38';
requires 'File::Basename';
requires 'File::Spec';
requires 'UNIVERSAL::require';

build_requires 'DBD::SQLite' => '1.14';
build_requires 'FindBin::libs';
build_requires 'Test::More' => '0.42';

auto_include;
#auto_set_repository;

author_tests('xt');
tests_recursive;

install_script 'script/thin-generate-schema.pl';

WriteAll;

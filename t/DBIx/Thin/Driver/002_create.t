#!/usr/bin/env perl

use FindBin::libs;
use Test::Utils;
use Test::More qw/no_plan/;
use DBIx::Thin::Driver;

my %values = (
    dsn => 'dbi:sqlite:mydb',
    username => 'root',
    password => 'hoge',
);
my $driver = DBIx::Thin::Driver->create(
    dsn => 'dbi:sqlite:mydb',
    username => 'root',
    password => 'hoge',
);

my $driver2 = DBIx::Thin::Driver->create(
    dsn => 'dbi:hoge:mydb',
);
is(ref($driver), 'DBIx::Thin::Driver::SQLite', 'create');
is(ref($driver2), 'DBIx::Thin::Driver', 'create');



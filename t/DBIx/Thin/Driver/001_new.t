#!/usr/bin/env perl

use FindBin::libs;
use Test::Utils;
use Test::More qw(no_plan);

BEGIN { use_ok('DBIx::Thin::Driver') }

my %values = (
    dsn => 'dbi:sqlite:mydb',
    username => 'root',
    password => 'hoge',
);
my $driver = DBIx::Thin::Driver->new(%values);
while (my ($k, $v) = each %values) {
    is($driver->{$k}, $values{$k}, "new - $k");
}

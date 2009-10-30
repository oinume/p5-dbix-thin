#!/usr/bin/env perl

use FindBin::libs;
use Test::Utils;
use Test::More qw(no_plan);
use Your::Model;

my $driver = Your::Model->driver;

my $sth = $driver->execute_select(
    "SELECT * FROM user WHERE name = ?",
    [ 'find-0' ]
);
ok($sth, 'execute_select');

eval {
    $driver->execute_select(
        'select hoge()',
    );
};
ok($@, 'execute_select (error)');

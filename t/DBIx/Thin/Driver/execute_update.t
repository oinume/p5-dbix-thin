#!/usr/bin/env perl

use FindBin::libs;
use Test::Utils;
use Test::More qw/no_plan/;
use Your::Model;

my $driver = Your::Model->driver;

my $sth = $driver->execute_update(
    'INSERT INTO user (name, email) VALUES (?, ?)',
    [ 'hogehoge', 'fuga@gmail.com' ]
);
ok($sth, 'execute_update');

eval {
    $driver->execute_update(
        'INSERT INTO user (name, email) VALUES ()',
    );
};
ok($@, 'execute_update (error)');

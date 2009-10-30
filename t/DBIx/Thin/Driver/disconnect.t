#!/usr/bin/env perl

use FindBin::libs;
use Test::Utils;
use Test::More qw(no_plan);
use Your::Model;

my $driver = Your::Model->driver;
my $dbh = $driver->connect;
$driver->disconnect;

ok(!$driver->{dbh}, 'disconnect');


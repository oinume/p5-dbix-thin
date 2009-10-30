#!/usr/bin/env perl

use FindBin::libs;
use Test::Utils;
use Test::More qw(no_plan);
use Your::Model;

my $driver = Your::Model->driver;
my $dbh = $driver->connect;
$dbh->disconnect;

my $dbh2 = $driver->reconnect;
ok($dbh2->ping, 'reconnect');
isnt($dbh2, $dbh, 'reconect');


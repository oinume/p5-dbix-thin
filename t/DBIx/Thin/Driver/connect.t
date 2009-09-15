#!/usr/bin/env perl

use FindBin::libs;
use Test::Utils;
use Test::More qw/no_plan/;
use Your::Model;

my $model = Your::Model->new;
my $dbh = $model->driver->connect;
ok($dbh && $dbh->ping && $dbh->FETCH('Active'), 'connect');
is($model->driver->dbh, $dbh, 'dbh');
is($model->driver->_dbh, $dbh, '_dbh');

# call connect twice and check dbh is the same.
my $dbh2 = $model->driver->connect;
is($dbh2, $dbh, 'connect');

# failed to connect
eval {
    Your::Model->driver->connect({
        dsn => 'DBI:mysql:dbix_thin:localhost',
        username => 'anonuser',
        password => 'anonpassword',
    });
};
ok($@, 'connect (error)');

eval {
    DBIx::Thin::Driver->new->connect;
};
ok($@, 'connect (error)');


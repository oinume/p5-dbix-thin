#!/usr/bin/env perl

use FindBin::libs;
use Test::Utils;
use Test::More qw/no_plan/;
use Your::Model;

my $model = Your::Model->new;
my $dbh = $model->connect;
ok($dbh && $dbh->ping && $dbh->FETCH('Active'), 'connect');

# failed to connect
eval {
    Your::Model->connect({
        dsn => 'DBI:mysql:dbix_thin:localhost',
        username => 'anonuser',
        password => '',
    });
};
ok($@, 'connect (error)');

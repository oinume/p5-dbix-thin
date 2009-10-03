#!/usr/bin/env perl

use FindBin::libs;
use Test::Utils;
use Test::More tests => 3;
use Your::Model;

my $model = Your::Model->new;
is($model->{klass}, 'Your::Model', 'new');
my $driver = $model->driver;

my $dsn = 'DBI:SQLite:your_project.sqlite3';
my $model2 = Your::Model->new({
    dsn => $dsn,
    username => '',
    password => '',
    connect_options => {
        HandleError => sub { Carp::croak(shift) },
    }
});
my $driver2 = $model2->driver;
is($driver2->{dsn}, $dsn, 'new (with connection_info)');
isnt($driver2, $driver, 'new (with connection_info)');

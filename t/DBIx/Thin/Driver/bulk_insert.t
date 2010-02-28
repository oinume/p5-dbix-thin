#!/usr/bin/env perl

use FindBin::libs;
use Test::Utils;
use Test::More qw(no_plan);
use Your::Model;

my $model = Your::Model->new;
my $driver = $model->driver;

my $counter = 0;
my @values = ();
for my $i (0 .. 2) {
    my $name = 'create_all-' . $counter++;
    push @values, {
        name => $name,
        email => $name . '@test.com',
    };
}

my $inserted = $driver->bulk_insert(
    model => $model,
    table => 'user',
    values => \@values,
);
ok($inserted, 'bulk_insert');

eval {
    $driver->bulk_insert(
        model => $model,
        table => 'user',
        values => [],
    );
};
ok($@, 'bulk_insert (empty values)');

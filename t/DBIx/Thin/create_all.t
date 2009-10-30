#!/usr/bin/env perl

use FindBin::libs;
use Test::Utils;
use Test::More qw(no_plan);
use Your::Model;

my $model = Your::Model->new;

my $counter = 0;

my @values = ();
for my $i (0 .. 2) {
    my $name = 'create_all-' . $counter++;
    push @values, {
        name => $name,
        email => $name . '@test.com',
    };
}

my $created_count = $model->create_all(
    'user',
    values => \@values
);
is($created_count, 3, 'create_all');

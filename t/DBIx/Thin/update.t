#!/usr/bin/env perl

use FindBin::libs;
use Test::Utils;
use Test::More qw/no_plan/;
use Your::Model;
use Your::Model::User;

my $model = Your::Model->new;

my $counter = 0;
my @values = ();
for my $i (0 .. 2) {
    my $name = 'update-' . $counter++;
    push @values, {
        name => $name,
        email => $name . '@test.com',
    };
}

$model->create_all('user', \@values);
my $updated_count = $model->update(
    'user',
    { # columns
        name => 'name was updated',
        email => 'updated@test.com',
    },
    { # where
        name => 'update-0',
    },
);
is($updated_count, 1, 'update');

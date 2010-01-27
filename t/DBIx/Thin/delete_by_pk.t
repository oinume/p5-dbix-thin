#!/usr/bin/env perl

use FindBin::libs;
use Test::Utils;
use Test::More qw(no_plan);
use Your::Model;

my $model = Your::Model->new;

my $counter = 0;
my @values = ();
for my $i (0 .. 2) {
    my $name = 'delete_by_pk-' . $counter++;
    push @values, {
        name => $name,
        email => $name . '@test.com',
    };
}

my $user = $model->create(
    'user',
    values => {
        name => 'delete_by_pk-0',
        email => 'delete_by_pk-0@test.com',
    }
);

my $deleted = $model->delete_by_pk('user', $user->id);
is($deleted, 1, 'delete');

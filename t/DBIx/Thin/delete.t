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
    my $name = 'delete-' . $counter++;
    push @values, {
        name => $name,
        email => $name . '@test.com',
    };
}

my $user = $model->create(
    'user',
    data => {
        name => 'delete-0',
        email => 'delete-0@test.com',
    }
);

my $deleted_count = $model->delete('user', $user->id);
is($deleted_count, 1, 'delete');

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

$model->create_all('user', \@values);
my $deleted_count = $model->delete(
    'user',
# TODO:
#    { # where
#        name => 'delete-0',
#    },
);
is($deleted_count, 1, 'delete');

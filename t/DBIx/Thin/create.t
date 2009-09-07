#!/usr/bin/env perl

use FindBin::libs;
use Test::Utils;
use Test::More qw/no_plan/;
use Your::Model;
use Your::Model::User;

my $model = Your::Model->new;

my $counter = 0;
my $name = 'create-' . $counter++;
my $user = $model->create(
    'user',
    {
        name => $name,
        email => $name . '@test.com',
    },
);
is($user->{name}, $name, 'create');

#!/usr/bin/env perl

use FindBin::libs;
use Test::Utils;
use Test::More qw/no_plan/;
use Your::Model;
use Your::Model::User;

my $model = Your::Model->new;

my $counter = 0;
my @values = ();

my $name = 'find_by_pk-0';
my $user = $model->create(
    'user',
    data => {
        name => $name, email => $name . '@test.com'
    }
);

my $actual = $model->find_by_pk('user', $user->id);
is($user->email, $actual->email, 'find_by_pk');

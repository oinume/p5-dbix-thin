#!/usr/bin/env perl

use FindBin::libs;
use Test::Utils;
use Test::More qw/no_plan/;
use Your::Model;

my $model = Your::Model->new;

my $counter = 0;
my @values = ();
for my $i (0 .. 2) {
    my $name = 'find-' . $counter++;
    push @values, {
        name => $name,
        email => $name . '@test.com',
    };
}

$model->create_all('user', values => \@values);

my $user = $model->find(
    'user',
    where => { name => 'find-0' }
);
is($user->email, 'find-0@test.com', 'find');

my $user2 = $model->find(
    'user',
    where => { name => 'not_exist' }
);
ok(!$user2, 'find (not found)');


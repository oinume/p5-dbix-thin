#!/usr/bin/env perl

use FindBin::libs;
use Test::Utils;
use Test::More qw/no_plan/;
use Your::Model;

my $model = Your::Model->new;

my $counter = 0;
my @values = ();
for my $i (0 .. 2) {
    my $name = 'find_all-' . $counter++;
    push @values, {
        name => $name,
        email => $name . '@test.com',
    };
}
$model->create_all('user', data => \@values);

my $iterator = $model->find_all(
    'user',
    where => { name => { op => 'LIKE', value => '%find_all%' } }
);
ok($iterator->size >= 3, 'find_all');

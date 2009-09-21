#!/usr/bin/env perl

use utf8;
use FindBin::libs;
use Test::Utils;
use Test::More qw/no_plan/;
use Your::Model;

my $model = Your::Model->new;

my $counter = 0;
my $name = 'create-' . $counter++;
my $user = $model->create(
    'user',
    data => {
        name => $name,
        email => $name . '@test.com',
    },
);
is($user->{name}, $name, 'create');
# check value of primary key
ok($user->{$user->schema_info->{primary_key}}, 'create');

my $name2 = 'おいぬめ-0';
my $user2 = $model->create(
    'user',
    data => {
        name => $name2,
        email => 'oinume-2@test.com',
    },
);
is($user2->{name}, $name2, 'create (utf8_off)');
ok(utf8::is_utf8($user2->{name}), 'create (utf8_on)');

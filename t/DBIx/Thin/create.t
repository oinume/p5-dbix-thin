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
    values => {
        name => $name,
        email => $name . '@test.com',
    },
);
is($user->name, $name, 'create');
# check value of primary key
my $primary_key = $user->schema_info->{primary_key};
ok($user->$primary_key, 'create');

# check utf8
my $name2 = 'おいぬめ-0';
my $user2 = $model->create(
    'user',
    values => {
        name => $name2,
        email => 'oinume-2@test.com',
    },
);
is($user2->name, $name2, 'create (utf8_off)');
ok(utf8::is_utf8($user2->name), 'create (utf8_on)');

# check deflate
my $user3 = $model->create(
    'user',
    values => {
        name => $name2,
        email => 'oinume-3@test.com',
        created_at => '2009/09/30 13:59:10',
    },
);
is($user3->get_raw_value('created_at'), '2009-09-30 13:59:10', 'create (deflate)');

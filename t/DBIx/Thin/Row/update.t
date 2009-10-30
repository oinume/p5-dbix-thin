#!/usr/bin/env perl

use FindBin::libs;
use Test::Utils;
use Test::More qw(no_plan);
use Data::Dumper;
use Your::Model;

my $model = Your::Model->new;
my $user = undef;
my %values = (
    name => 'row-update',
    email => 'row@hoge.com',
    created_at => '2009-09-01 12:00:00',
);

Your::Model->create(
    'user',
    values => \%values,
);

$user = Your::Model->find(
    'user',
    where => { name => 'row-update' },
);
my $new_created_at = '2009-10-01 23:59:59';
$user->set(created_at => $new_created_at);
$user->update;

my $user2 = Your::Model->find_by_pk('user', $user->id);
is($user2->get_raw_value('created_at'), $new_created_at, 'update');

# TODO: test for dirty column

#!/usr/bin/env perl

use FindBin::libs;
use Test::Utils;
use Test::More qw(no_plan);
use Data::Dumper;
use Your::Model;

BEGIN { use_ok('DBIx::Thin::Row'); }

my $model = Your::Model->new;
my $user = undef;
my %values = (
    name => 'row-0',
    email => 'row@hoge.com',
    created_at => '2009-09-01 12:00:00',
);

# setup
{
    $user = Your::Model->create(
        'user',
        values => \%values,
    );

    $values{id} = $user->{_values}->{id};
    $user = Your::Model->find_by_pk('user', $values{id});
    ok($user->{_values}->{id} > 0, '(setup)');
}

# get_value
{
    is($user->id, $values{id}, 'accessor (id)');
    is($user->name, $values{name}, 'accessor (name)');
    is($user->email, $values{email}, 'accessor (email)');
    is($user->created_at, '2009/09/01 12:00:00', 'accessor (created_at with inflate)');
}


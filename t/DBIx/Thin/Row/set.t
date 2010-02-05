#!/usr/bin/env perl

use FindBin::libs;
use Test::Utils;
use Test::More qw(no_plan);
use Data::Dumper;
use Your::Model;

my $model = Your::Model->new;
my $user = undef;
my %values = (
    name => 'row-set',
    email => 'row@hoge.com',
    created_at => '2009-01-01 12:00:00',
);

Your::Model->create(
    'user',
    values => \%values,
);

$user = Your::Model->find(
    'user',
    where => { name => 'row-set' },
);
my $created_at_inflated = '2009/10/01 23:59:59';
my $created_at = $created_at_inflated;
$created_at =~ s!/!-!g;
$user->set(created_at => $created_at_inflated);

# check the value is deflated
is($user->get_raw_value('created_at'), $created_at, 'set (deflated)');
is($user->created_at, $created_at_inflated, 'set (inflated)');

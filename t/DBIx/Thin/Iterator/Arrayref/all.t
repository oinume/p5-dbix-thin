#!/usr/bin/env perl

use FindBin::libs;
use Test::Utils;
use Test::More qw/no_plan/;
use Data::Dumper;

#print Dumper(\@INC);

BEGIN { use_ok('DBIx::Thin::Iterator::Arrayref'); }

my @data = (
    { name => 'tokyo', email => 'tokyo@test.com', __index__ => 0 },
    { name => 'osaka', email => 'osaka@test.com', __index__ => 1 },
    { name => 'sapporo', email => 'sapporo@test.com', __index__ => 2 },
);
my $iterator = undef;

# new
{
    $iterator = DBIx::Thin::Iterator::Arrayref->new(
        data => \@data,
        object_class => 'Your::Model::User'
    );
    ok($iterator, 'new');
}

# next
{
    my @list = ();
    while (my $row = $iterator->next) {
        push @list, $row;
    }
    is($list[0]->{name}, $data[0]->{name}, 'next');
    is($list[0]->{email}, $data[0]->{email}, 'next');

    # Returns undef
    ok(!$iterator->next, 'next');
}

# size
{
    is(scalar(@data), $iterator->size, 'size');
}


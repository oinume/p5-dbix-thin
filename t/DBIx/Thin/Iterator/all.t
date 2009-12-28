#!/usr/bin/env perl

use FindBin::libs;
use Test::Utils;
use Test::More qw(no_plan);
use Data::Dumper;
use Your::Model::Schema::Inflate;

BEGIN { use_ok('DBIx::Thin::Iterator'); }

my @data = (
    { name => 'tokyo', email => 'tokyo@test.com', __index__ => 0 },
    { name => 'osaka', email => 'osaka@test.com', __index__ => 1 },
    { name => 'sapporo', email => 'sapporo@test.com', __index__ => 2 },
);
my $iterator = undef;

# create
{
    $iterator = DBIx::Thin::Iterator->create(
        data => \@data,
        object_class => 'Your::Model::User'
    );
    is(ref($iterator), 'DBIx::Thin::Iterator::Arrayref', 'create');
}

# as_array
{
    my @array = $iterator->as_array;
    for my $obj (@array) {
        $obj->{_dirty_columns} = {};
    }
#    use Data::Dumper;
#    print Dumper \@array;
    for my $i (0 .. $#data) {
        is_deeply($array[$i]->{_values}, $data[$i], "as_array ($i)");
    }
}

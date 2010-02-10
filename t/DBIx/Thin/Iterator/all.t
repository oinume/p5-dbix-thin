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
        # delete unnessesary field
        $obj->{_dirty_columns} = {};
    }
#    use Data::Dumper;
#    print Dumper \@array;
    for my $i (0 .. $#data) {
        is_deeply($array[$i]->{_values}, $data[$i], "as_array ($i)");
    }
}

# as_data_array
{
    my @array = $iterator->as_data_array;
#    use Data::Dumper;
#    print Dumper \@array;
    for my $i (0 .. $#data) {
        is_deeply($array[$i], $data[$i], "as_data_array ($i)");
    }
}

# collect
{
    my $iterator2 = DBIx::Thin::Iterator->create(
        data => \@data,
        object_class => 'Your::Model::User'
    );
    my @array = $iterator2->collect(sub { shift->name });
    is_deeply(\@array, [ qw(tokyo osaka sapporo) ], 'collect');
}

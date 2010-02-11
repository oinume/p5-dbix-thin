#!/usr/bin/env perl

use FindBin::libs;
use Test::Utils;
use Test::More qw(no_plan);
use Your::Model;

my $model = Your::Model->new;

my $counter = 0;
my @values = ();
for my $i (0 .. 10) {
    my $name = 'search_with_pager-' . $counter++;
    push @values, {
        name => $name,
        email => $name . '@test.com',
    };
}
$model->create_all('user', values => \@values);

my $expected_total_entires = $model->count_by_sql(
    sql => "SELECT COUNT(*) AS c FROM user WHERE name LIKE ?",
    bind => [ '%search_with_pager-%' ],
);
my ($iterator, $pager) = $model->search_with_pager(
    'user',
    where => {
        name => { op => 'LIKE', value => 'search_with_pager-%' }
    },
    entries_per_page => 3,
    page => 2,
);
is($pager->total_entries, $expected_total_entires, 'search_with_pager (total_entries)');
is($pager->entries_per_page, 3, 'search_with_pager (entries_per_page)');
is($pager->current_page, 2, 'search_with_pager (current_page)');

# TODO: more test.

#use Data::Dumper;
#print Dumper $pager;

#!/usr/bin/env perl

use FindBin::libs;
use Test::Utils;
use Test::More qw(no_plan);
use DBIx::Thin::Pager;

my $TOTAL_ENTRIES = 105;
my $pager = DBIx::Thin::Pager->new(
    total_entries => $TOTAL_ENTRIES,
    entries_per_page => 10,
    current_page => 1,
);

# new
{
    ok($pager, 'new');
}

# total_entries
{
    is($pager->total_entries, $TOTAL_ENTRIES, 'total_entries');
}

# as_navigation
{
    my @navigation = $pager->as_navigation;
#    use Data::Dumper;
#    print Dumper \@navigation;
    is(scalar(@navigation), 10, 'as_navigation');
    ok($navigation[0]->{is_first_page}, 'as_navigation(is_first_page)');
    ok(!$navigation[1]->{is_first_page}, 'as_navigation(is_first_page)');

    is($navigation[0]->{page}, 1, 'as_navigation(page)');
    is($navigation[1]->{page}, 2, 'as_navigation(page)');
}


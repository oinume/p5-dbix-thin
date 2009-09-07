package Test::Utils;

use strict;
use warnings;
use utf8;
use Test::More;

BEGIN {
    eval "use DBD::SQLite";
    my $no_sqlite = $@;
    eval "use DBD::mysql";
    my $no_mysql = $@;
    if ($no_sqlite && $no_mysql) {
        plan skip_all => 'needs DBD::SQLite or DBD::mysql for testing';
    }
}

sub import {
    strict->import;
    warnings->import;
    utf8->import;
}

1;

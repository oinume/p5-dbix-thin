package DBIx::Thin::Iterator::Null;

use strict;
use warnings;

use base qw(DBIx::Thin::Iterator);

sub new { bless {}, shift }

sub next { undef }

sub size { 0 }

sub group_by { return () }

sub delegate {
    # just override to avoid loop
}

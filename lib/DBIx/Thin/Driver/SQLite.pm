package DBIx::Thin::Driver::SQLite;

use strict;
use warnings;

use base qw(DBIx::Thin::Driver);

sub last_insert_id {
    my ($self, $sth, $opts) = @_;
    return $self->_dbh->func('last_insert_rowid');
}

1;

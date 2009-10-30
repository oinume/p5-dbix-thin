package DBIx::Thin::Driver::PostgreSQL;

use strict;
use warnings;

use base qw(DBIx::Thin::Driver);

sub last_insert_id {
    my ($self, $sth, $opts) = @_;
    return $self->_dbh->last_insert_id(undef, undef, $opts->{table}, undef);
}

sub sql_for_unixtime {
    return "TRUNC(EXTRACT('epoch' from NOW()))";
}

1;

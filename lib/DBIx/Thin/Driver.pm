package DBIx::Thin::Driver;

=head1 NAME

DBIx::Thin::Driver - A base class for database driver

=cut

use strict;
use warnings;
use Carp qw/croak/;

=head1 CLASS METHODS

=cut

=head2 new

Creates an instance.

=cut
sub new { bless {}, shift };


=head2 last_insert_id

Returns id of last inserted row.

=cut
sub last_insert_id {
    return 0;
}

=head2 sql_for_unixtime

unixtime.

=cut
sub sql_for_unixtime {
    croak "Not implemented.";
}

=head2 bulk_insert

Interface for inserting multi rows.

=cut
sub bulk_insert {
    my ($thin, $table, $args) = @_;

    my $dbh = $thin->dbh;
    $dbh->begin_work;

    my $inserted = 0;
    for my $arg ( @{$args} ) {
        $thin->create($table, $arg);
        $inserted++;
    }

    $dbh->commit;

    return $inserted;
}

1;

package DBIx::Thin::Profiler;

use strict;
use warnings;

sub new {
    my ($class) = @_;
    my $self = bless {
        query_logs => [],
    }, $class;
    $self->reset;

    return $self;
}

sub reset {
    shift->{query_logs} = [];
}

sub record_query {
    my ($self, $sql, $bind) = @_;

    my $log = normalize_query($sql);
    if (my $bind_value = join ', ', @{ $bind || [] } ) {
        $log .= ' :binds ' . $bind_value;
    }

    push @{ $self->{query_logs} }, $log;
}

sub normalize_query {
    my $sql = shift;
    $sql =~ s/^\s*//;
    $sql =~ s/\s*$//;
    $sql =~ s/[\r\n]/ /g;
    $sql =~ s/\s+/ /g;
    return $sql;
}

'base code from DBIx::Skinny';

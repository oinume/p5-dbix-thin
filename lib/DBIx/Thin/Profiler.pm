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

    my $log = sprintf(<<"EOS", normalize_sql($sql), normalize_bind($bind));
%s
#BIND: (%s)
EOS
    push @{ $self->{query_logs} }, $log;
}

sub normalize_sql {
    my $sql = shift;
    $sql =~ s/^\s*//;
    $sql =~ s/\s*$//;
#    $sql =~ s/[\r\n]/ /g;
#    $sql =~ s/\s+/ /g;
    return $sql;
}

sub normalize_bind {
    my ($values) = @_;

    unless (@{$values}) {
        return '';
    }

    my $str = '';
    for my $v (@{$values}) {
        $str .= (defined $v) ? "'$v', " : "undef, ";
    }
    chop $str;
    chop $str;

    return $str;
}

'base code from DBIx::Skinny';

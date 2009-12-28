package DBIx::Thin::SchemaGenerator::DDLParser;

use strict;
use warnings;
use Carp qw(croak);
use DBI;

sub new {
    my ($class, %args) = @_;
    bless { %args }, $class;
}

sub parse {
    die "Implement by sub-class";
}

package DBIx::Thin::SchemaGenerator::DDLParser::MySQL;
use base qw(DBIx::Thin::SchemaGenerator::DDLParser);

sub parse {
    my ($self, $table, $dsn, $username, $password) = @_;

    my $primary_key = $self->{options}->{primary_key};
    my @fields = ();
    eval {
        my $dbh = DBI->connect($dsn, $username, $password, { RaiseError => 1 });
        my $sth = $dbh->prepare("DESC $table");
        $sth->execute;

        my $table_pk = '';
        while (my $row = $sth->fetchrow_hashref) {
            my $field = $row->{Field};
            push @fields, { name => $field, type => $row->{Type} };
            if ($row->{Key} eq 'PRI') {
                $table_pk = $row->{Field};
            }
        }
        $sth->finish();
        # TODO: handling complex primary keys
        $primary_key ||= $table_pk;
    };
    $@ && die "[error] $@";

    return {
        fields => \@fields,
        primary_key => $primary_key,
    };
}

1;

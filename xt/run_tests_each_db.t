#!/usr/bin/env perl

use strict;
use warnings;
use Data::Dumper qw/Dumper/;
use File::Find;
use FindBin qw/$Bin/;
use FindBin::libs;
use Test::Harness qw(runtests execute_tests);

use DBIx::Thin;
use DBIx::Thin::Driver;

my @test_files = ();

sub filter {
    my $name = $_;
    my $dir = $File::Find::dir;
    if ($name =~ /^\./ || $dir =~ /\.svn/) {
        return;
    }

    if ($name =~ /\.t/) {
        push @test_files, "$dir/$name";
    }
}

#----------------------------#
# Main
#----------------------------#
find(\&filter, "$Bin/../t");
@test_files = sort @test_files;

my %drivers = DBIx::Thin::Driver->available_drivers;
#print Dumper \%drivers;
%drivers = (
    sqlite => 'SQLite',
    mysql => 'MySQL',
);

print "[All tests]\n";
print join("\n", @test_files), "\n\n";

#print Dumper \@test_files;

while (my ($key, $value) = each %drivers) {
    my $class = 'DBIx::Thin::Test::' . $value;
    my $test = $class->new(dir => $Bin);

    unless ($test->setup) {
        print "Skip tests for '$key'\n";
    }

    runtests(@test_files);
    $test->teardown;
}


package DBIx::Thin::Test;
sub new {
    my ($class, %args) = @_;
    bless { dir => $args{dir} }, shift;
}
sub setup {}
sub teardown {}


#--------------------------------#
# SQLite
#--------------------------------#
package DBIx::Thin::Test::SQLite;
use base qw/DBIx::Thin::Test/;

sub setup {
    my ($self) = @_;

    if (system("which sqlite3 > /dev/null") == 0) {
        unlink '/tmp/dbix_thin_test.sqlite3';
        system "sqlite3 /tmp/dbix_thin_test.sqlite3 < $self->{dir}/../t/create_tables_sqlite3.sql";
        $ENV{DBIX_THIN_DSN} = "dbi:SQLite:dbname=/tmp/dbix_thin_test.sqlite3";
        $ENV{DBIX_THIN_USERNAME} = 'root';
        $ENV{DBIX_THIN_PASSWORD} = 'hoge';
        return 1;
    }
    else {
        return 0;
    }
}

sub teardown {
    unlink '/tmp/dbix_thin_test.sqlite3';
}

#--------------------------------#
# MySQL
#--------------------------------#
package DBIx::Thin::Test::MySQL;
use base qw/DBIx::Thin::Test/;

sub setup {
    my $self = shift;
    my $username = $ENV{DBIX_THIN_USERNAME} || 'root';
    my $password = $ENV{DBIX_THIN_PASSWORD} || '';
    if (system("which mysql") == 0) {
        system "mysql -B -u$username -p'$password' < $self->{dir}/../t/create_tables_mysql.sql";
        $ENV{DBIX_THIN_DSN} = "dbi:mysql:database=dbix_thin_test";
        $ENV{DBIX_THIN_USERNAME} = $username;
        $ENV{DBIX_THIN_PASSWORD} = $password;
        return 1;
    }
    else {
        return 0;
    }
}

sub teardown {
    
}

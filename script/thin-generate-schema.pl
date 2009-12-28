#!/usr/bin/env perl

use strict;
use warnings;
use lib "lib";
use DBIx::Thin::SchemaGenerator;

DBIx::Thin::SchemaGenerator->new->run(@ARGV);

__END__

=head1 NAME

 thin-generate-schema.pl - Generate model class of DBIx::Thin

=head1 SYNOPSIS

 thin-generate-schema.pl [options] TABLE_NAME MODULE_NAME

 Description:
    Generate a model class of DBIx::Thin

 Options:
    -d, --dsn           Connection datasource
    -u, --username      Username
    -p, --password      Password
    -k, --primary-key   Primary key field
    -u, --utf8          enable utf8 flag on DBIx::Thin
    -h, --help          Print this message and exit

=cut

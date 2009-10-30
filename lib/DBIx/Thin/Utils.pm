package DBIx::Thin::Utils;

use strict;
use warnings;
use Carp qw(croak);
use Exporter;
use base qw(Exporter);

our @EXPORT_OK = qw(check_required_args);

sub check_required_args {
    my ($keys, $values) = @_;
    for my $key (@{ $keys || [] }) {
        unless (defined $values->{$key}) {
            croak "Argument '$key' is not defined.";
        }
    }
}

1;

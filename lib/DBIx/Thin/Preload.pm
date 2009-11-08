package DBIx::Thin::Preload;

use strict;
use warnings;
use UNIVERSAL::require;

my @PRELOAD_MODULES = qw(
   File::Basename
   File::Spec
   DBIx::Thin
   DBIx::Thin::Accessor
   DBIx::Thin::Driver
   DBIx::Thin::Inflate
   DBIx::Thin::Iterator
   DBIx::Thin::Iterator::Arrayref
   DBIx::Thin::Iterator::StatementHandle
   DBIx::Thin::Profiler
   DBIx::Thin::Row
   DBIx::Thin::Schema
   DBIx::Thin::Statement
   DBIx::Thin::Utils
);

sub import {
    for my $module (@PRELOAD_MODULES) {
        $module->require or croak $@;
        if ($module->can('requires')) {
            for my $m ($module->requires) {
                $m->require or croak $@;
            }
        }
    }
    return;
}

1;

__END__

=head1 NAME

DBIx::Thin::Preload - Preload DBIx::Thin's related modules.

=head1 SYNOPSIS

  # in your startup.pl file for mod_perl
  use DBIx::Thin::Preload;
  use Your::Model;
  Your::Model->setup(
      .....
  );

OR

  # in your httpd.conf
  PerlModule DBIx::Thin::Preload

=cut

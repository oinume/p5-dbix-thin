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
   DBIx::Thin::Iterator
   DBIx::Thin::Iterator::Arrayref
   DBIx::Thin::Iterator::Null
   DBIx::Thin::Iterator::StatementHandle
   DBIx::Thin::Pager
   DBIx::Thin::Profiler
   DBIx::Thin::Row
   DBIx::Thin::Statement
   DBIx::Thin::Utils
);
# TODO: Undefined subroutine &DBIx::Thin::Schema::require called at ...
#   DBIx::Thin::Schema
#   DBIx::Thin::Schema::Inflate

sub import {
    for my $module (@PRELOAD_MODULES) {
        $module->use or croak $@;
        if ($module->can('requires')) {
            for my $m ($module->requires) {
                $m->use or croak $@;
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

OR

  # in your httpd.conf
  PerlModule DBIx::Thin::Preload
  PerlModule Your::Model

=head1 DESCRIPTION

DBIx::Thin::Preload enables COW(Copy On Write) on persistent environment, such as mod_perl, FastCGI, and so on.
The module loads all DBIx::Thin's related modules when "use DBIx::Thi::Preload".
It is recommended that you don't use the module in pure CGI.

=cut

# TODO:
# DBIx::Thin::Preload qw(
#    Driver::MySQL
#    Schema::Inflate::Time::Piece
#);

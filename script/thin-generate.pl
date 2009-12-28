#!/usr/bin/env perl

use strict;
use warnings;
use lib "lib";
use DBIx::Thin::SchemaGenerator;

DBIx::Thin::SchemaGenerator->new->run(@ARGV);

package DBIx::Thin::Schema;

use strict;
use warnings;
use Carp qw/croak/;

BEGIN {
    if ($] <= 5.008000) {
        require Encode;
    } else {
        require utf8;
    }
}

my %table2schema_class = ();
sub import {
    my $caller = caller;

    my @functions = qw/
        install_table
          schema primary_key columns schema_info
        install_inflate_rule
          inflate deflate call_inflate call_deflate
          callback _do_inflate
        trigger call_trigger
        install_utf8_columns
          is_utf8_column utf8_on utf8_off
    /;
    no strict 'refs';
    for my $func (@functions) {
        *{"$caller\::$func"} = \&$func;
    }

    my $schema_info = {
        primary_key => undef,
        columns => undef,
        triggers => {},
    };
    *{"$caller\::schema_info"} = sub { $schema_info };
    my $_schema_inflate_rule = {};
    *{"$caller\::inflate_rules"} = sub { $_schema_inflate_rule };
    my $_utf8_columns = {};
    *{"$caller\::utf8_columns"} = sub { $_utf8_columns };

    strict->import;
#    warnings->import;
}

sub _get_caller_class {
    my $caller = caller(1);
    return $caller;
}

sub table2schema_class($) {
    my $table = shift;
    my $schema_class = $table2schema_class{$table};
    unless ($schema_class) {
        Carp::croak "Cannot find shcema_class for '$table'";
    }
    return $schema_class;
}

sub install_table ($$) {
    my ($table, $install_code) = @_;

    my $class = _get_caller_class;
#warn "caller class: $class\n";
    $class->schema_info->{installing_table} = $table;
    $install_code->();
    $table2schema_class{$table} = $class;
    delete $class->schema_info->{installing_table};
}

sub schema (&) { shift }

sub primary_key ($) {
    my $column = shift;
    _get_caller_class()->schema_info->{primary_key} = $column;
}

sub columns (@) {
    my @columns = @_;
    _get_caller_class()->schema_info->{columns} = \@columns;
}

sub trigger ($$) {
    my ($trigger_name, $code) = @_;

    my $class = _get_caller_class;
#    push @{$class->schema_info->{
#        $class->schema_info->{installing_table}
#    }->{triggers}->{$trigger_name}}, $code;
    
    my $triggers = $class->schema_info->{triggers};
    unless ($triggers->{$trigger_name}) {
        $triggers->{$trigger_name} ||= [];
    }
    push @{ $triggers->{$trigger_name} }, $code;
}

sub call_trigger {
    my ($class, $thin, %args) = @_;
    # TODO: check args
    my $triggers = $class->schema_info->{triggers}->{$args{trigger_name}};
    for my $code (@{ $triggers || [] }) {
        $code->($thin, $args{trigger_args});
    }
}

sub install_inflate_rule ($$) {
    my ($rule, $install_inflate_code) = @_;

    my $class = _get_caller_class;
    $class->inflate_rules->{_installing_rule} = $rule;
        $install_inflate_code->();
    delete $class->inflate_rules->{_installing_rule};
}

sub inflate (&) {
    my $code = shift;

    my $class = _get_caller_class;
    $class->inflate_rules->{
        $class->inflate_rules->{_installing_rule}
    }->{inflate} = $code;
}

sub deflate (&) {
    my $code = shift;

    my $class = _get_caller_class;
    $class->inflate_rules->{
        $class->inflate_rules->{_installing_rule}
    }->{deflate} = $code;
}

sub call_inflate {
    my $class = shift;

    return $class->_do_inflate('inflate', @_);
}

sub call_deflate {
    my $class = shift;

    return $class->_do_inflate('deflate', @_);
}

sub _do_inflate {
    my ($class, $key, $col, $data) = @_;

    my $inflate_rules = $class->inflate_rules;
    for my $rule (keys %{$inflate_rules}) {
        if ($col =~ /$rule/ and my $code = $inflate_rules->{$rule}->{$key}) {
            $data = $code->($data);
        }
    }
    return $data;
}

sub callback (&) { shift }

sub install_utf8_columns (@) {
    my @columns = @_;
    my $class = _get_caller_class;
    for my $column (@columns) {
        $class->utf8_columns->{$column} = 1;
    }
}

sub is_utf8_column {
    my ($class, $column) = @_;
    return $class->utf8_columns->{$column} ? 1 : 0;
}

sub utf8_on {
    my ($class, $column, $data) = @_;

    if ($class->is_utf8_column($column)) {
        if ($] <= 5.008000) {
            Encode::_utf8_on($data) unless Encode::is_utf8($data);
        } else {
            utf8::decode($data) unless utf8::is_utf8($data);
        }
    }

    return $data;
}

sub utf8_off {
    my ($class, $column, $data) = @_;

    if ($class->is_utf8_column($column)) {
        if ($] <= 5.008000) {
            Encode::_utf8_off($data) if Encode::is_utf8($data);
        } else {
            utf8::encode($data) if utf8::is_utf8($data);
        }
    }
    return $data;
}

1;

__END__

=head1 NAME

DBIx::Thin::Schema - Schema DSL for DBIx::Thin

=head1 SYNOPSIS

  package Your::Model;

  use DBIx::Thin;
  DBIx::Thin->setup({
      dsn => 'dbi:SQLite:',
      username => 'root',
      password => '',
  });
  
  1;
  
  package Your::Model::Schema:
  use DBIx::Thin::Schema;
  
  # set user table schema settings
  install_table user => schema {
      primary_key 'id';
      columns qw/id name created_at/;

      trigger pre_insert => callback {
          # hook
      };

      trigger pre_update => callback {
          # hook
      };
  };
  
  # TODO: not implemented yet
  install_inflate_rule '^name$' => callback {
      inflate {
          my $value = shift;
          # inflate hook
      };
      deflate {
          my $value = shift;
          # deflate hook
      };
  };
  
  1;


package DBIx::Thin::Schema;

use strict;
use warnings;
use Carp qw(croak);
use DBIx::Thin::Utils qw(check_required_args);
use DBIx::Thin::Schema::Inflate qw(get_inflate_code get_deflate_code);
use Storable qw(dclone);

my ($is_utf8_function, $utf8_on_function, $utf8_off_function);
BEGIN {
    # TODO: updating code of DBIx::Skinny
    if ($] <= 5.008000) {
        require Encode;
        $is_utf8_function = \&Encode::is_utf8;
        $utf8_on_function = \&Encode::_utf8_on;
        $utf8_off_function = \&Encode::_utf8_off;
    } else {
        require utf8;
        $is_utf8_function = \&utf8::is_utf8;
        $utf8_on_function = \&utf8::decode;
        $utf8_off_function = \&utf8::encode;
    }
};

my %table2schema_class = ();
sub import {
    my $caller = caller;

    {
        no strict 'refs';
        my @not_define = qw(__ANON__ BEGIN VERSION croak import check_required_args);
        my %symbols = %DBIx::Thin::Schema::;
        my @functions = ();
        for my $name (keys %symbols) {
            next if (grep { $name eq $_ } @not_define);
            push @functions, $name;
        }

        for my $f (@functions) {
            *{"$caller\::$f"} = \&$f;
        }

        my $schema_info = {
            table => undef,
            primary_key => undef,
            columns => {},
            column_names => [],
            triggers => {},
            utf8_columns => {},
            defaults => {},
        };

        *{"$caller\::schema_info"} = sub { $schema_info };
        *{"$caller\::utf8_columns"} = sub { $schema_info->{utf8_columns} };
    }

    strict->import;
    warnings->import;
}

sub caller_class {
    my $caller = caller(1);
    return $caller;
}

sub table2schema_class($) {
    my $table = shift;
    return $table2schema_class{$table};
}

sub install_table ($$) {
    my ($table, $install_code) = @_;
    my $class = caller_class;
    my $schema_info = $class->schema_info;
#warn "caller class: $class\n";
    $schema_info->{_installing_table} = $table;
    $schema_info->{table} = $table;
    $table2schema_class{$table} = $class;
    
    $install_code->();
    delete $schema_info->{_installing_table};

    if (defined $schema_info->{primary_key}) {
        my $pk = $schema_info->{primary_key};
        unless (grep { $_ eq $pk } @{ $schema_info->{column_names} || [] }) {
            croak "Column definition for primary key '$pk' not found.";
        }
    }
}

sub schema (&) { shift }

sub primary_key ($) {
    my $column = shift;
    caller_class->schema_info->{primary_key} = $column;
}

sub columns (@) {
    my $class = caller_class;
    my $schema_info = $class->schema_info;
    my $defaults = $schema_info->{defaults};

    while (my ($name, $def) = splice @_, 0, 2) {
        my $inflate = delete $def->{inflate};
        my $deflate = delete $def->{deflate};
        
        my $cloned_def = Storable::dclone $def;
        if (defined $inflate) {
            $def->{inflate} = $inflate;
            $cloned_def->{inflate} = $inflate;
        }
        if (defined $deflate) {
            $def->{deflate} = $deflate;
            $cloned_def->{deflate} = $deflate;
        }
        
        if ($def->{type} eq 'string') {
            no warnings 'uninitialized';
            if (defined $def->{utf8} && $def->{utf8} == 1) {
                $schema_info->{utf8_columns}->{$name} = 1;
            }
            elsif (!defined $def->{utf8} && $defaults->{string_is_utf8} == 1) {
                # apply default 'utf8' value
                $schema_info->{utf8_columns}->{$name} = 1;
                $cloned_def->{utf8} = 1;
            }
        }

        $schema_info->{columns}->{$name} = $cloned_def;
        push @{ $schema_info->{column_names} }, $name;
    }
#    print Dumper $schema_info;
}

sub Integer { 'integer' }
sub Decimal { 'decimal' }
sub String { 'string' }
sub Binary { 'binary' }
sub Boolean { 'boolean' }
sub Datetime { 'datetime' }
sub Date { 'date' }
sub Time { 'time' }

sub defaults {
    my %args = @_;
    my $defaults = caller_class->schema_info->{defaults};
    while (my ($k, $v) = each %args) {
        # TODO: need to validate values? (low priority)
        $defaults->{$k} = $v;
    }
}

sub is_utf8_column {
    my ($class, $column) = @_;
    return $class->utf8_columns->{$column} ? 1 : 0;
}

sub utf8_on {
    my ($class, $column, $value) = @_;
    if ($class->is_utf8_column($column) && !$is_utf8_function->($value)) {
        $utf8_on_function->($value);
    }
    return $value;
}

sub force_utf8_on {
    my ($class, $column, $value) = @_;
    unless ($is_utf8_function->($value)) {
        $utf8_on_function->($value);
    }
    return $value;
}

sub utf8_off {
    my ($class, $column, $value) = @_;
    if ($class->is_utf8_column($column) && $is_utf8_function->($value)) {
        $utf8_off_function->($value);
    }
    return $value;
}

sub force_utf8_off {
    my ($class, $column, $value) = @_;
    if ($is_utf8_function->($value)) {
        $utf8_off_function->($value);
    }
    return $value;
}

sub inflate_code($) {
    my ($name) = @_;
    my $code = get_inflate_code($name);
    unless (defined $code) {
        croak "No inflate code for '$name'.";
    }
    return $code;
}

sub deflate_code($) {
    my ($name) = @_;
    my $code = get_deflate_code($name);
    unless (defined $code) {
        croak "No deflate code for '$name'.";
    }
    return $code;
}


sub trigger ($$) {
    my ($trigger_name, $code) = @_;

    my $class = caller_class;
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
    check_required_args([ qw(trigger_name) ], \%args);
    my $triggers = $class->schema_info->{triggers}->{$args{trigger_name}};
    for my $trigger (@{ $triggers || [] }) {
        $trigger->($thin, $args{trigger_args});
    }
}

#sub install_inflate_rule ($$) {
#    my ($rule, $install_inflate_code) = @_;
#
#    my $class = caller_class;
#    $class->inflate_rules->{_installing_rule} = $rule;
#    $install_inflate_code->();
#    delete $class->inflate_rules->{_installing_rule};
#}
#
#sub inflate (&) {
#    my $code = shift;
#
#    my $class = caller_class;
#    $class->inflate_rules->{
#        $class->inflate_rules->{_installing_rule}
#    }->{inflate} = $code;
#}
#
#sub deflate (&) {
#    my $code = shift;
#
#    my $class = caller_class;
#    $class->inflate_rules->{
#        $class->inflate_rules->{_installing_rule}
#    }->{deflate} = $code;
#}
#
#sub callback (&) { shift }

sub call_inflate {
    my $class = shift;
    return $class->_do_inflate('inflate', @_);
}

sub call_deflate {
    my $class = shift;
    return $class->_do_inflate('deflate', @_);
}

sub _do_inflate {
    my ($class, $method, $column, $value) = @_;
#    warn "_do_inflate: $method, column=$column, value=$value\n";
    my %columns = %{ $class->schema_info->{columns} };
    my $callback = $columns{$column}->{$method};
    if (defined $callback) {
        $callback->($column, $value);
    } else {
        return $value;
    }
}

1;

__END__

=head1 NAME

DBIx::Thin::Schema - Schema DSL for DBIx::Thin

=head1 SYNOPSIS

  package Your::Model;

  use DBIx::Thin;
  DBIx::Thin->setup(
      dsn => 'dbi:SQLite:model.sqlite',
      username => 'root',
      password => '',
  );
  
  1;
  
  package Your::Model::User;
  
  use DBIx::Thin::Schema;
  
  # set user table schema settings
  install_table user => schema {
      primary_key 'id';
      columns qw(id name created_at);

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

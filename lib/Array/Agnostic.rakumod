use v6.d;

my class X::Array::NoImplementation is Exception {
    has $.object;
    has $.method;
    method message() {
        my $text = "No implementation of $.method method found for $.object.^name().";
        $*DEFAULT-CLEAN
          ?? "$text\nThis is needed to be able to clear an agnostic hash."
          !! $*DEFAULT-UP
            ?? "$text\nThis is needed to be able to insert elements in an agnostic array"
            !! $*DEFAULT-DOWN
              ?? "$text\nThis is needed to be able to remove elements from an agnostic array"
              !! $text
    }
}

sub is-container(\it) is export { it.VAR.^name ne it.^name }

role Array::Agnostic
  does Positional   # .AT-POS and friends
  does Iterable     # .iterator, basically
{

#--- These methods *MUST* be implemented by the consumer -----------------------
    method AT-POS($)     is raw { ... }
    method elems()              { ... }

#--- Internal Iterator classes that need to be specified here ------------------
    my class Iterate does Iterator {
        has $.backend;
        has $.end;
        has $.index = -1;

        method pull-one() is raw {
            $!index < $!end
              ?? $!backend.AT-POS(++$!index)
              !! IterationEnd
        }
    }

    my class KV does Iterator {
        has $.backend;
        has $.end;
        has $.index = -1;
        has int $on;

        method pull-one() is raw {
            $on++ %% 2
              ?? $!index < $!end            # on the key now
                ?? ++$!index
                !! IterationEnd
              !! $!backend.AT-POS($!index)  # on the value now
        }
    }

#--- Positional methods that *MAY* be implemented by the consumer --------------
    method BIND-POS(::?ROLE:D: $,$) is hidden-from-backtrace {
        X::Array::NoImplementation.new(object => self, method => 'BIND-POS').throw
    }

    method EXISTS-POS(::?ROLE:D: $pos) { self.AT-POS($pos).defined }

    method DELETE-POS(::?ROLE:D: $) is hidden-from-backtrace {
        X::Array::NoImplementation.new(object => self, method => 'DELETE-POS').throw
    }

    method CLEAR(::?ROLE:D:) {
        my $*DEFAULT-CLEAN := True;
        self.DELETE-POS($_) for (^$.elems).reverse;
    }

    method ASSIGN-POS(::?ROLE:D: $pos, \value) is raw {
        self.AT-POS($pos) = value;
    }

    proto method STORE(|) {*}
    multi method STORE(::?ROLE:D: Iterable:D \iterable) {
        self.CLEAR;
        self!append(iterable)
    }
    multi method STORE(::?ROLE:D: Mu \item) {
        self.CLEAR;
        self.ASSIGN-POS(0,item);
        self
    }

#--- Array methods that *MAY* be implemented by the consumer -------------------
    method new(::?CLASS:U: **@values is raw) {
        self.bless(|%_).STORE(@values)
    }
    method iterator(::?ROLE:D:) { Iterate.new( :backend(self), :$.end ) }

    method end(::?ROLE:D:)     { self.elems - 1 }
    method Numeric(::?ROLE:D:) { self.elems     }
    method Int(::?ROLE:D:)     { self.elems     }
    method Bool(::?ROLE:D:)    { so self.elems  }

    method keys(::?ROLE:D:)    { Seq.new( (^self.elems).iterator ) }
    method values(::?ROLE:D:)  { Seq.new( self.iterator ) }
    method pairs(::?ROLE:D:)   { (^self.elems).map: { $_ => self.AT-POS($_) } }
    method shape(::?ROLE:D:)   { (*,) }

    method kv(::?ROLE:D:) { Seq.new( KV.new( :backend(self), :$.end ) ) }

    method list(::?ROLE:D:)  { List .from-iterator(self.iterator) }
    method Slip(::?ROLE:D:)  { Slip .from-iterator(self.iterator) }
    method List(::?ROLE:D:)  { List .from-iterator(self.iterator) }
    method Array(::?ROLE:D:) { Array.from-iterator(self.iterator) }

    method !append(Iterable:D \iterable) {
        my int $i = self.end;
        if is-container(iterable) {
            self.ASSIGN-POS(++$i,iterable);
        }
        else {
            my \iterator := iterable.iterator;
            until (my \pulled := iterator.pull-one) =:= IterationEnd {
                self.ASSIGN-POS(++$i, pulled);
            }
        }
        self
    }
    method append(::?ROLE:D: +@values is raw) { self!append(@values) }
    method push(::?ROLE:D:  **@values is raw) { self!append(@values) }
    method pop(::?ROLE:D:) {
        if self.elems -> \elems {
            self.DELETE-POS(elems - 1)
        }
        else {
            [].pop  # standard behaviour on empty arrays
        }
    }

    method !prepend(@values) {
        self.move-indexes-up(+@values);
        self.ASSIGN-POS($_,@values.AT-POS($_)) for ^@values;
        self
    }
    method prepend(::?ROLE:D:  +@values is raw) { self!prepend(@values) }
    method unshift(::?ROLE:D: **@values is raw) { self!prepend(@values) }
    method shift(::?ROLE:D:) {
        if self.elems -> \elems {
            my \value = self.AT-POS(0)<>;
            self.move-indexes-down(1);
            value
        }
        else {
            [].shift  # standard behaviour on empty arrays
        }
    }

    method gist(::?ROLE:D:) { '[' ~ self.Str ~ ']' }
    method Str(::?ROLE:D:)  { self.values.map( *.Str ).join(" ") }
    method perl(::?ROLE:D:) is DEPRECATED("raku") { self.raku }
    method raku(::?ROLE:D:) {
        self.perlseen(self.^name, {
          ~ self.^name
          ~ '.new('
          ~ self.map({$_<>.perl}).join(',')
          ~ ',' x (self.elems == 1 && self.AT-POS(0) ~~ Iterable)
          ~ ')'
        })
    }

    method splice(::?ROLE:D:) { X::NYI.new( :feature<splice> ).throw }
    method grab(::?ROLE:D:)   { X::NYI.new( :feature<grab>   ).throw }

# -- Internal subroutines and methods that *MAY* be implemented ----------------

    # Move indexes up for the number of positions given, optionally from the
    # given given position (defaults to start). Removes the original positions.
    method move-indexes-up(::?ROLE:D: $up, $start = 0 --> Nil) {
        my $DEFAULT-UP := True;
        for ($start ..^ $.elems).reverse {
            if self.EXISTS-POS($_) {
                is-container(my \value = self.DELETE-POS($_))
                  ?? self.ASSIGN-POS($_ + $up, value)
                  !! self.BIND-POS(  $_ + $up, value);
            }
        }
    }

    # Move indexes down for the number of positions given, optionally from the
    # given position (which defaults to the number of positions to move down).
    # Removes original positions.
    method move-indexes-down(::?ROLE:D: $down, $start = $down --> Nil) {
        my $DEFAULT-DOWN := True;
        for ($start ..^ $.elems).list -> $from {
            my $to = $from - $down;
            if self.EXISTS-POS($from) {
                my \value = self.DELETE-POS($from);  # something to move
                if is-container(value) {
                    self.DELETE-POS($to);            # could have been bound
                    self.ASSIGN-POS($to, value);
                }
                else {
                    self.BIND-POS($to, value);       # don't care what it was
                }
            }
            else {
                self.DELETE-POS($to);                # nothing to move
            }
        }
    }
}

=begin pod

=head1 NAME

Array::Agnostic - be an array without knowing how

=head1 SYNOPSIS

=begin code :lang<raku>

use Array::Agnostic;
class MyArray does Array::Agnostic {
    method AT-POS()     { ... }
    method elems()      { ... }
}

my @a is MyArray = 1,2,3;

=end code

=head1 DESCRIPTION

This module makes an C<Array::Agnostic> role available for those classes that
wish to implement the C<Positional> role as an C<Array>.  It provides all of
the C<Array> functionality while only needing to implement 2 methods:

=head2 Required Methods

=head3 method AT-POS

=begin code :lang<raku>

method AT-POS($position) { ... }  # simple case

method AT-POS($position) { Proxy.new( FETCH => { ... }, STORE => { ... } }

=end code

Return the value at the given position in the array.  Must return a C<Proxy>
that will assign to that position if you wish to allow for auto-vivification
of elements in your array.

=head3 method elems

=begin code :lang<raku>

method elems(--> Int:D) { ... }

=end code

Return the number of elements in the array (defined as the index of the
highest element + 1).

=head2 Optional Methods (provided by role)

You may implement these methods out of performance reasons yourself, but you
don't have to as an implementation is provided by this role.  They follow the
same semantics as the methods on the
L<Array object|https://docs.perl6.org/type/Array>.

In alphabetical order:
C<append>, C<Array>, C<ASSIGN-POS>, C<end>, C<gist>, C<grab>, C<iterator>, 
C<keys>, C<kv>, C<list>, C<List>, C<new>, C<pairs>, C<perl>, C<pop>, 
C<prepend>, C<push>, C<shape>, C<shift>, C<Slip>, C<STORE>, C<Str>, C<splice>, 
C<unshift>, C<values>

=head2 Optional Internal Methods (provided by role)

These methods may be implemented by the consumer for performance reasons
or to provide a given capability.

=head3 method BIND-POS

=begin code :lang<raku>

method BIND-POS($position, $value) { ... }

=end code

Bind the given value to the given position in the array, and return the value.
Will throw an exception if called and not implemented.

=head3 method DELETE-POS

=begin code :lang<raku>

method DELETE-POS($position) { ... }

=end code

Mark the element at the given position in the array as absent (make
C<EXISTS-POS> return C<False> for this position).  Will throw an exception if
called and not implemented.

=head3 method EXISTS-POS

=begin code :lang<raku>

method EXISTS-POS($position) { ... }

=end code

Return C<Bool> indicating whether the element at the given position exists
(aka, is B<not> marked as absent).  If not implemented, Will call C<AT-POS>
and return C<True> if the returned value is defined.

=head3 method CLEAR

=begin code :lang<raku>

method CLEAR(--> Nil) { ... }

=end code

Reset the array to have no elements at all.  By default implemented by
repeatedly calling C<DELETE-POS>, which will by all means, be very slow.
So it is a good idea to implement this method yourself.

=head3 method move-indexes-up

=begin code :lang<raku>

method move-indexes-up($up, $start = 0) { ... }

=end code

Add the given value to the B<indexes> of the elements in the array, optionally
starting from a given start index value (by default 0, so all elements of the
array will be affected).  This functionality is needed if you want to be able
to use C<shift>, C<unshift> and related functions.

=head3 method move-indexes-down

=begin code :lang<raku>

method move-indexes-down($down, $start = $down) { ... }

=end code

Subtract the given value to the B<indexes> of the elements in the array,
optionally starting from a given start index value (by default the same as
the number to subtract, so that all elements of the array will be affected.
This functionality is needed if you want to be able to use C<shift>,
C<unshift> and related functions.

=head2 Exported subroutines

=head3 sub is-container

=begin code :lang<raku>

my $a = 42;
say is-container($a);  # True
say is-container(42);  # False

=end code

Returns whether the given argument is a container or not.  This can be handy
for situations where you want to also support binding, B<and> allow for
methods such as C<shift>, C<unshift> and related functions.

=head1 AUTHOR

Elizabeth Mattijsen <liz@raku.rocks>

Source can be located at: https://github.com/lizmat/Array-Agnostic .
Comments and Pull Requests are welcome.

If you like this module, or what I’m doing more generally, committing to a
L<small sponsorship|https://github.com/sponsors/lizmat/>  would mean a great
deal to me!

=head1 COPYRIGHT AND LICENSE

Copyright 2018, 2020, 2021, 2023, 2024 Elizabeth Mattijsen

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

=end pod

# vim: expandtab shiftwidth=4

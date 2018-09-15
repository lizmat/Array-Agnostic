use v6.c;

role Array::Agnostic:ver<0.0.1>:auth<cpan:ELIZABETH> does Positional {

#--- These methods *MUST* be implemented by the consumer -----------------------
    method AT-POS($)     is raw { ... }
    method BIND-POS($,$) is raw { ... }
    method EXISTS-POS($)        { ... }
    method DELETE-POS($)        { ... }
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
            $on++ & 1  
              ?? $!index < $!end            # on the key now
                ?? ++$!index
                !! IterationEnd
              !! $!backend.AT-POS($!index)  # on the value now
        }
    }

#--- Positional methods that *MAY* be implemented by the consumer --------------
    method CLEAR() {
        self.DELETE-POS($_) for (^$.elems).reverse;
    }

    method ASSIGN-POS(int $pos, \value) is raw {
        self.AT-POS($pos) = value;
    }

    method STORE(*@values, :$initialize) {
        self.CLEAR;
        self.ASSIGN-POS($_,@values.AT-POS($_)) for ^@values;
        self
    }

#--- Array methods that *MAY* be implemented by the consumer -------------------
    method new(::?CLASS:U: **@values is raw) {
        self.CREATE.STORE(@values)
    }
    method iterator() { Iterate.new( :backend(self), :$.end ) }

    method end()    { $.elems - 1 }
    method keys()   { Seq.new( (^$.elems).iterator ) }
    method values() { Seq.new( self.iterator ) }
    method pairs()  { (^$.elems).map: { $_ => self.AT-POS } }
    method shape()  { (*,) }

    method head(|c) { Seq.new( self.iterator ).head(c) }
    method tail(|c) { Seq.new( self.iterator ).tail(c) }

    method kv() { Seq.new( KV.new( :backend(self), :$.end ) ) }

    method list()  { List.new(self.values) }
    method Slip()  { Slip.from-iterator(self.iterator) }
    method List()  { List.new(self.values) }
    method Array() { Array.new(self.values) }

    method append(+@values is raw) {
        self.ASSIGN-POS(self.elems,$_) for @values;
    }
    method push(**@values is raw) {
        self.ASSIGN-POS(self.elems,$_) for @values;
    }
    method pop() {
        if self.elems -> \elems {
            self.DELETE-POS(elems - 1)
        }
        else {
            [].pop  # standard behaviour on empty arrays
        }
    }

    method prepend(+@values is raw) {
        self!move-indexes-up(+@values);
        self.ASSIGN-POS($_,@values.AT-POS($_)) for ^@values;
        self
    }
    method unshift(**@values is raw) {
        self!move-indexes-up(+@values);
        self.ASSIGN-POS($_,@values.AT-POS($_)) for ^@values;
        self
    }
    method shift() {
        if self.elems -> \elems {
            my \value = self.AT-POS(0);
            self!move-indexes-down(1);
            value
        }
        else {
            [].shift  # standard behaviour on empty arrays
        }
    }

    method gist() { '[' ~ self.Str ~ ']' }
    method Str()  { self.values.map( *.Str ).join(" ") }
    method perl() {
        self.perlseen(self.^name, {
          ~ self.^name
          ~ '.new('
          ~ self.map({$_<>.perl}).join(', ')
          ~ ',' x (self.elems == 1 && self.AT-POS(0) ~~ Iterable)
          ~ ')'
        })
    }

    method splice() { X::NYI.new( :feature<splice> ).throw }
    method grab()   { X::NYI.new( :feature<grab>   ).throw }

# -- Internal subroutines and private methods ----------------------------------
    sub is-container(\it) { it.VAR.^name ne it.^name }

    method !move-indexes-up($number, $range = ^$.elems) {
        is-container(my \value = self.AT-POS($_))
          ?? self.BIND-POS(  $_ + $number, value)
          !! self.ASSIGN-POS($_ + $number, value)
          for $range.reverse;
    }

    method !move-indexes-down($number, $range = ^$.elems) {
        is-container(my \value = self.AT-POS($_ + $number))
          ?? self.BIND-POS(  $_, value)
          !! self.ASSIGN-POS($_, value)
          for $range.list;
    }
}

=begin pod

=head1 NAME

Array::Agnostic - add "is sparse" trait for Arrays

=head1 SYNOPSIS

  use Array::Agnostic;
  class Array::MyWay does Array::Agnostic {
      method AT-POS()     { ... }
      method BIND-POS()   { ... }
      method DELETE-POS() { ... }
      method EXISTS-POS() { ... }
      method elems()      { ... }
  }

  my @a is Array::MyWay = 1,2,3;

=head1 DESCRIPTION

This module makes an C<Array::Agnostic> role available for those classes that
wish to implement the C<Positional> role.  It provides all of the C<Array>
functionality while only needing to implement 5 methods:

=head2 Required Methods

=head3 method AT-POS

=head3 method BIND-POS

=head3 method DELETE-POS

=head3 method EXISTS-POS

=head3 method elems

=head2 Optional Methods (provided by role)

You may implement these methods out of performance reasons yourself, but you
don't have to as an implementation is provided by this role.

=head3 method ASSIGN-POS

=head3 method CLEAR

=head3 method STORE

=head3 method Array

=head3 method append

=head3 method end

=head3 method grab

=head3 method head

=head3 method iterator

=head3 method keys

=head3 method kv

=head3 method list

=head3 method List

=head3 method new

=head3 method pairs

=head3 method pop

=head3 method prepend

=head3 method push

=head3 method shape

=head3 method shift

=head3 method Slip

=head3 method splice

=head3 method tail

=head3 method unshift

=head3 method values

=head1 AUTHOR

Elizabeth Mattijsen <liz@wenzperl.nl>

Source can be located at: https://github.com/lizmat/Array-Agnostic .
Comments and Pull Requests are welcome.

=head1 COPYRIGHT AND LICENSE

Copyright 2018 Elizabeth Mattijsen

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

=end pod

# vim: ft=perl6 expandtab sw=4

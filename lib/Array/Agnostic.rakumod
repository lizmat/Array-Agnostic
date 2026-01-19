my class X::Array::NoImplementation is Exception {
    has $.object;
    has $.method;
    method message() {
        my $text = "No implementation of $.method method found for $.object.^name().";
        $*DEFAULT-CLEAR
          ?? "$text\nThis is needed to be able to clear an agnostic array."
          !! $*DEFAULT-UP
            ?? "$text\nThis is needed to be able to insert elements in an agnostic array"
            !! $*DEFAULT-DOWN
              ?? "$text\nThis is needed to be able to remove elements from an agnostic array"
              !! $text
    }
}

sub is-container(\it) is export { it.VAR.^name ne it.^name }

#--- Internal Iterator classes -------------------------------------------------
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

#- Array::Agnostic -------------------------------------------------------------
role Array::Agnostic
  does Positional   # .AT-POS and friends
  does Iterable     # .iterator, basically
{

#--- These methods *MUST* be implemented by the consumer -----------------------
    method AT-POS($) is raw { ... }  # UNCOVERABLE
    method elems()          { ... }  # UNCOVERABLE

#--- Positional methods that *MAY* be implemented by the consumer --------------
    method BIND-POS(::?ROLE:D: $,$) is hidden-from-backtrace {
        X::Array::NoImplementation.new(object => self, method => 'BIND-POS').throw
    }

    method EXISTS-POS(::?ROLE:D: $pos) { self.AT-POS($pos).defined }

    method DELETE-POS(::?ROLE:D: $) is hidden-from-backtrace {
        X::Array::NoImplementation.new(object => self, method => 'DELETE-POS').throw
    }

    method CLEAR(::?ROLE:D:) {
        my $*DEFAULT-CLEAR := True;
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
            until (my \pulled := iterator.pull-one) =:= IterationEnd {  # UNCOVERABLE
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
        if self.elems {
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
          ~ ',' x (self.elems == 1 && self.AT-POS(0) ~~ Iterable)  # UNCOVERABLE
          ~ ')'
        })
    }

    method splice(::?ROLE:D: |) { X::NYI.new( :feature<splice> ).throw }
    method grab(::?ROLE:D:   |) { X::NYI.new( :feature<grab>   ).throw }

#--- Internal subroutines and methods that *MAY* be implemented ----------------

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
        for $start ..^ $.elems -> $from {
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

    # Since .AT-POS and .elems are provided by Any, the normal
    # "has it been provided" test of the core doesn't work, because
    # technically those methods *are* provided.  But just not with
    # the role that we're consuming.  So check for the minimal
    # number of methods that *should* be provided, and bail if one
    # of them isn't found.
    for <AT-POS elems> {
        X::Comp::AdHoc.new(
          :is-compile-time,
          payload => "Method '$_' must be implemented by $?CLASS.^name() because it is required by roles: Array::Agnostic."
        ).throw if $?CLASS.^find_method($_) =:= Mu;
    }
}

# vim: expandtab shiftwidth=4

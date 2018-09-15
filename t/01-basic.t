use v6.c;
use Test;

use Array::Agnostic;

class MyArray does Array::Agnostic {
    has @!array;

    method AT-POS($pos)          is raw { @!array.AT-POS($pos)         }
    method BIND-POS($pos,\value) is raw { @!array.BIND-POS($pos,value) }
    method EXISTS-POS($pos)             { @!array.EXISTS-POS($pos)     }
    method DELETE-POS($pos)             { @!array.DELETE-POS($pos)     }
    method elems()                      { @!array.elems                }
}

plan 5;

my @a is MyArray = ^10;

dd @a[$_] for ^10;

dd $_ for @a;

@a[9]:delete;

dd $_ for @a;

dd @a[3,5,7]:delete;

dd @a[]:v;

dd @a.keys;
dd @a.values;

# vim: ft=perl6 expandtab sw=4

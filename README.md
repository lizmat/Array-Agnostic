[![Actions Status](https://github.com/lizmat/Array-Agnostic/actions/workflows/linux.yml/badge.svg)](https://github.com/lizmat/Array-Agnostic/actions) [![Actions Status](https://github.com/lizmat/Array-Agnostic/actions/workflows/macos.yml/badge.svg)](https://github.com/lizmat/Array-Agnostic/actions) [![Actions Status](https://github.com/lizmat/Array-Agnostic/actions/workflows/windows.yml/badge.svg)](https://github.com/lizmat/Array-Agnostic/actions)

NAME
====

Array::Agnostic - be an array without knowing how

SYNOPSIS
========

```raku
use Array::Agnostic;
class MyArray does Array::Agnostic {
    method AT-POS()     { ... }
    method elems()      { ... }
}

my @a is MyArray = 1,2,3;
```

DESCRIPTION
===========

This module makes an `Array::Agnostic` role available for those classes that wish to implement the `Positional` role as an `Array`. It provides all of the `Array` functionality while only needing to implement 2 methods:

Required Methods
----------------

### method AT-POS

```raku
method AT-POS($position) { ... }  # simple case

method AT-POS($position) { Proxy.new( FETCH => { ... }, STORE => { ... } }
```

Return the value at the given position in the array. Must return a `Proxy` that will assign to that position if you wish to allow for auto-vivification of elements in your array.

### method elems

```raku
method elems(--> Int:D) { ... }
```

Return the number of elements in the array (defined as the index of the highest element + 1).

Optional Methods (provided by role)
-----------------------------------

You may implement these methods out of performance reasons yourself, but you don't have to as an implementation is provided by this role. They follow the same semantics as the methods on the [Array object](https://docs.perl6.org/type/Array).

In alphabetical order: `append`, `Array`, `ASSIGN-POS`, `end`, `gist`, `grab`, `iterator`, `keys`, `kv`, `list`, `List`, `new`, `pairs`, `perl`, `pop`, `prepend`, `push`, `shape`, `shift`, `Slip`, `STORE`, `Str`, `splice`, `unshift`, `values`

Optional Internal Methods (provided by role)
--------------------------------------------

These methods may be implemented by the consumer for performance reasons or to provide a given capability.

### method BIND-POS

```raku
method BIND-POS($position, $value) { ... }
```

Bind the given value to the given position in the array, and return the value. Will throw an exception if called and not implemented.

### method DELETE-POS

```raku
method DELETE-POS($position) { ... }
```

Mark the element at the given position in the array as absent (make `EXISTS-POS` return `False` for this position). Will throw an exception if called and not implemented.

### method EXISTS-POS

```raku
method EXISTS-POS($position) { ... }
```

Return `Bool` indicating whether the element at the given position exists (aka, is **not** marked as absent). If not implemented, Will call `AT-POS` and return `True` if the returned value is defined.

### method CLEAR

```raku
method CLEAR(--> Nil) { ... }
```

Reset the array to have no elements at all. By default implemented by repeatedly calling `DELETE-POS`, which will by all means, be very slow. So it is a good idea to implement this method yourself.

### method move-indexes-up

```raku
method move-indexes-up($up, $start = 0) { ... }
```

Add the given value to the **indexes** of the elements in the array, optionally starting from a given start index value (by default 0, so all elements of the array will be affected). This functionality is needed if you want to be able to use `shift`, `unshift` and related functions.

### method move-indexes-down

```raku
method move-indexes-down($down, $start = $down) { ... }
```

Subtract the given value to the **indexes** of the elements in the array, optionally starting from a given start index value (by default the same as the number to subtract, so that all elements of the array will be affected. This functionality is needed if you want to be able to use `shift`, `unshift` and related functions.

Exported subroutines
--------------------

### sub is-container

```raku
my $a = 42;
say is-container($a);  # True
say is-container(42);  # False
```

Returns whether the given argument is a container or not. This can be handy for situations where you want to also support binding, **and** allow for methods such as `shift`, `unshift` and related functions.

AUTHOR
======

Elizabeth Mattijsen <liz@raku.rocks>

Source can be located at: https://github.com/lizmat/Array-Agnostic . Comments and Pull Requests are welcome.

If you like this module, or what I’m doing more generally, committing to a [small sponsorship](https://github.com/sponsors/lizmat/) would mean a great deal to me!

COPYRIGHT AND LICENSE
=====================

Copyright 2018, 2020, 2021, 2023, 2024, 2025 Elizabeth Mattijsen

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.


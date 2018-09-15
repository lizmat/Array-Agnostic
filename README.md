[![Build Status](https://travis-ci.org/lizmat/Array-Agnostic.svg?branch=master)](https://travis-ci.org/lizmat/Array-Agnostic)

NAME
====

Array::Agnostic - be an array without knowing how

SYNOPSIS
========

    use Array::Agnostic;
    class Array::MyWay does Array::Agnostic {
        method AT-POS()     { ... }
        method BIND-POS()   { ... }
        method DELETE-POS() { ... }
        method EXISTS-POS() { ... }
        method elems()      { ... }
    }

    my @a is Array::MyWay = 1,2,3;

DESCRIPTION
===========

This module makes an `Array::Agnostic` role available for those classes that wish to implement the `Positional` role. It provides all of the `Array` functionality while only needing to implement 5 methods:

Required Methods
----------------

### method AT-POS

### method BIND-POS

### method DELETE-POS

### method EXISTS-POS

### method elems

Optional Methods (provided by role)
-----------------------------------

You may implement these methods out of performance reasons yourself, but you don't have to as an implementation is provided by this role.

### method ASSIGN-POS

### method CLEAR

### method STORE

### method Array

### method append

### method end

### method gist

### method grab

### method head

### method iterator

### method keys

### method kv

### method list

### method List

### method new

### method pairs

### method perl

### method pop

### method prepend

### method push

### method shape

### method shift

### method Slip

### method Str

### method splice

### method tail

### method unshift

### method values

AUTHOR
======

Elizabeth Mattijsen <liz@wenzperl.nl>

Source can be located at: https://github.com/lizmat/Array-Agnostic . Comments and Pull Requests are welcome.

COPYRIGHT AND LICENSE
=====================

Copyright 2018 Elizabeth Mattijsen

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.


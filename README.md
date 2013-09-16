perl6-benchmarks
================

Demo/benchmarking code in Perl 6

This project contains sample code for a series of [introspective evaluations of Perl 6,](http://sd.jtimothyking.com/2013/09/09/perl-6-and-the-price-of-elegant-code/) published at sd.JTimothyKing.com.

`primes.pl6` is a Perl6 script that finds primes up to a series of maximums, using a series of algorithms, and reports the time taken (according the wall clock) in each case.

To run the script
-----------------

```
$ cd perl6-benchmarks
$ ./primes.pl6
```

Or feel free to run it with any P6 interpreter you want. For example:

```
$ rakudo/install-jvm/bin/perl6 perl6-benchmarks/primes.pl6
```

The script supports a number of options to limit, expand, and tweak the benchmarking parameters. Display a usage message with:

```
$ ./primes.pl6 --help
```

This script is a hack!
----------------------

Look at the code for more goodies!

This is not intended to be production code. There are no unit tests (though the script itself does double-check the results of the functions it runs). There are undocumented bits. There are bits that don't work.

But while the code is not designed to be production quality, it is intended to give useful results, and I learned a great deal about Perl 6 while writing it.

So run it. Talk about it. Write about it. Send me your comments. Send me a link to your discussions. And above all, have fun!

-TimK

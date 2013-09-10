#!/usr/bin/env perl6
use v6;

my $me;
BEGIN {
    my ($script-vol, $script-dir, $script-pl) = IO::Spec.splitpath($*PROGRAM_NAME);
    $me = $script-pl || 'primes';

    # Add script's ./lib to @*INC
    my $libdir = IO::Spec.catpath( $script-vol, IO::Spec.catdir($script-dir, 'lib'), '' );
    @*INC.unshift($libdir);
}


# NOTE: This script requires a hacked version of Benchmark.
# It will not work unless you're pulling the hacked version from the script's ./lib.
use Benchmark;

constant $is-JVM = $*VM<name> ~~ 'jvm';


constant $default-min = 10;
constant $default-max = 10_000;
constant $default-by = 10;
constant $default-warmup = ($is-JVM and 30 or 0);
constant $default-min-iters = 10;
constant $default-min-seconds = 60;

constant @default-algorithms = <
    native
    any any-upto-sqrt
    loop loop-upto-sqrt loop-gather-upto-sqrt inline-loop-upto-sqrt
    cached
>;

# For other algorithms not in the above list (for one reason or another), search for
# subs named like "primes-*."


# We should be able to use A<@default-algorithms> and A<$default-FOO> in the POD below,
# instead of copying and pasting the corresponding values down there; but pod2text does
# not support A<> (yet?).

=begin USAGE
./primes.pl6 [--min=<Int>] [--max=<Int>] [--by=<Int>] [--warmup=<Numeric>]
  [--min-iters=<Int>] [--min-seconds=<Numeric>] [<algorithms-to-benchmark> ...] 

  =item Finds primes up to a series of maximums, using a series of algorithms, and
    reports the time taken (according the wall clock) in each case.

  =item --min=10 --max=10_000 --by=10 (the default) computes primes up to the following maxes:
    10, 100, 1_000, 10_000

  =item --warmup=N runs the algorithm N seconds before actually benchmarking.
    --warmup=30 is the default when running on the JVM. --warmup=0 is the default
    when running on Parrot (or other VMs).

  =item --min-iters=10 --min-seconds=60 (the default) runs each benchmark at least 10
    times for at least 60 seconds.

  =item If no algorithms are specified, defaults to the following list:
    native
    any any-upto-sqrt
    loop loop-upto-sqrt loop-gather-upto-sqrt inline-loop-upto-sqrt
    cached
=end USAGE


# The following operators really want to be "is equiv(&infix:<X>)"
# but see https://rt.perl.org/rt3/Ticket/Display.html?id=119589

# Should be infix:<%%-any> (Int $n, Int @a --> Bool)
# and infix:<upto> (Numeric ::T @a, Numeric $n --> Array[T])
# but Rakudo chokes on these, too,
# because parametric types don't seem to be (fully?) implemented yet,
# and functions can't currently return typed arrays
# (see https://rt.perl.org/rt3/Ticket/Display.html?id=66892)
# and therefore can't pass them to other functions.

sub infix:<upto> (@a, Numeric $max) is looser(&infix:<==>) is assoc<left> {
    return (for @a { if $_ <= $max { $_ } else { last } });
}

sub infix:<gather-upto> (@a, Numeric $max) is equiv(&infix:<upto>) is assoc<left> {
    return gather for @a { if $_ <= $max { take $_ } else { last } };
}

sub infix:<%%-any> (Int $n, @a --> Bool) is equiv(&infix:<upto>) is assoc<non> {
    return True if $n %% $_ for @a;
    return False;
}


sub test-primes (:&primes-fn, Int :@maxes,
                 Numeric :$warmup-seconds = $default-warmup,
                 Int :$min-benchmark-iterations = $default-min-iters,
                 Numeric :$min-benchmark-seconds = $default-min-seconds,
                ) {
    say "$me: {&primes-fn.name}()";

    my %primes = @maxes.map({ $_ => [ primes-native($_) ] });

    my %primes-error;

    my sub primes-with-check($max) {
        my @primes-this-iter = &primes-fn($max);
        if ! %primes-error{$max} && @primes-this-iter != %primes{$max} {
            %primes-error{$max} = True;
            note "$me: {&primes-fn.name}($max) returned an incorrect list of primes\n",
              " expected = {%primes{$max}.perl}\n",
              " observed = {@primes-this-iter.perl}\n";
        }
        return @primes-this-iter;
    }

    my %benchmark-code = @maxes.map( -> $max { $max => &primes-with-check.assuming($max) } );

    if $warmup-seconds {
        say "$me: Warming up the benchmarker...";
        # Warm up the benchmarking code. (Allows the VM to optimize running code, if supported.)
        timethese(min-iters => 1, min-time => $warmup-seconds, code => %benchmark-code);
    }

    say "$me: Benchmarking {&primes-fn.name}()...";
    my %benchmarks = timethese(min-iters => $min-benchmark-iterations,
                               min-time => $min-benchmark-seconds,
                               code => %benchmark-code);

    for @maxes -> $max {
        my $num-primes = %primes{$max}.elems;

        my %benchmark = %benchmarks{$max};
        my $milliseconds-per-iter = %benchmark<average> * 1000;
        my $stddev-milliseconds = %benchmark<stddev> * 1000;
        my $num-iterations = %benchmark<iters>;

        say "$me: {&primes-fn.name}({$max}) found $num-primes primes",
            " in {$milliseconds-per-iter.fmt('%.2f')} milliseconds",
            " (σ = {$stddev-milliseconds.fmt('%.3f')} milliseconds,",
            " run $num-iterations times)";
    }
}


sub MAIN (Int :$min = $default-min,
          Int :$max = $default-max,
          Int :$by = $default-by,
          Numeric :$warmup = $default-warmup,
          Int :$min-iters = $default-min-iters,
          Numeric :$min-seconds = $default-min-seconds,
          *@algorithms-to-benchmark) {

    say "$me: Running on the JVM" if $is-JVM;

    @algorithms-to-benchmark ||= @default-algorithms;
    say "$me: Benchmarking algorithms: @algorithms-to-benchmark[]";

    my Int @maxes = (($min, (* * $by) ... *) upto $max);
    say "$me: Up to maxes: @maxes[]";

    my @fns = @algorithms-to-benchmark.map( -> $name {
        my $fn = &::("primes-$name");
        $fn.defined or die "$me: There is no function prime-{$name}()";
        $fn;
    });

    test-primes(primes-fn => $_,
                maxes => @maxes,
                warmup-seconds => $warmup,
                min-benchmark-iterations => $min-iters,
                min-benchmark-seconds => $min-seconds,
               ) for @fns;
}

sub USAGE () {
    use Pod::To::Text;
    say pod2text( $=pod.grep({.name eq 'USAGE'}) );
}



# For testing:
# Doesn't actually return primes, but returns a different result for each positive $max.
sub primes-dummy (Int $max) {
    return 1 .. $max;
}



# DOESN'T WORK (yet?)
sub primes-functional (Int $max) {
    # Translation into P6 of the naïve Haskell:
    #   primes = sieve [2..]
    #   sieve (p : xs) = p : sieve [x | x <− xs, x `mod` p > 0]
    # (which does NOT actually implement a sieve)

    my sub filter-non-primes (*@xs) {
        my $p = @xs.shift;
        return $p, filter-non-primes( @xs.grep(* % $p > 0) );
    }

# The following should give the correct result, but always uses up all memory without
# returning a result, because of https://rt.perl.org/rt3/Ticket/Display.html?id=117635
    my @primes := filter-non-primes 2..*;
    return @primes gather-upto $max;
}



# Sucks that Rakudo doesn't work right with: --> Array[Int]
# See https://rt.perl.org/rt3/Ticket/Display.html?id=66892

sub primes-native (Int $max) {
    grep({.is-prime}, 2 .. $max);
}

sub primes-any (Int $max) {
    my Int @primes;
    @primes.push($_) unless $_ %% any(@primes) for 2 .. $max;
    return @primes;
}

sub primes-any-upto-sqrt (Int $max) {
    my Int @primes;
    @primes.push($_) unless $_ %% any(@primes upto sqrt $_) for 2 .. $max;
    return @primes;
}

sub primes-loop (Int $max) {
    my Int @primes;
    @primes.push($_) unless $_ %%-any @primes for 2 .. $max;
    return @primes;
}

sub primes-loop-upto-sqrt (Int $max) {
    my Int @primes;
    @primes.push($_) unless $_ %%-any (@primes upto sqrt $_) for 2 .. $max;
    return @primes;
}

sub primes-loop-gather-upto-sqrt (Int $max) {
    my Int @primes;
    @primes.push($_) unless $_ %%-any (@primes gather-upto sqrt $_) for 2 .. $max;
    return @primes;
}

sub primes-inline-loop-upto-sqrt (Int $max) {
    my Int @primes;
    loop (my $n = 2; $n <= $max; $n++) {
        my $sqrt-n = sqrt $n;
        # Use a loop-exit flag because labels are not implemented yet in Rakudo
        my $is-prime = True; # assume until proven otherwise
        for @primes -> $prime {
            ($is-prime = False, last) if $n %% $prime;
            last if $prime > $sqrt-n;
        }
        @primes.push($n) if $is-prime;
    }
    return @primes;
}

sub primes-cached (Int $max) {
    state Int @primes = 2;
    @primes.push($_) unless $_ %%-any (@primes upto sqrt $_) for @primes[*-1]+1 .. $max;
    return @primes upto $max;
}


# end

module Benchmark;

# THIS IS A HACKED VERSION OF THE Benchmark MODULE
# 2013-Sep-8
# The improvements hacked into this module will (I hope) be integrated into the
# Benchmark mainline. But for now, just make sure this version of Benchmark.pm6
# is first in your perl6 include path, if you need it (which you probably don't).


my constant default-min-iters = 4;
my constant default-min-time = 3;


my multi sub time_it (Int $iters where { $_ > 0 }, Code $code) {
    time_it(min-iters => $iters, min-time => 0, :$code);
}

my multi sub time_it (Int $negative-min-time where { $_ <= 0 }, Code $code) {
    time_it(min-iters => 1, min-time => -$negative-min-time || default-min-time, :$code);
}

my multi sub time_it (Int :$min-iters = default-min-iters,
                      Int :$min-time = default-min-time,
                      Code :$code) {

    my @times;

    my $iters = 0;
    my $total-time = 0;
    repeat {
        my $start-time = now;
        $code.();
        my $time-this-iter = now - $start-time;

        @times.push($time-this-iter);

        $iters++;
        $total-time += $time-this-iter;
    } until $iters >= $min-iters && $total-time >= $min-time;

    my $average = $total-time / $iters;

    my $stddev = sqrt(
        (
            [+] @times.map((* - $average)**2)
        ) / $iters
    );

    return {
        real => $total-time, # real "wall-clock" time, as opposed to system or user time
        iters => $iters,
        average => $average,
        stddev => $stddev,
    };
}

my multi sub to-code (Code $code --> Code) { $code }
my multi sub to-code (Str $code --> Code) { sub { eval $code } }


multi sub timethis (Int $iters, $code) is export { 
    return time_it($iters, to-code($code));
}

multi sub timethis (Int :$min-iters = default-min-iters, Int :$min-time = default-min-time, :$code) is export {
    return time_it(:$min-iters, :$min-time, code => to-code($code));
}

multi sub timethese (Int $iters, %code) is export {
    return %( %code.map( -> $c { $c.key => time_it($iters, to-code($c.value)) }) );
}

multi sub timethese (Int :$min-iters = default-min-iters, Int :$min-time = default-min-time, :%code) is export {
    return %( %code.map( -> $c { $c.key => time_it(:$min-iters, :$min-time, code => to-code($c.value)) }) );
}

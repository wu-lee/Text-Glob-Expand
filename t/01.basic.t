#!/usr/bin/perl
use strict;
use warnings;
use FindBin qw($Bin);
use lib "$Bin/../lib";

use Text::Glob::Expand qw(explode);
use Test::More tests => 49;

for ("ab{s,d{e,f}g,h}i",
     "aa{a{a,b}c{a,b}}d{e,f}") 
{
#    note explain $_;
#    note "\n";
#    note explain parse_glob $_;
};


# a{b,cr}d
# abd b  # 1 1
# acrd cr  # 1 2


# a{b,c{d,e}f}g
# [abg b]
# [acdfg [cdf d]
# [acefg [cef e]] # %0 = acdfg %1 = cdf %1.1 = e


# a{b}d  
# a{c{d}f}g 
# a{c{e}f}g

# [abd  [b]]    %1 = b 
# [a{c{d}f}g [cdf [d]]]  %1 = cdf %1.1 = d 
# [a{c{e}f}g [cef [e]]]

# [abd  [b]]    $_ = b 
# [a{c{d}f}g [cdf [d]]]  %1 = cdf %1.1 = d 
# [a{c{e}f}g [cef [e]]]
 
my @cases = (
    ["aaa" => ["aaa"],
     ".%0." => [".aaa."]],
    ["a{a}a" => ["aaa"],
     ".%0.%1." => [".aaa.a."]],
    ["a{a}a{b}" => ["aaab"],
     ".%0.%1.%2" => [qw(.aaab.a.b)]],
    ["a{a,b}a{b,a}" => [qw(aaab aaaa abab abaa)],
     ".%0.%1.%2." => [qw(.aaab.a.b. .aaaa.a.a. .abab.b.b. .abaa.b.a.)]],
    ["a{a,a{b,a}}" => [qw(aa aab aaa)],
     ".%0.%1." => [qw(.aa.a. .aab.ab. .aaa.aa.)]],
    ["a{a{},a{b,a}}" => [qw(aa aab aaa)],
     ".%0.%1.%1.1." => [qw(.aa.a.. .aab.ab.b. .aaa.aa.a.)]],
    ["a{a{b,c},d{e,f}}" => [qw(aab aac ade adf)],
     ".%0.%1.%1.1." => [qw(.aab.ab.b. .aac.ac.c. .ade.de.e. .adf.df.f.)]],
#    ["a{a,b{a{b,a}}" => qw(aaab aaaa abab abaa)], # FIXME add this error case
);


for my $case (@cases) {
    my ($expr, $expected) = splice @$case, 0, 2;

    # check a simple glob expansion
    my $glob = Text::Glob::Expand::Glob->parse($expr);
    isa_ok $glob, "Text::Glob::Expand::Glob";
    my $result = $glob->explode;
    is_deeply $result, $expected, "simple case: $expr ok";

    is_deeply [explode $expr], $expected, "simple functional case: $expr ok";


    # check the structured glob expansion is equivalent
    my $sglob = Text::Glob::Expand::StructuredGlob->parse($expr);
    isa_ok $sglob, "Text::Glob::Expand::StructuredGlob";
    $result = $sglob->explode;
    my $unwrapped_result = [map { $_->unwrap } @$result];
    is_deeply $unwrapped_result, $expected, "structured case: $expr ok";

    # check the structured glob formatting
    while(my ($format, $expected) = splice @$case, 0, 2) {
        my $fmt_result = [map { $_->expand($format) } @$result];

        is_deeply $fmt_result, $expected, "formatting case: $format => $expr ok";

        is_deeply [explode $expr, $format], $expected, "formatting functional case: $format => $expr ok";
    }

}


#!/usr/bin/env perl
# Reads UPOS and FEATS and generates a new XPOS in the PDT-C tagset.
# This should be run after all manipulations in Udapi and elsewhere to ensure
# that different flavors of the Czech tagset are not mixed in XPOS.
# Copyright © 2025 Dan Zeman <zeman@ufal.mff.cuni.cz>
# License: GNU GPL

use utf8;
use open ':utf8';
binmode(STDIN, ':utf8');
binmode(STDOUT, ':utf8');
binmode(STDERR, ':utf8');
use Lingua::Interset::Converter;

my $intopdtc = new Lingua::Interset::Converter ('from' => 'mul::uposf', 'to' => 'cs::pdtc');

while(<>)
{
    if(m/^[0-9]+\t/)
    {
        my @f = split(/\t/);
        $f[4] = $intopdtc->convert("$f[3]\t$f[5]");
        $_ = join("\t", @f);
    }
    print;
}

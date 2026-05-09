#!/usr/bin/env perl
# Odebere značky XML <doc> a <p>.
# Copyright © 2026 Dan Zeman <zeman@ufal.mff.cuni.cz>
# License: GNU GPL

use utf8;
use open ':utf8';
binmode(STDIN, ':utf8');
binmode(STDOUT, ':utf8');
binmode(STDERR, ':utf8');

while(<>)
{
    # Úvodní značku dokumentu zahodit.
    s/<doc.*?>//;
    # Odstavce standardně očekáváme na jednom řádku i s počáteční a koncovou značkou.
    # Místo toho vytiskneme řádek následovaný prázdným řádkem.
    s/^\s*<p>(.*?)<\/p>/$1\n/;
    # Pro případ, že někde byly značky odstavce umístěné jinak, zkusíme odstranit i je.
    s/<p>//g;
    s/<\/p>/\n/g;
    # Koncovou značku dokumentu zahodit.
    s/<\/doc>/\n/g;
    print;
}

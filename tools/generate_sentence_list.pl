#!/usr/bin/env perl
# Převede soubor CoNLL-U do formátu, který je sice podobný, ale rysy jsou rozepsané do samostatných sloupců.
# Copyright © 2016, 2022, 2024 Dan Zeman <zeman@ufal.mff.cuni.cz>
# License: GNU GPL

use utf8;
use open ':utf8';
binmode(STDIN, ':utf8');
binmode(STDOUT, ':utf8');
binmode(STDERR, ':utf8');

while(<>)
{
    s/\r?\n$//;
    if(m/^\#\s*sent_id\s*=\s*(.+)$/)
    {
        my $sid = $1;
        # Anotátoři by rádi viděli u každého tokenu jen konec id věty (kde je číslo odstavce a věty v rámci dokumentu).
        $sid =~ s/^.*(p[0-9][0-9A-B]*-s[0-9][0-9A-B]*)$/$1/;
        print("$sid\t");
    }
    elsif(m/^\#\s*text\s*=\s*(.+)$/)
    {
        my $text = $1;
        print("$text\n");
    }
}

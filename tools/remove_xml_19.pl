#!/usr/bin/env perl
# Odebere značky XML, které se vyskytují v textech z 19. století.
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
    # Tohle vypadá jako čísla stránek, vložená klidně doprostřed věty.
    s:<s>.*?</s>::g;
    # Tohle jsou asi emendace. Původní chybný text (resp. text používající zastaralý pravopis) je obalený éčky za opraveným textem. Vyhodit, nechat jen opravený.
    s:<e>.*?</e>::g;
    # Můžou tam být různé další značky XML, neznáme ani jejich seznam. Vyhodit značky, ponechat obsah.
    s:</?.*?>::g;
    # Dekódovat případné entity XML.
    s/&lt;/</g;
    s/&gt;/>/g;
    s/&quot;/"/g; #"
    s/&amp;/&/g;
    # Vypustit přebytečné mezery.
    s/^\s*//;
    s/\s*$//;
    s/\s+/ /g;
    print("$_\n");
}

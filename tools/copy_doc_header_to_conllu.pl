#!/usr/bin/env perl
# Zkopíruje hlavičku s metadaty z textu do odpovídajícího souboru CoNLL-U.
# Copyright © 2026 Dan Zeman <zeman@ufal.mff.cuni.cz>
# License: GNU GPL

use utf8;
use open ':utf8';
binmode(STDIN, ':utf8');
binmode(STDOUT, ':utf8');
binmode(STDERR, ':utf8');

my $nargs = scalar(@ARGV);
if($nargs != 2)
{
    die("Očekávány 2 argumenty: původní textový (XML) soubor a odpovídající CoNLL-U soubor");
}
my $tfile = $ARGV[0];
my $cfile = $ARGV[1];
# Textový soubor má někde, typicky na prvním řádku, značku <doc> se čtyřmi atributy.
# Například data/monitor_renamed/19/JADRO/1801_gesner_dlabac_vyobrazeni_potopy_bel.txt:
# <doc year="1801" author="Gessner, Salomon" title="Vyobrazení potopy světa" txtype_group="FIC: beletrie">
# Například data/monitor_korpus/21/JADRO/_1rocnikope.xml:
# <doc year="2015" author="X" title="Propozice 1. ročníku Open Novoborské Akademie 2015" txtype_group="NFC: oborová literatura">
# Předpokládáme, že celá značka je vždy na jednom řádku.
open(TEXT, $tfile) or die("Nelze číst $tfile: $!");
while(<TEXT>)
{
    if(m/<doc year="(.*?)" author="(.*?)" title="(.*?)" txtype_group="(.*?)">/)
    {
        $docyear = $1;
        $docauthor = $2;
        $doctitle = $3;
        $doctype = $4;
        last;
    }
    elsif(m/<doc/)
    {
        die("Regulární výraz nezabral na tento řádek: $_");
    }
}
close(TEXT);
###!!! A teď ještě vložit odpovídající komentáře na začátek souboru CoNLL-U.

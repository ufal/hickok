#!/usr/bin/env perl
# Volá Fomu a generuje tvary slova.
# Copyright © 2023 Dan Zeman <zeman@ufal.mff.cuni.cz>
# License: GNU GPL

use utf8;
use open ':utf8';
binmode(STDIN, ':utf8');
binmode(STDOUT, ':utf8');
binmode(STDERR, ':utf8');

my $lemma = shift(@ARGV);  # e.g. "cesta"
my $gender = shift(@ARGV); # e.g. "NF"
my @numbers = qw(Sg Du Pl);
my @cases = qw(Nom Gen Dat Acc Voc Loc Ins);
my @paradigm;
foreach my $n (@numbers)
{
    foreach my $c (@cases)
    {
        push(@paradigm, "$lemma+$gender+$n+$c");
    }
}
# Give it as input to flookup. Assume that flookup is in PATH and fst.bin exists in the current folder.
open(FOMA, "| flookup -i fst.bin") or die("Cannot pipe to foma: $!");
###!!! If fst.bin was created on Linux with locale cs_CZ.UTF-8, fslookup will digest UTF-8 input but I must send it as raw bytes (not sure what is the difference from binmode ':utf8' though).
###!!! It does not work on Windows.
binmode(FOMA, ':raw');
foreach my $p (@paradigm)
{
    print FOMA ("$p\n");
}
close(FOMA);

#!/usr/bin/env perl
# Volá Fomu a generuje tvary slova.
# Copyright © 2023 Dan Zeman <zeman@ufal.mff.cuni.cz>
# License: GNU GPL

use utf8;
use open ':utf8';
binmode(STDIN, ':utf8');
binmode(STDOUT, ':utf8');
binmode(STDERR, ':utf8');
use Encode;

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
# In Windows, flookup does not expect UTF-8 on input, although it can generate it on output.
# Perhaps it expects ANSI?
binmode(FOMA, ':raw');
foreach my $p (@paradigm)
{
    print FOMA (encode('utf8', "$p\n"));
    #print FOMA ("$p\n");
}
close(FOMA);

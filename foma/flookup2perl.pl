#!/usr/bin/env perl
# Čte výstup z flookup a generuje perlový kód pro můj skript fix_morphology.pl.
# Copyright © 2023 Dan Zeman <zeman@ufal.mff.cuni.cz>
# License: GNU GPL

use utf8;
use open ':utf8';
binmode(STDIN, ':utf8');
binmode(STDOUT, ':utf8');
binmode(STDERR, ':utf8');
use csort;

my $oldlemma = shift(@ARGV);

my %dict;
my $lemma;
my $maxl = 0;
while(<>)
{
    chomp();
    next if(m/^\s*$/);
    # Přeskočit tvary, které flookup nenašel.
    next if(m/\+\?$/);
    my ($input, $output) = split(/\s+/);
    # Vyhodit lemma a nechat si jen značku. Např. "žena+NF+Sg+Nom" zkrátit na "NF+Sg+Nom".
    $input =~ s/^(.+?)\+//;
    $lemma = $1;
    push(@{$dict{$output}}, $input);
    my $l = length($output);
    $maxl = $l if($l > $maxl);
}
$oldlemma = $lemma if(!defined($oldlemma));
my %th; map {$th{$_} = csort::zjistit_tridici_hodnoty($_, 'cs')} (keys(%dict));
my @forms = sort {$th{$a} cmp $th{$b}} (keys(%dict));
my @genders = qw(NM NF NN);
my @numbers = qw(Sg Du Pl);
my %longnum = ('Sg'=>'Sing', 'Du'=>'Dual', 'Pl'=>'Plur');
my @cases = qw(Nom Gen Dat Acc Voc Loc Ins);
my %conversion;
foreach my $g (@genders)
{
    foreach my $n (@numbers)
    {
        my $nc = substr($n, 0, 1);
        for(my $i = 0; $i < 7; $i++)
        {
            my $c = $cases[$i];
            my $cn = $i+1;
            my $src = "$g+$n+$c";
            my $tgt = "['$longnum{$n}', '$nc', '$c', '$cn']";
            $conversion{$src} = $tgt;
        }
    }
}
foreach my $f (@forms)
{
    #                 'cěstě'       => ['cesta',    'cěsta',    [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
    my $pad = ' ' x ($maxl-length($f));
    my $analyses = join(', ', map {$conversion{$_}} (@{$dict{$f}}));
    print("                '$f'$pad => ['$lemma', '$oldlemma', [$analyses]],\n");
}

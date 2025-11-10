#!/usr/bin/env perl
# Surveys morphological annotation in a CoNLL-U corpus. Focuses on word forms that have multiple different analyses.
# Copyright © 2025 Dan Zeman <zeman@ufal.mff.cuni.cz>
# License: GNU GPL

use utf8;
use open ':utf8';
binmode(STDIN, ':utf8');
binmode(STDOUT, ':utf8');
binmode(STDERR, ':utf8');

my %stats;
$stats{n} = 0; # corpus size
while(<>)
{
    # We are only interested in morphosyntactic words (tree nodes). Ignore
    # comment lines, multiword token lines and abstract nodes.
    if(m/^[0-9]+\t/)
    {
        my @f = split(/\t/);
        my $lform = lc($f[1]);
        $stats{nocc}{$lform}++;
        # Take lemma, UPOS, and features.
        my $analysis = "$f[2]\t$f[3]\t$f[5]";
        $stats{analyses}{$lform}{$analysis}++;
        $stats{n}++;
    }
}
process_and_print_stats(\%stats);



#------------------------------------------------------------------------------
# Takes the raw hash collected when reading a corpus. Processes it to compute
# additional statistics, then prints them to STDOUT.
#------------------------------------------------------------------------------
sub process_and_print_stats
{
    my $stats = shift;
    # Process the statistics.
    # For each word, get the number of distinct analyses observed with it.
    my @lforms = sort(keys(%{$stats->{analyses}}));
    foreach my $lform (@lforms)
    {
        my @analyses = keys(%{$stats->{analyses}{$lform}});
        $stats->{nanal}{$lform} = scalar(@analyses);
    }
    # Filter the words: Keep those that have more than one analysis.
    my @amblforms = grep {$stats->{nanal}{$_} > 1} (@lforms);
    # Most frequent ones first, then most ambiguous ones first, then alphabetically.
    @amblforms = sort
    {
        my $r = $stats->{nocc}{$b} <=> $stats->{nocc}{$a};
        unless($r)
        {
            $r = $stats->{nanal}{$b} <=> $stats->{nanal}{$a};
            unless($r)
            {
                $r = $a cmp $b;
            }
        }
        $r
    }
    (@amblforms);
    # Print the statistics.
    foreach my $lform (@amblforms)
    {
        my $ipm = $stats->{nocc}{$lform} / $stats->{n} * 1000000;
        printf("$lform\t%.3f ipm\t$stats->{nocc}{$lform} occurrences\t$stats->{nanal}{$lform} analyses\n", $ipm);
        my @analyses = keys(%{$stats->{analyses}{$lform}});
        @analyses = sort
        {
            my $r = $stats->{analyses}{$lform}{$b} <=> $stats->{analyses}{$lform}{$a};
            unless($r)
            {
                $r = $a cmp $b;
            }
            $r
        }
        (@analyses);
        foreach my $analysis (@analyses)
        {
            $ipm = $stats->{analyses}{$lform}{$analysis} / $stats->{n} * 1000000;
            printf("\t%.3f ipm\t$stats->{analyses}{$lform}{$analysis}\t$analysis\n", $ipm);
        }
        print("\n");
    }
}

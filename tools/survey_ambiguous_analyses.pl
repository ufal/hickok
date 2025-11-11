#!/usr/bin/env perl
# Surveys morphological annotation in a CoNLL-U corpus. Focuses on word forms that have multiple different analyses.
# Copyright © 2025 Dan Zeman <zeman@ufal.mff.cuni.cz>
# License: GNU GPL

use utf8;
use open ':utf8';
binmode(STDIN, ':utf8');
binmode(STDOUT, ':utf8');
binmode(STDERR, ':utf8');
use Getopt::Long;

sub usage
{
    print STDERR ("cat *.conllu | $0 | less\n");
    print STDERR ("    All input files will be treated as one corpus. Ambiguous words will be\n");
    print STDERR ("    printed with their analyses, most frequent words first.\n");
    print STDERR ("$0 --compare corpus1.conllu corpus2.conllu | less\n");
    print STDERR ("    Requires named input files as arguments, cannot read from STDIN. Each file\n");
    print STDERR ("    will be treated as a separate corpus. Ambiguous words will be printed if\n");
    print STDERR ("    they occur in at least two corpora and their analyses in these corpora are\n");
    print STDERR ("    not identical. If the word has multiple analyses in one corpus, being\n");
    print STDERR ("    identical means that the frequencies of the analyses in the other corpus\n");
    print STDERR ("    must be in the same order.\n");
}

my $compare = 0;
GetOptions
(
    'compare' => \$compare
);
my $nargs = scalar(@ARGV);
if($compare && $nargs != 2)
{
    usage();
    die("Expected 2 arguments, found $nargs");
}



if(!$compare)
{
    my %stats;
    $stats{n} = 0; # corpus size
    while(<>)
    {
        input_line($_, \%stats);
    }
    process_and_print_stats(\%stats);
}
else # compare multiple corpora
{
    my @stats;
    foreach my $file (@ARGV)
    {
        print STDERR ("Reading $file...\n");
        my %stats;
        $stats{name} = $file;
        $stats{name} =~ s/\.conllu$//i;
        $stats{n} = 0; # corpus size
        open(my $fh, $file) or die("Cannot read $file: $!");
        while(<$fh>)
        {
            input_line($_, \%stats);
        }
        close($fh);
        push(@stats, \%stats);
    }
    compare_stats($stats[0], $stats[1]);
}



#------------------------------------------------------------------------------
# Processes one CoNLL-U input line. To be called from different loops depending
# on how we obtain input.
#------------------------------------------------------------------------------
sub input_line
{
    my $line = shift;
    my $stats = shift;
    # We are only interested in morphosyntactic words (tree nodes). Ignore
    # comment lines, multiword token lines and abstract nodes.
    if(m/^[0-9]+\t/)
    {
        my @f = split(/\t/);
        my $lform = lc($f[1]);
        $stats->{nocc}{$lform}++;
        # Take lemma, UPOS, and features.
        my $analysis = "$f[2]\t$f[3]\t$f[5]";
        $stats->{analyses}{$lform}{$analysis}++;
        $stats->{n}++;
    }
}



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



#------------------------------------------------------------------------------
# Takes raw hashes collected when reading two corpora. Looks for words that are
# analyzed differently in the two corpora.
#------------------------------------------------------------------------------
sub compare_stats
{
    my @stats = @_;
    my $stats1 = $stats[0];
    my $stats2 = $stats[1];
    # Identify words that occur in both corpora.
    my @lforms = keys_shared_by_at_least_two($stats1->{analyses}, $stats2->{analyses});
    print STDERR ("Found ", scalar(@lforms), " common keys\n");
    # For each word, collect its analyses in both corpora, ordered by frequency.
    # Discard words for which these lists do not differ.
    my %differences;
    foreach my $lform (@lforms)
    {
        my @analyses = get_lform_analyses($lform, $stats1, $stats2);
        ###!!! THIS SHOULD BE CONFIGURABLE!
        # Either compare the full lists of analyses, or just the most frequent members.
        #if(join(' ; ', @analyses1) ne join(' ; ', @analyses2))
        if($analyses[0][0] ne $analyses[1][0])
        {
            $differences{$lform} =
            {
                'ipm' => ($stats1->{nocc}{$lform} / $stats1->{n} + $stats2->{nocc}{$lform} / $stats2->{n}) * 1000000,
                'a1'  => $analyses[0],
                'a2'  => $analyses[1]
            };
        }
    }
    # Print the differing words, most frequent first.
    my @difflforms = sort
    {
        my $r = $differences{$b}{ipm} <=> $differences{$a}{ipm};
        unless($r)
        {
            $r = $a cmp $b;
        }
        $r
    }
    (keys(%differences));
    foreach my $lform (@difflforms)
    {
        printf("$lform\t%.3f ipm\n", $differences{$lform}{ipm});
        printf("\t$stats1->{name}:\n");
        foreach my $analysis (@{$differences{$lform}{a1}})
        {
            $ipm = $stats1->{analyses}{$lform}{$analysis} / $stats1->{n} * 1000000;
            printf("\t\t%09.3f\t$analysis\n", $ipm);
        }
        printf("\t$stats2->{name}:\n");
        foreach my $analysis (@{$differences{$lform}{a2}})
        {
            $ipm = $stats2->{analyses}{$lform}{$analysis} / $stats2->{n} * 1000000;
            printf("\t\t%09.3f\t$analysis\n", $ipm);
        }
        print("\n");
    }
}



#------------------------------------------------------------------------------
# Takes a list of hash references. Returns a list of keys such that each key
# occurs in at least two hashes.
#------------------------------------------------------------------------------
sub keys_shared_by_at_least_two
{
    my @hashes = @_;
    my %keyhits;
    foreach my $hash (@hashes)
    {
        foreach my $key (keys(%{$hash}))
        {
            $keyhits{$key}++;
        }
    }
    # Sort them to maintain determinism between runs.
    return sort(grep {$keyhits{$_} >= 2} (keys(%keyhits)));
}



#------------------------------------------------------------------------------
# Takes a lowercased word form and a list of hash references. Each of the
# hashes has a subhash called 'analyses', indexed by word forms. The function
# returns a list of array references with the same number of elements as there
# were input hashes. Each array contains the analyses of the given form in the
# given hash, in descending order by frequency.
#------------------------------------------------------------------------------
sub get_lform_analyses
{
    my $lform = shift;
    my @stats = @_;
    my @analyses;
    foreach my $stats (@stats)
    {
        my @analyses0 = exists($stats->{analyses}{$lform}) ? sort {$stats->{analyses}{$lform}{$b} <=> $stats->{analyses}{$lform}{$a}} (keys(%{$stats->{analyses}{$lform}})) : ();
        push(@analyses, \@analyses0);
    }
    return @analyses;
}

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
if($compare && $nargs < 2)
{
    usage();
    die("Expected at least 2 arguments, found $nargs");
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
        # Remove path and file extension, assuming that they are not significant for distinguishing the corpora.
        $stats{name} =~ s/\.conllu$//i;
        $stats{name} =~ s:^.*/([^/]+)$:$1:;
        $stats{n} = 0; # corpus size
        open(my $fh, $file) or die("Cannot read $file: $!");
        while(<$fh>)
        {
            input_line($_, \%stats);
        }
        close($fh);
        push(@stats, \%stats);
    }
    compare_stats(@stats);
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
    # Identify words that occur in both corpora.
    my @lforms = keys_shared_by_at_least_two(map {$_->{analyses}} (@stats));
    #print STDERR ("Found ", scalar(@lforms), " common keys\n");
    # For each word, collect its analyses in both corpora, ordered by frequency.
    # Discard words for which these lists do not differ.
    my %differences;
    foreach my $lform (@lforms)
    {
        my @analyses = get_lform_analyses($lform, @stats);
        if(analyses_differ(@analyses))
        {
            $differences{$lform} =
            {
                'ipm' => sum_ipm($lform, @stats),
                'analyses' => \@analyses
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
        for(my $i = 0; $i <= $#stats; $i++)
        {
            printf("\t$stats[$i]{name}:\n");
            foreach my $analysis (@{$differences{$lform}{analyses}[$i]})
            {
                $ipm = $stats[$i]{analyses}{$lform}{$analysis} / $stats[$i]{n} * 1000000;
                printf("\t\t%09.3f\t$analysis\n", $ipm);
            }
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
        my @analyses0 = exists($stats->{analyses}{$lform}) ? sort {my $r = $stats->{analyses}{$lform}{$b} <=> $stats->{analyses}{$lform}{$a}; unless($r) {$r = $a cmp $b} $r} (keys(%{$stats->{analyses}{$lform}})) : ();
        push(@analyses, \@analyses0);
    }
    return @analyses;
}



#------------------------------------------------------------------------------
# Takes a list of lists of analyses of a word. Each list of analyses is ordered
# by descending frequency, i.e., the most frequent analysis comes first. The
# function checks whether there is a difference between the analyses and
# returns 1 or 0.
###!!!
# There are multiple options how to define that the analyses differ. We may
# want to parameterize this in the future, but currently we define a difference
# as non-identity between the most frequent analysis for the word in each hash
# (ignoring other analyses); if comparing more than two hashes, it is enough
# that there is a difference between any two of them).
#------------------------------------------------------------------------------
sub analyses_differ
{
    my @analyses = @_;
    for(my $i = 0; $i <= $#analyses; $i++)
    {
        for(my $j = $i+1; $j <= $#analyses; $j++)
        {
            # Compare the first analysis (the most frequent one) from each list.
            ###!!! Alternatively we could compare the full lists and be sensitive to other differences.
            # For some corpora the list of analyses may be empty because the
            # word does not occur there. Do not count this as a difference.
            next if(scalar(@{$analyses[$i]}) == 0 || scalar(@{$analyses[$j]}) == 0);
            ###!!! Another change that should be configurable:
            # If the first two analyses differ only in Case (but both have a
            # non-empty Case), co not take it as a significant difference.
            if(0 && $analyses[$i][0] ne $analyses[$j][0])
            {
                return 1;
            }
            else
            {
                my $samecasei = $analyses[$i][0];
                $samecasei =~ s/Case=[A-Za-z]+/Case=XXX/;
                my $samecasej = $analyses[$j][0];
                $samecasej =~ s/Case=[A-Za-z]+/Case=XXX/;
                # For adjectives we could also relax Gender, Animacy, and Number.
                if($samecasei =~ m/\tADJ\t/)
                {
                    $samecasei =~ s/Animacy=[A-Za-z]+\|(.*)Gender=Masc/${1}Gender=XXX/;
                    $samecasei =~ s/Gender=[A-Za-z]+/Gender=XXX/;
                    $samecasei =~ s/Number=[A-Za-z]+/Number=XXX/;
                    $samecasej =~ s/Animacy=[A-Za-z]+\|(.*)Gender=Masc/${1}Gender=XXX/;
                    $samecasej =~ s/Gender=[A-Za-z]+/Gender=XXX/;
                    $samecasej =~ s/Number=[A-Za-z]+/Number=XXX/;
                }
                if($samecasei ne $samecasej)
                {
                    return 1;
                }
            }
        }
    }
    return 0;
}



#------------------------------------------------------------------------------
# Takes a lowercased word form and a list of hashes with statistics from
# individual corpora. Sums up the relative frequencies of the word in all
# corpora and returns the sum expressed as ipm (instances per million tokens).
#------------------------------------------------------------------------------
sub sum_ipm
{
    my $lform = shift;
    my @stats = @_;
    my $relfrq = 0;
    foreach my $stats (@stats)
    {
        $relfrq += $stats->{nocc}{$lform} / $stats->{n};
    }
    return $relfrq * 1000000;
}

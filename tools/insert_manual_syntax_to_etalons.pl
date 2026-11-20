#!/usr/bin/env perl
# Čte syntax/od_bary, zapamatuje si ruční anotaci podle sent_id, pak zpracovává
# automaticky zparsované etalony a když narazí na větu, kteoru Bára anotovala,
# nahradí ji Bářinou verzí.
# Copyright © 2026 Dan Zeman <zeman@ufal.mff.cuni.cz>
# License: GNU GPL

use utf8;
use open ':utf8';
binmode(STDIN, ':utf8');
binmode(STDOUT, ':utf8');
binmode(STDERR, ':utf8');

# Read and remember sentences with manual syntax from Bára.
my $data_path = '/net/work/people/zeman/hickok-data';
my $manual_syntax_path = "$data_path/syntax";
my %manual_sentences;
foreach my $period ('13', '16', '19')
{
    my $path = "$manual_syntax_path/od_bary_$period";
    opendir(DIR, $path) or die("Cannot read folder '$path': $!");
    my @files = grep {-f "$path/$_" && m/\.conllu$/} (readdir(DIR));
    closedir(DIR);
    foreach my $file (@files)
    {
        open(FILE, "$path/$file") or die("Cannot read '$path/$file': $!");
        my @sentence;
        my $current_sent_id;
        while(<FILE>)
        {
            # If manual syntax contains forgotten info about automatic parsing,
            # skip it.
            next if(m/^\#\s*udpipe_model\s*=/);
            push(@sentence, $_);
            if(m/^\#\s*sent_id\s*=\s*(.+)$/)
            {
                $current_sent_id = $1;
                $current_sent_id =~ s/\r?\n$//;
            }
            elsif(m/^\s*$/) # end of sentence
            {
                die("Unknown sent_id") if(!defined($current_sent_id));
                $manual_sentences{$current_sent_id} = [];
                @{$manual_sentences{$current_sent_id}} = @sentence;
                @sentence = ();
                $current_sent_id = undef;
            }
        }
        close(FILE);
    }
}

# Process the etalons. Edit them in-place.
foreach my $period ('13', '16', '19')
{
    my $path = "$data_path/etalon$period";
    opendir(DIR, $path) or die("Cannot read folder '$path': $!");
    my @files = sort(grep {-f "$path/$_" && m/\.conllu$/} (readdir(DIR)));
    closedir(DIR);
    foreach my $file (@files)
    {
        my $filepath = "$path/$file";
        print STDERR ("$filepath\n");
        open(FILE, $filepath) or die("Cannot read '$filepath': $!");
        my @document;
        my @sentence;
        my $current_sent_id;
        while(<FILE>)
        {
            push(@sentence, $_);
            if(m/^\#\s*sent_id\s*=\s*(.+)$/)
            {
                $current_sent_id = $1;
                $current_sent_id =~ s/\r?\n$//;
            }
            elsif(m/^\s*$/) # end of sentence
            {
                die("Unknown sent_id") if(!defined($current_sent_id));
                if(exists($manual_sentences{$current_sent_id}))
                {
                    # We cannot simply replace the sentence in the etalon with the one from Bára.
                    # First, the manual file sometimes contains document-level headers at sentences
                    # that are not the first sentence of the document (but they are first in the
                    # excerpt selected for manual annotation). Second, the manual file has good
                    # syntax but possibly outdated morphology (we made some fixes in the etalons
                    # after we gave Bára data to annotate). So we should not copy anything else
                    # than dependency relations!
                    # First, take comment lines from the current etalon.
                    while(@sentence && $sentence[0] =~ m/^\#/)
                    {
                        push(@document, shift(@sentence));
                    }
                    # Add an extra comment that will make this sentence recognizable
                    # as one with manual syntactic annotation.
                    push(@document, "\# manual syntax\n");
                    # Remove any comment lines from the manual syntax version.
                    my @manual = @{$manual_sentences{$current_sent_id}};
                    while(@manual && $manual[0] =~ m/^\#/)
                    {
                        shift(@manual);
                    }
                    # Now both versions should have the same number of lines.
                    my $n_etalon = scalar(@sentence);
                    my $n_manual = scalar(@manual);
                    if($n_etalon != $n_manual)
                    {
                        die("Etalon sentence has $n_etalon and manual sentence has $n_manual non-comment lines");
                    }
                    # Decompose each token/word line and replace syntax with manual annotation.
                    for(my $i = 0; $i <= $#sentence; $i++)
                    {
                        # Is this a word/token line, or the final empty line?
                        if($sentence[$i] =~ m/^[0-9]/)
                        {
                            my @fe = split(/\t/, $sentence[$i]);
                            my @fm = split(/\t/, $manual[$i]);
                            $fe[6] = $fm[6]; # HEAD
                            $fe[7] = $fm[7]; # DEPREL
                            push(@document, join("\t", @fe));
                        }
                        else
                        {
                            push(@document, $sentence[$i]);
                        }
                    }
                }
                else
                {
                    # The sentence should not contain a comment about manual syntax,
                    # as we did not find it in our manual syntactic annotation.
                    if(grep {m/^\# manual syntax/} (@sentence))
                    {
                        print STDERR ("WARNING: Sentence '$current_sent_id' is labeled as 'manual syntax' but it was not found in manually annotated data.\n");
                        @sentence = grep {!m/^\# manual syntax/} (@sentence);
                    }
                    push(@document, @sentence);
                }
                @sentence = ();
                $current_sent_id = undef;
            }
        }
        close(FILE);
        # Now open the file for writing and flush the possibly modified contents back.
        open(FILE, ">$filepath") or die("Cannot write '$filepath': $!");
        print FILE (@document);
        close(FILE);
    }
}

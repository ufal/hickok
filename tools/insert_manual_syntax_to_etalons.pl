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
                    push(@document, @{$manual_sentences{$current_sent_id}});
                }
                else
                {
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

#!/usr/bin/env perl
# Převede soubor CoNLL-U do formátu, který je sice podobný, ale rysy jsou rozepsané do samostatných sloupců.
# Copyright © 2016, 2022, 2024 Dan Zeman <zeman@ufal.mff.cuni.cz>
# License: GNU GPL

use utf8;
use open ':utf8';
binmode(STDIN, ':utf8');
binmode(STDOUT, ':utf8');
binmode(STDERR, ':utf8');

my $sid = '';
while(<>)
{
    if(m/^\#\s*sent_id\s*=\s*(.+)$/)
    {
        $sid = $1;
        $sid =~ s/\r?\n$//;
    }
    elsif(m/^\d/)
    {
        s/\r?\n$//;
        my @fields = split(/\t/, $_);
        my $reversed = myreverse($fields[1]);
        my $lemma1300 = '';
        my @lemma1300 = map {s/^Lemma1300=//; $_} (grep {m/^Lemma1300=/} (split(/\|/, $fields[9])));
        $lemma1300 = $lemma1300[0] if(scalar(@lemma1300) > 0);
        my @features = split(/\|/, $fields[5]);
        my %features;
        foreach my $fpair (@features)
        {
            if($fpair =~ m/^(.+?)=(.+)$/)
            {
                $features{$1} = $2;
            }
        }
        my @fnames = ('Gender', 'Animacy', 'Number', 'Case', 'Degree', 'Person', 'VerbForm', 'Mood', 'Tense', 'Aspect', 'Voice', 'Polarity', 'PronType', 'Reflex', 'Poss', 'Gender[psor]', 'Number[psor]', 'PrepCase', 'Variant', 'NumType', 'NumForm', 'NumValue', 'NameType', 'AdpType', 'Abbr', 'Hyph', 'Style', 'Foreign');
        my @values = map {my $x = $features{$_} // '_'; delete($features{$_}); $x} @fnames;
        # Sanity check: Are there any features that we do not export?
        my @remaining_features = keys(%features);
        if(scalar(@remaining_features)>0)
        {
            print STDERR ("Features not exported: ", join(', ', @remaining_features), "\n");
        }
        splice(@fields, 4, 1, @values);
        if($fields[3] =~ m/^(NUM|PUNCT)$/)
        {
            $fields[1] =~ s/"/""/g; # "
            $fields[1] = '"'.$fields[1].'"';
        }
        splice(@fields, 3, 0, $lemma1300);
        splice(@fields, 2, 0, $reversed);
        unshift(@fields, $sid);
        $_ = join("\t", @fields)."\n";
    }
    print;
}



#------------------------------------------------------------------------------
# Staročeši chtějí pro účely retrográdního řazení převrácený řetězec, ale
# trochu sofistikovanější, aby se s některými dvojicemi znaků zacházelo jako
# s jedním.
#------------------------------------------------------------------------------
sub myreverse
{
    my $x = shift;
    $x = lc($x);
    # Digrafy: ch, ie, uo
    $x =~ s/ch/ħ/g;
    $x =~ s/ie/ĳ/g;
    $x =~ s/uo/ŏ/g;
    $x = reverse($x);
    $x =~ s/ħ/ch/g;
    $x =~ s/ĳ/ie/g;
    $x =~ s/ŏ/uo/g;
    return $x;
}

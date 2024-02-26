#!/usr/bin/env perl
# Převede soubor CoNLL-U do formátu, který je sice podobný, ale rysy jsou rozepsané do samostatných sloupců.
# Copyright © 2016, 2022, 2024 Dan Zeman <zeman@ufal.mff.cuni.cz>
# License: GNU GPL

use utf8;
use open ':utf8';
binmode(STDIN, ':utf8');
binmode(STDOUT, ':utf8');
binmode(STDERR, ':utf8');

# Seznam rysů, které chceme exportovat. Možná by do budoucna mohl být konfigurovatelný z příkazového řádku.
# NumValue ... Býval v konverzi z pražských značek, ale byl k ničemu (hodnota byla stejně vždy "1,2,3"). Z dat UD už jsem ho vyhodil.
# AdpType ... Sice nás nezajímá rozdíl mezi předložkou a záložkou, ale máme tam taky Comprep a hlavně Voc.
# Style ... Nevěřím, že jsme schopni o něm rozhodovat konzistentně. A zejména Style=Arch je obtížně proveditelný u dat, která jdou napříč staletími. (Mělo by to znamenat, že daný výraz byl archaický už v době sepsání textu, ale jak zjistíme, jestli tomu tak bylo?)
my @fnames = ('Gender', 'Animacy', 'Number', 'Case', 'Degree', 'Person',
    'VerbForm', 'Mood', 'Tense', 'Aspect', 'Voice', 'Polarity',
    'PronType', 'Reflex', 'Poss', 'Gender[psor]', 'Number[psor]', 'PrepCase', 'Variant',
    'NumType', 'NumForm', 'NameType', 'AdpType', 'Abbr', 'Hyph', 'Foreign');
# Seznam všech sloupců včetně morfologických rysů.
my @names = ('SENTENCE', 'ID', 'FORM', 'RETRO', 'LEMMA', 'LEMMA1300', 'UPOS', @fnames, 'HEAD', 'DEPREL', 'DEPS', 'MISC');
my %conllu_name_index = ('ID' => 0, 'FORM' => 1, 'LEMMA' => 2, 'UPOS' => 3, 'XPOS' => 4, 'FEATS' => 5, 'HEAD' => 6, 'DEPREL' => 7, 'DEPS' => 8, 'MISC' => 9);

# Vypsat záhlaví tabulky.
print(join("\t", @names)."\n");
my %ignored_features;
my %requested_features;
my %observed_features;
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
        my @features = split(/\|/, $fields[5]);
        my %features;
        foreach my $fpair (@features)
        {
            if($fpair =~ m/^(.+?)=(.+)$/)
            {
                $features{$1} = $2;
            }
        }
        my @output_fields = map {get_column_value($_, $sid, \%features, @fields)} (@names);
        # Sanity check: Are there any features that we do not export?
        foreach my $f (keys(%features))
        {
            $ignored_features{$f}++;
        }
        $_ = join("\t", @output_fields)."\n";
    }
    print;
}
my @ignored_features = sort(keys(%ignored_features));
if(scalar(@ignored_features)>0)
{
    print STDERR ("Features not exported (but observed): ", join(', ', @ignored_features), "\n");
}
my @unknown_features = sort(grep {!exists($observed_features{$_})} (keys(%requested_features)));
if(scalar(@unknown_features)>0)
{
    print STDERR ("Features not observed (but expected): ", join(', ', @unknown_features), "\n");
}



#------------------------------------------------------------------------------
# Dodá hodnotu pole (sloupce) podle jeho názvu. Umožňuje uspořádat sloupce
# podle přání uživatele.
#------------------------------------------------------------------------------
sub get_column_value
{
    my $name = shift;
    my $sid = shift; # poslední spatřené sent_id
    my $features = shift; # hash; použité rysy z něj budeme odstraňovat, aby se na konci dalo zjistit, zda jsme na nějaké zapomněli
    my @conllu_fields = @_;
    if($name eq 'SENTENCE')
    {
        return $sid;
    }
    # Standardní pole formátu CoNLL-U prostě zkopírovat.
    elsif($name =~ m/^(ID|FORM|LEMMA|UPOS|XPOS|FEATS|HEAD|DEPREL|DEPS|MISC)$/)
    {
        my $value = $conllu_fields[$conllu_name_index{$name}];
        if($name eq 'FORM' && $conllu_fields[3] =~ m/^(NUM|PUNCT)$/)
        {
            $value =~ s/"/""/g; # "
            $value = '"'.$value.'"';
        }
        return $value;
    }
    # Zvláštní pole, která jsme si dodefinovali pro naše potřeby.
    elsif($name eq 'RETRO')
    {
        return myreverse($conllu_fields[1]);
    }
    elsif($name eq 'LEMMA1300')
    {
        my $lemma1300 = '';
        my @lemma1300 = map {s/^Lemma1300=//; $_} (grep {m/^Lemma1300=/} (split(/\|/, $conllu_fields[9])));
        $lemma1300 = $lemma1300[0] if(scalar(@lemma1300) > 0);
        return $lemma1300;
    }
    # Neznámé názvy polí považujeme za jména rysů. Jejich seznam neznáme předem, různé soubory můžou obsahovat různé rysy.
    else
    {
        # Zapamatovat si, které z očekávaných rysů byly opravdu spatřeny s neprázdnou hodnotou, abychom to mohli na konci ohlásit.
        $requested_features{$name}++;
        my $value = $features->{$name};
        if(defined($value))
        {
            $observed_features{$name}++;
        }
        else
        {
            $value = '_';
        }
        delete($features->{$name});
        return $value;
    }
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

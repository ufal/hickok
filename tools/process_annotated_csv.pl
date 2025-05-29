#!/usr/bin/env perl
# Přebere anotovaná data. Z ÚJČ dostanu soubory pro Excel (.xlsx), ty otevřu a uložím jako CSV (oddělený středníkem).
# Excel mi při ukládání nedává na výběr např. jiný oddělovač, prostě to uloží. Kódování je ANSI (!) a konce řádků jsou CRLF.
# Když ale excelovský soubor otevřu v LibreOffice Calc, řeknu uložit jak Text CSV a zaškrtnu "Upravit nastavení filtru",
# dostanu na výběr znakovou sadu (Unicode (UTF-8)), oddělovač pole (lze zvolit tabulátor) a oddělovač textu. Konce řádků jsou taky CRLF.
# Zde předpokládáme, že byl zvolen druhý uvedený postup, tj. přes LibreOffice a s tabulátory jako oddělovači.
# Copyright © 2024 Dan Zeman <zeman@ufal.mff.cuni.cz>
# License: GNU GPL

use utf8;
use open ':utf8';
binmode(STDIN, ':utf8');
binmode(STDOUT, ':utf8');
binmode(STDERR, ':utf8');
use Carp;
use Getopt::Long;

sub usage
{
    print STDERR ("Usage: $0 --orig for_annotation.tsv --ann1 by_annotator_1.tsv [--ann2 by_annotator_2.tsv] --name1 AB [--name2 CD]\n");
    print STDERR ("    The original file, as sent to the annotators, is used to check that the annotated file has not been altered too much.\n");
    print STDERR ("    Options --name1 and --name2 give initials of the annotators for difference reports. Default: A1 and A2.\n");
    print STDERR ("Output:\n");
    print STDERR ("    Differences are printed to STDOUT.\n");
    print STDERR ("    In addition, a CoNLL-U file is created for each annotator: Path and base name is taken from --ann1/2, '.conllu' is added.\n");
    print STDERR ("    If the CoNLL-U file already exists, it will be overwritten without warning!\n");
    print STDERR ("    If only one annotated file is provided (e.g., the final annotation), no difference is printed.\n");
}

my $orig;
my $ann1;
my $ann2;
my $name1 = 'A1';
my $name2 = 'A2';
GetOptions
(
    'orig=s'  => \$orig,
    'ann1=s'  => \$ann1,
    'ann2=s'  => \$ann2,
    'name1=s' => \$name1,
    'name2=s' => \$name2
);
if(!defined($orig))
{
    usage();
    confess("Missing the path to the original file");
}
if(!defined($ann1))
{
    usage();
    confess("Missing the path to the file annotated by annotator 1");
}
my $single_annotation = 0;
if(!defined($ann2))
{
    $single_annotation = 1;
}

my $oheaders; # original file
my $olines;
my $a1headers; # file annotated by annotator 1
my $a1lines;
my $a2headers; # file annotated by annotator 2
my $a2lines;
($oheaders, $olines) = read_tsv_file($orig);
# Sometimes the spreadsheet processor will add many empty columns, e.g. to make
# the total number of columns rise to 1024, and name them "Sloupec1" to "Sloupec984".
# Hence we will tell the reading function how many columns we expect and it will
# skip the rest.
my $onh = scalar(@{$oheaders});
my $onl = scalar(@{$olines});
# If there are fatal errors in one or both annotated files, do not crash immediately.
# Try to collect and report them all to minimize the number of times we must get
# back to the annotators and request corrections.
my @a1errors;
my @a2errors;
($a1headers, $a1lines) = read_tsv_file($ann1, $onh, \@a1errors);
($a2headers, $a2lines) = read_tsv_file($ann2, $onh, \@a2errors) unless($single_annotation);
# We will report if the annotated file has too few columns but we must tolerate
# if it has too many. Sometimes the spreadsheet processor will add many empty
# columns, e.g. to make the total number of columns rise to 1024, and name them
# "Sloupec1" to "Sloupec984".
my $a1nh = scalar(@{$a1headers});
if($a1nh < $onh)
{
    push(@a1errors, "The original file had $onh columns, file annotated by $name1 has $a1nh columns");
}
else
{
    # It should not happen that $a1nh > $onh because we told the reading function
    # we want at most $onh columns. But check if we have the right columns.
    foreach my $header (@{$oheaders})
    {
        if(!grep {$_ eq $header} (@{$a1headers}))
        {
            push(@a1errors, "Missing column '$header' in $name1");
        }
    }
}
my $a1nl = scalar(@{$a1lines});
if($a1nl != $onl)
{
    push(@a1errors, "The original file had $onl lines, file annotated by $name1 has $a1nl lines");
}
# Check that the important values that should not be modified are indeed identical in both annotated files and the original.
for(my $i = 0; $i < $onl; $i++)
{
    foreach my $header (qw(SENTENCE ID FORM))
    {
        if($a1lines->[$i]{$header} ne $olines->[$i]{$header})
        {
            my $pad = ' ' x (length('ORIGINAL')-length($name1));
            my $vor = "    ORIGINAL: $olines->[$i]{$header}";
            my $va1 = "    $name1:$pad $a1lines->[$i]{$header}";
            push(@a1errors, "Line $olines->[$i]{LINENO}: Mismatch in $header column\n$vor\n$va1\n");
        }
    }
}
unless($single_annotation)
{
    my $a2nh = scalar(@{$a2headers});
    if($a2nh < $onh)
    {
        push(@a2errors, "The original file had $onh columns, file annotated by $name2 has $a2nh columns");
    }
    else
    {
        # It should not happen that $a2nh > $onh because we told the reading function
        # we want at most $onh columns. But check if we have the right columns.
        foreach my $header (@{$oheaders})
        {
            if(!grep {$_ eq $header} (@{$a2headers}))
            {
                push(@a2errors, "Missing column '$header' in $name2");
            }
        }
    }
    my $a2nl = scalar(@{$a2lines});
    if($a2nl != $onl)
    {
        push(@a2errors, "The original file had $onl lines, file annotated by $name2 has $a2nl lines");
    }
    # Check that the important values that should not be modified are indeed identical in both annotated files and the original.
    for(my $i = 0; $i < $onl; $i++)
    {
        foreach my $header (qw(SENTENCE ID FORM))
        {
            if($a2lines->[$i]{$header} ne $olines->[$i]{$header})
            {
                my $pad = ' ' x (length('ORIGINAL')-length($name2));
                my $vor = "    ORIGINAL: $olines->[$i]{$header}";
                my $va2 = "    $name2:$pad $a2lines->[$i]{$header}";
                push(@a2errors, "Line $olines->[$i]{LINENO}: Mismatch in $header column\n$vor\n$va2\n");
            }
        }
    }
    # Look for differences.
    my $ndiff = 0;
    my $maxl = 0;
    for(my $i = 0; $i < $onl; $i++)
    {
        # Find differences between the two annotated files.
        foreach my $header (@{$oheaders})
        {
            if($a1lines->[$i]{$header} ne $a2lines->[$i]{$header})
            {
                my $message = "Line $olines->[$i]{LINENO} ($olines->[$i]{FORM}): Difference in $header:";
                # Try to align the message with the longest message encountered so far, except for super-outliers.
                my $l = length($message);
                if($l < $maxl)
                {
                    $message .= ' ' x ($maxl-$l);
                }
                elsif($maxl == 0 || $l > $maxl && $l < $maxl*1.2)
                {
                    $maxl = $l;
                }
                my $m1 = "$name1=$a1lines->[$i]{$header}"; $m1 .= ' ' x (length($name1)+10-length($m1));
                my $m2 = "$name2=$a2lines->[$i]{$header}";
                print("$message   $m1   $m2\n");
                $ndiff++;
            }
        }
    }
    print("\nFound $ndiff differences between $name1 and $name2.\n");
}
# Now it is time to stop if there were fatal errors in any of the input files.
my $ne1 = scalar(@a1errors);
my $ne2 = scalar(@a2errors);
if($ne1 or $ne2)
{
    if($ne1)
    {
        print STDERR ("Found $ne1 fatal error(s) in $ann1:\n");
        print STDERR (join('', map {"  $_\n"} (@a1errors)));
    }
    if($ne2)
    {
        print STDERR ("Found $ne2 fatal error(s) in $ann2:\n");
        print STDERR (join('', map {"  $_\n"} (@a2errors)));
    }
    confess('Fatal input errors');
}
# Write each annotator's file in the CoNLL-U format.
my $conllu1 = $ann1;
$conllu1 =~ s/(.)\.[a-z]*$/$1/;
$conllu1 .= '.conllu';
write_conllu_file($conllu1, $a1headers, $a1lines);
unless($single_annotation)
{
    my $conllu2 = $ann2;
    $conllu2 =~ s/(.)\.[a-z]*$/$1/;
    $conllu2 .= '.conllu';
    write_conllu_file($conllu2, $a2headers, $a2lines);
}



#------------------------------------------------------------------------------
# Reads a TSV file into memory. We assume that the files we work with are not
# too big and can be read into memory before processing.
#------------------------------------------------------------------------------
sub read_tsv_file
{
    my $path = shift; # read <> if undef
    my $expected_n_columns = shift; # read all columns if undef
    my $error_list = shift; # array ref; if defined, LINENO errors will be stored here instead of dying immediately
    my @original_args;
    if(defined($path))
    {
        @original_args = @ARGV;
        @ARGV = ($path);
    }
    my $expected_input_columns;
    my @headers;
    # We may need the Emph column even if it was not generated in the file for
    # the annotators. So we will add it to the headers if it is not in the file.
    # However, we must remember if we did so because then we also must generate
    # its empty values.
    my $add_emph = 0;
    my @lines; # array of hashes
    while(<>)
    {
        my $line = $_;
        # Remove line break and trailing empty columns (tabs).
        $line =~ s/\s+$//;
        my @f = split(/\t/, $line);
        # The first line is special.
        if(!defined($expected_input_columns))
        {
            # The first line should contain the headers of the columns.
            @headers = @f;
            # We decided we need the Emph column after the first batch of files
            # was given to the annotators. Therefore we may have to add the column
            # now.
            if(!grep {$_ eq 'Emph'} (@headers))
            {
                $add_emph = 1;
            }
            my $n_columns = scalar(@f);
            # If we know how many columns we expect, check that we have them.
            if(defined($expected_n_columns))
            {
                # If we must generate the Emph column, $expected_n_columns already
                # includes it (because we also generated the column when reading
                # the original file, from which the number is taken), but $n_columns
                # does not include it!
                $expected_input_columns = $add_emph ? $expected_n_columns-1 : $expected_n_columns;
                if($n_columns < $expected_input_columns)
                {
                    confess("Expected $expected_input_columns, found only $n_columns");
                }
                # If there are more columns, it could be Excel's decision to pad
                # the sheet by "Sloupec100", "Sloupec101" etc., so we will just
                # remove them, without reporting an error.
                elsif($n_columns > $expected_input_columns)
                {
                    splice(@headers, $expected_input_columns);
                }
            }
            else
            {
                # In any case we expect more than 1 column. If we do not see them,
                # the file may have been exported with a wrong column separator.
                if($n_columns <= 1)
                {
                    confess('Expected more than one column');
                }
                $expected_input_columns = $n_columns;
            }
            # Now that we have removed superfluous column, we can add the Emph column.
            if($add_emph)
            {
                push(@headers, 'Emph');
            }
        }
        else
        {
            # The columns may be in any order. Hash them by headers. Nevertheless,
            # if there are more columns than expected, the last ones will be ignored.
            # If there are fewer columns than expected, the missing ones will be
            # treated as empty values.
            my %f;
            for(my $i = 0; $i < $expected_input_columns; $i++)
            {
                # The value of the cell may be enclosed in quotation marks if the value is considered dangerous. Get rid of the quotation marks.
                $f[$i] =~ s/^"(.+)"$/$1/;
                # Get rid of leading and trailing spaces.
                $f[$i] =~ s/^\s+//;
                $f[$i] =~ s/\s+$//;
                # Replace empty values by underscores (but not for the SENTENCE column because we need the empty line at the end).
                $f[$i] = '_' if($f[$i] eq '' && $headers[$i] ne 'SENTENCE');
                # Fix MWT ranges that were mis-interpreted by Excel as dates.
                if($headers[$i] eq 'ID')
                {
                    $f[$i] = fix_mwt_id($f[$i]);
                }
                $f{$headers[$i]} = $f[$i];
            }
            if($add_emph)
            {
                $f{Emph} = '_';
            }
            # Make annotations more consistent and automatically fix certain
            # common errors.
            fix_morphology(\%f);
            # Check that the line numbers are ordered.
            if($f{LINENO} != $.-1)
            {
                if(defined($error_list))
                {
                    push(@{$error_list}, "The LINENO column on line $. contains $f{LINENO}");
                }
                else
                {
                    confess("The LINENO column on line $. contains $f{LINENO}");
                }
            }
            # Skip the extra lines that we inserted to the file for readability.
            if($f{SENTENCE} eq '###!!! EXTRA LINE')
            {
                next;
            }
            push(@lines, \%f);
        }
    }
    # Restore the original args if needed.
    if(defined($path))
    {
        @ARGV = @original_args;
    }
    # Return the list of headers and list of line hashes.
    return (\@headers, \@lines);
}



#------------------------------------------------------------------------------
# Fixes multiword token range that was misinterpreted by Excel as a date.
#------------------------------------------------------------------------------
my %conversion;
BEGIN
{
    %conversion =
    (
        'I'    => 1,
        'II'   => 2,
        'III'  => 3,
        'IV'   => 4,
        'V'    => 5,
        'VI'   => 6,
        'VII'  => 7,
        'VIII' => 8,
        'IX'   => 9,
        'X'    => 10,
        'XI'   => 11,
        'XII'  => 12
    );
}
sub fix_mwt_id
{
    my $x = shift;
    if($x =~ m/^([0-9]+)\.([IVX]+)$/)
    {
        my $x0 = $1;
        my $x1 = $2;
        if(exists($conversion{$x1}))
        {
            $x = "$x0-$conversion{$x1}";
        }
    }
    elsif($x =~ m/^([IVX]+)\.([0-9]+)$/)
    {
        my $x0 = $1;
        my $x1 = $2;
        if(exists($conversion{$x0}))
        {
            $x = "$conversion{$x0}-$x1";
        }
    }
    return $x;
}



#------------------------------------------------------------------------------
# Fixes certain annotation inconsistencies that the annotators are allowed to
# do. The fixes must be done in this script, before the differences between
# annotators are computed and reported.
#------------------------------------------------------------------------------
sub fix_morphology
{
    my $f = shift; # hash ref (fixes will be done in-place)
    # Nouns do not have Polarity. As per meeting on 2024-05-16, negative nouns
    # have negative lemmas and are not treated as negative forms of affirmative
    # lemmas.
    if($f->{UPOS} =~ m/^NOUN|PROPN$/)
    {
        $f->{Polarity} = '_';
    }
    # Third person pronouns in non-nominative must have the PrepCase feature
    # (except clitics "ho" and "mu").
    if($f->{UPOS} eq 'PRON' && $f->{LEMMA} eq 'on' && $f->{Case} =~ m/^(Gen|Dat|Acc|Loc|Ins)$/)
    {
        if($f->{FORM} =~ m/^j/i)
        {
            $f->{PrepCase} = 'Npr';
        }
        elsif($f->{FORM} =~ m/^[nň]/i)
        {
            $f->{PrepCase} = 'Pre';
        }
    }
    # Adjectives including short forms and passive participles should have
    # non-empty Degree.
    if($f->{UPOS} eq 'ADJ' && $f->{NumType} eq '_' && $f->{Poss} eq '_' && ($f->{VerbForm} eq '_' || $f->{Voice} eq 'Pass'))
    {
        if($f->{Degree} eq '_')
        {
            $f->{Degree} = 'Pos';
        }
    }
    # Pronouns use Variant=Short only for a handful of forms, based on existing
    # Modern Czech data. The feature is not used elsewhere where longer and
    # shorter forms compete.
    if($f->{UPOS} eq 'PRON')
    {
        if($f->{FORM} =~ m/^(mě|mi|tě|ti|ho|mu|se|si)ť?$/i)
        {
            $f->{Variant} = 'Short';
        }
        else
        {
            $f->{Variant} = '_';
        }
    }
    # The indefinite quantifier "nejeden" is not annotated as negative form of
    # the numeral "jeden". It has the lemma "nejeden", tag DET (not NUM),
    # PronType=Ind.
    if($f->{LEMMA} eq 'nejeden')
    {
        $f->{UPOS} = 'DET';
        $f->{PronType} = 'Ind';
        $f->{NumType} = 'Card';
        $f->{NumForm} = '_';
    }
    # The determiner "sám/samý" is lemmatized as "sám" in Hičkok but we need to
    # make it consistent with Modern Czech data, where it is lemmatized "samý".
    if($f->{UPOS} eq 'DET' && $f->{LEMMA} eq 'sám')
    {
        $f->{LEMMA} = 'samý';
    }
    # The verb "být" is always AUX and never VERB. And it is imperfective.
    if($f->{UPOS} =~ m/^(VERB|AUX)$/ && $f->{LEMMA} eq 'být')
    {
        $f->{UPOS} = 'AUX';
        $f->{Aspect} = 'Imp';
    }
    # Ideally we want "oba" (both) to have NumType=Card | PronType=Tot but at
    # present we do not have the PronType in Modern Czech data and the validator
    # does not expect it.
    if($f->{UPOS} eq 'NUM' && $f->{LEMMA} eq 'oba' && $f->{PronType} eq 'Tot')
    {
        $f->{PronType} = '_';
    }
    # The modern infinitive ending in -t should serve as the lemma instead of
    # the old infinitive ending in -ti; make sure that the annotators did not
    # forget it. (But the few verbs ending in -ci are OK and should not be
    # replaced with -ct.)
    if($f->{UPOS} =~ m/^(VERB|AUX)$/ && $f->{LEMMA} =~ m/ti$/i)
    {
        $f->{LEMMA} =~ s/ti$/t/i;
    }
    # In some cases, the annotators consider a verb (or participle) biaspectual,
    # but in Modern Czech it is treated as single aspect.
    if($f->{LEMMA} =~ m/^(řečený|říci)$/)
    {
        $f->{Aspect} = 'Perf';
    }
    # Adverbs: Unlike the previous practice in PDT and Czech UD, we will
    # require Degree and Polarity for most adverbs even if the only value
    # they can have is Pos. The reason is that some adverbs can be negated in
    # Old Czech, although it does not happen in Modern Czech (vždy-nevždy).
    # The other reason is that it will be simpler and more consistent. The
    # exceptions that have empty Degree and Polarity are now determined by
    # other features: non-empty PronType other than Tot, or non-empty NumType.
    # In order to reduce the necessity for the annotators to supply the values,
    # default values can be guessed here.
    if($f->{UPOS} eq 'ADV' && $f->{NumType} eq '_' && $f->{PronType} =~ m/^(Tot|_)$/)
    {
        if($f->{Polarity} eq '_')
        {
            # We cannot require that the lemma is identical to the lowercased form
            # because there are many spelling variants in Old Czech (for example,
            # "přieliš" is lemmatized as "příliš"). Therefore, we will simply check
            # that the form does not start with "ne-".
            if($f->{LEMMA} eq lc($f->{FORM}) or lc($f->{FORM}) !~ m/^ne/i)
            {
                $f->{Polarity} = 'Pos';
            }
            # The negative ones must match or must be manually annotated for Polarity.
            elsif('ne'.$f->{LEMMA} eq lc($f->{FORM}))
            {
                $f->{Polarity} = 'Neg';
            }
        }
        if($f->{Degree} eq '_')
        {
            if($f->{FORM} !~ m/^(n[ae]j)?v(í|ie)ce?$/i)
            {
                $f->{Degree} = 'Pos';
            }
        }
    }
    # Following a new agreement from October 2024, emphatic -ž is only
    # annotated in non-lexicalized cases (see the wiki for the list of the
    # lexicalized ones: e.g., "kdož" is lexicalized, "dřevniehož" is not).
    # It is never treated as a multiword token. Instead, the lemma has no -ž
    # and there is a new feature Emph=Yes. Since the pregenerated files had no
    # column for Emph, Hyph=ž can be temporarily used instead of Emph=Yes.
    if($f->{Hyph} =~ m/^ž$/i)
    {
        $f->{Hyph} = '_';
        $f->{Emph} = 'Yes';
    }
    #--------------------------------------------------------------------------
    # The following is more about syntax than morphology. The data contains
    # syntactic annotation but only morphology was edited manually. Here we
    # just try to avoid validation errors stemming from syntax incompatible
    # with the manual morphology.
    if($f->{UPOS} eq 'AUX' && $f->{DEPREL} =~ m/^(case|mark|nummod)(:|$)/)
    {
        $f->{DEPREL} = 'aux';
    }
    if($f->{UPOS} ne'AUX' && $f->{DEPREL} =~ m/^(aux)(:|$)/)
    {
        $f->{DEPREL} = 'dep';
    }
    if($f->{UPOS} eq 'PRON' && $f->{DEPREL} =~ m/^(case|cc)(:|$)/)
    {
        $f->{DEPREL} = 'dep';
    }
    if($f->{UPOS} eq 'ADV' && $f->{DEPREL} =~ m/^(nummod|nmod|obl)(:|$)/)
    {
        $f->{DEPREL} = 'advmod';
    }
    if($f->{UPOS} eq 'PART' && $f->{DEPREL} =~ m/^(det|punct)(:|$)/)
    {
        $f->{DEPREL} = 'dep';
    }
}



#------------------------------------------------------------------------------
# Writes a CoNLL-U file based on headers and lines previously read from TSV.
#------------------------------------------------------------------------------
sub write_conllu_file
{
    my $path = shift;
    my $headers = shift;
    my $lines = shift;
    # Use :raw to prevent LF to CRLF translation. Combine it with :utf8, otherwise the encoding will be messed up.
    open(OUT, '>:raw:utf8', $path) or confess("Cannot write '$path': $!");
    my @fheaders = sort {lc($a) cmp lc($b)} (grep {uc($_) ne $_} (@{$headers}));
    my $n_err = 0;
    foreach my $line (@{$lines})
    {
        if($line->{ID} =~ m/^[0-9]/)
        {
            # This is a token/word/node line.
            my $feats = join('|', map {"$_=$line->{$_}"} (grep {$line->{$_} ne '_'} (@fheaders)));
            $feats = '_' if($feats eq '');
            $n_err = encode_resegment_instructions($line, $n_err);
            # The annotated files do not contain XPOS. Print underscore now. We will compute XPOS from UPOS+FEATS later.
            print OUT ("$line->{ID}\t$line->{FORM}\t$line->{LEMMA}\t$line->{UPOS}\t_\t$feats\t$line->{HEAD}\t$line->{DEPREL}\t$line->{DEPS}\t$line->{MISC}\n");
        }
        else
        {
            # This is a sentence-level comment or an empty line after a sentence.
            if($line->{SENTENCE} =~ m/^\#\s*text\s*=\s*$/)
            {
                print OUT ("\# text = $line->{FORM}\n");
            }
            else
            {
                print OUT ("$line->{SENTENCE}\n");
            }
        }
    }
    close(OUT);
    # If there were errors in the tokenization instructions, allow some time to
    # spot them in the log. Nevertheless, they are also saved as Bug in MISC,
    # so they will be visible when we later run Udapi ud.cs.MarkFeatsBugs.
    if($n_err > 0)
    {
        print STDERR ("There were $n_err errors when writing $path.\n");
        sleep(5);
    }
}



#------------------------------------------------------------------------------
# Reads columns with instructions for resegmentation of sentences and words.
# Checks whether the instructions are correct and encodes them in MISC so that
# Udapi can later process them.
#------------------------------------------------------------------------------
sub encode_resegment_instructions
{
    my $line = shift; # hash ref
    my $n_err = shift;
    my @misc = $line->{MISC} eq '_' ? () : split(/\|/, $line->{MISC});
    # Sentence segmentation instructions are in the RESEGMENT column.
    # We may want to split a sentence ('rozdělit') or merge it with previous
    # sentence ('spojit').
    if($line->{RESEGMENT} ne '_')
    {
        if($line->{RESEGMENT} eq 'rozdělit')
        {
            unshift(@misc, 'SplitSentence=Here');
        }
        elsif($line->{RESEGMENT} eq 'spojit')
        {
            unshift(@misc, 'JoinSentence=Here');
        }
        else
        {
            confess("Unknown resegmenting instruction '$line->{RESEGMENT}'");
        }
    }
    # Word segmentation instructions are in the columns RETOKENIZE and SUBTOKENS.
    # We may want to split a token ('rozdělit') or merge it with previous token
    # ('spojit'). At present, only splitting of selected kinds of multiword tokens
    # is implemented in Udapi.
    if($line->{RETOKENIZE} ne '_')
    {
        # Fix previously encountered typos.
        $line->{RETOKENIZE} = 'rozdělit' if($line->{RETOKENIZE} =~ m/^roz(dl)?ělit$/);
        if($line->{RETOKENIZE} eq 'rozdělit')
        {
            if($line->{ID} =~ m/-/)
            {
                print STDERR ("Resplitting an existing multiword token ('$line->{FORM}') is not yet implemented.\n");
                unshift(@misc, "Bug=RetokenizeExistingMWTNotSupported");
                $n_err++;
            }
            # In fact, the SUBTOKENS column is not so important because we will
            # reject splits that do not follow a pre-approved pattern. So if the
            # column is empty but we see a known pattern, we can fill it in.
            my $auto_subtokens;
            if($line->{FORM} =~ m/^(a|kdy)(bych|bys|by|bychom|bychme|byšta|byste)$/)
            {
                my $sconj = $1 eq 'a' ? 'aby' : 'když';
                $auto_subtokens = "$sconj $2";
            }
            # byls, jaks, žes, ...
            # But there are other spellings: jaks’ = jak jsi, žejs’ = že jsi
            elsif($line->{FORM} =~ m/^(.+?)(j?s’?)$/i)
            {
                $auto_subtokens = "$1 jsi";
            }
            # myslilaj = myslila i (CCONJ)
            # I do not know how much productive it is.
            elsif($line->{FORM} =~ m/^(myslila)j$/i)
            {
                $auto_subtokens = "$1 i";
            }
            # bylť, onť, ...
            elsif($line->{FORM} =~ m/^(.+?)(ť|tě|ti)$/i)
            {
                $auto_subtokens = "$1 $2";
            }
            # naň, oň, ...
            # Known contractions of this type will be split by Udapi even
            # without instruction from the annotator.
            elsif($line->{FORM} =~ m/^(na|nade|o|pro|přěde|ski?rz[eě]|za)[nň]$/i)
            {
                $auto_subtokens = "$1 něj";
                # At present Udapi removes vocalization from "přěde" (=> "přěd něj") but not from "skirzě".
                $auto_subtokens =~ s/(nad|přěd)e /přěd /;
            }
            # skirzěňž, zaňž, ...
            # Known contractions of this type will be split by Udapi even
            # without instruction from the annotator.
            elsif($line->{FORM} =~ m/^(na|nade|o|pro|přěde|ski?rz[eě]|za)ňž$/i)
            {
                $auto_subtokens = "$1 nějž";
                # At present Udapi removes vocalization from "přěde" (=> "přěd něj") but not from "skirzě".
                $auto_subtokens =~ s/(nad|přěd)e /přěd /;
            }
            # The proposed subtokens should try to follow the casing of the original.
            if(defined($auto_subtokens))
            {
                if($line->{FORM} eq uc($line->{FORM}))
                {
                    $auto_subtokens = uc($auto_subtokens);
                }
                elsif($line->{FORM} =~ m/^\p{Lu}/)
                {
                    # The /e option causes the substitution part to be interpreted
                    # as an expression => the uc() function should work.
                    $auto_subtokens =~ s/^(.)/uc($1)/e;
                }
                if($line->{SUBTOKENS} eq '_')
                {
                    $line->{SUBTOKENS} = $auto_subtokens;
                }
                elsif($line->{SUBTOKENS} ne $auto_subtokens)
                {
                    print STDERR ("Mismatch: FORM='$line->{FORM}', proposed SUBTOKENS='$line->{SUBTOKENS}' changed to '$auto_subtokens'.\n");
                    $line->{SUBTOKENS} = $auto_subtokens;
                }
            }
            elsif($line->{SUBTOKENS} ne '_')
            {
                print STDERR ("Splitting '$line->{FORM}' to '$line->{SUBTOKENS}' is not supported.\n");
                unshift(@misc, "Bug=SplittingUnsupportedPattern");
                $n_err++;
            }
            if($line->{SUBTOKENS} ne '_')
            {
                # byls
                # bylť
                # přědeň
                # skirzěňž, zaňž
                # abychme (předzpracování zatím umí jen novočeské abych, abys, aby, abychom, abyste)
                if($line->{SUBTOKENS} =~ m/^(\S+) (jsi|bychme|byšta|i|ť|tě|ti|nějž?)$/)
                {
                    unshift(@misc, "AddMwt=$line->{SUBTOKENS}");
                }
                else
                {
                    print STDERR ("Splitting a token to '$line->{SUBTOKENS}' is not yet implemented.\n");
                    unshift(@misc, "Bug=SplittingUnsupportedPattern");
                    $n_err++;
                }
            }
            else
            {
                print STDERR ("RETOKENIZE='rozdělit' but there are no SUBTOKENS (FORM=$line->{FORM}).\n");
                unshift(@misc, "Bug=RetokenizeRozdělitWithoutSubtokens");
                $n_err++;
            }
        }
        elsif($line->{RETOKENIZE} eq 'spojit')
        {
            # Merging two tokens is currently supported only without MWTs and
            # if there was no space between this token and the previous one in
            # the original text. We do not have to check the conditions here.
            # Udapi ud.JoinToken will check them and if they are not met, it
            # will print a warning and add a Bug attribute to MISC.
            unshift(@misc, 'JoinToken=Here');
        }
        else
        {
            confess("Unknown retokenizing instruction '$line->{RETOKENIZE}'");
        }
    }
    elsif($line->{SUBTOKENS} ne '_')
    {
        confess("SUBTOKENS='$line->{SUBTOKENS}' but RETOKENIZE is not 'rozdělit'");
    }
    $line->{MISC} = scalar(@misc) > 0 ? join('|', @misc) : '_';
    return $n_err;
}

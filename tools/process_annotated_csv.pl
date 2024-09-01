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
    print STDERR ("Usage: $0 --orig for_annotation.tsv --ann1 by_annotator_1.tsv --ann2 by_annotator_2.tsv --name1 AB --name2 CD\n");
    print STDERR ("    The original file, as sent to the annotators, is used to check that the annotated file has not been altered too much.\n");
    print STDERR ("    Options --name1 and --name2 give initials of the annotators for difference reports. Default: A1 and A2.\n");
    print STDERR ("Output:\n");
    print STDERR ("    Differences are printed to STDOUT.\n");
    print STDERR ("    In addition, a CoNLL-U file is created for each annotator: Path and base name is taken from --ann1/2, '.conllu' is added.\n");
    print STDERR ("    If the CoNLL-U file already exists, it will be overwritten without warning!\n");
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
if(!defined($ann2))
{
    usage();
    confess("Missing the path to the file annotated by annotator 2");
}

my $oheaders; # original file
my $olines;
my $a1headers; # file annotated by annotator 1
my $a1lines;
my $a2headers; # file annotated by annotator 2
my $a2lines;
($oheaders, $olines) = read_tsv_file($orig);
($a1headers, $a1lines) = read_tsv_file($ann1);
($a2headers, $a2lines) = read_tsv_file($ann2);
my $onh = scalar(@{$oheaders});
my $onl = scalar(@{$olines});
# We will report if the annotated file has too few columns but we must tolerate
# if it has too many. Sometimes the spreadsheet processor will add many empty
# columns, e.g. to make the total number of columns rise to 1024, and name them
# "Sloupec1" to "Sloupec984".
my $a1nh = scalar(@{$a1headers});
if($a1nh < $onh)
{
    confess("The original file had $onh columns, file annotated by $name1 has $a1nh columns");
}
else
{
    if($a1nh > $onh)
    {
        splice(@{$a1headers}, $onh);
        $a1nh = $onh;
    }
    foreach my $header (@{$oheaders})
    {
        if(!grep {$_ eq $header} (@{$a1headers}))
        {
            confess("Missing column '$header' in $name1");
        }
    }
}
my $a1nl = scalar(@{$a1lines});
if($a1nl != $onl)
{
    confess("The original file had $onl lines, file annotated by $name1 has $a1nl lines");
}
my $a2nh = scalar(@{$a2headers});
if($a2nh < $onh)
{
    confess("The original file had $onh columns, file annotated by $name2 has $a2nh columns");
}
else
{
    if($a2nh > $onh)
    {
        splice(@{$a2headers}, $onh);
        $a2nh = $onh;
    }
    foreach my $header (@{$oheaders})
    {
        if(!grep {$_ eq $header} (@{$a2headers}))
        {
            confess("Missing column '$header' in $name2");
        }
    }
}
my $a2nl = scalar(@{$a2lines});
if($a2nl != $onl)
{
    confess("The original file had $onl lines, file annotated by $name2 has $a2nl lines");
}
# Look for differences.
my $ndiff = 0;
my $maxl = 0;
for(my $i = 0; $i < $onl; $i++)
{
    # Check that the important values that should not be modified are indeed identical in both annotated files and the original.
    foreach my $header (qw(SENTENCE ID FORM))
    {
        if($a1lines->[$i]{$header} ne $olines->[$i]{$header})
        {
            confess("Line $olines->[$i]{LINENO}: Mismatch in $header column\nORIGINAL: $olines->[$i]{$header}\n$name1: $a1lines->[$i]{$header}\n");
        }
    }
    foreach my $header (qw(SENTENCE ID FORM))
    {
        if($a2lines->[$i]{$header} ne $olines->[$i]{$header})
        {
            confess("Line $olines->[$i]{LINENO}: Mismatch in $header column\nORIGINAL: $olines->[$i]{$header}\n$name2: $a2lines->[$i]{$header}\n");
        }
    }
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
# Write each annotator's file in the CoNLL-U format.
my $conllu1 = $ann1;
my $conllu2 = $ann2;
$conllu1 =~ s/(.)\.[a-z]*$/$1/;
$conllu2 =~ s/(.)\.[a-z]*$/$1/;
$conllu1 .= '.conllu';
$conllu2 .= '.conllu';
write_conllu_file($conllu1, $a1headers, $a1lines);
write_conllu_file($conllu2, $a2headers, $a2lines);



#------------------------------------------------------------------------------
# Reads a TSV file into memory. We assume that the files we work with are not
# too big and can be read into memory before processing.
#------------------------------------------------------------------------------
sub read_tsv_file
{
    my $path = shift; # read <> if undef
    my @original_args;
    if(defined($path))
    {
        @original_args = @ARGV;
        @ARGV = ($path);
    }
    my $n_columns;
    my @headers;
    my @lines; # array of hashes
    while(<>)
    {
        my $line = $_;
        # Remove line break and trailing empty columns (tabs).
        $line =~ s/\s+$//;
        my @f = split(/\t/, $line);
        # The first line is special.
        if(!defined($n_columns))
        {
            $n_columns = scalar(@f);
            # We expect more than 1 column. If we do not see them, the file may have been exported with a wrong column separator.
            if($n_columns <= 1)
            {
                confess('Expected more than one column');
            }
            # The first line should contain the headers of the columns.
            @headers = @f;
        }
        else
        {
            # Check that we do not have more columns than headers.
            my $n = scalar(@f);
            if($n > $n_columns)
            {
                confess("Expected $n_columns columns but found $n on line $.");
            }
            # The columns may be in any order. Hash them by headers.
            my %f;
            for(my $i = 0; $i <= $#f; $i++)
            {
                # The value of the cell may be enclosed in quotation marks if the value is considered dangerous. Get rid of the quotation marks.
                $f[$i] =~ s/^"(.+)"$/$1/;
                # Get rid of leading and trailing spaces.
                $f[$i] =~ s/^\s+//;
                $f[$i] =~ s/\s+$//;
                # Replace empty values by underscores.
                $f[$i] = '_' if($f[$i] eq '');
                # Fix MWT ranges that were mis-interpreted by Excel as dates.
                if($headers[$i] eq 'ID')
                {
                    $f[$i] = fix_mwt_id($f[$i]);
                }
                $f{$headers[$i]} = $f[$i];
            }
            # Make annotations more consistent and automatically fix certain
            # common errors.
            fix_morphology(\%f);
            # Check that the line numbers are ordered.
            if($f{LINENO} != $.-1)
            {
                confess("The LINENO column on line $. contains $f{LINENO}");
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
    foreach my $line (@{$lines})
    {
        if($line->{ID} =~ m/^[0-9]/)
        {
            # This is a token/word/node line.
            my $feats = join('|', map {"$_=$line->{$_}"} (grep {$line->{$_} ne '_'} (@fheaders)));
            $feats = '_' if($feats eq '');
            my @misc = $line->{MISC} eq '_' ? () : split(/\|/, $line->{MISC});
            if($line->{SUBTOKENS} ne '_')
            {
                unshift(@misc, "SUBTOKENS=$line->{SUBTOKENS}");
            }
            if($line->{RETOKENIZE} ne '_')
            {
                unshift(@misc, "RETOKENIZE=$line->{RETOKENIZE}");
            }
            if($line->{RESEGMENT} ne '_')
            {
                unshift(@misc, "RESEGMENT=$line->{RESEGMENT}");
            }
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
}

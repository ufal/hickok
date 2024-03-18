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
    print STDERR ("Usage: $0 --orig for_annotation.tsv < annotated.tsv\n");
    print STDERR ("    The original file, as sent to the annotators, is used to check that the annotated file has not been altered too much.\n");
}

my $orig;
GetOptions
(
    'orig=s' => \$orig
);
if(!defined($orig))
{
    usage();
    confess("Missing the path to the original file");
}

my $oheaders; # original file
my $olines;
my $aheaders; # annotated file
my $alines;
($oheaders, $olines) = read_tsv_file($orig);
($aheaders, $alines) = read_tsv_file();
my $onh = scalar(@{$oheaders});
my $anh = scalar(@{$aheaders});
if($anh != $onh)
{
    confess("The original file had $onh columns but the annotated file has $anh columns");
}
my $onl = scalar(@{$olines});
my $anl = scalar(@{$alines});
if($anl != $onl)
{
    confess("The original file had $onl lines but the annotated file has $anl lines");
}
# Check that the important values that should not be modified are indeed identical in both files.
for(my $i = 0; $i <= $#{$alines}; $i++)
{
    if($alines->[$i]{SENTENCE} ne $olines->[$i]{SENTENCE})
    {
        confess("Line $alines->[$i]{LINENO}: Mismatch in SENTENCE column\nORIGINAL:  $olines->[$i]{SENTENCE}\nANNOTATED: $alines->[$i]{SENTENCE}\n");
    }
    if($alines->[$i]{ID} ne $olines->[$i]{ID})
    {
        confess("Line $alines->[$i]{LINENO}: Mismatch in ID column\nORIGINAL:  $olines->[$i]{ID}\nANNOTATED: $alines->[$i]{ID}\n");
    }
    if($alines->[$i]{FORM} ne $olines->[$i]{FORM})
    {
        confess("Line $alines->[$i]{LINENO}: Mismatch in FORM column\nORIGINAL:  $olines->[$i]{FORM}\nANNOTATED: $alines->[$i]{FORM}\n");
    }
}



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
                if($headers[$i] eq 'ID')
                {
                    $f[$i] = fix_mwt_id($f[$i]);
                }
                $f{$headers[$i]} = $f[$i];
            }
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

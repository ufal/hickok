#!/usr/bin/env perl
# Slije dva CoNLL-U soubory. Z prvního vezme všechny větné komentáře a anotaci
# v MISC, ze druhého vezme anotace LEMMA, UPOS, XPOS, FEATS, HEAD, DEPREL a
# případné komentáře "generator" a "udpipe_model" na začátku souboru. Předpokládá
# se, že oba soubory mají stejnou tokenizaci, slovní a větnou segmentaci.
# Skript slouží k přelití anotace z UDPipe do původního souboru, ve kterém mohou
# být další informace, které chceme zachovat.
# Copyright © 2022 Dan Zeman <zeman@ufal.mff.cuni.cz>
# License: GNU GPL

use utf8;
use open ':utf8';
binmode(STDIN, ':utf8');
binmode(STDOUT, ':utf8');
binmode(STDERR, ':utf8');
use Carp;

if(scalar(@ARGV) != 2)
{
    confess("Usage: $0 orig.conllu udpipe.conllu > merged.conllu");
}
my $orgpath = $ARGV[0];
my $udppath = $ARGV[1];
open(ORG, $orgpath) or confess("Cannot read $orgpath: $!");
open(UDP, $udppath) or confess("Cannot read $udppath: $!");
my $orgli = 0; # original file line number
my $udpli = 0; # udpipe file line number
my $udpline = get_next_line(*UDP, \$udpli);
if($udpline =~ m/^\#\s*generator\s*=/)
{
    print("$udpline\n");
    $udpline = get_next_line(*UDP, \$udpli);
    if($udpline =~ m/^\#\s*udpipe_model\s*=/)
    {
        print("$udpline\n");
    }
    else
    {
        confess("Expected udpipe_model line");
    }
}
else
{
    confess("Expected generator line");
}
# We cannot use $orgline as the while condition because empty line is OK (only undef should terminate the loop).
while(1)
{
    my $orgline = get_next_line(*ORG, \$orgli);
    last if(!defined($orgline));
    if($orgline =~ m/^\d/)
    {
        do
        {
            $udpline = get_next_line(*UDP, \$udpli);
            if(!defined($udpline))
            {
                confess("Unexpected end of UDPipe file; original file at line $orgli");
            }
        }
        while($udpline !~ m/^\d/);
        my @of = split(/\t/, $orgline);
        my @uf = split(/\t/, $udpline);
        if($of[1] ne $uf[1])
        {
            confess("Token mismatch: original '$of[1]' at line $orgli, UDPipe '$uf[1]' at line $udpli");
        }
        # Copy lemma, UPOS, XPOS, features, head and deprel from UDPipe to the original file.
        for(my $i = 2; $i <= 7; $i++)
        {
            $of[$i] = $uf[$i];
        }
        $orgline = join("\t", @of);
    }
    print("$orgline\n");
}
close(ORG);
close(UDP);



#------------------------------------------------------------------------------
# Reads a line from a file. Strips it off the line break and returns it.
#------------------------------------------------------------------------------
sub get_next_line
{
    my $fh = shift; # the handle of the open file
    my $li = shift; # reference to the current line number
    my $line = <$fh>;
    return undef if(!defined($line));
    ${$li}++;
    $line =~ s/\r?\n$//;
    return $line;
}

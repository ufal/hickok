#!/usr/bin/env perl
# Fixes treatment of Czech quotation marks with respect to sentence segmentation.
# The UDPipe Czech-PDT model does not know the Czech Unicode „quotes“ (typically
# surrounded by spaces from both sides in the Old Czech data). It often moves
# the closing quotation mark to the next sentence. Move it back.
# Copyright © 2022 Dan Zeman <zeman@ufal.mff.cuni.cz>
# License: GNU GPL

use utf8;
use open ':utf8';
binmode(STDIN, ':utf8');
binmode(STDOUT, ':utf8');
binmode(STDERR, ':utf8');

my @buffer;
my @sentence;
while(<>)
{
    push(@sentence, $_);
    if(m/^\s*$/)
    {
        process_sentence(\@buffer, @sentence);
        @sentence = ();
    }
}
# Flush the buffer.
foreach my $bsentence (@buffer)
{
    print(join('', @{$bsentence}));
}



#------------------------------------------------------------------------------
# Process the sentence that was just read.
#------------------------------------------------------------------------------
sub process_sentence
{
    my $buffer = shift;
    my @sentence = @_;
    # If the sentence starts with a closing quotation mark (Czech, i.e. '“'; it
    # would be opening mark in English), move it to the previous sentence.
    my $something_left = 1;
    if(scalar(@{$buffer}) > 0)
    {
        for(my $i = 0; $i <= $#sentence; $i++)
        {
            # The quotation mark should not be part of a multi-word token but if it
            # is, do not touch it.
            if($sentence[$i] =~ m/^\d+-\d+\t/)
            {
                last;
            }
            elsif($sentence[$i] =~ m/^1\t“\t/)
            {
                my $lastid;
                my $rootid = '_';
                my $no_space_after = 0;
                foreach my $line (@{$buffer->[-1]})
                {
                    if($line =~ m/^\d+\t/)
                    {
                        my @f = split(/\t/, $line);
                        $lastid = $f[0];
                        if($f[6] eq '0' && $f[7] =~ m/^root(:|$)/)
                        {
                            $rootid = $f[0];
                        }
                        my $misc = $f[9];
                        $misc =~ s/\r?\n$//;
                        $no_space_after = $misc ne '_' && grep {m/^SpaceAfter=No$/} (split(/\|/, $misc));
                    }
                }
                if(!defined($lastid))
                {
                    die("Cannot find id of the last token of the previous sentence");
                }
                my @f = split(/\t/, $sentence[$i]);
                # Note down if the quotation mark was the root in the current
                # sentence. It will be important when adjusting the rest of the
                # sentence.
                my $wasroot = $f[6] eq '0';
                $f[0] = $lastid+1;
                $f[3] = 'PUNCT'; # upos from UDPipe is sometimes PART
                $f[6] = $rootid; # head
                $f[7] = 'punct'; # deprel
                # Insert the quotation mark before the last line of the previous
                # sentence (which should be the empty line).
                splice(@{$buffer->[-1]}, $#{$buffer->[-1]}, 0, join("\t", @f));
                # Adjust text in the previous sentence.
                foreach my $line (@{$buffer->[-1]})
                {
                    if($line =~ m/^\#\s*text\s*=/)
                    {
                        $line =~ s/\r?\n$//;
                        unless($no_space_after)
                        {
                            $line .= ' ';
                        }
                        $line .= '“';
                        $line .= "\n";
                        last;
                    }
                }
                # Remove the quotation mark from the current sentence.
                splice(@sentence, $i, 1);
                $something_left = 0;
                # Adjust ID and HEAD of the remaining nodes in @sentence.
                my $newroot;
                foreach my $line (@sentence)
                {
                    if($line =~ s/^(\#\s*text\s*=\s*)“\s*/$1/)
                    {
                        # No more action. We have removed the quotation mark as a side-effect of the condition above.
                    }
                    elsif($line =~ m/^\d/)
                    {
                        $something_left = 1;
                        my @f = split(/\t/, $line);
                        if($f[0] =~ m/^(\d+)\.(\d+)$/)
                        {
                            $f[0] = ($1-1).'.'.$2;
                        }
                        elsif($f[0] =~ m/^(\d+)-(\d+)$/)
                        {
                            $f[0] = ($1-1).'-'.($2-1);
                        }
                        else
                        {
                            $f[0]--;
                        }
                        if($f[6] ne '_' && $f[6] ne '0')
                        {
                            # If the quotation mark was the root, the first child we encounter will be the new root.
                            if($f[6] eq '1')
                            {
                                if($wasroot)
                                {
                                    if(defined($newroot))
                                    {
                                        $f[6] = $newroot;
                                    }
                                    else
                                    {
                                        $f[6] = 0;
                                        $f[7] = 'root';
                                        $newroot = $f[0];
                                    }
                                }
                                else
                                {
                                    die("Moving a quotation mark that has children");
                                }
                            }
                            else
                            {
                                $f[6]--;
                            }
                        }
                        ###!!! We currently assume that there are no enhanced dependencies.
                        $line = join("\t", @f);
                    }
                }
                last;
            }
            elsif($sentence[$i] =~ m/^\d+\t/)
            {
                last;
            }
        }
    }
    if($something_left)
    {
        # Flush the buffer. We will then add the current sentence to it, so if
        # there is a quotation mark in the next sentence, we will have where to
        # move it.
        foreach my $bsentence (@{$buffer})
        {
            print(join('', @{$bsentence}));
        }
        @{$buffer} = (\@sentence);
    }
}

#!/usr/bin/env perl
# Loops recursively over text files in a folder subtree, copies them to a new
# location, changes file names so they comply with our constraints.
# Copyright © 2026 Dan Zeman <zeman@ufal.mff.cuni.cz>
# License: GNU GPL

use utf8;
use open ':utf8';
binmode(STDIN, ':utf8');
binmode(STDOUT, ':utf8');
binmode(STDERR, ':utf8');
use Getopt::Long;
use File::Path qw(make_path);
use Encode;
use Carp;
# Dan's modules.
use ascii;

sub usage
{
    print STDERR ("This script recursively copies files, preserving the folder structure but renaming files where their current names violate constraints.\n\n");
    print STDERR ("Usage: $0 --srcdir PATH --tgtdir PATH\n");
    print STDERR ("       Takes all files from srcdir, creates corresponding files in tgtdir.\n");
}

my $srcdir;
my $tgtdir;
GetOptions
(
    'srcdir=s'   => \$srcdir,
    'tgtdir=s'   => \$tgtdir
);

if(!defined($srcdir))
{
    usage();
    confess("Missing --srcdir");
}
if(!defined($tgtdir))
{
    usage();
    confess("Missing --tgtdir");
}
if(! -d $srcdir)
{
    confess("Unknown path '$srcdir'");
}
if(! -d $tgtdir)
{
    # make_path() from File::Path is equivalent to make -p in bash.
    make_path($tgtdir) or confess("Cannot create path '$tgtdir': $!");
}
# Recursively traverse the folder and its subfolders.
# Convert files that are found there.
process_folder($srcdir, $tgtdir);



#------------------------------------------------------------------------------
# Traverses the folder and its subfolders recursively. Converts files that are
# found there.
#------------------------------------------------------------------------------
sub process_folder
{
    my $srcpath = shift;
    my $tgtpath = shift;
    opendir(DIR, $srcpath) or confess("Cannot read folder '$srcpath': $!");
    my @objects = readdir(DIR);
    closedir(DIR);
    my @folders = sort(grep {-d "$srcpath/$_" && !m/^\.\.?$/} (@objects));
    # What file type are we looking for? Currently hardcoded: .txt.
    my $srcextension = 'txt';
    my $tgtextension = 'txt';
    my @srcfiles = sort(grep {-f "$srcpath/$_" && m/\.$srcextension$/} (@objects));
    printf STDERR ("$srcpath: found %d subfolders and %d source files.\n", scalar(@folders), scalar(@srcfiles));
    foreach my $subfolder (@folders)
    {
        process_folder("$srcpath/$subfolder", "$tgtpath/$subfolder");
    }
    if(scalar(@srcfiles) > 0 && ! -d $tgtpath)
    {
        # make_path() from File::Path is equivalent to make -p in bash.
        make_path($tgtpath) or confess("Cannot create path '$tgtpath': $!");
    }
    foreach my $srcfile (@srcfiles)
    {
        # If the filename contains non-English letters, Perl sees them as individual
        # bytes and they are encoded in a system-specific encoding. Assume that if
        # path 'C:/' exists, we are on Windows and the encoding is CP1250. Otherwise
        # we are on Linux and the encoding is UTF-8. We need decoded filename when
        # printing information about it. But we need to keep the string of bytes
        # when asking the system to open the file.
        my $decoded_srcfile = $srcfile;
        if($decoded_srcfile !~ m/^[-A-Za-z0-9_\.]+$/)
        {
            if(-d 'C:/') # Windows
            {
                $decoded_srcfile = decode('cp1250', $decoded_srcfile);
            }
            else # Linux
            {
                $decoded_srcfile = decode('utf8', $decoded_srcfile);
            }
            # This string is damaged and "á" appears as "Ě<U+0081>".
            $decoded_srcfile =~ s/Pr..vo lidu/Právo_lidu/;
        }
        # Get rid of non-English letters in the filename.
        my $tgtfile = ascii::ascii($decoded_srcfile);
        $tgtfile =~ s/\.$srcextension$/.$tgtextension/;
        # Some names use CamelCase, some use underscores. Standardize to lowercase with underscores.
        $tgtfile =~ s/([a-z])([A-Z0-9])/${1}_${2}/g;
        $tgtfile = lc($tgtfile);
        # Make sure there are no spaces in the filename.
        $tgtfile =~ s/\s/_/g;
        $tgtfile =~ s/-/_/g;
        # Specific for the files from the 19th century: remove certain prefixes and suffixes.
        $tgtfile =~ s/^martin_(18[0-9][0-9])__/${1}_/;
        $tgtfile =~ s/1899_upr.*$/1899.$tgtextension/;
        $tgtfile =~ s/\+1//;
        # Avoid multiple adjacent underscores, as well as leading or trailing underscores.
        $tgtfile =~ s/_+/_/g;
        $tgtfile =~ s/^_// unless($tgtfile eq '_');
        $tgtfile =~ s/_$// unless($tgtfile eq '_');
        my $dsfpath = "$srcpath/$decoded_srcfile";
        my $sfpath = "$srcpath/$srcfile";
        my $tfpath = "$tgtpath/$tgtfile";
        print STDERR ("$dsfpath --> $tfpath\n");
        # We cannot use system("cp $sfpath $tfpath") because the system will not understand $sfpath with accented characters or spaces.
        open(my $IN, $sfpath) or confess("Cannot read '$sfpath': $!");
        open(my $OUT, ">$tfpath") or confess("Cannot write '$tfpath': $!");
        while(<$IN>)
        {
            print $OUT ($_);
        }
        close($IN);
        close($OUT);
    }
}

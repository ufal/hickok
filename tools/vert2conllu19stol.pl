#!/usr/bin/env perl
# Converts vertical format to CoNLL-U.
# Adapted from vert2conllu.pl, which was developed for Old Czech texts from
# Ústav pro jazyk český. This script targets a slightly different vertical
# input, used in the Czech National Corpus for 19th-century texts. I am keeping
# the two scripts separate because I do not want to hamper the Old Czech pipeline.
# Copyright © 2022, 2023, 2025 Dan Zeman <zeman@ufal.mff.cuni.cz>
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
use Lingua::Interset::Converter;
# Dan's modules.
use ascii;

sub usage
{
    print STDERR ("This script converts data from a vertical format (ÚČNK) to CoNLL-U.\n\n");
    print STDERR ("Usage: $0 --sourceid STRING < in.vert > out.conllu\n");
    print STDERR ("       --sourceid ... prefix for sentence ids so they are unique in broader context\n");
    print STDERR ("Or:    $0 --srcdir PATH --tgtdir PATH\n");
    print STDERR ("       Converts all .vert files from srcdir, creates corresponding .conllu files in tgtdir.\n");
    print STDERR ("       Uses file name as sourceid.\n");
}

# Source ID will be prepended to every sentence ID so that it stays unique if
# we concatenate CoNLL-U files from multiple sources. For example:
# 'bibledr-mt' = Bible drážďanská, Matoušovo evangelium
# 'bibleol-mt' = Bible olomoucká, Matoušovo evangelium
my $sourceid = '';
my $srcdir;
my $tgtdir;
my $fields = 'word,lemmatag,comment';
GetOptions
(
    'sourceid=s' => \$sourceid,
    'srcdir=s'   => \$srcdir,
    'tgtdir=s'   => \$tgtdir,
    'fields=s'   => \$fields
);

my $interset = new Lingua::Interset::Converter ('from' => 'cs::cnk', 'to' => 'mul::uposf');

# Depending on how the vertical was exported, there may be different positional attributes.
# Known attributes (vert fields):
my %known_vert_fields =
(
    'word'           => 1, # the "surface" word form (but for old Czech this typically is a result of transcription)
    'lc'             => 1, # lowercased word
    'lemma'          => 1, # lemma of the word (single form, modern Czech if possible)
    'lemmatag'       => 1, # lemma and Prague-style tag separated by a space (i.e., not by TAB)
    'amblemma'       => 1, # (lemma) ... list of possible (historical) lemmas according to morphological analysis
    'ambhlemma'      => 1, # (hl) ... hyperlemma from morphological analysis (still potentially ambiguous if the word form can belong to multiple lexemes)
    'tag'            => 1, # positional tag, Prague-style, but different from those used in PDT and in Old Czech data
    'ambprgtag'      => 1, # (tag) ... list of possible Prague-style morphological tags from morphological analysis
    'ambbrntag'      => 1, # (atag) ... list of possible Brno-style morphological tags from morphological analysis
    'comment'        => 1, # any token-level prose comment
    'corrected_from' => 1, # (emendation) ... emendation/emendace (oprava porušeného nebo nečitelného místa textu založená na využití odpovídajícího úseku v jiném textu daného díla)
    'translit'       => 1, # transliteration
    'language'       => 1, # "cizí jazyk" = foreign language (other than the main language of the text)
    'hlt'            => 1, # list of possible combinations hyperlemma + tag
    'hlat'           => 1, # list of possible combinations hyperlemma + atag
    'flags'          => 1, # one of the following values: damaged|restored|supplied|symbol or image|variant
    'inflclass'      => 1  # list of model lemmas representing the inflection types (paradigm)
);
# The following fields were present in the data for the pilot project in 2021 (Gospel of Matthew from Bible drážďanská and Bible olomoucká):
#     word,amblemma,ambhlemma,ambprgtag,ambbrntag,comment,corrected_from,translit,language,hlt,hlat
# The following fields were present in Hičkok vert_full in November 2023:
#     word,flags,corrected_from,language
# The following fields were present in Hičkok vert_etalon in February 2024 (the first line is what Ondra reported but the second line is what actually was in the data):
#     word,lc,amblemma,ambhlemma,ambprgtag,ambbrntag,comment,corrected_from,translit,language,hlt,hlat
#     word,amblemma,ambhlemma,ambprgtag,ambbrntag,comment,corrected_from,translit,language,hlt,hlat,inflclass
my @vert_fields = split(',', $fields);
if(scalar(@vert_fields) == 0)
{
    confess("No fields (positional attributes) defined for the input");
}
else
{
    foreach my $f (@vert_fields)
    {
        if(!exists($known_vert_fields{$f}))
        {
            confess("Unknown input field (positional attribute) '$f'");
        }
    }
}
# Hash all document ids so we can check they are unique.
my %docids;
if(defined($srcdir))
{
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
    process_folder($sourceid, $srcdir, $tgtdir);
}
else
{
    # Read STDIN as if it were one file, write to STDOUT.
    process_file($sourceid);
}



#------------------------------------------------------------------------------
# Traverses the folder and its subfolders recursively. Converts files that are
# found there.
#------------------------------------------------------------------------------
sub process_folder
{
    my $sourceid = shift;
    my $srcpath = shift;
    my $tgtpath = shift;
    opendir(DIR, $srcpath) or confess("Cannot read folder '$srcpath': $!");
    my @objects = readdir(DIR);
    closedir(DIR);
    my @folders = sort(grep {-d "$srcpath/$_" && !m/^\.\.?$/} (@objects));
    my @vertfiles = sort(grep {-f "$srcpath/$_" && m/\.vert$/} (@objects));
    printf STDERR ("$srcpath: found %d subfolders and %d vertical files.\n", scalar(@folders), scalar(@vertfiles));
    foreach my $subfolder (@folders)
    {
        my $folderid = $sourceid ne '' ? "$sourceid-$subfolder" : $subfolder;
        process_folder($folderid, "$srcpath/$subfolder", "$tgtpath/$subfolder");
    }
    if(scalar(@vertfiles) > 0 && ! -d $tgtpath)
    {
        # make_path() from File::Path is equivalent to make -p in bash.
        make_path($tgtpath) or confess("Cannot create path '$tgtpath': $!");
    }
    foreach my $vertfile (@vertfiles)
    {
        # If the filename contains non-English letters, Perl sees them as individual
        # bytes and they are encoded in a system-specific encoding. Assume that if
        # path 'C:/' exists, we are on Windows and the encoding is CP1250. Otherwise
        # we are on Linux and the encoding is UTF-8. We need decoded filename when
        # printing information about it. But we need to keep the string of bytes
        # when asking the system to open the file.
        my $decoded_vertfile = $vertfile;
        if($decoded_vertfile !~ m/^[-A-Za-z0-9_\.]+$/)
        {
            if(-d 'C:/') # Windows
            {
                $decoded_vertfile = decode('cp1250', $decoded_vertfile);
            }
            else # Linux
            {
                $decoded_vertfile = decode('utf8', $decoded_vertfile);
            }
        }
        # Get rid of non-English letters in the filename.
        my $conllufile = ascii::ascii($decoded_vertfile);
        $conllufile =~ s/\.vert$/.conllu/;
        # Some names use CamelCase, some use underscores. Standardize to lowercase with underscores.
        $conllufile =~ s/([a-z])([A-Z0-9])/${1}_${2}/g;
        $conllufile = lc($conllufile);
        # Make sure there are no spaces in the filename.
        $conllufile =~ s/\s/_/g;
        $conllufile =~ s/-/_/g;
        # Specific for the files from the 19th century: remove certain prefixes and suffixes.
        $conllufile =~ s/^martin_(18[0-9][0-9])__/${1}_/;
        $conllufile =~ s/1899_upr.*$/1899.conllu/;
        $conllufile =~ s/__.*$/.conllu/;
        my $dvfpath = "$srcpath/$decoded_vertfile";
        my $vfpath = "$srcpath/$vertfile";
        my $cfpath = "$tgtpath/$conllufile";
        my $fileid = $conllufile;
        $fileid =~ s/\.conllu$//;
        $fileid = $sourceid ne '' ? "$sourceid-$fileid" : $fileid;
        print STDERR ("$dvfpath --> $cfpath\n");
        process_file($fileid, $vfpath, $cfpath);
    }
}



#------------------------------------------------------------------------------
# Converts a vertical file to CoNLL-U.
#------------------------------------------------------------------------------
sub process_file
{
    my $sourceid = shift;
    my $srcfile = shift;
    my $tgtfile = shift;
    # Open the file or STDIN/STDOUT.
    local $IN;
    local $OUT;
    if(defined($srcfile))
    {
        open($IN, $srcfile) or confess("Cannot read '$srcfile': $!");
    }
    else
    {
        $IN = \*STDIN;
    }
    if(defined($tgtfile))
    {
        open($OUT, '>', $tgtfile) or confess("Cannot write '$tgtfile': $!");
    }
    else
    {
        $OUT = \*STDOUT;
    }
    my $docid;
    my $kniha;
    my $kapitola;
    my $odstavec = 0;
    my $nopar = 1; # to recognize text that occurs outside paragraph-level elements such as <nadpis> or <odstavec> (but maybe inside <verse>, which we consider smaller than sentence)
    local %sentids;
    local $isent = 1; # current sentence number inside the current paragraph (reset to 1 when new paragraph starts)
    local @sentence = ();
    local $sentid = $sourceid ne '' ? "$sourceid-$isent" : $isent;
    local $tokenid = 1;
    my $newfolio; # NewFolio=cislo:171r,sloupec:b
    my $bibleref; # Ref=MATT_9.1 do MISC
    my $ivers = 0; # if <vers> is not numbered in the source, we will use our own counter; if it is numbered in the source, we will project the number here
    my $verse; # same as $ivers when inside a verse; undef outside
    while(<$IN>)
    {
        s/\r?\n$//;
        # We could also employ a XML parser to parse the XML markup. But the markup
        # is relatively lightweight, so maybe we do not need it.
        if(m/<doc (.+)>/)
        {
            my $attributes = $1;
            flush_sentence();
            # Some documents have a long and unintuitive id, e.g., '1a7d2af9-23f4-493c-b2ca-2086be033765'.
            # Others do not have it. We will preferably use $sourceid, which may hold the file name.
            # Only if $sourceid is empty we will require that doc id exists and use it.
            $docid = $sourceid;
            my @attributes;
            while($attributes =~ s/^(\w+)="(.*?)"\s*//)
            {
                my $attribute = $1;
                my $value = $2;
                if($docid eq '' && $attribute eq 'id')
                {
                    $docid = $value;
                }
                else
                {
                    push(@attributes, [$attribute, $value]);
                }
            }
            if(!defined($docid))
            {
                print STDERR ("$_\n");
                confess("Unknown document id");
            }
            elsif(exists($docids{$docid}))
            {
                confess("Document id '$docid' is not unique");
            }
            else
            {
                $docids{$docid}++;
            }
            print $OUT ("\# newdoc id = $docid\n");
            foreach my $av (@attributes)
            {
                print $OUT ("\# doc $av->[0] = $av->[1]\n");
            }
        }
        # Folio může jít napříč knihami, kapitolami a verši, protože jde v podstatě o číslo stránky.
        # Nemůžeme se tedy spolehnout, že nám vyjde na začátek věty, a schováme si ho
        # jako poznámku k prvnímu tokenu na novém foliu.
        elsif(m/<folio cislo="(.*?)" sloupec="(.*?)">/)
        {
            $newfolio = "cislo:$1,sloupec:$2";
        }
        elsif(m/<(folio|strana|strana_edice|pg) (cislo|num)="?(.*?)"\/?>/) # v jednom případě úvodní uvozovka chyběla (chyba na vstupu)
        {
            $newfolio = "cislo:$2";
        }
        elsif(m/<\/?pg>/)
        {
            # Strana bez čísla. Asi nedělat nic. Stejně moc nerozumím tomu, jak jsou v textech z 19. století strany anotovány. Obvykle jsou na začátku nové strany tři řádky značek za sebou:
            # <pg>
            # <pg num="1"/>
            # </pg>
        }
        elsif(m/<\/?(f|k|o|v|n)>/)
        {
            # Vůbec nevím, co to znamená. Nedělat nic.
        }
        elsif(m/<e>.*<\/e>/)
        {
            # Zřejmě emendace předcházejícího slova, vyskytlo se např. tohle:
            # Fridrichovi	Fridrich N-MS3j----A-----	<done/>
            # <e>Frydrychowi</e>
            # Takže to asi můžu vyhodit, není to další token a nejsou u toho anotace.
        }
        elsif(m/<kniha zkratka="(.+)">/)
        {
            my $nova_kniha = $1;
            # Je to opravdu nová kniha, nebo jen zopakované číslo stávající
            # knihy na začátku dalšího folia?
            unless($nova_kniha eq $kniha)
            {
                $kniha = $nova_kniha;
                flush_sentence();
                print $OUT ("\# kniha $kniha\n");
                $odstavec = 0;
                $isent = 1;
                $sentid = create_sentence_id($sourceid, $kniha);
            }
        }
        elsif(m/<kapitola cislo="(.+)">/)
        {
            my $nova_kapitola = $1;
            # Je to opravdu nová kapitola, nebo jen zopakované číslo stávající
            # kapitoly na začátku dalšího folia?
            unless($nova_kapitola eq $kapitola)
            {
                $kapitola = $nova_kapitola;
                flush_sentence();
                print $OUT ("\# kapitola $kapitola\n");
                $odstavec = 0;
                $isent = 1;
                $sentid = create_sentence_id($sourceid, $kniha, $kapitola);
            }
        }
        elsif(m/<(titul|nadpis|podnadpis|predmluva|incipit|explicit|impresum|adresat|poznamka)>/)
        {
            flush_sentence();
            print $OUT ("\# $1\n");
            $odstavec++;
            $isent = 1;
            $sentid = create_sentence_id($sourceid, $kniha, $kapitola, $odstavec);
            print $OUT ("\# newpar id = $sentid\n");
            $nopar = 0;
        }
        elsif(m/<(titul|nadpis|podnadpis|predmluva|incipit|explicit|impresum|adresat|poznamka) continued="true">/)
        {
            # Nedělat nic. Zejména ne flush_sentence()!
            $nopar = 0;
        }
        elsif(m/<(odstavec|p)( typ="rejstřík")?>/)
        {
            flush_sentence();
            $odstavec++;
            $isent = 1;
            $sentid = create_sentence_id($sourceid, $kniha, $kapitola, $odstavec);
            print $OUT ("\# newpar id = $sentid\n");
            $nopar = 0;
        }
        elsif(m/<odstavec( typ="rejstřík")? continued="true">/)
        {
            # Nedělat nic. Zejména ne flush_sentence()!
            $nopar = 0;
        }
        # V textech z 19. století bývají vyznačeny hranice vět. Ve staročeských
        # textech nebyly, takže jsme celý obsah odstavce zpracovávali jako jedinou větu.
        elsif(m/<s>/)
        {
            # Na začátku věty nedělat nic. Pro první větu už je číslo nastavené
            # na 1 a odpovídající sent_id je také připravené. Na konci věty ale
            # budeme muset číslo zvýšit o 1.
        }
        # Konec věty.
        elsif(m/<\/s>/)
        {
            flush_sentence();
            $isent++;
            $sentid = create_sentence_id($sourceid, $kniha, $kapitola, $odstavec, $isent);
        }
        # Ve staročeských textech jsme s veršem zacházeli jako s jednotkou přibližně na úrovni věty.
        # V textech z 19. století ale máme prvek <s>, který označuje větu.
        elsif(m/<vers cislo="([^"]+)">/) # "
        {
            my $vers = $1;
            $ivers = $vers;
            $verse = $ivers;
            # Problém: Pokud skončí folio, tak kvůli němu skončí i odstavec a
            # vers. Jenže na následujícím foliu může tento vers (a odstavec)
            # pokračovat.
            # <vers cislo="24">
            # ...
            # </vers>
            # </odstavec>
            # </folio>
            # <folio cislo="541v" sloupec="a">
            # <odstavec continued="true">
            # <vers cislo="24">
        }
        elsif(m/<vers( cislo="[^"]+")? continued="true">/) # "
        {
            # Pouze znovu aktivovat již známé číslo verše (ať už teď bylo zopakováno jako atribut, nebo ne).
            $verse = $ivers;
        }
        elsif(m/<vers>/)
        {
            # Pokud není u verše uvedeno číslo, použijeme naše vlastní počítadlo.
            $ivers++;
            $verse = $ivers;
        }
        # U těchto elementů si nejsem jist, jak zapadají do struktury dokumentu a co bych si s nimi měl počít.
        # Zde pobereme jak začátek, tak konec elementu.
        elsif(m/<\/?(zive_zahlavi|pripisek|obrazek)>/)
        {
            # Nedělat nic.
        }
        # Konec verše.
        elsif(m/<\/vers>/)
        {
            $verse = undef; # but keep the last number in $ivers
            $bibleref = undef;
        }
        # Konec odstavce nebo jiného elementu na úrovni odstavce.
        elsif(m/<\/(titul|nadpis|podnadpis|predmluva|odstavec|p|explicit|incipit|impresum|adresat|poznamka)>/)
        {
            # We do not want to flush sentence at the paragraph end tag because
            # this may not be the real end of the paragraph. The tag may be here
            # because of the end of folio/page, and the paragraph may resume on
            # the next page with <odstavec continued="true">. On the other hand,
            # we want to set $nopar to true so that we can recognize text that
            # is not enclosed in a paragraph (and treat it as a new paragraph).
            # This happens in documents where <podnadpis> is followed by text
            # that is organized in <vers>-es but not in <odstavec>-es.
            $nopar = 1;
        }
        # Konec jiného elementu.
        elsif(m/<\/(doc|kniha|kapitola|folio|strana|strana_edice)>/)
        {
            # Nedělat nic.
        }
        elsif(m/(<g \/>|<g><\/g>)/)
        {
            # A line with this element means that there is no space between the
            # previous and the next token.
            if(scalar(@sentence) == 0)
            {
                # Unfortunately, there are documents that have <g /> at beginnings of sentences,
                # for example between </podnadpis> and <odstavec>, as on the line 75982 of 13_15_stol/286_LekJadroBrn.vert.
                # So we cannot crash when we encounter it, but we also cannot do anything meaningful.
                #confess("<g /> at the beginning of a sentence");
            }
            else
            {
                if($sentence[-1][9] eq '_')
                {
                    $sentence[-1][9] = 'SpaceAfter=No';
                }
                else
                {
                    $sentence[-1][9] .= '|SpaceAfter=No';
                }
            }
        }
        # V textech z 19. století se u poškozených částí textu trojtečky uzavírají do skobiček, ale neměli bychom si je plést s markupem XML.
        elsif(m/^<.*>/ && !m/^<\.\.\.>/)
        {
            confess("Unexpected XML markup '$_'");
        }
        else
        {
            # If we encounter text outside paragraph-level elements, treat it
            # as a new paragraph.
            if($nopar)
            {
                flush_sentence();
                $odstavec++;
                $isent = 1;
                $sentid = create_sentence_id($sourceid, $kniha, $kapitola, $odstavec, $isent);
                print $OUT ("\# newpar id = $sentid\n");
                $nopar = 0;
            }
            my @f = process_token($_, \@vert_fields, $tokenid, $newfolio, $verse, $bibleref);
            push(@sentence, \@f);
            $tokenid++;
            $newfolio = undef;
        }
    }
    # Normálně vypisujeme nasbíraný text ("větu") na začátku následujícího verše
    # místo na konci předchozího, a to kvůli případům, kdy je verš a odstavec
    # rozdělen mezi několik folií. To ale znamená, že na konci dokumentu může být
    # nějaký text nasbírán a dosud nevypsán.
    flush_sentence();
    if(defined($srcfile))
    {
        close($IN);
    }
    if(defined($tgtfile))
    {
        close($OUT);
    }
}



#------------------------------------------------------------------------------
# Takes one tab-separated token line from the vertical file, along with labels
# of the columns (fields). Returns the list of corresponding 10 CoNLL-U columns
# (fields).
#------------------------------------------------------------------------------
sub process_token
{
    my $vert_token_line = shift;
    my $vert_fields = shift; # array ref
    my $tokenid = shift;
    my $newfolio = shift;
    my $verse = shift; # verse number, if the token is part of a verse
    my $bibleref = shift;
    my $form = '_';
    my $lemma = '_';
    my $upos = '_';
    my $xpos = '_';
    my $feats = '_';
    my $head = '_';
    my $deprel = '_';
    my $deps = '_';
    my @misc;
    # Decode XML entities.
    $vert_token_line =~ s/&lt;/</g;
    $vert_token_line =~ s/&gt;/>/g;
    $vert_token_line =~ s/&amp;/&/g;
    my @f = split(/\t/, $vert_token_line);
    my @vert_fields = @{$vert_fields};
    for(my $i = 0; $i <= $#f; $i++)
    {
        if(!$vert_fields[$i])
        {
            confess("Unexpected field index $i");
        }
        elsif($vert_fields[$i] eq 'word')
        {
            $form = $f[$i];
        }
        elsif($vert_fields[$i] eq 'lc')
        {
            # Do nothing. We can always get lc from word if we need it.
        }
        elsif($vert_fields[$i] eq 'lemma')
        {
            $lemma = $f[$i];
        }
        elsif($vert_fields[$i] eq 'lemmatag')
        {
            ($lemma, $xpos) = split(/ /, $f[$i]);
        }
        elsif($vert_fields[$i] eq 'amblemma')
        {
            add_misc_attribute(\@misc, 'AmbLemma', $f[$i]);
        }
        elsif($vert_fields[$i] eq 'ambhlemma')
        {
            if($f[$i] ne '' && $f[$i] !~ m/\|/)
            {
                $lemma = $f[$i];
            }
            add_misc_attribute(\@misc, 'AmbHlemma', $f[$i]);
        }
        elsif($vert_fields[$i] eq 'tag')
        {
            $xpos = $f[$i];
        }
        elsif($vert_fields[$i] eq 'ambprgtag')
        {
            if($f[$i] ne '' && $f[$i] !~ m/\|/)
            {
                $xpos = $f[$i];
            }
            add_misc_attribute(\@misc, 'AmbPrgTag', $f[$i]);
        }
        elsif($vert_fields[$i] eq 'ambbrntag')
        {
            add_misc_attribute(\@misc, 'AmbBrnTag', $f[$i]);
        }
        elsif($vert_fields[$i] eq 'comment')
        {
            unless($f[$i] eq '<done/>')
            {
                $f[$i] = 'ToDo' if($f[$i] eq '<todo/>');
                add_misc_attribute(\@misc, 'Comment', $f[$i]);
            }
        }
        elsif($vert_fields[$i] eq 'corrected_from')
        {
            add_misc_attribute(\@misc, 'CorrectedFrom', $f[$i]);
        }
        elsif($vert_fields[$i] eq 'translit')
        {
            add_misc_attribute(\@misc, 'Translit', $f[$i]);
        }
        elsif($vert_fields[$i] eq 'language')
        {
            # Běžně, tj. pro češtinu, je tento sloupec prázdný.
            if($f[$i] =~ m/^(cizí jazyk|foreign)$/)
            {
                $feats = 'Foreign=Yes';
            }
        }
        elsif($vert_fields[$i] eq 'hlt')
        {
            add_misc_attribute(\@misc, 'AmbHlemmaPrgTag', $f[$i]);
        }
        elsif($vert_fields[$i] eq 'hlat')
        {
            add_misc_attribute(\@misc, 'AmbHlemmaBrnTag', $f[$i]);
        }
        elsif($vert_fields[$i] eq 'inflclass')
        {
            add_misc_attribute(\@misc, 'InflClass', $f[$i]);
        }
        elsif($vert_fields[$i] eq 'flags')
        {
            # Observed values:
            # damaged
            # restored
            # supplied
            # symbol or image
            # variant
            if($f[$i] ne '' && $f[$i] !~ m/^(damaged|restored|supplied|symbol or image|variant)$/)
            {
                confess("Unknown flag '$f[$i]'");
            }
            add_misc_attribute(\@misc, 'Flags', $f[$i]);
        }
        else
        {
            confess("Unknown field '$vert_fields[$i]'");
        }
    }
    if(defined($verse))
    {
        add_misc_attribute(\@misc, 'Verse', $verse);
    }
    if(defined($bibleref))
    {
        add_misc_attribute(\@misc, 'Ref', $bibleref);
    }
    if(defined($newfolio))
    {
        add_misc_attribute(\@misc, 'NewFolio', $newfolio);
    }
    if(defined($xpos) && $xpos ne '_')
    {
        ($upos, $feats) = split(/\t/, $interset->convert($xpos));
    }
    my $misc = scalar(@misc) > 0 ? join('|', @misc) : '_';
    @f = ($tokenid, $form, $lemma, $upos, $xpos, $feats, $head, $deprel, $deps, $misc);
    return @f;
}



#------------------------------------------------------------------------------
# Constructs sentence id depending on the known ids of the superordinate
# elements (kniha=book, kapitola=chapter, verš=verse).
#------------------------------------------------------------------------------
sub create_sentence_id
{
    my $sourceid = shift;
    my $kniha = shift;
    my $kapitola = shift;
    my $odstavec = shift;
    my $veta = shift;
    my @elements = ();
    push(@elements, $sourceid) unless($sourceid eq '');
    push(@elements, "kniha-$kniha") unless($kniha eq '');
    push(@elements, "kapitola-$kapitola") unless($kapitola eq '');
    push(@elements, "p$odstavec") unless($odstavec eq '');
    push(@elements, "s$veta") unless($veta eq '');
    if(scalar(@elements) == 0)
    {
        confess("Not enough information for sentence id");
    }
    return join('-', @elements);
}



#------------------------------------------------------------------------------
# Flushes the currently collected tokens as one sentence and resets the global
# variables so that a new sentence can be collected.
#------------------------------------------------------------------------------
sub flush_sentence
{
    # We access the following variables that have been declared local by the
    # caller (process_file()):
    # $OUT, @sentence, %sentids, $sentid, $isent, $tokenid
    if(scalar(@sentence) > 0)
    {
        # Unfortunately there are documents (e.g., 031_HradSat.vert) where
        # verse numbers are not unique because they restart at 1 after a
        # subheading (podnadpis) as if a new book or chapter started, but there
        # are no formal book or chapter elements. Therefore our sentence ids
        # are not unique either. We must make them unique artificially by adding
        # a letter here.
        if(exists($sentids{$sentid}))
        {
            foreach my $letter (split(//, 'abcdefghijklmnopqrstuvwxyz'))
            {
                if(!exists($sentids{$sentid.$letter}))
                {
                    $sentid .= $letter;
                    last;
                }
            }
            if(exists($sentids{$sentid}))
            {
                confess("Sentence id '$sentid' is not unique");
            }
        }
        $sentids{$sentid}++;
        print $OUT ("\# sent_id = $sentid\n");
        my $text = '';
        for(my $i = 0; $i <= $#sentence; $i++)
        {
            $text .= $sentence[$i][1];
            unless($i == $#sentence || $sentence[$i][9] ne '_' && grep {m/^SpaceAfter=No$/} (split(/\|/, $sentence[$i][9])))
            {
                $text .= ' ';
            }
        }
        print $OUT ("\# text = $text\n");
        foreach my $token (@sentence)
        {
            print $OUT (join("\t", @{$token}), "\n");
        }
        print $OUT ("\n");
        $isent++;
        @sentence = ();
        $sentid = $sourceid ne '' ? "$sourceid-$isent" : $isent;
        $tokenid = 1;
    }
}



#------------------------------------------------------------------------------
# Takes care of escaping special characters and adding an Attribute=Value pair
# to the MISC list.
#------------------------------------------------------------------------------
sub add_misc_attribute
{
    my $misc = shift; # array ref
    my $attribute = shift; # assumed to not need escaping
    my $value = shift; # will be escaped
    $value =~ s/^\s+//;
    $value =~ s/\s+$//;
    $value =~ s/\s+/ /g;
    $value =~ s/\\/\\\\/g;
    $value =~ s/\|/\\p/g;
    if($value ne '')
    {
        push(@{$misc}, "$attribute=$value");
    }
}

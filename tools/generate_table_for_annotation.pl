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
# Prozatím vyřazuju LEMMA1300, protože bylo k dispozici jen pro hrstku slov a v kontextu projektu Hičkok ho možná ani nechceme.
# Také skrývám XPOS a FEATS, protože obojí budeme po anotaci automaticky odvozovat z vyplněných hodnot rysů.
# RESEGMENT: V tomto sloupci bude neprázdná hodnota v případě, že je potřeba opravit segmentaci textu na věty. Povolené hodnoty:
#     "spojit" ... Má smysl pouze u prvního tokenu existující věty a říká, že tato věta se má spojit s větou předcházející. (Tj. ta hodnota se nemůže objevit v první větě dokumentu a asi ani odstavce.)
#     "rozdělit" ... Má smysl pouze u jiného než prvního tokenu existující věty a říká, že tato věta se má rozdělit a toto má být první token nové věty.
#     Jednu větu lze rozdělit i na více než dva kusy. Lze také začátek věty spojit s předchozí větou, ale později větu rozdělit.
# RETOKENIZE: V tomto sloupci bude neprázdná hodnota v případě, že je potřeba opravit tokenizaci (resp. segmentaci na slova). Povolené hodnoty:
#     "spojit" ... Tento token má být součástí předcházejícího tokenu. Pokud je předcházející token v jiné větě, je třeba současně signalizovat i spojení vět (viz výše).
#         Správná morfologická anotace je uvedena u předcházejícího tokenu (pokud nebyl předcházející token současně dělen, viz níže).
#     "rozdělit" ... Tento token má být rozdělen na dva nebo více nových tokenů. Tato hodnota sama neříká, jak a na kolik dílů se má token rozdělit, ani jaká je morfologická anotace jednotlivých dílů.
#         Pokud je alespoň na jedné straně od nové hranice tokenů interpunkční znak, výsledkem dělení jsou dva podřetězce původního tokenu, přičemž u toho prvního přibude v MISC atribut SpaceAfter=No. (Zařídím později skriptem.)
#         Pokud je nová hranice vedena mezi dvěma písmeny, bude výsledkem "multiword token" (MWT, agregát). Můj skript vloží nový řádek pro rozsah MWT, jednotlivé části pak nemusí být nutně podřetězce
#         povrchového tokenu, např. "bylas" se rozloží na "byla" a "jsi".
#     "obojí" ... Token se má rozdělit a jeho první část se má spojit s předcházejícím tokenem. Jde o komplexní (a snad nepravděpodobnou) situaci, která se bude muset dořešit ručně.
# SUBTOKENS: Vyplňuje se právě tehdy, když ve sloupci RETOKENIZE je hodnota "rozdělit" nebo "obojí". Obsahuje hodnoty pole FORM nových tokenů, oddělené mezerou (např. pro "bylas" zde bude "byla jsi").
#    Ani toto není úplná informace, protože nemáme prostor na oddělenou morfologickou anotaci každého nového tokenu zvlášť. Pokud se ukáže, že jde o častý jev, vymyslíme dodatečně, jak ho řešit
#    systematicky; pokud to bude jen pár případů, tak je vyřešíme ad hoc při přebírání anotací.
my @names = ('LINENO', 'SENTENCE', 'RESEGMENT', 'RETOKENIZE', 'SUBTOKENS', 'ID', 'FORM', 'RETRO', 'LEMMA', 'UPOS', @fnames, 'HEAD', 'DEPREL', 'DEPS', 'MISC');
my %conllu_name_index = ('ID' => 0, 'FORM' => 1, 'LEMMA' => 2, 'UPOS' => 3, 'XPOS' => 4, 'FEATS' => 5, 'HEAD' => 6, 'DEPREL' => 7, 'DEPS' => 8, 'MISC' => 9);

# Vypsat záhlaví tabulky.
print(join("\t", @names)."\n");
my %ignored_features;
my %requested_features;
my %observed_features;
my $sid = '';
my $lineno = 0;
while(<>)
{
    $lineno++;
    my $line = $_;
    $line =~ s/\r?\n$//;
    my $sentence = $line;
    my @fields = ();
    my %features = ();
    if($line =~ m/^\#\s*sent_id\s*=\s*(.+)$/)
    {
        $sid = $1;
        # Anotátoři by rádi viděli u každého tokenu jen konec id věty (kde je číslo odstavce a věty v rámci dokumentu).
        $sid =~ s/^.*(p[0-9][0-9A-B]*-s[0-9][0-9A-B]*)$/$1/;
    }
    elsif($line =~ m/^\d/)
    {
        # Jirka si vyžádal ještě jeden prázdný řádek mezi komentáři a tokeny. Úplně prázdný tedy nebude, protože ho potřebuju pak snadno poznat.
        if($line =~ m/^1\t/)
        {
            my $extra = '###!!! EXTRA LINE';
            my @output_fields = map {get_column_value($_, $lineno, $extra)} (@names);
            $_ = join("\t", @output_fields)."\n";
            print;
            $lineno++;
        }
        $sentence = $sid;
        @fields = split(/\t/, $line);
        my @features = split(/\|/, $fields[5]);
        foreach my $fpair (@features)
        {
            if($fpair =~ m/^(.+?)=(.+)$/)
            {
                $features{$1} = $2;
            }
        }
    }
    my @output_fields = map {get_column_value($_, $lineno, $sentence, \%features, @fields)} (@names);
    # Sanity check: Are there any features that we do not export?
    foreach my $f (keys(%features))
    {
        $ignored_features{$f}++;
    }
    $_ = join("\t", @output_fields)."\n";
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
    my $lineno = shift; # číslo aktuálně zpracovávaného řádku
    my $sentence = shift; # řádek s větným komentářem nebo prázdný řádek nebo (na úrovni tokenu) poslední spatřené sent_id
    my $features = shift; # hash; použité rysy z něj budeme odstraňovat, aby se na konci dalo zjistit, zda jsme na nějaké zapomněli
    my @conllu_fields = @_;
    # Výjimka se zvláštním zpracováním pro # text, kde se vlastní text věty uřízne a dá se do sloupce FORM.
    if($name =~ m/^(SENTENCE|FORM)$/ && $sentence =~ m/^(\#\s*text\s*=)\s*(.+)$/)
    {
        $sentence = $1;
        $conllu_fields[1] = $2;
    }
    # A teď vrátit žádaný řetězec.
    if($name eq 'LINENO')
    {
        return $lineno;
    }
    elsif($name eq 'SENTENCE')
    {
        # Sem patří všechny řádky, které nejsou rozsekané do sloupců, tedy komentáře před větou a prázdné řádky za větou.
        return $sentence;
    }
    elsif($name =~ m/^(RESEGMENT|RETOKENIZE|SUBTOKENS)$/)
    {
        return '';
    }
    # Standardní pole formátu CoNLL-U prostě zkopírovat.
    elsif($name =~ m/^(ID|FORM|LEMMA|UPOS|XPOS|FEATS|HEAD|DEPREL|DEPS|MISC)$/)
    {
        my $value = $conllu_fields[$conllu_name_index{$name}];
        if($name eq 'ID' && $value =~ m/[-\.]/ ||
           $name =~ m/^(FORM|LEMMA)$/ && $conllu_fields[3] =~ m/^(NUM|PUNCT)$/ ||
           $name eq 'XPOS')
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
        if($conllu_fields[3] =~ m/^(NUM|PUNCT)$/)
        {
            $lemma1300 =~ s/"/""/g; # "
            $lemma1300 = '"'.$lemma1300.'"';
        }
        return $lemma1300;
    }
    # Neznámé názvy polí považujeme za jména rysů. Jejich seznam neznáme předem, různé soubory můžou obsahovat různé rysy.
    else
    {
        # Rysy zobrazovat pouze na řádcích, které odpovídají tokenům. Na řádcích s větnými komentáři a na prázdných řádcích za větou vracet prázdné řetězce, nikoli podtržítka.
        if(scalar(@conllu_fields) > 0)
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
        else
        {
            return '';
        }
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

#!/usr/bin/env perl
# Opraví po UDPipu některé drobnosti v tokenizaci. Tohle můžeme udělat až poté,
# co jsme původní soubor slili s výstupem UDPipu, protože se tím opět naruší
# synchronizace obou souborů!
# Copyright © 2022 Dan Zeman <zeman@ufal.mff.cuni.cz>
# License: GNU GPL

use utf8;
use open ':utf8';
binmode(STDIN, ':utf8');
binmode(STDOUT, ':utf8');
binmode(STDERR, ':utf8');

my @sentence;
while(<>)
{
    s/\r?\n$//;
    push(@sentence, $_);
    if(m/^\s*$/)
    {
        process_sentence(@sentence);
        @sentence = ();
    }
}



#------------------------------------------------------------------------------
# Zpracuje větu. V případě potřeby upraví její tokenizaci a segmentaci
# víceslovných tokenů. Upravenou větu pošle na standardní výstup.
#------------------------------------------------------------------------------
sub process_sentence
{
    my @sentence = @_;
    for(my $i = 0; $i <= $#sentence; $i++)
    {
        # Zrušit mezeru za počáteční uvozovkou nebo před koncovou uvozovkou.
        if($sentence[$i] =~ m/^\#\s*text\s*=\s*.+$/)
        {
            $sentence[$i] =~ s/„\s+/„/g;
            $sentence[$i] =~ s/\s+“/“/g;
        }
        elsif($sentence[$i] =~ m/\d+\t„\t/)
        {
            my @f = split(/\t/, $sentence[$i]);
            my @misc = $f[9] eq '_' ? () : split(/\|/, $f[9]);
            unless(grep {m/^SpaceAfter=No$/} (@misc))
            {
                push(@misc, 'SpaceAfter=No');
                $f[9] = join('|', @misc);
                $sentence[$i] = join("\t", @f);
            }
        }
        elsif($sentence[$i] =~ m/\d+\t“\t/)
        {
            my @f = split(/\t/, $sentence[$i-1]);
            my @misc = $f[9] eq '_' ? () : split(/\|/, $f[9]);
            unless(grep {m/^SpaceAfter=No$/} (@misc))
            {
                push(@misc, 'SpaceAfter=No');
                $f[9] = join('|', @misc);
                $sentence[$i-1] = join("\t", @f);
            }
        }
    }
    # Při druhém průchodu rozdělit "abyšte" na "aby" a "byšte".
    # Postupovat odzadu kvůli nutnému přečíslování uzlů.
    # Další tokeny, které bude nutné rozdělit:
    # Příklonka -s (jsi) může být přilepená k různým slovním druhům:
    # pročs, dvěs, žes, lis, všaks, zjevils, nebos, cos, ještos, pěts, čemus, rovnys, tys
    for(my $i = $#sentence; $i >= 0; $i--)
    {
        # Kdyby se náhodou stalo, že nějaký výskyt už rozdělený je, tak ho zde
        # přeskočíme, protože tvar "abyšte" už bude mít před sebou intervalové ID.
        my $rec = 'na|ve|za'; # nač, več, zač
        my $ren = 'mimo|na|pro|př[eě]de|ve'; # mimoň, naň, proň...
        my $res = 'co|čemu|dvě|ješto|li|nebo|pět|proč|rovny|ty|však|zj[eě]vil|že'; # cos, čemus, dvěs...
        my $ret = 'bude|co|což|druhé|já|jakož|jeden|jediný|jenž|ješto|kde|kterak|ktož|lehčějie|lépe|li|my|nečiním|nenie|neumřěla|odpuščeni|on|otplatí|otpuštěny|pójdem|pravi|sbéřem|slepí|spí|ten|toho|toto|tuto|viem|vstal|všecko|zajisté|zhynem|že'; # nechať, jáť, neumřělať...
        if($sentence[$i] =~ m/^(\d+)\t(abyšte|($rec)č|($ren)ň|($res)s|($ret)ť)\t/i)
        {
            my $id = $1;
            # Budeme přidávat uzel. Všechna ID od následujícího slova do konce
            # věty musí být o jedničku vyšší. Kvůli HEAD ale musíme projít celou
            # větu.
            for(my $j = 0; $j <= $#sentence; $j++)
            {
                if($sentence[$j] =~ m/^\d/)
                {
                    my @f = split(/\t/, $sentence[$j]);
                    # Upravit ID.
                    if($f[0] =~ m/^\d+$/ && $f[0] > $id)
                    {
                        $f[0]++;
                    }
                    elsif($f[0] =~ m/^(\d+)-(\d+)$/ && $1 > $id)
                    {
                        $f[0] = ($1+1).'-'.($2+1);
                    }
                    ###!!! V našich datech by neměly být prázdné uzly...
                    elsif($f[0] =~ m/^(\d+)\.(\d+)$/ && $1 >= $id)
                    {
                        $f[0] = ($1+1).'.'.($2+1);
                    }
                    # Upravit HEAD.
                    if($f[6] =~ m/^\d+$/ && $f[6] > $id)
                    {
                        $f[6]++;
                    }
                    ###!!! V našich datech by neměly být žádné obohacené DEPS,
                    ###!!! takže se s nimi nepokoušíme nic dělat.
                    $sentence[$j] = join("\t", @f);
                }
            }
            # Potřebujeme tři řádky místo původního jednoho.
            splice(@sentence, $i+1, 0, ($sentence[$i], $sentence[$i]));
            # Z aktuálního řádku se stane intervalový úvod víceslovného tokenu.
            my @f = split(/\t/, $sentence[$i]);
            my $id = $f[0];
            my $lemma = $f[2];
            $f[0] = $f[0].'-'.($f[0]+1);
            foreach my $k (2..8)
            {
                $f[$k] = '_';
            }
            $sentence[$i] = join("\t", @f);
            if($f[1] =~ m/^abyšte$/i)
            {
                $sentence[$i+1] = set_line($sentence[$i+1], 0, ['šte$', ''], 'aby', 'SCONJ', 'J,-------------', '_', undef, 'mark', undef, 'aby');
                $sentence[$i+2] = set_line($sentence[$i+2], 1, ['^a', ''], 'být', 'AUX', 'Vc-P---2-------', 'Aspect=Imp|Mood=Cnd|Number=Plur|Person=2|VerbForm=Fin', undef, 'aux', undef, 'býti');
            }
            elsif($f[1] =~ m/č$/i)
            {
                # Uvnitř agregátu musely být neslabičné předložky vokalizované, ale v rozepsaném tvaru by vokalizované nebyly ("več" = "v co", nikoli "ve co").
                $lemma =~ s/e?č$//i;
                $sentence[$i+1] = set_line($sentence[$i+1], 0, ['e?č$', ''], $lemma, 'ADP', 'RR--4----------', 'AdpType=Prep|Case=Acc', $id+1, 'case', undef, $lemma);
                $sentence[$i+2] = set_line($sentence[$i+2], 1, 'co', 'co', 'PRON', 'PQ--4----------', 'Animacy=Inan|Case=Acc|PronType=Int,Rel', undef, 'obl', undef, 'co');
            }
            elsif($f[1] =~ m/ň$/i)
            {
                # Uvnitř agregátu musely být neslabičné předložky vokalizované, ale v rozepsaném tvaru by vokalizované nebyly ("več" = "v co", nikoli "ve co").
                $lemma =~ s/e?ň$//i;
                $lemma =~ s/přě/pře/i;
                $sentence[$i+1] = set_line($sentence[$i+1], 0, ['e?ň$', ''], $lemma, 'ADP', 'RR--4----------', 'AdpType=Prep|Case=Acc', $id+1, 'case', undef, $lemma);
                $sentence[$i+2] = set_line($sentence[$i+2], 1, 'něj', 'on', 'PRON', 'P5ZS4--3-------', 'Case=Acc|Gender=Masc,Neut|Number=Sing|Person=3|PrepCase=Pre|PronType=Prs', undef, 'obl', undef, 'on');
            }
            # Prý existovalo i "ktoj" a "coj" ("Ktoj přišel?" = "Kto jest přišel?"; "Coj slyšel Petr?" = "Co jest slyšel Petr?"), ale v našich datech se to neobjevuje.
            elsif($f[1] =~ m/s$/i)
            {
                $lemma =~ s/s$//i;
                if($f[1] =~ m/^cos$/i)
                {
                    $sentence[$i+1] = set_line($sentence[$i+1], 0, ['s$', ''], 'co', 'PRON', 'PQ--4----------', 'Animacy=Inan|Case=Acc|PronType=Int,Rel', undef, 'obj', undef, 'co');
                }
                elsif($f[1] =~ m/^čemus$/i)
                {
                    $sentence[$i+1] = set_line($sentence[$i+1], 0, ['s$', ''], 'co', 'PRON', 'PQ--3----------', 'Animacy=Inan|Case=Dat|PronType=Int,Rel', undef, 'obl', undef, 'co');
                }
                elsif($f[1] =~ m/^dvěs$/i)
                {
                    $sentence[$i+1] = set_line($sentence[$i+1], 0, ['s$', ''], 'dva', 'NUM', 'ClHD4----------', 'Case=Acc|Gender=Fem,Neut|Number=Dual|NumForm=Word|NumType=Card|NumValue=1,2,3', undef, 'nummod', undef, 'dva');
                }
                elsif($f[1] =~ m/^lis$/i)
                {
                    $sentence[$i+1] = set_line($sentence[$i+1], 0, ['s$', ''], 'li', 'PART', 'TT-------------', '_', undef, 'mark', undef, 'li');
                }
                elsif($f[1] =~ m/^nebos$/i)
                {
                    $sentence[$i+1] = set_line($sentence[$i+1], 0, ['s$', ''], 'nebo', 'CCONJ', 'J^-------------', '_', undef, 'cc', undef, 'nebo');
                }
                elsif($f[1] =~ m/^pěts$/i)
                {
                    $sentence[$i+1] = set_line($sentence[$i+1], 0, ['s$', ''], 'pět', 'NUM', 'Cn-S4----------', 'Case=Acc|Number=Sing|NumForm=Word|NumType=Card', undef, 'nummod:gov', undef, 'pět');
                }
                elsif($f[1] =~ m/^tys$/i)
                {
                    $sentence[$i+1] = set_line($sentence[$i+1], 0, ['s$', ''], 'ty', 'PRON', 'PP-S1--2-------', 'Case=Nom|Number=Sing|Person=2|PronType=Prs', undef, 'nsubj', undef, 'ty');
                }
                elsif($f[1] =~ m/^všaks$/i)
                {
                    $sentence[$i+1] = set_line($sentence[$i+1], 0, ['s$', ''], 'však', 'CCONJ', 'J^-------------', '_', undef, 'cc', undef, 'však');
                }
                elsif($f[1] =~ m/^žes$/i)
                {
                    $sentence[$i+1] = set_line($sentence[$i+1], 0, ['s$', ''], 'že', 'SCONJ', 'J,-------------', '_', undef, 'mark', undef, 'že');
                }
                else
                {
                    $sentence[$i+1] = set_line($sentence[$i+1], 0, ['s$', ''], $lemma);
                }
                $sentence[$i+2] = set_line($sentence[$i+2], 1, 'jsi', 'být', 'AUX', 'VB-S---2P-AA---', 'Aspect=Imp|Mood=Ind|Number=Sing|Person=2|Polarity=Pos|Tense=Pres|VerbForm=Fin|Voice=Act', undef, 'aux', undef, 'býti');
            }
            else # něco + ť
            {
                $lemma =~ s/ť$//i;
                $sentence[$i+1] = set_line($sentence[$i+1], 0, ['ť$', ''], $lemma, undef, undef, undef, undef, undef, undef, $lemma);
                $sentence[$i+2] = set_line($sentence[$i+2], 1, 'ť', 'ť', 'PART', 'TT-------------', '_', $id, 'discourse', undef, 'ť');
            }
        }
    }
    print(join("\n", @sentence)."\n");
}



#------------------------------------------------------------------------------
# Vyplní řádek pro nově vytvořený uzel (syntaktické slovo).
#------------------------------------------------------------------------------
sub set_line
{
    my $line = shift;
    my @inf = @_;
    my @f = split(/\t/, $line);
    for(my $i = 0; $i <= 9; $i++)
    {
        if(defined($inf[$i]))
        {
            # For ID, we only get offset from the original token ID (typically 0 or 1).
            if($i==0)
            {
                $f[$i] += $inf[$i];
            }
            # For FORM, we expect a pair (array ref) for substitution regular expression. This is to preserve the original capitalization to some extent.
            # The assumption is that the original token form already is in $f[1].
            elsif($i==1 && ref($inf[$i]) eq 'ARRAY')
            {
                $f[$i] =~ s/$inf[$i][0]/$inf[$i][1]/i;
            }
            # For MISC, we only want to add Lemma1300.
            elsif($i==9)
            {
                my @misc = $f[9] eq '_' ? () : split(/\|/, $f[9]);
                @misc = grep {!m/^SpaceAfter=No$/} (@misc);
                if(grep {m/^Ref=/} (@misc))
                {
                    my @misc1;
                    foreach my $m (@misc)
                    {
                        push(@misc1, $m);
                        if($m =~ m/^Ref=/)
                        {
                            push(@misc1, "Lemma1300=$inf[$i]");
                        }
                    }
                    @misc = @misc1;
                }
                else
                {
                    unshift(@misc, "Lemma1300=$inf[$i]");
                }
                $f[9] = scalar(@misc) == 0 ? '_' : join('|', @misc);
            }
            else
            {
                $f[$i] = $inf[$i];
            }
        }
    }
    $line = join("\t", @f);
    return $line;
}

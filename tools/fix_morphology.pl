#!/usr/bin/env perl
# Pomocí různých heuristik se pokusí opravit morfologickou anotaci z UDPipu.
# Může využít i nezjednoznačněnou částečnou morfologickou analýzu v MISC.
# Copyright © 2022 Dan Zeman <zeman@ufal.mff.cuni.cz>
# License: GNU GPL

use utf8;
use open ':utf8';
binmode(STDIN, ':utf8');
binmode(STDOUT, ':utf8');
binmode(STDERR, ':utf8');
use Carp;
use Lingua::Interset;

# Některá lemmata nezná ani UDPipe, ani morfologická analýza ze Staročeské banky,
# tak je vyjmenujeme zde. První je moderní lemma, druhé staročeské.
my %lemmata =
(
    'dachu' => ['dát', 'dáti'],
    'dějiechu' => ['dít', 'dieti'],
    'dějieše' => ['dít', 'dieti'],
    'jedúce' => ['jíst', 'jiesti'],
    'jědúce' => ['jíst', 'jiesti'],
    'jěchu' => ['jíst', 'jiesti'], # "jíst" je to v MATT 14.20 a 15.37 (Dr. i Ol.), zatímco ve 26.67 (Dr.) a 26.50 (Ol.) je to "jmout" / "jieti"
    'jemše' => ['jmout', 'jieti'],
    'lajieše' => ['lát', 'láti'],
    'lžíce' => ['lhát', 'lháti'],
    'melíce' => ['mlít', 'mlíti'],
    'nadějieše' => ['nadít', 'nadieti'],
    'nemožiechu' => ['moci', 'moci'],
    'nemožieše' => ['moci', 'moci'],
    'neodpoviedáše' => ['odpovídat', 'otpoviedati'],
    'nevědúce' => ['vědět', 'věděti'],
    'nevzěchu' => ['vzít', 'vzieti'],
    'oblečechu' => ['obléci', 'obléci'],
    'oděchu' => ['odít', 'odíti'],
    'otevřěchu' => ['otevřít', 'otevříti'],
    'otevřěvše' => ['otevřít', 'otevříti'],
    'pasiechu' => ['pást', 'pásti'],
    'píce' => ['pít', 'píti'],
    'plváchu' => ['plivat', 'plvati'],
    'počěchu' => ['počít', 'počíti'],
    'podachu' => ['podat', 'podati'],
    'pokazachu' => ['pokázat', 'pokázati'],
    'přěpluchu' => ['přeplout', 'přěplúti'],
    'přěvezechu' => ['převézt', 'přěvézti'],
    'přěvzděchu' => ['přezdít', 'přěvzdíti'], # I vzě svú ženu, a nepozna jie tělestně, až ona urodi svého syna prvorozeného, i přěvzděchu jemu Ježíš.
    'přijemše' => ['přijmout', 'přijieti'],
    'přinesechu' => ['přinést', 'přinésti'],
    'přivedechu' => ['přivést', 'přivésti'],
    'přivedesta' => ['přivést', 'přivésti'],
    'sějieše' => ['sít', 'sieti'],
    'sněchu' => ['sníst', 'snísti'],
    'spletše' => ['splést', 'splésti'],
    'sstupujíce' => ['sestupovat', 'sstupovati'],
    'střěhúce' => ['střežit', 'střěžiti'],
    'střěžiechu' => ['střežit', 'střěžiti'],
    'svlečechu' => ['svléci', 'svléci'],
    'svlekše' => ['svléci', 'svléci'],
    'tepiechu' => ['tepat', 'tepati'],
    'utečechu' => ['utéci', 'utéci'], ###!!! Morfologie z StB tvrdí, že to má lemma "utknout".
    'vdachu' => ['vdát', 'vdáti'],
    'vedechu' => ['vést', 'vésti'],
    'vediechu' => ['vést', 'vésti'],
    'vědieše' => ['vědět', 'věděti'],
    'viechu' => ['vát', 'vieti'],
    'vstachu' => ['vstát', 'vstáti'],
    'vstavše' => ['vstát', 'vstáti'],
    'vuolajíce' => ['volat', 'volati'],
    'vuolášta' => ['volat', 'volati'],
    'vzachu' => ['vzít', 'vzieti'],
    'vzdachu' => ['vzdát', 'vzdáti'],
    'vzděchu' => ['vzdít', 'vzdíti'],
    'vzěchu' => ['vzít', 'vzieti'],
    'vzem' => ['vzít', 'vzieti'],
    'vzemše' => ['vzít', 'vzieti'],
    'vzemši' => ['vzít', 'vzieti'],
    'vzvěděchu' => ['vzvědět', 'vzvěděti'],
    'zabichu' => ['zabít', 'zabíti'],
    'zažhúce' => ['zažehnout', 'zažéci'],
    'zbichu' => ['zbít', 'zbíti'],
    'zemřěchu' => ['zemřít', 'zemříti'],
    'zeplvachu' => ['zeplivat', 'zeplvati'],
    'zrazijíce' => ['zrazit', 'zraziti'],
    'zvolachu' => ['zvolat', 'zvolati'],
    'zvolašta' => ['zvolat', 'zvolati']
);

while(<>)
{
    if(m/^\d/)
    {
        s/\r?\n$//;
        my @f = split(/\t/);
        # Rys Style=Arch smazat všude. Tvary, které jsou archaické ve 21. století, nebyly archaické ve 14. století.
        # Jiné hodnoty Style v těchto datech asi nepotkáme, ale pokud ano, vymažeme je taky.
        $f[4] = substr($f[4], 0, 14).'-' if(length($f[4]) == 15 && $f[4] !~ m/8$/); # 8 ... zkratka
        $f[5] = join('|', grep {!m/^Style=.*$/} (split(/\|/, $f[5])));
        $f[5] = '_' if($f[5] eq '');
        #----------------------------------------------------------------------
        # Mužský rod životný.
        #----------------------------------------------------------------------
        if($f[1] =~ m/^(ne)?(anděl|anjel|apoštol|běs|brat[rř]|bu?o[hž]|býc|člověk|črv|dělní[kc]|diábe?l|dlužní[kc]|duch|duchovní[kcč]|had|hospodin|hřiešní[kc]|kacieř|kokot|kopáč|koze?lc?|krajěn|licoměrník|mládenečk|mistr|mudrá[kc]|muž|otc|pán|panoš|panošic|pe?s|pohan|pop|proro[kc]|přietel|rybář|rytieř|sath?an(?:as)?|sl[uú]h|starost|súdc|svědk|syn|šielene?[cč]|tetrarch|tovařiš|učedlní[kc]|učenní[kc]|velblúd|vodič|vrabc|ženc|žid)(a|e|ě|i|u|ovi|i?em|ú|oma|ie|ové|ěvé|é|óv|uov|í|ám|óm|uom|y|ami|ěmi)?$/i && $f[1] !~ m/^(božú|bu?oží|bu?ožiem?|hospodinóv|pohaně|popové|starosti)$/i)
        {
            my $negprefix = lc($1);
            my $lform = lc($2.$3);
            my %ma =
            (
                'anděl'     => ['anděl', 'anděl', [['Sing', 'S', 'Nom', '1']]],
                'anděla'    => ['anděl', 'anděl', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'anděle'    => ['anděl', 'anděl', [['Sing', 'S', 'Voc', '5']]],
                'andělé'    => ['anděl', 'anděl', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'andělě'    => ['anděl', 'anděl', [['Sing', 'S', 'Loc', '6']]],
                'andělem'   => ['anděl', 'anděl', [['Sing', 'S', 'Ins', '7']]],
                'anděli'    => ['anděl', 'anděl', [['Sing', 'S', 'Voc', '5'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'andělie'   => ['anděl', 'anděl', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'anděliech' => ['anděl', 'anděl', [['Plur', 'P', 'Loc', '6']]],
                'andělóm'   => ['anděl', 'anděl', [['Plur', 'P', 'Dat', '3']]],
                'anděloma'  => ['anděl', 'anděl', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'andělóv'   => ['anděl', 'anděl', [['Plur', 'P', 'Gen', '2']]],
                'andělové'  => ['anděl', 'anděl', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'andělovi'  => ['anděl', 'anděl', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'andělu'    => ['anděl', 'anděl', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'andělú'    => ['anděl', 'anděl', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'anděluom'  => ['anděl', 'anděl', [['Plur', 'P', 'Dat', '3']]],
                'anděluov'  => ['anděl', 'anděl', [['Plur', 'P', 'Gen', '2']]],
                'anděly'    => ['anděl', 'anděl', [['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Ins', '7']]],
                'anjel'     => ['anděl', 'anděl', [['Sing', 'S', 'Nom', '1']]],
                'anjela'    => ['anděl', 'anděl', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'anjele'    => ['anděl', 'anděl', [['Sing', 'S', 'Voc', '5']]],
                'anjelé'    => ['anděl', 'anděl', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'anjelě'    => ['anděl', 'anděl', [['Sing', 'S', 'Loc', '6']]],
                'anjelem'   => ['anděl', 'anděl', [['Sing', 'S', 'Ins', '7']]],
                'anjeli'    => ['anděl', 'anděl', [['Sing', 'S', 'Voc', '5'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'anjelie'   => ['anděl', 'anděl', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'anjeliech' => ['anděl', 'anděl', [['Plur', 'P', 'Loc', '6']]],
                'anjelóm'   => ['anděl', 'anděl', [['Plur', 'P', 'Dat', '3']]],
                'anjeloma'  => ['anděl', 'anděl', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'anjelóv'   => ['anděl', 'anděl', [['Plur', 'P', 'Gen', '2']]],
                'anjelové'  => ['anděl', 'anděl', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'anjelovi'  => ['anděl', 'anděl', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'anjelu'    => ['anděl', 'anděl', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'anjelú'    => ['anděl', 'anděl', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'anjeluom'  => ['anděl', 'anděl', [['Plur', 'P', 'Dat', '3']]],
                'anjeluov'  => ['anděl', 'anděl', [['Plur', 'P', 'Gen', '2']]],
                'anjely'    => ['anděl', 'anděl', [['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Ins', '7']]],
                'apoštol'     => ['apoštol', 'apoštol', [['Sing', 'S', 'Nom', '1']]],
                'apoštola'    => ['apoštol', 'apoštol', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'apoštole'    => ['apoštol', 'apoštol', [['Sing', 'S', 'Voc', '5']]],
                'apoštolé'    => ['apoštol', 'apoštol', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'apoštolě'    => ['apoštol', 'apoštol', [['Sing', 'S', 'Loc', '6']]],
                'apoštolem'   => ['apoštol', 'apoštol', [['Sing', 'S', 'Ins', '7']]],
                'apoštoli'    => ['apoštol', 'apoštol', [['Sing', 'S', 'Voc', '5'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'apoštolie'   => ['apoštol', 'apoštol', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'apoštoliech' => ['apoštol', 'apoštol', [['Plur', 'P', 'Loc', '6']]],
                'apoštolóm'   => ['apoštol', 'apoštol', [['Plur', 'P', 'Dat', '3']]],
                'apoštoloma'  => ['apoštol', 'apoštol', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'apoštolóv'   => ['apoštol', 'apoštol', [['Plur', 'P', 'Gen', '2']]],
                'apoštolové'  => ['apoštol', 'apoštol', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'apoštolovi'  => ['apoštol', 'apoštol', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'apoštolu'    => ['apoštol', 'apoštol', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'apoštolú'    => ['apoštol', 'apoštol', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'apoštoluom'  => ['apoštol', 'apoštol', [['Plur', 'P', 'Dat', '3']]],
                'apoštoluov'  => ['apoštol', 'apoštol', [['Plur', 'P', 'Gen', '2']]],
                'apoštoly'    => ['apoštol', 'apoštol', [['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Ins', '7']]],
                'běs'     => ['běs', 'běs', [['Sing', 'S', 'Nom', '1']]],
                'běsa'    => ['běs', 'běs', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'běse'    => ['běs', 'běs', [['Sing', 'S', 'Voc', '5']]],
                'běsě'    => ['běs', 'běs', [['Sing', 'S', 'Loc', '6']]],
                'běsem'   => ['běs', 'běs', [['Sing', 'S', 'Ins', '7']]],
                'běsi'    => ['běs', 'běs', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'běsie'   => ['běs', 'běs', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'běsiech' => ['běs', 'běs', [['Plur', 'P', 'Loc', '6']]],
                'běsóm'   => ['běs', 'běs', [['Plur', 'P', 'Dat', '3']]],
                'běsoma'  => ['běs', 'běs', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'běsóv'   => ['běs', 'běs', [['Plur', 'P', 'Gen', '2']]],
                'běsové'  => ['běs', 'běs', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'běsovi'  => ['běs', 'běs', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'běsu'    => ['běs', 'běs', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'běsú'    => ['běs', 'běs', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'běsuom'  => ['běs', 'běs', [['Plur', 'P', 'Dat', '3']]],
                'běsuov'  => ['běs', 'běs', [['Plur', 'P', 'Gen', '2']]],
                'běsy'    => ['běs', 'běs', [['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Ins', '7']]],
                'boh'      => ['bůh', 'bóh', [['Sing', 'S', 'Nom', '1']]],
                'bóh'      => ['bůh', 'bóh', [['Sing', 'S', 'Nom', '1']]],
                'boha'     => ['bůh', 'bóh', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'bohem'    => ['bůh', 'bóh', [['Sing', 'S', 'Ins', '7']]],
                'bohóm'    => ['bůh', 'bóh', [['Plur', 'P', 'Dat', '3']]],
                'bohoma'   => ['bůh', 'bóh', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'bohóv'    => ['bůh', 'bóh', [['Plur', 'P', 'Gen', '2']]],
                'bohové'   => ['bůh', 'bóh', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'bohovi'   => ['bůh', 'bóh', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'bohu'     => ['bůh', 'bóh', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Voc', '5'], ['Sing', 'S', 'Loc', '6']]],
                'bohú'     => ['bůh', 'bóh', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'bohuom'   => ['bůh', 'bóh', [['Plur', 'P', 'Dat', '3']]],
                'bohuov'   => ['bůh', 'bóh', [['Plur', 'P', 'Gen', '2']]],
                'bohy'     => ['bůh', 'bóh', [['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Ins', '7']]],
                'bozě'     => ['bůh', 'bóh', [['Sing', 'S', 'Loc', '6']]],
                'bozi'     => ['bůh', 'bóh', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'bozie'    => ['bůh', 'bóh', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'boziech'  => ['bůh', 'bóh', [['Plur', 'P', 'Loc', '6']]],
                'bože'     => ['bůh', 'bóh', [['Sing', 'S', 'Voc', '5']]],
                'božé'     => ['bůh', 'bóh', [['Sing', 'S', 'Gen', '2']]],
                'buoh'     => ['bůh', 'bóh', [['Sing', 'S', 'Nom', '1']]],
                'buoha'    => ['bůh', 'bóh', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'buohem'   => ['bůh', 'bóh', [['Sing', 'S', 'Ins', '7']]],
                'buohóm'   => ['bůh', 'bóh', [['Plur', 'P', 'Dat', '3']]],
                'buohoma'  => ['bůh', 'bóh', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'buohóv'   => ['bůh', 'bóh', [['Plur', 'P', 'Gen', '2']]],
                'buohové'  => ['bůh', 'bóh', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'buohovi'  => ['bůh', 'bóh', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'buohu'    => ['bůh', 'bóh', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Voc', '5'], ['Sing', 'S', 'Loc', '6']]],
                'buohú'    => ['bůh', 'bóh', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'buohuom'  => ['bůh', 'bóh', [['Plur', 'P', 'Dat', '3']]],
                'buohuov'  => ['bůh', 'bóh', [['Plur', 'P', 'Gen', '2']]],
                'buohy'    => ['bůh', 'bóh', [['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Ins', '7']]],
                'buozě'    => ['bůh', 'bóh', [['Sing', 'S', 'Loc', '6']]],
                'buozi'    => ['bůh', 'bóh', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'buozie'   => ['bůh', 'bóh', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'buoziech' => ['bůh', 'bóh', [['Plur', 'P', 'Loc', '6']]],
                'buože'    => ['bůh', 'bóh', [['Sing', 'S', 'Voc', '5']]],
                'bratr'     => ['bratr', 'bratr', [['Sing', 'S', 'Nom', '1']]],
                'bratra'    => ['bratr', 'bratr', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'bratrem'   => ['bratr', 'bratr', [['Sing', 'S', 'Ins', '7']]],
                'bratróm'   => ['bratr', 'bratr', [['Plur', 'P', 'Dat', '3']]],
                'bratroma'  => ['bratr', 'bratr', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'bratróv'   => ['bratr', 'bratr', [['Plur', 'P', 'Gen', '2']]],
                'bratrové'  => ['bratr', 'bratr', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'bratrovi'  => ['bratr', 'bratr', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'bratru'    => ['bratr', 'bratr', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'bratrú'    => ['bratr', 'bratr', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'bratruom'  => ['bratr', 'bratr', [['Plur', 'P', 'Dat', '3']]],
                'bratruov'  => ['bratr', 'bratr', [['Plur', 'P', 'Gen', '2']]],
                'bratry'    => ['bratr', 'bratr', [['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Ins', '7']]],
                'bratře'    => ['bratr', 'bratr', [['Sing', 'S', 'Voc', '5']]],
                'bratřě'    => ['bratr', 'bratr', [['Sing', 'S', 'Loc', '6']]],
                'bratři'    => ['bratr', 'bratr', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'bratří'    => ['bratr', 'bratr', [['Plur', 'P', 'Gen', '2'], ['Plur', 'P', 'Dat', '3']]],
                'bratřie'   => ['bratr', 'bratr', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5']]],
                'bratřiech' => ['bratr', 'bratr', [['Plur', 'P', 'Loc', '6']]],
                'bratřú'    => ['bratr', 'bratr', [['Dual', 'D', 'Gen', '2']]],
                'býcě'    => ['býk', 'býk', [['Sing', 'S', 'Loc', '6']]],
                'býci'    => ['býk', 'býk', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'býcie'   => ['býk', 'býk', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'býciech' => ['býk', 'býk', [['Plur', 'P', 'Loc', '6']]],
                'býče'    => ['býk', 'býk', [['Sing', 'S', 'Voc', '5']]],
                'býk'     => ['býk', 'býk', [['Sing', 'S', 'Nom', '1']]],
                'býka'    => ['býk', 'býk', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'býkem'   => ['býk', 'býk', [['Sing', 'S', 'Ins', '7']]],
                'býkóm'   => ['býk', 'býk', [['Plur', 'P', 'Dat', '3']]],
                'býkoma'  => ['býk', 'býk', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'býkóv'   => ['býk', 'býk', [['Plur', 'P', 'Gen', '2']]],
                'býkové'  => ['býk', 'býk', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'býkovi'  => ['býk', 'býk', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'býku'    => ['býk', 'býk', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Voc', '5'], ['Sing', 'S', 'Loc', '6']]],
                'býkú'    => ['býk', 'býk', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'býkuom'  => ['býk', 'býk', [['Plur', 'P', 'Dat', '3']]],
                'býkuov'  => ['býk', 'býk', [['Plur', 'P', 'Gen', '2']]],
                'býky'    => ['býk', 'býk', [['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Ins', '7']]],
                'člověcě'    => ['člověk', 'člověk', [['Sing', 'S', 'Loc', '6']]],
                'člověci'    => ['člověk', 'člověk', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'člověcie'   => ['člověk', 'člověk', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'člověciech' => ['člověk', 'člověk', [['Plur', 'P', 'Loc', '6']]],
                'člověče'    => ['člověk', 'člověk', [['Sing', 'S', 'Voc', '5']]],
                'člověk'     => ['člověk', 'člověk', [['Sing', 'S', 'Nom', '1']]],
                'člověka'    => ['člověk', 'člověk', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'člověkem'   => ['člověk', 'člověk', [['Sing', 'S', 'Ins', '7']]],
                'člověkóm'   => ['člověk', 'člověk', [['Plur', 'P', 'Dat', '3']]],
                'člověkoma'  => ['člověk', 'člověk', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'člověkóv'   => ['člověk', 'člověk', [['Plur', 'P', 'Gen', '2']]],
                'člověkové'  => ['člověk', 'člověk', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'člověkovi'  => ['člověk', 'člověk', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'člověku'    => ['člověk', 'člověk', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Voc', '5'], ['Sing', 'S', 'Loc', '6']]],
                'člověkú'    => ['člověk', 'člověk', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'člověkuom'  => ['člověk', 'člověk', [['Plur', 'P', 'Dat', '3']]],
                'člověkuov'  => ['člověk', 'člověk', [['Plur', 'P', 'Gen', '2']]],
                'člověky'    => ['člověk', 'člověk', [['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Ins', '7']]],
                'červ'     => ['červ', 'črv', [['Sing', 'S', 'Nom', '1']]],
                'červa'    => ['červ', 'črv', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'červe'    => ['červ', 'črv', [['Sing', 'S', 'Voc', '5']]],
                'červě'    => ['červ', 'črv', [['Sing', 'S', 'Loc', '6']]],
                'červem'   => ['červ', 'črv', [['Sing', 'S', 'Ins', '7']]],
                'červi'    => ['červ', 'črv', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'červie'   => ['červ', 'črv', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'červiech' => ['červ', 'črv', [['Plur', 'P', 'Loc', '6']]],
                'červóm'   => ['červ', 'črv', [['Plur', 'P', 'Dat', '3']]],
                'červoma'  => ['červ', 'črv', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'červóv'   => ['červ', 'črv', [['Plur', 'P', 'Gen', '2']]],
                'červové'  => ['červ', 'črv', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'červovi'  => ['červ', 'črv', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'červu'    => ['červ', 'črv', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'červú'    => ['červ', 'črv', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'červuom'  => ['červ', 'črv', [['Plur', 'P', 'Dat', '3']]],
                'červuov'  => ['červ', 'črv', [['Plur', 'P', 'Gen', '2']]],
                'červy'    => ['červ', 'črv', [['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Ins', '7']]],
                'črv'      => ['červ', 'črv', [['Sing', 'S', 'Nom', '1']]],
                'črva'     => ['červ', 'črv', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'črve'     => ['červ', 'črv', [['Sing', 'S', 'Voc', '5']]],
                'črvě'     => ['červ', 'črv', [['Sing', 'S', 'Loc', '6']]],
                'črvem'    => ['červ', 'črv', [['Sing', 'S', 'Ins', '7']]],
                'črvi'     => ['červ', 'črv', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'črvie'    => ['červ', 'črv', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'črviech'  => ['červ', 'črv', [['Plur', 'P', 'Loc', '6']]],
                'črvóm'    => ['červ', 'črv', [['Plur', 'P', 'Dat', '3']]],
                'črvoma'   => ['červ', 'črv', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'črvóv'    => ['červ', 'črv', [['Plur', 'P', 'Gen', '2']]],
                'črvové'   => ['červ', 'črv', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'črvovi'   => ['červ', 'črv', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'črvu'     => ['červ', 'črv', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'črvú'     => ['červ', 'črv', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'črvuom'   => ['červ', 'črv', [['Plur', 'P', 'Dat', '3']]],
                'črvuov'   => ['červ', 'črv', [['Plur', 'P', 'Gen', '2']]],
                'črvy'     => ['červ', 'črv', [['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Ins', '7']]],
                'dělnícě'    => ['dělník', 'dělník', [['Sing', 'S', 'Loc', '6']]],
                'dělníci'    => ['dělník', 'dělník', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'dělnície'   => ['dělník', 'dělník', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'dělníciech' => ['dělník', 'dělník', [['Plur', 'P', 'Loc', '6']]],
                'dělníče'    => ['dělník', 'dělník', [['Sing', 'S', 'Voc', '5']]],
                'dělník'     => ['dělník', 'dělník', [['Sing', 'S', 'Nom', '1']]],
                'dělníka'    => ['dělník', 'dělník', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'dělníkem'   => ['dělník', 'dělník', [['Sing', 'S', 'Ins', '7']]],
                'dělníkóm'   => ['dělník', 'dělník', [['Plur', 'P', 'Dat', '3']]],
                'dělníkoma'  => ['dělník', 'dělník', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'dělníkóv'   => ['dělník', 'dělník', [['Plur', 'P', 'Gen', '2']]],
                'dělníkové'  => ['dělník', 'dělník', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'dělníkovi'  => ['dělník', 'dělník', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'dělníku'    => ['dělník', 'dělník', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Voc', '5'], ['Sing', 'S', 'Loc', '6']]],
                'dělníkú'    => ['dělník', 'dělník', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'dělníkuom'  => ['dělník', 'dělník', [['Plur', 'P', 'Dat', '3']]],
                'dělníkuov'  => ['dělník', 'dělník', [['Plur', 'P', 'Gen', '2']]],
                'dělníky'    => ['dělník', 'dělník', [['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Ins', '7']]],
                'diábel'    => ['ďábel', 'diábel', [['Sing', 'S', 'Nom', '1']]],
                'diábla'    => ['ďábel', 'diábel', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'diáble'    => ['ďábel', 'diábel', [['Sing', 'S', 'Voc', '5']]],
                'diáblě'    => ['ďábel', 'diábel', [['Sing', 'S', 'Loc', '6']]],
                'diáblem'   => ['ďábel', 'diábel', [['Sing', 'S', 'Ins', '7']]],
                'diábli'    => ['ďábel', 'diábel', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'diáblie'   => ['ďábel', 'diábel', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'diábliech' => ['ďábel', 'diábel', [['Plur', 'P', 'Loc', '6']]],
                'diáblóm'   => ['ďábel', 'diábel', [['Plur', 'P', 'Dat', '3']]],
                'diábloma'  => ['ďábel', 'diábel', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'diáblóv'   => ['ďábel', 'diábel', [['Plur', 'P', 'Gen', '2']]],
                'diáblové'  => ['ďábel', 'diábel', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'diáblovi'  => ['ďábel', 'diábel', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'diáblu'    => ['ďábel', 'diábel', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'diáblú'    => ['ďábel', 'diábel', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'diábluom'  => ['ďábel', 'diábel', [['Plur', 'P', 'Dat', '3']]],
                'diábluov'  => ['ďábel', 'diábel', [['Plur', 'P', 'Gen', '2']]],
                'diábly'    => ['ďábel', 'diábel', [['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Ins', '7']]],
                'dlužnícě'    => ['dlužník', 'dlužník', [['Sing', 'S', 'Loc', '6']]],
                'dlužníci'    => ['dlužník', 'dlužník', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'dlužnície'   => ['dlužník', 'dlužník', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'dlužníciech' => ['dlužník', 'dlužník', [['Plur', 'P', 'Loc', '6']]],
                'dlužníče'    => ['dlužník', 'dlužník', [['Sing', 'S', 'Voc', '5']]],
                'dlužník'     => ['dlužník', 'dlužník', [['Sing', 'S', 'Nom', '1']]],
                'dlužníka'    => ['dlužník', 'dlužník', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'dlužníkem'   => ['dlužník', 'dlužník', [['Sing', 'S', 'Ins', '7']]],
                'dlužníkóm'   => ['dlužník', 'dlužník', [['Plur', 'P', 'Dat', '3']]],
                'dlužníkoma'  => ['dlužník', 'dlužník', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'dlužníkóv'   => ['dlužník', 'dlužník', [['Plur', 'P', 'Gen', '2']]],
                'dlužníkové'  => ['dlužník', 'dlužník', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'dlužníkovi'  => ['dlužník', 'dlužník', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'dlužníku'    => ['dlužník', 'dlužník', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Voc', '5'], ['Sing', 'S', 'Loc', '6']]],
                'dlužníkú'    => ['dlužník', 'dlužník', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'dlužníkuom'  => ['dlužník', 'dlužník', [['Plur', 'P', 'Dat', '3']]],
                'dlužníkuov'  => ['dlužník', 'dlužník', [['Plur', 'P', 'Gen', '2']]],
                'dlužníky'    => ['dlužník', 'dlužník', [['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Ins', '7']]],
                'duczě'   => ['duch', 'duch', [['Sing', 'S', 'Loc', '6']]],
                'duch'    => ['duch', 'duch', [['Sing', 'S', 'Nom', '1']]],
                'ducha'   => ['duch', 'duch', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'duchem'  => ['duch', 'duch', [['Sing', 'S', 'Ins', '7']]],
                'duchóm'  => ['duch', 'duch', [['Plur', 'P', 'Dat', '3']]],
                'duchoma' => ['duch', 'duch', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'duchóv'  => ['duch', 'duch', [['Plur', 'P', 'Gen', '2']]],
                'duchové' => ['duch', 'duch', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'duchovi' => ['duch', 'duch', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'duchu'   => ['duch', 'duch', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Voc', '5'], ['Sing', 'S', 'Loc', '6']]],
                'duchú'   => ['duch', 'duch', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'duchuom' => ['duch', 'duch', [['Plur', 'P', 'Dat', '3']]],
                'duchuov' => ['duch', 'duch', [['Plur', 'P', 'Gen', '2']]],
                'duchy'   => ['duch', 'duch', [['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Ins', '7']]],
                'duše'    => ['duch', 'duch', [['Sing', 'S', 'Voc', '5']]],
                'duši'    => ['duch', 'duch', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'dušie'   => ['duch', 'duch', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'dušiech' => ['duch', 'duch', [['Plur', 'P', 'Loc', '6']]],
                'duchovnícě'    => ['duchovník', 'duchovník', [['Sing', 'S', 'Loc', '6']]],
                'duchovníci'    => ['duchovník', 'duchovník', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'duchovnície'   => ['duchovník', 'duchovník', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'duchovníciech' => ['duchovník', 'duchovník', [['Plur', 'P', 'Loc', '6']]],
                'duchovníče'    => ['duchovník', 'duchovník', [['Sing', 'S', 'Voc', '5']]],
                'duchovník'     => ['duchovník', 'duchovník', [['Sing', 'S', 'Nom', '1']]],
                'duchovníka'    => ['duchovník', 'duchovník', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'duchovníkem'   => ['duchovník', 'duchovník', [['Sing', 'S', 'Ins', '7']]],
                'duchovníkóm'   => ['duchovník', 'duchovník', [['Plur', 'P', 'Dat', '3']]],
                'duchovníkoma'  => ['duchovník', 'duchovník', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'duchovníkóv'   => ['duchovník', 'duchovník', [['Plur', 'P', 'Gen', '2']]],
                'duchovníkové'  => ['duchovník', 'duchovník', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'duchovníkovi'  => ['duchovník', 'duchovník', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'duchovníku'    => ['duchovník', 'duchovník', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Voc', '5'], ['Sing', 'S', 'Loc', '6']]],
                'duchovníkú'    => ['duchovník', 'duchovník', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'duchovníkuom'  => ['duchovník', 'duchovník', [['Plur', 'P', 'Dat', '3']]],
                'duchovníkuov'  => ['duchovník', 'duchovník', [['Plur', 'P', 'Gen', '2']]],
                'duchovníky'    => ['duchovník', 'duchovník', [['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Ins', '7']]],
                'had'     => ['had', 'had', [['Sing', 'S', 'Nom', '1']]],
                'hada'    => ['had', 'had', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'hade'    => ['had', 'had', [['Sing', 'S', 'Voc', '5']]],
                'hadě'    => ['had', 'had', [['Sing', 'S', 'Loc', '6']]],
                'hadem'   => ['had', 'had', [['Sing', 'S', 'Ins', '7']]],
                'hadi'    => ['had', 'had', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'hadie'   => ['had', 'had', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'hadiech' => ['had', 'had', [['Plur', 'P', 'Loc', '6']]],
                'hadóm'   => ['had', 'had', [['Plur', 'P', 'Dat', '3']]],
                'hadoma'  => ['had', 'had', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'hadóv'   => ['had', 'had', [['Plur', 'P', 'Gen', '2']]],
                'hadové'  => ['had', 'had', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'hadovi'  => ['had', 'had', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'hadu'    => ['had', 'had', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'hadú'    => ['had', 'had', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'haduom'  => ['had', 'had', [['Plur', 'P', 'Dat', '3']]],
                'haduov'  => ['had', 'had', [['Plur', 'P', 'Gen', '2']]],
                'hady'    => ['had', 'had', [['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Ins', '7']]],
                'hospodin'     => ['hospodin', 'hospodin', [['Sing', 'S', 'Nom', '1']]],
                'hospodina'    => ['hospodin', 'hospodin', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'hospodine'    => ['hospodin', 'hospodin', [['Sing', 'S', 'Voc', '5']]],
                'hospodině'    => ['hospodin', 'hospodin', [['Sing', 'S', 'Loc', '6']]],
                'hospodinem'   => ['hospodin', 'hospodin', [['Sing', 'S', 'Ins', '7']]],
                'hospodini'    => ['hospodin', 'hospodin', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'hospodinie'   => ['hospodin', 'hospodin', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'hospodiniech' => ['hospodin', 'hospodin', [['Plur', 'P', 'Loc', '6']]],
                'hospodinóm'   => ['hospodin', 'hospodin', [['Plur', 'P', 'Dat', '3']]],
                'hospodinoma'  => ['hospodin', 'hospodin', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'hospodinóv'   => ['hospodin', 'hospodin', [['Plur', 'P', 'Gen', '2']]],
                'hospodinové'  => ['hospodin', 'hospodin', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'hospodinovi'  => ['hospodin', 'hospodin', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'hospodinu'    => ['hospodin', 'hospodin', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'hospodinú'    => ['hospodin', 'hospodin', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'hospodinuom'  => ['hospodin', 'hospodin', [['Plur', 'P', 'Dat', '3']]],
                'hospodinuov'  => ['hospodin', 'hospodin', [['Plur', 'P', 'Gen', '2']]],
                'hospodiny'    => ['hospodin', 'hospodin', [['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Ins', '7']]],
                'hřiešnícě'    => ['hříšník', 'hřiešník', [['Sing', 'S', 'Loc', '6']]],
                'hřiešníci'    => ['hříšník', 'hřiešník', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'hřiešnície'   => ['hříšník', 'hřiešník', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'hřiešníciech' => ['hříšník', 'hřiešník', [['Plur', 'P', 'Loc', '6']]],
                'hřiešníče'    => ['hříšník', 'hřiešník', [['Sing', 'S', 'Voc', '5']]],
                'hřiešník'     => ['hříšník', 'hřiešník', [['Sing', 'S', 'Nom', '1']]],
                'hřiešníka'    => ['hříšník', 'hřiešník', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'hřiešníkem'   => ['hříšník', 'hřiešník', [['Sing', 'S', 'Ins', '7']]],
                'hřiešníkóm'   => ['hříšník', 'hřiešník', [['Plur', 'P', 'Dat', '3']]],
                'hřiešníkoma'  => ['hříšník', 'hřiešník', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'hřiešníkóv'   => ['hříšník', 'hřiešník', [['Plur', 'P', 'Gen', '2']]],
                'hřiešníkové'  => ['hříšník', 'hřiešník', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'hřiešníkovi'  => ['hříšník', 'hřiešník', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'hřiešníku'    => ['hříšník', 'hřiešník', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Voc', '5'], ['Sing', 'S', 'Loc', '6']]],
                'hřiešníkú'    => ['hříšník', 'hřiešník', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'hřiešníkuom'  => ['hříšník', 'hřiešník', [['Plur', 'P', 'Dat', '3']]],
                'hřiešníkuov'  => ['hříšník', 'hřiešník', [['Plur', 'P', 'Gen', '2']]],
                'hřiešníky'    => ['hříšník', 'hřiešník', [['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Ins', '7']]],
                'kacieř'     => ['kacíř', 'kacieř', [['Sing', 'S', 'Nom', '1']]],
                'kacieřa'    => ['kacíř', 'kacieř', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'kacieře'    => ['kacíř', 'kacieř', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4'], ['Sing', 'S', 'Voc', '5'], ['Plur', 'P', 'Acc', '4']]],
                'kacieřě'    => ['kacíř', 'kacieř', [['Sing', 'S', 'Loc', '6'], ['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5']]],
                'kacieřem'   => ['kacíř', 'kacieř', [['Sing', 'S', 'Ins', '7']]],
                'kacieři'    => ['kacíř', 'kacieř', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5'], ['Plur', 'P', 'Ins', '7']]],
                'kacieřie'   => ['kacíř', 'kacieř', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'kacieřiech' => ['kacíř', 'kacieř', [['Plur', 'P', 'Loc', '6']]],
                'kacieřiem'  => ['kacíř', 'kacieř', [['Sing', 'S', 'Ins', '7']]],
                'kacieřiev'  => ['kacíř', 'kacieř', [['Plur', 'P', 'Gen', '2']]],
                'kacieřóm'   => ['kacíř', 'kacieř', [['Plur', 'P', 'Dat', '3']]],
                'kacieřoma'  => ['kacíř', 'kacieř', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'kacieřóv'   => ['kacíř', 'kacieř', [['Plur', 'P', 'Gen', '2']]],
                'kacieřové'  => ['kacíř', 'kacieř', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'kacieřovi'  => ['kacíř', 'kacieř', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'kacieřu'    => ['kacíř', 'kacieř', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'kacieřú'    => ['kacíř', 'kacieř', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'kacieřuom'  => ['kacíř', 'kacieř', [['Plur', 'P', 'Dat', '3']]],
                'kacieřuov'  => ['kacíř', 'kacieř', [['Plur', 'P', 'Gen', '2']]],
                'kokot'     => ['kokot', 'kokot', [['Sing', 'S', 'Nom', '1']]],
                'kokota'    => ['kokot', 'kokot', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'kokote'    => ['kokot', 'kokot', [['Sing', 'S', 'Voc', '5']]],
                'kokotě'    => ['kokot', 'kokot', [['Sing', 'S', 'Loc', '6']]],
                'kokotem'   => ['kokot', 'kokot', [['Sing', 'S', 'Ins', '7']]],
                'kokoti'    => ['kokot', 'kokot', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'kokotie'   => ['kokot', 'kokot', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'kokotiech' => ['kokot', 'kokot', [['Plur', 'P', 'Loc', '6']]],
                'kokotóm'   => ['kokot', 'kokot', [['Plur', 'P', 'Dat', '3']]],
                'kokotoma'  => ['kokot', 'kokot', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'kokotóv'   => ['kokot', 'kokot', [['Plur', 'P', 'Gen', '2']]],
                'kokotové'  => ['kokot', 'kokot', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'kokotovi'  => ['kokot', 'kokot', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'kokotu'    => ['kokot', 'kokot', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'kokotú'    => ['kokot', 'kokot', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'kokotuom'  => ['kokot', 'kokot', [['Plur', 'P', 'Dat', '3']]],
                'kokotuov'  => ['kokot', 'kokot', [['Plur', 'P', 'Gen', '2']]],
                'kokoty'    => ['kokot', 'kokot', [['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Ins', '7']]],
                'kopáč'     => ['kopáč', 'kopáč', [['Sing', 'S', 'Nom', '1']]],
                'kopáča'    => ['kopáč', 'kopáč', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'kopáče'    => ['kopáč', 'kopáč', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4'], ['Sing', 'S', 'Voc', '5'], ['Plur', 'P', 'Acc', '4']]],
                'kopáčě'    => ['kopáč', 'kopáč', [['Sing', 'S', 'Loc', '6'], ['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5']]],
                'kopáčem'   => ['kopáč', 'kopáč', [['Sing', 'S', 'Ins', '7']]],
                'kopáči'    => ['kopáč', 'kopáč', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5'], ['Plur', 'P', 'Ins', '7']]],
                'kopáčie'   => ['kopáč', 'kopáč', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'kopáčiech' => ['kopáč', 'kopáč', [['Plur', 'P', 'Loc', '6']]],
                'kopáčiem'  => ['kopáč', 'kopáč', [['Sing', 'S', 'Ins', '7']]],
                'kopáčiev'  => ['kopáč', 'kopáč', [['Plur', 'P', 'Gen', '2']]],
                'kopáčóm'   => ['kopáč', 'kopáč', [['Plur', 'P', 'Dat', '3']]],
                'kopáčoma'  => ['kopáč', 'kopáč', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'kopáčóv'   => ['kopáč', 'kopáč', [['Plur', 'P', 'Gen', '2']]],
                'kopáčové'  => ['kopáč', 'kopáč', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'kopáčovi'  => ['kopáč', 'kopáč', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'kopáču'    => ['kopáč', 'kopáč', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'kopáčú'    => ['kopáč', 'kopáč', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'kopáčuom'  => ['kopáč', 'kopáč', [['Plur', 'P', 'Dat', '3']]],
                'kopáčuov'  => ['kopáč', 'kopáč', [['Plur', 'P', 'Gen', '2']]],
                'kozel'      => ['kozel', 'kozel', [['Sing', 'S', 'Nom', '1']]],
                'kozelca'    => ['kozel', 'kozel', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'kozelce'    => ['kozel', 'kozel', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4'], ['Plur', 'P', 'Acc', '4']]],
                'kozelcě'    => ['kozel', 'kozel', [['Sing', 'S', 'Loc', '6'], ['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5']]],
                'kozelcem'   => ['kozel', 'kozel', [['Sing', 'S', 'Ins', '7']]],
                'kozelci'    => ['kozel', 'kozel', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5'], ['Plur', 'P', 'Ins', '7']]],
                'kozelcie'   => ['kozel', 'kozel', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'kozelciech' => ['kozel', 'kozel', [['Plur', 'P', 'Loc', '6']]],
                'kozelciem'  => ['kozel', 'kozel', [['Sing', 'S', 'Ins', '7']]],
                'kozelciev'  => ['kozel', 'kozel', [['Plur', 'P', 'Gen', '2']]],
                'kozelcóm'   => ['kozel', 'kozel', [['Plur', 'P', 'Dat', '3']]],
                'kozelcoma'  => ['kozel', 'kozel', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'kozelcóv'   => ['kozel', 'kozel', [['Plur', 'P', 'Gen', '2']]],
                'kozelcové'  => ['kozel', 'kozel', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'kozelcovi'  => ['kozel', 'kozel', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'kozelcu'    => ['kozel', 'kozel', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'kozelcú'    => ['kozel', 'kozel', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'kozelcuom'  => ['kozel', 'kozel', [['Plur', 'P', 'Dat', '3']]],
                'kozelcuov'  => ['kozel', 'kozel', [['Plur', 'P', 'Gen', '2']]],
                'kozelče'    => ['kozel', 'kozel', [['Sing', 'S', 'Voc', '5']]],
                'kozelec'    => ['kozel', 'kozel', [['Sing', 'S', 'Nom', '1']]],
                'kozla'      => ['kozel', 'kozel', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'kozle'      => ['kozel', 'kozel', [['Sing', 'S', 'Voc', '5']]],
                'kozlě'      => ['kozel', 'kozel', [['Sing', 'S', 'Loc', '6']]],
                'kozlem'     => ['kozel', 'kozel', [['Sing', 'S', 'Ins', '7']]],
                'kozli'      => ['kozel', 'kozel', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'kozlie'     => ['kozel', 'kozel', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'kozliech'   => ['kozel', 'kozel', [['Plur', 'P', 'Loc', '6']]],
                'kozlóm'     => ['kozel', 'kozel', [['Plur', 'P', 'Dat', '3']]],
                'kozloma'    => ['kozel', 'kozel', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'kozlóv'     => ['kozel', 'kozel', [['Plur', 'P', 'Gen', '2']]],
                'kozlové'    => ['kozel', 'kozel', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'kozlovi'    => ['kozel', 'kozel', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'kozlu'      => ['kozel', 'kozel', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'kozlú'      => ['kozel', 'kozel', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'kozluom'    => ['kozel', 'kozel', [['Plur', 'P', 'Dat', '3']]],
                'kozluov'    => ['kozel', 'kozel', [['Plur', 'P', 'Gen', '2']]],
                'kozly'      => ['kozel', 'kozel', [['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Ins', '7']]],
                'krajěné'      => ['krajan',     'krajěnín',   [['Plur', 'P', 'Nom', '1']]],
                'licoměrnícě'    => ['licoměrník', 'licoměrník', [['Sing', 'S', 'Loc', '6']]],
                'licoměrníci'    => ['licoměrník', 'licoměrník', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'licoměrnície'   => ['licoměrník', 'licoměrník', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'licoměrníciech' => ['licoměrník', 'licoměrník', [['Plur', 'P', 'Loc', '6']]],
                'licoměrníče'    => ['licoměrník', 'licoměrník', [['Sing', 'S', 'Voc', '5']]],
                'licoměrník'     => ['licoměrník', 'licoměrník', [['Sing', 'S', 'Nom', '1']]],
                'licoměrníka'    => ['licoměrník', 'licoměrník', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'licoměrníkem'   => ['licoměrník', 'licoměrník', [['Sing', 'S', 'Ins', '7']]],
                'licoměrníkóm'   => ['licoměrník', 'licoměrník', [['Plur', 'P', 'Dat', '3']]],
                'licoměrníkoma'  => ['licoměrník', 'licoměrník', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'licoměrníkóv'   => ['licoměrník', 'licoměrník', [['Plur', 'P', 'Gen', '2']]],
                'licoměrníkové'  => ['licoměrník', 'licoměrník', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'licoměrníkovi'  => ['licoměrník', 'licoměrník', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'licoměrníku'    => ['licoměrník', 'licoměrník', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Voc', '5'], ['Sing', 'S', 'Loc', '6']]],
                'licoměrníkú'    => ['licoměrník', 'licoměrník', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'licoměrníkuom'  => ['licoměrník', 'licoměrník', [['Plur', 'P', 'Dat', '3']]],
                'licoměrníkuov'  => ['licoměrník', 'licoměrník', [['Plur', 'P', 'Gen', '2']]],
                'licoměrníky'    => ['licoměrník', 'licoměrník', [['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Ins', '7']]],
                'mistr'     => ['mistr', 'mistr', [['Sing', 'S', 'Nom', '1']]],
                'mistra'    => ['mistr', 'mistr', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'mistrem'   => ['mistr', 'mistr', [['Sing', 'S', 'Ins', '7']]],
                'mistróm'   => ['mistr', 'mistr', [['Plur', 'P', 'Dat', '3']]],
                'mistroma'  => ['mistr', 'mistr', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'mistróv'   => ['mistr', 'mistr', [['Plur', 'P', 'Gen', '2']]],
                'mistrové'  => ['mistr', 'mistr', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'mistrovi'  => ['mistr', 'mistr', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'mistru'    => ['mistr', 'mistr', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'mistrú'    => ['mistr', 'mistr', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'mistruom'  => ['mistr', 'mistr', [['Plur', 'P', 'Dat', '3']]],
                'mistruov'  => ['mistr', 'mistr', [['Plur', 'P', 'Gen', '2']]],
                'mistry'    => ['mistr', 'mistr', [['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Ins', '7']]],
                'mistře'    => ['mistr', 'mistr', [['Sing', 'S', 'Voc', '5']]],
                'mistřě'    => ['mistr', 'mistr', [['Sing', 'S', 'Loc', '6']]],
                'mistři'    => ['mistr', 'mistr', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'mistřie'   => ['mistr', 'mistr', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'mistřiech' => ['mistr', 'mistr', [['Plur', 'P', 'Loc', '6']]],
                'mládenečcě'    => ['mládeneček', 'mládeneček', [['Sing', 'S', 'Loc', '6']]],
                'mládenečci'    => ['mládeneček', 'mládeneček', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'mládenečcie'   => ['mládeneček', 'mládeneček', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'mládenečciech' => ['mládeneček', 'mládeneček', [['Plur', 'P', 'Loc', '6']]],
                'mládenečče'    => ['mládeneček', 'mládeneček', [['Sing', 'S', 'Voc', '5']]],
                'mládeneček'    => ['mládeneček', 'mládeneček', [['Sing', 'S', 'Nom', '1']]],
                'mládenečka'    => ['mládeneček', 'mládeneček', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'mládenečkem'   => ['mládeneček', 'mládeneček', [['Sing', 'S', 'Ins', '7']]],
                'mládenečkóm'   => ['mládeneček', 'mládeneček', [['Plur', 'P', 'Dat', '3']]],
                'mládenečkoma'  => ['mládeneček', 'mládeneček', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'mládenečkóv'   => ['mládeneček', 'mládeneček', [['Plur', 'P', 'Gen', '2']]],
                'mládenečkové'  => ['mládeneček', 'mládeneček', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'mládenečkovi'  => ['mládeneček', 'mládeneček', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'mládenečku'    => ['mládeneček', 'mládeneček', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Voc', '5'], ['Sing', 'S', 'Loc', '6']]],
                'mládenečkú'    => ['mládeneček', 'mládeneček', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'mládenečkuom'  => ['mládeneček', 'mládeneček', [['Plur', 'P', 'Dat', '3']]],
                'mládenečkuov'  => ['mládeneček', 'mládeneček', [['Plur', 'P', 'Gen', '2']]],
                'mládenečky'    => ['mládeneček', 'mládeneček', [['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Ins', '7']]],
                'mudrácě'    => ['mudrák', 'mudrák', [['Sing', 'S', 'Loc', '6']]],
                'mudráci'    => ['mudrák', 'mudrák', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'mudrácie'   => ['mudrák', 'mudrák', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'mudráciech' => ['mudrák', 'mudrák', [['Plur', 'P', 'Loc', '6']]],
                'mudráče'    => ['mudrák', 'mudrák', [['Sing', 'S', 'Voc', '5']]],
                'mudrák'     => ['mudrák', 'mudrák', [['Sing', 'S', 'Nom', '1']]],
                'mudráka'    => ['mudrák', 'mudrák', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'mudrákem'   => ['mudrák', 'mudrák', [['Sing', 'S', 'Ins', '7']]],
                'mudrákóm'   => ['mudrák', 'mudrák', [['Plur', 'P', 'Dat', '3']]],
                'mudrákoma'  => ['mudrák', 'mudrák', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'mudrákóv'   => ['mudrák', 'mudrák', [['Plur', 'P', 'Gen', '2']]],
                'mudrákové'  => ['mudrák', 'mudrák', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'mudrákovi'  => ['mudrák', 'mudrák', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'mudráku'    => ['mudrák', 'mudrák', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Voc', '5'], ['Sing', 'S', 'Loc', '6']]],
                'mudrákú'    => ['mudrák', 'mudrák', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'mudrákuom'  => ['mudrák', 'mudrák', [['Plur', 'P', 'Dat', '3']]],
                'mudrákuov'  => ['mudrák', 'mudrák', [['Plur', 'P', 'Gen', '2']]],
                'mudráky'    => ['mudrák', 'mudrák', [['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Ins', '7']]],
                'muž'     => ['muž', 'muž', [['Sing', 'S', 'Nom', '1']]],
                'muža'    => ['muž', 'muž', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'muže'    => ['muž', 'muž', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4'], ['Sing', 'S', 'Voc', '5'], ['Plur', 'P', 'Acc', '4']]],
                'mužě'    => ['muž', 'muž', [['Sing', 'S', 'Loc', '6'], ['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5']]],
                'mužem'   => ['muž', 'muž', [['Sing', 'S', 'Ins', '7']]],
                'muži'    => ['muž', 'muž', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5'], ['Plur', 'P', 'Ins', '7']]],
                'muží'    => ['muž', 'muž', [['Plur', 'P', 'Gen', '2']]],
                'mužie'   => ['muž', 'muž', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'mužiech' => ['muž', 'muž', [['Plur', 'P', 'Loc', '6']]],
                'mužiem'  => ['muž', 'muž', [['Sing', 'S', 'Ins', '7']]],
                'mužiev'  => ['muž', 'muž', [['Plur', 'P', 'Gen', '2']]],
                'mužóm'   => ['muž', 'muž', [['Plur', 'P', 'Dat', '3']]],
                'mužoma'  => ['muž', 'muž', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'mužóv'   => ['muž', 'muž', [['Plur', 'P', 'Gen', '2']]],
                'mužové'  => ['muž', 'muž', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'mužovi'  => ['muž', 'muž', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'mužu'    => ['muž', 'muž', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'mužú'    => ['muž', 'muž', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'mužuom'  => ['muž', 'muž', [['Plur', 'P', 'Dat', '3']]],
                'mužuov'  => ['muž', 'muž', [['Plur', 'P', 'Gen', '2']]],
                'otca'    => ['otec', 'otec', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'otce'    => ['otec', 'otec', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4'], ['Plur', 'P', 'Acc', '4']]],
                'otcě'    => ['otec', 'otec', [['Sing', 'S', 'Loc', '6'], ['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5']]],
                'otcem'   => ['otec', 'otec', [['Sing', 'S', 'Ins', '7']]],
                'otci'    => ['otec', 'otec', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5'], ['Plur', 'P', 'Ins', '7']]],
                'otcí'    => ['otec', 'otec', [['Dual', 'D', 'Gen', '2']]],
                'otcie'   => ['otec', 'otec', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'otciech' => ['otec', 'otec', [['Plur', 'P', 'Loc', '6']]],
                'otciem'  => ['otec', 'otec', [['Sing', 'S', 'Ins', '7']]],
                'otciev'  => ['otec', 'otec', [['Plur', 'P', 'Gen', '2']]],
                'otcóm'   => ['otec', 'otec', [['Plur', 'P', 'Dat', '3']]],
                'otcoma'  => ['otec', 'otec', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'otcóv'   => ['otec', 'otec', [['Plur', 'P', 'Gen', '2']]],
                'otcové'  => ['otec', 'otec', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'otcovi'  => ['otec', 'otec', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'otcu'    => ['otec', 'otec', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'otcú'    => ['otec', 'otec', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'otcuom'  => ['otec', 'otec', [['Plur', 'P', 'Dat', '3']]],
                'otcuov'  => ['otec', 'otec', [['Plur', 'P', 'Gen', '2']]],
                'otče'    => ['otec', 'otec', [['Sing', 'S', 'Voc', '5']]],
                'otec'    => ['otec', 'otec', [['Sing', 'S', 'Nom', '1']]],
                'pán'     => ['pán', 'pán', [['Sing', 'S', 'Nom', '1']]],
                'pána'    => ['pán', 'pán', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'páne'    => ['pán', 'pán', [['Sing', 'S', 'Voc', '5']]],
                'páně'    => ['pán', 'pán', [['Sing', 'S', 'Loc', '6']]],
                'pánem'   => ['pán', 'pán', [['Sing', 'S', 'Ins', '7']]],
                'páni'    => ['pán', 'pán', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'pánie'   => ['pán', 'pán', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'pániech' => ['pán', 'pán', [['Plur', 'P', 'Loc', '6']]],
                'pánóm'   => ['pán', 'pán', [['Plur', 'P', 'Dat', '3']]],
                'pánoma'  => ['pán', 'pán', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'pánóv'   => ['pán', 'pán', [['Plur', 'P', 'Gen', '2']]],
                'pánové'  => ['pán', 'pán', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'pánovi'  => ['pán', 'pán', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'pánu'    => ['pán', 'pán', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'pánú'    => ['pán', 'pán', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'pánuom'  => ['pán', 'pán', [['Plur', 'P', 'Dat', '3']]],
                'pánuov'  => ['pán', 'pán', [['Plur', 'P', 'Gen', '2']]],
                'pány'    => ['pán', 'pán', [['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Ins', '7']]],
                'panoš'     => ['panoš', 'panoše', [['Sing', 'S', 'Nom', '1']]],
                'panoša'    => ['panoš', 'panoše', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'panoše'    => ['panoš', 'panoše', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4'], ['Sing', 'S', 'Voc', '5'], ['Plur', 'P', 'Acc', '4']]],
                'panošě'    => ['panoš', 'panoše', [['Sing', 'S', 'Loc', '6'], ['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5']]],
                'panošem'   => ['panoš', 'panoše', [['Sing', 'S', 'Ins', '7']]],
                'panošěmi'  => ['panoš', 'panoše', [['Plur', 'P', 'Ins', '7']]],
                'panoši'    => ['panoš', 'panoše', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5'], ['Plur', 'P', 'Ins', '7']]],
                'panoší'    => ['panoš', 'panoše', [['Sing', 'S', 'Ins', '7'], ['Plur', 'P', 'Gen', '2']]],
                'panošicě'  => ['panoš', 'panoše', [['Sing', 'S', 'Nom', '1'], ['Plur', 'P', 'Nom', '1']]],
                'panošie'   => ['panoš', 'panoše', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'panošiech' => ['panoš', 'panoše', [['Plur', 'P', 'Loc', '6']]],
                'panošiem'  => ['panoš', 'panoše', [['Sing', 'S', 'Ins', '7']]],
                'panošiev'  => ['panoš', 'panoše', [['Plur', 'P', 'Gen', '2']]],
                'panošóm'   => ['panoš', 'panoše', [['Plur', 'P', 'Dat', '3']]],
                'panošoma'  => ['panoš', 'panoše', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'panošóv'   => ['panoš', 'panoše', [['Plur', 'P', 'Gen', '2']]],
                'panošové'  => ['panoš', 'panoše', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'panošovi'  => ['panoš', 'panoše', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'panošu'    => ['panoš', 'panoše', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'panošú'    => ['panoš', 'panoše', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'panošuom'  => ['panoš', 'panoše', [['Plur', 'P', 'Dat', '3']]],
                'panošuov'  => ['panoš', 'panoše', [['Plur', 'P', 'Gen', '2']]],
                'pes'    => ['pes', 'pes', [['Sing', 'S', 'Nom', '1']]],
                'psa'    => ['pes', 'pes', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'pse'    => ['pes', 'pes', [['Sing', 'S', 'Voc', '5']]],
                'psě'    => ['pes', 'pes', [['Sing', 'S', 'Loc', '6']]],
                'psem'   => ['pes', 'pes', [['Sing', 'S', 'Ins', '7']]],
                'psi'    => ['pes', 'pes', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'psí'    => ['pes', 'pes', [['Plur', 'P', 'Gen', '2']]],
                'psie'   => ['pes', 'pes', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'psiech' => ['pes', 'pes', [['Plur', 'P', 'Loc', '6']]],
                'psóm'   => ['pes', 'pes', [['Plur', 'P', 'Dat', '3']]],
                'psoma'  => ['pes', 'pes', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'psóv'   => ['pes', 'pes', [['Plur', 'P', 'Gen', '2']]],
                'psové'  => ['pes', 'pes', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'psovi'  => ['pes', 'pes', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'psu'    => ['pes', 'pes', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'psú'    => ['pes', 'pes', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'psuom'  => ['pes', 'pes', [['Plur', 'P', 'Dat', '3']]],
                'psuov'  => ['pes', 'pes', [['Plur', 'P', 'Gen', '2']]],
                'psy'    => ['pes', 'pes', [['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Ins', '7']]],
                'pisca'    => ['pisec', 'pisec', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'pisce'    => ['pisec', 'pisec', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4'], ['Plur', 'P', 'Acc', '4']]],
                'piscě'    => ['pisec', 'pisec', [['Sing', 'S', 'Loc', '6'], ['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5']]],
                'piscem'   => ['pisec', 'pisec', [['Sing', 'S', 'Ins', '7']]],
                'pisci'    => ['pisec', 'pisec', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5'], ['Plur', 'P', 'Ins', '7']]],
                'piscie'   => ['pisec', 'pisec', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'pisciech' => ['pisec', 'pisec', [['Plur', 'P', 'Loc', '6']]],
                'pisciem'  => ['pisec', 'pisec', [['Sing', 'S', 'Ins', '7']]],
                'piscóm'   => ['pisec', 'pisec', [['Plur', 'P', 'Dat', '3']]],
                'piscoma'  => ['pisec', 'pisec', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'piscóv'   => ['pisec', 'pisec', [['Plur', 'P', 'Gen', '2']]],
                'piscové'  => ['pisec', 'pisec', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'piscovi'  => ['pisec', 'pisec', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'piscu'    => ['pisec', 'pisec', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'piscú'    => ['pisec', 'pisec', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'piscuom'  => ['pisec', 'pisec', [['Plur', 'P', 'Dat', '3']]],
                'piscuov'  => ['pisec', 'pisec', [['Plur', 'P', 'Gen', '2']]],
                'pisče'    => ['pisec', 'pisec', [['Sing', 'S', 'Voc', '5']]],
                'pisec'    => ['pisec', 'pisec', [['Sing', 'S', 'Nom', '1']]],
                'pohan'     => ['pohan', 'pohan', [['Sing', 'S', 'Nom', '1']]],
                'pohana'    => ['pohan', 'pohan', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'pohane'    => ['pohan', 'pohan', [['Sing', 'S', 'Voc', '5']]],
                'pohané'    => ['pohan', 'pohan', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'pohaně'    => ['pohan', 'pohan', [['Sing', 'S', 'Loc', '6']]],
                'pohanem'   => ['pohan', 'pohan', [['Sing', 'S', 'Ins', '7']]],
                'pohani'    => ['pohan', 'pohan', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'pohanie'   => ['pohan', 'pohan', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'pohaniech' => ['pohan', 'pohan', [['Plur', 'P', 'Loc', '6']]],
                'pohanóm'   => ['pohan', 'pohan', [['Plur', 'P', 'Dat', '3']]],
                'pohanoma'  => ['pohan', 'pohan', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'pohanóv'   => ['pohan', 'pohan', [['Plur', 'P', 'Gen', '2']]],
                'pohanové'  => ['pohan', 'pohan', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'pohanovi'  => ['pohan', 'pohan', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'pohanu'    => ['pohan', 'pohan', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'pohanú'    => ['pohan', 'pohan', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'pohanuom'  => ['pohan', 'pohan', [['Plur', 'P', 'Dat', '3']]],
                'pohanuov'  => ['pohan', 'pohan', [['Plur', 'P', 'Gen', '2']]],
                'pohany'    => ['pohan', 'pohan', [['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Ins', '7']]],
                'pop'     => ['pop', 'pop', [['Sing', 'S', 'Nom', '1']]],
                'popa'    => ['pop', 'pop', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'pope'    => ['pop', 'pop', [['Sing', 'S', 'Voc', '5']]],
                'popě'    => ['pop', 'pop', [['Sing', 'S', 'Loc', '6']]],
                'popem'   => ['pop', 'pop', [['Sing', 'S', 'Ins', '7']]],
                'popi'    => ['pop', 'pop', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'popie'   => ['pop', 'pop', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'popiech' => ['pop', 'pop', [['Plur', 'P', 'Loc', '6']]],
                'popóm'   => ['pop', 'pop', [['Plur', 'P', 'Dat', '3']]],
                'popoma'  => ['pop', 'pop', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'popóv'   => ['pop', 'pop', [['Plur', 'P', 'Gen', '2']]],
                'popové'  => ['pop', 'pop', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'popovi'  => ['pop', 'pop', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'popu'    => ['pop', 'pop', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'popú'    => ['pop', 'pop', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'popuom'  => ['pop', 'pop', [['Plur', 'P', 'Dat', '3']]],
                'popuov'  => ['pop', 'pop', [['Plur', 'P', 'Gen', '2']]],
                'popy'    => ['pop', 'pop', [['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Ins', '7']]],
                'prorocě'    => ['prorok', 'prorok', [['Sing', 'S', 'Loc', '6']]],
                'proroci'    => ['prorok', 'prorok', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'prorocie'   => ['prorok', 'prorok', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'prorociech' => ['prorok', 'prorok', [['Plur', 'P', 'Loc', '6']]],
                'proroče'    => ['prorok', 'prorok', [['Sing', 'S', 'Voc', '5']]],
                'prorok'     => ['prorok', 'prorok', [['Sing', 'S', 'Nom', '1']]],
                'proroka'    => ['prorok', 'prorok', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'prorokem'   => ['prorok', 'prorok', [['Sing', 'S', 'Ins', '7']]],
                'prorokóm'   => ['prorok', 'prorok', [['Plur', 'P', 'Dat', '3']]],
                'prorokoma'  => ['prorok', 'prorok', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'prorokóv'   => ['prorok', 'prorok', [['Plur', 'P', 'Gen', '2']]],
                'prorokové'  => ['prorok', 'prorok', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'prorokovi'  => ['prorok', 'prorok', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'proroku'    => ['prorok', 'prorok', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Voc', '5'], ['Sing', 'S', 'Loc', '6']]],
                'prorokú'    => ['prorok', 'prorok', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'prorokuom'  => ['prorok', 'prorok', [['Plur', 'P', 'Dat', '3']]],
                'prorokuov'  => ['prorok', 'prorok', [['Plur', 'P', 'Gen', '2']]],
                'proroky'    => ['prorok', 'prorok', [['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Ins', '7']]],
                'přietel'     => ['přítel', 'přietel', [['Sing', 'S', 'Nom', '1']]],
                'přietela'    => ['přítel', 'přietel', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'přietele'    => ['přítel', 'přietel', [['Sing', 'S', 'Voc', '5']]],
                'přietelé'    => ['přítel', 'přietel', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'přietelě'    => ['přítel', 'přietel', [['Sing', 'S', 'Loc', '6']]],
                'přietelem'   => ['přítel', 'přietel', [['Sing', 'S', 'Ins', '7']]],
                'přieteli'    => ['přítel', 'přietel', [['Sing', 'S', 'Voc', '5'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'přietelie'   => ['přítel', 'přietel', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'přieteliech' => ['přítel', 'přietel', [['Plur', 'P', 'Loc', '6']]],
                'přietelóm'   => ['přítel', 'přietel', [['Plur', 'P', 'Dat', '3']]],
                'přieteloma'  => ['přítel', 'přietel', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'přietelóv'   => ['přítel', 'přietel', [['Plur', 'P', 'Gen', '2']]],
                'přietelové'  => ['přítel', 'přietel', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'přietelovi'  => ['přítel', 'přietel', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'přietelu'    => ['přítel', 'přietel', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'přietelú'    => ['přítel', 'přietel', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'přieteluom'  => ['přítel', 'přietel', [['Plur', 'P', 'Dat', '3']]],
                'přieteluov'  => ['přítel', 'přietel', [['Plur', 'P', 'Gen', '2']]],
                'rybář'     => ['rybář', 'rybář', [['Sing', 'S', 'Nom', '1']]],
                'rybářa'    => ['rybář', 'rybář', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'rybáře'    => ['rybář', 'rybář', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4'], ['Sing', 'S', 'Voc', '5'], ['Plur', 'P', 'Acc', '4']]],
                'rybářě'    => ['rybář', 'rybář', [['Sing', 'S', 'Loc', '6'], ['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5']]],
                'rybářem'   => ['rybář', 'rybář', [['Sing', 'S', 'Ins', '7']]],
                'rybáři'    => ['rybář', 'rybář', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5'], ['Plur', 'P', 'Ins', '7']]],
                'rybářie'   => ['rybář', 'rybář', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'rybářiech' => ['rybář', 'rybář', [['Plur', 'P', 'Loc', '6']]],
                'rybářiem'  => ['rybář', 'rybář', [['Sing', 'S', 'Ins', '7']]],
                'rybářóm'   => ['rybář', 'rybář', [['Plur', 'P', 'Dat', '3']]],
                'rybářoma'  => ['rybář', 'rybář', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'rybářóv'   => ['rybář', 'rybář', [['Plur', 'P', 'Gen', '2']]],
                'rybářové'  => ['rybář', 'rybář', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'rybářovi'  => ['rybář', 'rybář', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'rybářu'    => ['rybář', 'rybář', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'rybářú'    => ['rybář', 'rybář', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'rybářuom'  => ['rybář', 'rybář', [['Plur', 'P', 'Dat', '3']]],
                'rybářuov'  => ['rybář', 'rybář', [['Plur', 'P', 'Gen', '2']]],
                'rytieř'     => ['rytíř', 'rytieř', [['Sing', 'S', 'Nom', '1']]],
                'rytieřa'    => ['rytíř', 'rytieř', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'rytieře'    => ['rytíř', 'rytieř', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4'], ['Sing', 'S', 'Voc', '5'], ['Plur', 'P', 'Acc', '4']]],
                'rytieřě'    => ['rytíř', 'rytieř', [['Sing', 'S', 'Loc', '6'], ['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5']]],
                'rytieřem'   => ['rytíř', 'rytieř', [['Sing', 'S', 'Ins', '7']]],
                'rytieři'    => ['rytíř', 'rytieř', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5'], ['Plur', 'P', 'Ins', '7']]],
                'rytieří'    => ['rytíř', 'rytieř', [['Dual', 'D', 'Gen', '2']]],
                'rytieřie'   => ['rytíř', 'rytieř', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'rytieřiech' => ['rytíř', 'rytieř', [['Plur', 'P', 'Loc', '6']]],
                'rytieřiem'  => ['rytíř', 'rytieř', [['Sing', 'S', 'Ins', '7']]],
                'rytieřiev'  => ['rytíř', 'rytieř', [['Plur', 'P', 'Gen', '2']]],
                'rytieřóm'   => ['rytíř', 'rytieř', [['Plur', 'P', 'Dat', '3']]],
                'rytieřoma'  => ['rytíř', 'rytieř', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'rytieřóv'   => ['rytíř', 'rytieř', [['Plur', 'P', 'Gen', '2']]],
                'rytieřové'  => ['rytíř', 'rytieř', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'rytieřovi'  => ['rytíř', 'rytieř', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'rytieřu'    => ['rytíř', 'rytieř', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'rytieřú'    => ['rytíř', 'rytieř', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'rytieřuom'  => ['rytíř', 'rytieř', [['Plur', 'P', 'Dat', '3']]],
                'rytieřuov'  => ['rytíř', 'rytieř', [['Plur', 'P', 'Gen', '2']]],
                'satan'     => ['satan', 'satan', [['Sing', 'S', 'Nom', '1']]],
                'satana'    => ['satan', 'satan', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'satanas'   => ['satan', 'satan', [['Sing', 'S', 'Voc', '5']]],
                'satane'    => ['satan', 'satan', [['Sing', 'S', 'Voc', '5']]],
                'sataně'    => ['satan', 'satan', [['Sing', 'S', 'Loc', '6']]],
                'satanem'   => ['satan', 'satan', [['Sing', 'S', 'Ins', '7']]],
                'satani'    => ['satan', 'satan', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'satanie'   => ['satan', 'satan', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'sataniech' => ['satan', 'satan', [['Plur', 'P', 'Loc', '6']]],
                'satanóm'   => ['satan', 'satan', [['Plur', 'P', 'Dat', '3']]],
                'satanoma'  => ['satan', 'satan', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'satanóv'   => ['satan', 'satan', [['Plur', 'P', 'Gen', '2']]],
                'satanové'  => ['satan', 'satan', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'satanovi'  => ['satan', 'satan', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'satanu'    => ['satan', 'satan', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'satanú'    => ['satan', 'satan', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'satanuom'  => ['satan', 'satan', [['Plur', 'P', 'Dat', '3']]],
                'satanuov'  => ['satan', 'satan', [['Plur', 'P', 'Gen', '2']]],
                'satany'    => ['satan', 'satan', [['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Ins', '7']]],
                'sathana'   => ['satan', 'satan', [['Sing', 'S', 'Voc', '5']]],
                'sluh'    => ['sluha', 'sluha', [['Plur', 'P', 'Gen', '2']]],
                'slúh'    => ['sluha', 'sluha', [['Plur', 'P', 'Gen', '2']]],
                'sluha'   => ['sluha', 'sluha', [['Sing', 'S', 'Nom', '1']]],
                'slúha'   => ['sluha', 'sluha', [['Sing', 'S', 'Nom', '1']]],
                'sluhách' => ['sluha', 'sluha', [['Plur', 'P', 'Loc', '6']]],
                'slúhách' => ['sluha', 'sluha', [['Plur', 'P', 'Loc', '6']]],
                'sluhám'  => ['sluha', 'sluha', [['Plur', 'P', 'Dat', '3']]],
                'slúhám'  => ['sluha', 'sluha', [['Plur', 'P', 'Dat', '3']]],
                'sluhami' => ['sluha', 'sluha', [['Plur', 'P', 'Ins', '7']]],
                'slúhami' => ['sluha', 'sluha', [['Plur', 'P', 'Ins', '7']]],
                'sluho'   => ['sluha', 'sluha', [['Sing', 'S', 'Voc', '5']]],
                'slúho'   => ['sluha', 'sluha', [['Sing', 'S', 'Voc', '5']]],
                'sluhou'  => ['sluha', 'sluha', [['Sing', 'S', 'Ins', '7']]],
                'slúhou'  => ['sluha', 'sluha', [['Sing', 'S', 'Ins', '7']]],
                'sluhu'   => ['sluha', 'sluha', [['Sing', 'S', 'Acc', '4']]],
                'sluhú'   => ['sluha', 'sluha', [['Sing', 'S', 'Ins', '7']]],
                'slúhu'   => ['sluha', 'sluha', [['Sing', 'S', 'Acc', '4']]],
                'slúhú'   => ['sluha', 'sluha', [['Sing', 'S', 'Ins', '7']]],
                'sluhy'   => ['sluha', 'sluha', [['Sing', 'S', 'Gen', '2'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5']]],
                'slúhy'   => ['sluha', 'sluha', [['Sing', 'S', 'Gen', '2'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5']]],
                'sluze'   => ['sluha', 'sluha', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'sluzě'   => ['sluha', 'sluha', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6'], ['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5']]],
                'slúze'   => ['sluha', 'sluha', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'slúzě'   => ['sluha', 'sluha', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6'], ['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5']]],
                'starost'    => ['starosta', 'starosta', [['Plur', 'P', 'Gen', '2']]],
                'starosta'   => ['starosta', 'starosta', [['Sing', 'S', 'Nom', '1']]],
                'starostách' => ['starosta', 'starosta', [['Plur', 'P', 'Loc', '6']]],
                'starostám'  => ['starosta', 'starosta', [['Plur', 'P', 'Dat', '3']]],
                'starostami' => ['starosta', 'starosta', [['Plur', 'P', 'Ins', '7']]],
                'starostě'   => ['starosta', 'starosta', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6'], ['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5']]],
                'starosto'   => ['starosta', 'starosta', [['Sing', 'S', 'Voc', '5']]],
                'starostou'  => ['starosta', 'starosta', [['Sing', 'S', 'Ins', '7']]],
                'starostu'   => ['starosta', 'starosta', [['Sing', 'S', 'Acc', '4']]],
                'starostú'   => ['starosta', 'starosta', [['Sing', 'S', 'Ins', '7']]],
                'starosty'   => ['starosta', 'starosta', [['Sing', 'S', 'Gen', '2'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5']]],
                'súdc'     => ['soudce', 'súdcě', [['Plur', 'P', 'Gen', '2']]],
                'súdce'    => ['soudce', 'súdcě', [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Voc', '5'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5']]],
                'súdcě'    => ['soudce', 'súdcě', [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Voc', '5'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5']]],
                'súdcemi'  => ['soudce', 'súdcě', [['Plur', 'P', 'Ins', '7']]],
                'súdcěmi'  => ['soudce', 'súdcě', [['Plur', 'P', 'Ins', '7']]],
                'súdci'    => ['soudce', 'súdcě', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Acc', '4'], ['Sing', 'S', 'Loc', '6']]],
                'súdcí'    => ['soudce', 'súdcě', [['Sing', 'S', 'Ins', '7']]],
                'súdcie'   => ['soudce', 'súdcě', [['Plur', 'P', 'Voc', '5']]],
                'súdciech' => ['soudce', 'súdcě', [['Plur', 'P', 'Loc', '6']]],
                'súdciem'  => ['soudce', 'súdcě', [['Plur', 'P', 'Dat', '3']]],
                'súdcích'  => ['soudce', 'súdcě', [['Plur', 'P', 'Loc', '6']]],
                'súdcím'   => ['soudce', 'súdcě', [['Plur', 'P', 'Dat', '3']]],
                'súdcu'    => ['soudce', 'súdcě', [['Sing', 'S', 'Acc', '4']]],
                'svědcě'    => ['svědek', 'svědek', [['Sing', 'S', 'Loc', '6']]],
                'svědci'    => ['svědek', 'svědek', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'svědcie'   => ['svědek', 'svědek', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'svědciech' => ['svědek', 'svědek', [['Plur', 'P', 'Loc', '6']]],
                'svědče'    => ['svědek', 'svědek', [['Sing', 'S', 'Voc', '5']]],
                'svědek'    => ['svědek', 'svědek', [['Sing', 'S', 'Nom', '1']]],
                'svědka'    => ['svědek', 'svědek', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'svědkem'   => ['svědek', 'svědek', [['Sing', 'S', 'Ins', '7']]],
                'svědkóm'   => ['svědek', 'svědek', [['Plur', 'P', 'Dat', '3']]],
                'svědkoma'  => ['svědek', 'svědek', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'svědkóv'   => ['svědek', 'svědek', [['Plur', 'P', 'Gen', '2']]],
                'svědkové'  => ['svědek', 'svědek', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'svědkovi'  => ['svědek', 'svědek', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'svědku'    => ['svědek', 'svědek', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Voc', '5'], ['Sing', 'S', 'Loc', '6']]],
                'svědkú'    => ['svědek', 'svědek', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'svědkuom'  => ['svědek', 'svědek', [['Plur', 'P', 'Dat', '3']]],
                'svědkuov'  => ['svědek', 'svědek', [['Plur', 'P', 'Gen', '2']]],
                'svědky'    => ['svědek', 'svědek', [['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Ins', '7']]],
                'syn'     => ['syn', 'syn', [['Sing', 'S', 'Nom', '1']]],
                'syna'    => ['syn', 'syn', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'syne'    => ['syn', 'syn', [['Sing', 'S', 'Voc', '5']]],
                'syně'    => ['syn', 'syn', [['Sing', 'S', 'Loc', '6']]],
                'synem'   => ['syn', 'syn', [['Sing', 'S', 'Ins', '7']]],
                'syni'    => ['syn', 'syn', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'synie'   => ['syn', 'syn', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'syniech' => ['syn', 'syn', [['Plur', 'P', 'Loc', '6']]],
                'synóm'   => ['syn', 'syn', [['Plur', 'P', 'Dat', '3']]],
                'synoma'  => ['syn', 'syn', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'synóv'   => ['syn', 'syn', [['Plur', 'P', 'Gen', '2']]],
                'synové'  => ['syn', 'syn', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'synovi'  => ['syn', 'syn', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'synu'    => ['syn', 'syn', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'synú'    => ['syn', 'syn', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'synuom'  => ['syn', 'syn', [['Plur', 'P', 'Dat', '3']]],
                'synuov'  => ['syn', 'syn', [['Plur', 'P', 'Gen', '2']]],
                'syny'    => ['syn', 'syn', [['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Ins', '7']]],
                'šielenca'    => ['šílenec', 'šielenec', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'šielence'    => ['šílenec', 'šielenec', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4'], ['Plur', 'P', 'Acc', '4']]],
                'šielencě'    => ['šílenec', 'šielenec', [['Sing', 'S', 'Loc', '6'], ['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5']]],
                'šielencem'   => ['šílenec', 'šielenec', [['Sing', 'S', 'Ins', '7']]],
                'šielenci'    => ['šílenec', 'šielenec', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5'], ['Plur', 'P', 'Ins', '7']]],
                'šielencie'   => ['šílenec', 'šielenec', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'šielenciech' => ['šílenec', 'šielenec', [['Plur', 'P', 'Loc', '6']]],
                'šielenciem'  => ['šílenec', 'šielenec', [['Sing', 'S', 'Ins', '7']]],
                'šielenciev'  => ['šílenec', 'šielenec', [['Plur', 'P', 'Gen', '2']]],
                'šielencóm'   => ['šílenec', 'šielenec', [['Plur', 'P', 'Dat', '3']]],
                'šielencoma'  => ['šílenec', 'šielenec', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'šielencóv'   => ['šílenec', 'šielenec', [['Plur', 'P', 'Gen', '2']]],
                'šielencové'  => ['šílenec', 'šielenec', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'šielencovi'  => ['šílenec', 'šielenec', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'šielencu'    => ['šílenec', 'šielenec', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'šielencú'    => ['šílenec', 'šielenec', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'šielencuom'  => ['šílenec', 'šielenec', [['Plur', 'P', 'Dat', '3']]],
                'šielencuov'  => ['šílenec', 'šielenec', [['Plur', 'P', 'Gen', '2']]],
                'šielenče'    => ['šílenec', 'šielenec', [['Sing', 'S', 'Voc', '5']]],
                'šielenec'    => ['šílenec', 'šielenec', [['Sing', 'S', 'Nom', '1']]],
                'tetrarch'    => ['tetrarcha', 'tetrarcha', [['Plur', 'P', 'Gen', '2']]],
                'tetrarcha'   => ['tetrarcha', 'tetrarcha', [['Sing', 'S', 'Nom', '1']]],
                'tetrarchách' => ['tetrarcha', 'tetrarcha', [['Plur', 'P', 'Loc', '6']]],
                'tetrarchám'  => ['tetrarcha', 'tetrarcha', [['Plur', 'P', 'Dat', '3']]],
                'tetrarchami' => ['tetrarcha', 'tetrarcha', [['Plur', 'P', 'Ins', '7']]],
                'tetrarcho'   => ['tetrarcha', 'tetrarcha', [['Sing', 'S', 'Voc', '5']]],
                'tetrarchou'  => ['tetrarcha', 'tetrarcha', [['Sing', 'S', 'Ins', '7']]],
                'tetrarchu'   => ['tetrarcha', 'tetrarcha', [['Sing', 'S', 'Acc', '4']]],
                'tetrarchú'   => ['tetrarcha', 'tetrarcha', [['Sing', 'S', 'Ins', '7']]],
                'tetrarchy'   => ['tetrarcha', 'tetrarcha', [['Sing', 'S', 'Gen', '2'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5']]],
                'tetrarše'    => ['tetrarcha', 'tetrarcha', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'tetraršě'    => ['tetrarcha', 'tetrarcha', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6'], ['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5']]],
                'tovařiš'     => ['tovaryš', 'tovařiš', [['Sing', 'S', 'Nom', '1']]],
                'tovařiša'    => ['tovaryš', 'tovařiš', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'tovařiše'    => ['tovaryš', 'tovařiš', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4'], ['Sing', 'S', 'Voc', '5'], ['Plur', 'P', 'Acc', '4']]],
                'tovařišě'    => ['tovaryš', 'tovařiš', [['Sing', 'S', 'Loc', '6'], ['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5']]],
                'tovařišem'   => ['tovaryš', 'tovařiš', [['Sing', 'S', 'Ins', '7']]],
                'tovařiši'    => ['tovaryš', 'tovařiš', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5'], ['Plur', 'P', 'Ins', '7']]],
                'tovařišie'   => ['tovaryš', 'tovařiš', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'tovařišiech' => ['tovaryš', 'tovařiš', [['Plur', 'P', 'Loc', '6']]],
                'tovařišiem'  => ['tovaryš', 'tovařiš', [['Sing', 'S', 'Ins', '7']]],
                'tovařišiev'  => ['tovaryš', 'tovařiš', [['Plur', 'P', 'Gen', '2']]],
                'tovařišóm'   => ['tovaryš', 'tovařiš', [['Plur', 'P', 'Dat', '3']]],
                'tovařišoma'  => ['tovaryš', 'tovařiš', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'tovařišóv'   => ['tovaryš', 'tovařiš', [['Plur', 'P', 'Gen', '2']]],
                'tovařišové'  => ['tovaryš', 'tovařiš', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'tovařišovi'  => ['tovaryš', 'tovařiš', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'tovařišu'    => ['tovaryš', 'tovařiš', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'tovařišú'    => ['tovaryš', 'tovařiš', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'tovařišuom'  => ['tovaryš', 'tovařiš', [['Plur', 'P', 'Dat', '3']]],
                'tovařišuov'  => ['tovaryš', 'tovařiš', [['Plur', 'P', 'Gen', '2']]],
                'učedlnícě'    => ['učedník', 'učedlník', [['Sing', 'S', 'Loc', '6']]],
                'učedlníci'    => ['učedník', 'učedlník', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'učedlnície'   => ['učedník', 'učedlník', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'učedlníciech' => ['učedník', 'učedlník', [['Plur', 'P', 'Loc', '6']]],
                'učedlníče'    => ['učedník', 'učedlník', [['Sing', 'S', 'Voc', '5']]],
                'učedlník'     => ['učedník', 'učedlník', [['Sing', 'S', 'Nom', '1']]],
                'učedlníka'    => ['učedník', 'učedlník', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'učedlníkem'   => ['učedník', 'učedlník', [['Sing', 'S', 'Ins', '7']]],
                'učedlníkóm'   => ['učedník', 'učedlník', [['Plur', 'P', 'Dat', '3']]],
                'učedlníkoma'  => ['učedník', 'učedlník', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'učedlníkóv'   => ['učedník', 'učedlník', [['Plur', 'P', 'Gen', '2']]],
                'učedlníkové'  => ['učedník', 'učedlník', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'učedlníkovi'  => ['učedník', 'učedlník', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'učedlníku'    => ['učedník', 'učedlník', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Voc', '5'], ['Sing', 'S', 'Loc', '6']]],
                'učedlníkú'    => ['učedník', 'učedlník', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'učedlníkuom'  => ['učedník', 'učedlník', [['Plur', 'P', 'Dat', '3']]],
                'učedlníkuov'  => ['učedník', 'učedlník', [['Plur', 'P', 'Gen', '2']]],
                'učedlníky'    => ['učedník', 'učedlník', [['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Ins', '7']]],
                'učennícě'     => ['učedník', 'učedlník', [['Sing', 'S', 'Loc', '6']]],
                'učenníci'     => ['učedník', 'učedlník', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'učennície'    => ['učedník', 'učedlník', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'učenníciech'  => ['učedník', 'učedlník', [['Plur', 'P', 'Loc', '6']]],
                'učenníče'     => ['učedník', 'učedlník', [['Sing', 'S', 'Voc', '5']]],
                'učenník'      => ['učedník', 'učedlník', [['Sing', 'S', 'Nom', '1']]],
                'učenníka'     => ['učedník', 'učedlník', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'učenníkem'    => ['učedník', 'učedlník', [['Sing', 'S', 'Ins', '7']]],
                'učenníkóm'    => ['učedník', 'učedlník', [['Plur', 'P', 'Dat', '3']]],
                'učenníkoma'   => ['učedník', 'učedlník', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'učenníkóv'    => ['učedník', 'učedlník', [['Plur', 'P', 'Gen', '2']]],
                'učenníkové'   => ['učedník', 'učedlník', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'učenníkovi'   => ['učedník', 'učedlník', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'učenníku'     => ['učedník', 'učedlník', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Voc', '5'], ['Sing', 'S', 'Loc', '6']]],
                'učenníkú'     => ['učedník', 'učedlník', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'učenníkuom'   => ['učedník', 'učedlník', [['Plur', 'P', 'Dat', '3']]],
                'učenníkuov'   => ['učedník', 'učedlník', [['Plur', 'P', 'Gen', '2']]],
                'učenníky'     => ['učedník', 'učedlník', [['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Ins', '7']]],
                'velblúd'     => ['velbloud', 'velblúd', [['Sing', 'S', 'Nom', '1']]],
                'velblúda'    => ['velbloud', 'velblúd', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'velblúde'    => ['velbloud', 'velblúd', [['Sing', 'S', 'Voc', '5']]],
                'velblúdě'    => ['velbloud', 'velblúd', [['Sing', 'S', 'Loc', '6']]],
                'velblúdem'   => ['velbloud', 'velblúd', [['Sing', 'S', 'Ins', '7']]],
                'velblúdi'    => ['velbloud', 'velblúd', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'velblúdie'   => ['velbloud', 'velblúd', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'velblúdiech' => ['velbloud', 'velblúd', [['Plur', 'P', 'Loc', '6']]],
                'velblúdóm'   => ['velbloud', 'velblúd', [['Plur', 'P', 'Dat', '3']]],
                'velblúdoma'  => ['velbloud', 'velblúd', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'velblúdóv'   => ['velbloud', 'velblúd', [['Plur', 'P', 'Gen', '2']]],
                'velblúdové'  => ['velbloud', 'velblúd', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'velblúdovi'  => ['velbloud', 'velblúd', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'velblúdu'    => ['velbloud', 'velblúd', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'velblúdú'    => ['velbloud', 'velblúd', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'velblúduom'  => ['velbloud', 'velblúd', [['Plur', 'P', 'Dat', '3']]],
                'velblúduov'  => ['velbloud', 'velblúd', [['Plur', 'P', 'Gen', '2']]],
                'velblúdy'    => ['velbloud', 'velblúd', [['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Ins', '7']]],
                'vodič'     => ['vodič', 'vodič', [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Acc', '4']]],
                'vodiča'    => ['vodič', 'vodič', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'vodiče'    => ['vodič', 'vodič', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4'], ['Sing', 'S', 'Voc', '5'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5']]],
                'vodičě'    => ['vodič', 'vodič', [['Sing', 'S', 'Loc', '6'], ['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5']]],
                'vodičem'   => ['vodič', 'vodič', [['Sing', 'S', 'Ins', '7']]],
                'vodičěvé'  => ['vodič', 'vodič', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'vodiči'    => ['vodič', 'vodič', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5'], ['Plur', 'P', 'Ins', '7']]],
                'vodičí'    => ['vodič', 'vodič', [['Dual', 'D', 'Gen', '2']]],
                'vodičie'   => ['vodič', 'vodič', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'vodičiech' => ['vodič', 'vodič', [['Plur', 'P', 'Loc', '6']]],
                'vodičiem'  => ['vodič', 'vodič', [['Sing', 'S', 'Ins', '7']]],
                'vodičiev'  => ['vodič', 'vodič', [['Plur', 'P', 'Gen', '2']]],
                'vodičóm'   => ['vodič', 'vodič', [['Plur', 'P', 'Dat', '3']]],
                'vodičoma'  => ['vodič', 'vodič', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'vodičóv'   => ['vodič', 'vodič', [['Plur', 'P', 'Gen', '2']]],
                'vodičové'  => ['vodič', 'vodič', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'vodičovi'  => ['vodič', 'vodič', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'vodiču'    => ['vodič', 'vodič', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'vodičú'    => ['vodič', 'vodič', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'vodičuom'  => ['vodič', 'vodič', [['Plur', 'P', 'Dat', '3']]],
                'vodičuov'  => ['vodič', 'vodič', [['Plur', 'P', 'Gen', '2']]],
                'vrabca'    => ['vrabec', 'vrabec', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'vrabce'    => ['vrabec', 'vrabec', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4'], ['Plur', 'P', 'Acc', '4']]],
                'vrabcě'    => ['vrabec', 'vrabec', [['Sing', 'S', 'Loc', '6'], ['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5']]],
                'vrabcem'   => ['vrabec', 'vrabec', [['Sing', 'S', 'Ins', '7']]],
                'vrabci'    => ['vrabec', 'vrabec', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5'], ['Plur', 'P', 'Ins', '7']]],
                'vrabcie'   => ['vrabec', 'vrabec', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'vrabciech' => ['vrabec', 'vrabec', [['Plur', 'P', 'Loc', '6']]],
                'vrabciem'  => ['vrabec', 'vrabec', [['Sing', 'S', 'Ins', '7']]],
                'vrabciev'  => ['vrabec', 'vrabec', [['Plur', 'P', 'Gen', '2']]],
                'vrabcóm'   => ['vrabec', 'vrabec', [['Plur', 'P', 'Dat', '3']]],
                'vrabcoma'  => ['vrabec', 'vrabec', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'vrabcóv'   => ['vrabec', 'vrabec', [['Plur', 'P', 'Gen', '2']]],
                'vrabcové'  => ['vrabec', 'vrabec', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'vrabcovi'  => ['vrabec', 'vrabec', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'vrabcu'    => ['vrabec', 'vrabec', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'vrabcú'    => ['vrabec', 'vrabec', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'vrabcuom'  => ['vrabec', 'vrabec', [['Plur', 'P', 'Dat', '3']]],
                'vrabcuov'  => ['vrabec', 'vrabec', [['Plur', 'P', 'Gen', '2']]],
                'vrabče'    => ['vrabec', 'vrabec', [['Sing', 'S', 'Voc', '5']]],
                'vrabec'    => ['vrabec', 'vrabec', [['Sing', 'S', 'Nom', '1']]],
                'zjěvnícě'    => ['zjevník', 'zjěvník', [['Sing', 'S', 'Loc', '6']]],
                'zjěvníci'    => ['zjevník', 'zjěvník', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'zjěvnície'   => ['zjevník', 'zjěvník', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'zjěvníciech' => ['zjevník', 'zjěvník', [['Plur', 'P', 'Loc', '6']]],
                'zjěvníče'    => ['zjevník', 'zjěvník', [['Sing', 'S', 'Voc', '5']]],
                'zjěvník'     => ['zjevník', 'zjěvník', [['Sing', 'S', 'Nom', '1']]],
                'zjěvníka'    => ['zjevník', 'zjěvník', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'zjěvníkem'   => ['zjevník', 'zjěvník', [['Sing', 'S', 'Ins', '7']]],
                'zjěvníkóm'   => ['zjevník', 'zjěvník', [['Plur', 'P', 'Dat', '3']]],
                'zjěvníkoma'  => ['zjevník', 'zjěvník', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'zjěvníkóv'   => ['zjevník', 'zjěvník', [['Plur', 'P', 'Gen', '2']]],
                'zjěvníkové'  => ['zjevník', 'zjěvník', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'zjěvníkovi'  => ['zjevník', 'zjěvník', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'zjěvníku'    => ['zjevník', 'zjěvník', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Voc', '5'], ['Sing', 'S', 'Loc', '6']]],
                'zjěvníkú'    => ['zjevník', 'zjěvník', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'zjěvníkuom'  => ['zjevník', 'zjěvník', [['Plur', 'P', 'Dat', '3']]],
                'zjěvníkuov'  => ['zjevník', 'zjěvník', [['Plur', 'P', 'Gen', '2']]],
                'zjěvníky'    => ['zjevník', 'zjěvník', [['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Ins', '7']]],
                'ženca'    => ['žnec', 'žnec', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'žence'    => ['žnec', 'žnec', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4'], ['Plur', 'P', 'Acc', '4']]],
                'žencě'    => ['žnec', 'žnec', [['Sing', 'S', 'Loc', '6'], ['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5']]],
                'žencem'   => ['žnec', 'žnec', [['Sing', 'S', 'Ins', '7']]],
                'ženci'    => ['žnec', 'žnec', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5'], ['Plur', 'P', 'Ins', '7']]],
                'žencie'   => ['žnec', 'žnec', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'ženciech' => ['žnec', 'žnec', [['Plur', 'P', 'Loc', '6']]],
                'ženciem'  => ['žnec', 'žnec', [['Sing', 'S', 'Ins', '7']]],
                'ženciev'  => ['žnec', 'žnec', [['Plur', 'P', 'Gen', '2']]],
                'žencóm'   => ['žnec', 'žnec', [['Plur', 'P', 'Dat', '3']]],
                'žencoma'  => ['žnec', 'žnec', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'žencóv'   => ['žnec', 'žnec', [['Plur', 'P', 'Gen', '2']]],
                'žencové'  => ['žnec', 'žnec', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'žencovi'  => ['žnec', 'žnec', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'žencu'    => ['žnec', 'žnec', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'žencú'    => ['žnec', 'žnec', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'žencuom'  => ['žnec', 'žnec', [['Plur', 'P', 'Dat', '3']]],
                'žencuov'  => ['žnec', 'žnec', [['Plur', 'P', 'Gen', '2']]],
                'ženče'    => ['žnec', 'žnec', [['Sing', 'S', 'Voc', '5']]],
                'žnec'     => ['žnec', 'žnec', [['Sing', 'S', 'Nom', '1']]],
                'žid'     => ['žid', 'žid', [['Sing', 'S', 'Nom', '1']]],
                'žida'    => ['žid', 'žid', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'žide'    => ['žid', 'žid', [['Sing', 'S', 'Voc', '5']]],
                'židé'    => ['žid', 'žid', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'židě'    => ['žid', 'žid', [['Sing', 'S', 'Loc', '6']]],
                'židem'   => ['žid', 'žid', [['Sing', 'S', 'Ins', '7']]],
                'židi'    => ['žid', 'žid', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'židie'   => ['žid', 'žid', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'židiech' => ['žid', 'žid', [['Plur', 'P', 'Loc', '6']]],
                'židóm'   => ['žid', 'žid', [['Plur', 'P', 'Dat', '3']]],
                'židoma'  => ['žid', 'žid', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'židóv'   => ['žid', 'žid', [['Plur', 'P', 'Gen', '2']]],
                'židové'  => ['žid', 'žid', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'židovi'  => ['žid', 'žid', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'židu'    => ['žid', 'žid', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'židú'    => ['žid', 'žid', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'židuom'  => ['žid', 'žid', [['Plur', 'P', 'Dat', '3']]],
                'židuov'  => ['žid', 'žid', [['Plur', 'P', 'Gen', '2']]],
                'židy'    => ['žid', 'žid', [['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Ins', '7']]]
            );
            my $ma = $ma{$lform}; die("Something is wrong: '$lform'") if(!defined($ma));
            my ($polarity, $p) = negprefix_to_polarity($negprefix);
            $f[2] = $ma->[0];
            $f[9] = set_lemma1300($f[9], $ma->[1]);
            $f[3] = 'NOUN';
            # U některých slov umožňujeme několik čtení, ale pokud to není žádné z nich, dáme první jako default.
            my @alt = @{$ma->[2]};
            for(my $i = $#alt; $i >= 0 ; $i--)
            {
                if($i == 0 || defined($alt[$i][4]) && get_ref($f[9]) =~ m/^$alt[$i][4]$/ || $f[5] =~ m/Case=$alt[$i][2].*Number=$alt[$i][0]/)
                {
                    $f[4] = 'NNM'.$alt[$i][1].$alt[$i][3].'-----'.$p.'----';
                    $f[5] = 'Animacy=Anim|Case='.$alt[$i][2].'|Gender=Masc|Number='.$alt[$i][0].'|Polarity='.$polarity;
                    last;
                }
            }
        }
        # Koncovka -ovi může být dativ substantiva, nebo přivlastňovací adjektivum v Plur Masc Nom.
        # Přeskočit tuto větev, pokud už UDPipe odhadl, že jde o adjektivum.
        elsif($f[1] =~ m/^(Archelaus|Bar[nr]abáš|Daniel|H?eliáš|H?erod(?:es)?|Izaiáš|Jezukrist(?:us)?|Ježíš|Jozef|Mojžieš|Ozěp|Petr|Pilát|Šalomún|Zebedáš|Zebede)(a|e|ě|u|i|ovi|e|em)?$/i && !($f[1] =~ m/ovi$/i && $f[3] eq 'ADJ'))
        {
            my $lform = lc($f[1]);
            my %ma =
            (
                'archelaus'    => ['Archelaus',   'Archelaus',   [['Sing', 'S', 'Nom', '1']]],
                'barnabáš'     => ['Barnabáš', 'Barnabáš', [['Sing', 'S', 'Nom', '1']]],
                'barnabáša'    => ['Barnabáš', 'Barnabáš', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'barnabáše'    => ['Barnabáš', 'Barnabáš', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4'], ['Sing', 'S', 'Voc', '5'], ['Plur', 'P', 'Acc', '4']]],
                'barnabášě'    => ['Barnabáš', 'Barnabáš', [['Sing', 'S', 'Loc', '6'], ['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5']]],
                'barnabášem'   => ['Barnabáš', 'Barnabáš', [['Sing', 'S', 'Ins', '7']]],
                'barnabáši'    => ['Barnabáš', 'Barnabáš', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5'], ['Plur', 'P', 'Ins', '7']]],
                'barnabášie'   => ['Barnabáš', 'Barnabáš', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'barnabášiech' => ['Barnabáš', 'Barnabáš', [['Plur', 'P', 'Loc', '6']]],
                'barnabášiem'  => ['Barnabáš', 'Barnabáš', [['Sing', 'S', 'Ins', '7']]],
                'barnabášiev'  => ['Barnabáš', 'Barnabáš', [['Plur', 'P', 'Gen', '2']]],
                'barnabášóm'   => ['Barnabáš', 'Barnabáš', [['Plur', 'P', 'Dat', '3']]],
                'barnabášoma'  => ['Barnabáš', 'Barnabáš', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'barnabášóv'   => ['Barnabáš', 'Barnabáš', [['Plur', 'P', 'Gen', '2']]],
                'barnabášové'  => ['Barnabáš', 'Barnabáš', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'barnabášovi'  => ['Barnabáš', 'Barnabáš', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'barnabášu'    => ['Barnabáš', 'Barnabáš', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'barnabášú'    => ['Barnabáš', 'Barnabáš', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'barnabášuom'  => ['Barnabáš', 'Barnabáš', [['Plur', 'P', 'Dat', '3']]],
                'barnabášuov'  => ['Barnabáš', 'Barnabáš', [['Plur', 'P', 'Gen', '2']]],
                'barrabáš'     => ['Barnabáš', 'Barnabáš', [['Sing', 'S', 'Nom', '1']]],
                'barrabáša'    => ['Barnabáš', 'Barnabáš', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'barrabáše'    => ['Barnabáš', 'Barnabáš', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4'], ['Sing', 'S', 'Voc', '5'], ['Plur', 'P', 'Acc', '4']]],
                'barrabášě'    => ['Barnabáš', 'Barnabáš', [['Sing', 'S', 'Loc', '6'], ['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5']]],
                'barrabášem'   => ['Barnabáš', 'Barnabáš', [['Sing', 'S', 'Ins', '7']]],
                'barrabáši'    => ['Barnabáš', 'Barnabáš', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5'], ['Plur', 'P', 'Ins', '7']]],
                'barrabášie'   => ['Barnabáš', 'Barnabáš', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'barrabášiech' => ['Barnabáš', 'Barnabáš', [['Plur', 'P', 'Loc', '6']]],
                'barrabášiem'  => ['Barnabáš', 'Barnabáš', [['Sing', 'S', 'Ins', '7']]],
                'barrabášiev'  => ['Barnabáš', 'Barnabáš', [['Plur', 'P', 'Gen', '2']]],
                'barrabášóm'   => ['Barnabáš', 'Barnabáš', [['Plur', 'P', 'Dat', '3']]],
                'barrabášoma'  => ['Barnabáš', 'Barnabáš', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'barrabášóv'   => ['Barnabáš', 'Barnabáš', [['Plur', 'P', 'Gen', '2']]],
                'barrabášové'  => ['Barnabáš', 'Barnabáš', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'barrabášovi'  => ['Barnabáš', 'Barnabáš', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'barrabášu'    => ['Barnabáš', 'Barnabáš', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'barrabášú'    => ['Barnabáš', 'Barnabáš', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'barrabášuom'  => ['Barnabáš', 'Barnabáš', [['Plur', 'P', 'Dat', '3']]],
                'barrabášuov'  => ['Barnabáš', 'Barnabáš', [['Plur', 'P', 'Gen', '2']]],
                'daniel'     => ['Daniel', 'Daniel', [['Sing', 'S', 'Nom', '1']]],
                'daniela'    => ['Daniel', 'Daniel', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'daniele'    => ['Daniel', 'Daniel', [['Sing', 'S', 'Voc', '5']]],
                'danielé'    => ['Daniel', 'Daniel', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'danielě'    => ['Daniel', 'Daniel', [['Sing', 'S', 'Loc', '6']]],
                'danielem'   => ['Daniel', 'Daniel', [['Sing', 'S', 'Ins', '7']]],
                'danieli'    => ['Daniel', 'Daniel', [['Sing', 'S', 'Voc', '5'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'danielie'   => ['Daniel', 'Daniel', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'danieliech' => ['Daniel', 'Daniel', [['Plur', 'P', 'Loc', '6']]],
                'danielóm'   => ['Daniel', 'Daniel', [['Plur', 'P', 'Dat', '3']]],
                'danieloma'  => ['Daniel', 'Daniel', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'danielóv'   => ['Daniel', 'Daniel', [['Plur', 'P', 'Gen', '2']]],
                'danielové'  => ['Daniel', 'Daniel', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'danielovi'  => ['Daniel', 'Daniel', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'danielu'    => ['Daniel', 'Daniel', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'danielú'    => ['Daniel', 'Daniel', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'danieluom'  => ['Daniel', 'Daniel', [['Plur', 'P', 'Dat', '3']]],
                'danieluov'  => ['Daniel', 'Daniel', [['Plur', 'P', 'Gen', '2']]],
                'daniely'    => ['Daniel', 'Daniel', [['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Ins', '7']]],
                'eliáš'      => ['Eliáš', 'Eliáš', [['Sing', 'S', 'Nom', '1']]],
                'eliáša'     => ['Eliáš', 'Eliáš', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'eliáše'     => ['Eliáš', 'Eliáš', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4'], ['Sing', 'S', 'Voc', '5'], ['Plur', 'P', 'Acc', '4']]],
                'eliášě'     => ['Eliáš', 'Eliáš', [['Sing', 'S', 'Loc', '6'], ['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5']]],
                'eliášem'    => ['Eliáš', 'Eliáš', [['Sing', 'S', 'Ins', '7']]],
                'eliáši'     => ['Eliáš', 'Eliáš', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5'], ['Plur', 'P', 'Ins', '7']]],
                'eliášie'    => ['Eliáš', 'Eliáš', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'eliášiech'  => ['Eliáš', 'Eliáš', [['Plur', 'P', 'Loc', '6']]],
                'eliášiem'   => ['Eliáš', 'Eliáš', [['Sing', 'S', 'Ins', '7']]],
                'eliášiev'   => ['Eliáš', 'Eliáš', [['Plur', 'P', 'Gen', '2']]],
                'eliášóm'    => ['Eliáš', 'Eliáš', [['Plur', 'P', 'Dat', '3']]],
                'eliášoma'   => ['Eliáš', 'Eliáš', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'eliášóv'    => ['Eliáš', 'Eliáš', [['Plur', 'P', 'Gen', '2']]],
                'eliášové'   => ['Eliáš', 'Eliáš', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'eliášovi'   => ['Eliáš', 'Eliáš', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'eliášu'     => ['Eliáš', 'Eliáš', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'eliášú'     => ['Eliáš', 'Eliáš', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'eliášuom'   => ['Eliáš', 'Eliáš', [['Plur', 'P', 'Dat', '3']]],
                'eliášuov'   => ['Eliáš', 'Eliáš', [['Plur', 'P', 'Gen', '2']]],
                'heliáš'     => ['Eliáš', 'Eliáš', [['Sing', 'S', 'Nom', '1']]],
                'heliáša'    => ['Eliáš', 'Eliáš', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'heliáše'    => ['Eliáš', 'Eliáš', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4'], ['Sing', 'S', 'Voc', '5'], ['Plur', 'P', 'Acc', '4']]],
                'heliášě'    => ['Eliáš', 'Eliáš', [['Sing', 'S', 'Loc', '6'], ['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5']]],
                'heliášem'   => ['Eliáš', 'Eliáš', [['Sing', 'S', 'Ins', '7']]],
                'heliáši'    => ['Eliáš', 'Eliáš', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5'], ['Plur', 'P', 'Ins', '7']]],
                'heliášie'   => ['Eliáš', 'Eliáš', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'heliášiech' => ['Eliáš', 'Eliáš', [['Plur', 'P', 'Loc', '6']]],
                'heliášiem'  => ['Eliáš', 'Eliáš', [['Sing', 'S', 'Ins', '7']]],
                'heliášiev'  => ['Eliáš', 'Eliáš', [['Plur', 'P', 'Gen', '2']]],
                'heliášóm'   => ['Eliáš', 'Eliáš', [['Plur', 'P', 'Dat', '3']]],
                'heliášoma'  => ['Eliáš', 'Eliáš', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'heliášóv'   => ['Eliáš', 'Eliáš', [['Plur', 'P', 'Gen', '2']]],
                'heliášové'  => ['Eliáš', 'Eliáš', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'heliášovi'  => ['Eliáš', 'Eliáš', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'heliášu'    => ['Eliáš', 'Eliáš', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'heliášú'    => ['Eliáš', 'Eliáš', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'heliášuom'  => ['Eliáš', 'Eliáš', [['Plur', 'P', 'Dat', '3']]],
                'heliášuov'  => ['Eliáš', 'Eliáš', [['Plur', 'P', 'Gen', '2']]],
                'erod'        => ['Herodes', 'Herodes', [['Sing', 'S', 'Nom', '1']]],
                'eroda'       => ['Herodes', 'Herodes', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'erode'       => ['Herodes', 'Herodes', [['Sing', 'S', 'Voc', '5']]],
                'erodě'       => ['Herodes', 'Herodes', [['Sing', 'S', 'Loc', '6']]],
                'erodem'      => ['Herodes', 'Herodes', [['Sing', 'S', 'Ins', '7']]],
                'erodes'      => ['Herodes', 'Herodes', [['Sing', 'S', 'Nom', '1']]],
                'erodesa'     => ['Herodes', 'Herodes', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'erodese'     => ['Herodes', 'Herodes', [['Sing', 'S', 'Voc', '5']]],
                'erodesě'     => ['Herodes', 'Herodes', [['Sing', 'S', 'Loc', '6']]],
                'erodesem'    => ['Herodes', 'Herodes', [['Sing', 'S', 'Ins', '7']]],
                'erodesi'     => ['Herodes', 'Herodes', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'erodesie'    => ['Herodes', 'Herodes', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'erodesiech'  => ['Herodes', 'Herodes', [['Plur', 'P', 'Loc', '6']]],
                'erodesóm'    => ['Herodes', 'Herodes', [['Plur', 'P', 'Dat', '3']]],
                'erodesoma'   => ['Herodes', 'Herodes', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'erodesóv'    => ['Herodes', 'Herodes', [['Plur', 'P', 'Gen', '2']]],
                'erodesové'   => ['Herodes', 'Herodes', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'erodesovi'   => ['Herodes', 'Herodes', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'erodesu'     => ['Herodes', 'Herodes', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'erodesú'     => ['Herodes', 'Herodes', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'erodesuom'   => ['Herodes', 'Herodes', [['Plur', 'P', 'Dat', '3']]],
                'erodesuov'   => ['Herodes', 'Herodes', [['Plur', 'P', 'Gen', '2']]],
                'erodesy'     => ['Herodes', 'Herodes', [['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Ins', '7']]],
                'erodi'       => ['Herodes', 'Herodes', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'erodie'      => ['Herodes', 'Herodes', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'erodiech'    => ['Herodes', 'Herodes', [['Plur', 'P', 'Loc', '6']]],
                'erodóm'      => ['Herodes', 'Herodes', [['Plur', 'P', 'Dat', '3']]],
                'erodoma'     => ['Herodes', 'Herodes', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'erodóv'      => ['Herodes', 'Herodes', [['Plur', 'P', 'Gen', '2']]],
                'erodové'     => ['Herodes', 'Herodes', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'erodovi'     => ['Herodes', 'Herodes', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'erodu'       => ['Herodes', 'Herodes', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'erodú'       => ['Herodes', 'Herodes', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'eroduom'     => ['Herodes', 'Herodes', [['Plur', 'P', 'Dat', '3']]],
                'eroduov'     => ['Herodes', 'Herodes', [['Plur', 'P', 'Gen', '2']]],
                'erody'       => ['Herodes', 'Herodes', [['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Ins', '7']]],
                'herod'       => ['Herodes', 'Herodes', [['Sing', 'S', 'Nom', '1']]],
                'heroda'      => ['Herodes', 'Herodes', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'herode'      => ['Herodes', 'Herodes', [['Sing', 'S', 'Voc', '5']]],
                'herodě'      => ['Herodes', 'Herodes', [['Sing', 'S', 'Loc', '6']]],
                'herodem'     => ['Herodes', 'Herodes', [['Sing', 'S', 'Ins', '7']]],
                'herodes'     => ['Herodes', 'Herodes', [['Sing', 'S', 'Nom', '1']]],
                'herodesa'    => ['Herodes', 'Herodes', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'herodese'    => ['Herodes', 'Herodes', [['Sing', 'S', 'Voc', '5']]],
                'herodesě'    => ['Herodes', 'Herodes', [['Sing', 'S', 'Loc', '6']]],
                'herodesem'   => ['Herodes', 'Herodes', [['Sing', 'S', 'Ins', '7']]],
                'herodesi'    => ['Herodes', 'Herodes', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'herodesie'   => ['Herodes', 'Herodes', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'herodesiech' => ['Herodes', 'Herodes', [['Plur', 'P', 'Loc', '6']]],
                'herodesóm'   => ['Herodes', 'Herodes', [['Plur', 'P', 'Dat', '3']]],
                'herodesoma'  => ['Herodes', 'Herodes', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'herodesóv'   => ['Herodes', 'Herodes', [['Plur', 'P', 'Gen', '2']]],
                'herodesové'  => ['Herodes', 'Herodes', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'herodesovi'  => ['Herodes', 'Herodes', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'herodesu'    => ['Herodes', 'Herodes', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'herodesú'    => ['Herodes', 'Herodes', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'herodesuom'  => ['Herodes', 'Herodes', [['Plur', 'P', 'Dat', '3']]],
                'herodesuov'  => ['Herodes', 'Herodes', [['Plur', 'P', 'Gen', '2']]],
                'herodesy'    => ['Herodes', 'Herodes', [['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Ins', '7']]],
                'herodi'      => ['Herodes', 'Herodes', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'herodie'     => ['Herodes', 'Herodes', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'herodiech'   => ['Herodes', 'Herodes', [['Plur', 'P', 'Loc', '6']]],
                'herodóm'     => ['Herodes', 'Herodes', [['Plur', 'P', 'Dat', '3']]],
                'herodoma'    => ['Herodes', 'Herodes', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'herodóv'     => ['Herodes', 'Herodes', [['Plur', 'P', 'Gen', '2']]],
                'herodové'    => ['Herodes', 'Herodes', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'herodovi'    => ['Herodes', 'Herodes', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'herodu'      => ['Herodes', 'Herodes', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'herodú'      => ['Herodes', 'Herodes', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'heroduom'    => ['Herodes', 'Herodes', [['Plur', 'P', 'Dat', '3']]],
                'heroduov'    => ['Herodes', 'Herodes', [['Plur', 'P', 'Gen', '2']]],
                'herody'      => ['Herodes', 'Herodes', [['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Ins', '7']]],
                'izaiáš'     => ['Izaiáš', 'Izaiáš', [['Sing', 'S', 'Nom', '1']]],
                'izaiáša'    => ['Izaiáš', 'Izaiáš', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'izaiáše'    => ['Izaiáš', 'Izaiáš', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4'], ['Sing', 'S', 'Voc', '5'], ['Plur', 'P', 'Acc', '4']]],
                'izaiášě'    => ['Izaiáš', 'Izaiáš', [['Sing', 'S', 'Loc', '6'], ['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5']]],
                'izaiášem'   => ['Izaiáš', 'Izaiáš', [['Sing', 'S', 'Ins', '7']]],
                'izaiáši'    => ['Izaiáš', 'Izaiáš', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5'], ['Plur', 'P', 'Ins', '7']]],
                'izaiášie'   => ['Izaiáš', 'Izaiáš', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'izaiášiech' => ['Izaiáš', 'Izaiáš', [['Plur', 'P', 'Loc', '6']]],
                'izaiášiem'  => ['Izaiáš', 'Izaiáš', [['Sing', 'S', 'Ins', '7']]],
                'izaiášiev'  => ['Izaiáš', 'Izaiáš', [['Plur', 'P', 'Gen', '2']]],
                'izaiášóm'   => ['Izaiáš', 'Izaiáš', [['Plur', 'P', 'Dat', '3']]],
                'izaiášoma'  => ['Izaiáš', 'Izaiáš', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'izaiášóv'   => ['Izaiáš', 'Izaiáš', [['Plur', 'P', 'Gen', '2']]],
                'izaiášové'  => ['Izaiáš', 'Izaiáš', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'izaiášovi'  => ['Izaiáš', 'Izaiáš', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'izaiášu'    => ['Izaiáš', 'Izaiáš', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'izaiášú'    => ['Izaiáš', 'Izaiáš', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'izaiášuom'  => ['Izaiáš', 'Izaiáš', [['Plur', 'P', 'Dat', '3']]],
                'izaiášuov'  => ['Izaiáš', 'Izaiáš', [['Plur', 'P', 'Gen', '2']]],
                'jezukrist'     => ['Jezukristus', 'Jezukristus', [['Sing', 'S', 'Nom', '1']]],
                'jezukrista'    => ['Jezukristus', 'Jezukristus', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'jezukriste'    => ['Jezukristus', 'Jezukristus', [['Sing', 'S', 'Voc', '5']]],
                'jezukristě'    => ['Jezukristus', 'Jezukristus', [['Sing', 'S', 'Loc', '6']]],
                'jezukristem'   => ['Jezukristus', 'Jezukristus', [['Sing', 'S', 'Ins', '7']]],
                'jezukristi'    => ['Jezukristus', 'Jezukristus', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'jezukristie'   => ['Jezukristus', 'Jezukristus', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'jezukristiech' => ['Jezukristus', 'Jezukristus', [['Plur', 'P', 'Loc', '6']]],
                'jezukristóm'   => ['Jezukristus', 'Jezukristus', [['Plur', 'P', 'Dat', '3']]],
                'jezukristoma'  => ['Jezukristus', 'Jezukristus', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'jezukristóv'   => ['Jezukristus', 'Jezukristus', [['Plur', 'P', 'Gen', '2']]],
                'jezukristové'  => ['Jezukristus', 'Jezukristus', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'jezukristovi'  => ['Jezukristus', 'Jezukristus', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'jezukristu'    => ['Jezukristus', 'Jezukristus', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'jezukristú'    => ['Jezukristus', 'Jezukristus', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'jezukristuom'  => ['Jezukristus', 'Jezukristus', [['Plur', 'P', 'Dat', '3']]],
                'jezukristuov'  => ['Jezukristus', 'Jezukristus', [['Plur', 'P', 'Gen', '2']]],
                'jezukristus'   => ['Jezukristus', 'Jezukristus', [['Sing', 'S', 'Nom', '1']]],
                'jezukristy'    => ['Jezukristus', 'Jezukristus', [['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Ins', '7']]],
                'ježíš'     => ['Ježíš', 'Ježíš', [['Sing', 'S', 'Nom', '1']]],
                'ježíša'    => ['Ježíš', 'Ježíš', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'ježíše'    => ['Ježíš', 'Ježíš', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4'], ['Sing', 'S', 'Voc', '5'], ['Plur', 'P', 'Acc', '4']]],
                'ježíšě'    => ['Ježíš', 'Ježíš', [['Sing', 'S', 'Loc', '6'], ['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5']]],
                'ježíšem'   => ['Ježíš', 'Ježíš', [['Sing', 'S', 'Ins', '7']]],
                'ježíši'    => ['Ježíš', 'Ježíš', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5'], ['Plur', 'P', 'Ins', '7']]],
                'ježíšie'   => ['Ježíš', 'Ježíš', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'ježíšiech' => ['Ježíš', 'Ježíš', [['Plur', 'P', 'Loc', '6']]],
                'ježíšiem'  => ['Ježíš', 'Ježíš', [['Sing', 'S', 'Ins', '7']]],
                'ježíšiev'  => ['Ježíš', 'Ježíš', [['Plur', 'P', 'Gen', '2']]],
                'ježíšóm'   => ['Ježíš', 'Ježíš', [['Plur', 'P', 'Dat', '3']]],
                'ježíšoma'  => ['Ježíš', 'Ježíš', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'ježíšóv'   => ['Ježíš', 'Ježíš', [['Plur', 'P', 'Gen', '2']]],
                'ježíšové'  => ['Ježíš', 'Ježíš', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'ježíšovi'  => ['Ježíš', 'Ježíš', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'ježíšu'    => ['Ježíš', 'Ježíš', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'ježíšú'    => ['Ježíš', 'Ježíš', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'ježíšuom'  => ['Ježíš', 'Ježíš', [['Plur', 'P', 'Dat', '3']]],
                'ježíšuov'  => ['Ježíš', 'Ježíš', [['Plur', 'P', 'Gen', '2']]],
                'josef'     => ['Josef', 'Jozef', [['Sing', 'S', 'Nom', '1']]],
                'josefa'    => ['Josef', 'Jozef', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'josefe'    => ['Josef', 'Jozef', [['Sing', 'S', 'Voc', '5']]],
                'josefě'    => ['Josef', 'Jozef', [['Sing', 'S', 'Loc', '6']]],
                'josefem'   => ['Josef', 'Jozef', [['Sing', 'S', 'Ins', '7']]],
                'josefi'    => ['Josef', 'Jozef', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'josefie'   => ['Josef', 'Jozef', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'josefiech' => ['Josef', 'Jozef', [['Plur', 'P', 'Loc', '6']]],
                'josefóm'   => ['Josef', 'Jozef', [['Plur', 'P', 'Dat', '3']]],
                'josefoma'  => ['Josef', 'Jozef', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'josefóv'   => ['Josef', 'Jozef', [['Plur', 'P', 'Gen', '2']]],
                'josefové'  => ['Josef', 'Jozef', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'josefovi'  => ['Josef', 'Jozef', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'josefu'    => ['Josef', 'Jozef', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'josefú'    => ['Josef', 'Jozef', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'josefuom'  => ['Josef', 'Jozef', [['Plur', 'P', 'Dat', '3']]],
                'josefuov'  => ['Josef', 'Jozef', [['Plur', 'P', 'Gen', '2']]],
                'josefy'    => ['Josef', 'Jozef', [['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Ins', '7']]],
                'jozef'     => ['Josef', 'Jozef', [['Sing', 'S', 'Nom', '1']]],
                'jozefa'    => ['Josef', 'Jozef', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'jozefe'    => ['Josef', 'Jozef', [['Sing', 'S', 'Voc', '5']]],
                'jozefě'    => ['Josef', 'Jozef', [['Sing', 'S', 'Loc', '6']]],
                'jozefem'   => ['Josef', 'Jozef', [['Sing', 'S', 'Ins', '7']]],
                'jozefi'    => ['Josef', 'Jozef', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'jozefie'   => ['Josef', 'Jozef', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'jozefiech' => ['Josef', 'Jozef', [['Plur', 'P', 'Loc', '6']]],
                'jozefóm'   => ['Josef', 'Jozef', [['Plur', 'P', 'Dat', '3']]],
                'jozefoma'  => ['Josef', 'Jozef', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'jozefóv'   => ['Josef', 'Jozef', [['Plur', 'P', 'Gen', '2']]],
                'jozefové'  => ['Josef', 'Jozef', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'jozefovi'  => ['Josef', 'Jozef', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'jozefu'    => ['Josef', 'Jozef', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'jozefú'    => ['Josef', 'Jozef', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'jozefuom'  => ['Josef', 'Jozef', [['Plur', 'P', 'Dat', '3']]],
                'jozefuov'  => ['Josef', 'Jozef', [['Plur', 'P', 'Gen', '2']]],
                'jozefy'    => ['Josef', 'Jozef', [['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Ins', '7']]],
                'ozěp'      => ['Josef', 'Jozef', [['Sing', 'S', 'Nom', '1']]],
                'ozěpa'     => ['Josef', 'Jozef', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'ozěpe'     => ['Josef', 'Jozef', [['Sing', 'S', 'Voc', '5']]],
                'ozěpě'     => ['Josef', 'Jozef', [['Sing', 'S', 'Loc', '6']]],
                'ozěpem'    => ['Josef', 'Jozef', [['Sing', 'S', 'Ins', '7']]],
                'ozěpi'     => ['Josef', 'Jozef', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'ozěpie'    => ['Josef', 'Jozef', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'ozěpiech'  => ['Josef', 'Jozef', [['Plur', 'P', 'Loc', '6']]],
                'ozěpóm'    => ['Josef', 'Jozef', [['Plur', 'P', 'Dat', '3']]],
                'ozěpoma'   => ['Josef', 'Jozef', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'ozěpóv'    => ['Josef', 'Jozef', [['Plur', 'P', 'Gen', '2']]],
                'ozěpové'   => ['Josef', 'Jozef', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'ozěpovi'   => ['Josef', 'Jozef', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'ozěpu'     => ['Josef', 'Jozef', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'ozěpú'     => ['Josef', 'Jozef', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'ozěpuom'   => ['Josef', 'Jozef', [['Plur', 'P', 'Dat', '3']]],
                'ozěpuov'   => ['Josef', 'Jozef', [['Plur', 'P', 'Gen', '2']]],
                'ozěpy'     => ['Josef', 'Jozef', [['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Ins', '7']]],
                'mojžieš'     => ['Mojžíš', 'Mojžieš', [['Sing', 'S', 'Nom', '1']]],
                'mojžieša'    => ['Mojžíš', 'Mojžieš', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'mojžieše'    => ['Mojžíš', 'Mojžieš', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4'], ['Sing', 'S', 'Voc', '5'], ['Plur', 'P', 'Acc', '4']]],
                'mojžiešě'    => ['Mojžíš', 'Mojžieš', [['Sing', 'S', 'Loc', '6'], ['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5']]],
                'mojžiešem'   => ['Mojžíš', 'Mojžieš', [['Sing', 'S', 'Ins', '7']]],
                'mojžieši'    => ['Mojžíš', 'Mojžieš', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5'], ['Plur', 'P', 'Ins', '7']]],
                'mojžiešie'   => ['Mojžíš', 'Mojžieš', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'mojžiešiech' => ['Mojžíš', 'Mojžieš', [['Plur', 'P', 'Loc', '6']]],
                'mojžiešiem'  => ['Mojžíš', 'Mojžieš', [['Sing', 'S', 'Ins', '7']]],
                'mojžiešiev'  => ['Mojžíš', 'Mojžieš', [['Plur', 'P', 'Gen', '2']]],
                'mojžiešóm'   => ['Mojžíš', 'Mojžieš', [['Plur', 'P', 'Dat', '3']]],
                'mojžiešoma'  => ['Mojžíš', 'Mojžieš', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'mojžiešóv'   => ['Mojžíš', 'Mojžieš', [['Plur', 'P', 'Gen', '2']]],
                'mojžiešové'  => ['Mojžíš', 'Mojžieš', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'mojžiešovi'  => ['Mojžíš', 'Mojžieš', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'mojžiešu'    => ['Mojžíš', 'Mojžieš', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'mojžiešú'    => ['Mojžíš', 'Mojžieš', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'mojžiešuom'  => ['Mojžíš', 'Mojžieš', [['Plur', 'P', 'Dat', '3']]],
                'mojžiešuov'  => ['Mojžíš', 'Mojžieš', [['Plur', 'P', 'Gen', '2']]],
                'mojžíš'      => ['Mojžíš', 'Mojžieš', [['Sing', 'S', 'Nom', '1']]],
                'mojžíša'     => ['Mojžíš', 'Mojžieš', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'mojžíše'     => ['Mojžíš', 'Mojžieš', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4'], ['Sing', 'S', 'Voc', '5'], ['Plur', 'P', 'Acc', '4']]],
                'mojžíšě'     => ['Mojžíš', 'Mojžieš', [['Sing', 'S', 'Loc', '6'], ['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5']]],
                'mojžíšem'    => ['Mojžíš', 'Mojžieš', [['Sing', 'S', 'Ins', '7']]],
                'mojžíši'     => ['Mojžíš', 'Mojžieš', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5'], ['Plur', 'P', 'Ins', '7']]],
                'mojžíšie'    => ['Mojžíš', 'Mojžieš', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'mojžíšiech'  => ['Mojžíš', 'Mojžieš', [['Plur', 'P', 'Loc', '6']]],
                'mojžíšiem'   => ['Mojžíš', 'Mojžieš', [['Sing', 'S', 'Ins', '7']]],
                'mojžíšiev'   => ['Mojžíš', 'Mojžieš', [['Plur', 'P', 'Gen', '2']]],
                'mojžíšóm'    => ['Mojžíš', 'Mojžieš', [['Plur', 'P', 'Dat', '3']]],
                'mojžíšoma'   => ['Mojžíš', 'Mojžieš', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'mojžíšóv'    => ['Mojžíš', 'Mojžieš', [['Plur', 'P', 'Gen', '2']]],
                'mojžíšové'   => ['Mojžíš', 'Mojžieš', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'mojžíšovi'   => ['Mojžíš', 'Mojžieš', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'mojžíšu'     => ['Mojžíš', 'Mojžieš', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'mojžíšú'     => ['Mojžíš', 'Mojžieš', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'mojžíšuom'   => ['Mojžíš', 'Mojžieš', [['Plur', 'P', 'Dat', '3']]],
                'mojžíšuov'   => ['Mojžíš', 'Mojžieš', [['Plur', 'P', 'Gen', '2']]],
                'petr'     => ['Petr', 'Petr', [['Sing', 'S', 'Nom', '1']]],
                'petra'    => ['Petr', 'Petr', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'petrem'   => ['Petr', 'Petr', [['Sing', 'S', 'Ins', '7']]],
                'petróm'   => ['Petr', 'Petr', [['Plur', 'P', 'Dat', '3']]],
                'petroma'  => ['Petr', 'Petr', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'petróv'   => ['Petr', 'Petr', [['Plur', 'P', 'Gen', '2']]],
                'petrové'  => ['Petr', 'Petr', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'petrovi'  => ['Petr', 'Petr', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'petru'    => ['Petr', 'Petr', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'petrú'    => ['Petr', 'Petr', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'petruom'  => ['Petr', 'Petr', [['Plur', 'P', 'Dat', '3']]],
                'petruov'  => ['Petr', 'Petr', [['Plur', 'P', 'Gen', '2']]],
                'petry'    => ['Petr', 'Petr', [['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Ins', '7']]],
                'petře'    => ['Petr', 'Petr', [['Sing', 'S', 'Voc', '5']]],
                'petřě'    => ['Petr', 'Petr', [['Sing', 'S', 'Loc', '6']]],
                'petři'    => ['Petr', 'Petr', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'petřie'   => ['Petr', 'Petr', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'petřiech' => ['Petr', 'Petr', [['Plur', 'P', 'Loc', '6']]],
                'pilát'     => ['Pilát', 'Pilát', [['Sing', 'S', 'Nom', '1']]],
                'piláta'    => ['Pilát', 'Pilát', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'piláte'    => ['Pilát', 'Pilát', [['Sing', 'S', 'Voc', '5']]],
                'pilátě'    => ['Pilát', 'Pilát', [['Sing', 'S', 'Loc', '6']]],
                'pilátem'   => ['Pilát', 'Pilát', [['Sing', 'S', 'Ins', '7']]],
                'piláti'    => ['Pilát', 'Pilát', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'pilátie'   => ['Pilát', 'Pilát', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'pilátiech' => ['Pilát', 'Pilát', [['Plur', 'P', 'Loc', '6']]],
                'pilátóm'   => ['Pilát', 'Pilát', [['Plur', 'P', 'Dat', '3']]],
                'pilátoma'  => ['Pilát', 'Pilát', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'pilátóv'   => ['Pilát', 'Pilát', [['Plur', 'P', 'Gen', '2']]],
                'pilátové'  => ['Pilát', 'Pilát', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'pilátovi'  => ['Pilát', 'Pilát', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'pilátu'    => ['Pilát', 'Pilát', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'pilátú'    => ['Pilát', 'Pilát', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'pilátuom'  => ['Pilát', 'Pilát', [['Plur', 'P', 'Dat', '3']]],
                'pilátuov'  => ['Pilát', 'Pilát', [['Plur', 'P', 'Gen', '2']]],
                'piláty'    => ['Pilát', 'Pilát', [['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Ins', '7']]],
                'šalamoun'     => ['Šalamoun', 'Šalomún', [['Sing', 'S', 'Nom', '1']]],
                'šalamouna'    => ['Šalamoun', 'Šalomún', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'šalamoune'    => ['Šalamoun', 'Šalomún', [['Sing', 'S', 'Voc', '5']]],
                'šalamouně'    => ['Šalamoun', 'Šalomún', [['Sing', 'S', 'Loc', '6']]],
                'šalamounem'   => ['Šalamoun', 'Šalomún', [['Sing', 'S', 'Ins', '7']]],
                'šalamouni'    => ['Šalamoun', 'Šalomún', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'šalamounie'   => ['Šalamoun', 'Šalomún', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'šalamouniech' => ['Šalamoun', 'Šalomún', [['Plur', 'P', 'Loc', '6']]],
                'šalamounóm'   => ['Šalamoun', 'Šalomún', [['Plur', 'P', 'Dat', '3']]],
                'šalamounoma'  => ['Šalamoun', 'Šalomún', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'šalamounóv'   => ['Šalamoun', 'Šalomún', [['Plur', 'P', 'Gen', '2']]],
                'šalamounové'  => ['Šalamoun', 'Šalomún', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'šalamounovi'  => ['Šalamoun', 'Šalomún', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'šalamounu'    => ['Šalamoun', 'Šalomún', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'šalamounú'    => ['Šalamoun', 'Šalomún', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'šalamounuom'  => ['Šalamoun', 'Šalomún', [['Plur', 'P', 'Dat', '3']]],
                'šalamounuov'  => ['Šalamoun', 'Šalomún', [['Plur', 'P', 'Gen', '2']]],
                'šalamouny'    => ['Šalamoun', 'Šalomún', [['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Ins', '7']]],
                'šalomún'      => ['Šalamoun', 'Šalomún', [['Sing', 'S', 'Nom', '1']]],
                'šalomúna'     => ['Šalamoun', 'Šalomún', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'šalomúne'     => ['Šalamoun', 'Šalomún', [['Sing', 'S', 'Voc', '5']]],
                'šalomúně'     => ['Šalamoun', 'Šalomún', [['Sing', 'S', 'Loc', '6']]],
                'šalomúnem'    => ['Šalamoun', 'Šalomún', [['Sing', 'S', 'Ins', '7']]],
                'šalomúni'     => ['Šalamoun', 'Šalomún', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'šalomúnie'    => ['Šalamoun', 'Šalomún', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'šalomúniech'  => ['Šalamoun', 'Šalomún', [['Plur', 'P', 'Loc', '6']]],
                'šalomúnóm'    => ['Šalamoun', 'Šalomún', [['Plur', 'P', 'Dat', '3']]],
                'šalomúnoma'   => ['Šalamoun', 'Šalomún', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'šalomúnóv'    => ['Šalamoun', 'Šalomún', [['Plur', 'P', 'Gen', '2']]],
                'šalomúnové'   => ['Šalamoun', 'Šalomún', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'šalomúnovi'   => ['Šalamoun', 'Šalomún', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'šalomúnu'     => ['Šalamoun', 'Šalomún', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'šalomúnú'     => ['Šalamoun', 'Šalomún', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'šalomúnuom'   => ['Šalamoun', 'Šalomún', [['Plur', 'P', 'Dat', '3']]],
                'šalomúnuov'   => ['Šalamoun', 'Šalomún', [['Plur', 'P', 'Gen', '2']]],
                'šalomúny'     => ['Šalamoun', 'Šalomún', [['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Ins', '7']]],
                'zebedáš'      => ['Zebedeus', 'Zebedeus', [['Sing', 'S', 'Nom', '1']]],
                'zebedáša'     => ['Zebedeus', 'Zebedeus', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'zebedáše'     => ['Zebedeus', 'Zebedeus', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4'], ['Sing', 'S', 'Voc', '5'], ['Plur', 'P', 'Acc', '4']]],
                'zebedášě'     => ['Zebedeus', 'Zebedeus', [['Sing', 'S', 'Loc', '6'], ['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5']]],
                'zebedášem'    => ['Zebedeus', 'Zebedeus', [['Sing', 'S', 'Ins', '7']]],
                'zebedáši'     => ['Zebedeus', 'Zebedeus', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5'], ['Plur', 'P', 'Ins', '7']]],
                'zebedášie'    => ['Zebedeus', 'Zebedeus', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'zebedášiech'  => ['Zebedeus', 'Zebedeus', [['Plur', 'P', 'Loc', '6']]],
                'zebedášiem'   => ['Zebedeus', 'Zebedeus', [['Sing', 'S', 'Ins', '7']]],
                'zebedášiev'   => ['Zebedeus', 'Zebedeus', [['Plur', 'P', 'Gen', '2']]],
                'zebedášóm'    => ['Zebedeus', 'Zebedeus', [['Plur', 'P', 'Dat', '3']]],
                'zebedášoma'   => ['Zebedeus', 'Zebedeus', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'zebedášóv'    => ['Zebedeus', 'Zebedeus', [['Plur', 'P', 'Gen', '2']]],
                'zebedášové'   => ['Zebedeus', 'Zebedeus', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'zebedášovi'   => ['Zebedeus', 'Zebedeus', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'zebedášu'     => ['Zebedeus', 'Zebedeus', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'zebedášú'     => ['Zebedeus', 'Zebedeus', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'zebedášuom'   => ['Zebedeus', 'Zebedeus', [['Plur', 'P', 'Dat', '3']]],
                'zebedášuov'   => ['Zebedeus', 'Zebedeus', [['Plur', 'P', 'Gen', '2']]],
                'zebede'       => ['Zebedeus', 'Zebedeus', [['Sing', 'S', 'Nom', '1']]],
                'zebedea'      => ['Zebedeus', 'Zebedeus', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'zebedeáš'     => ['Zebedeus', 'Zebedeus', [['Sing', 'S', 'Nom', '1']]],
                'zebedeáša'    => ['Zebedeus', 'Zebedeus', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'zebedeáše'    => ['Zebedeus', 'Zebedeus', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4'], ['Sing', 'S', 'Voc', '5'], ['Plur', 'P', 'Acc', '4']]],
                'zebedeášě'    => ['Zebedeus', 'Zebedeus', [['Sing', 'S', 'Loc', '6'], ['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5']]],
                'zebedeášem'   => ['Zebedeus', 'Zebedeus', [['Sing', 'S', 'Ins', '7']]],
                'zebedeáši'    => ['Zebedeus', 'Zebedeus', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5'], ['Plur', 'P', 'Ins', '7']]],
                'zebedeášie'   => ['Zebedeus', 'Zebedeus', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'zebedeášiech' => ['Zebedeus', 'Zebedeus', [['Plur', 'P', 'Loc', '6']]],
                'zebedeášiem'  => ['Zebedeus', 'Zebedeus', [['Sing', 'S', 'Ins', '7']]],
                'zebedeášiev'  => ['Zebedeus', 'Zebedeus', [['Plur', 'P', 'Gen', '2']]],
                'zebedeášóm'   => ['Zebedeus', 'Zebedeus', [['Plur', 'P', 'Dat', '3']]],
                'zebedeášoma'  => ['Zebedeus', 'Zebedeus', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'zebedeášóv'   => ['Zebedeus', 'Zebedeus', [['Plur', 'P', 'Gen', '2']]],
                'zebedeášové'  => ['Zebedeus', 'Zebedeus', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'zebedeášovi'  => ['Zebedeus', 'Zebedeus', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'zebedeášu'    => ['Zebedeus', 'Zebedeus', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'zebedeášú'    => ['Zebedeus', 'Zebedeus', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'zebedeášuom'  => ['Zebedeus', 'Zebedeus', [['Plur', 'P', 'Dat', '3']]],
                'zebedeášuov'  => ['Zebedeus', 'Zebedeus', [['Plur', 'P', 'Gen', '2']]],
                'zebedee'      => ['Zebedeus', 'Zebedeus', [['Sing', 'S', 'Voc', '5']]],
                'zebedeě'      => ['Zebedeus', 'Zebedeus', [['Sing', 'S', 'Loc', '6']]],
                'zebedeem'     => ['Zebedeus', 'Zebedeus', [['Sing', 'S', 'Ins', '7']]],
                'zebedei'      => ['Zebedeus', 'Zebedeus', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'zebedeie'     => ['Zebedeus', 'Zebedeus', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'zebedeiech'   => ['Zebedeus', 'Zebedeus', [['Plur', 'P', 'Loc', '6']]],
                'zebedeóm'     => ['Zebedeus', 'Zebedeus', [['Plur', 'P', 'Dat', '3']]],
                'zebedeoma'    => ['Zebedeus', 'Zebedeus', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'zebedeóv'     => ['Zebedeus', 'Zebedeus', [['Plur', 'P', 'Gen', '2']]],
                'zebedeové'    => ['Zebedeus', 'Zebedeus', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'zebedeovi'    => ['Zebedeus', 'Zebedeus', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'zebedeu'      => ['Zebedeus', 'Zebedeus', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'zebedeú'      => ['Zebedeus', 'Zebedeus', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'zebedeuom'    => ['Zebedeus', 'Zebedeus', [['Plur', 'P', 'Dat', '3']]],
                'zebedeuov'    => ['Zebedeus', 'Zebedeus', [['Plur', 'P', 'Gen', '2']]],
                'zebedeus'     => ['Zebedeus', 'Zebedeus', [['Sing', 'S', 'Nom', '1']]],
                'zebedey'      => ['Zebedeus', 'Zebedeus', [['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Ins', '7']]]
            );
            my $ma = $ma{$lform}; die("Something is wrong: '$lform'") if(!defined($ma));
            $f[2] = $ma->[0];
            $f[9] = set_lemma1300($f[9], $ma->[1]);
            $f[3] = 'PROPN';
            # U některých slov umožňujeme několik čtení, ale pokud to není žádné z nich, dáme první jako default.
            my @alt = @{$ma->[2]};
            for(my $i = $#alt; $i >= 0 ; $i--)
            {
                if($i == 0 || defined($alt[$i][4]) && get_ref($f[9]) =~ m/^$alt[$i][4]$/ || $f[5] =~ m/Case=$alt[$i][2].*Number=$alt[$i][0]/)
                {
                    $f[4] = 'NNM'.$alt[$i][1].$alt[$i][3].'-----A----';
                    $f[5] = 'Animacy=Anim|Case='.$alt[$i][2].'|Gender=Masc|NameType=Giv|Number='.$alt[$i][0].'|Polarity=Pos';
                    last;
                }
            }
        }
        ###!!! Ale např. ve BiblDrážď 24.24 to má být ADJ ("proroci Kristovi") a UDPipe to nepoznal.
        elsif($f[1] =~ m/^(Krist(?:us)?|K[rř]s?titel|Nazaren?(?:us)?)(a|e|ě|u|i|ovi|e|em|ové)?$/i && !($f[1] =~ m/ovi$/i && $f[3] eq 'ADJ'))
        {
            my $lform = lc($f[1]);
            my %ma =
            (
                'krist'     => ['Kristus', 'Kristus', [['Sing', 'S', 'Nom', '1']]],
                'krista'    => ['Kristus', 'Kristus', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'kriste'    => ['Kristus', 'Kristus', [['Sing', 'S', 'Voc', '5']]],
                'kristě'    => ['Kristus', 'Kristus', [['Sing', 'S', 'Loc', '6']]],
                'kristem'   => ['Kristus', 'Kristus', [['Sing', 'S', 'Ins', '7']]],
                'kristi'    => ['Kristus', 'Kristus', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'kristie'   => ['Kristus', 'Kristus', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'kristiech' => ['Kristus', 'Kristus', [['Plur', 'P', 'Loc', '6']]],
                'kristóm'   => ['Kristus', 'Kristus', [['Plur', 'P', 'Dat', '3']]],
                'kristoma'  => ['Kristus', 'Kristus', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'kristóv'   => ['Kristus', 'Kristus', [['Plur', 'P', 'Gen', '2']]],
                'kristové'  => ['Kristus', 'Kristus', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'kristovi'  => ['Kristus', 'Kristus', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'kristu'    => ['Kristus', 'Kristus', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'kristú'    => ['Kristus', 'Kristus', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'kristuom'  => ['Kristus', 'Kristus', [['Plur', 'P', 'Dat', '3']]],
                'kristuov'  => ['Kristus', 'Kristus', [['Plur', 'P', 'Gen', '2']]],
                'kristus'   => ['Kristus', 'Kristus', [['Sing', 'S', 'Nom', '1']]],
                'kristy'    => ['Kristus', 'Kristus', [['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Ins', '7']]],
                'krstitel'     => ['Křtitel', 'Křstitel', [['Sing', 'S', 'Nom', '1']]],
                'krstitela'    => ['Křtitel', 'Křstitel', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'krstitele'    => ['Křtitel', 'Křstitel', [['Sing', 'S', 'Voc', '5']]],
                'krstitelé'    => ['Křtitel', 'Křstitel', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'krstitelě'    => ['Křtitel', 'Křstitel', [['Sing', 'S', 'Loc', '6']]],
                'krstitelem'   => ['Křtitel', 'Křstitel', [['Sing', 'S', 'Ins', '7']]],
                'krstiteli'    => ['Křtitel', 'Křstitel', [['Sing', 'S', 'Voc', '5'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'krstitelie'   => ['Křtitel', 'Křstitel', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'krstiteliech' => ['Křtitel', 'Křstitel', [['Plur', 'P', 'Loc', '6']]],
                'krstitelóm'   => ['Křtitel', 'Křstitel', [['Plur', 'P', 'Dat', '3']]],
                'krstiteloma'  => ['Křtitel', 'Křstitel', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'krstitelóv'   => ['Křtitel', 'Křstitel', [['Plur', 'P', 'Gen', '2']]],
                'krstitelové'  => ['Křtitel', 'Křstitel', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'krstitelovi'  => ['Křtitel', 'Křstitel', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'krstitelu'    => ['Křtitel', 'Křstitel', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'krstitelú'    => ['Křtitel', 'Křstitel', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'krstiteluom'  => ['Křtitel', 'Křstitel', [['Plur', 'P', 'Dat', '3']]],
                'krstiteluov'  => ['Křtitel', 'Křstitel', [['Plur', 'P', 'Gen', '2']]],
                'krstitely'    => ['Křtitel', 'Křstitel', [['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Ins', '7']]],
                'křstitel'     => ['Křtitel', 'Křstitel', [['Sing', 'S', 'Nom', '1']]],
                'křstitela'    => ['Křtitel', 'Křstitel', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'křstitele'    => ['Křtitel', 'Křstitel', [['Sing', 'S', 'Voc', '5']]],
                'křstitelé'    => ['Křtitel', 'Křstitel', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'křstitelě'    => ['Křtitel', 'Křstitel', [['Sing', 'S', 'Loc', '6']]],
                'křstitelem'   => ['Křtitel', 'Křstitel', [['Sing', 'S', 'Ins', '7']]],
                'křstiteli'    => ['Křtitel', 'Křstitel', [['Sing', 'S', 'Voc', '5'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'křstitelie'   => ['Křtitel', 'Křstitel', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'křstiteliech' => ['Křtitel', 'Křstitel', [['Plur', 'P', 'Loc', '6']]],
                'křstitelóm'   => ['Křtitel', 'Křstitel', [['Plur', 'P', 'Dat', '3']]],
                'křstiteloma'  => ['Křtitel', 'Křstitel', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'křstitelóv'   => ['Křtitel', 'Křstitel', [['Plur', 'P', 'Gen', '2']]],
                'křstitelové'  => ['Křtitel', 'Křstitel', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'křstitelovi'  => ['Křtitel', 'Křstitel', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'křstitelu'    => ['Křtitel', 'Křstitel', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'křstitelú'    => ['Křtitel', 'Křstitel', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'křstiteluom'  => ['Křtitel', 'Křstitel', [['Plur', 'P', 'Dat', '3']]],
                'křstiteluov'  => ['Křtitel', 'Křstitel', [['Plur', 'P', 'Gen', '2']]],
                'křstitely'    => ['Křtitel', 'Křstitel', [['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Ins', '7']]],
                'křtitel'      => ['Křtitel', 'Křstitel', [['Sing', 'S', 'Nom', '1']]],
                'křtitela'     => ['Křtitel', 'Křstitel', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'křtitele'     => ['Křtitel', 'Křstitel', [['Sing', 'S', 'Voc', '5']]],
                'křtitelé'     => ['Křtitel', 'Křstitel', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'křtitelě'     => ['Křtitel', 'Křstitel', [['Sing', 'S', 'Loc', '6']]],
                'křtitelem'    => ['Křtitel', 'Křstitel', [['Sing', 'S', 'Ins', '7']]],
                'křtiteli'     => ['Křtitel', 'Křstitel', [['Sing', 'S', 'Voc', '5'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'křtitelie'    => ['Křtitel', 'Křstitel', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'křtiteliech'  => ['Křtitel', 'Křstitel', [['Plur', 'P', 'Loc', '6']]],
                'křtitelóm'    => ['Křtitel', 'Křstitel', [['Plur', 'P', 'Dat', '3']]],
                'křtiteloma'   => ['Křtitel', 'Křstitel', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'křtitelóv'    => ['Křtitel', 'Křstitel', [['Plur', 'P', 'Gen', '2']]],
                'křtitelové'   => ['Křtitel', 'Křstitel', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'křtitelovi'   => ['Křtitel', 'Křstitel', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'křtitelu'     => ['Křtitel', 'Křstitel', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'křtitelú'     => ['Křtitel', 'Křstitel', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'křtiteluom'   => ['Křtitel', 'Křstitel', [['Plur', 'P', 'Dat', '3']]],
                'křtiteluov'   => ['Křtitel', 'Křstitel', [['Plur', 'P', 'Gen', '2']]],
                'křtitely'     => ['Křtitel', 'Křstitel', [['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Ins', '7']]],
                'nazare'      => ['Nazareus', 'Nazarenus', [['Sing', 'S', 'Nom', '1']]],
                'nazarea'     => ['Nazareus', 'Nazarenus', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'nazaree'     => ['Nazareus', 'Nazarenus', [['Sing', 'S', 'Voc', '5']]],
                'nazareě'     => ['Nazareus', 'Nazarenus', [['Sing', 'S', 'Loc', '6']]],
                'nazareem'    => ['Nazareus', 'Nazarenus', [['Sing', 'S', 'Ins', '7']]],
                'nazarei'     => ['Nazareus', 'Nazarenus', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'nazareie'    => ['Nazareus', 'Nazarenus', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'nazareiech'  => ['Nazareus', 'Nazarenus', [['Plur', 'P', 'Loc', '6']]],
                'nazaren'     => ['Nazareus', 'Nazarenus', [['Sing', 'S', 'Nom', '1']]],
                'nazarena'    => ['Nazareus', 'Nazarenus', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'nazarene'    => ['Nazareus', 'Nazarenus', [['Sing', 'S', 'Voc', '5']]],
                'nazareně'    => ['Nazareus', 'Nazarenus', [['Sing', 'S', 'Loc', '6']]],
                'nazarenem'   => ['Nazareus', 'Nazarenus', [['Sing', 'S', 'Ins', '7']]],
                'nazareni'    => ['Nazareus', 'Nazarenus', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'nazarenie'   => ['Nazareus', 'Nazarenus', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'nazareniech' => ['Nazareus', 'Nazarenus', [['Plur', 'P', 'Loc', '6']]],
                'nazarenóm'   => ['Nazareus', 'Nazarenus', [['Plur', 'P', 'Dat', '3']]],
                'nazarenoma'  => ['Nazareus', 'Nazarenus', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'nazarenóv'   => ['Nazareus', 'Nazarenus', [['Plur', 'P', 'Gen', '2']]],
                'nazarenové'  => ['Nazareus', 'Nazarenus', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'nazarenovi'  => ['Nazareus', 'Nazarenus', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'nazarenu'    => ['Nazareus', 'Nazarenus', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'nazarenú'    => ['Nazareus', 'Nazarenus', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'nazarenuom'  => ['Nazareus', 'Nazarenus', [['Plur', 'P', 'Dat', '3']]],
                'nazarenuov'  => ['Nazareus', 'Nazarenus', [['Plur', 'P', 'Gen', '2']]],
                'nazarenus'   => ['Nazareus', 'Nazarenus', [['Sing', 'S', 'Nom', '1']]],
                'nazareny'    => ['Nazareus', 'Nazarenus', [['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Ins', '7']]],
                'nazareóm'    => ['Nazareus', 'Nazarenus', [['Plur', 'P', 'Dat', '3']]],
                'nazareoma'   => ['Nazareus', 'Nazarenus', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'nazareóv'    => ['Nazareus', 'Nazarenus', [['Plur', 'P', 'Gen', '2']]],
                'nazareové'   => ['Nazareus', 'Nazarenus', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'nazareovi'   => ['Nazareus', 'Nazarenus', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'nazareu'     => ['Nazareus', 'Nazarenus', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'nazareú'     => ['Nazareus', 'Nazarenus', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'nazareuom'   => ['Nazareus', 'Nazarenus', [['Plur', 'P', 'Dat', '3']]],
                'nazareuov'   => ['Nazareus', 'Nazarenus', [['Plur', 'P', 'Gen', '2']]],
                'nazareus'    => ['Nazareus', 'Nazarenus', [['Sing', 'S', 'Nom', '1']]],
                'nazarey'     => ['Nazareus', 'Nazarenus', [['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Ins', '7']]]
            );
            my $ma = $ma{$lform}; die("Something is wrong: '$lform'") if(!defined($ma));
            $f[2] = $ma->[0];
            $f[9] = set_lemma1300($f[9], $ma->[1]);
            $f[3] = 'PROPN';
            # U některých slov umožňujeme několik čtení, ale pokud to není žádné z nich, dáme první jako default.
            my @alt = @{$ma->[2]};
            for(my $i = $#alt; $i >= 0 ; $i--)
            {
                if($i == 0 || defined($alt[$i][4]) && get_ref($f[9]) =~ m/^$alt[$i][4]$/ || $f[5] =~ m/Case=$alt[$i][2].*Number=$alt[$i][0]/)
                {
                    $f[4] = 'NNM'.$alt[$i][1].$alt[$i][3].'-----A----';
                    $f[5] = 'Animacy=Anim|Case='.$alt[$i][2].'|Gender=Masc|NameType=Sur|Number='.$alt[$i][0].'|Polarity=Pos';
                    last;
                }
            }
        }
        #----------------------------------------------------------------------
        # Mužský rod neživotný.
        #----------------------------------------------------------------------
        # Výjimka: 'čině' může být sloveso, 'činiech' možná taky?
        # Výjimka: 'dna' a 'dny' je ve všech výskytech nemoc, nikoli tvar slova 'den'.
        # Výjimka: "pláče" je v dotyčném výskytu sloveso "plakat", nikoli tvar slova "pláč".
        elsif($f[1] =~ m/^(balšám|buochenc|čas|čin|déšč|div|dn|dóm|du?om|fík|hrob|hřie(ch|š)|chleb|ku?oš|kút|národ|neduh|okrajk|otrusk|pas|peniez|pláč|plamen|plášč|podhrdlk|podolk|poklad|příklad|rov|sbuor|skutk|sn|stien|stol|súd|ščěvík|tisíc|úd|u?oheň|u?ohn|u?ostatk|uzlíc|užitk|větr|vlas|zárodc|zástup|zbytk|zub)(a|e|ě|i|u|ové|óv|uov|iev|í|óm|uom|y|ách|iech)?$/i && $f[1] !~ m/^(dn[ay]|diví|čin[ěí]|činiech|fíkové|pas[ae]?|pláč[eí]|súdí|tisící)$/i)
        {
            my $lform = lc($f[1]);
            my %ma =
            (
                'balšám'     => ['balšám', 'balšám', [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Acc', '4']]],
                'balšáma'    => ['balšám', 'balšám', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'balšáme'    => ['balšám', 'balšám', [['Sing', 'S', 'Voc', '5']]],
                'balšámě'    => ['balšám', 'balšám', [['Sing', 'S', 'Loc', '6']]],
                'balšámem'   => ['balšám', 'balšám', [['Sing', 'S', 'Ins', '7']]],
                'balšámi'    => ['balšám', 'balšám', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'balšámie'   => ['balšám', 'balšám', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'balšámiech' => ['balšám', 'balšám', [['Plur', 'P', 'Loc', '6']]],
                'balšámóm'   => ['balšám', 'balšám', [['Plur', 'P', 'Dat', '3']]],
                'balšámoma'  => ['balšám', 'balšám', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'balšámóv'   => ['balšám', 'balšám', [['Plur', 'P', 'Gen', '2']]],
                'balšámové'  => ['balšám', 'balšám', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'balšámovi'  => ['balšám', 'balšám', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'balšámu'    => ['balšám', 'balšám', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'balšámú'    => ['balšám', 'balšám', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'balšámuom'  => ['balšám', 'balšám', [['Plur', 'P', 'Dat', '3']]],
                'balšámuov'  => ['balšám', 'balšám', [['Plur', 'P', 'Gen', '2']]],
                'balšámy'    => ['balšám', 'balšám', [['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5'], ['Plur', 'P', 'Ins', '7']]],
                'buochenca'    => ['bochník', 'buochenec', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'buochence'    => ['bochník', 'buochenec', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5']]],
                'buochencě'    => ['bochník', 'buochenec', [['Sing', 'S', 'Loc', '6'], ['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5']]],
                'buochencem'   => ['bochník', 'buochenec', [['Sing', 'S', 'Ins', '7']]],
                'buochenci'    => ['bochník', 'buochenec', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5'], ['Plur', 'P', 'Ins', '7']]],
                'buochencie'   => ['bochník', 'buochenec', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'buochenciech' => ['bochník', 'buochenec', [['Plur', 'P', 'Loc', '6']]],
                'buochenciem'  => ['bochník', 'buochenec', [['Sing', 'S', 'Ins', '7']]],
                'buochenciev'  => ['bochník', 'buochenec', [['Plur', 'P', 'Gen', '2']]],
                'buochencóm'   => ['bochník', 'buochenec', [['Plur', 'P', 'Dat', '3']]],
                'buochencoma'  => ['bochník', 'buochenec', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'buochencóv'   => ['bochník', 'buochenec', [['Plur', 'P', 'Gen', '2']]],
                'buochencové'  => ['bochník', 'buochenec', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'buochencovi'  => ['bochník', 'buochenec', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'buochencu'    => ['bochník', 'buochenec', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'buochencú'    => ['bochník', 'buochenec', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'buochencuom'  => ['bochník', 'buochenec', [['Plur', 'P', 'Dat', '3']]],
                'buochencuov'  => ['bochník', 'buochenec', [['Plur', 'P', 'Gen', '2']]],
                'buochenče'    => ['bochník', 'buochenec', [['Sing', 'S', 'Voc', '5']]],
                'buochenec'    => ['bochník', 'buochenec', [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Acc', '4']]],
                'čas'     => ['čas', 'čas', [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Acc', '4']]],
                'časa'    => ['čas', 'čas', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'čase'    => ['čas', 'čas', [['Sing', 'S', 'Voc', '5']]],
                'časě'    => ['čas', 'čas', [['Sing', 'S', 'Loc', '6']]],
                'časem'   => ['čas', 'čas', [['Sing', 'S', 'Ins', '7']]],
                'časi'    => ['čas', 'čas', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'časie'   => ['čas', 'čas', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'časiech' => ['čas', 'čas', [['Plur', 'P', 'Loc', '6']]],
                'časóm'   => ['čas', 'čas', [['Plur', 'P', 'Dat', '3']]],
                'časoma'  => ['čas', 'čas', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'časóv'   => ['čas', 'čas', [['Plur', 'P', 'Gen', '2']]],
                'časové'  => ['čas', 'čas', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'časovi'  => ['čas', 'čas', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'času'    => ['čas', 'čas', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'časú'    => ['čas', 'čas', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'časuom'  => ['čas', 'čas', [['Plur', 'P', 'Dat', '3']]],
                'časuov'  => ['čas', 'čas', [['Plur', 'P', 'Gen', '2']]],
                'časy'    => ['čas', 'čas', [['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5'], ['Plur', 'P', 'Ins', '7']]],
                'čin'     => ['čin', 'čin', [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Acc', '4']]],
                'čina'    => ['čin', 'čin', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'čine'    => ['čin', 'čin', [['Sing', 'S', 'Voc', '5']]],
                'čině'    => ['čin', 'čin', [['Sing', 'S', 'Loc', '6']]],
                'činem'   => ['čin', 'čin', [['Sing', 'S', 'Ins', '7']]],
                'čini'    => ['čin', 'čin', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'činie'   => ['čin', 'čin', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'činiech' => ['čin', 'čin', [['Plur', 'P', 'Loc', '6']]],
                'činóm'   => ['čin', 'čin', [['Plur', 'P', 'Dat', '3']]],
                'činoma'  => ['čin', 'čin', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'činóv'   => ['čin', 'čin', [['Plur', 'P', 'Gen', '2']]],
                'činové'  => ['čin', 'čin', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'činovi'  => ['čin', 'čin', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'činu'    => ['čin', 'čin', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'činú'    => ['čin', 'čin', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'činuom'  => ['čin', 'čin', [['Plur', 'P', 'Dat', '3']]],
                'činuov'  => ['čin', 'čin', [['Plur', 'P', 'Gen', '2']]],
                'činy'    => ['čin', 'čin', [['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5'], ['Plur', 'P', 'Ins', '7']]],
                'déšč'        => ['déšť',      'déšč',    [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Acc', '4']]],
                'div'     => ['div', 'div', [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Acc', '4']]],
                'diva'    => ['div', 'div', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'dive'    => ['div', 'div', [['Sing', 'S', 'Voc', '5']]],
                'divě'    => ['div', 'div', [['Sing', 'S', 'Loc', '6']]],
                'divem'   => ['div', 'div', [['Sing', 'S', 'Ins', '7']]],
                'divi'    => ['div', 'div', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'divie'   => ['div', 'div', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'diviech' => ['div', 'div', [['Plur', 'P', 'Loc', '6']]],
                'divóm'   => ['div', 'div', [['Plur', 'P', 'Dat', '3']]],
                'divoma'  => ['div', 'div', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'divóv'   => ['div', 'div', [['Plur', 'P', 'Gen', '2']]],
                'divové'  => ['div', 'div', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'divovi'  => ['div', 'div', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'divu'    => ['div', 'div', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'divú'    => ['div', 'div', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'divuom'  => ['div', 'div', [['Plur', 'P', 'Dat', '3']]],
                'divuov'  => ['div', 'div', [['Plur', 'P', 'Gen', '2']]],
                'divy'    => ['div', 'div', [['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5'], ['Plur', 'P', 'Ins', '7']]],
                'den'    => ['den', 'den', [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Acc', '4']]],
                'dna'    => ['den', 'den', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'dne'    => ['den', 'den', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Voc', '5']]],
                'dně'    => ['den', 'den', [['Sing', 'S', 'Loc', '6']]],
                'dnem'   => ['den', 'den', [['Sing', 'S', 'Ins', '7']]],
                'dni'    => ['den', 'den', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'dní'    => ['den', 'den', [['Plur', 'P', 'Gen', '2']]],
                'dnie'   => ['den', 'den', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'dniech' => ['den', 'den', [['Plur', 'P', 'Loc', '6']]],
                'dnóm'   => ['den', 'den', [['Plur', 'P', 'Dat', '3']]],
                'dnoma'  => ['den', 'den', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'dnóv'   => ['den', 'den', [['Plur', 'P', 'Gen', '2']]],
                'dnové'  => ['den', 'den', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'dnovi'  => ['den', 'den', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'dnu'    => ['den', 'den', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'dnú'    => ['den', 'den', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'dnuom'  => ['den', 'den', [['Plur', 'P', 'Dat', '3']]],
                'dnuov'  => ['den', 'den', [['Plur', 'P', 'Gen', '2']]],
                'dny'    => ['den', 'den', [['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5'], ['Plur', 'P', 'Ins', '7']]],
                'dom'      => ['dům', 'dóm', [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Acc', '4']]],
                'dóm'      => ['dům', 'dóm', [['Sing', 'S', 'Nom', '1']]],
                'doma'     => ['dům', 'dóm', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'dome'     => ['dům', 'dóm', [['Sing', 'S', 'Voc', '5']]],
                'domě'     => ['dům', 'dóm', [['Sing', 'S', 'Loc', '6']]],
                'domem'    => ['dům', 'dóm', [['Sing', 'S', 'Ins', '7']]],
                'domi'     => ['dům', 'dóm', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'domie'    => ['dům', 'dóm', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'domiech'  => ['dům', 'dóm', [['Plur', 'P', 'Loc', '6']]],
                'domóm'    => ['dům', 'dóm', [['Plur', 'P', 'Dat', '3']]],
                'domoma'   => ['dům', 'dóm', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'domóv'    => ['dům', 'dóm', [['Plur', 'P', 'Gen', '2']]],
                'domové'   => ['dům', 'dóm', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'domovi'   => ['dům', 'dóm', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'domu'     => ['dům', 'dóm', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'domú'     => ['dům', 'dóm', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'domuom'   => ['dům', 'dóm', [['Plur', 'P', 'Dat', '3']]],
                'domuov'   => ['dům', 'dóm', [['Plur', 'P', 'Gen', '2']]],
                'domy'     => ['dům', 'dóm', [['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5'], ['Plur', 'P', 'Ins', '7']]],
                'duom'     => ['dům', 'dóm', [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Acc', '4']]],
                'duoma'    => ['dům', 'dóm', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'duome'    => ['dům', 'dóm', [['Sing', 'S', 'Voc', '5']]],
                'duomě'    => ['dům', 'dóm', [['Sing', 'S', 'Loc', '6']]],
                'duomem'   => ['dům', 'dóm', [['Sing', 'S', 'Ins', '7']]],
                'duomi'    => ['dům', 'dóm', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'duomie'   => ['dům', 'dóm', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'duomiech' => ['dům', 'dóm', [['Plur', 'P', 'Loc', '6']]],
                'duomóm'   => ['dům', 'dóm', [['Plur', 'P', 'Dat', '3']]],
                'duomoma'  => ['dům', 'dóm', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'duomóv'   => ['dům', 'dóm', [['Plur', 'P', 'Gen', '2']]],
                'duomové'  => ['dům', 'dóm', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'duomovi'  => ['dům', 'dóm', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'duomu'    => ['dům', 'dóm', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'duomú'    => ['dům', 'dóm', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'duomuom'  => ['dům', 'dóm', [['Plur', 'P', 'Dat', '3']]],
                'duomuov'  => ['dům', 'dóm', [['Plur', 'P', 'Gen', '2']]],
                'duomy'    => ['dům', 'dóm', [['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5'], ['Plur', 'P', 'Ins', '7']]],
                'fícě'    => ['fík', 'fík', [['Sing', 'S', 'Loc', '6']]],
                'fíci'    => ['fík', 'fík', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'fície'   => ['fík', 'fík', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'fíciech' => ['fík', 'fík', [['Plur', 'P', 'Loc', '6']]],
                'fíče'    => ['fík', 'fík', [['Sing', 'S', 'Voc', '5']]],
                'fík'     => ['fík', 'fík', [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Acc', '4']]],
                'fíka'    => ['fík', 'fík', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'fíkem'   => ['fík', 'fík', [['Sing', 'S', 'Ins', '7']]],
                'fíkóm'   => ['fík', 'fík', [['Plur', 'P', 'Dat', '3']]],
                'fíkoma'  => ['fík', 'fík', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'fíkóv'   => ['fík', 'fík', [['Plur', 'P', 'Gen', '2']]],
                'fíkové'  => ['fík', 'fík', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'fíkovi'  => ['fík', 'fík', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'fíku'    => ['fík', 'fík', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Voc', '5'], ['Sing', 'S', 'Loc', '6']]],
                'fíkú'    => ['fík', 'fík', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'fíkuom'  => ['fík', 'fík', [['Plur', 'P', 'Dat', '3']]],
                'fíkuov'  => ['fík', 'fík', [['Plur', 'P', 'Gen', '2']]],
                'fíky'    => ['fík', 'fík', [['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5'], ['Plur', 'P', 'Ins', '7']]],
                'hrob'     => ['hrob', 'hrob', [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Acc', '4']]],
                'hroba'    => ['hrob', 'hrob', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'hrobe'    => ['hrob', 'hrob', [['Sing', 'S', 'Voc', '5']]],
                'hrobě'    => ['hrob', 'hrob', [['Sing', 'S', 'Loc', '6']]],
                'hrobem'   => ['hrob', 'hrob', [['Sing', 'S', 'Ins', '7']]],
                'hrobi'    => ['hrob', 'hrob', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'hrobie'   => ['hrob', 'hrob', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'hrobiech' => ['hrob', 'hrob', [['Plur', 'P', 'Loc', '6']]],
                'hrobóm'   => ['hrob', 'hrob', [['Plur', 'P', 'Dat', '3']]],
                'hroboma'  => ['hrob', 'hrob', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'hrobóv'   => ['hrob', 'hrob', [['Plur', 'P', 'Gen', '2']]],
                'hrobové'  => ['hrob', 'hrob', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'hrobovi'  => ['hrob', 'hrob', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'hrobu'    => ['hrob', 'hrob', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'hrobú'    => ['hrob', 'hrob', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'hrobuom'  => ['hrob', 'hrob', [['Plur', 'P', 'Dat', '3']]],
                'hrobuov'  => ['hrob', 'hrob', [['Plur', 'P', 'Gen', '2']]],
                'hroby'    => ['hrob', 'hrob', [['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5'], ['Plur', 'P', 'Ins', '7']]],
                'hřiech'    => ['hřích', 'hřiech', [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Acc', '4']]],
                'hřiecha'   => ['hřích', 'hřiech', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'hřiechem'  => ['hřích', 'hřiech', [['Sing', 'S', 'Ins', '7']]],
                'hřiechóm'  => ['hřích', 'hřiech', [['Plur', 'P', 'Dat', '3']]],
                'hřiechoma' => ['hřích', 'hřiech', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'hřiechóv'  => ['hřích', 'hřiech', [['Plur', 'P', 'Gen', '2']]],
                'hřiechové' => ['hřích', 'hřiech', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'hřiechovi' => ['hřích', 'hřiech', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'hřiechu'   => ['hřích', 'hřiech', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Voc', '5'], ['Sing', 'S', 'Loc', '6']]],
                'hřiechú'   => ['hřích', 'hřiech', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'hřiechuom' => ['hřích', 'hřiech', [['Plur', 'P', 'Dat', '3']]],
                'hřiechuov' => ['hřích', 'hřiech', [['Plur', 'P', 'Gen', '2']]],
                'hřiechy'   => ['hřích', 'hřiech', [['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5'], ['Plur', 'P', 'Ins', '7']]],
                'hřieše'    => ['hřích', 'hřiech', [['Sing', 'S', 'Voc', '5']]],
                'hřiešě'    => ['hřích', 'hřiech', [['Sing', 'S', 'Loc', '6']]],
                'hřieši'    => ['hřích', 'hřiech', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'hřiešie'   => ['hřích', 'hřiech', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'hřiešiech' => ['hřích', 'hřiech', [['Plur', 'P', 'Loc', '6']]],
                'chleb'     => ['chléb', 'chléb', [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Acc', '4']]],
                'chléb'     => ['chléb', 'chléb', [['Sing', 'S', 'Nom', '1']]],
                'chleba'    => ['chléb', 'chléb', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'chlebe'    => ['chléb', 'chléb', [['Sing', 'S', 'Voc', '5']]],
                'chlebě'    => ['chléb', 'chléb', [['Sing', 'S', 'Loc', '6']]],
                'chlebem'   => ['chléb', 'chléb', [['Sing', 'S', 'Ins', '7']]],
                'chlebi'    => ['chléb', 'chléb', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'chlebie'   => ['chléb', 'chléb', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'chlebiech' => ['chléb', 'chléb', [['Plur', 'P', 'Loc', '6']]],
                'chlebóm'   => ['chléb', 'chléb', [['Plur', 'P', 'Dat', '3']]],
                'chleboma'  => ['chléb', 'chléb', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'chlebóv'   => ['chléb', 'chléb', [['Plur', 'P', 'Gen', '2']]],
                'chlebové'  => ['chléb', 'chléb', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'chlebovi'  => ['chléb', 'chléb', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'chlebu'    => ['chléb', 'chléb', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'chlebú'    => ['chléb', 'chléb', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'chlebuom'  => ['chléb', 'chléb', [['Plur', 'P', 'Dat', '3']]],
                'chlebuov'  => ['chléb', 'chléb', [['Plur', 'P', 'Gen', '2']]],
                'chleby'    => ['chléb', 'chléb', [['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5'], ['Plur', 'P', 'Ins', '7']]],
                'koš'      => ['koš', 'koš', [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Acc', '4']]],
                'koša'     => ['koš', 'koš', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'koše'     => ['koš', 'koš', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4'], ['Sing', 'S', 'Voc', '5'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5']]],
                'košě'     => ['koš', 'koš', [['Sing', 'S', 'Loc', '6'], ['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5']]],
                'košem'    => ['koš', 'koš', [['Sing', 'S', 'Ins', '7']]],
                'koši'     => ['koš', 'koš', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5'], ['Plur', 'P', 'Ins', '7']]],
                'košie'    => ['koš', 'koš', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'košiech'  => ['koš', 'koš', [['Plur', 'P', 'Loc', '6']]],
                'košiem'   => ['koš', 'koš', [['Sing', 'S', 'Ins', '7']]],
                'košiev'   => ['koš', 'koš', [['Plur', 'P', 'Gen', '2']]],
                'košóm'    => ['koš', 'koš', [['Plur', 'P', 'Dat', '3']]],
                'košoma'   => ['koš', 'koš', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'košóv'    => ['koš', 'koš', [['Plur', 'P', 'Gen', '2']]],
                'košové'   => ['koš', 'koš', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'košovi'   => ['koš', 'koš', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'košu'     => ['koš', 'koš', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'košú'     => ['koš', 'koš', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'košuom'   => ['koš', 'koš', [['Plur', 'P', 'Dat', '3']]],
                'košuov'   => ['koš', 'koš', [['Plur', 'P', 'Gen', '2']]],
                'kuoš'     => ['koš', 'koš', [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Acc', '4']]],
                'kuoša'    => ['koš', 'koš', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'kuoše'    => ['koš', 'koš', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4'], ['Sing', 'S', 'Voc', '5'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5']]],
                'kuošě'    => ['koš', 'koš', [['Sing', 'S', 'Loc', '6'], ['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5']]],
                'kuošem'   => ['koš', 'koš', [['Sing', 'S', 'Ins', '7']]],
                'kuoši'    => ['koš', 'koš', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5'], ['Plur', 'P', 'Ins', '7']]],
                'kuošie'   => ['koš', 'koš', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'kuošiech' => ['koš', 'koš', [['Plur', 'P', 'Loc', '6']]],
                'kuošiem'  => ['koš', 'koš', [['Sing', 'S', 'Ins', '7']]],
                'kuošiev'  => ['koš', 'koš', [['Plur', 'P', 'Gen', '2']]],
                'kuošóm'   => ['koš', 'koš', [['Plur', 'P', 'Dat', '3']]],
                'kuošoma'  => ['koš', 'koš', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'kuošóv'   => ['koš', 'koš', [['Plur', 'P', 'Gen', '2']]],
                'kuošové'  => ['koš', 'koš', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'kuošovi'  => ['koš', 'koš', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'kuošu'    => ['koš', 'koš', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'kuošú'    => ['koš', 'koš', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'kuošuom'  => ['koš', 'koš', [['Plur', 'P', 'Dat', '3']]],
                'kuošuov'  => ['koš', 'koš', [['Plur', 'P', 'Gen', '2']]],
                'kout'     => ['kout', 'kút', [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Acc', '4']]],
                'kouta'    => ['kout', 'kút', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'koute'    => ['kout', 'kút', [['Sing', 'S', 'Voc', '5']]],
                'koutě'    => ['kout', 'kút', [['Sing', 'S', 'Loc', '6']]],
                'koutem'   => ['kout', 'kút', [['Sing', 'S', 'Ins', '7']]],
                'kouti'    => ['kout', 'kút', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'koutie'   => ['kout', 'kút', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'koutiech' => ['kout', 'kút', [['Plur', 'P', 'Loc', '6']]],
                'koutóm'   => ['kout', 'kút', [['Plur', 'P', 'Dat', '3']]],
                'koutoma'  => ['kout', 'kút', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'koutóv'   => ['kout', 'kút', [['Plur', 'P', 'Gen', '2']]],
                'koutové'  => ['kout', 'kút', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'koutovi'  => ['kout', 'kút', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'koutu'    => ['kout', 'kút', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'koutú'    => ['kout', 'kút', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'koutuom'  => ['kout', 'kút', [['Plur', 'P', 'Dat', '3']]],
                'koutuov'  => ['kout', 'kút', [['Plur', 'P', 'Gen', '2']]],
                'kouty'    => ['kout', 'kút', [['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5'], ['Plur', 'P', 'Ins', '7']]],
                'kút'      => ['kout', 'kút', [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Acc', '4']]],
                'kúta'     => ['kout', 'kút', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'kúte'     => ['kout', 'kút', [['Sing', 'S', 'Voc', '5']]],
                'kútě'     => ['kout', 'kút', [['Sing', 'S', 'Loc', '6']]],
                'kútem'    => ['kout', 'kút', [['Sing', 'S', 'Ins', '7']]],
                'kúti'     => ['kout', 'kút', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'kútie'    => ['kout', 'kút', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'kútiech'  => ['kout', 'kút', [['Plur', 'P', 'Loc', '6']]],
                'kútóm'    => ['kout', 'kút', [['Plur', 'P', 'Dat', '3']]],
                'kútoma'   => ['kout', 'kút', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'kútóv'    => ['kout', 'kút', [['Plur', 'P', 'Gen', '2']]],
                'kútové'   => ['kout', 'kút', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'kútovi'   => ['kout', 'kút', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'kútu'     => ['kout', 'kút', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'kútú'     => ['kout', 'kút', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'kútuom'   => ['kout', 'kút', [['Plur', 'P', 'Dat', '3']]],
                'kútuov'   => ['kout', 'kút', [['Plur', 'P', 'Gen', '2']]],
                'kúty'     => ['kout', 'kút', [['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5'], ['Plur', 'P', 'Ins', '7']]],
                'národ'     => ['národ', 'národ', [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Acc', '4']]],
                'národa'    => ['národ', 'národ', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'národe'    => ['národ', 'národ', [['Sing', 'S', 'Voc', '5']]],
                'národě'    => ['národ', 'národ', [['Sing', 'S', 'Loc', '6']]],
                'národem'   => ['národ', 'národ', [['Sing', 'S', 'Ins', '7']]],
                'národi'    => ['národ', 'národ', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'národie'   => ['národ', 'národ', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'národiech' => ['národ', 'národ', [['Plur', 'P', 'Loc', '6']]],
                'národóm'   => ['národ', 'národ', [['Plur', 'P', 'Dat', '3']]],
                'národoma'  => ['národ', 'národ', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'národóv'   => ['národ', 'národ', [['Plur', 'P', 'Gen', '2']]],
                'národové'  => ['národ', 'národ', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'národovi'  => ['národ', 'národ', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'národu'    => ['národ', 'národ', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'národú'    => ['národ', 'národ', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'národuom'  => ['národ', 'národ', [['Plur', 'P', 'Dat', '3']]],
                'národuov'  => ['národ', 'národ', [['Plur', 'P', 'Gen', '2']]],
                'národy'    => ['národ', 'národ', [['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5'], ['Plur', 'P', 'Ins', '7']]],
                'neduh'     => ['neduh', 'neduh', [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Acc', '4']]],
                'neduha'    => ['neduh', 'neduh', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'neduhem'   => ['neduh', 'neduh', [['Sing', 'S', 'Ins', '7']]],
                'neduhóm'   => ['neduh', 'neduh', [['Plur', 'P', 'Dat', '3']]],
                'neduhoma'  => ['neduh', 'neduh', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'neduhóv'   => ['neduh', 'neduh', [['Plur', 'P', 'Gen', '2']]],
                'neduhové'  => ['neduh', 'neduh', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'neduhovi'  => ['neduh', 'neduh', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'neduhu'    => ['neduh', 'neduh', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'neduhú'    => ['neduh', 'neduh', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'neduhuom'  => ['neduh', 'neduh', [['Plur', 'P', 'Dat', '3']]],
                'neduhuov'  => ['neduh', 'neduh', [['Plur', 'P', 'Gen', '2']]],
                'neduhy'    => ['neduh', 'neduh', [['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5'], ['Plur', 'P', 'Ins', '7']]],
                'neduzě'    => ['neduh', 'neduh', [['Sing', 'S', 'Loc', '6']]],
                'neduzi'    => ['neduh', 'neduh', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'neduzie'   => ['neduh', 'neduh', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'neduziech' => ['neduh', 'neduh', [['Plur', 'P', 'Loc', '6']]],
                'neduže'    => ['neduh', 'neduh', [['Sing', 'S', 'Voc', '5']]],
                'oheň'     => ['oheň', 'oheň', [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Acc', '4']]],
                'ohňa'     => ['oheň', 'oheň', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'ohně'     => ['oheň', 'oheň', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4'], ['Sing', 'S', 'Loc', '6'], ['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5']]],
                'ohňe'     => ['oheň', 'oheň', [['Sing', 'S', 'Voc', '5']]],
                'ohněm'    => ['oheň', 'oheň', [['Sing', 'S', 'Ins', '7']]],
                'ohni'     => ['oheň', 'oheň', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5'], ['Plur', 'P', 'Ins', '7']]],
                'ohnie'    => ['oheň', 'oheň', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'ohniech'  => ['oheň', 'oheň', [['Plur', 'P', 'Loc', '6']]],
                'ohniem'   => ['oheň', 'oheň', [['Sing', 'S', 'Ins', '7']]],
                'ohniev'   => ['oheň', 'oheň', [['Plur', 'P', 'Gen', '2']]],
                'ohňóm'    => ['oheň', 'oheň', [['Plur', 'P', 'Dat', '3']]],
                'ohňoma'   => ['oheň', 'oheň', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'ohňóv'    => ['oheň', 'oheň', [['Plur', 'P', 'Gen', '2']]],
                'ohňové'   => ['oheň', 'oheň', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'ohňovi'   => ['oheň', 'oheň', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'ohňu'     => ['oheň', 'oheň', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'ohňú'     => ['oheň', 'oheň', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'ohňuom'   => ['oheň', 'oheň', [['Plur', 'P', 'Dat', '3']]],
                'ohňuov'   => ['oheň', 'oheň', [['Plur', 'P', 'Gen', '2']]],
                'uoheň'    => ['oheň', 'oheň', [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Acc', '4']]],
                'uohňa'    => ['oheň', 'oheň', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'uohně'    => ['oheň', 'oheň', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4'], ['Sing', 'S', 'Loc', '6'], ['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5']]],
                'uohňe'    => ['oheň', 'oheň', [['Sing', 'S', 'Voc', '5']]],
                'uohněm'   => ['oheň', 'oheň', [['Sing', 'S', 'Ins', '7']]],
                'uohni'    => ['oheň', 'oheň', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5'], ['Plur', 'P', 'Ins', '7']]],
                'uohnie'   => ['oheň', 'oheň', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'uohniech' => ['oheň', 'oheň', [['Plur', 'P', 'Loc', '6']]],
                'uohniem'  => ['oheň', 'oheň', [['Sing', 'S', 'Ins', '7']]],
                'uohniev'  => ['oheň', 'oheň', [['Plur', 'P', 'Gen', '2']]],
                'uohňóm'   => ['oheň', 'oheň', [['Plur', 'P', 'Dat', '3']]],
                'uohňoma'  => ['oheň', 'oheň', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'uohňóv'   => ['oheň', 'oheň', [['Plur', 'P', 'Gen', '2']]],
                'uohňové'  => ['oheň', 'oheň', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'uohňovi'  => ['oheň', 'oheň', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'uohňu'    => ['oheň', 'oheň', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'uohňú'    => ['oheň', 'oheň', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'uohňuom'  => ['oheň', 'oheň', [['Plur', 'P', 'Dat', '3']]],
                'uohňuov'  => ['oheň', 'oheň', [['Plur', 'P', 'Gen', '2']]],
                'okrajcě'    => ['okrajek', 'okrajek', [['Sing', 'S', 'Loc', '6']]],
                'okrajci'    => ['okrajek', 'okrajek', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'okrajcie'   => ['okrajek', 'okrajek', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'okrajciech' => ['okrajek', 'okrajek', [['Plur', 'P', 'Loc', '6']]],
                'okrajče'    => ['okrajek', 'okrajek', [['Sing', 'S', 'Voc', '5']]],
                'okrajek'    => ['okrajek', 'okrajek', [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Acc', '4']]],
                'okrajka'    => ['okrajek', 'okrajek', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'okrajkem'   => ['okrajek', 'okrajek', [['Sing', 'S', 'Ins', '7']]],
                'okrajkóm'   => ['okrajek', 'okrajek', [['Plur', 'P', 'Dat', '3']]],
                'okrajkoma'  => ['okrajek', 'okrajek', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'okrajkóv'   => ['okrajek', 'okrajek', [['Plur', 'P', 'Gen', '2']]],
                'okrajkové'  => ['okrajek', 'okrajek', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'okrajkovi'  => ['okrajek', 'okrajek', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'okrajku'    => ['okrajek', 'okrajek', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Voc', '5'], ['Sing', 'S', 'Loc', '6']]],
                'okrajkú'    => ['okrajek', 'okrajek', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'okrajkuom'  => ['okrajek', 'okrajek', [['Plur', 'P', 'Dat', '3']]],
                'okrajkuov'  => ['okrajek', 'okrajek', [['Plur', 'P', 'Gen', '2']]],
                'okrajky'    => ['okrajek', 'okrajek', [['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5'], ['Plur', 'P', 'Ins', '7']]],
                'ostatcě'     => ['ostatek', 'ostatek', [['Sing', 'S', 'Loc', '6']]],
                'ostatci'     => ['ostatek', 'ostatek', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'ostatcie'    => ['ostatek', 'ostatek', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'ostatciech'  => ['ostatek', 'ostatek', [['Plur', 'P', 'Loc', '6']]],
                'ostatče'     => ['ostatek', 'ostatek', [['Sing', 'S', 'Voc', '5']]],
                'ostatek'     => ['ostatek', 'ostatek', [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Acc', '4']]],
                'ostatka'     => ['ostatek', 'ostatek', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'ostatkem'    => ['ostatek', 'ostatek', [['Sing', 'S', 'Ins', '7']]],
                'ostatkóm'    => ['ostatek', 'ostatek', [['Plur', 'P', 'Dat', '3']]],
                'ostatkoma'   => ['ostatek', 'ostatek', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'ostatkóv'    => ['ostatek', 'ostatek', [['Plur', 'P', 'Gen', '2']]],
                'ostatkové'   => ['ostatek', 'ostatek', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'ostatkovi'   => ['ostatek', 'ostatek', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'ostatku'     => ['ostatek', 'ostatek', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Voc', '5'], ['Sing', 'S', 'Loc', '6']]],
                'ostatkú'     => ['ostatek', 'ostatek', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'ostatkuom'   => ['ostatek', 'ostatek', [['Plur', 'P', 'Dat', '3']]],
                'ostatkuov'   => ['ostatek', 'ostatek', [['Plur', 'P', 'Gen', '2']]],
                'ostatky'     => ['ostatek', 'ostatek', [['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5'], ['Plur', 'P', 'Ins', '7']]],
                'uostatcě'    => ['ostatek', 'ostatek', [['Sing', 'S', 'Loc', '6']]],
                'uostatci'    => ['ostatek', 'ostatek', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'uostatcie'   => ['ostatek', 'ostatek', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'uostatciech' => ['ostatek', 'ostatek', [['Plur', 'P', 'Loc', '6']]],
                'uostatče'    => ['ostatek', 'ostatek', [['Sing', 'S', 'Voc', '5']]],
                'uostatek'    => ['ostatek', 'ostatek', [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Acc', '4']]],
                'uostatka'    => ['ostatek', 'ostatek', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'uostatkem'   => ['ostatek', 'ostatek', [['Sing', 'S', 'Ins', '7']]],
                'uostatkóm'   => ['ostatek', 'ostatek', [['Plur', 'P', 'Dat', '3']]],
                'uostatkoma'  => ['ostatek', 'ostatek', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'uostatkóv'   => ['ostatek', 'ostatek', [['Plur', 'P', 'Gen', '2']]],
                'uostatkové'  => ['ostatek', 'ostatek', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'uostatkovi'  => ['ostatek', 'ostatek', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'uostatku'    => ['ostatek', 'ostatek', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Voc', '5'], ['Sing', 'S', 'Loc', '6']]],
                'uostatkú'    => ['ostatek', 'ostatek', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'uostatkuom'  => ['ostatek', 'ostatek', [['Plur', 'P', 'Dat', '3']]],
                'uostatkuov'  => ['ostatek', 'ostatek', [['Plur', 'P', 'Gen', '2']]],
                'uostatky'    => ['ostatek', 'ostatek', [['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5'], ['Plur', 'P', 'Ins', '7']]],
                'otruscě'    => ['otrusek', 'otrusek', [['Sing', 'S', 'Loc', '6']]],
                'otrusci'    => ['otrusek', 'otrusek', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'otruscie'   => ['otrusek', 'otrusek', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'otrusciech' => ['otrusek', 'otrusek', [['Plur', 'P', 'Loc', '6']]],
                'otrusče'    => ['otrusek', 'otrusek', [['Sing', 'S', 'Voc', '5']]],
                'otrusek'    => ['otrusek', 'otrusek', [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Acc', '4']]],
                'otruska'    => ['otrusek', 'otrusek', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'otruskem'   => ['otrusek', 'otrusek', [['Sing', 'S', 'Ins', '7']]],
                'otruskóm'   => ['otrusek', 'otrusek', [['Plur', 'P', 'Dat', '3']]],
                'otruskoma'  => ['otrusek', 'otrusek', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'otruskóv'   => ['otrusek', 'otrusek', [['Plur', 'P', 'Gen', '2']]],
                'otruskové'  => ['otrusek', 'otrusek', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'otruskovi'  => ['otrusek', 'otrusek', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'otrusku'    => ['otrusek', 'otrusek', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Voc', '5'], ['Sing', 'S', 'Loc', '6']]],
                'otruskú'    => ['otrusek', 'otrusek', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'otruskuom'  => ['otrusek', 'otrusek', [['Plur', 'P', 'Dat', '3']]],
                'otruskuov'  => ['otrusek', 'otrusek', [['Plur', 'P', 'Gen', '2']]],
                'otrusky'    => ['otrusek', 'otrusek', [['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5'], ['Plur', 'P', 'Ins', '7']]],
                'pas'     => ['pas', 'pas', [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Acc', '4']]],
                'pasa'    => ['pas', 'pas', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'pase'    => ['pas', 'pas', [['Sing', 'S', 'Voc', '5']]],
                'pasě'    => ['pas', 'pas', [['Sing', 'S', 'Loc', '6']]],
                'pasem'   => ['pas', 'pas', [['Sing', 'S', 'Ins', '7']]],
                'pasi'    => ['pas', 'pas', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'pasie'   => ['pas', 'pas', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'pasiech' => ['pas', 'pas', [['Plur', 'P', 'Loc', '6']]],
                'pasóm'   => ['pas', 'pas', [['Plur', 'P', 'Dat', '3']]],
                'pasoma'  => ['pas', 'pas', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'pasóv'   => ['pas', 'pas', [['Plur', 'P', 'Gen', '2']]],
                'pasové'  => ['pas', 'pas', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'pasovi'  => ['pas', 'pas', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'pasu'    => ['pas', 'pas', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'pasú'    => ['pas', 'pas', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'pasuom'  => ['pas', 'pas', [['Plur', 'P', 'Dat', '3']]],
                'pasuov'  => ['pas', 'pas', [['Plur', 'P', 'Gen', '2']]],
                'pasy'    => ['pas', 'pas', [['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5'], ['Plur', 'P', 'Ins', '7']]],
                'peniez'     => ['peníz', 'peniez', [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Acc', '4']]],
                'penieza'    => ['peníz', 'peniez', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'penieze'    => ['peníz', 'peniez', [['Sing', 'S', 'Voc', '5']]],
                'peniezě'    => ['peníz', 'peniez', [['Sing', 'S', 'Loc', '6']]],
                'peniezem'   => ['peníz', 'peniez', [['Sing', 'S', 'Ins', '7']]],
                'peniezi'    => ['peníz', 'peniez', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'peniezie'   => ['peníz', 'peniez', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'penieziech' => ['peníz', 'peniez', [['Plur', 'P', 'Loc', '6']]],
                'peniezóm'   => ['peníz', 'peniez', [['Plur', 'P', 'Dat', '3']]],
                'peniezoma'  => ['peníz', 'peniez', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'peniezóv'   => ['peníz', 'peniez', [['Plur', 'P', 'Gen', '2']]],
                'peniezové'  => ['peníz', 'peniez', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'peniezovi'  => ['peníz', 'peniez', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'peniezu'    => ['peníz', 'peniez', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'peniezú'    => ['peníz', 'peniez', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'peniezuom'  => ['peníz', 'peniez', [['Plur', 'P', 'Dat', '3']]],
                'peniezuov'  => ['peníz', 'peniez', [['Plur', 'P', 'Gen', '2']]],
                'peniezy'    => ['peníz', 'peniez', [['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5'], ['Plur', 'P', 'Ins', '7']]],
                'peníz'      => ['peníz', 'peniez', [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Acc', '4']]],
                'peníza'     => ['peníz', 'peniez', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'peníze'     => ['peníz', 'peniez', [['Sing', 'S', 'Voc', '5']]],
                'penízě'     => ['peníz', 'peniez', [['Sing', 'S', 'Loc', '6']]],
                'penízem'    => ['peníz', 'peniez', [['Sing', 'S', 'Ins', '7']]],
                'penízi'     => ['peníz', 'peniez', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'penízie'    => ['peníz', 'peniez', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'peníziech'  => ['peníz', 'peniez', [['Plur', 'P', 'Loc', '6']]],
                'penízóm'    => ['peníz', 'peniez', [['Plur', 'P', 'Dat', '3']]],
                'penízoma'   => ['peníz', 'peniez', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'penízóv'    => ['peníz', 'peniez', [['Plur', 'P', 'Gen', '2']]],
                'penízové'   => ['peníz', 'peniez', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'penízovi'   => ['peníz', 'peniez', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'penízu'     => ['peníz', 'peniez', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'penízú'     => ['peníz', 'peniez', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'penízuom'   => ['peníz', 'peniez', [['Plur', 'P', 'Dat', '3']]],
                'penízuov'   => ['peníz', 'peniez', [['Plur', 'P', 'Gen', '2']]],
                'penízy'     => ['peníz', 'peniez', [['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5'], ['Plur', 'P', 'Ins', '7']]],
                'pláč'     => ['pláč', 'pláč', [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Acc', '4']]],
                'pláča'    => ['pláč', 'pláč', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'pláče'    => ['pláč', 'pláč', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4'], ['Sing', 'S', 'Voc', '5'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5']]],
                'pláčě'    => ['pláč', 'pláč', [['Sing', 'S', 'Loc', '6'], ['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5']]],
                'pláčem'   => ['pláč', 'pláč', [['Sing', 'S', 'Ins', '7']]],
                'pláči'    => ['pláč', 'pláč', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5'], ['Plur', 'P', 'Ins', '7']]],
                'pláčie'   => ['pláč', 'pláč', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'pláčiech' => ['pláč', 'pláč', [['Plur', 'P', 'Loc', '6']]],
                'pláčiem'  => ['pláč', 'pláč', [['Sing', 'S', 'Ins', '7']]],
                'pláčiev'  => ['pláč', 'pláč', [['Plur', 'P', 'Gen', '2']]],
                'pláčóm'   => ['pláč', 'pláč', [['Plur', 'P', 'Dat', '3']]],
                'pláčoma'  => ['pláč', 'pláč', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'pláčóv'   => ['pláč', 'pláč', [['Plur', 'P', 'Gen', '2']]],
                'pláčové'  => ['pláč', 'pláč', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'pláčovi'  => ['pláč', 'pláč', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'pláču'    => ['pláč', 'pláč', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'pláčú'    => ['pláč', 'pláč', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'pláčuom'  => ['pláč', 'pláč', [['Plur', 'P', 'Dat', '3']]],
                'pláčuov'  => ['pláč', 'pláč', [['Plur', 'P', 'Gen', '2']]],
                'plamen'     => ['plamen', 'plamen', [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Acc', '4']]],
                'plamena'    => ['plamen', 'plamen', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'plamene'    => ['plamen', 'plamen', [['Sing', 'S', 'Voc', '5']]],
                'plameně'    => ['plamen', 'plamen', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4'], ['Sing', 'S', 'Loc', '6'], ['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5']]],
                'plamenem'   => ['plamen', 'plamen', [['Sing', 'S', 'Ins', '7']]],
                'plameni'    => ['plamen', 'plamen', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5'], ['Plur', 'P', 'Ins', '7']]],
                'plamenie'   => ['plamen', 'plamen', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'plameniech' => ['plamen', 'plamen', [['Plur', 'P', 'Loc', '6']]],
                'plameniem'  => ['plamen', 'plamen', [['Sing', 'S', 'Ins', '7']]],
                'plameniev'  => ['plamen', 'plamen', [['Plur', 'P', 'Gen', '2']]],
                'plamenóm'   => ['plamen', 'plamen', [['Plur', 'P', 'Dat', '3']]],
                'plamenoma'  => ['plamen', 'plamen', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'plamenóv'   => ['plamen', 'plamen', [['Plur', 'P', 'Gen', '2']]],
                'plamenové'  => ['plamen', 'plamen', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'plamenovi'  => ['plamen', 'plamen', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'plamenu'    => ['plamen', 'plamen', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'plamenú'    => ['plamen', 'plamen', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'plamenuom'  => ['plamen', 'plamen', [['Plur', 'P', 'Dat', '3']]],
                'plamenuov'  => ['plamen', 'plamen', [['Plur', 'P', 'Gen', '2']]],
                'plášč'     => ['plášť', 'plášč', [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Acc', '4']]],
                'plášča'    => ['plášť', 'plášč', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'plášče'    => ['plášť', 'plášč', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4'], ['Sing', 'S', 'Voc', '5'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5']]],
                'pláščě'    => ['plášť', 'plášč', [['Sing', 'S', 'Loc', '6'], ['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5']]],
                'pláščem'   => ['plášť', 'plášč', [['Sing', 'S', 'Ins', '7']]],
                'plášči'    => ['plášť', 'plášč', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5'], ['Plur', 'P', 'Ins', '7']]],
                'pláščie'   => ['plášť', 'plášč', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'pláščiech' => ['plášť', 'plášč', [['Plur', 'P', 'Loc', '6']]],
                'pláščiem'  => ['plášť', 'plášč', [['Sing', 'S', 'Ins', '7']]],
                'pláščiev'  => ['plášť', 'plášč', [['Plur', 'P', 'Gen', '2']]],
                'pláščóm'   => ['plášť', 'plášč', [['Plur', 'P', 'Dat', '3']]],
                'pláščoma'  => ['plášť', 'plášč', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'pláščóv'   => ['plášť', 'plášč', [['Plur', 'P', 'Gen', '2']]],
                'pláščové'  => ['plášť', 'plášč', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'pláščovi'  => ['plášť', 'plášč', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'plášču'    => ['plášť', 'plášč', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'pláščú'    => ['plášť', 'plášč', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'pláščuom'  => ['plášť', 'plášč', [['Plur', 'P', 'Dat', '3']]],
                'pláščuov'  => ['plášť', 'plášč', [['Plur', 'P', 'Gen', '2']]],
                'plášť'     => ['plášť', 'plášč', [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Acc', '4']]],
                'plášťa'    => ['plášť', 'plášč', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'pláště'    => ['plášť', 'plášč', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4'], ['Sing', 'S', 'Loc', '6'], ['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5']]],
                'plášťe'    => ['plášť', 'plášč', [['Sing', 'S', 'Voc', '5']]],
                'pláštěm'   => ['plášť', 'plášč', [['Sing', 'S', 'Ins', '7']]],
                'plášti'    => ['plášť', 'plášč', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5'], ['Plur', 'P', 'Ins', '7']]],
                'pláštie'   => ['plášť', 'plášč', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'pláštiech' => ['plášť', 'plášč', [['Plur', 'P', 'Loc', '6']]],
                'pláštiem'  => ['plášť', 'plášč', [['Sing', 'S', 'Ins', '7']]],
                'pláštiev'  => ['plášť', 'plášč', [['Plur', 'P', 'Gen', '2']]],
                'plášťóm'   => ['plášť', 'plášč', [['Plur', 'P', 'Dat', '3']]],
                'plášťoma'  => ['plášť', 'plášč', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'plášťóv'   => ['plášť', 'plášč', [['Plur', 'P', 'Gen', '2']]],
                'plášťové'  => ['plášť', 'plášč', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'plášťovi'  => ['plášť', 'plášč', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'plášťu'    => ['plášť', 'plášč', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'plášťú'    => ['plášť', 'plášč', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'plášťuom'  => ['plášť', 'plášč', [['Plur', 'P', 'Dat', '3']]],
                'plášťuov'  => ['plášť', 'plášč', [['Plur', 'P', 'Gen', '2']]],
                'podhrdlcě'    => ['podhrdlek', 'podhrdlek', [['Sing', 'S', 'Loc', '6']]],
                'podhrdlci'    => ['podhrdlek', 'podhrdlek', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'podhrdlcie'   => ['podhrdlek', 'podhrdlek', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'podhrdlciech' => ['podhrdlek', 'podhrdlek', [['Plur', 'P', 'Loc', '6']]],
                'podhrdlče'    => ['podhrdlek', 'podhrdlek', [['Sing', 'S', 'Voc', '5']]],
                'podhrdlek'    => ['podhrdlek', 'podhrdlek', [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Acc', '4']]],
                'podhrdlka'    => ['podhrdlek', 'podhrdlek', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'podhrdlkem'   => ['podhrdlek', 'podhrdlek', [['Sing', 'S', 'Ins', '7']]],
                'podhrdlkóm'   => ['podhrdlek', 'podhrdlek', [['Plur', 'P', 'Dat', '3']]],
                'podhrdlkoma'  => ['podhrdlek', 'podhrdlek', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'podhrdlkóv'   => ['podhrdlek', 'podhrdlek', [['Plur', 'P', 'Gen', '2']]],
                'podhrdlkové'  => ['podhrdlek', 'podhrdlek', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'podhrdlkovi'  => ['podhrdlek', 'podhrdlek', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'podhrdlku'    => ['podhrdlek', 'podhrdlek', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Voc', '5'], ['Sing', 'S', 'Loc', '6']]],
                'podhrdlkú'    => ['podhrdlek', 'podhrdlek', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'podhrdlkuom'  => ['podhrdlek', 'podhrdlek', [['Plur', 'P', 'Dat', '3']]],
                'podhrdlkuov'  => ['podhrdlek', 'podhrdlek', [['Plur', 'P', 'Gen', '2']]],
                'podhrdlky'    => ['podhrdlek', 'podhrdlek', [['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5'], ['Plur', 'P', 'Ins', '7']]],
                'podolcě'    => ['podolek', 'podolek', [['Sing', 'S', 'Loc', '6']]],
                'podolci'    => ['podolek', 'podolek', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'podolcie'   => ['podolek', 'podolek', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'podolciech' => ['podolek', 'podolek', [['Plur', 'P', 'Loc', '6']]],
                'podolče'    => ['podolek', 'podolek', [['Sing', 'S', 'Voc', '5']]],
                'podolek'    => ['podolek', 'podolek', [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Acc', '4']]],
                'podolka'    => ['podolek', 'podolek', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'podolkem'   => ['podolek', 'podolek', [['Sing', 'S', 'Ins', '7']]],
                'podolkóm'   => ['podolek', 'podolek', [['Plur', 'P', 'Dat', '3']]],
                'podolkoma'  => ['podolek', 'podolek', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'podolkóv'   => ['podolek', 'podolek', [['Plur', 'P', 'Gen', '2']]],
                'podolkové'  => ['podolek', 'podolek', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'podolkovi'  => ['podolek', 'podolek', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'podolku'    => ['podolek', 'podolek', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Voc', '5'], ['Sing', 'S', 'Loc', '6']]],
                'podolkú'    => ['podolek', 'podolek', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'podolkuom'  => ['podolek', 'podolek', [['Plur', 'P', 'Dat', '3']]],
                'podolkuov'  => ['podolek', 'podolek', [['Plur', 'P', 'Gen', '2']]],
                'podolky'    => ['podolek', 'podolek', [['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5'], ['Plur', 'P', 'Ins', '7']]],
                'poklad'     => ['poklad', 'poklad', [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Acc', '4']]],
                'poklada'    => ['poklad', 'poklad', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'poklade'    => ['poklad', 'poklad', [['Sing', 'S', 'Voc', '5']]],
                'pokladě'    => ['poklad', 'poklad', [['Sing', 'S', 'Loc', '6']]],
                'pokladem'   => ['poklad', 'poklad', [['Sing', 'S', 'Ins', '7']]],
                'pokladi'    => ['poklad', 'poklad', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'pokladie'   => ['poklad', 'poklad', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'pokladiech' => ['poklad', 'poklad', [['Plur', 'P', 'Loc', '6']]],
                'pokladóm'   => ['poklad', 'poklad', [['Plur', 'P', 'Dat', '3']]],
                'pokladoma'  => ['poklad', 'poklad', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'pokladóv'   => ['poklad', 'poklad', [['Plur', 'P', 'Gen', '2']]],
                'pokladové'  => ['poklad', 'poklad', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'pokladovi'  => ['poklad', 'poklad', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'pokladu'    => ['poklad', 'poklad', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'pokladú'    => ['poklad', 'poklad', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'pokladuom'  => ['poklad', 'poklad', [['Plur', 'P', 'Dat', '3']]],
                'pokladuov'  => ['poklad', 'poklad', [['Plur', 'P', 'Gen', '2']]],
                'poklady'    => ['poklad', 'poklad', [['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5'], ['Plur', 'P', 'Ins', '7']]],
                'příklad'     => ['příklad', 'příklad', [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Acc', '4']]],
                'příklada'    => ['příklad', 'příklad', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'příklade'    => ['příklad', 'příklad', [['Sing', 'S', 'Voc', '5']]],
                'příkladě'    => ['příklad', 'příklad', [['Sing', 'S', 'Loc', '6']]],
                'příkladem'   => ['příklad', 'příklad', [['Sing', 'S', 'Ins', '7']]],
                'příkladi'    => ['příklad', 'příklad', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'příkladie'   => ['příklad', 'příklad', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'příkladiech' => ['příklad', 'příklad', [['Plur', 'P', 'Loc', '6']]],
                'příkladóm'   => ['příklad', 'příklad', [['Plur', 'P', 'Dat', '3']]],
                'příkladoma'  => ['příklad', 'příklad', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'příkladóv'   => ['příklad', 'příklad', [['Plur', 'P', 'Gen', '2']]],
                'příkladové'  => ['příklad', 'příklad', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'příkladovi'  => ['příklad', 'příklad', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'příkladu'    => ['příklad', 'příklad', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'příkladú'    => ['příklad', 'příklad', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'příkladuom'  => ['příklad', 'příklad', [['Plur', 'P', 'Dat', '3']]],
                'příkladuov'  => ['příklad', 'příklad', [['Plur', 'P', 'Gen', '2']]],
                'příklady'    => ['příklad', 'příklad', [['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5'], ['Plur', 'P', 'Ins', '7']]],
                'rov'     => ['rov', 'rov', [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Acc', '4']]],
                'rova'    => ['rov', 'rov', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'rove'    => ['rov', 'rov', [['Sing', 'S', 'Voc', '5']]],
                'rově'    => ['rov', 'rov', [['Sing', 'S', 'Loc', '6']]],
                'rovem'   => ['rov', 'rov', [['Sing', 'S', 'Ins', '7']]],
                'rovi'    => ['rov', 'rov', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'rovie'   => ['rov', 'rov', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'roviech' => ['rov', 'rov', [['Plur', 'P', 'Loc', '6']]],
                'rovóm'   => ['rov', 'rov', [['Plur', 'P', 'Dat', '3']]],
                'rovoma'  => ['rov', 'rov', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'rovóv'   => ['rov', 'rov', [['Plur', 'P', 'Gen', '2']]],
                'rovové'  => ['rov', 'rov', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'rovovi'  => ['rov', 'rov', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'rovu'    => ['rov', 'rov', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'rovú'    => ['rov', 'rov', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'rovuom'  => ['rov', 'rov', [['Plur', 'P', 'Dat', '3']]],
                'rovuov'  => ['rov', 'rov', [['Plur', 'P', 'Gen', '2']]],
                'rovy'    => ['rov', 'rov', [['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5'], ['Plur', 'P', 'Ins', '7']]],
                'sbor'      => ['sbor', 'sbuor', [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Acc', '4']]],
                'sbora'     => ['sbor', 'sbuor', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'sborem'    => ['sbor', 'sbuor', [['Sing', 'S', 'Ins', '7']]],
                'sboróm'    => ['sbor', 'sbuor', [['Plur', 'P', 'Dat', '3']]],
                'sboroma'   => ['sbor', 'sbuor', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'sboróv'    => ['sbor', 'sbuor', [['Plur', 'P', 'Gen', '2']]],
                'sborové'   => ['sbor', 'sbuor', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'sborovi'   => ['sbor', 'sbuor', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'sboru'     => ['sbor', 'sbuor', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'sború'     => ['sbor', 'sbuor', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'sboruom'   => ['sbor', 'sbuor', [['Plur', 'P', 'Dat', '3']]],
                'sboruov'   => ['sbor', 'sbuor', [['Plur', 'P', 'Gen', '2']]],
                'sbory'     => ['sbor', 'sbuor', [['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5'], ['Plur', 'P', 'Ins', '7']]],
                'sboře'     => ['sbor', 'sbuor', [['Sing', 'S', 'Voc', '5']]],
                'sbořě'     => ['sbor', 'sbuor', [['Sing', 'S', 'Loc', '6']]],
                'sboři'     => ['sbor', 'sbuor', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'sbořie'    => ['sbor', 'sbuor', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'sbořiech'  => ['sbor', 'sbuor', [['Plur', 'P', 'Loc', '6']]],
                'sbuor'     => ['sbor', 'sbuor', [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Acc', '4']]],
                'sbuora'    => ['sbor', 'sbuor', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'sbuorem'   => ['sbor', 'sbuor', [['Sing', 'S', 'Ins', '7']]],
                'sbuoróm'   => ['sbor', 'sbuor', [['Plur', 'P', 'Dat', '3']]],
                'sbuoroma'  => ['sbor', 'sbuor', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'sbuoróv'   => ['sbor', 'sbuor', [['Plur', 'P', 'Gen', '2']]],
                'sbuorové'  => ['sbor', 'sbuor', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'sbuorovi'  => ['sbor', 'sbuor', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'sbuoru'    => ['sbor', 'sbuor', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'sbuorú'    => ['sbor', 'sbuor', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'sbuoruom'  => ['sbor', 'sbuor', [['Plur', 'P', 'Dat', '3']]],
                'sbuoruov'  => ['sbor', 'sbuor', [['Plur', 'P', 'Gen', '2']]],
                'sbuory'    => ['sbor', 'sbuor', [['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5'], ['Plur', 'P', 'Ins', '7']]],
                'sbuoře'    => ['sbor', 'sbuor', [['Sing', 'S', 'Voc', '5']]],
                'sbuořě'    => ['sbor', 'sbuor', [['Sing', 'S', 'Loc', '6']]],
                'sbuoři'    => ['sbor', 'sbuor', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'sbuořie'   => ['sbor', 'sbuor', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'sbuořiech' => ['sbor', 'sbuor', [['Plur', 'P', 'Loc', '6']]],
                'skutcě'    => ['skutek', 'skutek', [['Sing', 'S', 'Loc', '6']]],
                'skutci'    => ['skutek', 'skutek', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'skutcie'   => ['skutek', 'skutek', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'skutciech' => ['skutek', 'skutek', [['Plur', 'P', 'Loc', '6']]],
                'skutče'    => ['skutek', 'skutek', [['Sing', 'S', 'Voc', '5']]],
                'skutek'    => ['skutek', 'skutek', [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Acc', '4']]],
                'skutka'    => ['skutek', 'skutek', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'skutkem'   => ['skutek', 'skutek', [['Sing', 'S', 'Ins', '7']]],
                'skutkóm'   => ['skutek', 'skutek', [['Plur', 'P', 'Dat', '3']]],
                'skutkoma'  => ['skutek', 'skutek', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'skutkóv'   => ['skutek', 'skutek', [['Plur', 'P', 'Gen', '2']]],
                'skutkové'  => ['skutek', 'skutek', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'skutkovi'  => ['skutek', 'skutek', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'skutku'    => ['skutek', 'skutek', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Voc', '5'], ['Sing', 'S', 'Loc', '6']]],
                'skutkú'    => ['skutek', 'skutek', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'skutkuom'  => ['skutek', 'skutek', [['Plur', 'P', 'Dat', '3']]],
                'skutkuov'  => ['skutek', 'skutek', [['Plur', 'P', 'Gen', '2']]],
                'skutky'    => ['skutek', 'skutek', [['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5'], ['Plur', 'P', 'Ins', '7']]],
                'sen'    => ['sen', 'sen', [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Acc', '4']]],
                'sna'    => ['sen', 'sen', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'snách'  => ['sen', 'sen', [['Plur', 'P', 'Loc', '6']]],
                'sne'    => ['sen', 'sen', [['Sing', 'S', 'Voc', '5']]],
                'sně'    => ['sen', 'sen', [['Sing', 'S', 'Loc', '6']]],
                'snem'   => ['sen', 'sen', [['Sing', 'S', 'Ins', '7']]],
                'sni'    => ['sen', 'sen', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'snie'   => ['sen', 'sen', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'sniech' => ['sen', 'sen', [['Plur', 'P', 'Loc', '6']]],
                'snóm'   => ['sen', 'sen', [['Plur', 'P', 'Dat', '3']]],
                'snoma'  => ['sen', 'sen', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'snóv'   => ['sen', 'sen', [['Plur', 'P', 'Gen', '2']]],
                'snové'  => ['sen', 'sen', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'snovi'  => ['sen', 'sen', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'snu'    => ['sen', 'sen', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'snú'    => ['sen', 'sen', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'snuom'  => ['sen', 'sen', [['Plur', 'P', 'Dat', '3']]],
                'snuov'  => ['sen', 'sen', [['Plur', 'P', 'Gen', '2']]],
                'sny'    => ['sen', 'sen', [['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5'], ['Plur', 'P', 'Ins', '7']]],
                'stien'     => ['stín', 'stien', [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Acc', '4']]],
                'stiena'    => ['stín', 'stien', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'stiene'    => ['stín', 'stien', [['Sing', 'S', 'Voc', '5']]],
                'stieně'    => ['stín', 'stien', [['Sing', 'S', 'Loc', '6']]],
                'stienem'   => ['stín', 'stien', [['Sing', 'S', 'Ins', '7']]],
                'stieni'    => ['stín', 'stien', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'stienie'   => ['stín', 'stien', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'stieniech' => ['stín', 'stien', [['Plur', 'P', 'Loc', '6']]],
                'stienóm'   => ['stín', 'stien', [['Plur', 'P', 'Dat', '3']]],
                'stienoma'  => ['stín', 'stien', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'stienóv'   => ['stín', 'stien', [['Plur', 'P', 'Gen', '2']]],
                'stienové'  => ['stín', 'stien', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'stienovi'  => ['stín', 'stien', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'stienu'    => ['stín', 'stien', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'stienú'    => ['stín', 'stien', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'stienuom'  => ['stín', 'stien', [['Plur', 'P', 'Dat', '3']]],
                'stienuov'  => ['stín', 'stien', [['Plur', 'P', 'Gen', '2']]],
                'stieny'    => ['stín', 'stien', [['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5'], ['Plur', 'P', 'Ins', '7']]],
                'stol'     => ['stůl', 'stól', [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Acc', '4']]],
                'stól'     => ['stůl', 'stól', [['Sing', 'S', 'Nom', '1']]],
                'stola'    => ['stůl', 'stól', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'stole'    => ['stůl', 'stól', [['Sing', 'S', 'Voc', '5']]],
                'stolě'    => ['stůl', 'stól', [['Sing', 'S', 'Loc', '6']]],
                'stolem'   => ['stůl', 'stól', [['Sing', 'S', 'Ins', '7']]],
                'stoli'    => ['stůl', 'stól', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'stolie'   => ['stůl', 'stól', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'stoliech' => ['stůl', 'stól', [['Plur', 'P', 'Loc', '6']]],
                'stolóm'   => ['stůl', 'stól', [['Plur', 'P', 'Dat', '3']]],
                'stoloma'  => ['stůl', 'stól', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'stolóv'   => ['stůl', 'stól', [['Plur', 'P', 'Gen', '2']]],
                'stolové'  => ['stůl', 'stól', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'stolovi'  => ['stůl', 'stól', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'stolu'    => ['stůl', 'stól', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'stolú'    => ['stůl', 'stól', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'stoluom'  => ['stůl', 'stól', [['Plur', 'P', 'Dat', '3']]],
                'stoluov'  => ['stůl', 'stól', [['Plur', 'P', 'Gen', '2']]],
                'stoly'    => ['stůl', 'stól', [['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5'], ['Plur', 'P', 'Ins', '7']]],
                'súd'     => ['soud', 'súd', [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Acc', '4']]],
                'súda'    => ['soud', 'súd', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'súde'    => ['soud', 'súd', [['Sing', 'S', 'Voc', '5']]],
                'súdě'    => ['soud', 'súd', [['Sing', 'S', 'Loc', '6']]],
                'súdem'   => ['soud', 'súd', [['Sing', 'S', 'Ins', '7']]],
                'súdi'    => ['soud', 'súd', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'súdie'   => ['soud', 'súd', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'súdiech' => ['soud', 'súd', [['Plur', 'P', 'Loc', '6']]],
                'súdóm'   => ['soud', 'súd', [['Plur', 'P', 'Dat', '3']]],
                'súdoma'  => ['soud', 'súd', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'súdóv'   => ['soud', 'súd', [['Plur', 'P', 'Gen', '2']]],
                'súdové'  => ['soud', 'súd', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'súdovi'  => ['soud', 'súd', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'súdu'    => ['soud', 'súd', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'súdú'    => ['soud', 'súd', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'súduom'  => ['soud', 'súd', [['Plur', 'P', 'Dat', '3']]],
                'súduov'  => ['soud', 'súd', [['Plur', 'P', 'Gen', '2']]],
                'súdy'    => ['soud', 'súd', [['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5'], ['Plur', 'P', 'Ins', '7']]],
                'ščěvícě'    => ['šťovík', 'ščěvík', [['Sing', 'S', 'Loc', '6']]],
                'ščěvíci'    => ['šťovík', 'ščěvík', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'ščěvície'   => ['šťovík', 'ščěvík', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'ščěvíciech' => ['šťovík', 'ščěvík', [['Plur', 'P', 'Loc', '6']]],
                'ščěvíče'    => ['šťovík', 'ščěvík', [['Sing', 'S', 'Voc', '5']]],
                'ščěvík'     => ['šťovík', 'ščěvík', [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Acc', '4']]],
                'ščěvíka'    => ['šťovík', 'ščěvík', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'ščěvíkem'   => ['šťovík', 'ščěvík', [['Sing', 'S', 'Ins', '7']]],
                'ščěvíkóm'   => ['šťovík', 'ščěvík', [['Plur', 'P', 'Dat', '3']]],
                'ščěvíkoma'  => ['šťovík', 'ščěvík', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'ščěvíkóv'   => ['šťovík', 'ščěvík', [['Plur', 'P', 'Gen', '2']]],
                'ščěvíkové'  => ['šťovík', 'ščěvík', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'ščěvíkovi'  => ['šťovík', 'ščěvík', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'ščěvíku'    => ['šťovík', 'ščěvík', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Voc', '5'], ['Sing', 'S', 'Loc', '6']]],
                'ščěvíkú'    => ['šťovík', 'ščěvík', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'ščěvíkuom'  => ['šťovík', 'ščěvík', [['Plur', 'P', 'Dat', '3']]],
                'ščěvíkuov'  => ['šťovík', 'ščěvík', [['Plur', 'P', 'Gen', '2']]],
                'ščěvíky'    => ['šťovík', 'ščěvík', [['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5'], ['Plur', 'P', 'Ins', '7']]],
                'tisíc'     => ['tisíc', 'tisíc', [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Acc', '4']]],
                'tisíca'    => ['tisíc', 'tisíc', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'tisíce'    => ['tisíc', 'tisíc', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5']]],
                'tisícě'    => ['tisíc', 'tisíc', [['Sing', 'S', 'Loc', '6'], ['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5']]],
                'tisícem'   => ['tisíc', 'tisíc', [['Sing', 'S', 'Ins', '7']]],
                'tisíci'    => ['tisíc', 'tisíc', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5'], ['Plur', 'P', 'Ins', '7']]],
                'tisície'   => ['tisíc', 'tisíc', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'tisíciech' => ['tisíc', 'tisíc', [['Plur', 'P', 'Loc', '6']]],
                'tisíciem'  => ['tisíc', 'tisíc', [['Sing', 'S', 'Ins', '7']]],
                'tisíciev'  => ['tisíc', 'tisíc', [['Plur', 'P', 'Gen', '2']]],
                'tisícóm'   => ['tisíc', 'tisíc', [['Plur', 'P', 'Dat', '3']]],
                'tisícoma'  => ['tisíc', 'tisíc', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'tisícóv'   => ['tisíc', 'tisíc', [['Plur', 'P', 'Gen', '2']]],
                'tisícové'  => ['tisíc', 'tisíc', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'tisícovi'  => ['tisíc', 'tisíc', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'tisícu'    => ['tisíc', 'tisíc', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'tisícú'    => ['tisíc', 'tisíc', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'tisícuom'  => ['tisíc', 'tisíc', [['Plur', 'P', 'Dat', '3']]],
                'tisícuov'  => ['tisíc', 'tisíc', [['Plur', 'P', 'Gen', '2']]],
                'tisíče'    => ['tisíc', 'tisíc', [['Sing', 'S', 'Voc', '5']]],
                'úd'     => ['úd', 'úd', [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Acc', '4']]],
                'úda'    => ['úd', 'úd', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'úde'    => ['úd', 'úd', [['Sing', 'S', 'Voc', '5']]],
                'údě'    => ['úd', 'úd', [['Sing', 'S', 'Loc', '6']]],
                'údem'   => ['úd', 'úd', [['Sing', 'S', 'Ins', '7']]],
                'údi'    => ['úd', 'úd', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'údie'   => ['úd', 'úd', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'údiech' => ['úd', 'úd', [['Plur', 'P', 'Loc', '6']]],
                'údóm'   => ['úd', 'úd', [['Plur', 'P', 'Dat', '3']]],
                'údoma'  => ['úd', 'úd', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'údóv'   => ['úd', 'úd', [['Plur', 'P', 'Gen', '2']]],
                'údové'  => ['úd', 'úd', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'údovi'  => ['úd', 'úd', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'údu'    => ['úd', 'úd', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'údú'    => ['úd', 'úd', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'úduom'  => ['úd', 'úd', [['Plur', 'P', 'Dat', '3']]],
                'úduov'  => ['úd', 'úd', [['Plur', 'P', 'Gen', '2']]],
                'údy'    => ['úd', 'úd', [['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5'], ['Plur', 'P', 'Ins', '7']]],
                'uzlícě'    => ['uzlík', 'uzlík', [['Sing', 'S', 'Loc', '6']]],
                'uzlíci'    => ['uzlík', 'uzlík', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'uzlície'   => ['uzlík', 'uzlík', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'uzlíciech' => ['uzlík', 'uzlík', [['Plur', 'P', 'Loc', '6']]],
                'uzlíče'    => ['uzlík', 'uzlík', [['Sing', 'S', 'Voc', '5']]],
                'uzlík'     => ['uzlík', 'uzlík', [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Acc', '4']]],
                'uzlíka'    => ['uzlík', 'uzlík', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'uzlíkem'   => ['uzlík', 'uzlík', [['Sing', 'S', 'Ins', '7']]],
                'uzlíkóm'   => ['uzlík', 'uzlík', [['Plur', 'P', 'Dat', '3']]],
                'uzlíkoma'  => ['uzlík', 'uzlík', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'uzlíkóv'   => ['uzlík', 'uzlík', [['Plur', 'P', 'Gen', '2']]],
                'uzlíkové'  => ['uzlík', 'uzlík', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'uzlíkovi'  => ['uzlík', 'uzlík', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'uzlíku'    => ['uzlík', 'uzlík', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Voc', '5'], ['Sing', 'S', 'Loc', '6']]],
                'uzlíkú'    => ['uzlík', 'uzlík', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'uzlíkuom'  => ['uzlík', 'uzlík', [['Plur', 'P', 'Dat', '3']]],
                'uzlíkuov'  => ['uzlík', 'uzlík', [['Plur', 'P', 'Gen', '2']]],
                'uzlíky'    => ['uzlík', 'uzlík', [['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5'], ['Plur', 'P', 'Ins', '7']]],
                'užitcě'    => ['užitek', 'užitek', [['Sing', 'S', 'Loc', '6']]],
                'užitci'    => ['užitek', 'užitek', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'užitcie'   => ['užitek', 'užitek', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'užitciech' => ['užitek', 'užitek', [['Plur', 'P', 'Loc', '6']]],
                'užitče'    => ['užitek', 'užitek', [['Sing', 'S', 'Voc', '5']]],
                'užitek'    => ['užitek', 'užitek', [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Acc', '4']]],
                'užitka'    => ['užitek', 'užitek', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'užitkem'   => ['užitek', 'užitek', [['Sing', 'S', 'Ins', '7']]],
                'užitkóm'   => ['užitek', 'užitek', [['Plur', 'P', 'Dat', '3']]],
                'užitkoma'  => ['užitek', 'užitek', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'užitkóv'   => ['užitek', 'užitek', [['Plur', 'P', 'Gen', '2']]],
                'užitkové'  => ['užitek', 'užitek', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'užitkovi'  => ['užitek', 'užitek', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'užitku'    => ['užitek', 'užitek', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Voc', '5'], ['Sing', 'S', 'Loc', '6']]],
                'užitkú'    => ['užitek', 'užitek', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'užitkuom'  => ['užitek', 'užitek', [['Plur', 'P', 'Dat', '3']]],
                'užitkuov'  => ['užitek', 'užitek', [['Plur', 'P', 'Gen', '2']]],
                'užitky'    => ['užitek', 'užitek', [['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5'], ['Plur', 'P', 'Ins', '7']]],
                'větr'      => ['vítr', 'vietr', [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Acc', '4']]],
                'větra'     => ['vítr', 'vietr', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'větrem'    => ['vítr', 'vietr', [['Sing', 'S', 'Ins', '7']]],
                'větróm'    => ['vítr', 'vietr', [['Plur', 'P', 'Dat', '3']]],
                'větroma'   => ['vítr', 'vietr', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'větróv'    => ['vítr', 'vietr', [['Plur', 'P', 'Gen', '2']]],
                'větrové'   => ['vítr', 'vietr', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'větrovi'   => ['vítr', 'vietr', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'větru'     => ['vítr', 'vietr', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'větrú'     => ['vítr', 'vietr', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'větruom'   => ['vítr', 'vietr', [['Plur', 'P', 'Dat', '3']]],
                'větruov'   => ['vítr', 'vietr', [['Plur', 'P', 'Gen', '2']]],
                'větry'     => ['vítr', 'vietr', [['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5'], ['Plur', 'P', 'Ins', '7']]],
                'větře'     => ['vítr', 'vietr', [['Sing', 'S', 'Voc', '5']]],
                'větřě'     => ['vítr', 'vietr', [['Sing', 'S', 'Loc', '6']]],
                'větři'     => ['vítr', 'vietr', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'větřie'    => ['vítr', 'vietr', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'větřiech'  => ['vítr', 'vietr', [['Plur', 'P', 'Loc', '6']]],
                'vietr'     => ['vítr', 'vietr', [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Acc', '4']]],
                'vietra'    => ['vítr', 'vietr', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'vietrem'   => ['vítr', 'vietr', [['Sing', 'S', 'Ins', '7']]],
                'vietróm'   => ['vítr', 'vietr', [['Plur', 'P', 'Dat', '3']]],
                'vietroma'  => ['vítr', 'vietr', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'vietróv'   => ['vítr', 'vietr', [['Plur', 'P', 'Gen', '2']]],
                'vietrové'  => ['vítr', 'vietr', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'vietrovi'  => ['vítr', 'vietr', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'vietru'    => ['vítr', 'vietr', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'vietrú'    => ['vítr', 'vietr', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'vietruom'  => ['vítr', 'vietr', [['Plur', 'P', 'Dat', '3']]],
                'vietruov'  => ['vítr', 'vietr', [['Plur', 'P', 'Gen', '2']]],
                'vietry'    => ['vítr', 'vietr', [['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5'], ['Plur', 'P', 'Ins', '7']]],
                'vietře'    => ['vítr', 'vietr', [['Sing', 'S', 'Voc', '5']]],
                'vietřě'    => ['vítr', 'vietr', [['Sing', 'S', 'Loc', '6']]],
                'vietři'    => ['vítr', 'vietr', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'vietřie'   => ['vítr', 'vietr', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'vietřiech' => ['vítr', 'vietr', [['Plur', 'P', 'Loc', '6']]],
                'vlas'     => ['vlas', 'vlas', [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Acc', '4']]],
                'vlasa'    => ['vlas', 'vlas', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'vlase'    => ['vlas', 'vlas', [['Sing', 'S', 'Voc', '5']]],
                'vlasě'    => ['vlas', 'vlas', [['Sing', 'S', 'Loc', '6']]],
                'vlasem'   => ['vlas', 'vlas', [['Sing', 'S', 'Ins', '7']]],
                'vlasi'    => ['vlas', 'vlas', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'vlasie'   => ['vlas', 'vlas', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'vlasiech' => ['vlas', 'vlas', [['Plur', 'P', 'Loc', '6']]],
                'vlasóm'   => ['vlas', 'vlas', [['Plur', 'P', 'Dat', '3']]],
                'vlasoma'  => ['vlas', 'vlas', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'vlasóv'   => ['vlas', 'vlas', [['Plur', 'P', 'Gen', '2']]],
                'vlasové'  => ['vlas', 'vlas', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'vlasovi'  => ['vlas', 'vlas', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'vlasu'    => ['vlas', 'vlas', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'vlasú'    => ['vlas', 'vlas', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'vlasuom'  => ['vlas', 'vlas', [['Plur', 'P', 'Dat', '3']]],
                'vlasuov'  => ['vlas', 'vlas', [['Plur', 'P', 'Gen', '2']]],
                'vlasy'    => ['vlas', 'vlas', [['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5'], ['Plur', 'P', 'Ins', '7']]],
                'zárodcě'    => ['zárodek', 'zárodek', [['Sing', 'S', 'Loc', '6']]],
                'zárodci'    => ['zárodek', 'zárodek', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'zárodcie'   => ['zárodek', 'zárodek', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'zárodciech' => ['zárodek', 'zárodek', [['Plur', 'P', 'Loc', '6']]],
                'zárodče'    => ['zárodek', 'zárodek', [['Sing', 'S', 'Voc', '5']]],
                'zárodek'    => ['zárodek', 'zárodek', [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Acc', '4']]],
                'zárodka'    => ['zárodek', 'zárodek', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'zárodkem'   => ['zárodek', 'zárodek', [['Sing', 'S', 'Ins', '7']]],
                'zárodkóm'   => ['zárodek', 'zárodek', [['Plur', 'P', 'Dat', '3']]],
                'zárodkoma'  => ['zárodek', 'zárodek', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'zárodkóv'   => ['zárodek', 'zárodek', [['Plur', 'P', 'Gen', '2']]],
                'zárodkové'  => ['zárodek', 'zárodek', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'zárodkovi'  => ['zárodek', 'zárodek', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'zárodku'    => ['zárodek', 'zárodek', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Voc', '5'], ['Sing', 'S', 'Loc', '6']]],
                'zárodkú'    => ['zárodek', 'zárodek', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'zárodkuom'  => ['zárodek', 'zárodek', [['Plur', 'P', 'Dat', '3']]],
                'zárodkuov'  => ['zárodek', 'zárodek', [['Plur', 'P', 'Gen', '2']]],
                'zárodky'    => ['zárodek', 'zárodek', [['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5'], ['Plur', 'P', 'Ins', '7']]],
                'zástup'      => ['zástup',    'zástup',  [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Acc', '4']]],
                'zástupa'     => ['zástup',    'zástup',  [['Sing', 'S', 'Gen', '2']]],
                'zástupi'     => ['zástup',    'zástup',  [['Plur', 'P', 'Nom', '1']]],
                'zástupiech'  => ['zástup',    'zástup',  [['Plur', 'P', 'Loc', '6']]],
                'zástupóm'    => ['zástup',    'zástup',  [['Plur', 'P', 'Dat', '3']]],
                'zástupóv'    => ['zástup',    'zástup',  [['Plur', 'P', 'Gen', '2']]],
                'zástupové'   => ['zástup',    'zástup',  [['Plur', 'P', 'Nom', '1']]],
                'zástupu'     => ['zástup',    'zástup',  [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Dat', '3']]],
                'zástupuov'   => ['zástup',    'zástup',  [['Plur', 'P', 'Gen', '2']]],
                'zástupy'     => ['zástup',    'zástup',  [['Plur', 'P', 'Acc', '4']]],
                'zbytcě'    => ['zbytek', 'zbytek', [['Sing', 'S', 'Loc', '6']]],
                'zbytci'    => ['zbytek', 'zbytek', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'zbytcie'   => ['zbytek', 'zbytek', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'zbytciech' => ['zbytek', 'zbytek', [['Plur', 'P', 'Loc', '6']]],
                'zbytče'    => ['zbytek', 'zbytek', [['Sing', 'S', 'Voc', '5']]],
                'zbytek'    => ['zbytek', 'zbytek', [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Acc', '4']]],
                'zbytka'    => ['zbytek', 'zbytek', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'zbytkem'   => ['zbytek', 'zbytek', [['Sing', 'S', 'Ins', '7']]],
                'zbytkóm'   => ['zbytek', 'zbytek', [['Plur', 'P', 'Dat', '3']]],
                'zbytkoma'  => ['zbytek', 'zbytek', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'zbytkóv'   => ['zbytek', 'zbytek', [['Plur', 'P', 'Gen', '2']]],
                'zbytkové'  => ['zbytek', 'zbytek', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'zbytkovi'  => ['zbytek', 'zbytek', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'zbytku'    => ['zbytek', 'zbytek', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Voc', '5'], ['Sing', 'S', 'Loc', '6']]],
                'zbytkú'    => ['zbytek', 'zbytek', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'zbytkuom'  => ['zbytek', 'zbytek', [['Plur', 'P', 'Dat', '3']]],
                'zbytkuov'  => ['zbytek', 'zbytek', [['Plur', 'P', 'Gen', '2']]],
                'zbytky'    => ['zbytek', 'zbytek', [['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5'], ['Plur', 'P', 'Ins', '7']]],
                'zub'     => ['zub', 'zub', [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Acc', '4']]],
                'zuba'    => ['zub', 'zub', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'zube'    => ['zub', 'zub', [['Sing', 'S', 'Voc', '5']]],
                'zubě'    => ['zub', 'zub', [['Sing', 'S', 'Loc', '6']]],
                'zubem'   => ['zub', 'zub', [['Sing', 'S', 'Ins', '7']]],
                'zubi'    => ['zub', 'zub', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'zubie'   => ['zub', 'zub', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'zubiech' => ['zub', 'zub', [['Plur', 'P', 'Loc', '6']]],
                'zubóm'   => ['zub', 'zub', [['Plur', 'P', 'Dat', '3']]],
                'zuboma'  => ['zub', 'zub', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'zubóv'   => ['zub', 'zub', [['Plur', 'P', 'Gen', '2']]],
                'zubové'  => ['zub', 'zub', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'zubovi'  => ['zub', 'zub', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'zubu'    => ['zub', 'zub', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'zubú'    => ['zub', 'zub', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'zubuom'  => ['zub', 'zub', [['Plur', 'P', 'Dat', '3']]],
                'zubuov'  => ['zub', 'zub', [['Plur', 'P', 'Gen', '2']]],
                'zuby'    => ['zub', 'zub', [['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5'], ['Plur', 'P', 'Ins', '7']]]
            );
            my $ma = $ma{$lform}; die("Something is wrong: '$lform'") if(!defined($ma));
            $f[2] = $ma->[0];
            $f[9] = set_lemma1300($f[9], $ma->[1]);
            $f[3] = 'NOUN';
            # U některých slov umožňujeme několik čtení, ale pokud to není žádné z nich, dáme první jako default.
            my @alt = @{$ma->[2]};
            for(my $i = $#alt; $i >= 0 ; $i--)
            {
                if($i == 0 || defined($alt[$i][4]) && get_ref($f[9]) =~ m/^$alt[$i][4]$/ || $f[5] =~ m/Case=$alt[$i][2].*Number=$alt[$i][0]/)
                {
                    $f[4] = 'NNI'.$alt[$i][1].$alt[$i][3].'-----A----';
                    $f[5] = 'Animacy=Inan|Case='.$alt[$i][2].'|Gender=Masc|Number='.$alt[$i][0].'|Polarity=Pos';
                    last;
                }
            }
        }
        elsif($f[1] =~ m/^(Acheldemach|Bethlee?m|Jeruzalém|Jordán|Korozaim|Nazareth?)(a|e|ě|i|em)?$/i)
        {
            my $lform = lc($f[1]);
            my %ma =
            (
                'acheldemach' => ['Acheldemach', 'Acheldemach', [['Sing', 'S', 'Nom', '1']]],
                'bethleem'     => ['Betlém', 'Bethlem', [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Acc', '4']]],
                'bethleema'    => ['Betlém', 'Bethlem', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'bethleeme'    => ['Betlém', 'Bethlem', [['Sing', 'S', 'Voc', '5']]],
                'bethleemě'    => ['Betlém', 'Bethlem', [['Sing', 'S', 'Loc', '6']]],
                'bethleemem'   => ['Betlém', 'Bethlem', [['Sing', 'S', 'Ins', '7']]],
                'bethleemi'    => ['Betlém', 'Bethlem', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'bethleemie'   => ['Betlém', 'Bethlem', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'bethleemiech' => ['Betlém', 'Bethlem', [['Plur', 'P', 'Loc', '6']]],
                'bethleemóm'   => ['Betlém', 'Bethlem', [['Plur', 'P', 'Dat', '3']]],
                'bethleemoma'  => ['Betlém', 'Bethlem', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'bethleemóv'   => ['Betlém', 'Bethlem', [['Plur', 'P', 'Gen', '2']]],
                'bethleemové'  => ['Betlém', 'Bethlem', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'bethleemovi'  => ['Betlém', 'Bethlem', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'bethleemu'    => ['Betlém', 'Bethlem', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'bethleemú'    => ['Betlém', 'Bethlem', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'bethleemuom'  => ['Betlém', 'Bethlem', [['Plur', 'P', 'Dat', '3']]],
                'bethleemuov'  => ['Betlém', 'Bethlem', [['Plur', 'P', 'Gen', '2']]],
                'bethleemy'    => ['Betlém', 'Bethlem', [['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5'], ['Plur', 'P', 'Ins', '7']]],
                'bethlem'      => ['Betlém', 'Bethlem', [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Acc', '4']]],
                'bethlema'     => ['Betlém', 'Bethlem', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'bethleme'     => ['Betlém', 'Bethlem', [['Sing', 'S', 'Voc', '5']]],
                'bethlemě'     => ['Betlém', 'Bethlem', [['Sing', 'S', 'Loc', '6']]],
                'bethlemem'    => ['Betlém', 'Bethlem', [['Sing', 'S', 'Ins', '7']]],
                'bethlemi'     => ['Betlém', 'Bethlem', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'bethlemie'    => ['Betlém', 'Bethlem', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'bethlemiech'  => ['Betlém', 'Bethlem', [['Plur', 'P', 'Loc', '6']]],
                'bethlemóm'    => ['Betlém', 'Bethlem', [['Plur', 'P', 'Dat', '3']]],
                'bethlemoma'   => ['Betlém', 'Bethlem', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'bethlemóv'    => ['Betlém', 'Bethlem', [['Plur', 'P', 'Gen', '2']]],
                'bethlemové'   => ['Betlém', 'Bethlem', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'bethlemovi'   => ['Betlém', 'Bethlem', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'bethlemu'     => ['Betlém', 'Bethlem', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'bethlemú'     => ['Betlém', 'Bethlem', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'bethlemuom'   => ['Betlém', 'Bethlem', [['Plur', 'P', 'Dat', '3']]],
                'bethlemuov'   => ['Betlém', 'Bethlem', [['Plur', 'P', 'Gen', '2']]],
                'bethlemy'     => ['Betlém', 'Bethlem', [['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5'], ['Plur', 'P', 'Ins', '7']]],
                'betlém'       => ['Betlém', 'Bethlem', [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Acc', '4']]],
                'betléma'      => ['Betlém', 'Bethlem', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'betléme'      => ['Betlém', 'Bethlem', [['Sing', 'S', 'Voc', '5']]],
                'betlémě'      => ['Betlém', 'Bethlem', [['Sing', 'S', 'Loc', '6']]],
                'betlémem'     => ['Betlém', 'Bethlem', [['Sing', 'S', 'Ins', '7']]],
                'betlémi'      => ['Betlém', 'Bethlem', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'betlémie'     => ['Betlém', 'Bethlem', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'betlémiech'   => ['Betlém', 'Bethlem', [['Plur', 'P', 'Loc', '6']]],
                'betlémóm'     => ['Betlém', 'Bethlem', [['Plur', 'P', 'Dat', '3']]],
                'betlémoma'    => ['Betlém', 'Bethlem', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'betlémóv'     => ['Betlém', 'Bethlem', [['Plur', 'P', 'Gen', '2']]],
                'betlémové'    => ['Betlém', 'Bethlem', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'betlémovi'    => ['Betlém', 'Bethlem', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'betlému'      => ['Betlém', 'Bethlem', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'betlémú'      => ['Betlém', 'Bethlem', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'betlémuom'    => ['Betlém', 'Bethlem', [['Plur', 'P', 'Dat', '3']]],
                'betlémuov'    => ['Betlém', 'Bethlem', [['Plur', 'P', 'Gen', '2']]],
                'betlémy'      => ['Betlém', 'Bethlem', [['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5'], ['Plur', 'P', 'Ins', '7']]],
                'jeruzalém'     => ['Jeruzalém', 'Jeruzalém', [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Acc', '4']]],
                'jeruzaléma'    => ['Jeruzalém', 'Jeruzalém', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'jeruzaléme'    => ['Jeruzalém', 'Jeruzalém', [['Sing', 'S', 'Voc', '5']]],
                'jeruzalémě'    => ['Jeruzalém', 'Jeruzalém', [['Sing', 'S', 'Loc', '6']]],
                'jeruzalémem'   => ['Jeruzalém', 'Jeruzalém', [['Sing', 'S', 'Ins', '7']]],
                'jeruzalémi'    => ['Jeruzalém', 'Jeruzalém', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'jeruzalémie'   => ['Jeruzalém', 'Jeruzalém', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'jeruzalémiech' => ['Jeruzalém', 'Jeruzalém', [['Plur', 'P', 'Loc', '6']]],
                'jeruzalémóm'   => ['Jeruzalém', 'Jeruzalém', [['Plur', 'P', 'Dat', '3']]],
                'jeruzalémoma'  => ['Jeruzalém', 'Jeruzalém', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'jeruzalémóv'   => ['Jeruzalém', 'Jeruzalém', [['Plur', 'P', 'Gen', '2']]],
                'jeruzalémové'  => ['Jeruzalém', 'Jeruzalém', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'jeruzalémovi'  => ['Jeruzalém', 'Jeruzalém', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'jeruzalému'    => ['Jeruzalém', 'Jeruzalém', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'jeruzalémú'    => ['Jeruzalém', 'Jeruzalém', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'jeruzalémuom'  => ['Jeruzalém', 'Jeruzalém', [['Plur', 'P', 'Dat', '3']]],
                'jeruzalémuov'  => ['Jeruzalém', 'Jeruzalém', [['Plur', 'P', 'Gen', '2']]],
                'jeruzalémy'    => ['Jeruzalém', 'Jeruzalém', [['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5'], ['Plur', 'P', 'Ins', '7']]],
                'jordán'     => ['Jordán', 'Jordán', [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Acc', '4']]],
                'jordána'    => ['Jordán', 'Jordán', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'jordáne'    => ['Jordán', 'Jordán', [['Sing', 'S', 'Voc', '5']]],
                'jordáně'    => ['Jordán', 'Jordán', [['Sing', 'S', 'Loc', '6']]],
                'jordánem'   => ['Jordán', 'Jordán', [['Sing', 'S', 'Ins', '7']]],
                'jordáni'    => ['Jordán', 'Jordán', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'jordánie'   => ['Jordán', 'Jordán', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'jordániech' => ['Jordán', 'Jordán', [['Plur', 'P', 'Loc', '6']]],
                'jordánóm'   => ['Jordán', 'Jordán', [['Plur', 'P', 'Dat', '3']]],
                'jordánoma'  => ['Jordán', 'Jordán', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'jordánóv'   => ['Jordán', 'Jordán', [['Plur', 'P', 'Gen', '2']]],
                'jordánové'  => ['Jordán', 'Jordán', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'jordánovi'  => ['Jordán', 'Jordán', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'jordánu'    => ['Jordán', 'Jordán', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'jordánú'    => ['Jordán', 'Jordán', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'jordánuom'  => ['Jordán', 'Jordán', [['Plur', 'P', 'Dat', '3']]],
                'jordánuov'  => ['Jordán', 'Jordán', [['Plur', 'P', 'Gen', '2']]],
                'jordány'    => ['Jordán', 'Jordán', [['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5'], ['Plur', 'P', 'Ins', '7']]],
                'korozaim'    => ['Korozaim',    'Korozaim',    [['Sing', 'S', 'Voc', '5']]],
                'nazaret'      => ['Nazaret', 'Nazareth', [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Acc', '4']]],
                'nazareta'     => ['Nazaret', 'Nazareth', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'nazarete'     => ['Nazaret', 'Nazareth', [['Sing', 'S', 'Voc', '5']]],
                'nazaretě'     => ['Nazaret', 'Nazareth', [['Sing', 'S', 'Loc', '6']]],
                'nazaretem'    => ['Nazaret', 'Nazareth', [['Sing', 'S', 'Ins', '7']]],
                'nazareth'     => ['Nazaret', 'Nazareth', [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Acc', '4']]],
                'nazaretha'    => ['Nazaret', 'Nazareth', [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'nazarethem'   => ['Nazaret', 'Nazareth', [['Sing', 'S', 'Ins', '7']]],
                'nazarethóm'   => ['Nazaret', 'Nazareth', [['Plur', 'P', 'Dat', '3']]],
                'nazarethoma'  => ['Nazaret', 'Nazareth', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'nazarethóv'   => ['Nazaret', 'Nazareth', [['Plur', 'P', 'Gen', '2']]],
                'nazarethové'  => ['Nazaret', 'Nazareth', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'nazarethovi'  => ['Nazaret', 'Nazareth', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'nazarethu'    => ['Nazaret', 'Nazareth', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'nazarethú'    => ['Nazaret', 'Nazareth', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'nazarethuom'  => ['Nazaret', 'Nazareth', [['Plur', 'P', 'Dat', '3']]],
                'nazarethuov'  => ['Nazaret', 'Nazareth', [['Plur', 'P', 'Gen', '2']]],
                'nazarethy'    => ['Nazaret', 'Nazareth', [['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5'], ['Plur', 'P', 'Ins', '7']]],
                'nazareti'     => ['Nazaret', 'Nazareth', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'nazaretie'    => ['Nazaret', 'Nazareth', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'nazaretiech'  => ['Nazaret', 'Nazareth', [['Plur', 'P', 'Loc', '6']]],
                'nazaretóm'    => ['Nazaret', 'Nazareth', [['Plur', 'P', 'Dat', '3']]],
                'nazaretoma'   => ['Nazaret', 'Nazareth', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'nazaretóv'    => ['Nazaret', 'Nazareth', [['Plur', 'P', 'Gen', '2']]],
                'nazaretové'   => ['Nazaret', 'Nazareth', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'nazaretovi'   => ['Nazaret', 'Nazareth', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'nazaretu'     => ['Nazaret', 'Nazareth', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'nazaretú'     => ['Nazaret', 'Nazareth', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'nazaretuom'   => ['Nazaret', 'Nazareth', [['Plur', 'P', 'Dat', '3']]],
                'nazaretuov'   => ['Nazaret', 'Nazareth', [['Plur', 'P', 'Gen', '2']]],
                'nazarety'     => ['Nazaret', 'Nazareth', [['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5'], ['Plur', 'P', 'Ins', '7']]]
            );
            my $ma = $ma{$lform}; die("Something is wrong: '$lform'") if(!defined($ma));
            $f[2] = $ma->[0];
            $f[9] = set_lemma1300($f[9], $ma->[1]);
            $f[3] = 'PROPN';
            # U některých slov umožňujeme několik čtení, ale pokud to není žádné z nich, dáme první jako default.
            my @alt = @{$ma->[2]};
            for(my $i = $#alt; $i >= 0 ; $i--)
            {
                if($i == 0 || defined($alt[$i][4]) && get_ref($f[9]) =~ m/^$alt[$i][4]$/ || $f[5] =~ m/Case=$alt[$i][2].*Number=$alt[$i][0]/)
                {
                    $f[4] = 'NNI'.$alt[$i][1].$alt[$i][3].'-----A----';
                    $f[5] = 'Animacy=Inan|Case='.$alt[$i][2].'|Gender=Masc|NameType=Geo|Number='.$alt[$i][0].'|Polarity=Pos';
                    last;
                }
            }
        }
        #----------------------------------------------------------------------
        # Ženský rod.
        #----------------------------------------------------------------------
        # Slovo "duše" je někdy Voc od slova "duch"!
        # Slovo "hoře" je většinou střední rod ("hoře vám"). Jako Dat/Loc od slova
        # "hora" se to píše "huořě" a pouze jednou, v Olomoucké bibli 24.3, se objevuje
        # "hoře" ("na hoře Olivetské").
        # Slovo "vinny" se vyskytlo v Ol. 5.32 jako substantivum, nikoli adjektivum.
        elsif(!($f[1] =~ m/^hoře$/i && get_ref($f[9]) !~ m/^MATT_24\.3$/ || $f[1] =~ m/^(duše|hoř[ií]?|potopi|vinni)$/) &&
              $f[1] =~ m/^(buožnic|cěst|dci|dn|duš|hu?o[rř]|libř|lichv|mátě|m[aá]teř|matk|měřic|mís|modlitv|n[oó][hz]|potop|přísah|púš[čtť]|rez|ruc|siet|sól|stred|suol|světedlnic|škuol|trúb|ulic|u?ovc|vesnic|vier|vinn|vuod)(e|ě|i|í|y|u|ú|iem|iech|ách|ami)?$/i)
        {
            my $lform = lc($f[1]);
            my %ma =
            (
                'buožnic'     => ['božnice', 'buožnicě', [['Plur', 'P', 'Gen', '2']]],
                'buožnice'    => ['božnice', 'buožnicě', [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Voc', '5'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5']]],
                'buožnicě'    => ['božnice', 'buožnicě', [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Voc', '5'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5']]],
                'buožnicemi'  => ['božnice', 'buožnicě', [['Plur', 'P', 'Ins', '7']]],
                'buožnicěmi'  => ['božnice', 'buožnicě', [['Plur', 'P', 'Ins', '7']]],
                'buožnici'    => ['božnice', 'buožnicě', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Acc', '4'], ['Sing', 'S', 'Loc', '6']]],
                'buožnicí'    => ['božnice', 'buožnicě', [['Sing', 'S', 'Ins', '7'], ['Plur', 'P', 'Gen', '2']]],
                'buožnicie'   => ['božnice', 'buožnicě', [['Plur', 'P', 'Voc', '5']]],
                'buožniciech' => ['božnice', 'buožnicě', [['Plur', 'P', 'Loc', '6']]],
                'buožniciem'  => ['božnice', 'buožnicě', [['Plur', 'P', 'Dat', '3']]],
                'buožnicích'  => ['božnice', 'buožnicě', [['Plur', 'P', 'Loc', '6']]],
                'buožnicím'   => ['božnice', 'buožnicě', [['Plur', 'P', 'Dat', '3']]],
                'buožnicu'    => ['božnice', 'buožnicě', [['Sing', 'S', 'Acc', '4']]],
                'buožnicú'    => ['božnice', 'buožnicě', [['Sing', 'S', 'Ins', '7']]],
                'cěst'    => ['cesta', 'cesta', [['Plur', 'P', 'Gen', '2']]],
                'cěsta'   => ['cesta', 'cesta', [['Sing', 'S', 'Nom', '1']]],
                'cěstách' => ['cesta', 'cesta', [['Plur', 'P', 'Loc', '6']]],
                'cěstám'  => ['cesta', 'cesta', [['Plur', 'P', 'Dat', '3']]],
                'cěstami' => ['cesta', 'cesta', [['Plur', 'P', 'Ins', '7']]],
                'cěstě'   => ['cesta', 'cesta', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6'], ['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5']]],
                'cěsto'   => ['cesta', 'cesta', [['Sing', 'S', 'Voc', '5']]],
                'cěstou'  => ['cesta', 'cesta', [['Sing', 'S', 'Ins', '7']]],
                'cěstu'   => ['cesta', 'cesta', [['Sing', 'S', 'Acc', '4']]],
                'cěstú'   => ['cesta', 'cesta', [['Sing', 'S', 'Ins', '7']]],
                'cěsty'   => ['cesta', 'cesta', [['Sing', 'S', 'Gen', '2'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5']]],
                'dci'         => ['dcera',    'dci',      [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Voc', '5', 'MATT_9\\.22']]],
                'den'   => ['dna', 'dna', [['Plur', 'P', 'Gen', '2']]],
                'dna'   => ['dna', 'dna', [['Sing', 'S', 'Nom', '1']]],
                'dnách' => ['dna', 'dna', [['Plur', 'P', 'Loc', '6']]],
                'dnám'  => ['dna', 'dna', [['Plur', 'P', 'Dat', '3']]],
                'dnami' => ['dna', 'dna', [['Plur', 'P', 'Ins', '7']]],
                'dně'   => ['dna', 'dna', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6'], ['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5']]],
                'dno'   => ['dna', 'dna', [['Sing', 'S', 'Voc', '5']]],
                'dnou'  => ['dna', 'dna', [['Sing', 'S', 'Ins', '7']]],
                'dnu'   => ['dna', 'dna', [['Sing', 'S', 'Acc', '4']]],
                'dnú'   => ['dna', 'dna', [['Sing', 'S', 'Ins', '7']]],
                'dny'   => ['dna', 'dna', [['Sing', 'S', 'Gen', '2'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5']]],
                'duš'     => ['duše', 'dušě', [['Plur', 'P', 'Gen', '2']]],
                'duše'    => ['duše', 'dušě', [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Voc', '5'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5']]],
                'dušě'    => ['duše', 'dušě', [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Voc', '5'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5']]],
                'dušemi'  => ['duše', 'dušě', [['Plur', 'P', 'Ins', '7']]],
                'dušěmi'  => ['duše', 'dušě', [['Plur', 'P', 'Ins', '7']]],
                'duši'    => ['duše', 'dušě', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Acc', '4'], ['Sing', 'S', 'Loc', '6']]],
                'duší'    => ['duše', 'dušě', [['Sing', 'S', 'Ins', '7'], ['Plur', 'P', 'Gen', '2']]],
                'dušie'   => ['duše', 'dušě', [['Plur', 'P', 'Voc', '5']]],
                'dušiech' => ['duše', 'dušě', [['Plur', 'P', 'Loc', '6']]],
                'dušiem'  => ['duše', 'dušě', [['Plur', 'P', 'Dat', '3']]],
                'duších'  => ['duše', 'dušě', [['Plur', 'P', 'Loc', '6']]],
                'duším'   => ['duše', 'dušě', [['Plur', 'P', 'Dat', '3']]],
                'dušu'    => ['duše', 'dušě', [['Sing', 'S', 'Acc', '4']]],
                'dušú'    => ['duše', 'dušě', [['Sing', 'S', 'Ins', '7']]],
                'hor'     => ['hora', 'huora', [['Plur', 'P', 'Gen', '2']]],
                'hora'    => ['hora', 'huora', [['Sing', 'S', 'Nom', '1']]],
                'horách'  => ['hora', 'huora', [['Plur', 'P', 'Loc', '6']]],
                'horám'   => ['hora', 'huora', [['Plur', 'P', 'Dat', '3']]],
                'horami'  => ['hora', 'huora', [['Plur', 'P', 'Ins', '7']]],
                'horo'    => ['hora', 'huora', [['Sing', 'S', 'Voc', '5']]],
                'horou'   => ['hora', 'huora', [['Sing', 'S', 'Ins', '7']]],
                'horu'    => ['hora', 'huora', [['Sing', 'S', 'Acc', '4']]],
                'horú'    => ['hora', 'huora', [['Sing', 'S', 'Ins', '7']]],
                'hory'    => ['hora', 'huora', [['Sing', 'S', 'Gen', '2'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5']]],
                'hoře'    => ['hora', 'huora', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'hořě'    => ['hora', 'huora', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6'], ['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5']]],
                'huor'    => ['hora', 'huora', [['Plur', 'P', 'Gen', '2']]],
                'huora'   => ['hora', 'huora', [['Sing', 'S', 'Nom', '1']]],
                'huorách' => ['hora', 'huora', [['Plur', 'P', 'Loc', '6']]],
                'huorám'  => ['hora', 'huora', [['Plur', 'P', 'Dat', '3']]],
                'huorami' => ['hora', 'huora', [['Plur', 'P', 'Ins', '7']]],
                'huoro'   => ['hora', 'huora', [['Sing', 'S', 'Voc', '5']]],
                'huorou'  => ['hora', 'huora', [['Sing', 'S', 'Ins', '7']]],
                'huoru'   => ['hora', 'huora', [['Sing', 'S', 'Acc', '4']]],
                'huorú'   => ['hora', 'huora', [['Sing', 'S', 'Ins', '7']]],
                'huory'   => ['hora', 'huora', [['Sing', 'S', 'Gen', '2'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5']]],
                'huoře'   => ['hora', 'huora', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'huořě'   => ['hora', 'huora', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6'], ['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5']]],
                'liber'   => ['libra', 'libra', [['Plur', 'P', 'Gen', '2']]],
                'libra'   => ['libra', 'libra', [['Sing', 'S', 'Nom', '1']]],
                'librách' => ['libra', 'libra', [['Plur', 'P', 'Loc', '6']]],
                'librám'  => ['libra', 'libra', [['Plur', 'P', 'Dat', '3']]],
                'librami' => ['libra', 'libra', [['Plur', 'P', 'Ins', '7']]],
                'libro'   => ['libra', 'libra', [['Sing', 'S', 'Voc', '5']]],
                'librou'  => ['libra', 'libra', [['Sing', 'S', 'Ins', '7']]],
                'libru'   => ['libra', 'libra', [['Sing', 'S', 'Acc', '4']]],
                'librú'   => ['libra', 'libra', [['Sing', 'S', 'Ins', '7']]],
                'libry'   => ['libra', 'libra', [['Sing', 'S', 'Gen', '2'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5']]],
                'libře'   => ['libra', 'libra', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'libřě'   => ['libra', 'libra', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6'], ['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5']]],
                'lichev'   => ['lichva', 'lichva', [['Plur', 'P', 'Gen', '2']]],
                'lichva'   => ['lichva', 'lichva', [['Sing', 'S', 'Nom', '1']]],
                'lichvách' => ['lichva', 'lichva', [['Plur', 'P', 'Loc', '6']]],
                'lichvám'  => ['lichva', 'lichva', [['Plur', 'P', 'Dat', '3']]],
                'lichvami' => ['lichva', 'lichva', [['Plur', 'P', 'Ins', '7']]],
                'lichve'   => ['lichva', 'lichva', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'lichvě'   => ['lichva', 'lichva', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6'], ['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5']]],
                'lichvo'   => ['lichva', 'lichva', [['Sing', 'S', 'Voc', '5']]],
                'lichvou'  => ['lichva', 'lichva', [['Sing', 'S', 'Ins', '7']]],
                'lichvu'   => ['lichva', 'lichva', [['Sing', 'S', 'Acc', '4']]],
                'lichvú'   => ['lichva', 'lichva', [['Sing', 'S', 'Ins', '7']]],
                'lichvy'   => ['lichva', 'lichva', [['Sing', 'S', 'Gen', '2'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5']]],
                'mátě'   => ['máti', 'máti', [['Sing', 'S', 'Nom', '1']]],
                'mateř'  => ['máti', 'máti', [['Sing', 'S', 'Acc', '4']]],
                'máteř'  => ['máti', 'máti', [['Sing', 'S', 'Acc', '4']]],
                'mateře' => ['máti', 'máti', [['Sing', 'S', 'Gen', '2']]],
                'mateřě' => ['máti', 'máti', [['Sing', 'S', 'Gen', '2']]],
                'mateři' => ['máti', 'máti', [['Sing', 'S', 'Dat', '3']]],
                'mateří' => ['máti', 'máti', [['Sing', 'S', 'Ins', '7']]],
                'mateřú' => ['máti', 'máti', [['Sing', 'S', 'Ins', '7']]],
                'matce'   => ['matka', 'matka', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'matcě'   => ['matka', 'matka', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6'], ['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5']]],
                'matek'   => ['matka', 'matka', [['Plur', 'P', 'Gen', '2']]],
                'matka'   => ['matka', 'matka', [['Sing', 'S', 'Nom', '1']]],
                'matkách' => ['matka', 'matka', [['Plur', 'P', 'Loc', '6']]],
                'matkám'  => ['matka', 'matka', [['Plur', 'P', 'Dat', '3']]],
                'matkami' => ['matka', 'matka', [['Plur', 'P', 'Ins', '7']]],
                'matko'   => ['matka', 'matka', [['Sing', 'S', 'Voc', '5']]],
                'matkou'  => ['matka', 'matka', [['Sing', 'S', 'Ins', '7']]],
                'matku'   => ['matka', 'matka', [['Sing', 'S', 'Acc', '4']]],
                'matkú'   => ['matka', 'matka', [['Sing', 'S', 'Ins', '7']]],
                'matky'   => ['matka', 'matka', [['Sing', 'S', 'Gen', '2'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5']]],
                'měřic'     => ['měřice', 'měřicě', [['Plur', 'P', 'Gen', '2']]],
                'měřice'    => ['měřice', 'měřicě', [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Voc', '5'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5']]],
                'měřicě'    => ['měřice', 'měřicě', [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Voc', '5'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5']]],
                'měřicemi'  => ['měřice', 'měřicě', [['Plur', 'P', 'Ins', '7']]],
                'měřicěmi'  => ['měřice', 'měřicě', [['Plur', 'P', 'Ins', '7']]],
                'měřici'    => ['měřice', 'měřicě', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Acc', '4'], ['Sing', 'S', 'Loc', '6']]],
                'měřicí'    => ['měřice', 'měřicě', [['Sing', 'S', 'Ins', '7']]],
                'měřiciech' => ['měřice', 'měřicě', [['Plur', 'P', 'Loc', '6']]],
                'měřiciem'  => ['měřice', 'měřicě', [['Plur', 'P', 'Dat', '3']]],
                'měřicích'  => ['měřice', 'měřicě', [['Plur', 'P', 'Loc', '6']]],
                'měřicím'   => ['měřice', 'měřicě', [['Plur', 'P', 'Dat', '3']]],
                'měřicu'    => ['měřice', 'měřicě', [['Sing', 'S', 'Acc', '4']]],
                'mís'    => ['mísa', 'mísa', [['Plur', 'P', 'Gen', '2']]],
                'mísa'   => ['mísa', 'mísa', [['Sing', 'S', 'Nom', '1']]],
                'mísách' => ['mísa', 'mísa', [['Plur', 'P', 'Loc', '6']]],
                'mísám'  => ['mísa', 'mísa', [['Plur', 'P', 'Dat', '3']]],
                'mísami' => ['mísa', 'mísa', [['Plur', 'P', 'Ins', '7']]],
                'míse'   => ['mísa', 'mísa', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'mísě'   => ['mísa', 'mísa', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6'], ['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5']]],
                'míso'   => ['mísa', 'mísa', [['Sing', 'S', 'Voc', '5']]],
                'mísou'  => ['mísa', 'mísa', [['Sing', 'S', 'Ins', '7']]],
                'mísu'   => ['mísa', 'mísa', [['Sing', 'S', 'Acc', '4']]],
                'mísú'   => ['mísa', 'mísa', [['Sing', 'S', 'Ins', '7']]],
                'mísy'   => ['mísa', 'mísa', [['Sing', 'S', 'Gen', '2'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5']]],
                'modlitv'    => ['modlitba', 'modlitva', [['Plur', 'P', 'Gen', '2']]],
                'modlitev'   => ['modlitba', 'modlitva', [['Plur', 'P', 'Gen', '2']]],
                'modlitva'   => ['modlitba', 'modlitva', [['Sing', 'S', 'Nom', '1']]],
                'modlitvách' => ['modlitba', 'modlitva', [['Plur', 'P', 'Loc', '6']]],
                'modlitvám'  => ['modlitba', 'modlitva', [['Plur', 'P', 'Dat', '3']]],
                'modlitvami' => ['modlitba', 'modlitva', [['Plur', 'P', 'Ins', '7']]],
                'modlitve'   => ['modlitba', 'modlitva', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'modlitvě'   => ['modlitba', 'modlitva', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6'], ['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5']]],
                'modlitvo'   => ['modlitba', 'modlitva', [['Sing', 'S', 'Voc', '5']]],
                'modlitvou'  => ['modlitba', 'modlitva', [['Sing', 'S', 'Ins', '7']]],
                'modlitvu'   => ['modlitba', 'modlitva', [['Sing', 'S', 'Acc', '4']]],
                'modlitvú'   => ['modlitba', 'modlitva', [['Sing', 'S', 'Ins', '7']]],
                'modlitvy'   => ['modlitba', 'modlitva', [['Sing', 'S', 'Gen', '2'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5']]],
                'noh'    => ['noha', 'noha', [['Plur', 'P', 'Gen', '2']]],
                'nóh'    => ['noha', 'noha', [['Plur', 'P', 'Gen', '2']]],
                'noha'   => ['noha', 'noha', [['Sing', 'S', 'Nom', '1']]],
                'nohách' => ['noha', 'noha', [['Plur', 'P', 'Loc', '6']]],
                'nohám'  => ['noha', 'noha', [['Plur', 'P', 'Dat', '3']]],
                'nohami' => ['noha', 'noha', [['Plur', 'P', 'Ins', '7']]],
                'noho'   => ['noha', 'noha', [['Sing', 'S', 'Voc', '5']]],
                'nohou'  => ['noha', 'noha', [['Sing', 'S', 'Ins', '7']]],
                'nohu'   => ['noha', 'noha', [['Sing', 'S', 'Acc', '4']]],
                'nohú'   => ['noha', 'noha', [['Sing', 'S', 'Ins', '7']]],
                'nohy'   => ['noha', 'noha', [['Sing', 'S', 'Gen', '2'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5']]],
                'noze'   => ['noha', 'noha', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'nozě'   => ['noha', 'noha', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6'], ['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5']]],
                'ovce'     => ['ovce', 'ovcě', [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Voc', '5'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5']]],
                'ovcě'     => ['ovce', 'ovcě', [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Voc', '5'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5']]],
                'ovcemi'   => ['ovce', 'ovcě', [['Plur', 'P', 'Ins', '7']]],
                'ovcěmi'   => ['ovce', 'ovcě', [['Plur', 'P', 'Ins', '7']]],
                'ovci'     => ['ovce', 'ovcě', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Acc', '4'], ['Sing', 'S', 'Loc', '6']]],
                'ovcí'     => ['ovce', 'ovcě', [['Sing', 'S', 'Ins', '7']]],
                'ovciech'  => ['ovce', 'ovcě', [['Plur', 'P', 'Loc', '6']]],
                'ovciem'   => ['ovce', 'ovcě', [['Plur', 'P', 'Dat', '3']]],
                'ovcích'   => ['ovce', 'ovcě', [['Plur', 'P', 'Loc', '6']]],
                'ovcím'    => ['ovce', 'ovcě', [['Plur', 'P', 'Dat', '3']]],
                'ovcu'     => ['ovce', 'ovcě', [['Sing', 'S', 'Acc', '4']]],
                'uovce'    => ['ovce', 'ovcě', [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Voc', '5'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5']]],
                'uovcě'    => ['ovce', 'ovcě', [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Voc', '5'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5']]],
                'uovcemi'  => ['ovce', 'ovcě', [['Plur', 'P', 'Ins', '7']]],
                'uovcěmi'  => ['ovce', 'ovcě', [['Plur', 'P', 'Ins', '7']]],
                'uovci'    => ['ovce', 'ovcě', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Acc', '4'], ['Sing', 'S', 'Loc', '6']]],
                'uovcí'    => ['ovce', 'ovcě', [['Sing', 'S', 'Ins', '7']]],
                'uovciech' => ['ovce', 'ovcě', [['Plur', 'P', 'Loc', '6']]],
                'uovciem'  => ['ovce', 'ovcě', [['Plur', 'P', 'Dat', '3']]],
                'uovcích'  => ['ovce', 'ovcě', [['Plur', 'P', 'Loc', '6']]],
                'uovcím'   => ['ovce', 'ovcě', [['Plur', 'P', 'Dat', '3']]],
                'uovcu'    => ['ovce', 'ovcě', [['Sing', 'S', 'Acc', '4']]],
                'potop'    => ['potopa', 'potopa', [['Plur', 'P', 'Gen', '2']]],
                'potopa'   => ['potopa', 'potopa', [['Sing', 'S', 'Nom', '1']]],
                'potopách' => ['potopa', 'potopa', [['Plur', 'P', 'Loc', '6']]],
                'potopám'  => ['potopa', 'potopa', [['Plur', 'P', 'Dat', '3']]],
                'potopami' => ['potopa', 'potopa', [['Plur', 'P', 'Ins', '7']]],
                'potope'   => ['potopa', 'potopa', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'potopě'   => ['potopa', 'potopa', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6'], ['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5']]],
                'potopo'   => ['potopa', 'potopa', [['Sing', 'S', 'Voc', '5']]],
                'potopou'  => ['potopa', 'potopa', [['Sing', 'S', 'Ins', '7']]],
                'potopu'   => ['potopa', 'potopa', [['Sing', 'S', 'Acc', '4']]],
                'potopú'   => ['potopa', 'potopa', [['Sing', 'S', 'Ins', '7']]],
                'potopy'   => ['potopa', 'potopa', [['Sing', 'S', 'Gen', '2'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5']]],
                'přísah'    => ['přísaha', 'přísaha', [['Plur', 'P', 'Gen', '2']]],
                'přísaha'   => ['přísaha', 'přísaha', [['Sing', 'S', 'Nom', '1']]],
                'přísahách' => ['přísaha', 'přísaha', [['Plur', 'P', 'Loc', '6']]],
                'přísahám'  => ['přísaha', 'přísaha', [['Plur', 'P', 'Dat', '3']]],
                'přísahami' => ['přísaha', 'přísaha', [['Plur', 'P', 'Ins', '7']]],
                'přísaho'   => ['přísaha', 'přísaha', [['Sing', 'S', 'Voc', '5']]],
                'přísahou'  => ['přísaha', 'přísaha', [['Sing', 'S', 'Ins', '7']]],
                'přísahu'   => ['přísaha', 'přísaha', [['Sing', 'S', 'Acc', '4']]],
                'přísahú'   => ['přísaha', 'přísaha', [['Sing', 'S', 'Ins', '7']]],
                'přísahy'   => ['přísaha', 'přísaha', [['Sing', 'S', 'Gen', '2'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5']]],
                'přísaze'   => ['přísaha', 'přísaha', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'přísazě'   => ['přísaha', 'přísaha', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6'], ['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5']]],
                'púšč'     => ['poušť', 'púščě', [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Acc', '4']]],
                'púšče'    => ['poušť', 'púščě', [['Sing', 'S', 'Gen', '2']]],
                'púščě'    => ['poušť', 'púščě', [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Voc', '5'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5']]],
                'púščěmi'  => ['poušť', 'púščě', [['Plur', 'P', 'Ins', '7']]],
                'púšči'    => ['poušť', 'púščě', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Acc', '4'], ['Sing', 'S', 'Loc', '6']]],
                'púščí'    => ['poušť', 'púščě', [['Sing', 'S', 'Ins', '7'], ['Plur', 'P', 'Gen', '2']]],
                'púščiech' => ['poušť', 'púščě', [['Plur', 'P', 'Loc', '6']]],
                'púščiem'  => ['poušť', 'púščě', [['Plur', 'P', 'Dat', '3']]],
                'púšču'    => ['poušť', 'púščě', [['Sing', 'S', 'Acc', '4']]],
                'púšť'     => ['poušť', 'púščě', [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Acc', '4']]],
                'púště'    => ['poušť', 'púščě', [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Voc', '5'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5']]],
                'púštěmi'  => ['poušť', 'púščě', [['Plur', 'P', 'Ins', '7']]],
                'púšti'    => ['poušť', 'púščě', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Acc', '4'], ['Sing', 'S', 'Loc', '6']]],
                'púští'    => ['poušť', 'púščě', [['Sing', 'S', 'Ins', '7'], ['Plur', 'P', 'Gen', '2']]],
                'púštiech' => ['poušť', 'púščě', [['Plur', 'P', 'Loc', '6']]],
                'púštiem'  => ['poušť', 'púščě', [['Plur', 'P', 'Dat', '3']]],
                'púšťu'    => ['poušť', 'púščě', [['Sing', 'S', 'Acc', '4']]],
                'rez'         => ['rez',      'rez',      [['Sing', 'S', 'Nom', '1']]],
                'ruce'   => ['ruka', 'ruka', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'rucě'   => ['ruka', 'ruka', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6'], ['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5']]],
                'ruci'   => ['ruka', 'ruka', [['Sing', 'S', 'Gen', '2'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5']]],
                'ruk'    => ['ruka', 'ruka', [['Plur', 'P', 'Gen', '2']]],
                'ruka'   => ['ruka', 'ruka', [['Sing', 'S', 'Nom', '1']]],
                'rukách' => ['ruka', 'ruka', [['Plur', 'P', 'Loc', '6']]],
                'rukám'  => ['ruka', 'ruka', [['Plur', 'P', 'Dat', '3']]],
                'rukami' => ['ruka', 'ruka', [['Plur', 'P', 'Ins', '7']]],
                'ruko'   => ['ruka', 'ruka', [['Sing', 'S', 'Voc', '5']]],
                'rukou'  => ['ruka', 'ruka', [['Sing', 'S', 'Ins', '7']]],
                'ruku'   => ['ruka', 'ruka', [['Sing', 'S', 'Acc', '4']]],
                'rukú'   => ['ruka', 'ruka', [['Sing', 'S', 'Ins', '7']]],
                'ruky'   => ['ruka', 'ruka', [['Sing', 'S', 'Gen', '2'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5']]],
                'siet'     => ['síť', 'sieť', [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Acc', '4']]],
                'sieť'     => ['síť', 'sieť', [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Acc', '4']]],
                'sietě'    => ['síť', 'sieť', [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Voc', '5'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5']]],
                'sietěmi'  => ['síť', 'sieť', [['Plur', 'P', 'Ins', '7']]],
                'sieti'    => ['síť', 'sieť', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Acc', '4'], ['Sing', 'S', 'Loc', '6']]],
                'sietí'    => ['síť', 'sieť', [['Sing', 'S', 'Ins', '7'], ['Plur', 'P', 'Gen', '2']]],
                'sietiech' => ['síť', 'sieť', [['Plur', 'P', 'Loc', '6']]],
                'sietiem'  => ['síť', 'sieť', [['Plur', 'P', 'Dat', '3']]],
                'sieťu'    => ['síť', 'sieť', [['Sing', 'S', 'Acc', '4']]],
                'sol'      => ['sůl', 'sól', [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Acc', '4']]],
                'sól'      => ['sůl', 'sól', [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Acc', '4']]],
                'solě'     => ['sůl', 'sól', [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Voc', '5'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5']]],
                'sólě'     => ['sůl', 'sól', [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Voc', '5'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5']]],
                'solěmi'   => ['sůl', 'sól', [['Plur', 'P', 'Ins', '7']]],
                'sólěmi'   => ['sůl', 'sól', [['Plur', 'P', 'Ins', '7']]],
                'soli'     => ['sůl', 'sól', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Acc', '4'], ['Sing', 'S', 'Loc', '6']]],
                'solí'     => ['sůl', 'sól', [['Sing', 'S', 'Ins', '7'], ['Plur', 'P', 'Gen', '2']]],
                'sóli'     => ['sůl', 'sól', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Acc', '4'], ['Sing', 'S', 'Loc', '6']]],
                'sólí'     => ['sůl', 'sól', [['Sing', 'S', 'Ins', '7'], ['Plur', 'P', 'Gen', '2']]],
                'soliech'  => ['sůl', 'sól', [['Plur', 'P', 'Loc', '6']]],
                'sóliech'  => ['sůl', 'sól', [['Plur', 'P', 'Loc', '6']]],
                'soliem'   => ['sůl', 'sól', [['Plur', 'P', 'Dat', '3']]],
                'sóliem'   => ['sůl', 'sól', [['Plur', 'P', 'Dat', '3']]],
                'solu'     => ['sůl', 'sól', [['Sing', 'S', 'Acc', '4']]],
                'sólu'     => ['sůl', 'sól', [['Sing', 'S', 'Acc', '4']]],
                'suol'     => ['sůl', 'sól', [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Acc', '4']]],
                'suolě'    => ['sůl', 'sól', [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Voc', '5'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5']]],
                'suolěmi'  => ['sůl', 'sól', [['Plur', 'P', 'Ins', '7']]],
                'suoli'    => ['sůl', 'sól', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Acc', '4'], ['Sing', 'S', 'Loc', '6']]],
                'suolí'    => ['sůl', 'sól', [['Sing', 'S', 'Ins', '7'], ['Plur', 'P', 'Gen', '2']]],
                'suoliech' => ['sůl', 'sól', [['Plur', 'P', 'Loc', '6']]],
                'suoliem'  => ['sůl', 'sól', [['Plur', 'P', 'Dat', '3']]],
                'suolu'    => ['sůl', 'sól', [['Sing', 'S', 'Acc', '4']]],
                'stred'     => ['stred', 'stred', [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Acc', '4']]],
                'stredě'    => ['stred', 'stred', [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Voc', '5'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5']]],
                'streděmi'  => ['stred', 'stred', [['Plur', 'P', 'Ins', '7']]],
                'stredi'    => ['stred', 'stred', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Acc', '4'], ['Sing', 'S', 'Loc', '6']]],
                'stredí'    => ['stred', 'stred', [['Sing', 'S', 'Ins', '7'], ['Plur', 'P', 'Gen', '2']]],
                'strediech' => ['stred', 'stred', [['Plur', 'P', 'Loc', '6']]],
                'strediem'  => ['stred', 'stred', [['Plur', 'P', 'Dat', '3']]],
                'stredu'    => ['stred', 'stred', [['Sing', 'S', 'Acc', '4']]],
                'světedlnic'     => ['světelnice', 'světedlnicě', [['Plur', 'P', 'Gen', '2']]],
                'světedlnice'    => ['světelnice', 'světedlnicě', [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Voc', '5'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5']]],
                'světedlnicě'    => ['světelnice', 'světedlnicě', [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Voc', '5'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5']]],
                'světedlnicemi'  => ['světelnice', 'světedlnicě', [['Plur', 'P', 'Ins', '7']]],
                'světedlnicěmi'  => ['světelnice', 'světedlnicě', [['Plur', 'P', 'Ins', '7']]],
                'světedlnici'    => ['světelnice', 'světedlnicě', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Acc', '4'], ['Sing', 'S', 'Loc', '6']]],
                'světedlnicí'    => ['světelnice', 'světedlnicě', [['Sing', 'S', 'Ins', '7']]],
                'světedlnicie'   => ['světelnice', 'světedlnicě', [['Plur', 'P', 'Voc', '5']]],
                'světedlniciech' => ['světelnice', 'světedlnicě', [['Plur', 'P', 'Loc', '6']]],
                'světedlniciem'  => ['světelnice', 'světedlnicě', [['Plur', 'P', 'Dat', '3']]],
                'světedlnicích'  => ['světelnice', 'světedlnicě', [['Plur', 'P', 'Loc', '6']]],
                'světedlnicím'   => ['světelnice', 'světedlnicě', [['Plur', 'P', 'Dat', '3']]],
                'světedlnicu'    => ['světelnice', 'světedlnicě', [['Sing', 'S', 'Acc', '4']]],
                'škuol'    => ['škola', 'škuola', [['Plur', 'P', 'Gen', '2']]],
                'škuola'   => ['škola', 'škuola', [['Sing', 'S', 'Nom', '1']]],
                'škuolách' => ['škola', 'škuola', [['Plur', 'P', 'Loc', '6']]],
                'škuolám'  => ['škola', 'škuola', [['Plur', 'P', 'Dat', '3']]],
                'škuolami' => ['škola', 'škuola', [['Plur', 'P', 'Ins', '7']]],
                'škuole'   => ['škola', 'škuola', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'škuolě'   => ['škola', 'škuola', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6'], ['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5']]],
                'škuolo'   => ['škola', 'škuola', [['Sing', 'S', 'Voc', '5']]],
                'škuolou'  => ['škola', 'škuola', [['Sing', 'S', 'Ins', '7']]],
                'škuolu'   => ['škola', 'škuola', [['Sing', 'S', 'Acc', '4']]],
                'škuolú'   => ['škola', 'škuola', [['Sing', 'S', 'Ins', '7']]],
                'škuoly'   => ['škola', 'škuola', [['Sing', 'S', 'Gen', '2'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5']]],
                'trúb'    => ['trouba', 'trúba', [['Plur', 'P', 'Gen', '2']]],
                'trúba'   => ['trouba', 'trúba', [['Sing', 'S', 'Nom', '1']]],
                'trúbách' => ['trouba', 'trúba', [['Plur', 'P', 'Loc', '6']]],
                'trúbám'  => ['trouba', 'trúba', [['Plur', 'P', 'Dat', '3']]],
                'trúbami' => ['trouba', 'trúba', [['Plur', 'P', 'Ins', '7']]],
                'trúbe'   => ['trouba', 'trúba', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'trúbě'   => ['trouba', 'trúba', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6'], ['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5']]],
                'trúbo'   => ['trouba', 'trúba', [['Sing', 'S', 'Voc', '5']]],
                'trúbou'  => ['trouba', 'trúba', [['Sing', 'S', 'Ins', '7']]],
                'trúbu'   => ['trouba', 'trúba', [['Sing', 'S', 'Acc', '4']]],
                'trúbú'   => ['trouba', 'trúba', [['Sing', 'S', 'Ins', '7']]],
                'trúby'   => ['trouba', 'trúba', [['Sing', 'S', 'Gen', '2'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5']]],
                'ulic'     => ['ulice', 'ulicě', [['Plur', 'P', 'Gen', '2']]],
                'ulice'    => ['ulice', 'ulicě', [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Voc', '5'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5']]],
                'ulicě'    => ['ulice', 'ulicě', [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Voc', '5'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5']]],
                'ulicemi'  => ['ulice', 'ulicě', [['Plur', 'P', 'Ins', '7']]],
                'ulicěmi'  => ['ulice', 'ulicě', [['Plur', 'P', 'Ins', '7']]],
                'ulici'    => ['ulice', 'ulicě', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Acc', '4'], ['Sing', 'S', 'Loc', '6']]],
                'ulicí'    => ['ulice', 'ulicě', [['Sing', 'S', 'Ins', '7']]],
                'ulicie'   => ['ulice', 'ulicě', [['Plur', 'P', 'Voc', '5']]],
                'uliciech' => ['ulice', 'ulicě', [['Plur', 'P', 'Loc', '6']]],
                'uliciem'  => ['ulice', 'ulicě', [['Plur', 'P', 'Dat', '3']]],
                'ulicích'  => ['ulice', 'ulicě', [['Plur', 'P', 'Loc', '6']]],
                'ulicím'   => ['ulice', 'ulicě', [['Plur', 'P', 'Dat', '3']]],
                'ulicu'    => ['ulice', 'ulicě', [['Sing', 'S', 'Acc', '4']]],
                'vesnic'     => ['vesnice', 'vesnicě', [['Plur', 'P', 'Gen', '2']]],
                'vesnice'    => ['vesnice', 'vesnicě', [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Voc', '5'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5']]],
                'vesnicě'    => ['vesnice', 'vesnicě', [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Voc', '5'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5']]],
                'vesnicemi'  => ['vesnice', 'vesnicě', [['Plur', 'P', 'Ins', '7']]],
                'vesnicěmi'  => ['vesnice', 'vesnicě', [['Plur', 'P', 'Ins', '7']]],
                'vesnici'    => ['vesnice', 'vesnicě', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Acc', '4'], ['Sing', 'S', 'Loc', '6']]],
                'vesnicí'    => ['vesnice', 'vesnicě', [['Sing', 'S', 'Ins', '7']]],
                'vesnicie'   => ['vesnice', 'vesnicě', [['Plur', 'P', 'Voc', '5']]],
                'vesniciech' => ['vesnice', 'vesnicě', [['Plur', 'P', 'Loc', '6']]],
                'vesniciem'  => ['vesnice', 'vesnicě', [['Plur', 'P', 'Dat', '3']]],
                'vesnicích'  => ['vesnice', 'vesnicě', [['Plur', 'P', 'Loc', '6']]],
                'vesnicím'   => ['vesnice', 'vesnicě', [['Plur', 'P', 'Dat', '3']]],
                'vesnicu'    => ['vesnice', 'vesnicě', [['Sing', 'S', 'Acc', '4']]],
                'vier'    => ['víra', 'viera', [['Plur', 'P', 'Gen', '2']]],
                'viera'   => ['víra', 'viera', [['Sing', 'S', 'Nom', '1']]],
                'vierách' => ['víra', 'viera', [['Plur', 'P', 'Loc', '6']]],
                'vierám'  => ['víra', 'viera', [['Plur', 'P', 'Dat', '3']]],
                'vierami' => ['víra', 'viera', [['Plur', 'P', 'Ins', '7']]],
                'viero'   => ['víra', 'viera', [['Sing', 'S', 'Voc', '5']]],
                'vierou'  => ['víra', 'viera', [['Sing', 'S', 'Ins', '7']]],
                'vieru'   => ['víra', 'viera', [['Sing', 'S', 'Acc', '4']]],
                'vierú'   => ['víra', 'viera', [['Sing', 'S', 'Ins', '7']]],
                'viery'   => ['víra', 'viera', [['Sing', 'S', 'Gen', '2'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5']]],
                'vieře'   => ['víra', 'viera', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'vieřě'   => ['víra', 'viera', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6'], ['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5']]],
                'vinn'    => ['vina', 'vinna', [['Plur', 'P', 'Gen', '2']]],
                'vinna'   => ['vina', 'vinna', [['Sing', 'S', 'Nom', '1']]],
                'vinnách' => ['vina', 'vinna', [['Plur', 'P', 'Loc', '6']]],
                'vinnám'  => ['vina', 'vinna', [['Plur', 'P', 'Dat', '3']]],
                'vinnami' => ['vina', 'vinna', [['Plur', 'P', 'Ins', '7']]],
                'vinně'   => ['vina', 'vinna', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6'], ['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5']]],
                'vinno'   => ['vina', 'vinna', [['Sing', 'S', 'Voc', '5']]],
                'vinnou'  => ['vina', 'vinna', [['Sing', 'S', 'Ins', '7']]],
                'vinnu'   => ['vina', 'vinna', [['Sing', 'S', 'Acc', '4']]],
                'vinnú'   => ['vina', 'vinna', [['Sing', 'S', 'Ins', '7']]],
                'vinny'   => ['vina', 'vinna', [['Sing', 'S', 'Gen', '2'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5']]],
                'vuod'    => ['voda', 'vuoda', [['Plur', 'P', 'Gen', '2']]],
                'vuoda'   => ['voda', 'vuoda', [['Sing', 'S', 'Nom', '1']]],
                'vuodách' => ['voda', 'vuoda', [['Plur', 'P', 'Loc', '6']]],
                'vuodám'  => ['voda', 'vuoda', [['Plur', 'P', 'Dat', '3']]],
                'vuodami' => ['voda', 'vuoda', [['Plur', 'P', 'Ins', '7']]],
                'vuodě'   => ['voda', 'vuoda', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6'], ['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5']]],
                'vuodo'   => ['voda', 'vuoda', [['Sing', 'S', 'Voc', '5']]],
                'vuodou'  => ['voda', 'vuoda', [['Sing', 'S', 'Ins', '7']]],
                'vuodu'   => ['voda', 'vuoda', [['Sing', 'S', 'Acc', '4']]],
                'vuodú'   => ['voda', 'vuoda', [['Sing', 'S', 'Ins', '7']]],
                'vuody'   => ['voda', 'vuoda', [['Sing', 'S', 'Gen', '2'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5']]]
            );
            my $ma = $ma{$lform}; die("Something is wrong: '$lform'") if(!defined($ma));
            $f[2] = $ma->[0];
            $f[9] = set_lemma1300($f[9], $ma->[1]);
            $f[3] = 'NOUN';
            # U některých slov umožňujeme několik čtení, ale pokud to není žádné z nich, dáme první jako default.
            my @alt = @{$ma->[2]};
            for(my $i = $#alt; $i >= 0 ; $i--)
            {
                if($i == 0 || defined($alt[$i][4]) && get_ref($f[9]) =~ m/^$alt[$i][4]$/ || $f[5] =~ m/Case=$alt[$i][2].*Number=$alt[$i][0]/)
                {
                    $f[4] = 'NNF'.$alt[$i][1].$alt[$i][3].'-----A----';
                    $f[5] = 'Case='.$alt[$i][2].'|Gender=Fem|Number='.$alt[$i][0].'|Polarity=Pos';
                    last;
                }
            }
        }
        elsif($f[1] =~ m/^(Mari|M[aá]ři?|Rachel)(a|e|í|jí)?$/i)
        {
            my $lform = lc($f[1]);
            my %ma =
            (
                'mari'     => ['Marie', 'Maria', [['Plur', 'P', 'Gen', '2']]],
                'maria'    => ['Marie', 'Maria', [['Sing', 'S', 'Nom', '1']]],
                'marie'    => ['Marie', 'Maria', [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Voc', '5'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5']]],
                'mariě'    => ['Marie', 'Maria', [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Voc', '5'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5']]],
                'mariemi'  => ['Marie', 'Maria', [['Plur', 'P', 'Ins', '7']]],
                'mariěmi'  => ['Marie', 'Maria', [['Plur', 'P', 'Ins', '7']]],
                'marii'    => ['Marie', 'Maria', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Acc', '4'], ['Sing', 'S', 'Loc', '6']]],
                'marií'    => ['Marie', 'Maria', [['Sing', 'S', 'Ins', '7']]],
                'mariie'   => ['Marie', 'Maria', [['Plur', 'P', 'Voc', '5']]],
                'mariiech' => ['Marie', 'Maria', [['Plur', 'P', 'Loc', '6']]],
                'mariiem'  => ['Marie', 'Maria', [['Plur', 'P', 'Dat', '3']]],
                'mariích'  => ['Marie', 'Maria', [['Plur', 'P', 'Loc', '6']]],
                'mariím'   => ['Marie', 'Maria', [['Plur', 'P', 'Dat', '3']]],
                'marijí'   => ['Marie', 'Maria', [['Sing', 'S', 'Ins', '7']]],
                'mariu'    => ['Marie', 'Maria', [['Sing', 'S', 'Acc', '4']]],
                'maři'     => ['Marie', 'Maria', [['Plur', 'P', 'Gen', '2']]],
                'maří'     => ['Marie', 'Maria', [['Sing', 'S', 'Ins', '7']]],
                'máři'     => ['Marie', 'Maria', [['Plur', 'P', 'Gen', '2']]],
                'máří'     => ['Marie', 'Maria', [['Sing', 'S', 'Nom', '1']]],
                'mařie'    => ['Marie', 'Maria', [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Voc', '5'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5']]],
                'mařiě'    => ['Marie', 'Maria', [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Voc', '5'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5']]],
                'mářie'    => ['Marie', 'Maria', [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Voc', '5'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5']]],
                'mářiě'    => ['Marie', 'Maria', [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Voc', '5'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5']]],
                'mařiemi'  => ['Marie', 'Maria', [['Plur', 'P', 'Ins', '7']]],
                'mařiěmi'  => ['Marie', 'Maria', [['Plur', 'P', 'Ins', '7']]],
                'mářiemi'  => ['Marie', 'Maria', [['Plur', 'P', 'Ins', '7']]],
                'mářiěmi'  => ['Marie', 'Maria', [['Plur', 'P', 'Ins', '7']]],
                'mařii'    => ['Marie', 'Maria', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Acc', '4'], ['Sing', 'S', 'Loc', '6']]],
                'mařií'    => ['Marie', 'Maria', [['Sing', 'S', 'Ins', '7']]],
                'mářii'    => ['Marie', 'Maria', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Acc', '4'], ['Sing', 'S', 'Loc', '6']]],
                'mářií'    => ['Marie', 'Maria', [['Sing', 'S', 'Ins', '7']]],
                'mařiie'   => ['Marie', 'Maria', [['Plur', 'P', 'Voc', '5']]],
                'mářiie'   => ['Marie', 'Maria', [['Plur', 'P', 'Voc', '5']]],
                'mařiiech' => ['Marie', 'Maria', [['Plur', 'P', 'Loc', '6']]],
                'mářiiech' => ['Marie', 'Maria', [['Plur', 'P', 'Loc', '6']]],
                'mařiiem'  => ['Marie', 'Maria', [['Plur', 'P', 'Dat', '3']]],
                'mářiiem'  => ['Marie', 'Maria', [['Plur', 'P', 'Dat', '3']]],
                'mařiích'  => ['Marie', 'Maria', [['Plur', 'P', 'Loc', '6']]],
                'mářiích'  => ['Marie', 'Maria', [['Plur', 'P', 'Loc', '6']]],
                'mařiím'   => ['Marie', 'Maria', [['Plur', 'P', 'Dat', '3']]],
                'mářiím'   => ['Marie', 'Maria', [['Plur', 'P', 'Dat', '3']]],
                'mařiu'    => ['Marie', 'Maria', [['Sing', 'S', 'Acc', '4']]],
                'mářiu'    => ['Marie', 'Maria', [['Sing', 'S', 'Acc', '4']]],
                'rachel'   => ['Ráchel',  'Rachel',  [['Sing', 'S', 'Nom', '1']]]
            );
            my $ma = $ma{$lform}; die("Something is wrong: '$lform'") if(!defined($ma));
            $f[2] = $ma->[0];
            $f[9] = set_lemma1300($f[9], $ma->[1]);
            $f[3] = 'PROPN';
            # U některých slov umožňujeme několik čtení, ale pokud to není žádné z nich, dáme první jako default.
            my @alt = @{$ma->[2]};
            for(my $i = $#alt; $i >= 0 ; $i--)
            {
                if($i == 0 || defined($alt[$i][4]) && get_ref($f[9]) =~ m/^$alt[$i][4]$/ || $f[5] =~ m/Case=$alt[$i][2].*Number=$alt[$i][0]/)
                {
                    $f[4] = 'NNF'.$alt[$i][1].$alt[$i][3].'-----A----';
                    $f[5] = 'Case='.$alt[$i][2].'|Gender=Fem|NameType=Giv|Number='.$alt[$i][0].'|Polarity=Pos';
                    last;
                }
            }
        }
        elsif($f[1] =~ m/^(Betani?|Dekapol|Galile?|Golgat|Sodom|Sy[rř])(a|e|é|ě|i|í|jí)$/i)
        {
            my $lform = lc($f[1]);
            my %ma =
            (
                'betania'     => ['Betanie',   'Betanie',   [['Sing', 'S', 'Nom', '1']]],
                'betaní'      => ['Betanie',   'Betanie',   [['Sing', 'S', 'Loc', '6']]],
                'betanie'     => ['Betanie',   'Betanie',   [['Sing', 'S', 'Gen', '2']]],
                'dekapol'     => ['Dekapolis', 'Dekapolis', [['Plur', 'P', 'Gen', '2']]],
                'dekapole'    => ['Dekapolis', 'Dekapolis', [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Voc', '5'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5']]],
                'dekapolě'    => ['Dekapolis', 'Dekapolis', [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Voc', '5'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5']]],
                'dekapolemi'  => ['Dekapolis', 'Dekapolis', [['Plur', 'P', 'Ins', '7']]],
                'dekapolěmi'  => ['Dekapolis', 'Dekapolis', [['Plur', 'P', 'Ins', '7']]],
                'dekapoli'    => ['Dekapolis', 'Dekapolis', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Acc', '4'], ['Sing', 'S', 'Loc', '6']]],
                'dekapolí'    => ['Dekapolis', 'Dekapolis', [['Sing', 'S', 'Ins', '7']]],
                'dekapolie'   => ['Dekapolis', 'Dekapolis', [['Plur', 'P', 'Voc', '5']]],
                'dekapoliech' => ['Dekapolis', 'Dekapolis', [['Plur', 'P', 'Loc', '6']]],
                'dekapoliem'  => ['Dekapolis', 'Dekapolis', [['Plur', 'P', 'Dat', '3']]],
                'dekapolích'  => ['Dekapolis', 'Dekapolis', [['Plur', 'P', 'Loc', '6']]],
                'dekapolím'   => ['Dekapolis', 'Dekapolis', [['Plur', 'P', 'Dat', '3']]],
                'dekapolu'    => ['Dekapolis', 'Dekapolis', [['Sing', 'S', 'Acc', '4']]],
                'galilé'      => ['Galilea',   'Galilea',   [['Sing', 'S', 'Gen', '2']]],
                'galilea'     => ['Galilea',   'Galilea',   [['Sing', 'S', 'Nom', '1']]],
                'galilee'     => ['Galilea',   'Galilea',   [['Sing', 'S', 'Gen', '2']]],
                'galilei'     => ['Galilea',   'Galilea',   [['Sing', 'S', 'Loc', '6']]],
                'galileí'     => ['Galilea',   'Galilea',   [['Sing', 'S', 'Acc', '4']]],
                'golgata'     => ['Golgata',   'Golgata',   [['Sing', 'S', 'Nom', '1']]],
                'sodom'    => ['Sodoma', 'Sodoma', [['Plur', 'P', 'Gen', '2']]],
                'sodoma'   => ['Sodoma', 'Sodoma', [['Sing', 'S', 'Nom', '1']]],
                'sodomách' => ['Sodoma', 'Sodoma', [['Plur', 'P', 'Loc', '6']]],
                'sodomám'  => ['Sodoma', 'Sodoma', [['Plur', 'P', 'Dat', '3']]],
                'sodomami' => ['Sodoma', 'Sodoma', [['Plur', 'P', 'Ins', '7']]],
                'sodome'   => ['Sodoma', 'Sodoma', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'sodomě'   => ['Sodoma', 'Sodoma', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6'], ['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5']]],
                'sodomo'   => ['Sodoma', 'Sodoma', [['Sing', 'S', 'Voc', '5']]],
                'sodomou'  => ['Sodoma', 'Sodoma', [['Sing', 'S', 'Ins', '7']]],
                'sodomu'   => ['Sodoma', 'Sodoma', [['Sing', 'S', 'Acc', '4']]],
                'sodomú'   => ['Sodoma', 'Sodoma', [['Sing', 'S', 'Ins', '7']]],
                'sodomy'   => ['Sodoma', 'Sodoma', [['Sing', 'S', 'Gen', '2'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5']]],
                'syrí'        => ['Sýrie',     'Syří',      [['Sing', 'S', 'Loc', '6']]],
                'syří'        => ['Sýrie',     'Syří',      [['Sing', 'S', 'Loc', '6']]]
            );
            my $ma = $ma{$lform}; die("Something is wrong: '$lform'") if(!defined($ma));
            $f[2] = $ma->[0];
            $f[9] = set_lemma1300($f[9], $ma->[1]);
            $f[3] = 'PROPN';
            # U některých slov umožňujeme několik čtení, ale pokud to není žádné z nich, dáme první jako default.
            my @alt = @{$ma->[2]};
            for(my $i = $#alt; $i >= 0 ; $i--)
            {
                if($i == 0 || defined($alt[$i][4]) && get_ref($f[9]) =~ m/^$alt[$i][4]$/ || $f[5] =~ m/Case=$alt[$i][2].*Number=$alt[$i][0]/)
                {
                    $f[4] = 'NNF'.$alt[$i][1].$alt[$i][3].'-----A----';
                    $f[5] = 'Case='.$alt[$i][2].'|Gender=Fem|NameType=Geo|Number='.$alt[$i][0].'|Polarity=Pos';
                    last;
                }
            }
        }
        #----------------------------------------------------------------------
        # Střední rod.
        #----------------------------------------------------------------------
        # "Jmu" zřejmě může být zájmeno "mu" a ne dativ od "jmě" = "jméno". A taky to může být sloveso "jmout".
        # "Miesto" je předložka v 2.21 resp. 2.22, všude jinde je to podstatné jméno.
        elsif(!($f[1] =~ m/^miesto$/i && get_ref($f[9]) =~ m/^MATT_2\.(21|22)$/) &&
              $f[1] =~ m/^(břiem|břiš|diet|dietek|dietky|d(?:ó|uo)stojenstv|hniezd|hoř|jm|jmen|kniež|ledv|let|měst|miest|násil|neb|nebes|oc|oslíč|písemc|práv|rob|robátk|rúch|sěn|siem|slovc|srde?c|tržišč|ust|vajc|zábradl)(o|e|é|ě|ie|a|i|u|ú|í|em|[eě]t[ei]|ata?|atóm|atuom|i?ech|ách|ích|aty)?$/i && $f[1] !~ m/^(diet[aei]|hniezdie|hoří?|hořie|hořěti|jm[aeiuú]?|jměte|jmie|jmiech|letě|letěti|letie|letí|násil|neb[ou]?|nebiech|nebích|ocí|roba)$/i)
        {
            my $lform = lc($f[1]);
            my %ma =
            (
                'břiem'    => ['břímě', 'břiemě', [['Plur', 'P', 'Gen', '2']]],
                'břieme'   => ['břímě', 'břiemě', [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4'], ['Sing', 'S', 'Voc', '5'], ['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5']]],
                'břiemě'   => ['břímě', 'břiemě', [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4'], ['Sing', 'S', 'Voc', '5'], ['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5']]],
                'břiemem'  => ['břímě', 'břiemě', [['Sing', 'S', 'Ins', '7']]],
                'břiemi'   => ['břímě', 'břiemě', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6'], ['Plur', 'P', 'Ins', '7']]],
                'břiemí'   => ['břímě', 'břiemě', [['Plur', 'P', 'Gen', '2']]],
                'břiemích' => ['břímě', 'břiemě', [['Plur', 'P', 'Loc', '6']]],
                'břiemím'  => ['břímě', 'břiemě', [['Plur', 'P', 'Dat', '3']]],
                'břiemoma' => ['břímě', 'břiemě', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'břiemu'   => ['břímě', 'břiemě', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'břiemú'   => ['břímě', 'břiemě', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'břím'     => ['břímě', 'břiemě', [['Plur', 'P', 'Gen', '2']]],
                'bříme'    => ['břímě', 'břiemě', [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4'], ['Sing', 'S', 'Voc', '5'], ['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5']]],
                'břímě'    => ['břímě', 'břiemě', [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4'], ['Sing', 'S', 'Voc', '5'], ['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5']]],
                'břímem'   => ['břímě', 'břiemě', [['Sing', 'S', 'Ins', '7']]],
                'břími'    => ['břímě', 'břiemě', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6'], ['Plur', 'P', 'Ins', '7']]],
                'břímí'    => ['břímě', 'břiemě', [['Plur', 'P', 'Gen', '2']]],
                'břímích'  => ['břímě', 'břiemě', [['Plur', 'P', 'Loc', '6']]],
                'břímím'   => ['břímě', 'břiemě', [['Plur', 'P', 'Dat', '3']]],
                'břímoma'  => ['břímě', 'břiemě', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'břímu'    => ['břímě', 'břiemě', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'břímú'    => ['břímě', 'břiemě', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'břich'    => ['břicho', 'břicho', [['Plur', 'P', 'Gen', '2']]],
                'břicha'   => ['břicho', 'břicho', [['Sing', 'S', 'Gen', '2'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5']]],
                'břichách' => ['břicho', 'břicho', [['Plur', 'P', 'Loc', '6']]],
                'břichami' => ['břicho', 'břicho', [['Plur', 'P', 'Ins', '7']]],
                'břichech' => ['břicho', 'břicho', [['Plur', 'P', 'Loc', '6']]],
                'břichem'  => ['břicho', 'břicho', [['Sing', 'S', 'Ins', '7']]],
                'břicho'   => ['břicho', 'břicho', [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Acc', '4'], ['Sing', 'S', 'Voc', '5']]],
                'břichóm'  => ['břicho', 'břicho', [['Plur', 'P', 'Dat', '3']]],
                'břichoma' => ['břicho', 'břicho', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'břichu'   => ['břicho', 'břicho', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'břichú'   => ['břicho', 'břicho', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'břichům'  => ['břicho', 'břicho', [['Plur', 'P', 'Dat', '3']]],
                'břichuom' => ['břicho', 'břicho', [['Plur', 'P', 'Dat', '3']]],
                'břichy'   => ['břicho', 'břicho', [['Plur', 'P', 'Ins', '7']]],
                'břiše'    => ['břicho', 'břicho', [['Sing', 'S', 'Loc', '6'], ['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5']]],
                'břišě'    => ['břicho', 'břicho', [['Sing', 'S', 'Loc', '6'], ['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5']]],
                'břišiech' => ['břicho', 'břicho', [['Plur', 'P', 'Loc', '6']]],
                'dět'       => ['dítě', 'dietě', [['Plur', 'P', 'Gen', '2']]],
                'dětě'      => ['dítě', 'dietě', [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4'], ['Sing', 'S', 'Voc', '5'], ['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5']]],
                'dětem'     => ['dítě', 'dietě', [['Sing', 'S', 'Ins', '7']]],
                'děti'      => ['dítě', 'dietě', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6'], ['Plur', 'P', 'Ins', '7']]],
                'dětí'      => ['dítě', 'dietě', [['Plur', 'P', 'Gen', '2']]],
                'dětích'    => ['dítě', 'dietě', [['Plur', 'P', 'Loc', '6']]],
                'dětím'     => ['dítě', 'dietě', [['Plur', 'P', 'Dat', '3']]],
                'dětoma'    => ['dítě', 'dietě', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'dětu'      => ['dítě', 'dietě', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'dětú'      => ['dítě', 'dietě', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'diet'      => ['dítě', 'dietě', [['Plur', 'P', 'Gen', '2']]],
                'dietat'    => ['dítě', 'dietě', [['Plur', 'P', 'Gen', '2']]],
                'dietata'   => ['dítě', 'dietě', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5']]],
                'dietatech' => ['dítě', 'dietě', [['Plur', 'P', 'Loc', '6']]],
                'dietatóm'  => ['dítě', 'dietě', [['Plur', 'P', 'Dat', '3']]],
                'dietatům'  => ['dítě', 'dietě', [['Plur', 'P', 'Dat', '3']]],
                'dietatuom' => ['dítě', 'dietě', [['Plur', 'P', 'Dat', '3']]],
                'dietaty'   => ['dítě', 'dietě', [['Plur', 'P', 'Ins', '7']]],
                'dietě'     => ['dítě', 'dietě', [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4'], ['Sing', 'S', 'Voc', '5'], ['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5']]],
                'dietem'    => ['dítě', 'dietě', [['Sing', 'S', 'Ins', '7']]],
                'dietete'   => ['dítě', 'dietě', [['Sing', 'S', 'Gen', '2']]],
                'dietěte'   => ['dítě', 'dietě', [['Sing', 'S', 'Gen', '2']]],
                'dietetem'  => ['dítě', 'dietě', [['Sing', 'S', 'Ins', '7']]],
                'dietětem'  => ['dítě', 'dietě', [['Sing', 'S', 'Ins', '7']]],
                'dieteti'   => ['dítě', 'dietě', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'dietěti'   => ['dítě', 'dietě', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'dieti'     => ['dítě', 'dietě', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6'], ['Plur', 'P', 'Ins', '7']]],
                'dietí'     => ['dítě', 'dietě', [['Plur', 'P', 'Gen', '2']]],
                'dietích'   => ['dítě', 'dietě', [['Plur', 'P', 'Loc', '6']]],
                'dietím'    => ['dítě', 'dietě', [['Plur', 'P', 'Dat', '3']]],
                'dietoma'   => ['dítě', 'dietě', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'dietu'     => ['dítě', 'dietě', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'dietú'     => ['dítě', 'dietě', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'dítat'     => ['dítě', 'dietě', [['Plur', 'P', 'Gen', '2']]],
                'dítata'    => ['dítě', 'dietě', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5']]],
                'dítatech'  => ['dítě', 'dietě', [['Plur', 'P', 'Loc', '6']]],
                'dítatóm'   => ['dítě', 'dietě', [['Plur', 'P', 'Dat', '3']]],
                'dítatům'   => ['dítě', 'dietě', [['Plur', 'P', 'Dat', '3']]],
                'dítatuom'  => ['dítě', 'dietě', [['Plur', 'P', 'Dat', '3']]],
                'dítaty'    => ['dítě', 'dietě', [['Plur', 'P', 'Ins', '7']]],
                'dítě'      => ['dítě', 'dietě', [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Acc', '4'], ['Sing', 'S', 'Voc', '5']]],
                'dítete'    => ['dítě', 'dietě', [['Sing', 'S', 'Gen', '2']]],
                'dítěte'    => ['dítě', 'dietě', [['Sing', 'S', 'Gen', '2']]],
                'dítetem'   => ['dítě', 'dietě', [['Sing', 'S', 'Ins', '7']]],
                'dítětem'   => ['dítě', 'dietě', [['Sing', 'S', 'Ins', '7']]],
                'díteti'    => ['dítě', 'dietě', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'dítěti'    => ['dítě', 'dietě', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'dietek'      => ['dítě',     'dietě',    [['Plur', 'P', 'Gen', '2']]],
                'dietky'      => ['dítě',     'dietě',    [['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Nom', '1']]],
                'dóstojenstev'     => ['důstojenství', 'dóstojenstvie', [['Plur', 'P', 'Gen', '2']]],
                'dóstojenstva'     => ['důstojenství', 'dóstojenstvie', [['Sing', 'S', 'Gen', '2'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5']]],
                'dóstojenstvách'   => ['důstojenství', 'dóstojenstvie', [['Plur', 'P', 'Loc', '6']]],
                'dóstojenstvami'   => ['důstojenství', 'dóstojenstvie', [['Plur', 'P', 'Ins', '7']]],
                'dóstojenstve'     => ['důstojenství', 'dóstojenstvie', [['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5']]],
                'dóstojenstvě'     => ['důstojenství', 'dóstojenstvie', [['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5']]],
                'dóstojenstvem'    => ['důstojenství', 'dóstojenstvie', [['Sing', 'S', 'Ins', '7']]],
                'dóstojenství'     => ['důstojenství', 'dóstojenstvie', [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Acc', '4'], ['Sing', 'S', 'Voc', '5'], ['Sing', 'S', 'Loc', '6'], ['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Gen', '2'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5']]],
                'dóstojenstvie'    => ['důstojenství', 'dóstojenstvie', [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Acc', '4'], ['Sing', 'S', 'Voc', '5']]],
                'dóstojenstviech'  => ['důstojenství', 'dóstojenstvie', [['Plur', 'P', 'Loc', '6']]],
                'dóstojenstvích'   => ['důstojenství', 'dóstojenstvie', [['Plur', 'P', 'Loc', '6']]],
                'dóstojenstvím'    => ['důstojenství', 'dóstojenstvie', [['Sing', 'S', 'Ins', '7'], ['Plur', 'P', 'Dat', '3']]],
                'dóstojenstvíma'   => ['důstojenství', 'dóstojenstvie', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'dóstojenstvími'   => ['důstojenství', 'dóstojenstvie', [['Plur', 'P', 'Ins', '7']]],
                'dóstojenstvo'     => ['důstojenství', 'dóstojenstvie', [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Acc', '4'], ['Sing', 'S', 'Voc', '5']]],
                'dóstojenstvóm'    => ['důstojenství', 'dóstojenstvie', [['Plur', 'P', 'Dat', '3']]],
                'dóstojenstvoma'   => ['důstojenství', 'dóstojenstvie', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'dóstojenstvu'     => ['důstojenství', 'dóstojenstvie', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'dóstojenstvú'     => ['důstojenství', 'dóstojenstvie', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'dóstojenstvům'    => ['důstojenství', 'dóstojenstvie', [['Plur', 'P', 'Dat', '3']]],
                'dóstojenstvuom'   => ['důstojenství', 'dóstojenstvie', [['Plur', 'P', 'Dat', '3']]],
                'dóstojenstvy'     => ['důstojenství', 'dóstojenstvie', [['Plur', 'P', 'Ins', '7']]],
                'duostojenstev'    => ['důstojenství', 'dóstojenstvie', [['Plur', 'P', 'Gen', '2']]],
                'duostojenstva'    => ['důstojenství', 'dóstojenstvie', [['Sing', 'S', 'Gen', '2'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5']]],
                'duostojenstvách'  => ['důstojenství', 'dóstojenstvie', [['Plur', 'P', 'Loc', '6']]],
                'duostojenstvami'  => ['důstojenství', 'dóstojenstvie', [['Plur', 'P', 'Ins', '7']]],
                'duostojenstve'    => ['důstojenství', 'dóstojenstvie', [['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5']]],
                'duostojenstvě'    => ['důstojenství', 'dóstojenstvie', [['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5']]],
                'duostojenstvem'   => ['důstojenství', 'dóstojenstvie', [['Sing', 'S', 'Ins', '7']]],
                'duostojenství'    => ['důstojenství', 'dóstojenstvie', [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Acc', '4'], ['Sing', 'S', 'Voc', '5'], ['Sing', 'S', 'Loc', '6'], ['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Gen', '2'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5']]],
                'duostojenstvie'   => ['důstojenství', 'dóstojenstvie', [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Acc', '4'], ['Sing', 'S', 'Voc', '5']]],
                'duostojenstviech' => ['důstojenství', 'dóstojenstvie', [['Plur', 'P', 'Loc', '6']]],
                'duostojenstvích'  => ['důstojenství', 'dóstojenstvie', [['Plur', 'P', 'Loc', '6']]],
                'duostojenstvím'   => ['důstojenství', 'dóstojenstvie', [['Sing', 'S', 'Ins', '7'], ['Plur', 'P', 'Dat', '3']]],
                'duostojenstvíma'  => ['důstojenství', 'dóstojenstvie', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'duostojenstvími'  => ['důstojenství', 'dóstojenstvie', [['Plur', 'P', 'Ins', '7']]],
                'duostojenstvo'    => ['důstojenství', 'dóstojenstvie', [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Acc', '4'], ['Sing', 'S', 'Voc', '5']]],
                'duostojenstvóm'   => ['důstojenství', 'dóstojenstvie', [['Plur', 'P', 'Dat', '3']]],
                'duostojenstvoma'  => ['důstojenství', 'dóstojenstvie', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'duostojenstvu'    => ['důstojenství', 'dóstojenstvie', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'duostojenstvú'    => ['důstojenství', 'dóstojenstvie', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'duostojenstvům'   => ['důstojenství', 'dóstojenstvie', [['Plur', 'P', 'Dat', '3']]],
                'duostojenstvuom'  => ['důstojenství', 'dóstojenstvie', [['Plur', 'P', 'Dat', '3']]],
                'duostojenstvy'    => ['důstojenství', 'dóstojenstvie', [['Plur', 'P', 'Ins', '7']]],
                'důstojenstev'     => ['důstojenství', 'dóstojenstvie', [['Plur', 'P', 'Gen', '2']]],
                'důstojenstva'     => ['důstojenství', 'dóstojenstvie', [['Sing', 'S', 'Gen', '2'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5']]],
                'důstojenstvách'   => ['důstojenství', 'dóstojenstvie', [['Plur', 'P', 'Loc', '6']]],
                'důstojenstvami'   => ['důstojenství', 'dóstojenstvie', [['Plur', 'P', 'Ins', '7']]],
                'důstojenstve'     => ['důstojenství', 'dóstojenstvie', [['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5']]],
                'důstojenstvě'     => ['důstojenství', 'dóstojenstvie', [['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5']]],
                'důstojenstvem'    => ['důstojenství', 'dóstojenstvie', [['Sing', 'S', 'Ins', '7']]],
                'důstojenství'     => ['důstojenství', 'dóstojenstvie', [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Acc', '4'], ['Sing', 'S', 'Voc', '5'], ['Sing', 'S', 'Loc', '6'], ['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Gen', '2'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5']]],
                'důstojenstvie'    => ['důstojenství', 'dóstojenstvie', [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Acc', '4'], ['Sing', 'S', 'Voc', '5']]],
                'důstojenstviech'  => ['důstojenství', 'dóstojenstvie', [['Plur', 'P', 'Loc', '6']]],
                'důstojenstvích'   => ['důstojenství', 'dóstojenstvie', [['Plur', 'P', 'Loc', '6']]],
                'důstojenstvím'    => ['důstojenství', 'dóstojenstvie', [['Sing', 'S', 'Ins', '7'], ['Plur', 'P', 'Dat', '3']]],
                'důstojenstvíma'   => ['důstojenství', 'dóstojenstvie', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'důstojenstvími'   => ['důstojenství', 'dóstojenstvie', [['Plur', 'P', 'Ins', '7']]],
                'důstojenstvo'     => ['důstojenství', 'dóstojenstvie', [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Acc', '4'], ['Sing', 'S', 'Voc', '5']]],
                'důstojenstvóm'    => ['důstojenství', 'dóstojenstvie', [['Plur', 'P', 'Dat', '3']]],
                'důstojenstvoma'   => ['důstojenství', 'dóstojenstvie', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'důstojenstvu'     => ['důstojenství', 'dóstojenstvie', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'důstojenstvú'     => ['důstojenství', 'dóstojenstvie', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'důstojenstvům'    => ['důstojenství', 'dóstojenstvie', [['Plur', 'P', 'Dat', '3']]],
                'důstojenstvuom'   => ['důstojenství', 'dóstojenstvie', [['Plur', 'P', 'Dat', '3']]],
                'důstojenstvy'     => ['důstojenství', 'dóstojenstvie', [['Plur', 'P', 'Ins', '7']]],
                'hniezd'      => ['hnízdo',   'hniezdo',  [['Plur', 'P', 'Gen', '2']]],
                'hniezda'     => ['hnízdo',   'hniezdo',  [['Sing', 'S', 'Gen', '2'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4']]],
                'hniezdo'     => ['hnízdo',   'hniezdo',  [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Acc', '4'], ['Sing', 'S', 'Voc', '5']]],
                'hoře'        => ['hoře',     'hoře',     [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4'], ['Sing', 'S', 'Voc', '5']]],
                'hoři'        => ['hoře',     'hoře',     [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'hořem'       => ['hoře',     'hoře',     [['Sing', 'S', 'Ins', '7']]],
                'jmě'         => ['jméno',    'jmě',      [['Sing', 'S', 'Acc', '4'], ['Sing', 'S', 'Nom', '1']]],
                'jmen'        => ['jméno',    'jmě',      [['Plur', 'P', 'Gen', '2']]],
                'jmena'       => ['jméno',    'jmě',      [['Plur', 'P', 'Nom', '1']]],
                'jmene'       => ['jméno',    'jmě',      [['Sing', 'S', 'Gen', '2']]],
                'jmeni'       => ['jméno',    'jmě',      [['Sing', 'S', 'Gen', '2']]],
                'jmenu'       => ['jméno',    'jmě',      [['Sing', 'S', 'Loc', '6']]],
                'jmenem'      => ['jméno',    'jmě',      [['Sing', 'S', 'Ins', '7']]],
                'kniežat'     => ['kníže',    'kniežě',   [['Plur', 'P', 'Gen', '2']]],
                'kniežata'    => ['kníže',    'kniežě',   [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4']]],
                'kniežatóm'   => ['kníže',    'kniežě',   [['Plur', 'P', 'Dat', '3']]],
                'kniežaty'    => ['kníže',    'kniežě',   [['Plur', 'P', 'Ins', '7']]],
                'knieže'      => ['kníže',    'kniežě',   [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Acc', '4']]],
                'kniežě'      => ['kníže',    'kniežě',   [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Acc', '4']]],
                'kniežete'    => ['kníže',    'kniežě',   [['Sing', 'S', 'Gen', '2']]],
                'kniežěte'    => ['kníže',    'kniežě',   [['Sing', 'S', 'Gen', '2']]],
                'kniežeti'    => ['kníže',    'kniežě',   [['Sing', 'S', 'Dat', '3']]],
                'kniežěti'    => ['kníže',    'kniežě',   [['Sing', 'S', 'Dat', '3']]],
                'ledvie'      => ['ledví',    'ledvie',   [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Acc', '4']]],
                'ledví'       => ['ledví',    'ledvie',   [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4']]],
                'ledvích'     => ['ledví',    'ledvie',   [['Plur', 'P', 'Loc', '6']]],
                'let'     => ['rok', 'rok', [['Plur', 'P', 'Gen', '2']]],
                'leta'    => ['rok', 'rok', [['Sing', 'S', 'Gen', '2'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5']]],
                'letách'  => ['rok', 'rok', [['Plur', 'P', 'Loc', '6']]],
                'letami'  => ['rok', 'rok', [['Plur', 'P', 'Ins', '7']]],
                'letě'    => ['rok', 'rok', [['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5']]],
                'letech'  => ['rok', 'rok', [['Plur', 'P', 'Loc', '6']]],
                'letem'   => ['rok', 'rok', [['Sing', 'S', 'Ins', '7']]],
                'letiech' => ['rok', 'rok', [['Plur', 'P', 'Loc', '6']]],
                'leto'    => ['rok', 'rok', [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Acc', '4'], ['Sing', 'S', 'Voc', '5']]],
                'letóm'   => ['rok', 'rok', [['Plur', 'P', 'Dat', '3']]],
                'letoma'  => ['rok', 'rok', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'letu'    => ['rok', 'rok', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'letú'    => ['rok', 'rok', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'letům'   => ['rok', 'rok', [['Plur', 'P', 'Dat', '3']]],
                'letuom'  => ['rok', 'rok', [['Plur', 'P', 'Dat', '3']]],
                'lety'    => ['rok', 'rok', [['Plur', 'P', 'Ins', '7']]],
                'měst'     => ['město', 'město', [['Plur', 'P', 'Gen', '2']]],
                'města'    => ['město', 'město', [['Sing', 'S', 'Gen', '2'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5']]],
                'městách'  => ['město', 'město', [['Plur', 'P', 'Loc', '6']]],
                'městami'  => ['město', 'město', [['Plur', 'P', 'Ins', '7']]],
                'městě'    => ['město', 'město', [['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5']]],
                'městech'  => ['město', 'město', [['Plur', 'P', 'Loc', '6']]],
                'městem'   => ['město', 'město', [['Sing', 'S', 'Ins', '7']]],
                'městiech' => ['město', 'město', [['Plur', 'P', 'Loc', '6']]],
                'město'    => ['město', 'město', [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Acc', '4'], ['Sing', 'S', 'Voc', '5']]],
                'městóm'   => ['město', 'město', [['Plur', 'P', 'Dat', '3']]],
                'městoma'  => ['město', 'město', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'městu'    => ['město', 'město', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'městú'    => ['město', 'město', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'městům'   => ['město', 'město', [['Plur', 'P', 'Dat', '3']]],
                'městuom'  => ['město', 'město', [['Plur', 'P', 'Dat', '3']]],
                'městy'    => ['město', 'město', [['Plur', 'P', 'Ins', '7']]],
                'miest'     => ['místo', 'miesto', [['Plur', 'P', 'Gen', '2']]],
                'miesta'    => ['místo', 'miesto', [['Sing', 'S', 'Gen', '2'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5']]],
                'miestách'  => ['místo', 'miesto', [['Plur', 'P', 'Loc', '6']]],
                'miestami'  => ['místo', 'miesto', [['Plur', 'P', 'Ins', '7']]],
                'miestě'    => ['místo', 'miesto', [['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5']]],
                'miestech'  => ['místo', 'miesto', [['Plur', 'P', 'Loc', '6']]],
                'miestem'   => ['místo', 'miesto', [['Sing', 'S', 'Ins', '7']]],
                'miestiech' => ['místo', 'miesto', [['Plur', 'P', 'Loc', '6']]],
                'miesto'    => ['místo', 'miesto', [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Acc', '4'], ['Sing', 'S', 'Voc', '5']]],
                'miestóm'   => ['místo', 'miesto', [['Plur', 'P', 'Dat', '3']]],
                'miestoma'  => ['místo', 'miesto', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'miestu'    => ['místo', 'miesto', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'miestú'    => ['místo', 'miesto', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'miestům'   => ['místo', 'miesto', [['Plur', 'P', 'Dat', '3']]],
                'miestuom'  => ['místo', 'miesto', [['Plur', 'P', 'Dat', '3']]],
                'miesty'    => ['místo', 'miesto', [['Plur', 'P', 'Ins', '7']]],
                'míst'      => ['místo', 'miesto', [['Plur', 'P', 'Gen', '2']]],
                'místa'     => ['místo', 'miesto', [['Sing', 'S', 'Gen', '2'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5']]],
                'místách'   => ['místo', 'miesto', [['Plur', 'P', 'Loc', '6']]],
                'místami'   => ['místo', 'miesto', [['Plur', 'P', 'Ins', '7']]],
                'místě'     => ['místo', 'miesto', [['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5']]],
                'místech'   => ['místo', 'miesto', [['Plur', 'P', 'Loc', '6']]],
                'místem'    => ['místo', 'miesto', [['Sing', 'S', 'Ins', '7']]],
                'místiech'  => ['místo', 'miesto', [['Plur', 'P', 'Loc', '6']]],
                'místo'     => ['místo', 'miesto', [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Acc', '4'], ['Sing', 'S', 'Voc', '5']]],
                'místóm'    => ['místo', 'miesto', [['Plur', 'P', 'Dat', '3']]],
                'místoma'   => ['místo', 'miesto', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'místu'     => ['místo', 'miesto', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'místú'     => ['místo', 'miesto', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'místům'    => ['místo', 'miesto', [['Plur', 'P', 'Dat', '3']]],
                'místuom'   => ['místo', 'miesto', [['Plur', 'P', 'Dat', '3']]],
                'místy'     => ['místo', 'miesto', [['Plur', 'P', 'Ins', '7']]],
                'násilé'      => ['násilí',   'násilé',   [['Sing', 'S', 'Acc', '4'], ['Sing', 'S', 'Nom', '1']]],
                'nebe'      => ['nebe', 'nebě', [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4'], ['Sing', 'S', 'Voc', '5'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5']]],
                'nebě'      => ['nebe', 'nebě', [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4'], ['Sing', 'S', 'Voc', '5'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5']]],
                'nebem'     => ['nebe', 'nebě', [['Sing', 'S', 'Ins', '7']]],
                'nebes'     => ['nebe', 'nebě', [['Plur', 'P', 'Gen', '2']]],
                'nebesa'    => ['nebe', 'nebě', [['Sing', 'S', 'Gen', '2'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5']]],
                'nebesách'  => ['nebe', 'nebě', [['Plur', 'P', 'Loc', '6']]],
                'nebesami'  => ['nebe', 'nebě', [['Plur', 'P', 'Ins', '7']]],
                'nebesem'   => ['nebe', 'nebě', [['Sing', 'S', 'Ins', '7']]],
                'nebesiech' => ['nebe', 'nebě', [['Plur', 'P', 'Loc', '6']]],
                'nebeso'    => ['nebe', 'nebě', [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Acc', '4'], ['Sing', 'S', 'Voc', '5']]],
                'nebesóm'   => ['nebe', 'nebě', [['Plur', 'P', 'Dat', '3']]],
                'nebesu'    => ['nebe', 'nebě', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'nebesům'   => ['nebe', 'nebě', [['Plur', 'P', 'Dat', '3']]],
                'nebesuom'  => ['nebe', 'nebě', [['Plur', 'P', 'Dat', '3']]],
                'nebesy'    => ['nebe', 'nebě', [['Plur', 'P', 'Ins', '7']]],
                'nebi'      => ['nebe', 'nebě', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6'], ['Plur', 'P', 'Ins', '7']]],
                'nebí'      => ['nebe', 'nebě', [['Plur', 'P', 'Gen', '2']]],
                'nebích'    => ['nebe', 'nebě', [['Plur', 'P', 'Loc', '6']]],
                'nebím'     => ['nebe', 'nebě', [['Plur', 'P', 'Dat', '3']]],
                'ocě'         => ['oko',      'oko',      [['Sing', 'S', 'Loc', '6'], ['Dual', 'D', 'Acc', '4', 'MATT_18\\.9']]],
                'oslíčě'      => ['oslíče',   'oslíčě',   [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Acc', '4']]],
                'písemce'     => ['písmeno',  'písemce',  [['Sing', 'S', 'Nom', '1']]],
                'práv'        => ['právo',    'právo',    [['Plur', 'P', 'Gen', '2']]],
                'práva'       => ['právo',    'právo',    [['Sing', 'S', 'Gen', '2'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4']]],
                'právě'       => ['právo',    'právo',    [['Sing', 'S', 'Dat', '3']]],
                'právem'      => ['právo',    'právo',    [['Plur', 'P', 'Ins', '7']]],
                'práviech'    => ['právo',    'právo',    [['Plur', 'P', 'Loc', '6']]],
                'právo'       => ['právo',    'právo',    [['Sing', 'S', 'Nom', '1']]],
                'právu'       => ['právo',    'právo',    [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'robat'    => ['robě', 'robě', [['Plur', 'P', 'Gen', '2']]],
                'robata'   => ['robě', 'robě', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5']]],
                'robatech' => ['robě', 'robě', [['Plur', 'P', 'Loc', '6']]],
                'robatóm'  => ['robě', 'robě', [['Plur', 'P', 'Dat', '3']]],
                'robatům'  => ['robě', 'robě', [['Plur', 'P', 'Dat', '3']]],
                'robatuom' => ['robě', 'robě', [['Plur', 'P', 'Dat', '3']]],
                'robaty'   => ['robě', 'robě', [['Plur', 'P', 'Ins', '7']]],
                'robe'     => ['robě', 'robě', [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Acc', '4'], ['Sing', 'S', 'Voc', '5']]],
                'robě'     => ['robě', 'robě', [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Acc', '4'], ['Sing', 'S', 'Voc', '5']]],
                'robete'   => ['robě', 'robě', [['Sing', 'S', 'Gen', '2']]],
                'roběte'   => ['robě', 'robě', [['Sing', 'S', 'Gen', '2']]],
                'robetem'  => ['robě', 'robě', [['Sing', 'S', 'Ins', '7']]],
                'robětem'  => ['robě', 'robě', [['Sing', 'S', 'Ins', '7']]],
                'robeti'   => ['robě', 'robě', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'roběti'   => ['robě', 'robě', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'robátce'    => ['robátko', 'robátko', [['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5']]],
                'robátcě'    => ['robátko', 'robátko', [['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5']]],
                'robátciech' => ['robátko', 'robátko', [['Plur', 'P', 'Loc', '6']]],
                'robátek'    => ['robátko', 'robátko', [['Plur', 'P', 'Gen', '2']]],
                'robátka'    => ['robátko', 'robátko', [['Sing', 'S', 'Gen', '2'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5']]],
                'robátkách'  => ['robátko', 'robátko', [['Plur', 'P', 'Loc', '6']]],
                'robátkami'  => ['robátko', 'robátko', [['Plur', 'P', 'Ins', '7']]],
                'robátkech'  => ['robátko', 'robátko', [['Plur', 'P', 'Loc', '6']]],
                'robátkem'   => ['robátko', 'robátko', [['Sing', 'S', 'Ins', '7']]],
                'robátko'    => ['robátko', 'robátko', [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Acc', '4'], ['Sing', 'S', 'Voc', '5']]],
                'robátkóm'   => ['robátko', 'robátko', [['Plur', 'P', 'Dat', '3']]],
                'robátkoma'  => ['robátko', 'robátko', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'robátku'    => ['robátko', 'robátko', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'robátkú'    => ['robátko', 'robátko', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'robátkům'   => ['robátko', 'robátko', [['Plur', 'P', 'Dat', '3']]],
                'robátkuom'  => ['robátko', 'robátko', [['Plur', 'P', 'Dat', '3']]],
                'robátky'    => ['robátko', 'robátko', [['Plur', 'P', 'Ins', '7']]],
                'rouch'    => ['roucho', 'rúcho', [['Plur', 'P', 'Gen', '2']]],
                'roucha'   => ['roucho', 'rúcho', [['Sing', 'S', 'Gen', '2'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5']]],
                'rouchách' => ['roucho', 'rúcho', [['Plur', 'P', 'Loc', '6']]],
                'rouchami' => ['roucho', 'rúcho', [['Plur', 'P', 'Ins', '7']]],
                'rouchech' => ['roucho', 'rúcho', [['Plur', 'P', 'Loc', '6']]],
                'rouchem'  => ['roucho', 'rúcho', [['Sing', 'S', 'Ins', '7']]],
                'roucho'   => ['roucho', 'rúcho', [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Acc', '4'], ['Sing', 'S', 'Voc', '5']]],
                'rouchóm'  => ['roucho', 'rúcho', [['Plur', 'P', 'Dat', '3']]],
                'rouchoma' => ['roucho', 'rúcho', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'rouchu'   => ['roucho', 'rúcho', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'rouchú'   => ['roucho', 'rúcho', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'rouchům'  => ['roucho', 'rúcho', [['Plur', 'P', 'Dat', '3']]],
                'rouchuom' => ['roucho', 'rúcho', [['Plur', 'P', 'Dat', '3']]],
                'rouchy'   => ['roucho', 'rúcho', [['Plur', 'P', 'Ins', '7']]],
                'rouše'    => ['roucho', 'rúcho', [['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5']]],
                'roušě'    => ['roucho', 'rúcho', [['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5']]],
                'roušiech' => ['roucho', 'rúcho', [['Plur', 'P', 'Loc', '6']]],
                'rúch'     => ['roucho', 'rúcho', [['Plur', 'P', 'Gen', '2']]],
                'rúcha'    => ['roucho', 'rúcho', [['Sing', 'S', 'Gen', '2'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5']]],
                'rúchách'  => ['roucho', 'rúcho', [['Plur', 'P', 'Loc', '6']]],
                'rúchami'  => ['roucho', 'rúcho', [['Plur', 'P', 'Ins', '7']]],
                'rúchech'  => ['roucho', 'rúcho', [['Plur', 'P', 'Loc', '6']]],
                'rúchem'   => ['roucho', 'rúcho', [['Sing', 'S', 'Ins', '7']]],
                'rúcho'    => ['roucho', 'rúcho', [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Acc', '4'], ['Sing', 'S', 'Voc', '5']]],
                'rúchóm'   => ['roucho', 'rúcho', [['Plur', 'P', 'Dat', '3']]],
                'rúchoma'  => ['roucho', 'rúcho', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'rúchu'    => ['roucho', 'rúcho', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'rúchú'    => ['roucho', 'rúcho', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'rúchům'   => ['roucho', 'rúcho', [['Plur', 'P', 'Dat', '3']]],
                'rúchuom'  => ['roucho', 'rúcho', [['Plur', 'P', 'Dat', '3']]],
                'rúchy'    => ['roucho', 'rúcho', [['Plur', 'P', 'Ins', '7']]],
                'rúše'     => ['roucho', 'rúcho', [['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5']]],
                'rúšě'     => ['roucho', 'rúcho', [['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5']]],
                'rúšiech'  => ['roucho', 'rúcho', [['Plur', 'P', 'Loc', '6']]],
                'sen'     => ['seno', 'sěno', [['Plur', 'P', 'Gen', '2']]],
                'sěn'     => ['seno', 'sěno', [['Plur', 'P', 'Gen', '2']]],
                'sena'    => ['seno', 'sěno', [['Sing', 'S', 'Gen', '2'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5']]],
                'sěna'    => ['seno', 'sěno', [['Sing', 'S', 'Gen', '2'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5']]],
                'senách'  => ['seno', 'sěno', [['Plur', 'P', 'Loc', '6']]],
                'sěnách'  => ['seno', 'sěno', [['Plur', 'P', 'Loc', '6']]],
                'senami'  => ['seno', 'sěno', [['Plur', 'P', 'Ins', '7']]],
                'sěnami'  => ['seno', 'sěno', [['Plur', 'P', 'Ins', '7']]],
                'seně'    => ['seno', 'sěno', [['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5']]],
                'sěně'    => ['seno', 'sěno', [['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5']]],
                'senech'  => ['seno', 'sěno', [['Plur', 'P', 'Loc', '6']]],
                'sěnech'  => ['seno', 'sěno', [['Plur', 'P', 'Loc', '6']]],
                'senem'   => ['seno', 'sěno', [['Sing', 'S', 'Ins', '7']]],
                'sěnem'   => ['seno', 'sěno', [['Sing', 'S', 'Ins', '7']]],
                'seniech' => ['seno', 'sěno', [['Plur', 'P', 'Loc', '6']]],
                'sěniech' => ['seno', 'sěno', [['Plur', 'P', 'Loc', '6']]],
                'seno'    => ['seno', 'sěno', [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Acc', '4'], ['Sing', 'S', 'Voc', '5']]],
                'sěno'    => ['seno', 'sěno', [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Acc', '4'], ['Sing', 'S', 'Voc', '5']]],
                'senóm'   => ['seno', 'sěno', [['Plur', 'P', 'Dat', '3']]],
                'sěnóm'   => ['seno', 'sěno', [['Plur', 'P', 'Dat', '3']]],
                'senoma'  => ['seno', 'sěno', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'sěnoma'  => ['seno', 'sěno', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'senu'    => ['seno', 'sěno', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'senú'    => ['seno', 'sěno', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'sěnu'    => ['seno', 'sěno', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'sěnú'    => ['seno', 'sěno', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'senům'   => ['seno', 'sěno', [['Plur', 'P', 'Dat', '3']]],
                'sěnům'   => ['seno', 'sěno', [['Plur', 'P', 'Dat', '3']]],
                'senuom'  => ['seno', 'sěno', [['Plur', 'P', 'Dat', '3']]],
                'sěnuom'  => ['seno', 'sěno', [['Plur', 'P', 'Dat', '3']]],
                'seny'    => ['seno', 'sěno', [['Plur', 'P', 'Ins', '7']]],
                'sěny'    => ['seno', 'sěno', [['Plur', 'P', 'Ins', '7']]],
                'siemě'       => ['semeno',   'siemě',    [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Acc', '4']]],
                'slovce'   => ['slovo', 'slovce', [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4'], ['Sing', 'S', 'Voc', '5'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5']]],
                'slovcě'   => ['slovo', 'slovce', [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4'], ['Sing', 'S', 'Voc', '5'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5']]],
                'slovcem'  => ['slovo', 'slovce', [['Sing', 'S', 'Ins', '7']]],
                'slovci'   => ['slovo', 'slovce', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6'], ['Plur', 'P', 'Ins', '7']]],
                'slovcí'   => ['slovo', 'slovce', [['Plur', 'P', 'Gen', '2']]],
                'slovcích' => ['slovo', 'slovce', [['Plur', 'P', 'Loc', '6']]],
                'slovcím'  => ['slovo', 'slovce', [['Plur', 'P', 'Dat', '3']]],
                'srdce'   => ['srdce', 'srdce', [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4'], ['Sing', 'S', 'Voc', '5'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5']]],
                'srdcě'   => ['srdce', 'srdce', [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4'], ['Sing', 'S', 'Voc', '5'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5']]],
                'srdcem'  => ['srdce', 'srdce', [['Sing', 'S', 'Ins', '7']]],
                'srdci'   => ['srdce', 'srdce', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6'], ['Plur', 'P', 'Ins', '7']]],
                'srdcí'   => ['srdce', 'srdce', [['Plur', 'P', 'Gen', '2']]],
                'srdcích' => ['srdce', 'srdce', [['Plur', 'P', 'Loc', '6']]],
                'srdcím'  => ['srdce', 'srdce', [['Plur', 'P', 'Dat', '3']]],
                'srdcu'   => ['srdce', 'srdce', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'srdec'   => ['srdce', 'srdce', [['Plur', 'P', 'Gen', '2']]],
                'tržišč'    => ['tržiště', 'tržišče', [['Plur', 'P', 'Gen', '2']]],
                'tržišče'   => ['tržiště', 'tržišče', [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4'], ['Sing', 'S', 'Voc', '5'], ['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5']]],
                'tržiščě'   => ['tržiště', 'tržišče', [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4'], ['Sing', 'S', 'Voc', '5'], ['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5']]],
                'tržiščem'  => ['tržiště', 'tržišče', [['Sing', 'S', 'Ins', '7']]],
                'tržišči'   => ['tržiště', 'tržišče', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6'], ['Plur', 'P', 'Ins', '7']]],
                'tržiščí'   => ['tržiště', 'tržišče', [['Plur', 'P', 'Gen', '2']]],
                'tržiščích' => ['tržiště', 'tržišče', [['Plur', 'P', 'Loc', '6']]],
                'tržiščím'  => ['tržiště', 'tržišče', [['Plur', 'P', 'Dat', '3']]],
                'tržiščoma' => ['tržiště', 'tržišče', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'tržišču'   => ['tržiště', 'tržišče', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'tržiščú'   => ['tržiště', 'tržišče', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'tržišť'    => ['tržiště', 'tržišče', [['Plur', 'P', 'Gen', '2']]],
                'tržiště'   => ['tržiště', 'tržišče', [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4'], ['Sing', 'S', 'Voc', '5'], ['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5']]],
                'tržištěm'  => ['tržiště', 'tržišče', [['Sing', 'S', 'Ins', '7']]],
                'tržišti'   => ['tržiště', 'tržišče', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6'], ['Plur', 'P', 'Ins', '7']]],
                'tržiští'   => ['tržiště', 'tržišče', [['Plur', 'P', 'Gen', '2']]],
                'tržištích' => ['tržiště', 'tržišče', [['Plur', 'P', 'Loc', '6']]],
                'tržištím'  => ['tržiště', 'tržišče', [['Plur', 'P', 'Dat', '3']]],
                'tržišťoma' => ['tržiště', 'tržišče', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'tržišťu'   => ['tržiště', 'tržišče', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'tržišťú'   => ['tržiště', 'tržišče', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'ust'     => ['ústa', 'usta', [['Plur', 'P', 'Gen', '2']]],
                'úst'     => ['ústa', 'usta', [['Plur', 'P', 'Gen', '2']]],
                'usta'    => ['ústa', 'usta', [['Sing', 'S', 'Gen', '2'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5']]],
                'ústa'    => ['ústa', 'usta', [['Sing', 'S', 'Gen', '2'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5']]],
                'ustách'  => ['ústa', 'usta', [['Plur', 'P', 'Loc', '6']]],
                'ústách'  => ['ústa', 'usta', [['Plur', 'P', 'Loc', '6']]],
                'ustami'  => ['ústa', 'usta', [['Plur', 'P', 'Ins', '7']]],
                'ústami'  => ['ústa', 'usta', [['Plur', 'P', 'Ins', '7']]],
                'ustě'    => ['ústa', 'usta', [['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5']]],
                'ústě'    => ['ústa', 'usta', [['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5']]],
                'ustech'  => ['ústa', 'usta', [['Plur', 'P', 'Loc', '6']]],
                'ústech'  => ['ústa', 'usta', [['Plur', 'P', 'Loc', '6']]],
                'ustem'   => ['ústa', 'usta', [['Sing', 'S', 'Ins', '7']]],
                'ústem'   => ['ústa', 'usta', [['Sing', 'S', 'Ins', '7']]],
                'ustiech' => ['ústa', 'usta', [['Plur', 'P', 'Loc', '6']]],
                'ústiech' => ['ústa', 'usta', [['Plur', 'P', 'Loc', '6']]],
                'usto'    => ['ústa', 'usta', [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Acc', '4'], ['Sing', 'S', 'Voc', '5']]],
                'ústo'    => ['ústa', 'usta', [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Acc', '4'], ['Sing', 'S', 'Voc', '5']]],
                'ustóm'   => ['ústa', 'usta', [['Plur', 'P', 'Dat', '3']]],
                'ústóm'   => ['ústa', 'usta', [['Plur', 'P', 'Dat', '3']]],
                'ustoma'  => ['ústa', 'usta', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'ústoma'  => ['ústa', 'usta', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'ustu'    => ['ústa', 'usta', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'ustú'    => ['ústa', 'usta', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'ústu'    => ['ústa', 'usta', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'ústú'    => ['ústa', 'usta', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'ustům'   => ['ústa', 'usta', [['Plur', 'P', 'Dat', '3']]],
                'ústům'   => ['ústa', 'usta', [['Plur', 'P', 'Dat', '3']]],
                'ustuom'  => ['ústa', 'usta', [['Plur', 'P', 'Dat', '3']]],
                'ústuom'  => ['ústa', 'usta', [['Plur', 'P', 'Dat', '3']]],
                'usty'    => ['ústa', 'usta', [['Plur', 'P', 'Ins', '7']]],
                'ústy'    => ['ústa', 'usta', [['Plur', 'P', 'Ins', '7']]],
                'vajce'   => ['vejce', 'vajce', [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4'], ['Sing', 'S', 'Voc', '5'], ['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5']]],
                'vajcě'   => ['vejce', 'vajce', [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4'], ['Sing', 'S', 'Voc', '5'], ['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5']]],
                'vajcem'  => ['vejce', 'vajce', [['Sing', 'S', 'Ins', '7']]],
                'vajci'   => ['vejce', 'vajce', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6'], ['Plur', 'P', 'Ins', '7']]],
                'vajcí'   => ['vejce', 'vajce', [['Plur', 'P', 'Gen', '2']]],
                'vajcích' => ['vejce', 'vajce', [['Plur', 'P', 'Loc', '6']]],
                'vajcím'  => ['vejce', 'vajce', [['Plur', 'P', 'Dat', '3']]],
                'vajcoma' => ['vejce', 'vajce', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'vajcu'   => ['vejce', 'vajce', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'vajcú'   => ['vejce', 'vajce', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'vajec'   => ['vejce', 'vajce', [['Plur', 'P', 'Gen', '2']]],
                'zábradl'     => ['zábradlí', 'zábradlo', [['Plur', 'P', 'Gen', '2']]],
                'zábradla'    => ['zábradlí', 'zábradlo', [['Sing', 'S', 'Gen', '2'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5']]],
                'zábradlách'  => ['zábradlí', 'zábradlo', [['Plur', 'P', 'Loc', '6']]],
                'zábradlami'  => ['zábradlí', 'zábradlo', [['Plur', 'P', 'Ins', '7']]],
                'zábradle'    => ['zábradlí', 'zábradlo', [['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5']]],
                'zábradlě'    => ['zábradlí', 'zábradlo', [['Dual', 'D', 'Nom', '1'], ['Dual', 'D', 'Acc', '4'], ['Dual', 'D', 'Voc', '5']]],
                'zábradlech'  => ['zábradlí', 'zábradlo', [['Plur', 'P', 'Loc', '6']]],
                'zábradlem'   => ['zábradlí', 'zábradlo', [['Sing', 'S', 'Ins', '7']]],
                'zábradliech' => ['zábradlí', 'zábradlo', [['Plur', 'P', 'Loc', '6']]],
                'zábradlo'    => ['zábradlí', 'zábradlo', [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Acc', '4'], ['Sing', 'S', 'Voc', '5']]],
                'zábradlóm'   => ['zábradlí', 'zábradlo', [['Plur', 'P', 'Dat', '3']]],
                'zábradloma'  => ['zábradlí', 'zábradlo', [['Dual', 'D', 'Dat', '3'], ['Dual', 'D', 'Ins', '7']]],
                'zábradlu'    => ['zábradlí', 'zábradlo', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'zábradlú'    => ['zábradlí', 'zábradlo', [['Dual', 'D', 'Gen', '2'], ['Dual', 'D', 'Loc', '6']]],
                'zábradlům'   => ['zábradlí', 'zábradlo', [['Plur', 'P', 'Dat', '3']]],
                'zábradluom'  => ['zábradlí', 'zábradlo', [['Plur', 'P', 'Dat', '3']]],
                'zábradly'    => ['zábradlí', 'zábradlo', [['Plur', 'P', 'Ins', '7']]]
            );
            my $ma = $ma{$lform}; die("Something is wrong: '$lform'") if(!defined($ma));
            $f[2] = $ma->[0];
            $f[9] = set_lemma1300($f[9], $ma->[1]);
            $f[3] = 'NOUN';
            # U některých slov umožňujeme několik čtení, ale pokud to není žádné z nich, dáme první jako default.
            my @alt = @{$ma->[2]};
            for(my $i = $#alt; $i >= 0 ; $i--)
            {
                if($i == 0 || defined($alt[$i][4]) && get_ref($f[9]) =~ m/^$alt[$i][4]$/ || $f[5] =~ m/Case=$alt[$i][2].*Number=$alt[$i][0]/)
                {
                    $f[4] = 'NNN'.$alt[$i][1].$alt[$i][3].'-----A----';
                    $f[5] = 'Case='.$alt[$i][2].'|Gender=Neut|Number='.$alt[$i][0].'|Polarity=Pos';
                    last;
                }
            }
        }
        elsif($f[1] =~ m/^(Ka(?:f|ph)arnaum|Židovstv)(ie|í)?$/i)
        {
            my $lform = lc($f[1]);
            my %ma =
            (
                'kafarnaum'  => ['Kafarnaum', 'Kafarnaum',  [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4'], ['Sing', 'S', 'Voc', '5'], ['Sing', 'S', 'Loc', '6']]],
                'kapharnaum' => ['Kafarnaum', 'Kafarnaum',  [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4'], ['Sing', 'S', 'Voc', '5'], ['Sing', 'S', 'Loc', '6']]],
                'židovstvie' => ['Židovství', 'Židovstvie', [['Sing', 'S', 'Gen', '2']]], # v Drážďanské bibli používáno jako překlad názvu království Judea
                'židovství'  => ['Židovství', 'Židovstvie', [['Sing', 'S', 'Loc', '6']]]
            );
            my $ma = $ma{$lform}; die("Something is wrong: '$lform'") if(!defined($ma));
            $f[2] = $ma->[0];
            $f[9] = set_lemma1300($f[9], $ma->[1]);
            $f[3] = 'PROPN';
            # U některých slov umožňujeme několik čtení, ale pokud to není žádné z nich, dáme první jako default.
            my @alt = @{$ma->[2]};
            for(my $i = $#alt; $i >= 0 ; $i--)
            {
                if($i == 0 || defined($alt[$i][4]) && get_ref($f[9]) =~ m/^$alt[$i][4]$/ || $f[5] =~ m/Case=$alt[$i][2].*Number=$alt[$i][0]/)
                {
                    $f[4] = 'NNN'.$alt[$i][1].$alt[$i][3].'-----A----';
                    $f[5] = 'Case='.$alt[$i][2].'|Gender=Neut|NameType=Geo|Number='.$alt[$i][0].'|Polarity=Pos';
                    last;
                }
            }
        }
        # Substantiva středního rodu končící na -ie (novočesky -í).
        # U koncovky -ie musíme být opatrnější kvůli slovesům a požadovat, aby UDPipe odhadl, že jde o substantivum.
        # Výjimka z výjimky: o některých slovech víme, že jsou to substantiva, i když je UDPipe považuje za slovesa.
        elsif($f[1] =~ m/^(myšlenie|pohoršenie|pokánie|přikázanie|rozedřěnie|třěsenie|vzezřěnie|vzkříšenie)$/i || $f[1] =~ m/(stv|n|t)ie$/i && $f[3] =~ m/^(NOUN|PROPN)$/ && $f[1] !~ m/^(Aromatie|Betanie|činie|jinie|mnie|nynie|prvnie|příštie|pustie|trpie|třetie|žalostie)$/i)
        {
            my $lform = lc($f[1]);
            $f[2] = $lform;
            $f[2] =~ s/^(po)?rúhanie$/${1}rouhání/;
            $f[2] =~ s/^otpočívanie$/odpočívání/;
            $f[2] =~ s/^sbožie$/zboží/;
            $f[2] =~ s/^svědečstvie$/svědectví/;
            $f[2] =~ s/^uobíhánie$/ubíhání/;
            $f[2] =~ s/^úfanie$/doufání/;
            $f[2] =~ s/^ot/od/;
            $f[2] =~ s/ú/ou/g;
            $f[2] =~ s/ie$/í/;
            $f[2] = lemma_1300_to_2022($f[2]);
            $f[9] = set_lemma1300($f[9], $lform);
            $f[3] = 'NOUN' unless($f[3] =~ m/^(NOUN|PROPN)$/);
            # V singuláru (který je pravděpodobný) může jít o nominativ, genitiv, akuzativ nebo vokativ.
            # Pokud je uveden jiný pád, dáme nominativ.
            # V případě potřeby bychom asi taky mohli sáhnout po analýze ze Staročeské banky, tato substantiva ji často mají.
            my $case;
            my $c;
            if($f[5] =~ m/Case=([A-Z][a-z]+)/)
            {
                $case = $1;
            }
            if($case eq 'Acc')
            {
                $c = '4';
            }
            elsif($case eq 'Gen')
            {
                $c = '2';
            }
            elsif($case eq 'Voc')
            {
                $c = '5';
            }
            else
            {
                $case = 'Nom';
                $c = '1';
            }
            $f[4] = "NNNS${c}-----A----";
            $f[5] = "Case=$case|Gender=Neut|Number=Sing|Polarity=Pos";
        }
        # U koncovky -í bychom měli být opatrnější kvůli slovesům a požadovat, aby UDPipe odhadl, že jde o substantivum.
        elsif($f[1] =~ m/(stv|n|t)í$/i && $f[3] =~ m/^(NOUN|PROPN)$/ && $f[1] !~ m/^(Betaní|blahoslavení|bolestí|dětí|dní|kostí|radostí|smrtí|srstí|sukní|sviní|vlastí|vzvolení|žní)$/i)
        {
            my $lform = lc($f[1]);
            $f[2] = lemma_1300_to_2022($lform);
            my $lemma1300 = $lform;
            $lemma1300 =~ s/í$/ie/;
            $f[9] = set_lemma1300($f[9], $lemma1300);
            # V singuláru (který je pravděpodobný) může jít o dativ nebo lokativ.
            # Pokud je uveden jiný pád, dáme lokativ.
            # V případě potřeby bychom asi taky mohli sáhnout po analýze ze Staročeské banky, tato substantiva ji často mají.
            my $case;
            my $c;
            if($f[5] =~ m/Case=([A-Z][a-z]+)/)
            {
                $case = $1;
            }
            if($case eq 'Dat')
            {
                $c = '3';
            }
            else
            {
                $case = 'Loc';
                $c = '6';
            }
            $f[4] = "NNNS${c}-----A----";
            $f[5] = "Case=$case|Gender=Neut|Number=Sing|Polarity=Pos";
        }
        # U koncovky -ím bychom měli být opatrnější kvůli slovesům a požadovat, aby UDPipe odhadl, že jde o substantivum.
        elsif($f[1] =~ m/(stv|n|t)ím$/i && $f[3] =~ m/^(NOUN|PROPN)$/ && $f[1] !~ m/kloním$/i)
        {
            my $lform = lc($f[1]);
            $f[2] = lemma_1300_to_2022($lform);
            $f[2] =~ s/m$//;
            my $lemma1300 = $lform;
            $lemma1300 =~ s/ím$/ie/;
            $f[9] = set_lemma1300($f[9], $lemma1300);
            # V singuláru (který je pravděpodobný) může jít jen o instrumentál.
            # Pokud je uveden jiný pád, dáme instrumentál.
            # V případě potřeby bychom asi taky mohli sáhnout po analýze ze Staročeské banky, tato substantiva ji často mají.
            my $case = 'Ins';
            my $c = '7';
            $f[4] = "NNNS${c}-----A----";
            $f[5] = "Case=$case|Gender=Neut|Number=Sing|Polarity=Pos";
        }
        #----------------------------------------------------------------------
        # Adjektiva.
        #----------------------------------------------------------------------
        # "Neznám" se v našich datech vyskytuje pouze jako 1. osoba přítomného času slovesa.
        elsif($f[1] !~ m/^((ne)?znám|nic)$/i &&
              $f[1] =~ m/^(ne)?(biel|črn|d(?:ó|uo)stoje?n|hotov|lače?n|moce?n|náh|náměséče?n|nic|pln|podobe?n|posluše?n|povine?n|smute?n|vine?n|znám|žiez[ln]iv|ž[ií]v)(a|o|i|y)?$/i)
        {
            my $negprefix = lc($1);
            my $stem = lc($2);
            my $suffix = lc($3);
            if($negprefix && $stem =~ m/^moce?n$/)
            {
                $negprefix = '';
                $stem = 'ne'.$stem;
            }
            my ($polarity, $p) = negprefix_to_polarity($negprefix);
            my $lform = $stem.$suffix;
            my %ma =
            (
                # "Nemóžeš jediného vlasa učiniti biela nebo črna."
                'biel'  => ['bílý', 'bielý', [['Anim', 'M', 'Sing', 'S', 'Nom', '1'], ['Inan', 'I', 'Sing', 'S', 'Nom', '1'], ['Inan', 'I', 'Sing', 'S', 'Acc', '4']]],
                'biela' => ['bílý', 'bielý', [['Anim', 'M', 'Sing', 'S', 'Acc', '4'], ['Fem', 'F', 'Sing', 'S', 'Nom', '1'], ['Neut', 'N', 'Plur', 'P', 'Nom', '1'], ['Neut', 'N', 'Plur', 'P', 'Acc', '4']]],
                'bieli' => ['bílý', 'bielý', [['Anim', 'M', 'Plur', 'P', 'Nom', '1']]],
                'bielo' => ['bílý', 'bielý', [['Neut', 'N', 'Sing', 'S', 'Nom', '1'], ['Neut', 'N', 'Sing', 'S', 'Acc', '4']]],
                'bielu' => ['bílý', 'bielý', [['Fem', 'F', 'Sing', 'S', 'Acc', '4']]],
                'biely' => ['bílý', 'bielý', [['Anim', 'M', 'Plur', 'P', 'Acc', '4'], ['Inan', 'I', 'Plur', 'P', 'Nom', '1'], ['Inan', 'I', 'Plur', 'P', 'Acc', '4'], ['Fem', 'F', 'Plur', 'P', 'Nom', '1'], ['Fem', 'F', 'Plur', 'P', 'Acc', '4']]],
                'črn'  => ['černý', 'črný', [['Anim', 'M', 'Sing', 'S', 'Nom', '1'], ['Inan', 'I', 'Sing', 'S', 'Nom', '1'], ['Inan', 'I', 'Sing', 'S', 'Acc', '4']]],
                'črna' => ['černý', 'črný', [['Anim', 'M', 'Sing', 'S', 'Acc', '4'], ['Fem', 'F', 'Sing', 'S', 'Nom', '1'], ['Neut', 'N', 'Plur', 'P', 'Nom', '1'], ['Neut', 'N', 'Plur', 'P', 'Acc', '4']]],
                'črni' => ['černý', 'črný', [['Anim', 'M', 'Plur', 'P', 'Nom', '1']]],
                'črno' => ['černý', 'črný', [['Neut', 'N', 'Sing', 'S', 'Nom', '1'], ['Neut', 'N', 'Sing', 'S', 'Acc', '4']]],
                'črnu' => ['černý', 'črný', [['Fem', 'F', 'Sing', 'S', 'Acc', '4']]],
                'črny' => ['černý', 'črný', [['Anim', 'M', 'Plur', 'P', 'Acc', '4'], ['Inan', 'I', 'Plur', 'P', 'Nom', '1'], ['Inan', 'I', 'Plur', 'P', 'Acc', '4'], ['Fem', 'F', 'Plur', 'P', 'Nom', '1'], ['Fem', 'F', 'Plur', 'P', 'Acc', '4']]],
                'dóstojen'  => ['důstojný', 'dóstojný', [['Anim', 'M', 'Sing', 'S', 'Nom', '1'], ['Inan', 'I', 'Sing', 'S', 'Nom', '1'], ['Inan', 'I', 'Sing', 'S', 'Acc', '4']]],
                'dóstojna'  => ['důstojný', 'dóstojný', [['Anim', 'M', 'Sing', 'S', 'Acc', '4'], ['Fem', 'F', 'Sing', 'S', 'Nom', '1'], ['Neut', 'N', 'Plur', 'P', 'Nom', '1'], ['Neut', 'N', 'Plur', 'P', 'Acc', '4']]],
                'dóstojni'  => ['důstojný', 'dóstojný', [['Anim', 'M', 'Plur', 'P', 'Nom', '1']]],
                'dóstojno'  => ['důstojný', 'dóstojný', [['Neut', 'N', 'Sing', 'S', 'Nom', '1'], ['Neut', 'N', 'Sing', 'S', 'Acc', '4']]],
                'dóstojnu'  => ['důstojný', 'dóstojný', [['Fem', 'F', 'Sing', 'S', 'Acc', '4']]],
                'dóstojny'  => ['důstojný', 'dóstojný', [['Anim', 'M', 'Plur', 'P', 'Acc', '4'], ['Inan', 'I', 'Plur', 'P', 'Nom', '1'], ['Inan', 'I', 'Plur', 'P', 'Acc', '4'], ['Fem', 'F', 'Plur', 'P', 'Nom', '1'], ['Fem', 'F', 'Plur', 'P', 'Acc', '4']]],
                'duostojen' => ['důstojný', 'dóstojný', [['Anim', 'M', 'Sing', 'S', 'Nom', '1'], ['Inan', 'I', 'Sing', 'S', 'Nom', '1'], ['Inan', 'I', 'Sing', 'S', 'Acc', '4']]],
                'duostojna' => ['důstojný', 'dóstojný', [['Anim', 'M', 'Sing', 'S', 'Acc', '4'], ['Fem', 'F', 'Sing', 'S', 'Nom', '1'], ['Neut', 'N', 'Plur', 'P', 'Nom', '1'], ['Neut', 'N', 'Plur', 'P', 'Acc', '4']]],
                'duostojni' => ['důstojný', 'dóstojný', [['Anim', 'M', 'Plur', 'P', 'Nom', '1']]],
                'duostojno' => ['důstojný', 'dóstojný', [['Neut', 'N', 'Sing', 'S', 'Nom', '1'], ['Neut', 'N', 'Sing', 'S', 'Acc', '4']]],
                'duostojnu' => ['důstojný', 'dóstojný', [['Fem', 'F', 'Sing', 'S', 'Acc', '4']]],
                'duostojny' => ['důstojný', 'dóstojný', [['Anim', 'M', 'Plur', 'P', 'Acc', '4'], ['Inan', 'I', 'Plur', 'P', 'Nom', '1'], ['Inan', 'I', 'Plur', 'P', 'Acc', '4'], ['Fem', 'F', 'Plur', 'P', 'Nom', '1'], ['Fem', 'F', 'Plur', 'P', 'Acc', '4']]],
                'důstojen'  => ['důstojný', 'dóstojný', [['Anim', 'M', 'Sing', 'S', 'Nom', '1'], ['Inan', 'I', 'Sing', 'S', 'Nom', '1'], ['Inan', 'I', 'Sing', 'S', 'Acc', '4']]],
                'důstojna'  => ['důstojný', 'dóstojný', [['Anim', 'M', 'Sing', 'S', 'Acc', '4'], ['Fem', 'F', 'Sing', 'S', 'Nom', '1'], ['Neut', 'N', 'Plur', 'P', 'Nom', '1'], ['Neut', 'N', 'Plur', 'P', 'Acc', '4']]],
                'důstojni'  => ['důstojný', 'dóstojný', [['Anim', 'M', 'Plur', 'P', 'Nom', '1']]],
                'důstojno'  => ['důstojný', 'dóstojný', [['Neut', 'N', 'Sing', 'S', 'Nom', '1'], ['Neut', 'N', 'Sing', 'S', 'Acc', '4']]],
                'důstojnu'  => ['důstojný', 'dóstojný', [['Fem', 'F', 'Sing', 'S', 'Acc', '4']]],
                'důstojny'  => ['důstojný', 'dóstojný', [['Anim', 'M', 'Plur', 'P', 'Acc', '4'], ['Inan', 'I', 'Plur', 'P', 'Nom', '1'], ['Inan', 'I', 'Plur', 'P', 'Acc', '4'], ['Fem', 'F', 'Plur', 'P', 'Nom', '1'], ['Fem', 'F', 'Plur', 'P', 'Acc', '4']]],
                'hotov'  => ['hotový', 'hotový', [['Anim', 'M', 'Sing', 'S', 'Nom', '1'], ['Inan', 'I', 'Sing', 'S', 'Nom', '1'], ['Inan', 'I', 'Sing', 'S', 'Acc', '4']]],
                'hotova' => ['hotový', 'hotový', [['Anim', 'M', 'Sing', 'S', 'Acc', '4'], ['Fem', 'F', 'Sing', 'S', 'Nom', '1'], ['Neut', 'N', 'Plur', 'P', 'Nom', '1'], ['Neut', 'N', 'Plur', 'P', 'Acc', '4']]],
                'hotovi' => ['hotový', 'hotový', [['Anim', 'M', 'Plur', 'P', 'Nom', '1']]],
                'hotovo' => ['hotový', 'hotový', [['Neut', 'N', 'Sing', 'S', 'Nom', '1'], ['Neut', 'N', 'Sing', 'S', 'Acc', '4']]],
                'hotovu' => ['hotový', 'hotový', [['Fem', 'F', 'Sing', 'S', 'Acc', '4']]],
                'hotovy' => ['hotový', 'hotový', [['Anim', 'M', 'Plur', 'P', 'Acc', '4'], ['Inan', 'I', 'Plur', 'P', 'Nom', '1'], ['Inan', 'I', 'Plur', 'P', 'Acc', '4'], ['Fem', 'F', 'Plur', 'P', 'Nom', '1'], ['Fem', 'F', 'Plur', 'P', 'Acc', '4']]],
                'lačen' => ['lačný', 'lačný', [['Anim', 'M', 'Sing', 'S', 'Nom', '1'], ['Inan', 'I', 'Sing', 'S', 'Nom', '1'], ['Inan', 'I', 'Sing', 'S', 'Acc', '4']]],
                'lačna' => ['lačný', 'lačný', [['Anim', 'M', 'Sing', 'S', 'Acc', '4'], ['Fem', 'F', 'Sing', 'S', 'Nom', '1'], ['Neut', 'N', 'Plur', 'P', 'Nom', '1'], ['Neut', 'N', 'Plur', 'P', 'Acc', '4']]],
                'lačni' => ['lačný', 'lačný', [['Anim', 'M', 'Plur', 'P', 'Nom', '1']]],
                'lačno' => ['lačný', 'lačný', [['Neut', 'N', 'Sing', 'S', 'Nom', '1'], ['Neut', 'N', 'Sing', 'S', 'Acc', '4']]],
                'lačnu' => ['lačný', 'lačný', [['Fem', 'F', 'Sing', 'S', 'Acc', '4']]],
                'lačny' => ['lačný', 'lačný', [['Anim', 'M', 'Plur', 'P', 'Acc', '4'], ['Inan', 'I', 'Plur', 'P', 'Nom', '1'], ['Inan', 'I', 'Plur', 'P', 'Acc', '4'], ['Fem', 'F', 'Plur', 'P', 'Nom', '1'], ['Fem', 'F', 'Plur', 'P', 'Acc', '4']]],
                'mocen' => ['mocný', 'mocný', [['Anim', 'M', 'Sing', 'S', 'Nom', '1'], ['Inan', 'I', 'Sing', 'S', 'Nom', '1'], ['Inan', 'I', 'Sing', 'S', 'Acc', '4']]],
                'mocna' => ['mocný', 'mocný', [['Anim', 'M', 'Sing', 'S', 'Acc', '4'], ['Fem', 'F', 'Sing', 'S', 'Nom', '1'], ['Neut', 'N', 'Plur', 'P', 'Nom', '1'], ['Neut', 'N', 'Plur', 'P', 'Acc', '4']]],
                'mocni' => ['mocný', 'mocný', [['Anim', 'M', 'Plur', 'P', 'Nom', '1']]],
                'mocno' => ['mocný', 'mocný', [['Neut', 'N', 'Sing', 'S', 'Nom', '1'], ['Neut', 'N', 'Sing', 'S', 'Acc', '4']]],
                'mocnu' => ['mocný', 'mocný', [['Fem', 'F', 'Sing', 'S', 'Acc', '4']]],
                'mocny' => ['mocný', 'mocný', [['Anim', 'M', 'Plur', 'P', 'Acc', '4'], ['Inan', 'I', 'Plur', 'P', 'Nom', '1'], ['Inan', 'I', 'Plur', 'P', 'Acc', '4'], ['Fem', 'F', 'Plur', 'P', 'Nom', '1'], ['Fem', 'F', 'Plur', 'P', 'Acc', '4']]],
                'náh'  => ['nahý', 'nahý', [['Anim', 'M', 'Sing', 'S', 'Nom', '1'], ['Inan', 'I', 'Sing', 'S', 'Nom', '1'], ['Inan', 'I', 'Sing', 'S', 'Acc', '4']]],
                'náha' => ['nahý', 'nahý', [['Anim', 'M', 'Sing', 'S', 'Acc', '4'], ['Fem', 'F', 'Sing', 'S', 'Nom', '1'], ['Neut', 'N', 'Plur', 'P', 'Nom', '1'], ['Neut', 'N', 'Plur', 'P', 'Acc', '4']]],
                'náho' => ['nahý', 'nahý', [['Neut', 'N', 'Sing', 'S', 'Nom', '1'], ['Neut', 'N', 'Sing', 'S', 'Acc', '4']]],
                'náhu' => ['nahý', 'nahý', [['Fem', 'F', 'Sing', 'S', 'Acc', '4']]],
                'náhy' => ['nahý', 'nahý', [['Anim', 'M', 'Plur', 'P', 'Acc', '4'], ['Inan', 'I', 'Plur', 'P', 'Nom', '1'], ['Inan', 'I', 'Plur', 'P', 'Acc', '4'], ['Fem', 'F', 'Plur', 'P', 'Nom', '1'], ['Fem', 'F', 'Plur', 'P', 'Acc', '4']]],
                'názi' => ['nahý', 'nahý', [['Anim', 'M', 'Plur', 'P', 'Nom', '1']]],
                'náměséčen' => ['náměsíčný', 'náměsíčný', [['Anim', 'M', 'Sing', 'S', 'Nom', '1'], ['Inan', 'I', 'Sing', 'S', 'Nom', '1'], ['Inan', 'I', 'Sing', 'S', 'Acc', '4']]],
                'náměséčna' => ['náměsíčný', 'náměsíčný', [['Anim', 'M', 'Sing', 'S', 'Acc', '4'], ['Fem', 'F', 'Sing', 'S', 'Nom', '1'], ['Neut', 'N', 'Plur', 'P', 'Nom', '1'], ['Neut', 'N', 'Plur', 'P', 'Acc', '4']]],
                'náměséčni' => ['náměsíčný', 'náměsíčný', [['Anim', 'M', 'Plur', 'P', 'Nom', '1']]],
                'náměséčno' => ['náměsíčný', 'náměsíčný', [['Neut', 'N', 'Sing', 'S', 'Nom', '1'], ['Neut', 'N', 'Sing', 'S', 'Acc', '4']]],
                'náměséčnu' => ['náměsíčný', 'náměsíčný', [['Fem', 'F', 'Sing', 'S', 'Acc', '4']]],
                'náměséčny' => ['náměsíčný', 'náměsíčný', [['Anim', 'M', 'Plur', 'P', 'Acc', '4'], ['Inan', 'I', 'Plur', 'P', 'Nom', '1'], ['Inan', 'I', 'Plur', 'P', 'Acc', '4'], ['Fem', 'F', 'Plur', 'P', 'Nom', '1'], ['Fem', 'F', 'Plur', 'P', 'Acc', '4']]],
                'nemocen' => ['nemocný', 'nemocný', [['Anim', 'M', 'Sing', 'S', 'Nom', '1'], ['Inan', 'I', 'Sing', 'S', 'Nom', '1'], ['Inan', 'I', 'Sing', 'S', 'Acc', '4']]],
                'nemocna' => ['nemocný', 'nemocný', [['Anim', 'M', 'Sing', 'S', 'Acc', '4'], ['Fem', 'F', 'Sing', 'S', 'Nom', '1'], ['Neut', 'N', 'Plur', 'P', 'Nom', '1'], ['Neut', 'N', 'Plur', 'P', 'Acc', '4']]],
                'nemocni' => ['nemocný', 'nemocný', [['Anim', 'M', 'Plur', 'P', 'Nom', '1']]],
                'nemocno' => ['nemocný', 'nemocný', [['Neut', 'N', 'Sing', 'S', 'Nom', '1'], ['Neut', 'N', 'Sing', 'S', 'Acc', '4']]],
                'nemocnu' => ['nemocný', 'nemocný', [['Fem', 'F', 'Sing', 'S', 'Acc', '4']]],
                'nemocny' => ['nemocný', 'nemocný', [['Anim', 'M', 'Plur', 'P', 'Acc', '4'], ['Inan', 'I', 'Plur', 'P', 'Nom', '1'], ['Inan', 'I', 'Plur', 'P', 'Acc', '4'], ['Fem', 'F', 'Plur', 'P', 'Nom', '1'], ['Fem', 'F', 'Plur', 'P', 'Acc', '4']]],
                'nic'  => ['nicí', 'nicí', [['Anim', 'M', 'Sing', 'S', 'Nom', '1'], ['Inan', 'I', 'Sing', 'S', 'Nom', '1'], ['Inan', 'I', 'Sing', 'S', 'Acc', '4']]],
                'nica' => ['nicí', 'nicí', [['Anim', 'M', 'Sing', 'S', 'Acc', '4'], ['Fem', 'F', 'Sing', 'S', 'Nom', '1'], ['Neut', 'N', 'Plur', 'P', 'Nom', '1'], ['Neut', 'N', 'Plur', 'P', 'Acc', '4']]],
                'nici' => ['nicí', 'nicí', [['Anim', 'M', 'Plur', 'P', 'Nom', '1']]],
                'nico' => ['nicí', 'nicí', [['Neut', 'N', 'Sing', 'S', 'Nom', '1'], ['Neut', 'N', 'Sing', 'S', 'Acc', '4']]],
                'nicu' => ['nicí', 'nicí', [['Fem', 'F', 'Sing', 'S', 'Acc', '4']]],
                'nicy' => ['nicí', 'nicí', [['Anim', 'M', 'Plur', 'P', 'Acc', '4'], ['Inan', 'I', 'Plur', 'P', 'Nom', '1'], ['Inan', 'I', 'Plur', 'P', 'Acc', '4'], ['Fem', 'F', 'Plur', 'P', 'Nom', '1'], ['Fem', 'F', 'Plur', 'P', 'Acc', '4']]],
                'pln'  => ['plný', 'plný', [['Anim', 'M', 'Sing', 'S', 'Nom', '1'], ['Inan', 'I', 'Sing', 'S', 'Nom', '1'], ['Inan', 'I', 'Sing', 'S', 'Acc', '4']]],
                'plna' => ['plný', 'plný', [['Anim', 'M', 'Sing', 'S', 'Acc', '4'], ['Fem', 'F', 'Sing', 'S', 'Nom', '1'], ['Neut', 'N', 'Plur', 'P', 'Nom', '1'], ['Neut', 'N', 'Plur', 'P', 'Acc', '4']]],
                'plni' => ['plný', 'plný', [['Anim', 'M', 'Plur', 'P', 'Nom', '1']]],
                'plno' => ['plný', 'plný', [['Neut', 'N', 'Sing', 'S', 'Nom', '1'], ['Neut', 'N', 'Sing', 'S', 'Acc', '4']]],
                'plnu' => ['plný', 'plný', [['Fem', 'F', 'Sing', 'S', 'Acc', '4']]],
                'plny' => ['plný', 'plný', [['Anim', 'M', 'Plur', 'P', 'Acc', '4'], ['Inan', 'I', 'Plur', 'P', 'Nom', '1'], ['Inan', 'I', 'Plur', 'P', 'Acc', '4'], ['Fem', 'F', 'Plur', 'P', 'Nom', '1'], ['Fem', 'F', 'Plur', 'P', 'Acc', '4']]],
                'podoben' => ['podobný', 'podobný', [['Anim', 'M', 'Sing', 'S', 'Nom', '1'], ['Inan', 'I', 'Sing', 'S', 'Nom', '1'], ['Inan', 'I', 'Sing', 'S', 'Acc', '4']]],
                'podobna' => ['podobný', 'podobný', [['Anim', 'M', 'Sing', 'S', 'Acc', '4'], ['Fem', 'F', 'Sing', 'S', 'Nom', '1'], ['Neut', 'N', 'Plur', 'P', 'Nom', '1'], ['Neut', 'N', 'Plur', 'P', 'Acc', '4']]],
                'podobni' => ['podobný', 'podobný', [['Anim', 'M', 'Plur', 'P', 'Nom', '1']]],
                'podobno' => ['podobný', 'podobný', [['Neut', 'N', 'Sing', 'S', 'Nom', '1'], ['Neut', 'N', 'Sing', 'S', 'Acc', '4']]],
                'podobnu' => ['podobný', 'podobný', [['Fem', 'F', 'Sing', 'S', 'Acc', '4']]],
                'podobny' => ['podobný', 'podobný', [['Anim', 'M', 'Plur', 'P', 'Acc', '4'], ['Inan', 'I', 'Plur', 'P', 'Nom', '1'], ['Inan', 'I', 'Plur', 'P', 'Acc', '4'], ['Fem', 'F', 'Plur', 'P', 'Nom', '1'], ['Fem', 'F', 'Plur', 'P', 'Acc', '4']]],
                'poslušen' => ['poslušný', 'poslušný', [['Anim', 'M', 'Sing', 'S', 'Nom', '1'], ['Inan', 'I', 'Sing', 'S', 'Nom', '1'], ['Inan', 'I', 'Sing', 'S', 'Acc', '4']]],
                'poslušna' => ['poslušný', 'poslušný', [['Anim', 'M', 'Sing', 'S', 'Acc', '4'], ['Fem', 'F', 'Sing', 'S', 'Nom', '1'], ['Neut', 'N', 'Plur', 'P', 'Nom', '1'], ['Neut', 'N', 'Plur', 'P', 'Acc', '4']]],
                'poslušni' => ['poslušný', 'poslušný', [['Anim', 'M', 'Plur', 'P', 'Nom', '1']]],
                'poslušno' => ['poslušný', 'poslušný', [['Neut', 'N', 'Sing', 'S', 'Nom', '1'], ['Neut', 'N', 'Sing', 'S', 'Acc', '4']]],
                'poslušnu' => ['poslušný', 'poslušný', [['Fem', 'F', 'Sing', 'S', 'Acc', '4']]],
                'poslušny' => ['poslušný', 'poslušný', [['Anim', 'M', 'Plur', 'P', 'Acc', '4'], ['Inan', 'I', 'Plur', 'P', 'Nom', '1'], ['Inan', 'I', 'Plur', 'P', 'Acc', '4'], ['Fem', 'F', 'Plur', 'P', 'Nom', '1'], ['Fem', 'F', 'Plur', 'P', 'Acc', '4']]],
                'povinen' => ['povinný', 'povinný', [['Anim', 'M', 'Sing', 'S', 'Nom', '1'], ['Inan', 'I', 'Sing', 'S', 'Nom', '1'], ['Inan', 'I', 'Sing', 'S', 'Acc', '4']]],
                'povinna' => ['povinný', 'povinný', [['Anim', 'M', 'Sing', 'S', 'Acc', '4'], ['Fem', 'F', 'Sing', 'S', 'Nom', '1'], ['Neut', 'N', 'Plur', 'P', 'Nom', '1'], ['Neut', 'N', 'Plur', 'P', 'Acc', '4']]],
                'povinni' => ['povinný', 'povinný', [['Anim', 'M', 'Plur', 'P', 'Nom', '1']]],
                'povinno' => ['povinný', 'povinný', [['Neut', 'N', 'Sing', 'S', 'Nom', '1'], ['Neut', 'N', 'Sing', 'S', 'Acc', '4']]],
                'povinnu' => ['povinný', 'povinný', [['Fem', 'F', 'Sing', 'S', 'Acc', '4']]],
                'povinny' => ['povinný', 'povinný', [['Anim', 'M', 'Plur', 'P', 'Acc', '4'], ['Inan', 'I', 'Plur', 'P', 'Nom', '1'], ['Inan', 'I', 'Plur', 'P', 'Acc', '4'], ['Fem', 'F', 'Plur', 'P', 'Nom', '1'], ['Fem', 'F', 'Plur', 'P', 'Acc', '4']]],
                'smuten' => ['smutný', 'smutný', [['Anim', 'M', 'Sing', 'S', 'Nom', '1'], ['Inan', 'I', 'Sing', 'S', 'Nom', '1'], ['Inan', 'I', 'Sing', 'S', 'Acc', '4']]],
                'smutna' => ['smutný', 'smutný', [['Anim', 'M', 'Sing', 'S', 'Acc', '4'], ['Fem', 'F', 'Sing', 'S', 'Nom', '1'], ['Neut', 'N', 'Plur', 'P', 'Nom', '1'], ['Neut', 'N', 'Plur', 'P', 'Acc', '4']]],
                'smutni' => ['smutný', 'smutný', [['Anim', 'M', 'Plur', 'P', 'Nom', '1']]],
                'smutno' => ['smutný', 'smutný', [['Neut', 'N', 'Sing', 'S', 'Nom', '1'], ['Neut', 'N', 'Sing', 'S', 'Acc', '4']]],
                'smutnu' => ['smutný', 'smutný', [['Fem', 'F', 'Sing', 'S', 'Acc', '4']]],
                'smutny' => ['smutný', 'smutný', [['Anim', 'M', 'Plur', 'P', 'Acc', '4'], ['Inan', 'I', 'Plur', 'P', 'Nom', '1'], ['Inan', 'I', 'Plur', 'P', 'Acc', '4'], ['Fem', 'F', 'Plur', 'P', 'Nom', '1'], ['Fem', 'F', 'Plur', 'P', 'Acc', '4']]],
                'vinen' => ['vinný', 'vinný', [['Anim', 'M', 'Sing', 'S', 'Nom', '1'], ['Inan', 'I', 'Sing', 'S', 'Nom', '1'], ['Inan', 'I', 'Sing', 'S', 'Acc', '4']]],
                'vinna' => ['vinný', 'vinný', [['Anim', 'M', 'Sing', 'S', 'Acc', '4'], ['Fem', 'F', 'Sing', 'S', 'Nom', '1'], ['Neut', 'N', 'Plur', 'P', 'Nom', '1'], ['Neut', 'N', 'Plur', 'P', 'Acc', '4']]],
                'vinni' => ['vinný', 'vinný', [['Anim', 'M', 'Plur', 'P', 'Nom', '1']]],
                'vinno' => ['vinný', 'vinný', [['Neut', 'N', 'Sing', 'S', 'Nom', '1'], ['Neut', 'N', 'Sing', 'S', 'Acc', '4']]],
                'vinnu' => ['vinný', 'vinný', [['Fem', 'F', 'Sing', 'S', 'Acc', '4']]],
                'vinny' => ['vinný', 'vinný', [['Anim', 'M', 'Plur', 'P', 'Acc', '4'], ['Inan', 'I', 'Plur', 'P', 'Nom', '1'], ['Inan', 'I', 'Plur', 'P', 'Acc', '4'], ['Fem', 'F', 'Plur', 'P', 'Nom', '1'], ['Fem', 'F', 'Plur', 'P', 'Acc', '4']]],
                'znám'  => ['známý', 'známý', [['Anim', 'M', 'Sing', 'S', 'Nom', '1'], ['Inan', 'I', 'Sing', 'S', 'Nom', '1'], ['Inan', 'I', 'Sing', 'S', 'Acc', '4']]],
                'známa' => ['známý', 'známý', [['Anim', 'M', 'Sing', 'S', 'Acc', '4'], ['Fem', 'F', 'Sing', 'S', 'Nom', '1'], ['Neut', 'N', 'Plur', 'P', 'Nom', '1'], ['Neut', 'N', 'Plur', 'P', 'Acc', '4']]],
                'známi' => ['známý', 'známý', [['Anim', 'M', 'Plur', 'P', 'Nom', '1']]],
                'známo' => ['známý', 'známý', [['Neut', 'N', 'Sing', 'S', 'Nom', '1'], ['Neut', 'N', 'Sing', 'S', 'Acc', '4']]],
                'známu' => ['známý', 'známý', [['Fem', 'F', 'Sing', 'S', 'Acc', '4']]],
                'známy' => ['známý', 'známý', [['Anim', 'M', 'Plur', 'P', 'Acc', '4'], ['Inan', 'I', 'Plur', 'P', 'Nom', '1'], ['Inan', 'I', 'Plur', 'P', 'Acc', '4'], ['Fem', 'F', 'Plur', 'P', 'Nom', '1'], ['Fem', 'F', 'Plur', 'P', 'Acc', '4']]],
                'žiezliv'  => ['žíznivý', 'žieznivý', [['Anim', 'M', 'Sing', 'S', 'Nom', '1'], ['Inan', 'I', 'Sing', 'S', 'Nom', '1'], ['Inan', 'I', 'Sing', 'S', 'Acc', '4']]],
                'žiezliva' => ['žíznivý', 'žieznivý', [['Anim', 'M', 'Sing', 'S', 'Acc', '4'], ['Fem', 'F', 'Sing', 'S', 'Nom', '1'], ['Neut', 'N', 'Plur', 'P', 'Nom', '1'], ['Neut', 'N', 'Plur', 'P', 'Acc', '4']]],
                'žiezlivi' => ['žíznivý', 'žieznivý', [['Anim', 'M', 'Plur', 'P', 'Nom', '1']]],
                'žiezlivo' => ['žíznivý', 'žieznivý', [['Neut', 'N', 'Sing', 'S', 'Nom', '1'], ['Neut', 'N', 'Sing', 'S', 'Acc', '4']]],
                'žiezlivu' => ['žíznivý', 'žieznivý', [['Fem', 'F', 'Sing', 'S', 'Acc', '4']]],
                'žiezlivy' => ['žíznivý', 'žieznivý', [['Anim', 'M', 'Plur', 'P', 'Acc', '4'], ['Inan', 'I', 'Plur', 'P', 'Nom', '1'], ['Inan', 'I', 'Plur', 'P', 'Acc', '4'], ['Fem', 'F', 'Plur', 'P', 'Nom', '1'], ['Fem', 'F', 'Plur', 'P', 'Acc', '4']]],
                'žiezniv'  => ['žíznivý', 'žieznivý', [['Anim', 'M', 'Sing', 'S', 'Nom', '1'], ['Inan', 'I', 'Sing', 'S', 'Nom', '1'], ['Inan', 'I', 'Sing', 'S', 'Acc', '4']]],
                'žiezniva' => ['žíznivý', 'žieznivý', [['Anim', 'M', 'Sing', 'S', 'Acc', '4'], ['Fem', 'F', 'Sing', 'S', 'Nom', '1'], ['Neut', 'N', 'Plur', 'P', 'Nom', '1'], ['Neut', 'N', 'Plur', 'P', 'Acc', '4']]],
                'žieznivi' => ['žíznivý', 'žieznivý', [['Anim', 'M', 'Plur', 'P', 'Nom', '1']]],
                'žieznivo' => ['žíznivý', 'žieznivý', [['Neut', 'N', 'Sing', 'S', 'Nom', '1'], ['Neut', 'N', 'Sing', 'S', 'Acc', '4']]],
                'žieznivu' => ['žíznivý', 'žieznivý', [['Fem', 'F', 'Sing', 'S', 'Acc', '4']]],
                'žieznivy' => ['žíznivý', 'žieznivý', [['Anim', 'M', 'Plur', 'P', 'Acc', '4'], ['Inan', 'I', 'Plur', 'P', 'Nom', '1'], ['Inan', 'I', 'Plur', 'P', 'Acc', '4'], ['Fem', 'F', 'Plur', 'P', 'Nom', '1'], ['Fem', 'F', 'Plur', 'P', 'Acc', '4']]],
                'živ'  => ['živý', 'živý', [['Anim', 'M', 'Sing', 'S', 'Nom', '1'], ['Inan', 'I', 'Sing', 'S', 'Nom', '1'], ['Inan', 'I', 'Sing', 'S', 'Acc', '4']]],
                'žív'  => ['živý', 'živý', [['Anim', 'M', 'Sing', 'S', 'Nom', '1'], ['Inan', 'I', 'Sing', 'S', 'Nom', '1'], ['Inan', 'I', 'Sing', 'S', 'Acc', '4']]],
                'živa' => ['živý', 'živý', [['Anim', 'M', 'Sing', 'S', 'Acc', '4'], ['Fem', 'F', 'Sing', 'S', 'Nom', '1'], ['Neut', 'N', 'Plur', 'P', 'Nom', '1'], ['Neut', 'N', 'Plur', 'P', 'Acc', '4']]],
                'žíva' => ['živý', 'živý', [['Anim', 'M', 'Sing', 'S', 'Acc', '4'], ['Fem', 'F', 'Sing', 'S', 'Nom', '1'], ['Neut', 'N', 'Plur', 'P', 'Nom', '1'], ['Neut', 'N', 'Plur', 'P', 'Acc', '4']]],
                'živi' => ['živý', 'živý', [['Anim', 'M', 'Plur', 'P', 'Nom', '1']]],
                'žívi' => ['živý', 'živý', [['Anim', 'M', 'Plur', 'P', 'Nom', '1']]],
                'živo' => ['živý', 'živý', [['Neut', 'N', 'Sing', 'S', 'Nom', '1'], ['Neut', 'N', 'Sing', 'S', 'Acc', '4']]],
                'žívo' => ['živý', 'živý', [['Neut', 'N', 'Sing', 'S', 'Nom', '1'], ['Neut', 'N', 'Sing', 'S', 'Acc', '4']]],
                'živu' => ['živý', 'živý', [['Fem', 'F', 'Sing', 'S', 'Acc', '4']]],
                'žívu' => ['živý', 'živý', [['Fem', 'F', 'Sing', 'S', 'Acc', '4']]],
                'živy' => ['živý', 'živý', [['Anim', 'M', 'Plur', 'P', 'Acc', '4'], ['Inan', 'I', 'Plur', 'P', 'Nom', '1'], ['Inan', 'I', 'Plur', 'P', 'Acc', '4'], ['Fem', 'F', 'Plur', 'P', 'Nom', '1'], ['Fem', 'F', 'Plur', 'P', 'Acc', '4']]],
                'žívy' => ['živý', 'živý', [['Anim', 'M', 'Plur', 'P', 'Acc', '4'], ['Inan', 'I', 'Plur', 'P', 'Nom', '1'], ['Inan', 'I', 'Plur', 'P', 'Acc', '4'], ['Fem', 'F', 'Plur', 'P', 'Nom', '1'], ['Fem', 'F', 'Plur', 'P', 'Acc', '4']]]
            );
            my $ma = $ma{$lform}; die("Something is wrong: '$lform'") if(!defined($ma));
            $f[2] = $ma->[0];
            $f[9] = set_lemma1300($f[9], $ma->[1]);
            $f[3] = 'ADJ';
            # U některých slov umožňujeme několik čtení, ale pokud to není žádné z nich, dáme první jako default.
            my @alt = @{$ma->[2]};
            for(my $i = $#alt; $i >= 0 ; $i--)
            {
                my $animacy = $alt[$i][0] =~ m/^(Anim|Inan)$/ ? $alt[$i][0] : undef;
                my $gender = $alt[$i][0] =~ m/^(Anim|Inan)$/ ? 'Masc' : $alt[$i][0];
                my $number = $alt[$i][2];
                my $case = $alt[$i][4];
                if($i == 0 || defined($alt[$i][6]) && get_ref($f[9]) =~ m/^$alt[$i][6]$/ || !defined($alt[$i][6]) && $f[5] =~ m/Case=$case.*Gender=$gender.*Number=$number/)
                {
                    $f[4] = 'AC'.$alt[$i][1].$alt[$i][3].$alt[$i][5]."-----${p}----";
                    $f[5] = "Case=$case|Gender=$gender|Number=$number|Polarity=$polarity|Variant=Short";
                    $f[5] = "Animacy=$animacy|$f[5]" if(defined($animacy));
                    last;
                }
            }
        }
        # Krátké tvary trpných příčestí jsou v UD také řazeny pod adjektiva, nikoli pod slovesa.
        elsif($f[1] =~ m/^(ne)?(křtěn|pokřtěn)(a|o|i|y)?$/i)
        {
            my $negprefix = lc($1);
            my $stem = lc($2);
            my $suffix = lc($3);
            my ($polarity, $p) = negprefix_to_polarity($negprefix);
            my $aspect = $stem =~ m/^pokřtěn$/ ? 'Perf' : 'Imp';
            my $lform = $stem.$suffix;
            my %ma =
            (
                'křtěn'   => ['křtěný',   'křstěný',   [['Anim', 'M', 'Sing', 'S', 'Nom', '1']]],
                'pokřtěn' => ['pokřtěný', 'pokřstěný', [['Anim', 'M', 'Sing', 'S', 'Nom', '1']]]
            );
            my $ma = $ma{$lform}; die("Something is wrong: '$lform'") if(!defined($ma));
            $f[2] = $ma->[0];
            $f[9] = set_lemma1300($f[9], $ma->[1]);
            $f[3] = 'ADJ';
            # U některých slov umožňujeme několik čtení, ale pokud to není žádné z nich, dáme první jako default.
            my @alt = @{$ma->[2]};
            for(my $i = $#alt; $i >= 0 ; $i--)
            {
                my $animacy = $alt[$i][0] =~ m/^(Anim|Inan)$/ ? $alt[$i][0] : undef;
                my $gender = $alt[$i][0] =~ m/^(Anim|Inan)$/ ? 'Masc' : $alt[$i][0];
                my $number = $alt[$i][2];
                my $case = $alt[$i][4];
                if($i == 0 || defined($alt[$i][6]) && get_ref($f[9]) =~ m/^$alt[$i][6]$/ || !defined($alt[$i][6]) && $f[5] =~ m/Case=$case.*Gender=$gender.*Number=$number/)
                {
                    $f[4] = 'Vs'.$alt[$i][1].$alt[$i][3].$alt[$i][5]."--XX-${p}P---";
                    $f[5] = "Aspect=$aspect|Case=$case|Gender=$gender|Number=$number|Polarity=$polarity|Variant=Short|VerbForm=Part|Voice=Pass";
                    $f[5] = "Animacy=$animacy|$f[5]" if(defined($animacy));
                    last;
                }
            }
        }
        # Krátké tvary trpných příčestí končící na -a jsou většinou Fem Sing, ale je tam pár výjimek.
        # Navíc musíme vyloučit spoustu tvarů, které se pletou s příčestím trpným, ale nejsou jím (aoristy, duály, přechodníky).
        elsif($f[1] =~ m/[nt]a$/i && $f[3] =~ m/^(ADJ|VERB)$/ && $f[5] =~ m/Gender=Fem,Neut\|Number=Plur,Sing/ && $f[1] !~ m/^(.+[sš]ta|budeta|nalezneta|osta|plna|počna|povolíta|sta|upadáta|upadneta|utna|věříta)$/i ||
              $f[1] =~ m/^otdána$/i) # otdána je podle UDPipu NOUN
        {
            $f[2] = lc($f[1]);
            $f[2] =~ s/ána$/aný/;
            $f[2] =~ s/([eě])na$/${1}ný/;
            $f[2] =~ s/ta$/tý/;
            $f[2] = lemma_1300_to_2022($f[2]);
            $f[3] = 'ADJ';
            # Masc Sing Acc: Dr. 14.30: Petr vzvola a řka: Hospodine, učiň mě spasena!; Dr. 27.2: svázána přivedechu jeho
            if(get_ref($f[9]) =~ m/^MATT_(14\.30|27\.2)$/)
            {
                $f[4] = 'VsMS4--XX-AP---';
                $f[5] = 'Animacy=Anim|Aspect=Perf|Case=Acc|Gender=Masc|Number=Sing|Polarity=Pos|Variant=Short|VerbForm=Part|Voice=Pass';
            }
            # Neut Plur: Ol. 25.10: zavřěna běchu vrata
            elsif(get_ref($f[9]) =~ m/^MATT_25\.10$/)
            {
                $f[4] = 'VsNP1--XX-AP---';
                $f[5] = 'Aspect=Perf|Case=Nom|Gender=Neut|Number=Plur|Polarity=Pos|Variant=Short|VerbForm=Part|Voice=Pass';
            }
            # Masc Dual: Dr. i Ol. 27.38, 27.44: biešta s ním dva lotry ukřižována
            elsif(get_ref($f[9]) =~ m/^MATT_27\.(38|44)$/)
            {
                $f[4] = 'VsMD1--XX-AP---';
                $f[5] = 'Animacy=Anim|Aspect=Perf|Case=Nom|Gender=Masc|Number=Dual|Polarity=Pos|Variant=Short|VerbForm=Part|Voice=Pass';
            }
            # Všechno ostatní je Fem Sing. Vid neznáme, ale odhaduju, že převážně bude dokonavý.
            else
            {
                $f[4] = 'VsFS1--XX-AP---';
                $f[5] = 'Aspect=Perf|Case=Nom|Gender=Fem|Number=Sing|Polarity=Pos|Variant=Short|VerbForm=Part|Voice=Pass';
            }
        }
        # 'popové' není plurál od substantiva 'pop'. Je to adjektivum ve spojení 'kniežě popové' ('velekněz').
        # Měli bychom zavést samostatnou kategorii trpných příčestí dlouhých a "propuščenú" přestěhovat tam.
        elsif($f[1] =~ m/^(dobreh|d(?:ó|uo)stojn|jin|lesk|lidsk|nebe(?:sk|št)|neptalimov(?:sk)?|ohněv|popov|propuščen|smrtedln|velik|vysok|židov(?:sk|št)?)(ý|á|é|ého|ém|ým|ú|éj|ie|í|ých|ými)$/i && $f[1] !~ m/^(židového)$/i)
        {
            my $lform = lc($f[1]);
            my %ma =
            (
                'dobrá'     => ['dobrý', 'dobrý', [['Fem', 'F', 'Sing', 'S', 'Nom', '1'], ['Fem', 'F', 'Sing', 'S', 'Voc', '5'], ['Neut', 'N', 'Plur', 'P', 'Nom', '1'], ['Neut', 'N', 'Plur', 'P', 'Acc', '4'], ['Neut', 'N', 'Plur', 'P', 'Voc', '5']]],
                'dobré'     => ['dobrý', 'dobrý', [['Anim', 'M', 'Plur', 'P', 'Acc', '4'], ['Inan', 'I', 'Plur', 'P', 'Nom', '1'], ['Inan', 'I', 'Plur', 'P', 'Acc', '4'], ['Inan', 'I', 'Plur', 'P', 'Voc', '5'], ['Fem', 'F', 'Sing', 'S', 'Gen', '2'], ['Fem', 'F', 'Sing', 'S', 'Dat', '3'], ['Fem', 'F', 'Sing', 'S', 'Loc', '6'], ['Fem', 'F', 'Plur', 'P', 'Nom', '1'], ['Fem', 'F', 'Plur', 'P', 'Acc', '4'], ['Fem', 'F', 'Plur', 'P', 'Voc', '5'], ['Neut', 'N', 'Sing', 'S', 'Nom', '1'], ['Neut', 'N', 'Sing', 'S', 'Acc', '4'], ['Neut', 'N', 'Sing', 'S', 'Voc', '5']]],
                'dobrehá'   => ['dobrý', 'dobrý', [['Fem', 'F', 'Sing', 'S', 'Nom', '1'], ['Fem', 'F', 'Sing', 'S', 'Voc', '5'], ['Neut', 'N', 'Plur', 'P', 'Nom', '1'], ['Neut', 'N', 'Plur', 'P', 'Acc', '4'], ['Neut', 'N', 'Plur', 'P', 'Voc', '5']]],
                'dobrehé'   => ['dobrý', 'dobrý', [['Anim', 'M', 'Plur', 'P', 'Acc', '4'], ['Inan', 'I', 'Plur', 'P', 'Nom', '1'], ['Inan', 'I', 'Plur', 'P', 'Acc', '4'], ['Inan', 'I', 'Plur', 'P', 'Voc', '5'], ['Fem', 'F', 'Sing', 'S', 'Gen', '2'], ['Fem', 'F', 'Sing', 'S', 'Dat', '3'], ['Fem', 'F', 'Sing', 'S', 'Loc', '6'], ['Fem', 'F', 'Plur', 'P', 'Nom', '1'], ['Fem', 'F', 'Plur', 'P', 'Acc', '4'], ['Fem', 'F', 'Plur', 'P', 'Voc', '5'], ['Neut', 'N', 'Sing', 'S', 'Nom', '1'], ['Neut', 'N', 'Sing', 'S', 'Acc', '4'], ['Neut', 'N', 'Sing', 'S', 'Voc', '5']]],
                'dobrehého' => ['dobrý', 'dobrý', [['Anim', 'M', 'Sing', 'S', 'Gen', '2'], ['Anim', 'M', 'Sing', 'S', 'Acc', '4'], ['Inan', 'I', 'Sing', 'S', 'Gen', '2'], ['Neut', 'N', 'Sing', 'S', 'Gen', '2']]],
                'dobrehéj'  => ['dobrý', 'dobrý', [['Fem', 'F', 'Sing', 'S', 'Gen', '2'], ['Fem', 'F', 'Sing', 'S', 'Dat', '3'], ['Fem', 'F', 'Sing', 'S', 'Loc', '6']]],
                'dobrehém'  => ['dobrý', 'dobrý', [['Anim', 'M', 'Sing', 'S', 'Loc', '6'], ['Inan', 'I', 'Sing', 'S', 'Loc', '6'], ['Neut', 'N', 'Sing', 'S', 'Loc', '6']]],
                'dobrehému' => ['dobrý', 'dobrý', [['Anim', 'M', 'Sing', 'S', 'Dat', '3'], ['Inan', 'I', 'Sing', 'S', 'Dat', '3'], ['Neut', 'N', 'Sing', 'S', 'Dat', '3']]],
                'dobrého'   => ['dobrý', 'dobrý', [['Anim', 'M', 'Sing', 'S', 'Gen', '2'], ['Anim', 'M', 'Sing', 'S', 'Acc', '4'], ['Inan', 'I', 'Sing', 'S', 'Gen', '2'], ['Neut', 'N', 'Sing', 'S', 'Gen', '2']]],
                'dobrehou'  => ['dobrý', 'dobrý', [['Fem', 'F', 'Sing', 'S', 'Acc', '4'], ['Fem', 'F', 'Sing', 'S', 'Ins', '7']]],
                'dobrehú'   => ['dobrý', 'dobrý', [['Fem', 'F', 'Sing', 'S', 'Acc', '4'], ['Fem', 'F', 'Sing', 'S', 'Ins', '7']]],
                'dobrehý'   => ['dobrý', 'dobrý', [['Anim', 'M', 'Sing', 'S', 'Nom', '1'], ['Anim', 'M', 'Sing', 'S', 'Voc', '5'], ['Inan', 'I', 'Sing', 'S', 'Nom', '1'], ['Inan', 'I', 'Sing', 'S', 'Acc', '4'], ['Inan', 'I', 'Sing', 'S', 'Voc', '5']]],
                'dobrehých' => ['dobrý', 'dobrý', [['Anim', 'M', 'Plur', 'P', 'Gen', '2'], ['Anim', 'M', 'Plur', 'P', 'Loc', '6'], ['Inan', 'I', 'Plur', 'P', 'Gen', '2'], ['Inan', 'I', 'Plur', 'P', 'Loc', '6'], ['Fem', 'F', 'Plur', 'P', 'Gen', '2'], ['Fem', 'F', 'Plur', 'P', 'Loc', '6'], ['Neut', 'N', 'Plur', 'P', 'Gen', '2'], ['Neut', 'N', 'Plur', 'P', 'Loc', '6']]],
                'dobrehým'  => ['dobrý', 'dobrý', [['Anim', 'M', 'Sing', 'S', 'Ins', '7'], ['Anim', 'M', 'Plur', 'P', 'Dat', '3'], ['Inan', 'I', 'Sing', 'S', 'Ins', '7'], ['Inan', 'I', 'Plur', 'P', 'Dat', '3'], ['Fem', 'F', 'Plur', 'P', 'Dat', '3'], ['Neut', 'N', 'Sing', 'S', 'Ins', '7'], ['Neut', 'N', 'Plur', 'P', 'Dat', '3']]],
                'dobrehými' => ['dobrý', 'dobrý', [['Anim', 'M', 'Plur', 'P', 'Ins', '7'], ['Inan', 'I', 'Plur', 'P', 'Ins', '7'], ['Fem', 'F', 'Plur', 'P', 'Ins', '7'], ['Neut', 'N', 'Plur', 'P', 'Ins', '7']]],
                'dobréj'    => ['dobrý', 'dobrý', [['Fem', 'F', 'Sing', 'S', 'Gen', '2'], ['Fem', 'F', 'Sing', 'S', 'Dat', '3'], ['Fem', 'F', 'Sing', 'S', 'Loc', '6']]],
                'dobrém'    => ['dobrý', 'dobrý', [['Anim', 'M', 'Sing', 'S', 'Loc', '6'], ['Inan', 'I', 'Sing', 'S', 'Loc', '6'], ['Neut', 'N', 'Sing', 'S', 'Loc', '6']]],
                'dobrému'   => ['dobrý', 'dobrý', [['Anim', 'M', 'Sing', 'S', 'Dat', '3'], ['Inan', 'I', 'Sing', 'S', 'Dat', '3'], ['Neut', 'N', 'Sing', 'S', 'Dat', '3']]],
                'dobrezí'   => ['dobrý', 'dobrý', [['Anim', 'M', 'Plur', 'P', 'Nom', '1'], ['Anim', 'M', 'Plur', 'P', 'Voc', '5']]],
                'dobrou'    => ['dobrý', 'dobrý', [['Fem', 'F', 'Sing', 'S', 'Acc', '4'], ['Fem', 'F', 'Sing', 'S', 'Ins', '7']]],
                'dobrú'     => ['dobrý', 'dobrý', [['Fem', 'F', 'Sing', 'S', 'Acc', '4'], ['Fem', 'F', 'Sing', 'S', 'Ins', '7']]],
                'dobrý'     => ['dobrý', 'dobrý', [['Anim', 'M', 'Sing', 'S', 'Nom', '1'], ['Anim', 'M', 'Sing', 'S', 'Voc', '5'], ['Inan', 'I', 'Sing', 'S', 'Nom', '1'], ['Inan', 'I', 'Sing', 'S', 'Acc', '4'], ['Inan', 'I', 'Sing', 'S', 'Voc', '5']]],
                'dobrých'   => ['dobrý', 'dobrý', [['Anim', 'M', 'Plur', 'P', 'Gen', '2'], ['Anim', 'M', 'Plur', 'P', 'Loc', '6'], ['Inan', 'I', 'Plur', 'P', 'Gen', '2'], ['Inan', 'I', 'Plur', 'P', 'Loc', '6'], ['Fem', 'F', 'Plur', 'P', 'Gen', '2'], ['Fem', 'F', 'Plur', 'P', 'Loc', '6'], ['Neut', 'N', 'Plur', 'P', 'Gen', '2'], ['Neut', 'N', 'Plur', 'P', 'Loc', '6']]],
                'dobrým'    => ['dobrý', 'dobrý', [['Anim', 'M', 'Sing', 'S', 'Ins', '7'], ['Anim', 'M', 'Plur', 'P', 'Dat', '3'], ['Inan', 'I', 'Sing', 'S', 'Ins', '7'], ['Inan', 'I', 'Plur', 'P', 'Dat', '3'], ['Fem', 'F', 'Plur', 'P', 'Dat', '3'], ['Neut', 'N', 'Sing', 'S', 'Ins', '7'], ['Neut', 'N', 'Plur', 'P', 'Dat', '3']]],
                'dobrými'   => ['dobrý', 'dobrý', [['Anim', 'M', 'Plur', 'P', 'Ins', '7'], ['Inan', 'I', 'Plur', 'P', 'Ins', '7'], ['Fem', 'F', 'Plur', 'P', 'Ins', '7'], ['Neut', 'N', 'Plur', 'P', 'Ins', '7']]],
                'dobří'     => ['dobrý', 'dobrý', [['Anim', 'M', 'Plur', 'P', 'Nom', '1'], ['Anim', 'M', 'Plur', 'P', 'Voc', '5']]],
                'dóstojná'    => ['důstojný', 'dóstojný', [['Fem', 'F', 'Sing', 'S', 'Nom', '1'], ['Fem', 'F', 'Sing', 'S', 'Voc', '5'], ['Neut', 'N', 'Plur', 'P', 'Nom', '1'], ['Neut', 'N', 'Plur', 'P', 'Acc', '4'], ['Neut', 'N', 'Plur', 'P', 'Voc', '5']]],
                'dóstojné'    => ['důstojný', 'dóstojný', [['Anim', 'M', 'Plur', 'P', 'Acc', '4'], ['Inan', 'I', 'Plur', 'P', 'Nom', '1'], ['Inan', 'I', 'Plur', 'P', 'Acc', '4'], ['Inan', 'I', 'Plur', 'P', 'Voc', '5'], ['Fem', 'F', 'Sing', 'S', 'Gen', '2'], ['Fem', 'F', 'Sing', 'S', 'Dat', '3'], ['Fem', 'F', 'Sing', 'S', 'Loc', '6'], ['Fem', 'F', 'Plur', 'P', 'Nom', '1'], ['Fem', 'F', 'Plur', 'P', 'Acc', '4'], ['Fem', 'F', 'Plur', 'P', 'Voc', '5'], ['Neut', 'N', 'Sing', 'S', 'Nom', '1'], ['Neut', 'N', 'Sing', 'S', 'Acc', '4'], ['Neut', 'N', 'Sing', 'S', 'Voc', '5']]],
                'dóstojného'  => ['důstojný', 'dóstojný', [['Anim', 'M', 'Sing', 'S', 'Gen', '2'], ['Anim', 'M', 'Sing', 'S', 'Acc', '4'], ['Inan', 'I', 'Sing', 'S', 'Gen', '2'], ['Neut', 'N', 'Sing', 'S', 'Gen', '2']]],
                'dóstojnéj'   => ['důstojný', 'dóstojný', [['Fem', 'F', 'Sing', 'S', 'Gen', '2'], ['Fem', 'F', 'Sing', 'S', 'Dat', '3'], ['Fem', 'F', 'Sing', 'S', 'Loc', '6']]],
                'dóstojném'   => ['důstojný', 'dóstojný', [['Anim', 'M', 'Sing', 'S', 'Loc', '6'], ['Inan', 'I', 'Sing', 'S', 'Loc', '6'], ['Neut', 'N', 'Sing', 'S', 'Loc', '6']]],
                'dóstojnému'  => ['důstojný', 'dóstojný', [['Anim', 'M', 'Sing', 'S', 'Dat', '3'], ['Inan', 'I', 'Sing', 'S', 'Dat', '3'], ['Neut', 'N', 'Sing', 'S', 'Dat', '3']]],
                'dóstojní'    => ['důstojný', 'dóstojný', [['Anim', 'M', 'Plur', 'P', 'Nom', '1'], ['Anim', 'M', 'Plur', 'P', 'Voc', '5']]],
                'dóstojnou'   => ['důstojný', 'dóstojný', [['Fem', 'F', 'Sing', 'S', 'Acc', '4'], ['Fem', 'F', 'Sing', 'S', 'Ins', '7']]],
                'dóstojnú'    => ['důstojný', 'dóstojný', [['Fem', 'F', 'Sing', 'S', 'Acc', '4'], ['Fem', 'F', 'Sing', 'S', 'Ins', '7']]],
                'dóstojný'    => ['důstojný', 'dóstojný', [['Anim', 'M', 'Sing', 'S', 'Nom', '1'], ['Anim', 'M', 'Sing', 'S', 'Voc', '5'], ['Inan', 'I', 'Sing', 'S', 'Nom', '1'], ['Inan', 'I', 'Sing', 'S', 'Acc', '4'], ['Inan', 'I', 'Sing', 'S', 'Voc', '5']]],
                'dóstojných'  => ['důstojný', 'dóstojný', [['Anim', 'M', 'Plur', 'P', 'Gen', '2'], ['Anim', 'M', 'Plur', 'P', 'Loc', '6'], ['Inan', 'I', 'Plur', 'P', 'Gen', '2'], ['Inan', 'I', 'Plur', 'P', 'Loc', '6'], ['Fem', 'F', 'Plur', 'P', 'Gen', '2'], ['Fem', 'F', 'Plur', 'P', 'Loc', '6'], ['Neut', 'N', 'Plur', 'P', 'Gen', '2'], ['Neut', 'N', 'Plur', 'P', 'Loc', '6']]],
                'dóstojným'   => ['důstojný', 'dóstojný', [['Anim', 'M', 'Sing', 'S', 'Ins', '7'], ['Anim', 'M', 'Plur', 'P', 'Dat', '3'], ['Inan', 'I', 'Sing', 'S', 'Ins', '7'], ['Inan', 'I', 'Plur', 'P', 'Dat', '3'], ['Fem', 'F', 'Plur', 'P', 'Dat', '3'], ['Neut', 'N', 'Sing', 'S', 'Ins', '7'], ['Neut', 'N', 'Plur', 'P', 'Dat', '3']]],
                'dóstojnými'  => ['důstojný', 'dóstojný', [['Anim', 'M', 'Plur', 'P', 'Ins', '7'], ['Inan', 'I', 'Plur', 'P', 'Ins', '7'], ['Fem', 'F', 'Plur', 'P', 'Ins', '7'], ['Neut', 'N', 'Plur', 'P', 'Ins', '7']]],
                'duostojná'   => ['důstojný', 'dóstojný', [['Fem', 'F', 'Sing', 'S', 'Nom', '1'], ['Fem', 'F', 'Sing', 'S', 'Voc', '5'], ['Neut', 'N', 'Plur', 'P', 'Nom', '1'], ['Neut', 'N', 'Plur', 'P', 'Acc', '4'], ['Neut', 'N', 'Plur', 'P', 'Voc', '5']]],
                'duostojné'   => ['důstojný', 'dóstojný', [['Anim', 'M', 'Plur', 'P', 'Acc', '4'], ['Inan', 'I', 'Plur', 'P', 'Nom', '1'], ['Inan', 'I', 'Plur', 'P', 'Acc', '4'], ['Inan', 'I', 'Plur', 'P', 'Voc', '5'], ['Fem', 'F', 'Sing', 'S', 'Gen', '2'], ['Fem', 'F', 'Sing', 'S', 'Dat', '3'], ['Fem', 'F', 'Sing', 'S', 'Loc', '6'], ['Fem', 'F', 'Plur', 'P', 'Nom', '1'], ['Fem', 'F', 'Plur', 'P', 'Acc', '4'], ['Fem', 'F', 'Plur', 'P', 'Voc', '5'], ['Neut', 'N', 'Sing', 'S', 'Nom', '1'], ['Neut', 'N', 'Sing', 'S', 'Acc', '4'], ['Neut', 'N', 'Sing', 'S', 'Voc', '5']]],
                'duostojného' => ['důstojný', 'dóstojný', [['Anim', 'M', 'Sing', 'S', 'Gen', '2'], ['Anim', 'M', 'Sing', 'S', 'Acc', '4'], ['Inan', 'I', 'Sing', 'S', 'Gen', '2'], ['Neut', 'N', 'Sing', 'S', 'Gen', '2']]],
                'duostojnéj'  => ['důstojný', 'dóstojný', [['Fem', 'F', 'Sing', 'S', 'Gen', '2'], ['Fem', 'F', 'Sing', 'S', 'Dat', '3'], ['Fem', 'F', 'Sing', 'S', 'Loc', '6']]],
                'duostojném'  => ['důstojný', 'dóstojný', [['Anim', 'M', 'Sing', 'S', 'Loc', '6'], ['Inan', 'I', 'Sing', 'S', 'Loc', '6'], ['Neut', 'N', 'Sing', 'S', 'Loc', '6']]],
                'duostojnému' => ['důstojný', 'dóstojný', [['Anim', 'M', 'Sing', 'S', 'Dat', '3'], ['Inan', 'I', 'Sing', 'S', 'Dat', '3'], ['Neut', 'N', 'Sing', 'S', 'Dat', '3']]],
                'duostojní'   => ['důstojný', 'dóstojný', [['Anim', 'M', 'Plur', 'P', 'Nom', '1'], ['Anim', 'M', 'Plur', 'P', 'Voc', '5']]],
                'duostojnou'  => ['důstojný', 'dóstojný', [['Fem', 'F', 'Sing', 'S', 'Acc', '4'], ['Fem', 'F', 'Sing', 'S', 'Ins', '7']]],
                'duostojnú'   => ['důstojný', 'dóstojný', [['Fem', 'F', 'Sing', 'S', 'Acc', '4'], ['Fem', 'F', 'Sing', 'S', 'Ins', '7']]],
                'duostojný'   => ['důstojný', 'dóstojný', [['Anim', 'M', 'Sing', 'S', 'Nom', '1'], ['Anim', 'M', 'Sing', 'S', 'Voc', '5'], ['Inan', 'I', 'Sing', 'S', 'Nom', '1'], ['Inan', 'I', 'Sing', 'S', 'Acc', '4'], ['Inan', 'I', 'Sing', 'S', 'Voc', '5']]],
                'duostojných' => ['důstojný', 'dóstojný', [['Anim', 'M', 'Plur', 'P', 'Gen', '2'], ['Anim', 'M', 'Plur', 'P', 'Loc', '6'], ['Inan', 'I', 'Plur', 'P', 'Gen', '2'], ['Inan', 'I', 'Plur', 'P', 'Loc', '6'], ['Fem', 'F', 'Plur', 'P', 'Gen', '2'], ['Fem', 'F', 'Plur', 'P', 'Loc', '6'], ['Neut', 'N', 'Plur', 'P', 'Gen', '2'], ['Neut', 'N', 'Plur', 'P', 'Loc', '6']]],
                'duostojným'  => ['důstojný', 'dóstojný', [['Anim', 'M', 'Sing', 'S', 'Ins', '7'], ['Anim', 'M', 'Plur', 'P', 'Dat', '3'], ['Inan', 'I', 'Sing', 'S', 'Ins', '7'], ['Inan', 'I', 'Plur', 'P', 'Dat', '3'], ['Fem', 'F', 'Plur', 'P', 'Dat', '3'], ['Neut', 'N', 'Sing', 'S', 'Ins', '7'], ['Neut', 'N', 'Plur', 'P', 'Dat', '3']]],
                'duostojnými' => ['důstojný', 'dóstojný', [['Anim', 'M', 'Plur', 'P', 'Ins', '7'], ['Inan', 'I', 'Plur', 'P', 'Ins', '7'], ['Fem', 'F', 'Plur', 'P', 'Ins', '7'], ['Neut', 'N', 'Plur', 'P', 'Ins', '7']]],
                'důstojná'    => ['důstojný', 'dóstojný', [['Fem', 'F', 'Sing', 'S', 'Nom', '1'], ['Fem', 'F', 'Sing', 'S', 'Voc', '5'], ['Neut', 'N', 'Plur', 'P', 'Nom', '1'], ['Neut', 'N', 'Plur', 'P', 'Acc', '4'], ['Neut', 'N', 'Plur', 'P', 'Voc', '5']]],
                'důstojné'    => ['důstojný', 'dóstojný', [['Anim', 'M', 'Plur', 'P', 'Acc', '4'], ['Inan', 'I', 'Plur', 'P', 'Nom', '1'], ['Inan', 'I', 'Plur', 'P', 'Acc', '4'], ['Inan', 'I', 'Plur', 'P', 'Voc', '5'], ['Fem', 'F', 'Sing', 'S', 'Gen', '2'], ['Fem', 'F', 'Sing', 'S', 'Dat', '3'], ['Fem', 'F', 'Sing', 'S', 'Loc', '6'], ['Fem', 'F', 'Plur', 'P', 'Nom', '1'], ['Fem', 'F', 'Plur', 'P', 'Acc', '4'], ['Fem', 'F', 'Plur', 'P', 'Voc', '5'], ['Neut', 'N', 'Sing', 'S', 'Nom', '1'], ['Neut', 'N', 'Sing', 'S', 'Acc', '4'], ['Neut', 'N', 'Sing', 'S', 'Voc', '5']]],
                'důstojného'  => ['důstojný', 'dóstojný', [['Anim', 'M', 'Sing', 'S', 'Gen', '2'], ['Anim', 'M', 'Sing', 'S', 'Acc', '4'], ['Inan', 'I', 'Sing', 'S', 'Gen', '2'], ['Neut', 'N', 'Sing', 'S', 'Gen', '2']]],
                'důstojnéj'   => ['důstojný', 'dóstojný', [['Fem', 'F', 'Sing', 'S', 'Gen', '2'], ['Fem', 'F', 'Sing', 'S', 'Dat', '3'], ['Fem', 'F', 'Sing', 'S', 'Loc', '6']]],
                'důstojném'   => ['důstojný', 'dóstojný', [['Anim', 'M', 'Sing', 'S', 'Loc', '6'], ['Inan', 'I', 'Sing', 'S', 'Loc', '6'], ['Neut', 'N', 'Sing', 'S', 'Loc', '6']]],
                'důstojnému'  => ['důstojný', 'dóstojný', [['Anim', 'M', 'Sing', 'S', 'Dat', '3'], ['Inan', 'I', 'Sing', 'S', 'Dat', '3'], ['Neut', 'N', 'Sing', 'S', 'Dat', '3']]],
                'důstojní'    => ['důstojný', 'dóstojný', [['Anim', 'M', 'Plur', 'P', 'Nom', '1'], ['Anim', 'M', 'Plur', 'P', 'Voc', '5']]],
                'důstojnou'   => ['důstojný', 'dóstojný', [['Fem', 'F', 'Sing', 'S', 'Acc', '4'], ['Fem', 'F', 'Sing', 'S', 'Ins', '7']]],
                'důstojnú'    => ['důstojný', 'dóstojný', [['Fem', 'F', 'Sing', 'S', 'Acc', '4'], ['Fem', 'F', 'Sing', 'S', 'Ins', '7']]],
                'důstojný'    => ['důstojný', 'dóstojný', [['Anim', 'M', 'Sing', 'S', 'Nom', '1'], ['Anim', 'M', 'Sing', 'S', 'Voc', '5'], ['Inan', 'I', 'Sing', 'S', 'Nom', '1'], ['Inan', 'I', 'Sing', 'S', 'Acc', '4'], ['Inan', 'I', 'Sing', 'S', 'Voc', '5']]],
                'důstojných'  => ['důstojný', 'dóstojný', [['Anim', 'M', 'Plur', 'P', 'Gen', '2'], ['Anim', 'M', 'Plur', 'P', 'Loc', '6'], ['Inan', 'I', 'Plur', 'P', 'Gen', '2'], ['Inan', 'I', 'Plur', 'P', 'Loc', '6'], ['Fem', 'F', 'Plur', 'P', 'Gen', '2'], ['Fem', 'F', 'Plur', 'P', 'Loc', '6'], ['Neut', 'N', 'Plur', 'P', 'Gen', '2'], ['Neut', 'N', 'Plur', 'P', 'Loc', '6']]],
                'důstojným'   => ['důstojný', 'dóstojný', [['Anim', 'M', 'Sing', 'S', 'Ins', '7'], ['Anim', 'M', 'Plur', 'P', 'Dat', '3'], ['Inan', 'I', 'Sing', 'S', 'Ins', '7'], ['Inan', 'I', 'Plur', 'P', 'Dat', '3'], ['Fem', 'F', 'Plur', 'P', 'Dat', '3'], ['Neut', 'N', 'Sing', 'S', 'Ins', '7'], ['Neut', 'N', 'Plur', 'P', 'Dat', '3']]],
                'důstojnými'  => ['důstojný', 'dóstojný', [['Anim', 'M', 'Plur', 'P', 'Ins', '7'], ['Inan', 'I', 'Plur', 'P', 'Ins', '7'], ['Fem', 'F', 'Plur', 'P', 'Ins', '7'], ['Neut', 'N', 'Plur', 'P', 'Ins', '7']]],
                'jiná'       => ['jiný',     'jiný',      [['Fem',  'F', 'Sing', 'S', 'Nom', '1'], ['Anim', 'M', 'Dual', 'D', 'Acc', '4', 'MATT_4\\.21'], ['Inan', 'I', 'Dual', 'D', 'Acc', '4'], ['Neut', 'N', 'Plur', 'P', 'Nom', '1']]],
                'jiné'       => ['jiný',     'jiný',      [['Neut', 'N', 'Sing', 'S', 'Nom', '1'], ['Neut', 'N', 'Sing', 'S', 'Acc', '4'], ['Anim', 'M', 'Plur', 'P', 'Nom', '1'], ['Anim', 'M', 'Plur', 'P', 'Acc', '4']]],
                'jiného'     => ['jiný',     'jiný',      [['Anim', 'M', 'Sing', 'S', 'Acc', '4'], ['Neut', 'N', 'Sing', 'S', 'Gen', '2']]],
                'jinéj'      => ['jiný',     'jiný',      [['Fem',  'F', 'Sing', 'S', 'Dat', '3'], ['Fem',  'F', 'Sing', 'S', 'Loc', '6']]],
                'jiném'      => ['jiný',     'jiný',      [['Anim', 'M', 'Sing', 'S', 'Loc', '6'], ['Inan', 'I', 'Sing', 'S', 'Loc', '6'], ['Neut', 'N', 'Sing', 'S', 'Loc', '6']]],
                'jinému'     => ['jiný',     'jiný',      [['Anim', 'M', 'Sing', 'S', 'Dat', '3']]],
                'jiní'       => ['jiný',     'jiný',      [['Anim', 'M', 'Plur', 'P', 'Nom', '1']]],
                'jinie'      => ['jiný',     'jiný',      [['Fem',  'F', 'Dual', 'D', 'Acc', '4']]],
                'jinú'       => ['jiný',     'jiný',      [['Fem',  'F', 'Sing', 'S', 'Acc', '4'], ['Fem',  'F', 'Sing', 'S', 'Ins', '7']]],
                'jiný'       => ['jiný',     'jiný',      [['Anim', 'M', 'Sing', 'S', 'Nom', '1'], ['Inan', 'I', 'Sing', 'S', 'Acc', '4']]],
                'jiných'     => ['jiný',     'jiný',      [['Anim', 'M', 'Plur', 'P', 'Gen', '2'], ['Fem',  'F', 'Plur', 'P', 'Gen', '2']]],
                'jiným'      => ['jiný',     'jiný',      [['Anim', 'M', 'Plur', 'P', 'Dat', '3']]],
                'jinými'     => ['jiný',     'jiný',      [['Anim', 'M', 'Plur', 'P', 'Ins', '7'], ['Neut', 'N', 'Plur', 'P', 'Ins', '7']]],
                'leská'   => ['lesní', 'leský', [['Fem', 'F', 'Sing', 'S', 'Nom', '1'], ['Fem', 'F', 'Sing', 'S', 'Voc', '5']]],
                'leské'   => ['lesní', 'leský', [['Anim', 'M', 'Plur', 'P', 'Acc', '4'], ['Inan', 'I', 'Plur', 'P', 'Nom', '1'], ['Inan', 'I', 'Plur', 'P', 'Acc', '4'], ['Inan', 'I', 'Plur', 'P', 'Voc', '5'], ['Fem', 'F', 'Sing', 'S', 'Gen', '2'], ['Fem', 'F', 'Sing', 'S', 'Dat', '3'], ['Fem', 'F', 'Sing', 'S', 'Loc', '6'], ['Fem', 'F', 'Plur', 'P', 'Nom', '1'], ['Fem', 'F', 'Plur', 'P', 'Acc', '4'], ['Fem', 'F', 'Plur', 'P', 'Voc', '5'], ['Neut', 'N', 'Sing', 'S', 'Nom', '1'], ['Neut', 'N', 'Sing', 'S', 'Acc', '4'], ['Neut', 'N', 'Sing', 'S', 'Voc', '5'], ['Neut', 'N', 'Plur', 'P', 'Nom', '1'], ['Neut', 'N', 'Plur', 'P', 'Acc', '4'], ['Neut', 'N', 'Plur', 'P', 'Voc', '5']]],
                'leského' => ['lesní', 'leský', [['Anim', 'M', 'Sing', 'S', 'Gen', '2'], ['Anim', 'M', 'Sing', 'S', 'Acc', '4'], ['Inan', 'I', 'Sing', 'S', 'Gen', '2'], ['Neut', 'N', 'Sing', 'S', 'Gen', '2']]],
                'leskéj'  => ['lesní', 'leský', [['Fem', 'F', 'Sing', 'S', 'Gen', '2'], ['Fem', 'F', 'Sing', 'S', 'Dat', '3'], ['Fem', 'F', 'Sing', 'S', 'Loc', '6']]],
                'leském'  => ['lesní', 'leský', [['Anim', 'M', 'Sing', 'S', 'Loc', '6'], ['Inan', 'I', 'Sing', 'S', 'Loc', '6'], ['Neut', 'N', 'Sing', 'S', 'Loc', '6']]],
                'leskému' => ['lesní', 'leský', [['Anim', 'M', 'Sing', 'S', 'Dat', '3'], ['Inan', 'I', 'Sing', 'S', 'Dat', '3'], ['Neut', 'N', 'Sing', 'S', 'Dat', '3']]],
                'leskou'  => ['lesní', 'leský', [['Fem', 'F', 'Sing', 'S', 'Acc', '4'], ['Fem', 'F', 'Sing', 'S', 'Ins', '7']]],
                'leskú'   => ['lesní', 'leský', [['Fem', 'F', 'Sing', 'S', 'Acc', '4'], ['Fem', 'F', 'Sing', 'S', 'Ins', '7']]],
                'leský'   => ['lesní', 'leský', [['Anim', 'M', 'Sing', 'S', 'Nom', '1'], ['Anim', 'M', 'Sing', 'S', 'Voc', '5'], ['Inan', 'I', 'Sing', 'S', 'Nom', '1'], ['Inan', 'I', 'Sing', 'S', 'Acc', '4'], ['Inan', 'I', 'Sing', 'S', 'Voc', '5']]],
                'leských' => ['lesní', 'leský', [['Anim', 'M', 'Plur', 'P', 'Gen', '2'], ['Anim', 'M', 'Plur', 'P', 'Loc', '6'], ['Inan', 'I', 'Plur', 'P', 'Gen', '2'], ['Inan', 'I', 'Plur', 'P', 'Loc', '6'], ['Fem', 'F', 'Plur', 'P', 'Gen', '2'], ['Fem', 'F', 'Plur', 'P', 'Loc', '6'], ['Neut', 'N', 'Plur', 'P', 'Gen', '2'], ['Neut', 'N', 'Plur', 'P', 'Loc', '6']]],
                'leským'  => ['lesní', 'leský', [['Anim', 'M', 'Sing', 'S', 'Ins', '7'], ['Anim', 'M', 'Plur', 'P', 'Dat', '3'], ['Inan', 'I', 'Sing', 'S', 'Ins', '7'], ['Inan', 'I', 'Plur', 'P', 'Dat', '3'], ['Fem', 'F', 'Plur', 'P', 'Dat', '3'], ['Neut', 'N', 'Sing', 'S', 'Ins', '7'], ['Neut', 'N', 'Plur', 'P', 'Dat', '3']]],
                'leskými' => ['lesní', 'leský', [['Anim', 'M', 'Plur', 'P', 'Ins', '7'], ['Inan', 'I', 'Plur', 'P', 'Ins', '7'], ['Fem', 'F', 'Plur', 'P', 'Ins', '7'], ['Neut', 'N', 'Plur', 'P', 'Ins', '7']]],
                'leští'   => ['lesní', 'leský', [['Anim', 'M', 'Plur', 'P', 'Nom', '1'], ['Anim', 'M', 'Plur', 'P', 'Voc', '5']]],
                'lidská'   => ['lidský', 'lidský', [['Fem', 'F', 'Sing', 'S', 'Nom', '1'], ['Fem', 'F', 'Sing', 'S', 'Voc', '5']]],
                'lidské'   => ['lidský', 'lidský', [['Anim', 'M', 'Plur', 'P', 'Acc', '4'], ['Inan', 'I', 'Plur', 'P', 'Nom', '1'], ['Inan', 'I', 'Plur', 'P', 'Acc', '4'], ['Inan', 'I', 'Plur', 'P', 'Voc', '5'], ['Fem', 'F', 'Sing', 'S', 'Gen', '2'], ['Fem', 'F', 'Sing', 'S', 'Dat', '3'], ['Fem', 'F', 'Sing', 'S', 'Loc', '6'], ['Fem', 'F', 'Plur', 'P', 'Nom', '1'], ['Fem', 'F', 'Plur', 'P', 'Acc', '4'], ['Fem', 'F', 'Plur', 'P', 'Voc', '5'], ['Neut', 'N', 'Sing', 'S', 'Nom', '1'], ['Neut', 'N', 'Sing', 'S', 'Acc', '4'], ['Neut', 'N', 'Sing', 'S', 'Voc', '5'], ['Neut', 'N', 'Plur', 'P', 'Nom', '1'], ['Neut', 'N', 'Plur', 'P', 'Acc', '4'], ['Neut', 'N', 'Plur', 'P', 'Voc', '5']]],
                'lidského' => ['lidský', 'lidský', [['Anim', 'M', 'Sing', 'S', 'Gen', '2'], ['Anim', 'M', 'Sing', 'S', 'Acc', '4'], ['Inan', 'I', 'Sing', 'S', 'Gen', '2'], ['Neut', 'N', 'Sing', 'S', 'Gen', '2']]],
                'lidskéj'  => ['lidský', 'lidský', [['Fem', 'F', 'Sing', 'S', 'Gen', '2'], ['Fem', 'F', 'Sing', 'S', 'Dat', '3'], ['Fem', 'F', 'Sing', 'S', 'Loc', '6']]],
                'lidském'  => ['lidský', 'lidský', [['Anim', 'M', 'Sing', 'S', 'Loc', '6'], ['Inan', 'I', 'Sing', 'S', 'Loc', '6'], ['Neut', 'N', 'Sing', 'S', 'Loc', '6']]],
                'lidskému' => ['lidský', 'lidský', [['Anim', 'M', 'Sing', 'S', 'Dat', '3'], ['Inan', 'I', 'Sing', 'S', 'Dat', '3'], ['Neut', 'N', 'Sing', 'S', 'Dat', '3']]],
                'lidskou'  => ['lidský', 'lidský', [['Fem', 'F', 'Sing', 'S', 'Acc', '4'], ['Fem', 'F', 'Sing', 'S', 'Ins', '7']]],
                'lidskú'   => ['lidský', 'lidský', [['Fem', 'F', 'Sing', 'S', 'Acc', '4'], ['Fem', 'F', 'Sing', 'S', 'Ins', '7']]],
                'lidský'   => ['lidský', 'lidský', [['Anim', 'M', 'Sing', 'S', 'Nom', '1'], ['Anim', 'M', 'Sing', 'S', 'Voc', '5'], ['Inan', 'I', 'Sing', 'S', 'Nom', '1'], ['Inan', 'I', 'Sing', 'S', 'Acc', '4'], ['Inan', 'I', 'Sing', 'S', 'Voc', '5']]],
                'lidských' => ['lidský', 'lidský', [['Anim', 'M', 'Plur', 'P', 'Gen', '2'], ['Anim', 'M', 'Plur', 'P', 'Loc', '6'], ['Inan', 'I', 'Plur', 'P', 'Gen', '2'], ['Inan', 'I', 'Plur', 'P', 'Loc', '6'], ['Fem', 'F', 'Plur', 'P', 'Gen', '2'], ['Fem', 'F', 'Plur', 'P', 'Loc', '6'], ['Neut', 'N', 'Plur', 'P', 'Gen', '2'], ['Neut', 'N', 'Plur', 'P', 'Loc', '6']]],
                'lidským'  => ['lidský', 'lidský', [['Anim', 'M', 'Sing', 'S', 'Ins', '7'], ['Anim', 'M', 'Plur', 'P', 'Dat', '3'], ['Inan', 'I', 'Sing', 'S', 'Ins', '7'], ['Inan', 'I', 'Plur', 'P', 'Dat', '3'], ['Fem', 'F', 'Plur', 'P', 'Dat', '3'], ['Neut', 'N', 'Sing', 'S', 'Ins', '7'], ['Neut', 'N', 'Plur', 'P', 'Dat', '3']]],
                'lidskými' => ['lidský', 'lidský', [['Anim', 'M', 'Plur', 'P', 'Ins', '7'], ['Inan', 'I', 'Plur', 'P', 'Ins', '7'], ['Fem', 'F', 'Plur', 'P', 'Ins', '7'], ['Neut', 'N', 'Plur', 'P', 'Ins', '7']]],
                'lidští'   => ['lidský', 'lidský', [['Anim', 'M', 'Plur', 'P', 'Nom', '1'], ['Anim', 'M', 'Plur', 'P', 'Voc', '5']]],
                'nebeská'   => ['nebeský', 'nebeský', [['Fem', 'F', 'Sing', 'S', 'Nom', '1'], ['Fem', 'F', 'Sing', 'S', 'Voc', '5']]],
                'nebeské'   => ['nebeský', 'nebeský', [['Anim', 'M', 'Plur', 'P', 'Acc', '4'], ['Inan', 'I', 'Plur', 'P', 'Nom', '1'], ['Inan', 'I', 'Plur', 'P', 'Acc', '4'], ['Inan', 'I', 'Plur', 'P', 'Voc', '5'], ['Fem', 'F', 'Sing', 'S', 'Gen', '2'], ['Fem', 'F', 'Sing', 'S', 'Dat', '3'], ['Fem', 'F', 'Sing', 'S', 'Loc', '6'], ['Fem', 'F', 'Plur', 'P', 'Nom', '1'], ['Fem', 'F', 'Plur', 'P', 'Acc', '4'], ['Fem', 'F', 'Plur', 'P', 'Voc', '5'], ['Neut', 'N', 'Sing', 'S', 'Nom', '1'], ['Neut', 'N', 'Sing', 'S', 'Acc', '4'], ['Neut', 'N', 'Sing', 'S', 'Voc', '5'], ['Neut', 'N', 'Plur', 'P', 'Nom', '1'], ['Neut', 'N', 'Plur', 'P', 'Acc', '4'], ['Neut', 'N', 'Plur', 'P', 'Voc', '5']]],
                'nebeského' => ['nebeský', 'nebeský', [['Anim', 'M', 'Sing', 'S', 'Gen', '2'], ['Anim', 'M', 'Sing', 'S', 'Acc', '4'], ['Inan', 'I', 'Sing', 'S', 'Gen', '2'], ['Neut', 'N', 'Sing', 'S', 'Gen', '2']]],
                'nebeskéj'  => ['nebeský', 'nebeský', [['Fem', 'F', 'Sing', 'S', 'Gen', '2'], ['Fem', 'F', 'Sing', 'S', 'Dat', '3'], ['Fem', 'F', 'Sing', 'S', 'Loc', '6']]],
                'nebeském'  => ['nebeský', 'nebeský', [['Anim', 'M', 'Sing', 'S', 'Loc', '6'], ['Inan', 'I', 'Sing', 'S', 'Loc', '6'], ['Neut', 'N', 'Sing', 'S', 'Loc', '6']]],
                'nebeskému' => ['nebeský', 'nebeský', [['Anim', 'M', 'Sing', 'S', 'Dat', '3'], ['Inan', 'I', 'Sing', 'S', 'Dat', '3'], ['Neut', 'N', 'Sing', 'S', 'Dat', '3']]],
                'nebeskou'  => ['nebeský', 'nebeský', [['Fem', 'F', 'Sing', 'S', 'Acc', '4'], ['Fem', 'F', 'Sing', 'S', 'Ins', '7']]],
                'nebeskú'   => ['nebeský', 'nebeský', [['Fem', 'F', 'Sing', 'S', 'Acc', '4'], ['Fem', 'F', 'Sing', 'S', 'Ins', '7']]],
                'nebeský'   => ['nebeský', 'nebeský', [['Anim', 'M', 'Sing', 'S', 'Nom', '1'], ['Anim', 'M', 'Sing', 'S', 'Voc', '5'], ['Inan', 'I', 'Sing', 'S', 'Nom', '1'], ['Inan', 'I', 'Sing', 'S', 'Acc', '4'], ['Inan', 'I', 'Sing', 'S', 'Voc', '5']]],
                'nebeských' => ['nebeský', 'nebeský', [['Anim', 'M', 'Plur', 'P', 'Gen', '2'], ['Anim', 'M', 'Plur', 'P', 'Loc', '6'], ['Inan', 'I', 'Plur', 'P', 'Gen', '2'], ['Inan', 'I', 'Plur', 'P', 'Loc', '6'], ['Fem', 'F', 'Plur', 'P', 'Gen', '2'], ['Fem', 'F', 'Plur', 'P', 'Loc', '6'], ['Neut', 'N', 'Plur', 'P', 'Gen', '2'], ['Neut', 'N', 'Plur', 'P', 'Loc', '6']]],
                'nebeským'  => ['nebeský', 'nebeský', [['Anim', 'M', 'Sing', 'S', 'Ins', '7'], ['Anim', 'M', 'Plur', 'P', 'Dat', '3'], ['Inan', 'I', 'Sing', 'S', 'Ins', '7'], ['Inan', 'I', 'Plur', 'P', 'Dat', '3'], ['Fem', 'F', 'Plur', 'P', 'Dat', '3'], ['Neut', 'N', 'Sing', 'S', 'Ins', '7'], ['Neut', 'N', 'Plur', 'P', 'Dat', '3']]],
                'nebeskými' => ['nebeský', 'nebeský', [['Anim', 'M', 'Plur', 'P', 'Ins', '7'], ['Inan', 'I', 'Plur', 'P', 'Ins', '7'], ['Fem', 'F', 'Plur', 'P', 'Ins', '7'], ['Neut', 'N', 'Plur', 'P', 'Ins', '7']]],
                'nebeští'   => ['nebeský', 'nebeský', [['Anim', 'M', 'Plur', 'P', 'Nom', '1'], ['Anim', 'M', 'Plur', 'P', 'Voc', '5']]],
                'neptalimová' => ['neptalimový', 'neptalimový', [['Fem', 'F', 'Sing', 'S', 'Nom', '1']]],
                'neptalimovských' => ['neptalimovský', 'neptalimovský', [['Inan', 'I', 'Plur', 'P', 'Loc', '6']]],
                'ohněvá'   => ['ohnivý', 'ohněvý', [['Fem', 'F', 'Sing', 'S', 'Nom', '1'], ['Fem', 'F', 'Sing', 'S', 'Voc', '5'], ['Neut', 'N', 'Plur', 'P', 'Nom', '1'], ['Neut', 'N', 'Plur', 'P', 'Acc', '4'], ['Neut', 'N', 'Plur', 'P', 'Voc', '5']]],
                'ohněvé'   => ['ohnivý', 'ohněvý', [['Anim', 'M', 'Plur', 'P', 'Acc', '4'], ['Inan', 'I', 'Plur', 'P', 'Nom', '1'], ['Inan', 'I', 'Plur', 'P', 'Acc', '4'], ['Inan', 'I', 'Plur', 'P', 'Voc', '5'], ['Fem', 'F', 'Sing', 'S', 'Gen', '2'], ['Fem', 'F', 'Sing', 'S', 'Dat', '3'], ['Fem', 'F', 'Sing', 'S', 'Loc', '6'], ['Fem', 'F', 'Plur', 'P', 'Nom', '1'], ['Fem', 'F', 'Plur', 'P', 'Acc', '4'], ['Fem', 'F', 'Plur', 'P', 'Voc', '5'], ['Neut', 'N', 'Sing', 'S', 'Nom', '1'], ['Neut', 'N', 'Sing', 'S', 'Acc', '4'], ['Neut', 'N', 'Sing', 'S', 'Voc', '5']]],
                'ohněvého' => ['ohnivý', 'ohněvý', [['Anim', 'M', 'Sing', 'S', 'Gen', '2'], ['Anim', 'M', 'Sing', 'S', 'Acc', '4'], ['Inan', 'I', 'Sing', 'S', 'Gen', '2'], ['Neut', 'N', 'Sing', 'S', 'Gen', '2']]],
                'ohněvéj'  => ['ohnivý', 'ohněvý', [['Fem', 'F', 'Sing', 'S', 'Gen', '2'], ['Fem', 'F', 'Sing', 'S', 'Dat', '3'], ['Fem', 'F', 'Sing', 'S', 'Loc', '6']]],
                'ohněvém'  => ['ohnivý', 'ohněvý', [['Anim', 'M', 'Sing', 'S', 'Loc', '6'], ['Inan', 'I', 'Sing', 'S', 'Loc', '6'], ['Neut', 'N', 'Sing', 'S', 'Loc', '6']]],
                'ohněvému' => ['ohnivý', 'ohněvý', [['Anim', 'M', 'Sing', 'S', 'Dat', '3'], ['Inan', 'I', 'Sing', 'S', 'Dat', '3'], ['Neut', 'N', 'Sing', 'S', 'Dat', '3']]],
                'ohněví'   => ['ohnivý', 'ohněvý', [['Anim', 'M', 'Plur', 'P', 'Nom', '1'], ['Anim', 'M', 'Plur', 'P', 'Voc', '5']]],
                'ohněvou'  => ['ohnivý', 'ohněvý', [['Fem', 'F', 'Sing', 'S', 'Acc', '4'], ['Fem', 'F', 'Sing', 'S', 'Ins', '7']]],
                'ohněvú'   => ['ohnivý', 'ohněvý', [['Fem', 'F', 'Sing', 'S', 'Acc', '4'], ['Fem', 'F', 'Sing', 'S', 'Ins', '7']]],
                'ohněvý'   => ['ohnivý', 'ohněvý', [['Anim', 'M', 'Sing', 'S', 'Nom', '1'], ['Anim', 'M', 'Sing', 'S', 'Voc', '5'], ['Inan', 'I', 'Sing', 'S', 'Nom', '1'], ['Inan', 'I', 'Sing', 'S', 'Acc', '4'], ['Inan', 'I', 'Sing', 'S', 'Voc', '5']]],
                'ohněvých' => ['ohnivý', 'ohněvý', [['Anim', 'M', 'Plur', 'P', 'Gen', '2'], ['Anim', 'M', 'Plur', 'P', 'Loc', '6'], ['Inan', 'I', 'Plur', 'P', 'Gen', '2'], ['Inan', 'I', 'Plur', 'P', 'Loc', '6'], ['Fem', 'F', 'Plur', 'P', 'Gen', '2'], ['Fem', 'F', 'Plur', 'P', 'Loc', '6'], ['Neut', 'N', 'Plur', 'P', 'Gen', '2'], ['Neut', 'N', 'Plur', 'P', 'Loc', '6']]],
                'ohněvým'  => ['ohnivý', 'ohněvý', [['Anim', 'M', 'Sing', 'S', 'Ins', '7'], ['Anim', 'M', 'Plur', 'P', 'Dat', '3'], ['Inan', 'I', 'Sing', 'S', 'Ins', '7'], ['Inan', 'I', 'Plur', 'P', 'Dat', '3'], ['Fem', 'F', 'Plur', 'P', 'Dat', '3'], ['Neut', 'N', 'Sing', 'S', 'Ins', '7'], ['Neut', 'N', 'Plur', 'P', 'Dat', '3']]],
                'ohněvými' => ['ohnivý', 'ohněvý', [['Anim', 'M', 'Plur', 'P', 'Ins', '7'], ['Inan', 'I', 'Plur', 'P', 'Ins', '7'], ['Fem', 'F', 'Plur', 'P', 'Ins', '7'], ['Neut', 'N', 'Plur', 'P', 'Ins', '7']]],
                'ohnivá'   => ['ohnivý', 'ohněvý', [['Fem', 'F', 'Sing', 'S', 'Nom', '1'], ['Fem', 'F', 'Sing', 'S', 'Voc', '5'], ['Neut', 'N', 'Plur', 'P', 'Nom', '1'], ['Neut', 'N', 'Plur', 'P', 'Acc', '4'], ['Neut', 'N', 'Plur', 'P', 'Voc', '5']]],
                'ohnivé'   => ['ohnivý', 'ohněvý', [['Anim', 'M', 'Plur', 'P', 'Acc', '4'], ['Inan', 'I', 'Plur', 'P', 'Nom', '1'], ['Inan', 'I', 'Plur', 'P', 'Acc', '4'], ['Inan', 'I', 'Plur', 'P', 'Voc', '5'], ['Fem', 'F', 'Sing', 'S', 'Gen', '2'], ['Fem', 'F', 'Sing', 'S', 'Dat', '3'], ['Fem', 'F', 'Sing', 'S', 'Loc', '6'], ['Fem', 'F', 'Plur', 'P', 'Nom', '1'], ['Fem', 'F', 'Plur', 'P', 'Acc', '4'], ['Fem', 'F', 'Plur', 'P', 'Voc', '5'], ['Neut', 'N', 'Sing', 'S', 'Nom', '1'], ['Neut', 'N', 'Sing', 'S', 'Acc', '4'], ['Neut', 'N', 'Sing', 'S', 'Voc', '5']]],
                'ohnivého' => ['ohnivý', 'ohněvý', [['Anim', 'M', 'Sing', 'S', 'Gen', '2'], ['Anim', 'M', 'Sing', 'S', 'Acc', '4'], ['Inan', 'I', 'Sing', 'S', 'Gen', '2'], ['Neut', 'N', 'Sing', 'S', 'Gen', '2']]],
                'ohnivéj'  => ['ohnivý', 'ohněvý', [['Fem', 'F', 'Sing', 'S', 'Gen', '2'], ['Fem', 'F', 'Sing', 'S', 'Dat', '3'], ['Fem', 'F', 'Sing', 'S', 'Loc', '6']]],
                'ohnivém'  => ['ohnivý', 'ohněvý', [['Anim', 'M', 'Sing', 'S', 'Loc', '6'], ['Inan', 'I', 'Sing', 'S', 'Loc', '6'], ['Neut', 'N', 'Sing', 'S', 'Loc', '6']]],
                'ohnivému' => ['ohnivý', 'ohněvý', [['Anim', 'M', 'Sing', 'S', 'Dat', '3'], ['Inan', 'I', 'Sing', 'S', 'Dat', '3'], ['Neut', 'N', 'Sing', 'S', 'Dat', '3']]],
                'ohniví'   => ['ohnivý', 'ohněvý', [['Anim', 'M', 'Plur', 'P', 'Nom', '1'], ['Anim', 'M', 'Plur', 'P', 'Voc', '5']]],
                'ohnivou'  => ['ohnivý', 'ohněvý', [['Fem', 'F', 'Sing', 'S', 'Acc', '4'], ['Fem', 'F', 'Sing', 'S', 'Ins', '7']]],
                'ohnivú'   => ['ohnivý', 'ohněvý', [['Fem', 'F', 'Sing', 'S', 'Acc', '4'], ['Fem', 'F', 'Sing', 'S', 'Ins', '7']]],
                'ohnivý'   => ['ohnivý', 'ohněvý', [['Anim', 'M', 'Sing', 'S', 'Nom', '1'], ['Anim', 'M', 'Sing', 'S', 'Voc', '5'], ['Inan', 'I', 'Sing', 'S', 'Nom', '1'], ['Inan', 'I', 'Sing', 'S', 'Acc', '4'], ['Inan', 'I', 'Sing', 'S', 'Voc', '5']]],
                'ohnivých' => ['ohnivý', 'ohněvý', [['Anim', 'M', 'Plur', 'P', 'Gen', '2'], ['Anim', 'M', 'Plur', 'P', 'Loc', '6'], ['Inan', 'I', 'Plur', 'P', 'Gen', '2'], ['Inan', 'I', 'Plur', 'P', 'Loc', '6'], ['Fem', 'F', 'Plur', 'P', 'Gen', '2'], ['Fem', 'F', 'Plur', 'P', 'Loc', '6'], ['Neut', 'N', 'Plur', 'P', 'Gen', '2'], ['Neut', 'N', 'Plur', 'P', 'Loc', '6']]],
                'ohnivým'  => ['ohnivý', 'ohněvý', [['Anim', 'M', 'Sing', 'S', 'Ins', '7'], ['Anim', 'M', 'Plur', 'P', 'Dat', '3'], ['Inan', 'I', 'Sing', 'S', 'Ins', '7'], ['Inan', 'I', 'Plur', 'P', 'Dat', '3'], ['Fem', 'F', 'Plur', 'P', 'Dat', '3'], ['Neut', 'N', 'Sing', 'S', 'Ins', '7'], ['Neut', 'N', 'Plur', 'P', 'Dat', '3']]],
                'ohnivými' => ['ohnivý', 'ohněvý', [['Anim', 'M', 'Plur', 'P', 'Ins', '7'], ['Inan', 'I', 'Plur', 'P', 'Ins', '7'], ['Fem', 'F', 'Plur', 'P', 'Ins', '7'], ['Neut', 'N', 'Plur', 'P', 'Ins', '7']]],
                'popová'   => ['popový', 'popový', [['Fem', 'F', 'Sing', 'S', 'Nom', '1'], ['Fem', 'F', 'Sing', 'S', 'Voc', '5']]],
                'popové'   => ['popový', 'popový', [['Anim', 'M', 'Plur', 'P', 'Acc', '4'], ['Inan', 'I', 'Plur', 'P', 'Nom', '1'], ['Inan', 'I', 'Plur', 'P', 'Acc', '4'], ['Inan', 'I', 'Plur', 'P', 'Voc', '5'], ['Fem', 'F', 'Sing', 'S', 'Gen', '2'], ['Fem', 'F', 'Sing', 'S', 'Dat', '3'], ['Fem', 'F', 'Sing', 'S', 'Loc', '6'], ['Fem', 'F', 'Plur', 'P', 'Nom', '1'], ['Fem', 'F', 'Plur', 'P', 'Acc', '4'], ['Fem', 'F', 'Plur', 'P', 'Voc', '5'], ['Neut', 'N', 'Sing', 'S', 'Nom', '1'], ['Neut', 'N', 'Sing', 'S', 'Acc', '4'], ['Neut', 'N', 'Sing', 'S', 'Voc', '5'], ['Neut', 'N', 'Plur', 'P', 'Nom', '1'], ['Neut', 'N', 'Plur', 'P', 'Acc', '4'], ['Neut', 'N', 'Plur', 'P', 'Voc', '5']]],
                'popového' => ['popový', 'popový', [['Anim', 'M', 'Sing', 'S', 'Gen', '2'], ['Anim', 'M', 'Sing', 'S', 'Acc', '4'], ['Inan', 'I', 'Sing', 'S', 'Gen', '2'], ['Neut', 'N', 'Sing', 'S', 'Gen', '2']]],
                'popovéj'  => ['popový', 'popový', [['Fem', 'F', 'Sing', 'S', 'Gen', '2'], ['Fem', 'F', 'Sing', 'S', 'Dat', '3'], ['Fem', 'F', 'Sing', 'S', 'Loc', '6']]],
                'popovém'  => ['popový', 'popový', [['Anim', 'M', 'Sing', 'S', 'Loc', '6'], ['Inan', 'I', 'Sing', 'S', 'Loc', '6'], ['Neut', 'N', 'Sing', 'S', 'Loc', '6']]],
                'popovému' => ['popový', 'popový', [['Anim', 'M', 'Sing', 'S', 'Dat', '3'], ['Inan', 'I', 'Sing', 'S', 'Dat', '3'], ['Neut', 'N', 'Sing', 'S', 'Dat', '3']]],
                'popoví'   => ['popový', 'popový', [['Anim', 'M', 'Plur', 'P', 'Nom', '1'], ['Anim', 'M', 'Plur', 'P', 'Voc', '5']]],
                'popovou'  => ['popový', 'popový', [['Fem', 'F', 'Sing', 'S', 'Acc', '4'], ['Fem', 'F', 'Sing', 'S', 'Ins', '7']]],
                'popovú'   => ['popový', 'popový', [['Fem', 'F', 'Sing', 'S', 'Acc', '4'], ['Fem', 'F', 'Sing', 'S', 'Ins', '7']]],
                'popový'   => ['popový', 'popový', [['Anim', 'M', 'Sing', 'S', 'Nom', '1'], ['Anim', 'M', 'Sing', 'S', 'Voc', '5'], ['Inan', 'I', 'Sing', 'S', 'Nom', '1'], ['Inan', 'I', 'Sing', 'S', 'Acc', '4'], ['Inan', 'I', 'Sing', 'S', 'Voc', '5']]],
                'popových' => ['popový', 'popový', [['Anim', 'M', 'Plur', 'P', 'Gen', '2'], ['Anim', 'M', 'Plur', 'P', 'Loc', '6'], ['Inan', 'I', 'Plur', 'P', 'Gen', '2'], ['Inan', 'I', 'Plur', 'P', 'Loc', '6'], ['Fem', 'F', 'Plur', 'P', 'Gen', '2'], ['Fem', 'F', 'Plur', 'P', 'Loc', '6'], ['Neut', 'N', 'Plur', 'P', 'Gen', '2'], ['Neut', 'N', 'Plur', 'P', 'Loc', '6']]],
                'popovým'  => ['popový', 'popový', [['Anim', 'M', 'Sing', 'S', 'Ins', '7'], ['Anim', 'M', 'Plur', 'P', 'Dat', '3'], ['Inan', 'I', 'Sing', 'S', 'Ins', '7'], ['Inan', 'I', 'Plur', 'P', 'Dat', '3'], ['Fem', 'F', 'Plur', 'P', 'Dat', '3'], ['Neut', 'N', 'Sing', 'S', 'Ins', '7'], ['Neut', 'N', 'Plur', 'P', 'Dat', '3']]],
                'popovými' => ['popový', 'popový', [['Anim', 'M', 'Plur', 'P', 'Ins', '7'], ['Inan', 'I', 'Plur', 'P', 'Ins', '7'], ['Fem', 'F', 'Plur', 'P', 'Ins', '7'], ['Neut', 'N', 'Plur', 'P', 'Ins', '7']]],
                'propuščená'   => ['propuštěný', 'propuščený', [['Fem', 'F', 'Sing', 'S', 'Nom', '1'], ['Fem', 'F', 'Sing', 'S', 'Voc', '5']]],
                'propuščené'   => ['propuštěný', 'propuščený', [['Anim', 'M', 'Plur', 'P', 'Acc', '4'], ['Inan', 'I', 'Plur', 'P', 'Nom', '1'], ['Inan', 'I', 'Plur', 'P', 'Acc', '4'], ['Inan', 'I', 'Plur', 'P', 'Voc', '5'], ['Fem', 'F', 'Sing', 'S', 'Gen', '2'], ['Fem', 'F', 'Sing', 'S', 'Dat', '3'], ['Fem', 'F', 'Sing', 'S', 'Loc', '6'], ['Fem', 'F', 'Plur', 'P', 'Nom', '1'], ['Fem', 'F', 'Plur', 'P', 'Acc', '4'], ['Fem', 'F', 'Plur', 'P', 'Voc', '5'], ['Neut', 'N', 'Sing', 'S', 'Nom', '1'], ['Neut', 'N', 'Sing', 'S', 'Acc', '4'], ['Neut', 'N', 'Sing', 'S', 'Voc', '5'], ['Neut', 'N', 'Plur', 'P', 'Nom', '1'], ['Neut', 'N', 'Plur', 'P', 'Acc', '4'], ['Neut', 'N', 'Plur', 'P', 'Voc', '5']]],
                'propuščeného' => ['propuštěný', 'propuščený', [['Anim', 'M', 'Sing', 'S', 'Gen', '2'], ['Anim', 'M', 'Sing', 'S', 'Acc', '4'], ['Inan', 'I', 'Sing', 'S', 'Gen', '2'], ['Neut', 'N', 'Sing', 'S', 'Gen', '2']]],
                'propuščenéj'  => ['propuštěný', 'propuščený', [['Fem', 'F', 'Sing', 'S', 'Gen', '2'], ['Fem', 'F', 'Sing', 'S', 'Dat', '3'], ['Fem', 'F', 'Sing', 'S', 'Loc', '6']]],
                'propuščeném'  => ['propuštěný', 'propuščený', [['Anim', 'M', 'Sing', 'S', 'Loc', '6'], ['Inan', 'I', 'Sing', 'S', 'Loc', '6'], ['Neut', 'N', 'Sing', 'S', 'Loc', '6']]],
                'propuščenému' => ['propuštěný', 'propuščený', [['Anim', 'M', 'Sing', 'S', 'Dat', '3'], ['Inan', 'I', 'Sing', 'S', 'Dat', '3'], ['Neut', 'N', 'Sing', 'S', 'Dat', '3']]],
                'propuščení'   => ['propuštěný', 'propuščený', [['Anim', 'M', 'Plur', 'P', 'Nom', '1'], ['Anim', 'M', 'Plur', 'P', 'Voc', '5']]],
                'propuščenou'  => ['propuštěný', 'propuščený', [['Fem', 'F', 'Sing', 'S', 'Acc', '4'], ['Fem', 'F', 'Sing', 'S', 'Ins', '7']]],
                'propuščenú'   => ['propuštěný', 'propuščený', [['Fem', 'F', 'Sing', 'S', 'Acc', '4'], ['Fem', 'F', 'Sing', 'S', 'Ins', '7']]],
                'propuščený'   => ['propuštěný', 'propuščený', [['Anim', 'M', 'Sing', 'S', 'Nom', '1'], ['Anim', 'M', 'Sing', 'S', 'Voc', '5'], ['Inan', 'I', 'Sing', 'S', 'Nom', '1'], ['Inan', 'I', 'Sing', 'S', 'Acc', '4'], ['Inan', 'I', 'Sing', 'S', 'Voc', '5']]],
                'propuščených' => ['propuštěný', 'propuščený', [['Anim', 'M', 'Plur', 'P', 'Gen', '2'], ['Anim', 'M', 'Plur', 'P', 'Loc', '6'], ['Inan', 'I', 'Plur', 'P', 'Gen', '2'], ['Inan', 'I', 'Plur', 'P', 'Loc', '6'], ['Fem', 'F', 'Plur', 'P', 'Gen', '2'], ['Fem', 'F', 'Plur', 'P', 'Loc', '6'], ['Neut', 'N', 'Plur', 'P', 'Gen', '2'], ['Neut', 'N', 'Plur', 'P', 'Loc', '6']]],
                'propuščeným'  => ['propuštěný', 'propuščený', [['Anim', 'M', 'Sing', 'S', 'Ins', '7'], ['Anim', 'M', 'Plur', 'P', 'Dat', '3'], ['Inan', 'I', 'Sing', 'S', 'Ins', '7'], ['Inan', 'I', 'Plur', 'P', 'Dat', '3'], ['Fem', 'F', 'Plur', 'P', 'Dat', '3'], ['Neut', 'N', 'Sing', 'S', 'Ins', '7'], ['Neut', 'N', 'Plur', 'P', 'Dat', '3']]],
                'propuščenými' => ['propuštěný', 'propuščený', [['Anim', 'M', 'Plur', 'P', 'Ins', '7'], ['Inan', 'I', 'Plur', 'P', 'Ins', '7'], ['Fem', 'F', 'Plur', 'P', 'Ins', '7'], ['Neut', 'N', 'Plur', 'P', 'Ins', '7']]],
                'smrtedlná'   => ['smrtelný', 'smrtedlný', [['Fem', 'F', 'Sing', 'S', 'Nom', '1'], ['Fem', 'F', 'Sing', 'S', 'Voc', '5']]],
                'smrtedlné'   => ['smrtelný', 'smrtedlný', [['Anim', 'M', 'Plur', 'P', 'Acc', '4'], ['Inan', 'I', 'Plur', 'P', 'Nom', '1'], ['Inan', 'I', 'Plur', 'P', 'Acc', '4'], ['Inan', 'I', 'Plur', 'P', 'Voc', '5'], ['Fem', 'F', 'Sing', 'S', 'Gen', '2'], ['Fem', 'F', 'Sing', 'S', 'Dat', '3'], ['Fem', 'F', 'Sing', 'S', 'Loc', '6'], ['Fem', 'F', 'Plur', 'P', 'Nom', '1'], ['Fem', 'F', 'Plur', 'P', 'Acc', '4'], ['Fem', 'F', 'Plur', 'P', 'Voc', '5'], ['Neut', 'N', 'Sing', 'S', 'Nom', '1'], ['Neut', 'N', 'Sing', 'S', 'Acc', '4'], ['Neut', 'N', 'Sing', 'S', 'Voc', '5'], ['Neut', 'N', 'Plur', 'P', 'Nom', '1'], ['Neut', 'N', 'Plur', 'P', 'Acc', '4'], ['Neut', 'N', 'Plur', 'P', 'Voc', '5']]],
                'smrtedlného' => ['smrtelný', 'smrtedlný', [['Anim', 'M', 'Sing', 'S', 'Gen', '2'], ['Anim', 'M', 'Sing', 'S', 'Acc', '4'], ['Inan', 'I', 'Sing', 'S', 'Gen', '2'], ['Neut', 'N', 'Sing', 'S', 'Gen', '2']]],
                'smrtedlnéj'  => ['smrtelný', 'smrtedlný', [['Fem', 'F', 'Sing', 'S', 'Gen', '2'], ['Fem', 'F', 'Sing', 'S', 'Dat', '3'], ['Fem', 'F', 'Sing', 'S', 'Loc', '6']]],
                'smrtedlném'  => ['smrtelný', 'smrtedlný', [['Anim', 'M', 'Sing', 'S', 'Loc', '6'], ['Inan', 'I', 'Sing', 'S', 'Loc', '6'], ['Neut', 'N', 'Sing', 'S', 'Loc', '6']]],
                'smrtedlnému' => ['smrtelný', 'smrtedlný', [['Anim', 'M', 'Sing', 'S', 'Dat', '3'], ['Inan', 'I', 'Sing', 'S', 'Dat', '3'], ['Neut', 'N', 'Sing', 'S', 'Dat', '3']]],
                'smrtedlní'   => ['smrtelný', 'smrtedlný', [['Anim', 'M', 'Plur', 'P', 'Nom', '1'], ['Anim', 'M', 'Plur', 'P', 'Voc', '5']]],
                'smrtedlnou'  => ['smrtelný', 'smrtedlný', [['Fem', 'F', 'Sing', 'S', 'Acc', '4'], ['Fem', 'F', 'Sing', 'S', 'Ins', '7']]],
                'smrtedlnú'   => ['smrtelný', 'smrtedlný', [['Fem', 'F', 'Sing', 'S', 'Acc', '4'], ['Fem', 'F', 'Sing', 'S', 'Ins', '7']]],
                'smrtedlný'   => ['smrtelný', 'smrtedlný', [['Anim', 'M', 'Sing', 'S', 'Nom', '1'], ['Anim', 'M', 'Sing', 'S', 'Voc', '5'], ['Inan', 'I', 'Sing', 'S', 'Nom', '1'], ['Inan', 'I', 'Sing', 'S', 'Acc', '4'], ['Inan', 'I', 'Sing', 'S', 'Voc', '5']]],
                'smrtedlných' => ['smrtelný', 'smrtedlný', [['Anim', 'M', 'Plur', 'P', 'Gen', '2'], ['Anim', 'M', 'Plur', 'P', 'Loc', '6'], ['Inan', 'I', 'Plur', 'P', 'Gen', '2'], ['Inan', 'I', 'Plur', 'P', 'Loc', '6'], ['Fem', 'F', 'Plur', 'P', 'Gen', '2'], ['Fem', 'F', 'Plur', 'P', 'Loc', '6'], ['Neut', 'N', 'Plur', 'P', 'Gen', '2'], ['Neut', 'N', 'Plur', 'P', 'Loc', '6']]],
                'smrtedlným'  => ['smrtelný', 'smrtedlný', [['Anim', 'M', 'Sing', 'S', 'Ins', '7'], ['Anim', 'M', 'Plur', 'P', 'Dat', '3'], ['Inan', 'I', 'Sing', 'S', 'Ins', '7'], ['Inan', 'I', 'Plur', 'P', 'Dat', '3'], ['Fem', 'F', 'Plur', 'P', 'Dat', '3'], ['Neut', 'N', 'Sing', 'S', 'Ins', '7'], ['Neut', 'N', 'Plur', 'P', 'Dat', '3']]],
                'smrtedlnými' => ['smrtelný', 'smrtedlný', [['Anim', 'M', 'Plur', 'P', 'Ins', '7'], ['Inan', 'I', 'Plur', 'P', 'Ins', '7'], ['Fem', 'F', 'Plur', 'P', 'Ins', '7'], ['Neut', 'N', 'Plur', 'P', 'Ins', '7']]],
                'velicí'   => ['veliký', 'veliký', [['Anim', 'M', 'Plur', 'P', 'Nom', '1'], ['Anim', 'M', 'Plur', 'P', 'Voc', '5']]],
                'veliká'   => ['veliký', 'veliký', [['Fem', 'F', 'Sing', 'S', 'Nom', '1'], ['Fem', 'F', 'Sing', 'S', 'Voc', '5']]],
                'veliké'   => ['veliký', 'veliký', [['Anim', 'M', 'Plur', 'P', 'Acc', '4'], ['Inan', 'I', 'Plur', 'P', 'Nom', '1'], ['Inan', 'I', 'Plur', 'P', 'Acc', '4'], ['Inan', 'I', 'Plur', 'P', 'Voc', '5'], ['Fem', 'F', 'Sing', 'S', 'Gen', '2'], ['Fem', 'F', 'Sing', 'S', 'Dat', '3'], ['Fem', 'F', 'Sing', 'S', 'Loc', '6'], ['Fem', 'F', 'Plur', 'P', 'Nom', '1'], ['Fem', 'F', 'Plur', 'P', 'Acc', '4'], ['Fem', 'F', 'Plur', 'P', 'Voc', '5'], ['Neut', 'N', 'Sing', 'S', 'Nom', '1'], ['Neut', 'N', 'Sing', 'S', 'Acc', '4'], ['Neut', 'N', 'Sing', 'S', 'Voc', '5'], ['Neut', 'N', 'Plur', 'P', 'Nom', '1'], ['Neut', 'N', 'Plur', 'P', 'Acc', '4'], ['Neut', 'N', 'Plur', 'P', 'Voc', '5']]],
                'velikého' => ['veliký', 'veliký', [['Anim', 'M', 'Sing', 'S', 'Gen', '2'], ['Anim', 'M', 'Sing', 'S', 'Acc', '4'], ['Inan', 'I', 'Sing', 'S', 'Gen', '2'], ['Neut', 'N', 'Sing', 'S', 'Gen', '2']]],
                'velikéj'  => ['veliký', 'veliký', [['Fem', 'F', 'Sing', 'S', 'Gen', '2'], ['Fem', 'F', 'Sing', 'S', 'Dat', '3'], ['Fem', 'F', 'Sing', 'S', 'Loc', '6']]],
                'velikém'  => ['veliký', 'veliký', [['Anim', 'M', 'Sing', 'S', 'Loc', '6'], ['Inan', 'I', 'Sing', 'S', 'Loc', '6'], ['Neut', 'N', 'Sing', 'S', 'Loc', '6']]],
                'velikému' => ['veliký', 'veliký', [['Anim', 'M', 'Sing', 'S', 'Dat', '3'], ['Inan', 'I', 'Sing', 'S', 'Dat', '3'], ['Neut', 'N', 'Sing', 'S', 'Dat', '3']]],
                'velikou'  => ['veliký', 'veliký', [['Fem', 'F', 'Sing', 'S', 'Acc', '4'], ['Fem', 'F', 'Sing', 'S', 'Ins', '7']]],
                'velikú'   => ['veliký', 'veliký', [['Fem', 'F', 'Sing', 'S', 'Acc', '4'], ['Fem', 'F', 'Sing', 'S', 'Ins', '7']]],
                'veliký'   => ['veliký', 'veliký', [['Anim', 'M', 'Sing', 'S', 'Nom', '1'], ['Anim', 'M', 'Sing', 'S', 'Voc', '5'], ['Inan', 'I', 'Sing', 'S', 'Nom', '1'], ['Inan', 'I', 'Sing', 'S', 'Acc', '4'], ['Inan', 'I', 'Sing', 'S', 'Voc', '5']]],
                'velikých' => ['veliký', 'veliký', [['Anim', 'M', 'Plur', 'P', 'Gen', '2'], ['Anim', 'M', 'Plur', 'P', 'Loc', '6'], ['Inan', 'I', 'Plur', 'P', 'Gen', '2'], ['Inan', 'I', 'Plur', 'P', 'Loc', '6'], ['Fem', 'F', 'Plur', 'P', 'Gen', '2'], ['Fem', 'F', 'Plur', 'P', 'Loc', '6'], ['Neut', 'N', 'Plur', 'P', 'Gen', '2'], ['Neut', 'N', 'Plur', 'P', 'Loc', '6']]],
                'velikým'  => ['veliký', 'veliký', [['Anim', 'M', 'Sing', 'S', 'Ins', '7'], ['Anim', 'M', 'Plur', 'P', 'Dat', '3'], ['Inan', 'I', 'Sing', 'S', 'Ins', '7'], ['Inan', 'I', 'Plur', 'P', 'Dat', '3'], ['Fem', 'F', 'Plur', 'P', 'Dat', '3'], ['Neut', 'N', 'Sing', 'S', 'Ins', '7'], ['Neut', 'N', 'Plur', 'P', 'Dat', '3']]],
                'velikými' => ['veliký', 'veliký', [['Anim', 'M', 'Plur', 'P', 'Ins', '7'], ['Inan', 'I', 'Plur', 'P', 'Ins', '7'], ['Fem', 'F', 'Plur', 'P', 'Ins', '7'], ['Neut', 'N', 'Plur', 'P', 'Ins', '7']]],
                'vysocí'   => ['vysoký', 'vysoký', [['Anim', 'M', 'Plur', 'P', 'Nom', '1'], ['Anim', 'M', 'Plur', 'P', 'Voc', '5']]],
                'vysoká'   => ['vysoký', 'vysoký', [['Fem', 'F', 'Sing', 'S', 'Nom', '1'], ['Fem', 'F', 'Sing', 'S', 'Voc', '5']]],
                'vysoké'   => ['vysoký', 'vysoký', [['Anim', 'M', 'Plur', 'P', 'Acc', '4'], ['Inan', 'I', 'Plur', 'P', 'Nom', '1'], ['Inan', 'I', 'Plur', 'P', 'Acc', '4'], ['Inan', 'I', 'Plur', 'P', 'Voc', '5'], ['Fem', 'F', 'Sing', 'S', 'Gen', '2'], ['Fem', 'F', 'Sing', 'S', 'Dat', '3'], ['Fem', 'F', 'Sing', 'S', 'Loc', '6'], ['Fem', 'F', 'Plur', 'P', 'Nom', '1'], ['Fem', 'F', 'Plur', 'P', 'Acc', '4'], ['Fem', 'F', 'Plur', 'P', 'Voc', '5'], ['Neut', 'N', 'Sing', 'S', 'Nom', '1'], ['Neut', 'N', 'Sing', 'S', 'Acc', '4'], ['Neut', 'N', 'Sing', 'S', 'Voc', '5'], ['Neut', 'N', 'Plur', 'P', 'Nom', '1'], ['Neut', 'N', 'Plur', 'P', 'Acc', '4'], ['Neut', 'N', 'Plur', 'P', 'Voc', '5']]],
                'vysokého' => ['vysoký', 'vysoký', [['Anim', 'M', 'Sing', 'S', 'Gen', '2'], ['Anim', 'M', 'Sing', 'S', 'Acc', '4'], ['Inan', 'I', 'Sing', 'S', 'Gen', '2'], ['Neut', 'N', 'Sing', 'S', 'Gen', '2']]],
                'vysokéj'  => ['vysoký', 'vysoký', [['Fem', 'F', 'Sing', 'S', 'Gen', '2'], ['Fem', 'F', 'Sing', 'S', 'Dat', '3'], ['Fem', 'F', 'Sing', 'S', 'Loc', '6']]],
                'vysokém'  => ['vysoký', 'vysoký', [['Anim', 'M', 'Sing', 'S', 'Loc', '6'], ['Inan', 'I', 'Sing', 'S', 'Loc', '6'], ['Neut', 'N', 'Sing', 'S', 'Loc', '6']]],
                'vysokému' => ['vysoký', 'vysoký', [['Anim', 'M', 'Sing', 'S', 'Dat', '3'], ['Inan', 'I', 'Sing', 'S', 'Dat', '3'], ['Neut', 'N', 'Sing', 'S', 'Dat', '3']]],
                'vysokou'  => ['vysoký', 'vysoký', [['Fem', 'F', 'Sing', 'S', 'Acc', '4'], ['Fem', 'F', 'Sing', 'S', 'Ins', '7']]],
                'vysokú'   => ['vysoký', 'vysoký', [['Fem', 'F', 'Sing', 'S', 'Acc', '4'], ['Fem', 'F', 'Sing', 'S', 'Ins', '7']]],
                'vysoký'   => ['vysoký', 'vysoký', [['Anim', 'M', 'Sing', 'S', 'Nom', '1'], ['Anim', 'M', 'Sing', 'S', 'Voc', '5'], ['Inan', 'I', 'Sing', 'S', 'Nom', '1'], ['Inan', 'I', 'Sing', 'S', 'Acc', '4'], ['Inan', 'I', 'Sing', 'S', 'Voc', '5']]],
                'vysokých' => ['vysoký', 'vysoký', [['Anim', 'M', 'Plur', 'P', 'Gen', '2'], ['Anim', 'M', 'Plur', 'P', 'Loc', '6'], ['Inan', 'I', 'Plur', 'P', 'Gen', '2'], ['Inan', 'I', 'Plur', 'P', 'Loc', '6'], ['Fem', 'F', 'Plur', 'P', 'Gen', '2'], ['Fem', 'F', 'Plur', 'P', 'Loc', '6'], ['Neut', 'N', 'Plur', 'P', 'Gen', '2'], ['Neut', 'N', 'Plur', 'P', 'Loc', '6']]],
                'vysokým'  => ['vysoký', 'vysoký', [['Anim', 'M', 'Sing', 'S', 'Ins', '7'], ['Anim', 'M', 'Plur', 'P', 'Dat', '3'], ['Inan', 'I', 'Sing', 'S', 'Ins', '7'], ['Inan', 'I', 'Plur', 'P', 'Dat', '3'], ['Fem', 'F', 'Plur', 'P', 'Dat', '3'], ['Neut', 'N', 'Sing', 'S', 'Ins', '7'], ['Neut', 'N', 'Plur', 'P', 'Dat', '3']]],
                'vysokými' => ['vysoký', 'vysoký', [['Anim', 'M', 'Plur', 'P', 'Ins', '7'], ['Inan', 'I', 'Plur', 'P', 'Ins', '7'], ['Fem', 'F', 'Plur', 'P', 'Ins', '7'], ['Neut', 'N', 'Plur', 'P', 'Ins', '7']]],
                'židovská'   => ['židovský', 'židovský', [['Fem', 'F', 'Sing', 'S', 'Nom', '1'], ['Fem', 'F', 'Sing', 'S', 'Voc', '5']]],
                'židovské'   => ['židovský', 'židovský', [['Anim', 'M', 'Plur', 'P', 'Acc', '4'], ['Inan', 'I', 'Plur', 'P', 'Nom', '1'], ['Inan', 'I', 'Plur', 'P', 'Acc', '4'], ['Inan', 'I', 'Plur', 'P', 'Voc', '5'], ['Fem', 'F', 'Sing', 'S', 'Gen', '2'], ['Fem', 'F', 'Sing', 'S', 'Dat', '3'], ['Fem', 'F', 'Sing', 'S', 'Loc', '6'], ['Fem', 'F', 'Plur', 'P', 'Nom', '1'], ['Fem', 'F', 'Plur', 'P', 'Acc', '4'], ['Fem', 'F', 'Plur', 'P', 'Voc', '5'], ['Neut', 'N', 'Sing', 'S', 'Nom', '1'], ['Neut', 'N', 'Sing', 'S', 'Acc', '4'], ['Neut', 'N', 'Sing', 'S', 'Voc', '5'], ['Neut', 'N', 'Plur', 'P', 'Nom', '1'], ['Neut', 'N', 'Plur', 'P', 'Acc', '4'], ['Neut', 'N', 'Plur', 'P', 'Voc', '5']]],
                'židovského' => ['židovský', 'židovský', [['Anim', 'M', 'Sing', 'S', 'Gen', '2'], ['Anim', 'M', 'Sing', 'S', 'Acc', '4'], ['Inan', 'I', 'Sing', 'S', 'Gen', '2'], ['Neut', 'N', 'Sing', 'S', 'Gen', '2']]],
                'židovskéj'  => ['židovský', 'židovský', [['Fem', 'F', 'Sing', 'S', 'Gen', '2'], ['Fem', 'F', 'Sing', 'S', 'Dat', '3'], ['Fem', 'F', 'Sing', 'S', 'Loc', '6']]],
                'židovském'  => ['židovský', 'židovský', [['Anim', 'M', 'Sing', 'S', 'Loc', '6'], ['Inan', 'I', 'Sing', 'S', 'Loc', '6'], ['Neut', 'N', 'Sing', 'S', 'Loc', '6']]],
                'židovskému' => ['židovský', 'židovský', [['Anim', 'M', 'Sing', 'S', 'Dat', '3'], ['Inan', 'I', 'Sing', 'S', 'Dat', '3'], ['Neut', 'N', 'Sing', 'S', 'Dat', '3']]],
                'židovskou'  => ['židovský', 'židovský', [['Fem', 'F', 'Sing', 'S', 'Acc', '4'], ['Fem', 'F', 'Sing', 'S', 'Ins', '7']]],
                'židovskú'   => ['židovský', 'židovský', [['Fem', 'F', 'Sing', 'S', 'Acc', '4'], ['Fem', 'F', 'Sing', 'S', 'Ins', '7']]],
                'židovský'   => ['židovský', 'židovský', [['Anim', 'M', 'Sing', 'S', 'Nom', '1'], ['Anim', 'M', 'Sing', 'S', 'Voc', '5'], ['Inan', 'I', 'Sing', 'S', 'Nom', '1'], ['Inan', 'I', 'Sing', 'S', 'Acc', '4'], ['Inan', 'I', 'Sing', 'S', 'Voc', '5']]],
                'židovských' => ['židovský', 'židovský', [['Anim', 'M', 'Plur', 'P', 'Gen', '2'], ['Anim', 'M', 'Plur', 'P', 'Loc', '6'], ['Inan', 'I', 'Plur', 'P', 'Gen', '2'], ['Inan', 'I', 'Plur', 'P', 'Loc', '6'], ['Fem', 'F', 'Plur', 'P', 'Gen', '2'], ['Fem', 'F', 'Plur', 'P', 'Loc', '6'], ['Neut', 'N', 'Plur', 'P', 'Gen', '2'], ['Neut', 'N', 'Plur', 'P', 'Loc', '6']]],
                'židovským'  => ['židovský', 'židovský', [['Anim', 'M', 'Sing', 'S', 'Ins', '7'], ['Anim', 'M', 'Plur', 'P', 'Dat', '3'], ['Inan', 'I', 'Sing', 'S', 'Ins', '7'], ['Inan', 'I', 'Plur', 'P', 'Dat', '3'], ['Fem', 'F', 'Plur', 'P', 'Dat', '3'], ['Neut', 'N', 'Sing', 'S', 'Ins', '7'], ['Neut', 'N', 'Plur', 'P', 'Dat', '3']]],
                'židovskými' => ['židovský', 'židovský', [['Anim', 'M', 'Plur', 'P', 'Ins', '7'], ['Inan', 'I', 'Plur', 'P', 'Ins', '7'], ['Fem', 'F', 'Plur', 'P', 'Ins', '7'], ['Neut', 'N', 'Plur', 'P', 'Ins', '7']]],
                'židovští'   => ['židovský', 'židovský', [['Anim', 'M', 'Plur', 'P', 'Nom', '1'], ['Anim', 'M', 'Plur', 'P', 'Voc', '5']]]
            );
            my $ma = $ma{$lform}; die("Something is wrong: '$lform'") if(!defined($ma));
            $f[2] = $ma->[0];
            $f[9] = set_lemma1300($f[9], $ma->[1]);
            $f[3] = 'ADJ';
            # U některých slov umožňujeme několik čtení, ale pokud to není žádné z nich, dáme první jako default.
            my @alt = @{$ma->[2]};
            for(my $i = $#alt; $i >= 0 ; $i--)
            {
                my $animacy = $alt[$i][0] =~ m/^(Anim|Inan)$/ ? $alt[$i][0] : undef;
                my $gender = $alt[$i][0] =~ m/^(Anim|Inan)$/ ? 'Masc' : $alt[$i][0];
                my $number = $alt[$i][2];
                my $case = $alt[$i][4];
                if($i == 0 || defined($alt[$i][6]) && get_ref($f[9]) =~ m/^$alt[$i][6]$/ || !defined($alt[$i][6]) && $f[5] =~ m/Case=$case.*Gender=$gender.*Number=$number/)
                {
                    $f[4] = 'AA'.$alt[$i][1].$alt[$i][3].$alt[$i][5].'----1A----';
                    $f[5] = "Case=$case|Degree=Pos|Gender=$gender|Number=$number|Polarity=Pos";
                    $f[5] = "Animacy=$animacy|$f[5]" if(defined($animacy));
                    last;
                }
            }
        }
        elsif($f[1] =~ m/^(bližn|bu?ož|člověč|jěš(?:če|tě)(?:r|ři)č)(í|ieho|iemu|iem|ím|ie|iej|ích)$/i)
        {
            my $lform = lc($f[1]);
            my %ma =
            (
                'bližní'    => ['bližní', 'bližní', [['Anim', 'M', 'Sing', 'S', 'Nom', '1'], ['Anim', 'M', 'Sing', 'S', 'Voc', '5'], ['Anim', 'M', 'Plur', 'P', 'Nom', '1'], ['Anim', 'M', 'Plur', 'P', 'Acc', '4'], ['Anim', 'M', 'Plur', 'P', 'Voc', '5'], ['Inan', 'I', 'Sing', 'S', 'Nom', '1'], ['Inan', 'I', 'Sing', 'S', 'Acc', '4'], ['Inan', 'I', 'Sing', 'S', 'Voc', '5'], ['Inan', 'I', 'Plur', 'P', 'Nom', '1'], ['Inan', 'I', 'Plur', 'P', 'Acc', '4'], ['Inan', 'I', 'Plur', 'P', 'Voc', '5'], ['Fem', 'F', 'Sing', 'S', 'Nom', '1'], ['Fem', 'F', 'Sing', 'S', 'Gen', '2'], ['Fem', 'F', 'Sing', 'S', 'Dat', '3'], ['Fem', 'F', 'Sing', 'S', 'Acc', '4'], ['Fem', 'F', 'Sing', 'S', 'Voc', '5'], ['Fem', 'F', 'Sing', 'S', 'Loc', '6'], ['Fem', 'F', 'Sing', 'S', 'Ins', '7'], ['Fem', 'F', 'Plur', 'P', 'Nom', '1'], ['Fem', 'F', 'Plur', 'P', 'Acc', '4'], ['Fem', 'F', 'Plur', 'P', 'Voc', '5'], ['Neut', 'N', 'Sing', 'S', 'Nom', '1'], ['Neut', 'N', 'Sing', 'S', 'Acc', '4'], ['Neut', 'N', 'Sing', 'S', 'Voc', '5'], ['Neut', 'N', 'Plur', 'P', 'Nom', '1'], ['Neut', 'N', 'Plur', 'P', 'Acc', '4'], ['Neut', 'N', 'Plur', 'P', 'Voc', '5']]],
                'bližnieho' => ['bližní', 'bližní', [['Anim', 'M', 'Sing', 'S', 'Gen', '2'], ['Anim', 'M', 'Sing', 'S', 'Acc', '4'], ['Inan', 'I', 'Sing', 'S', 'Gen', '2'], ['Neut', 'N', 'Sing', 'S', 'Gen', '2']]],
                'bližniemu' => ['bližní', 'bližní', [['Anim', 'M', 'Sing', 'S', 'Dat', '3'], ['Inan', 'I', 'Sing', 'S', 'Dat', '3'], ['Neut', 'N', 'Sing', 'S', 'Dat', '3']]],
                'bližního'  => ['bližní', 'bližní', [['Anim', 'M', 'Sing', 'S', 'Gen', '2'], ['Anim', 'M', 'Sing', 'S', 'Acc', '4'], ['Inan', 'I', 'Sing', 'S', 'Gen', '2'], ['Neut', 'N', 'Sing', 'S', 'Gen', '2']]],
                'bližních'  => ['bližní', 'bližní', [['Anim', 'M', 'Plur', 'P', 'Gen', '2'], ['Anim', 'M', 'Plur', 'P', 'Loc', '6'], ['Inan', 'I', 'Plur', 'P', 'Gen', '2'], ['Inan', 'I', 'Plur', 'P', 'Loc', '6'], ['Fem', 'F', 'Plur', 'P', 'Gen', '2'], ['Fem', 'F', 'Plur', 'P', 'Loc', '6'], ['Neut', 'N', 'Plur', 'P', 'Gen', '2'], ['Neut', 'N', 'Plur', 'P', 'Loc', '6']]],
                'bližním'   => ['bližní', 'bližní', [['Anim', 'M', 'Sing', 'S', 'Loc', '6'], ['Anim', 'M', 'Sing', 'S', 'Ins', '7'], ['Anim', 'M', 'Plur', 'P', 'Dat', '3'], ['Inan', 'I', 'Sing', 'S', 'Loc', '6'], ['Inan', 'I', 'Sing', 'S', 'Ins', '7'], ['Inan', 'I', 'Plur', 'P', 'Dat', '3'], ['Fem', 'F', 'Plur', 'P', 'Dat', '3'], ['Neut', 'N', 'Sing', 'S', 'Loc', '6'], ['Neut', 'N', 'Sing', 'S', 'Ins', '7'], ['Neut', 'N', 'Plur', 'P', 'Dat', '3']]],
                'bližními'  => ['bližní', 'bližní', [['Anim', 'M', 'Plur', 'P', 'Ins', '7'], ['Inan', 'I', 'Plur', 'P', 'Ins', '7'], ['Fem', 'F', 'Plur', 'P', 'Ins', '7'], ['Neut', 'N', 'Plur', 'P', 'Ins', '7']]],
                'bližnímu'  => ['bližní', 'bližní', [['Anim', 'M', 'Sing', 'S', 'Dat', '3'], ['Inan', 'I', 'Sing', 'S', 'Dat', '3'], ['Neut', 'N', 'Sing', 'S', 'Dat', '3']]],
                'boží'     => ['boží', 'boží', [['Anim', 'M', 'Sing', 'S', 'Nom', '1'], ['Anim', 'M', 'Sing', 'S', 'Voc', '5'], ['Anim', 'M', 'Plur', 'P', 'Nom', '1'], ['Anim', 'M', 'Plur', 'P', 'Acc', '4'], ['Anim', 'M', 'Plur', 'P', 'Voc', '5'], ['Inan', 'I', 'Sing', 'S', 'Nom', '1'], ['Inan', 'I', 'Sing', 'S', 'Acc', '4'], ['Inan', 'I', 'Sing', 'S', 'Voc', '5'], ['Inan', 'I', 'Plur', 'P', 'Nom', '1'], ['Inan', 'I', 'Plur', 'P', 'Acc', '4'], ['Inan', 'I', 'Plur', 'P', 'Voc', '5'], ['Fem', 'F', 'Sing', 'S', 'Nom', '1'], ['Fem', 'F', 'Sing', 'S', 'Gen', '2'], ['Fem', 'F', 'Sing', 'S', 'Dat', '3'], ['Fem', 'F', 'Sing', 'S', 'Acc', '4'], ['Fem', 'F', 'Sing', 'S', 'Voc', '5'], ['Fem', 'F', 'Sing', 'S', 'Loc', '6'], ['Fem', 'F', 'Sing', 'S', 'Ins', '7'], ['Fem', 'F', 'Plur', 'P', 'Nom', '1'], ['Fem', 'F', 'Plur', 'P', 'Acc', '4'], ['Fem', 'F', 'Plur', 'P', 'Voc', '5'], ['Neut', 'N', 'Sing', 'S', 'Nom', '1'], ['Neut', 'N', 'Sing', 'S', 'Acc', '4'], ['Neut', 'N', 'Sing', 'S', 'Voc', '5'], ['Neut', 'N', 'Plur', 'P', 'Nom', '1'], ['Neut', 'N', 'Plur', 'P', 'Acc', '4'], ['Neut', 'N', 'Plur', 'P', 'Voc', '5']]],
                'božie'    => ['boží', 'boží', [['Fem', 'F', 'Sing', 'S', 'Gen', '2'], ['Fem', 'F', 'Plur', 'P', 'Acc', '4'], ['Neut', 'N', 'Sing', 'S', 'Nom', '1'], ['Neut', 'N', 'Sing', 'S', 'Acc', '4']]],
                'božieho'  => ['boží', 'boží', [['Anim', 'M', 'Sing', 'S', 'Gen', '2'], ['Anim', 'M', 'Sing', 'S', 'Acc', '4'], ['Inan', 'I', 'Sing', 'S', 'Gen', '2'], ['Neut', 'N', 'Sing', 'S', 'Gen', '2']]],
                'božiej'   => ['boží', 'boží', [['Fem', 'F', 'Sing', 'S', 'Dat', '3'], ['Fem', 'F', 'Sing', 'S', 'Loc', '6']]],
                'božiem'   => ['boží', 'boží', [['Neut', 'N', 'Sing', 'S', 'Loc', '6']]],
                'božiemu'  => ['boží', 'boží', [['Anim', 'M', 'Sing', 'S', 'Dat', '3'], ['Inan', 'I', 'Sing', 'S', 'Dat', '3'], ['Neut', 'N', 'Sing', 'S', 'Dat', '3']]],
                'božího'   => ['boží', 'boží', [['Anim', 'M', 'Sing', 'S', 'Gen', '2'], ['Anim', 'M', 'Sing', 'S', 'Acc', '4'], ['Inan', 'I', 'Sing', 'S', 'Gen', '2'], ['Neut', 'N', 'Sing', 'S', 'Gen', '2']]],
                'božích'   => ['boží', 'boží', [['Anim', 'M', 'Plur', 'P', 'Gen', '2'], ['Anim', 'M', 'Plur', 'P', 'Loc', '6'], ['Inan', 'I', 'Plur', 'P', 'Gen', '2'], ['Inan', 'I', 'Plur', 'P', 'Loc', '6'], ['Fem', 'F', 'Plur', 'P', 'Gen', '2'], ['Fem', 'F', 'Plur', 'P', 'Loc', '6'], ['Neut', 'N', 'Plur', 'P', 'Gen', '2'], ['Neut', 'N', 'Plur', 'P', 'Loc', '6']]],
                'božím'    => ['boží', 'boží', [['Anim', 'M', 'Sing', 'S', 'Loc', '6'], ['Anim', 'M', 'Sing', 'S', 'Ins', '7'], ['Anim', 'M', 'Plur', 'P', 'Dat', '3'], ['Inan', 'I', 'Sing', 'S', 'Loc', '6'], ['Inan', 'I', 'Sing', 'S', 'Ins', '7'], ['Inan', 'I', 'Plur', 'P', 'Dat', '3'], ['Fem', 'F', 'Plur', 'P', 'Dat', '3'], ['Neut', 'N', 'Sing', 'S', 'Loc', '6'], ['Neut', 'N', 'Sing', 'S', 'Ins', '7'], ['Neut', 'N', 'Plur', 'P', 'Dat', '3']]],
                'božími'   => ['boží', 'boží', [['Anim', 'M', 'Plur', 'P', 'Ins', '7'], ['Inan', 'I', 'Plur', 'P', 'Ins', '7'], ['Fem', 'F', 'Plur', 'P', 'Ins', '7'], ['Neut', 'N', 'Plur', 'P', 'Ins', '7']]],
                'božímu'   => ['boží', 'boží', [['Anim', 'M', 'Sing', 'S', 'Dat', '3'], ['Inan', 'I', 'Sing', 'S', 'Dat', '3'], ['Neut', 'N', 'Sing', 'S', 'Dat', '3']]],
                'božú'     => ['boží', 'boží', [['Fem', 'F', 'Sing', 'S', 'Acc', '4']]],
                'buoží'    => ['boží', 'boží', [['Anim', 'M', 'Sing', 'S', 'Nom', '1'], ['Anim', 'M', 'Sing', 'S', 'Voc', '5'], ['Anim', 'M', 'Plur', 'P', 'Nom', '1'], ['Anim', 'M', 'Plur', 'P', 'Acc', '4'], ['Anim', 'M', 'Plur', 'P', 'Voc', '5'], ['Inan', 'I', 'Sing', 'S', 'Nom', '1'], ['Inan', 'I', 'Sing', 'S', 'Acc', '4'], ['Inan', 'I', 'Sing', 'S', 'Voc', '5'], ['Inan', 'I', 'Plur', 'P', 'Nom', '1'], ['Inan', 'I', 'Plur', 'P', 'Acc', '4'], ['Inan', 'I', 'Plur', 'P', 'Voc', '5'], ['Fem', 'F', 'Sing', 'S', 'Nom', '1'], ['Fem', 'F', 'Sing', 'S', 'Gen', '2'], ['Fem', 'F', 'Sing', 'S', 'Dat', '3'], ['Fem', 'F', 'Sing', 'S', 'Acc', '4'], ['Fem', 'F', 'Sing', 'S', 'Voc', '5'], ['Fem', 'F', 'Sing', 'S', 'Loc', '6'], ['Fem', 'F', 'Sing', 'S', 'Ins', '7'], ['Fem', 'F', 'Plur', 'P', 'Nom', '1'], ['Fem', 'F', 'Plur', 'P', 'Acc', '4'], ['Fem', 'F', 'Plur', 'P', 'Voc', '5'], ['Neut', 'N', 'Sing', 'S', 'Nom', '1'], ['Neut', 'N', 'Sing', 'S', 'Acc', '4'], ['Neut', 'N', 'Sing', 'S', 'Voc', '5'], ['Neut', 'N', 'Plur', 'P', 'Nom', '1'], ['Neut', 'N', 'Plur', 'P', 'Acc', '4'], ['Neut', 'N', 'Plur', 'P', 'Voc', '5']]],
                'buožie'   => ['boží', 'boží', [['Fem', 'F', 'Sing', 'S', 'Gen', '2'], ['Fem', 'F', 'Plur', 'P', 'Acc', '4'], ['Neut', 'N', 'Sing', 'S', 'Nom', '1'], ['Neut', 'N', 'Sing', 'S', 'Acc', '4']]],
                'buožieho' => ['boží', 'boží', [['Anim', 'M', 'Sing', 'S', 'Gen', '2'], ['Anim', 'M', 'Sing', 'S', 'Acc', '4'], ['Inan', 'I', 'Sing', 'S', 'Gen', '2'], ['Neut', 'N', 'Sing', 'S', 'Gen', '2']]],
                'buožiej'  => ['boží', 'boží', [['Fem', 'F', 'Sing', 'S', 'Dat', '3'], ['Fem', 'F', 'Sing', 'S', 'Loc', '6']]],
                'buožiem'  => ['boží', 'boží', [['Neut', 'N', 'Sing', 'S', 'Loc', '6']]],
                'buožiemu' => ['boží', 'boží', [['Anim', 'M', 'Sing', 'S', 'Dat', '3'], ['Inan', 'I', 'Sing', 'S', 'Dat', '3'], ['Neut', 'N', 'Sing', 'S', 'Dat', '3']]],
                'buožího'  => ['boží', 'boží', [['Anim', 'M', 'Sing', 'S', 'Gen', '2'], ['Anim', 'M', 'Sing', 'S', 'Acc', '4'], ['Inan', 'I', 'Sing', 'S', 'Gen', '2'], ['Neut', 'N', 'Sing', 'S', 'Gen', '2']]],
                'buožích'  => ['boží', 'boží', [['Anim', 'M', 'Plur', 'P', 'Gen', '2'], ['Anim', 'M', 'Plur', 'P', 'Loc', '6'], ['Inan', 'I', 'Plur', 'P', 'Gen', '2'], ['Inan', 'I', 'Plur', 'P', 'Loc', '6'], ['Fem', 'F', 'Plur', 'P', 'Gen', '2'], ['Fem', 'F', 'Plur', 'P', 'Loc', '6'], ['Neut', 'N', 'Plur', 'P', 'Gen', '2'], ['Neut', 'N', 'Plur', 'P', 'Loc', '6']]],
                'buožím'   => ['boží', 'boží', [['Anim', 'M', 'Sing', 'S', 'Loc', '6'], ['Anim', 'M', 'Sing', 'S', 'Ins', '7'], ['Anim', 'M', 'Plur', 'P', 'Dat', '3'], ['Inan', 'I', 'Sing', 'S', 'Loc', '6'], ['Inan', 'I', 'Sing', 'S', 'Ins', '7'], ['Inan', 'I', 'Plur', 'P', 'Dat', '3'], ['Fem', 'F', 'Plur', 'P', 'Dat', '3'], ['Neut', 'N', 'Sing', 'S', 'Loc', '6'], ['Neut', 'N', 'Sing', 'S', 'Ins', '7'], ['Neut', 'N', 'Plur', 'P', 'Dat', '3']]],
                'buožími'  => ['boží', 'boží', [['Anim', 'M', 'Plur', 'P', 'Ins', '7'], ['Inan', 'I', 'Plur', 'P', 'Ins', '7'], ['Fem', 'F', 'Plur', 'P', 'Ins', '7'], ['Neut', 'N', 'Plur', 'P', 'Ins', '7']]],
                'buožímu'  => ['boží', 'boží', [['Anim', 'M', 'Sing', 'S', 'Dat', '3'], ['Inan', 'I', 'Sing', 'S', 'Dat', '3'], ['Neut', 'N', 'Sing', 'S', 'Dat', '3']]],
                'buožú'    => ['boží', 'boží', [['Fem', 'F', 'Sing', 'S', 'Acc', '4']]],
                'člověčí'    => ['člověčí', 'člověčí', [['Anim', 'M', 'Sing', 'S', 'Nom', '1'], ['Anim', 'M', 'Sing', 'S', 'Voc', '5'], ['Anim', 'M', 'Plur', 'P', 'Nom', '1'], ['Anim', 'M', 'Plur', 'P', 'Acc', '4'], ['Anim', 'M', 'Plur', 'P', 'Voc', '5'], ['Inan', 'I', 'Sing', 'S', 'Nom', '1'], ['Inan', 'I', 'Sing', 'S', 'Acc', '4'], ['Inan', 'I', 'Sing', 'S', 'Voc', '5'], ['Inan', 'I', 'Plur', 'P', 'Nom', '1'], ['Inan', 'I', 'Plur', 'P', 'Acc', '4'], ['Inan', 'I', 'Plur', 'P', 'Voc', '5'], ['Fem', 'F', 'Sing', 'S', 'Nom', '1'], ['Fem', 'F', 'Sing', 'S', 'Gen', '2'], ['Fem', 'F', 'Sing', 'S', 'Dat', '3'], ['Fem', 'F', 'Sing', 'S', 'Acc', '4'], ['Fem', 'F', 'Sing', 'S', 'Voc', '5'], ['Fem', 'F', 'Sing', 'S', 'Loc', '6'], ['Fem', 'F', 'Sing', 'S', 'Ins', '7'], ['Fem', 'F', 'Plur', 'P', 'Nom', '1'], ['Fem', 'F', 'Plur', 'P', 'Acc', '4'], ['Fem', 'F', 'Plur', 'P', 'Voc', '5'], ['Neut', 'N', 'Sing', 'S', 'Nom', '1'], ['Neut', 'N', 'Sing', 'S', 'Acc', '4'], ['Neut', 'N', 'Sing', 'S', 'Voc', '5'], ['Neut', 'N', 'Plur', 'P', 'Nom', '1'], ['Neut', 'N', 'Plur', 'P', 'Acc', '4'], ['Neut', 'N', 'Plur', 'P', 'Voc', '5']]],
                'člověčie'   => ['člověčí', 'člověčí', [['Fem', 'F', 'Sing', 'S', 'Gen', '2'], ['Fem', 'F', 'Plur', 'P', 'Acc', '4'], ['Neut', 'N', 'Sing', 'S', 'Nom', '1'], ['Neut', 'N', 'Sing', 'S', 'Acc', '4']]],
                'člověčieho' => ['člověčí', 'člověčí', [['Anim', 'M', 'Sing', 'S', 'Gen', '2'], ['Anim', 'M', 'Sing', 'S', 'Acc', '4'], ['Inan', 'I', 'Sing', 'S', 'Gen', '2'], ['Neut', 'N', 'Sing', 'S', 'Gen', '2']]],
                'člověčiej'  => ['člověčí', 'člověčí', [['Fem', 'F', 'Sing', 'S', 'Dat', '3'], ['Fem', 'F', 'Sing', 'S', 'Loc', '6']]],
                'člověčiem'  => ['člověčí', 'člověčí', [['Neut', 'N', 'Sing', 'S', 'Loc', '6']]],
                'člověčiemu' => ['člověčí', 'člověčí', [['Anim', 'M', 'Sing', 'S', 'Dat', '3'], ['Inan', 'I', 'Sing', 'S', 'Dat', '3'], ['Neut', 'N', 'Sing', 'S', 'Dat', '3']]],
                'člověčího'  => ['člověčí', 'člověčí', [['Anim', 'M', 'Sing', 'S', 'Gen', '2'], ['Anim', 'M', 'Sing', 'S', 'Acc', '4'], ['Inan', 'I', 'Sing', 'S', 'Gen', '2'], ['Neut', 'N', 'Sing', 'S', 'Gen', '2']]],
                'člověčích'  => ['člověčí', 'člověčí', [['Anim', 'M', 'Plur', 'P', 'Gen', '2'], ['Anim', 'M', 'Plur', 'P', 'Loc', '6'], ['Inan', 'I', 'Plur', 'P', 'Gen', '2'], ['Inan', 'I', 'Plur', 'P', 'Loc', '6'], ['Fem', 'F', 'Plur', 'P', 'Gen', '2'], ['Fem', 'F', 'Plur', 'P', 'Loc', '6'], ['Neut', 'N', 'Plur', 'P', 'Gen', '2'], ['Neut', 'N', 'Plur', 'P', 'Loc', '6']]],
                'člověčím'   => ['člověčí', 'člověčí', [['Anim', 'M', 'Sing', 'S', 'Loc', '6'], ['Anim', 'M', 'Sing', 'S', 'Ins', '7'], ['Anim', 'M', 'Plur', 'P', 'Dat', '3'], ['Inan', 'I', 'Sing', 'S', 'Loc', '6'], ['Inan', 'I', 'Sing', 'S', 'Ins', '7'], ['Inan', 'I', 'Plur', 'P', 'Dat', '3'], ['Fem', 'F', 'Plur', 'P', 'Dat', '3'], ['Neut', 'N', 'Sing', 'S', 'Loc', '6'], ['Neut', 'N', 'Sing', 'S', 'Ins', '7'], ['Neut', 'N', 'Plur', 'P', 'Dat', '3']]],
                'člověčími'  => ['člověčí', 'člověčí', [['Anim', 'M', 'Plur', 'P', 'Ins', '7'], ['Inan', 'I', 'Plur', 'P', 'Ins', '7'], ['Fem', 'F', 'Plur', 'P', 'Ins', '7'], ['Neut', 'N', 'Plur', 'P', 'Ins', '7']]],
                'člověčímu'  => ['člověčí', 'člověčí', [['Anim', 'M', 'Sing', 'S', 'Dat', '3'], ['Inan', 'I', 'Sing', 'S', 'Dat', '3'], ['Neut', 'N', 'Sing', 'S', 'Dat', '3']]],
                'člověčú'    => ['člověčí', 'člověčí', [['Fem', 'F', 'Sing', 'S', 'Acc', '4']]],
                'ješčerčí'     => ['ještěrčí', 'ješčeřičí', [['Anim', 'M', 'Sing', 'S', 'Nom', '1'], ['Anim', 'M', 'Sing', 'S', 'Voc', '5'], ['Anim', 'M', 'Plur', 'P', 'Nom', '1'], ['Anim', 'M', 'Plur', 'P', 'Acc', '4'], ['Anim', 'M', 'Plur', 'P', 'Voc', '5'], ['Inan', 'I', 'Sing', 'S', 'Nom', '1'], ['Inan', 'I', 'Sing', 'S', 'Acc', '4'], ['Inan', 'I', 'Sing', 'S', 'Voc', '5'], ['Inan', 'I', 'Plur', 'P', 'Nom', '1'], ['Inan', 'I', 'Plur', 'P', 'Acc', '4'], ['Inan', 'I', 'Plur', 'P', 'Voc', '5'], ['Fem', 'F', 'Sing', 'S', 'Nom', '1'], ['Fem', 'F', 'Sing', 'S', 'Gen', '2'], ['Fem', 'F', 'Sing', 'S', 'Dat', '3'], ['Fem', 'F', 'Sing', 'S', 'Acc', '4'], ['Fem', 'F', 'Sing', 'S', 'Voc', '5'], ['Fem', 'F', 'Sing', 'S', 'Loc', '6'], ['Fem', 'F', 'Sing', 'S', 'Ins', '7'], ['Fem', 'F', 'Plur', 'P', 'Nom', '1'], ['Fem', 'F', 'Plur', 'P', 'Acc', '4'], ['Fem', 'F', 'Plur', 'P', 'Voc', '5'], ['Neut', 'N', 'Sing', 'S', 'Nom', '1'], ['Neut', 'N', 'Sing', 'S', 'Acc', '4'], ['Neut', 'N', 'Sing', 'S', 'Voc', '5'], ['Neut', 'N', 'Plur', 'P', 'Nom', '1'], ['Neut', 'N', 'Plur', 'P', 'Acc', '4'], ['Neut', 'N', 'Plur', 'P', 'Voc', '5']]],
                'jěščerčí'     => ['ještěrčí', 'ješčeřičí', [['Anim', 'M', 'Sing', 'S', 'Nom', '1'], ['Anim', 'M', 'Sing', 'S', 'Voc', '5'], ['Anim', 'M', 'Plur', 'P', 'Nom', '1'], ['Anim', 'M', 'Plur', 'P', 'Acc', '4'], ['Anim', 'M', 'Plur', 'P', 'Voc', '5'], ['Inan', 'I', 'Sing', 'S', 'Nom', '1'], ['Inan', 'I', 'Sing', 'S', 'Acc', '4'], ['Inan', 'I', 'Sing', 'S', 'Voc', '5'], ['Inan', 'I', 'Plur', 'P', 'Nom', '1'], ['Inan', 'I', 'Plur', 'P', 'Acc', '4'], ['Inan', 'I', 'Plur', 'P', 'Voc', '5'], ['Fem', 'F', 'Sing', 'S', 'Nom', '1'], ['Fem', 'F', 'Sing', 'S', 'Gen', '2'], ['Fem', 'F', 'Sing', 'S', 'Dat', '3'], ['Fem', 'F', 'Sing', 'S', 'Acc', '4'], ['Fem', 'F', 'Sing', 'S', 'Voc', '5'], ['Fem', 'F', 'Sing', 'S', 'Loc', '6'], ['Fem', 'F', 'Sing', 'S', 'Ins', '7'], ['Fem', 'F', 'Plur', 'P', 'Nom', '1'], ['Fem', 'F', 'Plur', 'P', 'Acc', '4'], ['Fem', 'F', 'Plur', 'P', 'Voc', '5'], ['Neut', 'N', 'Sing', 'S', 'Nom', '1'], ['Neut', 'N', 'Sing', 'S', 'Acc', '4'], ['Neut', 'N', 'Sing', 'S', 'Voc', '5'], ['Neut', 'N', 'Plur', 'P', 'Nom', '1'], ['Neut', 'N', 'Plur', 'P', 'Acc', '4'], ['Neut', 'N', 'Plur', 'P', 'Voc', '5']]],
                'ješčerčie'    => ['ještěrčí', 'ješčeřičí', [['Fem', 'F', 'Sing', 'S', 'Gen', '2'], ['Fem', 'F', 'Plur', 'P', 'Acc', '4'], ['Neut', 'N', 'Sing', 'S', 'Nom', '1'], ['Neut', 'N', 'Sing', 'S', 'Acc', '4']]],
                'jěščerčie'    => ['ještěrčí', 'ješčeřičí', [['Fem', 'F', 'Sing', 'S', 'Gen', '2'], ['Fem', 'F', 'Plur', 'P', 'Acc', '4'], ['Neut', 'N', 'Sing', 'S', 'Nom', '1'], ['Neut', 'N', 'Sing', 'S', 'Acc', '4']]],
                'ješčerčieho'  => ['ještěrčí', 'ješčeřičí', [['Anim', 'M', 'Sing', 'S', 'Gen', '2'], ['Anim', 'M', 'Sing', 'S', 'Acc', '4'], ['Inan', 'I', 'Sing', 'S', 'Gen', '2'], ['Neut', 'N', 'Sing', 'S', 'Gen', '2']]],
                'jěščerčieho'  => ['ještěrčí', 'ješčeřičí', [['Anim', 'M', 'Sing', 'S', 'Gen', '2'], ['Anim', 'M', 'Sing', 'S', 'Acc', '4'], ['Inan', 'I', 'Sing', 'S', 'Gen', '2'], ['Neut', 'N', 'Sing', 'S', 'Gen', '2']]],
                'ješčerčiej'   => ['ještěrčí', 'ješčeřičí', [['Fem', 'F', 'Sing', 'S', 'Dat', '3'], ['Fem', 'F', 'Sing', 'S', 'Loc', '6']]],
                'jěščerčiej'   => ['ještěrčí', 'ješčeřičí', [['Fem', 'F', 'Sing', 'S', 'Dat', '3'], ['Fem', 'F', 'Sing', 'S', 'Loc', '6']]],
                'ješčerčiem'   => ['ještěrčí', 'ješčeřičí', [['Neut', 'N', 'Sing', 'S', 'Loc', '6']]],
                'jěščerčiem'   => ['ještěrčí', 'ješčeřičí', [['Neut', 'N', 'Sing', 'S', 'Loc', '6']]],
                'ješčerčiemu'  => ['ještěrčí', 'ješčeřičí', [['Anim', 'M', 'Sing', 'S', 'Dat', '3'], ['Inan', 'I', 'Sing', 'S', 'Dat', '3'], ['Neut', 'N', 'Sing', 'S', 'Dat', '3']]],
                'jěščerčiemu'  => ['ještěrčí', 'ješčeřičí', [['Anim', 'M', 'Sing', 'S', 'Dat', '3'], ['Inan', 'I', 'Sing', 'S', 'Dat', '3'], ['Neut', 'N', 'Sing', 'S', 'Dat', '3']]],
                'ješčerčího'   => ['ještěrčí', 'ješčeřičí', [['Anim', 'M', 'Sing', 'S', 'Gen', '2'], ['Anim', 'M', 'Sing', 'S', 'Acc', '4'], ['Inan', 'I', 'Sing', 'S', 'Gen', '2'], ['Neut', 'N', 'Sing', 'S', 'Gen', '2']]],
                'jěščerčího'   => ['ještěrčí', 'ješčeřičí', [['Anim', 'M', 'Sing', 'S', 'Gen', '2'], ['Anim', 'M', 'Sing', 'S', 'Acc', '4'], ['Inan', 'I', 'Sing', 'S', 'Gen', '2'], ['Neut', 'N', 'Sing', 'S', 'Gen', '2']]],
                'ješčerčích'   => ['ještěrčí', 'ješčeřičí', [['Anim', 'M', 'Plur', 'P', 'Gen', '2'], ['Anim', 'M', 'Plur', 'P', 'Loc', '6'], ['Inan', 'I', 'Plur', 'P', 'Gen', '2'], ['Inan', 'I', 'Plur', 'P', 'Loc', '6'], ['Fem', 'F', 'Plur', 'P', 'Gen', '2'], ['Fem', 'F', 'Plur', 'P', 'Loc', '6'], ['Neut', 'N', 'Plur', 'P', 'Gen', '2'], ['Neut', 'N', 'Plur', 'P', 'Loc', '6']]],
                'jěščerčích'   => ['ještěrčí', 'ješčeřičí', [['Anim', 'M', 'Plur', 'P', 'Gen', '2'], ['Anim', 'M', 'Plur', 'P', 'Loc', '6'], ['Inan', 'I', 'Plur', 'P', 'Gen', '2'], ['Inan', 'I', 'Plur', 'P', 'Loc', '6'], ['Fem', 'F', 'Plur', 'P', 'Gen', '2'], ['Fem', 'F', 'Plur', 'P', 'Loc', '6'], ['Neut', 'N', 'Plur', 'P', 'Gen', '2'], ['Neut', 'N', 'Plur', 'P', 'Loc', '6']]],
                'ješčerčím'    => ['ještěrčí', 'ješčeřičí', [['Anim', 'M', 'Sing', 'S', 'Loc', '6'], ['Anim', 'M', 'Sing', 'S', 'Ins', '7'], ['Anim', 'M', 'Plur', 'P', 'Dat', '3'], ['Inan', 'I', 'Sing', 'S', 'Loc', '6'], ['Inan', 'I', 'Sing', 'S', 'Ins', '7'], ['Inan', 'I', 'Plur', 'P', 'Dat', '3'], ['Fem', 'F', 'Plur', 'P', 'Dat', '3'], ['Neut', 'N', 'Sing', 'S', 'Loc', '6'], ['Neut', 'N', 'Sing', 'S', 'Ins', '7'], ['Neut', 'N', 'Plur', 'P', 'Dat', '3']]],
                'jěščerčím'    => ['ještěrčí', 'ješčeřičí', [['Anim', 'M', 'Sing', 'S', 'Loc', '6'], ['Anim', 'M', 'Sing', 'S', 'Ins', '7'], ['Anim', 'M', 'Plur', 'P', 'Dat', '3'], ['Inan', 'I', 'Sing', 'S', 'Loc', '6'], ['Inan', 'I', 'Sing', 'S', 'Ins', '7'], ['Inan', 'I', 'Plur', 'P', 'Dat', '3'], ['Fem', 'F', 'Plur', 'P', 'Dat', '3'], ['Neut', 'N', 'Sing', 'S', 'Loc', '6'], ['Neut', 'N', 'Sing', 'S', 'Ins', '7'], ['Neut', 'N', 'Plur', 'P', 'Dat', '3']]],
                'ješčerčími'   => ['ještěrčí', 'ješčeřičí', [['Anim', 'M', 'Plur', 'P', 'Ins', '7'], ['Inan', 'I', 'Plur', 'P', 'Ins', '7'], ['Fem', 'F', 'Plur', 'P', 'Ins', '7'], ['Neut', 'N', 'Plur', 'P', 'Ins', '7']]],
                'jěščerčími'   => ['ještěrčí', 'ješčeřičí', [['Anim', 'M', 'Plur', 'P', 'Ins', '7'], ['Inan', 'I', 'Plur', 'P', 'Ins', '7'], ['Fem', 'F', 'Plur', 'P', 'Ins', '7'], ['Neut', 'N', 'Plur', 'P', 'Ins', '7']]],
                'ješčerčímu'   => ['ještěrčí', 'ješčeřičí', [['Anim', 'M', 'Sing', 'S', 'Dat', '3'], ['Inan', 'I', 'Sing', 'S', 'Dat', '3'], ['Neut', 'N', 'Sing', 'S', 'Dat', '3']]],
                'jěščerčímu'   => ['ještěrčí', 'ješčeřičí', [['Anim', 'M', 'Sing', 'S', 'Dat', '3'], ['Inan', 'I', 'Sing', 'S', 'Dat', '3'], ['Neut', 'N', 'Sing', 'S', 'Dat', '3']]],
                'ješčerčú'     => ['ještěrčí', 'ješčeřičí', [['Fem', 'F', 'Sing', 'S', 'Acc', '4']]],
                'jěščerčú'     => ['ještěrčí', 'ješčeřičí', [['Fem', 'F', 'Sing', 'S', 'Acc', '4']]],
                'ješčeřičí'    => ['ještěrčí', 'ješčeřičí', [['Anim', 'M', 'Sing', 'S', 'Nom', '1'], ['Anim', 'M', 'Sing', 'S', 'Voc', '5'], ['Anim', 'M', 'Plur', 'P', 'Nom', '1'], ['Anim', 'M', 'Plur', 'P', 'Acc', '4'], ['Anim', 'M', 'Plur', 'P', 'Voc', '5'], ['Inan', 'I', 'Sing', 'S', 'Nom', '1'], ['Inan', 'I', 'Sing', 'S', 'Acc', '4'], ['Inan', 'I', 'Sing', 'S', 'Voc', '5'], ['Inan', 'I', 'Plur', 'P', 'Nom', '1'], ['Inan', 'I', 'Plur', 'P', 'Acc', '4'], ['Inan', 'I', 'Plur', 'P', 'Voc', '5'], ['Fem', 'F', 'Sing', 'S', 'Nom', '1'], ['Fem', 'F', 'Sing', 'S', 'Gen', '2'], ['Fem', 'F', 'Sing', 'S', 'Dat', '3'], ['Fem', 'F', 'Sing', 'S', 'Acc', '4'], ['Fem', 'F', 'Sing', 'S', 'Voc', '5'], ['Fem', 'F', 'Sing', 'S', 'Loc', '6'], ['Fem', 'F', 'Sing', 'S', 'Ins', '7'], ['Fem', 'F', 'Plur', 'P', 'Nom', '1'], ['Fem', 'F', 'Plur', 'P', 'Acc', '4'], ['Fem', 'F', 'Plur', 'P', 'Voc', '5'], ['Neut', 'N', 'Sing', 'S', 'Nom', '1'], ['Neut', 'N', 'Sing', 'S', 'Acc', '4'], ['Neut', 'N', 'Sing', 'S', 'Voc', '5'], ['Neut', 'N', 'Plur', 'P', 'Nom', '1'], ['Neut', 'N', 'Plur', 'P', 'Acc', '4'], ['Neut', 'N', 'Plur', 'P', 'Voc', '5']]],
                'jěščeřičí'    => ['ještěrčí', 'ješčeřičí', [['Anim', 'M', 'Sing', 'S', 'Nom', '1'], ['Anim', 'M', 'Sing', 'S', 'Voc', '5'], ['Anim', 'M', 'Plur', 'P', 'Nom', '1'], ['Anim', 'M', 'Plur', 'P', 'Acc', '4'], ['Anim', 'M', 'Plur', 'P', 'Voc', '5'], ['Inan', 'I', 'Sing', 'S', 'Nom', '1'], ['Inan', 'I', 'Sing', 'S', 'Acc', '4'], ['Inan', 'I', 'Sing', 'S', 'Voc', '5'], ['Inan', 'I', 'Plur', 'P', 'Nom', '1'], ['Inan', 'I', 'Plur', 'P', 'Acc', '4'], ['Inan', 'I', 'Plur', 'P', 'Voc', '5'], ['Fem', 'F', 'Sing', 'S', 'Nom', '1'], ['Fem', 'F', 'Sing', 'S', 'Gen', '2'], ['Fem', 'F', 'Sing', 'S', 'Dat', '3'], ['Fem', 'F', 'Sing', 'S', 'Acc', '4'], ['Fem', 'F', 'Sing', 'S', 'Voc', '5'], ['Fem', 'F', 'Sing', 'S', 'Loc', '6'], ['Fem', 'F', 'Sing', 'S', 'Ins', '7'], ['Fem', 'F', 'Plur', 'P', 'Nom', '1'], ['Fem', 'F', 'Plur', 'P', 'Acc', '4'], ['Fem', 'F', 'Plur', 'P', 'Voc', '5'], ['Neut', 'N', 'Sing', 'S', 'Nom', '1'], ['Neut', 'N', 'Sing', 'S', 'Acc', '4'], ['Neut', 'N', 'Sing', 'S', 'Voc', '5'], ['Neut', 'N', 'Plur', 'P', 'Nom', '1'], ['Neut', 'N', 'Plur', 'P', 'Acc', '4'], ['Neut', 'N', 'Plur', 'P', 'Voc', '5']]],
                'ješčeřičie'   => ['ještěrčí', 'ješčeřičí', [['Fem', 'F', 'Sing', 'S', 'Gen', '2'], ['Fem', 'F', 'Plur', 'P', 'Acc', '4'], ['Neut', 'N', 'Sing', 'S', 'Nom', '1'], ['Neut', 'N', 'Sing', 'S', 'Acc', '4']]],
                'jěščeřičie'   => ['ještěrčí', 'ješčeřičí', [['Fem', 'F', 'Sing', 'S', 'Gen', '2'], ['Fem', 'F', 'Plur', 'P', 'Acc', '4'], ['Neut', 'N', 'Sing', 'S', 'Nom', '1'], ['Neut', 'N', 'Sing', 'S', 'Acc', '4']]],
                'ješčeřičieho' => ['ještěrčí', 'ješčeřičí', [['Anim', 'M', 'Sing', 'S', 'Gen', '2'], ['Anim', 'M', 'Sing', 'S', 'Acc', '4'], ['Inan', 'I', 'Sing', 'S', 'Gen', '2'], ['Neut', 'N', 'Sing', 'S', 'Gen', '2']]],
                'jěščeřičieho' => ['ještěrčí', 'ješčeřičí', [['Anim', 'M', 'Sing', 'S', 'Gen', '2'], ['Anim', 'M', 'Sing', 'S', 'Acc', '4'], ['Inan', 'I', 'Sing', 'S', 'Gen', '2'], ['Neut', 'N', 'Sing', 'S', 'Gen', '2']]],
                'ješčeřičiej'  => ['ještěrčí', 'ješčeřičí', [['Fem', 'F', 'Sing', 'S', 'Dat', '3'], ['Fem', 'F', 'Sing', 'S', 'Loc', '6']]],
                'jěščeřičiej'  => ['ještěrčí', 'ješčeřičí', [['Fem', 'F', 'Sing', 'S', 'Dat', '3'], ['Fem', 'F', 'Sing', 'S', 'Loc', '6']]],
                'ješčeřičiem'  => ['ještěrčí', 'ješčeřičí', [['Neut', 'N', 'Sing', 'S', 'Loc', '6']]],
                'jěščeřičiem'  => ['ještěrčí', 'ješčeřičí', [['Neut', 'N', 'Sing', 'S', 'Loc', '6']]],
                'ješčeřičiemu' => ['ještěrčí', 'ješčeřičí', [['Anim', 'M', 'Sing', 'S', 'Dat', '3'], ['Inan', 'I', 'Sing', 'S', 'Dat', '3'], ['Neut', 'N', 'Sing', 'S', 'Dat', '3']]],
                'jěščeřičiemu' => ['ještěrčí', 'ješčeřičí', [['Anim', 'M', 'Sing', 'S', 'Dat', '3'], ['Inan', 'I', 'Sing', 'S', 'Dat', '3'], ['Neut', 'N', 'Sing', 'S', 'Dat', '3']]],
                'ješčeřičího'  => ['ještěrčí', 'ješčeřičí', [['Anim', 'M', 'Sing', 'S', 'Gen', '2'], ['Anim', 'M', 'Sing', 'S', 'Acc', '4'], ['Inan', 'I', 'Sing', 'S', 'Gen', '2'], ['Neut', 'N', 'Sing', 'S', 'Gen', '2']]],
                'jěščeřičího'  => ['ještěrčí', 'ješčeřičí', [['Anim', 'M', 'Sing', 'S', 'Gen', '2'], ['Anim', 'M', 'Sing', 'S', 'Acc', '4'], ['Inan', 'I', 'Sing', 'S', 'Gen', '2'], ['Neut', 'N', 'Sing', 'S', 'Gen', '2']]],
                'ješčeřičích'  => ['ještěrčí', 'ješčeřičí', [['Anim', 'M', 'Plur', 'P', 'Gen', '2'], ['Anim', 'M', 'Plur', 'P', 'Loc', '6'], ['Inan', 'I', 'Plur', 'P', 'Gen', '2'], ['Inan', 'I', 'Plur', 'P', 'Loc', '6'], ['Fem', 'F', 'Plur', 'P', 'Gen', '2'], ['Fem', 'F', 'Plur', 'P', 'Loc', '6'], ['Neut', 'N', 'Plur', 'P', 'Gen', '2'], ['Neut', 'N', 'Plur', 'P', 'Loc', '6']]],
                'jěščeřičích'  => ['ještěrčí', 'ješčeřičí', [['Anim', 'M', 'Plur', 'P', 'Gen', '2'], ['Anim', 'M', 'Plur', 'P', 'Loc', '6'], ['Inan', 'I', 'Plur', 'P', 'Gen', '2'], ['Inan', 'I', 'Plur', 'P', 'Loc', '6'], ['Fem', 'F', 'Plur', 'P', 'Gen', '2'], ['Fem', 'F', 'Plur', 'P', 'Loc', '6'], ['Neut', 'N', 'Plur', 'P', 'Gen', '2'], ['Neut', 'N', 'Plur', 'P', 'Loc', '6']]],
                'ješčeřičím'   => ['ještěrčí', 'ješčeřičí', [['Anim', 'M', 'Sing', 'S', 'Loc', '6'], ['Anim', 'M', 'Sing', 'S', 'Ins', '7'], ['Anim', 'M', 'Plur', 'P', 'Dat', '3'], ['Inan', 'I', 'Sing', 'S', 'Loc', '6'], ['Inan', 'I', 'Sing', 'S', 'Ins', '7'], ['Inan', 'I', 'Plur', 'P', 'Dat', '3'], ['Fem', 'F', 'Plur', 'P', 'Dat', '3'], ['Neut', 'N', 'Sing', 'S', 'Loc', '6'], ['Neut', 'N', 'Sing', 'S', 'Ins', '7'], ['Neut', 'N', 'Plur', 'P', 'Dat', '3']]],
                'jěščeřičím'   => ['ještěrčí', 'ješčeřičí', [['Anim', 'M', 'Sing', 'S', 'Loc', '6'], ['Anim', 'M', 'Sing', 'S', 'Ins', '7'], ['Anim', 'M', 'Plur', 'P', 'Dat', '3'], ['Inan', 'I', 'Sing', 'S', 'Loc', '6'], ['Inan', 'I', 'Sing', 'S', 'Ins', '7'], ['Inan', 'I', 'Plur', 'P', 'Dat', '3'], ['Fem', 'F', 'Plur', 'P', 'Dat', '3'], ['Neut', 'N', 'Sing', 'S', 'Loc', '6'], ['Neut', 'N', 'Sing', 'S', 'Ins', '7'], ['Neut', 'N', 'Plur', 'P', 'Dat', '3']]],
                'ješčeřičími'  => ['ještěrčí', 'ješčeřičí', [['Anim', 'M', 'Plur', 'P', 'Ins', '7'], ['Inan', 'I', 'Plur', 'P', 'Ins', '7'], ['Fem', 'F', 'Plur', 'P', 'Ins', '7'], ['Neut', 'N', 'Plur', 'P', 'Ins', '7']]],
                'jěščeřičími'  => ['ještěrčí', 'ješčeřičí', [['Anim', 'M', 'Plur', 'P', 'Ins', '7'], ['Inan', 'I', 'Plur', 'P', 'Ins', '7'], ['Fem', 'F', 'Plur', 'P', 'Ins', '7'], ['Neut', 'N', 'Plur', 'P', 'Ins', '7']]],
                'ješčeřičímu'  => ['ještěrčí', 'ješčeřičí', [['Anim', 'M', 'Sing', 'S', 'Dat', '3'], ['Inan', 'I', 'Sing', 'S', 'Dat', '3'], ['Neut', 'N', 'Sing', 'S', 'Dat', '3']]],
                'jěščeřičímu'  => ['ještěrčí', 'ješčeřičí', [['Anim', 'M', 'Sing', 'S', 'Dat', '3'], ['Inan', 'I', 'Sing', 'S', 'Dat', '3'], ['Neut', 'N', 'Sing', 'S', 'Dat', '3']]],
                'ješčeřičú'    => ['ještěrčí', 'ješčeřičí', [['Fem', 'F', 'Sing', 'S', 'Acc', '4']]],
                'jěščeřičú'    => ['ještěrčí', 'ješčeřičí', [['Fem', 'F', 'Sing', 'S', 'Acc', '4']]],
                'ještěrčí'     => ['ještěrčí', 'ješčeřičí', [['Anim', 'M', 'Sing', 'S', 'Nom', '1'], ['Anim', 'M', 'Sing', 'S', 'Voc', '5'], ['Anim', 'M', 'Plur', 'P', 'Nom', '1'], ['Anim', 'M', 'Plur', 'P', 'Acc', '4'], ['Anim', 'M', 'Plur', 'P', 'Voc', '5'], ['Inan', 'I', 'Sing', 'S', 'Nom', '1'], ['Inan', 'I', 'Sing', 'S', 'Acc', '4'], ['Inan', 'I', 'Sing', 'S', 'Voc', '5'], ['Inan', 'I', 'Plur', 'P', 'Nom', '1'], ['Inan', 'I', 'Plur', 'P', 'Acc', '4'], ['Inan', 'I', 'Plur', 'P', 'Voc', '5'], ['Fem', 'F', 'Sing', 'S', 'Nom', '1'], ['Fem', 'F', 'Sing', 'S', 'Gen', '2'], ['Fem', 'F', 'Sing', 'S', 'Dat', '3'], ['Fem', 'F', 'Sing', 'S', 'Acc', '4'], ['Fem', 'F', 'Sing', 'S', 'Voc', '5'], ['Fem', 'F', 'Sing', 'S', 'Loc', '6'], ['Fem', 'F', 'Sing', 'S', 'Ins', '7'], ['Fem', 'F', 'Plur', 'P', 'Nom', '1'], ['Fem', 'F', 'Plur', 'P', 'Acc', '4'], ['Fem', 'F', 'Plur', 'P', 'Voc', '5'], ['Neut', 'N', 'Sing', 'S', 'Nom', '1'], ['Neut', 'N', 'Sing', 'S', 'Acc', '4'], ['Neut', 'N', 'Sing', 'S', 'Voc', '5'], ['Neut', 'N', 'Plur', 'P', 'Nom', '1'], ['Neut', 'N', 'Plur', 'P', 'Acc', '4'], ['Neut', 'N', 'Plur', 'P', 'Voc', '5']]],
                'ještěrčie'    => ['ještěrčí', 'ješčeřičí', [['Fem', 'F', 'Sing', 'S', 'Gen', '2'], ['Fem', 'F', 'Plur', 'P', 'Acc', '4'], ['Neut', 'N', 'Sing', 'S', 'Nom', '1'], ['Neut', 'N', 'Sing', 'S', 'Acc', '4']]],
                'ještěrčieho'  => ['ještěrčí', 'ješčeřičí', [['Anim', 'M', 'Sing', 'S', 'Gen', '2'], ['Anim', 'M', 'Sing', 'S', 'Acc', '4'], ['Inan', 'I', 'Sing', 'S', 'Gen', '2'], ['Neut', 'N', 'Sing', 'S', 'Gen', '2']]],
                'ještěrčiej'   => ['ještěrčí', 'ješčeřičí', [['Fem', 'F', 'Sing', 'S', 'Dat', '3'], ['Fem', 'F', 'Sing', 'S', 'Loc', '6']]],
                'ještěrčiem'   => ['ještěrčí', 'ješčeřičí', [['Neut', 'N', 'Sing', 'S', 'Loc', '6']]],
                'ještěrčiemu'  => ['ještěrčí', 'ješčeřičí', [['Anim', 'M', 'Sing', 'S', 'Dat', '3'], ['Inan', 'I', 'Sing', 'S', 'Dat', '3'], ['Neut', 'N', 'Sing', 'S', 'Dat', '3']]],
                'ještěrčího'   => ['ještěrčí', 'ješčeřičí', [['Anim', 'M', 'Sing', 'S', 'Gen', '2'], ['Anim', 'M', 'Sing', 'S', 'Acc', '4'], ['Inan', 'I', 'Sing', 'S', 'Gen', '2'], ['Neut', 'N', 'Sing', 'S', 'Gen', '2']]],
                'ještěrčích'   => ['ještěrčí', 'ješčeřičí', [['Anim', 'M', 'Plur', 'P', 'Gen', '2'], ['Anim', 'M', 'Plur', 'P', 'Loc', '6'], ['Inan', 'I', 'Plur', 'P', 'Gen', '2'], ['Inan', 'I', 'Plur', 'P', 'Loc', '6'], ['Fem', 'F', 'Plur', 'P', 'Gen', '2'], ['Fem', 'F', 'Plur', 'P', 'Loc', '6'], ['Neut', 'N', 'Plur', 'P', 'Gen', '2'], ['Neut', 'N', 'Plur', 'P', 'Loc', '6']]],
                'ještěrčím'    => ['ještěrčí', 'ješčeřičí', [['Anim', 'M', 'Sing', 'S', 'Loc', '6'], ['Anim', 'M', 'Sing', 'S', 'Ins', '7'], ['Anim', 'M', 'Plur', 'P', 'Dat', '3'], ['Inan', 'I', 'Sing', 'S', 'Loc', '6'], ['Inan', 'I', 'Sing', 'S', 'Ins', '7'], ['Inan', 'I', 'Plur', 'P', 'Dat', '3'], ['Fem', 'F', 'Plur', 'P', 'Dat', '3'], ['Neut', 'N', 'Sing', 'S', 'Loc', '6'], ['Neut', 'N', 'Sing', 'S', 'Ins', '7'], ['Neut', 'N', 'Plur', 'P', 'Dat', '3']]],
                'ještěrčími'   => ['ještěrčí', 'ješčeřičí', [['Anim', 'M', 'Plur', 'P', 'Ins', '7'], ['Inan', 'I', 'Plur', 'P', 'Ins', '7'], ['Fem', 'F', 'Plur', 'P', 'Ins', '7'], ['Neut', 'N', 'Plur', 'P', 'Ins', '7']]],
                'ještěrčímu'   => ['ještěrčí', 'ješčeřičí', [['Anim', 'M', 'Sing', 'S', 'Dat', '3'], ['Inan', 'I', 'Sing', 'S', 'Dat', '3'], ['Neut', 'N', 'Sing', 'S', 'Dat', '3']]],
                'ještěrčú'     => ['ještěrčí', 'ješčeřičí', [['Fem', 'F', 'Sing', 'S', 'Acc', '4']]]
            );
            my $ma = $ma{$lform}; die("Something is wrong: '$lform'") if(!defined($ma));
            $f[2] = $ma->[0];
            $f[9] = set_lemma1300($f[9], $ma->[1]);
            $f[3] = 'ADJ';
            # U některých slov umožňujeme několik čtení, ale pokud to není žádné z nich, dáme první jako default.
            my @alt = @{$ma->[2]};
            for(my $i = $#alt; $i >= 0 ; $i--)
            {
                my $animacy = $alt[$i][0] =~ m/^(Anim|Inan)$/ ? $alt[$i][0] : undef;
                my $gender = $alt[$i][0] =~ m/^(Anim|Inan)$/ ? 'Masc' : $alt[$i][0];
                my $number = $alt[$i][2];
                my $case = $alt[$i][4];
                if($i == 0 || defined($alt[$i][6]) && get_ref($f[9]) =~ m/^$alt[$i][6]$/ || !defined($alt[$i][6]) && $f[5] =~ m/Case=$case.*Gender=$gender.*Number=$number/)
                {
                    $f[4] = 'AA'.$alt[$i][1].$alt[$i][3].$alt[$i][5].'----1A----';
                    $f[5] = "Case=$case|Degree=Pos|Gender=$gender|Number=$number|Polarity=Pos";
                    $f[5] = "Animacy=$animacy|$f[5]" if(defined($animacy));
                    last;
                }
            }
        }
        # Přídavná jména slovesná – činná příčestí nedokonavá/přítomná.
        elsif($f[1] =~ m/^(vu?olajíc)(í|ieho|iemu|iem|ím|ie|iej|ích)$/i)
        {
            my $lform = lc($f[1]);
            my %ma =
            (
                'volající'     => ['volající', 'vuolající', [['Anim', 'M', 'Sing', 'S', 'Nom', '1'], ['Anim', 'M', 'Sing', 'S', 'Voc', '5'], ['Anim', 'M', 'Plur', 'P', 'Nom', '1'], ['Anim', 'M', 'Plur', 'P', 'Acc', '4'], ['Anim', 'M', 'Plur', 'P', 'Voc', '5'], ['Inan', 'I', 'Sing', 'S', 'Nom', '1'], ['Inan', 'I', 'Sing', 'S', 'Acc', '4'], ['Inan', 'I', 'Sing', 'S', 'Voc', '5'], ['Inan', 'I', 'Plur', 'P', 'Nom', '1'], ['Inan', 'I', 'Plur', 'P', 'Acc', '4'], ['Inan', 'I', 'Plur', 'P', 'Voc', '5'], ['Fem', 'F', 'Sing', 'S', 'Nom', '1'], ['Fem', 'F', 'Sing', 'S', 'Gen', '2'], ['Fem', 'F', 'Sing', 'S', 'Dat', '3'], ['Fem', 'F', 'Sing', 'S', 'Acc', '4'], ['Fem', 'F', 'Sing', 'S', 'Voc', '5'], ['Fem', 'F', 'Sing', 'S', 'Loc', '6'], ['Fem', 'F', 'Sing', 'S', 'Ins', '7'], ['Fem', 'F', 'Plur', 'P', 'Nom', '1'], ['Fem', 'F', 'Plur', 'P', 'Acc', '4'], ['Fem', 'F', 'Plur', 'P', 'Voc', '5'], ['Neut', 'N', 'Sing', 'S', 'Nom', '1'], ['Neut', 'N', 'Sing', 'S', 'Acc', '4'], ['Neut', 'N', 'Sing', 'S', 'Voc', '5'], ['Neut', 'N', 'Plur', 'P', 'Nom', '1'], ['Neut', 'N', 'Plur', 'P', 'Acc', '4'], ['Neut', 'N', 'Plur', 'P', 'Voc', '5']]],
                'volajície'    => ['volající', 'vuolající', [['Fem', 'F', 'Sing', 'S', 'Gen', '2'], ['Fem', 'F', 'Plur', 'P', 'Acc', '4'], ['Neut', 'N', 'Sing', 'S', 'Nom', '1'], ['Neut', 'N', 'Sing', 'S', 'Acc', '4']]],
                'volajícieho'  => ['volající', 'vuolající', [['Anim', 'M', 'Sing', 'S', 'Gen', '2'], ['Anim', 'M', 'Sing', 'S', 'Acc', '4'], ['Inan', 'I', 'Sing', 'S', 'Gen', '2'], ['Neut', 'N', 'Sing', 'S', 'Gen', '2']]],
                'volajíciej'   => ['volající', 'vuolající', [['Fem', 'F', 'Sing', 'S', 'Dat', '3'], ['Fem', 'F', 'Sing', 'S', 'Loc', '6']]],
                'volajíciem'   => ['volající', 'vuolající', [['Neut', 'N', 'Sing', 'S', 'Loc', '6']]],
                'volajíciemu'  => ['volající', 'vuolající', [['Anim', 'M', 'Sing', 'S', 'Dat', '3'], ['Inan', 'I', 'Sing', 'S', 'Dat', '3'], ['Neut', 'N', 'Sing', 'S', 'Dat', '3']]],
                'volajícího'   => ['volající', 'vuolající', [['Anim', 'M', 'Sing', 'S', 'Gen', '2'], ['Anim', 'M', 'Sing', 'S', 'Acc', '4'], ['Inan', 'I', 'Sing', 'S', 'Gen', '2'], ['Neut', 'N', 'Sing', 'S', 'Gen', '2']]],
                'volajících'   => ['volající', 'vuolající', [['Anim', 'M', 'Plur', 'P', 'Gen', '2'], ['Anim', 'M', 'Plur', 'P', 'Loc', '6'], ['Inan', 'I', 'Plur', 'P', 'Gen', '2'], ['Inan', 'I', 'Plur', 'P', 'Loc', '6'], ['Fem', 'F', 'Plur', 'P', 'Gen', '2'], ['Fem', 'F', 'Plur', 'P', 'Loc', '6'], ['Neut', 'N', 'Plur', 'P', 'Gen', '2'], ['Neut', 'N', 'Plur', 'P', 'Loc', '6']]],
                'volajícím'    => ['volající', 'vuolající', [['Anim', 'M', 'Sing', 'S', 'Loc', '6'], ['Anim', 'M', 'Sing', 'S', 'Ins', '7'], ['Anim', 'M', 'Plur', 'P', 'Dat', '3'], ['Inan', 'I', 'Sing', 'S', 'Loc', '6'], ['Inan', 'I', 'Sing', 'S', 'Ins', '7'], ['Inan', 'I', 'Plur', 'P', 'Dat', '3'], ['Fem', 'F', 'Plur', 'P', 'Dat', '3'], ['Neut', 'N', 'Sing', 'S', 'Loc', '6'], ['Neut', 'N', 'Sing', 'S', 'Ins', '7'], ['Neut', 'N', 'Plur', 'P', 'Dat', '3']]],
                'volajícími'   => ['volající', 'vuolající', [['Anim', 'M', 'Plur', 'P', 'Ins', '7'], ['Inan', 'I', 'Plur', 'P', 'Ins', '7'], ['Fem', 'F', 'Plur', 'P', 'Ins', '7'], ['Neut', 'N', 'Plur', 'P', 'Ins', '7']]],
                'volajícímu'   => ['volající', 'vuolající', [['Anim', 'M', 'Sing', 'S', 'Dat', '3'], ['Inan', 'I', 'Sing', 'S', 'Dat', '3'], ['Neut', 'N', 'Sing', 'S', 'Dat', '3']]],
                'volajícú'     => ['volající', 'vuolající', [['Fem', 'F', 'Sing', 'S', 'Acc', '4']]],
                'vuolající'    => ['volající', 'vuolající', [['Anim', 'M', 'Sing', 'S', 'Nom', '1'], ['Anim', 'M', 'Sing', 'S', 'Voc', '5'], ['Anim', 'M', 'Plur', 'P', 'Nom', '1'], ['Anim', 'M', 'Plur', 'P', 'Acc', '4'], ['Anim', 'M', 'Plur', 'P', 'Voc', '5'], ['Inan', 'I', 'Sing', 'S', 'Nom', '1'], ['Inan', 'I', 'Sing', 'S', 'Acc', '4'], ['Inan', 'I', 'Sing', 'S', 'Voc', '5'], ['Inan', 'I', 'Plur', 'P', 'Nom', '1'], ['Inan', 'I', 'Plur', 'P', 'Acc', '4'], ['Inan', 'I', 'Plur', 'P', 'Voc', '5'], ['Fem', 'F', 'Sing', 'S', 'Nom', '1'], ['Fem', 'F', 'Sing', 'S', 'Gen', '2'], ['Fem', 'F', 'Sing', 'S', 'Dat', '3'], ['Fem', 'F', 'Sing', 'S', 'Acc', '4'], ['Fem', 'F', 'Sing', 'S', 'Voc', '5'], ['Fem', 'F', 'Sing', 'S', 'Loc', '6'], ['Fem', 'F', 'Sing', 'S', 'Ins', '7'], ['Fem', 'F', 'Plur', 'P', 'Nom', '1'], ['Fem', 'F', 'Plur', 'P', 'Acc', '4'], ['Fem', 'F', 'Plur', 'P', 'Voc', '5'], ['Neut', 'N', 'Sing', 'S', 'Nom', '1'], ['Neut', 'N', 'Sing', 'S', 'Acc', '4'], ['Neut', 'N', 'Sing', 'S', 'Voc', '5'], ['Neut', 'N', 'Plur', 'P', 'Nom', '1'], ['Neut', 'N', 'Plur', 'P', 'Acc', '4'], ['Neut', 'N', 'Plur', 'P', 'Voc', '5']]],
                'vuolajície'   => ['volající', 'vuolající', [['Fem', 'F', 'Sing', 'S', 'Gen', '2'], ['Fem', 'F', 'Plur', 'P', 'Acc', '4'], ['Neut', 'N', 'Sing', 'S', 'Nom', '1'], ['Neut', 'N', 'Sing', 'S', 'Acc', '4']]],
                'vuolajícieho' => ['volající', 'vuolající', [['Anim', 'M', 'Sing', 'S', 'Gen', '2'], ['Anim', 'M', 'Sing', 'S', 'Acc', '4'], ['Inan', 'I', 'Sing', 'S', 'Gen', '2'], ['Neut', 'N', 'Sing', 'S', 'Gen', '2']]],
                'vuolajíciej'  => ['volající', 'vuolající', [['Fem', 'F', 'Sing', 'S', 'Dat', '3'], ['Fem', 'F', 'Sing', 'S', 'Loc', '6']]],
                'vuolajíciem'  => ['volající', 'vuolající', [['Neut', 'N', 'Sing', 'S', 'Loc', '6']]],
                'vuolajíciemu' => ['volající', 'vuolající', [['Anim', 'M', 'Sing', 'S', 'Dat', '3'], ['Inan', 'I', 'Sing', 'S', 'Dat', '3'], ['Neut', 'N', 'Sing', 'S', 'Dat', '3']]],
                'vuolajícího'  => ['volající', 'vuolající', [['Anim', 'M', 'Sing', 'S', 'Gen', '2'], ['Anim', 'M', 'Sing', 'S', 'Acc', '4'], ['Inan', 'I', 'Sing', 'S', 'Gen', '2'], ['Neut', 'N', 'Sing', 'S', 'Gen', '2']]],
                'vuolajících'  => ['volající', 'vuolající', [['Anim', 'M', 'Plur', 'P', 'Gen', '2'], ['Anim', 'M', 'Plur', 'P', 'Loc', '6'], ['Inan', 'I', 'Plur', 'P', 'Gen', '2'], ['Inan', 'I', 'Plur', 'P', 'Loc', '6'], ['Fem', 'F', 'Plur', 'P', 'Gen', '2'], ['Fem', 'F', 'Plur', 'P', 'Loc', '6'], ['Neut', 'N', 'Plur', 'P', 'Gen', '2'], ['Neut', 'N', 'Plur', 'P', 'Loc', '6']]],
                'vuolajícím'   => ['volající', 'vuolající', [['Anim', 'M', 'Sing', 'S', 'Loc', '6'], ['Anim', 'M', 'Sing', 'S', 'Ins', '7'], ['Anim', 'M', 'Plur', 'P', 'Dat', '3'], ['Inan', 'I', 'Sing', 'S', 'Loc', '6'], ['Inan', 'I', 'Sing', 'S', 'Ins', '7'], ['Inan', 'I', 'Plur', 'P', 'Dat', '3'], ['Fem', 'F', 'Plur', 'P', 'Dat', '3'], ['Neut', 'N', 'Sing', 'S', 'Loc', '6'], ['Neut', 'N', 'Sing', 'S', 'Ins', '7'], ['Neut', 'N', 'Plur', 'P', 'Dat', '3']]],
                'vuolajícími'  => ['volající', 'vuolající', [['Anim', 'M', 'Plur', 'P', 'Ins', '7'], ['Inan', 'I', 'Plur', 'P', 'Ins', '7'], ['Fem', 'F', 'Plur', 'P', 'Ins', '7'], ['Neut', 'N', 'Plur', 'P', 'Ins', '7']]],
                'vuolajícímu'  => ['volající', 'vuolající', [['Anim', 'M', 'Sing', 'S', 'Dat', '3'], ['Inan', 'I', 'Sing', 'S', 'Dat', '3'], ['Neut', 'N', 'Sing', 'S', 'Dat', '3']]],
                'vuolajícú'    => ['volající', 'vuolající', [['Fem', 'F', 'Sing', 'S', 'Acc', '4']]]
            );
            my $ma = $ma{$lform}; die("Something is wrong: '$lform'") if(!defined($ma));
            $f[2] = $ma->[0];
            $f[9] = set_lemma1300($f[9], $ma->[1]);
            $f[3] = 'ADJ';
            # U některých slov umožňujeme několik čtení, ale pokud to není žádné z nich, dáme první jako default.
            my @alt = @{$ma->[2]};
            for(my $i = $#alt; $i >= 0 ; $i--)
            {
                my $animacy = $alt[$i][0] =~ m/^(Anim|Inan)$/ ? $alt[$i][0] : undef;
                my $gender = $alt[$i][0] =~ m/^(Anim|Inan)$/ ? 'Masc' : $alt[$i][0];
                my $number = $alt[$i][2];
                my $case = $alt[$i][4];
                if($i == 0 || defined($alt[$i][6]) && get_ref($f[9]) =~ m/^$alt[$i][6]$/ || !defined($alt[$i][6]) && $f[5] =~ m/Case=$case.*Gender=$gender.*Number=$number/)
                {
                    $f[4] = 'AG'.$alt[$i][1].$alt[$i][3].$alt[$i][5].'-----A----';
                    $f[5] = "Aspect=Imp|Case=$case|Gender=$gender|Number=$number|Polarity=Pos|Tense=Pres|VerbForm=Part|Voice=Act";
                    $f[5] = "Animacy=$animacy|$f[5]" if(defined($animacy));
                    last;
                }
            }
        }
        # 2. a 3. stupeň.
        # 'mlazší' je sice adjektivum, ale používá se obvykle ve spojení 'jeho mlazší', což zřejmě znamená něco jako 'jeho učedníci'
        # Asi můžeme předpokládat, že ve všech případech jde o rod mužský životný.
        elsif($f[1] =~ m/^(naj)?(d(?:ó|uo)stojnějš|menš|mlazš)(í|ieho|iemu|iem|ím|ie|iej|ích|ími)$/i)
        {
            my $suprefix = lc($1);
            my $stem = lc($2);
            my $suffix = lc($3);
            my $degree = $suprefix ? 'Sup' : 'Cmp';
            my $d = $suprefix ? '3' : '2';
            my $lform = $stem.$suffix;
            my %ma =
            (
                'dóstojnější'     => ['důstojný', 'dóstojný', [['Anim', 'M', 'Sing', 'S', 'Nom', '1'], ['Anim', 'M', 'Sing', 'S', 'Voc', '5'], ['Anim', 'M', 'Plur', 'P', 'Nom', '1'], ['Anim', 'M', 'Plur', 'P', 'Acc', '4'], ['Anim', 'M', 'Plur', 'P', 'Voc', '5'], ['Inan', 'I', 'Sing', 'S', 'Nom', '1'], ['Inan', 'I', 'Sing', 'S', 'Acc', '4'], ['Inan', 'I', 'Sing', 'S', 'Voc', '5'], ['Inan', 'I', 'Plur', 'P', 'Nom', '1'], ['Inan', 'I', 'Plur', 'P', 'Acc', '4'], ['Inan', 'I', 'Plur', 'P', 'Voc', '5'], ['Fem', 'F', 'Sing', 'S', 'Nom', '1'], ['Fem', 'F', 'Sing', 'S', 'Gen', '2'], ['Fem', 'F', 'Sing', 'S', 'Dat', '3'], ['Fem', 'F', 'Sing', 'S', 'Acc', '4'], ['Fem', 'F', 'Sing', 'S', 'Voc', '5'], ['Fem', 'F', 'Sing', 'S', 'Loc', '6'], ['Fem', 'F', 'Sing', 'S', 'Ins', '7'], ['Fem', 'F', 'Plur', 'P', 'Nom', '1'], ['Fem', 'F', 'Plur', 'P', 'Acc', '4'], ['Fem', 'F', 'Plur', 'P', 'Voc', '5'], ['Neut', 'N', 'Sing', 'S', 'Nom', '1'], ['Neut', 'N', 'Sing', 'S', 'Acc', '4'], ['Neut', 'N', 'Sing', 'S', 'Voc', '5'], ['Neut', 'N', 'Plur', 'P', 'Nom', '1'], ['Neut', 'N', 'Plur', 'P', 'Acc', '4'], ['Neut', 'N', 'Plur', 'P', 'Voc', '5']]],
                'dóstojnějšie'    => ['důstojný', 'dóstojný', [['Fem', 'F', 'Sing', 'S', 'Gen', '2'], ['Fem', 'F', 'Plur', 'P', 'Acc', '4'], ['Neut', 'N', 'Sing', 'S', 'Nom', '1'], ['Neut', 'N', 'Sing', 'S', 'Acc', '4']]],
                'dóstojnějšieho'  => ['důstojný', 'dóstojný', [['Anim', 'M', 'Sing', 'S', 'Gen', '2'], ['Anim', 'M', 'Sing', 'S', 'Acc', '4'], ['Inan', 'I', 'Sing', 'S', 'Gen', '2'], ['Neut', 'N', 'Sing', 'S', 'Gen', '2']]],
                'dóstojnějšiej'   => ['důstojný', 'dóstojný', [['Fem', 'F', 'Sing', 'S', 'Dat', '3'], ['Fem', 'F', 'Sing', 'S', 'Loc', '6']]],
                'dóstojnějšiem'   => ['důstojný', 'dóstojný', [['Neut', 'N', 'Sing', 'S', 'Loc', '6']]],
                'dóstojnějšiemu'  => ['důstojný', 'dóstojný', [['Anim', 'M', 'Sing', 'S', 'Dat', '3'], ['Inan', 'I', 'Sing', 'S', 'Dat', '3'], ['Neut', 'N', 'Sing', 'S', 'Dat', '3']]],
                'dóstojnějšího'   => ['důstojný', 'dóstojný', [['Anim', 'M', 'Sing', 'S', 'Gen', '2'], ['Anim', 'M', 'Sing', 'S', 'Acc', '4'], ['Inan', 'I', 'Sing', 'S', 'Gen', '2'], ['Neut', 'N', 'Sing', 'S', 'Gen', '2']]],
                'dóstojnějších'   => ['důstojný', 'dóstojný', [['Anim', 'M', 'Plur', 'P', 'Gen', '2'], ['Anim', 'M', 'Plur', 'P', 'Loc', '6'], ['Inan', 'I', 'Plur', 'P', 'Gen', '2'], ['Inan', 'I', 'Plur', 'P', 'Loc', '6'], ['Fem', 'F', 'Plur', 'P', 'Gen', '2'], ['Fem', 'F', 'Plur', 'P', 'Loc', '6'], ['Neut', 'N', 'Plur', 'P', 'Gen', '2'], ['Neut', 'N', 'Plur', 'P', 'Loc', '6']]],
                'dóstojnějším'    => ['důstojný', 'dóstojný', [['Anim', 'M', 'Sing', 'S', 'Loc', '6'], ['Anim', 'M', 'Sing', 'S', 'Ins', '7'], ['Anim', 'M', 'Plur', 'P', 'Dat', '3'], ['Inan', 'I', 'Sing', 'S', 'Loc', '6'], ['Inan', 'I', 'Sing', 'S', 'Ins', '7'], ['Inan', 'I', 'Plur', 'P', 'Dat', '3'], ['Fem', 'F', 'Plur', 'P', 'Dat', '3'], ['Neut', 'N', 'Sing', 'S', 'Loc', '6'], ['Neut', 'N', 'Sing', 'S', 'Ins', '7'], ['Neut', 'N', 'Plur', 'P', 'Dat', '3']]],
                'dóstojnějšími'   => ['důstojný', 'dóstojný', [['Anim', 'M', 'Plur', 'P', 'Ins', '7'], ['Inan', 'I', 'Plur', 'P', 'Ins', '7'], ['Fem', 'F', 'Plur', 'P', 'Ins', '7'], ['Neut', 'N', 'Plur', 'P', 'Ins', '7']]],
                'dóstojnějšímu'   => ['důstojný', 'dóstojný', [['Anim', 'M', 'Sing', 'S', 'Dat', '3'], ['Inan', 'I', 'Sing', 'S', 'Dat', '3'], ['Neut', 'N', 'Sing', 'S', 'Dat', '3']]],
                'dóstojnějšú'     => ['důstojný', 'dóstojný', [['Fem', 'F', 'Sing', 'S', 'Acc', '4']]],
                'duostojnější'    => ['důstojný', 'dóstojný', [['Anim', 'M', 'Sing', 'S', 'Nom', '1'], ['Anim', 'M', 'Sing', 'S', 'Voc', '5'], ['Anim', 'M', 'Plur', 'P', 'Nom', '1'], ['Anim', 'M', 'Plur', 'P', 'Acc', '4'], ['Anim', 'M', 'Plur', 'P', 'Voc', '5'], ['Inan', 'I', 'Sing', 'S', 'Nom', '1'], ['Inan', 'I', 'Sing', 'S', 'Acc', '4'], ['Inan', 'I', 'Sing', 'S', 'Voc', '5'], ['Inan', 'I', 'Plur', 'P', 'Nom', '1'], ['Inan', 'I', 'Plur', 'P', 'Acc', '4'], ['Inan', 'I', 'Plur', 'P', 'Voc', '5'], ['Fem', 'F', 'Sing', 'S', 'Nom', '1'], ['Fem', 'F', 'Sing', 'S', 'Gen', '2'], ['Fem', 'F', 'Sing', 'S', 'Dat', '3'], ['Fem', 'F', 'Sing', 'S', 'Acc', '4'], ['Fem', 'F', 'Sing', 'S', 'Voc', '5'], ['Fem', 'F', 'Sing', 'S', 'Loc', '6'], ['Fem', 'F', 'Sing', 'S', 'Ins', '7'], ['Fem', 'F', 'Plur', 'P', 'Nom', '1'], ['Fem', 'F', 'Plur', 'P', 'Acc', '4'], ['Fem', 'F', 'Plur', 'P', 'Voc', '5'], ['Neut', 'N', 'Sing', 'S', 'Nom', '1'], ['Neut', 'N', 'Sing', 'S', 'Acc', '4'], ['Neut', 'N', 'Sing', 'S', 'Voc', '5'], ['Neut', 'N', 'Plur', 'P', 'Nom', '1'], ['Neut', 'N', 'Plur', 'P', 'Acc', '4'], ['Neut', 'N', 'Plur', 'P', 'Voc', '5']]],
                'duostojnějšie'   => ['důstojný', 'dóstojný', [['Fem', 'F', 'Sing', 'S', 'Gen', '2'], ['Fem', 'F', 'Plur', 'P', 'Acc', '4'], ['Neut', 'N', 'Sing', 'S', 'Nom', '1'], ['Neut', 'N', 'Sing', 'S', 'Acc', '4']]],
                'duostojnějšieho' => ['důstojný', 'dóstojný', [['Anim', 'M', 'Sing', 'S', 'Gen', '2'], ['Anim', 'M', 'Sing', 'S', 'Acc', '4'], ['Inan', 'I', 'Sing', 'S', 'Gen', '2'], ['Neut', 'N', 'Sing', 'S', 'Gen', '2']]],
                'duostojnějšiej'  => ['důstojný', 'dóstojný', [['Fem', 'F', 'Sing', 'S', 'Dat', '3'], ['Fem', 'F', 'Sing', 'S', 'Loc', '6']]],
                'duostojnějšiem'  => ['důstojný', 'dóstojný', [['Neut', 'N', 'Sing', 'S', 'Loc', '6']]],
                'duostojnějšiemu' => ['důstojný', 'dóstojný', [['Anim', 'M', 'Sing', 'S', 'Dat', '3'], ['Inan', 'I', 'Sing', 'S', 'Dat', '3'], ['Neut', 'N', 'Sing', 'S', 'Dat', '3']]],
                'duostojnějšího'  => ['důstojný', 'dóstojný', [['Anim', 'M', 'Sing', 'S', 'Gen', '2'], ['Anim', 'M', 'Sing', 'S', 'Acc', '4'], ['Inan', 'I', 'Sing', 'S', 'Gen', '2'], ['Neut', 'N', 'Sing', 'S', 'Gen', '2']]],
                'duostojnějších'  => ['důstojný', 'dóstojný', [['Anim', 'M', 'Plur', 'P', 'Gen', '2'], ['Anim', 'M', 'Plur', 'P', 'Loc', '6'], ['Inan', 'I', 'Plur', 'P', 'Gen', '2'], ['Inan', 'I', 'Plur', 'P', 'Loc', '6'], ['Fem', 'F', 'Plur', 'P', 'Gen', '2'], ['Fem', 'F', 'Plur', 'P', 'Loc', '6'], ['Neut', 'N', 'Plur', 'P', 'Gen', '2'], ['Neut', 'N', 'Plur', 'P', 'Loc', '6']]],
                'duostojnějším'   => ['důstojný', 'dóstojný', [['Anim', 'M', 'Sing', 'S', 'Loc', '6'], ['Anim', 'M', 'Sing', 'S', 'Ins', '7'], ['Anim', 'M', 'Plur', 'P', 'Dat', '3'], ['Inan', 'I', 'Sing', 'S', 'Loc', '6'], ['Inan', 'I', 'Sing', 'S', 'Ins', '7'], ['Inan', 'I', 'Plur', 'P', 'Dat', '3'], ['Fem', 'F', 'Plur', 'P', 'Dat', '3'], ['Neut', 'N', 'Sing', 'S', 'Loc', '6'], ['Neut', 'N', 'Sing', 'S', 'Ins', '7'], ['Neut', 'N', 'Plur', 'P', 'Dat', '3']]],
                'duostojnějšími'  => ['důstojný', 'dóstojný', [['Anim', 'M', 'Plur', 'P', 'Ins', '7'], ['Inan', 'I', 'Plur', 'P', 'Ins', '7'], ['Fem', 'F', 'Plur', 'P', 'Ins', '7'], ['Neut', 'N', 'Plur', 'P', 'Ins', '7']]],
                'duostojnějšímu'  => ['důstojný', 'dóstojný', [['Anim', 'M', 'Sing', 'S', 'Dat', '3'], ['Inan', 'I', 'Sing', 'S', 'Dat', '3'], ['Neut', 'N', 'Sing', 'S', 'Dat', '3']]],
                'duostojnějšú'    => ['důstojný', 'dóstojný', [['Fem', 'F', 'Sing', 'S', 'Acc', '4']]],
                'důstojnější'     => ['důstojný', 'dóstojný', [['Anim', 'M', 'Sing', 'S', 'Nom', '1'], ['Anim', 'M', 'Sing', 'S', 'Voc', '5'], ['Anim', 'M', 'Plur', 'P', 'Nom', '1'], ['Anim', 'M', 'Plur', 'P', 'Acc', '4'], ['Anim', 'M', 'Plur', 'P', 'Voc', '5'], ['Inan', 'I', 'Sing', 'S', 'Nom', '1'], ['Inan', 'I', 'Sing', 'S', 'Acc', '4'], ['Inan', 'I', 'Sing', 'S', 'Voc', '5'], ['Inan', 'I', 'Plur', 'P', 'Nom', '1'], ['Inan', 'I', 'Plur', 'P', 'Acc', '4'], ['Inan', 'I', 'Plur', 'P', 'Voc', '5'], ['Fem', 'F', 'Sing', 'S', 'Nom', '1'], ['Fem', 'F', 'Sing', 'S', 'Gen', '2'], ['Fem', 'F', 'Sing', 'S', 'Dat', '3'], ['Fem', 'F', 'Sing', 'S', 'Acc', '4'], ['Fem', 'F', 'Sing', 'S', 'Voc', '5'], ['Fem', 'F', 'Sing', 'S', 'Loc', '6'], ['Fem', 'F', 'Sing', 'S', 'Ins', '7'], ['Fem', 'F', 'Plur', 'P', 'Nom', '1'], ['Fem', 'F', 'Plur', 'P', 'Acc', '4'], ['Fem', 'F', 'Plur', 'P', 'Voc', '5'], ['Neut', 'N', 'Sing', 'S', 'Nom', '1'], ['Neut', 'N', 'Sing', 'S', 'Acc', '4'], ['Neut', 'N', 'Sing', 'S', 'Voc', '5'], ['Neut', 'N', 'Plur', 'P', 'Nom', '1'], ['Neut', 'N', 'Plur', 'P', 'Acc', '4'], ['Neut', 'N', 'Plur', 'P', 'Voc', '5']]],
                'důstojnějšie'    => ['důstojný', 'dóstojný', [['Fem', 'F', 'Sing', 'S', 'Gen', '2'], ['Fem', 'F', 'Plur', 'P', 'Acc', '4'], ['Neut', 'N', 'Sing', 'S', 'Nom', '1'], ['Neut', 'N', 'Sing', 'S', 'Acc', '4']]],
                'důstojnějšieho'  => ['důstojný', 'dóstojný', [['Anim', 'M', 'Sing', 'S', 'Gen', '2'], ['Anim', 'M', 'Sing', 'S', 'Acc', '4'], ['Inan', 'I', 'Sing', 'S', 'Gen', '2'], ['Neut', 'N', 'Sing', 'S', 'Gen', '2']]],
                'důstojnějšiej'   => ['důstojný', 'dóstojný', [['Fem', 'F', 'Sing', 'S', 'Dat', '3'], ['Fem', 'F', 'Sing', 'S', 'Loc', '6']]],
                'důstojnějšiem'   => ['důstojný', 'dóstojný', [['Neut', 'N', 'Sing', 'S', 'Loc', '6']]],
                'důstojnějšiemu'  => ['důstojný', 'dóstojný', [['Anim', 'M', 'Sing', 'S', 'Dat', '3'], ['Inan', 'I', 'Sing', 'S', 'Dat', '3'], ['Neut', 'N', 'Sing', 'S', 'Dat', '3']]],
                'důstojnějšího'   => ['důstojný', 'dóstojný', [['Anim', 'M', 'Sing', 'S', 'Gen', '2'], ['Anim', 'M', 'Sing', 'S', 'Acc', '4'], ['Inan', 'I', 'Sing', 'S', 'Gen', '2'], ['Neut', 'N', 'Sing', 'S', 'Gen', '2']]],
                'důstojnějších'   => ['důstojný', 'dóstojný', [['Anim', 'M', 'Plur', 'P', 'Gen', '2'], ['Anim', 'M', 'Plur', 'P', 'Loc', '6'], ['Inan', 'I', 'Plur', 'P', 'Gen', '2'], ['Inan', 'I', 'Plur', 'P', 'Loc', '6'], ['Fem', 'F', 'Plur', 'P', 'Gen', '2'], ['Fem', 'F', 'Plur', 'P', 'Loc', '6'], ['Neut', 'N', 'Plur', 'P', 'Gen', '2'], ['Neut', 'N', 'Plur', 'P', 'Loc', '6']]],
                'důstojnějším'    => ['důstojný', 'dóstojný', [['Anim', 'M', 'Sing', 'S', 'Loc', '6'], ['Anim', 'M', 'Sing', 'S', 'Ins', '7'], ['Anim', 'M', 'Plur', 'P', 'Dat', '3'], ['Inan', 'I', 'Sing', 'S', 'Loc', '6'], ['Inan', 'I', 'Sing', 'S', 'Ins', '7'], ['Inan', 'I', 'Plur', 'P', 'Dat', '3'], ['Fem', 'F', 'Plur', 'P', 'Dat', '3'], ['Neut', 'N', 'Sing', 'S', 'Loc', '6'], ['Neut', 'N', 'Sing', 'S', 'Ins', '7'], ['Neut', 'N', 'Plur', 'P', 'Dat', '3']]],
                'důstojnějšími'   => ['důstojný', 'dóstojný', [['Anim', 'M', 'Plur', 'P', 'Ins', '7'], ['Inan', 'I', 'Plur', 'P', 'Ins', '7'], ['Fem', 'F', 'Plur', 'P', 'Ins', '7'], ['Neut', 'N', 'Plur', 'P', 'Ins', '7']]],
                'důstojnějšímu'   => ['důstojný', 'dóstojný', [['Anim', 'M', 'Sing', 'S', 'Dat', '3'], ['Inan', 'I', 'Sing', 'S', 'Dat', '3'], ['Neut', 'N', 'Sing', 'S', 'Dat', '3']]],
                'důstojnějšú'     => ['důstojný', 'dóstojný', [['Fem', 'F', 'Sing', 'S', 'Acc', '4']]],
                'menší'    => ['malý', 'malý', [['Anim', 'M', 'Sing', 'S', 'Nom', '1'], ['Anim', 'M', 'Sing', 'S', 'Voc', '5'], ['Anim', 'M', 'Plur', 'P', 'Nom', '1'], ['Anim', 'M', 'Plur', 'P', 'Acc', '4'], ['Anim', 'M', 'Plur', 'P', 'Voc', '5'], ['Inan', 'I', 'Sing', 'S', 'Nom', '1'], ['Inan', 'I', 'Sing', 'S', 'Acc', '4'], ['Inan', 'I', 'Sing', 'S', 'Voc', '5'], ['Inan', 'I', 'Plur', 'P', 'Nom', '1'], ['Inan', 'I', 'Plur', 'P', 'Acc', '4'], ['Inan', 'I', 'Plur', 'P', 'Voc', '5'], ['Fem', 'F', 'Sing', 'S', 'Nom', '1'], ['Fem', 'F', 'Sing', 'S', 'Gen', '2'], ['Fem', 'F', 'Sing', 'S', 'Dat', '3'], ['Fem', 'F', 'Sing', 'S', 'Acc', '4'], ['Fem', 'F', 'Sing', 'S', 'Voc', '5'], ['Fem', 'F', 'Sing', 'S', 'Loc', '6'], ['Fem', 'F', 'Sing', 'S', 'Ins', '7'], ['Fem', 'F', 'Plur', 'P', 'Nom', '1'], ['Fem', 'F', 'Plur', 'P', 'Acc', '4'], ['Fem', 'F', 'Plur', 'P', 'Voc', '5'], ['Neut', 'N', 'Sing', 'S', 'Nom', '1'], ['Neut', 'N', 'Sing', 'S', 'Acc', '4'], ['Neut', 'N', 'Sing', 'S', 'Voc', '5'], ['Neut', 'N', 'Plur', 'P', 'Nom', '1'], ['Neut', 'N', 'Plur', 'P', 'Acc', '4'], ['Neut', 'N', 'Plur', 'P', 'Voc', '5']]],
                'menšie'   => ['malý', 'malý', [['Fem', 'F', 'Sing', 'S', 'Gen', '2'], ['Fem', 'F', 'Plur', 'P', 'Acc', '4'], ['Neut', 'N', 'Sing', 'S', 'Nom', '1'], ['Neut', 'N', 'Sing', 'S', 'Acc', '4']]],
                'menšieho' => ['malý', 'malý', [['Anim', 'M', 'Sing', 'S', 'Gen', '2'], ['Anim', 'M', 'Sing', 'S', 'Acc', '4'], ['Inan', 'I', 'Sing', 'S', 'Gen', '2'], ['Neut', 'N', 'Sing', 'S', 'Gen', '2']]],
                'menšiej'  => ['malý', 'malý', [['Fem', 'F', 'Sing', 'S', 'Dat', '3'], ['Fem', 'F', 'Sing', 'S', 'Loc', '6']]],
                'menšiem'  => ['malý', 'malý', [['Neut', 'N', 'Sing', 'S', 'Loc', '6']]],
                'menšiemu' => ['malý', 'malý', [['Anim', 'M', 'Sing', 'S', 'Dat', '3'], ['Inan', 'I', 'Sing', 'S', 'Dat', '3'], ['Neut', 'N', 'Sing', 'S', 'Dat', '3']]],
                'menšího'  => ['malý', 'malý', [['Anim', 'M', 'Sing', 'S', 'Gen', '2'], ['Anim', 'M', 'Sing', 'S', 'Acc', '4'], ['Inan', 'I', 'Sing', 'S', 'Gen', '2'], ['Neut', 'N', 'Sing', 'S', 'Gen', '2']]],
                'menších'  => ['malý', 'malý', [['Anim', 'M', 'Plur', 'P', 'Gen', '2'], ['Anim', 'M', 'Plur', 'P', 'Loc', '6'], ['Inan', 'I', 'Plur', 'P', 'Gen', '2'], ['Inan', 'I', 'Plur', 'P', 'Loc', '6'], ['Fem', 'F', 'Plur', 'P', 'Gen', '2'], ['Fem', 'F', 'Plur', 'P', 'Loc', '6'], ['Neut', 'N', 'Plur', 'P', 'Gen', '2'], ['Neut', 'N', 'Plur', 'P', 'Loc', '6']]],
                'menším'   => ['malý', 'malý', [['Anim', 'M', 'Sing', 'S', 'Loc', '6'], ['Anim', 'M', 'Sing', 'S', 'Ins', '7'], ['Anim', 'M', 'Plur', 'P', 'Dat', '3'], ['Inan', 'I', 'Sing', 'S', 'Loc', '6'], ['Inan', 'I', 'Sing', 'S', 'Ins', '7'], ['Inan', 'I', 'Plur', 'P', 'Dat', '3'], ['Fem', 'F', 'Plur', 'P', 'Dat', '3'], ['Neut', 'N', 'Sing', 'S', 'Loc', '6'], ['Neut', 'N', 'Sing', 'S', 'Ins', '7'], ['Neut', 'N', 'Plur', 'P', 'Dat', '3']]],
                'menšími'  => ['malý', 'malý', [['Anim', 'M', 'Plur', 'P', 'Ins', '7'], ['Inan', 'I', 'Plur', 'P', 'Ins', '7'], ['Fem', 'F', 'Plur', 'P', 'Ins', '7'], ['Neut', 'N', 'Plur', 'P', 'Ins', '7']]],
                'menšímu'  => ['malý', 'malý', [['Anim', 'M', 'Sing', 'S', 'Dat', '3'], ['Inan', 'I', 'Sing', 'S', 'Dat', '3'], ['Neut', 'N', 'Sing', 'S', 'Dat', '3']]],
                'menšú'    => ['malý', 'malý', [['Fem', 'F', 'Sing', 'S', 'Acc', '4']]],
                'mladší'    => ['mladý', 'mladý', [['Anim', 'M', 'Sing', 'S', 'Nom', '1'], ['Anim', 'M', 'Sing', 'S', 'Voc', '5'], ['Anim', 'M', 'Plur', 'P', 'Nom', '1'], ['Anim', 'M', 'Plur', 'P', 'Acc', '4'], ['Anim', 'M', 'Plur', 'P', 'Voc', '5'], ['Inan', 'I', 'Sing', 'S', 'Nom', '1'], ['Inan', 'I', 'Sing', 'S', 'Acc', '4'], ['Inan', 'I', 'Sing', 'S', 'Voc', '5'], ['Inan', 'I', 'Plur', 'P', 'Nom', '1'], ['Inan', 'I', 'Plur', 'P', 'Acc', '4'], ['Inan', 'I', 'Plur', 'P', 'Voc', '5'], ['Fem', 'F', 'Sing', 'S', 'Nom', '1'], ['Fem', 'F', 'Sing', 'S', 'Gen', '2'], ['Fem', 'F', 'Sing', 'S', 'Dat', '3'], ['Fem', 'F', 'Sing', 'S', 'Acc', '4'], ['Fem', 'F', 'Sing', 'S', 'Voc', '5'], ['Fem', 'F', 'Sing', 'S', 'Loc', '6'], ['Fem', 'F', 'Sing', 'S', 'Ins', '7'], ['Fem', 'F', 'Plur', 'P', 'Nom', '1'], ['Fem', 'F', 'Plur', 'P', 'Acc', '4'], ['Fem', 'F', 'Plur', 'P', 'Voc', '5'], ['Neut', 'N', 'Sing', 'S', 'Nom', '1'], ['Neut', 'N', 'Sing', 'S', 'Acc', '4'], ['Neut', 'N', 'Sing', 'S', 'Voc', '5'], ['Neut', 'N', 'Plur', 'P', 'Nom', '1'], ['Neut', 'N', 'Plur', 'P', 'Acc', '4'], ['Neut', 'N', 'Plur', 'P', 'Voc', '5']]],
                'mladšie'   => ['mladý', 'mladý', [['Fem', 'F', 'Sing', 'S', 'Gen', '2'], ['Fem', 'F', 'Plur', 'P', 'Acc', '4'], ['Neut', 'N', 'Sing', 'S', 'Nom', '1'], ['Neut', 'N', 'Sing', 'S', 'Acc', '4']]],
                'mladšieho' => ['mladý', 'mladý', [['Anim', 'M', 'Sing', 'S', 'Gen', '2'], ['Anim', 'M', 'Sing', 'S', 'Acc', '4'], ['Inan', 'I', 'Sing', 'S', 'Gen', '2'], ['Neut', 'N', 'Sing', 'S', 'Gen', '2']]],
                'mladšiej'  => ['mladý', 'mladý', [['Fem', 'F', 'Sing', 'S', 'Dat', '3'], ['Fem', 'F', 'Sing', 'S', 'Loc', '6']]],
                'mladšiem'  => ['mladý', 'mladý', [['Neut', 'N', 'Sing', 'S', 'Loc', '6']]],
                'mladšiemu' => ['mladý', 'mladý', [['Anim', 'M', 'Sing', 'S', 'Dat', '3'], ['Inan', 'I', 'Sing', 'S', 'Dat', '3'], ['Neut', 'N', 'Sing', 'S', 'Dat', '3']]],
                'mladšího'  => ['mladý', 'mladý', [['Anim', 'M', 'Sing', 'S', 'Gen', '2'], ['Anim', 'M', 'Sing', 'S', 'Acc', '4'], ['Inan', 'I', 'Sing', 'S', 'Gen', '2'], ['Neut', 'N', 'Sing', 'S', 'Gen', '2']]],
                'mladších'  => ['mladý', 'mladý', [['Anim', 'M', 'Plur', 'P', 'Gen', '2'], ['Anim', 'M', 'Plur', 'P', 'Loc', '6'], ['Inan', 'I', 'Plur', 'P', 'Gen', '2'], ['Inan', 'I', 'Plur', 'P', 'Loc', '6'], ['Fem', 'F', 'Plur', 'P', 'Gen', '2'], ['Fem', 'F', 'Plur', 'P', 'Loc', '6'], ['Neut', 'N', 'Plur', 'P', 'Gen', '2'], ['Neut', 'N', 'Plur', 'P', 'Loc', '6']]],
                'mladším'   => ['mladý', 'mladý', [['Anim', 'M', 'Sing', 'S', 'Loc', '6'], ['Anim', 'M', 'Sing', 'S', 'Ins', '7'], ['Anim', 'M', 'Plur', 'P', 'Dat', '3'], ['Inan', 'I', 'Sing', 'S', 'Loc', '6'], ['Inan', 'I', 'Sing', 'S', 'Ins', '7'], ['Inan', 'I', 'Plur', 'P', 'Dat', '3'], ['Fem', 'F', 'Plur', 'P', 'Dat', '3'], ['Neut', 'N', 'Sing', 'S', 'Loc', '6'], ['Neut', 'N', 'Sing', 'S', 'Ins', '7'], ['Neut', 'N', 'Plur', 'P', 'Dat', '3']]],
                'mladšími'  => ['mladý', 'mladý', [['Anim', 'M', 'Plur', 'P', 'Ins', '7'], ['Inan', 'I', 'Plur', 'P', 'Ins', '7'], ['Fem', 'F', 'Plur', 'P', 'Ins', '7'], ['Neut', 'N', 'Plur', 'P', 'Ins', '7']]],
                'mladšímu'  => ['mladý', 'mladý', [['Anim', 'M', 'Sing', 'S', 'Dat', '3'], ['Inan', 'I', 'Sing', 'S', 'Dat', '3'], ['Neut', 'N', 'Sing', 'S', 'Dat', '3']]],
                'mladšú'    => ['mladý', 'mladý', [['Fem', 'F', 'Sing', 'S', 'Acc', '4']]],
                'mlazší'    => ['mladý', 'mladý', [['Anim', 'M', 'Sing', 'S', 'Nom', '1'], ['Anim', 'M', 'Sing', 'S', 'Voc', '5'], ['Anim', 'M', 'Plur', 'P', 'Nom', '1'], ['Anim', 'M', 'Plur', 'P', 'Acc', '4'], ['Anim', 'M', 'Plur', 'P', 'Voc', '5'], ['Inan', 'I', 'Sing', 'S', 'Nom', '1'], ['Inan', 'I', 'Sing', 'S', 'Acc', '4'], ['Inan', 'I', 'Sing', 'S', 'Voc', '5'], ['Inan', 'I', 'Plur', 'P', 'Nom', '1'], ['Inan', 'I', 'Plur', 'P', 'Acc', '4'], ['Inan', 'I', 'Plur', 'P', 'Voc', '5'], ['Fem', 'F', 'Sing', 'S', 'Nom', '1'], ['Fem', 'F', 'Sing', 'S', 'Gen', '2'], ['Fem', 'F', 'Sing', 'S', 'Dat', '3'], ['Fem', 'F', 'Sing', 'S', 'Acc', '4'], ['Fem', 'F', 'Sing', 'S', 'Voc', '5'], ['Fem', 'F', 'Sing', 'S', 'Loc', '6'], ['Fem', 'F', 'Sing', 'S', 'Ins', '7'], ['Fem', 'F', 'Plur', 'P', 'Nom', '1'], ['Fem', 'F', 'Plur', 'P', 'Acc', '4'], ['Fem', 'F', 'Plur', 'P', 'Voc', '5'], ['Neut', 'N', 'Sing', 'S', 'Nom', '1'], ['Neut', 'N', 'Sing', 'S', 'Acc', '4'], ['Neut', 'N', 'Sing', 'S', 'Voc', '5'], ['Neut', 'N', 'Plur', 'P', 'Nom', '1'], ['Neut', 'N', 'Plur', 'P', 'Acc', '4'], ['Neut', 'N', 'Plur', 'P', 'Voc', '5']]],
                'mlazšie'   => ['mladý', 'mladý', [['Fem', 'F', 'Sing', 'S', 'Gen', '2'], ['Fem', 'F', 'Plur', 'P', 'Acc', '4'], ['Neut', 'N', 'Sing', 'S', 'Nom', '1'], ['Neut', 'N', 'Sing', 'S', 'Acc', '4']]],
                'mlazšieho' => ['mladý', 'mladý', [['Anim', 'M', 'Sing', 'S', 'Gen', '2'], ['Anim', 'M', 'Sing', 'S', 'Acc', '4'], ['Inan', 'I', 'Sing', 'S', 'Gen', '2'], ['Neut', 'N', 'Sing', 'S', 'Gen', '2']]],
                'mlazšiej'  => ['mladý', 'mladý', [['Fem', 'F', 'Sing', 'S', 'Dat', '3'], ['Fem', 'F', 'Sing', 'S', 'Loc', '6']]],
                'mlazšiem'  => ['mladý', 'mladý', [['Neut', 'N', 'Sing', 'S', 'Loc', '6']]],
                'mlazšiemu' => ['mladý', 'mladý', [['Anim', 'M', 'Sing', 'S', 'Dat', '3'], ['Inan', 'I', 'Sing', 'S', 'Dat', '3'], ['Neut', 'N', 'Sing', 'S', 'Dat', '3']]],
                'mlazšího'  => ['mladý', 'mladý', [['Anim', 'M', 'Sing', 'S', 'Gen', '2'], ['Anim', 'M', 'Sing', 'S', 'Acc', '4'], ['Inan', 'I', 'Sing', 'S', 'Gen', '2'], ['Neut', 'N', 'Sing', 'S', 'Gen', '2']]],
                'mlazších'  => ['mladý', 'mladý', [['Anim', 'M', 'Plur', 'P', 'Gen', '2'], ['Anim', 'M', 'Plur', 'P', 'Loc', '6'], ['Inan', 'I', 'Plur', 'P', 'Gen', '2'], ['Inan', 'I', 'Plur', 'P', 'Loc', '6'], ['Fem', 'F', 'Plur', 'P', 'Gen', '2'], ['Fem', 'F', 'Plur', 'P', 'Loc', '6'], ['Neut', 'N', 'Plur', 'P', 'Gen', '2'], ['Neut', 'N', 'Plur', 'P', 'Loc', '6']]],
                'mlazším'   => ['mladý', 'mladý', [['Anim', 'M', 'Sing', 'S', 'Loc', '6'], ['Anim', 'M', 'Sing', 'S', 'Ins', '7'], ['Anim', 'M', 'Plur', 'P', 'Dat', '3'], ['Inan', 'I', 'Sing', 'S', 'Loc', '6'], ['Inan', 'I', 'Sing', 'S', 'Ins', '7'], ['Inan', 'I', 'Plur', 'P', 'Dat', '3'], ['Fem', 'F', 'Plur', 'P', 'Dat', '3'], ['Neut', 'N', 'Sing', 'S', 'Loc', '6'], ['Neut', 'N', 'Sing', 'S', 'Ins', '7'], ['Neut', 'N', 'Plur', 'P', 'Dat', '3']]],
                'mlazšími'  => ['mladý', 'mladý', [['Anim', 'M', 'Plur', 'P', 'Ins', '7'], ['Inan', 'I', 'Plur', 'P', 'Ins', '7'], ['Fem', 'F', 'Plur', 'P', 'Ins', '7'], ['Neut', 'N', 'Plur', 'P', 'Ins', '7']]],
                'mlazšímu'  => ['mladý', 'mladý', [['Anim', 'M', 'Sing', 'S', 'Dat', '3'], ['Inan', 'I', 'Sing', 'S', 'Dat', '3'], ['Neut', 'N', 'Sing', 'S', 'Dat', '3']]],
                'mlazšú'    => ['mladý', 'mladý', [['Fem', 'F', 'Sing', 'S', 'Acc', '4']]]
            );
            my $ma = $ma{$lform}; die("Something is wrong: '$lform'") if(!defined($ma));
            $f[2] = $ma->[0];
            $f[9] = set_lemma1300($f[9], $ma->[1]);
            $f[3] = 'ADJ';
            # U některých slov umožňujeme několik čtení, ale pokud to není žádné z nich, dáme první jako default.
            my @alt = @{$ma->[2]};
            for(my $i = $#alt; $i >= 0 ; $i--)
            {
                my $animacy = $alt[$i][0] =~ m/^(Anim|Inan)$/ ? $alt[$i][0] : undef;
                my $gender = $alt[$i][0] =~ m/^(Anim|Inan)$/ ? 'Masc' : $alt[$i][0];
                my $number = $alt[$i][2];
                my $case = $alt[$i][4];
                if($i == 0 || defined($alt[$i][6]) && get_ref($f[9]) =~ m/^$alt[$i][6]$/ || !defined($alt[$i][6]) && $f[5] =~ m/Case=$case.*Gender=$gender.*Number=$number/)
                {
                    $f[4] = 'AA'.$alt[$i][1].$alt[$i][3].$alt[$i][5]."----${d}A----";
                    $f[5] = "Case=$case|Degree=$degree|Gender=$gender|Number=$number|Polarity=Pos";
                    $f[5] = "Animacy=$animacy|$f[5]" if(defined($animacy));
                    last;
                }
            }
        }
        # Většinou "syn Davidóv", "synu Davidóv", "synu Davidovu", ale "rodu Davidova".
        elsif($f[1] =~ m/^(Abraham|Al(f|ph)e|Belzebub|David|Erod|Herodes|Izaiáš|Izák|Jakub|Jan|Ježíš|Jozef|Mojžieš|Ozěp|Petr|Šalomún|Zachař|Zebede(áš|us)?)(óv|ova|ově|ovo|ovu|ovú|ovy|ových)$/i)
        {
            my $lform = lc($f[1]);
            my %ma =
            (
                'abrahamóv'    => ['Abrahamův', 'Abrahamóv', [['Anim', 'M', 'Sing', 'S', 'Nom', '1'], ['Anim', 'M', 'Sing', 'S', 'Voc', '5']]],
                'abrahamova'   => ['Abrahamův', 'Abrahamóv', [['Anim', 'M', 'Sing', 'S', 'Gen', '2'], ['Anim', 'M', 'Sing', 'S', 'Acc', '4'], ['Fem', 'F', 'Sing', 'S', 'Nom', '1'], ['Fem', 'F', 'Sing', 'S', 'Voc', '5'], ['Neut', 'N', 'Sing', 'S', 'Gen', '2'], ['Neut', 'N', 'Plur', 'P', 'Nom', '1'], ['Neut', 'N', 'Plur', 'P', 'Acc', '4'], ['Neut', 'N', 'Plur', 'P', 'Voc', '5']]],
                'abrahamově'   => ['Abrahamův', 'Abrahamóv', [['Anim', 'M', 'Sing', 'S', 'Loc', '6'], ['Fem', 'F', 'Sing', 'S', 'Dat', '3'], ['Fem', 'F', 'Sing', 'S', 'Loc', '6'], ['Neut', 'N', 'Sing', 'S', 'Loc', '6']]],
                'abrahamovi'   => ['Abrahamův', 'Abrahamóv', [['Anim', 'M', 'Plur', 'P', 'Nom', '1'], ['Anim', 'M', 'Plur', 'P', 'Voc', '5']]],
                'abrahamovo'   => ['Abrahamův', 'Abrahamóv', [['Neut', 'N', 'Sing', 'S', 'Nom', '1'], ['Neut', 'N', 'Sing', 'S', 'Acc', '4'], ['Neut', 'N', 'Sing', 'S', 'Voc', '5']]],
                'abrahamovou'  => ['Abrahamův', 'Abrahamóv', [['Fem', 'F', 'Sing', 'S', 'Ins', '7']]],
                'abrahamovu'   => ['Abrahamův', 'Abrahamóv', [['Anim', 'M', 'Sing', 'S', 'Dat', '3'], ['Fem', 'F', 'Sing', 'S', 'Acc', '4'], ['Neut', 'N', 'Sing', 'S', 'Dat', '3']]],
                'abrahamovú'   => ['Abrahamův', 'Abrahamóv', [['Fem', 'F', 'Sing', 'S', 'Ins', '7']]],
                'abrahamovy'   => ['Abrahamův', 'Abrahamóv', [['Anim', 'M', 'Plur', 'P', 'Acc', '4'], ['Fem', 'F', 'Sing', 'S', 'Gen', '2'], ['Fem', 'F', 'Plur', 'P', 'Nom', '1'], ['Fem', 'F', 'Plur', 'P', 'Acc', '4'], ['Fem', 'F', 'Plur', 'P', 'Voc', '5']]],
                'abrahamových' => ['Abrahamův', 'Abrahamóv', [['Anim', 'M', 'Plur', 'P', 'Gen', '2'], ['Anim', 'M', 'Plur', 'P', 'Loc', '6'], ['Fem', 'F', 'Plur', 'P', 'Gen', '2'], ['Fem', 'F', 'Plur', 'P', 'Loc', '6'], ['Neut', 'N', 'Plur', 'P', 'Gen', '2'], ['Neut', 'N', 'Plur', 'P', 'Loc', '6']]],
                'abrahamovým'  => ['Abrahamův', 'Abrahamóv', [['Anim', 'M', 'Sing', 'S', 'Ins', '7'], ['Anim', 'M', 'Plur', 'P', 'Dat', '3'], ['Fem', 'F', 'Plur', 'P', 'Dat', '3'], ['Neut', 'N', 'Sing', 'S', 'Ins', '7'], ['Neut', 'N', 'Plur', 'P', 'Dat', '3']]],
                'abrahamovými' => ['Abrahamův', 'Abrahamóv', [['Anim', 'M', 'Plur', 'P', 'Ins', '7'], ['Fem', 'F', 'Plur', 'P', 'Ins', '7'], ['Neut', 'N', 'Plur', 'P', 'Ins', '7']]],
                'abrahamuov'   => ['Abrahamův', 'Abrahamóv', [['Anim', 'M', 'Sing', 'S', 'Nom', '1'], ['Anim', 'M', 'Sing', 'S', 'Voc', '5']]],
                'abrahamův'    => ['Abrahamův', 'Abrahamóv', [['Anim', 'M', 'Sing', 'S', 'Nom', '1'], ['Anim', 'M', 'Sing', 'S', 'Voc', '5']]],
                'alfeóv'     => ['Alfeusův', 'Alfeóv', [['Anim', 'M', 'Sing', 'S', 'Nom', '1'], ['Anim', 'M', 'Sing', 'S', 'Voc', '5']]],
                'alfeova'    => ['Alfeusův', 'Alfeóv', [['Anim', 'M', 'Sing', 'S', 'Gen', '2'], ['Anim', 'M', 'Sing', 'S', 'Acc', '4'], ['Fem', 'F', 'Sing', 'S', 'Nom', '1'], ['Fem', 'F', 'Sing', 'S', 'Voc', '5'], ['Neut', 'N', 'Sing', 'S', 'Gen', '2'], ['Neut', 'N', 'Plur', 'P', 'Nom', '1'], ['Neut', 'N', 'Plur', 'P', 'Acc', '4'], ['Neut', 'N', 'Plur', 'P', 'Voc', '5']]],
                'alfeově'    => ['Alfeusův', 'Alfeóv', [['Anim', 'M', 'Sing', 'S', 'Loc', '6'], ['Fem', 'F', 'Sing', 'S', 'Dat', '3'], ['Fem', 'F', 'Sing', 'S', 'Loc', '6'], ['Neut', 'N', 'Sing', 'S', 'Loc', '6']]],
                'alfeovi'    => ['Alfeusův', 'Alfeóv', [['Anim', 'M', 'Plur', 'P', 'Nom', '1'], ['Anim', 'M', 'Plur', 'P', 'Voc', '5']]],
                'alfeovo'    => ['Alfeusův', 'Alfeóv', [['Neut', 'N', 'Sing', 'S', 'Nom', '1'], ['Neut', 'N', 'Sing', 'S', 'Acc', '4'], ['Neut', 'N', 'Sing', 'S', 'Voc', '5']]],
                'alfeovou'   => ['Alfeusův', 'Alfeóv', [['Fem', 'F', 'Sing', 'S', 'Ins', '7']]],
                'alfeovu'    => ['Alfeusův', 'Alfeóv', [['Anim', 'M', 'Sing', 'S', 'Dat', '3'], ['Fem', 'F', 'Sing', 'S', 'Acc', '4'], ['Neut', 'N', 'Sing', 'S', 'Dat', '3']]],
                'alfeovú'    => ['Alfeusův', 'Alfeóv', [['Fem', 'F', 'Sing', 'S', 'Ins', '7']]],
                'alfeovy'    => ['Alfeusův', 'Alfeóv', [['Anim', 'M', 'Plur', 'P', 'Acc', '4'], ['Fem', 'F', 'Sing', 'S', 'Gen', '2'], ['Fem', 'F', 'Plur', 'P', 'Nom', '1'], ['Fem', 'F', 'Plur', 'P', 'Acc', '4'], ['Fem', 'F', 'Plur', 'P', 'Voc', '5']]],
                'alfeových'  => ['Alfeusův', 'Alfeóv', [['Anim', 'M', 'Plur', 'P', 'Gen', '2'], ['Anim', 'M', 'Plur', 'P', 'Loc', '6'], ['Fem', 'F', 'Plur', 'P', 'Gen', '2'], ['Fem', 'F', 'Plur', 'P', 'Loc', '6'], ['Neut', 'N', 'Plur', 'P', 'Gen', '2'], ['Neut', 'N', 'Plur', 'P', 'Loc', '6']]],
                'alfeovým'   => ['Alfeusův', 'Alfeóv', [['Anim', 'M', 'Sing', 'S', 'Ins', '7'], ['Anim', 'M', 'Plur', 'P', 'Dat', '3'], ['Fem', 'F', 'Plur', 'P', 'Dat', '3'], ['Neut', 'N', 'Sing', 'S', 'Ins', '7'], ['Neut', 'N', 'Plur', 'P', 'Dat', '3']]],
                'alfeovými'  => ['Alfeusův', 'Alfeóv', [['Anim', 'M', 'Plur', 'P', 'Ins', '7'], ['Fem', 'F', 'Plur', 'P', 'Ins', '7'], ['Neut', 'N', 'Plur', 'P', 'Ins', '7']]],
                'alfeuov'    => ['Alfeusův', 'Alfeóv', [['Anim', 'M', 'Sing', 'S', 'Nom', '1'], ['Anim', 'M', 'Sing', 'S', 'Voc', '5']]],
                'alfeův'     => ['Alfeusův', 'Alfeóv', [['Anim', 'M', 'Sing', 'S', 'Nom', '1'], ['Anim', 'M', 'Sing', 'S', 'Voc', '5']]],
                'alpheóv'    => ['Alfeusův', 'Alfeóv', [['Anim', 'M', 'Sing', 'S', 'Nom', '1'], ['Anim', 'M', 'Sing', 'S', 'Voc', '5']]],
                'alpheova'   => ['Alfeusův', 'Alfeóv', [['Anim', 'M', 'Sing', 'S', 'Gen', '2'], ['Anim', 'M', 'Sing', 'S', 'Acc', '4'], ['Fem', 'F', 'Sing', 'S', 'Nom', '1'], ['Fem', 'F', 'Sing', 'S', 'Voc', '5'], ['Neut', 'N', 'Sing', 'S', 'Gen', '2'], ['Neut', 'N', 'Plur', 'P', 'Nom', '1'], ['Neut', 'N', 'Plur', 'P', 'Acc', '4'], ['Neut', 'N', 'Plur', 'P', 'Voc', '5']]],
                'alpheově'   => ['Alfeusův', 'Alfeóv', [['Anim', 'M', 'Sing', 'S', 'Loc', '6'], ['Fem', 'F', 'Sing', 'S', 'Dat', '3'], ['Fem', 'F', 'Sing', 'S', 'Loc', '6'], ['Neut', 'N', 'Sing', 'S', 'Loc', '6']]],
                'alpheovi'   => ['Alfeusův', 'Alfeóv', [['Anim', 'M', 'Plur', 'P', 'Nom', '1'], ['Anim', 'M', 'Plur', 'P', 'Voc', '5']]],
                'alpheovo'   => ['Alfeusův', 'Alfeóv', [['Neut', 'N', 'Sing', 'S', 'Nom', '1'], ['Neut', 'N', 'Sing', 'S', 'Acc', '4'], ['Neut', 'N', 'Sing', 'S', 'Voc', '5']]],
                'alpheovou'  => ['Alfeusův', 'Alfeóv', [['Fem', 'F', 'Sing', 'S', 'Ins', '7']]],
                'alpheovu'   => ['Alfeusův', 'Alfeóv', [['Anim', 'M', 'Sing', 'S', 'Dat', '3'], ['Fem', 'F', 'Sing', 'S', 'Acc', '4'], ['Neut', 'N', 'Sing', 'S', 'Dat', '3']]],
                'alpheovú'   => ['Alfeusův', 'Alfeóv', [['Fem', 'F', 'Sing', 'S', 'Ins', '7']]],
                'alpheovy'   => ['Alfeusův', 'Alfeóv', [['Anim', 'M', 'Plur', 'P', 'Acc', '4'], ['Fem', 'F', 'Sing', 'S', 'Gen', '2'], ['Fem', 'F', 'Plur', 'P', 'Nom', '1'], ['Fem', 'F', 'Plur', 'P', 'Acc', '4'], ['Fem', 'F', 'Plur', 'P', 'Voc', '5']]],
                'alpheových' => ['Alfeusův', 'Alfeóv', [['Anim', 'M', 'Plur', 'P', 'Gen', '2'], ['Anim', 'M', 'Plur', 'P', 'Loc', '6'], ['Fem', 'F', 'Plur', 'P', 'Gen', '2'], ['Fem', 'F', 'Plur', 'P', 'Loc', '6'], ['Neut', 'N', 'Plur', 'P', 'Gen', '2'], ['Neut', 'N', 'Plur', 'P', 'Loc', '6']]],
                'alpheovým'  => ['Alfeusův', 'Alfeóv', [['Anim', 'M', 'Sing', 'S', 'Ins', '7'], ['Anim', 'M', 'Plur', 'P', 'Dat', '3'], ['Fem', 'F', 'Plur', 'P', 'Dat', '3'], ['Neut', 'N', 'Sing', 'S', 'Ins', '7'], ['Neut', 'N', 'Plur', 'P', 'Dat', '3']]],
                'alpheovými' => ['Alfeusův', 'Alfeóv', [['Anim', 'M', 'Plur', 'P', 'Ins', '7'], ['Fem', 'F', 'Plur', 'P', 'Ins', '7'], ['Neut', 'N', 'Plur', 'P', 'Ins', '7']]],
                'alpheuov'   => ['Alfeusův', 'Alfeóv', [['Anim', 'M', 'Sing', 'S', 'Nom', '1'], ['Anim', 'M', 'Sing', 'S', 'Voc', '5']]],
                'alpheův'    => ['Alfeusův', 'Alfeóv', [['Anim', 'M', 'Sing', 'S', 'Nom', '1'], ['Anim', 'M', 'Sing', 'S', 'Voc', '5']]],
                'belzebubóv'    => ['Belzebubův', 'Belzebubóv', [['Anim', 'M', 'Sing', 'S', 'Nom', '1'], ['Anim', 'M', 'Sing', 'S', 'Voc', '5']]],
                'belzebubova'   => ['Belzebubův', 'Belzebubóv', [['Anim', 'M', 'Sing', 'S', 'Gen', '2'], ['Anim', 'M', 'Sing', 'S', 'Acc', '4'], ['Fem', 'F', 'Sing', 'S', 'Nom', '1'], ['Fem', 'F', 'Sing', 'S', 'Voc', '5'], ['Neut', 'N', 'Sing', 'S', 'Gen', '2'], ['Neut', 'N', 'Plur', 'P', 'Nom', '1'], ['Neut', 'N', 'Plur', 'P', 'Acc', '4'], ['Neut', 'N', 'Plur', 'P', 'Voc', '5']]],
                'belzebubově'   => ['Belzebubův', 'Belzebubóv', [['Anim', 'M', 'Sing', 'S', 'Loc', '6'], ['Fem', 'F', 'Sing', 'S', 'Dat', '3'], ['Fem', 'F', 'Sing', 'S', 'Loc', '6'], ['Neut', 'N', 'Sing', 'S', 'Loc', '6']]],
                'belzebubovi'   => ['Belzebubův', 'Belzebubóv', [['Anim', 'M', 'Plur', 'P', 'Nom', '1'], ['Anim', 'M', 'Plur', 'P', 'Voc', '5']]],
                'belzebubovo'   => ['Belzebubův', 'Belzebubóv', [['Neut', 'N', 'Sing', 'S', 'Nom', '1'], ['Neut', 'N', 'Sing', 'S', 'Acc', '4'], ['Neut', 'N', 'Sing', 'S', 'Voc', '5']]],
                'belzebubovou'  => ['Belzebubův', 'Belzebubóv', [['Fem', 'F', 'Sing', 'S', 'Ins', '7']]],
                'belzebubovu'   => ['Belzebubův', 'Belzebubóv', [['Anim', 'M', 'Sing', 'S', 'Dat', '3'], ['Fem', 'F', 'Sing', 'S', 'Acc', '4'], ['Neut', 'N', 'Sing', 'S', 'Dat', '3']]],
                'belzebubovú'   => ['Belzebubův', 'Belzebubóv', [['Fem', 'F', 'Sing', 'S', 'Ins', '7']]],
                'belzebubovy'   => ['Belzebubův', 'Belzebubóv', [['Anim', 'M', 'Plur', 'P', 'Acc', '4'], ['Fem', 'F', 'Sing', 'S', 'Gen', '2'], ['Fem', 'F', 'Plur', 'P', 'Nom', '1'], ['Fem', 'F', 'Plur', 'P', 'Acc', '4'], ['Fem', 'F', 'Plur', 'P', 'Voc', '5']]],
                'belzebubových' => ['Belzebubův', 'Belzebubóv', [['Anim', 'M', 'Plur', 'P', 'Gen', '2'], ['Anim', 'M', 'Plur', 'P', 'Loc', '6'], ['Fem', 'F', 'Plur', 'P', 'Gen', '2'], ['Fem', 'F', 'Plur', 'P', 'Loc', '6'], ['Neut', 'N', 'Plur', 'P', 'Gen', '2'], ['Neut', 'N', 'Plur', 'P', 'Loc', '6']]],
                'belzebubovým'  => ['Belzebubův', 'Belzebubóv', [['Anim', 'M', 'Sing', 'S', 'Ins', '7'], ['Anim', 'M', 'Plur', 'P', 'Dat', '3'], ['Fem', 'F', 'Plur', 'P', 'Dat', '3'], ['Neut', 'N', 'Sing', 'S', 'Ins', '7'], ['Neut', 'N', 'Plur', 'P', 'Dat', '3']]],
                'belzebubovými' => ['Belzebubův', 'Belzebubóv', [['Anim', 'M', 'Plur', 'P', 'Ins', '7'], ['Fem', 'F', 'Plur', 'P', 'Ins', '7'], ['Neut', 'N', 'Plur', 'P', 'Ins', '7']]],
                'belzebubuov'   => ['Belzebubův', 'Belzebubóv', [['Anim', 'M', 'Sing', 'S', 'Nom', '1'], ['Anim', 'M', 'Sing', 'S', 'Voc', '5']]],
                'belzebubův'    => ['Belzebubův', 'Belzebubóv', [['Anim', 'M', 'Sing', 'S', 'Nom', '1'], ['Anim', 'M', 'Sing', 'S', 'Voc', '5']]],
                'davidóv'    => ['Davidův', 'Davidóv', [['Anim', 'M', 'Sing', 'S', 'Nom', '1'], ['Anim', 'M', 'Sing', 'S', 'Voc', '5']]],
                'davidova'   => ['Davidův', 'Davidóv', [['Anim', 'M', 'Sing', 'S', 'Gen', '2'], ['Anim', 'M', 'Sing', 'S', 'Acc', '4'], ['Fem', 'F', 'Sing', 'S', 'Nom', '1'], ['Fem', 'F', 'Sing', 'S', 'Voc', '5'], ['Neut', 'N', 'Sing', 'S', 'Gen', '2'], ['Neut', 'N', 'Plur', 'P', 'Nom', '1'], ['Neut', 'N', 'Plur', 'P', 'Acc', '4'], ['Neut', 'N', 'Plur', 'P', 'Voc', '5']]],
                'davidově'   => ['Davidův', 'Davidóv', [['Anim', 'M', 'Sing', 'S', 'Loc', '6'], ['Fem', 'F', 'Sing', 'S', 'Dat', '3'], ['Fem', 'F', 'Sing', 'S', 'Loc', '6'], ['Neut', 'N', 'Sing', 'S', 'Loc', '6']]],
                'davidovi'   => ['Davidův', 'Davidóv', [['Anim', 'M', 'Plur', 'P', 'Nom', '1'], ['Anim', 'M', 'Plur', 'P', 'Voc', '5']]],
                'davidovo'   => ['Davidův', 'Davidóv', [['Neut', 'N', 'Sing', 'S', 'Nom', '1'], ['Neut', 'N', 'Sing', 'S', 'Acc', '4'], ['Neut', 'N', 'Sing', 'S', 'Voc', '5']]],
                'davidovou'  => ['Davidův', 'Davidóv', [['Fem', 'F', 'Sing', 'S', 'Ins', '7']]],
                'davidovu'   => ['Davidův', 'Davidóv', [['Anim', 'M', 'Sing', 'S', 'Dat', '3'], ['Fem', 'F', 'Sing', 'S', 'Acc', '4'], ['Neut', 'N', 'Sing', 'S', 'Dat', '3']]],
                'davidovú'   => ['Davidův', 'Davidóv', [['Fem', 'F', 'Sing', 'S', 'Ins', '7']]],
                'davidovy'   => ['Davidův', 'Davidóv', [['Anim', 'M', 'Plur', 'P', 'Acc', '4'], ['Fem', 'F', 'Sing', 'S', 'Gen', '2'], ['Fem', 'F', 'Plur', 'P', 'Nom', '1'], ['Fem', 'F', 'Plur', 'P', 'Acc', '4'], ['Fem', 'F', 'Plur', 'P', 'Voc', '5']]],
                'davidových' => ['Davidův', 'Davidóv', [['Anim', 'M', 'Plur', 'P', 'Gen', '2'], ['Anim', 'M', 'Plur', 'P', 'Loc', '6'], ['Fem', 'F', 'Plur', 'P', 'Gen', '2'], ['Fem', 'F', 'Plur', 'P', 'Loc', '6'], ['Neut', 'N', 'Plur', 'P', 'Gen', '2'], ['Neut', 'N', 'Plur', 'P', 'Loc', '6']]],
                'davidovým'  => ['Davidův', 'Davidóv', [['Anim', 'M', 'Sing', 'S', 'Ins', '7'], ['Anim', 'M', 'Plur', 'P', 'Dat', '3'], ['Fem', 'F', 'Plur', 'P', 'Dat', '3'], ['Neut', 'N', 'Sing', 'S', 'Ins', '7'], ['Neut', 'N', 'Plur', 'P', 'Dat', '3']]],
                'davidovými' => ['Davidův', 'Davidóv', [['Anim', 'M', 'Plur', 'P', 'Ins', '7'], ['Fem', 'F', 'Plur', 'P', 'Ins', '7'], ['Neut', 'N', 'Plur', 'P', 'Ins', '7']]],
                'daviduov'   => ['Davidův', 'Davidóv', [['Anim', 'M', 'Sing', 'S', 'Nom', '1'], ['Anim', 'M', 'Sing', 'S', 'Voc', '5']]],
                'davidův'    => ['Davidův', 'Davidóv', [['Anim', 'M', 'Sing', 'S', 'Nom', '1'], ['Anim', 'M', 'Sing', 'S', 'Voc', '5']]],
                'erodesóv'     => ['Herodesův', 'Herodóv', [['Anim', 'M', 'Sing', 'S', 'Nom', '1'], ['Anim', 'M', 'Sing', 'S', 'Voc', '5']]],
                'erodesova'    => ['Herodesův', 'Herodóv', [['Anim', 'M', 'Sing', 'S', 'Gen', '2'], ['Anim', 'M', 'Sing', 'S', 'Acc', '4'], ['Fem', 'F', 'Sing', 'S', 'Nom', '1'], ['Fem', 'F', 'Sing', 'S', 'Voc', '5'], ['Neut', 'N', 'Sing', 'S', 'Gen', '2'], ['Neut', 'N', 'Plur', 'P', 'Nom', '1'], ['Neut', 'N', 'Plur', 'P', 'Acc', '4'], ['Neut', 'N', 'Plur', 'P', 'Voc', '5']]],
                'erodesově'    => ['Herodesův', 'Herodóv', [['Anim', 'M', 'Sing', 'S', 'Loc', '6'], ['Fem', 'F', 'Sing', 'S', 'Dat', '3'], ['Fem', 'F', 'Sing', 'S', 'Loc', '6'], ['Neut', 'N', 'Sing', 'S', 'Loc', '6']]],
                'erodesovi'    => ['Herodesův', 'Herodóv', [['Anim', 'M', 'Plur', 'P', 'Nom', '1'], ['Anim', 'M', 'Plur', 'P', 'Voc', '5']]],
                'erodesovo'    => ['Herodesův', 'Herodóv', [['Neut', 'N', 'Sing', 'S', 'Nom', '1'], ['Neut', 'N', 'Sing', 'S', 'Acc', '4'], ['Neut', 'N', 'Sing', 'S', 'Voc', '5']]],
                'erodesovou'   => ['Herodesův', 'Herodóv', [['Fem', 'F', 'Sing', 'S', 'Ins', '7']]],
                'erodesovu'    => ['Herodesův', 'Herodóv', [['Anim', 'M', 'Sing', 'S', 'Dat', '3'], ['Fem', 'F', 'Sing', 'S', 'Acc', '4'], ['Neut', 'N', 'Sing', 'S', 'Dat', '3']]],
                'erodesovú'    => ['Herodesův', 'Herodóv', [['Fem', 'F', 'Sing', 'S', 'Ins', '7']]],
                'erodesovy'    => ['Herodesův', 'Herodóv', [['Anim', 'M', 'Plur', 'P', 'Acc', '4'], ['Fem', 'F', 'Sing', 'S', 'Gen', '2'], ['Fem', 'F', 'Plur', 'P', 'Nom', '1'], ['Fem', 'F', 'Plur', 'P', 'Acc', '4'], ['Fem', 'F', 'Plur', 'P', 'Voc', '5']]],
                'erodesových'  => ['Herodesův', 'Herodóv', [['Anim', 'M', 'Plur', 'P', 'Gen', '2'], ['Anim', 'M', 'Plur', 'P', 'Loc', '6'], ['Fem', 'F', 'Plur', 'P', 'Gen', '2'], ['Fem', 'F', 'Plur', 'P', 'Loc', '6'], ['Neut', 'N', 'Plur', 'P', 'Gen', '2'], ['Neut', 'N', 'Plur', 'P', 'Loc', '6']]],
                'erodesovým'   => ['Herodesův', 'Herodóv', [['Anim', 'M', 'Sing', 'S', 'Ins', '7'], ['Anim', 'M', 'Plur', 'P', 'Dat', '3'], ['Fem', 'F', 'Plur', 'P', 'Dat', '3'], ['Neut', 'N', 'Sing', 'S', 'Ins', '7'], ['Neut', 'N', 'Plur', 'P', 'Dat', '3']]],
                'erodesovými'  => ['Herodesův', 'Herodóv', [['Anim', 'M', 'Plur', 'P', 'Ins', '7'], ['Fem', 'F', 'Plur', 'P', 'Ins', '7'], ['Neut', 'N', 'Plur', 'P', 'Ins', '7']]],
                'erodesuov'    => ['Herodesův', 'Herodóv', [['Anim', 'M', 'Sing', 'S', 'Nom', '1'], ['Anim', 'M', 'Sing', 'S', 'Voc', '5']]],
                'erodesův'     => ['Herodesův', 'Herodóv', [['Anim', 'M', 'Sing', 'S', 'Nom', '1'], ['Anim', 'M', 'Sing', 'S', 'Voc', '5']]],
                'erodóv'       => ['Herodesův', 'Herodóv', [['Anim', 'M', 'Sing', 'S', 'Nom', '1'], ['Anim', 'M', 'Sing', 'S', 'Voc', '5']]],
                'erodova'      => ['Herodesův', 'Herodóv', [['Anim', 'M', 'Sing', 'S', 'Gen', '2'], ['Anim', 'M', 'Sing', 'S', 'Acc', '4'], ['Fem', 'F', 'Sing', 'S', 'Nom', '1'], ['Fem', 'F', 'Sing', 'S', 'Voc', '5'], ['Neut', 'N', 'Sing', 'S', 'Gen', '2'], ['Neut', 'N', 'Plur', 'P', 'Nom', '1'], ['Neut', 'N', 'Plur', 'P', 'Acc', '4'], ['Neut', 'N', 'Plur', 'P', 'Voc', '5']]],
                'erodově'      => ['Herodesův', 'Herodóv', [['Anim', 'M', 'Sing', 'S', 'Loc', '6'], ['Fem', 'F', 'Sing', 'S', 'Dat', '3'], ['Fem', 'F', 'Sing', 'S', 'Loc', '6'], ['Neut', 'N', 'Sing', 'S', 'Loc', '6']]],
                'erodovi'      => ['Herodesův', 'Herodóv', [['Anim', 'M', 'Plur', 'P', 'Nom', '1'], ['Anim', 'M', 'Plur', 'P', 'Voc', '5']]],
                'erodovo'      => ['Herodesův', 'Herodóv', [['Neut', 'N', 'Sing', 'S', 'Nom', '1'], ['Neut', 'N', 'Sing', 'S', 'Acc', '4'], ['Neut', 'N', 'Sing', 'S', 'Voc', '5']]],
                'erodovou'     => ['Herodesův', 'Herodóv', [['Fem', 'F', 'Sing', 'S', 'Ins', '7']]],
                'erodovu'      => ['Herodesův', 'Herodóv', [['Anim', 'M', 'Sing', 'S', 'Dat', '3'], ['Fem', 'F', 'Sing', 'S', 'Acc', '4'], ['Neut', 'N', 'Sing', 'S', 'Dat', '3']]],
                'erodovú'      => ['Herodesův', 'Herodóv', [['Fem', 'F', 'Sing', 'S', 'Ins', '7']]],
                'erodovy'      => ['Herodesův', 'Herodóv', [['Anim', 'M', 'Plur', 'P', 'Acc', '4'], ['Fem', 'F', 'Sing', 'S', 'Gen', '2'], ['Fem', 'F', 'Plur', 'P', 'Nom', '1'], ['Fem', 'F', 'Plur', 'P', 'Acc', '4'], ['Fem', 'F', 'Plur', 'P', 'Voc', '5']]],
                'erodových'    => ['Herodesův', 'Herodóv', [['Anim', 'M', 'Plur', 'P', 'Gen', '2'], ['Anim', 'M', 'Plur', 'P', 'Loc', '6'], ['Fem', 'F', 'Plur', 'P', 'Gen', '2'], ['Fem', 'F', 'Plur', 'P', 'Loc', '6'], ['Neut', 'N', 'Plur', 'P', 'Gen', '2'], ['Neut', 'N', 'Plur', 'P', 'Loc', '6']]],
                'erodovým'     => ['Herodesův', 'Herodóv', [['Anim', 'M', 'Sing', 'S', 'Ins', '7'], ['Anim', 'M', 'Plur', 'P', 'Dat', '3'], ['Fem', 'F', 'Plur', 'P', 'Dat', '3'], ['Neut', 'N', 'Sing', 'S', 'Ins', '7'], ['Neut', 'N', 'Plur', 'P', 'Dat', '3']]],
                'erodovými'    => ['Herodesův', 'Herodóv', [['Anim', 'M', 'Plur', 'P', 'Ins', '7'], ['Fem', 'F', 'Plur', 'P', 'Ins', '7'], ['Neut', 'N', 'Plur', 'P', 'Ins', '7']]],
                'eroduov'      => ['Herodesův', 'Herodóv', [['Anim', 'M', 'Sing', 'S', 'Nom', '1'], ['Anim', 'M', 'Sing', 'S', 'Voc', '5']]],
                'erodův'       => ['Herodesův', 'Herodóv', [['Anim', 'M', 'Sing', 'S', 'Nom', '1'], ['Anim', 'M', 'Sing', 'S', 'Voc', '5']]],
                'herodesóv'    => ['Herodesův', 'Herodóv', [['Anim', 'M', 'Sing', 'S', 'Nom', '1'], ['Anim', 'M', 'Sing', 'S', 'Voc', '5']]],
                'herodesova'   => ['Herodesův', 'Herodóv', [['Anim', 'M', 'Sing', 'S', 'Gen', '2'], ['Anim', 'M', 'Sing', 'S', 'Acc', '4'], ['Fem', 'F', 'Sing', 'S', 'Nom', '1'], ['Fem', 'F', 'Sing', 'S', 'Voc', '5'], ['Neut', 'N', 'Sing', 'S', 'Gen', '2'], ['Neut', 'N', 'Plur', 'P', 'Nom', '1'], ['Neut', 'N', 'Plur', 'P', 'Acc', '4'], ['Neut', 'N', 'Plur', 'P', 'Voc', '5']]],
                'herodesově'   => ['Herodesův', 'Herodóv', [['Anim', 'M', 'Sing', 'S', 'Loc', '6'], ['Fem', 'F', 'Sing', 'S', 'Dat', '3'], ['Fem', 'F', 'Sing', 'S', 'Loc', '6'], ['Neut', 'N', 'Sing', 'S', 'Loc', '6']]],
                'herodesovi'   => ['Herodesův', 'Herodóv', [['Anim', 'M', 'Plur', 'P', 'Nom', '1'], ['Anim', 'M', 'Plur', 'P', 'Voc', '5']]],
                'herodesovo'   => ['Herodesův', 'Herodóv', [['Neut', 'N', 'Sing', 'S', 'Nom', '1'], ['Neut', 'N', 'Sing', 'S', 'Acc', '4'], ['Neut', 'N', 'Sing', 'S', 'Voc', '5']]],
                'herodesovou'  => ['Herodesův', 'Herodóv', [['Fem', 'F', 'Sing', 'S', 'Ins', '7']]],
                'herodesovu'   => ['Herodesův', 'Herodóv', [['Anim', 'M', 'Sing', 'S', 'Dat', '3'], ['Fem', 'F', 'Sing', 'S', 'Acc', '4'], ['Neut', 'N', 'Sing', 'S', 'Dat', '3']]],
                'herodesovú'   => ['Herodesův', 'Herodóv', [['Fem', 'F', 'Sing', 'S', 'Ins', '7']]],
                'herodesovy'   => ['Herodesův', 'Herodóv', [['Anim', 'M', 'Plur', 'P', 'Acc', '4'], ['Fem', 'F', 'Sing', 'S', 'Gen', '2'], ['Fem', 'F', 'Plur', 'P', 'Nom', '1'], ['Fem', 'F', 'Plur', 'P', 'Acc', '4'], ['Fem', 'F', 'Plur', 'P', 'Voc', '5']]],
                'herodesových' => ['Herodesův', 'Herodóv', [['Anim', 'M', 'Plur', 'P', 'Gen', '2'], ['Anim', 'M', 'Plur', 'P', 'Loc', '6'], ['Fem', 'F', 'Plur', 'P', 'Gen', '2'], ['Fem', 'F', 'Plur', 'P', 'Loc', '6'], ['Neut', 'N', 'Plur', 'P', 'Gen', '2'], ['Neut', 'N', 'Plur', 'P', 'Loc', '6']]],
                'herodesovým'  => ['Herodesův', 'Herodóv', [['Anim', 'M', 'Sing', 'S', 'Ins', '7'], ['Anim', 'M', 'Plur', 'P', 'Dat', '3'], ['Fem', 'F', 'Plur', 'P', 'Dat', '3'], ['Neut', 'N', 'Sing', 'S', 'Ins', '7'], ['Neut', 'N', 'Plur', 'P', 'Dat', '3']]],
                'herodesovými' => ['Herodesův', 'Herodóv', [['Anim', 'M', 'Plur', 'P', 'Ins', '7'], ['Fem', 'F', 'Plur', 'P', 'Ins', '7'], ['Neut', 'N', 'Plur', 'P', 'Ins', '7']]],
                'herodesuov'   => ['Herodesův', 'Herodóv', [['Anim', 'M', 'Sing', 'S', 'Nom', '1'], ['Anim', 'M', 'Sing', 'S', 'Voc', '5']]],
                'herodesův'    => ['Herodesův', 'Herodóv', [['Anim', 'M', 'Sing', 'S', 'Nom', '1'], ['Anim', 'M', 'Sing', 'S', 'Voc', '5']]],
                'herodóv'      => ['Herodesův', 'Herodóv', [['Anim', 'M', 'Sing', 'S', 'Nom', '1'], ['Anim', 'M', 'Sing', 'S', 'Voc', '5']]],
                'herodova'     => ['Herodesův', 'Herodóv', [['Anim', 'M', 'Sing', 'S', 'Gen', '2'], ['Anim', 'M', 'Sing', 'S', 'Acc', '4'], ['Fem', 'F', 'Sing', 'S', 'Nom', '1'], ['Fem', 'F', 'Sing', 'S', 'Voc', '5'], ['Neut', 'N', 'Sing', 'S', 'Gen', '2'], ['Neut', 'N', 'Plur', 'P', 'Nom', '1'], ['Neut', 'N', 'Plur', 'P', 'Acc', '4'], ['Neut', 'N', 'Plur', 'P', 'Voc', '5']]],
                'herodově'     => ['Herodesův', 'Herodóv', [['Anim', 'M', 'Sing', 'S', 'Loc', '6'], ['Fem', 'F', 'Sing', 'S', 'Dat', '3'], ['Fem', 'F', 'Sing', 'S', 'Loc', '6'], ['Neut', 'N', 'Sing', 'S', 'Loc', '6']]],
                'herodovi'     => ['Herodesův', 'Herodóv', [['Anim', 'M', 'Plur', 'P', 'Nom', '1'], ['Anim', 'M', 'Plur', 'P', 'Voc', '5']]],
                'herodovo'     => ['Herodesův', 'Herodóv', [['Neut', 'N', 'Sing', 'S', 'Nom', '1'], ['Neut', 'N', 'Sing', 'S', 'Acc', '4'], ['Neut', 'N', 'Sing', 'S', 'Voc', '5']]],
                'herodovou'    => ['Herodesův', 'Herodóv', [['Fem', 'F', 'Sing', 'S', 'Ins', '7']]],
                'herodovu'     => ['Herodesův', 'Herodóv', [['Anim', 'M', 'Sing', 'S', 'Dat', '3'], ['Fem', 'F', 'Sing', 'S', 'Acc', '4'], ['Neut', 'N', 'Sing', 'S', 'Dat', '3']]],
                'herodovú'     => ['Herodesův', 'Herodóv', [['Fem', 'F', 'Sing', 'S', 'Ins', '7']]],
                'herodovy'     => ['Herodesův', 'Herodóv', [['Anim', 'M', 'Plur', 'P', 'Acc', '4'], ['Fem', 'F', 'Sing', 'S', 'Gen', '2'], ['Fem', 'F', 'Plur', 'P', 'Nom', '1'], ['Fem', 'F', 'Plur', 'P', 'Acc', '4'], ['Fem', 'F', 'Plur', 'P', 'Voc', '5']]],
                'herodových'   => ['Herodesův', 'Herodóv', [['Anim', 'M', 'Plur', 'P', 'Gen', '2'], ['Anim', 'M', 'Plur', 'P', 'Loc', '6'], ['Fem', 'F', 'Plur', 'P', 'Gen', '2'], ['Fem', 'F', 'Plur', 'P', 'Loc', '6'], ['Neut', 'N', 'Plur', 'P', 'Gen', '2'], ['Neut', 'N', 'Plur', 'P', 'Loc', '6']]],
                'herodovým'    => ['Herodesův', 'Herodóv', [['Anim', 'M', 'Sing', 'S', 'Ins', '7'], ['Anim', 'M', 'Plur', 'P', 'Dat', '3'], ['Fem', 'F', 'Plur', 'P', 'Dat', '3'], ['Neut', 'N', 'Sing', 'S', 'Ins', '7'], ['Neut', 'N', 'Plur', 'P', 'Dat', '3']]],
                'herodovými'   => ['Herodesův', 'Herodóv', [['Anim', 'M', 'Plur', 'P', 'Ins', '7'], ['Fem', 'F', 'Plur', 'P', 'Ins', '7'], ['Neut', 'N', 'Plur', 'P', 'Ins', '7']]],
                'heroduov'     => ['Herodesův', 'Herodóv', [['Anim', 'M', 'Sing', 'S', 'Nom', '1'], ['Anim', 'M', 'Sing', 'S', 'Voc', '5']]],
                'herodův'      => ['Herodesův', 'Herodóv', [['Anim', 'M', 'Sing', 'S', 'Nom', '1'], ['Anim', 'M', 'Sing', 'S', 'Voc', '5']]],
                'izaiášóv'    => ['Izaiášův', 'Izaiášóv', [['Anim', 'M', 'Sing', 'S', 'Nom', '1'], ['Anim', 'M', 'Sing', 'S', 'Voc', '5']]],
                'izaiášova'   => ['Izaiášův', 'Izaiášóv', [['Anim', 'M', 'Sing', 'S', 'Gen', '2'], ['Anim', 'M', 'Sing', 'S', 'Acc', '4'], ['Fem', 'F', 'Sing', 'S', 'Nom', '1'], ['Fem', 'F', 'Sing', 'S', 'Voc', '5'], ['Neut', 'N', 'Sing', 'S', 'Gen', '2'], ['Neut', 'N', 'Plur', 'P', 'Nom', '1'], ['Neut', 'N', 'Plur', 'P', 'Acc', '4'], ['Neut', 'N', 'Plur', 'P', 'Voc', '5']]],
                'izaiášově'   => ['Izaiášův', 'Izaiášóv', [['Anim', 'M', 'Sing', 'S', 'Loc', '6'], ['Fem', 'F', 'Sing', 'S', 'Dat', '3'], ['Fem', 'F', 'Sing', 'S', 'Loc', '6'], ['Neut', 'N', 'Sing', 'S', 'Loc', '6']]],
                'izaiášovi'   => ['Izaiášův', 'Izaiášóv', [['Anim', 'M', 'Plur', 'P', 'Nom', '1'], ['Anim', 'M', 'Plur', 'P', 'Voc', '5']]],
                'izaiášovo'   => ['Izaiášův', 'Izaiášóv', [['Neut', 'N', 'Sing', 'S', 'Nom', '1'], ['Neut', 'N', 'Sing', 'S', 'Acc', '4'], ['Neut', 'N', 'Sing', 'S', 'Voc', '5']]],
                'izaiášovou'  => ['Izaiášův', 'Izaiášóv', [['Fem', 'F', 'Sing', 'S', 'Ins', '7']]],
                'izaiášovu'   => ['Izaiášův', 'Izaiášóv', [['Anim', 'M', 'Sing', 'S', 'Dat', '3'], ['Fem', 'F', 'Sing', 'S', 'Acc', '4'], ['Neut', 'N', 'Sing', 'S', 'Dat', '3']]],
                'izaiášovú'   => ['Izaiášův', 'Izaiášóv', [['Fem', 'F', 'Sing', 'S', 'Ins', '7']]],
                'izaiášovy'   => ['Izaiášův', 'Izaiášóv', [['Anim', 'M', 'Plur', 'P', 'Acc', '4'], ['Fem', 'F', 'Sing', 'S', 'Gen', '2'], ['Fem', 'F', 'Plur', 'P', 'Nom', '1'], ['Fem', 'F', 'Plur', 'P', 'Acc', '4'], ['Fem', 'F', 'Plur', 'P', 'Voc', '5']]],
                'izaiášových' => ['Izaiášův', 'Izaiášóv', [['Anim', 'M', 'Plur', 'P', 'Gen', '2'], ['Anim', 'M', 'Plur', 'P', 'Loc', '6'], ['Fem', 'F', 'Plur', 'P', 'Gen', '2'], ['Fem', 'F', 'Plur', 'P', 'Loc', '6'], ['Neut', 'N', 'Plur', 'P', 'Gen', '2'], ['Neut', 'N', 'Plur', 'P', 'Loc', '6']]],
                'izaiášovým'  => ['Izaiášův', 'Izaiášóv', [['Anim', 'M', 'Sing', 'S', 'Ins', '7'], ['Anim', 'M', 'Plur', 'P', 'Dat', '3'], ['Fem', 'F', 'Plur', 'P', 'Dat', '3'], ['Neut', 'N', 'Sing', 'S', 'Ins', '7'], ['Neut', 'N', 'Plur', 'P', 'Dat', '3']]],
                'izaiášovými' => ['Izaiášův', 'Izaiášóv', [['Anim', 'M', 'Plur', 'P', 'Ins', '7'], ['Fem', 'F', 'Plur', 'P', 'Ins', '7'], ['Neut', 'N', 'Plur', 'P', 'Ins', '7']]],
                'izaiášuov'   => ['Izaiášův', 'Izaiášóv', [['Anim', 'M', 'Sing', 'S', 'Nom', '1'], ['Anim', 'M', 'Sing', 'S', 'Voc', '5']]],
                'izaiášův'    => ['Izaiášův', 'Izaiášóv', [['Anim', 'M', 'Sing', 'S', 'Nom', '1'], ['Anim', 'M', 'Sing', 'S', 'Voc', '5']]],
                'izákóv'        => ['Izákův',     'Izákóv',     [['Anim', 'M', 'Sing', 'S', 'Nom', '1']]],
                'jakubóv'    => ['Jakubův', 'Jakubóv', [['Anim', 'M', 'Sing', 'S', 'Nom', '1'], ['Anim', 'M', 'Sing', 'S', 'Voc', '5']]],
                'jakubova'   => ['Jakubův', 'Jakubóv', [['Anim', 'M', 'Sing', 'S', 'Gen', '2'], ['Anim', 'M', 'Sing', 'S', 'Acc', '4'], ['Fem', 'F', 'Sing', 'S', 'Nom', '1'], ['Fem', 'F', 'Sing', 'S', 'Voc', '5'], ['Neut', 'N', 'Sing', 'S', 'Gen', '2'], ['Neut', 'N', 'Plur', 'P', 'Nom', '1'], ['Neut', 'N', 'Plur', 'P', 'Acc', '4'], ['Neut', 'N', 'Plur', 'P', 'Voc', '5']]],
                'jakubově'   => ['Jakubův', 'Jakubóv', [['Anim', 'M', 'Sing', 'S', 'Loc', '6'], ['Fem', 'F', 'Sing', 'S', 'Dat', '3'], ['Fem', 'F', 'Sing', 'S', 'Loc', '6'], ['Neut', 'N', 'Sing', 'S', 'Loc', '6']]],
                'jakubovi'   => ['Jakubův', 'Jakubóv', [['Anim', 'M', 'Plur', 'P', 'Nom', '1'], ['Anim', 'M', 'Plur', 'P', 'Voc', '5']]],
                'jakubovo'   => ['Jakubův', 'Jakubóv', [['Neut', 'N', 'Sing', 'S', 'Nom', '1'], ['Neut', 'N', 'Sing', 'S', 'Acc', '4'], ['Neut', 'N', 'Sing', 'S', 'Voc', '5']]],
                'jakubovou'  => ['Jakubův', 'Jakubóv', [['Fem', 'F', 'Sing', 'S', 'Ins', '7']]],
                'jakubovu'   => ['Jakubův', 'Jakubóv', [['Anim', 'M', 'Sing', 'S', 'Dat', '3'], ['Fem', 'F', 'Sing', 'S', 'Acc', '4'], ['Neut', 'N', 'Sing', 'S', 'Dat', '3']]],
                'jakubovú'   => ['Jakubův', 'Jakubóv', [['Fem', 'F', 'Sing', 'S', 'Ins', '7']]],
                'jakubovy'   => ['Jakubův', 'Jakubóv', [['Anim', 'M', 'Plur', 'P', 'Acc', '4'], ['Fem', 'F', 'Sing', 'S', 'Gen', '2'], ['Fem', 'F', 'Plur', 'P', 'Nom', '1'], ['Fem', 'F', 'Plur', 'P', 'Acc', '4'], ['Fem', 'F', 'Plur', 'P', 'Voc', '5']]],
                'jakubových' => ['Jakubův', 'Jakubóv', [['Anim', 'M', 'Plur', 'P', 'Gen', '2'], ['Anim', 'M', 'Plur', 'P', 'Loc', '6'], ['Fem', 'F', 'Plur', 'P', 'Gen', '2'], ['Fem', 'F', 'Plur', 'P', 'Loc', '6'], ['Neut', 'N', 'Plur', 'P', 'Gen', '2'], ['Neut', 'N', 'Plur', 'P', 'Loc', '6']]],
                'jakubovým'  => ['Jakubův', 'Jakubóv', [['Anim', 'M', 'Sing', 'S', 'Ins', '7'], ['Anim', 'M', 'Plur', 'P', 'Dat', '3'], ['Fem', 'F', 'Plur', 'P', 'Dat', '3'], ['Neut', 'N', 'Sing', 'S', 'Ins', '7'], ['Neut', 'N', 'Plur', 'P', 'Dat', '3']]],
                'jakubovými' => ['Jakubův', 'Jakubóv', [['Anim', 'M', 'Plur', 'P', 'Ins', '7'], ['Fem', 'F', 'Plur', 'P', 'Ins', '7'], ['Neut', 'N', 'Plur', 'P', 'Ins', '7']]],
                'jakubuov'   => ['Jakubův', 'Jakubóv', [['Anim', 'M', 'Sing', 'S', 'Nom', '1'], ['Anim', 'M', 'Sing', 'S', 'Voc', '5']]],
                'jakubův'    => ['Jakubův', 'Jakubóv', [['Anim', 'M', 'Sing', 'S', 'Nom', '1'], ['Anim', 'M', 'Sing', 'S', 'Voc', '5']]],
                'janóv'    => ['Janův', 'Janóv', [['Anim', 'M', 'Sing', 'S', 'Nom', '1'], ['Anim', 'M', 'Sing', 'S', 'Voc', '5']]],
                'janova'   => ['Janův', 'Janóv', [['Anim', 'M', 'Sing', 'S', 'Gen', '2'], ['Anim', 'M', 'Sing', 'S', 'Acc', '4'], ['Fem', 'F', 'Sing', 'S', 'Nom', '1'], ['Fem', 'F', 'Sing', 'S', 'Voc', '5'], ['Neut', 'N', 'Sing', 'S', 'Gen', '2'], ['Neut', 'N', 'Plur', 'P', 'Nom', '1'], ['Neut', 'N', 'Plur', 'P', 'Acc', '4'], ['Neut', 'N', 'Plur', 'P', 'Voc', '5']]],
                'janově'   => ['Janův', 'Janóv', [['Anim', 'M', 'Sing', 'S', 'Loc', '6'], ['Fem', 'F', 'Sing', 'S', 'Dat', '3'], ['Fem', 'F', 'Sing', 'S', 'Loc', '6'], ['Neut', 'N', 'Sing', 'S', 'Loc', '6']]],
                'janovi'   => ['Janův', 'Janóv', [['Anim', 'M', 'Plur', 'P', 'Nom', '1'], ['Anim', 'M', 'Plur', 'P', 'Voc', '5']]],
                'janovo'   => ['Janův', 'Janóv', [['Neut', 'N', 'Sing', 'S', 'Nom', '1'], ['Neut', 'N', 'Sing', 'S', 'Acc', '4'], ['Neut', 'N', 'Sing', 'S', 'Voc', '5']]],
                'janovou'  => ['Janův', 'Janóv', [['Fem', 'F', 'Sing', 'S', 'Ins', '7']]],
                'janovu'   => ['Janův', 'Janóv', [['Anim', 'M', 'Sing', 'S', 'Dat', '3'], ['Fem', 'F', 'Sing', 'S', 'Acc', '4'], ['Neut', 'N', 'Sing', 'S', 'Dat', '3']]],
                'janovú'   => ['Janův', 'Janóv', [['Fem', 'F', 'Sing', 'S', 'Ins', '7']]],
                'janovy'   => ['Janův', 'Janóv', [['Anim', 'M', 'Plur', 'P', 'Acc', '4'], ['Fem', 'F', 'Sing', 'S', 'Gen', '2'], ['Fem', 'F', 'Plur', 'P', 'Nom', '1'], ['Fem', 'F', 'Plur', 'P', 'Acc', '4'], ['Fem', 'F', 'Plur', 'P', 'Voc', '5']]],
                'janových' => ['Janův', 'Janóv', [['Anim', 'M', 'Plur', 'P', 'Gen', '2'], ['Anim', 'M', 'Plur', 'P', 'Loc', '6'], ['Fem', 'F', 'Plur', 'P', 'Gen', '2'], ['Fem', 'F', 'Plur', 'P', 'Loc', '6'], ['Neut', 'N', 'Plur', 'P', 'Gen', '2'], ['Neut', 'N', 'Plur', 'P', 'Loc', '6']]],
                'janovým'  => ['Janův', 'Janóv', [['Anim', 'M', 'Sing', 'S', 'Ins', '7'], ['Anim', 'M', 'Plur', 'P', 'Dat', '3'], ['Fem', 'F', 'Plur', 'P', 'Dat', '3'], ['Neut', 'N', 'Sing', 'S', 'Ins', '7'], ['Neut', 'N', 'Plur', 'P', 'Dat', '3']]],
                'janovými' => ['Janův', 'Janóv', [['Anim', 'M', 'Plur', 'P', 'Ins', '7'], ['Fem', 'F', 'Plur', 'P', 'Ins', '7'], ['Neut', 'N', 'Plur', 'P', 'Ins', '7']]],
                'januov'   => ['Janův', 'Janóv', [['Anim', 'M', 'Sing', 'S', 'Nom', '1'], ['Anim', 'M', 'Sing', 'S', 'Voc', '5']]],
                'janův'    => ['Janův', 'Janóv', [['Anim', 'M', 'Sing', 'S', 'Nom', '1'], ['Anim', 'M', 'Sing', 'S', 'Voc', '5']]],
                'ježíšóv'    => ['Ježíšův', 'Ježíšóv', [['Anim', 'M', 'Sing', 'S', 'Nom', '1'], ['Anim', 'M', 'Sing', 'S', 'Voc', '5']]],
                'ježíšova'   => ['Ježíšův', 'Ježíšóv', [['Anim', 'M', 'Sing', 'S', 'Gen', '2'], ['Anim', 'M', 'Sing', 'S', 'Acc', '4'], ['Fem', 'F', 'Sing', 'S', 'Nom', '1'], ['Fem', 'F', 'Sing', 'S', 'Voc', '5'], ['Neut', 'N', 'Sing', 'S', 'Gen', '2'], ['Neut', 'N', 'Plur', 'P', 'Nom', '1'], ['Neut', 'N', 'Plur', 'P', 'Acc', '4'], ['Neut', 'N', 'Plur', 'P', 'Voc', '5']]],
                'ježíšově'   => ['Ježíšův', 'Ježíšóv', [['Anim', 'M', 'Sing', 'S', 'Loc', '6'], ['Fem', 'F', 'Sing', 'S', 'Dat', '3'], ['Fem', 'F', 'Sing', 'S', 'Loc', '6'], ['Neut', 'N', 'Sing', 'S', 'Loc', '6']]],
                'ježíšovi'   => ['Ježíšův', 'Ježíšóv', [['Anim', 'M', 'Plur', 'P', 'Nom', '1'], ['Anim', 'M', 'Plur', 'P', 'Voc', '5']]],
                'ježíšovo'   => ['Ježíšův', 'Ježíšóv', [['Neut', 'N', 'Sing', 'S', 'Nom', '1'], ['Neut', 'N', 'Sing', 'S', 'Acc', '4'], ['Neut', 'N', 'Sing', 'S', 'Voc', '5']]],
                'ježíšovou'  => ['Ježíšův', 'Ježíšóv', [['Fem', 'F', 'Sing', 'S', 'Ins', '7']]],
                'ježíšovu'   => ['Ježíšův', 'Ježíšóv', [['Anim', 'M', 'Sing', 'S', 'Dat', '3'], ['Fem', 'F', 'Sing', 'S', 'Acc', '4'], ['Neut', 'N', 'Sing', 'S', 'Dat', '3']]],
                'ježíšovú'   => ['Ježíšův', 'Ježíšóv', [['Fem', 'F', 'Sing', 'S', 'Ins', '7']]],
                'ježíšovy'   => ['Ježíšův', 'Ježíšóv', [['Anim', 'M', 'Plur', 'P', 'Acc', '4'], ['Fem', 'F', 'Sing', 'S', 'Gen', '2'], ['Fem', 'F', 'Plur', 'P', 'Nom', '1'], ['Fem', 'F', 'Plur', 'P', 'Acc', '4'], ['Fem', 'F', 'Plur', 'P', 'Voc', '5']]],
                'ježíšových' => ['Ježíšův', 'Ježíšóv', [['Anim', 'M', 'Plur', 'P', 'Gen', '2'], ['Anim', 'M', 'Plur', 'P', 'Loc', '6'], ['Fem', 'F', 'Plur', 'P', 'Gen', '2'], ['Fem', 'F', 'Plur', 'P', 'Loc', '6'], ['Neut', 'N', 'Plur', 'P', 'Gen', '2'], ['Neut', 'N', 'Plur', 'P', 'Loc', '6']]],
                'ježíšovým'  => ['Ježíšův', 'Ježíšóv', [['Anim', 'M', 'Sing', 'S', 'Ins', '7'], ['Anim', 'M', 'Plur', 'P', 'Dat', '3'], ['Fem', 'F', 'Plur', 'P', 'Dat', '3'], ['Neut', 'N', 'Sing', 'S', 'Ins', '7'], ['Neut', 'N', 'Plur', 'P', 'Dat', '3']]],
                'ježíšovými' => ['Ježíšův', 'Ježíšóv', [['Anim', 'M', 'Plur', 'P', 'Ins', '7'], ['Fem', 'F', 'Plur', 'P', 'Ins', '7'], ['Neut', 'N', 'Plur', 'P', 'Ins', '7']]],
                'ježíšuov'   => ['Ježíšův', 'Ježíšóv', [['Anim', 'M', 'Sing', 'S', 'Nom', '1'], ['Anim', 'M', 'Sing', 'S', 'Voc', '5']]],
                'ježíšův'    => ['Ježíšův', 'Ježíšóv', [['Anim', 'M', 'Sing', 'S', 'Nom', '1'], ['Anim', 'M', 'Sing', 'S', 'Voc', '5']]],
                'josefóv'    => ['Josefův', 'Jozefóv', [['Anim', 'M', 'Sing', 'S', 'Nom', '1'], ['Anim', 'M', 'Sing', 'S', 'Voc', '5']]],
                'josefova'   => ['Josefův', 'Jozefóv', [['Anim', 'M', 'Sing', 'S', 'Gen', '2'], ['Anim', 'M', 'Sing', 'S', 'Acc', '4'], ['Fem', 'F', 'Sing', 'S', 'Nom', '1'], ['Fem', 'F', 'Sing', 'S', 'Voc', '5'], ['Neut', 'N', 'Sing', 'S', 'Gen', '2'], ['Neut', 'N', 'Plur', 'P', 'Nom', '1'], ['Neut', 'N', 'Plur', 'P', 'Acc', '4'], ['Neut', 'N', 'Plur', 'P', 'Voc', '5']]],
                'josefově'   => ['Josefův', 'Jozefóv', [['Anim', 'M', 'Sing', 'S', 'Loc', '6'], ['Fem', 'F', 'Sing', 'S', 'Dat', '3'], ['Fem', 'F', 'Sing', 'S', 'Loc', '6'], ['Neut', 'N', 'Sing', 'S', 'Loc', '6']]],
                'josefovi'   => ['Josefův', 'Jozefóv', [['Anim', 'M', 'Plur', 'P', 'Nom', '1'], ['Anim', 'M', 'Plur', 'P', 'Voc', '5']]],
                'josefovo'   => ['Josefův', 'Jozefóv', [['Neut', 'N', 'Sing', 'S', 'Nom', '1'], ['Neut', 'N', 'Sing', 'S', 'Acc', '4'], ['Neut', 'N', 'Sing', 'S', 'Voc', '5']]],
                'josefovou'  => ['Josefův', 'Jozefóv', [['Fem', 'F', 'Sing', 'S', 'Ins', '7']]],
                'josefovu'   => ['Josefův', 'Jozefóv', [['Anim', 'M', 'Sing', 'S', 'Dat', '3'], ['Fem', 'F', 'Sing', 'S', 'Acc', '4'], ['Neut', 'N', 'Sing', 'S', 'Dat', '3']]],
                'josefovú'   => ['Josefův', 'Jozefóv', [['Fem', 'F', 'Sing', 'S', 'Ins', '7']]],
                'josefovy'   => ['Josefův', 'Jozefóv', [['Anim', 'M', 'Plur', 'P', 'Acc', '4'], ['Fem', 'F', 'Sing', 'S', 'Gen', '2'], ['Fem', 'F', 'Plur', 'P', 'Nom', '1'], ['Fem', 'F', 'Plur', 'P', 'Acc', '4'], ['Fem', 'F', 'Plur', 'P', 'Voc', '5']]],
                'josefových' => ['Josefův', 'Jozefóv', [['Anim', 'M', 'Plur', 'P', 'Gen', '2'], ['Anim', 'M', 'Plur', 'P', 'Loc', '6'], ['Fem', 'F', 'Plur', 'P', 'Gen', '2'], ['Fem', 'F', 'Plur', 'P', 'Loc', '6'], ['Neut', 'N', 'Plur', 'P', 'Gen', '2'], ['Neut', 'N', 'Plur', 'P', 'Loc', '6']]],
                'josefovým'  => ['Josefův', 'Jozefóv', [['Anim', 'M', 'Sing', 'S', 'Ins', '7'], ['Anim', 'M', 'Plur', 'P', 'Dat', '3'], ['Fem', 'F', 'Plur', 'P', 'Dat', '3'], ['Neut', 'N', 'Sing', 'S', 'Ins', '7'], ['Neut', 'N', 'Plur', 'P', 'Dat', '3']]],
                'josefovými' => ['Josefův', 'Jozefóv', [['Anim', 'M', 'Plur', 'P', 'Ins', '7'], ['Fem', 'F', 'Plur', 'P', 'Ins', '7'], ['Neut', 'N', 'Plur', 'P', 'Ins', '7']]],
                'josefuov'   => ['Josefův', 'Jozefóv', [['Anim', 'M', 'Sing', 'S', 'Nom', '1'], ['Anim', 'M', 'Sing', 'S', 'Voc', '5']]],
                'josefův'    => ['Josefův', 'Jozefóv', [['Anim', 'M', 'Sing', 'S', 'Nom', '1'], ['Anim', 'M', 'Sing', 'S', 'Voc', '5']]],
                'jozefóv'    => ['Josefův', 'Jozefóv', [['Anim', 'M', 'Sing', 'S', 'Nom', '1'], ['Anim', 'M', 'Sing', 'S', 'Voc', '5']]],
                'jozefova'   => ['Josefův', 'Jozefóv', [['Anim', 'M', 'Sing', 'S', 'Gen', '2'], ['Anim', 'M', 'Sing', 'S', 'Acc', '4'], ['Fem', 'F', 'Sing', 'S', 'Nom', '1'], ['Fem', 'F', 'Sing', 'S', 'Voc', '5'], ['Neut', 'N', 'Sing', 'S', 'Gen', '2'], ['Neut', 'N', 'Plur', 'P', 'Nom', '1'], ['Neut', 'N', 'Plur', 'P', 'Acc', '4'], ['Neut', 'N', 'Plur', 'P', 'Voc', '5']]],
                'jozefově'   => ['Josefův', 'Jozefóv', [['Anim', 'M', 'Sing', 'S', 'Loc', '6'], ['Fem', 'F', 'Sing', 'S', 'Dat', '3'], ['Fem', 'F', 'Sing', 'S', 'Loc', '6'], ['Neut', 'N', 'Sing', 'S', 'Loc', '6']]],
                'jozefovi'   => ['Josefův', 'Jozefóv', [['Anim', 'M', 'Plur', 'P', 'Nom', '1'], ['Anim', 'M', 'Plur', 'P', 'Voc', '5']]],
                'jozefovo'   => ['Josefův', 'Jozefóv', [['Neut', 'N', 'Sing', 'S', 'Nom', '1'], ['Neut', 'N', 'Sing', 'S', 'Acc', '4'], ['Neut', 'N', 'Sing', 'S', 'Voc', '5']]],
                'jozefovou'  => ['Josefův', 'Jozefóv', [['Fem', 'F', 'Sing', 'S', 'Ins', '7']]],
                'jozefovu'   => ['Josefův', 'Jozefóv', [['Anim', 'M', 'Sing', 'S', 'Dat', '3'], ['Fem', 'F', 'Sing', 'S', 'Acc', '4'], ['Neut', 'N', 'Sing', 'S', 'Dat', '3']]],
                'jozefovú'   => ['Josefův', 'Jozefóv', [['Fem', 'F', 'Sing', 'S', 'Ins', '7']]],
                'jozefovy'   => ['Josefův', 'Jozefóv', [['Anim', 'M', 'Plur', 'P', 'Acc', '4'], ['Fem', 'F', 'Sing', 'S', 'Gen', '2'], ['Fem', 'F', 'Plur', 'P', 'Nom', '1'], ['Fem', 'F', 'Plur', 'P', 'Acc', '4'], ['Fem', 'F', 'Plur', 'P', 'Voc', '5']]],
                'jozefových' => ['Josefův', 'Jozefóv', [['Anim', 'M', 'Plur', 'P', 'Gen', '2'], ['Anim', 'M', 'Plur', 'P', 'Loc', '6'], ['Fem', 'F', 'Plur', 'P', 'Gen', '2'], ['Fem', 'F', 'Plur', 'P', 'Loc', '6'], ['Neut', 'N', 'Plur', 'P', 'Gen', '2'], ['Neut', 'N', 'Plur', 'P', 'Loc', '6']]],
                'jozefovým'  => ['Josefův', 'Jozefóv', [['Anim', 'M', 'Sing', 'S', 'Ins', '7'], ['Anim', 'M', 'Plur', 'P', 'Dat', '3'], ['Fem', 'F', 'Plur', 'P', 'Dat', '3'], ['Neut', 'N', 'Sing', 'S', 'Ins', '7'], ['Neut', 'N', 'Plur', 'P', 'Dat', '3']]],
                'jozefovými' => ['Josefův', 'Jozefóv', [['Anim', 'M', 'Plur', 'P', 'Ins', '7'], ['Fem', 'F', 'Plur', 'P', 'Ins', '7'], ['Neut', 'N', 'Plur', 'P', 'Ins', '7']]],
                'jozefuov'   => ['Josefův', 'Jozefóv', [['Anim', 'M', 'Sing', 'S', 'Nom', '1'], ['Anim', 'M', 'Sing', 'S', 'Voc', '5']]],
                'jozefův'    => ['Josefův', 'Jozefóv', [['Anim', 'M', 'Sing', 'S', 'Nom', '1'], ['Anim', 'M', 'Sing', 'S', 'Voc', '5']]],
                'ozěpóv'     => ['Josefův', 'Jozefóv', [['Anim', 'M', 'Sing', 'S', 'Nom', '1'], ['Anim', 'M', 'Sing', 'S', 'Voc', '5']]],
                'ozěpova'    => ['Josefův', 'Jozefóv', [['Anim', 'M', 'Sing', 'S', 'Gen', '2'], ['Anim', 'M', 'Sing', 'S', 'Acc', '4'], ['Fem', 'F', 'Sing', 'S', 'Nom', '1'], ['Fem', 'F', 'Sing', 'S', 'Voc', '5'], ['Neut', 'N', 'Sing', 'S', 'Gen', '2'], ['Neut', 'N', 'Plur', 'P', 'Nom', '1'], ['Neut', 'N', 'Plur', 'P', 'Acc', '4'], ['Neut', 'N', 'Plur', 'P', 'Voc', '5']]],
                'ozěpově'    => ['Josefův', 'Jozefóv', [['Anim', 'M', 'Sing', 'S', 'Loc', '6'], ['Fem', 'F', 'Sing', 'S', 'Dat', '3'], ['Fem', 'F', 'Sing', 'S', 'Loc', '6'], ['Neut', 'N', 'Sing', 'S', 'Loc', '6']]],
                'ozěpovi'    => ['Josefův', 'Jozefóv', [['Anim', 'M', 'Plur', 'P', 'Nom', '1'], ['Anim', 'M', 'Plur', 'P', 'Voc', '5']]],
                'ozěpovo'    => ['Josefův', 'Jozefóv', [['Neut', 'N', 'Sing', 'S', 'Nom', '1'], ['Neut', 'N', 'Sing', 'S', 'Acc', '4'], ['Neut', 'N', 'Sing', 'S', 'Voc', '5']]],
                'ozěpovou'   => ['Josefův', 'Jozefóv', [['Fem', 'F', 'Sing', 'S', 'Ins', '7']]],
                'ozěpovu'    => ['Josefův', 'Jozefóv', [['Anim', 'M', 'Sing', 'S', 'Dat', '3'], ['Fem', 'F', 'Sing', 'S', 'Acc', '4'], ['Neut', 'N', 'Sing', 'S', 'Dat', '3']]],
                'ozěpovú'    => ['Josefův', 'Jozefóv', [['Fem', 'F', 'Sing', 'S', 'Ins', '7']]],
                'ozěpovy'    => ['Josefův', 'Jozefóv', [['Anim', 'M', 'Plur', 'P', 'Acc', '4'], ['Fem', 'F', 'Sing', 'S', 'Gen', '2'], ['Fem', 'F', 'Plur', 'P', 'Nom', '1'], ['Fem', 'F', 'Plur', 'P', 'Acc', '4'], ['Fem', 'F', 'Plur', 'P', 'Voc', '5']]],
                'ozěpových'  => ['Josefův', 'Jozefóv', [['Anim', 'M', 'Plur', 'P', 'Gen', '2'], ['Anim', 'M', 'Plur', 'P', 'Loc', '6'], ['Fem', 'F', 'Plur', 'P', 'Gen', '2'], ['Fem', 'F', 'Plur', 'P', 'Loc', '6'], ['Neut', 'N', 'Plur', 'P', 'Gen', '2'], ['Neut', 'N', 'Plur', 'P', 'Loc', '6']]],
                'ozěpovým'   => ['Josefův', 'Jozefóv', [['Anim', 'M', 'Sing', 'S', 'Ins', '7'], ['Anim', 'M', 'Plur', 'P', 'Dat', '3'], ['Fem', 'F', 'Plur', 'P', 'Dat', '3'], ['Neut', 'N', 'Sing', 'S', 'Ins', '7'], ['Neut', 'N', 'Plur', 'P', 'Dat', '3']]],
                'ozěpovými'  => ['Josefův', 'Jozefóv', [['Anim', 'M', 'Plur', 'P', 'Ins', '7'], ['Fem', 'F', 'Plur', 'P', 'Ins', '7'], ['Neut', 'N', 'Plur', 'P', 'Ins', '7']]],
                'ozěpuov'    => ['Josefův', 'Jozefóv', [['Anim', 'M', 'Sing', 'S', 'Nom', '1'], ['Anim', 'M', 'Sing', 'S', 'Voc', '5']]],
                'ozěpův'     => ['Josefův', 'Jozefóv', [['Anim', 'M', 'Sing', 'S', 'Nom', '1'], ['Anim', 'M', 'Sing', 'S', 'Voc', '5']]],
                'mojžiešóv'    => ['Mojžíšův', 'Mojžiešóv', [['Anim', 'M', 'Sing', 'S', 'Nom', '1'], ['Anim', 'M', 'Sing', 'S', 'Voc', '5']]],
                'mojžiešova'   => ['Mojžíšův', 'Mojžiešóv', [['Anim', 'M', 'Sing', 'S', 'Gen', '2'], ['Anim', 'M', 'Sing', 'S', 'Acc', '4'], ['Fem', 'F', 'Sing', 'S', 'Nom', '1'], ['Fem', 'F', 'Sing', 'S', 'Voc', '5'], ['Neut', 'N', 'Sing', 'S', 'Gen', '2'], ['Neut', 'N', 'Plur', 'P', 'Nom', '1'], ['Neut', 'N', 'Plur', 'P', 'Acc', '4'], ['Neut', 'N', 'Plur', 'P', 'Voc', '5']]],
                'mojžiešově'   => ['Mojžíšův', 'Mojžiešóv', [['Anim', 'M', 'Sing', 'S', 'Loc', '6'], ['Fem', 'F', 'Sing', 'S', 'Dat', '3'], ['Fem', 'F', 'Sing', 'S', 'Loc', '6'], ['Neut', 'N', 'Sing', 'S', 'Loc', '6']]],
                'mojžiešovi'   => ['Mojžíšův', 'Mojžiešóv', [['Anim', 'M', 'Plur', 'P', 'Nom', '1'], ['Anim', 'M', 'Plur', 'P', 'Voc', '5']]],
                'mojžiešovo'   => ['Mojžíšův', 'Mojžiešóv', [['Neut', 'N', 'Sing', 'S', 'Nom', '1'], ['Neut', 'N', 'Sing', 'S', 'Acc', '4'], ['Neut', 'N', 'Sing', 'S', 'Voc', '5']]],
                'mojžiešovou'  => ['Mojžíšův', 'Mojžiešóv', [['Fem', 'F', 'Sing', 'S', 'Ins', '7']]],
                'mojžiešovu'   => ['Mojžíšův', 'Mojžiešóv', [['Anim', 'M', 'Sing', 'S', 'Dat', '3'], ['Fem', 'F', 'Sing', 'S', 'Acc', '4'], ['Neut', 'N', 'Sing', 'S', 'Dat', '3']]],
                'mojžiešovú'   => ['Mojžíšův', 'Mojžiešóv', [['Fem', 'F', 'Sing', 'S', 'Ins', '7']]],
                'mojžiešovy'   => ['Mojžíšův', 'Mojžiešóv', [['Anim', 'M', 'Plur', 'P', 'Acc', '4'], ['Fem', 'F', 'Sing', 'S', 'Gen', '2'], ['Fem', 'F', 'Plur', 'P', 'Nom', '1'], ['Fem', 'F', 'Plur', 'P', 'Acc', '4'], ['Fem', 'F', 'Plur', 'P', 'Voc', '5']]],
                'mojžiešových' => ['Mojžíšův', 'Mojžiešóv', [['Anim', 'M', 'Plur', 'P', 'Gen', '2'], ['Anim', 'M', 'Plur', 'P', 'Loc', '6'], ['Fem', 'F', 'Plur', 'P', 'Gen', '2'], ['Fem', 'F', 'Plur', 'P', 'Loc', '6'], ['Neut', 'N', 'Plur', 'P', 'Gen', '2'], ['Neut', 'N', 'Plur', 'P', 'Loc', '6']]],
                'mojžiešovým'  => ['Mojžíšův', 'Mojžiešóv', [['Anim', 'M', 'Sing', 'S', 'Ins', '7'], ['Anim', 'M', 'Plur', 'P', 'Dat', '3'], ['Fem', 'F', 'Plur', 'P', 'Dat', '3'], ['Neut', 'N', 'Sing', 'S', 'Ins', '7'], ['Neut', 'N', 'Plur', 'P', 'Dat', '3']]],
                'mojžiešovými' => ['Mojžíšův', 'Mojžiešóv', [['Anim', 'M', 'Plur', 'P', 'Ins', '7'], ['Fem', 'F', 'Plur', 'P', 'Ins', '7'], ['Neut', 'N', 'Plur', 'P', 'Ins', '7']]],
                'mojžiešuov'   => ['Mojžíšův', 'Mojžiešóv', [['Anim', 'M', 'Sing', 'S', 'Nom', '1'], ['Anim', 'M', 'Sing', 'S', 'Voc', '5']]],
                'mojžiešův'    => ['Mojžíšův', 'Mojžiešóv', [['Anim', 'M', 'Sing', 'S', 'Nom', '1'], ['Anim', 'M', 'Sing', 'S', 'Voc', '5']]],
                'mojžíšóv'     => ['Mojžíšův', 'Mojžiešóv', [['Anim', 'M', 'Sing', 'S', 'Nom', '1'], ['Anim', 'M', 'Sing', 'S', 'Voc', '5']]],
                'mojžíšova'    => ['Mojžíšův', 'Mojžiešóv', [['Anim', 'M', 'Sing', 'S', 'Gen', '2'], ['Anim', 'M', 'Sing', 'S', 'Acc', '4'], ['Fem', 'F', 'Sing', 'S', 'Nom', '1'], ['Fem', 'F', 'Sing', 'S', 'Voc', '5'], ['Neut', 'N', 'Sing', 'S', 'Gen', '2'], ['Neut', 'N', 'Plur', 'P', 'Nom', '1'], ['Neut', 'N', 'Plur', 'P', 'Acc', '4'], ['Neut', 'N', 'Plur', 'P', 'Voc', '5']]],
                'mojžíšově'    => ['Mojžíšův', 'Mojžiešóv', [['Anim', 'M', 'Sing', 'S', 'Loc', '6'], ['Fem', 'F', 'Sing', 'S', 'Dat', '3'], ['Fem', 'F', 'Sing', 'S', 'Loc', '6'], ['Neut', 'N', 'Sing', 'S', 'Loc', '6']]],
                'mojžíšovi'    => ['Mojžíšův', 'Mojžiešóv', [['Anim', 'M', 'Plur', 'P', 'Nom', '1'], ['Anim', 'M', 'Plur', 'P', 'Voc', '5']]],
                'mojžíšovo'    => ['Mojžíšův', 'Mojžiešóv', [['Neut', 'N', 'Sing', 'S', 'Nom', '1'], ['Neut', 'N', 'Sing', 'S', 'Acc', '4'], ['Neut', 'N', 'Sing', 'S', 'Voc', '5']]],
                'mojžíšovou'   => ['Mojžíšův', 'Mojžiešóv', [['Fem', 'F', 'Sing', 'S', 'Ins', '7']]],
                'mojžíšovu'    => ['Mojžíšův', 'Mojžiešóv', [['Anim', 'M', 'Sing', 'S', 'Dat', '3'], ['Fem', 'F', 'Sing', 'S', 'Acc', '4'], ['Neut', 'N', 'Sing', 'S', 'Dat', '3']]],
                'mojžíšovú'    => ['Mojžíšův', 'Mojžiešóv', [['Fem', 'F', 'Sing', 'S', 'Ins', '7']]],
                'mojžíšovy'    => ['Mojžíšův', 'Mojžiešóv', [['Anim', 'M', 'Plur', 'P', 'Acc', '4'], ['Fem', 'F', 'Sing', 'S', 'Gen', '2'], ['Fem', 'F', 'Plur', 'P', 'Nom', '1'], ['Fem', 'F', 'Plur', 'P', 'Acc', '4'], ['Fem', 'F', 'Plur', 'P', 'Voc', '5']]],
                'mojžíšových'  => ['Mojžíšův', 'Mojžiešóv', [['Anim', 'M', 'Plur', 'P', 'Gen', '2'], ['Anim', 'M', 'Plur', 'P', 'Loc', '6'], ['Fem', 'F', 'Plur', 'P', 'Gen', '2'], ['Fem', 'F', 'Plur', 'P', 'Loc', '6'], ['Neut', 'N', 'Plur', 'P', 'Gen', '2'], ['Neut', 'N', 'Plur', 'P', 'Loc', '6']]],
                'mojžíšovým'   => ['Mojžíšův', 'Mojžiešóv', [['Anim', 'M', 'Sing', 'S', 'Ins', '7'], ['Anim', 'M', 'Plur', 'P', 'Dat', '3'], ['Fem', 'F', 'Plur', 'P', 'Dat', '3'], ['Neut', 'N', 'Sing', 'S', 'Ins', '7'], ['Neut', 'N', 'Plur', 'P', 'Dat', '3']]],
                'mojžíšovými'  => ['Mojžíšův', 'Mojžiešóv', [['Anim', 'M', 'Plur', 'P', 'Ins', '7'], ['Fem', 'F', 'Plur', 'P', 'Ins', '7'], ['Neut', 'N', 'Plur', 'P', 'Ins', '7']]],
                'mojžíšuov'    => ['Mojžíšův', 'Mojžiešóv', [['Anim', 'M', 'Sing', 'S', 'Nom', '1'], ['Anim', 'M', 'Sing', 'S', 'Voc', '5']]],
                'mojžíšův'     => ['Mojžíšův', 'Mojžiešóv', [['Anim', 'M', 'Sing', 'S', 'Nom', '1'], ['Anim', 'M', 'Sing', 'S', 'Voc', '5']]],
                'petróv'    => ['Petrův', 'Petróv', [['Anim', 'M', 'Sing', 'S', 'Nom', '1'], ['Anim', 'M', 'Sing', 'S', 'Voc', '5']]],
                'petrova'   => ['Petrův', 'Petróv', [['Anim', 'M', 'Sing', 'S', 'Gen', '2'], ['Anim', 'M', 'Sing', 'S', 'Acc', '4'], ['Fem', 'F', 'Sing', 'S', 'Nom', '1'], ['Fem', 'F', 'Sing', 'S', 'Voc', '5'], ['Neut', 'N', 'Sing', 'S', 'Gen', '2'], ['Neut', 'N', 'Plur', 'P', 'Nom', '1'], ['Neut', 'N', 'Plur', 'P', 'Acc', '4'], ['Neut', 'N', 'Plur', 'P', 'Voc', '5']]],
                'petrově'   => ['Petrův', 'Petróv', [['Anim', 'M', 'Sing', 'S', 'Loc', '6'], ['Fem', 'F', 'Sing', 'S', 'Dat', '3'], ['Fem', 'F', 'Sing', 'S', 'Loc', '6'], ['Neut', 'N', 'Sing', 'S', 'Loc', '6']]],
                'petrovi'   => ['Petrův', 'Petróv', [['Anim', 'M', 'Plur', 'P', 'Nom', '1'], ['Anim', 'M', 'Plur', 'P', 'Voc', '5']]],
                'petrovo'   => ['Petrův', 'Petróv', [['Neut', 'N', 'Sing', 'S', 'Nom', '1'], ['Neut', 'N', 'Sing', 'S', 'Acc', '4'], ['Neut', 'N', 'Sing', 'S', 'Voc', '5']]],
                'petrovou'  => ['Petrův', 'Petróv', [['Fem', 'F', 'Sing', 'S', 'Ins', '7']]],
                'petrovu'   => ['Petrův', 'Petróv', [['Anim', 'M', 'Sing', 'S', 'Dat', '3'], ['Fem', 'F', 'Sing', 'S', 'Acc', '4'], ['Neut', 'N', 'Sing', 'S', 'Dat', '3']]],
                'petrovú'   => ['Petrův', 'Petróv', [['Fem', 'F', 'Sing', 'S', 'Ins', '7']]],
                'petrovy'   => ['Petrův', 'Petróv', [['Anim', 'M', 'Plur', 'P', 'Acc', '4'], ['Fem', 'F', 'Sing', 'S', 'Gen', '2'], ['Fem', 'F', 'Plur', 'P', 'Nom', '1'], ['Fem', 'F', 'Plur', 'P', 'Acc', '4'], ['Fem', 'F', 'Plur', 'P', 'Voc', '5']]],
                'petrových' => ['Petrův', 'Petróv', [['Anim', 'M', 'Plur', 'P', 'Gen', '2'], ['Anim', 'M', 'Plur', 'P', 'Loc', '6'], ['Fem', 'F', 'Plur', 'P', 'Gen', '2'], ['Fem', 'F', 'Plur', 'P', 'Loc', '6'], ['Neut', 'N', 'Plur', 'P', 'Gen', '2'], ['Neut', 'N', 'Plur', 'P', 'Loc', '6']]],
                'petrovým'  => ['Petrův', 'Petróv', [['Anim', 'M', 'Sing', 'S', 'Ins', '7'], ['Anim', 'M', 'Plur', 'P', 'Dat', '3'], ['Fem', 'F', 'Plur', 'P', 'Dat', '3'], ['Neut', 'N', 'Sing', 'S', 'Ins', '7'], ['Neut', 'N', 'Plur', 'P', 'Dat', '3']]],
                'petrovými' => ['Petrův', 'Petróv', [['Anim', 'M', 'Plur', 'P', 'Ins', '7'], ['Fem', 'F', 'Plur', 'P', 'Ins', '7'], ['Neut', 'N', 'Plur', 'P', 'Ins', '7']]],
                'petruov'   => ['Petrův', 'Petróv', [['Anim', 'M', 'Sing', 'S', 'Nom', '1'], ['Anim', 'M', 'Sing', 'S', 'Voc', '5']]],
                'petrův'    => ['Petrův', 'Petróv', [['Anim', 'M', 'Sing', 'S', 'Nom', '1'], ['Anim', 'M', 'Sing', 'S', 'Voc', '5']]],
                'šalamounóv'    => ['Šalamounův', 'Šalomúnóv', [['Anim', 'M', 'Sing', 'S', 'Nom', '1'], ['Anim', 'M', 'Sing', 'S', 'Voc', '5']]],
                'šalamounova'   => ['Šalamounův', 'Šalomúnóv', [['Anim', 'M', 'Sing', 'S', 'Gen', '2'], ['Anim', 'M', 'Sing', 'S', 'Acc', '4'], ['Fem', 'F', 'Sing', 'S', 'Nom', '1'], ['Fem', 'F', 'Sing', 'S', 'Voc', '5'], ['Neut', 'N', 'Sing', 'S', 'Gen', '2'], ['Neut', 'N', 'Plur', 'P', 'Nom', '1'], ['Neut', 'N', 'Plur', 'P', 'Acc', '4'], ['Neut', 'N', 'Plur', 'P', 'Voc', '5']]],
                'šalamounově'   => ['Šalamounův', 'Šalomúnóv', [['Anim', 'M', 'Sing', 'S', 'Loc', '6'], ['Fem', 'F', 'Sing', 'S', 'Dat', '3'], ['Fem', 'F', 'Sing', 'S', 'Loc', '6'], ['Neut', 'N', 'Sing', 'S', 'Loc', '6']]],
                'šalamounovi'   => ['Šalamounův', 'Šalomúnóv', [['Anim', 'M', 'Plur', 'P', 'Nom', '1'], ['Anim', 'M', 'Plur', 'P', 'Voc', '5']]],
                'šalamounovo'   => ['Šalamounův', 'Šalomúnóv', [['Neut', 'N', 'Sing', 'S', 'Nom', '1'], ['Neut', 'N', 'Sing', 'S', 'Acc', '4'], ['Neut', 'N', 'Sing', 'S', 'Voc', '5']]],
                'šalamounovou'  => ['Šalamounův', 'Šalomúnóv', [['Fem', 'F', 'Sing', 'S', 'Ins', '7']]],
                'šalamounovu'   => ['Šalamounův', 'Šalomúnóv', [['Anim', 'M', 'Sing', 'S', 'Dat', '3'], ['Fem', 'F', 'Sing', 'S', 'Acc', '4'], ['Neut', 'N', 'Sing', 'S', 'Dat', '3']]],
                'šalamounovú'   => ['Šalamounův', 'Šalomúnóv', [['Fem', 'F', 'Sing', 'S', 'Ins', '7']]],
                'šalamounovy'   => ['Šalamounův', 'Šalomúnóv', [['Anim', 'M', 'Plur', 'P', 'Acc', '4'], ['Fem', 'F', 'Sing', 'S', 'Gen', '2'], ['Fem', 'F', 'Plur', 'P', 'Nom', '1'], ['Fem', 'F', 'Plur', 'P', 'Acc', '4'], ['Fem', 'F', 'Plur', 'P', 'Voc', '5']]],
                'šalamounových' => ['Šalamounův', 'Šalomúnóv', [['Anim', 'M', 'Plur', 'P', 'Gen', '2'], ['Anim', 'M', 'Plur', 'P', 'Loc', '6'], ['Fem', 'F', 'Plur', 'P', 'Gen', '2'], ['Fem', 'F', 'Plur', 'P', 'Loc', '6'], ['Neut', 'N', 'Plur', 'P', 'Gen', '2'], ['Neut', 'N', 'Plur', 'P', 'Loc', '6']]],
                'šalamounovým'  => ['Šalamounův', 'Šalomúnóv', [['Anim', 'M', 'Sing', 'S', 'Ins', '7'], ['Anim', 'M', 'Plur', 'P', 'Dat', '3'], ['Fem', 'F', 'Plur', 'P', 'Dat', '3'], ['Neut', 'N', 'Sing', 'S', 'Ins', '7'], ['Neut', 'N', 'Plur', 'P', 'Dat', '3']]],
                'šalamounovými' => ['Šalamounův', 'Šalomúnóv', [['Anim', 'M', 'Plur', 'P', 'Ins', '7'], ['Fem', 'F', 'Plur', 'P', 'Ins', '7'], ['Neut', 'N', 'Plur', 'P', 'Ins', '7']]],
                'šalamounuov'   => ['Šalamounův', 'Šalomúnóv', [['Anim', 'M', 'Sing', 'S', 'Nom', '1'], ['Anim', 'M', 'Sing', 'S', 'Voc', '5']]],
                'šalamounův'    => ['Šalamounův', 'Šalomúnóv', [['Anim', 'M', 'Sing', 'S', 'Nom', '1'], ['Anim', 'M', 'Sing', 'S', 'Voc', '5']]],
                'šalomúnóv'     => ['Šalamounův', 'Šalomúnóv', [['Anim', 'M', 'Sing', 'S', 'Nom', '1'], ['Anim', 'M', 'Sing', 'S', 'Voc', '5']]],
                'šalomúnova'    => ['Šalamounův', 'Šalomúnóv', [['Anim', 'M', 'Sing', 'S', 'Gen', '2'], ['Anim', 'M', 'Sing', 'S', 'Acc', '4'], ['Fem', 'F', 'Sing', 'S', 'Nom', '1'], ['Fem', 'F', 'Sing', 'S', 'Voc', '5'], ['Neut', 'N', 'Sing', 'S', 'Gen', '2'], ['Neut', 'N', 'Plur', 'P', 'Nom', '1'], ['Neut', 'N', 'Plur', 'P', 'Acc', '4'], ['Neut', 'N', 'Plur', 'P', 'Voc', '5']]],
                'šalomúnově'    => ['Šalamounův', 'Šalomúnóv', [['Anim', 'M', 'Sing', 'S', 'Loc', '6'], ['Fem', 'F', 'Sing', 'S', 'Dat', '3'], ['Fem', 'F', 'Sing', 'S', 'Loc', '6'], ['Neut', 'N', 'Sing', 'S', 'Loc', '6']]],
                'šalomúnovi'    => ['Šalamounův', 'Šalomúnóv', [['Anim', 'M', 'Plur', 'P', 'Nom', '1'], ['Anim', 'M', 'Plur', 'P', 'Voc', '5']]],
                'šalomúnovo'    => ['Šalamounův', 'Šalomúnóv', [['Neut', 'N', 'Sing', 'S', 'Nom', '1'], ['Neut', 'N', 'Sing', 'S', 'Acc', '4'], ['Neut', 'N', 'Sing', 'S', 'Voc', '5']]],
                'šalomúnovou'   => ['Šalamounův', 'Šalomúnóv', [['Fem', 'F', 'Sing', 'S', 'Ins', '7']]],
                'šalomúnovu'    => ['Šalamounův', 'Šalomúnóv', [['Anim', 'M', 'Sing', 'S', 'Dat', '3'], ['Fem', 'F', 'Sing', 'S', 'Acc', '4'], ['Neut', 'N', 'Sing', 'S', 'Dat', '3']]],
                'šalomúnovú'    => ['Šalamounův', 'Šalomúnóv', [['Fem', 'F', 'Sing', 'S', 'Ins', '7']]],
                'šalomúnovy'    => ['Šalamounův', 'Šalomúnóv', [['Anim', 'M', 'Plur', 'P', 'Acc', '4'], ['Fem', 'F', 'Sing', 'S', 'Gen', '2'], ['Fem', 'F', 'Plur', 'P', 'Nom', '1'], ['Fem', 'F', 'Plur', 'P', 'Acc', '4'], ['Fem', 'F', 'Plur', 'P', 'Voc', '5']]],
                'šalomúnových'  => ['Šalamounův', 'Šalomúnóv', [['Anim', 'M', 'Plur', 'P', 'Gen', '2'], ['Anim', 'M', 'Plur', 'P', 'Loc', '6'], ['Fem', 'F', 'Plur', 'P', 'Gen', '2'], ['Fem', 'F', 'Plur', 'P', 'Loc', '6'], ['Neut', 'N', 'Plur', 'P', 'Gen', '2'], ['Neut', 'N', 'Plur', 'P', 'Loc', '6']]],
                'šalomúnovým'   => ['Šalamounův', 'Šalomúnóv', [['Anim', 'M', 'Sing', 'S', 'Ins', '7'], ['Anim', 'M', 'Plur', 'P', 'Dat', '3'], ['Fem', 'F', 'Plur', 'P', 'Dat', '3'], ['Neut', 'N', 'Sing', 'S', 'Ins', '7'], ['Neut', 'N', 'Plur', 'P', 'Dat', '3']]],
                'šalomúnovými'  => ['Šalamounův', 'Šalomúnóv', [['Anim', 'M', 'Plur', 'P', 'Ins', '7'], ['Fem', 'F', 'Plur', 'P', 'Ins', '7'], ['Neut', 'N', 'Plur', 'P', 'Ins', '7']]],
                'šalomúnuov'    => ['Šalamounův', 'Šalomúnóv', [['Anim', 'M', 'Sing', 'S', 'Nom', '1'], ['Anim', 'M', 'Sing', 'S', 'Voc', '5']]],
                'šalomúnův'     => ['Šalamounův', 'Šalomúnóv', [['Anim', 'M', 'Sing', 'S', 'Nom', '1'], ['Anim', 'M', 'Sing', 'S', 'Voc', '5']]],
                'zachařóv'    => ['Zachařův', 'Zachařóv', [['Anim', 'M', 'Sing', 'S', 'Nom', '1'], ['Anim', 'M', 'Sing', 'S', 'Voc', '5']]],
                'zachařova'   => ['Zachařův', 'Zachařóv', [['Anim', 'M', 'Sing', 'S', 'Gen', '2'], ['Anim', 'M', 'Sing', 'S', 'Acc', '4'], ['Fem', 'F', 'Sing', 'S', 'Nom', '1'], ['Fem', 'F', 'Sing', 'S', 'Voc', '5'], ['Neut', 'N', 'Sing', 'S', 'Gen', '2'], ['Neut', 'N', 'Plur', 'P', 'Nom', '1'], ['Neut', 'N', 'Plur', 'P', 'Acc', '4'], ['Neut', 'N', 'Plur', 'P', 'Voc', '5']]],
                'zachařově'   => ['Zachařův', 'Zachařóv', [['Anim', 'M', 'Sing', 'S', 'Loc', '6'], ['Fem', 'F', 'Sing', 'S', 'Dat', '3'], ['Fem', 'F', 'Sing', 'S', 'Loc', '6'], ['Neut', 'N', 'Sing', 'S', 'Loc', '6']]],
                'zachařovi'   => ['Zachařův', 'Zachařóv', [['Anim', 'M', 'Plur', 'P', 'Nom', '1'], ['Anim', 'M', 'Plur', 'P', 'Voc', '5']]],
                'zachařovo'   => ['Zachařův', 'Zachařóv', [['Neut', 'N', 'Sing', 'S', 'Nom', '1'], ['Neut', 'N', 'Sing', 'S', 'Acc', '4'], ['Neut', 'N', 'Sing', 'S', 'Voc', '5']]],
                'zachařovou'  => ['Zachařův', 'Zachařóv', [['Fem', 'F', 'Sing', 'S', 'Ins', '7']]],
                'zachařovu'   => ['Zachařův', 'Zachařóv', [['Anim', 'M', 'Sing', 'S', 'Dat', '3'], ['Fem', 'F', 'Sing', 'S', 'Acc', '4'], ['Neut', 'N', 'Sing', 'S', 'Dat', '3']]],
                'zachařovú'   => ['Zachařův', 'Zachařóv', [['Fem', 'F', 'Sing', 'S', 'Ins', '7']]],
                'zachařovy'   => ['Zachařův', 'Zachařóv', [['Anim', 'M', 'Plur', 'P', 'Acc', '4'], ['Fem', 'F', 'Sing', 'S', 'Gen', '2'], ['Fem', 'F', 'Plur', 'P', 'Nom', '1'], ['Fem', 'F', 'Plur', 'P', 'Acc', '4'], ['Fem', 'F', 'Plur', 'P', 'Voc', '5']]],
                'zachařových' => ['Zachařův', 'Zachařóv', [['Anim', 'M', 'Plur', 'P', 'Gen', '2'], ['Anim', 'M', 'Plur', 'P', 'Loc', '6'], ['Fem', 'F', 'Plur', 'P', 'Gen', '2'], ['Fem', 'F', 'Plur', 'P', 'Loc', '6'], ['Neut', 'N', 'Plur', 'P', 'Gen', '2'], ['Neut', 'N', 'Plur', 'P', 'Loc', '6']]],
                'zachařovým'  => ['Zachařův', 'Zachařóv', [['Anim', 'M', 'Sing', 'S', 'Ins', '7'], ['Anim', 'M', 'Plur', 'P', 'Dat', '3'], ['Fem', 'F', 'Plur', 'P', 'Dat', '3'], ['Neut', 'N', 'Sing', 'S', 'Ins', '7'], ['Neut', 'N', 'Plur', 'P', 'Dat', '3']]],
                'zachařovými' => ['Zachařův', 'Zachařóv', [['Anim', 'M', 'Plur', 'P', 'Ins', '7'], ['Fem', 'F', 'Plur', 'P', 'Ins', '7'], ['Neut', 'N', 'Plur', 'P', 'Ins', '7']]],
                'zachařuov'   => ['Zachařův', 'Zachařóv', [['Anim', 'M', 'Sing', 'S', 'Nom', '1'], ['Anim', 'M', 'Sing', 'S', 'Voc', '5']]],
                'zachařův'    => ['Zachařův', 'Zachařóv', [['Anim', 'M', 'Sing', 'S', 'Nom', '1'], ['Anim', 'M', 'Sing', 'S', 'Voc', '5']]],
                'zebedeášóv'    => ['Zebedeův', 'Zebedeóv', [['Anim', 'M', 'Sing', 'S', 'Nom', '1'], ['Anim', 'M', 'Sing', 'S', 'Voc', '5']]],
                'zebedeášova'   => ['Zebedeův', 'Zebedeóv', [['Anim', 'M', 'Sing', 'S', 'Gen', '2'], ['Anim', 'M', 'Sing', 'S', 'Acc', '4'], ['Fem', 'F', 'Sing', 'S', 'Nom', '1'], ['Fem', 'F', 'Sing', 'S', 'Voc', '5'], ['Neut', 'N', 'Sing', 'S', 'Gen', '2'], ['Neut', 'N', 'Plur', 'P', 'Nom', '1'], ['Neut', 'N', 'Plur', 'P', 'Acc', '4'], ['Neut', 'N', 'Plur', 'P', 'Voc', '5']]],
                'zebedeášově'   => ['Zebedeův', 'Zebedeóv', [['Anim', 'M', 'Sing', 'S', 'Loc', '6'], ['Fem', 'F', 'Sing', 'S', 'Dat', '3'], ['Fem', 'F', 'Sing', 'S', 'Loc', '6'], ['Neut', 'N', 'Sing', 'S', 'Loc', '6']]],
                'zebedeášovi'   => ['Zebedeův', 'Zebedeóv', [['Anim', 'M', 'Plur', 'P', 'Nom', '1'], ['Anim', 'M', 'Plur', 'P', 'Voc', '5']]],
                'zebedeášovo'   => ['Zebedeův', 'Zebedeóv', [['Neut', 'N', 'Sing', 'S', 'Nom', '1'], ['Neut', 'N', 'Sing', 'S', 'Acc', '4'], ['Neut', 'N', 'Sing', 'S', 'Voc', '5']]],
                'zebedeášovou'  => ['Zebedeův', 'Zebedeóv', [['Fem', 'F', 'Sing', 'S', 'Ins', '7']]],
                'zebedeášovu'   => ['Zebedeův', 'Zebedeóv', [['Anim', 'M', 'Sing', 'S', 'Dat', '3'], ['Fem', 'F', 'Sing', 'S', 'Acc', '4'], ['Neut', 'N', 'Sing', 'S', 'Dat', '3']]],
                'zebedeášovú'   => ['Zebedeův', 'Zebedeóv', [['Fem', 'F', 'Sing', 'S', 'Ins', '7']]],
                'zebedeášovy'   => ['Zebedeův', 'Zebedeóv', [['Anim', 'M', 'Plur', 'P', 'Acc', '4'], ['Fem', 'F', 'Sing', 'S', 'Gen', '2'], ['Fem', 'F', 'Plur', 'P', 'Nom', '1'], ['Fem', 'F', 'Plur', 'P', 'Acc', '4'], ['Fem', 'F', 'Plur', 'P', 'Voc', '5']]],
                'zebedeášových' => ['Zebedeův', 'Zebedeóv', [['Anim', 'M', 'Plur', 'P', 'Gen', '2'], ['Anim', 'M', 'Plur', 'P', 'Loc', '6'], ['Fem', 'F', 'Plur', 'P', 'Gen', '2'], ['Fem', 'F', 'Plur', 'P', 'Loc', '6'], ['Neut', 'N', 'Plur', 'P', 'Gen', '2'], ['Neut', 'N', 'Plur', 'P', 'Loc', '6']]],
                'zebedeášovým'  => ['Zebedeův', 'Zebedeóv', [['Anim', 'M', 'Sing', 'S', 'Ins', '7'], ['Anim', 'M', 'Plur', 'P', 'Dat', '3'], ['Fem', 'F', 'Plur', 'P', 'Dat', '3'], ['Neut', 'N', 'Sing', 'S', 'Ins', '7'], ['Neut', 'N', 'Plur', 'P', 'Dat', '3']]],
                'zebedeášovými' => ['Zebedeův', 'Zebedeóv', [['Anim', 'M', 'Plur', 'P', 'Ins', '7'], ['Fem', 'F', 'Plur', 'P', 'Ins', '7'], ['Neut', 'N', 'Plur', 'P', 'Ins', '7']]],
                'zebedeášuov'   => ['Zebedeův', 'Zebedeóv', [['Anim', 'M', 'Sing', 'S', 'Nom', '1'], ['Anim', 'M', 'Sing', 'S', 'Voc', '5']]],
                'zebedeášův'    => ['Zebedeův', 'Zebedeóv', [['Anim', 'M', 'Sing', 'S', 'Nom', '1'], ['Anim', 'M', 'Sing', 'S', 'Voc', '5']]],
                'zebedeóv'      => ['Zebedeův', 'Zebedeóv', [['Anim', 'M', 'Sing', 'S', 'Nom', '1'], ['Anim', 'M', 'Sing', 'S', 'Voc', '5']]],
                'zebedeova'     => ['Zebedeův', 'Zebedeóv', [['Anim', 'M', 'Sing', 'S', 'Gen', '2'], ['Anim', 'M', 'Sing', 'S', 'Acc', '4'], ['Fem', 'F', 'Sing', 'S', 'Nom', '1'], ['Fem', 'F', 'Sing', 'S', 'Voc', '5'], ['Neut', 'N', 'Sing', 'S', 'Gen', '2'], ['Neut', 'N', 'Plur', 'P', 'Nom', '1'], ['Neut', 'N', 'Plur', 'P', 'Acc', '4'], ['Neut', 'N', 'Plur', 'P', 'Voc', '5']]],
                'zebedeově'     => ['Zebedeův', 'Zebedeóv', [['Anim', 'M', 'Sing', 'S', 'Loc', '6'], ['Fem', 'F', 'Sing', 'S', 'Dat', '3'], ['Fem', 'F', 'Sing', 'S', 'Loc', '6'], ['Neut', 'N', 'Sing', 'S', 'Loc', '6']]],
                'zebedeovi'     => ['Zebedeův', 'Zebedeóv', [['Anim', 'M', 'Plur', 'P', 'Nom', '1'], ['Anim', 'M', 'Plur', 'P', 'Voc', '5']]],
                'zebedeovo'     => ['Zebedeův', 'Zebedeóv', [['Neut', 'N', 'Sing', 'S', 'Nom', '1'], ['Neut', 'N', 'Sing', 'S', 'Acc', '4'], ['Neut', 'N', 'Sing', 'S', 'Voc', '5']]],
                'zebedeovou'    => ['Zebedeův', 'Zebedeóv', [['Fem', 'F', 'Sing', 'S', 'Ins', '7']]],
                'zebedeovu'     => ['Zebedeův', 'Zebedeóv', [['Anim', 'M', 'Sing', 'S', 'Dat', '3'], ['Fem', 'F', 'Sing', 'S', 'Acc', '4'], ['Neut', 'N', 'Sing', 'S', 'Dat', '3']]],
                'zebedeovú'     => ['Zebedeův', 'Zebedeóv', [['Fem', 'F', 'Sing', 'S', 'Ins', '7']]],
                'zebedeovy'     => ['Zebedeův', 'Zebedeóv', [['Anim', 'M', 'Plur', 'P', 'Acc', '4'], ['Fem', 'F', 'Sing', 'S', 'Gen', '2'], ['Fem', 'F', 'Plur', 'P', 'Nom', '1'], ['Fem', 'F', 'Plur', 'P', 'Acc', '4'], ['Fem', 'F', 'Plur', 'P', 'Voc', '5']]],
                'zebedeových'   => ['Zebedeův', 'Zebedeóv', [['Anim', 'M', 'Plur', 'P', 'Gen', '2'], ['Anim', 'M', 'Plur', 'P', 'Loc', '6'], ['Fem', 'F', 'Plur', 'P', 'Gen', '2'], ['Fem', 'F', 'Plur', 'P', 'Loc', '6'], ['Neut', 'N', 'Plur', 'P', 'Gen', '2'], ['Neut', 'N', 'Plur', 'P', 'Loc', '6']]],
                'zebedeovým'    => ['Zebedeův', 'Zebedeóv', [['Anim', 'M', 'Sing', 'S', 'Ins', '7'], ['Anim', 'M', 'Plur', 'P', 'Dat', '3'], ['Fem', 'F', 'Plur', 'P', 'Dat', '3'], ['Neut', 'N', 'Sing', 'S', 'Ins', '7'], ['Neut', 'N', 'Plur', 'P', 'Dat', '3']]],
                'zebedeovými'   => ['Zebedeův', 'Zebedeóv', [['Anim', 'M', 'Plur', 'P', 'Ins', '7'], ['Fem', 'F', 'Plur', 'P', 'Ins', '7'], ['Neut', 'N', 'Plur', 'P', 'Ins', '7']]],
                'zebedeuov'     => ['Zebedeův', 'Zebedeóv', [['Anim', 'M', 'Sing', 'S', 'Nom', '1'], ['Anim', 'M', 'Sing', 'S', 'Voc', '5']]],
                'zebedeův'      => ['Zebedeův', 'Zebedeóv', [['Anim', 'M', 'Sing', 'S', 'Nom', '1'], ['Anim', 'M', 'Sing', 'S', 'Voc', '5']]]
            );
            my $ma = $ma{$lform}; die("Something is wrong: '$lform'") if(!defined($ma));
            $f[2] = $ma->[0];
            $f[9] = set_lemma1300($f[9], $ma->[1]);
            $f[3] = 'ADJ';
            # U některých slov umožňujeme několik čtení, ale pokud to není žádné z nich, dáme první jako default.
            my @alt = @{$ma->[2]};
            for(my $i = $#alt; $i >= 0 ; $i--)
            {
                my $animacy = $alt[$i][0] =~ m/^(Anim|Inan)$/ ? $alt[$i][0] : undef;
                my $gender = $alt[$i][0] =~ m/^(Anim|Inan)$/ ? 'Masc' : $alt[$i][0];
                my $number = $alt[$i][2];
                my $case = $alt[$i][4];
                if($i == 0 || defined($alt[$i][6]) && get_ref($f[9]) =~ m/^$alt[$i][6]$/ || !defined($alt[$i][6]) && $f[5] =~ m/Case=$case.*Gender=$gender.*Number=$number/)
                {
                    $f[4] = 'AU'.$alt[$i][1].$alt[$i][3].$alt[$i][5].'M---------';
                    $f[5] = "Case=$case|Gender=$gender|Gender[psor]=Masc|NameType=Giv|Number=$number|Poss=Yes";
                    $f[5] = "Animacy=$animacy|$f[5]" if(defined($animacy));
                    last;
                }
            }
        }
        elsif($f[1] =~ m/^(Křtitel)(óv|ova|ově|ovo|ovu|ovú|ovy|ových)$/i)
        {
            my $lform = lc($f[1]);
            my %ma =
            (
                'křtitelovu' => ['Křtitelův', 'Křstitelóv', [['Fem', 'F', 'Sing', 'S', 'Acc', '4']]]
            );
            my $ma = $ma{$lform}; die("Something is wrong: '$lform'") if(!defined($ma));
            $f[2] = $ma->[0];
            $f[9] = set_lemma1300($f[9], $ma->[1]);
            $f[3] = 'ADJ';
            # U některých slov umožňujeme několik čtení, ale pokud to není žádné z nich, dáme první jako default.
            my @alt = @{$ma->[2]};
            for(my $i = $#alt; $i >= 0 ; $i--)
            {
                my $animacy = $alt[$i][0] =~ m/^(Anim|Inan)$/ ? $alt[$i][0] : undef;
                my $gender = $alt[$i][0] =~ m/^(Anim|Inan)$/ ? 'Masc' : $alt[$i][0];
                my $number = $alt[$i][2];
                my $case = $alt[$i][4];
                if($i == 0 || defined($alt[$i][6]) && get_ref($f[9]) =~ m/^$alt[$i][6]$/ || !defined($alt[$i][6]) && $f[5] =~ m/Case=$case.*Gender=$gender.*Number=$number/)
                {
                    $f[4] = 'AU'.$alt[$i][1].$alt[$i][3].$alt[$i][5].'M---------';
                    $f[5] = "Case=$case|Gender=$gender|Gender[psor]=Masc|NameType=Sur|Number=$number|Poss=Yes";
                    $f[5] = "Animacy=$animacy|$f[5]" if(defined($animacy));
                    last;
                }
            }
        }
        elsif($f[1] =~ m/^(ciesař|hospodin)(óv|iev|ova|ově|ovo|ěvo|ovu|ovy|ových)$/i)
        {
            my $lform = lc($f[1]);
            my %ma =
            (
                'ciesařiev'     => ['císařův',    'ciesařóv',   [['Anim', 'M', 'Sing', 'S', 'Nom', '1']]],
                'ciesařěvo'     => ['císařův',    'ciesařóv',   [['Neut', 'N', 'Sing', 'S', 'Nom', '1']]],
                'ciesařóv'    => ['císařův', 'ciesařóv', [['Anim', 'M', 'Sing', 'S', 'Nom', '1'], ['Anim', 'M', 'Sing', 'S', 'Voc', '5']]],
                'ciesařova'   => ['císařův', 'ciesařóv', [['Anim', 'M', 'Sing', 'S', 'Gen', '2'], ['Anim', 'M', 'Sing', 'S', 'Acc', '4'], ['Fem', 'F', 'Sing', 'S', 'Nom', '1'], ['Fem', 'F', 'Sing', 'S', 'Voc', '5'], ['Neut', 'N', 'Sing', 'S', 'Gen', '2'], ['Neut', 'N', 'Plur', 'P', 'Nom', '1'], ['Neut', 'N', 'Plur', 'P', 'Acc', '4'], ['Neut', 'N', 'Plur', 'P', 'Voc', '5']]],
                'ciesařově'   => ['císařův', 'ciesařóv', [['Anim', 'M', 'Sing', 'S', 'Loc', '6'], ['Fem', 'F', 'Sing', 'S', 'Dat', '3'], ['Fem', 'F', 'Sing', 'S', 'Loc', '6'], ['Neut', 'N', 'Sing', 'S', 'Loc', '6']]],
                'ciesařovi'   => ['císařův', 'ciesařóv', [['Anim', 'M', 'Plur', 'P', 'Nom', '1'], ['Anim', 'M', 'Plur', 'P', 'Voc', '5']]],
                'ciesařovo'   => ['císařův', 'ciesařóv', [['Neut', 'N', 'Sing', 'S', 'Nom', '1'], ['Neut', 'N', 'Sing', 'S', 'Acc', '4'], ['Neut', 'N', 'Sing', 'S', 'Voc', '5']]],
                'ciesařovou'  => ['císařův', 'ciesařóv', [['Fem', 'F', 'Sing', 'S', 'Ins', '7']]],
                'ciesařovu'   => ['císařův', 'ciesařóv', [['Anim', 'M', 'Sing', 'S', 'Dat', '3'], ['Fem', 'F', 'Sing', 'S', 'Acc', '4'], ['Neut', 'N', 'Sing', 'S', 'Dat', '3']]],
                'ciesařovú'   => ['císařův', 'ciesařóv', [['Fem', 'F', 'Sing', 'S', 'Ins', '7']]],
                'ciesařovy'   => ['císařův', 'ciesařóv', [['Anim', 'M', 'Plur', 'P', 'Acc', '4'], ['Fem', 'F', 'Sing', 'S', 'Gen', '2'], ['Fem', 'F', 'Plur', 'P', 'Nom', '1'], ['Fem', 'F', 'Plur', 'P', 'Acc', '4'], ['Fem', 'F', 'Plur', 'P', 'Voc', '5']]],
                'ciesařových' => ['císařův', 'ciesařóv', [['Anim', 'M', 'Plur', 'P', 'Gen', '2'], ['Anim', 'M', 'Plur', 'P', 'Loc', '6'], ['Fem', 'F', 'Plur', 'P', 'Gen', '2'], ['Fem', 'F', 'Plur', 'P', 'Loc', '6'], ['Neut', 'N', 'Plur', 'P', 'Gen', '2'], ['Neut', 'N', 'Plur', 'P', 'Loc', '6']]],
                'ciesařovým'  => ['císařův', 'ciesařóv', [['Anim', 'M', 'Sing', 'S', 'Ins', '7'], ['Anim', 'M', 'Plur', 'P', 'Dat', '3'], ['Fem', 'F', 'Plur', 'P', 'Dat', '3'], ['Neut', 'N', 'Sing', 'S', 'Ins', '7'], ['Neut', 'N', 'Plur', 'P', 'Dat', '3']]],
                'ciesařovými' => ['císařův', 'ciesařóv', [['Anim', 'M', 'Plur', 'P', 'Ins', '7'], ['Fem', 'F', 'Plur', 'P', 'Ins', '7'], ['Neut', 'N', 'Plur', 'P', 'Ins', '7']]],
                'ciesařuov'   => ['císařův', 'ciesařóv', [['Anim', 'M', 'Sing', 'S', 'Nom', '1'], ['Anim', 'M', 'Sing', 'S', 'Voc', '5']]],
                'ciesařův'    => ['císařův', 'ciesařóv', [['Anim', 'M', 'Sing', 'S', 'Nom', '1'], ['Anim', 'M', 'Sing', 'S', 'Voc', '5']]],
                'hospodinóv'    => ['hospodinův', 'hospodinóv', [['Anim', 'M', 'Sing', 'S', 'Nom', '1'], ['Anim', 'M', 'Sing', 'S', 'Voc', '5']]],
                'hospodinova'   => ['hospodinův', 'hospodinóv', [['Anim', 'M', 'Sing', 'S', 'Gen', '2'], ['Anim', 'M', 'Sing', 'S', 'Acc', '4'], ['Fem', 'F', 'Sing', 'S', 'Nom', '1'], ['Fem', 'F', 'Sing', 'S', 'Voc', '5'], ['Neut', 'N', 'Sing', 'S', 'Gen', '2'], ['Neut', 'N', 'Plur', 'P', 'Nom', '1'], ['Neut', 'N', 'Plur', 'P', 'Acc', '4'], ['Neut', 'N', 'Plur', 'P', 'Voc', '5']]],
                'hospodinově'   => ['hospodinův', 'hospodinóv', [['Anim', 'M', 'Sing', 'S', 'Loc', '6'], ['Fem', 'F', 'Sing', 'S', 'Dat', '3'], ['Fem', 'F', 'Sing', 'S', 'Loc', '6'], ['Neut', 'N', 'Sing', 'S', 'Loc', '6']]],
                'hospodinovi'   => ['hospodinův', 'hospodinóv', [['Anim', 'M', 'Plur', 'P', 'Nom', '1'], ['Anim', 'M', 'Plur', 'P', 'Voc', '5']]],
                'hospodinovo'   => ['hospodinův', 'hospodinóv', [['Neut', 'N', 'Sing', 'S', 'Nom', '1'], ['Neut', 'N', 'Sing', 'S', 'Acc', '4'], ['Neut', 'N', 'Sing', 'S', 'Voc', '5']]],
                'hospodinovou'  => ['hospodinův', 'hospodinóv', [['Fem', 'F', 'Sing', 'S', 'Ins', '7']]],
                'hospodinovu'   => ['hospodinův', 'hospodinóv', [['Anim', 'M', 'Sing', 'S', 'Dat', '3'], ['Fem', 'F', 'Sing', 'S', 'Acc', '4'], ['Neut', 'N', 'Sing', 'S', 'Dat', '3']]],
                'hospodinovú'   => ['hospodinův', 'hospodinóv', [['Fem', 'F', 'Sing', 'S', 'Ins', '7']]],
                'hospodinovy'   => ['hospodinův', 'hospodinóv', [['Anim', 'M', 'Plur', 'P', 'Acc', '4'], ['Fem', 'F', 'Sing', 'S', 'Gen', '2'], ['Fem', 'F', 'Plur', 'P', 'Nom', '1'], ['Fem', 'F', 'Plur', 'P', 'Acc', '4'], ['Fem', 'F', 'Plur', 'P', 'Voc', '5']]],
                'hospodinových' => ['hospodinův', 'hospodinóv', [['Anim', 'M', 'Plur', 'P', 'Gen', '2'], ['Anim', 'M', 'Plur', 'P', 'Loc', '6'], ['Fem', 'F', 'Plur', 'P', 'Gen', '2'], ['Fem', 'F', 'Plur', 'P', 'Loc', '6'], ['Neut', 'N', 'Plur', 'P', 'Gen', '2'], ['Neut', 'N', 'Plur', 'P', 'Loc', '6']]],
                'hospodinovým'  => ['hospodinův', 'hospodinóv', [['Anim', 'M', 'Sing', 'S', 'Ins', '7'], ['Anim', 'M', 'Plur', 'P', 'Dat', '3'], ['Fem', 'F', 'Plur', 'P', 'Dat', '3'], ['Neut', 'N', 'Sing', 'S', 'Ins', '7'], ['Neut', 'N', 'Plur', 'P', 'Dat', '3']]],
                'hospodinovými' => ['hospodinův', 'hospodinóv', [['Anim', 'M', 'Plur', 'P', 'Ins', '7'], ['Fem', 'F', 'Plur', 'P', 'Ins', '7'], ['Neut', 'N', 'Plur', 'P', 'Ins', '7']]],
                'hospodinuov'   => ['hospodinův', 'hospodinóv', [['Anim', 'M', 'Sing', 'S', 'Nom', '1'], ['Anim', 'M', 'Sing', 'S', 'Voc', '5']]],
                'hospodinův'    => ['hospodinův', 'hospodinóv', [['Anim', 'M', 'Sing', 'S', 'Nom', '1'], ['Anim', 'M', 'Sing', 'S', 'Voc', '5']]]
            );
            my $ma = $ma{$lform}; die("Something is wrong: '$lform'") if(!defined($ma));
            $f[2] = $ma->[0];
            $f[9] = set_lemma1300($f[9], $ma->[1]);
            $f[3] = 'ADJ';
            # U některých slov umožňujeme několik čtení, ale pokud to není žádné z nich, dáme první jako default.
            my @alt = @{$ma->[2]};
            for(my $i = $#alt; $i >= 0 ; $i--)
            {
                my $animacy = $alt[$i][0] =~ m/^(Anim|Inan)$/ ? $alt[$i][0] : undef;
                my $gender = $alt[$i][0] =~ m/^(Anim|Inan)$/ ? 'Masc' : $alt[$i][0];
                my $number = $alt[$i][2];
                my $case = $alt[$i][4];
                if($i == 0 || defined($alt[$i][6]) && get_ref($f[9]) =~ m/^$alt[$i][6]$/ || !defined($alt[$i][6]) && $f[5] =~ m/Case=$case.*Gender=$gender.*Number=$number/)
                {
                    $f[4] = 'AU'.$alt[$i][1].$alt[$i][3].$alt[$i][5].'M---------';
                    $f[5] = "Case=$case|Gender=$gender|Gender[psor]=Masc|Number=$number|Poss=Yes";
                    $f[5] = "Animacy=$animacy|$f[5]" if(defined($animacy));
                    last;
                }
            }
        }
        #----------------------------------------------------------------------
        # Zájmena (jejich hlavní zpracování ale bude dole).
        #----------------------------------------------------------------------
        # Zájmena "an, ana, ano" jsou zřejmě etymologicky spojením "a on, a ona, a ono".
        # Můžou odkazovat na podmět nebo předmět předcházející věty (pokud je ve 3. osobě).
        # Můžou se také chovat jako vztažná zájmena (= "který, jenž") a můžou
        # dokonce vystupovat jako spojky nebo částice, tj. referenční funkce zájmena je potlačená.
        # https://vokabular.ujc.cas.cz/hledani.aspx?hw=an
        elsif($f[1] =~ m/^an$/i)
        {
            $f[2] = 'an';
            $f[9] = set_lemma1300($f[9], 'an');
            $f[3] = 'PRON';
            $f[4] = 'PJYS1----------';
            $f[5] = 'Case=Nom|Gender=Masc|Number=Sing|PronType=Rel';
        }
        elsif($f[1] =~ m/^ana$/i)
        {
            $f[2] = 'an';
            $f[9] = set_lemma1300($f[9], 'an');
            $f[3] = 'PRON';
            $f[4] = 'PJFS1----------';
            $f[5] = 'Case=Nom|Gender=Fem|Number=Sing|PronType=Rel';
        }
        # Pozor na homonymii s částicí/citoslovcem "ano".
        elsif($f[1] =~ m/^ano$/i && get_ref($f[9]) =~ m/^MATT_(7\.4|10\.23)$/)
        {
            $f[2] = 'an';
            $f[9] = set_lemma1300($f[9], 'an');
            $f[3] = 'PRON';
            $f[4] = 'PJNS1----------';
            $f[5] = 'Case=Nom|Gender=Neut|Number=Sing|PronType=Rel';
        }
        # Pozor na homonymii se spojkou "ani". Ve většině případů jde o spojku,
        # ale v Ol. 4.21: "A když ottud jide dále, uzřě druhá dva bratry, Jakuba,
        # syna Zebedeova, a Jana, bratra jeho, v lodí s Zebedeem, s otcem jich,
        # ani skládáchu své sieti, i pozva jich."
        elsif($f[1] =~ m/^ani$/i && get_ref($f[9]) =~ m/^MATT_(5\.15|17\.15|22\.3|4\.18|4\.21)$/)
        {
            $f[2] = 'an';
            $f[9] = set_lemma1300($f[9], 'an');
            $f[3] = 'PRON';
            $f[4] = 'PJMP1----------';
            $f[5] = 'Animacy=Anim|Case=Nom|Gender=Masc|Number=Plur|PronType=Rel';
        }
        elsif($f[1] =~ m/^čie$/i)
        {
            # Ve všech třech výskytech jde o "čie bude žena", tj. Fem Sing Nom.
            $f[2] = 'čí';
            $f[9] = set_lemma1300($f[9], 'čie');
            $f[3] = 'DET';
            $f[4] = 'P4FS1----------';
            $f[5] = 'Case=Nom|Gender=Fem|Number=Sing|Poss=Yes|PronType=Int,Rel';
        }
        elsif($f[1] =~ m/^je$/i)
        {
            # Většinou jde o akuzativ osobního zájmena "ono", ale v několika případech jde o tvar slovesa "být"
            # (jako alternativa k tehdy běžnému tvaru "jest") a v jednom případě jde o tvar slovesa "jmout"
            # (jako alternativa ke správnému tvaru "jě").
            if(get_ref($f[9]) =~ m/^MATT_(13\.56|22\.20|26\.8|26\.9|12\.6)$/)
            {
                $f[2] = 'být';
                $f[9] = set_lemma1300($f[9], 'býti');
                $f[3] = 'AUX';
                $f[4] = 'VB-S---3P-AA---';
                $f[5] = 'Aspect=Imp|Mood=Ind|Number=Sing|Person=3|Polarity=Pos|Tense=Pres|VerbForm=Fin|Voice=Act';
            }
            elsif(get_ref($f[9]) =~ m/^MATT_9\.33$/)
            {
                $f[2] = 'jmout';
                $f[9] = set_lemma1300($f[9], 'jieti');
                $f[3] = 'VERB';
                $f[4] = 'V--S---3A-AA---';
                $f[5] = 'Aspect=Perf|Mood=Ind|Number=Sing|Person=3|Polarity=Pos|Tense=Past|Variant=Long|VerbForm=Fin|Voice=Act';
            }
            else
            {
                $f[2] = 'on';
                $f[9] = set_lemma1300($f[9], 'on');
                $f[3] = 'PRON';
                $f[4] = 'PPNS4--3-------';
                $f[5] = 'Case=Acc|Gender=Neut|Number=Sing|Person=3|PrepCase=Npr|PronType=Prs';
            }
        }
        elsif($f[1] =~ m/^jenž$/i)
        {
            # Ostatní tvary zájmena "jenž" jsou podchycené níže u zájmen, ale
            # samotný tvar "jenž" si UDPipe občas plete i se spojkami, tak ho
            # řeším tady, bez omezení na PRON a DET.
            $f[2] = 'jenž';
            $f[9] = set_lemma1300($f[9], 'jenž');
            $f[3] = 'PRON';
            $f[4] = 'PJYS1----------';
            $f[5] = 'Case=Nom|Gender=Masc|Number=Sing|PrepCase=Npr|PronType=Rel';
        }
        # Tvary zájmena "jenžto" si UDPipe často plete se spojkami a dalšími slovními druhy.
        # jenžto ... Masc Anim|Inan Sing Nom (ale pro Inan i Acc); v nominativu se vyskytlo i ve vztažných větách, kam z kontextu patřil plurál!
        # jiežto ... Fem Sing Gen (i když v jednom případě odkazuje na "trest", takže Masc Inan)
        # jižto ... Fem Sing Acc
        # ježto ... Neut Sing Acc
        # jížto ... Masc Anim Plur Nom
        # jěžto ... Masc Anim Plur Acc
        elsif($f[1] =~ m/^(jenž|jiež|již|jež|jíž|jěž)to$/i)
        {
            $f[2] = 'jenžto';
            $f[9] = set_lemma1300($f[9], 'jenžto');
            $f[3] = 'PRON';
            if($f[1] =~ m/^jenžto$/i)
            {
                $f[4] = 'PJMS1----------';
                $f[5] = 'Animacy=Anim|Case=Nom|Gender=Masc|Number=Sing|PrepCase=Npr|PronType=Rel';
            }
            elsif($f[1] =~ m/^jiežto$/i)
            {
                $f[4] = 'PJFS2----------';
                $f[5] = 'Case=Gen|Gender=Fem|Number=Sing|PrepCase=Npr|PronType=Rel';
            }
            elsif($f[1] =~ m/^jižto$/i)
            {
                $f[4] = 'PJFS4----------';
                $f[5] = 'Case=Acc|Gender=Fem|Number=Sing|PrepCase=Npr|PronType=Rel';
            }
            elsif($f[1] =~ m/^ježto$/i)
            {
                $f[4] = 'PJNS4----------';
                $f[5] = 'Case=Acc|Gender=Neut|Number=Sing|PrepCase=Npr|PronType=Rel';
            }
            elsif($f[1] =~ m/^jížto$/i)
            {
                $f[4] = 'PJMP1----------';
                $f[5] = 'Animacy=Anim|Case=Nom|Gender=Masc|Number=Plur|PrepCase=Npr|PronType=Rel';
            }
            else # jěžto
            {
                $f[4] = 'PJMP4----------';
                $f[5] = 'Animacy=Anim|Case=Acc|Gender=Masc|Number=Plur|PrepCase=Npr|PronType=Rel';
            }
        }
        elsif($f[1] =~ m/^ješto$/i)
        {
            # Zdá se, že "ješto" bylo nesklonné a zastupovalo libovolný rod a číslo.
            # Nejsem si jist, zda může vystupovat v jiné pozici než jako podmět (nominativ).
            $f[2] = 'ješto';
            $f[9] = set_lemma1300($f[9], 'ješto');
            $f[3] = 'PRON';
            $f[4] = 'PE--1----------';
            $f[5] = 'Case=Nom|PronType=Rel';
        }
        elsif($f[1] =~ m/^jie$/i)
        {
            # Většinou jde o tvar osobního zájmena "ona", ale v 9.11 jde o tvar slovesa "jíst".
            # UDPipe tomu někdy dává dost divoké značky, třeba ADP nebo PART, takže to musíme zkoumat už zde.
            if(get_ref($f[9]) =~ m/^MATT_9\.11$/)
            {
                $f[2] = 'jíst';
                $f[9] = set_lemma1300($f[9], 'jiesti');
                $f[3] = 'VERB';
                $f[4] = 'VB-S---3P-AA---';
                $f[5] = 'Aspect=Imp|Mood=Ind|Number=Sing|Person=3|Polarity=Pos|Tense=Pres|VerbForm=Fin|Voice=Act';
            }
            else
            {
                $f[2] = 'on';
                $f[9] = set_lemma1300($f[9], 'on');
                $f[3] = 'PRON';
                ###!!! Je jasné, že jde o femininum a singulár, ale mám problém s pádem.
                ###!!! Pokud předpokládám, že staročeské "jie" odpovídá novočeskému "jí", pak může jít o genitiv, dativ a instrumentál; ten poslední ale můžu u všech výskytů podle kontextu vyloučit.
                ###!!! Naopak v řadě kontextů by mi spíše pasoval akuzativ, i když nemůžu vyloučit, že ve starší češtině dotyčná slovesa umožňovala i vazbu s genitivem.
                ###!!! Např. v Drážďanské bibli: "nechtieše jie pojieti" by mohl být genitiv i akuzativ, o kus dál ale autor používá akuzativ: "pojě svú ženu".
                ###!!! V Olomoucké bibli je řada výskytů, které vypadají na dativ: 14.7 "slíbil jest jie dáti to vše", 15.23 "neotpovědě jie i slova", 20.21 "jenž vecě jie".
                ###!!! V Olomoucké 18.13 to dokonce vypadá na ten instrumentál: "sě bude viece jie radovati nežli devieti a devadesáti, ješto sú nezablúdily".
                $f[4] = 'PPFS2--3-------';
                $f[5] = 'Case=Gen|Gender=Fem|Number=Sing|Person=3|PrepCase=Npr|PronType=Prs';
            }
        }
        elsif($f[1] =~ m/^jiej$/i)
        {
            $f[2] = 'on';
            $f[9] = set_lemma1300($f[9], 'on');
            $f[3] = 'PRON';
            if(get_ref($f[9]) eq 'MATT_5.28')
            {
                $f[4] = 'PPFS2--3-------';
                $f[5] = 'Case=Gen|Gender=Fem|Number=Sing|Person=3|PrepCase=Npr|PronType=Prs';
            }
            else
            {
                $f[4] = 'PPFS3--3-------';
                $f[5] = 'Case=Dat|Gender=Fem|Number=Sing|Person=3|PrepCase=Npr|PronType=Prs';
            }
        }
        elsif($f[1] =~ m/^má$/i)
        {
            # Asi 20 výskytů jsou zájmena: "slova má", "dcera má".
            # Asi 23 výskytů jsou slovesa ("mít"), zejména v Olomoucké bibli. V Drážďanské jsem našel jeden výskyt ve verši 25.28, jinak tam převládá zápis "jmá".
            if(get_ref($f[9]) =~ m/^MATT_(25\.28|5\.23|6\.34|9\.6|11\.14|11\.15|13\.(9|12|27|43|44|46)|16\.27|17\.(11|12|21)|24\.(42|44)|25\.(28|29)|26\.(21|46))$/)
            {
                $f[2] = 'mít';
                $f[9] = set_lemma1300($f[9], 'jmieti');
                $f[3] = 'VERB';
                $f[4] = 'VB-S---3P-AA---';
                $f[5] = 'Mood=Ind|Number=Sing|Person=3|Polarity=Pos|Tense=Pres|VerbForm=Fin|Voice=Act';
            }
            elsif(get_ref($f[9]) =~ m/^MATT_20\.21$/)
            {
                # Nom tato má dva syny
                $f[2] = 'můj';
                $f[9] = set_lemma1300($f[9], 'mój');
                $f[3] = 'DET';
                $f[5] = 'Case=Nom|Gender=Masc|Number=Dual|Number[psor]=Sing|Person=1|Poss=Yes|PronType=Prs';
            }
            else
            {
                # Nom dcera má
                # Nom|Acc slova má
                $f[2] = 'můj';
                $f[9] = set_lemma1300($f[9], 'mój');
                $f[3] = 'DET';
                if($f[5] =~ m/Number=Plur/)
                {
                    $f[5] = 'Case=Acc|Gender=Neut|Number=Plur|Number[psor]=Sing|Person=1|Poss=Yes|PronType=Prs';
                }
                else
                {
                    $f[5] = 'Case=Nom|Gender=Fem|Number=Sing|Number[psor]=Sing|Person=1|Poss=Yes|PronType=Prs';
                }
            }
        }
        elsif($f[1] =~ m/^my$/i)
        {
            # Několik výskytů zájmena "my" je chybně označkováno jako spojka.
            $f[2] = 'my';
            $f[9] = set_lemma1300($f[9], 'já');
            $f[3] = 'PRON';
            $f[4] = 'PP-P1--1-------';
            $f[5] = 'Case=Nom|Number=Plur|Person=1|PronType=Prs';
        }
        # Tvary slova "sám", "samý" se obtížně interpretují.
        # Nejčastěji jde o zdůrazňovací zájmeno (PronType=Emp) s lemmatem "sám": "sebe sama".
        # Některé dlouhé tvary ("samý") by se případně daly považovat za PronType=Tot "samým chlebem" – nezdůrazňujeme, že je to chleba, ale že to všechno je chleba a nic jiného.
        # Kromě toho "samý" může mít i význam "stejný": "v ten samý čas". Pak by to možná mělo být spíš adjektivum než zájmeno/DET.
        # 12 sami:   vždy "sám" Emp PLMP1
        #  3 sama:   vždy "sám" Emp PLFS1
        #  3 samého: vždy "sám" Emp PLMS4
        #  2 samému: vždy "sám" Emp PLMS3
        #  3 samiem (Dr.) resp. samým (Ol.):
        #  - 18.15 "mezi jím samiem" ... "sám" Emp PLMS7
        #  - 12.4 ...................... "sám" Emp PLMP3
        #  - 4.4 "samiem chlebem" ...... "samý" Tot PLMS7 ???
        #  1 samý: "v ten samý čas" .... "samý" ADJ AAIS4...
        # Kromě toho "sám" (ale ne "samý") v nové češtině může ještě odpovídat adjektivu "samotný", "osamocený".
        # Další nejasnost je, zda máme oddělovat dlouhé tvary ("samý") od krátkých ("sám").
        # Např. akuzativ "samého" je podle mne dlouhý tvar, krátký (jmenný) by byl "sama".
        # Přinejmenším v nové češtině se v některých výše uvedených funkcích zřejmě preferují
        # některé tvary, ale možná nemá smysl zkoušet podle toho štěpit paradigma.
        # samý samého samému samém samým samí samých samým samé samými
        # sám  sama   samu?  samu? ?     sami ?      ?     samy ?
        # samá samé                samou samé samých samým samé samými
        # sama samy   ?      ?     ?     samy ?      ?     samy ?
        # samé samého samému samém samým samá samých samým samá samými
        # samo sama   samu?  samu? ?     sama ?      ?     sama ?
        # Shrnutí:
        # Dlouhé tvary: samý samá samé samí samé samého samou samému samém samým samých samými
        # Krátké tvary: sám  sama samo sami samy sama   samu  ?      ?     ?     ?      ?
        # Zastaralé tvary:                                                 samiem
        # https://docs.google.com/document/d/1G9PlLctMGHycW-GLaYCZFZV4OjT7pilO/edit#
        # Navzdory současné úpravě v PDT a mému současnému převodu do UD by to
        # asi chtělo trochu jiné řešení. Dlouhé i krátké tvary by měly mít stejnou
        # kategorii, a to DET PronType=Emp. Asi by také všechny měly mít stejné
        # lemma, a to v souladu s adjektivy dlouhý tvar "samý". Krátké tvary by
        # měly dostat rys Variant=Short.
        elsif($f[1] =~ m/^(samý|samého|samému|samém|samým|samiem|samá|samé|samou|samí|samých|samými|sám|sama|samy|samu|samo|sami)$/i)
        {
            my $lform = lc($1);
            $f[2] = 'samý';
            $f[9] = set_lemma1300($f[9], 'sám');
            $f[3] = 'DET';
            # Nemůžeme stoprocentně určit rod, číslo a pád libovolného tvaru.
            # Zde se soustředíme na tvary, o kterých víme, že se skutečně vyskytly v našich datech.
            if($lform eq 'sám')
            {
                $f[4] = 'PLMS1----------';
                $f[5] = 'Animacy=Anim|Case=Nom|Gender=Masc|Number=Sing|PronType=Emp|Variant=Short';
            }
            elsif($lform eq 'sami')
            {
                $f[4] = 'PLMP1----------';
                $f[5] = 'Animacy=Anim|Case=Nom|Gender=Masc|Number=Plur|PronType=Emp|Variant=Short';
            }
            elsif($lform eq 'sama')
            {
                $f[4] = 'PLFS1----------';
                $f[5] = 'Case=Nom|Gender=Fem|Number=Sing|PronType=Emp|Variant=Short';
            }
            elsif($lform eq 'samého')
            {
                $f[4] = 'PLMS4----------';
                $f[5] = 'Animacy=Anim|Case=Acc|Gender=Masc|Number=Sing|PronType=Emp';
            }
            elsif($lform eq 'samý')
            {
                $f[4] = 'PLIS4----------';
                $f[5] = 'Animacy=Inan|Case=Acc|Gender=Masc|Number=Sing|PronType=Emp';
            }
            elsif($lform eq 'samému')
            {
                $f[4] = 'PLMS3----------';
                $f[5] = 'Animacy=Anim|Case=Dat|Gender=Masc|Number=Sing|PronType=Emp';
            }
            elsif($lform =~ m/^(samiem|samým)$/)
            {
                if(get_ref($f[9]) eq 'MATT_12.4')
                {
                    $f[4] = 'PLMP3----------';
                    $f[5] = 'Animacy=Anim|Case=Dat|Gender=Masc|Number=Plur|PronType=Emp';
                }
                else
                {
                    $f[4] = 'PLMS7----------';
                    $f[5] = 'Animacy=Anim|Case=Ins|Gender=Masc|Number=Sing|PronType=Emp';
                }
            }
        }
        elsif($f[1] =~ m/^sě$/i)
        {
            # Několik výskytů zájmena "sě" je chybně označkováno jako předložka. Ta by se asi psala "se", nikoli "sě".
            $f[2] = 'se';
            $f[9] = set_lemma1300($f[9], 'sě');
            $f[3] = 'PRON';
            $f[4] = 'P7-X4----------';
            $f[5] = 'Case=Acc|PronType=Prs|Reflex=Yes|Variant=Short';
        }
        # Slovo "také" je většinou příslovce jako v nové češtině, ale výjimečně
        # to může být tvar ukazovacího zájmena "taký":
        # 8.10 (Dr i Ol) "nenalezl jsem také viery" ... Fem Sing Gen
        # 14.1 (Dr) "činí také divy" ... Masc Inan Plur Acc
        # 24.21 (Ol) "bude také hoře veliké" ... Neut Sing Nom
        elsif($f[1] =~ m/^také$/i && get_ref($f[9]) =~ m/^MATT_(8\.10|14\.1|24\.21)$/)
        {
            $f[2] = 'taký';
            $f[9] = set_lemma1300($f[9], 'taký');
            $f[3] = 'DET';
            my $ref = get_ref($f[9]);
            if($ref eq 'MATT_8.10')
            {
                $f[4] = 'PDFS2----------';
                $f[5] = 'Case=Gen|Gender=Fem|Number=Sing|PronType=Dem';
            }
            elsif($ref eq 'MATT_14.1')
            {
                $f[4] = 'PDMP4----------';
                $f[5] = 'Animacy=Inan|Case=Acc|Gender=Masc|Number=Plur|PronType=Dem';
            }
            else
            {
                $f[4] = 'PDNS1----------';
                $f[5] = 'Case=Nom|Gender=Neut|Number=Sing|PronType=Dem';
            }
        }
        elsif($f[1] =~ m/^takú$/i && $f[3] eq 'ADV')
        {
            # Jeden výskyt zájmena "takú" je chybně označkován jako příslovce.
            # Mohl by to být i instrumentál, ale oba výskyty jsou akuzativ.
            $f[2] = 'taký';
            $f[9] = set_lemma1300($f[9], 'taký');
            $f[3] = 'DET';
            $f[4] = 'PDFS4----------';
            $f[5] = 'Case=Acc|Gender=Fem|Number=Sing|PronType=Dem';
        }
        # Slovo "ti" může být dativ osobního zájmena "ty" nebo nominativ plurálu
        # od demonstrativa "ten". Jako dativ od "ty" se to ale v našich datech
        # vůbec nevyskytuje.
        elsif($f[1] =~ m/^ti$/i)
        {
            $f[2] = 'ten';
            $f[9] = set_lemma1300($f[9], 'ten');
            $f[3] = 'DET';
            $f[4] = 'PDMP1----------';
            $f[5] = 'Animacy=Anim|Case=Nom|Gender=Masc|Number=Plur|PronType=Dem';
        }
        elsif($f[1] =~ m/^tiem$/i)
        {
            $f[2] = 'ten';
            $f[9] = set_lemma1300($f[9], 'ten');
            $f[3] = 'DET';
            if(get_ref($f[9]) eq 'MATT_2.10')
            {
                $f[4] = 'PDNS7----------';
                $f[5] = 'Case=Ins|Gender=Neut|Number=Sing|PronType=Dem';
            }
            else
            {
                $f[4] = 'PDMS7----------';
                $f[5] = 'Animacy=Anim|Case=Ins|Gender=Masc|Number=Sing|PronType=Dem';
            }
        }
        elsif($f[1] =~ m/^túž$/i && $f[3] eq 'ADV')
        {
            # Jeden výskyt zájmena "túž" je chybně označkován jako příslovce.
            $f[2] = 'týž';
            $f[9] = set_lemma1300($f[9], 'týž');
            $f[3] = 'DET';
            $f[4] = 'PDFS7----------';
            $f[5] = 'Case=Ins|Gender=Fem|Number=Sing|PronType=Dem';
        }
        #----------------------------------------------------------------------
        # Číslovky.
        #----------------------------------------------------------------------
        elsif($f[1] =~ m/^(jeden)$/i)
        {
            $f[2] = 'jeden';
            $f[9] = set_lemma1300($f[9], 'jeden');
            $f[3] = 'NUM';
            if($f[5] =~ m/Case=Acc/)
            {
                $f[4] = 'ClIS4----------';
                $f[5] = 'Animacy=Inan|Case=Acc|Gender=Masc|Number=Sing|NumForm=Word|NumType=Card|NumValue=1,2,3';
            }
            else
            {
                $f[4] = 'ClYS1----------';
                $f[5] = 'Case=Nom|Gender=Masc|Number=Sing|NumForm=Word|NumType=Card|NumValue=1,2,3';
            }
        }
        elsif($f[1] =~ m/^(dva|dvě|dvú|dvěma|oba|obě)$/i)
        {
            $f[2] = $f[1] =~ m/^d/i ? 'dva' : 'oba';
            $f[9] = set_lemma1300($f[9], $f[2]);
            $f[3] = 'NUM';
            if($f[1] =~ m/^(dva|oba)$/i)
            {
                # Může být nominativ nebo akuzativ.
                if($f[5] =~ m/Case=Acc/)
                {
                    $f[4] = 'ClYD4----------';
                    $f[5] = 'Case=Acc|Gender=Masc|Number=Dual|NumForm=Word|NumType=Card|NumValue=1,2,3';
                }
                else
                {
                    $f[4] = 'ClYD1----------';
                    $f[5] = 'Case=Nom|Gender=Masc|Number=Dual|NumForm=Word|NumType=Card|NumValue=1,2,3';
                }
            }
            elsif($f[1] =~ m/^(dvě|obě)$/i)
            {
                # Všechny výskyty, které jsem viděl, byly akuzativ. Někdy femininum (dvě rybě, dvě nozě, dvě rucě), někdy neutrum (druhému dal dvě (závaží)).
                $f[4] = 'ClHD4----------';
                $f[5] = 'Case=Acc|Gender=Fem,Neut|Number=Dual|NumForm=Word|NumType=Card|NumValue=1,2,3';
            }
            elsif($f[1] =~ m/^dvú$/i)
            {
                # Obvykle jde o genitiv maskulina, ale viděl jsem taky lokativ (po dvú dní).
                $f[4] = 'ClZD2----------';
                $f[5] = 'Case=Gen|Gender=Masc,Neut|Number=Dual|NumForm=Word|NumType=Card|NumValue=1,2,3';
            }
            elsif($f[1] =~ m/^dvěma$/i)
            {
                # Viděl jsem jeden výskyt, byl to dativ maskulina (proti dvěma bratroma).
                $f[4] = 'ClXD3----------';
                $f[5] = 'Case=Dat|Number=Dual|NumForm=Word|NumType=Card|NumValue=1,2,3';
            }
        }
        elsif($f[1] =~ m/^pět$/i)
        {
            $f[9] = set_lemma1300($f[9], 'pět');
        }
        elsif($f[1] =~ m/^(tři|čtyři)dc[eě]ti(krát)?$/i)
        {
            my $prefix = lc($1);
            my $krat = lc($2);
            $f[2] = $prefix.'cet'.$krat;
            $f[9] = set_lemma1300($f[9], $prefix.'dcěti'.$krat);
            if($krat)
            {
                $f[3] = 'ADV';
                $f[4] = 'Cv-------------';
                $f[5] = 'NumType=Mult';
            }
            else
            {
                $f[3] = 'NUM';
                $f[4] = 'Cn-P4----------';
                $f[5] = 'Case=Acc|Number=Plur|NumForm=Word|NumType=Card';
            }
        }
        #----------------------------------------------------------------------
        # Slovesa.
        #----------------------------------------------------------------------
        # Zdá se, že v záporném tvaru se "j" v přítomném čase nedá vynechat. A i kdyby dalo, pletlo by se to se slovesem "nést", takže by bylo nebezpečné tu anotaci nějak měnit.
        # Tvar "je" se už vzácně objevuje jako alternativa k "jest", většina výskytů je ale akuzativ zájmena "ono". Řešíme výše spolu se zájmeny.
        # Tvar "buď" může být v nové češtině i spojka ("buď-nebo"), popř. také imperativ od "budit", ale ve staročeském evangeliu je to zřejmě vždy imperativ od "býti".
        # Nejdříve tvary, které umožňují pravidelné tvoření záporu.
        elsif($f[1] =~ m/^(ne)?(do|o[dt]|po|při|z)?(b[ýy]ti?|jsem|jsi|jest|jsta|jsm[ey]|jste|jsú|budu|budeš|bude|budeta|budemy?|budete|budú|bieše?|biešta|biechu|b[yě]chu|buď|buďtež?|bych|by|bychom|byšte|byl[aoi]?|jsa|jsúci?|jsúce)$/i)
        {
            my $negprefix = lc($1);
            my $prefix = lc($2);
            my $suffix = lc($3);
            @f = opravit_sloveso_byt($negprefix, $prefix, $suffix, @f);
        }
        # Potom tvary nepravidelného záporu a tvary, ze kterých zápor utvořit nelze. Např. jde utvořit "nejsem", ale ne "nesem", to je úplně jiné sloveso.
        elsif($f[1] =~ m/^(?:(ne)(nie|ní)|(sem|si|sta|sm[ey]|ste|sú))$/i)
        {
            my $negprefix = lc($1);
            my $suffix = lc($2 ? $2 : $3);
            @f = opravit_sloveso_byt($negprefix, '', $suffix, @f);
        }
        elsif($f[1] =~ m/^(ne)?cizolož(i|í)?$/i)
        {
            my $negprefix = lc($1);
            my $suffix = lc($2);
            my ($polarity, $p) = negprefix_to_polarity($negprefix);
            $f[2] = 'cizoložit';
            $f[9] = set_lemma1300($f[9], 'cizoložiti');
            $f[3] = 'VERB';
            if($suffix =~ m/^(i|í)$/)
            {
                $f[4] = "VB-S---3P-${p}A---";
                $f[5] = "Aspect=Imp|Mood=Ind|Number=Sing|Person=3|Polarity=$polarity|Tense=Pres|VerbForm=Fin|Voice=Act";
            }
            else
            {
                $f[4] = "Vi-S---2--${p}----";
                $f[5] = "Aspect=Imp|Mood=Imp|Number=Sing|Person=2|Polarity=$polarity|VerbForm=Fin";
            }
        }
        elsif($f[1] =~ m/^(u)činišta$/i)
        {
            my $prefix = lc($1);
            my $polarity = 'Pos';
            my $p = 'A';
            $f[2] = $prefix.'činit';
            $f[9] = set_lemma1300($f[9], $prefix.'činiti');
            $f[3] = 'VERB';
            $f[4] = "V--D---3A-${p}A---";
            # Neznáme lexikální vid, ale aoristový tvar je pravděpodobnější u dokonavých sloves.
            $f[5] = "Aspect=Perf|Mood=Ind|Number=Dual|Person=3|Polarity=$polarity|Tense=Past|Variant=Long|VerbForm=Fin|Voice=Act";
        }
        elsif($f[1] =~ m/(ne)?(po)(čna)$/i)
        {
            my $negprefix = lc($1);
            my $prefix = lc($2);
            my $suffix = lc($3);
            my ($polarity, $p) = negprefix_to_polarity($negprefix);
            $f[2] = $prefix.'čít';
            $f[9] = set_lemma1300($f[9], $prefix.'číti');
            $f[3] = 'VERB';
            $f[4] = "VeYS------${p}----";
            $f[5] = "Aspect=Perf|Gender=Masc|Number=Sing|Polarity=$polarity|Tense=Pres|VerbForm=Conv|Voice=Act";
        }
        elsif($f[1] =~ m/^(ne)?die$/i)
        {
            my $negprefix = lc($1);
            my ($polarity, $p) = negprefix_to_polarity($negprefix);
            $f[2] = 'dít';
            $f[9] = set_lemma1300($f[9], 'dieti');
            $f[3] = 'VERB';
            $f[4] = "VB-S---3P-${p}A---";
            $f[5] = "Aspect=Imp|Mood=Ind|Number=Sing|Person=3|Polarity=$polarity|Tense=Pres|VerbForm=Fin|Voice=Act";
        }
        elsif($f[1] =~ m/^hledaj(ě|íc)$/i)
        {
            my $suffix = lc($1);
            # Jeden výskyt "hledajíc" v Olomoucké bibli MATT_12.46.
            $f[2] = 'hledat';
            $f[9] = set_lemma1300($f[9], 'hledati');
            $f[3] = 'VERB';
            if($suffix eq 'ě')
            {
                $f[4] = "VeYS------A----";
                $f[5] = "Aspect=Imp|Gender=Masc|Number=Sing|Polarity=Pos|Tense=Pres|VerbForm=Conv|Voice=Act";
            }
            else
            {
                $f[4] = "VeXP------A----";
                $f[5] = "Aspect=Imp|Number=Plur|Polarity=Pos|Tense=Pres|VerbForm=Conv|Voice=Act";
            }
        }
        elsif($f[1] =~ m/^(ne)?(s)?hromazdí$/i)
        {
            my $negprefix = lc($1);
            my $prefix = lc($2);
            my ($polarity, $p) = negprefix_to_polarity($negprefix);
            my $aspect = $prefix ? 'Perf' : 'Imp';
            $f[2] = $prefix ? $prefix.'hromáždit' : 'hromadit';
            $f[9] = set_lemma1300($f[9], $prefix.'hromazditi');
            $f[3] = 'VERB';
            $f[4] = "VB-S---3P-${p}A---";
            $f[5] = "Aspect=$aspect|Mood=Ind|Number=Sing|Person=3|Polarity=$polarity|Tense=Pres|VerbForm=Fin|Voice=Act";
        }
        elsif($f[1] =~ m/^(ne)?(vy)chá(zie)$/i)
        {
            my $negprefix = lc($1);
            my $prefix = lc($2);
            my $suffix = lc($3);
            my ($polarity, $p) = negprefix_to_polarity($negprefix);
            my $aspect = 'Imp';
            $f[2] = 'vycházet';
            $f[9] = set_lemma1300($f[9], 'vycházěti');
            $f[3] = 'VERB';
            if($suffix eq 'zie')
            {
                $f[4] = "VB-S---3P-${p}A---";
                $f[5] = "Aspect=$aspect|Mood=Ind|Number=Sing|Person=3|Polarity=$polarity|Tense=Pres|VerbForm=Fin|Voice=Act";
            }
        }
        elsif($f[1] =~ m/^(ne)?(ze)?ch(ci|ceš|ce|csta|ceme?|cete|tie|tieše|tiechu|tějte|těl[aoi]?|tě|tiec[ie]?)$/i)
        {
            my $negprefix = lc($1);
            my $prefix = lc($2);
            my $suffix = lc($3);
            @f = opravit_sloveso_chtit($negprefix, $prefix, $suffix, @f);
        }
        elsif($f[1] =~ m/^(ne)?(do|o[dt]e?|po|pó|pro|př[eě]|př[eě]de|při|puo|roz|se?|ve?|vy|vz)?(jíti?|jdu|jdeš|jde|jdem[eť]?|jdete|jdú|jdieše|jdiešta|jdiechu|jide|jide[sš]ta|jid(echu|ú)|jdiž?|jděta|jděte|ď(me|my|ta|te)?|šel|šl[aoi]|jda|jdúc[ie]?|šed|šedš[ie]?|diž|příd[ueúa])$/i)
        {
            my $negprefix = lc($1);
            my $prefix = lc($2);
            my $suffix = lc($3);
            if($prefix eq '' && $suffix =~ s/^příd/jd/)
            {
                $prefix = 'při';
            }
            @f = opravit_sloveso_jit($negprefix, $prefix, $suffix, @f);
        }
        # Přeskočit "jě" bez předpony, to je obvykle spíš zájmeno, ale Staročeši hlásí, že v BiblDr 12.22, 17.17 a v BiblOl 2.4 je to aorist.
        # Jednou se dokonce aorist od "jmout" vyskytl jako "je" (Dr. 9.33: "A když vyhna z něho běsa, je sě mluviti němý." – buď je to chyba přepisu, nebo jde o počátek ztráty jať ve staré češtině).
        # S předponou, třeba "pojě", to je aorist.
        # Aorist "jěchu": "jíst" je to v MATT 14.20 a 15.37 (Dr. i Ol.), zatímco ve 26.67 (Dr.) a 26.50 (Ol.) je to "jmout" / "jieti".
        # Výjimky musíme otestovat dříve než hlavní regulární výraz, aby nám nepřepsaly obsah magických proměnných $1, $2, $3.
        elsif(!($f[1] =~ m/^jě$/i && get_ref($f[9]) !~ m/^MATT_(?:12\.22|17\.17|2\.4)$/ ||
                $f[1] =~ m/^je$/i && get_ref($f[9]) !~ m/^MATT_9\.33$/ ||
                $f[1] =~ m/^jěchu$/i && get_ref($f[9]) !~ m/^MATT_26\.(?:50|67)$/) &&
              $f[1] =~ m/^(ne)?(do|na|o[dt]e?|po|př[eě]|při|se?|u|vy)?(jieti?|jmu|jmeš|jme|jmem[eť]?|jmete|jmú|j[ěe]|jěchu|jmi|jmětež?|jal[aoi]?|jem|jemš[ie]?)$/i)
        {
            my $negprefix = lc($1);
            my $prefix = lc($2);
            my $suffix = lc($3);
            @f = opravit_sloveso_jmout($negprefix, $prefix, $suffix, @f);
        }
        elsif($f[1] =~ m/^(ne)?(krst|křst|křt)(íti|ím|iechu|il|iece|iv)$/i)
        {
            my $negprefix = lc($1);
            my $stem = lc($2);
            my $suffix = lc($3);
            my ($polarity, $p) = negprefix_to_polarity($negprefix);
            my $aspect = 'Imp';
            $f[2] = 'křtít';
            $f[9] = set_lemma1300($f[9], 'křstíti');
            $f[3] = 'VERB';
            if($suffix eq 'íti')
            {
                $f[4] = "Vf--------${p}----";
                $f[5] = "Aspect=$aspect|Polarity=$polarity|VerbForm=Inf";
            }
            elsif($suffix eq 'ím')
            {
                $f[4] = "VB-S---1P-${p}A---";
                $f[5] = "Aspect=$aspect|Mood=Ind|Number=Sing|Person=1|Polarity=$polarity|Tense=Pres|VerbForm=Fin|Voice=Act";
            }
            elsif($suffix eq 'iechu')
            {
                $f[4] = "V--P---3I-${p}A---";
                $f[5] = "Aspect=$aspect|Mood=Ind|Number=Plur|Person=3|Polarity=$polarity|Tense=Imp|VerbForm=Fin|Voice=Act";
            }
            elsif($suffix eq 'il')
            {
                $f[4] = "VpYS---XR-${p}A---";
                $f[5] = "Aspect=$aspect|Gender=Masc|Number=Sing|Polarity=$polarity|Tense=Past|VerbForm=Part|Voice=Act";
            }
            elsif($suffix eq 'iece')
            {
                $f[4] = "VeXP------${p}----";
                $f[5] = "Aspect=$aspect|Number=Plur|Polarity=$polarity|Tense=Pres|VerbForm=Conv|Voice=Act";
            }
            elsif($suffix eq 'iv')
            {
                $f[4] = "VmYS------${p}----";
                $f[5] = "Aspect=$aspect|Gender=Masc|Number=Sing|Polarity=$polarity|Tense=Past|VerbForm=Conv|Voice=Act";
            }
        }
        elsif($f[1] =~ m/^pokúšěj([eě]|íce?)$/i)
        {
            my $suffix = lc($1);
            $f[2] = 'pokoušet';
            $f[9] = set_lemma1300($f[9], 'pokúšěti');
            $f[3] = 'VERB';
            if($suffix =~ m/^[eě]$/)
            {
                $f[4] = "VeYS------A----";
                $f[5] = "Aspect=Imp|Gender=Masc|Number=Sing|Polarity=Pos|Tense=Pres|VerbForm=Conv|Voice=Act";
            }
            else
            {
                $f[4] = "VeXP------A----";
                $f[5] = "Aspect=Imp|Number=Plur|Polarity=Pos|Tense=Pres|VerbForm=Conv|Voice=Act";
            }
        }
        elsif($f[1] =~ m/^(ne)?nalezú$/i)
        {
            my $negprefix = lc($1);
            my ($polarity, $p) = negprefix_to_polarity($negprefix);
            $f[2] = 'nalézt';
            $f[9] = set_lemma1300($f[9], 'nalézti');
            $f[3] = 'VERB';
            $f[4] = "VB-P---3P-${p}A---";
            $f[5] = "Aspect=Perf|Mood=Ind|Number=Plur|Person=3|Polarity=$polarity|Tense=Pres|VerbForm=Fin|Voice=Act";
        }
        elsif($f[1] =~ m/^(ne)?(vy)?lup$/i)
        {
            my $negprefix = lc($1);
            my $prefix = lc($2);
            my ($polarity, $p) = negprefix_to_polarity($negprefix);
            my $aspect = $prefix ? 'Perf' : 'Imp';
            $f[2] = 'vyloupnout';
            $f[9] = set_lemma1300($f[9], 'vylúpiti');
            $f[3] = 'VERB';
            $f[4] = "Vi-S---2--${p}----";
            $f[5] = "Aspect=$aspect|Mood=Imp|Number=Sing|Person=2|Polarity=$polarity|VerbForm=Fin";
        }
        elsif($f[1] =~ m/^(ne)?j?m(ieti|ám|áš|á|áme|áte|ají|ějieše|ějiešta|ě(jie)?chu|ěj|ějte|ěl[aoi]?|aj[eě]|ajíci|ajíce?|ajíciemu)$/i)
        {
            my $negprefix = lc($1);
            my $suffix = lc($2);
            @f = opravit_sloveso_mit($negprefix, $suffix, @f);
        }
        # V Drážďanské bibli 13.13 je to prézens, ten zpracujeme zde.
        # Ostatní výskyty jsou aoristy, ty zpracujeme níže.
        elsif($f[1] =~ m/^mluvi$/i && get_ref($f[9]) eq 'MATT_13.13')
        {
            $f[2] = 'mluvit';
            $f[9] = set_lemma1300($f[9], 'mluviti');
            $f[3] = 'VERB';
            $f[4] = 'VB-S---1P-AA---';
            $f[5] = 'Aspect=Imp|Mood=Ind|Number=Sing|Person=1|Polarity=Pos|Tense=Pres|VerbForm=Fin|Voice=Act';
        }
        elsif($f[1] =~ m/^(ne)?(po)?(m(ó|uo)ž(e|eš|em[ey]|ete)?|mohu|mohú)$/i)
        {
            my $negprefix = lc($1);
            my $prefix = lc($2);
            my $suffix = lc($3);
            my ($polarity, $p) = negprefix_to_polarity($negprefix);
            my $aspect = $prefix ? 'Perf' : 'Imp';
            $f[2] = $prefix.'moci';
            $f[9] = set_lemma1300($f[9], $f[2]);
            $f[3] = 'VERB';
            if($suffix eq 'mohu')
            {
                $f[4] = "VB-S---1P-${p}A---";
                $f[5] = "Aspect=$aspect|Mood=Ind|Number=Sing|Person=1|Polarity=$polarity|Tense=Pres|VerbForm=Fin|Voice=Act";
            }
            elsif($suffix eq 'mohú')
            {
                $f[4] = "VB-P---3P-${p}A---";
                $f[5] = "Aspect=$aspect|Mood=Ind|Number=Plur|Person=3|Polarity=$polarity|Tense=Pres|VerbForm=Fin|Voice=Act";
            }
            elsif($suffix =~ m/š$/)
            {
                $f[4] = "VB-S---2P-${p}A---";
                $f[5] = "Aspect=$aspect|Mood=Ind|Number=Sing|Person=2|Polarity=$polarity|Tense=Pres|VerbForm=Fin|Voice=Act";
            }
            elsif($suffix =~ m/em[ey]$/)
            {
                $f[4] = "VB-P---1P-${p}A---";
                $f[5] = "Aspect=$aspect|Mood=Ind|Number=Plur|Person=1|Polarity=$polarity|Tense=Pres|VerbForm=Fin|Voice=Act";
            }
            elsif($suffix =~ m/ete$/)
            {
                $f[4] = "VB-P---2P-${p}A---";
                $f[5] = "Aspect=$aspect|Mood=Ind|Number=Plur|Person=2|Polarity=$polarity|Tense=Pres|VerbForm=Fin|Voice=Act";
            }
            else
            {
                $f[4] = "VB-S---3P-${p}A---";
                $f[5] = "Aspect=$aspect|Mood=Ind|Number=Sing|Person=3|Polarity=$polarity|Tense=Pres|VerbForm=Fin|Voice=Act";
            }
        }
        elsif($f[1] =~ m/^neumyjíce?$/i)
        {
            $f[2] = 'umýt';
            $f[9] = set_lemma1300($f[9], 'umyti');
            $f[3] = 'VERB';
            $f[4] = "VeXP------N----";
            $f[5] = "Aspect=Perf|Number=Plur|Polarity=Neg|Tense=Pres|VerbForm=Conv|Voice=Act";
        }
        elsif($f[1] =~ m/^nalezneta$/i)
        {
            $f[2] = 'nalézt';
            $f[9] = set_lemma1300($f[9], 'nalézti');
            $f[3] = 'VERB';
            $f[4] = "VB-D---2P-AA---";
            $f[5] = "Aspect=Perf|Mood=Ind|Number=Dual|Person=2|Polarity=Pos|Tense=Pres|VerbForm=Fin|Voice=Act";
        }
        # Sloveso "neroditi" je sice negativní a bude mít Polarity=Neg, ale jeho lemma je "nerodit" a kladný tvar neexistuje.
        # Od slovesa "rodit" se liší významem i valencí, odpovídá spíš slovesu "neráčit".
        # Sloveso "rodit" se ovšem v našich datech nevyskytuje, takže záměna nehrozí (jsou tam pouze odvozená "narodit", "porodit", "urodit" a "zarodit"(?)).
        elsif($f[1] =~ m/^(ne)ro(die|di|ď|ďte|dil|dieci)$/i)
        {
            my $negprefix = lc($1);
            my $suffix = lc($2);
            @f = opravit_sloveso_nerodit($negprefix, '', $suffix, @f);
        }
        elsif($f[1] =~ m/^nesúc$/i) # neplést se záporným přechodníkem od být
        {
            $f[2] = 'nést';
            $f[9] = set_lemma1300($f[9], 'nésti');
            $f[3] = 'VERB';
            $f[4] = 'VeFS------A----';
            $f[5] = 'Aspect=Imp|Gender=Fem|Number=Sing|Polarity=Pos|Tense=Pres|VerbForm=Conv|Voice=Act';
        }
        elsif($f[1] =~ m/^(při)?nuz(í)$/i)
        {
            my $prefix = lc($1);
            my $suffix = lc($2);
            my $aspect = 'Perf';
            $f[2] = $prefix.'nuzit';
            $f[9] = set_lemma1300($f[9], $prefix.'nuziti');
            $f[3] = 'VERB';
            $f[4] = "VB-S---3P-AA---";
            $f[5] = "Aspect=$aspect|Mood=Ind|Number=Sing|Person=3|Polarity=Pos|Tense=Pres|VerbForm=Fin|Voice=Act";
        }
        elsif($f[1] =~ m/^upadáta$/i)
        {
            $f[2] = 'upadat';
            $f[9] = set_lemma1300($f[9], 'upadati');
            $f[3] = 'VERB';
            $f[4] = "VB-D---3P-AA---";
            $f[5] = "Aspect=Imp|Mood=Ind|Number=Dual|Person=3|Polarity=Pos|Tense=Pres|VerbForm=Fin|Voice=Act";
        }
        elsif($f[1] =~ m/^(u)?padn(eta|a)$/i)
        {
            my $prefix = lc($1);
            my $suffix = lc($2);
            my $aspect = 'Perf';
            $f[2] = $prefix.'padnout';
            $f[9] = set_lemma1300($f[9], $prefix.'padnúti');
            $f[3] = 'VERB';
            if($suffix eq 'eta')
            {
                $f[4] = "VB-D---3P-AA---";
                $f[5] = "Aspect=$aspect|Mood=Ind|Number=Dual|Person=3|Polarity=Pos|Tense=Pres|VerbForm=Fin|Voice=Act";
            }
            elsif($suffix eq 'a')
            {
                $f[4] = "VeYS------A----";
                $f[5] = "Aspect=$aspect|Gender=Masc|Number=Sing|Polarity=Pos|Tense=Pres|VerbForm=Conv|Voice=Act";
            }
        }
        elsif($f[1] =~ m/^plačíci$/i)
        {
            $f[2] = 'plakat';
            $f[9] = set_lemma1300($f[9], 'plakati');
            $f[3] = 'VERB';
            $f[4] = 'VeFS------A----';
            $f[5] = 'Aspect=Imp|Gender=Fem|Number=Sing|Polarity=Pos|Tense=Pres|VerbForm=Conv|Voice=Act';
        }
        elsif($f[1] =~ m/^(ne)?(o[dt]|pro|před|vz)?pov(ěděti|iem|ieš|ie|iete|ědie|ědě|ědě[šs]ta|ěděchu|ěz|ězta|ěztež?|ěděl[aoi]?|ěda|ěděv|ěděvše|ěděn[aoi]?)$/i)
        {
            my $negprefix = lc($1);
            my $prefix = lc($2);
            my $suffix = lc($3);
            @f = opravit_sloveso_povedet($negprefix, $prefix, $suffix, @f);
        }
        elsif($f[1] =~ m/^(ne)?pravi$/i)
        {
            my $negprefix = lc($1);
            my ($polarity, $p) = negprefix_to_polarity($negprefix);
            $f[2] = 'pravit';
            $f[9] = set_lemma1300($f[9], 'praviti');
            $f[3] = 'VERB';
            $f[4] = "VB-S---1P-${p}A---";
            $f[5] = "Aspect=Imp|Mood=Ind|Number=Sing|Person=1|Polarity=$polarity|Tense=Pres|VerbForm=Fin|Voice=Act";
        }
        elsif($f[1] =~ m/^(ne)?pros(te|ě|ieci?)$/i)
        {
            my $negprefix = lc($1);
            my $suffix = lc($2);
            my ($polarity, $p) = negprefix_to_polarity($negprefix);
            $f[2] = 'prosit';
            $f[9] = set_lemma1300($f[9], 'prositi');
            $f[3] = 'VERB';
            if($suffix eq 'te')
            {
                $f[4] = "Vi-P---2--${p}----";
                $f[5] = "Aspect=Imp|Mood=Imp|Number=Plur|Person=2|Polarity=$polarity|VerbForm=Fin";
            }
            elsif($suffix eq 'ě')
            {
                $f[4] = "VeYS------${p}----";
                $f[5] = "Aspect=Imp|Gender=Masc|Number=Sing|Polarity=$polarity|Tense=Pres|VerbForm=Conv|Voice=Act";
            }
            else
            {
                $f[4] = "VeFS------${p}----";
                $f[5] = "Aspect=Imp|Gender=Fem|Number=Sing|Polarity=$polarity|Tense=Pres|VerbForm=Conv|Voice=Act";
            }
        }
        elsif($f[1] =~ m/^o[dt](puš(tě|če)n[oiy]?)$/i)
        {
            my $suffix = lc($1);
            $f[2] = 'odpuštěný'; # je to příčestí trpné, takže ho zařadíme pod adjektiva, takže bude mít adjektivní lemma
            $f[9] = set_lemma1300($f[9], 'otpuštěný');
            $f[3] = 'ADJ';
            if($suffix =~ m/o$/)
            {
                $f[4] = "VsNS---XX-AP---";
                $f[5] = "Aspect=Perf|Gender=Neut|Number=Sing|Polarity=Pos|Variant=Short|VerbForm=Part|Voice=Pass";
            }
            elsif($suffix =~ m/i$/)
            {
                $f[4] = "VsMP---XX-AP---";
                $f[5] = "Animacy=Anim|Aspect=Perf|Gender=Masc|Number=Plur|Polarity=Pos|Variant=Short|VerbForm=Part|Voice=Pass";
            }
            elsif($suffix =~ m/y$/)
            {
                # Mohl by to být i ženský rod, ale v našich datech je to mužský: "odpuštěnyť jsú tobě tvoji hřieši".
                $f[4] = "VsIP---XX-AP---";
                $f[5] = "Animacy=Inan|Aspect=Perf|Gender=Masc|Number=Plur|Polarity=Pos|Variant=Short|VerbForm=Part|Voice=Pass";
            }
            else # odpuštěn
            {
                $f[4] = "VsYS---XX-AP---";
                $f[5] = "Aspect=Perf|Gender=Masc|Number=Sing|Polarity=Pos|Variant=Short|VerbForm=Part|Voice=Pass";
            }
        }
        elsif($f[1] =~ m/^(ne)?ř(éci|ku|kú|ečechu|ci|cětež?|ekl[aoi]?|ka|kúc[ie]?|ekše|ečen[aoi]?)$/i)
        {
            my $negprefix = lc($1);
            my $suffix = lc($2);
            @f = opravit_sloveso_rici($negprefix, '', $suffix, @f);
        }
        elsif($f[1] =~ m/^(ne)?(při)sáhaj$/i)
        {
            my $negprefix = lc($1);
            my $prefix = lc($2);
            my ($polarity, $p) = negprefix_to_polarity($negprefix);
            my $aspect = 'Imp';
            $f[2] = 'přísahat';
            $f[9] = set_lemma1300($f[9], 'přisáhati');
            $f[3] = 'VERB';
            $f[4] = "Vi-S---2--${p}----";
            $f[5] = "Aspect=$aspect|Mood=Imp|Number=Sing|Person=2|Polarity=$polarity|VerbForm=Fin";
        }
        # MA ze Staročeské banky sice nabízí analýzu s hyperlemmatem "poskytnúti", ale pouze jako aorist (2. nebo 3. osoba singuláru).
        # V daném kontextu (Dr 7.9 a 7.10) ale očekáváme přítomně-budoucí tvar. Snad proto JP navrhl lemma "poskýsti", což zřejmě bude
        # sloveso podobného významu, ale z jiné třídy.
        elsif($f[1] =~ m/^(ne)?(po)(skyte|skyť)$/i)
        {
            my $negprefix = lc($1);
            my $prefix = lc($2);
            my $suffix = lc($3);
            my ($polarity, $p) = negprefix_to_polarity($negprefix);
            my $aspect = 'Perf';
            $f[2] = $prefix.'skytnout';
            $f[9] = set_lemma1300($f[9], $prefix.'skýsti');
            $f[3] = 'VERB';
            if($suffix eq 'skyte')
            {
                $f[4] = "VB-S---3P-${p}A---";
                $f[5] = "Aspect=$aspect|Mood=Ind|Number=Sing|Person=3|Polarity=$polarity|Tense=Pres|VerbForm=Fin|Voice=Act";
            }
            else
            {
                $f[4] = "Vi-S---2--${p}----";
                $f[5] = "Aspect=$aspect|Mood=Imp|Number=Sing|Person=2|Polarity=$polarity|VerbForm=Fin";
            }
        }
        elsif($f[1] =~ m/^(ne)?(slóvt?e)$/i)
        {
            my $negprefix = lc($1);
            my $suffix = lc($2);
            my ($polarity, $p) = negprefix_to_polarity($negprefix);
            $f[2] = 'slout';
            $f[9] = set_lemma1300($f[9], 'slúti');
            $f[3] = 'VERB';
            if($suffix eq 'slóvte')
            {
                $f[4] = "Vi-P---2--${p}----";
                $f[5] = "Aspect=Imp|Mood=Imp|Number=Plur|Person=2|Polarity=$polarity|VerbForm=Fin";
            }
            else
            {
                $f[4] = "VB-S---3P-${p}A---";
                $f[5] = "Aspect=Imp|Mood=Ind|Number=Sing|Person=3|Polarity=$polarity|Tense=Pres|VerbForm=Fin|Voice=Act";
            }
        }
        elsif($f[1] =~ m/^(ne)?sluš(ie|[aě]lo)$/i)
        {
            my $negprefix = lc($1);
            my $suffix = lc($2);
            my ($polarity, $p) = negprefix_to_polarity($negprefix);
            my $aspect = 'Imp';
            $f[2] = 'slušet';
            $f[9] = set_lemma1300($f[9], 'slušěti');
            $f[3] = 'VERB';
            if($suffix eq 'ie')
            {
                $f[4] = "VB-S---3P-${p}A---";
                $f[5] = "Aspect=$aspect|Mood=Ind|Number=Sing|Person=3|Polarity=$polarity|Tense=Pres|VerbForm=Fin|Voice=Act";
            }
            elsif($suffix =~ m/^[aě]lo$/)
            {
                $f[4] = "VpNS---XR-${p}A---";
                $f[5] = "Aspect=$aspect|Gender=Neut|Number=Sing|Polarity=$polarity|Tense=Past|VerbForm=Part|Voice=Act";
            }
        }
        # Nepatří sem ale 'usta', což je obvykle tehdejší tvar pro dnešní 'ústa'.
        elsif($f[1] =~ m/^(ne)?(o|pov|př[eě]|v)(sta[lv]?)$/i)
        {
            my $negprefix = lc($1);
            my $prefix = lc($2);
            my $suffix = lc($3);
            my $prefix1300 = $prefix;
            $prefix =~ s/^přě/pře/;
            $prefix1300 =~ s/^pře/přě/;
            my ($polarity, $p) = negprefix_to_polarity($negprefix);
            $f[2] = $prefix eq 'v' ? 'vstát' : $prefix.'stat';
            $f[9] = set_lemma1300($f[9], $prefix eq 'v' ? 'vstáti' : $prefix1300.'stati');
            $f[3] = 'VERB';
            if($suffix eq 'stal')
            {
                $f[4] = "VpYS---XR-${p}A---";
                $f[5] = "Aspect=Perf|Gender=Masc|Number=Sing|Polarity=$polarity|Tense=Past|VerbForm=Part|Voice=Act";
            }
            elsif($suffix eq 'stav')
            {
                $f[4] = "VmYS------${p}----";
                $f[5] = "Aspect=Perf|Gender=Masc|Number=Sing|Polarity=$polarity|Tense=Past|VerbForm=Conv|Voice=Act";
            }
            else
            {
                $f[4] = "V--S---3A-${p}A---";
                $f[5] = "Aspect=Perf|Mood=Ind|Number=Sing|Person=3|Polarity=$polarity|Tense=Past|Variant=Long|VerbForm=Fin|Voice=Act";
            }
        }
        elsif($f[1] =~ m/^(ne)?(střie)ci$/i)
        {
            my $negprefix = lc($1);
            my $suffix = lc($2);
            my ($polarity, $p) = negprefix_to_polarity($negprefix);
            my $lemma1300 = 'střieci';
            # Pavel Kosek našel, že "stříci" se vyskytuje i v novodobých slovnících (SSJČ?) Pozor, u jiných tvarů mám možná lemma "střežit", ale tam je námitka, že už to patří do jiné třídy.
            $f[2] = lemma_1300_to_2022($lemma1300);
            $f[9] = set_lemma1300($f[9], $lemma1300);
            $f[3] = 'VERB';
            $f[4] = "Vf--------${p}----";
            $f[5] = "Aspect=Imp|Polarity=$polarity|VerbForm=Inf";
        }
        elsif($f[1] =~ m/^(ne)?(o)?(svěť)$/i)
        {
            my $negprefix = lc($1);
            my $prefix = lc($2);
            my $suffix = lc($3);
            my ($polarity, $p) = negprefix_to_polarity($negprefix);
            my $aspect = $prefix ? 'Perf' : 'Imp';
            my $lemma1300 = $prefix.'svietiti';
            $f[2] = lemma_1300_to_2022($lemma1300);
            $f[9] = set_lemma1300($f[9], $lemma1300);
            $f[3] = 'VERB';
            # V 5.16 jde o imperativ pro 3. osobu: "svěť světlost vašě přěd lidmi".
            $f[4] = "Vi-S---3--${p}----";
            $f[5] = "Aspect=$aspect|Mood=Imp|Number=Sing|Person=3|Polarity=$polarity|VerbForm=Fin";
        }
        elsif($f[1] =~ m/^(ne)?tiež(i|eš)$/i)
        {
            my $negprefix = lc($1);
            my $suffix = lc($2);
            my ($polarity, $p) = negprefix_to_polarity($negprefix);
            $f[2] = 'tázat';
            $f[9] = set_lemma1300($f[9], 'tázati');
            $f[3] = 'VERB';
            if($suffix eq 'i')
            {
                $f[4] = "VB-S---1P-${p}A---";
                $f[5] = "Aspect=Imp|Mood=Ind|Number=Sing|Person=1|Polarity=$polarity|Tense=Pres|VerbForm=Fin|Voice=Act";
            }
            else
            {
                $f[4] = "VB-S---2P-${p}A---";
                $f[5] = "Aspect=Imp|Mood=Ind|Number=Sing|Person=2|Polarity=$polarity|Tense=Pres|VerbForm=Fin|Voice=Act";
            }
        }
        elsif($f[1] =~ m/(ne)?(u)(tna)$/i)
        {
            my $negprefix = lc($1);
            my $prefix = lc($2);
            my $suffix = lc($3);
            my ($polarity, $p) = negprefix_to_polarity($negprefix);
            $f[2] = $prefix.'tnout';
            $f[9] = set_lemma1300($f[9], $prefix.'tnúti');
            $f[3] = 'VERB';
            $f[4] = "VeYS------${p}----";
            $f[5] = "Aspect=Perf|Gender=Masc|Number=Sing|Polarity=$polarity|Tense=Pres|VerbForm=Conv|Voice=Act";
        }
        elsif($f[1] =~ m/^(ne)?vec[ěe](šta|chu)?$/i)
        {
            my $negprefix = lc($1);
            my $suffix = lc($2);
            @f = opravit_sloveso_vecet($negprefix, '', $suffix, @f);
        }
        elsif($f[1] =~ m/^věříta$/i)
        {
            $f[2] = 'věřit';
            $f[9] = set_lemma1300($f[9], 'věřiti');
            $f[3] = 'VERB';
            $f[4] = "VB-D---2P-AA---";
            $f[5] = "Aspect=Imp|Mood=Ind|Number=Dual|Person=2|Polarity=Pos|Tense=Pres|VerbForm=Fin|Voice=Act";
        }
        elsif($f[1] =~ m/^vid(a|úce?)$/i)
        {
            my $suffix = lc($1);
            $f[2] = 'vidět';
            $f[9] = set_lemma1300($f[9], 'viděti');
            $f[3] = 'VERB';
            if($suffix eq 'a')
            {
                $f[4] = "VeYS------A----";
                $f[5] = "Aspect=Imp|Gender=Masc|Number=Sing|Polarity=Pos|Tense=Pres|VerbForm=Conv|Voice=Act";
            }
            else
            {
                $f[4] = "VeXP------A----";
                $f[5] = "Aspect=Imp|Number=Plur|Polarity=Pos|Tense=Pres|VerbForm=Conv|Voice=Act";
            }
        }
        elsif($f[1] =~ m/^(ne)?(od)?vracij$/i)
        {
            my $negprefix = lc($1);
            my $prefix = lc($2);
            my ($polarity, $p) = negprefix_to_polarity($negprefix);
            my $aspect = 'Imp';
            $f[2] = $prefix.'vracet';
            $f[9] = set_lemma1300($f[9], $prefix.'vraciti');
            $f[3] = 'VERB';
            $f[4] = "Vi-S---2--${p}----";
            $f[5] = "Aspect=$aspect|Mood=Imp|Number=Sing|Person=2|Polarity=$polarity|VerbForm=Fin";
        }
        elsif($f[1] =~ m/^(ne)?(na)?vrať$/i)
        {
            my $negprefix = lc($1);
            my $prefix = lc($2);
            my ($polarity, $p) = negprefix_to_polarity($negprefix);
            my $aspect = 'Perf';
            $f[2] = $prefix.'vrátit';
            $f[9] = set_lemma1300($f[9], $prefix.'vrátiti');
            $f[3] = 'VERB';
            $f[4] = "Vi-S---2--${p}----";
            $f[5] = "Aspect=$aspect|Mood=Imp|Number=Sing|Person=2|Polarity=$polarity|VerbForm=Fin";
        }
        elsif($f[1] =~ m/^(ne)?vrz(iž)?$/i)
        {
            my $negprefix = lc($1);
            my $suffix = lc($2);
            my ($polarity, $p) = negprefix_to_polarity($negprefix);
            $f[2] = 'vrhnout';
            $f[9] = set_lemma1300($f[9], 'vrhnúti');
            $f[3] = 'VERB';
            $f[4] = "Vi-S---2--${p}----";
            $f[5] = "Aspect=Perf|Mood=Imp|Number=Sing|Person=2|Polarity=$polarity|VerbForm=Fin";
        }
        elsif($f[1] =~ m/^povolíta$/i)
        {
            $f[2] = 'povolit';
            $f[9] = set_lemma1300($f[9], 'povoliti');
            $f[3] = 'VERB';
            $f[4] = "VB-D---2P-AA---";
            $f[5] = "Aspect=Perf|Mood=Ind|Number=Dual|Person=2|Polarity=Pos|Tense=Pres|VerbForm=Fin|Voice=Act";
        }
        elsif($f[1] =~ m/(ne)?(ote|při|za)(vr[uúa])$/i)
        {
            my $negprefix = lc($1);
            my $prefix = lc($2);
            my $suffix = lc($3);
            my ($polarity, $p) = negprefix_to_polarity($negprefix);
            $f[2] = $prefix.'vřít';
            $f[9] = set_lemma1300($f[9], $prefix.'vříti');
            $f[3] = 'VERB';
            if($suffix eq 'vru')
            {
                $f[4] = "VB-S---1P-${p}A---";
                $f[5] = "Aspect=Perf|Mood=Ind|Number=Sing|Person=1|Polarity=$polarity|Tense=Pres|VerbForm=Fin|Voice=Act";
            }
            elsif($suffix eq 'vrú')
            {
                $f[4] = "VB-P---3P-${p}A---";
                $f[5] = "Aspect=Perf|Mood=Ind|Number=Plur|Person=3|Polarity=$polarity|Tense=Pres|VerbForm=Fin|Voice=Act";
            }
            elsif($suffix eq 'vra')
            {
                $f[4] = "VeYS------${p}----";
                $f[5] = "Aspect=Perf|Gender=Masc|Number=Sing|Polarity=$polarity|Tense=Pres|VerbForm=Conv|Voice=Act";
            }
        }
        elsif($f[1] =~ m/^vezma$/i)
        {
            my $suffix = lc($1);
            $f[2] = 'vzít';
            $f[9] = set_lemma1300($f[9], 'vzieti');
            $f[3] = 'VERB';
            $f[4] = "VeYS------A----";
            $f[5] = "Aspect=Perf|Gender=Masc|Number=Sing|Polarity=Pos|Tense=Pres|VerbForm=Conv|Voice=Act";
        }
        elsif($f[1] =~ m/^(ne)?(pro|u|ve|vze)?zř(í|íme|íte|ie|ě|ěsta|[eě]chu|ěte|ěl|ěv|ěvše)$/i)
        {
            my $negprefix = lc($1);
            my $prefix = lc($2);
            my $suffix = lc($3);
            @f = opravit_sloveso_zrit($negprefix, $prefix, $suffix, @f);
        }
        elsif($f[1] =~ m/^(ne)?se[jž]že$/i)
        {
            my $negprefix = lc($1);
            my ($polarity, $p) = negprefix_to_polarity($negprefix);
            my $aspect = 'Perf';
            $f[2] = 'sežehnout';
            $f[9] = set_lemma1300($f[9], 'sežéci');
            $f[3] = 'VERB';
            $f[4] = "VB-S---3P-${p}A---";
            $f[5] = "Aspect=$aspect|Mood=Ind|Number=Sing|Person=3|Polarity=$polarity|Tense=Pres|VerbForm=Fin|Voice=Act";
        }
        elsif($f[1] =~ m/^zažhúce?$/i)
        {
            $f[2] = 'zažehnout';
            $f[9] = set_lemma1300($f[9], 'zažéci');
            $f[3] = 'VERB';
            $f[4] = "VeXP------A----";
            $f[5] = "Aspect=Perf|Number=Plur|Polarity=Pos|Tense=Pres|VerbForm=Conv|Voice=Act";
        }
        elsif($f[1] =~ m/^zdvihnúc$/i)
        {
            $f[2] = 'zdvihnout';
            $f[9] = set_lemma1300($f[9], 'zdvihnúti');
            $f[3] = 'VERB';
            $f[4] = "VeFS------A----";
            $f[5] = "Aspect=Perf|Gender=Fem|Number=Sing|Polarity=Pos|Tense=Pres|VerbForm=Conv|Voice=Act";
        }
        #----------------------------------------------------------------------
        # Konec jednotlivých sloves. Začátek šablon podle zakončení.
        #----------------------------------------------------------------------
        # -ti: infinitiv
        # Infinitiv "zapřieti" = "zapřít" sice existuje, ale v našich datech jde o aorist od "zapřietiti" = "pohrozit", viz níže.
        elsif($f[1] =~ m/^(ne)?(bá|bdie|bí|bičova|brá|bráni|čini|dá|dáva|domnie|držě|hnú|jies|káza|kláně|klás|klé|krstí|křtí|kúpi|lá|mie|milova|minú|mluvi|mnie|modli|muči|múti|mysli|naléz|nazýva|nenávidě|nés|nosi|obiha|očišči|odpiera|odpúščě|opúšče|opúště|otkodlúči|otúpště|pada|pí|plni|plú|plva|pobra|pohřé|pojies|pokúšě|polapi|popadnú|posla|poslúcha|posti|posuzova|pozdravova|propusti|prosi|přídržě|přisáha|pusti|púščě|púště|radova|rosieva|rozpušči|rovna|ruos|řieka|sedě|shromazdi|sies|skmie|skrý|slibova|slú|slúži|slyšě|snúbi|soli|stá|stí|stkvie|súdi|sváři|tápa|táza|tknú|tonú|treskta|trpě|trúbi|tupi|uči|ukazova|ukřižova|umřie|úpi|uslyšě|vědě|věři|vidě|vlás|vola|vsies|vstá|vymína|vzchodi|vzie|vzkřiesi|vzýva|zabi|zahrnú|zbí|zjěvi|zná|zoba|zvá|zvěstova|žalosti|ženi)ti$/i)
        {
            my $negprefix = lc($1);
            my $suffix = lc($2);
            my $aspect = $suffix =~ m/^(dá|hnú|minú|naléz|očisti|očišči|otkodlúči|pobra|pohřé|pojies|polapi|popadnú|posla|propusti|přídržě|pusti|rozpušči|shromazdi|sies|skrý|stí|tknú|ukřižova|umřie|uslyšě|vsies|vstá|vzchodi|vzie|vzkřiesi|zabi|zahrnú|zapřie|zbí|zjěvi)$/ ? 'Perf' : 'Imp';
            my ($polarity, $p) = negprefix_to_polarity($negprefix);
            my $lemma1300 = $suffix.'ti';
            $f[2] = lemma_1300_to_2022($lemma1300);
            $f[9] = set_lemma1300($f[9], $lemma1300);
            $f[3] = 'VERB';
            $f[4] = "Vf--------${p}----";
            $f[5] = "Aspect=$aspect|Polarity=$polarity|VerbForm=Inf";
        }
        # -ím: prézens 1. osoby jednotného čísla
        elsif($f[1] =~ m/^(ne)?(na|o[dt]|po|pro|u|v|vy|vz|z|za)?(deř|horš|hřb|klid|klon|krst|křt|líb|lož|mluv|modl|práv|př|pust|púz|rad|síl|stanov|stav|vrát|zdrav)(ím|iem)$/)
        {
            my $negprefix = lc($1);
            my $prefix = lc($2);
            my $stem = lc($3);
            my $suffix = lc($4);
            my ($polarity, $p) = negprefix_to_polarity($negprefix);
            my $aspect = $prefix || $stem =~ m/^(pust|stanov|vrát)$/ ? 'Perf' : 'Imp';
            my $lemma1300 = $prefix.$stem.'iti';
            $lemma1300 =~ s/(krst|křt)iti$/křtíti/;
            $lemma1300 =~ s/^vypúziti$/vypúzěti/;
            $lemma1300 =~ s/^zapřiti$/zapříti/;
            $f[2] = lemma_1300_to_2022($lemma1300);
            $f[9] = set_lemma1300($f[9], $lemma1300);
            $f[3] = 'VERB';
            $f[4] = "VB-S---1P-${p}A---";
            $f[5] = "Aspect=$aspect|Mood=Ind|Number=Sing|Person=1|Polarity=$polarity|Tense=Pres|VerbForm=Fin|Voice=Act";
        }
        # -ie: prézens 3. osoby množného čísla
        elsif($f[1] =~ m/^(ne)?(ob|u)?(čin|drž|nenávid|protiv|těš|trp|žalost)ie$/i)
        {
            my $negprefix = lc($1);
            my $prefix = lc($2);
            my $stem = lc($3);
            my ($polarity, $p) = negprefix_to_polarity($negprefix);
            my $aspect = $prefix ? 'Perf' : 'Imp';
            my $lemma1300 = $prefix.$stem.'iti';
            $lemma1300 =~ s/držiti$/držěti/;
            $lemma1300 =~ s/^nenáviditi$/nenáviděti/;
            $lemma1300 =~ s/trpiti$/trpěti/;
            $f[2] = lemma_1300_to_2022($lemma1300);
            $f[9] = set_lemma1300($f[9], $lemma1300);
            $f[3] = 'VERB';
            $f[4] = "VB-P---3P-${p}A---";
            $f[5] = "Aspect=$aspect|Mood=Ind|Number=Plur|Person=3|Polarity=$polarity|Tense=Pres|VerbForm=Fin|Voice=Act";
        }
        # -jí: prézens 3. osoby množného čísla
        elsif($f[1] =~ m/^(ne)?(lka)jí$/i)
        {
            my $negprefix = lc($1);
            my $prefix = '';
            my $stem = lc($2);
            my ($polarity, $p) = negprefix_to_polarity($negprefix);
            my $aspect = $prefix ? 'Perf' : 'Imp';
            my $lemma1300 = $prefix.$stem.'ti';
            $lemma1300 =~ s/^lkati$/lkáti/;
            $f[2] = lemma_1300_to_2022($lemma1300);
            $f[9] = set_lemma1300($f[9], $lemma1300);
            $f[3] = 'VERB';
            $f[4] = "VB-P---3P-${p}A---";
            $f[5] = "Aspect=$aspect|Mood=Ind|Number=Plur|Person=3|Polarity=$polarity|Tense=Pres|VerbForm=Fin|Voice=Act";
        }
        # -a: sigmatický aorist 3. osoby jednotného čísla
        elsif($f[1] =~ m/^(ne)?(do|o|po|pro|přě|při|roze?|u|vz|za)?(bra|da|hněva|káza|kona|láma|následova|necha|pada|slitova|smilova|táza|tka|treskta|vola|získa|zna|zpieva|zva|žehna)$/i)
        {
            my $negprefix = lc($1);
            my $prefix = lc($2);
            my $suffix = lc($3);
            my $lform = $prefix.$suffix;
            $lform =~ s/^bra$/brá/;
            $lform =~ s/^da$/dá/;
            $lform =~ s/pada$/padnú/;
            my ($polarity, $p) = negprefix_to_polarity($negprefix);
            $f[2] = lemma_1300_to_2022($lform.'t');
            $f[2] =~ s/přě/pře/;
            $f[2] =~ s/tresktat/trestat/;
            $f[2] =~ s/zpievat/zpívat/;
            $f[9] = set_lemma1300($f[9], $lform.'ti');
            $f[3] = 'VERB';
            my $aspect = $f[2] =~ m/^(brát|kázat|následovat|trestat)$/ ? 'Imp' : 'Perf';
            $f[4] = "V--S---3A-${p}A---";
            $f[5] = "Aspect=$aspect|Mood=Ind|Number=Sing|Person=3|Polarity=$polarity|Tense=Past|Variant=Long|VerbForm=Fin|Voice=Act";
        }
        # -e, -ě, -i: aorist 3. osoby jednotného čísla
        # Tvar "mluvi" se také vyskytl jako prézens v Dr 13.13, ale to jsme zachytili nahoře.
        # Sloveso "zapřietiti" znamená "pohrozit" (od "přietiti" = "hrozit"), viz https://vokabular.ujc.cas.cz/hledani.aspx?hw=zap%C5%99ietiti
        elsif($f[1] =~ m/^(ne)?(do|na|o|od|po|pro|při|s|u|v|vy|vz|ze?|za)?(běsi|blíži|broji|čě|čini|divi|dviže|chýli|jěvi|kážě|kloni|kusi|leze|líbi|loži|měni|mluvi|modli|mřě|múti|pade|plni|prosi|přě|přieti|pusti|sěde|sla|slyšě|stavi|stúpi|tče|zdravi|zdravujě)$/i && $f[1] !~ m/^(loži|otče|plni)$/i)
        {
            my $negprefix = lc($1);
            my $prefix = lc($2);
            my $lform = $prefix.lc($3);
            $lform =~ s/^dotče/dotknú/;
            $lform =~ s/^kážě/káza/;
            $lform =~ s/^naleze/naléz/;
            $lform =~ s/^(po)?pade/${1}padnú/;
            $lform =~ s/^počě/počí/;
            $lform =~ s/^učě/uči/;
            $lform =~ s/^uzdravujě/uzdravova/;
            $lform =~ s/^(v)?sěde/${1}sědnú/;
            $lform =~ s/^vzdviže/vzdvihnú/;
            $lform =~ s/^zapřě/zapřie/;
            $lform =~ s/mřě/mří/;
            my ($polarity, $p) = negprefix_to_polarity($negprefix);
            $f[2] = lemma_1300_to_2022($lform.'t');
            $f[9] = set_lemma1300($f[9], $lform.'ti');
            $f[3] = 'VERB';
            my $aspect = $prefix && $f[2] ne 'učit' ? 'Perf' : 'Imp';
            my $variant = $f[2] =~ m/^(dotknout|nalézt|(po)?padnout|(v)?sednout|vzdvihnout)$/ ? 'Short' : 'Long';
            $f[4] = "V--S---3A-${p}A---";
            $f[5] = "Aspect=$aspect|Mood=Ind|Number=Sing|Person=3|Polarity=$polarity|Tense=Past|Variant=$variant|VerbForm=Fin|Voice=Act";
        }
        # -še: imperfekt 3. osoby jednotného čísla
        elsif($f[1] =~ m/^(ne)?.+(ieše|áše|léše)$/i && $f[1] !~ m/^Eliáše|Izaiáše$/i)
        {
            my $negprefix = lc($1);
            my $found = try_ma_from_misc(\@f, {'UPOS' => 'VERB', 'VerbForm' => 'Fin', 'Tense' => 'Imp', 'Person' => '3'});
            if(!$found)
            {
                my ($polarity, $p) = negprefix_to_polarity($negprefix);
                if(exists($lemmata{lc($f[1])}))
                {
                    $f[2] = $lemmata{lc($f[1])}[0];
                    $f[9] = set_lemma1300($f[9], $lemmata{lc($f[1])}[1]);
                }
                $f[3] = 'VERB';
                $f[4] = "V--S---3I-${p}A---";
                # Neznáme lexikální vid, ale imperfektový tvar je pravděpodobnější u nedokonavých sloves.
                $f[5] = "Aspect=Imp|Mood=Ind|Number=Sing|Person=3|Polarity=$polarity|Tense=Imp|VerbForm=Fin|Voice=Act";
            }
        }
        # -šta: imperfekt 3. osoby dvojného čísla
        elsif($f[1] =~ m/^(ne)?.+(iešta|ášta|léšta)$/i)
        {
            my $negprefix = lc($1);
            my $found = try_ma_from_misc(\@f, {'UPOS' => 'VERB', 'VerbForm' => 'Fin', 'Tense' => 'Imp'});
            if(!$found)
            {
                my ($polarity, $p) = negprefix_to_polarity($negprefix);
                if(exists($lemmata{lc($f[1])}))
                {
                    $f[2] = $lemmata{lc($f[1])}[0];
                    $f[9] = set_lemma1300($f[9], $lemmata{lc($f[1])}[1]);
                }
                $f[3] = 'VERB';
                $f[4] = "V--D---3I-${p}A---";
                # Neznáme lexikální vid, ale imperfektový tvar je pravděpodobnější u nedokonavých sloves.
                $f[5] = "Aspect=Imp|Mood=Ind|Number=Dual|Person=3|Polarity=$polarity|Tense=Imp|VerbForm=Fin|Voice=Act";
            }
        }
        # -sta: sigmatický aorist 3. osoby dvojného čísla
        elsif($f[1] =~ m/[aei][sš]ta$/i && $f[1] !~ m/^(Jezukrista|miesta)$/i)
        {
            my $found = try_ma_from_misc(\@f, {'UPOS' => 'VERB', 'VerbForm' => 'Fin', 'Tense' => 'Past'});
            if($found)
            {
                $f[5] =~ s/VerbForm/Variant=Long\|VerbForm/;
            }
            else
            {
                my ($polarity, $p) = negprefix_to_polarity($negprefix);
                my $lcform = lc($f[1]);
                if(exists($lemmata{$lcform}))
                {
                    my $l2022 = $lemmata{$lcform}[0];
                    my $l1300 = $lemmata{$lcform}[1];
                    $f[2] = $l2022;
                    $f[9] = set_lemma1300($f[9], $l1300);
                }
                $f[3] = 'VERB';
                $f[4] = "V--D---3A-${p}A---";
                # Neznáme lexikální vid, ale aoristový tvar je pravděpodobnější u dokonavých sloves.
                $f[5] = "Aspect=Perf|Mood=Ind|Number=Dual|Person=3|Polarity=$polarity|Tense=Past|Variant=Long|VerbForm=Fin|Voice=Act";
            }
        }
        # -chu: imperfekt 3. osoby množného čísla
        elsif($f[1] =~ m/^(ne)?.+(iechu|áchu|léchu)$/i)
        {
            # Podle Jiřího Perglera by tvary "báchu" a "stáchu" mohly být i aoristy, ale v daných kontextech se to nezdá pravděpodobné.
            my $negprefix = lc($1);
            my $found = try_ma_from_misc(\@f, {'UPOS' => 'VERB', 'VerbForm' => 'Fin', 'Tense' => 'Imp'});
            if(!$found)
            {
                my ($polarity, $p) = negprefix_to_polarity($negprefix);
                if(exists($lemmata{lc($f[1])}))
                {
                    $f[2] = $lemmata{lc($f[1])}[0];
                    $f[9] = set_lemma1300($f[9], $lemmata{lc($f[1])}[1]);
                }
                $f[3] = 'VERB';
                $f[4] = "V--P---3I-${p}A---";
                # Neznáme lexikální vid, ale imperfektový tvar je pravděpodobnější u nedokonavých sloves.
                $f[5] = "Aspect=Imp|Mood=Ind|Number=Plur|Person=3|Polarity=$polarity|Tense=Imp|VerbForm=Fin|Voice=Act";
            }
        }
        # -chu: sigmatický aorist 3. osoby množného čísla
        elsif($f[1] =~ m/^(ne)?.+chu$/i && $f[1] !~ m/^(duchu|rúchu|střěchu|svrchu|vrchu|ženichu)$/)
        {
            my $negprefix = lc($1);
            my $found = try_ma_from_misc(\@f, {'UPOS' => 'VERB', 'VerbForm' => 'Fin', 'Tense' => 'Past'});
            if($found)
            {
                $f[5] =~ s/VerbForm/Variant=Long\|VerbForm/;
            }
            else
            {
                my ($polarity, $p) = negprefix_to_polarity($negprefix);
                my $lcform = lc($f[1]);
                if(exists($lemmata{$lcform}))
                {
                    my $l2022 = $lemmata{$lcform}[0];
                    my $l1300 = $lemmata{$lcform}[1];
                    # 'jěchu' => ['jíst', 'jiesti'], # "jíst" je to v MATT 14.20 a 15.37 (Dr. i Ol.), zatímco ve 26.67 (Dr.) a 26.50 (Ol.) je to "jmout" / "jieti"
                    if($lcform eq 'jěchu' && get_ref($f[9]) =~ m/^MATT_26\.(50|67)$/)
                    {
                        $l2022 = 'jmout';
                        $l1300 = 'jieti';
                    }
                    $f[2] = $l2022;
                    $f[9] = set_lemma1300($f[9], $l1300);
                }
                $f[3] = 'VERB';
                $f[4] = "V--P---3A-${p}A---";
                # Neznáme lexikální vid, ale aoristový tvar je pravděpodobnější u dokonavých sloves.
                $f[5] = "Aspect=Perf|Mood=Ind|Number=Plur|Person=3|Polarity=$polarity|Tense=Past|Variant=Long|VerbForm=Fin|Voice=Act";
            }
        }
        # Minulé l-ové příčestí končící na -a je většinou Fem Sing, ale je tam pár výjimek.
        elsif($f[5] =~ m/Gender=Fem,Neut\|Number=Plur,Sing/ && $f[1] =~ m/^(ne)?.+la$/i && $f[3] eq 'VERB')
        {
            my $negprefix = lc($1);
            my ($polarity, $p) = negprefix_to_polarity($negprefix);
            $f[2] = lemma_1300_to_2022($f[2]);
            my $aspect;
            if($f[5] =~ m/Aspect=(Imp|Perf)/)
            {
                $aspect = $1;
            }
            # Neut Plur: Dr. 11.20: tresktati města, že jsú neučinila pokánie; 26.39: aby mě minula tato muka
            if(get_ref($f[9]) =~ m/^MATT_(11\.20|26\.39)$/)
            {
                $f[4] = "VpNP---XR-${p}A---";
                $f[5] = "Gender=Neut|Number=Plur|Polarity=$polarity|Tense=Past|VerbForm=Part|Voice=Act";
                $f[5] = "Aspect=$aspect|$f[5]" if(defined($aspect));
            }
            # Dual (obvykle Masc, jednou Masc+Fem): Dr. 1.18: sta sě sešla; Dr. 9.32: dva slepcě... když jsta pryč otešla; Dr. 11.4: odpovězta Janovi, co jsta slyšala i viděla; Ol. 8.28: ta biešta vyšla z hrobóv
            elsif(get_ref($f[9]) =~ m/^MATT_(1\.18|9\.32|11\.4|8\.28)$/)
            {
                $f[4] = "VpMD---XR-${p}A---";
                $f[5] = "Animacy=Anim|Gender=Masc|Number=Dual|Polarity=$polarity|Tense=Past|VerbForm=Part|Voice=Act";
                $f[5] =~ s/=Anim/=Anim|Aspect=$aspect/ if(defined($aspect));
            }
            # Všechno ostatní je Fem Sing.
            else
            {
                $f[4] = "VpFS---XR-${p}A---";
                $f[5] = "Gender=Fem|Number=Sing|Polarity=$polarity|Tense=Past|VerbForm=Part|Voice=Act";
                $f[5] = "Aspect=$aspect|$f[5]" if(defined($aspect));
            }
        }
        # -íce: přechodník přítomný množného (popř. dvojného) čísla
        elsif($f[1] =~ m/^(ne)?.+(íce)$/i && $f[1] !~ m/^(líce|tisíce)$/i)
        {
            my $negprefix = lc($1);
            my $suffix = lc($2);
            my ($polarity, $p) = negprefix_to_polarity($negprefix);
            my $found = try_ma_from_misc(\@f, {'UPOS' => 'VERB', 'VerbForm' => 'Conv', 'Tense' => 'Pres', 'Number' => 'Plur'});
            if($found)
            {
                # V tomto případě použijeme z analýzy ve Staročeské bance pouze
                # lemma a vid. Poziční značka je nepoužitelná, protože obsahuje
                # rod, který my v plurálu neoznačujeme, a pád, který neoznačujeme
                # u přechodníků vůbec.
                my $aspect = 'Imp';
                if($f[5] =~ m/Aspect=Perf/)
                {
                    $aspect = 'Perf';
                }
                if(get_ref($f[9]) =~ m/^MATT_4\.18$/)
                {
                    $f[4] = "VeXD------${p}----";
                    $f[5] = "Aspect=$aspect|Number=Dual|Polarity=$polarity|Tense=Pres|VerbForm=Conv|Voice=Act";
                }
                else
                {
                    $f[4] = "VeXP------${p}----";
                    $f[5] = "Aspect=$aspect|Number=Plur|Polarity=$polarity|Tense=Pres|VerbForm=Conv|Voice=Act";
                }
            }
            else
            {
                if(exists($lemmata{lc($f[1])}))
                {
                    $f[2] = $lemmata{lc($f[1])}[0];
                    $f[9] = set_lemma1300($f[9], $lemmata{lc($f[1])}[1]);
                }
                else
                {
                    my $lemma = lc($f[1]);
                    $lemma =~ s/$suffix$/it/;
                    $f[2] = $lemma;
                    $f[9] = set_lemma1300($f[9], $lemma.'i');
                }
                $f[3] = 'VERB';
                # Slovo "melíce" se vyskytlo v kontextu duálu, ostatní v plurálu.
                if($f[1] =~ m/^melíce$/i)
                {
                    $f[4] = "VeXD------${p}----";
                    $f[5] = "Aspect=Imp|Number=Dual|Polarity=$polarity|Tense=Pres|VerbForm=Conv|Voice=Act";
                }
                else
                {
                    $f[4] = "VeXP------${p}----";
                    # Neznáme lexikální vid, ale přechodník přítomný je pravděpodobnější u nedokonavých sloves.
                    $f[5] = "Aspect=Imp|Number=Plur|Polarity=$polarity|Tense=Pres|VerbForm=Conv|Voice=Act";
                }
            }
        }
        # -iece, -úce: přechodník přítomný množného (popř. dvojného) čísla
        elsif($f[1] =~ m/^(ne)?.+(iece|úce)$/i && $f[1] !~ m/^(viece)$/i)
        {
            my $negprefix = lc($1);
            my $suffix = lc($2);
            my ($polarity, $p) = negprefix_to_polarity($negprefix);
            my $found = try_ma_from_misc(\@f, {'UPOS' => 'VERB', 'VerbForm' => 'Conv', 'Tense' => 'Pres', 'Number' => 'Plur'});
            if($found)
            {
                # V tomto případě použijeme z analýzy ve Staročeské bance pouze
                # lemma a vid. Poziční značka je nepoužitelná, protože obsahuje
                # rod, který my v plurálu neoznačujeme, a pád, který neoznačujeme
                # u přechodníků vůbec.
                my $aspect = 'Imp';
                if($f[5] =~ m/Aspect=Perf/)
                {
                    $aspect = 'Perf';
                }
                $f[4] = "VeXP------${p}----";
                $f[5] = "Aspect=$aspect|Number=Plur|Polarity=$polarity|Tense=Pres|VerbForm=Conv|Voice=Act";
            }
            else
            {
                if(exists($lemmata{lc($f[1])}))
                {
                    $f[2] = $lemmata{lc($f[1])}[0];
                    $f[9] = set_lemma1300($f[9], $lemmata{lc($f[1])}[1]);
                }
                else
                {
                    my $lemma = lc($f[1]);
                    $lemma =~ s/$suffix$/et/;
                    $f[2] = $lemma;
                    $f[9] = set_lemma1300($f[9], $lemma.'i');
                }
                $f[3] = 'VERB';
                $f[4] = "VeXP------${p}----";
                # Neznáme lexikální vid, ale přechodník přítomný je pravděpodobnější u nedokonavých sloves.
                $f[5] = "Aspect=Imp|Number=Plur|Polarity=$polarity|Tense=Pres|VerbForm=Conv|Voice=Act";
            }
        }
        # 0/-ši/-še: přechodník minulý, vybrané tvary
        elsif($f[1] =~ m/^(ne)?(o|ote|po|při|se|u|vz)?(brav|pustiv|slav|slyš[aě]v|stav|stúpiv|věděv|volav|vřěv|vzem)(š[ie])?$/i)
        {
            my $negprefix = lc($1);
            my $prefix = lc($2);
            my $suffix = lc($3);
            my $suffix2 = lc($4);
            my ($polarity, $p) = negprefix_to_polarity($negprefix);
            my $aspect = $prefix || $suffix =~ m/^(pustiv|vzem)$/ ? 'Perf' : 'Imp';
            my $lemma1300 = $prefix.$suffix;
            $lemma1300 =~ s/vřěv$/vříti/;
            $lemma1300 =~ s/vzem$/vzieti/;
            $lemma1300 =~ s/v$/ti/;
            $f[2] = lemma_1300_to_2022($lemma1300);
            $f[9] = set_lemma1300($f[9], $lemma1300);
            $f[3] = 'VERB';
            if($suffix2 eq 'ši')
            {
                $f[4] = "VmFS------${p}----";
                $f[5] = "Aspect=$aspect|Gender=Fem|Number=Sing|Polarity=$polarity|Tense=Past|VerbForm=Conv|Voice=Act";
            }
            elsif($suffix2 eq 'še')
            {
                # Ve 4.20 "ostavše", 4.22 "opustivše" a ve 20.30 "uslyšěvše" jsou duály.
                if(get_ref($f[9]) =~ m/^MATT_(4\.20|4\.22|20\.30)$/)
                {
                    $f[4] = "VmXD------${p}----";
                    $f[5] = "Aspect=$aspect|Number=Dual|Polarity=$polarity|Tense=Past|VerbForm=Conv|Voice=Act";
                }
                else
                {
                    $f[4] = "VmXP------${p}----";
                    $f[5] = "Aspect=$aspect|Number=Plur|Polarity=$polarity|Tense=Past|VerbForm=Conv|Voice=Act";
                }
            }
            else
            {
                # V 9.18 v Drážďanské bibli je "přistúpiv" střední rod.
                if(get_ref($f[9]) =~ m/^MATT_9\.18$/)
                {
                    $f[4] = "VmNS------${p}----";
                    $f[5] = "Aspect=$aspect|Gender=Neut|Number=Sing|Polarity=$polarity|Tense=Past|VerbForm=Conv|Voice=Act";
                }
                else
                {
                    $f[4] = "VmYS------${p}----";
                    $f[5] = "Aspect=$aspect|Gender=Masc|Number=Sing|Polarity=$polarity|Tense=Past|VerbForm=Conv|Voice=Act";
                }
            }
        }
        # -še: přechodník minulý množného (popř. dvojného) čísla
        elsif($f[1] =~ m/^(ne)?.+([dhkmtv]še)$/i && $f[1] !~ m/^vše$/i)
        {
            my $negprefix = lc($1);
            my $suffix = lc($2);
            my $found = try_ma_from_misc(\@f, {'UPOS' => 'VERB', 'VerbForm' => 'Conv', 'Tense' => 'Past', 'Number' => 'Plur'});
            if($found)
            {
                # Ve verši 20.30 je "uslyšěvše" duál přinejmenším v Drážďanské bibli, v Olomoucké už to není jasné (je tam kolem duál i plurál).
                if(get_ref($f[9]) =~ m/^MATT_20\.30$/)
                {
                    $f[5] =~ s/Number=(Dual|Plur)/Number=Dual/;
                }
                else
                {
                    $f[5] =~ s/Number=(Dual|Plur)/Number=Plur/;
                }
            }
            else
            {
                my ($polarity, $p) = negprefix_to_polarity($negprefix);
                if(exists($lemmata{lc($f[1])}))
                {
                    $f[2] = $lemmata{lc($f[1])}[0];
                    $f[9] = set_lemma1300($f[9], $lemmata{lc($f[1])}[1]);
                }
                else
                {
                    my $lemma = lc($f[1]);
                    $lemma =~ s/$suffix$/t/;
                    $f[2] = $lemma;
                    $f[9] = set_lemma1300($f[9], $lemma.'i');
                }
                $f[3] = 'VERB';
                $f[4] = "VmXP------${p}----";
                # Neznáme lexikální vid, ale přechodník minulý je pravděpodobnější u dokonavých sloves.
                $f[5] = "Aspect=Perf|Number=Plur|Polarity=$polarity|Tense=Past|VerbForm=Conv|Voice=Act";
            }
        }
        #----------------------------------------------------------------------
        # Příslovce.
        #----------------------------------------------------------------------
        # "Protož" není totéž co dnešní "protože". Vyskytuje se to často na začátku věty jako diskurzní spojka.
        # Nemáme k dispozici žádnou jednoduchou analogii, podle které bychom to mohli označkovat.
        # Podobná slova dopadají každé jinak: "tedy" je ADV, "takže" je SCONJ, "tudíž" je CCONJ.
        # Momentálně se přikláním ke značce pro zájmenné příslovce, což by alespoň mělo odpovídat etymologii.
        # (Ovšem jak tak koukám, v RIDICS to považují za spojku. Ale neříkají, zda souřadící, nebo podřadící.)
        # "Takež" zřejmě znamená "tak též", "tak". Někdy se vyskytuje ve spojení "jakož...takež", někdy je dokonce označkováno jako SCONJ, ale sjednotíme to na příslovci.
        elsif($f[1] =~ m/^(dotud|protož|tak|takež)$/i)
        {
            $f[2] = lc($f[1]);
            $f[9] = set_lemma1300($f[9], $f[2]);
            $f[3] = 'ADV';
            $f[4] = 'Db-------------';
            $f[5] = 'PronType=Dem';
        }
        # "Tu" může být tvar zájmena "ten" nebo alternativní forma příslovce "tady".
        # Neměla by se nám ale zájmenná lemmata a rysy míchat se značkou pro příslovce.
        elsif($f[1] =~ m/^tu$/i && $f[3] eq 'ADV')
        {
            $f[2] = 'tady';
            $f[9] = set_lemma1300($f[9], 'tu');
            $f[3] = 'ADV';
            $f[4] = 'Db-------------';
            $f[5] = 'PronType=Dem';
        }
        # Vokabulář uvádí, že "poňaž" může být vztažné příslovce nebo spojka.
        # Alternativním tvarem je "poněvadž", ale na rozdíl od nové češtiny,
        # kde je "poněvadž" synonymem "protože", ve staré češtině to často
        # znamenalo "pokud" nebo "dokud".
        elsif($f[1] =~ m/^(kdež|poňaž|proč)$/i)
        {
            $f[2] = lc($f[1]);
            $f[9] = set_lemma1300($f[9], $f[2]);
            $f[3] = 'ADV';
            $f[4] = 'Db-------------';
            $f[5] = 'PronType=Int,Rel';
        }
        elsif($f[1] =~ m/^(nikakž)$/i)
        {
            $f[2] = lc($f[1]);
            $f[9] = set_lemma1300($f[9], $f[2]);
            $f[3] = 'ADV';
            $f[4] = 'Db-------------';
            $f[5] = 'PronType=Neg';
        }
        # "Velmi" se v novočeských datech značkuje jako nestupňované příslovce,
        # proto to tady udělám stejně. Nicméně vzhledem k tomu, že pro komparativ
        # "viece" níže dávám staročeské lemma "velmi", dávalo by smysl, aby
        # "velmi" bylo označkováno jako první stupeň.
        elsif($f[1] =~ m/^velmi$/i)
        {
            $f[2] = 'velmi';
            $f[9] = set_lemma1300($f[9], 'velmi');
            $f[3] = 'ADV';
            $f[4] = 'Db-------------'; # Dg-------1A----
            $f[5] = '_'; # Degree=Pos|Polarity=Pos
        }
        # "Více" je v novočeských datech buď komparativ příslovce "hodně",
        # nebo číslovka neurčitá (v tom případě značka komparativu chybí a lemma je "více").
        # Zdá se, že i ve staročeských datech má "viece" někdy blíže k příslovci
        # a někdy k číslovce, akorát příslovce "hodně" tam nefunguje jako příslovce
        # míry, to už by se hodilo spíš "velmi", případně "mnoho".
        elsif($f[1] =~ m/^viece$/i)
        {
            $f[2] = 'hodně';
            $f[9] = set_lemma1300($f[9], 'velmi');
            $f[3] = 'ADV';
            $f[4] = 'Dg-------2A----';
            $f[5] = 'Degree=Cmp|Polarity=Pos';
        }
        # Příslovce, která se nestupňují, nenegují, ani nejsou zájmenná.
        # "Jediné" = "jedině". Mohlo by sice jít i o tvar adjektiva "jediný", ale v drtivé většině případů
        # je to užito jako příslovce.
        # "Již" může být příslovce ("už") nebo vztažné zájmeno, to zde nerozhodneme, proto vynechat.
        # "Juž" je jedině příslovce (vyskytuje se jen v Drážďanské bibli). Jeho novodobé lemma by mohlo být "už" nebo "již".
        # "Okolo" může být příslovce nebo předložka, to zde nerozhodneme, proto vynechat.
        # "Ráno" může být příslovce nebo substantivum, to zde nerozhodneme, proto vynechat.
        # "Večer" může být příslovce nebo substantivum, to zde nerozhodneme, proto vynechat.
        # "Zavěrné" = "zajisté".
        elsif($f[1] =~ m/^(bliz|darmo|dnes|dolóv|inhed|jediné|ješče|ještě|jinak|juž|naposledy|např[eě]d|nazad|nynie|opět|potom|pr[ey]č|prostř[eě]d|snad|spolu|svrchu|szadu|tepruv|též|ven|věru|vnitř|zajisté|zajtra|zatiem|zavěrné|zdaleka|zevna|zevnitř)$/i)
        {
            my $lemma1300 = lc($f[1]);
            $lemma1300 =~ s/^napřed$/napřěd/;
            $lemma1300 =~ s/^preč$/pryč/;
            $lemma1300 =~ s/^prostřed$/prostřěd/;
            $f[2] = $lemma1300;
            $f[2] =~ s/^bliz$/blízko/;
            $f[2] =~ s/^dolóv$/dolů/;
            $f[2] =~ s/^inhed$/ihned/;
            $f[2] =~ s/^jediné$/jedině/;
            $f[2] =~ s/^ješče$/ještě/;
            $f[2] =~ s/^juž$/už/;
            $f[2] =~ s/^napřěd$/napřed/;
            $f[2] =~ s/^nynie$/nyní/;
            $f[2] =~ s/^prostřěd$/prostřed/;
            $f[2] =~ s/^szadu$/zezadu/;
            $f[2] =~ s/^tepruv$/teprve/;
            $f[2] =~ s/^vnitř$/uvnitř/;
            $f[2] =~ s/^zajtra$/zítra/;
            $f[2] =~ s/^zatiem$/zatím/;
            $f[2] =~ s/^zevna$/zvnějšku/;
            $f[9] = set_lemma1300($f[9], $lemma1300);
            $f[3] = 'ADV';
            $f[4] = 'Db-------------';
            $f[5] = '_';
        }
        #----------------------------------------------------------------------
        # Předložky.
        #----------------------------------------------------------------------
        # Zatím ignorujeme předložku "okolo", může to být i příslovce.
        # "Miesto" je předložka v 2.21 resp. 2.22, všude jinde je to podstatné jméno. To už jsme ale odchytili výše, takže pokud jsme tady, zbývá nám předložka.
        # "Vstřieci" může být předložka i záložka (s dativem).
        elsif($f[1] =~ m/^(během|beze?|do|k[eu]?|kromě|mezi|miesto|mimo|na|nade?|o|po|pod|podlé|pro|proti|př[eě]de?|př[eě]s|při|s|skrzě|ve|vně|vstřieci|za|ze?)$/i)
        {
            my $lemma1300 = lc($1);
            $lemma1300 =~ s/[eu]$//;
            # Není mi jasné, jestli lemma1300 má být "přěd", nebo "před" (v textech se vyskytuje obojí). Zatím sjednocuju na "před".
            $lemma1300 =~ s/přě/pře/;
            $f[9] = set_lemma1300($f[9], $lemma1300);
            $f[2] = $lemma1300;
            $f[2] =~ s/^miesto$/místo/;
            $f[2] =~ s/^podlé$/podle/;
            $f[2] =~ s/^skrzě$/skrz/;
            $f[2] =~ s/^vstřieci$/vstříc/;
            $f[3] = 'ADP';
            my $case;
            if($f[2] =~ m/^(během|bez|do|kromě|místo|podle|vně)$/)
            {
                $case = 'Gen';
            }
            elsif($f[2] =~ m/^(k|proti|vstříc)$/)
            {
                $case = 'Dat';
            }
            elsif($f[2] =~ m/^(pro|přes|skrz)$/)
            {
                $case = 'Acc';
            }
            elsif($f[2] =~ m/^(při)$/)
            {
                $case = 'Loc';
            }
            elsif($f[5] =~ m/Case=(...)/)
            {
                $case = $1;
            }
            else
            {
                $case = 'Gen';
            }
            if($f[1] =~ m/[eu]$/i)
            {
                $f[4] = uposf_to_xpos($f[3], {'AdpType' => 'Voc', 'Case' => $case});
                $f[5] = "AdpType=Voc|Case=$case";
            }
            else
            {
                $f[4] = uposf_to_xpos($f[3], {'AdpType' => 'Prep', 'Case' => $case});
                $f[5] = "AdpType=Prep|Case=$case";
            }
        }
        elsif($f[1] =~ m/^o[dt](e?)$/i)
        {
            my $e = $1;
            $f[2] = 'od';
            $f[9] = set_lemma1300($f[9], 'ot');
            $f[3] = 'ADP';
            if($e)
            {
                $f[4] = 'RV--2----------';
                $f[5] = 'AdpType=Voc|Case=Gen';
            }
            else
            {
                $f[4] = 'RR--2----------';
                $f[5] = 'AdpType=Prep|Case=Gen';
            }
        }
        # Vokalizované "se" je skoro vždy předložka, protože zvratné zájmeno tehdy bylo "sě"; pouze ve dvou výskytech v Olomoucké bibli je zvratné zájmeno "se".
        elsif($f[1] =~ m/^se$/i && get_ref($f[9]) !~ m/^MATT_(2\.11|7\.25)$/)
        {
            $f[2] = 's';
            $f[9] = set_lemma1300($f[9], 's');
            $f[3] = 'ADP';
            # Pád je instrumentál nebo genitiv, to tady nerozhodneme. Nicméně nechceme nechat případné zájmenné rysy, tak střelíme instrumentál.
            $f[4] = 'RV--7----------';
            $f[5] = 'AdpType=Voc|Case=Ins';
        }
        # Vokalizované "ve" jsme chytili výše, ale "v" může být také římská číslice nebo iniciála.
        elsif($f[1] =~ m/^v$/i && $f[3] !~ m/^(NOUN|PROPN|NUM)$/)
        {
            $f[2] = 'v';
            $f[9] = set_lemma1300($f[9], 'v');
            # Pád je akuzativ nebo lokativ, nechat ho tak, jak rozhodl UDPipe.
        }
        #----------------------------------------------------------------------
        # Spojky.
        #----------------------------------------------------------------------
        # "Neb" označkujeme jako "neboť", neb má podobný význam.
        elsif($f[1] =~ m/^(a|ale|ani|neb|nebo|neboť|poňadž|tudiež|však|všakž)$/i)
        {
            $f[2] = $f[1] =~ m/^tudiež$/i ? 'tudíž' : lc($1);
            $f[9] = set_lemma1300($f[9], $f[2]);
            $f[3] = 'CCONJ';
            $f[4] = 'J^-------------';
            $f[5] = '_';
        }
        # "I" může být i římská číslice.
        elsif($f[1] =~ m/^(i)$/i && $f[3] !~ m/^NUM$/)
        {
            $f[2] = lc($1);
            $f[9] = set_lemma1300($f[9], $f[2]);
            $f[3] = 'CCONJ';
            $f[4] = 'J^-------------';
            $f[5] = '_';
        }
        # "Pakli" je podobné jako "jestliže": Dr. 5.39 "Pakli tě kto udeří po pravém líci, poskyť jemu i druhého."
        # U "kdyžto" by se mohlo jednat o vztažné příslovce a nemám jasno, čemu dát přednost.
        elsif($f[1] =~ m/^(aby|ač|aniž|azda|ažť|dokud|jako|jakož|jakožto|kakož|když|kdyžto|než|nežli|pakli|pokud|pokudž|poněvadž|protože|zda|zdali|že)$/i)
        {
            $f[2] = lc($1);
            $f[9] = set_lemma1300($f[9], $f[2]);
            $f[3] = 'SCONJ';
            $f[4] = 'J,-------------';
            $f[5] = '_';
        }
        #----------------------------------------------------------------------
        # Částice.
        #----------------------------------------------------------------------
        elsif($f[1] =~ m/^ku?oli(věk)?$/i)
        {
            $f[2] = 'koli';
            $f[9] = set_lemma1300($f[9], 'kuoli');
            $f[3] = 'PART';
            $f[4] = 'TT-------------';
            $f[5] = '_';
        }
        elsif($f[1] =~ m/^(li)$/i)
        {
            $f[2] = lc($1);
            $f[9] = set_lemma1300($f[9], $f[2]);
            $f[3] = 'PART';
            $f[4] = 'TT-------------';
            $f[5] = '_';
        }
        # "Toť" může být buď částice, nebo tvar zájmena "to" ("ten").
        # Pokud je to částice, nemělo by u sebe mít rysy zájmena.
        # Ovšem ukazuje se, že ten jeden případ, kde se nám to stalo, ve skutečnosti má být zájmeno v akuzativu.
        elsif($f[1] =~ m/^toť$/i && $f[3] eq 'PART' && $f[5] ne '_')
        {
            $f[2] = 'ten';
            $f[9] = set_lemma1300($f[9], 'ten');
            $f[3] = 'DET';
            $f[4] = 'PDNS4----------';
            $f[5] = 'Case=Acc|Gender=Neut|Number=Sing|PronType=Dem';
        }
        #----------------------------------------------------------------------
        # Citoslovce.
        #----------------------------------------------------------------------
        elsif($f[1] =~ m/^naliť$/i)
        {
            $f[2] = 'naliť';
            $f[9] = set_lemma1300($f[9], 'naliť');
            $f[3] = 'INTJ';
            $f[4] = 'II-------------';
            $f[5] = '_';
        }
        elsif($f[1] =~ m/^[„…“]$/)
        {
            $f[2] = $f[1];
            $f[9] = set_lemma1300($f[9], $f[1]);
            $f[3] = 'PUNCT';
            $f[4] = 'Z:-------------';
            $f[5] = '_';
        }
        elsif($f[3] eq 'PUNCT')
        {
            $f[9] = set_lemma1300($f[9], $f[2]);
        }
        else
        {
            $f[2] = lemma_1300_to_2022($f[2]);
        }
        # Tohle už není elsif, protože nahoře jsme mohli udělat zájmeno ze slova, které bylo původně označkované jinak.
        # Některá pro UDPipe neznámá zájmena ("tebú", "sebú") jsou označkována jako substantiva.
        # Kromě toho "jě" je někdy označkováno jako tvar slovesa "být", což je chyba.
        # Na druhou stranu nahoře jsme už pochytali několik případů, kdy to má být aorist slovesa "jmout", těm se tady vyhnout.
        # Některá další zájmena je zde potřeba zachytit zvlášť, protože k nim UDPipe vymyslel nesmyslné značky, třeba VERB.
        if($f[3] =~ m/^(PRON|DET|NOUN)$/ || $f[1] =~ m/^jě$/i && $f[2] ne 'jmout' || $f[1] =~ m/^(mój|muoj|mú|ižádn|svój|svuoj|svú|tvój|tvuoj|tvú|uon|ve?š)/i)
        {
            @f = opravit_zajmena(@f);
        }
        $_ = join("\t", @f)."\n";
    }
    print;
}



#------------------------------------------------------------------------------
# Podle tvarů upraví anotaci tvarů slovesa být. Volá se za podmínky, že už
# víme, že to jeden z těch tvarů je, takže některé společné anotace můžeme
# udělat na začátku bez dalšího ptaní.
#------------------------------------------------------------------------------
sub opravit_sloveso_byt
{
    my $negprefix = shift;
    my $prefix = shift;
    my $suffix = shift;
    my @f = @_;
    my ($polarity, $p) = negprefix_to_polarity($negprefix);
    my $prefix1300 = $prefix;
    if($prefix =~ m/^o[dt]/)
    {
        # Sjednotit "od" vs. "ot".
        $prefix = 'od';
        $prefix1300 = 'ot';
    }
    $f[2] = $prefix.'být';
    $f[9] = set_lemma1300($f[9], $prefix1300.'býti');
    $f[3] = $prefix ? 'VERB' : 'AUX';
    my $aspect = $prefix ? 'Perf' : 'Imp';
    if($suffix =~ m/^b[ýy]ti?$/i)
    {
        $f[4] = "Vf--------${p}----";
        $f[5] = "Aspect=$aspect|Polarity=$polarity|VerbForm=Inf";
    }
    elsif($suffix =~ m/^j?sem$/i)
    {
        # Alternativní zápis "jsem". (Mohlo by se plést s příslovcem "sem", ale jeho výskyt se zdá být méně pravděpodobný.)
        $f[4] = "VB-S---1P-${p}A---";
        $f[5] = "Aspect=$aspect|Mood=Ind|Number=Sing|Person=1|Polarity=$polarity|Tense=Pres|VerbForm=Fin|Voice=Act";
    }
    elsif($suffix =~ m/^j?si$/i)
    {
        # Alternativní zápis "jsi". (Zvratné zájmeno "si" se v této době zřejmě ještě nepoužívalo?)
        $f[4] = "VB-S---2P-${p}A---";
        $f[5] = "Aspect=$aspect|Mood=Ind|Number=Sing|Person=2|Polarity=$polarity|Tense=Pres|VerbForm=Fin|Voice=Act";
    }
    elsif($suffix =~ m/^(jest|ní|nie)$/i)
    {
        # U "jest" tehdy ještě šlo o běžný tvar. Na rozdíl ode dneška by to nemělo mít příznak Style=Arch.
        # Krátký tvar "je" už se taky vyskytoval, ale pozor, ten je homonymní s akuzativem zájmena "ono" (viz níže).
        $f[4] = "VB-S---3P-${p}A---";
        $f[5] = "Aspect=$aspect|Mood=Ind|Number=Sing|Person=3|Polarity=$polarity|Tense=Pres|VerbForm=Fin|Voice=Act";
    }
    elsif($suffix =~ m/^j?sta$/i)
    {
        # Může jít o duál přítomného času slovesa "býti" ("dřéve než sta sě sešla") a morfologický analyzátor ani jinou možnost nenabízí (má pouze varianty pro 2. a 3. osobu a pro nedokonavý a dokonavý vid).
        # Jenže většina výskytů na mě dělá dojem, že jde jde spíš o tvar slovesa "státi sě" (potom by asi šlo o aorist singuláru, nikoli prézens duálu).
        # Prozatím se držím morfologického analyzátoru a dělám z toho ten duál. I tak je to zlepšení, protože UDPipe ani nepoznal, že jde o sloveso (hádal substantivum "sto").
        # U tvaru "jsta" tento problém není.
        my @ma = misc_to_ma($f[9]);
        foreach my $ma (@ma)
        {
            if($ma->{UPOS} eq 'VERB' && $ma->{VerbForm} eq 'Fin' && $ma->{Person} eq '3' && $ma->{Aspect} eq 'Imp')
            {
                $f[2] = $ma->{Hlemma};
                $f[2] =~ s/ti$/t/;
                $f[3] = 'AUX'; # $ma->{UPOS}; # v MA je UPOS odvozená z pražské značky, čili VERB, ale pro "býti" chceme AUX
                $f[4] = substr($ma->{PrgTag}, 0, 15);
                $f[5] = join('|', map {"$_=$ma->{$_}"} (grep {$ma->{$_}} (qw(Aspect Mood Number Person Polarity Tense VerbForm Voice))));
                last;
            }
        }
    }
    elsif($suffix =~ m/^j?sm[ey]$/i)
    {
        # Alternativní zápis "jsme".
        $f[4] = "VB-P---1P-${p}A---";
        $f[5] = "Aspect=$aspect|Mood=Ind|Number=Plur|Person=1|Polarity=$polarity|Tense=Pres|VerbForm=Fin|Voice=Act";
    }
    elsif($suffix =~ m/^j?ste$/i)
    {
        # Alternativní zápis "jste".
        $f[4] = "VB-P---2P-${p}A---";
        $f[5] = "Aspect=$aspect|Mood=Ind|Number=Plur|Person=2|Polarity=$polarity|Tense=Pres|VerbForm=Fin|Voice=Act";
    }
    elsif($suffix =~ m/^j?sú$/i)
    {
        # Alternativní zápis "jsú" = "jsou".
        $f[4] = "VB-P---3P-${p}A---";
        $f[5] = "Aspect=$aspect|Mood=Ind|Number=Plur|Person=3|Polarity=$polarity|Tense=Pres|VerbForm=Fin|Voice=Act";
    }
    elsif($suffix eq 'budu')
    {
        $f[4] = "VB-S---1F-${p}A---";
        $f[5] = "Aspect=$aspect|Mood=Ind|Number=Sing|Person=1|Polarity=$polarity|Tense=Fut|VerbForm=Fin|Voice=Act";
    }
    elsif($suffix eq 'budeš')
    {
        $f[4] = "VB-S---2F-${p}A---";
        $f[5] = "Aspect=$aspect|Mood=Ind|Number=Sing|Person=2|Polarity=$polarity|Tense=Fut|VerbForm=Fin|Voice=Act";
    }
    elsif($suffix eq 'bude')
    {
        $f[4] = "VB-S---3F-${p}A---";
        $f[5] = "Aspect=$aspect|Mood=Ind|Number=Sing|Person=3|Polarity=$polarity|Tense=Fut|VerbForm=Fin|Voice=Act";
    }
    elsif($suffix eq 'budeta')
    {
        $f[4] = "VB-D---3F-${p}A---";
        $f[5] = "Aspect=$aspect|Mood=Ind|Number=Dual|Person=3|Polarity=$polarity|Tense=Fut|VerbForm=Fin|Voice=Act";
    }
    elsif($suffix =~ m/^budemy?$/i)
    {
        $f[4] = "VB-P---1F-${p}A---";
        $f[5] = "Aspect=$aspect|Mood=Ind|Number=Plur|Person=1|Polarity=$polarity|Tense=Fut|VerbForm=Fin|Voice=Act";
    }
    elsif($suffix eq 'budete')
    {
        $f[4] = "VB-P---2F-${p}A---";
        $f[5] = "Aspect=$aspect|Mood=Ind|Number=Plur|Person=2|Polarity=$polarity|Tense=Fut|VerbForm=Fin|Voice=Act";
    }
    elsif($suffix eq 'budú')
    {
        $f[4] = "VB-P---3F-${p}A---";
        $f[5] = "Aspect=$aspect|Mood=Ind|Number=Plur|Person=3|Polarity=$polarity|Tense=Fut|VerbForm=Fin|Voice=Act";
    }
    elsif($suffix =~ m/^bieše?$/i)
    {
        # Imperfekt od býti. Mohlo by jít i o 2. osobu, ale prakticky vždy jde o 3.
        # V jednom případě je apokopa na "bieš": "... jakž se bieš přěptal od mudrákóv".
        $f[4] = "V--S---3I-${p}A---"; # značka RIDICS by byla "V--S---3I-${p}A---I-", ale tohle více zapadá do sady PDT
        $f[5] = "Aspect=$aspect|Mood=Ind|Number=Sing|Person=3|Polarity=$polarity|Tense=Imp|VerbForm=Fin|Voice=Act";
    }
    elsif($suffix eq 'biešta')
    {
        # Imperfekt od býti. Mohlo by jít i o 2. osobu, ale prakticky vždy jde o 3.
        $f[4] = "V--D---3I-${p}A---"; # značka RIDICS by byla "V--D---3I-${p}A---I-", ale tohle více zapadá do sady PDT
        $f[5] = "Aspect=$aspect|Mood=Ind|Number=Dual|Person=3|Polarity=$polarity|Tense=Imp|VerbForm=Fin|Voice=Act";
    }
    elsif($suffix eq 'biechu')
    {
        # Imperfekt od býti.
        $f[4] = "V--P---3I-${p}A---"; # značka RIDICS by byla "V--P---3I-${p}A---I-", ale tohle více zapadá do sady PDT
        $f[5] = "Aspect=$aspect|Mood=Ind|Number=Plur|Person=3|Polarity=$polarity|Tense=Imp|VerbForm=Fin|Voice=Act";
    }
    elsif($suffix =~ m/^b[yě]chu$/i)
    {
        # Aorist od býti. Variant=Long odlišuje sigmatický aorist od asigmatického.
        # Sigmatický (též slabý): tvary původně obsahovaly s-ový sufix. V některých tvarech ale bylo -s- už v prehistorické době nahrazeno -ch-.
        # Sing: -ch -0 -0; Dual: -chově/-chova -sta/-šta -sta/šta; Plur: -chom/-chomy/-chome -ste/-šte -chu
        # Asigmatický (též silný, tematický): neobsahoval s-ový element. Je pravděpodobně vývojově starší. Předpokládá se, že už ve 14. století byl archaický.
        # Doložen je jen u omezené skupiny sloves, která měla kořen zakončen na souhlásku, a jen u některých osob a čísel.
        # Sing: -0 -e -e; Dual: -ově/-ova -eta -eta; Plur: -om/-ome/-omy -ete -u/-ú
        $f[4] = "V--P---3A-${p}A---"; # značka RIDICS by byla "V--P---3A-${p}A---I-", ale tohle více zapadá do sady PDT
        $f[5] = "Aspect=$aspect|Mood=Ind|Number=Plur|Person=3|Polarity=$polarity|Tense=Past|Variant=Long|VerbForm=Fin|Voice=Act";
    }
    # Tvar "buď" může být v nové češtině i spojka ("buď-nebo"), popř. také imperativ od "budit", ale ve staročeském evangeliu je to zřejmě vždy imperativ od "býti".
    # Na druhou stranu v Matoušově evangeliu jde často o imperativ pro 3. osobu, zatímco v nové češtině se počítá pouze se 2. osobou.
    elsif($suffix eq 'buď')
    {
        if(get_ref($f[9]) =~ m/^MATT_(2\.13|5\.25)$/)
        {
            $f[4] = "Vi-S---2--${p}----";
            $f[5] = "Aspect=$aspect|Mood=Imp|Number=Sing|Person=2|Polarity=$polarity|VerbForm=Fin";
        }
        else
        {
            $f[4] = "Vi-S---3--${p}----";
            $f[5] = "Aspect=$aspect|Mood=Imp|Number=Sing|Person=3|Polarity=$polarity|VerbForm=Fin";
        }
    }
    elsif($suffix =~ m/^buďtež?$/i)
    {
        $f[4] = "Vi-P---2--${p}----";
        $f[5] = "Aspect=$aspect|Mood=Imp|Number=Plur|Person=2|Polarity=$polarity|VerbForm=Fin";
    }
    elsif($suffix eq 'bych')
    {
        # Asi by teoreticky mohlo jít i o aorist, ale podle mě jsou všechny výskyty kondicionál.
        $f[4] = "Vc-S---1-------";
        $f[5] = "Aspect=$aspect|Mood=Cnd|Number=Sing|Person=1|VerbForm=Fin";
    }
    elsif($suffix eq 'by')
    {
        # Většinou jde o kondicionál 3. osoby (singulár i plurál).
        # Občas ale jde i o aorist (singulár 3. osoby, mohla by být i 2., ale tu jsem nezaznamenal).
        # "A ihned by očiščena jeho trudovatina."
        # "I by uzdraven pacholík v túž hodinu."
        # "A když by večer, nesiechu přědeň mnohé."
        # Pro "by" bez předpony máme vytipované verše, ve kterých jde o aorist.
        # S předponou to nikdy nemůže být kondicionál: "doby", "zby".
        if($prefix || get_ref($f[9]) =~ m/^MATT_(8\.3|8\.13|8\.16|9\.22|9\.25|12\.13|14\.11|14\.15|14\.23|15\.28|17\.2|17\.17|20\.8|27\.57|1\.18|3\.16|7\.27|8\.3|8\.13|8\.16|9\.22|9\.25|12\.13|12\.22|13\.48|14\.11|14\.15|14\.24|15\.28|17\.17|18\.24|20\.8|21\.29|22\.10|26\.20|27\.1|27\.57)$/) # nejdřív reference do Drážďanské bible, pak do Olomoucké
        {
            $f[4] = "V--S---3A-${p}A---"; # značka RIDICS by byla "V--S---3A-${p}A---I-", ale tohle více zapadá do sady PDT
            $f[5] = "Aspect=$aspect|Mood=Ind|Number=Sing|Person=3|Polarity=$polarity|Tense=Past|Variant=Long|VerbForm=Fin|Voice=Act";
        }
        else
        {
            $f[4] = "Vc-X---3-------";
            $f[5] = "Aspect=$aspect|Mood=Cnd|Person=3|VerbForm=Fin";
        }
    }
    elsif($suffix eq 'bychom')
    {
        # Asi by teoreticky mohlo jít i o aorist, ale podle mě jsou všechny výskyty kondicionál.
        $f[4] = "Vc-P---1-------";
        $f[5] = "Aspect=$aspect|Mood=Cnd|Number=Plur|Person=1|VerbForm=Fin";
    }
    elsif($suffix eq 'byšte')
    {
        # Asi by teoreticky mohlo jít i o aorist, ale podle mě jsou všechny výskyty kondicionál.
        $f[4] = "Vc-P---2-------";
        $f[5] = "Aspect=$aspect|Mood=Cnd|Number=Plur|Person=2|VerbForm=Fin";
    }
    elsif($suffix eq 'byl')
    {
        $f[4] = "VpYS---XR-${p}A---";
        $f[5] = "Aspect=$aspect|Gender=Masc|Number=Sing|Polarity=$polarity|Tense=Past|VerbForm=Part|Voice=Act";
    }
    elsif($suffix eq 'byla')
    {
        # Příčestí na -la je předvyplněno nejednoznačně jako Fem Sing | Neut Plur, ale v našich datech je "byla" vždy Fem Sing.
        $f[4] = "VpFS---XR-${p}A---";
        $f[5] = "Aspect=$aspect|Gender=Fem|Number=Sing|Polarity=$polarity|Tense=Past|VerbForm=Part|Voice=Act";
    }
    elsif($suffix eq 'bylo')
    {
        $f[4] = "VpNS---XR-${p}A---";
        $f[5] = "Aspect=$aspect|Gender=Neut|Number=Sing|Polarity=$polarity|Tense=Past|VerbForm=Part|Voice=Act";
    }
    elsif($suffix eq 'byli')
    {
        $f[4] = "VpMP---XR-${p}A---";
        $f[5] = "Animacy=Anim|Aspect=$aspect|Gender=Masc|Number=Plur|Polarity=$polarity|Tense=Past|VerbForm=Part|Voice=Act";
    }
    elsif($suffix eq 'jsa')
    {
        $f[4] = "VeYS------${p}----";
        $f[5] = "Aspect=$aspect|Gender=Masc|Number=Sing|Polarity=$polarity|Tense=Pres|VerbForm=Conv|Voice=Act";
    }
    elsif($suffix eq 'jsúci')
    {
        $f[4] = "VeFS------${p}----";
        $f[5] = "Aspect=$aspect|Gender=Fem|Number=Sing|Polarity=$polarity|Tense=Pres|VerbForm=Conv|Voice=Act";
    }
    elsif($suffix =~ m/^jsúce?$/i)
    {
        # Je pár výjimek, kde tvar 'jsúce' odkazuje k singuláru. Typicky jsou to případy, kde je koreferenční s něčím jiným než s podmětem.
        # BiblDrážď Mt16,13 Koho pravie lidé jsúce synem člověčím [...]
        # BiblDrážď Mt18,8 Dobro jest tobě do věčného života vjíti jsúce mdlým nebo belhavým [...]
        if(get_ref($f[9]) =~ m/^MATT_(16\.13|18\.8)$/)
        {
            $f[4] = "VeYS------${p}----";
            $f[5] = "Aspect=$aspect|Gender=Masc|Number=Sing|Polarity=$polarity|Tense=Pres|VerbForm=Conv|Voice=Act";
        }
        # BiblOl 14.8 'jsúc' je femininum singuláru (v BiblDrážď je na odpovídajícím místě 'jsúci').
        elsif(get_ref($f[9]) =~ m/^MATT_(14\.8)$/)
        {
            $f[4] = "VeFS------${p}----";
            $f[5] = "Aspect=$aspect|Gender=Fem|Number=Sing|Polarity=$polarity|Tense=Pres|VerbForm=Conv|Voice=Act";
        }
        else
        {
            $f[4] = "VeXP------${p}----";
            $f[5] = "Aspect=$aspect|Number=Plur|Polarity=$polarity|Tense=Pres|VerbForm=Conv|Voice=Act";
        }
    }
    return @f;
}



#------------------------------------------------------------------------------
# Podle tvarů upraví anotaci tvarů slovesa chtít. Volá se za podmínky, že už
# víme, že to jeden z těch tvarů je, takže některé společné anotace můžeme
# udělat na začátku bez dalšího ptaní.
#------------------------------------------------------------------------------
sub opravit_sloveso_chtit
{
    my $negprefix = shift;
    my $prefix = shift;
    my $suffix = shift;
    my @f = @_;
    my $polarity = 'Pos';
    my $p = 'A';
    if($negprefix)
    {
        $polarity = 'Neg';
        $p = 'N';
    }
    $f[2] = $prefix.'chtít';
    $f[9] = set_lemma1300($f[9], $prefix.'chtieti');
    $f[3] = 'VERB';
    my $aspect = $prefix ? 'Perf' : 'Imp';
    if($suffix eq 'ci')
    {
        $f[4] = "VB-S---1P-${p}A---";
        $f[5] = "Aspect=$aspect|Mood=Ind|Number=Sing|Person=1|Polarity=$polarity|Tense=Pres|VerbForm=Fin|Voice=Act";
    }
    elsif($suffix eq 'ceš')
    {
        $f[4] = "VB-S---2P-${p}A---";
        $f[5] = "Aspect=$aspect|Mood=Ind|Number=Sing|Person=2|Polarity=$polarity|Tense=Pres|VerbForm=Fin|Voice=Act";
    }
    elsif($suffix eq 'ce')
    {
        $f[4] = "VB-S---3P-${p}A---";
        $f[5] = "Aspect=$aspect|Mood=Ind|Number=Sing|Person=3|Polarity=$polarity|Tense=Pres|VerbForm=Fin|Voice=Act";
    }
    elsif($suffix eq 'csta')
    {
        $f[4] = "VB-D---2P-${p}A---";
        $f[5] = "Aspect=$aspect|Mood=Ind|Number=Dual|Person=2|Polarity=$polarity|Tense=Pres|VerbForm=Fin|Voice=Act";
    }
    elsif($suffix =~ m/^ceme?$/i)
    {
        $f[4] = "VB-P---1P-${p}A---";
        $f[5] = "Aspect=$aspect|Mood=Ind|Number=Plur|Person=1|Polarity=$polarity|Tense=Pres|VerbForm=Fin|Voice=Act";
    }
    elsif($suffix eq 'cete')
    {
        $f[4] = "VB-P---2P-${p}A---";
        $f[5] = "Aspect=$aspect|Mood=Ind|Number=Plur|Person=2|Polarity=$polarity|Tense=Pres|VerbForm=Fin|Voice=Act";
    }
    elsif($suffix eq 'tie')
    {
        $f[4] = "VB-P---3P-${p}A---";
        $f[5] = "Aspect=$aspect|Mood=Ind|Number=Plur|Person=3|Polarity=$polarity|Tense=Pres|VerbForm=Fin|Voice=Act";
    }
    elsif($suffix eq 'tieše')
    {
        $f[4] = "V--S---3I-${p}A---";
        $f[5] = "Aspect=$aspect|Mood=Ind|Number=Sing|Person=3|Polarity=$polarity|Tense=Imp|VerbForm=Fin|Voice=Act";
    }
    elsif($suffix eq 'tiechu')
    {
        $f[4] = "V--P---3I-${p}A---";
        $f[5] = "Aspect=$aspect|Mood=Ind|Number=Plur|Person=3|Polarity=$polarity|Tense=Imp|VerbForm=Fin|Voice=Act";
    }
    elsif($suffix eq 'tějte')
    {
        $f[4] = "Vi-P---2--${p}----";
        $f[5] = "Aspect=$aspect|Mood=Imp|Number=Plur|Person=2|Polarity=$polarity|VerbForm=Fin";
    }
    elsif($suffix =~ m/^těla$/i)
    {
        # Příčestí na -la je předvyplněno nejednoznačně jako Fem Sing | Neut Plur, ale v našich datech je "chtěla" vždy Fem Sing.
        $f[4] = "VpFS---XR-${p}A---";
        $f[5] = "Aspect=$aspect|Gender=Fem|Number=Sing|Polarity=$polarity|Tense=Past|VerbForm=Part|Voice=Act";
    }
    elsif($suffix =~ m/^těl[oi]?$/i)
    {
        unless($f[5] =~ m/Aspect/)
        {
            unless($f[5] =~ s/^(Animacy=(?:Anim|Inan))/$1\|Aspect=$aspect/)
            {
                $f[5] = "Aspect=$aspect|$f[5]";
            }
        }
    }
    # Přípona -tě může být přechodník přítomný mužský, nebo aorist sigmatický ve 3. osobě singuláru.
    # V našich datech jsou všechny výskyty "chtě" přechodníky a všechny výskyty "zechtě" aoristy.
    elsif($suffix eq 'tě')
    {
        if($prefix)
        {
            $f[4] = "V--S---3A-${p}A---";
            $f[5] = "Aspect=$aspect|Mood=Ind|Number=Sing|Person=3|Polarity=$polarity|Tense=Past|Variant=Long|VerbForm=Fin|Voice=Act";
        }
        else
        {
            $f[4] = "VeYS------${p}----";
            $f[5] = "Aspect=$aspect|Gender=Masc|Number=Sing|Polarity=$polarity|Tense=Pres|VerbForm=Conv|Voice=Act";
        }
    }
    elsif($suffix eq 'tieci')
    {
        $f[4] = "VeFS------${p}----";
        $f[5] = "Aspect=$aspect|Gender=Fem|Number=Sing|Polarity=$polarity|Tense=Pres|VerbForm=Conv|Voice=Act";
    }
    elsif($suffix =~ m/^tiece?$/i)
    {
        $f[4] = "VeXP------${p}----";
        $f[5] = "Aspect=$aspect|Number=Plur|Polarity=$polarity|Tense=Pres|VerbForm=Conv|Voice=Act";
    }
    return @f;
}



#------------------------------------------------------------------------------
# Podle tvarů upraví anotaci tvarů slovesa jít a sloves od něj odvozených
# předponami (odejít, přijít atd.) Volá se za podmínky, že už víme, že
# to jeden z těch tvarů je, takže některé společné anotace můžeme udělat na
# začátku bez dalšího ptaní.
#------------------------------------------------------------------------------
sub opravit_sloveso_jit
{
    my $negprefix = shift;
    my $prefix = shift;
    my $suffix = shift;
    my @f = @_;
    my $polarity = 'Pos';
    my $p = 'A';
    my $prefix1300 = '';
    if($negprefix)
    {
        $polarity = 'Neg';
        $p = 'N';
    }
    # Imperativ "jdi, jděta, jděte" vs. "poď, poďta, poďte".
    if($prefix eq 'po' && $suffix =~ m/^ď/)
    {
        # Tvářit se, jako kdyby tam prefix nebyl, tj. lemma je "jít" a vid je nedokonavý.
        $prefix = '';
    }
    # Nedokonavý prézens ("jdu") vs. futurum ("pójdu", "puojdu").
    my $tense = 'Pres';
    my $t = 'P';
    if($prefix =~ s/^(pó|puo)$//)
    {
        $tense = 'Fut';
        $t = 'F';
    }
    elsif($prefix =~ m/^o[dt]/)
    {
        # Sjednotit "od" vs. "ot".
        $prefix = 'ode';
        $prefix1300 = 'ote';
    }
    else
    {
        $prefix =~ s/^přě/pře/;
        $prefix =~ s/^(před|roz|s|v|vz)$/${1}e/;
        $prefix1300 = $prefix;
    }
    $f[2] = $prefix.'jít';
    $f[9] = set_lemma1300($f[9], $prefix1300.'jíti');
    $f[3] = 'VERB';
    my $aspect = $prefix ? 'Perf' : 'Imp';
    if($suffix =~ m/^jíti?$/i)
    {
        $f[4] = "Vf--------${p}----";
        $f[5] = "Aspect=$aspect|Polarity=$polarity|VerbForm=Inf";
    }
    elsif($suffix eq 'jdu')
    {
        $f[4] = "VB-S---1${t}-${p}A---";
        $f[5] = "Aspect=$aspect|Mood=Ind|Number=Sing|Person=1|Polarity=$polarity|Tense=$tense|VerbForm=Fin|Voice=Act";
    }
    elsif($suffix eq 'jdeš')
    {
        $f[4] = "VB-S---2${t}-${p}A---";
        $f[5] = "Aspect=$aspect|Mood=Ind|Number=Sing|Person=2|Polarity=$polarity|Tense=$tense|VerbForm=Fin|Voice=Act";
    }
    elsif($suffix eq 'jde')
    {
        $f[4] = "VB-S---3${t}-${p}A---";
        $f[5] = "Aspect=$aspect|Mood=Ind|Number=Sing|Person=3|Polarity=$polarity|Tense=$tense|VerbForm=Fin|Voice=Act";
    }
    elsif($suffix =~ m/^jdem[eť]?$/i)
    {
        $f[4] = "VB-P---1${t}-${p}A---";
        $f[5] = "Aspect=$aspect|Mood=Ind|Number=Plur|Person=1|Polarity=$polarity|Tense=$tense|VerbForm=Fin|Voice=Act";
    }
    elsif($suffix eq 'jdete')
    {
        $f[4] = "VB-P---2${t}-${p}A---";
        $f[5] = "Aspect=$aspect|Mood=Ind|Number=Plur|Person=2|Polarity=$polarity|Tense=$tense|VerbForm=Fin|Voice=Act";
    }
    elsif($suffix eq 'jdú')
    {
        $f[4] = "VB-P---3${t}-${p}A---";
        $f[5] = "Aspect=$aspect|Mood=Ind|Number=Plur|Person=3|Polarity=$polarity|Tense=$tense|VerbForm=Fin|Voice=Act";
    }
    elsif($suffix eq 'jdieše')
    {
        $f[4] = "V--S---3I-${p}A---";
        $f[5] = "Aspect=$aspect|Mood=Ind|Number=Sing|Person=3|Polarity=$polarity|Tense=Imp|VerbForm=Fin|Voice=Act";
    }
    elsif($suffix eq 'jdiešta')
    {
        $f[4] = "V--D---3I-${p}A---";
        $f[5] = "Aspect=$aspect|Mood=Ind|Number=Dual|Person=3|Polarity=$polarity|Tense=Imp|VerbForm=Fin|Voice=Act";
    }
    elsif($suffix eq 'jdiechu')
    {
        $f[4] = "V--P---3I-${p}A---";
        $f[5] = "Aspect=$aspect|Mood=Ind|Number=Plur|Person=3|Polarity=$polarity|Tense=Imp|VerbForm=Fin|Voice=Act";
    }
    elsif($suffix eq 'jide')
    {
        $f[4] = "V--S---3A-${p}A---";
        $f[5] = "Aspect=$aspect|Mood=Ind|Number=Sing|Person=3|Polarity=$polarity|Tense=Past|Variant=Short|VerbForm=Fin|Voice=Act";
    }
    elsif($suffix =~ m/^jide[sš]ta$/i)
    {
        $f[4] = "V--D---3A-${p}A---";
        $f[5] = "Aspect=$aspect|Mood=Ind|Number=Dual|Person=3|Polarity=$polarity|Tense=Past|Variant=Long|VerbForm=Fin|Voice=Act";
    }
    elsif($suffix eq 'jidechu')
    {
        # Aorist sigmatický.
        $f[4] = "V--P---3A-${p}A---";
        $f[5] = "Aspect=$aspect|Mood=Ind|Number=Plur|Person=3|Polarity=$polarity|Tense=Past|Variant=Long|VerbForm=Fin|Voice=Act";
    }
    elsif($suffix eq 'jidú')
    {
        # Aorist asigmatický.
        $f[4] = "V--P---3A-${p}A---";
        $f[5] = "Aspect=$aspect|Mood=Ind|Number=Plur|Person=3|Polarity=$polarity|Tense=Past|Variant=Short|VerbForm=Fin|Voice=Act";
    }
    elsif($suffix =~ m/^(j?diž?|ď)$/i)
    {
        $f[4] = "Vi-S---2--${p}----";
        $f[5] = "Aspect=$aspect|Mood=Imp|Number=Sing|Person=2|Polarity=$polarity|VerbForm=Fin";
    }
    elsif($suffix =~ m/^(jděta|ďta)$/i)
    {
        $f[4] = "Vi-D---2--${p}----";
        $f[5] = "Aspect=$aspect|Mood=Imp|Number=Dual|Person=2|Polarity=$polarity|VerbForm=Fin";
    }
    elsif($suffix =~ m/^(jděme|ďm[ey])$/i)
    {
        $f[4] = "Vi-P---1--${p}----";
        $f[5] = "Aspect=$aspect|Mood=Imp|Number=Plur|Person=1|Polarity=$polarity|VerbForm=Fin";
    }
    elsif($suffix =~ m/^(jděte|ďte)$/i)
    {
        $f[4] = "Vi-P---2--${p}----";
        $f[5] = "Aspect=$aspect|Mood=Imp|Number=Plur|Person=2|Polarity=$polarity|VerbForm=Fin";
    }
    elsif($suffix =~ m/^šla$/i)
    {
        # Dual (obvykle Masc, jednou Masc+Fem): Dr. 1.18: sta sě sešla; Dr. 9.32: dva slepcě... když jsta pryč otešla; Dr. 11.4: odpovězta Janovi, co jsta slyšala i viděla; Ol. 8.28: ta biešta vyšla z hrobóv
        if(get_ref($f[9]) =~ m/^MATT_(1\.18|9\.32|11\.4|8\.28)$/)
        {
            $f[4] = "VpMD---XR-${p}A---";
            $f[5] = "Animacy=Anim|Aspect=$aspect|Gender=Masc|Number=Dual|Polarity=$polarity|Tense=Past|VerbForm=Part|Voice=Act";
        }
        else
        {
            $f[4] = "VpFS---XR-${p}A---";
            $f[5] = "Aspect=$aspect|Gender=Fem|Number=Sing|Polarity=$polarity|Tense=Past|VerbForm=Part|Voice=Act";
        }
    }
    elsif($suffix =~ m/^(šel|šl[oi])$/i)
    {
        unless($f[5] =~ m/Aspect/)
        {
            unless($f[5] =~ s/^(Animacy=(?:Anim|Inan))/$1\|Aspect=$aspect/)
            {
                $f[5] = "Aspect=$aspect|$f[5]";
            }
        }
    }
    # Ve staré češtině je společný tvar přechodníku v singuláru pro Masc a Neut, zatímco Fem má odlišný tvar.
    # Tím se stará čeština liší od nové, kde má Masc samostatný tvar, zatímco Fem a Neut mají společný tvar.
    # Příklad věty, kde "mužský" tvar přechodníku figuroval ve větě s podmětem v neutru: "tehdy jedno kniežě přistúpiv, pokloni sě jemu řka..."
    elsif($suffix eq 'jda')
    {
        $f[4] = "VeYS------${p}----";
        $f[5] = "Aspect=$aspect|Gender=Masc|Number=Sing|Polarity=$polarity|Tense=Pres|VerbForm=Conv|Voice=Act";
    }
    elsif($suffix eq 'jdúci')
    {
        $f[4] = "VeFS------${p}----";
        $f[5] = "Aspect=$aspect|Gender=Fem|Number=Sing|Polarity=$polarity|Tense=Pres|VerbForm=Conv|Voice=Act";
    }
    elsif($suffix =~ m/^jdúce?$/i)
    {
        $f[4] = "VeXP------${p}----";
        $f[5] = "Aspect=$aspect|Number=Plur|Polarity=$polarity|Tense=Pres|VerbForm=Conv|Voice=Act";
    }
    elsif($suffix eq 'šed')
    {
        $f[4] = "VmYS------${p}----";
        $f[5] = "Aspect=$aspect|Gender=Masc|Number=Sing|Polarity=$polarity|Tense=Past|VerbForm=Conv|Voice=Act";
    }
    elsif($suffix eq 'šedši')
    {
        $f[4] = "VmFS------${p}----";
        $f[5] = "Aspect=$aspect|Gender=Fem|Number=Sing|Polarity=$polarity|Tense=Past|VerbForm=Conv|Voice=Act";
    }
    elsif($suffix eq 'šedše')
    {
        # Problém: Ve verši 9.31 jde sice o dva slepce, ale pouze v Drážďanské bibli se o nich mluví v duálu, zatímco v Olomoucké už je tady plurál.
        # To neumím rozlišit pomocí reference z MISC. Potřeboval bych sent_id (biblol-mt-kapitola-9-vers-31), ale to tady nemám k dispozici.
        if(get_ref($f[9]) =~ m/^MATT_(9\.31|21\.6)$/)
        {
            $f[4] = "VmXD------${p}----";
            $f[5] = "Aspect=$aspect|Number=Dual|Polarity=$polarity|Tense=Past|VerbForm=Conv|Voice=Act";
        }
        else
        {
            $f[4] = "VmXP------${p}----";
            $f[5] = "Aspect=$aspect|Number=Plur|Polarity=$polarity|Tense=Past|VerbForm=Conv|Voice=Act";
        }
    }
    return @f;
}



#------------------------------------------------------------------------------
# Podle tvarů upraví anotaci tvarů slovesa jmout a sloves od něj odvozených
# předponami (odejmout, přijmout atd.) Volá se za podmínky, že už víme, že
# to jeden z těch tvarů je, takže některé společné anotace můžeme udělat na
# začátku bez dalšího ptaní.
#------------------------------------------------------------------------------
sub opravit_sloveso_jmout
{
    my $negprefix = shift;
    my $prefix = shift;
    my $suffix = shift;
    my @f = @_;
    my $polarity = 'Pos';
    my $p = 'A';
    my $prefix1300 = '';
    if($negprefix)
    {
        $polarity = 'Neg';
        $p = 'N';
    }
    if($prefix =~ m/^o[dt]/)
    {
        # Sjednotit "od" vs. "ot".
        $prefix = 'ode';
        $prefix1300 = 'ote';
    }
    else
    {
        $prefix =~ s/^přě/pře/;
        $prefix =~ s/^(před|roz|s|v|vz)$/${1}e/;
        $prefix1300 = $prefix;
    }
    $f[2] = $prefix.'jmout';
    $f[9] = set_lemma1300($f[9], $prefix1300.'jieti');
    $f[3] = 'VERB';
    # Tady je asi dokonavé i bezprefixové "jmout".
    my $aspect = 'Perf';
    if($suffix =~ m/^jieti?$/i)
    {
        $f[4] = "Vf--------${p}----";
        $f[5] = "Aspect=$aspect|Polarity=$polarity|VerbForm=Inf";
    }
    elsif($suffix eq 'jmu')
    {
        $f[4] = "VB-S---1P-${p}A---";
        $f[5] = "Aspect=$aspect|Mood=Ind|Number=Sing|Person=1|Polarity=$polarity|Tense=Pres|VerbForm=Fin|Voice=Act";
    }
    elsif($suffix eq 'jmeš')
    {
        $f[4] = "VB-S---2P-${p}A---";
        $f[5] = "Aspect=$aspect|Mood=Ind|Number=Sing|Person=2|Polarity=$polarity|Tense=Pres|VerbForm=Fin|Voice=Act";
    }
    elsif($suffix eq 'jme')
    {
        $f[4] = "VB-S---3P-${p}A---";
        $f[5] = "Aspect=$aspect|Mood=Ind|Number=Sing|Person=3|Polarity=$polarity|Tense=Pres|VerbForm=Fin|Voice=Act";
    }
    elsif($suffix =~ m/^jmem[eť]?$/i)
    {
        $f[4] = "VB-P---1P-${p}A---";
        $f[5] = "Aspect=$aspect|Mood=Ind|Number=Plur|Person=1|Polarity=$polarity|Tense=Pres|VerbForm=Fin|Voice=Act";
    }
    elsif($suffix eq 'jmete')
    {
        $f[4] = "VB-P---2P-${p}A---";
        $f[5] = "Aspect=$aspect|Mood=Ind|Number=Plur|Person=2|Polarity=$polarity|Tense=Pres|VerbForm=Fin|Voice=Act";
    }
    elsif($suffix eq 'jmú')
    {
        $f[4] = "VB-P---3P-${p}A---";
        $f[5] = "Aspect=$aspect|Mood=Ind|Number=Plur|Person=3|Polarity=$polarity|Tense=Pres|VerbForm=Fin|Voice=Act";
    }
    # Bezprefixové "jě" je obvykle zájmeno (takže s ním do této funkce nelézt), ale může se vyskytnout i s prefixem ("pojě").
    # A v několika verších to ve skutečnosti je aorist i bez prefixu (prověřit, než sem vlezeme).
    # Podobně "je" je normálně zájmeno, ale v Drážďanské bibli v 9.33 je to aorist: "A když vyhna z něho běsa, je sě mluviti němý."
    # Buď jde o chybu přepisu, nebo o počátek ztráty jať po j ve staré češtině.
    elsif($suffix =~ m/^j[ěe]$/i)
    {
        $f[4] = "V--S---3A-${p}A---";
        $f[5] = "Aspect=$aspect|Mood=Ind|Number=Sing|Person=3|Polarity=$polarity|Tense=Past|Variant=Long|VerbForm=Fin|Voice=Act";
    }
    # Bezprefixové "jěchu" může být také aorist od "jíst". Než vlezeme do této funkce, měli bychom prověřit, který je to verš.
    elsif($suffix eq 'jěchu')
    {
        # Aorist sigmatický.
        $f[4] = "V--P---3A-${p}A---";
        $f[5] = "Aspect=$aspect|Mood=Ind|Number=Plur|Person=3|Polarity=$polarity|Tense=Past|Variant=Long|VerbForm=Fin|Voice=Act";
    }
    elsif($suffix =~ m/^jmiž?$/i)
    {
        $f[4] = "Vi-S---2--${p}----";
        $f[5] = "Aspect=$aspect|Mood=Imp|Number=Sing|Person=2|Polarity=$polarity|VerbForm=Fin";
    }
    elsif($suffix =~ m/^jmětež?$/i)
    {
        $f[4] = "Vi-P---2--${p}----";
        $f[5] = "Aspect=$aspect|Mood=Imp|Number=Plur|Person=2|Polarity=$polarity|VerbForm=Fin";
    }
    elsif($suffix =~ m/^jala$/i)
    {
        # V našich datech se nevyskytuje ani jaku Dual, ani jako Neut Plur.
        $f[4] = "VpFS---XR-${p}A---";
        $f[5] = "Aspect=$aspect|Gender=Fem|Number=Sing|Polarity=$polarity|Tense=Past|VerbForm=Part|Voice=Act";
    }
    elsif($suffix =~ m/^(jal[oi]?)$/i)
    {
        unless($f[5] =~ m/Aspect/)
        {
            unless($f[5] =~ s/^(Animacy=(?:Anim|Inan))/$1\|Aspect=$aspect/)
            {
                $f[5] = "Aspect=$aspect|$f[5]";
            }
        }
    }
    # Ve staré češtině je společný tvar přechodníku v singuláru pro Masc a Neut, zatímco Fem má odlišný tvar.
    # Tím se stará čeština liší od nové, kde má Masc samostatný tvar, zatímco Fem a Neut mají společný tvar.
    # Příklad věty, kde "mužský" tvar přechodníku figuroval ve větě s podmětem v neutru: "tehdy jedno kniežě přistúpiv, pokloni sě jemu řka..."
    elsif($suffix eq 'jem')
    {
        $f[4] = "VmYS------${p}----";
        $f[5] = "Aspect=$aspect|Gender=Masc|Number=Sing|Polarity=$polarity|Tense=Past|VerbForm=Conv|Voice=Act";
    }
    elsif($suffix eq 'jemši')
    {
        $f[4] = "VmFS------${p}----";
        $f[5] = "Aspect=$aspect|Gender=Fem|Number=Sing|Polarity=$polarity|Tense=Past|VerbForm=Conv|Voice=Act";
    }
    else # jemše
    {
        $f[4] = "VmXP------${p}----";
        $f[5] = "Aspect=$aspect|Number=Plur|Polarity=$polarity|Tense=Past|VerbForm=Conv|Voice=Act";
    }
    return @f;
}



#------------------------------------------------------------------------------
# Podle tvarů upraví anotaci tvarů slovesa mít. Volá se za podmínky, že už
# víme, že to jeden z těch tvarů je, takže některé společné anotace můžeme
# udělat na začátku bez dalšího ptaní.
#------------------------------------------------------------------------------
sub opravit_sloveso_mit
{
    my $negprefix = shift;
    my $suffix = shift;
    my @f = @_;
    my $polarity = 'Pos';
    my $p = 'A';
    if($negprefix)
    {
        $polarity = 'Neg';
        $p = 'N';
    }
    if($suffix =~ m/^ajíciemu$/i)
    {
        # Adjektivní činné příčestí je vedeno jako ADJ, lemma je "mající".
        $f[2] = 'mající';
        $f[9] = set_lemma1300($f[9], 'jmající');
        $f[3] = 'ADJ';
    }
    else
    {
        $f[2] = 'mít';
        $f[9] = set_lemma1300($f[9], 'jmieti');
        $f[3] = 'VERB';
    }
    my $aspect = 'Imp';
    if($suffix eq 'ieti')
    {
        $f[4] = "Vf--------${p}----";
        $f[5] = "Aspect=Imp|Polarity=$polarity|VerbForm=Inf";
    }
    elsif($suffix eq 'ám')
    {
        $f[4] = "VB-S---1P-${p}A---";
        $f[5] = "Aspect=$aspect|Mood=Ind|Number=Sing|Person=1|Polarity=$polarity|Tense=Pres|VerbForm=Fin|Voice=Act";
    }
    elsif($suffix eq 'áš')
    {
        $f[4] = "VB-S---2P-${p}A---";
        $f[5] = "Aspect=$aspect|Mood=Ind|Number=Sing|Person=2|Polarity=$polarity|Tense=Pres|VerbForm=Fin|Voice=Act";
    }
    elsif($suffix eq 'á')
    {
        $f[4] = "VB-S---3P-${p}A---";
        $f[5] = "Aspect=$aspect|Mood=Ind|Number=Sing|Person=3|Polarity=$polarity|Tense=Pres|VerbForm=Fin|Voice=Act";
    }
    elsif($suffix eq 'áme')
    {
        $f[4] = "VB-P---1P-${p}A---";
        $f[5] = "Aspect=$aspect|Mood=Ind|Number=Plur|Person=1|Polarity=$polarity|Tense=Pres|VerbForm=Fin|Voice=Act";
    }
    elsif($suffix eq 'áte')
    {
        $f[4] = "VB-P---2P-${p}A---";
        $f[5] = "Aspect=$aspect|Mood=Ind|Number=Plur|Person=2|Polarity=$polarity|Tense=Pres|VerbForm=Fin|Voice=Act";
    }
    elsif($suffix eq 'ají')
    {
        $f[4] = "VB-P---3P-${p}A---";
        $f[5] = "Aspect=$aspect|Mood=Ind|Number=Plur|Person=3|Polarity=$polarity|Tense=Pres|VerbForm=Fin|Voice=Act";
    }
    elsif($suffix eq 'ějieše')
    {
        $f[4] = "V--S---3I-${p}A---";
        $f[5] = "Aspect=$aspect|Mood=Ind|Number=Sing|Person=3|Polarity=$polarity|Tense=Imp|VerbForm=Fin|Voice=Act";
    }
    elsif($suffix eq 'ějiešta')
    {
        $f[4] = "V--D---3I-${p}A---";
        $f[5] = "Aspect=$aspect|Mood=Ind|Number=Dual|Person=3|Polarity=$polarity|Tense=Imp|VerbForm=Fin|Voice=Act";
    }
    elsif($suffix =~ m/^ě(jie)?chu$/i)
    {
        $f[4] = "V--P---3I-${p}A---";
        $f[5] = "Aspect=$aspect|Mood=Ind|Number=Plur|Person=3|Polarity=$polarity|Tense=Imp|VerbForm=Fin|Voice=Act";
    }
    elsif($suffix eq 'ěj')
    {
        $f[4] = "Vi-S---2--${p}----";
        $f[5] = "Aspect=$aspect|Mood=Imp|Number=Sing|Person=2|Polarity=$polarity|VerbForm=Fin";
    }
    elsif($suffix eq 'ějte')
    {
        $f[4] = "Vi-P---2--${p}----";
        $f[5] = "Aspect=$aspect|Mood=Imp|Number=Plur|Person=2|Polarity=$polarity|VerbForm=Fin";
    }
    elsif($suffix =~ m/^ěl[aoi]?$/i)
    {
        unless($f[5] =~ m/Aspect/)
        {
            unless($f[5] =~ s/^(Animacy=(?:Anim|Inan))/$1\|Aspect=$aspect/)
            {
                $f[5] = "Aspect=$aspect|$f[5]";
            }
        }
    }
    elsif($suffix =~ m/^aj[eě]$/i)
    {
        $f[4] = "VeYS------${p}----";
        $f[5] = "Aspect=$aspect|Gender=Masc|Number=Sing|Polarity=$polarity|Tense=Pres|VerbForm=Conv|Voice=Act";
    }
    # Jediný výskyt "jmajíc" je v Olomoucké bibli v 18.9, kde jde spíš o singulár (i když rod není jasný).
    elsif($suffix =~ m/^ajíci?$/i)
    {
        $f[4] = "VeFS------${p}----";
        $f[5] = "Aspect=$aspect|Gender=Fem|Number=Sing|Polarity=$polarity|Tense=Pres|VerbForm=Conv|Voice=Act";
    }
    # Výskyty v Drážďanské bibli v 9.32, 12.22 a 8.16 by odpovídaly akuzativu, ale pád u přechodníků nakonec neoznačujeme.
    # Nicméně první dva z těchto výskytů jsou navíc v singuláru.
    elsif($suffix =~ m/^ajíce$/i)
    {
        my $ref = get_ref($f[9]);
        if($ref =~ m/^MATT_(9\.32|12\.22)$/)
        {
            $f[4] = "VeMS------${p}----";
            $f[5] = "Aspect=$aspect|Gender=Masc|Number=Sing|Polarity=$polarity|Tense=Pres|VerbForm=Conv|Voice=Act";
        }
        elsif($ref =~ m/^MATT_8\.28$/)
        {
            $f[4] = "VeXD------${p}----";
            $f[5] = "Aspect=$aspect|Number=Dual|Polarity=$polarity|Tense=Pres|VerbForm=Conv|Voice=Act";
        }
        else
        {
            $f[4] = "VeXP------${p}----";
            $f[5] = "Aspect=$aspect|Number=Plur|Polarity=$polarity|Tense=Pres|VerbForm=Conv|Voice=Act";
        }
    }
    elsif($suffix =~ m/^ajíciemu$/i)
    {
        # Adjektivní činné příčestí je vedeno jako ADJ, lemma je "mající".
        $f[4] = "AGMS3-----${p}----";
        $f[5] = "Animacy=Anim|Aspect=$aspect|Case=Dat|Gender=Masc|Number=Sing|Polarity=$polarity|Tense=Pres|VerbForm=Part|Voice=Act";
    }
    return @f;
}



#------------------------------------------------------------------------------
# Podle tvarů upraví anotaci tvarů slovesa nerodit. Volá se za podmínky, že už
# víme, že to jeden z těch tvarů je, takže některé společné anotace můžeme
# udělat na začátku bez dalšího ptaní.
# Sloveso "neroditi" je sice negativní a bude mít Polarity=Neg, ale jeho lemma
# je "nerodit" a kladný tvar neexistuje. Od slovesa "rodit" se liší významem i
# valencí, odpovídá spíš slovesu "neráčit". Sloveso "rodit" se ovšem v našich
# datech nevyskytuje, takže záměna nehrozí (jsou tam pouze odvozená "narodit",
# "porodit", "urodit" a "zarodit"(?)).
#------------------------------------------------------------------------------
sub opravit_sloveso_nerodit
{
    my $negprefix = shift;
    my $prefix = shift;
    my $suffix = shift;
    my @f = @_;
    my $polarity = 'Neg';
    my $p = 'N';
    if(!$negprefix)
    {
        confess("U slovesa 'nerodit' očekávám negativní prefix");
    }
    $f[2] = 'nerodit';
    $f[9] = set_lemma1300($f[9], 'neroditi');
    $f[3] = 'VERB';
    my $aspect = 'Imp';
    if($suffix eq 'die')
    {
        $f[4] = "VB-P---3P-${p}A---";
        $f[5] = "Aspect=$aspect|Mood=Ind|Number=Plur|Person=3|Polarity=$polarity|Tense=Pres|VerbForm=Fin|Voice=Act";
    }
    elsif($suffix eq 'di')
    {
        $f[4] = "V--S---3A-${p}A---";
        $f[5] = "Aspect=$aspect|Mood=Ind|Number=Sing|Person=3|Polarity=$polarity|Tense=Past|Variant=Long|VerbForm=Fin|Voice=Act";
    }
    elsif($suffix eq 'ď')
    {
        $f[4] = "Vi-S---2--${p}----";
        $f[5] = "Aspect=$aspect|Mood=Imp|Number=Sing|Person=2|Polarity=$polarity|VerbForm=Fin";
    }
    elsif($suffix eq 'ďte')
    {
        $f[4] = "Vi-P---2--${p}----";
        $f[5] = "Aspect=$aspect|Mood=Imp|Number=Plur|Person=2|Polarity=$polarity|VerbForm=Fin";
    }
    elsif($suffix eq 'dil')
    {
        $f[4] = "VpYS---XR-${p}A---";
        $f[5] = "Aspect=$aspect|Gender=Masc|Number=Sing|Polarity=$polarity|Tense=Past|VerbForm=Part|Voice=Act";
    }
    elsif($suffix eq 'dieci')
    {
        $f[4] = "VeFS------${p}----";
        $f[5] = "Aspect=$aspect|Gender=Fem|Number=Sing|Polarity=$polarity|Tense=Pres|VerbForm=Conv|Voice=Act";
    }
    return @f;
}



#------------------------------------------------------------------------------
# Podle tvarů upraví anotaci tvarů slovesa povědět a sloves od něj odvozených
# předponami (odpovědět, předpovědět atd.) Volá se za podmínky, že už víme, že
# to jeden z těch tvarů je, takže některé společné anotace můžeme udělat na
# začátku bez dalšího ptaní.
#------------------------------------------------------------------------------
sub opravit_sloveso_povedet
{
    my $negprefix = shift;
    my $prefix = shift;
    my $suffix = shift;
    my @f = @_;
    my $polarity = 'Pos';
    my $p = 'A';
    my $prefix1300 = '';
    if($negprefix)
    {
        $polarity = 'Neg';
        $p = 'N';
    }
    if($prefix =~ m/^o/)
    {
        # Sjednotit "od" vs. "ot".
        $prefix = 'od';
        $prefix1300 = 'ot';
    }
    else
    {
        $prefix1300 = $prefix;
    }
    if($suffix =~ m/^ěděn[aoi]?$/i)
    {
        # Trpné příčestí je vedeno jako ADJ, lemma je "pověděný".
        $f[2] = $prefix.'pověděný';
        $f[9] = set_lemma1300($f[9], $prefix1300.'pověděný');
        $f[3] = 'ADJ';
    }
    else
    {
        $f[2] = $prefix.'povědět';
        $f[9] = set_lemma1300($f[9], $prefix1300.'pověděti');
        $f[3] = 'VERB';
    }
    my $aspect = 'Perf';
    if($suffix eq 'ěděti')
    {
        $f[4] = "Vf--------${p}----";
        $f[5] = "Aspect=$aspect|Polarity=$polarity|VerbForm=Inf";
    }
    elsif($suffix eq 'iem')
    {
        $f[4] = "VB-S---1P-${p}A---";
        $f[5] = "Aspect=$aspect|Mood=Ind|Number=Sing|Person=1|Polarity=$polarity|Tense=Pres|VerbForm=Fin|Voice=Act";
    }
    elsif($suffix eq 'ieš')
    {
        $f[4] = "VB-S---2P-${p}A---";
        $f[5] = "Aspect=$aspect|Mood=Ind|Number=Sing|Person=2|Polarity=$polarity|Tense=Pres|VerbForm=Fin|Voice=Act";
    }
    elsif($suffix eq 'ie')
    {
        # Zdá se, že "povie" může být jak přítomný, tak minulý čas, ale to neumíme deterministicky určit
        # a tagging těchto tvarů byl tak jako tak špatně, takže nastavíme prozatím vždy přítomný čas.
        $f[4] = "VB-S---3P-${p}A---";
        $f[5] = "Aspect=$aspect|Mood=Ind|Number=Sing|Person=3|Polarity=$polarity|Tense=Pres|VerbForm=Fin|Voice=Act";
    }
    elsif($suffix eq 'iete')
    {
        $f[4] = "VB-P---2P-${p}A---";
        $f[5] = "Aspect=$aspect|Mood=Ind|Number=Plur|Person=2|Polarity=$polarity|Tense=Pres|VerbForm=Fin|Voice=Act";
    }
    elsif($suffix eq 'ědie')
    {
        $f[4] = "VB-P---3P-${p}A---";
        $f[5] = "Aspect=$aspect|Mood=Ind|Number=Plur|Person=3|Polarity=$polarity|Tense=Pres|VerbForm=Fin|Voice=Act";
    }
    elsif($suffix eq 'ědě')
    {
        if(get_ref($f[9]) =~ m/^MATT_21\.2[47]$/)
        {
            $f[4] = "VB-S---1P-${p}A---";
            $f[5] = "Aspect=$aspect|Mood=Ind|Number=Sing|Person=1|Polarity=$polarity|Tense=Pres|VerbForm=Fin|Voice=Act";
        }
        else
        {
            $f[4] = "V--S---3A-${p}A---";
            $f[5] = "Aspect=$aspect|Mood=Ind|Number=Sing|Person=3|Polarity=$polarity|Tense=Past|Variant=Long|VerbForm=Fin|Voice=Act";
        }
    }
    elsif($suffix =~ m/^ědě[šs]ta$/i)
    {
        $f[4] = "V--D---3A-${p}A---";
        $f[5] = "Aspect=$aspect|Mood=Ind|Number=Dual|Person=3|Polarity=$polarity|Tense=Past|Variant=Long|VerbForm=Fin|Voice=Act";
    }
    elsif($suffix eq 'ěděchu')
    {
        $f[4] = "V--P---3A-${p}A---";
        $f[5] = "Aspect=$aspect|Mood=Ind|Number=Plur|Person=3|Polarity=$polarity|Tense=Past|Variant=Long|VerbForm=Fin|Voice=Act";
    }
    elsif($suffix eq 'ěz')
    {
        # Mohl by to být i imperativ pro 3. osobu, ale to neumíme poznat, výchozí je 2. osoba.
        $f[4] = "Vi-S---2--${p}----";
        $f[5] = "Aspect=$aspect|Mood=Imp|Number=Sing|Person=2|Polarity=$polarity|VerbForm=Fin";
    }
    elsif($suffix eq 'ězta')
    {
        $f[4] = "Vi-D---2--${p}----";
        $f[5] = "Aspect=$aspect|Mood=Imp|Number=Dual|Person=2|Polarity=$polarity|VerbForm=Fin";
    }
    elsif($suffix =~ m/^ěztež?$/i)
    {
        $f[4] = "Vi-P---2--${p}----";
        $f[5] = "Aspect=$aspect|Mood=Imp|Number=Plur|Person=2|Polarity=$polarity|VerbForm=Fin";
    }
    elsif($suffix =~ m/^ěděl[aoi]?$/i)
    {
        unless($f[5] =~ m/Aspect/)
        {
            unless($f[5] =~ s/^(Animacy=(?:Anim|Inan))/$1\|Aspect=$aspect/)
            {
                $f[5] = "Aspect=$aspect|$f[5]";
            }
        }
    }
    elsif($suffix eq 'ěda')
    {
        $f[4] = "VeYS------${p}----";
        $f[5] = "Aspect=$aspect|Gender=Masc|Number=Sing|Polarity=$polarity|Tense=Pres|VerbForm=Conv|Voice=Act";
    }
    elsif($suffix eq 'ěděv')
    {
        $f[4] = "VmYS------${p}----";
        $f[5] = "Aspect=$aspect|Gender=Masc|Number=Sing|Polarity=$polarity|Tense=Past|VerbForm=Conv|Voice=Act";
    }
    elsif($suffix eq 'ěděvše')
    {
        $f[4] = "VmXP------${p}----";
        $f[5] = "Aspect=$aspect|Number=Plur|Polarity=$polarity|Tense=Past|VerbForm=Conv|Voice=Act";
    }
    elsif($suffix =~ m/^ěděn[aoi]?$/i)
    {
        # Trpné příčestí je vedeno jako ADJ, lemma je "pověděný".
        unless($f[5] =~ m/Aspect/)
        {
            unless($f[5] =~ s/^(Animacy=(?:Anim|Inan))/$1\|Aspect=$aspect/)
            {
                $f[5] = "Aspect=$aspect|$f[5]";
            }
        }
    }
    return @f;
}



#------------------------------------------------------------------------------
# Podle tvarů upraví anotaci tvarů slovesa říci. Volá se za podmínky, že už
# víme, že to jeden z těch tvarů je, takže některé společné anotace můžeme
# udělat na začátku bez dalšího ptaní.
#------------------------------------------------------------------------------
sub opravit_sloveso_rici
{
    my $negprefix = shift;
    my $prefix = shift;
    my $suffix = shift;
    my @f = @_;
    my $polarity = 'Pos';
    my $p = 'A';
    my $prefix1300 = '';
    if($negprefix)
    {
        $polarity = 'Neg';
        $p = 'N';
    }
    if($prefix =~ m/^o/)
    {
        # Sjednotit "od" vs. "ot".
        $prefix = 'od';
        $prefix1300 = 'ot';
    }
    else
    {
        $prefix1300 = $prefix;
    }
    if($suffix =~ m/^ečen[aoi]?$/i)
    {
        # Trpné příčestí je vedeno jako ADJ, lemma je "řečený".
        $f[2] = $prefix.'řečený';
        $f[9] = set_lemma1300($f[9], $prefix1300.'řečený');
        $f[3] = 'ADJ';
    }
    else
    {
        $f[2] = $prefix.'říci';
        $f[9] = set_lemma1300($f[9], $prefix1300.'řéci');
        $f[3] = 'VERB';
    }
    my $aspect = 'Perf';
    if($suffix eq 'éci')
    {
        $f[4] = "Vf--------${p}----";
        $f[5] = "Aspect=$aspect|Polarity=$polarity|VerbForm=Inf";
    }
    elsif($suffix eq 'ku')
    {
        $f[4] = "VB-S---1P-${p}A---";
        $f[5] = "Aspect=$aspect|Mood=Ind|Number=Sing|Person=1|Polarity=$polarity|Tense=Pres|VerbForm=Fin|Voice=Act";
    }
    elsif($suffix eq 'kú')
    {
        $f[4] = "VB-P---3P-${p}A---";
        $f[5] = "Aspect=$aspect|Mood=Ind|Number=Plur|Person=3|Polarity=$polarity|Tense=Pres|VerbForm=Fin|Voice=Act";
    }
    elsif($suffix eq 'ečechu')
    {
        $f[4] = "V--P---3A-${p}A---";
        $f[5] = "Aspect=$aspect|Mood=Ind|Number=Plur|Person=3|Polarity=$polarity|Tense=Past|Variant=Long|VerbForm=Fin|Voice=Act";
    }
    elsif($suffix eq 'ci')
    {
        $f[4] = "Vi-S---2--${p}----";
        $f[5] = "Aspect=$aspect|Mood=Imp|Number=Sing|Person=2|Polarity=$polarity|VerbForm=Fin";
    }
    elsif($suffix =~ m/^cětež?$/i)
    {
        $f[4] = "Vi-P---2--${p}----";
        $f[5] = "Aspect=$aspect|Mood=Imp|Number=Plur|Person=2|Polarity=$polarity|VerbForm=Fin";
    }
    elsif($suffix =~ m/^ekl[aoi]?$/i)
    {
        unless($f[5] =~ m/Aspect/)
        {
            unless($f[5] =~ s/^(Animacy=(?:Anim|Inan))/$1\|Aspect=$aspect/)
            {
                $f[5] = "Aspect=$aspect|$f[5]";
            }
        }
    }
    # Ve staré češtině je společný tvar přechodníku v singuláru pro Masc a Neut, zatímco Fem má odlišný tvar.
    # Tím se stará čeština liší od nové, kde má Masc samostatný tvar, zatímco Fem a Neut mají společný tvar.
    # Příklad věty, kde "mužský" tvar přechodníku figuroval ve větě s podmětem v neutru: "tehdy jedno kniežě přistúpiv, pokloni sě jemu řka..."
    elsif($suffix eq 'ka')
    {
        if(get_ref($f[9]) =~ m/^MATT_(9\.18|21\.10|26\.65)$/) # reference jsou podle Drážďanské bible
        {
            $f[4] = "VeNS------${p}----";
            $f[5] = "Aspect=$aspect|Gender=Neut|Number=Sing|Polarity=$polarity|Tense=Pres|VerbForm=Conv|Voice=Act";
        }
        else
        {
            $f[4] = "VeYS------${p}----";
            $f[5] = "Aspect=$aspect|Gender=Masc|Number=Sing|Polarity=$polarity|Tense=Pres|VerbForm=Conv|Voice=Act";
        }
    }
    elsif($suffix eq 'kúci')
    {
        $f[4] = "VeFS------${p}----";
        $f[5] = "Aspect=$aspect|Gender=Fem|Number=Sing|Polarity=$polarity|Tense=Pres|VerbForm=Conv|Voice=Act";
    }
    elsif($suffix =~ m/^kúce?$/i)
    {
        $f[4] = "VeXP------${p}----";
        $f[5] = "Aspect=$aspect|Number=Plur|Polarity=$polarity|Tense=Pres|VerbForm=Conv|Voice=Act";
    }
    elsif($suffix eq 'ekše')
    {
        $f[4] = "VmXP------${p}----";
        $f[5] = "Aspect=$aspect|Number=Plur|Polarity=$polarity|Tense=Past|VerbForm=Conv|Voice=Act";
    }
    elsif($suffix =~ m/^ečen[aoi]?$/i)
    {
        # Trpné příčestí je vedeno jako ADJ, lemma je "pověděný".
        unless($f[5] =~ m/Aspect/)
        {
            unless($f[5] =~ s/^(Animacy=(?:Anim|Inan))/$1\|Aspect=$aspect/)
            {
                $f[5] = "Aspect=$aspect|$f[5]";
            }
        }
    }
    return @f;
}



#------------------------------------------------------------------------------
# Podle tvarů upraví anotaci tvarů slovesa vecěti. Volá se za podmínky, že už
# víme, že to jeden z těch tvarů je, takže některé společné anotace můžeme
# udělat na začátku bez dalšího ptaní.
#------------------------------------------------------------------------------
sub opravit_sloveso_vecet
{
    my $negprefix = shift;
    my $prefix = shift;
    my $suffix = shift;
    my @f = @_;
    my $polarity = 'Pos';
    my $p = 'A';
    my $prefix1300 = '';
    if($negprefix)
    {
        $polarity = 'Neg';
        $p = 'N';
    }
    if($prefix =~ m/^o/)
    {
        # Sjednotit "od" vs. "ot".
        $prefix = 'od';
        $prefix1300 = 'ot';
    }
    else
    {
        $prefix1300 = $prefix;
    }
    $f[2] = $prefix.'vecet';
    $f[9] = set_lemma1300($f[9], $prefix1300.'vecěti');
    $f[3] = 'VERB';
    if($suffix eq 'šta')
    {
        $f[4] = "V--D---3A-${p}A---";
        $f[5] = "Aspect=Imp|Mood=Ind|Number=Dual|Person=3|Polarity=$polarity|Tense=Past|Variant=Long|VerbForm=Fin|Voice=Act";
    }
    elsif($suffix eq 'chu')
    {
        $f[4] = "V--P---3A-${p}A---";
        $f[5] = "Aspect=Imp|Mood=Ind|Number=Plur|Person=3|Polarity=$polarity|Tense=Past|Variant=Long|VerbForm=Fin|Voice=Act";
    }
    else # vecě
    {
        $f[4] = "V--S---3A-${p}A---";
        $f[5] = "Aspect=Imp|Mood=Ind|Number=Sing|Person=3|Polarity=$polarity|Tense=Past|Variant=Long|VerbForm=Fin|Voice=Act";
    }
    return @f;
}



#------------------------------------------------------------------------------
# Podle tvarů upraví anotaci tvarů slovesa zřít. Volá se za podmínky, že už
# víme, že to jeden z těch tvarů je, takže některé společné anotace můžeme
# udělat na začátku bez dalšího ptaní.
#------------------------------------------------------------------------------
sub opravit_sloveso_zrit
{
    my $negprefix = shift;
    my $prefix = shift;
    my $suffix = shift;
    my @f = @_;
    my $polarity = 'Pos';
    my $p = 'A';
    my $prefix1300 = '';
    if($negprefix)
    {
        $polarity = 'Neg';
        $p = 'N';
    }
    if($prefix =~ m/^o/)
    {
        # Sjednotit "od" vs. "ot".
        $prefix = 'od';
        $prefix1300 = 'ot';
    }
    else
    {
        $prefix1300 = $prefix;
    }
    $f[2] = $prefix.'zřít';
    $f[9] = set_lemma1300($f[9], $prefix1300.'zřieti');
    $f[3] = 'VERB';
    my $aspect = $prefix ? 'Perf' : 'Imp';
    if($suffix eq 'í')
    {
        $f[4] = "VB-S---3P-${p}A---";
        $f[5] = "Aspect=$aspect|Mood=Ind|Number=Sing|Person=3|Polarity=$polarity|Tense=Pres|VerbForm=Fin|Voice=Act";
    }
    elsif($suffix eq 'íme')
    {
        $f[4] = "VB-P---1P-${p}A---";
        $f[5] = "Aspect=$aspect|Mood=Ind|Number=Plur|Person=1|Polarity=$polarity|Tense=Pres|VerbForm=Fin|Voice=Act";
    }
    elsif($suffix eq 'íte')
    {
        $f[4] = "VB-P---2P-${p}A---";
        $f[5] = "Aspect=$aspect|Mood=Ind|Number=Plur|Person=2|Polarity=$polarity|Tense=Pres|VerbForm=Fin|Voice=Act";
    }
    elsif($suffix eq 'ie')
    {
        $f[4] = "VB-P---3P-${p}A---";
        $f[5] = "Aspect=$aspect|Mood=Ind|Number=Plur|Person=3|Polarity=$polarity|Tense=Pres|VerbForm=Fin|Voice=Act";
    }
    elsif($suffix eq 'ě')
    {
        $f[4] = "V--S---3A-${p}A---";
        $f[5] = "Aspect=$aspect|Mood=Ind|Number=Sing|Person=3|Polarity=$polarity|Tense=Past|Variant=Long|VerbForm=Fin|Voice=Act";
    }
    elsif($suffix eq 'ěsta')
    {
        $f[4] = "V--D---3A-${p}A---";
        $f[5] = "Aspect=$aspect|Mood=Ind|Number=Dual|Person=3|Polarity=$polarity|Tense=Past|Variant=Long|VerbForm=Fin|Voice=Act";
    }
    elsif($suffix =~ m/^[eě]chu$/i)
    {
        $f[4] = "V--P---3A-${p}A---";
        $f[5] = "Aspect=$aspect|Mood=Ind|Number=Plur|Person=3|Polarity=$polarity|Tense=Past|Variant=Long|VerbForm=Fin|Voice=Act";
    }
    elsif($suffix eq 'ěte')
    {
        $f[4] = "Vi-P---2--${p}----";
        $f[5] = "Aspect=$aspect|Mood=Imp|Number=Plur|Person=2|Polarity=$polarity|VerbForm=Fin";
    }
    elsif($suffix eq 'ěl')
    {
        $f[4] = "VpYS---XR-${p}A---";
        $f[5] = "Aspect=$aspect|Gender=Masc|Number=Sing|Polarity=$polarity|Tense=Past|VerbForm=Part|Voice=Act";
    }
    # Ve staré češtině je společný tvar přechodníku v singuláru pro Masc a Neut, zatímco Fem má odlišný tvar.
    # Tím se stará čeština liší od nové, kde má Masc samostatný tvar, zatímco Fem a Neut mají společný tvar.
    # Příklad věty, kde "mužský" tvar přechodníku figuroval ve větě s podmětem v neutru: "tehdy jedno kniežě přistúpiv, pokloni sě jemu řka..."
    elsif($suffix eq 'ěv')
    {
        $f[4] = "VmYS------${p}----";
        $f[5] = "Aspect=$aspect|Gender=Masc|Number=Sing|Polarity=$polarity|Tense=Past|VerbForm=Conv|Voice=Act";
    }
    elsif($suffix eq 'ěvše')
    {
        $f[4] = "VmXP------${p}----";
        $f[5] = "Aspect=$aspect|Number=Plur|Polarity=$polarity|Tense=Past|VerbForm=Conv|Voice=Act";
    }
    return @f;
}



#------------------------------------------------------------------------------
# Podle tvarů upraví anotaci zájmen. Zájmena jsou uzavřená třída, takže jejich
# tvary můžeme vyjmenovat. Problém je s některými tvary, které mohou mít
# několik čtení, ale naštěstí jich není moc. Abychom omezili škody na dalších
# slovech, voláme tuto funkci uvnitř podmínky, že UPOS je PRON, DET nebo NOUN
# (to poslední proto, že některé neznámé tvary, např. "tebú" a "sebú", jsou
# označkované jako substantiva). Má to ale nevýhodu, že zde nemůžeme řešit
# některé tvary, které UDPipe mohl považovat za jiné slovní druhy, např. za
# slovesa. Ty tedy musíme vyřešit předem, než zavoláme tuto funkci.
#------------------------------------------------------------------------------
sub opravit_zajmena
{
    my @f = @_;
    my %feats; map {if(m/^(.+?)=(.+)$/) {$feats{$1} = $2}} (split(/\|/, $f[5]));
    # Slova "ty" a "ti" mohou být buď ukazovací zájmena (DET), nebo osobní zájmena ve 2. osobě singuláru (PRON).
    # Zde neumíme rozhodnout, která interpretace je správně, budeme se tedy držet úsudku UDPipu a zkontrolujeme jen zbývající rysy.
    if($f[1] =~ m/^(ty|ti)$/i)
    {
        if($f[3] eq 'DET' || $feats{PronType} eq 'Dem')
        {
            $f[2] = 'ten';
            $f[9] = set_lemma1300($f[9], 'ten');
            $f[3] = 'DET';
            $feats{PronType} = 'Dem';
            delete($feats{Person});
            $feats{Number} = 'Plur';
            delete($feats{Poss});
            delete($feats{Reflex});
            delete($feats{Polarity});
            my $g = substr($f[4], 2, 1);
            my $c = substr($f[4], 4, 1);
            # V množném čísle rozlišujeme rod a pád podle kontextu.
            # Pokud jsme z UDPipe žádný rod nedostali, ale je to nominativ a tvar je "ty", tipneme si ženský rod.
            ###!!! Ale jak tak koukám, všechny případy, kterých se to týká, měly ve skutečnosti být označkovány jako osobní zájmeno "ty".
            if($f[1] =~ m/^ty$/i && $feats{Gender} eq '' && $feats{Case} eq 'Nom')
            {
                $feats{Gender} = 'Fem';
                $g = 'F';
            }
            $f[4] = "PD${g}P${c}----------";
        }
        else # PRON nebo NOUN, ale má být PRON
        {
            $f[2] = 'ty';
            $f[9] = set_lemma1300($f[9], 'ty');
            $f[3] = 'PRON';
            $feats{PronType} = 'Prs';
            $feats{Person} = 2;
            $feats{Number} = 'Sing';
            delete($feats{Poss});
            delete($feats{Reflex});
            delete($feats{Gender});
            delete($feats{Animacy});
            delete($feats{PrepCase});
            delete($feats{Polarity});
            my $c = substr($f[4], 4, 1);
            my $v = 'P';
            if($f[1] =~ m/^ti$/i)
            {
                $v = 'H';
                $feats{Variant} = 'Short';
            }
            else
            {
                delete($feats{Variant});
            }
            $f[4] = "P${v}-S${c}--2-------";
        }
    }
    # Slova "ona", "ono", "oni", "ony" mohou být buď tvary ukazovacího zájmena (DET) "onen", nebo může jít o tvary osobního zájmena "on" (PRON).
    # Zde neumíme rozhodnout, která interpretace je správně, budeme se tedy držet úsudku UDPipu a zkontrolujeme jen zbývající rysy.
    elsif($f[1] =~ m/^(ona|ono|oni|ony)$/)
    {
        if($f[3] eq 'DET')
        {
            $f[2] = 'onen';
            $f[9] = set_lemma1300($f[9], 'onen');
            $f[3] = 'DET';
            $feats{PronType} = 'Dem';
            delete($feats{Person});
            delete($feats{Reflex});
            delete($feats{Poss});
            delete($feats{Polarity});
            my $g = substr($f[4], 2, 1);
            my $n = substr($f[4], 3, 1);
            my $c = substr($f[4], 4, 1);
            if($f[1] =~ m/^ono$/i)
            {
                $feats{Gender} = 'Neut';
                $g = 'N';
                $feats{Number} = 'Sing';
                $n = 'S';
            }
            # "ona" se vyskytlo vždy jako osobní zájmeno a nikdy jako "onen".
            elsif($f[1] =~ m/^(oni|ony)$/i)
            {
                $feats{Number} = 'Plur';
                $n = 'P';
            }
            $f[4] = "PD${g}${n}${c}----------";
        }
        else # PRON nebo NOUN, ale má být PRON
        {
            $f[2] = 'on';
            $f[9] = set_lemma1300($f[9], 'on');
            $f[3] = 'PRON';
            $feats{PronType} = 'Prs';
            $feats{Person} = 3;
            delete($feats{Reflex});
            delete($feats{Poss});
            delete($feats{Animacy});
            delete($feats{Polarity});
            my $g = substr($f[4], 2, 1);
            my $n = substr($f[4], 3, 1);
            if($f[1] =~ m/^ono$/i)
            {
                $feats{Gender} = 'Neut';
                $g = 'N';
                $feats{Number} = 'Sing';
                $n = 'S';
            }
            # "ona" může být singulár (fem.), duál (asi všechny rody) i plurál (neut.)
            # Dr. 4.20: "ona jidesta po něm" ... Dual Masc Anim Nom; totéž 4.22, 9.31, 11.7, 20.31, 20.33
            # Dr. 5.32: "ona cizoloží" ... Sing Fem Nom; totéž 12.11, 14.8, 15.25, 15.27, Ol. 1.25, 14.8, 15.25, 15.27, 20.21
            elsif($f[1] =~ m/^ona$/i)
            {
                if(get_ref($f[9]) =~ m/^MATT_(4\.20|4\.22|9\.31|11\.7|20\.31|20\.33)$/)
                {
                    $feats{Gender} = 'Masc';
                    $feats{Animacy} = 'Anim';
                    $g = 'M';
                    $feats{Number} = 'Dual';
                    $n = 'D';
                }
                else
                {
                    $feats{Number} = 'Sing';
                    $n = 'S';
                }
            }
            elsif($f[1] =~ m/^(oni|ony)$/i)
            {
                $feats{Number} = 'Plur';
                $n = 'P';
            }
            $feats{Case} = 'Nom';
            $f[4] = "PP${g}${n}1--3-------";
        }
        # Žádným tvarům nenechat Style=Arch, protože UDPipe se řídí 20. stoletím, ale ve 14. století to archaické nebylo.
        delete($feats{Style});
        delete($feats{Variant});
    }
    # Slova "jeho" a "jich" mohou být buď přivlastňovací zájmena (DET) před vlastněným substantivem, nebo může jít o genitiv zájmena "on" (PRON).
    # Podobně slovo "jehožto" může být vztažné přivlastňovací zájmeno (DET), nebo genitiv či akuzativ vztažného zájmena "jenžto"  (PRON).
    # Zde neumíme rozhodnout, která interpretace je správně, budeme se tedy držet úsudku UDPipu a zkontrolujeme jen zbývající rysy.
    elsif($f[1] =~ m/^(jeho|jich|jehožto)$/i)
    {
        if($f[3] eq 'DET' && get_ref($f[9]) !~ m/^MATT_(2\.16|3\.15|4\.5|4\.8)$/)
        {
            # UDPipe prakticky vždy analyzuje "jich" jako genitiv osobního zájmena (PRON), takže se tady k němu spíš nedostaneme.
            $f[2] = 'jeho';
            $f[9] = set_lemma1300($f[9], 'jeho');
            $feats{PronType} = 'Prs';
            $feats{Person} = 3;
            delete($feats{Reflex});
            $feats{Poss} = 'Yes';
            delete($feats{Gender});
            delete($feats{Animacy});
            delete($feats{Number});
            delete($feats{Case});
            delete($feats{Polarity});
            if($f[1] =~ m/^jeho$/i)
            {
                $feats{'Gender[psor]'} = 'Masc,Neut';
                $feats{'Number[psor]'} = 'Sing';
                $f[4] = 'PSXXXZS3-------';
            }
            elsif($f[1] =~ m/^jich$/i)
            {
                delete($feats{'Gender[psor]'});
                $feats{'Number[psor]'} = 'Plur';
                $f[4] = 'PSXXXXP3-------';
            }
            else # jehožto
            {
                # "ten, jehožto nejsem duostojen obuvi nésti"
                $f[2] = 'jehožto';
                $feats{PronType} = 'Rel';
                $feats{'Gender[psor]'} = 'Masc,Neut';
                $feats{'Number[psor]'} = 'Sing';
                $f[4] = 'P1XXXZS3-------';
            }
        }
        else # PRON nebo NOUN, ale má být PRON
        {
            # UDPipe prakticky vždy analyzuje "jeho" jako přivlastňovací zájmeno (DET), takže se tady k němu spíš nedostaneme.
            $f[2] = 'on';
            $f[9] = set_lemma1300($f[9], 'on');
            $f[3] = 'PRON';
            $feats{PronType} = 'Prs';
            $feats{Person} = 3;
            $feats{PrepCase} = 'Npr';
            delete($feats{Reflex});
            delete($feats{Poss});
            delete($feats{Animacy});
            delete($feats{Polarity});
            my $g = substr($f[4], 2, 1);
            my $n = substr($f[4], 3, 1);
            my $c = substr($f[4], 4, 1);
            if($f[1] =~ m/^jeho$/i)
            {
                $feats{Gender} = 'Masc,Neut';
                $g = 'Z';
                $feats{Number} = 'Sing';
                $n = 'S';
                # Zájmeno "jeho" může být kromě genitivu i akuzativ ("zabieme jeho").
                $feats{Case} = 'Gen' if($feats{Case} !~ m/^(Gen|Acc)$/);
                $c = '2' if($c !~ m/^[24]$/);
            }
            elsif($f[1] =~ m/^jich$/i)
            {
                delete($feats{Gender});
                $g = 'X';
                $feats{Number} = 'Plur';
                $n = 'P';
                $feats{Case} = 'Gen';
                $c = '2';
            }
            else # jehožto
            {
                $f[2] = 'jenžto';
                $feats{PronType} = 'Rel';
                delete($feats{Person});
                $feats{Gender} = 'Masc,Neut';
                $g = 'Z';
                $feats{Number} = 'Sing';
                $n = 'S';
                $f[4] = 'PJZS2----------';
                # Zájmeno "jehožto" může být kromě genitivu i akuzativ.
                # Genitiv: "do toho dne, jehožto jest Noe všel v koráb"
                # Akuzativ: "muoj syn zmilelý, jehožto jsem sobě oblíbil"
                $feats{Case} = 'Gen' if($feats{Case} !~ m/^(Gen|Acc)$/);
                $c = '2' if($c !~ m/^[24]$/);
            }
            delete($feats{'Gender[psor]'});
            delete($feats{'Number[psor]'});
            delete($feats{PrepCase});
            $f[4] = "PP${g}${n}${c}--3-------";
        }
        # Žádným tvarům nenechat Style=Arch, protože UDPipe se řídí 20. stoletím, ale ve 14. století to archaické nebylo.
        delete($feats{Style});
        delete($feats{Variant});
    }
    # UDPipe považuje za tvar zájmena "já" i ojedinělé výskyty "mnie" a "mní", ale to zřejmě vůbec nejsou zájmena. Spíše jde o tvary slovesa "mnieti" (nevím, co znamená, možná "mínit").
    elsif($f[1] =~ m/^(já|mne|mně|mi|mě|mnú)$/i)
    {
        $f[2] = 'já';
        $f[9] = set_lemma1300($f[9], 'já');
        $f[3] = 'PRON';
        $feats{PronType} = 'Prs';
        $feats{Person} = 1;
        $feats{Number} = 'Sing';
        # Tvar "mnú" je instrumentál.
        if($f[1] =~ m/^mnú$/i)
        {
            $feats{Case} = 'Ins';
        }
        if($f[1] =~ m/^(mi|mě)$/)
        {
            $feats{Variant} = 'Short';
        }
        else
        {
            delete($feats{Variant});
        }
        keep_features(\%feats, 'PronType', 'Person', 'Number', 'Case', 'Variant');
        $f[4] = uposf_to_xpos($f[3], \%feats);
    }
    elsif($f[1] =~ m/^(náma)$/i)
    {
        $f[2] = 'já';
        $f[9] = set_lemma1300($f[9], 'já');
        $f[3] = 'PRON';
        $feats{PronType} = 'Prs';
        $feats{Person} = 1;
        $feats{Number} = 'Dual';
        keep_features(\%feats, 'PronType', 'Person', 'Number', 'Case');
        $f[4] = uposf_to_xpos($f[3], \%feats);
    }
    elsif($f[1] =~ m/^(my|nás|nám|ny|námi)$/i)
    {
        $f[2] = 'já';
        $f[9] = set_lemma1300($f[9], 'já');
        $f[3] = 'PRON';
        $feats{PronType} = 'Prs';
        $feats{Person} = 1;
        $feats{Number} = 'Plur';
        # Tvar "ny" je akuzativ.
        if($f[1] =~ m/^ny$/i)
        {
            $feats{Case} = 'Acc';
        }
        keep_features(\%feats, 'PronType', 'Person', 'Number', 'Case');
        $f[4] = uposf_to_xpos($f[3], \%feats);
    }
    # Zájmena "ty" a "ti" už jsme chytli výše, zde jsou vyjmenována pro úplnost, ale neuplatní se.
    # 2. osoba singuláru je vzácná a UDPipe ji často plete.
    elsif($f[1] =~ m/^(ty|tebe|tobě|ti|tě|tebú|tobú)$/i)
    {
        $f[2] = 'ty';
        $f[9] = set_lemma1300($f[9], 'ty');
        $f[3] = 'PRON';
        $feats{PronType} = 'Prs';
        $feats{Person} = 2;
        $feats{Number} = 'Sing';
        # Tvar "tobě" může být dativ nebo lokativ, ale ne nominativ, genitiv ani akuzativ.
        if($f[1] =~ m/^tobě$/i && $feats{Case} =~ m/^(Nom|Gen|Acc|Voc|Ins)$/)
        {
            # Nevíme, jestli je to dativ, nebo lokativ. Odhadneme dativ.
            $feats{Case} = 'Dat';
        }
        # Tvar "tebú" resp. "tobú" je instrumentál.
        elsif($f[1] =~ m/^(tebú|tobú)$/i)
        {
            $feats{Case} = 'Ins';
        }
        if($f[1] =~ m/^(ti|tě)$/)
        {
            $feats{Variant} = 'Short';
        }
        else
        {
            delete($feats{Variant});
        }
        keep_features(\%feats, 'PronType', 'Person', 'Number', 'Case', 'Variant');
        $f[4] = uposf_to_xpos($f[3], \%feats);
    }
    elsif($f[1] =~ m/^(váma)$/i)
    {
        $f[2] = 'ty';
        $f[9] = set_lemma1300($f[9], 'ty');
        $f[3] = 'PRON';
        $feats{PronType} = 'Prs';
        $feats{Person} = 2;
        $feats{Number} = 'Dual';
        keep_features(\%feats, 'PronType', 'Person', 'Number', 'Case');
        $f[4] = uposf_to_xpos($f[3], \%feats);
    }
    elsif($f[1] =~ m/^(vy|vás|vám|vámi)$/i)
    {
        $f[2] = 'ty';
        $f[9] = set_lemma1300($f[9], 'ty');
        $f[3] = 'PRON';
        $feats{PronType} = 'Prs';
        $feats{Person} = 2;
        $feats{Number} = 'Plur';
        keep_features(\%feats, 'PronType', 'Person', 'Number', 'Case');
        $f[4] = uposf_to_xpos($f[3], \%feats);
    }
    # Zájmena "ona", "ono", "oni" a "ony" už jsme chytli výše, zde jsou vyjmenována pro úplnost, ale neuplatní se.
    # Zájmena "jeho" a "jich" už jsme chytli výše, zde jsou vyjmenována pro úplnost, ale neuplatní se.
    elsif($f[1] =~ m/^(on|ona|ono|oni|ony|jeho|něho|jí|ní|jemu|němu|ňemu|jiej|niej|jej|něj|je|ně|ji|ju|ni|jie|nie|něm|ňem|jím|ním|jú|jima|nima|jich|nich|jim|nim|jě|jimi|nimi)$/i)
    {
        $f[2] = 'on';
        $f[9] = set_lemma1300($f[9], 'on');
        $f[3] = 'PRON';
        $feats{PronType} = 'Prs';
        $feats{Person} = 3;
        delete($feats{Animacy}); # obnovíme pro vybrané tvary, pro ostatní necháme vymazáno
        if($f[1] =~ m/^on$/i)
        {
            $feats{Gender} = 'Masc';
        }
        elsif($f[1] =~ m/^oni$/i)
        {
            $feats{Gender} = 'Masc';
            $feats{Animacy} = 'Anim';
        }
        elsif($f[1] =~ m/^(jeho|něho|jemu|němu|ňemu|jej|něj|něm|ňem|jím|ním)$/i)
        {
            $feats{Gender} = 'Masc,Neut';
        }
        # "je" je akuzativ singuláru neutra (ale občas se chybně plete se 3. osobou slovesa "být")
        # V plurálu se místo "je" používalo "jě".
        # Naproti tomu "ně" může být singulár neutra, ale taky duál nebo plurál.
        elsif($f[1] =~ m/^(ono|je)$/i)
        {
            $feats{Gender} = 'Neut';
        }
        elsif($f[1] =~ m/^(jí|ní|jiej|niej|ji|ju|ni|jie|nie)$/i)
        {
            $feats{Gender} = 'Fem';
        }
        # V duálu a plurálu lze rozlišit rod pouze v nominativu, a to ještě jen omezeně.
        elsif($f[1] =~ m/^(jima|nima|jich|nich|jim|nim|jě|jimi|nimi)$/i)
        {
            delete($feats{Gender});
        }
        # "ona" může být singulár (fem.), duál (asi všechny rody) i plurál (neut.)
        if($f[1] =~ m/^(on|ono|jeho|něho|jí|ní|jemu|němu|ňemu|jiej|niej|jej|něj|je|ji|ju|ni|jie|nie|něm|ňem|jím|ním|jú)$/i)
        {
            $feats{Number} = 'Sing';
        }
        elsif($f[1] =~ m/^(jima|nima)$/i)
        {
            $feats{Number} = 'Dual';
        }
        # Mám podezření, že některé tvary ("jich", "nich", "jě") by mohly být i duál, ale nejsem si jistý a příklady duálu jsou vzácné, tak to zatím nechávám být.
        elsif($f[1] =~ m/^(oni|ony|jich|nich|jim|nim|jě|jimi|nimi)$/i)
        {
            $feats{Number} = 'Plur';
        }
        if($f[1] =~ m/^(on|ona|ono|oni|ony)$/i)
        {
            $feats{Case} = 'Nom';
        }
        # Zájmena "jeho" a "jich" jsme vyřešili zvlášť, protože mohou být také přivlastňovací (DET).
        # Zájmeno "něho" může být kromě genitivu také akuzativ. Zájmeno "nich" může být genitiv nebo lokativ.
        elsif($f[1] =~ m/^něho$/i && $feats{Case} !~ m/^(Gen|Acc)$/)
        {
            $feats{Case} = 'Gen';
        }
        # "jiej" je dativ (s výjimkou Dr. 5.28, kde je to genitiv), "niej" může být dativ nebo lokativ (častěji lokativ).
        elsif($f[1] =~ m/^jiej$/i && $feats{Case} !~ m/^(Dat|Gen)$/)
        {
            $feats{Case} = 'Dat';
        }
        elsif($f[1] =~ m/^(je|ně|ji|ju|ni|jie|nie|jě)$/i)
        {
            $feats{Case} = 'Acc';
        }
        # "jiej" je dativ, "niej" může být dativ nebo lokativ (častěji lokativ).
        elsif($f[1] =~ m/^niej$/i && $feats{Case} ne 'Dat')
        {
            $feats{Case} = 'Loc';
        }
        elsif($f[1] =~ m/^(jím|ním|jú|jimi|nimi)$/i)
        {
            $feats{Case} = 'Ins';
        }
        if($f[1] =~ m/^[nň]/i)
        {
            $feats{PrepCase} = 'Pre';
        }
        else
        {
            if($f[1] =~ m/^j/i)
            {
                $feats{PrepCase} = 'Npr';
            }
            else
            {
                delete($feats{PrepCase});
            }
        }
        keep_features(\%feats, 'PronType', 'Person', 'Gender', 'Animacy', 'Number', 'Case', 'PrepCase');
        $f[4] = uposf_to_xpos($f[3], \%feats);
    }
    # "se" jako zvratné zájmeno je velmi vzácné, většinou je to "sě"; z těch pár příkladů "se" jsou navíc větší část chyby UDPipu, kde mělo jít o předložku "s".
    # Naopak "sě" nemůže být předložka; kvůli takovým chybám jsme "sě" podchytili už výše, tady je uvedeno jen pro úplnost.
    # "si" se tehdy ještě nepoužívalo, používalo se "sobě" (a "si" naopak existovalo jako alternativní tvar "jsi", viz výše).
    elsif($f[1] =~ m/^(sě|se|sebe|sobě|sebú|sobú)$/i)
    {
        $f[2] = 'se';
        $f[9] = set_lemma1300($f[9], 'sě');
        $f[3] = 'PRON';
        $feats{PronType} = 'Prs';
        $feats{Reflex} = 'Yes';
        # Tvar "sebú" je instrumentál.
        if($f[1] =~ m/^(sebú|sobú)$/i)
        {
            $feats{Case} = 'Ins';
        }
        if($f[1] =~ m/^(sě|se)$/)
        {
            $feats{Variant} = 'Short';
        }
        else
        {
            delete($feats{Variant});
        }
        keep_features(\%feats, 'PronType', 'Reflex', 'Case', 'Variant');
        $f[4] = uposf_to_xpos($f[3], \%feats);
    }
    # Přivlastňovací zájmena (DET).
    elsif($f[1] =~ m/^(můj|muoj|mój|mého|mému|mém|mým|má|moje|mé|méj|mojí|mou|mú|moji|muoji|mýma|mí|mých|mým|mými|náš|našeho|našemu|našem|naším|naše|našě|naší|našiej|naši|našie|našich|našim|našimi)$/i)
    {
        $f[2] = 'můj';
        $f[9] = set_lemma1300($f[9], 'mój');
        $f[3] = 'DET';
        $feats{PronType} = 'Prs';
        $feats{Poss} = 'Yes';
        $feats{Person} = 1;
        if($f[1] =~ m/^m/i)
        {
            $feats{'Number[psor]'} = 'Sing';
        }
        else
        {
            $feats{'Number[psor]'} = 'Plur';
        }
        if($f[1] =~ m/ú$/i)
        {
            # This can be only Sing Fem Acc|Ins.
            $feats{Number} = 'Sing';
            $feats{Gender} = 'Fem';
            if($feats{Case} !~ m/^(Acc|Ins)$/)
            {
                $feats{Case} = 'Acc';
            }
        }
        elsif($f[1] =~ m/^(muoj|mój)$/i)
        {
            $feats{Gender} = 'Masc';
            $feats{Animacy} = 'Inan' unless($feats{Animacy});
            $feats{Number} = 'Sing';
            $feats{Case} = 'Nom' unless($feats{Case} =~ m/(Nom|Acc|Voc)/);
        }
        elsif($f[1] =~ m/^moji$/i)
        {
            # V našich datech: "bratřie moji" nebo "býci moji", vše v nominativu.
            $feats{Gender} = 'Masc';
            $feats{Animacy} = 'Anim';
            $feats{Number} = 'Plur';
            $feats{Case} = 'Nom';
        }
        keep_features(\%feats, 'PronType', 'Poss', 'Person', 'Number[psor]', 'Gender', 'Animacy', 'Number', 'Case');
        $f[4] = uposf_to_xpos($f[3], \%feats);
    }
    elsif($f[1] =~ m/^(tvůj|tvuoj|tvój|tvého|tvému|tvém|tvým|tvá|tvoje|tvé|tvéj|tvojí|tvou|tvú|tvoji|tvuoji|tvýma|tví|tvých|tvým|tvými|váš|vašeho|vašemu|vašem|vaším|vaše|vašě|vaší|vašiej|vaši|vašie|vašich|vašim|vašimi)$/i)
    {
        $f[2] = 'tvůj';
        $f[9] = set_lemma1300($f[9], 'tvój');
        $f[3] = 'DET';
        $feats{PronType} = 'Prs';
        $feats{Poss} = 'Yes';
        $feats{Person} = 2;
        if($f[1] =~ m/^t/i)
        {
            $feats{'Number[psor]'} = 'Sing';
        }
        else
        {
            $feats{'Number[psor]'} = 'Plur';
        }
        if($f[1] =~ m/ú$/i)
        {
            # This can be only Sing Fem Acc|Ins.
            $feats{Number} = 'Sing';
            $feats{Gender} = 'Fem';
            if($feats{Case} !~ m/^(Acc|Ins)$/)
            {
                $feats{Case} = 'Acc';
            }
        }
        elsif($f[1] =~ m/^tvuoji$/i)
        {
            # Drážďanská 9.2, 9.5: "odpuščeniť jsú tobě tvuoji hřieši" Masc Inan Plur Nom
            # Drážďanská 9.14: "tvuoji učedlníci nepostie sě" Masc Anim Plur Nom; 12.2, 15.1
            $feats{Gender} = 'Masc';
            $feats{Animacy} = get_ref($f[9]) =~ m/^MATT_9\.(2|5)$/ ? 'Inan' : 'Anim';
            $feats{Number} = 'Plur';
            $feats{Case} = 'Nom';
        }
        keep_features(\%feats, 'PronType', 'Poss', 'Person', 'Number[psor]', 'Gender', 'Animacy', 'Number', 'Case');
        $f[4] = uposf_to_xpos($f[3], \%feats);
    }
    # Zájmena "jeho" a "jich" už jsme zachytili výše.
    elsif($f[1] =~ m/^(její|jejího|jejímu|jejím|jejiem|jejie|jejiej|jejíma|jejích|jejími)$/i)
    {
        $f[2] = 'jeho';
        $f[9] = set_lemma1300($f[9], 'jeho');
        $f[3] = 'DET';
        $feats{PronType} = 'Prs';
        $feats{Poss} = 'Yes';
        $feats{Person} = 3;
        $feats{'Gender[psor]'} = 'Fem';
        $feats{'Number[psor]'} = 'Sing';
        if($f[1] =~ m/^jejiej$/i)
        {
            # Oba výskyty jsou v Drážďanské bibli, druhý je v 21.4.
            if(get_ref($f[9]) =~ m/^MATT_5\.32$/)
            {
                # kromě jejiej viny
                $feats{Gender} = 'Fem';
                $feats{Case} = 'Gen';
            }
            else
            {
                # na jejiej hřieběti
                $feats{Gender} = 'Neut';
                $feats{Case} = 'Loc';
            }
        }
        keep_features(\%feats, 'PronType', 'Poss', 'Person', 'Gender[psor]', 'Number[psor]', 'Gender', 'Animacy', 'Number', 'Case');
        $f[4] = uposf_to_xpos($f[3], \%feats);
    }
    elsif($f[1] =~ m/^(svůj|svuoj|svój|svého|svému|svém|svým|svá|svoje|své|svéj|svojí|svou|svú|svoji|svuoji|svýma|sví|svých|svým|svými)$/i)
    {
        $f[2] = 'svůj';
        $f[9] = set_lemma1300($f[9], 'svój');
        $f[3] = 'DET';
        $feats{PronType} = 'Prs';
        $feats{Reflex} = 'Yes';
        $feats{Poss} = 'Yes';
        if($f[1] =~ m/ú$/i)
        {
            # This can be only Sing Fem Acc|Ins.
            $feats{Number} = 'Sing';
            $feats{Gender} = 'Fem';
            if($feats{Case} !~ m/^(Acc|Ins)$/)
            {
                $feats{Case} = 'Acc';
            }
        }
        elsif($f[1] =~ m/^svuoji$/i)
        {
            # Drážďanská 17.8: "pak oni vzdvihše svuoji oči"
            $feats{Gender} = 'Neut';
            delete($feats{Animacy});
            $feats{Number} = 'Dual';
            $feats{Case} = 'Acc';
        }
        keep_features(\%feats, 'PronType', 'Reflex', 'Poss', 'Gender', 'Animacy', 'Number', 'Case');
        $f[4] = uposf_to_xpos($f[3], \%feats);
    }
    #------------------------------------------------------------------
    # Ukazovací zájmena.
    #------------------------------------------------------------------
    ###!!! Vyhodit (buď jde o ukazovací příslovce, nebo vůbec nejde o demonstrativa): toliko, tehda, móž, totě (má se chápat jako "toť", nebo jako "to je"?)
    # Zájmena "ti", "ty", "ona", "ono", "oni" a "ony" už byla podchycena výše, tady jsou vyjmenována jen pro úplnost.
    elsif($f[1] =~ m/^(ten|toho|tomu|tom|tím|ta|té|tej|tu|tou|tú|to|ti|ty|těch|těm|těmi)ť?$/i)
    {
        $f[2] = 'ten';
        $f[9] = set_lemma1300($f[9], 'ten');
        $f[3] = 'DET';
        $feats{PronType} = 'Dem';
        if($f[1] =~ m/^toť?$/i && $feats{Case} !~ m/^(Nom|Acc)$/)
        {
            $feats{Gender} = 'Neut';
            $feats{Number} = 'Sing';
            $feats{Case} = 'Nom';
        }
        keep_features(\%feats, 'PronType', 'Gender', 'Animacy', 'Number', 'Case');
        $f[4] = uposf_to_xpos($f[3], \%feats);
    }
    elsif($f[1] =~ m/^(tento|tohoto|tomuto|tomto|tímto|tiemto|tato|této|tejto|tuto|touto|túto|toto|tito|tyto|těchto|těmto|těmito)ť?$/i)
    {
        $f[2] = 'tento';
        $f[9] = set_lemma1300($f[9], 'tento');
        $f[3] = 'DET';
        $feats{PronType} = 'Dem';
        if($f[1] =~ m/^tuto$/i)
        {
            $feats{Gender} = 'Fem';
            $feats{Number} = 'Sing';
            $feats{Case} = 'Acc';
        }
        keep_features(\%feats, 'PronType', 'Gender', 'Animacy', 'Number', 'Case');
        $f[4] = uposf_to_xpos($f[3], \%feats);
    }
    elsif($f[1] =~ m/^(tamten|tamtoho|tamtomu|tamtom|tamtím|tamtiem|tamta|tamté|tamtej|tamtu|tamtou|tamtú|tamto|tamti|tamty|tamtěch|tamtěm|tamtěmi)ť?$/i)
    {
        $f[2] = 'tamten';
        $f[9] = set_lemma1300($f[9], 'tamten');
        $f[3] = 'DET';
        $feats{PronType} = 'Dem';
        keep_features(\%feats, 'PronType', 'Gender', 'Animacy', 'Number', 'Case');
        $f[4] = uposf_to_xpos($f[3], \%feats);
    }
    # Zájmena "ti", "ty", "ona", "ono", "oni" a "ony" už byla podchycena výše, tady jsou vyjmenována jen pro úplnost.
    elsif($f[1] =~ m/^u?(onen|onoho|onomu|onom|oním|ona|oné|onej|onu|onou|onú|ono|oni|ony|oněch|oněm|oněmi)ť?$/i)
    {
        $f[2] = 'onen';
        $f[9] = set_lemma1300($f[9], 'onen');
        $f[3] = 'DET';
        $feats{PronType} = 'Dem';
        keep_features(\%feats, 'PronType', 'Gender', 'Animacy', 'Number', 'Case');
        $f[4] = uposf_to_xpos($f[3], \%feats);
    }
    # V Olomoucké bibli je doložen tvar "onenno": "Tento na své vlastnie pole a onenno na své vlastnie dielo."
    elsif($f[1] =~ m/^(onen|onoho|onomu|onom|oním|ona|oné|onej|onu|onou|onú|ono|oni|ony|oněch|oněm|oněmi)no$/i)
    {
        $f[2] = 'onenno';
        $f[9] = set_lemma1300($f[9], 'onenno');
        $f[3] = 'DET';
        $feats{PronType} = 'Dem';
        keep_features(\%feats, 'PronType', 'Gender', 'Animacy', 'Number', 'Case');
        $f[4] = uposf_to_xpos($f[3], \%feats);
    }
    elsif($f[1] =~ m/^(takový|takového|takovému|takovém|takovým|taková|takové|takovej|takovou|takovú|takoví|takových|takovým|takovými)$/i)
    {
        $f[2] = 'takový';
        $f[9] = set_lemma1300($f[9], 'takový');
        $f[3] = 'DET';
        $feats{PronType} = 'Dem';
        keep_features(\%feats, 'PronType', 'Gender', 'Animacy', 'Number', 'Case');
        $f[4] = uposf_to_xpos($f[3], \%feats);
    }
    elsif($f[1] =~ m/^(taký|takého|takému|takém|takým|taká|také|takej|takou|takú|tací|takých|takým|takými)$/i)
    {
        $f[2] = 'taký';
        $f[9] = set_lemma1300($f[9], 'taký');
        $f[3] = 'DET';
        $feats{PronType} = 'Dem';
        keep_features(\%feats, 'PronType', 'Gender', 'Animacy', 'Number', 'Case');
        $f[4] = uposf_to_xpos($f[3], \%feats);
    }
    elsif($f[1] =~ m/^(taký|takého|takému|takém|takým|taká|také|takej|takou|takú|tací|takých|takým|takými)ž$/i)
    {
        $f[2] = 'takýž';
        $f[9] = set_lemma1300($f[9], 'takýž');
        $f[3] = 'DET';
        $feats{PronType} = 'Dem';
        keep_features(\%feats, 'PronType', 'Gender', 'Animacy', 'Number', 'Case');
        $f[4] = uposf_to_xpos($f[3], \%feats);
    }
    elsif($f[1] =~ m/^(týž|téhož|témuž|témž|týmž|táž|též|tejž|touž|túž|tíž|týchž|týmž|týmiž)$/i)
    {
        $f[2] = 'týž';
        $f[9] = set_lemma1300($f[9], 'týž');
        $f[3] = 'DET';
        $feats{PronType} = 'Dem';
        keep_features(\%feats, 'PronType', 'Gender', 'Animacy', 'Number', 'Case');
        $f[4] = uposf_to_xpos($f[3], \%feats);
    }
    elsif($f[1] =~ m/^(tentýž|tohotéž|tomutéž|tomtéž|tímtéž|tatáž|tetéž|tejtéž|tetejž|tutouž|tutúž|titíž)$/i)
    {
        $f[2] = 'tentýž';
        $f[9] = set_lemma1300($f[9], 'tentýž');
        $f[3] = 'DET';
        $feats{PronType} = 'Dem';
        keep_features(\%feats, 'PronType', 'Gender', 'Animacy', 'Number', 'Case');
        $f[4] = uposf_to_xpos($f[3], \%feats);
    }
    elsif($f[1] =~ m/^(sám|sama|samého|samu|samému|samém|samým|samé|samej|samou|samú|sami|samí|samých|samým|samými)ž$/i)
    {
        $f[2] = 'sám';
        $f[9] = set_lemma1300($f[9], 'sám');
        $f[3] = 'DET';
        $feats{PronType} = 'Emp';
        keep_features(\%feats, 'PronType', 'Gender', 'Animacy', 'Number', 'Case');
        $f[4] = uposf_to_xpos($f[3], \%feats);
    }
    #------------------------------------------------------------------
    # Vztažná zájmena.
    #------------------------------------------------------------------
    elsif($f[1] =~ m/^(kdo|kto|koho|komu|kom|kým)$/i)
    {
        $f[2] = 'kdo';
        $f[9] = set_lemma1300($f[9], 'kto');
        $f[3] = 'PRON';
        $feats{PronType} = 'Int,Rel';
        $feats{Gender} = 'Masc';
        $feats{Animacy} = 'Anim';
        if($f[1] =~ m/^(kdo|kto)$/i)
        {
            $feats{Case} = 'Nom';
        }
        keep_features(\%feats, 'PronType', 'Gender', 'Animacy', 'Case');
        $f[4] = uposf_to_xpos($f[3], \%feats);
    }
    elsif($f[1] =~ m/^(kdo|kto|koho|komu|kom|kým)ž$/i)
    {
        $f[2] = 'kdož';
        $f[9] = set_lemma1300($f[9], 'ktož');
        $f[3] = 'PRON';
        $feats{PronType} = 'Rel';
        $feats{Gender} = 'Masc';
        $feats{Animacy} = 'Anim';
        if($f[1] =~ m/^(kdo|kto)ž$/i)
        {
            $feats{Case} = 'Nom';
        }
        keep_features(\%feats, 'PronType', 'Gender', 'Animacy', 'Case');
        $f[4] = uposf_to_xpos($f[3], \%feats);
    }
    elsif($f[1] =~ m/^(co|čeho|čemu|čem|čím)$/i)
    {
        $f[2] = 'co';
        $f[9] = set_lemma1300($f[9], 'co');
        $f[3] = 'PRON';
        $feats{PronType} = 'Int,Rel';
        if($f[1] =~ m/^čemu$/i)
        {
            $feats{Case} = 'Dat';
        }
        keep_features(\%feats, 'PronType', 'Case');
        $f[4] = uposf_to_xpos($f[3], \%feats);
    }
    # Zájmeno "ješto" už bylo podchyceno výše, protože si ho UDPipe pletl i s jinými slovními druhy.
    # Zájmeno "jenž" už bylo podchyceno výše, protože si ho UDPipe pletl i s jinými slovními druhy.
    # Zájmeno "jehožto" už bylo podchyceno výše, zde ho uvádím jen pro úplnost.
    elsif($f[1] =~ m/^(jenž|jehož|něhož|jemuž|němuž|němž|jímž|nímž|j[eě]ž|jíž|níž|již|niž|jichž|nichž|jimž|nimž|jimiž|nimiž)to$/i)
    {
        $f[2] = 'jenžto';
        $f[9] = set_lemma1300($f[9], 'jenžto');
        $f[3] = 'PRON';
        $feats{PronType} = 'Rel';
        if($f[1] =~ m/^jenžto$/i)
        {
            $feats{Gender} = 'Masc';
            $feats{Number} = 'Sing';
            $feats{Case} = 'Nom';
        }
        elsif($f[1] =~ m/^jemužto$/i)
        {
            $feats{Gender} = 'Masc,Neut';
            $feats{Number} = 'Sing';
            $feats{Case} = 'Dat';
        }
        if($f[1] =~ m/^[nň]/)
        {
            $feats{PrepCase} = 'Pre';
        }
        else
        {
            $feats{PrepCase} = 'Npr';
        }
        keep_features(\%feats, 'PronType', 'Gender', 'Animacy', 'Number', 'Case', 'PrepCase');
        $f[4] = uposf_to_xpos($f[3], \%feats);
    }
    elsif($f[1] =~ m/^(jenž|jehož|něhož|jemuž|němuž|němž|jímž|nímž|jež|jíž|níž|již|niž|jichž|nichž|jimž|nimž|jimiž|nimiž)$/i)
    {
        $f[2] = 'jenž';
        $f[9] = set_lemma1300($f[9], 'jenž');
        $f[3] = 'PRON';
        $feats{PronType} = 'Rel';
        if($f[1] =~ m/^jenž$/i)
        {
            $feats{Gender} = 'Masc';
            $feats{Number} = 'Sing';
            $feats{Case} = 'Nom';
        }
        elsif($f[1] =~ m/^jemuž$/i)
        {
            $feats{Gender} = 'Masc,Neut';
            $feats{Number} = 'Sing';
            $feats{Case} = 'Dat';
        }
        if($f[1] =~ m/^[nň]/)
        {
            $feats{PrepCase} = 'Pre';
        }
        else
        {
            $feats{PrepCase} = 'Npr';
        }
        keep_features(\%feats, 'PronType', 'Gender', 'Animacy', 'Number', 'Case', 'PrepCase');
        $f[4] = uposf_to_xpos($f[3], \%feats);
    }
    elsif($f[1] =~ m/^(který|kterého|kterému|kterém|kterým|která|které|kterej|kterou|kterú|kteří|kterých|kterým|kterými)$/i)
    {
        $f[2] = 'který';
        $f[9] = set_lemma1300($f[9], 'který');
        $f[3] = 'DET';
        $feats{PronType} = 'Int,Rel';
        keep_features(\%feats, 'PronType', 'Gender', 'Animacy', 'Number', 'Case');
        $f[4] = uposf_to_xpos($f[3], \%feats);
    }
    elsif($f[1] =~ m/^(který|kterého|kterému|kterém|kterým|která|které|kterej|kterou|kterú|kteří|kterých|kterým|kterými)ž$/i)
    {
        $f[2] = 'kterýž';
        $f[9] = set_lemma1300($f[9], 'kterýž');
        $f[3] = 'DET';
        $feats{PronType} = 'Rel';
        if($f[1] =~ m/^kteříž$/i)
        {
            $feats{Gender} = 'Masc';
            $feats{Animacy} = 'Anim';
            $feats{Number} = 'Plur';
            $feats{Case} = 'Nom';
        }
        keep_features(\%feats, 'PronType', 'Gender', 'Animacy', 'Number', 'Case');
        $f[4] = uposf_to_xpos($f[3], \%feats);
    }
    elsif($f[1] =~ m/^(který|kterého|kterému|kterém|kterým|která|které|kterej|kterou|kterú|kteří|kterých|kterým|kterými)žto$/i)
    {
        $f[2] = 'kterýžto';
        $f[9] = set_lemma1300($f[9], 'kterýžto');
        $f[3] = 'DET';
        $feats{PronType} = 'Rel';
        keep_features(\%feats, 'PronType', 'Gender', 'Animacy', 'Number', 'Case');
        $f[4] = uposf_to_xpos($f[3], \%feats);
    }
    elsif($f[1] =~ m/^(jaký|jakého|jakému|jakém|jakým|jaká|jaké|jakej|jakou|jakú|jací|jakých|jakým|jakými)ž$/i)
    {
        $f[2] = 'jakýž';
        $f[9] = set_lemma1300($f[9], 'jakýž');
        $f[3] = 'DET';
        $feats{PronType} = 'Rel';
        if($f[1] =~ m/^jacíž$/i)
        {
            $feats{Gender} = 'Masc';
            $feats{Animacy} = 'Anim';
            $feats{Number} = 'Plur';
            $feats{Case} = 'Nom';
        }
        keep_features(\%feats, 'PronType', 'Gender', 'Animacy', 'Number', 'Case');
        $f[4] = uposf_to_xpos($f[3], \%feats);
    }
    #------------------------------------------------------------------
    # Neurčitá zájmena.
    #------------------------------------------------------------------
    # Tvar "cos" může být agregát "co" + "jsi", ale také to může být starší varianta neurčitého zájmena "cosi".
    elsif($f[1] =~ m/^(co|čeho|čemu|čem|čím)s$/i)
    {
        $f[2] = 'cos';
        $f[9] = set_lemma1300($f[9], 'cos');
        $f[3] = 'PRON';
        $feats{PronType} = 'Ind';
        if($f[1] =~ m/^čemus$/i)
        {
            $feats{Case} = 'Dat';
        }
        keep_features(\%feats, 'PronType', 'Case');
        $f[4] = uposf_to_xpos($f[3], \%feats);
    }
    elsif($f[1] =~ m/^ně(který|kterého|kterému|kterém|kterým|která|které|kterej|kterou|kterú|kteří|kterých|kterým|kterými)$/i)
    {
        $f[2] = 'některý';
        $f[9] = set_lemma1300($f[9], 'některý');
        $f[3] = 'DET';
        $feats{PronType} = 'Ind';
        keep_features(\%feats, 'PronType', 'Gender', 'Animacy', 'Number', 'Case');
        $f[4] = uposf_to_xpos($f[3], \%feats);
    }
    elsif($f[1] =~ m/^(který|kterého|kterému|kterém|kterým|která|které|kterej|kterou|kterú|kteří|kterých|kterým|kterými)s$/i)
    {
        $f[2] = 'kterýs';
        $f[9] = set_lemma1300($f[9], 'kterýs');
        $f[3] = 'DET';
        $feats{PronType} = 'Ind';
        keep_features(\%feats, 'PronType', 'Gender', 'Animacy', 'Number', 'Case');
        $f[4] = uposf_to_xpos($f[3], \%feats);
    }
    #------------------------------------------------------------------
    # Totální zájmena.
    #------------------------------------------------------------------
    elsif($f[1] =~ m/^každ(ý|ého|ému|ém|ým|á|é|ej|ou|ú|í|ých|ým|ými)$/i)
    {
        $f[2] = 'každý';
        $f[9] = set_lemma1300($f[9], 'každý');
        # V datech z PDT v UD 2.6 je "každý" označkováno jako adjektivum! Mělo by to být zájmeno.
        # Zkusíme tady z toho udělat zájmeno, i když z toho UDPipe bude zmatený, až ho natrénujeme
        # na takto opravených datech spojených s neopraveným PDT.
        $f[3] = 'DET';
        $feats{PronType} = 'Tot';
        keep_features(\%feats, 'PronType', 'Gender', 'Animacy', 'Number', 'Case');
        $f[4] = uposf_to_xpos($f[3], \%feats);
    }
    # Pozor na homonymii se substantivem "veš"!
    # Ve staročeštině navíc existovalo zájmeno "veš" vedle "všechen", přičemž některé tvary (jiné než nominativ, akuzativ a vokativ) se zřejmě sdílely.
    elsif($f[1] =~ m/^(vš[eě]ho|vš[eě]mu|vš[eě]m|vším|vší|všiej|všie|vš[eě]|vš[eě]ch|vš[eě]mi)ť?$/i)
    {
        $f[2] = 'všechen';
        $f[9] = set_lemma1300($f[9], 'veš');
        $f[3] = 'DET';
        $feats{PronType} = 'Tot';
        keep_features(\%feats, 'PronType', 'Gender', 'Animacy', 'Number', 'Case');
        if($f[1] =~ m/^všiejť?$/i)
        {
            # Může být zřejmě jedině Fem Sing Gen, možná Loc.
            $feats{Gender} = 'Fem';
            $feats{Number} = 'Sing';
            $feats{Case} = 'Gen' unless($feats{Case} =~ m/Gen|Loc/);
        }
        elsif($f[1] =~ m/^všieť?$/i)
        {
            # Může být asi víc věcí.
            # Viděl jsem "všie zeleni", to má být zřejmě Fem Sing Dat.
            # Viděl jsem ale taky výskyty, které připomínaly Gen; zřejmě by to mohl být i Plur Acc.
            $feats{Gender} = 'Fem' unless($feats{Gender});
            $feats{Number} = 'Sing' unless($feats{Number});
            $feats{Case} = 'Dat' unless($feats{Case} =~ m/Gen|Dat|Acc/);
        }
        elsif($f[1] =~ m/^všímť?$/i)
        {
            # Může být Masc|Neut Sing Ins. UDPipe do toho občas plete Plur Dat, protože si představuje substantivum "veš".
            $feats{Gender} = 'Neut' unless($feats{Gender} =~ m/Masc|Neut/);
            $feats{Number} = 'Sing';
            $feats{Case} = 'Ins';
        }
        elsif($f[1] =~ m/^vš[eě]chť?$/i)
        {
            # Může být Gen|Loc Plur, všechny rody. V datech bylo vidět mj. všěch krajinách, všěch městech, všěch Gen Masc Plur.
            $feats{Gender} = 'Masc' unless($feats{Gender});
            $feats{Number} = 'Plur';
            $feats{Case} = 'Loc' unless($feats{Case} =~ m/Gen|Loc/);
        }
        elsif($f[1] =~ m/^vš[eě]mť?$/i)
        {
            # Může být Loc Sing Masc|Neut nebo Dat Plur, všechny rody.
            # V datech bylo vidět často jako Sing Loc ("po všem světě") a pak také jako Dat Plur bez substantiva, tj. default Masc.
            if($feats{Case} eq 'Loc')
            {
                $feats{Gender} = 'Masc,Neut';
                $feats{Number} = 'Sing';
            }
            else
            {
                $feats{Gender} = 'Masc' unless($feats{Gender});
                $feats{Number} = 'Plur';
                $feats{Case} = 'Dat';
            }
        }
        elsif($f[1] =~ m/^vš[eě]miť?$/i)
        {
            # Může být Ins Plur, všechny rody. V datech bylo vidět většinou všěmi sěmeny, tedy Neut.
            $feats{Gender} = 'Neut' unless($feats{Gender});
            $feats{Number} = 'Plur';
            $feats{Case} = 'Ins';
        }
        $f[4] = uposf_to_xpos($f[3], \%feats);
    }
    elsif($f[1] =~ m/^(vš[eě]chen|vš[eě]chna|vš[eě]chno|všichni|vš[eě]chny)ť?$/i)
    {
        $f[2] = 'všechen';
        $f[9] = set_lemma1300($f[9], 'všechen');
        $f[3] = 'DET';
        $feats{PronType} = 'Tot';
        keep_features(\%feats, 'PronType', 'Gender', 'Animacy', 'Number', 'Case');
        $f[4] = uposf_to_xpos($f[3], \%feats);
    }
    elsif($f[1] =~ m/^(vš[eě]cken|vš[eě]ckna|vš[eě]ckno|všickni|vš[eě]ckny)ť?$/i)
    {
        $f[2] = 'všecken';
        $f[9] = set_lemma1300($f[9], 'všecken');
        $f[3] = 'DET';
        $feats{PronType} = 'Tot';
        keep_features(\%feats, 'PronType', 'Gender', 'Animacy', 'Number', 'Case');
        if($f[1] =~ m/^všickni$/i)
        {
            $feats{Gender} = 'Masc';
            $feats{Animacy} = 'Anim';
            $feats{Number} = 'Plur';
            $feats{Case} = 'Nom' unless($feats{Case} eq 'Voc');
        }
        elsif($f[1] =~ m/^vš[eě]ckny$/i)
        {
            # Dva výskyty, oba jsou Masc Acc, Drážď 28.20 je Inan (všěckny dny), Ol 2.4 je Anim (všěckny starosty).
            $feats{Gender} = 'Masc';
            $feats{Animacy} = get_ref($f[9]) =~ m/^MATT_28\.20$/ ? 'Inan' : 'Anim';
            $feats{Number} = 'Plur';
            $feats{Case} = 'Acc';
        }
        $f[4] = uposf_to_xpos($f[3], \%feats);
    }
    elsif($f[1] =~ m/^(vš[eě]cek|vš[eě]cka|všicku|vš[eě]cko|všici|vš[eě]cky)ť?$/i)
    {
        $f[2] = 'všecek';
        $f[9] = set_lemma1300($f[9], 'všecek');
        $f[3] = 'DET';
        $feats{PronType} = 'Tot';
        keep_features(\%feats, 'PronType', 'Gender', 'Animacy', 'Number', 'Case');
        if($f[1] =~ m/^vš[eě]cky$/i)
        {
            $feats{Number} = 'Plur';
            # Může být Nom Inan, Nom Fem, Acc Masc, Acc Fem. A teoreticky taky Voc Inan, Voc Fem.
            $feats{Case} = 'Acc' unless($feats{Case} =~ m/Nom|Acc|Voc/);
            if(!$feats{Gender})
            {
                if($feats{Case} eq 'Acc')
                {
                    $feats{Gender} = 'Masc';
                    delete($feats{Animacy});
                }
                else
                {
                    $feats{Gender} = 'Fem';
                    delete($feats{Animacy});
                }
            }
        }
        $f[4] = uposf_to_xpos($f[3], \%feats);
    }
    elsif($f[1] =~ m/^vešken$/i)
    {
        $f[2] = 'veškerý';
        $f[9] = set_lemma1300($f[9], 'vešken');
        $f[3] = 'DET';
        $feats{PronType} = 'Tot';
        $feats{Gender} = 'Masc';
        $feats{Animacy} = 'Inan';
        $feats{Number} = 'Sing';
        $feats{Case} = 'Nom' unless($feats{Case} =~ m/(Nom|Acc)/);
        keep_features(\%feats, 'PronType', 'Gender', 'Animacy', 'Number', 'Case');
        $f[4] = uposf_to_xpos($f[3], \%feats);
    }
    elsif($f[1] =~ m/^vš[eě]lik(ý|ým|á|éj|ú|é)ť?$/i)
    {
        $f[2] = 'všeliký';
        $f[9] = set_lemma1300($f[9], 'všeliký');
        $f[3] = 'DET';
        $feats{PronType} = 'Tot';
        # Všechny výskyty "všeliké" v našich datech jsou neutrum singulár.
        if($f[1] =~ m/éť?$/i)
        {
            $feats{Gender} = 'Neut';
            $feats{Number} = 'Sing';
            $feats{Case} = 'Acc' unless($feats{Case} =~ m/(Nom|Acc)/);
        }
        keep_features(\%feats, 'PronType', 'Gender', 'Animacy', 'Number', 'Case');
        $f[4] = uposf_to_xpos($f[3], \%feats);
    }
    #------------------------------------------------------------------
    # Záporná zájmena.
    #------------------------------------------------------------------
    elsif($f[1] =~ m/^ni(kdo|kto|k[oe]ho|komu|kom|kým)$/i)
    {
        $f[2] = 'nikdo';
        $f[9] = set_lemma1300($f[9], 'nikto');
        $f[3] = 'PRON';
        $feats{PronType} = 'Neg';
        keep_features(\%feats, 'PronType', 'Gender', 'Animacy', 'Case');
        $feats{Gender} = 'Masc';
        $feats{Animacy} = 'Anim';
        if($f[1] =~ m/^ni(kdo|kto)$/i)
        {
            $feats{Case} = 'Nom';
        }
        $f[4] = uposf_to_xpos($f[3], \%feats);
    }
    elsif($f[1] =~ m/^(nico|ničeho|ničemu|ničem|ničím)ž$/i)
    {
        $f[2] = 'nicož';
        $f[9] = set_lemma1300($f[9], 'nicož');
        $f[3] = 'PRON';
        $feats{PronType} = 'Neg';
        keep_features(\%feats, 'PronType', 'Case');
        if($f[1] =~ m/^ničemž$/i)
        {
            $feats{Case} = 'Loc';
        }
        $f[4] = uposf_to_xpos($f[3], \%feats);
    }
    elsif($f[1] =~ m/^nikom(ý|ého|ému|ém|ým|á|é|ej|ou|ú|í|ých|ým|ými)$/i)
    {
        $f[2] = 'nikomý';
        $f[9] = set_lemma1300($f[9], 'nikomý');
        $f[3] = 'DET';
        $feats{PronType} = 'Neg';
        keep_features(\%feats, 'PronType', 'Gender', 'Animacy', 'Number', 'Case');
        $f[4] = uposf_to_xpos($f[3], \%feats);
    }
    elsif($f[1] =~ m/^ižádn(ý|ého|ému|ém|ým|á|é|ej|ou|ú|í|ých|ým|ými)$/i)
    {
        $f[2] = 'žádný';
        $f[9] = set_lemma1300($f[9], 'ižádný');
        $f[3] = 'DET';
        $feats{PronType} = 'Neg';
        keep_features(\%feats, 'PronType', 'Gender', 'Animacy', 'Number', 'Case');
        $f[4] = uposf_to_xpos($f[3], \%feats);
    }
    # Pokud po průchodu touto funkcí něco je/zůstalo zájmenem, tak u něj následující rysy nemají co dělat.
    if($f[3] =~ m/^(PRON|DET)$/)
    {
        delete($feats{Abbr});
        delete($feats{Foreign});
        delete($feats{NameType});
    }
    $f[5] = scalar(keys(%feats)) == 0 ? '_' : join('|', sort {lc($a) cmp lc($b)} (map {"$_=$feats{$_}"} (keys(%feats))));
    return @f;
}



#------------------------------------------------------------------------------
# Získá z MISCu odkaz na zdrojový verš v Bibli. Díky tomu můžeme některá
# pravidla cíleně uplatnit jen na některé verše.
#------------------------------------------------------------------------------
sub get_ref
{
    my $misc = shift;
    my @misc = split(/\|/, $misc);
    my @ref = map {s/^Ref=//; $_} (grep {m/^Ref=.+$/} (@misc));
    if(scalar(@ref) > 0)
    {
        return $ref[0];
    }
    return '';
}



#------------------------------------------------------------------------------
# Získá z MISCu alternativní morfologické analýzy a vrátí je jako pole hashů.
#------------------------------------------------------------------------------
sub misc_to_ma
{
    my $misc = shift;
    my @misc = split(/\|/, $misc);
    my @ma;
    foreach my $m (@misc)
    {
        if($m =~ m/^(Hlemma|PrgTag|BrnTag|UPOS|[A-Za-z]+)\[(\d+)\]=(.*)$/)
        {
            my $attribute = $1;
            my $maindex = $2;
            my $value = $3;
            $ma[$maindex]{$attribute} = $value;
        }
    }
    return @ma;
}



#------------------------------------------------------------------------------
# Pokud lze získat z MISCu alternativní morfologické analýzy, zkusí v nich
# najít takové, které odpovídají našim očekáváním, a vyplnit podle nich
# jednotlivá pole v CoNLL-U.
#------------------------------------------------------------------------------
sub try_ma_from_misc
{
    my $f = shift; # array ref
    my $expected = shift; # hash ref, e.g.: {'UPOS' => 'VERB', 'VerbForm' => 'Conv', 'Tense' => 'Pres'}
    my @ma = misc_to_ma($f->[9]);
    foreach my $ma (@ma)
    {
        # Check that all attribute-value pairs from $expected match this analysis.
        my $ok = 1;
        foreach my $expectkey (keys(%{$expected}))
        {
            if($ma->{$expectkey} ne $expected->{$expectkey})
            {
                $ok = 0;
                last;
            }
        }
        if($ok)
        {
            my $lemma1300 = $ma->{Hlemma};
            $lemma1300 =~ s/^sloviti$/slúti/;
            $f->[9] = set_lemma1300($f->[9], $lemma1300);
            $f->[2] = lemma_1300_to_2022($lemma1300);
            $f->[3] = $ma->{UPOS};
            $f->[4] = substr($ma->{PrgTag}, 0, 15);
            $f->[5] = join('|', map {"$_=$ma->{$_}"} (grep {$ma->{$_}} (qw(Aspect Mood Number Person Polarity Tense VerbForm Voice))));
            return 1;
        }
    }
    return 0;
}



#------------------------------------------------------------------------------
# Nastaví v MISCu atribut Lemma1300. Ve sloupci LEMMA se snažíme mít
# odpovídající lemma k roku 2022, protože je to výhodné pro UDPipe. Současně
# ale chceme mít povědomí i o normalizované podobě k roku 1300.
#------------------------------------------------------------------------------
sub set_lemma1300
{
    my $misc = shift;
    my $lemma = shift;
    # Hodnota atributu v MISC nemůže obsahovat svislítko. Museli bychom ho
    # zneškodnit třeba jako "\p" nebo "&pipe;", ale žádný standardní způsob
    # stanovený není. Vyřešíme to tím, že lemma1300 prostě nenastavíme.
    # (Svislítka se vyskytují vzácně, např. ve slovníku 020_slov_uka.conllu.)
    if($lemma =~ m/\|/)
    {
        return;
        #die("Hodnota atributu v MISC nemůže obsahovat svislítko");
    }
    my @misc = $misc eq '_' ? () : split(/\|/, $misc);
    # Pokud už tam tento atribut byl, vyhodit ho.
    @misc = grep {!m/^Lemma1300=/} (@misc);
    # Jestliže MISC obsahuje atribut Ref, dát Lemma1300 těsně za něj.
    # Jinak ho dát na začátek. (Ale Ref by tam měl být vždy.)
    if(grep {m/^Ref=/} (@misc))
    {
        my @misc1;
        foreach my $m (@misc)
        {
            push(@misc1, $m);
            if($m =~ m/^Ref=/)
            {
                push(@misc1, "Lemma1300=$lemma");
            }
        }
        @misc = @misc1;
    }
    else
    {
        unshift(@misc, "Lemma1300=$lemma");
    }
    $misc = scalar(@misc) > 0 ? join('|', @misc) : '_';
    return $misc;
}



#------------------------------------------------------------------------------
# Odhadne tvar moderního lemmatu podle lemmatu z roku 1300.
#------------------------------------------------------------------------------
sub lemma_1300_to_2022
{
    my $l = shift;
    $l =~ s/^domnieti$/domnívat/;
    $l =~ s/^držieti$/držet/;
    $l =~ s/^jěditi$/jíst/;
    $l =~ s/^kláněti$/klanět/;
    $l =~ s/^kléti$/klít/;
    $l =~ s/^krstíti$/křtít/;
    $l =~ s/^mieti$/mnout/;
    $l =~ s/^mlčati?$/mlčet/;
    $l =~ s/^mnieti$/mínit/;
    $l =~ s/^mútiti$/rmoutit/;
    $l =~ s/^obihati$/obíhat/;
    $l =~ s/^otkodlúčiti$/odloučit/;
    $l =~ s/^plvati$/plivat/;
    $l =~ s/^pohřbiti$/pohřbít/;
    $l =~ s/^pohřésti$/pohřbít/;
    $l =~ s/poman/pomen/; # napomanutý = napomenutý, totéž u příbuzných slov
    $l =~ s/^přídržěti$/přidržet/;
    $l =~ s/^přisáhati$/přísahat/;
    $l =~ s/^púščěti$/pouštět/;
    $l =~ s/^púštěti$/pouštět/;
    $l =~ s/^rosievati$/rozsévat/;
    $l =~ s/^rozpuščiti$/rozpustit/;
    $l =~ s/^ruosti$/růst/;
    $l =~ s/^shromazditi$/shromáždit/;
    $l =~ s/^siesti$/sednout/;
    $l =~ s/slyša/slyše/; # slyšati = slyšet, totéž u odvozených slov
    $l =~ s/^ssáti$/sát/;
    $l =~ s/^sstupovati$/sestupovati/;
    $l =~ s/^stkvieti$/skvít/;
    $l =~ s/^tresktati$/trestat/;
    $l =~ s/^úpiti$/úpět/;
    $l =~ s/^velbiti$/velebit/;
    $l =~ s/^vlásti$/vládnout/;
    $l =~ s/^vsiesti$/vsednout/;
    $l =~ s/^vzpoměnouti?$/vzpomenout/;
    $l =~ s/^zabiti$/zabít/;
    $l =~ s/^naj/nej/ unless($l =~ m/^najat/i);
    $l =~ s/^ot/od/ unless($l =~ m/^(otáz|otec|otev[rř])/i); # tehdy se tato předpona někdy psala ot- a někdy od-, dnes pouze od-
    $l =~ s/ti$/t/ unless($l eq 'proti'); # krátký infinitiv místo dlouhého
    # všeobecné morfonologické heuristiky
    $l =~ s/ie/í/g unless($l eq 'ewangelie');
    $l =~ s/(.)ú/${1}ou/g;
    $l =~ s/uo/o/g;
    $l =~ s/šč[eě]/ště/g;
    $l =~ s/šči/sti/g;
    $l =~ s/črv/červ/g;
    $l =~ s/([cčghjklqrřsšxzž])ě/${1}e/ig;
    return $l;
}



#------------------------------------------------------------------------------
# Podle záporného prefixu "ne-" nastaví hodnotu polarity pro PDT a pro UD.
#------------------------------------------------------------------------------
sub negprefix_to_polarity
{
    my $negprefix = shift;
    my $polarity = 'Pos';
    my $p = 'A';
    if($negprefix)
    {
        $polarity = 'Neg';
        $p = 'N';
    }
    return ($polarity, $p);
}



#------------------------------------------------------------------------------
# Často se stává, že slovo má vyplněné rysy, které vůbec nejsou relevantní.
# Např. jde o zájmeno, ale UDPipe ho považoval za sloveso a vyplnil Aspect,
# VerbForm a Voice. Tato funkce vymaže hodnoty všech rysů kromě těch, o jejichž
# zachování si výslovně řekneme.
#------------------------------------------------------------------------------
sub keep_features
{
    my $feats = shift; # hash ref
    my @keep = @_; # list of feature names
    foreach my $f (keys(%{$feats}))
    {
        unless(grep {$_ eq $f} (@keep))
        {
            delete($feats->{$f});
        }
    }
}



#------------------------------------------------------------------------------
# Převede UPOS + FEATS na značku PDT, kterou pak uložíme jako XPOS.
#------------------------------------------------------------------------------
sub uposf_to_xpos
{
    my $upos = shift;
    my $feats = shift; # hash ref
    my $fs = Lingua::Interset::decode('mul::upos', $upos);
    $fs->add_ufeatures(map {"$_=$feats->{$_}"} (keys(%{$feats})));
    return Lingua::Interset::encode('cs::pdt', $fs);
}

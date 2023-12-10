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
                'anděl'       => ['anděl',     'anděl',     [['Sing', 'S', 'Nom', '1']]],
                'anděla'      => ['anděl',     'anděl',     [['Sing', 'S', 'Acc', '4']]],
                'anděli'      => ['anděl',     'anděl',     [['Plur', 'P', 'Nom', '1']]],
                'andělóm'     => ['anděl',     'anděl',     [['Plur', 'P', 'Dat', '3']]],
                'andělóv'     => ['anděl',     'anděl',     [['Plur', 'P', 'Gen', '2']]],
                'andělové'    => ['anděl',     'anděl',     [['Plur', 'P', 'Nom', '1']]],
                'anděly'      => ['anděl',     'anděl',     [['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Ins', '7']]],
                'anjel'       => ['anděl',     'anděl',     [['Sing', 'S', 'Nom', '1']]],
                'anjela'      => ['anděl',     'anděl',     [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'anjelé'      => ['anděl',     'anděl',     [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'anjeli'      => ['anděl',     'anděl',     [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'anjelóm'     => ['anděl',     'anděl',     [['Plur', 'P', 'Dat', '3']]],
                'anjelóv'     => ['anděl',     'anděl',     [['Plur', 'P', 'Gen', '2']]],
                'anjelové'    => ['anděl',     'anděl',     [['Plur', 'P', 'Nom', '1']]],
                'anjely'      => ['anděl',     'anděl',     [['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Ins', '7']]],
                'apoštolóm'   => ['apoštol',   'apoštol',   [['Plur', 'P', 'Dat', '3']]],
                'apoštolóv'   => ['apoštol',   'apoštol',   [['Plur', 'P', 'Gen', '2']]],
                'apoštolové'  => ['apoštol',   'apoštol',   [['Plur', 'P', 'Nom', '1']]],
                'běsa'        => ['běs',       'běs',       [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'běsem'       => ['běs',       'běs',       [['Sing', 'S', 'Ins', '7']]],
                'běsi'        => ['běs',       'běs',       [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'běsóm'       => ['běs',       'běs',       [['Plur', 'P', 'Dat', '3']]],
                'běsóv'       => ['běs',       'běs',       [['Plur', 'P', 'Gen', '2']]],
                'běsové'      => ['běs',       'běs',       [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'běsu'        => ['běs',       'běs',       [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'běsy'        => ['běs',       'běs',       [['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Ins', '7']]],
                'bóh'         => ['bůh',       'bóh',       [['Sing', 'S', 'Nom', '1']]],
                'boha'        => ['bůh',       'bóh',       [['Sing', 'S', 'Acc', '4'], ['Sing', 'S', 'Gen', '2']]],
                'bohem'       => ['bůh',       'bóh',       [['Sing', 'S', 'Ins', '7']]],
                'bohóm'       => ['bůh',       'bóh',       [['Plur', 'P', 'Dat', '3']]],
                'bohóv'       => ['bůh',       'bóh',       [['Plur', 'P', 'Gen', '2']]],
                'bohové'      => ['bůh',       'bóh',       [['Plur', 'P', 'Nom', '1']]],
                'bohu'        => ['bůh',       'bóh',       [['Sing', 'S', 'Dat', '3']]],
                'bohy'        => ['bůh',       'bóh',       [['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Ins', '7']]],
                'bože'        => ['bůh',       'bóh',       [['Sing', 'S', 'Voc', '5']]],
                'božé'        => ['bůh',       'bóh',       [['Sing', 'S', 'Gen', '2']]],
                'bratr'       => ['bratr',     'bratr',     [['Sing', 'S', 'Nom', '1']]],
                'bratra'      => ['bratr',     'bratr',     [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'bratrem'     => ['bratr',     'bratr',     [['Sing', 'S', 'Ins', '7']]],
                'bratroma'    => ['bratr',     'bratr',     [['Dual', 'D', 'Dat', '3']]],
                'bratróv'     => ['bratr',     'bratr',     [['Plur', 'P', 'Gen', '2']]],
                'bratru'      => ['bratr',     'bratr',     [['Sing', 'S', 'Dat', '3']]],
                'bratry'      => ['bratr',     'bratr',     [['Dual', 'D', 'Acc', '4']]], # duál pro dva bratry 20.24 a 4.18 a 4.21
                'bratří'      => ['bratr',     'bratr',     [['Plur', 'P', 'Gen', '2'], ['Plur', 'P', 'Dat', '3']]],
                'bratřie'     => ['bratr',     'bratr',     [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4']]],
                'bratřú'      => ['bratr',     'bratr',     [['Dual', 'D', 'Acc', '4'], ['Plur', 'P', 'Acc', '4']]],
                'buoh'        => ['bůh',       'bóh',       [['Sing', 'S', 'Nom', '1']]],
                'buoha'       => ['bůh',       'bóh',       [['Sing', 'S', 'Acc', '4'], ['Sing', 'S', 'Gen', '2']]],
                'buohem'      => ['bůh',       'bóh',       [['Sing', 'S', 'Ins', '7']]],
                'buohu'       => ['bůh',       'bóh',       [['Sing', 'S', 'Dat', '3']]],
                'buože'       => ['bůh',       'bóh',       [['Sing', 'S', 'Voc', '5']]],
                'býci'        => ['býk',       'býk',       [['Plur', 'P', 'Nom', '1']]],
                'člověk'      => ['člověk',    'člověk',    [['Sing', 'S', 'Nom', '1']]],
                'člověka'     => ['člověk',    'člověk',    [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'člověkem'    => ['člověk',    'člověk',    [['Sing', 'S', 'Ins', '7']]],
                'člověkóv'    => ['člověk',    'člověk',    [['Plur', 'P', 'Gen', '2']]],
                'člověku'     => ['člověk',    'člověk',    [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'člověky'     => ['člověk',    'člověk',    [['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Ins', '7']]],
                'črv'         => ['červ',      'črv',       [['Sing', 'S', 'Nom', '1']]],
                'črvie'       => ['červ',      'črv',       [['Plur', 'P', 'Nom', '1']]],
                'dělníci'     => ['dělník',    'dělník',    [['Plur', 'P', 'Nom', '1']]],
                'dělník'      => ['dělník',    'dělník',    [['Sing', 'S', 'Nom', '1']]],
                'dělníkóv'    => ['dělník',    'dělník',    [['Plur', 'P', 'Gen', '2']]],
                'dělníkuov'   => ['dělník',    'dělník',    [['Plur', 'P', 'Gen', '2']]],
                'dělníky'     => ['dělník',    'dělník',    [['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Ins', '7']]],
                'diábel'      => ['ďábel',     'diábel',    [['Sing', 'S', 'Nom', '1']]],
                'diábla'      => ['ďábel',     'diábel',    [['Sing', 'S', 'Gen', '2']]],
                'diáblem'     => ['ďábel',     'diábel',    [['Sing', 'S', 'Ins', '7']]],
                'diáblové'    => ['ďábel',     'diábel',    [['Plur', 'P', 'Nom', '1']]],
                'diáblu'      => ['ďábel',     'diábel',    [['Sing', 'S', 'Dat', '3']]],
                'diábly'      => ['ďábel',     'diábel',    [['Plur', 'P', 'Acc', '4']]],
                'dlužníkóm'   => ['dlužník',   'dlužník',   [['Plur', 'P', 'Dat', '3']]],
                'duch'        => ['duch',      'duch',      [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Acc', '4']]],
                'ducha'       => ['duch',      'duch',      [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'duchem'      => ['duch',      'duch',      [['Sing', 'S', 'Ins', '7']]],
                'duchóv'      => ['duch',      'duch',      [['Plur', 'P', 'Gen', '2']]],
                'duchové'     => ['duch',      'duch',      [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'duchovníci'  => ['duchovník', 'duchovník', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'duchovníče'  => ['duchovník', 'duchovník', [['Sing', 'S', 'Voc', '5']]],
                'duchovníkóv' => ['duchovník', 'duchovník', [['Plur', 'P', 'Gen', '2']]],
                'duchovníky'  => ['duchovník', 'duchovník', [['Plur', 'P', 'Acc', '4']]],
                'duchu'       => ['duch',      'duch',      [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'duchy'       => ['duch',      'duch',      [['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Ins', '7']]],
                'had'          => ['had',        'had',        [['Sing', 'S', 'Nom', '1']]],
                'hada'         => ['had',        'had',        [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'hade'         => ['had',        'had',        [['Sing', 'S', 'Voc', '5']]],
                'hadem'        => ['had',        'had',        [['Sing', 'S', 'Ins', '7']]],
                'hadi'         => ['had',        'had',        [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'hadóm'        => ['had',        'had',        [['Plur', 'P', 'Dat', '3']]],
                'hadóv'        => ['had',        'had',        [['Plur', 'P', 'Gen', '2']]],
                'hadové'       => ['had',        'had',        [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'hadu'         => ['had',        'had',        [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'hady'         => ['had',        'had',        [['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Ins', '7']]],
                'hospodin'     => ['hospodin',   'hospodin',   [['Sing', 'S', 'Nom', '1']]],
                'hospodina'    => ['hospodin',   'hospodin',   [['Sing', 'S', 'Acc', '4'], ['Sing', 'S', 'Gen', '2']]],
                'hospodine'    => ['hospodin',   'hospodin',   [['Sing', 'S', 'Voc', '5']]],
                'hospodině'    => ['hospodin',   'hospodin',   [['Sing', 'S', 'Loc', '6']]],
                'hospodinem'   => ['hospodin',   'hospodin',   [['Sing', 'S', 'Ins', '7']]],
                'hospodinové'  => ['hospodin',   'hospodin',   [['Plur', 'P', 'Nom', '1']]],
                'hospodinovi'  => ['hospodin',   'hospodin',   [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'hospodinu'    => ['hospodin',   'hospodin',   [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'hospodiny'    => ['hospodin',   'hospodin',   [['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Ins', '7']]],
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
                'kokot'        => ['kohout',     'kokot',      [['Sing', 'S', 'Nom', '1']]],
                'kozelcě'      => ['kozel',      'kozelec',    [['Plur', 'P', 'Acc', '4']]],
                'kozelcóv'     => ['kozel',      'kozelec',    [['Plur', 'P', 'Gen', '2']]],
                'kozlóv'       => ['kozel',      'kozel',      [['Plur', 'P', 'Gen', '2']]],
                'kozlu'        => ['kozel',      'kozel',      [['Sing', 'S', 'Dat', '3']]],
                'kozly'        => ['kozel',      'kozel',      [['Plur', 'P', 'Acc', '4']]],
                'krajěné'      => ['krajan',     'krajěnín',   [['Plur', 'P', 'Nom', '1']]],
                'licoměrníkóv' => ['licoměrník', 'licoměrník', [['Plur', 'P', 'Gen', '2']]],
                'mistr'       => ['mistr',     'mistr',     [['Sing', 'S', 'Nom', '1']]],
                'mistra'      => ['mistr',     'mistr',     [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'mistrem'     => ['mistr',     'mistr',     [['Sing', 'S', 'Ins', '7']]],
                'mistróm'     => ['mistr',     'mistr',     [['Plur', 'P', 'Dat', '3']]],
                'mistróv'     => ['mistr',     'mistr',     [['Plur', 'P', 'Gen', '2']]],
                'mistry'      => ['mistr',     'mistr',     [['Plur', 'P', 'Acc', '4']]],
                'mládenečkóv' => ['mládeneček', 'mládeneček', [['Plur', 'P', 'Gen', '2']]],
                'mudráci'     => ['mudrák',    'mudrák',    [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'mudrák'      => ['mudrák',    'mudrák',    [['Sing', 'S', 'Nom', '1']]],
                'mudrákóm'    => ['mudrák',    'mudrák',    [['Plur', 'P', 'Dat', '3']]],
                'mudrákóv'    => ['mudrák',    'mudrák',    [['Plur', 'P', 'Gen', '2']]],
                'mudráky'     => ['mudrák',    'mudrák',    [['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Ins', '7']]],
                'muž'         => ['muž',       'muž',       [['Sing', 'S', 'Nom', '1']]],
                'mužě'        => ['muž',       'muž',       [['Sing', 'S', 'Acc', '4']]],
                'mužem'       => ['muž',       'muž',       [['Sing', 'S', 'Ins', '7']]],
                'muži'        => ['muž',       'muž',       [['Sing', 'S', 'Dat', '3']]],
                'muží'        => ['muž',       'muž',       [['Plur', 'P', 'Gen', '2']]],
                'mužie'       => ['muž',       'muž',       [['Plur', 'P', 'Nom', '1']]],
                'mužóv'       => ['muž',       'muž',       [['Plur', 'P', 'Gen', '2']]],
                'mužové'      => ['muž',       'muž',       [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'mužu'        => ['muž',       'muž',       [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'otcě'        => ['otec',      'otec',      [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4'], ['Plur', 'P', 'Acc', '4']]],
                'otci'        => ['otec',      'otec',      [['Sing', 'S', 'Dat', '3']]],
                'otcu'        => ['otec',      'otec',      [['Sing', 'S', 'Dat', '3']]],
                'otcem'       => ['otec',      'otec',      [['Sing', 'S', 'Ins', '7']]],
                'otcóm'       => ['otec',      'otec',      [['Plur', 'P', 'Dat', '3']]],
                'otcóv'       => ['otec',      'otec',      [['Plur', 'P', 'Gen', '2']]],
                'otcové'      => ['otec',      'otec',      [['Plur', 'P', 'Nom', '1']]],
                'pán'         => ['pán',       'pán',       [['Sing', 'S', 'Nom', '1']]],
                'pána'        => ['pán',       'pán',       [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'páně'        => ['pán',       'pán',       [['Sing', 'S', 'Gen', '2']]],
                'pánem'       => ['pán',       'pán',       [['Sing', 'S', 'Ins', '7']]],
                'páni'        => ['pán',       'pán',       [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'pánoma'      => ['pán',       'pán',       [['Dual', 'D', 'Dat', '3']]],
                'pánóv'       => ['pán',       'pán',       [['Plur', 'P', 'Gen', '2']]],
                'pánové'      => ['pán',       'pán',       [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'pánuov'      => ['pán',       'pán',       [['Plur', 'P', 'Gen', '2']]],
                'pánu'        => ['pán',       'pán',       [['Sing', 'S', 'Dat', '3']]],
                'panoš'       => ['panoš',    'panošě',     [['Sing', 'S', 'Nom', '1']]],
                'panošě'      => ['panoš',    'panošě',     [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Voc', '5'], ['Plur', 'P', 'Acc', '4']]],
                'panošěmi'    => ['panoš',    'panošě',     [['Plur', 'P', 'Ins', '7']]],
                'panoši'      => ['panoš',    'panošě',     [['Sing', 'S', 'Acc', '4']]],
                'panoší'      => ['panoš',    'panošě',     [['Plur', 'P', 'Gen', '2'], ['Sing', 'S', 'Ins', '7']]],
                'panošiem'    => ['panoš',    'panošě',     [['Plur', 'P', 'Dat', '3']]],
                'panošicě'    => ['panošice', 'panošicě',   [['Sing', 'S', 'Nom', '1'], ['Plur', 'P', 'Nom', '1', 'MATT_18\\.31']]], # případně bychom mohli 'panošice' modernizovat na 'panoš', ale tím by se dost změnil i vzor
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
                'rytieřie'   => ['rytíř', 'rytieř', [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'rytieřiech' => ['rytíř', 'rytieř', [['Plur', 'P', 'Loc', '6']]],
                'rytieřiem'  => ['rytíř', 'rytieř', [['Sing', 'S', 'Ins', '7']]],
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
                'súdce'    => ['soudce', 'súdcě', [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Voc', '5'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5']]],
                'súdcě'    => ['soudce', 'súdcě', [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Voc', '5'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5']]],
                'súdcemi'  => ['soudce', 'súdcě', [['Plur', 'P', 'Ins', '7']]],
                'súdcěmi'  => ['soudce', 'súdcě', [['Plur', 'P', 'Ins', '7']]],
                'súdci'    => ['soudce', 'súdcě', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Acc', '4'], ['Sing', 'S', 'Loc', '6']]],
                'súdcí'    => ['soudce', 'súdcě', [['Sing', 'S', 'Ins', '7']]],
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
                'šielenče'    => ['šílenec',  'šielenec', [['Sing', 'S', 'Voc', '5']]],
                'tetrarcha'   => ['tetrarcha', 'tetrarcha', [['Sing', 'S', 'Nom', '1']]],
                'tovařiš'     => ['tovaryš',  'tovařiš',  [['Sing', 'S', 'Nom', '1']]],
                'tovařišem'   => ['tovaryš',  'tovařiš',  [['Sing', 'S', 'Ins', '7']]],
                'tovařišie'   => ['tovaryš',  'tovařiš',  [['Plur', 'P', 'Nom', '1']]],
                'tovařišiem'  => ['tovaryš',  'tovařiš',  [['Plur', 'P', 'Dat', '3']]],
                'tovařišóv'   => ['tovaryš',  'tovařiš',  [['Plur', 'P', 'Gen', '2']]],
                'učedlníci'   => ['učedník',  'učedlník', [['Plur', 'P', 'Nom', '1']]],
                'učedlník'    => ['učedník',  'učedlník', [['Sing', 'S', 'Nom', '1']]],
                'učedlníka'   => ['učedník',  'učedlník', [['Sing', 'S', 'Gen', '2']]],
                'učedlníkóm'  => ['učedník',  'učedlník', [['Plur', 'P', 'Dat', '3']]],
                'učedlníkóv'  => ['učedník',  'učedlník', [['Plur', 'P', 'Gen', '2']]],
                'učedlníku'   => ['učedník',  'učedlník', [['Sing', 'S', 'Dat', '3']]],
                'učedlníkuom' => ['učedník',  'učedlník', [['Plur', 'P', 'Dat', '3']]],
                'učedlníkuov' => ['učedník',  'učedlník', [['Plur', 'P', 'Gen', '2']]],
                'učedlníky'   => ['učedník',  'učedlník', [['Plur', 'P', 'Acc', '4'], ['Dual', 'D', 'Nom', '1', 'MATT_(21\\.6)'], ['Dual', 'D', 'Acc', '4', 'MATT_(21\\.1)']]],
                'učenníci'    => ['učedník',  'učedlník', [['Plur', 'P', 'Nom', '1']]],
                'učenník'     => ['učedník',  'učedlník', [['Sing', 'S', 'Nom', '1']]],
                'učenníka'    => ['učedník',  'učedlník', [['Sing', 'S', 'Gen', '2']]],
                'učenníkóm'   => ['učedník',  'učedlník', [['Plur', 'P', 'Dat', '3']]],
                'učenníkóv'   => ['učedník',  'učedlník', [['Plur', 'P', 'Gen', '2']]],
                'učenníku'    => ['učedník',  'učedlník', [['Sing', 'S', 'Dat', '3']]],
                'učenníkuom'  => ['učedník',  'učedlník', [['Plur', 'P', 'Dat', '3']]],
                'učenníkuov'  => ['učedník',  'učedlník', [['Plur', 'P', 'Gen', '2']]],
                'učenníky'    => ['učedník',  'učedlník', [['Plur', 'P', 'Acc', '4'], ['Dual', 'D', 'Nom', '1', 'MATT_(21\\.6)'], ['Dual', 'D', 'Acc', '4', 'MATT_(21\\.1)']]],
                'velblúd'     => ['velbloud', 'velblúd',  [['Sing', 'S', 'Nom', '1']]],
                'velblúda'    => ['velbloud', 'velblúd',  [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'velblúde'    => ['velbloud', 'velblúd',  [['Sing', 'S', 'Voc', '5']]],
                'velblúdě'    => ['velbloud', 'velblúd',  [['Sing', 'S', 'Loc', '6']]],
                'velblúdem'   => ['velbloud', 'velblúd',  [['Sing', 'S', 'Ins', '7']]],
                'velblúdi'    => ['velbloud', 'velblúd',  [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'velblúdóm'   => ['velbloud', 'velblúd',  [['Plur', 'P', 'Dat', '3']]],
                'velblúdóv'   => ['velbloud', 'velblúd',  [['Plur', 'P', 'Gen', '2']]],
                'velblúdové'  => ['velbloud', 'velblúd',  [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'velblúdovi'  => ['velbloud', 'velblúd',  [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'velblúdu'    => ['velbloud', 'velblúd',  [['Sing', 'S', 'Dat', '3']]],
                'velblúdy'    => ['velbloud', 'velblúd',  [['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Ins', '7']]],
                'vodičěvé'    => ['vodič',    'vodič',    [['Plur', 'P', 'Voc', '5']]],
                'vodičové'    => ['vodič',    'vodič',    [['Plur', 'P', 'Voc', '5']]],
                'vodičóm'     => ['vodič',    'vodič',    [['Plur', 'P', 'Dat', '3']]],
                'vrabcě'      => ['vrabec',   'vrabec',   [['Dual', 'D', 'Acc', '4']]],
                'vrabci'      => ['vrabec',   'vrabec',   [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'vrabcóm'     => ['vrabec',   'vrabec',   [['Plur', 'P', 'Dat', '3']]],
                'vrabcóv'     => ['vrabec',   'vrabec',   [['Plur', 'P', 'Gen', '2']]],
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
                'daniel'       => ['Daniel',      'Daniel',      [['Sing', 'S', 'Nom', '1']]],
                'daniele'      => ['Daniel',      'Daniel',      [['Sing', 'S', 'Gen', '2']]],
                'danielem'     => ['Daniel',      'Daniel',      [['Sing', 'S', 'Ins', '7']]],
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
                'erodes'       => ['Herodes',     'Herodes',     [['Sing', 'S', 'Nom', '1']]],
                'erodovi'      => ['Herodes',     'Herodes',     [['Sing', 'S', 'Dat', '3']]],
                'herodes'      => ['Herodes',     'Herodes',     [['Sing', 'S', 'Nom', '1']]],
                'heroda'       => ['Herodes',     'Herodes',     [['Sing', 'S', 'Gen', '2']]],
                'herodovi'     => ['Herodes',     'Herodes',     [['Sing', 'S', 'Dat', '3']]],
                'herodesovi'   => ['Herodes',     'Herodes',     [['Sing', 'S', 'Dat', '3']]],
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
                'jezukrista'   => ['Jezukristus', 'Jezukristus', [['Sing', 'S', 'Gen', '2']]],
                'jezukristovi' => ['Jezukristus', 'Jezukristus', [['Sing', 'S', 'Loc', '6']]],
                'jezukristem'  => ['Jezukristus', 'Jezukristus', [['Sing', 'S', 'Ins', '7']]],
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
                'jozef'        => ['Josef',       'Jozef',       [['Sing', 'S', 'Nom', '1']]],
                'jozefovi'     => ['Josef',       'Jozef',       [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'jozefe'       => ['Josef',       'Jozef',       [['Sing', 'S', 'Voc', '5']]],
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
                'ozěp'         => ['Josef',       'Ozěp',        [['Sing', 'S', 'Nom', '1']]],
                'ozěpa'        => ['Josef',       'Ozěp',        [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'ozěpu'        => ['Josef',       'Ozěp',        [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'ozěpovi'      => ['Josef',       'Ozěp',        [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'ozěpe'        => ['Josef',       'Ozěp',        [['Sing', 'S', 'Voc', '5']]],
                'ozěpem'       => ['Josef',       'Ozěp',        [['Sing', 'S', 'Ins', '7']]],
                'petr'         => ['Petr',        'Petr',        [['Sing', 'S', 'Nom', '1']]],
                'petrovi'      => ['Petr',        'Petr',        [['Sing', 'S', 'Dat', '3']]],
                'petra'        => ['Petr',        'Petr',        [['Sing', 'S', 'Acc', '4']]],
                'pilát'        => ['Pilát',       'Pilát',       [['Sing', 'S', 'Nom', '1']]],
                'pilátu'       => ['Pilát',       'Pilát',       [['Sing', 'S', 'Dat', '3']]],
                'pilátovi'     => ['Pilát',       'Pilát',       [['Sing', 'S', 'Dat', '3']]],
                'piláta'       => ['Pilát',       'Pilát',       [['Sing', 'S', 'Acc', '4']]],
                'šalomún'      => ['Šalamoun',    'Šalomún',     [['Sing', 'S', 'Nom', '1']]],
                'zebedášem'    => ['Zebedeus',    'Zebedeus',    [['Sing', 'S', 'Ins', '7']]],
                'zebedeem'     => ['Zebedeus',    'Zebedeus',    [['Sing', 'S', 'Ins', '7']]]
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
                'kristus'   => ['Kristus',    'Kristus',     [['Sing', 'S', 'Nom', '1']]],
                'krista'    => ['Kristus',    'Kristus',     [['Sing', 'S', 'Gen', '2']]],
                'kristovi'  => ['Kristus',    'Kristus',     [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'kriste'    => ['Kristus',    'Kristus',     [['Sing', 'S', 'Voc', '5']]],
                'kristem'   => ['Kristus',    'Kristus',     [['Sing', 'S', 'Ins', '7']]],
                'kristové'  => ['Kristus',    'Kristus',     [['Plur', 'P', 'Nom', '1']]],
                'krstitele' => ['Křtitel',    'Křstitel',    [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'křstitel'  => ['Křtitel',    'Křstitel',    [['Sing', 'S', 'Nom', '1']]],
                'křstitele' => ['Křtitel',    'Křstitel',    [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'křstiteli' => ['Křtitel',    'Křstitel',    [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'křtitel'   => ['Křtitel',    'Křstitel',    [['Sing', 'S', 'Nom', '1']]],
                'křtitele'  => ['Křtitel',    'Křstitel',    [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'křtiteli'  => ['Křtitel',    'Křstitel',    [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'nazareus'  => ['Nazareus',   'Nazarenus',   [['Sing', 'S', 'Nom', '1']]],
                'nazarenus' => ['Nazareus',   'Nazarenus',   [['Sing', 'S', 'Nom', '1']]]
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
        elsif($f[1] =~ m/^(balšám|buochenc|čas|čin|déšč|div|dn|dóm|du?om|fík|hrob|hřie(ch|š)|chleb|kořen|ku?oš|kút|národ|neduh|okrajk|otrusk|pas|peniez|pláč|plamen|plášč|podhrdlk|podolk|poklad|příklad|rov|sbuor|skutk|sn|stien|stol|súd|ščěvík|tisíc|úd|u?oheň|u?ohn|u?ostatk|uzlíc|užitk|větr|vlas|zárodc|zástup|zbytk|zub)(a|e|ě|i|u|ové|óv|uov|iev|í|óm|uom|y|ách|iech)?$/i && $f[1] !~ m/^(dn[ay]|čin[ěí]|činiech|fíkové|pas[ae]?|pláče|súdí)$/i)
        {
            my $lform = lc($f[1]);
            my %ma =
            (
                'balšámu'     => ['balšám',    'balšám',  [['Sing', 'S', 'Gen', '2']]],
                'buochenciev' => ['bochník',   'buochenec', [['Plur', 'P', 'Gen', '2']]],
                'buochencóv'  => ['bochník',   'buochenec', [['Plur', 'P', 'Gen', '2']]],
                'čas'         => ['čas',       'čas',     [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Acc', '4']]],
                'časa'        => ['čas',       'čas',     [['Sing', 'S', 'Gen', '2']]],
                'čase'        => ['čas',       'čas',     [['Sing', 'S', 'Loc', '6']]],
                'časě'        => ['čas',       'čas',     [['Sing', 'S', 'Loc', '6']]],
                'časem'       => ['čas',       'čas',     [['Sing', 'S', 'Ins', '7']]],
                'časiech'     => ['čas',       'čas',     [['Plur', 'P', 'Loc', '6']]],
                'časóm'       => ['čas',       'čas',     [['Plur', 'P', 'Dat', '3']]],
                'časóv'       => ['čas',       'čas',     [['Plur', 'P', 'Gen', '2']]],
                'časové'      => ['čas',       'čas',     [['Plur', 'P', 'Nom', '1']]],
                'času'        => ['čas',       'čas',     [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Loc', '6']]],
                'časuov'      => ['čas',       'čas',     [['Plur', 'P', 'Gen', '2']]],
                'časy'        => ['čas',       'čas',     [['Plur', 'P', 'Ins', '7']]],
                'čin'         => ['čin',       'čin',     [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Acc', '4']]],
                'činem'       => ['čin',       'čin',     [['Sing', 'S', 'Ins', '7']]],
                'činóm'       => ['čin',       'čin',     [['Plur', 'P', 'Dat', '3']]],
                'činóv'       => ['čin',       'čin',     [['Plur', 'P', 'Gen', '2']]],
                'činové'      => ['čin',       'čin',     [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'činu'        => ['čin',       'čin',     [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'činy'        => ['čin',       'čin',     [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5'], ['Plur', 'P', 'Ins', '7']]],
                'déšč'        => ['déšť',      'déšč',    [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Acc', '4']]],
                'div'         => ['div',       'div',     [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Acc', '4']]],
                'diva'        => ['div',       'div',     [['Sing', 'S', 'Gen', '2']]],
                'divi'        => ['div',       'div',     [['Plur', 'P', 'Nom', '1']]],
                'divóm'       => ['div',       'div',     [['Plur', 'P', 'Dat', '3']]],
                'divóv'       => ['div',       'div',     [['Plur', 'P', 'Gen', '2']]],
                'divové'      => ['div',       'div',     [['Plur', 'P', 'Nom', '1']]],
                'divu'        => ['div',       'div',     [['Sing', 'S', 'Gen', '2']]],
                'divuov'      => ['div',       'div',     [['Plur', 'P', 'Gen', '2']]],
                'divy'        => ['div',       'div',     [['Plur', 'P', 'Acc', '4']]],
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
                'hrob'        => ['hrob',      'hrob',    [['Sing', 'S', 'Acc', '4']]],
                'hrobě'       => ['hrob',      'hrob',    [['Sing', 'S', 'Loc', '6']]],
                'hrobu'       => ['hrob',      'hrob',    [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Dat', '3']]],
                'hrobóm'      => ['hrob',      'hrob',    [['Plur', 'P', 'Dat', '3']]],
                'hrobóv'      => ['hrob',      'hrob',    [['Plur', 'P', 'Gen', '2']]],
                'hrobové'     => ['hrob',      'hrob',    [['Plur', 'P', 'Nom', '1']]],
                'hroby'       => ['hrob',      'hrob',    [['Plur', 'P', 'Acc', '4']]],
                'hřiech'      => ['hřích',     'hřiech',  [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Acc', '4']]],
                'hřiecha'     => ['hřích',     'hřiech',  [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'hřiechóm'    => ['hřích',     'hřiech',  [['Plur', 'P', 'Dat', '3']]],
                'hřiechóv'    => ['hřích',     'hřiech',  [['Plur', 'P', 'Gen', '2']]],
                'hřiechu'     => ['hřích',     'hřiech',  [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'hřiechy'     => ['hřích',     'hřiech',  [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5'], ['Plur', 'P', 'Ins', '7']]],
                'hřiešě'      => ['hřích',     'hřiech',  [['Sing', 'S', 'Loc', '6']]],
                'hřieši'      => ['hřích',     'hřiech',  [['Plur', 'P', 'Nom', '1']]],
                'hřiešiech'   => ['hřích',     'hřiech',  [['Plur', 'P', 'Loc', '6']]],
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
                'kořen'       => ['kořen',     'kořen',   [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Acc', '4']]],
                'kořene'      => ['kořen',     'kořen',   [['Sing', 'S', 'Gen', '2']]],
                'kořeni'      => ['kořen',     'kořen',   [['Sing', 'S', 'Dat', '3']]],
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
                'kút'         => ['kout',      'kút',     [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Acc', '4']]],
                'kúta'        => ['kout',      'kút',     [['Sing', 'S', 'Gen', '2']]],
                'kútě'        => ['kout',      'kút',     [['Sing', 'S', 'Loc', '6']]],
                'kútem'       => ['kout',      'kút',     [['Sing', 'S', 'Ins', '7']]],
                'kútiech'     => ['kout',      'kút',     [['Plur', 'P', 'Loc', '6']]],
                'kútóm'       => ['kout',      'kút',     [['Plur', 'P', 'Dat', '3']]],
                'kútóv'       => ['kout',      'kút',     [['Plur', 'P', 'Gen', '2']]],
                'kútu'        => ['kout',      'kút',     [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'kúty'        => ['kout',      'kút',     [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5'], ['Plur', 'P', 'Ins', '7']]],
                'národ'       => ['národ',     'národ',   [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Acc', '4']]],
                'národa'      => ['národ',     'národ',   [['Sing', 'S', 'Gen', '2']]],
                'národe'      => ['národ',     'národ',   [['Sing', 'S', 'Voc', '5']]],
                'národě'      => ['národ',     'národ',   [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'národiech'   => ['národ',     'národ',   [['Plur', 'P', 'Loc', '6']]],
                'národóm'     => ['národ',     'národ',   [['Plur', 'P', 'Dat', '3']]],
                'národóv'     => ['národ',     'národ',   [['Plur', 'P', 'Gen', '2']]],
                'národové'    => ['národ',     'národ',   [['Plur', 'P', 'Nom', '1']]],
                'národu'      => ['národ',     'národ',   [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'národy'      => ['národ',     'národ',   [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5'], ['Plur', 'P', 'Ins', '7']]],
                'neduh'       => ['neduh',     'neduh',   [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Acc', '4']]],
                'neduha'      => ['neduh',     'neduh',   [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'neduhu'      => ['neduh',     'neduh',   [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'neduhóm'     => ['neduh',     'neduh',   [['Plur', 'P', 'Dat', '3']]],
                'neduhóv'     => ['neduh',     'neduh',   [['Plur', 'P', 'Gen', '2']]],
                'neduhy'      => ['neduh',     'neduh',   [['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Ins', '7']]],
                'oheň'        => ['oheň',      'oheň',    [['Sing', 'S', 'Acc', '4']]],
                'ohně'        => ['oheň',      'oheň',    [['Sing', 'S', 'Gen', '2']]],
                'ohni'        => ['oheň',      'oheň',    [['Sing', 'S', 'Loc', '6']]],
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
                'pasóv'       => ['pas',       'pas',     [['Plur', 'P', 'Gen', '2']]],
                'peniez'      => ['peníz',     'peniez',  [['Sing', 'S', 'Acc', '4']]],
                'peniezě'     => ['peníz',     'peniez',  [['Plur', 'P', 'Acc', '4'], ['Sing', 'S', 'Gen', '2']]],
                'peniezi'     => ['peníz',     'peniez',  [['Sing', 'S', 'Loc', '6']]],
                'pláč'        => ['pláč',      'pláč',    [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Acc', '4']]],
                'pláčě'       => ['pláč',      'pláč',    [['Sing', 'S', 'Gen', '2']]], # Vyskytlo se i "pláče", ale v daném kontextu to bylo sloveso "plakat".
                'plamen'      => ['plamen',    'plamen',  [['Sing', 'S', 'Acc', '4']]],
                'plamene'     => ['plamen',    'plamen',  [['Sing', 'S', 'Gen', '2']]],
                'plášč'       => ['plášť',     'plášč',   [['Sing', 'S', 'Acc', '4']]],
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
                'poklad'      => ['poklad',    'poklad',  [['Sing', 'S', 'Acc', '4'], ['Sing', 'S', 'Nom', '1']]],
                'poklada'     => ['poklad',    'poklad',  [['Sing', 'S', 'Gen', '2']]],
                'pokladě'     => ['poklad',    'poklad',  [['Sing', 'S', 'Loc', '6']]],
                'pokladiech'  => ['poklad',    'poklad',  [['Plur', 'P', 'Loc', '6']]],
                'pokladóv'    => ['poklad',    'poklad',  [['Plur', 'P', 'Gen', '2']]],
                'pokladu'     => ['poklad',    'poklad',  [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Gen', '2']]],
                'poklady'     => ['poklad',    'poklad',  [['Plur', 'P', 'Acc', '4']]],
                'příklad'     => ['příklad',   'příklad', [['Sing', 'S', 'Acc', '4']]],
                'příkladiech' => ['příklad',   'příklad', [['Plur', 'P', 'Loc', '6']]],
                'příkladóv'   => ['příklad',   'příklad', [['Plur', 'P', 'Gen', '2']]],
                'příkladu'    => ['příklad',   'příklad', [['Sing', 'S', 'Dat', '3']]],
                'příklady'    => ['příklad',   'příklad', [['Plur', 'P', 'Acc', '4']]],
                'rov'         => ['rov',       'rov',     [['Sing', 'S', 'Acc', '4']]],
                'rově'        => ['rov',       'rov',     [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'roviech'     => ['rov',       'rov',     [['Plur', 'P', 'Loc', '6']]],
                'rovóm'       => ['rov',       'rov',     [['Plur', 'P', 'Dat', '3']]],
                'rovóv'       => ['rov',       'rov',     [['Plur', 'P', 'Gen', '2']]],
                'rovové'      => ['rov',       'rov',     [['Plur', 'P', 'Nom', '1']]],
                'rovu'        => ['rov',       'rov',     [['Sing', 'S', 'Gen', '2']]],
                'rovuom'      => ['rov',       'rov',     [['Plur', 'P', 'Dat', '3']]],
                'rovuov'      => ['rov',       'rov',     [['Plur', 'P', 'Gen', '2']]],
                'rovy'        => ['rov',       'rov',     [['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Ins', '7']]],
                'sbuoru'      => ['sbor',      'sbuor',   [['Sing', 'S', 'Gen', '2']]],
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
                'súd'         => ['soud',      'súd',     [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Acc', '4']]],
                'súda'        => ['soud',      'súd',     [['Sing', 'S', 'Gen', '2']]],
                'súdě'        => ['soud',      'súd',     [['Sing', 'S', 'Loc', '6']]],
                'súdem'       => ['soud',      'súd',     [['Sing', 'S', 'Ins', '7']]],
                'súdi'        => ['soud',      'súd',     [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'súdiech'     => ['soud',      'súd',     [['Plur', 'P', 'Loc', '6']]],
                'súdóm'       => ['soud',      'súd',     [['Plur', 'P', 'Dat', '3']]],
                'súdóv'       => ['soud',      'súd',     [['Plur', 'P', 'Gen', '2']]],
                'súdové'      => ['soud',      'súd',     [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'súdu'        => ['soud',      'súd',     [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Dat', '3']]],
                'súdy'        => ['soud',      'súd',     [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Ins', '7']]],
                'ščěvík'      => ['šťovík',    'ščěvík',  [['Sing', 'S', 'Nom', '1']]],
                'tisíc'       => ['tisíc',     'tisíc',   [['Sing', 'S', 'Acc', '4']]],
                'tisíce'      => ['tisíc',     'tisíc',   [['Plur', 'P', 'Acc', '4'], ['Dual', 'D', 'Acc', '4', 'MATT_(5\\.41)']]],
                'tisícě'      => ['tisíc',     'tisíc',   [['Plur', 'P', 'Nom', '1'], ['Dual', 'D', 'Acc', '4', 'MATT_(5\\.41)']]],
                'tisíci'      => ['tisíc',     'tisíc',   [['Sing', 'S', 'Dat', '3'], ['Plur', 'P', 'Ins', '7']]],
                'tisícóv'     => ['tisíc',     'tisíc',   [['Plur', 'P', 'Gen', '2']]],
                'údóv'        => ['úd',        'úd',      [['Plur', 'P', 'Gen', '2']]],
                'úduov'       => ['úd',        'úd',      [['Plur', 'P', 'Gen', '2']]],
                'údy'         => ['úd',        'úd',      [['Plur', 'P', 'Acc', '4']]],
                'uoheň'       => ['oheň',      'oheň',    [['Sing', 'S', 'Acc', '4']]],
                'uohni'       => ['oheň',      'oheň',    [['Sing', 'S', 'Loc', '6']]],
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
                'větra'       => ['vítr',      'vietr',   [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'větróm'      => ['vítr',      'vietr',   [['Plur', 'P', 'Dat', '3']]],
                'větróv'      => ['vítr',      'vietr',   [['Plur', 'P', 'Gen', '2']]],
                'větrové'     => ['vítr',      'vietr',   [['Plur', 'P', 'Nom', '1']]],
                'větry'       => ['vítr',      'vietr',   [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5'], ['Plur', 'P', 'Ins', '7']]],
                'vlas'        => ['vlas',      'vlas',    [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Acc', '4']]],
                'vlasa'       => ['vlas',      'vlas',    [['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'vlase'       => ['vlas',      'vlas',    [['Sing', 'S', 'Voc', '5']]],
                'vlasem'      => ['vlas',      'vlas',    [['Sing', 'S', 'Ins', '7']]],
                'vlasi'       => ['vlas',      'vlas',    [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'vlasóm'      => ['vlas',      'vlas',    [['Plur', 'P', 'Dat', '3']]],
                'vlasóv'      => ['vlas',      'vlas',    [['Plur', 'P', 'Gen', '2']]],
                'vlasové'     => ['vlas',      'vlas',    [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'vlasu'       => ['vlas',      'vlas',    [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'vlasy'       => ['vlas',      'vlas',    [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5'], ['Plur', 'P', 'Ins', '7']]],
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
                'zub'         => ['zub',       'zub',     [['Sing', 'S', 'Acc', '4'], ['Sing', 'S', 'Nom', '1']]],
                'zubóm'       => ['zub',       'zub',     [['Plur', 'P', 'Gen', '2']]], # BiblOl 8.12, 13.42, 13.49, 22.13 je to kupodivu fakt ve významu genitivu
                'zubóv'       => ['zub',       'zub',     [['Plur', 'P', 'Gen', '2']]],
                'zubové'      => ['zub',       'zub',     [['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Voc', '5']]],
                'zuby'        => ['zub',       'zub',     [['Plur', 'P', 'Acc', '4']]]
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
                'bethleema'   => ['Betlém',      'Bethlem',     [['Sing', 'S', 'Gen', '2']]],
                'bethleeme'   => ['Betlém',      'Bethlem',     [['Sing', 'S', 'Voc', '5']]],
                'bethleemě'   => ['Betlém',      'Bethlem',     [['Sing', 'S', 'Loc', '6']]],
                'bethlem'     => ['Betlém',      'Bethlem',     [['Sing', 'S', 'Nom', '1']]],
                'bethlema'    => ['Betlém',      'Bethlem',     [['Sing', 'S', 'Gen', '2']]],
                'bethlemi'    => ['Betlém',      'Bethlem',     [['Sing', 'S', 'Loc', '6']]],
                'jeruzalém'   => ['Jeruzalém',   'Jeruzalém',   [['Sing', 'S', 'Nom', '1']]],
                'jeruzaléma'  => ['Jeruzalém',   'Jeruzalém',   [['Sing', 'S', 'Gen', '2']]],
                'jeruzaléme'  => ['Jeruzalém',   'Jeruzalém',   [['Sing', 'S', 'Voc', '5']]],
                'jeruzalémě'  => ['Jeruzalém',   'Jeruzalém',   [['Sing', 'S', 'Loc', '6']]],
                'jeruzalémi'  => ['Jeruzalém',   'Jeruzalém',   [['Sing', 'S', 'Loc', '6']]],
                'jordána'     => ['Jordán',      'Jordán',      [['Sing', 'S', 'Gen', '2']]],
                'jordánu'     => ['Jordán',      'Jordán',      [['Sing', 'S', 'Dat', '3']]],
                'jordán'      => ['Jordán',      'Jordán',      [['Sing', 'S', 'Acc', '4']]],
                'jordáne'     => ['Jordán',      'Jordán',      [['Sing', 'S', 'Voc', '5']]],
                'jordáně'     => ['Jordán',      'Jordán',      [['Sing', 'S', 'Loc', '6']]],
                'jordánem'    => ['Jordán',      'Jordán',      [['Sing', 'S', 'Ins', '7']]],
                'korozaim'    => ['Korozaim',    'Korozaim',    [['Sing', 'S', 'Voc', '5']]],
                'nazaret'     => ['Nazaret',     'Nazareth',    [['Sing', 'S', 'Nom', '1']]],
                'nazareta'    => ['Nazaret',     'Nazareth',    [['Sing', 'S', 'Gen', '2']]],
                'nazareth'    => ['Nazaret',     'Nazareth',    [['Sing', 'S', 'Nom', '1']]]
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
        elsif(!($f[1] =~ m/^hoře$/i && get_ref($f[9]) !~ m/^MATT_24\.3$/ || $f[1] =~ m/^(duše|hoři?)$/) &&
              $f[1] =~ m/^(buožnic|cěst|dci|dn|duš|hu?o[rř]|libř|lichv|mátě|m[aá]teř|matk|měřic|mís|modlitv|n[oó][hz]|potop|přísah|púš[čtť]|rez|ruc|siet|sól|stred|suol|světedlnic|škuol|trúb|ulic|u?ovc|vesnic|vier|vinn|vuod)(e|ě|i|í|y|u|ú|iem|iech|ách|ami)?$/i)
        {
            my $lform = lc($f[1]);
            my %ma =
            (
                'buožniciech' => ['božnice',  'buožnicě', [['Plur', 'P', 'Loc', '6']]], # asi kostel, chrám
                'cěst'        => ['cesta',    'cěsta',    [['Sing', 'S', 'Gen', '2']]],
                'cěsta'       => ['cesta',    'cěsta',    [['Sing', 'S', 'Nom', '1']]],
                'cěstách'     => ['cesta',    'cěsta',    [['Plur', 'P', 'Loc', '6']]],
                'cěstě'       => ['cesta',    'cěsta',    [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'cěstu'       => ['cesta',    'cěsta',    [['Sing', 'S', 'Acc', '4']]],
                'cěstú'       => ['cesta',    'cěsta',    [['Sing', 'S', 'Ins', '7']]],
                'cěsty'       => ['cesta',    'cěsta',    [['Sing', 'S', 'Gen', '2'], ['Plur', 'P', 'Acc', '4']]],
                'dci'         => ['dcera',    'dci',      [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Voc', '5', 'MATT_9\\.22']]],
                'dnu'         => ['dna',      'dna',      [['Sing', 'S', 'Acc', '4']]],
                'dnú'         => ['dna',      'dna',      [['Sing', 'S', 'Ins', '7']]],
                'dny'         => ['dna',      'dna',      [['Sing', 'S', 'Gen', '2']]],
                'dušě'        => ['duše',     'dušě',     [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Gen', '2']]], ###!!! Ale BiblOl 3.11: 'v dušě svatém'. Neumíme poznat, že tady to má být rod mužský.
                'duši'        => ['duše',     'dušě',     [['Sing', 'S', 'Acc', '4'], ['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'dušiem'      => ['duše',     'dušě',     [['Plur', 'P', 'Dat', '3']]],
                'dušu'        => ['duše',     'dušě',     [['Sing', 'S', 'Acc', '4']]],
                'hora'        => ['hora',     'huora',    [['Sing', 'S', 'Nom', '1']]],
                'horách'      => ['hora',     'huora',    [['Plur', 'P', 'Loc', '6']]],
                'horami'      => ['hora',     'huora',    [['Plur', 'P', 'Ins', '7']]],
                'horu'        => ['hora',     'huora',    [['Sing', 'S', 'Acc', '4']]],
                'horú'        => ['hora',     'huora',    [['Sing', 'S', 'Ins', '7']]],
                'hory'        => ['hora',     'huora',    [['Sing', 'S', 'Gen', '2'], ['Plur', 'P', 'Acc', '4']]],
                'hoře'        => ['hora',     'huora',    [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6', 'MATT_24\\.3']]],
                'hořě'        => ['hora',     'huora',    [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'huoru'       => ['hora',     'huora',    [['Sing', 'S', 'Acc', '4']]],
                'huory'       => ['hora',     'huora',    [['Sing', 'S', 'Gen', '2']]],
                'huoře'       => ['hora',     'huora',    [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6', 'MATT_5\\.14']]],
                'huořě'       => ['hora',     'huora',    [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6', 'MATT_5\\.14']]],
                'libřě'       => ['libra',    'libra',    [['Dual', 'D', 'Acc', '4']]],
                'lichva'      => ['lichva',   'lichva',   [['Sing', 'S', 'Nom', '1']]],
                'lichvě'      => ['lichva',   'lichva',   [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'lichvo'      => ['lichva',   'lichva',   [['Sing', 'S', 'Voc', '5']]],
                'lichvu'      => ['lichva',   'lichva',   [['Sing', 'S', 'Acc', '4']]],
                'lichvú'      => ['lichva',   'lichva',   [['Sing', 'S', 'Ins', '7']]],
                'lichvy'      => ['lichva',   'lichva',   [['Sing', 'S', 'Gen', '2']]],
                'mátě'   => ['máti', 'máti', [['Sing', 'S', 'Nom', '1']]],
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
                'púšťi'    => ['poušť', 'púščě', [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Acc', '4'], ['Sing', 'S', 'Loc', '6']]],
                'púšťí'    => ['poušť', 'púščě', [['Sing', 'S', 'Ins', '7'], ['Plur', 'P', 'Gen', '2']]],
                'púšťiech' => ['poušť', 'púščě', [['Plur', 'P', 'Loc', '6']]],
                'púšťiem'  => ['poušť', 'púščě', [['Plur', 'P', 'Dat', '3']]],
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
                'sieti'       => ['síť',      'sieť',     [['Plur', 'P', 'Acc', '4']]],
                'sól'         => ['sůl',      'sól',      [['Sing', 'S', 'Nom', '1']]],
                'stred'       => ['stred',    'stred',    [['Sing', 'S', 'Nom', '1']]], # stred = strdí = med
                'suol'        => ['sůl',      'sól',      [['Sing', 'S', 'Nom', '1']]],
                'světedlnicě'   => ['světelnice', 'světedlnicě', [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Gen', '2'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4']]],
                'světedlnicěmi' => ['světelnice', 'světedlnicě', [['Plur', 'P', 'Ins', '7']]],
                'škuolách'      => ['škola',      'škuola',      [['Plur', 'P', 'Loc', '6']]],
                'škuoly'        => ['škola',      'škuola',      [['Sing', 'S', 'Gen', '2']]],
                'trúba'         => ['trouba',     'trúba',       [['Sing', 'S', 'Nom', '1']]],
                'trúbě'         => ['trouba',     'trúba',       [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'trúbu'         => ['trouba',     'trúba',       [['Sing', 'S', 'Acc', '4']]],
                'trúbú'         => ['trouba',     'trúba',       [['Sing', 'S', 'Ins', '7']]],
                'trúby'         => ['trouba',     'trúba',       [['Sing', 'S', 'Gen', '2']]],
                'ulic'          => ['ulice',      'ulicě',       [['Plur', 'P', 'Gen', '2']]],
                'ulicě'         => ['ulice',      'ulicě',       [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Gen', '2'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Voc', '5']]],
                'uliciech'      => ['ulice',      'ulicě',       [['Plur', 'P', 'Loc', '6']]],
                'vesnic'        => ['vesnice',    'vesnicě',     [['Plur', 'P', 'Gen', '2']]],
                'vesnici'       => ['vesnice',    'vesnicě',     [['Sing', 'S', 'Acc', '4']]],
                'vesniciech'    => ['vesnice',    'vesnicě',     [['Plur', 'P', 'Loc', '6']]],
                'viera'         => ['víra',       'viera',       [['Sing', 'S', 'Nom', '1']]],
                'vieru'         => ['víra',       'viera',       [['Sing', 'S', 'Acc', '4']]],
                'viery'         => ['víra',       'viera',       [['Sing', 'S', 'Gen', '2']]],
                'vinnu'         => ['vina',       'vinna',       [['Sing', 'S', 'Acc', '4']]],
                'vinny'         => ['vina',       'vinna',       [['Sing', 'S', 'Gen', '2']]],
                'vuodách'       => ['voda',       'vuoda',       [['Plur', 'P', 'Loc', '6']]],
                'vuodě'         => ['voda',       'vuoda',       [['Sing', 'S', 'Loc', '6']]],
                'vuodu'         => ['voda',       'vuoda',       [['Sing', 'S', 'Acc', '4']]],
                'vuody'         => ['voda',       'vuoda',       [['Sing', 'S', 'Gen', '2']]]
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
                'maria'    => ['Marie',   'Maria',   [['Sing', 'S', 'Nom', '1']]],
                'marie'    => ['Marie',   'Maria',   [['Sing', 'S', 'Gen', '2']]],
                'mařie'    => ['Marie',   'Maria',   [['Sing', 'S', 'Dat', '3']]],
                'mářie'    => ['Marie',   'Maria',   [['Sing', 'S', 'Gen', '2']]],
                'marijí'   => ['Marie',   'Maria',   [['Sing', 'S', 'Ins', '7']]],
                'maří'     => ['Marie',   'Maria',   [['Sing', 'S', 'Ins', '7']]],
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
                'betaní'      => ['Betanie',   'Betanie',   [['Sing', 'S', 'Loc', '6']]],
                'betanie'     => ['Betanie',   'Betanie',   [['Sing', 'S', 'Gen', '2']]],
                'dekapoli'    => ['Dekapolis', 'Dekapolis', [['Sing', 'S', 'Gen', '2']]],
                'galilé'      => ['Galilea',   'Galilea',   [['Sing', 'S', 'Gen', '2']]],
                'galilea'     => ['Galilea',   'Galilea',   [['Sing', 'S', 'Nom', '1']]],
                'galilee'     => ['Galilea',   'Galilea',   [['Sing', 'S', 'Gen', '2']]],
                'galilei'     => ['Galilea',   'Galilea',   [['Sing', 'S', 'Loc', '6']]],
                'golgata'     => ['Golgata',   'Golgata',   [['Sing', 'S', 'Nom', '1']]],
                'sodomě'      => ['Sodoma',    'Sodoma',    [['Sing', 'S', 'Loc', '6']]], # oba výskyty jsou lokativ
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
              $f[1] =~ m/^(břiem|břiš|diet|dietek|dietky|d(?:ó|uo)stojenstv|hniezd|hoř|jm|jmen|kniež|ledv|let|měst|miest|násil|neb|nebes|oc|oslíč|písemc|práv|rob|robátk|rúch|sěn|siem|slovc|srde?c|trn|tržišč|ust|vajc|zábradl)(o|e|é|ě|ie|a|i|u|ú|í|em|[eě]t[ei]|ata?|atóm|atuom|i?ech|ách|ích|aty)?$/i && $f[1] !~ m/^(diet[ei]|hniezdie|hoř|hořěti|jm[eiu]?|jmie|letie|letí|násil|nebo?|nebiech|nebích)$/i)
        {
            my $lform = lc($f[1]);
            my %ma =
            (
                'břiemě'      => ['břemeno',  'břiemě',   [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Acc', '4']]],
                'břiše'       => ['břicho',   'břicho',   [['Sing', 'S', 'Loc', '6']]],
                'břišě'       => ['břicho',   'břicho',   [['Sing', 'S', 'Loc', '6']]],
                'dietě'       => ['dítě',     'dietě',    [['Sing', 'S', 'Acc', '4'], ['Sing', 'S', 'Nom', '1']]],
                'dietek'      => ['dítě',     'dietě',    [['Plur', 'P', 'Gen', '2']]],
                'dietěte'     => ['dítě',     'dietě',    [['Sing', 'S', 'Gen', '2']]],
                'dietěti'     => ['dítě',     'dietě',    [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'dietky'      => ['dítě',     'dietě',    [['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Nom', '1']]],
                'dóstojenstva'   => ['důstojenství', 'dóstojenstvie', [['Sing', 'S', 'Gen', '2']]],
                'dóstojenstvie'  => ['důstojenství', 'dóstojenstvie', [['Sing', 'S', 'Acc', '4']]],
                'duostojenstvie' => ['důstojenství', 'dóstojenstvie', [['Sing', 'S', 'Gen', '2']]],
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
                'let'         => ['rok',      'rok',      [['Plur', 'P', 'Gen', '2']]],
                'letú'        => ['rok',      'rok',      [['Dual', 'D', 'Gen', '2']]],
                'měst'        => ['město',    'město',    [['Plur', 'P', 'Gen', '2']]],
                'města'       => ['město',    'město',    [['Sing', 'S', 'Gen', '2'], ['Plur', 'P', 'Acc', '4']]],
                'městě'       => ['město',    'město',    [['Sing', 'S', 'Loc', '6']]],
                'městech'     => ['město',    'město',    [['Plur', 'P', 'Loc', '6']]],
                'městiech'    => ['město',    'město',    [['Plur', 'P', 'Loc', '6']]],
                'město'       => ['město',    'město',    [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Acc', '4']]],
                'městu'       => ['město',    'město',    [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'městy'       => ['město',    'město',    [['Plur', 'P', 'Ins', '7']]],
                'miest'       => ['místo',    'miesto',   [['Plur', 'P', 'Gen', '2']]],
                'miesta'      => ['místo',    'miesto',   [['Sing', 'S', 'Gen', '2']]],
                'miesto'      => ['místo',    'miesto',   [['Sing', 'S', 'Acc', '4'], ['Sing', 'S', 'Nom', '1']]],
                'miestě'      => ['místo',    'miesto',   [['Sing', 'S', 'Loc', '6']]],
                'miestech'    => ['místo',    'miesto',   [['Plur', 'P', 'Loc', '6']]],
                'miestiech'   => ['místo',    'miesto',   [['Plur', 'P', 'Loc', '6']]],
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
                'robat'       => ['robě',     'robě',     [['Plur', 'P', 'Gen', '2']]],
                'robátka'     => ['robátko',  'robátko',  [['Sing', 'S', 'Gen', '2'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4']]],
                'robatuom'    => ['robě',     'robě',     [['Plur', 'P', 'Dat', '3']]],
                'rúcha'       => ['roucho',   'rúcho',    [['Sing', 'S', 'Gen', '2'], ['Plur', 'P', 'Nom', '1'], ['Plur', 'P', 'Acc', '4']]],
                'rúchem'      => ['roucho',   'rúcho',    [['Sing', 'S', 'Ins', '7']]],
                'rúcho'       => ['roucho',   'rúcho',    [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Acc', '4']]],
                'rúchu'       => ['roucho',   'rúcho',    [['Sing', 'S', 'Dat', '3']]],
                'sěně'        => ['seno',     'sěno',     [['Sing', 'S', 'Loc', '6']]],
                'sěno'        => ['seno',     'sěno',     [['Sing', 'S', 'Acc', '4']]],
                'siemě'       => ['semeno',   'siemě',    [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Acc', '4']]],
                'slovce'      => ['slovo',    'slovce',   [['Sing', 'S', 'Nom', '1']]],
                'srdce'       => ['srdce',    'srdce',    [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Acc', '4']]],
                'srdcě'       => ['srdce',    'srdce',    [['Sing', 'S', 'Gen', '2']]],
                'srdcem'      => ['srdce',    'srdce',    [['Sing', 'S', 'Ins', '7']]],
                'srdci'       => ['srdce',    'srdce',    [['Sing', 'S', 'Loc', '6'], ['Sing', 'S', 'Dat', '3']]],
                'srdcí'       => ['srdce',    'srdce',    [['Plur', 'P', 'Gen', '2']]],
                'srdcích'     => ['srdce',    'srdce',    [['Plur', 'P', 'Loc', '6']]],
                'srdcu'       => ['srdce',    'srdce',    [['Sing', 'S', 'Dat', '3'], ['Sing', 'S', 'Loc', '6']]],
                'srdec'       => ['srdce',    'srdce',    [['Plur', 'P', 'Gen', '2']]],
                'trní'        => ['trní',     'trnie',    [['Sing', 'S', 'Loc', '6']]],
                'trnie'       => ['trní',     'trnie',    [['Sing', 'S', 'Nom', '1'], ['Sing', 'S', 'Gen', '2'], ['Sing', 'S', 'Acc', '4']]],
                'trním'       => ['trní',     'trnie',    [['Sing', 'S', 'Ins', '7']]],
                'tržišči'     => ['tržiště',  'tržišče',  [['Sing', 'S', 'Loc', '6']]],
                'usta'        => ['ústa',     'usta',     [['Plur', 'P', 'Acc', '4'], ['Plur', 'P', 'Nom', '1']]],
                'ustech'      => ['ústa',     'usta',     [['Plur', 'P', 'Loc', '6']]],
                'ustiech'     => ['ústa',     'usta',     [['Plur', 'P', 'Loc', '6']]],
                'vajce'       => ['vejce',    'vajce',    [['Sing', 'S', 'Acc', '4']]],
                'zábradlách'  => ['zábradlí', 'zábradlo', [['Plur', 'P', 'Loc', '6']]]
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
                'biela'     => ['bílý',      'bielý',     [['Inan', 'I', 'Sing', 'S', 'Acc', '4']]],
                'bielo'     => ['bílý',      'bielý',     [['Neut', 'N', 'Sing', 'S', 'Nom', '1']]],
                'črna'      => ['černý',     'črný',      [['Inan', 'I', 'Sing', 'S', 'Acc', '4']]],
                'dóstojen'  => ['důstojný',  'dóstojný',  [['Anim', 'M', 'Sing', 'S', 'Nom', '1']]],
                'dóstojni'  => ['důstojný',  'dóstojný',  [['Anim', 'M', 'Plur', 'P', 'Nom', '1']]],
                'duostojen' => ['důstojný',  'dóstojný',  [['Anim', 'M', 'Sing', 'S', 'Nom', '1']]],
                'duostojni' => ['důstojný',  'dóstojný',  [['Anim', 'M', 'Plur', 'P', 'Nom', '1']]],
                'hotov'     => ['hotový',    'hotový',    [['Anim', 'M', 'Sing', 'S', 'Nom', '1']]],
                'hotova'    => ['hotový',    'hotový',    [['Fem',  'F', 'Sing', 'S', 'Nom', '1']]],
                'hotovi'    => ['hotový',    'hotový',    [['Anim', 'M', 'Plur', 'P', 'Nom', '1']]],
                'hotovo'    => ['hotový',    'hotový',    [['Neut', 'N', 'Sing', 'S', 'Nom', '1']]],
                'hotovy'    => ['hotový',    'hotový',    [['Fem',  'F', 'Plur', 'P', 'Nom', '1']]],
                'lačen'     => ['lačný',     'lačný',     [['Anim', 'M', 'Sing', 'S', 'Nom', '1']]],
                'lačna'     => ['lačný',     'lačný',     [['Anim', 'M', 'Sing', 'S', 'Acc', '4']]],
                'lačni'     => ['lačný',     'lačný',     [['Anim', 'M', 'Plur', 'P', 'Nom', '1']]],
                'mocen'     => ['mocný',     'mocný',     [['Anim', 'M', 'Sing', 'S', 'Nom', '1']]],
                'náh'       => ['nahý',      'nahý',      [['Anim', 'M', 'Sing', 'S', 'Nom', '1']]],
                'náha'      => ['nahý',      'nahý',      [['Anim', 'M', 'Sing', 'S', 'Acc', '4']]],
                'náměséčny' => ['náměsíčný', 'náměsíčný', [['Anim', 'M', 'Plur', 'P', 'Acc', '4']]],
                'nemocen'   => ['nemocný',   'nemocný',   [['Anim', 'M', 'Sing', 'S', 'Nom', '1']]],
                'nemocna'   => ['nemocný',   'nemocný',   [['Anim', 'M', 'Sing', 'S', 'Acc', '4']]],
                'nemocni'   => ['nemocný',   'nemocný',   [['Anim', 'M', 'Plur', 'P', 'Nom', '1']]],
                'nemocno'   => ['nemocný',   'nemocný',   [['Neut', 'N', 'Sing', 'S', 'Nom', '1']]],
                'nici'      => ['nicí',      'nicí',      [['Anim', 'M', 'Plur', 'P', 'Nom', '1']]], # https://vokabular.ujc.cas.cz/hledani.aspx?hw=nic%C3%AD
                'pln'       => ['plný',      'plný',      [['Anim', 'M', 'Sing', 'S', 'Nom', '1'], ['Anim', 'M', 'Sing', 'S', 'Acc', '4']]],
                'plna'      => ['plný',      'plný',      [['Fem',  'F', 'Sing', 'S', 'Nom', '1']]],
                'plni'      => ['plný',      'plný',      [['Anim', 'M', 'Plur', 'P', 'Nom', '1']]],
                'podoben'   => ['podobný',   'podobný',   [['Anim', 'M', 'Sing', 'S', 'Nom', '1']]],
                'podobni'   => ['podobný',   'podobný',   [['Anim', 'M', 'Plur', 'P', 'Nom', '1']]],
                'podobno'   => ['podobný',   'podobný',   [['Neut', 'N', 'Sing', 'S', 'Nom', '1']]],
                'poslušen'  => ['poslušný',  'poslušný',  [['Anim', 'M', 'Sing', 'S', 'Nom', '1']]],
                'poslušni'  => ['poslušný',  'poslušný',  [['Anim', 'M', 'Plur', 'P', 'Nom', '1']]],
                'povinen'   => ['povinný',   'povinný',   [['Anim', 'M', 'Sing', 'S', 'Nom', '1']]],
                'smuten'    => ['smutný',    'smutný',    [['Anim', 'M', 'Sing', 'S', 'Nom', '1']]],
                'smutna'    => ['smutný',    'smutný',    [['Fem',  'F', 'Sing', 'S', 'Nom', '1']]],
                'smutni'    => ['smutný',    'smutný',    [['Anim', 'M', 'Plur', 'P', 'Nom', '1']]],
                'smutno'    => ['smutný',    'smutný',    [['Neut', 'N', 'Sing', 'S', 'Nom', '1']]],
                'vinen'     => ['vinný',     'vinný',     [['Anim', 'M', 'Sing', 'S', 'Nom', '1']]],
                'známa'     => ['známý',     'známý',     [['Anim', 'M', 'Sing', 'S', 'Acc', '4']]],
                'známo'     => ['známý',     'známý',     [['Neut', 'N', 'Sing', 'S', 'Nom', '1']]],
                'známy'     => ['známý',     'známý',     [['Fem',  'F', 'Plur', 'P', 'Nom', '1']]],
                'žiezliv'   => ['žíznivý',   'žieznivý',  [['Anim', 'M', 'Sing', 'S', 'Nom', '1']]],
                'žiezliva'  => ['žíznivý',   'žieznivý',  [['Anim', 'M', 'Sing', 'S', 'Acc', '4']]],
                'žiezlivi'  => ['žíznivý',   'žieznivý',  [['Anim', 'M', 'Plur', 'P', 'Nom', '1']]],
                'žiezniv'   => ['žíznivý',   'žieznivý',  [['Anim', 'M', 'Sing', 'S', 'Nom', '1']]],
                'žiezniva'  => ['žíznivý',   'žieznivý',  [['Anim', 'M', 'Sing', 'S', 'Acc', '4']]],
                'živ'       => ['živý',      'živý',      [['Anim', 'M', 'Sing', 'S', 'Nom', '1']]],
                'žív'       => ['živý',      'živý',      [['Anim', 'M', 'Sing', 'S', 'Nom', '1']]],
                'živa'      => ['živý',      'živý',      [['Fem',  'F', 'Sing', 'S', 'Nom', '1']]],
                'živi'      => ['živý',      'živý',      [['Anim', 'M', 'Plur', 'P', 'Nom', '1']]],
                'živy'      => ['živý',      'živý',      [['Anim', 'M', 'Plur', 'P', 'Acc', '4']]]
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
        elsif($f[1] =~ m/^(dobreh|d(?:ó|uo)stojn|jin|lesk|lidsk|nebe(?:sk|št)|neptalimov(?:sk)?|ohněv|popov|propuščen|smrtedln|velik|vysok|židov(?:sk|št)?)(ý|á|é|ého|ém|ým|ú|éj|ie|í|ých|ými)$/i)
        {
            my $lform = lc($f[1]);
            my %ma =
            (
                'dobrehého'  => ['dobrý',    'dobrý',     [['Neut', 'N', 'Sing', 'S', 'Gen', '2']]], # Drážďanská bible Mt. 3.10: Zde by možná mělo být Typo=Yes.
                'dóstojný'   => ['důstojný', 'dóstojný',  [['Anim', 'M', 'Sing', 'S', 'Nom', '1'], ['Inan', 'I', 'Sing', 'S', 'Nom', '1']]],
                'duostojné'  => ['důstojný', 'dóstojný',  [['Inan', 'I', 'Plur', 'P', 'Acc', '4']]],
                'duostojný'  => ['důstojný', 'dóstojný',  [['Anim', 'M', 'Sing', 'S', 'Nom', '1'], ['Inan', 'I', 'Sing', 'S', 'Nom', '1']]],
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
                'ohněvý'      => ['ohnivý',   'ohněvý',    [['Inan', 'I', 'Sing', 'S', 'Acc', '4']]],
                'ohněvým'     => ['ohnivý',   'ohněvý',    [['Inan', 'I', 'Sing', 'S', 'Ins', '7']]],
                'popová'      => ['popový',   'popový',    [['Neut', 'N', 'Plur', 'P', 'Nom', '1'], ['Neut', 'N', 'Plur', 'P', 'Acc', '4']]],
                'popové'      => ['popový',   'popový',    [['Neut', 'N', 'Sing', 'S', 'Nom', '1']]],
                'popového'    => ['popový',   'popový',    [['Neut', 'N', 'Sing', 'S', 'Gen', '2']]],
                'popových'    => ['popový',   'popový',    [['Masc', 'M', 'Plur', 'P', 'Gen', '2']]],
                'popovým'     => ['popový',   'popový',    [['Neut', 'N', 'Plur', 'P', 'Dat', '3']]],
                'propuščenú'  => ['propuštěný', 'propuščený', [['Fem', 'F', 'Sing', 'S', 'Acc', '4']]], # + Aspect=Perf|VerbForm=Part|Voice=Pass
                'smrtedlné'   => ['smrtelný', 'smrtedlný', [['Fem',  'F', 'Plur', 'P', 'Nom', '1']]],
                'smrtedlném'  => ['smrtelný', 'smrtedlný', [['Inan', 'I', 'Sing', 'S', 'Loc', '6']]],
                'smrtedlnými' => ['smrtelný', 'smrtedlný', [['Inan', 'I', 'Plur', 'P', 'Ins', '7']]],
                'veliká'      => ['veliký',   'veliký',    [['Fem',  'F', 'Sing', 'S', 'Nom', '1'], ['Neut', 'N', 'Plur', 'P', 'Nom', '1'], ['Neut', 'N', 'Plur', 'P', 'Acc', '4']]],
                'veliké'      => ['veliký',   'veliký',    [['Neut', 'N', 'Sing', 'S', 'Nom', '1'], ['Neut', 'N', 'Sing', 'S', 'Acc', '4'], ['Inan', 'I', 'Plur', 'P', 'Acc', '4'], ['Fem', 'F', 'Plur', 'P', 'Acc', '4']]],
                'velikého'    => ['veliký',   'veliký',    [['Anim', 'M', 'Sing', 'S', 'Gen', '2']]],
                'velikéj'     => ['veliký',   'veliký',    [['Fem',  'F', 'Sing', 'S', 'Gen', '2']]],
                'velikém'     => ['veliký',   'veliký',    [['Inan', 'I', 'Sing', 'S', 'Loc', '6']]],
                'velikú'      => ['veliký',   'veliký',    [['Fem',  'F', 'Sing', 'S', 'Acc', '4'], ['Fem',  'F', 'Sing', 'S', 'Ins', '7']]],
                'veliký'      => ['veliký',   'veliký',    [['Anim', 'M', 'Sing', 'S', 'Nom', '1'], ['Inan', 'I', 'Sing', 'S', 'Nom', '1'], ['Inan', 'I', 'Sing', 'S', 'Acc', '4']]],
                'velikých'    => ['veliký',   'veliký',    [['Anim', 'M', 'Plur', 'P', 'Gen', '2'], ['Inan', 'I', 'Plur', 'P', 'Gen', '2'], ['Fem',  'F', 'Plur', 'P', 'Gen', '2'], ['Neut', 'N', 'Plur', 'P', 'Gen', '2']]],
                'velikým'     => ['veliký',   'veliký',    [['Anim', 'M', 'Sing', 'S', 'Ins', '7'], ['Inan', 'I', 'Sing', 'S', 'Ins', '7']]],
                'velikými'    => ['veliký',   'veliký',    [['Anim', 'M', 'Plur', 'P', 'Ins', '7'], ['Inan', 'I', 'Plur', 'P', 'Ins', '7'], ['Fem',  'F', 'Plur', 'P', 'Ins', '7'], ['Neut', 'N', 'Plur', 'P', 'Ins', '7']]],
                'vysoká'      => ['vysoký',   'vysoký',    [['Fem',  'F', 'Sing', 'S', 'Nom', '1']]],
                'vysoké'      => ['vysoký',   'vysoký',    [['Fem',  'F', 'Sing', 'S', 'Gen', '2']]],
                'vysokého'    => ['vysoký',   'vysoký',    [['Anim', 'M', 'Sing', 'S', 'Gen', '2'], ['Inan', 'I', 'Sing', 'S', 'Gen', '2'], ['Neut', 'N', 'Sing', 'S', 'Gen', '2']]],
                'vysokú'      => ['vysoký',   'vysoký',    [['Fem',  'F', 'Sing', 'S', 'Acc', '4']]],
                'vysoký'      => ['vysoký',   'vysoký',    [['Anim', 'M', 'Sing', 'S', 'Nom', '1'], ['Anim', 'M', 'Sing', 'S', 'Voc', '5'], ['Inan', 'I', 'Sing', 'S', 'Nom', '1'], ['Inan', 'I', 'Sing', 'S', 'Voc', '5']]],
                'židovská'    => ['židovský', 'židovský',  [['Fem',  'F', 'Sing', 'S', 'Nom', '1']]],
                'židovské'    => ['židovský', 'židovský',  [['Fem',  'F', 'Sing', 'S', 'Gen', '2'], ['Fem',  'F', 'Sing', 'S', 'Loc', '6'], ['Neut', 'N', 'Sing', 'S', 'Nom', '1'], ['Anim', 'M', 'Plur', 'P', 'Acc', '4']]],
                'židovskéj'   => ['židovský', 'židovský',  [['Fem',  'F', 'Sing', 'S', 'Loc', '6']]],
                'židovském'   => ['židovský', 'židovský',  [['Inan', 'I', 'Sing', 'S', 'Loc', '6'], ['Neut', 'N', 'Sing', 'S', 'Loc', '6']]],
                'židovský'    => ['židovský', 'židovský',  [['Anim', 'M', 'Sing', 'S', 'Nom', '1'], ['Inan', 'I', 'Sing', 'S', 'Acc', '4']]],
                'židovských'  => ['židovský', 'židovský',  [['Anim', 'M', 'Plur', 'P', 'Gen', '2'], ['Inan', 'I', 'Plur', 'P', 'Gen', '2'], ['Fem',  'F', 'Plur', 'P', 'Gen', '2'], ['Neut', 'N', 'Plur', 'P', 'Gen', '2']]],
                'židovským'   => ['židovský', 'židovský',  [['Anim', 'M', 'Sing', 'S', 'Ins', '7'], ['Inan', 'I', 'Sing', 'S', 'Ins', '7'], ['Neut', 'N', 'Sing', 'S', 'Ins', '7'], ['Anim', 'M', 'Plur', 'P', 'Dat', '3'], ['Inan', 'I', 'Plur', 'P', 'Dat', '3'], ['Fem', 'F', 'Plur', 'P', 'Dat', '3'], ['Neut', 'N', 'Plur', 'P', 'Dat', '3']]],
                'židovskými'  => ['židovský', 'židovský',  [['Neut', 'N', 'Plur', 'P', 'Ins', '7']]],
                'židovští'    => ['židovský', 'židovský',  [['Anim', 'M', 'Plur', 'P', 'Nom', '1']]]
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
                'boží'         => ['boží',     'boží',      [['Anim', 'M', 'Sing', 'S', 'Nom', '1']]], # Slovo "boží" by mohly být různé tvary, ale většinou je to "anjel boží" nebo "syn boží" v nominativu.
                'božie'        => ['boží',     'boží',      [['Neut', 'N', 'Sing', 'S', 'Nom', '1'], ['Neut', 'N', 'Sing', 'S', 'Acc', '4'], ['Fem', 'F', 'Sing', 'S', 'Gen', '2'], ['Fem', 'F', 'Plur', 'P', 'Acc', '4']]], # aby sě naplnilo slovo božie; vzemše přikázanie božie; připravujte cěsty božie; nevědúce písma ani moci božie
                'božieho'      => ['boží',     'boží',      [['Inan', 'I', 'Sing', 'S', 'Gen', '2'], ['Anim', 'M', 'Sing', 'S', 'Acc', '4']]],
                'božiej'       => ['boží',     'boží',      [['Fem',  'F', 'Sing', 'S', 'Dat', '3'], ['Fem',  'F', 'Sing', 'S', 'Loc', '6']]],
                'božiem'       => ['boží',     'boží',      [['Anim', 'M', 'Sing', 'S', 'Loc', '6']]], # v duchu božiem
                'božiemu'      => ['boží',     'boží',      [['Anim', 'M', 'Sing', 'S', 'Dat', '3']]], # k oltářu božiemu
                'božích'       => ['boží',     'boží',      [['Neut', 'N', 'Plur', 'P', 'Gen', '2']]], # z úst božích
                'božím'        => ['boží',     'boží',      [['Anim', 'M', 'Sing', 'S', 'Loc', '6'], ['Inan', 'I', 'Sing', 'S', 'Loc', '6'], ['Neut', 'N', 'Sing', 'S', 'Loc', '6'], ['Anim', 'M', 'Sing', 'S', 'Ins', '7'], ['Inan', 'I', 'Sing', 'S', 'Ins', '7'], ['Neut', 'N', 'Sing', 'S', 'Ins', '7']]],
                'božú'         => ['boží',     'boží',      [['Fem',  'F', 'Sing', 'S', 'Acc', '4']]],
                'buoží'        => ['boží',     'boží',      [['Anim', 'M', 'Sing', 'S', 'Nom', '1'], ['Anim', 'M', 'Plur', 'P', 'Nom', '1'], ['Inan', 'I', 'Sing', 'S', 'Acc', '4']]], # syn buoží, andělové buoží, obořiti chrám buoží
                'buožie'       => ['boží',     'boží',      [['Neut', 'N', 'Sing', 'S', 'Nom', '1'], ['Neut', 'N', 'Sing', 'S', 'Acc', '4'], ['Fem', 'F', 'Sing', 'S', 'Gen', '2'], ['Fem', 'F', 'Plur', 'P', 'Acc', '4']]], # královstvie buožie, jest stolicě buožie
                'buožieho'     => ['boží',     'boží',      [['Inan', 'I', 'Sing', 'S', 'Gen', '2'], ['Anim', 'M', 'Sing', 'S', 'Acc', '4'], ['Neut', 'N', 'Sing', 'S', 'Gen', '2']]],
                'buožiej'      => ['boží',     'boží',      [['Fem',  'F', 'Sing', 'S', 'Dat', '3'], ['Fem',  'F', 'Sing', 'S', 'Loc', '6']]], # buožiej cěstě učíš
                'buožiem'      => ['boží',     'boží',      [['Inan', 'I', 'Sing', 'S', 'Loc', '6'], ['Neut', 'N', 'Sing', 'S', 'Loc', '6']]], # na chrámu buožiem, o království buožiem
                'buožích'      => ['boží',     'boží',      [['Neut', 'N', 'Plur', 'P', 'Gen', '2']]], # z úst buožích
                'člověčí'      => ['člověčí',  'člověčí',   [['Anim', 'M', 'Sing', 'S', 'Nom', '1'], ['Anim', 'M', 'Plur', 'P', 'Nom', '1']]], # Slovo "člověčí" se obvykle vyskytuje ve spojení "syn člověčí", ale jednou byl taky plurál "nepřietelé člověčí".
                'člověčie'     => ['člověčí',  'člověčí',   [['Neut', 'N', 'Sing', 'S', 'Acc', '4']]], # nehledíš na člověčie dóstojenstvie
                'člověčieho'   => ['člověčí',  'člověčí',   [['Anim', 'M', 'Sing', 'S', 'Gen', '2'], ['Anim', 'M', 'Sing', 'S', 'Acc', '4']]], # pětkrát genitiv, třikrát akuzativ, vše "syna člověčieho"
                'člověčiemu'   => ['člověčí',  'člověčí',   [['Anim', 'M', 'Sing', 'S', 'Dat', '3']]], # proti synu člověčiemu
                'člověčích'    => ['člověčí',  'člověčí',   [['Anim', 'M', 'Plur', 'P', 'Gen', '2'], ['Anim', 'M', 'Plur', 'P', 'Loc', '6'], ['Inan', 'I', 'Plur', 'P', 'Gen', '2'], ['Inan', 'I', 'Plur', 'P', 'Loc', '6'], ['Fem', 'F', 'Plur', 'P', 'Gen', '2'], ['Fem', 'F', 'Plur', 'P', 'Loc', '6'], ['Neut', 'N', 'Plur', 'P', 'Gen', '2'], ['Neut', 'N', 'Plur', 'P', 'Loc', '6']]],
                'člověčím'     => ['člověčí',  'člověčí',   [['Anim', 'M', 'Sing', 'S', 'Ins', '7']]], # jsúce synem člověčím
                'jěščerčí'     => ['ještěrčí', 'jěščeřičí', [['Inan', 'I', 'Sing', 'S', 'Voc', '5']]], # národe jěščerčí, kak muožete dobré mluviti...
                'jěščeřičí'    => ['ještěrčí', 'jěščeřičí', [['Anim', 'M', 'Plur', 'P', 'Voc', '5']]], # zárodci jěščeřičí, kto jest vám ukázal...
                'jěštěrčí'     => ['ještěrčí', 'jěščeřičí', [['Inan', 'I', 'Sing', 'S', 'Voc', '5']]]  # národe jěštěrčí, kak móžete dobré mluviti...
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
                'volající'     => ['volající', 'vuolající', [['Inan', 'I', 'Sing', 'S', 'Nom', '1']]], # hlas volající na púšti
                'vuolajícieho' => ['volající', 'vuolající', [['Anim', 'M', 'Sing', 'S', 'Gen', '2']]], # hlas vuolajícieho na púšči
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
                'dóstojnější'  => ['důstojný', 'dóstojný', [['Anim', 'M', 'Plur', 'P', 'Nom', '1']]],
                'duostojnější' => ['důstojný', 'dóstojný', [['Anim', 'M', 'Plur', 'P', 'Nom', '1']]],
                'menší'        => ['malý',     'malý',     [['Anim', 'M', 'Sing', 'S', 'Nom', '1']]],
                'menšie'       => ['malý',     'malý',     [['Neut', 'N', 'Sing', 'S', 'Nom', '1'], ['Neut', 'N', 'Sing', 'S', 'Acc', '4']]],
                'menšieho'     => ['malý',     'malý',     [['Neut', 'N', 'Sing', 'S', 'Gen', '2']]],
                'menších'      => ['malý',     'malý',     [['Anim', 'M', 'Plur', 'P', 'Gen', '2']]],
                'menším'       => ['malý',     'malý',     [['Anim', 'M', 'Sing', 'S', 'Ins', '7']]],
                'mlazší'       => ['mladý',    'mladý',    [['Anim', 'M', 'Plur', 'P', 'Nom', '1'], ['Anim', 'M', 'Sing', 'S', 'Nom', '1', 'MATT_(10\\.24|27\\.57)']]],
                'mlazšie'      => ['mladý',    'mladý',    [['Anim', 'M', 'Plur', 'P', 'Acc', '4'], ['Anim', 'M', 'Dual', 'D', 'Acc', '4', 'MATT_(21\\.1)']]],
                'mlazšieho'    => ['mladý',    'mladý',    [['Anim', 'M', 'Sing', 'S', 'Gen', '2']]],
                'mlazších'     => ['mladý',    'mladý',    [['Anim', 'M', 'Plur', 'P', 'Gen', '2']]],
                'mlazším'      => ['mladý',    'mladý',    [['Anim', 'M', 'Plur', 'P', 'Dat', '3']]],
                'mlazšími'     => ['mladý',    'mladý',    [['Anim', 'M', 'Plur', 'P', 'Ins', '7']]]
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
                'abrahamóv'     => ['Abrahamův',  'Abrahamóv',  [['Anim', 'M', 'Sing', 'S', 'Nom', '1']]],
                'abrahamovo'    => ['Abrahamův',  'Abrahamóv',  [['Neut', 'N', 'Sing', 'S', 'Nom', '1']]],
                'abrahamovy'    => ['Abrahamův',  'Abrahamóv',  [['Anim', 'M', 'Plur', 'P', 'Acc', '4']]],
                'alfeóv'        => ['Alfeův',     'Alfeóv',     [['Anim', 'M', 'Sing', 'S', 'Nom', '1']]],
                'alpheóv'       => ['Alfeův',     'Alfeóv',     [['Anim', 'M', 'Sing', 'S', 'Nom', '1']]],
                'belzebubovú'   => ['Belzebubův', 'Belzebubóv', [['Fem',  'F', 'Sing', 'S', 'Ins', '7']]],
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
                'erodova'       => ['Herodův',    'Herodóv',    [['Fem',  'F', 'Sing', 'S', 'Nom', '1'], ['Neut', 'N', 'Sing', 'S', 'Gen', '2']]],
                'erodovú'       => ['Herodův',    'Herodóv',    [['Fem',  'F', 'Sing', 'S', 'Ins', '7']]],
                'herodesova'    => ['Herodův',    'Herodóv',    [['Neut', 'N', 'Sing', 'S', 'Gen', '2']]],
                'izaiášovo'     => ['Izaiášův',   'Izaiášóv',   [['Neut', 'N', 'Sing', 'S', 'Nom', '1']]],
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
                'mojžiešově'    => ['Mojžíšův',   'Mojžiešóv',  [['Fem',  'F', 'Sing', 'S', 'Loc', '6']]],
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
                'zachařovy'     => ['Zachařův',   'Zachařóv',   [['Fem',  'F', 'Sing', 'S', 'Gen', '2']]],
                'zebedeášova'   => ['Zebedeův',   'Zebedeóv',   [['Anim', 'M', 'Dual', 'D', 'Acc', '4']]],
                'zebedeášových' => ['Zebedeův',   'Zebedeóv',   [['Anim', 'M', 'Plur', 'P', 'Gen', '2']]],
                'zebedeóv'      => ['Zebedeův',   'Zebedeóv',   [['Anim', 'M', 'Sing', 'S', 'Nom', '1']]],
                'zebedeova'     => ['Zebedeův',   'Zebedeóv',   [['Anim', 'M', 'Sing', 'S', 'Acc', '4']]],
                'zebedeovy'     => ['Zebedeův',   'Zebedeóv',   [['Anim', 'M', 'Dual', 'D', 'Acc', '4']]],
                'zebedeových'   => ['Zebedeův',   'Zebedeóv',   [['Anim', 'M', 'Plur', 'P', 'Gen', '2']]]
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
                'ciesařóv'      => ['císařův',    'ciesařóv',   [['Anim', 'M', 'Sing', 'S', 'Nom', '1']]],
                'ciesařovo'     => ['císařův',    'ciesařóv',   [['Neut', 'N', 'Sing', 'S', 'Nom', '1']]],
                'hospodinóv'    => ['hospodinův', 'hospodinóv', [['Anim', 'M', 'Sing', 'S', 'Nom', '1'], ['Inan', 'I', 'Sing', 'S', 'Acc', '4', 'MATT_12\\.3']]],
                'hospodinova'   => ['hospodinův', 'hospodinóv', [['Fem',  'F', 'Sing', 'S', 'Nom', '1']]],
                'hospodinově'   => ['hospodinův', 'hospodinóv', [['Inan', 'I', 'Sing', 'S', 'Loc', '6']]],
                'hospodinovo'   => ['hospodinův', 'hospodinóv', [['Neut', 'N', 'Sing', 'S', 'Acc', '4']]],
                'hospodinovu'   => ['hospodinův', 'hospodinóv', [['Fem',  'F', 'Sing', 'S', 'Acc', '4']]],
                'hospodinovú'   => ['hospodinův', 'hospodinóv', [['Fem',  'F', 'Sing', 'S', 'Ins', '7']]],
                'hospodinovy'   => ['hospodinův', 'hospodinóv', [['Inan', 'I', 'Plur', 'P', 'Nom', '1'], ['Fem',  'F', 'Plur', 'P', 'Nom', '1'], ['Inan', 'I', 'Plur', 'P', 'Acc', '4'], ['Fem',  'F', 'Plur', 'P', 'Acc', '4'], ['Inan', 'I', 'Plur', 'P', 'Voc', '5'], ['Fem',  'F', 'Plur', 'P', 'Voc', '5']]],
                'hospodinových' => ['hospodinův', 'hospodinóv', [['Inan', 'I', 'Plur', 'P', 'Gen', '2'], ['Fem',  'F', 'Plur', 'P', 'Gen', '2'], ['Inan', 'I', 'Plur', 'P', 'Loc', '6'], ['Fem',  'F', 'Plur', 'P', 'Loc', '6']]]
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

"""
Project Hičkok: Fix individual positions in Etalon 13 and Etalon 16, following
observation and comparison performed by Martin Stluka.
"""
from udapi.core.block import Block

class FixEtalon(Block):

    def process_node(self, node):
        lform = node.form.lower()
        if lform == 'abrahama':
            # v e16 změnit lemma Abrahám za Abraham
            node.lemma = 'Abraham'
        elif lform == 'ačkolivěk':
            # v e13 změnit lemma na: ačkoli
            node.lemma = 'ačkoli'
        elif lform == 'agrest':
            # v e13 změnit lemma na: agrest
            node.lemma = 'agrest'
        elif lform == 'ano':
            # v 13. změnit lemma ano na an u PRON
            if node.upos == 'PRON':
                node.lemma = 'an'
        elif lform == 'arsenia':
            # "v e13 změnit lemma na ""Arsenius"""
            node.lemma = 'Arsenius'
        elif lform == 'augustin':
            # "v e16 změnit lemma z Augustýn na Augustin; a odstranit Abbr=Yes"
            node.lemma = 'Augustin'
            node.feats['Abbr'] = ''
        elif lform == 'auvech':
            # v e1š a 16 ujednotit na lemma auvech
            node.lemma = 'auvech'
        elif lform == 'avicena':
            # v e16 změnit NameTypa=Sur na Giv
            node.feats['NameType'] = 'Giv'
        elif lform == 'bachus':
            # v e16 změnit lemma Bachus na Bacchus
            node.lemma = 'Bacchus'
        elif lform == 'balšám':
            # v e13 změnit lemma na: balšám
            node.lemma = 'balšám'
        elif lform == 'bedra':
            # v e16 změnit lemma na: bedra
            node.lemma = 'bedra'
        elif lform == 'bližní':
            # v e16 změnit na: NOUN... (jako je to ve fictree a pdt)
            node.upos = 'NOUN'
        elif lform == 'blížních':
            # "v e16 změnit na: NOUN	Animacy=Anim|Case=Gen|Gender=Masc|Number=Plur"
            node.upos = 'NOUN'
        elif lform == 'bližnímu':
            # "v e16 změnit na: NOUN	Animacy=Anim|Case=Dat|Gender=Masc|Number=Sing"
            node.upos = 'NOUN'
        elif lform == 'bodl':
            # v e13 změnit lemma na: bodat
            node.lemma = 'bodnout'
        elif lform == 'bratří':
            # v e13 ujednotit lemma na: bratr (nezávisle na rodu)
            node.lemma = 'bratr'
        elif lform == 'bratři':
            # v e13 změnit lemma na: bratr (nezávisle na rodu)
            node.lemma = 'bratr'
        elif lform == 'bycha':
            # v e16 změnit: Animacy=Anim na Animacy=Inan
            node.feats['Animacy'] = 'Inan'
        elif lform == 'cokoliv':
            # v e16 a pdt změnit lemma na: cokoli
            node.lemma = 'cokoli'
        elif lform == 'což':
            # "v e13 a 16 a) odstranit interpretaci DET a ujednotit na PRON; b) odstranit interpretaci SCONJ_a ujednotit na PRON; c) u PRON odstranit Animacy"
            if node.upos in ['DET', 'SCONJ']:
                node.upos = 'PRON'
                if node.feats['PronType'] == '':
                    node.feats['PronType'] = 'Rel'
            node.feats['Animacy'] = ''
            node.feats['NumType'] = ''
        elif lform == 'cožkoli':
            # "v e16 ujednotit na: PRON	Case=Acc|PronType=Ind"
            node.upos = 'PRON'
            node.feats['PronType'] = 'Ind'
            node.feats['Case'] = 'Acc'
        elif lform == 'cožkolivěk':
            # "v e13 změnit  na: cožkoli	PRON	Case=Acc|PronType=Ind"
            node.lemma = 'cožkoli'
            node.upos = 'PRON'
            node.feats['NumType'] = ''
            node.feats['PronType'] = 'Ind'
            node.feats['Case'] = 'Acc'
        elif lform == 'čáry':
            # v e13 a 16 změnit lemma na: čáry
            node.lemma = 'čáry'
        elif lform == 'častokrát':
            # v e13 a 16 a pdt ujednotit na interpretaci: ADV NumType=Mult| PronType=Ind
            node.upos = 'ADV'
            node.feats = {'NumType': 'Mult', 'PronType': 'Ind'}
        elif lform == 'čemkoliv':
            # v e16 a pdt změnit lemma na: cokoli
            node.lemma = 'cokoli'
        elif lform == 'červena':
            # "v e16 změnit na: červeno	NOUN	Case=Gen|Gender=Neut|Number=Sing"
            node.lemma = 'červeno'
            node.upos = 'NOUN'
            node.feats['Gender'] = 'Neut'
            node.feats['Number'] = 'Sing'
            node.feats['Case'] = 'Gen'
        elif lform == 'čtvery':
            # v e13 změnit lemma na: čtvery
            node.lemma = 'čtvery'
        elif lform == 'čtvrt':
            # v e13 a 16 (apdt) odstrranit Gender u NUM
            if node.upos == 'NUM':
                node.feats['Gender'] = ''
        elif lform == 'da':
            # v e 13 asi odstranit Variant=Long
            node.feats['Variant'] = ''
        elif lform == 'dale':
            # v e16 ujednotit na lemma: dále
            node.lemma = 'dále'
        elif lform == 'další':
            # v e13 změnit lemma daleký na další
            node.lemma = 'další'
        elif lform == 'darováno':
            # v e16 doplnit: Animacy..., Aspect...
            dummy = 0 ###!!!
        elif lform == 'dav':
            # v e13 změnit VerbForm=Part na VerbForm=Conv
            if node.feats['VerbForm'] == 'Part':
                node.feats['VerbForm'] = 'Conv'
        elif lform == 'dávna':
            # "v e13 a 16 změnit ADj interpretaci s GENITIVEM SG. Neuter na: dávno	NOUN	Case=Gen|Gender=Neut|Number=Sing; "
            if node.upos == 'ADJ' and node.feats['Case'] == 'Gen':
                node.upos = 'NOUN'
                node.lemma = 'dávno'
                node.feats['Gender'] = 'Neut'
                node.feats['Number'] = 'Sing'
                node.feats['Case'] = 'Gen'
                node.feats['Degree'] = ''
                node.feats['Polarity'] = ''
                node.feats['Variant'] = ''
        elif lform == 'dceř':
            # v e13 změnit lemma na dcera
            node.lemma = 'dcera'
        elif lform == 'de':
            # v e16 odstarnit u lemmatu jít atribut: Foreign=Yes
            if node.lemma == 'jít':
                node.feats['Foreign'] = ''
        elif lform == 'děda':
            # v e13 změnit lemma na: děda
            node.lemma = 'děda'
        elif lform == 'dědu':
            # v e13 změnit lemma na: děda
            node.lemma = 'děda'
        elif lform == 'děly':
            # v e16 doplnit: Aspect=Imp
            node.feats['Aspect'] = 'Imp'
        elif lform == 'desk':
            # "v e16 změnit lemma na ""desky"""
            node.lemma = 'desky'
        elif lform == 'devatery':
            # "v e16 změnit na: NUM	Case=Nom|Number=Plur|NumForm=Word|NumType=Sets"
            node.upos = 'NUM'
            node.feats['Case'] = 'Nom'
            node.feats['Number'] = 'Plur'
            node.feats['NumForm'] = 'Word'
            node.feats['NumType'] = 'Sets'
        elif lform == 'dí':
            # v e16 doplnit Aspect=Imp
            node.feats['Aspect'] = 'Imp'
        elif lform == 'diem':
            # v e16 doplnit : Aspect=Imp / Aspect=Perf|
            node.feats['Aspect'] = 'Imp'
        elif lform == 'dítek':
            # v e16 změnit Gende=Fem na Neut
            node.feats['Gender'] = 'Neut'
        elif lform == 'dítkám':
            # v e16 změnit Gende=Fem na Neut
            node.feats['Gender'] = 'Neut'
        elif lform == 'dítky':
            # v e16 změnit Gende=Fem na Neut
            node.feats['Gender'] = 'Neut'
        elif lform == 'dlužen':
            # Odstranit z e13 Aspect=Imp|
            node.feats['Aspect'] = ''
        elif lform == 'doba':
            # v e13 změnit interptretaci: Gender=Neut|Number=Plur na Gender=Fem|Number=Sing
            ###!!! DZ: Ale co pak s Case=Acc? A navíc by se muselo něco udělat i s předcházejícím demonstrativem "ta".
            dummy = 0
            #if node.feats['Gender'] == 'Neut' and node.feats['Number'] == 'Plur':
            #    node.feats['Gender'] = 'Fem'
            #    node.feats['Number'] = 'Sing'
        elif lform == 'dobra':
            # v e13 ujednotitr na interpretaci: dobrý ADJ Case=...
            ###!!! DZ: Někdy je to minulý čas od "dobrat se".
            dummy = 0
            #node.upos = 'ADJ'
            #node.lemma = 'dobrý'
        elif lform == 'dobro':
            # v e13 ujednotit u interpretace ADJ lemma na: dobrý
            if node.upos == 'ADJ':
                node.lemma = 'dobrý'
        elif lform == 'dobude':
            # v e13 ujednotit na: Tense=Pres
            node.feats['Tense'] = 'Pres'
        elif lform == 'dočekati':
            # v e13 změnit lemma na dočkat
            node.lemma = 'dočkat'
        elif lform == 'dolejšího':
            # v e16 změnit lemma na: dolní
            node.lemma = 'dolní'
        elif lform == 'dosti':
            # "v e13 a 16 ujednotit na lemma ""dost""; a zrušit nejspíš číslovkovopu interpretaci (není v e 19 ani foictree"
            node.lemma = 'dost'
            node.upos = 'ADV'
            node.feats = {'Degree': 'Pos', 'Polarity': 'Pos'}
        elif lform == 'drahně':
            # "v e16 změnit  na: drahně	ADV	Degree=Pos|Polarity=Pos"
            node.lemma = 'drahně'
            node.upos = 'ADV'
            node.feats = {'Degree': 'Pos', 'Polarity': 'Pos'}
        elif lform == 'draho':
            # v e13 doklad: že ť žákóm draho vařenie je podle mě a jiných komntextů ADj, nikoli ADV, tak asi přeanotovat tenhle doklad
            if node.prev_node.form == 'žákóm':
                node.upos = 'ADJ'
                node.lemma = 'drahý'
                node.feats['Gender'] = 'Neut'
                node.feats['Number'] = 'Sing'
                node.feats['Case'] = 'Nom'
        elif lform == 'druhé':
            # v e13 u interpretace: druhý ADV... změnit lemma na druhé
            if node.upos == 'ADV':
                node.lemma = 'druhé'
        elif lform == 'drva':
            # v e16 změnit lemma na: dřevo
            node.lemma = 'dřevo'
        elif lform == 'důchodní':
            # "v e16 změnit na: NOUN	Animacy=Anim|Case=Nom|Gender=Masc|Number=Sing"
            node.upos = 'NOUN'
            node.feats['Animacy'] = 'Anim'
            node.feats['Case'] = 'Nom'
            node.feats['Gender'] = 'Masc'
            node.feats['Number'] = 'Sing'
        elif lform == 'dvé':
            # "v e13 ujednotit na: dvé	NUM	Case=Acc|Number=Sing|NumForm=Word|NumType=Card"
            node.lemma = 'dvé'
            node.upos = 'NUM'
            node.feats['Case'] = 'Acc'
            node.feats['Number'] = 'Sing'
            node.feats['NumForm'] = 'Word'
            node.feats['NumType'] = 'Card'
        elif lform == 'dvoje':
            # "v e13 a 16 ujednotit lemma na: dvojí; ADJ změnit na NUM; Numype na Sets a doplnit NumForm=Word"
            ###!!! DZ: To by bylo špatně např. zde: "nenie dvoje Božie Tělo".
            dummy = 0
            #node.lemma = 'dvojí'
            #node.upos = 'NUM'
            #node.feats['NumType'] = 'Sets'
            #node.feats['NumForm'] = 'Word'
        elif lform == 'dýnka':
            # "v e13 změnit lemma na ""dýnko"""
            node.lemma = 'dýnko'
        elif lform == 'etc':
            # "v e16 odstranit interpretaci: etc	ADV	Degree=Pos|Polarity=Pos"
            ###!!! DZ: A jakou interpretaci dát místo toho?
            dummy = 0
        elif lform == 'galilee':
            # "v e16 změnit lemma na ""Galilea"""
            node.lemma = 'Galilea'
        elif lform == 'had':
            # v e16 opravit Animacy na Anim
            node.feats['Animacy'] = 'Anim'
        elif lform == 'hanební':
            # v e13 změnit lemma na: hanebný
            node.lemma = 'hanebný'
        elif lform == 'hodinky':
            # v e16 a pdt změnit (ujednotit) lemma na: hodinky
            node.lemma = 'hodinky'
        elif lform == 'holé':
            # v e13 nutno změnit  ADJ... za: VERB Aspect=Imp|Mood=Ind|Number=Sing|Person=3|Polarity=Pos|Tense=Pres|VerbForm=Fin|Voice=Act
            ###!!! DZ: Ale jaké by to pak mělo lemma? A jak to poznám od míst, kde to má být ADJ?
            dummy = 0
        elif lform == 'huoře':
            # v e16 zmenit lemma na: špatně
            node.lemma = 'špatně'
        elif lform == 'hůře':
            # "v e16 a pdt  změnit lemma na ""špatně"""
            node.lemma = 'špatně'
        elif lform == 'hus':
            # v e13 ujednotit na lemma hus
            ###!!! DZ: Proč? Co vůbec znamená lemma hus?
            dummy = 0
            #node.lemma = 'hus'
        elif lform == 'husí':
            # v e13 změnit lemma na hus
            ###!!! DZ: Proč? Co vůbec znamená lemma hus?
            dummy = 0
            #node.lemma = 'hus'
        elif lform == 'izrahelských':
            # v e13 změnit lemma na izraelský
            node.lemma = 'izraelský'
        elif lform == 'jakés':
            # v e16 změnit lemma na: jakýsi
            node.lemma = 'jakýsi'
        elif lform == 'jakež':
            # "v e16 změnit na interpretaci jako je v e13: jakož	SCONJ	_"
            dummy = 0
        elif lform == 'jakoby':
            # v e16 změnit na: SCONJ_
            node.upos = 'SCONJ'
            node.feats = {}
        elif lform == 'jakýž':
            # "v e16 změnit nově na ""PronType=Rel"""
            node.feats['PronType'] = 'Rel'
        elif lform == 'jána':
            # v e16 změnit lemma na Ján
            node.lemma = 'Ján'
        elif lform == 'jedenkaždý':
            # v e16 změnit DET na PRON
            ###!!! DZ: To by ale skončilo s jinou značkou než "každý".
            dummy = 0
            #node.upos = 'PRON'
        elif lform == 'jediné':
            # "v e13 změnit lemma ""jediné"" na ""jedině"""
            if node.upos == 'ADV':
                node.lemma = 'jedině'
        elif lform == 'jednékaždé':
            # v e16 změnit DET na PRON
            ###!!! DZ: To by ale skončilo s jinou značkou než "každý".
            dummy = 0
            #node.upos = 'PRON'
        elif lform == 'jedni':
            # v e13 a16 ujednotit lemma na: jedny a NumType na Sets
            node.lemma = 'jedny'
            node.feats['NumType'] = 'Sets'
        elif lform == 'jedno':
            # číslovkovou interpretaci v e16 odstranit a nahradit za obyčejné ADV
            ###!!! DZ: Ale jak poznám, že nejde o číslovku?
            dummy = 0
        elif lform == 'jedny':
            # "v e13 ujednotit lemma na: jedny a NumType na Sets; doplnit: Animacy a Gender"
            ###!!! DZ: Nemůžu automaticky vědět, jakou hodnotu má mít Gender(+Animacy).
            node.lemma = 'jedny'
            node.feats['NumType'] = 'Sets'
        elif lform == 'jejichžto':
            # v e16 změnit lemma na jehožto
            node.lemma = 'jehožto'
        elif lform == 'jenžto':
            # v e16 změnit na: jenžtoPRON|Case=Acc|Gender=Neut|Number=Sing|PrepCase=Npr|PronType=Rel
            ###!!! DZ: Jenže v datech jsou jiné výskyty, které určitě nejsou akuzativ.
            dummy = 0
            #node.lemma = 'jenžto'
            #node.upos = 'PRON'
            #node.feats['Case'] = 'Acc'
            #node.feats['Gender'] = 'Neut'
            #node.feats['Number'] = 'Sing'
            #node.feats['PrepCase'] = 'Npr'
            #node.feats['PronType'] = 'Rel'
        elif lform == 'jesus':
            # v e13 změnit lemma Jezus za Jesus
            node.lemma = 'Jesus'
        elif lform == 'ješto':
            # "z 13 a 16 odstranit variantu: ADV	PronType=Rel; a doplnit variantu: PRON	PrepCase=Npr|PronType=Rel"
            if node.upos == 'ADV':
                node.upos = 'PRON'
                node.feats['PronType'] = 'Rel'
                node.feats['PrepCase'] = 'Npr'
        elif lform == 'jidáš':
            # v e16 zmenit NameType=Sur na NameType=Giv
            node.feats['NameType'] = 'Giv'
        elif lform == 'jupiter':
            # v e16 změnit NameType=Oth na NameType=Giv
            node.feats['NameType'] = 'Giv'
        elif lform == 'kak':
            # v e13 ujednotit na lemma kak
            node.lemma = 'kak'
        elif lform == 'kázal':
            # """Aspect"" zde chybí i u několika případů v e13 a e16"
            ###!!! DZ: A nebylo to tehdy obouvidové?
            dummy = 0
        elif lform == 'kdekoliv':
            # v e16 a pdt opravit lemma na: kdekoli
            node.lemma = 'kdekoli'
        elif lform == 'kdes':
            # v e16 a pdt změnit lemma na: kdesi
            node.lemma = 'kdesi'
        elif lform == 'kdokoliv':
            # v e13 a pdt změnit lemma na: kdokoli
            node.lemma = 'kdokoli'
        elif lform == 'kdykoliv':
            # v e13 a pdt změnit lemma na: kdykoli
            node.lemma = 'kdykoli'
        elif lform == 'klade':
            # v e13 smazat: Variant=Short
            node.feats['Variant'] = ''
        elif lform == 'kladní':
            # v e16 změnit lemma na: kladný
            node.lemma = 'kladný'
        elif lform == 'knížetem':
            # v e13 a 16  měnit na Neutrum večtně aributů k tomuto tokenu
            ###!!! DZ: Jak víme, že to není maskulinum? Navíc bychom museli dohledat i závislé uzly (např. "naším" u "naším knížetem") a změnit to i u nich.
            dummy = 0
            #node.feats['Gender'] = 'Neut'
            #node.feats['Animacy'] = ''
        elif lform == 'kohokoliv':
            # v e13 a pdt změnit lemma na: kdokoli
            node.lemma = 'kdokoli'
        elif lform == 'kolik':
            # upravit e13 a e16 podle fictree a e19
            ###!!! DZ: Tak to nejdřív budu muset zjistit, jak se to tam anotuje.
            dummy = 0
        elif lform == 'koliko':
            # v e16 změnit lemma na: kolik
            node.lemma = 'kolik'
        elif lform == 'kolikrát':
            # v e13 a 16 ujednotit na:PronType=Int
            node.feats['PronType'] = 'Int'
        elif lform == 'korunoval':
            # v e13 doplnit: Aspect=Imp
            ###!!! DZ: A není to obouvidové?
            dummy = 0
        elif lform == 'korunován':
            # v e13 a 16 doplnit Aspect=Imp
            ###!!! DZ: A není to obouvidové?
            dummy = 0
        elif lform == 'králova':
            # "v e16 změnit komplet na: králův	ADJ	Case=Nom|Gender=Fem|Gender[psor]=Masc|Number=Sing|Poss=Yes"
            node.lemma = 'králův'
            node.upos = 'ADJ'
            node.feats['Poss'] = 'Yes'
            node.feats['Gender[psor]'] = 'Masc'
            ###!!! DZ: ovšem Gender, Number a Case tady měnit nemůžu, závisí na kontextu.
        elif lform == 'kristem':
            # v e13 doplnit NameType=Sur
            node.lemma = 'Kristus'
            node.upos = 'PROPN'
            node.feats['NameType'] = 'Sur'
        elif lform == 'kristova':
            # "v e16 změnit ""NameType=Giv"" na ""NameType=Sur"""
            node.feats['NameType'] = 'Sur'
        elif lform == 'kristovu':
            # v e13 změnit NameType=Giv na NameType=Sur
            node.feats['NameType'] = 'Sur'
        elif lform == 'krom':
            # v e16 a pdt ujednostit na lemma kromě
            node.lemma = 'kromě'
        elif lform == 'kterou':
            # upravit v e13 a e16 podle e19 a fictree
            ###!!! DZ: Tak to nejdřív budu muset zjistit, jak se to tam anotuje.
            dummy = 0
        elif lform == 'lepí':
            # "v e13 ujednotit nas lemma: dobrý; a Variant=Short "
            if node.upos == 'ADJ':
                node.lemma = 'dobrý'
                node.feats['Variant'] = 'Short'
        elif lform == 'letanie':
            # v e16 změnit lemma na: litanie
            node.lemma = 'litania'
        elif lform == 'leze':
            # v e13 oppdstranit: Variant=Long
            node.feats['Variant'] = ''
        elif lform == 'loje':
            # v e16 změnit lemma na: lůj
            node.lemma = 'lůj'
        elif lform == 'luciper':
            # v e13a e16 změnit všusde na lemma Luciper
            node.lemma = 'Luciper'
            node.upos = 'PROPN'
        elif lform == 'lucipera':
            # v e13a e16 změnit všusde na lemma Luciper
            node.lemma = 'Luciper'
            node.upos = 'PROPN'
        elif lform == 'magdalena':
            # v e16 změnit lemma Magdaléna na Magdalena
            node.lemma = 'Magdalena'
        elif lform == 'magdaleně':
            # "v e16 změnit lemma na ""Magdalena"""
            node.lemma = 'Magdalena'
        elif lform == 'magdaleny':
            # v e16 změnit lemma Magdaléna na Magdalena
            node.lemma = 'Magdalena'
        elif lform == 'macha':
            # v e16 změnit NameType=Giv na NameType=Sur
            node.feats['NameType'] = 'Sur'
        elif lform == 'málo':
            # změnit ADJ interpretaci v e13 na ADV
            if node.upos == 'ADJ':
                node.upos = 'ADV'
                node.feats['Gender'] = ''
                node.feats['Animacy'] = ''
                node.feats['Number'] = ''
                node.feats['Case'] = ''
                node.feats['Variant'] = ''
        elif lform == 'manželstva':
            # v e13 a 16 změnit lemma na: manželství
            node.lemma = 'manželství'
        elif lform == 'maří':
            # "v e13 změnit lemma na ""Marie"""
            node.lemma = 'Marie'
        elif lform == 'medle':
            # v e16 změnit na:medle PART_
            node.upos = 'PART'
            node.feats = {}
        elif lform == 'met':
            # v e16 změnit lemma na: med
            node.lemma = 'med'
        elif lform == 'metly':
            # v e16 změnit lemma metl za metla
            if node.lemma == 'metl':
                node.lemma = 'metla'
        elif lform == 'mléce':
            # "v e13 opravit lemma na ""mléko"""
            node.lemma = 'mléko'
        elif lform == 'mnoha':
            # v e16 u mnohý ADJ doplnit atribut: Variant=Short
            if node.upos == 'ADJ':
                node.feats['Variant'] = 'Short'
        elif lform == 'moci':
            # v e13 a fictree doplnit Aspect u slovesa
            if node.upos == 'VERB':
                node.feats['Aspect'] = 'Imp'
        elif lform == 'mudřec':
            # v e16 změnit lemma na mudrc
            node.lemma = 'mudrc'
        elif lform == 'mýtní':
            # "v e13 změnit na: mýtný	NOUN	Animacy=Anim|Case=Nom|Gender=Masc|Number=Plur"
            node.lemma = 'mýtný'
            node.upos = 'NOUN'
            node.feats['Degree'] = ''
            node.feats['Polarity'] = ''
        elif lform == 'nabude':
            # v e13 změnit: Tense=Fut na Tense=Pres
            node.feats['Tense'] = 'Pres'
        elif lform == 'nadme':
            # v e13 změnit lemma na nadmout
            node.lemma = 'nadmout'
        elif lform == 'najednou':
            # "v e16 změnit na: ADV	Degree=Pos|Polarity=Pos"
            node.upos = 'ADV'
            node.feats = {}
            node.feats['Degree'] = 'Pos'
            node.feats['Polarity'] = 'Pos'
        elif lform == 'najprv':
            # v e13 a 16 ujednotit lemma na nejprve
            node.lemma = 'nejprve'
        elif lform == 'náklonosti':
            # v e16 změnit lemma na: náklonnost
            node.lemma = 'náklonnost'
        elif lform == 'né':
            # "v e13 změnit na: ne	PART	_"
            node.lemma = 'ne'
            node.upos = 'PART'
            node.feats = {}
        elif lform == 'nebes':
            # v e13 a 16 změnit lemma na: nebesa
            node.lemma = 'nebesa'
        elif lform == 'nebesa':
            # v e13 a 16 změnit lemma na: nebesa
            node.lemma = 'nebesa'
        elif lform == 'nebesích':
            # v e16 změnit lemma na nebesa
            node.lemma = 'nebesa'
        elif lform == 'nebť':
            # v e13 a 16 ujednotit lemma na neboť
            node.lemma = 'neboť'
        elif lform == 'neduživý':
            # v e16 ujednotit lemma na: neduživý
            node.lemma = 'neduživý'
        elif lform == 'nechažť':
            # "v e13 změnit na: nechť	PART	_"
            node.lemma = 'nechť'
            node.upos = 'PART'
            node.feats = {}
        elif lform == 'nejblíž':
            # v e16 změnit lemma na: blízko
            node.lemma = 'blízko'
        elif lform == 'nejen':
            # "v e13 změnit lemma ""jen"" na ""nejen"""
            node.lemma = 'nejen'
        elif lform == 'nejenom':
            # v e16 opravit na lemma nejenom
            node.lemma = 'nejenom'
        elif lform == 'nejináč':
            # v e16 změnit lemma na: jinak
            node.lemma = 'jinak'
        elif lform == 'nejprv':
            # v e16 ujednotit lemma na nejprve
            node.lemma = 'nejprve'
        elif lform == 'nejspíš':
            # v e16 upravit na lemma nejspíš
            node.lemma = 'nejspíš'
        elif lform == 'nejspíše':
            # v e16 upravit na lemma nejspíš
            node.lemma = 'nejspíš'
        elif lform == 'nějž':
            # v e16 změnit případ PronType=Prs na PronType=Rel
            if node.feats['PronType'] == 'Prs':
                node.feats['PronType'] = 'Rel'
        elif lform == 'nemocen':
            # v 13 a 16 ujednotit lemma na: nemocný
            node.lemma = 'nemocný'
        elif lform == 'nemocného':
            # v e16 změnit lemma na: nemocný
            node.lemma = 'nemocný'
        elif lform == 'nemocnému':
            # v e13 změnit lemma na: nemocný a Polarity na Pos
            node.lemma = 'nemocný'
        elif lform == 'nemocni':
            # "v e13 a 16 změnit lemma na: nemocný; v e16 doplnit: Variant=Short"
            node.lemma = 'nemocný'
            node.feats['Variant'] = 'Short'
        elif lform == 'nemocní':
            # v e13 změnit na lemma: nemocný
            node.lemma = 'nemocný'
        elif lform == 'nemocnou':
            # v e16 zmenit na lemma: nemocný
            node.lemma = 'nemocný'
        elif lform == 'nemocných':
            # "v e13 a 16 změnit lemma všude na ""nemocný"""
            node.lemma = 'nemocný'
        elif lform == 'nemocným':
            # v e13a 16 změnit lemma na: nemocný
            node.lemma = 'nemocný'
        elif lform == 'nemysli':
            # "v e16 odstranit ""Voice=Act"""
            node.feats['Voice'] = ''
        elif lform == 'nenadále':
            # v e16 sjednotit na lemma nenadále
            node.lemma = 'nenadále'
        elif lform == 'nepochybně':
            # v e16 změnit na PART_
            node.upos = 'PART'
            node.feats = {}
        elif lform == 'neponesu':
            # v e13 změnit lemma na nést
            node.lemma = 'nést'
        elif lform == 'nepřeje':
            # v e13 upravit na (je to prézens ne minulý čas): Aspect=Imp|Mood=Ind|Number=Sing|Person=3|Polarity=Neg|Tense=Pres|VerbForm=Fin|Voice=Act
            node.feats['Tense'] = 'Pres'
        elif lform == 'neřci':
            # v e13 změnit lemma na: nerci
            node.lemma = 'nerci'
        elif lform == 'nesmírná':
            # v e16 změnit lemma na: nesmírný a Polarity na Pos
            node.lemma = 'nesmírný'
            node.feats['Polarity'] = 'Pos'
        elif lform == 'nestydaté':
            # v e16 změnit lemma na: nestydatý
            node.lemma = 'nestydatý'
        elif lform == 'netoliko':
            # v e13 a 16 ujednotit lemma na netoliko
            node.lemma = 'netoliko'
        elif lform == 'nezbude':
            # v e13 změnit z Tense=Fut na Tense=Pres
            node.feats['Tense'] = 'Pres'
        elif lform == 'nie':
            # v e16 ostranit: |Foreign=Yes
            node.feats['Foreign'] = ''
        elif lform == 'nikdá':
            # "v e13 a e16 změnit lemma na ""nikdy"" všude"
            node.lemma = 'nikdy'
        elif lform == 'nikda':
            # v e13 a 16 ujednotit lemma na: nikdy
            node.lemma = 'nikdy'
        elif lform == 'nikoli':
            # v e13 všechno změnit na: PART_
            node.upos = 'PART'
            node.feats = {}
        elif lform == 'nižádného':
            # v e13 ujednotit na PronType=Neg
            node.feats['PronType'] = 'Neg'
        elif lform == 'nuž':
            # "v e13 a 16 změnit lemma na: nuže; a INTJ_na PART_"
            node.lemma = 'nuže'
            node.upos = 'PART'
            node.feats = {}
        elif lform == 'nuže':
            # v e13 a 16 změnit na: PART_
            node.upos = 'PART'
            node.feats = {}
        elif lform == 'nynie':
            # v e16 opravit podle e13
            ###!!! DZ: A to je jak?
            dummy = 0
        elif lform == 'obé':
            # v e13 a 16 změnit lemma na: obé
            # v e13 a16 změnit NUM interpretaci na ADJ interpretaci s lemmatem obé!!! ###!!! DZ: ???
            node.lemma = 'obé'
        elif lform == 'obého':
            # v e13 změnit lemma na: obé
            node.lemma = 'obé'
            # v e16 změnit podle e13 (dodat gender etc.) s lemmatem obé ###!!! DZ: ???
        elif lform == 'obětovali':
            # v  e13 a 16 doplnit: Aspect...
            ###!!! DZ: obouvidové
            dummy = 0
        elif lform == 'obětovat':
            # v e13 doplnit : Aspect=Imp / Aspect=Perf|
            ###!!! DZ: obouvidové
            dummy = 0
        elif lform == 'obory':
            # "v e13 přidat ""NameType=Geo"""
            if node.upos == 'PROPN':
                node.feats['NameType'] = 'Geo'
        elif lform == 'obraze':
            # v e16 změnit Animacy =Anim na Animacy=Inan
            node.feats['Animacy'] = 'Inan'
        elif lform == 'obvzláštně':
            # v e16 ujednotiti na lemma: obzvláště
            node.lemma = 'obzvláště'
        elif lform == 'obvzláštní':
            # v e16 ujednotit na lemma: obzvláštní
            node.lemma = 'obzvláštní'
        elif lform == 'odsad':
            # v e16 změnit lemma na odsud
            node.lemma = 'odsud'
        elif lform == 'onehdá':
            # v e13 a 16 a v pdt změnit lemma na: onehdy
            node.lemma = 'onehdy'
        elif lform == 'otcovým':
            # "v e13 změnit komplet na: otcův	ADJ	Case=Ins|Degree=Pos|Gender=Neut|Gender[psor]=Masc|Number=Sing|Poss=Yes"
            node.lemma = 'otcův'
            node.upos = 'ADJ'
            node.feats['Poss'] = 'Yes'
            node.feats['Gender[psor]'] = 'Masc'
            node.feats['Degree'] = ''
            node.feats['Polarity'] = ''
        elif lform == 'ovšem':
            # v13 odsttranit PronType=Tot
            node.feats['PronType'] = ''
        elif lform == 'oženil':
            # v e13 doplnit: Aspect=Perf
            node.feats['Aspect'] = 'Perf'
        elif lform == 'pačesy':
            # v e16 změnit lemma na: pačesy
            node.lemma = 'pačesy'
        elif lform == 'pana':
            # "v e16 změnit lemma na ""pan"""
            node.lemma = 'pan'
        elif lform == 'pár':
            # v e13 předělat DET na NUM se vším náležitým
            ###!!! DZ: ???
            dummy = 0
        elif lform == 'peci':
            # v e13 změnit lemma pece na pec
            node.lemma = 'pec'
        elif lform == 'peněz':
            # "v e13 a16 zde změnit na lemma ""peníze""; ale jinak rozlišovat lemma peníze vs. peníz"
            node.lemma = 'peníze'
        elif lform == 'penězi':
            # v e13 a16 změnit lemma na: peníze
            node.lemma = 'peníze'
        elif lform == 'penězích':
            # v e16 změnit lemma na: peníze
            node.lemma = 'peníze'
        elif lform == 'penězům':
            # v e16 změnit lemma na: peníze
            node.lemma = 'peníze'
        elif lform == 'peníze':
            # "v e13 a16 zde změnit na lemma ""peníze""; ale jinak rozlišovat lemma peníze vs. peníz"
            node.lemma = 'peníze'
        elif lform == 'penze':
            # "v e16 změnit  na: penze NOUN	Case=Acc|Gender=Fem|Number=Plur"
            node.lemma = 'penze'
            node.upos = 'NOUN'
        elif lform == 'plecí':
            # v e13 u Gender=Fem zěnit lemma na: plec
            if node.feats['Gender'] == 'Fem':
                node.lemma = 'plec'
        elif lform == 'pleci':
            # v e13 zmnit lemma na: plec
            node.lemma = 'plec'
        elif lform == 'polívka':
            # v e16 změnit lemma polévka na polívka
            node.lemma = 'polívka'
        elif lform == 'polívku':
            # v e16 změnit lemma na: polívku
            node.lemma = 'polívka'
        elif lform == 'polívky':
            # v e16 změnit lemma polévka na polívka
            node.lemma = 'polívka'
        elif lform == 'ponese':
            # v e13 změnit lemma na: nést
            node.lemma = 'nést'
        elif lform == 'ponukl':
            # v e13 změnit lemma na: ponouknout
            node.lemma = 'ponouknout'
        elif lform == 'pořáde':
            # v e16 ujednotit lemma na: pořád
            node.lemma = 'pořád'
        elif lform == 'posavad':
            # v e16 udělat jednotně jako u tvaru posavád, tudíž: posavadADVDegree=Pos|Polarity=Pos
            node.lemma = 'posavad'
            node.upos = 'ADV'
            node.feats = {}
            node.feats['Degree'] = 'Pos'
            node.feats['Polarity'] = 'Pos'
        elif lform == 'posla':
            # "v e13 změnit výskyt ""poslatNoun..."" na lemma ""poselNOUN..."""
            if node.upos == 'NOUN':
                node.lemma = 'posel'
        elif lform == 'povědom':
            # v e16 doplnit: Variant=Short
            node.feats['Variant'] = 'Short'
        elif lform == 'prázdno':
            # "v e13 změnit lemma ""prázdno"" na ""prázdný"""
            if node.upos == 'ADJ':
                node.lemma = 'prázdný'
        elif lform == 'president':
            # v e16 zmenit lemma z prezident na president
            node.lemma = 'president'
        elif lform == 'procesí':
            # v e16 změnit  na Number=Sing
            ###!!! DZ: Závisí na kontextu.
            dummy = 0
        elif lform == 'pročež':
            # v e16 ujednotit na PronType=Int/Rel
            node.feats['PronType'] = 'Rel'
        elif lform == 'prokopa':
            # v e16 zmenit NameType=Sur na NameType=Giv
            node.feats['NameType'] = 'Giv'
        elif lform == 'proto':
            # z 13 odstranit variantu s Degreee
            ###!!! DZ: ???
            dummy = 0
        elif lform == 'protožť':
            # "v e13 změnit na: CCONJ	_"
            node.upos = 'CCONJ'
            node.feats = {}
        elif lform == 'prsa':
            # "v e16 změnit lemma na ""prsa"""
            node.lemma = 'prsa'
        elif lform == 'prsi':
            # v e13 ujednotit gender na Inan/Masc
            node.feats['Gender'] = 'Masc'
            node.feats['Animacy'] = 'Inan'
        elif lform == 'prsí':
            # v e13 změnit femininní interpretaci na Maskulinum neživotné
            node.feats['Gender'] = 'Masc'
            node.feats['Animacy'] = 'Inan'
        elif lform == 'prv':
            # v e16 ujednotit lemma na prve
            node.lemma = 'prve'
        elif lform == 'prvé':
            # "v e13a 16 u lemmatu ""prvé"" (ADV) změnit toto lemma na: prve a xpos změnit z: NumType=Ord na:  Degree=Pos|Polarity=Pos"
            if node.lemma == 'prvé' and node.upos == 'ADV':
                node.lemma = 'prve'
                node.feats = {}
                node.feats['Degree'] = 'Pos'
                node.feats['Polarity'] = 'Pos'
        elif lform == 'přibude':
            # v e13 ujednotit  na: Tense=Pres
            node.feats['Tense'] = 'Pres'
        elif lform == 'přijedu':
            # "v obou případech v e13 by měl být korektní tvar ""přijedú"""
            ###!!! DZ: ???
            dummy = 0
        elif lform == 'přiklad':
            # v e13 změnit lemma na: příklad
            node.lemma = 'příklad'
        elif lform == 'půl':
            # v e16 (aprdt) doplnit: Case a Number
            ###!!! DZ: Potřebuju kontext.
            dummy = 0
        elif lform == 'půldruhého':
            # v e16 změnit na: půldruhý ADJ Case Gen|Gender=Fem|Number=Sing|NumType=Ord
            node.lemma = 'půldruhý'
            node.upos = 'ADJ'
            node.feats['Case'] = 'Gen'
            node.feats['Number'] = 'Sing'
            node.feats['NumType'] = 'Ord'
        elif lform == 'rači':
            # "v e13 doplnit ""Asapect"""
            node.feats['Aspect'] = 'Imp'
        elif lform == 'račte':
            # v e13 doplnit: Aspect=Imp
            node.feats['Aspect'] = 'Imp'
        elif lform == 'radějí':
            # v e13 změnit lemma na rád
            node.lemma = 'rád'
        elif lform == 'radní':
            # "v e16 změnit interpretaci s vokativem na  Noun: radní	NOUN	Animacy=Anim|Case=Voc|Gender=Masc|Number=Plur"
            if node.feats['Case'] == 'Voc':
                node.lemma = 'radní'
                node.upos = 'NOUN'
                node.feats['Animacy'] = 'Anim'
                node.feats['Gender'] = 'Masc'
        elif lform == 'radního':
            # v e16 změnit na: NOUN Animacy=Anim|Case=Acc|Gender=Masc|Number=Sing
            node.lemma = 'radní'
            node.upos = 'NOUN'
            node.feats['Animacy'] = 'Anim'
            node.feats['Gender'] = 'Masc'
            node.feats['Number'] = 'Sing'
        elif lform == 'rámě':
            # v e13 (a pdt) změnit lemma na: rameno
            node.lemma = 'rameno'
        elif lform == 'ramene':
            # v e13 změnit lemma na: rameno
            node.lemma = 'rameno'
        elif lform == 'rúče':
            # v e13 ujednotit na lemma ruče
            node.lemma = 'ruče'
        elif lform == 'říčan':
            # v e16 změnit rod z Fem na Inan Masc
            node.feats['Gender'] = 'Masc'
            node.feats['Animacy'] = 'Inan'
        elif lform == 'řkúc':
            # v e13 doplnit na různých místech: Aspect... a Gender
            ###!!! DZ: Nemůžu doplnit Gender, protože přinejmenším některé výskyty jsou Number=Plur.
            node.feats['Aspect'] = 'Perf'
        elif lform == 'řkúce':
            # v e13 doplnit: Aspect...
            node.feats['Aspect'] = 'Perf'
        elif lform == 'sam':
            # v e13 odstranit: Variant=Short
            node.feats['Variant'] = ''
        elif lform == 'samých':
            # v e13  smazat: |Variant=Short
            node.feats['Variant'] = ''
        elif lform == 'séci':
            # v e16 změnit lemma na: síci
            node.lemma = 'síci'
        elif lform == 'set':
            # v e16 odstranit Animacy a Gender
            node.feats['Gender'] = ''
            node.feats['Animacy'] = ''
        elif lform == 'shřešil':
            # v e13 ujednotit lemma na: zhřešit
            node.lemma = 'zhřešit'
        elif lform == 'sic':
            # v e13 a 16 ujednotit lema na: sice
            if node.feats['Foreign'] != 'Yes':
                node.lemma = 'sice'
        elif lform == 'sirach':
            # v e16 změnit nameTypa=Sur na Giv
            node.feats['NameType'] = 'Giv'
        elif lform == 'skoval':
            # v e13 a 16 ujednotit lemma na : schoval
            node.lemma = 'schovat'
        elif lform == 'skut':
            # v e16 doplnit: Abbr=Yes
            node.feats['Abbr'] = 'Yes'
        elif lform == 'složiv':
            # v e13 změnit VerbForm=Part na VerbForm=Conv
            node.feats['VerbForm'] = 'Conv'
        elif lform == 'spíšeji':
            # v e16 změnit lemma na: spíš
            node.lemma = 'spíš'
        elif lform == 'spropitné':
            # "v e16 zmenit na: spropitné	NOUN	Case=Acc|Gender=Neut|Number=Sing"
            node.lemma = 'spropitné'
            node.upos = 'NOUN'
            node.feats['Gender'] = 'Neut'
            node.feats['Number'] = 'Sing'
        elif lform == 'sprostní':
            # v e16 změnit lema na: sprostný
            node.lemma = 'sprostný'
        elif lform == 'stáři':
            # "v e16 změnit lema na: stář; a gender nově na: Fem"
            node.lemma = 'stář'
            node.feats['Gender'] = 'Fem'
            node.feats['Animacy'] = ''
        elif lform == 'stě':
            # v e13 opravit Number=Sing na Number=Dual
            node.feats['Number'] = 'Dual'
        elif lform == 'stkvěl':
            # v e16 změnit lemma na: skvít
            node.lemma = 'skvít'
        elif lform == 'stoupil':
            # v e13 změnit lemma na: sestoupit
            node.lemma = 'sestoupit'
        elif lform == 'střeže':
            # v e13 změnit lemma na: střežit
            node.lemma = 'střežit'
        elif lform == 'summa':
            # "v e16 změnit lemma na ""summa"""
            node.lemma = 'summa'
        elif lform == 'šatech':
            # "v e16 změnit lemma ""šat"" na ""šaty"""
            node.lemma = 'šaty'
        elif lform == 'šaty':
            # v e13, v e16 a pdt ujednotit lemma na: šaty (důvod: plurálové paradigma je totožné u lemmatu šat i šaty, tudíž nelze odlišit, tak můžem použít jen lemma šaty pro pl - odlišné třeba peníz/peníze, kde lema peníz má jiné plurálové paradigma než lemma peníze)
            node.lemma = 'šaty'
        elif lform == 'školném':
            # v e13 změnit lemma na: školný
            node.lemma = 'školný'
        elif lform == 'take':
            # "v e13 ujednotit lemma na ""tak"" a ponechat PronType=Dem"
            node.lemma = 'tak'
        elif lform == 'takměř':
            # v e13 změnit lemma na: téměř
            node.lemma = 'téměř'
        elif lform == 'takož':
            # v e13 ujednotit lemma na: takž
            node.lemma = 'takž'
        elif lform == 'takto':
            # změnit v e13 Degree=Pos|Polarity=Pos na PronType=Dem
            if node.feats['Degree'] == 'Pos':
                node.feats = {}
                node.feats['PronType'] = 'Dem'
        elif lform == 'takže':
            # změnit v e13 CCONJ na SCONJ
            node.upos = 'SCONJ'
        elif lform == 'tedy':
            # změnit Part v e16 na CCONJ
            if node.upos == 'PART':
                node.upos = 'CCONJ'
        elif lform == 'tehda':
            # "v e13 a 16 změnit na lemma ""tehdy""; a na interpretaci: PronType=Dem"
            node.lemma = 'tehdy'
            node.feats = {}
            node.feats['PronType'] = 'Dem'
        elif lform == 'teletem':
            # v e13 změnit lemma na: tele
            node.lemma = 'tele'
        elif lform == 'tenkráte':
            # "v e16 ujednotit na lemma tenkrát; a na PronType=Dem"
            node.lemma = 'tenkrát'
            node.feats = {}
            node.feats['PronType'] = 'Dem'
        elif lform == 'teprv':
            # v e13 a 16 ujednotit lemma na teprve
            node.lemma = 'teprve'
        elif lform == 'těžko':
            # v e13 a 16 ujednotit na: ADV Degree=Pos|Polarity=Pos
            node.upos = 'ADV'
            node.feats = {'Degree': 'Pos', 'Polarity': 'Pos'}
        elif lform == 'tisíc':
            # v e13 a16 doplnit: Animacy..., Gender=...
            ###!!! DZ: ???
            dummy = 0
        elif lform == 'tisíce':
            # v e13 a16 doplnit: Animacy..., Gender=...
            ###!!! DZ: ???
            dummy = 0
        elif lform == 'tisícem':
            # "v e13 změnit na: NUM	Animacy=Inan|Case=Ins|Gender=Masc|Number=Sing|NumForm=Word|NumType=Card"
            node.upos = 'NUM'
            node.feats['Animacy'] = 'Inan'
            node.feats['Case'] = 'Ins'
            node.feats['Gender'] = 'Masc'
            node.feats['Number'] = 'Sing'
            node.feats['NumForm'] = 'Word'
            node.feats['NumType'] = 'Card'
        elif lform == 'tisíci':
            # v e13 a16 doplnit: Animacy..., Gender=...
            ###!!! DZ: ???
            dummy = 0
        elif lform == 'tisící':
            # v e13 a16 změnit na ADJ a doplnit podle e19
            ###!!! DZ: ???
            dummy = 0
        elif lform == 'tíž':
            # "v e16 ujednotit lemma na: tíže; interpretaci DET změnit na:  tíže	NOUN	Case=Acc|Gender=Fem|Number=Sing"
            ###!!! DZ: Asi nelze, když neznáme kontext.
            dummy = 0
        elif lform == 'tolikéž':
            # v e13 a 16 ujednotit na interpretaci: AVD a verzi, kterou dojodneme
            ###!!! DZ: ???
            dummy = 0
        elif lform == 'toliko':
            # "v e13 a e16 ujednotit na lemma ""tolik"""
            node.lemma = 'tolik'
        elif lform == 'tovařišie':
            # v e13 změnit lemma na: tovaryš
            node.lemma = 'tovaryš'
        elif lform == 'tož':
            # v e13 ujednotit u DET lemma na: tenž
            if node.upos == 'DET':
                node.lemma = 'tenž'
        elif lform == 'troja':
            # "v e16 změnit lemma na ""Troja"""
            node.lemma = 'Troja'
        elif lform == 'troje':
            # "v e13 a 16 ujednotit lemma na: trojí; ADJ změnit na NUM; Numype na Sets a doplnit NumForm=Word"
            ###!!! DZ: ???
            dummy = 0
        elif lform == 'troji':
            # v e13 změnit lemma Trója na Troja
            if node.lemma == 'Trója':
                node.lemma = 'Troja'
        elif lform == 'třeva':
            # "v e16 změnit na: střevo	NOUN	Case=Acc|Gender=Neut|Number=Plur"
            node.lemma = 'střevo'
            node.upos = 'NOUN'
            node.feats['Gender'] = 'Neut'
        elif lform == 'tří':
            # v e1š a 16 Animacy... a Gender
            ###!!! DZ: ???
            dummy = 0
        elif lform == 'tuď':
            # v e16 změnit lemma na: tuď
            node.lemma = 'tuď'
        elif lform == 'tvárnosti':
            # v e16 změnit lemma na: tvárnost
            node.lemma = 'tvárnost'
        elif lform == 'tým':
            # v e16 změnit lemma na tý
            node.lemma = 'tý'
        elif lform == 'uťal':
            # v e13 změnit lemma na: utnout
            node.lemma = 'utnout'
        elif lform == 'valem':
            # v e13 změnit lemma na: valem
            node.lemma = 'valem'
        elif lform == 'věčí':
            # v e13 ujednotit lemma na: velký
            node.lemma = 'velký'
        elif lform == 'veškeré':
            # v e16 změnit DET na PRON
            ###!!! DZ: ne, to by mělo být DET
            dummy = 0
        elif lform == 'veškeren':
            # "v e13 a 16 ujednotit na lemma veškerý; u e13 odstranit ""Variant=Short"""
            node.lemma = 'veškerý'
        elif lform == 'veškerý':
            # v e13 změnit DET na PRON
            ###!!! DZ: ne, to by mělo být DET
            dummy = 0
        elif lform == 'většího':
            # v e16 změnit lemma veliký na velký
            node.lemma = 'velký'
        elif lform == 'viec':
            # "v e13 a) změnit lema víc na více; b) u interpretace: hodně	ADV	Degree=Pos|Polarity=Pos změnit Degree na Cmp (u lemmatu hodně to nemůže být pozitiv!); c) u interpretace  hodně DET doplnit chybějící: |Degree=Cmp "
            if node.lemma == 'víc':
                node.lemma = 'více'
            elif node.lemma == 'hodně' and node.upos == 'ADV':
                node.feats['Degree'] = 'Cmp'
        elif lform == 'viece':
            # "v e13 a) změnit lemma mnoho na hodně a víc na více; b) u interpretace: hodně	ADV	Degree=Pos|Polarity=Pos změnit Degree na Cmp (u lemmatu hodně to nemůže být pozitiv!); c) odstranit:Polarity=Pos u interpretace: hodně DET... "
            if node.lemma == 'mnoho':
                node.lemma = 'hodně'
            elif node.lemma == 'víc':
                node.lemma = 'více'
            if node.lemma == 'hodně' and node.upos == 'ADV':
                node.feats['Degree'] = 'Cmp'
        elif lform == 'višeň':
            # v e13 změnit lemma na:  višeň
            node.lemma = 'višeň'
        elif lform == 'vojsky':
            # "v e13 změnit lemma ""vojsko"" na ""vojska"""
            ###!!! DZ: ???
            dummy = 0
        elif lform == 'vrátného':
            # "v e16 změnit na: NOUN	Animacy=Anim|Case=Acc|Gender=Masc|Number=Sing;
            # platí i pro tvar ""vratný"" s lemma trem ""vrátný"", kde bude: NOUN	Animacy=Anim|Case=Nom|Gender=Masc|Number=Sing"
            node.upos = 'NOUN'
            node.lemma = 'vrátný'
        elif lform == 'vrátným':
            # "v e16 změnit na: NOUN	Animacy=Anim|Case=Ins|Gender=Masc|Number=Sing"
            node.upos = 'NOUN'
            node.lemma = 'vrátný'
        elif lform == 'všady':
            # v e13 ujednotit na lemma všudy
            node.lemma = 'všudy'
        elif lform == 'všelijaké':
            # v e16 ujednotiti na: PronType=Ind
            node.feats['PronType'] = 'Ind'
            node.feats['Degree'] = ''
            node.feats['Polarity'] = ''
        elif lform == 'všelijakého':
            # v e16 ujednotit na: PronType=Ind
            node.feats['PronType'] = 'Ind'
            node.feats['Degree'] = ''
            node.feats['Polarity'] = ''
        elif lform == 'všelijaký':
            # v e16 ujednotit na: PronType=Ind
            node.feats['PronType'] = 'Ind'
            node.feats['Degree'] = ''
            node.feats['Polarity'] = ''
        elif lform == 'všeliké':
            # v e13 ujednotit na PronType=Tot
            node.feats['PronType'] = 'Tot'
            node.feats['Degree'] = ''
            node.feats['Polarity'] = ''
        elif lform == 'všelikého':
            # "v e13 ujednotit na DET etc; v e16 ujednotit na PronType=Tot"
            node.upos = 'DET'
            node.feats['PronType'] = 'Tot'
            node.feats['Degree'] = ''
            node.feats['Polarity'] = ''
        elif lform == 'všelikému':
            # "v e13 ujednotit na DET etc; v e16 ujednotit na PronType=Tot"
            node.upos = 'DET'
            node.feats['PronType'] = 'Tot'
            node.feats['Degree'] = ''
            node.feats['Polarity'] = ''
        elif lform == 'vuoz':
            # v e13 změnit lemma na: vůz
            node.lemma = 'vůz'
        elif lform == 'vydaly':
            # v e13 doplnit: Aspect=Perf
            node.feats['Aspect'] = 'Perf'
        elif lform == 'vynešeno':
            # v e16 změnit lemma na: vynešený
            node.lemma = 'vynešený'
        elif lform == 'zadost':
            # "v e16 cyhbná anotace, změnit na: zadost	ADV	Degree=Pos|Polarity=Pos"
            node.lemma = 'zadost'
            node.upos = 'ADV'
            node.feats = {'Degree': 'Pos', 'Polarity': 'Pos'}
        elif lform == 'zachovale':
            # "v e16 změnit na: ADV	Degree=Pos|Polarity=Pos"
            node.upos = 'ADV'
            node.feats = {'Degree': 'Pos', 'Polarity': 'Pos'}
        elif lform == 'zámutkem':
            # v e13 změnit lemma na: zármutek
            node.lemma = 'zármutek'
        elif lform == 'zaroveň':
            # v e13 změnit lemma na: zároveň
            node.lemma = 'zároveň'
        elif lform == 'závírce':
            # v e16 změnit lemma na: závírka
            node.lemma = 'závírka'
        elif lform == 'zbude':
            # v e13 změnit z Tense=Fut na Tense=Pres
            node.feats['Tense'] = 'Pres'
        elif lform == 'zbudil':
            # v e13 změnit lemma na: vzbudit
            node.lemma = 'vzbudit'
        elif lform == 'zdenkovi':
            # v e16 změnit lemma na: Zdenek
            node.lemma = 'Zdenek'
        elif lform == 'zimě':
            # v e13 bych to ADV taky interpretoval jako lokál, a to bezpředložkový - ujednoti na Noun
            node.lemma = 'zima'
            node.upos = 'NOUN'
            node.feats['Gender'] = 'Fem'
            node.feats['Number'] = 'Sing'
            if node.feats['Case'] == '':
                node.feats['Case'] = 'Loc'
            node.feats['Degree'] = ''
            node.feats['Polarity'] = ''
        elif lform == 'zlatých':
            # v e13 a 16 identifikovat doklady, kde se jedná o NOUN a dát jim NOUN interpretaci (jsou tam!!)
            ###!!! DZ: ???
            dummy = 0
        elif lform == 'zroste':
            # v e13 změnit lemma na: vzrůst
            node.lemma = 'vzrůst'
        elif lform == 'žádný':
            # v e13 odstranit  Polarity=Pos a dát  PronType=Neg
            ###!!! DZ: Ale podle lemmatu to znamená "žádaný", takže ADJ, ne DET.
            dummy = 0
            #node.feats['Polarity'] = ''
            #node.feats['PronType'] = 'Neg'

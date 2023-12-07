#!/usr/bin/env perl
# Fixes spurious sentence breaks predicted by UDPipe. Relies on hard-coded
# descriptions of sentences that need fixing.
# Copyright © 2022 Dan Zeman <zeman@ufal.mff.cuni.cz>
# License: GNU GPL

use utf8;
use open ':utf8';
binmode(STDIN, ':utf8');
binmode(STDOUT, ':utf8');
binmode(STDERR, ':utf8');

my $counter = 0;
my @sentence;
while(<>)
{
    push(@sentence, $_);
    if(m/^\s*$/)
    {
        process_sentence(@sentence);
        @sentence = ();
    }
}
print STDERR ("MERGED $counter SENTENCE PAIRS IN TOTAL.\n");



#------------------------------------------------------------------------------
# Process the sentence that was just read.
#------------------------------------------------------------------------------
sub process_sentence
{
    my @sentence = @_;
    my @to_merge =
    (
        # Sentences to be merged in the Dresden Bible.
        'Tehdy jemu vecě', # 4.10-4.10B; next: 'Ježíš: „ Jdi, satanas!'
        '„ Neroďte mnieti, bych já přišel chtě zrušiti zákon nebo proroky;', # 5.17-5.17B; next: 'nepřišel sem chtě rušiti, ale doplniti.'
        'Nemocné uzdravujte, mrtvé křěste, trudovaté očiščijte, běsy vypuzujte;', # 10.8-10.8B; next: 'darmo jste vzěli, darmo dávajte.'
        'Slepí vidie, chromí chodie, trudovatí sě očiščijí, hluší slyšie, mrtví z návi vstávají, chudí zvěstují;', # 11.5-11.6; next: 'a blažený, jenž sě na mně nepohorší. “'
        'A tu bieše člověk, jmajě ruku uschlú, i tázáchu jeho řkúce: „ Slušie li v soboty uzdravovati? “', # 12.10-12.10B; next: ', chtiece jeho tudy uviniti.'
        'Pak zvěděv', # 12.25-12.25B; next: 'Ježíš myšlenie jich, povědě: „ Každé královstvie rozdělené proti sobě bude pusto a každé město nebo duom rozdělené proti sobě nesstojí.'
        'Ale vy pravíte: Ktož kuoli die otci nebo mateři: Dar, kteříž kuoli jest ote mne, tobě prospěje, i neučstil jest svého otcě nebo mateře;', # 15.5-15.6; next: 'i rušili jste buožie přikázanie pro vašě ustavenie.'
        'A odtud počě', # 16.21-16.21B; next: 'Ježíš ukazovati učedlníkóm svým, že musí jíti do Jeruzaléma a mnoho trpěti od starost i mudrákóv i kniežat popových a zabit býti a třetí den z mrtvých vstáti.'
        'Pak uzřěvše kniežata popová i mudráci divy, ješto činieše, a dietky volajíce v chrámě a řkúce: „ Spasenie buď synu Davidovu! “', # 21.15-21.16; next: ', rozhněvachu sě i vecěchu jemu: „ Slyšíš li, co tito pravie? “'
        'I vecě jim Ježíš: „ Nikdy ste nečtli u písmě: Kámen, jímžto jsú zhrdali dělajíce, ten jest vstaven na vrch úhelný;', # 21.42-21.42B; next: 'hospodinem to jest učiněno a jest divné v naší očí?'
        'Jacíž biechu ve dnech přěd potopú, jědúce i píce, svatbiece sě a své dcery otdávajíce až do toho dne, jehožto jest', # 24.38-24.39; next: 'Noe všel v koráb, a nesnábděli jsú, až jest přišla potopa a všěcky vzdvihla; takež bude příščie syna člověčieho.'
        'Tehdy oni přiskočivše, pochopichu', # 26.50B-26.50C; next: 'Ježíšě rukama i držiechu jeho.'
        'A v devátú hodinu zavola Ježíš velikým hlasem řka: „ Heli, heli, lamazabatani? “', # 27.46-27.46B; next: ', to jest: „ Buože, bože muoj, čemus mne ostal? “'
        # Sentences to be merged in the Olomouc Bible.
        'Tehdy vychodieše k němu všěcek', # 3.5-3.6; next: 'Jeruzalém i vešken zástup i všěcka krajina podlé Jordána i přijímáchu ot něho křest v Jordáně, zpoviedajíce sě svých hřiechóv.'
        'Tehdy počě', # 4.17-4.17B; next: 'Ježíš kázati a řka: „ Čiňte pokánie, nebo sě přiblíži k vám nebeské králevstvie. “'
        '„ Neroďte mnieti, že bych přišel, abych zrušil zákon nebo proroky;', # next: 'nepřišel sem zrušiti zákona, ale naplniti.'
        '„ A když sě modlíte, nebudete jako pokrytci, ješto milují ve školách a v kútiech uličných stojiece modliti sě, chtiece, aby byli viděni ot lidí;', # next: 'zavěrné pravi vám to, že sú vzěli svú otplatu.'
        '„ A když sě postíte, neroďte býti jako pokrytci smutni, nebo oni ošeředějí svój obličej, aby ot lidí byli viděni, že sě postie;', # next: 'zavěrné pravi vám to, že sú již přijeli svú mzdu.'
        'Protož vám pravi, neroďte péčě jmieti o své duši, co jie jiesti, ani o svém těle, več sě obléci;', # next: 'však dušě jest větčie nežli krmě a tělo větčie nežli rúcho.'
        'A když přijide Ježíš do domu Petrova, uzřě svěst jeho ležiece v studené nemoci, i dotče sě jejie ruky i osta jie studenicě;', # next: 'i vsta inhed i poče jim slúžiti.'
        'A když přejide Ježíš přes přievoz v zemi gerazenarenskú, vjide, i střětešta jej dva, ješto jmějiechu v sobě diábly;', # next: 'ta biešta vyšla z hrobóv, líta přieliš, tak že ižádný nemožieše tú cěstú jíti.'
        'Tehdy', # next: 'Ježíš obrátiv sě a uzřěv ji, vecě: „ Jměj naději, dci, viera tvá, ta tě jest uzdravila. “'
        'Nemocné uzdravujte, malomocné očistijte, diábly vypuzijte;', # next: 'darmo ste vzěli, darmo dajte.'
        'A když jide odtud, vjide do jich školy, naliť, člověk, jenž jmějieše ruku suchú, i tázáchu jeho a řkúce: „ Jest li lzě v sobotu uzdravovati? “', # next: ', aby jej mohli obžalovati.'
        'Ale vy pravíte: Ktož kolivěk die otci nebo mateři: Dar, kterýž kolivěk ote mne jest, tobě prospěje, i nepoctí otcě svého ani mateře;', # next: 'i přestúpili ste kázanie božie pro vaše ustavenie.'
        'Takež jest svatý Petr múdrým sprostenstvím syna božieho následoval.', # 16.17B-16.17C; next: '), nebo tělo a krev nezjěvilo tobě, ale otec mój, jenž jest na nebesiech.'; Perhaps it should be merged even with the previous sentence, 16.17.
        'Tehdy', # next: 'Ježíš vecě svým mlazším: „ Chce li kto po mně jíti, otpověz sě sám sebe a vezmi svój kříž a poď za mnú.'
        'Otpověděv', # next: 'Ježíš vecě jim: „ Tieži já vás také jedné řěči, k niežto otpoviete li mi, já vám také poviem, kterú mocí to činím.'
        'Nebo všichni jmějiechu', # next: 'Jana jako proroka.'
        'Nebo jakož jest bylo ve dnech', # next: 'Noe, tak bude v příští syna člověčieho.'
        'Nebo jakož sú byli ve dnech před potopú, jedúce a pijíce a svatbiece sě až do toho dne, kteréhožto Noe všel v koráb, a nepoznali sú, až přišla voda i pobrala všěcky;', # next: 'tak bude i příštie syna člověčieho.'
        'I sta sě, když dokona', # next: 'Ježíš všěcky ty řěči, vecě k svým mlazším: „ Viete li, že po dvú dní velikanoc bude a syn člověčí bude zrazen, aby byl ukřižován? “'
        'Tehdy rytieři vladařěvi přijemše', # next: 'Ježíšě v konšelský dóm, sebrachu sě k němu a vešken lid.'
        ###!!! but the second part of the following should be split into two sentences!
        'A k deváté hodině volal jest Ježíš velikým hlasem a řka: „ Heli, heli, lamazabatany? “', # next: ', to jest: „ Bože, bože mój, pročs mě opustil? “ Někteří pak tu stojiece a slyšiece, praviechu: „ Heliášě volá tento. “'
        'Otpověděv pak anjel, vecě ženám: „ Nebojte sě vy, viemť zajisté, že Ježíšě, ješto jest ukřižován, hledáte;' # next: 'nenieť zde, vstalť jest zajisté, jakožť jest řekl.'
    );
    # Get the text of the sentence.
    my $text;
    foreach my $line (@sentence)
    {
        if($line =~ m/\#\s*text\s=\s*(.+)$/)
        {
            $text = $1;
            $text =~ s/\r?\n$//;
            last;
        }
    }
    if(grep {$_ eq $text} (@to_merge))
    {
        # Read the next sentence. In all instances where we know merging is needed,
        # only two consecutive sentences have to be merged.
        my @sentence2;
        while(<>)
        {
            push(@sentence2, $_);
            last if(m/^\s*$/);
        }
        # Discard the terminating empty line of the first sentence.
        pop(@sentence);
        # Get the text of the second sentence and append it to the text of the
        # first sentence.
        my $text2;
        foreach my $line (@sentence2)
        {
            if($line =~ m/\#\s*text\s*=\s*(.+)$/)
            {
                $text2 = $1;
                $text2 =~ s/\r?\n$//;
                last;
            }
        }
        foreach my $line (@sentence)
        {
            if($line =~ m/\#\s*text\s*=\s*(.+)$/)
            {
                my $text = $1;
                $text =~ s/\r?\n$//;
                print STDERR ("Merging '$text' +++ '$text2'\n");
                $counter++;
                $text .= ' '.$text2;
                $line = "\# text = $text\n";
                last;
            }
        }
        # Discard sentence-level comments of the second sentence.
        @sentence2 = grep {!m/^\#/} (@sentence2);
        # Get the last word ID used in the first sentence. Assume that there are
        # no empty nodes, so we can simply take the ID on the last line.
        my @f = split(/\t/, $sentence[-1]);
        my $sentence1_lastid = $f[0];
        # Adjust node IDs in the second sentence.
        foreach my $line (@sentence2)
        {
            if($line =~ m/^[0-9]/)
            {
                @f = split(/\t/, $line);
                if($f[0] =~ m/^([0-9]+)-([0-9]+)$/)
                {
                    $f[0] = ($1+$sentence1_lastid).'-'.($2+$sentence1_lastid);
                }
                else
                {
                    $f[0] += $sentence1_lastid;
                }
                # In order to keep a valid file, we should re-attach the root of
                # the second sentence as 'parataxis' to the root of the first
                # sentence. However, the syntactic annotation will be revised
                # manually anyway, so let's just keep the root where it is now.
                if($f[6] ne '_' && $f[6] ne '0')
                {
                    $f[6] += $sentence1_lastid;
                }
                $line = join("\t", @f);
            }
        }
        print(@sentence, @sentence2);
    }
    else
    {
        print(@sentence);
    }
}

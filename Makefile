SHELL=/bin/bash
UDPIPE=$(PARSINGROOT)/udpipe-parser/scripts/parse.pl
UDTOOLS=/net/work/people/zeman/unidep/tools

# Define the folders for each step.
# At present, "data" is a symlink to /net/work/people/zeman/hickok-data-neverzovano.
# Despite the "neverzovano" in the path, some data there are actually under version control,
# as they are again symlinks to /net/work/people/zeman/hickok-data.
#VERTDIR   := data/vert_full
VERTDIR   := data/vert_etalon
CONLLUDIR := data/conllu
TEXTDIR   := data/text
PARSEDDIR := data/parsed
MERGEDDIR := data/merged
PREPRCDIR := data/preprocessed
FORANNDIR := data/for_annotation
ANNOTDIR  := data/annotated

# Find all source files in the source folder.
VERTFILES   := $(wildcard $(VERTDIR)/*/*.vert)
CONLLUFILES := $(wildcard $(CONLLUDIR)/*/*.conllu)

# Generate the target file names for each step.
TEXTFILES   := $(addprefix $(TEXTDIR)/, $(addsuffix .txt, $(subst $(CONLLUDIR)/,,$(subst .conllu,,$(CONLLUFILES)))))
PARSEDFILES := $(patsubst $(CONLLUDIR)/%, $(PARSEDDIR)/%, $(CONLLUFILES))
MERGEDFILES := $(patsubst $(CONLLUDIR)/%, $(MERGEDDIR)/%, $(CONLLUFILES))
PREPRCFILES := $(patsubst $(CONLLUDIR)/%, $(PREPRCDIR)/%, $(CONLLUFILES))
FORANNFILES := $(addprefix $(FORANNDIR)/, $(addsuffix .tsv, $(subst $(CONLLUDIR)/,,$(subst .conllu,,$(CONLLUFILES)))))

# If a command ends with ane error, delete its target file because it may be corrupt.
.DELETE_ON_ERROR:

all: conllu forann
	echo $(VERTFILES) | wc -w

# Phony targets for each step.
# Convert the ÚJČ vertical format to CoNLL-U.
# This is applied to the whole folder and the loop is inside the script because individual files get renamed in the process (CamelCase, diacritics etc.)
.PHONY: conllu
conllu: $(VERTFILES)
	./tools/vert2conllu.pl --srcdir $(VERTDIR) --tgtdir $(CONLLUDIR) --fields word,amblemma,ambhlemma,ambprgtag,ambbrntag,comment,corrected_from,translit,language,hlt,hlat,inflclass
.PHONY: text
text:   $(TEXTFILES)
.PHONY: parsed
parsed: $(PARSEDFILES)
.PHONY: merged
merged: $(MERGEDFILES)
.PHONY: preprc
preprc: $(PREPRCFILES)
	rm $(PREPRCDIR)/*/*-forudapi.conllu
.PHONY: forann
forann: $(FORANNFILES)

# Extract plain text from an individual CoNLL-U file (which was converted from the vertical).
# The script resides in the UD tools repository.
$(TEXTDIR)/%.txt: $(CONLLUDIR)/%.conllu
	mkdir -p $(@D)
	conllu_to_text.pl --lang cs < $< > $@

# Parse the plain text with UDPipe 2.12. The script is in my parsing SVN repository.
# The script accesses the REST API at https://lindat.mff.cuni.cz/services/udpipe/.
# The UDPipe Czech FicTree model does not know the Czech Unicode „quotes“ (typically
# surrounded by spaces from both sides in the Old Czech data). It often moves
# the closing quotation mark (looking like English opening mark) to the next sentence.
# Move it back with the two subsequent Perl scripts.
$(PARSEDDIR)/%.conllu: $(TEXTDIR)/%.txt
	mkdir -p $(@D)
	$(UDPIPE) cs_fictree by212 < $< | ./tools/fix_sentence_segmentation_quotes.pl | ./tools/fix_sentence_segmentation.pl > $@

# After parsing the files with UDPipe, we want to make sure that our pre-annotated file has the same tokenization as UDPipe so we can compare annotation.
# The script conllu_copy_tokenization.pl is in the UD tools repository.
# Once the tokenization of the original file matches the output from UDPipe, we can also port the sentence segmentation.
# The script conllu_copy_sentence_segmentation.pl is in the UD tools repository.
# Then we can finally merge the UDPipe-generated morphosyntactic annotation with the other annotations inherited from the vertical.
$(MERGEDDIR)/%.conllu: $(PARSEDDIR)/%.conllu $(CONLLUDIR)/%.conllu
	mkdir -p $(@D)
	conllu_copy_tokenization.pl $^ > $(MERGEDDIR)/$*-retokenized.conllu
	conllu_copy_sentence_segmentation.pl --par2sentids $< $(MERGEDDIR)/$*-retokenized.conllu > $(MERGEDDIR)/$*-resegmented.conllu
	./tools/merge_conllu.pl $(MERGEDDIR)/$*-resegmented.conllu $< > $@

# Once everything has been merged with the output of UDPipe, we can afford to touch the
# tokenization again (and thus break the synchronization with UDPipe). Things to fix:
# - Remove spaces next to quotation marks. Ondřej has confirmed that they are not deliberate.
#   And we know the side of the quotation marks.
# - Annotate "abyšte" as a multi-word token. (UDPipe does not recognize it because the modern
#   spelling is "abyste".)
# Furthermore, apply rule-based fixes of morphology to reduce the load of the annotators.
# Explanation of the Udapi part: The preposition "u" normally requires genitive. But it can be also
# realization of the preposition "v" before labials, and then it would go with locative or
# accusative.
$(PREPRCDIR)/%.conllu: $(MERGEDDIR)/%.conllu
	mkdir -p $(@D)
	./tools/fix_tokenization.pl < $< | ./tools/fix_morphology.pl > $(PREPRCDIR)/$*-forudapi.conllu
	udapy -s util.Eval node='if node.form.lower() == "u" and node.upos == "ADP" and re.match(r"(Acc|Loc)", node.parent.feats["Case"]): node.lemma = "v"; node.feats["Case"] = node.parent.feats["Case"]; node.xpos = "RV--6----------" if node.feats["Case"] == "Loc" else "RV--4----------"' < $(PREPRCDIR)/$*-forudapi.conllu > $@

# Prepare a TSV file (tab-separated values) that can be opened in a spreadsheet editor such as
# LibreOffice Calc and manually annotated.
$(FORANNDIR)/%.tsv: $(PREPRCDIR)/%.conllu
	mkdir -p $(@D)
	./tools/generate_table_for_annotation.pl < $< > $@
	./tools/generate_sentence_list.pl < $< > $(FORANNDIR)/$*-sentences.txt

# Once a file has been annotated independently by two annotators, save their files as
# tab-separated values again (but now with ".csv" file extensions):
# Open the .xlsx file in LibreOffice Calc rather than Microsoft Excel. Select Save as "Text CSV",
# make sure to check "Upravit nastavení filtru", then set output encoding to Unicode (UTF-8),
# field separator to TAB, the rest can probably stay set to default values.

# Read the .csv files by the script below and verify that they still match the original in the
# important fields such as the word forms. Report differences between the two annotators and save
# their files in the CoNLL-U format.

# Note: We can give the script the initials of the annotators via --name1 and --name2; they will be
# then used in the difference report instead of 'A1' and 'A2'.
# Set the environment variables before calling make like this:
# STOL=14 ANNBASE=002_modl_kunh       A1=AM A2=JZ make postprocess
# STOL=14 ANNBASE=004_zalt_u          A1=JP A2=ON make postprocess
# STOL=14 ANNBASE=005_umuc_rajhr      A1=AM A2=JZ make postprocess
# STOL=14 ANNBASE=008_hrad_sat        A1=JP A2=ON make postprocess
# STOL=14 ANNBASE=002_modl_kunh       make postprocess_def
# STOL=14 ANNBASE=004_zalt_u          make postprocess_def
# STOL=14 ANNBASE=005_umuc_rajhr      make postprocess_def
# STOL=14 ANNBASE=008_hrad_sat        make postprocess_def
# STOL=14 ANNBASE=003_alx_h           A1=AM A2=JP make postprocess
# STOL=14 ANNBASE=011_alx_bm          A1=JZ A2=ON make postprocess
# STOL=14 ANNBASE=019_rada_otc_r      A1=JP A2=JZ make postprocess
# STOL=15 ANNBASE=021_podk_u          A1=AM A2=ON make postprocess
# STOL=15 ANNBASE=028_hus_kor_d_35    A1=AM A2=JZ make postprocess
# STOL=15 ANNBASE=037_bibl_kladr_1rg  A1=JP A2=ON make postprocess
# STOL=14 ANNBASE=003_alx_h           make postprocess_def
# STOL=14 ANNBASE=011_alx_bm          make postprocess_def
# STOL=14 ANNBASE=019_rada_otc_r      make postprocess_def
# STOL=15 ANNBASE=021_podk_u          make postprocess_def
# STOL=15 ANNBASE=028_hus_kor_d_35    make postprocess_def
# STOL=15 ANNBASE=037_bibl_kladr_1rg  make postprocess_def
# STOL=15 ANNBASE=026_otc_b           A1=AM A2=ON make postprocess
# STOL=15 ANNBASE=032_mart_kron_a     A1=JP A2=JZ make postprocess
# STOL=14 ANNBASE=001_prip_jir        A1=AM A2=JP make postprocess
# STOL=15 ANNBASE=032_mart_kron_a     make postprocess_def
# STOL=14 ANNBASE=001_prip_jir        make postprocess_def
# STOL=15 ANNBASE=026_otc_b           make postprocess_def
# STOL=14 ANNBASE=006_hrad_prok       A1=JP A2=ON make postprocess
# STOL=14 ANNBASE=007_hrad_magd       A1=JP A2=AM make postprocess
# STOL=14 ANNBASE=009_bibl_drazd_mc   A1=JP A2=ON make postprocess
# STOL=14 ANNBASE=010_bibl_drazd_mt   A1=AM A2=JZ make postprocess
# STOL=14 ANNBASE=012_mast_muz        A1=AM A2=JZ make postprocess
# STOL=14 ANNBASE=013_zalt_wittb      A1=AM A2=JZ make postprocess
# STOL=14 ANNBASE=014_stit_klem       A1=AM A2=ON make postprocess
# STOL=14 ANNBASE=015_krist_a         A1=JZ A2=ON make postprocess
# STOL=14 ANNBASE=007_hrad_magd       make postprocess_def
# STOL=14 ANNBASE=009_bibl_drazd_mc   make postprocess_def
# STOL=14 ANNBASE=010_bibl_drazd_mt   make postprocess_def
# STOL=14 ANNBASE=012_mast_muz        make postprocess_def
# STOL=14 ANNBASE=013_zalt_wittb      make postprocess_def
# STOL=14 ANNBASE=016_rad_kor_a       A1=JP A2=ON make postprocess
# STOL=14 ANNBASE=017_pas_muz_a       A1=JP A2=JZ make postprocess
# STOL=14 ANNBASE=018_dal_v           A1=JP A2=ON make postprocess
# STOL=14 ANNBASE=020_prisl_flas      A1=AM A2=ON make postprocess
# STOL=14 ANNBASE=006_hrad_prok       make postprocess_def
# STOL=14 ANNBASE=015_krist_a         make postprocess_def
# STOL=14 ANNBASE=016_rad_kor_a       make postprocess_def
# STOL=14 ANNBASE=017_pas_muz_a       make postprocess_def
# STOL=15 ANNBASE=022_maj_car_a       A1=ON A2=JZ make postprocess
# STOL=15 ANNBASE=023_lyra_mat        A1=AM A2=ON make postprocess
# STOL=15 ANNBASE=024_bibl_ol_gn-2esd A1=JP A2=ON make postprocess
# STOL=15 ANNBASE=025_bibl_ol_ct      A1=AM A2=JZ make postprocess
# STOL=15 ANNBASE=027_zrc_spas_k      A1=AM A2=JZ make postprocess
# STOL=15 ANNBASE=029_astar           A1=JP A2=AM make postprocess
# STOL=15 ANNBASE=030_lek_frant_muz   A1=JP A2=AM make postprocess
# STOL=15 ANNBASE=031_alex_pov_d      A1=JP A2=JZ make postprocess
# STOL=15 ANNBASE=033_prav_svab_c     A1=ON A2=AM make postprocess
# STOL=15 ANNBASE=034_brez_snar_m     A1=ON A2=JZ make postprocess
# STOL=14 ANNBASE=014_stit_klem       make postprocess_def
# STOL=14 ANNBASE=018_dal_v           make postprocess_def
# STOL=14 ANNBASE=020_prisl_flas      make postprocess_def
# STOL=15 ANNBASE=022_maj_car_a       make postprocess_def
# STOL=15 ANNBASE=023_lyra_mat        make postprocess_def
# STOL=15 ANNBASE=024_bibl_ol_gn-2esd make postprocess_def
# STOL=15 ANNBASE=025_bibl_ol_ct      make postprocess_def
# STOL=15 ANNBASE=027_zrc_spas_k      make postprocess_def
# STOL=15 ANNBASE=029_astar           make postprocess_def
# STOL=15 ANNBASE=030_lek_frant_muz   make postprocess_def
# STOL=15 ANNBASE=031_alex_pov_d      make postprocess_def
# STOL=15 ANNBASE=034_brez_snar_m     make postprocess_def
# STOL=15 ANNBASE=035_prav_jihl_a     A1=AM A2=JZ make postprocess
# STOL=15 ANNBASE=036_asen_m          A1=AM A2=ON make postprocess
# STOL=15 ANNBASE=038_baw_arn         A1=ON A2=JZ make postprocess
# STOL=15 ANNBASE=039_cest_mand_m     A1=JP A2=AM make postprocess
# STOL=15 ANNBASE=040_let_a           A1=ON A2=JZ make postprocess
# STOL=15 ANNBASE=041_svar            A1=JP A2=AM make postprocess
# STOL=15 ANNBASE=042_pov_ol          A1=ON A2=JZ make postprocess
# STOL=15 ANNBASE=043_lek_zen         A1=JP A2=JZ make postprocess
# STOL=15 ANNBASE=044_tkadl_b         A1=JP A2=ON make postprocess
# STOL=15 ANNBASE=045_hus_svatokup    A1=JP A2=JZ make postprocess
# STOL=16 ANNBASE=046_vespucci_spis_o_novych_zemich A1=JP A2=JZ make postprocess
# STOL=16 ANNBASE=047_kuch                          A1=AM A2=JZ make postprocess
# STOL=16 ANNBASE=049_frantovy_prava                A1=JP A2=AM make postprocess
# STOL=16 ANNBASE=050_hanus                         A1=AM A2=ON make postprocess
# STOL=16 ANNBASE=052_dopisy_dorota_z_krumlova      A1=AM A2=ON make postprocess
# STOL=16 ANNBASE=053_vejce                         A1=JP A2=AM make postprocess
# STOL=16 ANNBASE=059_kron_jov                      A1=JP A2=ON make postprocess
# STOL=15 ANNBASE=033_prav_svab_c                   make postprocess_def
# STOL=16 ANNBASE=048_piccolomini                   A1=AM A2=JZ make postprocess
# STOL=16 ANNBASE=051_voceh_mor                     A1=JP A2=JZ make postprocess
# STOL=16 ANNBASE=054_artik_1554                    A1=ON A2=JZ make postprocess
# STOL=16 ANNBASE=055_trunkopolstvi                 A1=ON A2=AM make postprocess
# STOL=16 ANNBASE=056_peristerius_kaz               A1=ON A2=AM make postprocess
# STOL=16 ANNBASE=057_mendl_ezop                    A1=AM A2=JZ make postprocess
# STOL=16 ANNBASE=058_subar_kaz                     A1=JP A2=AM make postprocess
# STOL=16 ANNBASE=060_rosslin_zahr_1588             A1=ON A2=AM make postprocess
# STOL=16 ANNBASE=061_vel_predml_apateka            A1=ON A2=JP make postprocess
# STOL=16 ANNBASE=062_podagra                       A1=JP A2=ON make postprocess
# STOL=17 ANNBASE=063_div_velik                     A1=JP A2=ON make postprocess
# STOL=17 ANNBASE=064_subar_pis_1612                A1=JP A2=ON make postprocess
# STOL=17 ANNBASE=065_o_ctnych_manzelkach_tehotnych A1=AM A2=ON make postprocess
# STOL=17 ANNBASE=066_dac_prostopravda              A1=ON A2=JP make postprocess
# STOL=17 ANNBASE=067_dopisy_zofie_albinka_z_helfenburku A1=JP A2=ON make postprocess
# STOL=17 ANNBASE=068_kom_kanc_tisk                      A1=JP A2=AM make postprocess
# STOL=17 ANNBASE=069_rosa_rozml                         A1=JP A2=AM make postprocess
# STOL=17 ANNBASE=070_vetter_islandia                    A1=JP A2=ON make postprocess
# STOL=17 ANNBASE=071_zivot_a_skutkove_ezopa             A1=JP A2=ON make postprocess
# STOL=18 ANNBASE=072_navstiveni                         A1=AM A2=ON make postprocess
# STOL=18 ANNBASE=073_enspigl                            A1=JP A2=ON make postprocess
# STOL=18 ANNBASE=074_kniha_smol_bojk_carodejnice        A1=AM A2=ON make postprocess
# STOL=18 ANNBASE=075_kniha_smol_bojk_smilnici           A1=JP A2=AM make postprocess
# STOL=18 ANNBASE=076_smol_jimr                          A1=JP A2=ON make postprocess
# STOL=18 ANNBASE=077_solc_pam                           A1=ON A2=JZ make postprocess
# STOL=18 ANNBASE=078_sepsani_ctnostneho_zivota_svateho_vendelina A1=ON A2=AM make postprocess
# STOL=18 ANNBASE=079_kucharka                                    A1=JP A2=AM make postprocess
# STOL=18 ANNBASE=080_pranostika_nova                             A1=AM A2=ON make postprocess
# STOL=18 ANNBASE=081_pranostika_sedlsk                           A1=JP A2=ON make postprocess
# STOL=18 ANNBASE=082_lucidar_1750                                A1=AM A2=ON make postprocess
# STOL=18 ANNBASE=083_pis_nepom_1789                              A1=JP A2=AM make postprocess
# STOL=18 ANNBASE=084_pis_nepom_1799                              A1=JP A2=AM make postprocess
# STOL=15 ANNBASE=035_prav_jihl_a                                 make postprocess_def
# STOL=15 ANNBASE=036_asen_m                                      make postprocess_def
# STOL=15 ANNBASE=038_baw_arn                                     make postprocess_def
# STOL=15 ANNBASE=039_cest_mand_m                                 make postprocess_def
# STOL=15 ANNBASE=040_let_a                                       make postprocess_def
# STOL=15 ANNBASE=041_svar                                        make postprocess_def
# STOL=15 ANNBASE=042_pov_ol                                      make postprocess_def
# STOL=15 ANNBASE=043_lek_zen                                     make postprocess_def
# STOL=15 ANNBASE=044_tkadl_b                                     make postprocess_def
# STOL=15 ANNBASE=045_hus_svatokup                                make postprocess_def
# STOL=16 ANNBASE=046_vespucci_spis_o_novych_zemich               make postprocess_def
# STOL=16 ANNBASE=047_kuch                                        make postprocess_def
# STOL=16 ANNBASE=048_piccolomini                                 make postprocess_def
# STOL=16 ANNBASE=049_frantovy_prava                              make postprocess_def
# STOL=16 ANNBASE=050_hanus                                       make postprocess_def
# STOL=16 ANNBASE=051_voceh_mor                                   make postprocess_def
# STOL=16 ANNBASE=052_dopisy_dorota_z_krumlova                    make postprocess_def
# STOL=16 ANNBASE=053_vejce                                       make postprocess_def
# STOL=16 ANNBASE=054_artik_1554                                  make postprocess_def
# STOL=16 ANNBASE=055_trunkopolstvi                               make postprocess_def
# STOL=16 ANNBASE=056_peristerius_kaz                             make postprocess_def
# STOL=16 ANNBASE=057_mendl_ezop                                  make postprocess_def
# STOL=16 ANNBASE=058_subar_kaz                                   make postprocess_def
# STOL=16 ANNBASE=059_kron_jov                                    make postprocess_def
# STOL=16 ANNBASE=060_rosslin_zahr_1588                           make postprocess_def
# STOL=16 ANNBASE=061_vel_predml_apateka                          make postprocess_def
# STOL=16 ANNBASE=062_podagra                                     make postprocess_def
# STOL=17 ANNBASE=063_div_velik                                   make postprocess_def
# STOL=17 ANNBASE=064_subar_pis_1612                              make postprocess_def
# STOL=17 ANNBASE=065_o_ctnych_manzelkach_tehotnych               make postprocess_def
# STOL=17 ANNBASE=066_dac_prostopravda                            make postprocess_def
# STOL=17 ANNBASE=067_dopisy_zofie_albinka_z_helfenburku          make postprocess_def
# STOL=17 ANNBASE=068_kom_kanc_tisk                               make postprocess_def
# STOL=17 ANNBASE=069_rosa_rozml                                  make postprocess_def
# STOL=17 ANNBASE=070_vetter_islandia                             make postprocess_def
# STOL=17 ANNBASE=071_zivot_a_skutkove_ezopa                      make postprocess_def
# STOL=18 ANNBASE=072_navstiveni                                  make postprocess_def
# STOL=18 ANNBASE=073_enspigl                                     make postprocess_def
# STOL=18 ANNBASE=074_kniha_smol_bojk_carodejnice                 make postprocess_def
# STOL=18 ANNBASE=075_kniha_smol_bojk_smilnici                    make postprocess_def
# STOL=18 ANNBASE=076_smol_jimr                                   make postprocess_def
# STOL=18 ANNBASE=077_solc_pam                                    make postprocess_def
# STOL=18 ANNBASE=078_sepsani_ctnostneho_zivota_svateho_vendelina make postprocess_def
# STOL=18 ANNBASE=079_kucharka                                    make postprocess_def
# STOL=18 ANNBASE=080_pranostika_nova                             make postprocess_def
# STOL=18 ANNBASE=081_pranostika_sedlsk                           make postprocess_def
# STOL=18 ANNBASE=082_lucidar_1750                                make postprocess_def
# STOL=18 ANNBASE=083_pis_nepom_1789                              make postprocess_def
# STOL=18 ANNBASE=084_pis_nepom_1799                              make postprocess_def

# Install Udapi (python) and make sure it is in PATH.
# Udapi resides in https://github.com/udapi/udapi-python
# The UD validation script should be in PATH (and python3 available).
# The script resides in https://github.com/UniversalDependencies/tools
# The annotated files may not be valid because syntactic annotation has been ignored.
UDAPISCEN = \
    util.JoinSentence misc_name=JoinSentence \
    util.SplitSentence misc_name=SplitSentence \
    ud.JoinToken misc_name=JoinToken \
    ud.SplitToken misc_name=SplitToken \
    ud.cs.AddMwt \
    ud.FixRoot \
    ud.FixAdvmodByUpos \
    ud.FixMultiSubjects \
    ud.FixMultiObjects \
    util.Eval node='if node.upos=="PUNCT": node.deprel="punct"' \
    util.Eval node='if node.deprel == "flat:foreign": node.deprel = "flat"' \
    util.Eval node='if node.udeprel == "orphan" and node.parent.deprel != "conj": node.deprel = "dep"' \
    util.Eval node='if node.udeprel == "fixed": node.deprel = "compound"' \
    ud.FixLeaf deprels=aux,cop,case,mark,cc,det \
    ud.FixRightheaded deprels=conj,flat,fixed,appos,goeswith,list \
    ud.FixAdvmodByUpos \
    ud.FixPunct
postprocess:
	if [[ -z "$(ANNBASE)" ]] ; then exit 1 ; fi ; if [[ -z "$(A1)" ]] ; then exit 2 ; fi ; if [[ -z "$(A2)" ]] ; then exit 3 ; fi
	set -o pipefail ; perl ./tools/process_annotated_csv.pl --orig data/for_annotation/$(STOL)_stol/$(ANNBASE).tsv --name1 $(A1) --ann1 $(ANNOTDIR)/$(STOL)_stol/$(ANNBASE)_$(A1).csv --name2 $(A2) --ann2 $(ANNOTDIR)/$(STOL)_stol/$(ANNBASE)_$(A2).csv 2>&1 >$(ANNOTDIR)/$(STOL)_stol/$(ANNBASE)_$(A1)_$(A2).diff.txt | tee $(ANNOTDIR)/$(STOL)_stol/$(ANNBASE)_$(A1)_$(A2).postprocess.log
	udapy read.Conllu files=$(ANNOTDIR)/$(STOL)_stol/$(ANNBASE)_$(A1).conllu $(UDAPISCEN) write.Conllu files=$(ANNOTDIR)/$(STOL)_stol/$(ANNBASE)_$(A1).fixed.conllu
	udapy read.Conllu files=$(ANNOTDIR)/$(STOL)_stol/$(ANNBASE)_$(A2).conllu $(UDAPISCEN) write.Conllu files=$(ANNOTDIR)/$(STOL)_stol/$(ANNBASE)_$(A2).fixed.conllu
	mv $(ANNOTDIR)/$(STOL)_stol/$(ANNBASE)_$(A1).fixed.conllu $(ANNOTDIR)/$(STOL)_stol/$(ANNBASE)_$(A1).conllu
	mv $(ANNOTDIR)/$(STOL)_stol/$(ANNBASE)_$(A2).fixed.conllu $(ANNOTDIR)/$(STOL)_stol/$(ANNBASE)_$(A2).conllu
	udapy read.Conllu files=$(ANNOTDIR)/$(STOL)_stol/$(ANNBASE)_$(A1).conllu util.Eval node='node.misc["AmbLemma"] = ""; node.misc["AmbHlemma"] = ""; node.misc["AmbPrgTag"] = ""; node.misc["AmbBrnTag"] = ""; node.misc["AmbHlemmaPrgTag"] = ""; node.misc["AmbHlemmaBrnTag"] = ""; node.misc["InflClass"] = ""; node.misc["Lemma1300"] = ""; node.misc["Verse"] = ""' ud.cs.MarkFeatsBugs util.MarkMwtBugsAtNodes write.TextModeTreesHtml files=$(ANNOTDIR)/$(STOL)_stol/$(ANNBASE)_$(A1).bugs.html marked_only=1 layout=compact attributes=form,lemma,upos,xpos,feats,deprel,misc
	udapy read.Conllu files=$(ANNOTDIR)/$(STOL)_stol/$(ANNBASE)_$(A2).conllu util.Eval node='node.misc["AmbLemma"] = ""; node.misc["AmbHlemma"] = ""; node.misc["AmbPrgTag"] = ""; node.misc["AmbBrnTag"] = ""; node.misc["AmbHlemmaPrgTag"] = ""; node.misc["AmbHlemmaBrnTag"] = ""; node.misc["InflClass"] = ""; node.misc["Lemma1300"] = ""; node.misc["Verse"] = ""' ud.cs.MarkFeatsBugs util.MarkMwtBugsAtNodes write.TextModeTreesHtml files=$(ANNOTDIR)/$(STOL)_stol/$(ANNBASE)_$(A2).bugs.html marked_only=1 layout=compact attributes=form,lemma,upos,xpos,feats,deprel,misc
	validate.py --lang cs $(ANNOTDIR)/$(STOL)_stol/$(ANNBASE)_$(A1).conllu |& tee $(ANNOTDIR)/$(STOL)_stol/$(ANNBASE)_$(A1).validation.log
	validate.py --lang cs $(ANNOTDIR)/$(STOL)_stol/$(ANNBASE)_$(A2).conllu |& tee $(ANNOTDIR)/$(STOL)_stol/$(ANNBASE)_$(A2).validation.log

# Use only a slightly modified postprocessing procedure to process the definitive version (after addressing the differences between the annotators).
# We still use the same script in the beginning, using "DEF" as the identifier of both annotators (the script will read the same file twice).
postprocess_def:
	if [[ -z "$(ANNBASE)" ]] ; then exit 1 ; fi
	set -o pipefail ; perl ./tools/process_annotated_csv.pl --orig data/for_annotation/$(STOL)_stol/$(ANNBASE).tsv --name1 DEF --ann1 $(ANNOTDIR)/$(STOL)_stol/$(ANNBASE)_DEF.csv 2>&1 | tee $(ANNOTDIR)/$(STOL)_stol/$(ANNBASE)_DEF.postprocess.log
	udapy read.Conllu files=$(ANNOTDIR)/$(STOL)_stol/$(ANNBASE)_DEF.conllu $(UDAPISCEN) write.Conllu files=$(ANNOTDIR)/$(STOL)_stol/$(ANNBASE)_DEF.fixed.conllu
	#cp $(ANNOTDIR)/$(STOL)_stol/$(ANNBASE)_DEF.conllu $(ANNOTDIR)/$(STOL)_stol/$(ANNBASE)_DEF.pre-fix-backup.conllu
	mv $(ANNOTDIR)/$(STOL)_stol/$(ANNBASE)_DEF.fixed.conllu $(ANNOTDIR)/$(STOL)_stol/$(ANNBASE)_DEF.conllu
	udapy read.Conllu files=$(ANNOTDIR)/$(STOL)_stol/$(ANNBASE)_DEF.conllu util.Eval node='node.misc["AmbLemma"] = ""; node.misc["AmbHlemma"] = ""; node.misc["AmbPrgTag"] = ""; node.misc["AmbBrnTag"] = ""; node.misc["AmbHlemmaPrgTag"] = ""; node.misc["AmbHlemmaBrnTag"] = ""; node.misc["InflClass"] = ""; node.misc["Lemma1300"] = ""; node.misc["Verse"] = ""' ud.cs.MarkFeatsBugs util.MarkMwtBugsAtNodes write.TextModeTreesHtml files=$(ANNOTDIR)/$(STOL)_stol/$(ANNBASE)_DEF.bugs.html marked_only=1 layout=compact attributes=form,lemma,upos,xpos,feats,deprel,misc
	validate.py --lang cs $(ANNOTDIR)/$(STOL)_stol/$(ANNBASE)_DEF.conllu |& tee $(ANNOTDIR)/$(STOL)_stol/$(ANNBASE)_DEF.validation.log

# 19th century files were annotated independently by Martin's team and we do not have to handle them in the same way
# as the Old/Middle Czech files above. Instead, we take the manually annotated vertical files and convert them to
# CoNLL-U.
postprocess19:
	./tools/vert2conllu19stol.pl --srcdir $(ANNOTDIR)/19_stol_vert_od_martina --tgtdir $(ANNOTDIR)/19_stol
	for i in $(ANNOTDIR)/19_stol/*.conllu ; do echo $$i ; \
	  cp $$i backup.conllu ; \
	  set -o pipefail ; cat backup.conllu | udapy -s util.Eval node='node.misc["XixstolTag"]=node.xpos' ud.cs.AddMwt ud.cs.FixMorpho | ./tools/xpos_pdtc_from_upos_feats.pl > $$i ; \
	  rm -f backup.conllu ; \
	done

# Nyní parsujeme novočeským UDPipem i Etalon 19, který z tohohle vznikne.
# Rozdíl je ale v tom, že tam pouze doplňujeme novočeskou syntaxi a morfologii necháváme ruční, kdežto tady se
# predikuje i morfologie (výsledek slouží ke srovnání s ruční anotací a odhalení systematických rozdílů v ruční anotaci).
parse19:
	mkdir -p data/19_stol_parsed_by217
	for i in $(ANNOTDIR)/19_stol/*.conllu ; do echo $$i ; \
	  $(UDPIPE) cs_fictree by217 conllu < $$i > data/19_stol_parsed_by217/`basename $$i` ; \
	done

# TODO:
# - Prohnat to validací včetně MarkFeatsBugs.



#----------------------------------------------------------------------------------------------------------------------
# Clean the gold standard data ("etalons") and copy them to a new location.
# Note: It would be more elegant to use $(patsubst %_stol,,$(SRCFILES)) but it does not seem to work on my system.
ETALON13SRCFILES := $(wildcard data/annotated/14_stol/*_DEF.conllu) $(wildcard data/annotated/15_stol/*_DEF.conllu)
ETALON16SRCFILES := $(wildcard data/annotated/16_stol/*_DEF.conllu) $(wildcard data/annotated/17_stol/*_DEF.conllu) $(wildcard data/annotated/18_stol/*_DEF.conllu)
ETALON19SRCFILES := $(wildcard data/annotated/19_stol/*.conllu)
ETALON13FILES := $(addprefix data/etalon13/,$(addsuffix .conllu,$(subst data/annotated/,,$(subst /15_stol,,$(subst /14_stol,,$(subst _DEF.conllu,,$(ETALON13SRCFILES)))))))
ETALON16FILES := $(addprefix data/etalon16/,$(addsuffix .conllu,$(subst data/annotated/,,$(subst /18_stol,,$(subst /17_stol,,$(subst /16_stol,,$(subst _DEF.conllu,,$(ETALON16SRCFILES))))))))
ETALON19FILES := $(addprefix data/etalon19/,$(subst data/annotated/19_stol/,,$(ETALON19SRCFILES)))
ETALON13PARSEDFILES := $(addprefix data/etalon13_parsed/,$(subst data/etalon13/,,$(ETALON13FILES)))
ETALON16PARSEDFILES := $(addprefix data/etalon16_parsed/,$(subst data/etalon16/,,$(ETALON16FILES)))
ETALON19PARSEDFILES := $(addprefix data/etalon19_parsed/,$(subst data/etalon19/,,$(ETALON19FILES)))
.PHONY: clean_etalons
clean_etalons: clean_etalon13 clean_etalon16 clean_etalon19
.PHONY: clean_etalon13
clean_etalon13:
	rm -rf data/etalon13/*.conllu
.PHONY: clean_etalon16
clean_etalon16:
	rm -rf data/etalon16/*.conllu
.PHONY: clean_etalon19
clean_etalon19:
	rm -rf data/etalon19/*.conllu
# The etalons will be parsed using UD_Czech-FicTree 2.17 model. The parser must not touch tokenization, segmentation, and morphology.
.PHONY: etalons
etalons: etalon13 etalon16 etalon19
.PHONY: etalon13
etalon13: $(ETALON13FILES)
data/etalon13/%.conllu: $(ANNOTDIR)/14_stol/%_DEF.conllu
	mkdir -p $(@D)
	udapy read.Conllu files=$< fix_cycles=1 \
	      util.Eval node='node.misc["AmbLemma"] = ""; node.misc["AmbHlemma"] = ""; node.misc["AmbPrgTag"] = ""; node.misc["AmbBrnTag"] = ""; node.misc["AmbHlemmaPrgTag"] = ""; node.misc["AmbHlemmaBrnTag"] = ""; node.misc["InflClass"] = ""; node.misc["Lemma1300"] = ""; node.misc["Verse"] = ""; node.misc["XixstolTag"] = ""; node.misc["Comment"] = ""; node.misc["CzechParticle"] = ""' \
	      util.Eval node='if node.multiword_token and (node == node.multiword_token.words[0]): mwt = node.multiword_token; mwt.misc["AmbLemma"] = ""; mwt.misc["AmbHlemma"] = ""; mwt.misc["AmbPrgTag"] = ""; mwt.misc["AmbBrnTag"] = ""; mwt.misc["AmbHlemmaPrgTag"] = ""; mwt.misc["AmbHlemmaBrnTag"] = ""; mwt.misc["InflClass"] = ""; mwt.misc["Lemma1300"] = ""; mwt.misc["Verse"] = ""; mwt.misc["XixstolTag"] = ""; mwt.misc["Comment"] = ""; mwt.misc["CzechParticle"] = ""' \
	      write.Conllu files=- \
	    | grep -v -P '# (udpipe_model|udpipe_model_license|generator) = ' \
	    | perl -pe 's/\# (newdoc id|newpar id|sent_id) = 13_19_stol-/\# $$1 = /' \
	    | $(UDTOOLS)/conllu_convert_uposf_to_xpos.pl -t cs::pdtc \
	    | $(PARSINGROOT)/udpipe-parser/scripts/udpipe2_client.py --model cs_fictree-ud-2.17-251125 --input=conllu --parser='' \
	    | grep -v -P '# (udpipe_model_licence|generator) = ' > $@
data/etalon13/%.conllu: $(ANNOTDIR)/15_stol/%_DEF.conllu
	mkdir -p $(@D)
	udapy read.Conllu files=$< fix_cycles=1 \
	      util.Eval node='node.misc["AmbLemma"] = ""; node.misc["AmbHlemma"] = ""; node.misc["AmbPrgTag"] = ""; node.misc["AmbBrnTag"] = ""; node.misc["AmbHlemmaPrgTag"] = ""; node.misc["AmbHlemmaBrnTag"] = ""; node.misc["InflClass"] = ""; node.misc["Lemma1300"] = ""; node.misc["Verse"] = ""; node.misc["XixstolTag"] = ""; node.misc["Comment"] = ""; node.misc["CzechParticle"] = ""' \
	      util.Eval node='if node.multiword_token and (node == node.multiword_token.words[0]): mwt = node.multiword_token; mwt.misc["AmbLemma"] = ""; mwt.misc["AmbHlemma"] = ""; mwt.misc["AmbPrgTag"] = ""; mwt.misc["AmbBrnTag"] = ""; mwt.misc["AmbHlemmaPrgTag"] = ""; mwt.misc["AmbHlemmaBrnTag"] = ""; mwt.misc["InflClass"] = ""; mwt.misc["Lemma1300"] = ""; mwt.misc["Verse"] = ""; mwt.misc["XixstolTag"] = ""; mwt.misc["Comment"] = ""; mwt.misc["CzechParticle"] = ""' \
	      write.Conllu files=- \
	    | grep -v -P '# (udpipe_model|udpipe_model_license|generator) = ' \
	    | perl -pe 's/\# (newdoc id|newpar id|sent_id) = 13_19_stol-/\# $$1 = /' \
	    | $(UDTOOLS)/conllu_convert_uposf_to_xpos.pl -t cs::pdtc \
	    | $(PARSINGROOT)/udpipe-parser/scripts/udpipe2_client.py --model cs_fictree-ud-2.17-251125 --input=conllu --parser='' \
	    | grep -v -P '# (udpipe_model_licence|generator) = ' > $@
.PHONY: etalon16
etalon16: $(ETALON16FILES)
data/etalon16/%.conllu: $(ANNOTDIR)/16_stol/%_DEF.conllu
	mkdir -p $(@D)
	udapy read.Conllu files=$< fix_cycles=1 \
	      util.Eval node='node.misc["AmbLemma"] = ""; node.misc["AmbHlemma"] = ""; node.misc["AmbPrgTag"] = ""; node.misc["AmbBrnTag"] = ""; node.misc["AmbHlemmaPrgTag"] = ""; node.misc["AmbHlemmaBrnTag"] = ""; node.misc["InflClass"] = ""; node.misc["Lemma1300"] = ""; node.misc["Verse"] = ""; node.misc["XixstolTag"] = ""; node.misc["Comment"] = ""; node.misc["CzechParticle"] = ""' \
	      util.Eval node='if node.multiword_token and (node == node.multiword_token.words[0]): mwt = node.multiword_token; mwt.misc["AmbLemma"] = ""; mwt.misc["AmbHlemma"] = ""; mwt.misc["AmbPrgTag"] = ""; mwt.misc["AmbBrnTag"] = ""; mwt.misc["AmbHlemmaPrgTag"] = ""; mwt.misc["AmbHlemmaBrnTag"] = ""; mwt.misc["InflClass"] = ""; mwt.misc["Lemma1300"] = ""; mwt.misc["Verse"] = ""; mwt.misc["XixstolTag"] = ""; mwt.misc["Comment"] = ""; mwt.misc["CzechParticle"] = ""' \
	      write.Conllu files=- \
	    | grep -v -P '# (udpipe_model|udpipe_model_license|generator) = ' \
	    | perl -pe 's/\# (newdoc id|newpar id|sent_id) = 13_19_stol-/\# $$1 = /' \
	    | $(UDTOOLS)/conllu_convert_uposf_to_xpos.pl -t cs::pdtc \
	    | $(PARSINGROOT)/udpipe-parser/scripts/udpipe2_client.py --model cs_fictree-ud-2.17-251125 --input=conllu --parser='' \
	    | grep -v -P '# (udpipe_model_licence|generator) = ' > $@
data/etalon16/%.conllu: $(ANNOTDIR)/17_stol/%_DEF.conllu
	mkdir -p $(@D)
	udapy read.Conllu files=$< fix_cycles=1 \
	      util.Eval node='node.misc["AmbLemma"] = ""; node.misc["AmbHlemma"] = ""; node.misc["AmbPrgTag"] = ""; node.misc["AmbBrnTag"] = ""; node.misc["AmbHlemmaPrgTag"] = ""; node.misc["AmbHlemmaBrnTag"] = ""; node.misc["InflClass"] = ""; node.misc["Lemma1300"] = ""; node.misc["Verse"] = ""; node.misc["XixstolTag"] = ""; node.misc["Comment"] = ""; node.misc["CzechParticle"] = ""' \
	      util.Eval node='if node.multiword_token and (node == node.multiword_token.words[0]): mwt = node.multiword_token; mwt.misc["AmbLemma"] = ""; mwt.misc["AmbHlemma"] = ""; mwt.misc["AmbPrgTag"] = ""; mwt.misc["AmbBrnTag"] = ""; mwt.misc["AmbHlemmaPrgTag"] = ""; mwt.misc["AmbHlemmaBrnTag"] = ""; mwt.misc["InflClass"] = ""; mwt.misc["Lemma1300"] = ""; mwt.misc["Verse"] = ""; mwt.misc["XixstolTag"] = ""; mwt.misc["Comment"] = ""; mwt.misc["CzechParticle"] = ""' \
	      write.Conllu files=- \
	    | grep -v -P '# (udpipe_model|udpipe_model_license|generator) = ' \
	    | perl -pe 's/\# (newdoc id|newpar id|sent_id) = 13_19_stol-/\# $$1 = /' \
	    | $(UDTOOLS)/conllu_convert_uposf_to_xpos.pl -t cs::pdtc \
	    | $(PARSINGROOT)/udpipe-parser/scripts/udpipe2_client.py --model cs_fictree-ud-2.17-251125 --input=conllu --parser='' \
	    | grep -v -P '# (udpipe_model_licence|generator) = ' > $@
data/etalon16/%.conllu: $(ANNOTDIR)/18_stol/%_DEF.conllu
	mkdir -p $(@D)
	udapy read.Conllu files=$< fix_cycles=1 \
	      util.Eval node='node.misc["AmbLemma"] = ""; node.misc["AmbHlemma"] = ""; node.misc["AmbPrgTag"] = ""; node.misc["AmbBrnTag"] = ""; node.misc["AmbHlemmaPrgTag"] = ""; node.misc["AmbHlemmaBrnTag"] = ""; node.misc["InflClass"] = ""; node.misc["Lemma1300"] = ""; node.misc["Verse"] = ""; node.misc["XixstolTag"] = ""; node.misc["Comment"] = ""; node.misc["CzechParticle"] = ""' \
	      util.Eval node='if node.multiword_token and (node == node.multiword_token.words[0]): mwt = node.multiword_token; mwt.misc["AmbLemma"] = ""; mwt.misc["AmbHlemma"] = ""; mwt.misc["AmbPrgTag"] = ""; mwt.misc["AmbBrnTag"] = ""; mwt.misc["AmbHlemmaPrgTag"] = ""; mwt.misc["AmbHlemmaBrnTag"] = ""; mwt.misc["InflClass"] = ""; mwt.misc["Lemma1300"] = ""; mwt.misc["Verse"] = ""; mwt.misc["XixstolTag"] = ""; mwt.misc["Comment"] = ""; mwt.misc["CzechParticle"] = ""' \
	      write.Conllu files=- \
	    | grep -v -P '# (udpipe_model|udpipe_model_license|generator) = ' \
	    | perl -pe 's/\# (newdoc id|newpar id|sent_id) = 13_19_stol-/\# $$1 = /' \
	    | $(UDTOOLS)/conllu_convert_uposf_to_xpos.pl -t cs::pdtc \
	    | $(PARSINGROOT)/udpipe-parser/scripts/udpipe2_client.py --model cs_fictree-ud-2.17-251125 --input=conllu --parser='' \
	    | grep -v -P '# (udpipe_model_licence|generator) = ' > $@
.PHONY: etalon19
etalon19: $(ETALON19FILES)
data/etalon19/%.conllu: $(ANNOTDIR)/19_stol/%.conllu
	mkdir -p $(@D)
	udapy read.Conllu files=$< fix_cycles=1 \
	      util.Eval node='node.misc["AmbLemma"] = ""; node.misc["AmbHlemma"] = ""; node.misc["AmbPrgTag"] = ""; node.misc["AmbBrnTag"] = ""; node.misc["AmbHlemmaPrgTag"] = ""; node.misc["AmbHlemmaBrnTag"] = ""; node.misc["InflClass"] = ""; node.misc["Lemma1300"] = ""; node.misc["Verse"] = ""; node.misc["XixstolTag"] = ""; node.misc["Comment"] = ""; node.misc["CzechParticle"] = ""' \
	      util.Eval node='if node.multiword_token and (node == node.multiword_token.words[0]): mwt = node.multiword_token; mwt.misc["AmbLemma"] = ""; mwt.misc["AmbHlemma"] = ""; mwt.misc["AmbPrgTag"] = ""; mwt.misc["AmbBrnTag"] = ""; mwt.misc["AmbHlemmaPrgTag"] = ""; mwt.misc["AmbHlemmaBrnTag"] = ""; mwt.misc["InflClass"] = ""; mwt.misc["Lemma1300"] = ""; mwt.misc["Verse"] = ""; mwt.misc["XixstolTag"] = ""; mwt.misc["Comment"] = ""; mwt.misc["CzechParticle"] = ""' \
	      write.Conllu files=- \
	    | grep -v -P '# (udpipe_model|udpipe_model_license|generator) = ' \
	    | perl -pe 's/\# (newdoc id|newpar id|sent_id) = 13_19_stol-/\# $$1 = /' \
	    | $(UDTOOLS)/conllu_convert_uposf_to_xpos.pl -t cs::pdtc \
	    | $(PARSINGROOT)/udpipe-parser/scripts/udpipe2_client.py --model cs_fictree-ud-2.17-251125 --input=conllu --parser='' \
	    | grep -v -P '# (udpipe_model_licence|generator) = ' > $@

# TODO:
# - Prohnat i 19. století validací včetně MarkFeatsBugs.
# - Udělat nějaké statistické porovnání lematizace, UPOS a FEATS mezi PDT-C, 19. stoletím, střední a starou češtinou.
#   Např. pro každý tvar seřadit jeho analýzy podle četnosti, pak se podívat, jestli se nejčastější výsledek v různých korpusech liší.
compare19:
	###!!! Teď, když máme sjednocené cíle pro výrobu tří etalonů, by se tohle srovnání mohlo přesunout tam.
	# Podobně jako na řádku níže potřebuju taky fictree.conllu a podobně jeden soubor pro staročeštinu (popř. včetně střední češtiny).
	cat $(ANNOTDIR)/19_stol/*.conllu > $(ANNOTDIR)/19stol.conllu
	./tools/survey_ambiguous_analyses.pl --compare $(ANNOTDIR)/19stol.conllu $(ANNOTDIR)/14stol.conllu $(ANNOTDIR)/fictree.conllu > $(ANNOTDIR)/19stol-14stol-fictree-diff.txt



#----------------------------------------------------------------------------------------------------------------------
# Training and testing parsers on the etalons.

# Concatenate each etalon into a big file similarly to UD treebanks.
# Also fetch modern Czech data from an official UD release.
UDPIPE_DATA_DIR := data/for_udpipe
UD_RELEASE_DIR := /net/data/universal-dependencies-2.18

.PHONY: copy_ud_czech
copy_ud_czech:
	mkdir -p $(UDPIPE_DATA_DIR)/cs_pdtc
	rm -f $(UDPIPE_DATA_DIR)/cs_pdtc/*
	cp $(UD_RELEASE_DIR)/UD_Czech-PDTC/*.conllu $(UDPIPE_DATA_DIR)/cs_pdtc
	mkdir -p $(UDPIPE_DATA_DIR)/cs_fictree
	rm -f $(UDPIPE_DATA_DIR)/cs_fictree/*
	cp $(UD_RELEASE_DIR)/UD_Czech-FicTree/*.conllu $(UDPIPE_DATA_DIR)/cs_fictree
	mkdir -p $(UDPIPE_DATA_DIR)/cs_cac
	rm -f $(UDPIPE_DATA_DIR)/cs_cac/*
	cp $(UD_RELEASE_DIR)/UD_Czech-CAC/*.conllu $(UDPIPE_DATA_DIR)/cs_cac
	mkdir -p $(UDPIPE_DATA_DIR)/cs_cltt
	rm -f $(UDPIPE_DATA_DIR)/cs_cltt/*
	cp $(UD_RELEASE_DIR)/UD_Czech-CLTT/*.conllu $(UDPIPE_DATA_DIR)/cs_cltt

.PHONY: etalon_test_only
etalon_test_only:
	mkdir -p $(UDPIPE_DATA_DIR)/cs_e13to
	mkdir -p $(UDPIPE_DATA_DIR)/cs_e16to
	mkdir -p $(UDPIPE_DATA_DIR)/cs_e19to
	rm -f cs_e13to/*.conllu
	rm -f cs_e16to/*.conllu
	rm -f cs_e19to/*.conllu
	cat data/etalon13/*.conllu > $(UDPIPE_DATA_DIR)/cs_e13to/cs_e13to-ud-test.conllu
	cat data/etalon16/*.conllu > $(UDPIPE_DATA_DIR)/cs_e16to/cs_e16to-ud-test.conllu
	cat data/etalon19/*.conllu > $(UDPIPE_DATA_DIR)/cs_e19to/cs_e19to-ud-test.conllu

# Split Etalon 13 to training, development and test data.
ETALON13DEV := $(addprefix $(UDPIPE_DATA_DIR)/cs_e13tdt/train/,$(addsuffix .conllu,005_umuc_rajhr 017_pas_muz_a 030_lek_frant_muz 040_let_a))
ETALON13TEST := $(addprefix $(UDPIPE_DATA_DIR)/cs_e13tdt/train/,$(addsuffix .conllu,010_bibl_drazd_mt 019_rada_otc_r 033_prav_svab_c 042_pov_ol))
.PHONY: etalon13split
etalon13split:
	mkdir -p $(UDPIPE_DATA_DIR)/cs_e13tdt/train
	mkdir -p $(UDPIPE_DATA_DIR)/cs_e13tdt/dev
	mkdir -p $(UDPIPE_DATA_DIR)/cs_e13tdt/test
	cp data/etalon13/*.conllu $(UDPIPE_DATA_DIR)/cs_e13tdt/train
	mv $(ETALON13DEV) $(UDPIPE_DATA_DIR)/cs_e13tdt/dev
	mv $(ETALON13TEST) $(UDPIPE_DATA_DIR)/cs_e13tdt/test
	cat $(UDPIPE_DATA_DIR)/cs_e13tdt/train/*.conllu > $(UDPIPE_DATA_DIR)/cs_e13tdt/cs_e13tdt-ud-train.conllu
	cat $(UDPIPE_DATA_DIR)/cs_e13tdt/dev/*.conllu > $(UDPIPE_DATA_DIR)/cs_e13tdt/cs_e13tdt-ud-dev.conllu
	cat $(UDPIPE_DATA_DIR)/cs_e13tdt/test/*.conllu > $(UDPIPE_DATA_DIR)/cs_e13tdt/cs_e13tdt-ud-test.conllu
	rm -rf $(UDPIPE_DATA_DIR)/cs_e13tdt/train
	rm -rf $(UDPIPE_DATA_DIR)/cs_e13tdt/dev
	rm -rf $(UDPIPE_DATA_DIR)/cs_e13tdt/test
	@echo If necessary, update the size of this treebank in $(UDPIPE_DATA_DIR)/langs_sizes.
# Split Etalon 16 to training, development and test data.
ETALON16DEV := $(addprefix $(UDPIPE_DATA_DIR)/cs_e16tdt/train/,$(addsuffix .conllu,049_frantovy_prava 065_o_ctnych_manzelkach_tehotnych 076_smol_jimr))
ETALON16TEST := $(addprefix $(UDPIPE_DATA_DIR)/cs_e16tdt/train/,$(addsuffix .conllu,050_hanus 063_div_velik 080_pranostika_nova))
.PHONY: etalon16split
etalon16split:
	mkdir -p $(UDPIPE_DATA_DIR)/cs_e16tdt/train
	mkdir -p $(UDPIPE_DATA_DIR)/cs_e16tdt/dev
	mkdir -p $(UDPIPE_DATA_DIR)/cs_e16tdt/test
	cp data/etalon16/*.conllu $(UDPIPE_DATA_DIR)/cs_e16tdt/train
	mv $(ETALON16DEV) $(UDPIPE_DATA_DIR)/cs_e16tdt/dev
	mv $(ETALON16TEST) $(UDPIPE_DATA_DIR)/cs_e16tdt/test
	cat $(UDPIPE_DATA_DIR)/cs_e16tdt/train/*.conllu > $(UDPIPE_DATA_DIR)/cs_e16tdt/cs_e16tdt-ud-train.conllu
	cat $(UDPIPE_DATA_DIR)/cs_e16tdt/dev/*.conllu > $(UDPIPE_DATA_DIR)/cs_e16tdt/cs_e16tdt-ud-dev.conllu
	cat $(UDPIPE_DATA_DIR)/cs_e16tdt/test/*.conllu > $(UDPIPE_DATA_DIR)/cs_e16tdt/cs_e16tdt-ud-test.conllu
	rm -rf $(UDPIPE_DATA_DIR)/cs_e16tdt/train
	rm -rf $(UDPIPE_DATA_DIR)/cs_e16tdt/dev
	rm -rf $(UDPIPE_DATA_DIR)/cs_e16tdt/test
	@echo If necessary, update the size of this treebank in $(UDPIPE_DATA_DIR)/langs_sizes.
# Split Etalon 19 to training, development and test data.
ETALON19DEV := $(addprefix $(UDPIPE_DATA_DIR)/cs_e19tdt/train/,$(addsuffix .conllu,1802_krameriusovy_noviny_21.8.1802 1832_svihlik_edmund_a_belinka 1855_stroupeznicka_boure 1869_jaros_z_chladku))
ETALON19TEST := $(addprefix $(UDPIPE_DATA_DIR)/cs_e19tdt/train/,$(addsuffix .conllu,1808_kramerius_vyd_rozlicne_povidacky 1827_rettigova_bila_ruze 1846_prazske_noviny_19.3.1846 1874_palacky_nejnovejsi_politicke_uvahy))
.PHONY: etalon19split
etalon19split:
	mkdir -p $(UDPIPE_DATA_DIR)/cs_e19tdt/train
	mkdir -p $(UDPIPE_DATA_DIR)/cs_e19tdt/dev
	mkdir -p $(UDPIPE_DATA_DIR)/cs_e19tdt/test
	cp data/etalon19/*.conllu $(UDPIPE_DATA_DIR)/cs_e19tdt/train
	mv $(ETALON19DEV) $(UDPIPE_DATA_DIR)/cs_e19tdt/dev
	mv $(ETALON19TEST) $(UDPIPE_DATA_DIR)/cs_e19tdt/test
	cat $(UDPIPE_DATA_DIR)/cs_e19tdt/train/*.conllu > $(UDPIPE_DATA_DIR)/cs_e19tdt/cs_e19tdt-ud-train.conllu
	cat $(UDPIPE_DATA_DIR)/cs_e19tdt/dev/*.conllu > $(UDPIPE_DATA_DIR)/cs_e19tdt/cs_e19tdt-ud-dev.conllu
	cat $(UDPIPE_DATA_DIR)/cs_e19tdt/test/*.conllu > $(UDPIPE_DATA_DIR)/cs_e19tdt/cs_e19tdt-ud-test.conllu
	rm -rf $(UDPIPE_DATA_DIR)/cs_e19tdt/train
	rm -rf $(UDPIPE_DATA_DIR)/cs_e19tdt/dev
	rm -rf $(UDPIPE_DATA_DIR)/cs_e19tdt/test
	@echo If necessary, update the size of this treebank in $(UDPIPE_DATA_DIR)/langs_sizes.

.PHONY: cs_all
cs_all:
	mkdir -p $(UDPIPE_DATA_DIR)/cs_all
	rm -f $(UDPIPE_DATA_DIR)/cs_all/*
	for i in cs_pdtc cs_fictree cs_cac cs_cltt cs_e13tdt cs_e16tdt cs_e19tdt ; do \
	  cat $(UDPIPE_DATA_DIR)/$$i/*-train.conllu >> $(UDPIPE_DATA_DIR)/cs_all/cs_all-ud-train.conllu ; \
	  cp $(UDPIPE_DATA_DIR)/$$i/*-dev.conllu $(UDPIPE_DATA_DIR)/cs_all ; \
	  cp $(UDPIPE_DATA_DIR)/$$i/*-test.conllu $(UDPIPE_DATA_DIR)/cs_all ; \
	done

.PHONY: langsizes
langsizes:
	rm -f $(UDPIPE_DATA_DIR)/langs_sizes
	for i in $(UDPIPE_DATA_DIR)/cs_* ; do \
	  if compgen -G "$$i/*-train.conllu" > /dev/null ; then \
	    echo -en "`basename $$i`\t" >> $(UDPIPE_DATA_DIR)/langs_sizes ; \
	    cat $$i/*-train.conllu | grep -P '^[0-9]+\t' | wc -l >> $(UDPIPE_DATA_DIR)/langs_sizes ; \
	  fi ; \
	done
	cat $(UDPIPE_DATA_DIR)/langs_sizes

trenovani_modelu_na_etalonu_13: # jen přibližný záznam akcí; nelze skutečně spustit jako cíl
	ssh -A sol1
	cd /net/work/people/zeman/udpipe
	./scripts/compute_embeddings.sh ./hickok
	# This will submit a cluster job for each treebank in data. Wait until squeue says that all jobs finished. It should not take long.
	./scripts/train.sh ./hickok cs_e13tdt
	./scripts/train.sh ./hickok cs_e16tdt
	./scripts/train.sh ./hickok cs_e19tdt
	# This will submit one cluster job for cs_e13tdt. It may take about 2 hours. Monitor progress:
	tail -f models/hickok-cs_e13tdt/training.log
	# Train tokenizer using UDPipe 1.2 (runs locally, does not use cluster).
	./scripts/train_tokenizer.sh ./hickok cs_e13tdt models/hickok-cs_e13tdt
	./scripts/train_tokenizer.sh ./hickok cs_e16tdt models/hickok-cs_e16tdt
	./scripts/train_tokenizer.sh ./hickok cs_e19tdt models/hickok-cs_e19tdt
	# Launch parsing server with the new models, ideally on a cluster machine with a GPU available.
	# Note: Each model is a quadruple of parameters: model name(s) (colon-separated), path to model, treebank id (because in that path could be a model for multiple treebanks), acknowledgements URL.
	sbatch -p gpu-ms,gpu-troja -G 1 -C "gpu_cc6.1|gpu_cc7.5" -x dll-8gpu5 --mem=24G -o udpipe2_server_slurm.log ./run2 \
		udpipe2_server.py 8001 --logfile udpipe2_server.log --threads=4 e13 \
			e13 ./models/data-cs_e13tdt cs_e13tdt https://ufal.mff.cuni.cz/ \
			e16 ./models/data-cs_e16tdt cs_e16tdt https://ufal.mff.cuni.cz/ \
			e19 ./models/data-cs_e19tdt cs_e19tdt https://ufal.mff.cuni.cz/ \
			czech:ces:cs:fictree:e21 ./models-pretrained/cs_all-ud-2.17-251125.model cs_fictree https://ufal.mff.cuni.cz
	# Access the model through client script. Note that we need to know which cluster machine the server runs on!
	echo "Soused včera prodal auto." | python udpipe2_client.py --service http://dll-10gpu2.ufal.hide.ms.mff.cuni.cz:8001 --model e13 --tokenizer='' --tagger='' --parser=''
	echo "Soused včera prodal auto." | python udpipe2_client.py --service http://localhost:8001 --model czech --tokenizer='' --tagger='' --parser=''

etalon13testfictree:
	$(PARSINGROOT)/udpipe-parser/scripts/udpipe2_client.py --model cs_fictree-ud-2.17-251125 --input=conllu --tagger='' < $(UDPIPE_DATA_DIR)/cs_e13tdt/cs_e13tdt-ud-test.conllu > cs_e13tdt-ud-test-by217.conllu
	$(UDTOOLS)/eval.py -v $(UDPIPE_DATA_DIR)/cs_e13tdt/cs_e13tdt-ud-test.conllu cs_e13tdt-ud-test-by217.conllu
etalon16testfictree:
	$(PARSINGROOT)/udpipe-parser/scripts/udpipe2_client.py --model cs_fictree-ud-2.17-251125 --input=conllu --tagger='' < $(UDPIPE_DATA_DIR)/cs_e16tdt/cs_e16tdt-ud-test.conllu > cs_e16tdt-ud-test-by217.conllu
	$(UDTOOLS)/eval.py -v $(UDPIPE_DATA_DIR)/cs_e16tdt/cs_e16tdt-ud-test.conllu cs_e16tdt-ud-test-by217.conllu
etalon19testfictree:
	$(PARSINGROOT)/udpipe-parser/scripts/udpipe2_client.py --model cs_fictree-ud-2.17-251125 --input=conllu --tagger='' < $(UDPIPE_DATA_DIR)/cs_e19tdt/cs_e19tdt-ud-test.conllu > cs_e19tdt-ud-test-by217.conllu
	$(UDTOOLS)/eval.py -v $(UDPIPE_DATA_DIR)/cs_e19tdt/cs_e19tdt-ud-test.conllu cs_e19tdt-ud-test-by217.conllu
etalon19teste19:
	$(PARSINGROOT)/udpipe-parser/scripts/udpipe2_client.py --service http://dll-10gpu2.ufal.hide.ms.mff.cuni.cz:8001 --model e19 --input=conllu --tagger='' < $(UDPIPE_DATA_DIR)/cs_e19tdt/cs_e19tdt-ud-test.conllu > cs_e19tdt-ud-test-bye19.conllu
	$(UDTOOLS)/eval.py -v $(UDPIPE_DATA_DIR)/cs_e19tdt/cs_e19tdt-ud-test.conllu cs_e19tdt-ud-test-bye19.conllu
etalon19teste16:
	$(PARSINGROOT)/udpipe-parser/scripts/udpipe2_client.py --service http://dll-10gpu2.ufal.hide.ms.mff.cuni.cz:8001 --model e16 --input=conllu --tagger='' < $(UDPIPE_DATA_DIR)/cs_e19tdt/cs_e19tdt-ud-test.conllu > cs_e19tdt-ud-test-bye16.conllu
	$(UDTOOLS)/eval.py -v $(UDPIPE_DATA_DIR)/cs_e19tdt/cs_e19tdt-ud-test.conllu cs_e19tdt-ud-test-bye16.conllu
etalon19teste13:
	$(PARSINGROOT)/udpipe-parser/scripts/udpipe2_client.py --service http://dll-10gpu2.ufal.hide.ms.mff.cuni.cz:8001 --model e13 --input=conllu --tagger='' < $(UDPIPE_DATA_DIR)/cs_e19tdt/cs_e19tdt-ud-test.conllu > cs_e19tdt-ud-test-bye13.conllu
	$(UDTOOLS)/eval.py -v $(UDPIPE_DATA_DIR)/cs_e19tdt/cs_e19tdt-ud-test.conllu cs_e19tdt-ud-test-bye13.conllu



#----------------------------------------------------------------------------------------------------------------------
# Monitor corpus.
# $(MONITORDIR) has subfolders "19", "20", "21" for individual centuries (where "21" in fact starts with the year 1990).
# Each of them has subfolders "JADRO" and "NEJADRO".
# Their contents are .txt files in "13-15", "16-18" and "19", and .xml files in "20" and "21".
# Even the .txt files contain occasional markup that must be removed. Prepare the files: rename them, remove markup.
MONITORSRCDIR := data/monitor_korpus
MONITORRENAMEDDIR := data/monitor_renamed
MONITORTEXTDIR := data/monitor_text
MONITOR13SRCFILES := $(wildcard $(MONITORSRCDIR)/13-15/*/*.txt)
MONITOR16SRCFILES := $(wildcard $(MONITORSRCDIR)/16-18/*/*.txt)
MONITOR19SRCFILES := $(wildcard $(MONITORSRCDIR)/19/*/*.txt)
MONITOR13RENAMEDFILES := $(wildcard $(MONITORRENAMEDDIR)/13-15/*/*.txt)
MONITOR16RENAMEDFILES := $(wildcard $(MONITORRENAMEDDIR)/16-18/*/*.txt)
MONITOR19RENAMEDFILES := $(wildcard $(MONITORRENAMEDDIR)/19/*/*.txt)
MONITOR20RENAMEDFILES := $(addprefix $(MONITORRENAMEDDIR)/, $(addsuffix .txt, $(subst $(MONITORSRCDIR)/,,$(subst .xml,,$(wildcard $(MONITORSRCDIR)/20/*/*.xml) $(wildcard $(MONITORSRCDIR)/21/*/*.xml)))))
MONITOR13TEXTFILES := $(addprefix $(MONITORTEXTDIR)/, $(addsuffix .txt, $(subst $(MONITORRENAMEDDIR)/,,$(subst .txt,,$(MONITOR13RENAMEDFILES)))))
MONITOR16TEXTFILES := $(addprefix $(MONITORTEXTDIR)/, $(addsuffix .txt, $(subst $(MONITORRENAMEDDIR)/,,$(subst .txt,,$(MONITOR16RENAMEDFILES)))))
MONITOR19TEXTFILES := $(addprefix $(MONITORTEXTDIR)/, $(addsuffix .txt, $(subst $(MONITORRENAMEDDIR)/,,$(subst .txt,,$(MONITOR19RENAMEDFILES)))))
MONITOR20TEXTFILES := $(addprefix $(MONITORTEXTDIR)/, $(addsuffix .txt, $(subst $(MONITORRENAMEDDIR)/,,$(subst .txt,,$(MONITOR20RENAMEDFILES)))))

# The files from 19th century have bad names and must be copied and renamed first.
# The files from 13th to 18th century seem less bad but we will rename them anyway.
# For the files from 20th and 21st century, we just need to replace .xml with .txt.
.PHONY: monitor13rename
monitor13rename:
	./tools/copy_and_rename.pl --srcdir $(MONITORSRCDIR)/13-15 --tgtdir $(MONITORRENAMEDDIR)/13-15
.PHONY: monitor16rename
monitor16rename:
	./tools/copy_and_rename.pl --srcdir $(MONITORSRCDIR)/16-18 --tgtdir $(MONITORRENAMEDDIR)/16-18
.PHONY: monitor19rename
monitor19rename: # nedávat mezi závislosti, protože obsahuje soubory, které mají v názvu mezeru: $(MONITOR19SRCFILES)
	./tools/copy_and_rename.pl --srcdir $(MONITORSRCDIR)/19 --tgtdir $(MONITORRENAMEDDIR)/19
.PHONY: monitor20rename
monitor20rename: $(MONITOR20RENAMEDFILES)
$(MONITORRENAMEDDIR)/20/%.txt: $(MONITORSRCDIR)/20/%.xml
	mkdir -p $(@D)
	cp $< $@
$(MONITORRENAMEDDIR)/21/%.txt: $(MONITORSRCDIR)/21/%.xml
	mkdir -p $(@D)
	cp $< $@

# Despite having .txt in names, the files from 13th to 19th century contain markup that must be removed.
.PHONY: monitor13text
monitor13text: $(MONITOR13TEXTFILES)
.PHONY: monitor16text
monitor16text: $(MONITOR16TEXTFILES)
.PHONY: monitor19text
monitor19text: $(MONITOR19TEXTFILES)
$(MONITORTEXTDIR)/%.txt: $(MONITORRENAMEDDIR)/%.txt
	mkdir -p $(@D)
	./tools/remove_xml_19.pl $< > $@
.PHONY: monitor20text
monitor20text: $(MONITOR20TEXTFILES)
$(MONITORTEXTDIR)/%.txt: $(MONITORSRCDIR)/%.xml
	mkdir -p $(@D)
	./tools/remove_doc_p_xml.pl $< > $@



#----------------------------------------------------------------------------------------------------------------------
# Parsing the monitor corpus.
# By default, texts from 20th and 21st centuries are parsed by a Modern Czech model (FicTree), texts from 19th century
# are parsed by a model trained on Etalon 19, 16th to 18th century by Etalon 16, and 13th to 15th century by Etalon 13.
# We assume that a parsing service is running on the network at the address given in $(UDPIPESERVICE). For official
# pretrained UD models this could be Lindat, but for our custom models we need to launch the service on our cluster
# (see above how to do it) and then access it from here.
UDPIPESERVICE := http://dll-10gpu2.ufal.hide.ms.mff.cuni.cz:8001
UDPIPECLIENT := python /net/work/people/zeman/udpipe/udpipe2_client.py
MONITORPARSEDDIR := data/monitor_parsed
MONITOR13PARSEDFILES := $(addprefix $(MONITORPARSEDDIR)/, $(addsuffix .conllu, $(subst $(MONITORTEXTDIR)/,,$(subst .txt,,$(MONITOR13TEXTFILES)))))
MONITOR16PARSEDFILES := $(addprefix $(MONITORPARSEDDIR)/, $(addsuffix .conllu, $(subst $(MONITORTEXTDIR)/,,$(subst .txt,,$(MONITOR16TEXTFILES)))))
MONITOR19PARSEDFILES := $(addprefix $(MONITORPARSEDDIR)/, $(addsuffix .conllu, $(subst $(MONITORTEXTDIR)/,,$(subst .txt,,$(MONITOR19TEXTFILES)))))
MONITOR20PARSEDFILES := $(addprefix $(MONITORPARSEDDIR)/, $(addsuffix .conllu, $(subst $(MONITORTEXTDIR)/,,$(subst .txt,,$(MONITOR20TEXTFILES)))))
MONITORHEADERDIR := data/monitor_parsed_with_header
MONITOR_WITH_HEADER := $(addprefix $(MONITORHEADERDIR)/, $(subst $(MONITORPARSEDDIR)/,,$(MONITOR13PARSEDFILES) $(MONITOR16PARSEDFILES) $(MONITOR19PARSEDFILES) $(MONITOR20PARSEDFILES)))
.PHONY: clean_monitor13parsed
clean_monitor13parsed:
	rm -rf $(MONITORPARSEDDIR)/13-15/*
.PHONY: clean_monitor16parsed
clean_monitor16parsed:
	rm -rf $(MONITORPARSEDDIR)/16-18/*
.PHONY: clean_monitor19parsed
clean_monitor19parsed:
	rm -rf $(MONITORPARSEDDIR)/19/*
.PHONY: clean_monitor20parsed
clean_monitor20parsed:
	rm -rf $(MONITORPARSEDDIR)/{20,21}/*
.PHONY: monitor13parsed
monitor13parsed: $(MONITOR13PARSEDFILES)
$(MONITORPARSEDDIR)/13-15/%.conllu: $(MONITORTEXTDIR)/13-15/%.txt
	mkdir -p $(@D)
	$(UDPIPECLIENT) --service $(UDPIPESERVICE) --model e13 --tokenizer='' --tagger='' --parser='' < $< > $@
.PHONY: monitor16parsed
monitor16parsed: $(MONITOR16PARSEDFILES)
$(MONITORPARSEDDIR)/16-18/%.conllu: $(MONITORTEXTDIR)/16-18/%.txt
	mkdir -p $(@D)
	$(UDPIPECLIENT) --service $(UDPIPESERVICE) --model e16 --tokenizer='' --tagger='' --parser='' < $< > $@
.PHONY: monitor19parsed
monitor19parsed: $(MONITOR19PARSEDFILES)
$(MONITORPARSEDDIR)/19/%.conllu: $(MONITORTEXTDIR)/19/%.txt
	mkdir -p $(@D)
	$(UDPIPECLIENT) --service $(UDPIPESERVICE) --model e19 --tokenizer='' --tagger='' --parser='' < $< > $@
.PHONY: monitor20parsed
monitor20parsed: $(MONITOR20PARSEDFILES)
$(MONITORPARSEDDIR)/20/%.conllu: $(MONITORTEXTDIR)/20/%.txt
	mkdir -p $(@D)
	$(UDPIPECLIENT) --service $(UDPIPESERVICE) --model fictree --tokenizer='' --tagger='' --parser='' < $< > $@
$(MONITORPARSEDDIR)/21/%.conllu: $(MONITORTEXTDIR)/21/%.txt
	mkdir -p $(@D)
	$(UDPIPECLIENT) --service $(UDPIPESERVICE) --model fictree --tokenizer='' --tagger='' --parser='' < $< > $@
.PHONY: testmonitor
testmonitor: $(MONITOR_WITH_HEADER)
$(MONITORHEADERDIR)/%.conllu: $(MONITORTEXTDIR)/%.txt
	mkdir -p $(@D)
	perl tools/copy_doc_header_to_conllu.pl $< $(MONITORPARSEDDIR)/$*.conllu



#######################################################################################################################
###!!! Ty cíle z Makefilu níže možná prostě vyhodím, ale za úvahu stojí ta ruční anotace, kterou jsem tehdy dělal já, Jirka Pergler a Pavel Kosek.
###!!! Sice jsme ještě neměli ustálená pravidla jako v Hičkoku, ale zase to byly texty, které se pak v Hičkoku nedělaly (prvních 5 kapitol Matoušova evangelia z Bible drážďanské).
# Archiv cílů z projektu Matouš 2021

amblist:
	cat 08-bibl_dr_ol_mt-morfixed.conllu | udapy util.Eval node='if re.match(r"^(PRON|DET)$$", node.upos): print(node.upos, node.feats["PronType"], node.lemma, node.feats["Poss"], node.feats["Reflex"], node.feats["Number"], node.feats["Person"], node.feats["Gender"], node.feats["Case"], node.form.lower())' | sort | uniq -c > zajmena.txt
	cat 08-bibl_dr_ol_mt-morfixed.conllu | udapy util.Eval node='lemma = node.lemma; lemma += "/"+node.misc["Lemma1300"] if node.misc["Lemma1300"] != "" else ""; print(f"{node.form.lower()}\t{node.upos} {node.feats} {lemma}")' | perl -CDS -pe 'while(<>) { chomp; @f=split(/\t/); $$cw{$$f[0]}++; $$ca{$$f[0]}{$$f[1]}++ } @w=sort {$$r=$$cw{$$b}<=>$$cw{$$a}; unless($$r){$$r=$$a cmp $$b}; $$r} (keys(%cw)); foreach $$w (@w) { print("$$w\t$$cw{$$w}\n"); @u=sort {$$r=$$ca{$$w}{$$b}<=>$$ca{$$w}{$$a}; unless($$r){$$r=$$a cmp $$b}; $$r} (keys(%{$$ca{$$w}})); foreach $$u (@u) { print("\t$$u\t$$ca{$$w}{$$u}\n") } }' > amblist.txt
	conllu-stats.pl 08-bibl_dr_ol_mt-morfixed.conllu > stats.xml

# Check allowed and required features. This is how we run Udapi in Windows (udapy.bat will take care
# of setting PYTHONPATH and calling python with the right copy of the udapy script; however, we
# cannot use STDIN and STDOUT redirection because it would trigger UTF-8 encoding errors; also note
# the swapped single and double quotes as compared to the Linux command below):

# udapy read.Conllu files=bibl_dr_ol_mt-manual-zeman.conllu ud.cs.MarkFeatsBugs util.Eval node="if node.misc['Bug']: node.feats['Bug'] = node.misc['Bug']" write.TextModeTreesHtml mark=Bug marked_only=True attributes=form,lemma,upos,feats files=bugs.html
check_features:
	udapy read.Conllu files=bibl_dr_ol_mt-manual-zeman.conllu ud.cs.MarkFeatsBugs util.Eval node='if node.misc["Bug"]: node.feats["Bug"] = node.misc["Bug"]' write.TextModeTreesHtml mark=Bug marked_only=True attributes=form,lemma,upos,feats files=bugs.html

# Initially we annotate the first 5 chapters of MATT in Bible drážďanská. This part will be used
# to evaluate the parser and to compute inter-annotator agreement.
test_data:
	conllu_cut.pl --last 161 < 02-bibl_dr_mt-processed-udpipe-pdt26.conllu | conllu-quick-fix.pl > test-udpipe.conllu
	conllu_cut.pl --last 161 < 03-bibl_dr_mt-parsed.conllu | conllu-quick-fix.pl > test-parsed.conllu
	conllu_cut.pl --last bibldrazd-mt-kapitola-5-vers-48 < 08-bibl_dr_ol_mt-morfixed.conllu | conllu-quick-fix.pl > test-morfixed.conllu
	conllu_cut.pl --last bibldrazd-mt-kapitola-5-vers-48 < bibl_dr_ol_mt-manual-zeman.conllu > test-manual-zeman.conllu
	eval.py -v test-manual-zeman.conllu test-udpipe.conllu
	eval.py -v test-manual-zeman.conllu test-parsed.conllu
	eval.py -v test-manual-zeman.conllu test-morfixed.conllu
	# Inter-annotator agreement chapter 3, Kosek vs. Zeman.
	conllu_cut.pl --first 35 --last bibldrazd-mt-kapitola-3-vers-17 < bibl_dr_ol_mt-manual-zeman.conllu > kapitola3-zeman.conllu
	conllu_cut.pl --first 35 --last bibldrazd-mt-kapitola-3-vers-17 < bibl_dr_ol_mt-manual-kosek.conllu > kapitola3-kosek.conllu
	eval.py -v kapitola3-zeman.conllu kapitola3-kosek.conllu
	# Use chapters 1 to 4 for training, 5 for testing.
	conllu_cut.pl --last bibldrazd-mt-kapitola-4-vers-25 < bibl_dr_ol_mt-manual-zeman.conllu > train-1-4-manual-zeman.conllu
	conllu_cut.pl --first 79 --last bibldrazd-mt-kapitola-5-vers-48 < bibl_dr_ol_mt-manual-zeman.conllu > test-5-manual-zeman.conllu
	udpipe --tag --parse /home/zeman/nastroje/udpipe/udpipe-models/models/czech-pdt-ud-2.5-191206.udpipe < test-5-manual-zeman.conllu > kap-1-5-parsed/bibl_dr_mt_5-reprocessed-udpipe12-pdt25.conllu
	eval.py -v test-5-manual-zeman.conllu kap-1-5-parsed/bibl_dr_mt_5-reprocessed-udpipe12-pdt25.conllu
	udpipe --train model-1-4.udpipe --tokenizer=none train-1-4-manual-zeman.conllu
	udpipe --tag --parse model-1-4.udpipe < test-5-manual-zeman.conllu > kap-1-5-parsed/bibl_dr_mt_5-reprocessed-udpipe12-bdmt14.conllu
	eval.py -v test-5-manual-zeman.conllu kap-1-5-parsed/bibl_dr_mt_5-reprocessed-udpipe12-bdmt14.conllu
	udpipe --train model-fictree210-bdmt14.udpipe --tokenizer=none cs_fictree-ud-train.conllu train-1-4-manual-zeman.conllu


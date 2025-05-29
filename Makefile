SHELL=/bin/bash
UDPIPE=$(PARSINGROOT)/udpipe-parser/scripts/parse.pl

# Define the folders for each step.
#VERTDIR   := data/vert_full
VERTDIR   := data/vert_etalon
CONLLUDIR := data/conllu
TEXTDIR   := data/text
PARSEDDIR := data/parsed
MERGEDDIR := data/merged
PREPRCDIR := data/preprocessed
FORANNDIR := data/for_annotation

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
# STOL=14 ANNBASE=002_modl_kunh      A1=AM A2=JZ make postprocess
# STOL=14 ANNBASE=004_zalt_u         A1=JP A2=ON make postprocess
# STOL=14 ANNBASE=005_umuc_rajhr     A1=AM A2=JZ make postprocess
# STOL=14 ANNBASE=008_hrad_sat       A1=JP A2=ON make postprocess
# STOL=14 ANNBASE=002_modl_kunh      make postprocess_def
# STOL=14 ANNBASE=004_zalt_u         make postprocess_def
# STOL=14 ANNBASE=005_umuc_rajhr     make postprocess_def
# STOL=14 ANNBASE=008_hrad_sat       make postprocess_def
# STOL=14 ANNBASE=003_alx_h          A1=AM A2=JP make postprocess
# STOL=14 ANNBASE=011_alx_bm         A1=JZ A2=ON make postprocess
# STOL=14 ANNBASE=019_rada_otc_r     A1=JP A2=JZ make postprocess
# STOL=15 ANNBASE=021_podk_u         A1=AM A2=ON make postprocess
# STOL=15 ANNBASE=028_hus_kor_d_35   A1=AM A2=JZ make postprocess
# STOL=15 ANNBASE=037_bibl_kladr_1rg A1=JP A2=ON make postprocess
# STOL=14 ANNBASE=003_alx_h          make postprocess_def
# STOL=14 ANNBASE=011_alx_bm         make postprocess_def
# STOL=14 ANNBASE=019_rada_otc_r     make postprocess_def
# STOL=15 ANNBASE=021_podk_u         make postprocess_def
# STOL=15 ANNBASE=028_hus_kor_d_35   make postprocess_def
# STOL=15 ANNBASE=037_bibl_kladr_1rg make postprocess_def
# STOL=15 ANNBASE=026_otc_b          A1=AM A2=ON make postprocess
# STOL=15 ANNBASE=032_mart_kron_a    A1=JP A2=JZ make postprocess
# STOL=14 ANNBASE=001_prip_jir       A1=AM A2=JP make postprocess
# STOL=15 ANNBASE=032_mart_kron_a    make postprocess_def
# STOL=14 ANNBASE=001_prip_jir       make postprocess_def
# STOL=15 ANNBASE=026_otc_b          make postprocess_def
# STOL=14 ANNBASE=006_hrad_prok      A1=JP A2=ON make postprocess
# STOL=14 ANNBASE=007_hrad_magd      A1=JP A2=AM make postprocess
# STOL=14 ANNBASE=009_bibl_drazd_mc  A1=JP A2=ON make postprocess
# STOL=14 ANNBASE=010_bibl_drazd_mt  A1=AM A2=JZ make postprocess
# STOL=14 ANNBASE=012_mast_muz       A1=AM A2=JZ make postprocess
# STOL=14 ANNBASE=013_zalt_wittb     A1=AM A2=JZ make postprocess
# STOL=14 ANNBASE=014_stit_klem      A1=AM A2=ON make postprocess
# STOL=14 ANNBASE=015_krist_a        A1=JZ A2=ON make postprocess
# STOL=14 ANNBASE=007_hrad_magd      make postprocess_def
# STOL=14 ANNBASE=009_bibl_drazd_mc  make postprocess_def
# STOL=14 ANNBASE=010_bibl_drazd_mt  make postprocess_def
# STOL=14 ANNBASE=012_mast_muz       make postprocess_def
# STOL=14 ANNBASE=013_zalt_wittb     make postprocess_def
# STOL=14 ANNBASE=016_rad_kor_a      A1=JP A2=ON make postprocess
# STOL=14 ANNBASE=017_pas_muz_a      A1=JP A2=JZ make postprocess
# STOL=14 ANNBASE=018_dal_v          A1=JP A2=ON make postprocess
# STOL=14 ANNBASE=020_prisl_flas     A1=AM A2=ON make postprocess
DEFFILES14 := 001_prip_jir 002_modl_kunh 003_alx_h 004_zalt_u 005_umuc_rajhr 008_hrad_sat 011_alx_bm 019_rada_otc_r
DEFFILES15 := 021_podk_u 026_otc_b 028_hus_kor_d_35 032_mart_kron_a 037_bibl_kladr_1rg

# Install Udapi (python) and make sure it is in PATH.
# Udapi resides in https://github.com/udapi/udapi-python
# The UD validation script should be in PATH (and python3 available).
# The script resides in https://github.com/UniversalDependencies/tools
# The annotated files may not be valid because syntactic annotation has been ignored.
UDAPISCEN = \
    util.JoinSentence misc_name=JoinSentence \
    util.SplitSentence misc_name=SplitSentence \
    ud.JoinToken misc_name=JoinToken \
    ud.cs.AddMwt \
    ud.FixRoot \
    ud.FixAdvmodByUpos \
    ud.FixMultiSubjects \
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
	set -o pipefail ; perl ./tools/process_annotated_csv.pl --orig data/for_annotation/$(STOL)_stol/$(ANNBASE).tsv --name1 $(A1) --ann1 data/annotated/$(STOL)_stol/$(ANNBASE)_$(A1).csv --name2 $(A2) --ann2 data/annotated/$(STOL)_stol/$(ANNBASE)_$(A2).csv 2>&1 >data/annotated/$(STOL)_stol/$(ANNBASE)_$(A1)_$(A2).diff.txt | tee data/annotated/$(STOL)_stol/$(ANNBASE)_$(A1)_$(A2).postprocess.log
	udapy read.Conllu files=data/annotated/$(STOL)_stol/$(ANNBASE)_$(A1).conllu $(UDAPISCEN) write.Conllu files=data/annotated/$(STOL)_stol/$(ANNBASE)_$(A1).fixed.conllu
	udapy read.Conllu files=data/annotated/$(STOL)_stol/$(ANNBASE)_$(A2).conllu $(UDAPISCEN) write.Conllu files=data/annotated/$(STOL)_stol/$(ANNBASE)_$(A2).fixed.conllu
	mv data/annotated/$(STOL)_stol/$(ANNBASE)_$(A1).fixed.conllu data/annotated/$(STOL)_stol/$(ANNBASE)_$(A1).conllu
	mv data/annotated/$(STOL)_stol/$(ANNBASE)_$(A2).fixed.conllu data/annotated/$(STOL)_stol/$(ANNBASE)_$(A2).conllu
	udapy read.Conllu files=data/annotated/$(STOL)_stol/$(ANNBASE)_$(A1).conllu util.Eval node='node.misc["AmbLemma"] = ""; node.misc["AmbHlemma"] = ""; node.misc["AmbPrgTag"] = ""; node.misc["AmbBrnTag"] = ""; node.misc["AmbHlemmaPrgTag"] = ""; node.misc["AmbHlemmaBrnTag"] = ""; node.misc["InflClass"] = ""; node.misc["Lemma1300"] = ""; node.misc["Verse"] = ""' ud.cs.MarkFeatsBugs util.MarkMwtBugsAtNodes write.TextModeTreesHtml files=data/annotated/$(STOL)_stol/$(ANNBASE)_$(A1).bugs.html marked_only=1 layout=compact attributes=form,lemma,upos,xpos,feats,deprel,misc
	udapy read.Conllu files=data/annotated/$(STOL)_stol/$(ANNBASE)_$(A2).conllu util.Eval node='node.misc["AmbLemma"] = ""; node.misc["AmbHlemma"] = ""; node.misc["AmbPrgTag"] = ""; node.misc["AmbBrnTag"] = ""; node.misc["AmbHlemmaPrgTag"] = ""; node.misc["AmbHlemmaBrnTag"] = ""; node.misc["InflClass"] = ""; node.misc["Lemma1300"] = ""; node.misc["Verse"] = ""' ud.cs.MarkFeatsBugs util.MarkMwtBugsAtNodes write.TextModeTreesHtml files=data/annotated/$(STOL)_stol/$(ANNBASE)_$(A2).bugs.html marked_only=1 layout=compact attributes=form,lemma,upos,xpos,feats,deprel,misc
	validate.py --lang cs data/annotated/$(STOL)_stol/$(ANNBASE)_$(A1).conllu |& tee data/annotated/$(STOL)_stol/$(ANNBASE)_$(A1).validation.log
	validate.py --lang cs data/annotated/$(STOL)_stol/$(ANNBASE)_$(A2).conllu |& tee data/annotated/$(STOL)_stol/$(ANNBASE)_$(A2).validation.log

# Use only a slightly modified postprocessing procedure to process the definitive version (after addressing the differences between the annotators).
# We still use the same script in the beginning, using "DEF" as the identifier of both annotators (the script will read the same file twice).
postprocess_def:
	if [[ -z "$(ANNBASE)" ]] ; then exit 1 ; fi
	set -o pipefail ; perl ./tools/process_annotated_csv.pl --orig data/for_annotation/$(STOL)_stol/$(ANNBASE).tsv --name1 DEF --ann1 data/annotated/$(STOL)_stol/$(ANNBASE)_DEF.csv 2>&1 | tee data/annotated/$(STOL)_stol/$(ANNBASE)_DEF.postprocess.log
	udapy read.Conllu files=data/annotated/$(STOL)_stol/$(ANNBASE)_DEF.conllu $(UDAPISCEN) write.Conllu files=data/annotated/$(STOL)_stol/$(ANNBASE)_DEF.fixed.conllu
	mv data/annotated/$(STOL)_stol/$(ANNBASE)_DEF.fixed.conllu data/annotated/$(STOL)_stol/$(ANNBASE)_DEF.conllu
	udapy read.Conllu files=data/annotated/$(STOL)_stol/$(ANNBASE)_DEF.conllu util.Eval node='node.misc["AmbLemma"] = ""; node.misc["AmbHlemma"] = ""; node.misc["AmbPrgTag"] = ""; node.misc["AmbBrnTag"] = ""; node.misc["AmbHlemmaPrgTag"] = ""; node.misc["AmbHlemmaBrnTag"] = ""; node.misc["InflClass"] = ""; node.misc["Lemma1300"] = ""; node.misc["Verse"] = ""' ud.cs.MarkFeatsBugs util.MarkMwtBugsAtNodes write.TextModeTreesHtml files=data/annotated/$(STOL)_stol/$(ANNBASE)_DEF.bugs.html marked_only=1 layout=compact attributes=form,lemma,upos,xpos,feats,deprel,misc
	validate.py --lang cs data/annotated/$(STOL)_stol/$(ANNBASE)_DEF.conllu |& tee data/annotated/$(STOL)_stol/$(ANNBASE)_DEF.validation.log

# Evaluate the quality of the parsing and preprocessing on the files for which we now have manual annotation.
# The UD parser evaluation script and conllu_quick_fix.pl should be in PATH.
# The conllu_quick_fix.pl script ensures that fatal syntactic errors, which are not our focus here, will not prevent evaluation.
DEFFILES := $(addprefix data/annotated/14_stol/, $(addsuffix _DEF.conllu, $(DEFFILES14))) $(addprefix data/annotated/15_stol/, $(addsuffix _DEF.conllu, $(DEFFILES15)))
EVALFILES := $(addprefix $(PREPRCDIR)/13_19_stol/, $(addsuffix .conllu, $(DEFFILES14) $(DEFFILES15)))
eval:
	cat $(DEFFILES) | conllu_quick_fix.pl > gold.conllu
	cat $(EVALFILES) | conllu_quick_fix.pl > sys.conllu
	eval.py -v gold.conllu sys.conllu



# Clean rule to remove all generated files.
clean:
	rm -rf $(CONLLUDIR) $(TEXTDIR) $(PARSEDDIR) $(MERGEDDIR) $(PREPRCDIR) $(FORANNDIR)



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


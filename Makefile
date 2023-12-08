SHELL=/bin/bash
UDPIPE=$(PARSINGROOT)/udpipe-parser/scripts/parse.pl

# Define the folders for each step.
VERTDIR   := data/vert_full
CONLLUDIR := data/conllu
TEXTDIR   := data/text
PARSEDDIR := data/parsed
MERGEDDIR := data/merged
PREPRCDIR := data/preprocessed

# Find all source files in the source folder.
VERTFILES   := $(wildcard $(VERTDIR)/*/*.vert)
CONLLUFILES := $(wildcard $(CONLLUDIR)/*/*.conllu)

# Generate the target file names for each step.
TEXTFILES   := $(addprefix $(TEXTDIR)/, $(addsuffix .txt, $(subst $(CONLLUDIR)/,,$(subst .conllu,,$(CONLLUFILES)))))
PARSEDFILES := $(patsubst $(CONLLUDIR)/%, $(PARSEDDIR)/%, $(CONLLUFILES))
MERGEDFILES := $(patsubst $(CONLLUDIR)/%, $(MERGEDDIR)/%, $(CONLLUFILES))
PREPRCFILES := $(patsubst $(CONLLUDIR)/%, $(PREPRCDIR)/%, $(CONLLUFILES))

# If a command ends with ane error, delete its target file because it may be corrupt.
.DELETE_ON_ERROR:

all: conllu preprc
	echo $(VERTFILES) | wc -w

# Phony targets for each step.
# Convert the ÚJČ vertical format to CoNLL-U.
# This is applied to the whole folder and the loop is inside the script because individual files get renamed in the process (CamelCase, diacritics etc.)
.PHONY: conllu
conllu: $(VERTFILES)
	./tools/vert2conllu.pl --srcdir $(VERTDIR) --tgtdir $(CONLLUDIR)
.PHONY: text
text:   $(TEXTFILES)
.PHONY: parsed
parsed: $(PARSEDFILES)
.PHONY: merged
merged: $(MERGEDFILES)
.PHONY: preprc
preprc: $(PREPRCFILES)

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

# Clean rule to remove all generated files.
clean:
	rm -rf $(CONLLUDIR) $(TEXTDIR) $(PARSEDDIR) $(MERGEDDIR) $(PREPRCDIR)



amblist:
	cat 08-bibl_dr_ol_mt-morfixed.conllu | udapy util.Eval node='if re.match(r"^(PRON|DET)$$", node.upos): print(node.upos, node.feats["PronType"], node.lemma, node.feats["Poss"], node.feats["Reflex"], node.feats["Number"], node.feats["Person"], node.feats["Gender"], node.feats["Case"], node.form.lower())' | sort | uniq -c > zajmena.txt
	cat 08-bibl_dr_ol_mt-morfixed.conllu | udapy util.Eval node='lemma = node.lemma; lemma += "/"+node.misc["Lemma1300"] if node.misc["Lemma1300"] != "" else ""; print(f"{node.form.lower()}\t{node.upos} {node.feats} {lemma}")' | perl -CDS -pe 'while(<>) { chomp; @f=split(/\t/); $$cw{$$f[0]}++; $$ca{$$f[0]}{$$f[1]}++ } @w=sort {$$r=$$cw{$$b}<=>$$cw{$$a}; unless($$r){$$r=$$a cmp $$b}; $$r} (keys(%cw)); foreach $$w (@w) { print("$$w\t$$cw{$$w}\n"); @u=sort {$$r=$$ca{$$w}{$$b}<=>$$ca{$$w}{$$a}; unless($$r){$$r=$$a cmp $$b}; $$r} (keys(%{$$ca{$$w}})); foreach $$u (@u) { print("\t$$u\t$$ca{$$w}{$$u}\n") } }' > amblist.txt
	conllu-stats.pl 08-bibl_dr_ol_mt-morfixed.conllu > stats.xml

# Prepare a CSV file that can be opened in a spreadsheet editor such as LibreOffice Calc and manually annotated.
# First pass:
MANMORPHIN=08-bibl_dr_ol_mt-morfixed.conllu
MANMORPHCSV=bibl_dr_ol_mt-manually_checked.csv
MANMORPHXLSX=bibl_dr_ol_mt-manually_checked.xlsx
MANMORPHOUT=bibl_dr_ol_mt-manually_checked-zeman.txt
MANMORPHPOST=bibl_dr_ol_mt-manual-zeman.conllu
pre_manual_annotation:
	generate_table_for_annotation.pl < $(MANMORPHIN) > $(MANMORPHCSV)
	generate_xlsx_for_annotation.pl < $(MANMORPHIN) $(MANMORPHXLSX)

# In the Upper Sorbian project from 2016, the next step would be to open the CSV file in LibreOffice
# and edit it (screenshot in jak_spravne_otevrit_csv.jpg shows the import parameters). During
# annotation, the file would be saved in the LibreOffice native format: *.ods. Inserting or removing
# lines or columns is forbidden, we can only edit certain cells. The final file would be saved
# again in CSV (screenshot in jak_spravne_ulozit_csv.jpg shows the export parameters). Now in the
# Old Czech project, the main change is that we use Microsoft Excel instead of Libre Office.
# Exporting to plain text is different. We have to select Unicode Text, but it is Unicode BOM, not
# UTF-8, and it is also with Windows line breaks, so we subsequently have to open it in Notepad2
# and fix these remaining issues.

# Once we have the table in plain text again, we run a sanity check: Make sure that the annotated
# file has the same number of lines and that all words match those in the input file. If it is OK,
# remove extra columns and compress it back to the CoNLL-U format.
post_manual_annotation:
	sanity_check_after_annotation.pl $(MANMORPHIN) $(MANMORPHOUT) > $(MANMORPHPOST)
	sanity_check_after_annotation.pl $(MANMORPHIN) bibl_dr_ol_mt-manually_checked-kosek-dr_mt_3.txt > bibl_dr_ol_mt-manual-kosek.conllu

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


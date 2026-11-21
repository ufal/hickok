# HIČKOK Models

HIČKOK models cover historical stages of Czech from 13th to 21st centuries. They are distributed
under the [CC BY-NC-SA](https://creativecommons.org/licenses/by-nc-sa/4.0/) license. The models are
based on manually annotated data from the [HIČKOK](https://korpus.cz/hickok) project, combined with
the [FicTree](https://universaldependencies.org/treebanks/cs_fictree/index.html) treebank from
[Universal Dependencies 2.19](http://hdl.handle.net/11234/1-6316). In addition, the models use
[RobeCzech](https://huggingface.co/ufal/robeczech-base).

The models require [UDPiep 2](https://ufal.mff.cuni.cz/udpipe/2).

## Training Data

<table class="table table-condensed table-bordered table-striped">
<thead>
<tr>
<th style="text-align:left">Dataset</th>
<th style="text-align:right">Sentences</th>
<th style="text-align:right">Words</th>
<th style="text-align:left">Description</th>
</tr>
</thead>
<tbody>
<tr>
<td style="text-align:left"><a href="https://korpus.cz/hickok">HIČKOK e13</a></td>
<td style="text-align:right">5,712</td>
<td style="text-align:right">105,444</td>
<td style="text-align:right">Old Czech (13th to 15th century)</td>
</tr>
<tr>
<td style="text-align:left"><a href="https://korpus.cz/hickok">HIČKOK e16</a></td>
<td style="text-align:right">4,967</td>
<td style="text-align:right">103,829</td>
<td style="text-align:right">Middle Czech (16th to 18th century)</td>
</tr>
<tr>
<td style="text-align:left"><a href="https://korpus.cz/hickok">HIČKOK e19</a></td>
<td style="text-align:right">5,546</td>
<td style="text-align:right">110,929</td>
<td style="text-align:right">19th century</td>
</tr>
<tr>
<td style="text-align:left"><a href="http://hdl.handle.net/11234/1-6316">UD 2.19 Czech FicTree</a></td>
<td style="text-align:right">10,160</td>
<td style="text-align:right">133,637</td>
<td style="text-align:right">Czech fiction published between 1991 and 2007</td>
</tr>
</tbody>
</table>

All training datasets have manual annotation of morphology (lemma, UPOS, morphological features).
FicTree has also manual annotation of syntactic dependency relations. In the three HIČKOK datasets,
only a small sample has manual syntactic annotation. In the rest, syntax was predicted by a model
trained on the manually annotated data.

<!--
Number of sentences with manually annotated syntax:
| Dataset | Train | Dev | Test |
| e13 | 109 | 6 | 0 |
| e16 |  71 | 4 | 7 |
| e19 |  85 | 0 | 0 |
-->

## Download

The latest version YYYYMMDD of the HIČKOK models can be downloaded from the [LINDAT/CLARIAH-CZ
repository](https://hdl.handle.net/11234/1-NNNN). ###!!! TBA

The models are also available in the [REST service](https://lindat.mff.cuni.cz/services/udpipe/).

## Acknowledgements

This work was supported by the grant no. TQ01000072 of the Technology Agency of the Czech Republic
(TAČR), Programme Sigma, and has been using language resources stored and distributed by the
LINDAT/CLARIAH-CZ project of the Ministry of Education, Youth and Sports of the Czech Republic
(project LM2023062).

The models were trained on HIČKOK etalons and on [UD_Czech-FicTree
v2.19](https://universaldependencies.org/treebanks/cs_fictree/index.html).

Finally, [RobeCzech](https://huggingface.co/ufal/robeczech-base) is used to provide contextualized
word embeddings.

## Model Performance

###!!! (and can we provide evaluation both on raw text and on gold standard tokenization+segmentation?)
###!!! At present, the scores are on gold standard tokenization.

<table class="table table-condensed table-bordered table-striped">
<thead>
<tr>
<th style="text-align:left">Model</th>
<th style="text-align:left">Dataset</th>
<th style="text-align:right">Lemma</th>
<th style="text-align:right">UPOS</th>
<th style="text-align:right">UFeats</th>
</tr>
</thead>
<tbody>
<tr>
<td style="text-align:left"><span id="czech-hickok-e13-20261120">czech-hickok-e13-20261120</span></td>
<td style="text-align:left">test e13</td>
<td style="text-align:right">96.13</td>
<td style="text-align:right">97.99</td>
<td style="text-align:right">93.93</td>
</tr>
<tr>
<td style="text-align:left"><span id="czech-hickok-e16-20261120">czech-hickok-e16-20261120</span></td>
<td style="text-align:left">test e16</td>
<td style="text-align:right">96.67</td>
<td style="text-align:right">98.85</td>
<td style="text-align:right">95.33</td>
</tr>
<tr>
<td style="text-align:left"><span id="czech-hickok-e19-20261120">czech-hickok-e19-20261120</span></td>
<td style="text-align:left">test e19</td>
<td style="text-align:right">97.96</td>
<td style="text-align:right">98.85</td>
<td style="text-align:right">96.67</td>
</tr>
<tr>
<td style="text-align:left"><span id="czech-hickok-e19-20261120">czech-hickok-e19-20261120</span></td>
<td style="text-align:left">test fictree</td>
<td style="text-align:right">99.25</td>
<td style="text-align:right">99.24</td>
<td style="text-align:right">97.67</td>
</tr>
</tbody>
</table>

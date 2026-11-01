#!/usr/bin/env python3
"""Add the VerbForm feature to Czech deverbative nouns in a CoNLL-U file, based on a lemma list.

List format (one entry per line, whitespace-separated):
    <frequency> <lemma> <VerbForm>
e.g.
      2 dávání Vnoun
      5 dávkování Vnoun
      2 dědění Vnoun

This script was cloned from add_aspect.py and it can survive several entries
for the same lemma and different VerbForm values, but that should never happen
for verbal nouns. Note that the script is not suitable for other verb forms
because it decides based on lemma, not on form.

Usage:
    python add_verbform.py --list verbforms.txt -i in.conllu -o out.conllu
    python add_verbform.py --list verbforms.txt < in.conllu > out.conllu
    python add_verbform.py --list verbforms.txt --upos NOUN,VERB -i in.conllu -o out.conllu

It can also be used as a udapi block:
    udapy read.Conllu files=in.conllu add_aspect.AddVerbForm list_file=verbforms.txt write.Conllu
(with the directory of this file on PYTHONPATH).

In a UD treebank folder:
    for i in *.conllu ; do echo $i ; cp $i backup.conllu ; python /net/work/people/zeman/hickok/tools/add_verbform.py --list /net/work/people/zeman/hickok/tools/verbforms.txt --show-unknown < backup.conllu > $i ; rm -f backup.conllu ; done
"""
import argparse
import sys
from collections import defaultdict

from udapi.core.block import Block
from udapi.core.document import Document


def load_list(path):
    """Return {lemma: verbform}, resolving conflicts by highest total frequency."""
    freqs = defaultdict(lambda: defaultdict(int))  # lemma -> verbform -> freq
    order = {}  # (lemma, verbform) -> first line number, for deterministic tie-breaking
    with open(path, encoding='utf-8') as f:
        for lineno, line in enumerate(f, 1):
            fields = line.split()
            if not fields:
                continue
            if len(fields) != 3 or not fields[0].isdigit():
                print(f"{path}:{lineno}: skipping line without frequency/lemma/verbform: "
                      f"{line.rstrip()!r}", file=sys.stderr)
                continue
            freq, lemma, verbform = int(fields[0]), fields[1], fields[2]
            freqs[lemma][verbform] += freq
            order.setdefault((lemma, verbform), lineno)

    result = {}
    for lemma, by_verbform in freqs.items():
        if len(by_verbform) == 1:
            result[lemma] = next(iter(by_verbform))
            continue
        ranked = sorted(by_verbform.items(), key=lambda kv: (-kv[1], order[(lemma, kv[0])]))
        if ranked[0][1] == ranked[1][1]:
            print(f"Warning: tie for lemma '{lemma}' ({dict(by_verbform)}); "
                  f"using first listed: {ranked[0][0]}", file=sys.stderr)
        result[lemma] = ranked[0][0]
    return result


class AddVerbForm(Block):
    """Add VerbForm to nodes of the given UPOS that lack it, if their lemma is in the list."""

    def __init__(self, list_file, upos='NOUN', **kwargs):
        super().__init__(**kwargs)
        self.verbforms = load_list(list_file)
        self.upos = set(upos.split(','))
        self.added = 0
        self.unknown = defaultdict(int)

    def process_node(self, node):
        if node.upos not in self.upos or node.feats['VerbForm']:
            return
        verbform = self.verbforms.get(node.lemma)
        if verbform is None:
            self.unknown[node.lemma] += 1
            return
        node.feats['VerbForm'] = verbform
        self.added += 1

    def process_end(self):
        print(f"VerbForm added to {self.added} nodes; "
              f"{sum(self.unknown.values())} nodes with {len(self.unknown)} lemmas "
              f"not found in the list.", file=sys.stderr)


def main():
    parser = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    parser.add_argument('--list', required=True, help='file with "freq lemma VerbForm" lines')
    parser.add_argument('-i', '--input', default='-', help='input CoNLL-U (default: stdin)')
    parser.add_argument('-o', '--output', default='-', help='output CoNLL-U (default: stdout)')
    parser.add_argument('--upos', default='NOUN',
                        help='comma-separated UPOS tags to process (default: NOUN)')
    parser.add_argument('--show-unknown', action='store_true',
                        help='print lemmas missing from the list (stderr)')
    args = parser.parse_args()

    block = AddVerbForm(list_file=args.list, upos=args.upos)
    doc = Document()
    from udapi.block.read.conllu import Conllu as Reader
    from udapi.block.write.conllu import Conllu as Writer
    Reader(files=args.input).process_document(doc)
    block.process_document(doc)
    block.process_end()
    writer = Writer(files=args.output)
    # Outside a Udapi block pipeline, the before and after hooks are not called
    # automatically. They take care of opening the output file handle.
    writer.before_process_document(doc)
    writer.process_document(doc)
    writer.after_process_document(doc)
    if args.show_unknown:
        for lemma, n in sorted(block.unknown.items(), key=lambda kv: -kv[1]):
            print(f"{n}\t{lemma}", file=sys.stderr)


if __name__ == '__main__':
    main()

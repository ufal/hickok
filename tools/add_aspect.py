#!/usr/bin/env python3
"""Add the Aspect feature to Czech verbs in a CoNLL-U file, based on a lemma list.

List format (one entry per line, whitespace-separated):
    <frequency> <lemma> <Aspect>
e.g.
    2511 dát Perf
     176 dít Imp
       2 dít Imp,Perf

If a lemma has several entries with different Aspect values, the value with the
highest (summed) frequency wins. Existing Aspect values are never overwritten.

Usage:
    python add_aspect.py --list aspects.txt -i in.conllu -o out.conllu
    python add_aspect.py --list aspects.txt < in.conllu > out.conllu
    python add_aspect.py --list aspects.txt --upos VERB,AUX -i in.conllu -o out.conllu

It can also be used as a udapi block:
    udapy read.Conllu files=in.conllu add_aspect.AddAspect list_file=aspects.txt write.Conllu
(with the directory of this file on PYTHONPATH).

In a UD treebank folder:
    for i in *.conllu ; do echo $i ; cp $i backup.conllu ; python /net/work/people/zeman/hickok/tools/add_aspect.py --list /net/work/people/zeman/hickok/tools/aspects.txt --show-unknown < backup.conllu > $i ; rm -f backup.conllu ; done
"""
import argparse
import sys
from collections import defaultdict

from udapi.core.block import Block
from udapi.core.document import Document


def load_aspect_list(path):
    """Return {lemma: aspect}, resolving conflicts by highest total frequency."""
    freqs = defaultdict(lambda: defaultdict(int))  # lemma -> aspect -> freq
    order = {}  # (lemma, aspect) -> first line number, for deterministic tie-breaking
    with open(path, encoding='utf-8') as f:
        for lineno, line in enumerate(f, 1):
            fields = line.split()
            if not fields:
                continue
            if len(fields) != 3 or not fields[0].isdigit():
                print(f"{path}:{lineno}: skipping line without frequency/lemma/aspect: "
                      f"{line.rstrip()!r}", file=sys.stderr)
                continue
            freq, lemma, aspect = int(fields[0]), fields[1], fields[2]
            freqs[lemma][aspect] += freq
            order.setdefault((lemma, aspect), lineno)

    result = {}
    for lemma, by_aspect in freqs.items():
        if len(by_aspect) == 1:
            result[lemma] = next(iter(by_aspect))
            continue
        ranked = sorted(by_aspect.items(), key=lambda kv: (-kv[1], order[(lemma, kv[0])]))
        if ranked[0][1] == ranked[1][1]:
            print(f"Warning: tie for lemma '{lemma}' ({dict(by_aspect)}); "
                  f"using first listed: {ranked[0][0]}", file=sys.stderr)
        result[lemma] = ranked[0][0]
    return result


class AddAspect(Block):
    """Add Aspect to nodes of the given UPOS that lack it, if their lemma is in the list."""

    def __init__(self, list_file, upos='VERB,AUX', **kwargs):
        super().__init__(**kwargs)
        self.aspects = load_aspect_list(list_file)
        self.upos = set(upos.split(','))
        self.added = 0
        self.unknown = defaultdict(int)

    def process_node(self, node):
        if node.upos not in self.upos or node.feats['Aspect']:
            return
        aspect = self.aspects.get(node.lemma)
        if aspect is None:
            self.unknown[node.lemma] += 1
            return
        node.feats['Aspect'] = aspect
        self.added += 1

    def process_end(self):
        print(f"Aspect added to {self.added} nodes; "
              f"{sum(self.unknown.values())} nodes with {len(self.unknown)} lemmas "
              f"not found in the list.", file=sys.stderr)


def main():
    parser = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    parser.add_argument('--list', required=True, help='file with "freq lemma Aspect" lines')
    parser.add_argument('-i', '--input', default='-', help='input CoNLL-U (default: stdin)')
    parser.add_argument('-o', '--output', default='-', help='output CoNLL-U (default: stdout)')
    parser.add_argument('--upos', default='VERB,AUX',
                        help='comma-separated UPOS tags to process (default: VERB,AUX)')
    parser.add_argument('--show-unknown', action='store_true',
                        help='print lemmas missing from the list (stderr)')
    args = parser.parse_args()

    block = AddAspect(list_file=args.list, upos=args.upos)
    doc = Document()
    from udapi.block.read.conllu import Conllu as Reader
    from udapi.block.write.conllu import Conllu as Writer
    Reader(files=args.input).process_document(doc)
    block.process_document(doc)
    Writer(files=args.output).process_document(doc)
    block.process_end()
    if args.show_unknown:
        for lemma, n in sorted(block.unknown.items(), key=lambda kv: -kv[1]):
            print(f"{n}\t{lemma}", file=sys.stderr)


if __name__ == '__main__':
    main()


from pathlib import Path
import re

# ============================================================
# CESTY
# ============================================================

INPUT_DIR = Path(
    r"C:\Users\Martin\Desktop\python\etalon19_MS_pokus"
)

OUTPUT_DIR = Path(
    r"C:\Users\Martin\Desktop\python\etalon19_MS_pokus_vysledek"
)

# Sloupce CoNLL-U:
# 0 = ID, 1 = FORM, 2 = LEMMA, 3 = UPOS,
# 4 = XPOS, 5 = FEATS


# ============================================================
# SPOLEČNÁ DEFINICE PRAVIDEL
# ============================================================

rules = []


def add(
    words,
    upos,
    xpos=None,
    xpos_mode="exact",
    feats=None,
    contains=None,
    changes=None,
    xpos_regex=None,
    xpos_replacement=None,
    prefix_change=None,
    feats_replace=None,
    feats_contains=None,
):
    if len(words) == 1:
        form = None
        lemma = words[0]
    elif len(words) == 2:
        form, lemma = words
    else:
        raise ValueError(
            "Pravidlo musí obsahovat LEMMA, nebo FORM a LEMMA."
        )

    rules.append({
        "form": form,
        "lemma": lemma,
        "upos": upos,
        "xpos": xpos,
        "xpos_mode": xpos_mode,
        "feats": feats,
        "contains": contains,
        "changes": changes or {},
        "xpos_regex": xpos_regex,
        "xpos_replacement": xpos_replacement,
        "prefix_change": prefix_change,
        "feats_replace": feats_replace,
        "feats_contains": feats_contains,
    })


# ============================================================
# 1–2. JEHOŽ, JEHOŽTO
# ============================================================

for lemma in ["jehož", "jehožto"]:
    add(
        [lemma],
        "DET",
        xpos_regex=r"P(.{6})3-------",
        xpos_replacement=r"P\1--------",
        contains="Person=3|Poss=Yes",
        feats_replace=("Person=3|", ""),
    )


# ============================================================
# 3. JÍCH – JEHO
# ============================================================

add(
    ["jích", "jeho"],
    "DET",
    xpos_regex=r"P(.{4})XX3-------",
    xpos_replacement=r"P\1XP3-------",
    contains="Person=3|Poss=Yes",
    feats_replace=(
        "Person=3|Poss=Yes",
        "Person=3|Number[psor]=Plur|Poss=Yes",
    ),
)


# ============================================================
# 4–7. PRON -> DET
# ============================================================

for lemma in [
    "veškerý",
    "jedenkaždý",
    "všeliký",
    "všelikterý",
]:
    add(
        [lemma], "PRON",
        xpos="PL", xpos_mode="prefix",
        changes={3: "DET"},
    )


# ============================================================
# 8–12. ADJEKTIVA A ČÍSLOVKY
# ============================================================

for lemma in ["obojí", "dvojí", "trojí", "obé"]:
    add(
        [lemma], "ADJ",
        xpos="Cd", xpos_mode="prefix",
        prefix_change=("Cd", "Cv"),
    )

add(
    ["jedny"], "ADJ",
    xpos="Cd", xpos_mode="prefix",
    changes={3: "NUM"},
)

add(
    ["jedném", "jedný"], "NUM",
    xpos="Cn", xpos_mode="prefix",
    changes={2: "jeden"},
)


# ============================================================
# 13–15. NĚKOLIKERO, OSMERO, DEVATERO
# ============================================================

add(
    ["několikero"], "NUM",
    xpos="CnNS4----------",
    feats="Case=Acc|Gender=Neut|Number=Sing|NumType=Card",
    changes={
        4: "CdXS4----------",
        5: "Case=Acc|Number=Sing|NumForm=Word|NumType=Sets",
    },
)

for lemma in ["osmero", "devatero"]:
    add(
        [lemma], "NUM",
        xpos="CnXS4----------",
        feats="Case=Acc|Number=Sing|NumType=Card",
        changes={
            4: "CdXS4----------",
            5: "Case=Acc|Number=Sing|NumForm=Word|NumType=Sets",
        },
    )


# ============================================================
# 16. PODRUHÉ
# ============================================================

add(
    ["podruhé"], "ADJ",
    xpos="CrXXX", xpos_mode="prefix",
    changes={3: "ADV"},
)


# ============================================================
# 17–19. TISÍCERÝ
# ============================================================

add(
    ["tisícerý"], "ADJ",
    xpos="CdNS7----------",
    feats="Case=Ins|Gender=Neut|Number=Sing|NumType=Mult",
    changes={
        4: "AANS7----1A----",
        5: "Case=Ins|Degree=Pos|Gender=Neut|Number=Sing|Polarity=Pos",
    },
)

add(
    ["tisícerý"], "ADJ",
    xpos="CdFP1----------",
    feats="Case=Nom|Gender=Fem|Number=Plur|NumType=Mult",
    changes={
        4: "AAFP1----1A----",
        5: "Case=Nom|Degree=Pos|Gender=Fem|Number=Plur|Polarity=Pos",
    },
)

add(
    ["tisícerý"], "ADJ",
    xpos="CdFP2----------",
    feats="Case=Gen|Gender=Fem|Number=Plur|NumType=Mult",
    changes={
        4: "AAFP2----1A----",
        5: "Case=Gen|Degree=Pos|Gender=Fem|Number=Plur|Polarity=Pos",
    },
)


# ============================================================
# 20–22. TŘETINA, PĚTINA, DVANÁCTINA
# ============================================================

for lemma, old_xpos, old_feats, new_xpos, new_feats in [
    (
        "třetina",
        "CyFS4----------",
        "Case=Acc|Gender=Fem|Number=Sing|NumType=Frac",
        "NNFS4----------",
        "Case=Acc|Gender=Fem|Number=Sing",
    ),
    (
        "pětina",
        "CyFP1----------",
        "Case=Nom|Gender=Fem|Number=Plur|NumType=Frac",
        "NNFP1----------",
        "Case=Nom|Gender=Fem|Number=Plur",
    ),
    (
        "dvanáctina",
        "CyFS1----------",
        "Case=Nom|Gender=Fem|Number=Sing|NumType=Frac",
        "NNFS1----------",
        "Case=Nom|Gender=Fem|Number=Sing",
    ),
]:
    add(
        [lemma], "NUM",
        xpos=old_xpos,
        feats=old_feats,
        changes={
            3: "NOUN",
            4: new_xpos,
            5: new_feats,
        },
    )


# ============================================================
# 23–24. ČTVRT
#
# FEATS může obsahovat další atributy.
# Doplníme Gender=Fem a zachováme všechny ostatní atributy.
# ============================================================

add(
    ["čtvrt"], "NUM",
    xpos="CnXS6----------",
    feats_contains="Case=Loc|Number=Sing",
    changes={
        4: "CnFS6----------",
    },
    feats_replace=(
        "Case=Loc|Number=Sing",
        "Case=Loc|Gender=Fem|Number=Sing",
    ),
)

add(
    ["čtvrt"], "NUM",
    xpos="CnXS4----------",
    feats_contains="Case=Acc|Number=Sing",
    changes={
        4: "CnFS4----------",
    },
    feats_replace=(
        "Case=Acc|Number=Sing",
        "Case=Acc|Gender=Fem|Number=Sing",
    ),
)


# ============================================================
# 25–28. PŮL
# ============================================================

for xpos, case in [
    ("CnXS4----------", "Acc"),
    ("CnXS1----------", "Nom"),
    ("CnXS6----------", "Loc"),
    ("CnXS7----------", "Ins"),
]:
    add(
        ["půl"], "NUM",
        xpos=xpos,
        feats=f"Case={case}|Number=Sing|NumForm=Word|NumType=Card",
        changes={
            4: "CnXXX----------",
            5: "NumForm=Word|NumType=Card",
        },
    )


# ============================================================
# 29–33. POKUDŽ, KDOKOLI, KAMŽ, LECCO
# ============================================================

add(
    ["pokudž"], "DET",
    xpos="P4XXX----------",
    feats="PronType=Rel",
    changes={3: "ADV"},
)

add(
    ["kdokoli"], "DET",
    xpos="PZMX1----------",
    feats="Animacy=Anim|Case=Nom|Gender=Masc|PronType=Ind",
    changes={
        4: "PZMS1----------",
        5: "Animacy=Anim|Case=Nom|Gender=Masc|Number=Sing|PronType=Ind",
    },
)

add(
    ["kdokoli"], "DET",
    xpos="PZMX2----------",
    feats="Animacy=Anim|Case=Gen|Gender=Masc|PronType=Ind",
    changes={
        4: "PZMS2----------",
        5: "Animacy=Anim|Case=Gen|Gender=Masc|Number=Sing|PronType=Ind",
    },
)

add(
    ["kamž"], "DET",
    xpos="P4XXX", xpos_mode="prefix",
    changes={3: "ADV"},
)

add(
    ["lecco"], "DET",
    xpos="PZXX1----------",
    feats="Case=Nom|PronType=Ind",
    changes={
        3: "PRON",
        4: "PZ--1----------",
    },
)


# ============================================================
# 34–35. ZŘÍDKAKDO, MÁLOKDO
# ============================================================

for lemma in ["zřídkakdo", "málokdo"]:
    add(
        [lemma], "DET",
        xpos="PZMX1----------",
        feats="Animacy=Anim|Case=Nom|Gender=Masc|PronType=Ind",
        changes={
            3: "PRON",
            4: "PZM-1----------",
        },
    )


# ============================================================
# 36. KAŽDÝ
# ============================================================

add(
    ["každý"], "DET",
    xpos="PWMS3-----N----",
    feats=(
        "Animacy=Anim|Case=Dat|Gender=Masc|Number=Sing|"
        "Polarity=Neg|PronType=Tot"
    ),
    changes={
        4: "PWMS3----------",
        5: "Animacy=Anim|Case=Dat|Gender=Masc|Number=Sing|PronType=Tot",
    },
)


# ============================================================
# 37. BYSME – BÝT
# ============================================================

add(
    ["bysme", "být"], "AUX",
    xpos="Vc--------AAIm-",
    feats=(
        "Aspect=Imp|Mood=Cnd|Number=Plur|Person=1|Polarity=Pos|"
        "VerbForm=Fin|Voice=Act"
    ),
    changes={
        4: "Vc-P---1-------",
        5: "Aspect=Imp|Mood=Cnd|Number=Plur|Person=1|VerbForm=Fin",
    },
)


# ============================================================
# 38–40. ODNĚKUD, NICOŽ, VROUCÍ
# ============================================================

add(
    ["odněkud"], "DET",
    xpos="PZXXX----------",
    feats="PronType=Ind",
    changes={3: "ADV"},
)

add(
    ["nicož"], "DET",
    xpos="PWXX2----------",
    feats="Case=Gen|PronType=Neg",
    changes={
        3: "PRON",
        4: "PY--2----------",
    },
)

add(
    ["vroucí"], "ADJ",
    xpos="AGFS4----3A----",
    feats=(
        "Aspect=Imp|Case=Acc|Degree=Sup|Gender=Fem|Number=Sing|"
        "Polarity=Pos|Tense=Pres|VerbForm=Part|Voice=Act"
    ),
    changes={
        2: "vroucný",
        4: "AAFS4----3A----",
        5: "Case=Acc|Degree=Sup|Gender=Fem|Number=Sing|Polarity=Pos",
    },
)


# ============================================================
# 41–44. VZHLEDEM, BÍLEDNI, DOSMRTI, PŘI
# ============================================================

add(
    ["vzhledem"], "ADP",
    xpos="RF-------------",
    feats="AdpType=Comprep",
    changes={5: "AdpType=Comprep|ExtPos=ADP"},
)

add(
    ["bíledni"], "NOUN",
    xpos="NNXXX----------",
    changes={
        2: "bíledno",
        4: "NNNS6-----A----",
        5: "Case=Loc|Gender=Neut|Number=Sing",
    },
)

add(
    ["dosmrti"], "NOUN",
    xpos="NNXXX----------",
    changes={
        2: "dosmrt",
        4: "NNNS2-----A----",
        5: "Case=Gen|Gender=Fem|Number=Sing",
    },
)

add(
    ["Při", "při"], "NOUN",
    xpos="NNXXX----------",
    changes={
        3: "ADP",
        4: "RR--6----------",
        5: "AdpType=Prep|Case=Loc",
    },
)


# ============================================================
# 45–49. NEJVYŠŠÍ, NIVEC, PRANIC, PŘIČEMŽ
# ============================================================

add(
    ["Nejvyšší"], "PROPN",
    xpos="NNNX2----------",
    feats="Case=Gen|Gender=Neut",
    changes={
        4: "NNMS2----------",
        5: "Animacy=Anim|Case=Gen|Gender=Masc|Number=Sing",
    },
)

add(
    ["nivec"], "DET",
    xpos="PWXX4----------",
    feats="Case=Acc|PronType=Neg",
    changes={
        3: "NOUN",
        4: "NNIS4-----A----",
        5: "Animacy=Inan|Case=Acc|Gender=Masc|Number=Sing",
    },
)

add(
    ["pranic"], "DET",
    xpos="PWXX4----------",
    feats="Case=Acc|PronType=Neg",
    changes={
        3: "PRON",
        4: "PW--4----------",
    },
)

add(
    ["přičemž"], "DET",
    xpos="P4XXX----------",
    feats="PronType=Rel",
    changes={3: "ADV"},
)


# ============================================================
# 50. TÍMŽE – TENŽE
# ============================================================

add(
    ["tímže", "tenže"], "PRON",
    xpos="PLIS7----------",
    feats="Animacy=Inan|Case=Ins|Gender=Masc|Number=Sing|PronType=Tot",
    changes={
        3: "DET",
        4: "PDIS7----------",
        5: "Animacy=Inan|Case=Ins|Gender=Masc|Number=Sing|PronType=Dem",
    },
)


# ============================================================
# 51. PŘEDSEDŮV
# ============================================================

add(
    ["předsedův"], "ADJ",
    xpos="AUNSXM---------",
    feats="Gender=Neut|Gender[psor]=Masc|Number=Sing|Poss=Yes",
    changes={
        4: "AUNS3M---------",
        5: "Case=Dat|Gender=Neut|Gender[psor]=Masc|Number=Sing|Poss=Yes",
    },
)


# ============================================================
# 52. BY – BÝT
# ============================================================

add(
    ["by", "být"], "AUX",
    xpos="Vc--------AAIm-",
    feats=(
        "Aspect=Imp|Mood=Cnd|Number=Plur|Person=1|Polarity=Pos|"
        "VerbForm=Fin|Voice=Act"
    ),
    changes={
        4: "Vc----------I--",
        5: "Aspect=Imp|Mood=Cnd|VerbForm=Fin",
    },
)


# ============================================================
# 53–54. TOLIKERÝ, KOLIKERÝ
# ============================================================

add(
    ["tolikerý"], "ADJ",
    xpos="CdNS6----------",
    feats="Case=Loc|Gender=Neut|Number=Sing|NumType=Mult",
    changes={
        3: "DET",
        4: "PDNS6----------",
        5: "Case=Loc|Gender=Neut|Number=Sing|PronType=Dem",
    },
)

add(
    ["kolikerý"], "ADJ",
    xpos="CdFS7----------",
    feats="Case=Ins|Gender=Fem|Number=Sing|NumType=Mult",
    changes={
        4: "AAFS7----1A----",
        5: "Case=Ins|Degree=Pos|Gender=Fem|Number=Sing|Polarity=Pos",
    },
)


# ============================================================
# KONTROLA, ZDA ŘÁDEK ODPOVÍDÁ PRAVIDLU
# ============================================================

def matches(fields, rule):
    if len(fields) < 6:
        return False

    # FORM kontrolujeme jen tehdy, pokud byl uveden.
    if rule["form"] is not None and fields[1] != rule["form"]:
        return False

    # LEMMA a UPOS
    if fields[2] != rule["lemma"]:
        return False

    if fields[3] != rule["upos"]:
        return False

    # XPOS
    xpos = fields[4]

    if rule["xpos"] is not None:
        if rule["xpos_mode"] == "exact":
            if xpos != rule["xpos"]:
                return False
        elif rule["xpos_mode"] == "prefix":
            if not xpos.startswith(rule["xpos"]):
                return False

    if rule["xpos_regex"] is not None:
        if re.fullmatch(rule["xpos_regex"], xpos) is None:
            return False

    # FEATS: přesná shoda, nebo kontrola podřetězce.
    feats = fields[5]

    if rule["feats"] is not None and feats != rule["feats"]:
        return False

    if rule["contains"] is not None:
        if rule["contains"] not in feats:
            return False

    if rule["feats_contains"] is not None:
        if rule["feats_contains"] not in feats:
            return False

    return True


# ============================================================
# PROVEDENÍ NÁHRADY
# ============================================================

def apply_rule(fields, rule):
    # Nahrazení vybraných sloupců.
    for index, value in rule["changes"].items():
        fields[index] = value

    # Regulární náhrada XPOS včetně zachovaných skupin.
    if (
        rule["xpos_regex"] is not None
        and rule["xpos_replacement"] is not None
    ):
        fields[4] = re.sub(
            rule["xpos_regex"],
            rule["xpos_replacement"],
            fields[4],
        )

    # Změna prefixu XPOS při zachování zbytku značky.
    if rule["prefix_change"] is not None:
        old_prefix, new_prefix = rule["prefix_change"]

        if fields[4].startswith(old_prefix):
            fields[4] = (
                new_prefix + fields[4][len(old_prefix):]
            )

    # Nahrazení části FEATS; ostatní atributy zůstanou zachovány.
    if rule["feats_replace"] is not None:
        old, new = rule["feats_replace"]
        fields[5] = fields[5].replace(old, new, 1)


# ============================================================
# ZPRACOVÁNÍ JEDNOHO ŘÁDKU
# ============================================================

def process_line(line):
    if not line.strip() or line.startswith("#"):
        return line, False

    # Zachování původního konce řádku.
    if line.endswith("\r\n"):
        ending = "\r\n"
        content = line[:-2]
    elif line.endswith("\n") or line.endswith("\r"):
        ending = line[-1]
        content = line[:-1]
    else:
        ending = ""
        content = line

    fields = content.split("\t")

    if len(fields) < 6:
        return line, False

    for rule in rules:
        if matches(fields, rule):
            apply_rule(fields, rule)
            return "\t".join(fields) + ending, True

    return line, False


# ============================================================
# ZPRACOVÁNÍ VŠECH SOUBORŮ .CONLLU
# ============================================================

def main():
    if not INPUT_DIR.exists():
        print(f"Vstupní složka neexistuje: {INPUT_DIR}")
        return

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    total_files = 0
    total_changed_lines = 0

    for input_file in INPUT_DIR.rglob("*.conllu"):
        relative_path = input_file.relative_to(INPUT_DIR)
        output_file = OUTPUT_DIR / relative_path

        output_file.parent.mkdir(parents=True, exist_ok=True)

        with input_file.open(
            "r", encoding="utf-8", newline=""
        ) as source:
            lines = source.readlines()

        output_lines = []
        changed_lines = 0

        for line in lines:
            new_line, changed = process_line(line)
            output_lines.append(new_line)

            if changed:
                changed_lines += 1

        with output_file.open(
            "w", encoding="utf-8", newline=""
        ) as target:
            target.writelines(output_lines)

        total_files += 1
        total_changed_lines += changed_lines

        print(
            f"{relative_path}: "
            f"{changed_lines} změněných řádků"
        )

    print("\nZPRACOVÁNÍ DOKONČENO")
    print(f"Zpracované soubory: {total_files}")
    print(f"Změněné řádky: {total_changed_lines}")
    print(f"Výsledná složka: {OUTPUT_DIR}")


if __name__ == "__main__":
    main()

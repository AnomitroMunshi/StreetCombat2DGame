"""Win-rate tables from a census folder (one <style>.json per measured style).

Usage: python tools/balance/summarize.py <census_dir> [--moves]
Prints Markdown: overall win rate per style, the style x rival matrix, and
(with --moves) where each style's damage comes from.
"""
import glob
import json
import os
import sys

ORDER = ["boxing", "muay_thai", "kung_fu", "bangla_maar", "karate", "taekwondo", "kickboxing", "capoeira", "jeet_kune_do"]
SHORT = {"boxing": "BOX", "muay_thai": "MT", "kung_fu": "KF", "bangla_maar": "BM", "karate": "KAR",
         "taekwondo": "TKD", "kickboxing": "KB", "capoeira": "CAP", "jeet_kune_do": "JKD"}


def load(folder):
    data = {}
    for path in glob.glob(os.path.join(folder, "*.json")):
        d = json.load(open(path))
        data[d["style"]] = d
    return data


def score(rows):
    """Wins count 1, draws and timeouts 0.5."""
    w = sum(1 for r in rows if r["outcome"] == "win")
    h = sum(1 for r in rows if r["outcome"] in ("draw", "timeout"))
    return (w + 0.5 * h) / len(rows) if rows else 0.0


def main():
    folder = sys.argv[1]
    data = load(folder)
    styles = [s for s in ORDER if s in data]
    any_d = next(iter(data.values()))
    print("# Style census\n")
    print("AI: %s; difficulty %s vs %s; %d seeds; %d HP; one round to K.O.\n" % (
        any_d["ai"], any_d["difficulty"][0], any_d["difficulty"][1], len(any_d["seeds"]), any_d["health"]))
    print("| Style | Win rate | W-L-D | Mean time (s) | Mean HP left when winning |")
    print("|---|---:|---:|---:|---:|")
    for s in sorted(styles, key=lambda s: -score(data[s]["rows"])):
        rows = data[s]["rows"]
        w = sum(1 for r in rows if r["outcome"] == "win")
        l = sum(1 for r in rows if r["outcome"] == "loss")
        d = len(rows) - w - l
        wins = [r["health"][0] for r in rows if r["outcome"] == "win"]
        print("| %s | %.0f%% | %d-%d-%d | %.1f | %.0f |" % (s, 100 * score(rows), w, l, d,
              sum(r["ticks"] for r in rows) / len(rows) / 60.0, sum(wins) / len(wins) if wins else 0))
    print("\nRow style's win rate against the column rival:\n")
    print("| | " + " | ".join(SHORT[s] for s in styles) + " |")
    print("|---|" + "---:|" * len(styles))
    for s in styles:
        cells = []
        for r in styles:
            rows = [x for x in data[s]["rows"] if x["rival"] == r]
            cells.append("-" if not rows else "%.0f" % (100 * score(rows)))
        print("| **%s** | " % SHORT[s] + " | ".join(cells) + " |")
    if "--moves" in sys.argv:
        print("\nDamage share by move (measured style):\n")
        for s in styles:
            dmg, starts = {}, {}
            for r in data[s]["rows"]:
                for k, v in r["damage"][0].items():
                    dmg[k] = dmg.get(k, 0) + v
                for k, v in r["starts"][0].items():
                    starts[k] = starts.get(k, 0) + v
            total = sum(dmg.values()) or 1
            top = sorted(dmg.items(), key=lambda kv: -kv[1])[:6]
            print("- **%s**: " % s + ", ".join("%s %.0f%% (%d starts)" % (k, 100 * v / total, starts.get(k, 0)) for k, v in top))


if __name__ == "__main__":
    main()

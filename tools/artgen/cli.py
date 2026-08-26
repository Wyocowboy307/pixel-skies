"""Pixel Skies production art pipeline.

    tools/.venv/bin/python -m artgen.cli status
    tools/.venv/bin/python -m artgen.cli generate [key ...]
    tools/.venv/bin/python -m artgen.cli review
    tools/.venv/bin/python -m artgen.cli approve <key> [key ...]
    tools/.venv/bin/python -m artgen.cli reject <key> [key ...]

Candidates land in .art_candidates/ (gitignored) and only reach
assets/art/production/ by explicit approval. Nothing is imported automatically:
the rejection step is the point.
"""

from __future__ import annotations

import shutil
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(ROOT / "tools"))

from artgen import anchors as anchors_mod, client, review as review_mod  # noqa: E402
from artgen.spec import STARTER, by_key, reference_spec             # noqa: E402

CANDIDATES = ROOT / ".art_candidates"
PRODUCTION = ROOT / "assets" / "art" / "production"
PLACEHOLDER = ROOT / "assets" / "art" / "placeholder"


def _candidate_path(key: str) -> Path:
    return CANDIDATES / f"{key}.png"


def cmd_status() -> int:
    try:
        key_state = "present" if client.read_key() else "missing"
    except client.MissingKey as exc:
        key_state = f"MISSING\n{exc}"
    print(f"PixelLab key: {key_state}\n")
    print(f"{'asset':20} {'state':12} {'candidate':10} destination")
    print("-" * 78)
    for spec in STARTER:
        live = PRODUCTION / spec.logical
        state = "production" if live.exists() else (
            "placeholder" if (PLACEHOLDER / spec.logical).exists() else "MISSING")
        cand = "yes" if _candidate_path(spec.key).exists() else "-"
        mark = " *ref" if spec.is_reference else ""
        print(f"{spec.key:20} {state:12} {cand:10} {spec.logical}{mark}")
    return 0


def cmd_generate(keys: list[str]) -> int:
    specs = [by_key(k) for k in keys] if keys else list(STARTER)
    if any(s is None for s in specs):
        print("unknown asset key; run 'status' for the list")
        return 2
    try:
        client.read_key()
    except client.MissingKey as exc:
        print(exc)
        return 2

    CANDIDATES.mkdir(exist_ok=True)
    # The reference asset defines the look; everything else is style-matched to
    # whatever is already approved for it.
    reference = reference_spec()
    style_source = PRODUCTION / reference.logical
    style_image = None
    if style_source.exists() and reference.key not in keys:
        style_image = Image.open(style_source).convert("RGBA")
        print(f"style-locked to {reference.logical}")
    else:
        print("no approved reference yet — generating unlocked")

    for spec in specs:
        params = spec.params()
        print(f"\n-- {spec.key} {spec.size} {spec.view}")
        try:
            if style_image is not None:
                image, usage = client.generate("generate-image-bitforge", params,
                                               style_image=style_image)
            else:
                params.pop("style_strength", None)
                params.pop("extra_guidance_scale", None)
                image, usage = client.generate("generate-image-pixflux", params)
            path = _candidate_path(spec.key)
            image.save(path)
            findings = review_mod.review(path, spec.size)
            print(f"   saved {path.relative_to(ROOT)}  ->  "
                  f"{review_mod.verdict(findings)}   usage={usage}")
            for f in findings:
                print(f"     {f.level}: {f.message}")
        except Exception as exc:                       # noqa: BLE001 - reported per asset
            print(f"   FAILED: {exc}")
    return 0


def cmd_review() -> int:
    if not CANDIDATES.exists() or not any(CANDIDATES.glob("*.png")):
        print("no candidates; run 'generate' first")
        return 1
    worst = 0
    for spec in STARTER:
        path = _candidate_path(spec.key)
        if not path.exists():
            continue
        findings = review_mod.review(path, spec.size)
        state = review_mod.verdict(findings)
        print(f"{spec.key:20} {state}")
        for f in findings:
            print(f"    {f.level}: {f.message}")
        worst = max(worst, {"PASS": 0, "WARN": 1, "REJECT": 2}[state])
    print("\nCharm is judged in the running game, not here. "
          "Approve, then run ./verify.sh shots plane_gate.")
    return 0 if worst < 2 else 1


def cmd_approve(keys: list[str]) -> int:
    if not keys:
        print("name the assets to approve")
        return 2
    for key in keys:
        spec = by_key(key)
        if spec is None:
            print(f"{key}: unknown")
            continue
        path = _candidate_path(key)
        if not path.exists():
            print(f"{key}: no candidate")
            continue
        findings = review_mod.review(path, spec.size)
        if review_mod.verdict(findings) == "REJECT":
            print(f"{key}: REJECTED by the style gate, not approving")
            for f in findings:
                print(f"    {f.level}: {f.message}")
            continue
        # Snap to the locked palette and harden alpha on the way in, so the
        # shipped asset obeys the style guide exactly.
        image = review_mod.snap_to_palette(Image.open(path))
        target = PRODUCTION / spec.logical
        target.parent.mkdir(parents=True, exist_ok=True)
        image.save(target)
        print(f"{key}: approved -> assets/art/production/{spec.logical}")
        # An aircraft side sprite also needs its seat and cargo anchors, or the
        # plane screen has nowhere to put passengers.
        if spec.logical.endswith("_side.png"):
            import json
            found, notes = anchors_mod.detect(target, seats=4, cargo=3)
            (target.parent / (target.stem + ".json")).write_text(
                json.dumps(found, indent=2) + "\n")
            print(f"    anchors: {len(found['seats'])} seats, {len(found['cargo'])} cargo")
            for note in notes:
                print(f"    note: {note}")
    print("\nRun ./verify.sh to re-check, then review it in the running game.")
    return 0


def cmd_reject(keys: list[str]) -> int:
    for key in keys:
        path = _candidate_path(key)
        if path.exists():
            path.unlink()
            print(f"{key}: candidate discarded")
    return 0


def main(argv: list[str]) -> int:
    if not argv:
        print(__doc__)
        return 1
    command, rest = argv[0], argv[1:]
    return {
        "status": lambda: cmd_status(),
        "generate": lambda: cmd_generate(rest),
        "review": lambda: cmd_review(),
        "approve": lambda: cmd_approve(rest),
        "reject": lambda: cmd_reject(rest),
    }.get(command, lambda: (print(__doc__), 1)[1])()


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))

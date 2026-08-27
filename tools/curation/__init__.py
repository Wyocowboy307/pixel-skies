"""Per-domain curation manifests.

Each module exports MANIFEST: {sheet_rel: [(x, y, w, h, dest), ...]}. Split by
domain so parallel curation passes never edit the same file.
"""

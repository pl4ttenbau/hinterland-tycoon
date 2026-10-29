# Resource PNG icons

27 resource icons, each available as transparent RGBA PNGs in `32/`, `48/`, `64/`, and `128/`.
Names match the resource keys in GoodsTypesLoader. All images larger than 128px,
including original masters and preview sheets, were removed from this folder.
The 128px icons are now the retained source set in manifest.json.

Run `python3 export_sizes.py` with Pillow to rebuild smaller exports from 128px.
The optional build_preview.py creates a large review sheet; none is currently retained.

Created using the built-in image generation tool. Historical prompts remain in
PROMPTS.md, REVISION-PROMPTS.md, and FULL-SET-PROMPTS.md.
No game scripts or UI references were changed.

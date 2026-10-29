"""Rebuild smaller PNG exports from retained 128px icons. Requires Pillow."""
from pathlib import Path
import json
from PIL import Image

ROOT = Path(__file__).resolve().parent

def export():
    manifest = json.loads((ROOT / "manifest.json").read_text())
    for name in manifest["icons"]:
        with Image.open(ROOT / manifest["masters"][name]) as source:
            image = source.convert("RGBA")
            for size in manifest["sizes"]:
                if size >= 128:
                    continue
                folder = ROOT / str(size)
                folder.mkdir(exist_ok=True)
                image.resize((size, size), Image.Resampling.LANCZOS).save(folder / (name + ".png"))

if __name__ == "__main__":
    export()

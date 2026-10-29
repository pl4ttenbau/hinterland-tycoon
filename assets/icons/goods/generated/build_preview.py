"""Build a review sheet from the 32px and 64px raster exports."""
import json
from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parent


def build():
    names = json.loads((ROOT / "manifest.json").read_text())["icons"]
    width, panel_height = 1296, 430
    sheet = Image.new("RGB", (width, panel_height * 2))
    draw = ImageDraw.Draw(sheet)
    for panel, background, foreground in ((0, "#20252d", "#f4f1e9"),
                                           (1, "#eeeae2", "#252830")):
        top = panel * panel_height
        draw.rectangle((0, top, width, top + panel_height), fill=background)
        label = "DARK" if panel == 0 else "LIGHT"
        draw.text((18, top + 14), label + " BACKGROUND | actual 32px + 64px exports",
                  fill=foreground)
        for index, name in enumerate(names):
            x = (index % 9) * 144 + 12
            y = top + 48 + (index // 9) * 126
            draw.text((x, y), name.replace("_", " "), fill=foreground)
            for size, offset in ((32, 0), (64, 48)):
                with Image.open(ROOT / str(size) / (name + ".png")) as icon:
                    sheet.paste(icon, (x + offset, y + 24 + (64 - size) // 2), icon)
                draw.text((x + offset, y + 94), str(size), fill=foreground)
    sheet.save(ROOT / "full-set-preview.png")


if __name__ == "__main__":
    build()

"""Generates the P V O app icon set.

White background (required: iOS icons must be fully opaque, no alpha), the three
letters set in a heavy serif, and a coloured rule beneath each letter.
Run:  python3 tool/branding/make_icon.py
"""
import os
from PIL import Image, ImageDraw, ImageFont

BASE = 1024
BG = (255, 255, 255)
INK = (16, 18, 26)

# Oman flag palette only: red, white, green. The middle rule is the flag's
# white, given a hairline so it stays visible on the white background.
UNDERLINE = [(200, 16, 46), (255, 255, 255), (0, 122, 61)]
UNDERLINE_EDGE = [(200, 16, 46), (221, 225, 230), (0, 122, 61)]

FONT_CANDIDATES = [
    "/usr/share/fonts/truetype/dejavu/DejaVuSerif-Bold.ttf",
    "/usr/share/fonts/truetype/crosextra/Caladea-Bold.ttf",
    "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
]

# name -> pixel size, covering every slot in AppIcon.appiconset
IOS_SIZES = {
    "Icon-App-20x20@1x.png": 20, "Icon-App-20x20@2x.png": 40,
    "Icon-App-20x20@3x.png": 60, "Icon-App-29x29@1x.png": 29,
    "Icon-App-29x29@2x.png": 58, "Icon-App-29x29@3x.png": 87,
    "Icon-App-40x40@1x.png": 40, "Icon-App-40x40@2x.png": 80,
    "Icon-App-40x40@3x.png": 120, "Icon-App-60x60@2x.png": 120,
    "Icon-App-60x60@3x.png": 180, "Icon-App-76x76@1x.png": 76,
    "Icon-App-76x76@2x.png": 152, "Icon-App-83.5x83.5@2x.png": 167,
    "Icon-App-1024x1024@1x.png": 1024,
}


def pick_font(size):
    for path in FONT_CANDIDATES:
        if os.path.exists(path):
            return ImageFont.truetype(path, size)
    raise SystemExit("No usable TTF font found on this machine.")


def render_master():
    img = Image.new("RGB", (BASE, BASE), BG)
    draw = ImageDraw.Draw(img)

    letters = ["P", "V", "O"]
    font = pick_font(300)

    # Measure each glyph so the three columns are evenly distributed.
    widths, heights = [], []
    for ch in letters:
        box = draw.textbbox((0, 0), ch, font=font)
        widths.append(box[2] - box[0])
        heights.append(box[3] - box[1])

    gap = 46
    total = sum(widths) + gap * (len(letters) - 1)
    x = (BASE - total) / 2
    baseline_y = BASE / 2 - max(heights) / 2 - 40

    rule_h = 26
    rule_gap = 52

    for i, ch in enumerate(letters):
        box = draw.textbbox((0, 0), ch, font=font)
        draw.text((x - box[0], baseline_y - box[1]), ch, font=font, fill=INK)

        rule_y = baseline_y + max(heights) + rule_gap
        draw.rounded_rectangle(
            [x, rule_y, x + widths[i], rule_y + rule_h],
            radius=rule_h / 2,
            fill=UNDERLINE[i],
            outline=UNDERLINE_EDGE[i],
            width=3,
        )
        x += widths[i] + gap

    return img


def main():
    out_dir = os.path.join(
        "ios", "Runner", "Assets.xcassets", "AppIcon.appiconset")
    os.makedirs(out_dir, exist_ok=True)

    master = render_master()
    master.save(os.path.join("tool", "branding", "pvo-icon-1024.png"))

    for name, size in IOS_SIZES.items():
        master.resize((size, size), Image.LANCZOS).save(
            os.path.join(out_dir, name))

    print(f"Wrote {len(IOS_SIZES)} icons to {out_dir}")


if __name__ == "__main__":
    main()

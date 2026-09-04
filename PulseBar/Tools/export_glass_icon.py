"""Deterministic export of the user's approved artwork; no generative redraw."""
from collections import deque
from pathlib import Path
import hashlib
import sys

from PIL import Image, ImageFilter


def export(source_path: Path, output_dir: Path) -> None:
    image = Image.open(source_path).convert("RGB")
    if image.size != (1254, 1254):
        raise ValueError("Unexpected approved-reference dimensions")
    digest = hashlib.sha256(source_path.read_bytes()).hexdigest()
    if digest != "d2bc2b54e62889d9e2abcc3a76e9724aea6692ddfe7af8dee896e14f3dfe453b":
        raise ValueError("Approved reference changed; refusing to alter a different image")
    # Excludes both text rows while retaining the entire navy tile and its edges.
    crop = image.crop((190, 65, 1063, 935))
    width, height = crop.size
    pixels = crop.load()
    outside = Image.new("L", crop.size, 0)
    outside_pixels = outside.load()
    queue = deque()

    def add(x: int, y: int) -> None:
        if not (0 <= x < width and 0 <= y < height) or outside_pixels[x, y]:
            return
        red, green, blue = pixels[x, y]
        # Only flood the warm, light presentation background from the perimeter.
        # Interior cyan highlights cannot be reached across the dark navy tile.
        if red + green + blue > 405 and red >= green - 5 and red >= blue - 8:
            outside_pixels[x, y] = 255
            queue.append((x, y))

    for x in range(width):
        add(x, 0)
        add(x, height - 1)
    for y in range(height):
        add(0, y)
        add(width - 1, y)
    while queue:
        x, y = queue.popleft()
        for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
            add(x + dx, y + dy)

    mask = outside.point(lambda value: 255 - value)
    bounds = mask.getbbox()
    if bounds is None or not (790 <= bounds[2] - bounds[0] <= 850):
        raise ValueError(f"Unexpected extracted tile bounds: {bounds}")
    tile = crop.convert("RGBA")
    # Remove the presentation background's antialiased fringe without touching
    # the glass modules; soften only the outer alpha contour by a fraction of a pixel.
    tile.putalpha(mask.filter(ImageFilter.MinFilter(5)).filter(ImageFilter.GaussianBlur(0.45)))
    tile = tile.crop((bounds[0] - 2, bounds[1] - 2, bounds[2] + 2, bounds[3] + 2))
    tile.thumbnail((896, 896), Image.Resampling.LANCZOS)
    # Upscale the approved pixels uniformly; never distort the raised fourth tile.
    scale = 896 / max(tile.size)
    tile = tile.resize(tuple(round(value * scale) for value in tile.size), Image.Resampling.LANCZOS)
    master = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
    master.alpha_composite(tile, ((1024 - tile.width) // 2, (1024 - tile.height) // 2))
    output_dir.mkdir(parents=True, exist_ok=True)
    master.save(output_dir / "PulseBar-Glass-1024.png")
    iconset = output_dir / "PulseBar.iconset"
    iconset.mkdir(exist_ok=True)
    for points in (16, 32, 128, 256, 512):
        for scale in (1, 2):
            pixels_size = points * scale
            suffix = "@2x" if scale == 2 else ""
            master.resize((pixels_size, pixels_size), Image.Resampling.LANCZOS).save(
                iconset / f"icon_{points}x{points}{suffix}.png")
    alpha = master.getchannel("A")
    assert alpha.getextrema() == (0, 255)
    assert master.getpixel((0, 0))[3] == 0
    print(f"source_sha256={digest} tile_bounds={bounds} alpha={alpha.getextrema()}")
    print(output_dir / "PulseBar-Glass-1024.png")


if __name__ == "__main__":
    export(Path(sys.argv[1]), Path(sys.argv[2]))

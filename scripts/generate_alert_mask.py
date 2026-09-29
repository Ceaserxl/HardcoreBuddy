"""Generate a geometric alpha mask with 12px corners at the 896x80 alert size."""
from pathlib import Path
from PIL import Image, ImageDraw

scale = 4
mask = Image.new('RGBA', (896 * scale, 80 * scale), (255, 255, 255, 0))
ImageDraw.Draw(mask).rounded_rectangle(
    (0, 0, 896 * scale - 1, 80 * scale - 1),
    radius=12 * scale, fill=(255, 255, 255, 255))
mask = mask.resize((1024, 128), Image.Resampling.LANCZOS)
mask.save(Path(__file__).resolve().parents[1] / 'Media/Deaths/AlertRoundedMask.tga', compression=None)

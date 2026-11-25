"""Validate and normalize small uploaded images before storing them."""
import base64
import binascii
from io import BytesIO

from PIL import Image, ImageOps, UnidentifiedImageError

MAX_IMAGE_BYTES = 512 * 1024
MAX_IMAGE_BASE64 = 4 * ((MAX_IMAGE_BYTES + 2) // 3)


def normalized_image(value: str) -> str:
    try:
        raw = base64.b64decode(value, validate=True)
        if not 0 < len(raw) <= MAX_IMAGE_BYTES:
            raise ValueError()
        with Image.open(BytesIO(raw), formats=["JPEG", "PNG"]) as image:
            if (
                image.width > 2048
                or image.height > 2048
                or getattr(image, "is_animated", False)
            ):
                raise ValueError()
            oriented = ImageOps.exif_transpose(image)
            oriented.thumbnail((384, 384))
            clean = Image.new("RGB", oriented.size, "white")
            rgba = oriented.convert("RGBA")
            clean.paste(rgba, mask=rgba.getchannel("A"))
            output = BytesIO()
            clean.save(output, format="JPEG", quality=85)
    except (ValueError, binascii.Error, UnidentifiedImageError, OSError,
            SyntaxError, Image.DecompressionBombError):
        raise ValueError("Choose a JPEG or PNG up to 512 KiB and 2048 × 2048 pixels.") from None
    return "data:image/jpeg;base64," + base64.b64encode(output.getvalue()).decode("ascii")

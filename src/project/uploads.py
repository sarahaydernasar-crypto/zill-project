import secrets
from pathlib import Path

from fastapi import HTTPException, UploadFile

UPLOADS_DIR = Path(__file__).resolve().parents[2] / "uploads"
MAX_PHOTO_BYTES = 5 * 1024 * 1024

# نتحقق من محتوى الملف نفسه، لأن امتداده ونوعه المرسل يمكن تزويرهما
_SIGNATURES = {b"\xff\xd8\xff": ".jpg", b"\x89PNG\r\n\x1a\n": ".png"}


def _extension(content: bytes) -> str | None:
    for signature, extension in _SIGNATURES.items():
        if content.startswith(signature):
            return extension
    if content[:4] == b"RIFF" and content[8:12] == b"WEBP":
        return ".webp"
    return None


async def save_photo(photo: UploadFile) -> str:
    """يحفظ الصورة باسم عشوائي ويعيد رابطها النسبي."""
    content = await photo.read(MAX_PHOTO_BYTES + 1)
    if len(content) > MAX_PHOTO_BYTES:
        raise HTTPException(status_code=413, detail="حجم الصورة أكبر من 5 ميغابايت")
    extension = _extension(content)
    if extension is None:
        raise HTTPException(status_code=415, detail="يجب أن تكون الصورة بصيغة JPG أو PNG أو WEBP")
    UPLOADS_DIR.mkdir(exist_ok=True)
    name = secrets.token_urlsafe(16) + extension
    (UPLOADS_DIR / name).write_bytes(content)
    return f"/uploads/{name}"

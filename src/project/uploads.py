import secrets

from fastapi import HTTPException, UploadFile
from sqlalchemy.orm import Session

from project.models import PhotoDB

MAX_PHOTO_BYTES = 3 * 1024 * 1024

# نتحقق من محتوى الملف نفسه، لأن امتداده ونوعه المرسل يمكن تزويرهما
_SIGNATURES = {b"\xff\xd8\xff": (".jpg", "image/jpeg"), b"\x89PNG\r\n\x1a\n": (".png", "image/png")}


def _kind(content: bytes) -> tuple[str, str] | None:
    for signature, kind in _SIGNATURES.items():
        if content.startswith(signature):
            return kind
    if content[:4] == b"RIFF" and content[8:12] == b"WEBP":
        return ".webp", "image/webp"
    return None


async def save_photo(photo: UploadFile, db: Session) -> str:
    """يضيف الصورة إلى قاعدة البيانات باسم عشوائي ويعيد رابطها النسبي. الحفظ على من يستدعيها.

    لا تُحفظ على القرص لأن قرص الاستضافة المجانية يُمسح عند كل إعادة تشغيل.
    """
    content = await photo.read(MAX_PHOTO_BYTES + 1)
    if len(content) > MAX_PHOTO_BYTES:
        raise HTTPException(status_code=413, detail="حجم الصورة أكبر من 3 ميغابايت")
    kind = _kind(content)
    if kind is None:
        raise HTTPException(status_code=415, detail="يجب أن تكون الصورة بصيغة JPG أو PNG أو WEBP")
    extension, media_type = kind
    name = secrets.token_urlsafe(16) + extension
    db.add(PhotoDB(name=name, media_type=media_type, data=content))
    return f"/uploads/{name}"

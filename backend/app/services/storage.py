"""Protected file storage.

Files are written under STORAGE_DIR with random opaque keys and are only ever returned
through authorized API endpoints. No public URLs exist. Swap LocalFileStorage for a cloud
bucket implementation (private bucket + server-side reads) without touching the routers.
"""

import hashlib
import os
import secrets
from pathlib import Path
from typing import Protocol

from ..config import get_settings

ALLOWED_REPORT_TYPES = {
    "application/pdf": ".pdf",
    "image/jpeg": ".jpg",
    "image/png": ".png",
    "image/webp": ".webp",
    "image/heic": ".heic",
}
ALLOWED_PHOTO_TYPES = {"image/jpeg": ".jpg", "image/png": ".png", "image/webp": ".webp"}

EXTENSION_TYPES = {
    ".pdf": "application/pdf",
    ".jpg": "image/jpeg",
    ".jpeg": "image/jpeg",
    ".png": "image/png",
    ".webp": "image/webp",
    ".heic": "image/heic",
}


def sniff_content_type(data: bytes, filename: str, declared: str | None) -> str | None:
    """Determines the file type from its bytes, falling back to the extension for HEIC."""
    if data.startswith(b"%PDF"):
        return "application/pdf"
    if data.startswith(b"\xff\xd8\xff"):
        return "image/jpeg"
    if data.startswith(b"\x89PNG\r\n\x1a\n"):
        return "image/png"
    if data[:4] == b"RIFF" and data[8:12] == b"WEBP":
        return "image/webp"
    if data[4:12] in (b"ftypheic", b"ftypheix", b"ftypmif1", b"ftypmsf1"):
        return "image/heic"
    return None


class FileStorage(Protocol):
    def save(self, namespace: str, data: bytes, extension: str) -> str: ...

    def read(self, ref: str) -> bytes: ...


class LocalFileStorage:
    def __init__(self, root: str):
        self.root = Path(root).resolve()
        self.root.mkdir(parents=True, exist_ok=True)

    def _path(self, ref: str) -> Path:
        path = (self.root / ref).resolve()
        if self.root not in path.parents:
            raise ValueError("Invalid storage reference")
        return path

    def save(self, namespace: str, data: bytes, extension: str) -> str:
        ref = f"{namespace}/{secrets.token_hex(16)}{extension}"
        path = self._path(ref)
        path.parent.mkdir(parents=True, exist_ok=True)
        with open(path, "wb") as f:
            f.write(data)
        os.chmod(path, 0o600)
        return ref

    def read(self, ref: str) -> bytes:
        return self._path(ref).read_bytes()


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


_storage: FileStorage | None = None


def get_storage() -> FileStorage:
    global _storage
    if _storage is None:
        _storage = LocalFileStorage(get_settings().storage_dir)
    return _storage


def set_storage(storage: FileStorage) -> None:
    global _storage
    _storage = storage

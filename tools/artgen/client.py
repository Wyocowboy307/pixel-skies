"""PixelLab access.

The API key is never passed on a command line or pasted into a prompt. It is
read from ~/.pixellab_key or the PIXELLAB_API_KEY environment variable, matching
how the other service keys on this machine are stored.
"""

from __future__ import annotations

import os
import time
from pathlib import Path

KEY_FILE = Path.home() / ".pixellab_key"
ENV_VAR = "PIXELLAB_API_KEY"


class MissingKey(RuntimeError):
    pass


def read_key() -> str:
    env = os.environ.get(ENV_VAR, "").strip()
    if env:
        return env
    if KEY_FILE.exists():
        key = KEY_FILE.read_text().strip()
        if key:
            return key
    raise MissingKey(
        f"No PixelLab API key.\n"
        f"  Put it in {KEY_FILE} (chmod 600), or export {ENV_VAR}.\n"
        f"  Do not paste it into a chat prompt or a command line."
    )


BASE_URL = "https://api.pixellab.ai/v1"


def client():
    import pixellab
    return pixellab.Client(secret=read_key())


def _headers() -> dict:
    return {"Authorization": f"Bearer {read_key()}"}


def _encode(image) -> dict:
    """PIL image -> the API's base64 image object."""
    import base64
    from io import BytesIO
    buffer = BytesIO()
    image.save(buffer, format="PNG")
    return {"type": "base64", "base64": base64.b64encode(buffer.getvalue()).decode(),
            "format": "png"}


def _decode(payload: dict):
    import base64
    from io import BytesIO
    from PIL import Image
    return Image.open(BytesIO(base64.b64decode(payload["base64"])))


def generate(endpoint: str, params: dict, style_image=None, color_image=None):
    """Call PixelLab directly and return (image, usage).

    The SDK is used for its request shape but not its response model: it pins
    `usage` to a USD figure, while an account on a generations quota returns a
    different shape, and the strict model rejects a response whose image is
    perfectly good. Parsing the response here keeps the pipeline working across
    that drift — and the image has already been paid for by the time the SDK
    would have thrown.
    """
    import requests

    body = dict(params)
    if style_image is not None:
        body["style_image"] = _encode(style_image)
    if color_image is not None:
        body["color_image"] = _encode(color_image)

    # DNS to this host has proved intermittent from inside the venv, so a
    # transient resolution failure is retried rather than losing the run.
    last: Exception | None = None
    response = None
    for attempt in range(4):
        try:
            response = requests.post(f"{BASE_URL}/{endpoint}", headers=_headers(),
                                     json=body, timeout=240)
            break
        except requests.exceptions.ConnectionError as exc:
            last = exc
            time.sleep(1.5 * (attempt + 1))
    if response is None:
        raise RuntimeError(f"could not reach PixelLab after retries: {last}")
    if response.status_code in (401, 422, 402, 429):
        detail = ""
        try:
            detail = response.json().get("detail", response.text)
        except Exception:                          # noqa: BLE001
            detail = response.text
        raise RuntimeError(f"PixelLab {response.status_code}: {detail}")
    response.raise_for_status()
    payload = response.json()
    return _decode(payload["image"]), payload.get("usage", {})


def balance() -> str:
    import requests
    try:
        response = requests.get(f"{BASE_URL}/balance", headers=_headers(), timeout=30)
        response.raise_for_status()
        return str(response.json())
    except MissingKey:
        raise
    except Exception as exc:                      # noqa: BLE001 - reported, not raised
        return f"(balance unavailable: {exc})"

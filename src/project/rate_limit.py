import time
from collections import defaultdict, deque

from fastapi import HTTPException, Request


def rate_limit(limit: int, seconds: int):
    """يحدد عدد الطلبات من كل عنوان خلال مدة. العدّاد في الذاكرة، ويصلح لخادم بعملية واحدة."""
    hits: dict[str, deque[float]] = defaultdict(deque)

    def check(request: Request) -> None:
        now = time.monotonic()
        for key in [k for k, q in hits.items() if not q or now - q[-1] > seconds]:
            del hits[key]
        recent = hits[request.client.host if request.client else "unknown"]
        while recent and now - recent[0] > seconds:
            recent.popleft()
        if len(recent) >= limit:
            raise HTTPException(status_code=429, detail="طلبات كثيرة. انتظر قليلاً ثم حاول مرة أخرى.")
        recent.append(now)

    return check

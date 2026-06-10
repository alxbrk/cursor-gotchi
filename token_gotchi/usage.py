"""Fetch Cursor subscription usage from the local session token."""

from __future__ import annotations

import json
import sqlite3
import urllib.error
import urllib.request
from dataclasses import asdict, dataclass, fields
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

CURSOR_STATE_DB = (
    Path.home() / "Library/Application Support/Cursor/User/globalStorage/state.vscdb"
)
USAGE_API = "https://api2.cursor.sh/aiserver.v1.DashboardService/GetCurrentPeriodUsage"
PLAN_API = "https://api2.cursor.sh/aiserver.v1.DashboardService/GetPlanInfo"
DEFAULT_USAGE_PATH = Path.home() / ".cursor/token-gotchi/usage.json"


@dataclass
class UsageSnapshot:
    fetched_at: str
    plan_name: str | None = None
    included_limit_cents: int | None = None
    used_percent: int | None = None
    total_spend_cents: int | None = None
    included_spend_cents: int | None = None
    bonus_spend_cents: int | None = None
    display_message: str | None = None
    short_label: str = "—"
    billing_cycle_end: str | None = None
    error: str | None = None

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)


def _read_access_token() -> str | None:
    if not CURSOR_STATE_DB.exists():
        return None
    try:
        conn = sqlite3.connect(f"file:{CURSOR_STATE_DB}?mode=ro", uri=True)
        try:
            row = conn.execute(
                "SELECT value FROM ItemTable WHERE key = ?",
                ("cursorAuth/accessToken",),
            ).fetchone()
        finally:
            conn.close()
        if not row or not row[0]:
            return None
        return str(row[0])
    except sqlite3.Error:
        return None


def _post_json(url: str, token: str, timeout: float = 8.0) -> dict[str, Any]:
    request = urllib.request.Request(
        url,
        data=b"{}",
        headers={
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
            "Connect-Protocol-Version": "1",
        },
        method="POST",
    )
    with urllib.request.urlopen(request, timeout=timeout) as response:
        payload = response.read().decode("utf-8")
        return json.loads(payload)


def _format_money(cents: int) -> str:
    dollars = cents / 100
    if cents % 100 == 0:
        return f"${int(dollars)}"
    return f"${dollars:.2f}"


def _short_label(used_percent: int | None) -> str:
    if used_percent is not None:
        return f"{used_percent}%"
    return "—"


def fetch_usage() -> UsageSnapshot:
    now = datetime.now(timezone.utc).isoformat()
    token = _read_access_token()
    if not token:
        return UsageSnapshot(
            fetched_at=now,
            short_label="Sign in",
            error="Cursor is not signed in on this Mac.",
        )

    try:
        usage_payload = _post_json(USAGE_API, token)
        plan_payload: dict[str, Any] = {}
        try:
            plan_payload = _post_json(PLAN_API, token)
        except (urllib.error.URLError, TimeoutError, json.JSONDecodeError):
            pass

        plan_info = plan_payload.get("planInfo") or {}
        plan_usage = usage_payload.get("planUsage") or {}

        limit = plan_usage.get("limit")
        included_spend = plan_usage.get("includedSpend")
        percent_used_raw = plan_usage.get("totalPercentUsed")
        used_percent = None
        if isinstance(percent_used_raw, (int, float)):
            used_percent = int(max(0, round(percent_used_raw)))

        display_message = usage_payload.get("displayMessage")
        if isinstance(display_message, str):
            display_message = display_message.strip() or None
        else:
            display_message = None

        return UsageSnapshot(
            fetched_at=now,
            plan_name=plan_info.get("planName"),
            included_limit_cents=limit if isinstance(limit, int) else None,
            used_percent=used_percent,
            total_spend_cents=plan_usage.get("totalSpend")
            if isinstance(plan_usage.get("totalSpend"), int)
            else None,
            included_spend_cents=included_spend
            if isinstance(included_spend, int)
            else None,
            bonus_spend_cents=plan_usage.get("bonusSpend")
            if isinstance(plan_usage.get("bonusSpend"), int)
            else None,
            display_message=display_message,
            short_label=_short_label(used_percent),
            billing_cycle_end=str(usage_payload.get("billingCycleEnd"))
            if usage_payload.get("billingCycleEnd") is not None
            else None,
        )
    except urllib.error.HTTPError as exc:
        return UsageSnapshot(
            fetched_at=now,
            short_label="—",
            error=f"Cursor usage API returned HTTP {exc.code}.",
        )
    except (urllib.error.URLError, TimeoutError):
        return UsageSnapshot(
            fetched_at=now,
            short_label="—",
            error="Could not reach Cursor usage API.",
        )
    except json.JSONDecodeError:
        return UsageSnapshot(
            fetched_at=now,
            short_label="—",
            error="Cursor usage API returned invalid JSON.",
        )


def write_usage(snapshot: UsageSnapshot, path: Path | None = None) -> Path:
    target = path or DEFAULT_USAGE_PATH
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(json.dumps(snapshot.to_dict(), indent=2) + "\n", encoding="utf-8")
    return target


def load_usage(path: Path | None = None) -> UsageSnapshot | None:
    target = path or DEFAULT_USAGE_PATH
    if not target.exists():
        return None
    try:
        data = json.loads(target.read_text(encoding="utf-8"))
        allowed = {f.name for f in fields(UsageSnapshot)}
        filtered = {k: v for k, v in data.items() if k in allowed}
        return UsageSnapshot(**filtered)
    except (json.JSONDecodeError, TypeError):
        return None


def sync_usage(path: Path | None = None) -> UsageSnapshot:
    snapshot = fetch_usage()
    write_usage(snapshot, path)
    return snapshot

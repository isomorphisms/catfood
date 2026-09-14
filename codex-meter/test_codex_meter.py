#!/usr/bin/env python3
import importlib.machinery
import importlib.util
from pathlib import Path

path = Path(__file__).with_name("codex-meter")
loader = importlib.machinery.SourceFileLoader("codex_meter", str(path))
spec = importlib.util.spec_from_loader(loader.name, loader)
module = importlib.util.module_from_spec(spec)
loader.exec_module(module)

fixture = {
    "plan_type": "prolite",
    "rate_limit": {
        "allowed": True,
        "limit_reached": False,
        "primary_window": {
            "used_percent": 27,
            "limit_window_seconds": 18000,
            "reset_at": 1780000000,
        },
        "secondary_window": {
            "used_percent": 59,
            "limit_window_seconds": 604800,
            "reset_at": 1780100000,
        },
    },
}

data = module.normalized(fixture)
assert module.usage_url("https://chatgpt.com/backend-api") == "https://chatgpt.com/backend-api/wham/usage"
assert module.usage_url("https://example.invalid") == "https://example.invalid/api/codex/usage"
assert data["windows"][0]["label"] == "5h"
assert data["windows"][0]["remaining_percent"] == 73
assert data["windows"][1]["label"] == "7d"
assert data["windows"][1]["remaining_percent"] == 41
assert module.plain(data) == "Codex 5h 73% · 7d 41%"
assert module.waybar(data)["class"] == "normal"
print("ok")

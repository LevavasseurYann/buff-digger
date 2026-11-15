"""Run tests/smoke.lua (fake WoW API + scenarios), then tests/journal.lua (the dev journal), under Lua 5.1, the game's Lua version.

Usage, from the repo root:  uv run --no-project -q --with lupa python -I tests/run_smoke.py
Prints each scenario's output; any Lua error aborts with a traceback.
"""
import pathlib
import lupa.lua51 as lua51

root = pathlib.Path(__file__).resolve().parent.parent
for name in ("smoke.lua", "journal.lua"):  # each in a fresh Lua: no fake leaks from one to the other
    runtime = lua51.LuaRuntime()
    runtime.execute(f'DIR="{root.as_posix()}/"')
    runtime.execute((root / "tests" / name).read_text(encoding="utf-8"))

"""Run tests/smoke.lua (scenarios), tests/journal.lua (the dev journal), then tests/replay.lua on each
tests/fixtures/*.lua (journals replayed, invariants checked), under Lua 5.1, the game's Lua version.

Usage, from the repo root:  uv run --no-project -q --with lupa python -I tests/run_smoke.py
Prints each scenario's output; any Lua error or broken invariant aborts (fixture, time, invariant).
"""
import pathlib
import sys
import lupa.lua51 as lua51

root = pathlib.Path(__file__).resolve().parent.parent
runs = [("smoke.lua", None), ("journal.lua", None)]
runs += [("replay.lua", f) for f in sorted((root / "tests" / "fixtures").glob("*.lua"))]
for name, fixture in runs:  # each in a fresh Lua: no fake leaks from one to the other
    runtime = lua51.LuaRuntime()
    runtime.execute(f'DIR="{root.as_posix()}/"')
    if fixture:
        runtime.execute(f'FIXTURE="{fixture.as_posix()}"')
    try:
        runtime.execute((root / "tests" / name).read_text(encoding="utf-8"))
    except lua51.LuaError as e:
        sys.exit(f"FAILED {name}: {e}")

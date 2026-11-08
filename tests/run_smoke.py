"""Run tests/smoke.lua (fake WoW API + scenarios) under Lua 5.1, the game's Lua version.

Usage, from the repo root:  uv run --no-project -q --with lupa python -I tests/run_smoke.py
Prints each scenario's output; any Lua error aborts with a traceback.
"""
import pathlib
import lupa.lua51 as lua51

root = pathlib.Path(__file__).resolve().parent.parent
runtime = lua51.LuaRuntime()
runtime.execute(f'DIR="{root.as_posix()}/"')
runtime.execute((root / "tests" / "smoke.lua").read_text(encoding="utf-8"))

"""A journal (SavedVariables/BuffDiggerJournal.lua) -> a replay fixture, player names made up (public repo).

Usage, from the repo root:
  uv run --no-project -q --with lupa python -I tests/journal_to_fixture.py <BuffDiggerJournal.lua> tests/fixtures/<date-what>.lua
Keeps the raw events only (not the text lines nor the probe). Every first or last name the journal saw
on a unit becomes Player1, Player2...; check the output for names typed elsewhere (chat) before committing.
"""
import pathlib
import sys
import lupa.lua51 as lua51

LUA = r"""
local src, dst = ...
dofile(src)
local events = assert(BuffDiggerJournalDB and BuffDiggerJournalDB.events, "no events in " .. src)
local fake, n = {}, 0
local function learn(id)
  for _, f in ipairs({ "name", "last" }) do
    local v = type(id) == "table" and id[f]
    if type(v) == "string" and not v:find("^<") and not fake[v] then n = n + 1; fake[v] = "Player" .. n end
  end
end
for _, e in ipairs(events) do
  for _, id in pairs(type(e.units) == "table" and e.units or {}) do learn(id) end
end
local function anon(s)
  return (s:gsub("[^%s%-]+", function(w) return fake[w] end))
end
local function write(v, out)
  local t = type(v)
  if t == "string" then out[#out + 1] = string.format("%q", anon(v))
  elseif t == "table" then
    out[#out + 1] = "{ "
    for k, x in pairs(v) do
      out[#out + 1] = "["; write(k, out); out[#out + 1] = "] = "; write(x, out); out[#out + 1] = ", "
    end
    out[#out + 1] = "}"
  else out[#out + 1] = tostring(v) end
end
local out = { "-- Converted by tests/journal_to_fixture.py from a journal, names made up.\n",
  "BuffDiggerJournalDB = {\n  events = {\n" }
for _, e in ipairs(events) do out[#out + 1] = "    "; write(e, out); out[#out + 1] = ",\n" end
out[#out + 1] = "  },\n}\n"
local f = assert(io.open(dst, "w"))
f:write(table.concat(out))
f:close()
return #events, n
"""

if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    src, dst = (pathlib.Path(a).resolve().as_posix() for a in sys.argv[1:])
    count, names = lua51.LuaRuntime().execute(LUA, src, dst)
    print(f"{dst}: {count} events, {names} names replaced")

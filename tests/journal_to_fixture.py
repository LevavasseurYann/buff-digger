"""A journal (SavedVariables/BuffDiggerJournal.lua) -> a replay fixture, player names made up (public repo).

Usage, from the repo root:
  uv run --no-project -q --with lupa python -I tests/journal_to_fixture.py <BuffDiggerJournal.lua> tests/fixtures/<date-what>.lua
Keeps the raw events only (not the text lines nor the probe). Every first or last name the journal saw
(on a unit, or in Buff Digger's state: requests, Thank lines, givers) becomes Player1, Player2... in every
string but spell names; check the output for names typed elsewhere (chat) before committing.
"""
import pathlib
import sys
import lupa.lua51 as lua51

LUA = r"""
local src, dst = ...
dofile(src)
local events = assert(BuffDiggerJournalDB and BuffDiggerJournalDB.events, "no events in " .. src)
local fake, n = {}, 0
local WORD = "[%a\128-\255]+" -- letters (UTF-8 bytes too): "'Kell'" or "Ann-Bee" split right
local function learn(v)
  if type(v) ~= "string" or v:find("^<") then return end
  for w in v:gmatch(WORD) do if not fake[w] then n = n + 1; fake[w] = "Player" .. n end end
end
local function list(t) return type(t) == "table" and t or {} end
for _, e in ipairs(events) do
  for _, id in pairs(list(e.units)) do if type(id) == "table" then learn(id.name); learn(id.last) end end
  local s = list(e.state)
  for who, r in pairs(list(s.asked)) do learn(who); if type(r) == "table" then learn(r.target) end end
  for _, x in pairs(list(s.toThank)) do if type(x) == "table" then learn(x.name); learn(x.target) end end
  for _, m in pairs(list(s.mine)) do if type(m) == "table" then learn(m.giver) end end
end
local function anon(s)
  return (s:gsub(WORD, function(w) return fake[w] end))
end
-- spell: the name field of an aura (a table with a spellId) is the spell's, never a player's
local function write(v, out, spell)
  local t = type(v)
  if t == "string" then out[#out + 1] = string.format("%q", spell and v or anon(v))
  elseif t == "table" then
    out[#out + 1] = "{ "
    for k, x in pairs(v) do
      out[#out + 1] = "["; write(k, out); out[#out + 1] = "] = "
      write(x, out, k == "name" and v.spellId ~= nil); out[#out + 1] = ", "
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

-- Buff Digger: interface strings.
-- The interface is English only (decided 2026-11-08, #9). Strings still go through L[...] so a
-- translation can be added later without touching the code: a missing key shows its English text.
-- Messages sent to OTHER players are in Data.lua (ns.MESSAGES, ns.THANKS), in the language chosen in the settings.

local _, ns = ...

ns.L = setmetatable({}, { __index = function(_, key) return key end })

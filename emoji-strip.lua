-- Make text safe for the downloadable formats (PDF, Word, RTF); leave the web
-- pages untouched. Two jobs:
--
--   1. STRIP emoji, so a heading reads "Policies" rather than "🏫 Policies".
--   2. MAP the handful of non-emoji symbols that pdflatex cannot typeset onto
--      ASCII equivalents, so they degrade rather than vanish. Dropping the arrow
--      in "Insert → Page Break" would silently destroy the meaning; "Insert ->
--      Page Break" keeps it.
--
-- Both matter because `pdf-engine: pdflatex` is NOT a Unicode-native engine.
-- Anything it does not recognise is a hard `inputenc` error and a failed build,
-- not a cosmetic glitch. Step 3 below therefore warns at render time about any
-- surviving high codepoint, so the next such character surfaces as a readable
-- message instead of a LaTeX stack trace.
--
-- Registered once in _quarto.yml, so no page needs to do anything.
--
-- This file is shared verbatim across dwv_f26, sta_f26, and pst315_f26;
-- change it in one repo, copy it to the others.

if FORMAT:match("html") then return {} end

local function is_emoji(cp)
  return (cp >= 0x1F000 and cp <= 0x1FAFF)   -- pictographs, faces, symbols
      or (cp >= 0x2600  and cp <= 0x27BF)    -- misc symbols and dingbats
      or (cp >= 0x2B00  and cp <= 0x2BFF)    -- misc symbols and arrows
      or (cp >= 0xFE00  and cp <= 0xFE0F)    -- variation selectors
      or cp == 0x200D                        -- zero-width joiner
      or cp == 0x20E3                        -- combining enclosing keycap
end

-- Symbols worth keeping as text. Extend this rather than the strip ranges when
-- a character carries meaning.
local REPLACE = {
  [0x2192] = "->",   -- →  rightwards arrow (menu paths: Insert -> Page Break)
  [0x2190] = "<-",   -- ←
  [0x2194] = "<->",  -- ↔
  [0x21D2] = "=>",   -- ⇒
  [0x21D0] = "<=",   -- ⇐
  [0x2026] = "...",  -- …  ellipsis
  [0x2212] = "-",    -- −  minus sign
}

-- Codepoints above this are assumed safe only if stripped or mapped above.
-- Latin-1 and General Punctuation below 0x2010 are handled fine by inputenc.
local SAFE_MAX = 0x2010
local SAFE = {
  [0x2013] = true,  -- – en dash   (pandoc emits --)
  [0x2014] = true,  -- — em dash   (pandoc emits ---)
  [0x2018] = true, [0x2019] = true,  -- ' ' curly single quotes
  [0x201C] = true, [0x201D] = true,  -- " " curly double quotes
  [0x2022] = true,  -- • bullet
}

local warned = {}
local function warn_once(cp)
  if warned[cp] then return end
  warned[cp] = true
  io.stderr:write(string.format(
    "\n[emoji-strip] WARNING: U+%04X (%s) is not stripped, mapped or known-safe.\n" ..
    "              pdflatex will fail on it. Add it to REPLACE or SAFE in\n" ..
    "              emoji-strip.lua, or remove it from the source.\n\n",
    cp, utf8.char(cp)))
end

local function clean_text(s)
  local out = {}
  for _, cp in utf8.codes(s) do
    if is_emoji(cp) then
      -- dropped
    elseif REPLACE[cp] then
      out[#out + 1] = REPLACE[cp]
    else
      if cp > SAFE_MAX and not SAFE[cp] then warn_once(cp) end
      out[#out + 1] = utf8.char(cp)
    end
  end
  return table.concat(out)
end

-- Operate on whole inline lists so that an emoji-only Str, and the space left
-- behind after it, can both be dropped.
local function clean(inlines)
  local out = pandoc.Inlines({})
  for _, el in ipairs(inlines) do
    if el.t == "Str" then
      local s = clean_text(el.text)
      if s ~= "" then out:insert(pandoc.Str(s)) end
    else
      out:insert(el)
    end
  end
  while #out > 0 and out[1].t == "Space" do out:remove(1) end
  return out
end

return { { Inlines = clean } }

-- Render callouts as a plain indented block in the downloadable formats: a bold
-- title above an indented body, the way the RTF export already does it. The web
-- pages keep Quarto's styled callout boxes.
--
-- Every callout gets a title line. If the author supplied one (title="..."), that
-- is used; otherwise it falls back to the callout's type, matching the label
-- Quarto shows on the web ("Note", "Important", "Tip", ...). Without that
-- fallback an untitled callout prints as a bare indented paragraph that reads as
-- a lesser aside rather than a stronger one -- which is exactly backwards for a
-- callout-important.
--
-- Deliberately no box, rule or colour: the indent plus the bold label is the
-- whole treatment.
--
-- Callouts reach a filter as a Quarto custom node rather than a Div carrying a
-- .callout-note class, so this handles `Callout` directly. Its `title` and
-- `content` each arrive as either a single Block or a list, hence the type
-- checks.

if FORMAT:match("html") then return {} end

-- Quarto's five built-in types, capitalised the way the web pages label them.
local TYPE_LABEL = {
  note      = "Note",
  important = "Important",
  tip       = "Tip",
  warning   = "Warning",
  caution   = "Caution",
}

local function title_inlines(callout)
  local title = callout.title
  if title and pandoc.utils.stringify(title) ~= "" then
    if pandoc.utils.type(title) == "Block" then return title.content end
    return title
  end
  -- No explicit title: use the callout type.
  local t = callout.type
  if t == nil or t == "" then return nil end
  local label = TYPE_LABEL[t] or (t:sub(1, 1):upper() .. t:sub(2))
  return pandoc.Inlines({ pandoc.Str(label) })
end

return { {
  Callout = function(callout)
    local out = pandoc.Blocks({})

    local title = title_inlines(callout)
    if title then out:insert(pandoc.Para(pandoc.Strong(title))) end

    local body = callout.content
    if pandoc.utils.type(body) == "Blocks" then out:extend(body) else out:insert(body) end

    return pandoc.BlockQuote(out)
  end
} }

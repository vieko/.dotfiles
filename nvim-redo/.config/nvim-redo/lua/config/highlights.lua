local colors = {
  guifg = "#acb2be",
  guibg = "#282c33",

  gui00 = "#282c34", -- Default Background
  gui01 = "#3f4451", -- Lighter Background (Status bars)
  gui02 = "#4f5666", -- Selection Background
  gui03 = "#545862", -- Comments, Invisibles, Line Highlighting
  gui04 = "#9196a1", -- Dark Foreground (Status bars)
  gui05 = "#abb2bf", -- Default, Caret, Delimiters, Operators
  gui06 = "#e6e6e6", -- Light Foreground (Not often used)
  gui07 = "#ffffff", -- Lightest Foreground (Not often used)

  gui08 = "#d07277", -- Variables, XML Tags, Markup Links, Lists
  gui09 = "#bf956a", -- Integers, Boolean, XML Attributes
  gui0A = "#dfc184", -- Classes, Markup Bold, Search Background
  gui0B = "#a1c181", -- Strings, Inherited Class, Markup Code
  gui0C = "#6eb4bf", -- Support, RegEx, Escape Chars, Quotes
  gui0D = "#74ade8", -- Functions, Methods, IDs, Headings
  gui0E = "#b477cf", -- Keywords, Storage, Selector, Markup
  gui0F = "#b1574b", -- Deprecated Methods and Functions

  gui10 = "#21252b", -- Darker Background
  gui11 = "#181a1f", -- The Darkest Background
  gui12 = "#ff616e", -- Red
  gui13 = "#f0a45d", -- Yellow
  gui14 = "#a5e075", -- Green
  gui15 = "#4cd1e0", -- Cyan
  gui16 = "#4dc4ff", -- Blue
  gui17 = "#de73ff", -- Purple

  cterm00 = 0,
  cterm01 = 18,
  cterm02 = 19,
  cterm03 = 8,
  cterm04 = 20,
  cterm05 = 21,
  cterm06 = 7,
  cterm07 = 15,
  cterm08 = 1,
  cterm09 = 16,
  cterm0A = 3,
  cterm0B = 2,
  cterm0C = 6,
  cterm0D = 4,
  cterm0E = 5,
  cterm0F = 17,
  cterm10 = 0,
  cterm11 = 0,
  cterm12 = 9,
  cterm13 = 11,
  cterm14 = 10,
  cterm15 = 14,
  cterm16 = 12,
  cterm17 = 13,
}
local c = colors

local d = {
  ctermfg = colors.cterm05,
  ctermbg = colors.cterm00,
}

local function hex_to_rgb(hex)
  if not hex or #hex < 6 then
    return 0, 0, 0
  end
  -- Remove # if present
  hex = hex:gsub("#", "")
  -- Handle both 6 and 8 character hex (with alpha)
  local r = tonumber(hex:sub(1, 2), 16)
  local g = tonumber(hex:sub(3, 4), 16)
  local b = tonumber(hex:sub(5, 6), 16)
  return r or 0, g or 0, b or 0
end

local function hex_to_rgba(hex)
  if not hex or #hex < 6 then
    return 0, 0, 0, 255
  end
  -- Remove # if present
  hex = hex:gsub("#", "")
  local r, g, b = hex_to_rgb("#" .. hex:sub(1, 6))
  -- Handle alpha if present (8 character hex)
  local a = (#hex == 8) and tonumber(hex:sub(7, 8), 16) or 255
  return r, g, b, a
end

local function blend(f, b, a)
  return math.floor((1 - a) * b + a * f + 0.5)
end

local function ensure_hash(color)
  if not color then
    return nil
  end
  -- If color has 8 characters (alpha included), remove last 2 characters
  if #color == 8 then
    color = color:sub(1, 6)
  end
  -- Ensure it starts with #
  if #color == 6 and color:sub(1, 1) ~= "#" then
    return "#" .. color
  end
  return color
end

-- Convert decimal alpha (0-1) to hex alpha (00-FF)
local function with_alpha(hex, alpha)
  if not hex then
    return nil
  end

  -- Ensure hex starts with #
  hex = ensure_hash(hex)
  -- Remove any existing alpha
  hex = hex:sub(1, 7)

  -- Clamp alpha between 0 and 1
  alpha = math.max(0, math.min(1, alpha))
  -- Convert to hex value (0-255)
  local alpha_hex = string.format("%02x", math.floor(alpha * 255 + 0.5))

  return hex .. alpha_hex
end

local function blend_color(fg_hex, bg_hex)
  if not fg_hex or #fg_hex < 6 then
    return ensure_hash(bg_hex)
  end
  if not bg_hex or #bg_hex < 6 then
    return ensure_hash(fg_hex)
  end

  -- Remove # if present from both colors
  fg_hex = fg_hex:gsub("#", "")
  bg_hex = bg_hex:gsub("#", "")

  local fr, fg, fb, fa = hex_to_rgba("#" .. fg_hex)
  local br, bg, bb = hex_to_rgb("#" .. bg_hex) -- Use default bg if none is provided

  -- Convert alpha from 0-255 to 0-1 range
  local alpha = fa / 255

  -- Perform alpha blending
  local rr = blend(fr, br, alpha)
  local gg = blend(fg, bg, alpha)
  local bb = blend(fb, bb, alpha)

  -- Return blended color in #RRGGBB format
  return string.format("#%02x%02x%02x", rr, gg, bb)
end

local function hl(group, opts)
  if type(group) ~= "string" then
    error("highlight group must be a string")
    return
  end

  -- Set defaults
  opts = vim.tbl_extend("keep", opts or {}, {
    fg = nil,
    bg = nil,
    sp = nil,
    ctermfg = nil,
    ctermbg = d.ctermbg,
    attr = nil,
  })

  -- Get default background color
  local default_bg = colors.gui00

  -- Pre-process background color first
  if opts.bg and opts.bg ~= "NONE" then
    if #opts.bg == 9 then -- #RRGGBBAA format
      opts.bg = blend_color(opts.bg, default_bg)
    else
      opts.bg = ensure_hash(opts.bg)
    end
  else
    opts.bg = default_bg
  end

  -- Then process foreground color
  if opts.fg and opts.fg ~= "NONE" then
    if #opts.fg == 9 then -- #RRGGBBAA format
      opts.fg = blend_color(opts.fg, opts.bg)
    else
      opts.fg = ensure_hash(opts.fg)
    end
  end

  local hl_opts = {
    fg = opts.fg,
    bg = opts.bg,
    sp = ensure_hash(opts.sp),
    ctermfg = opts.ctermfg and tonumber(opts.ctermfg) or nil,
    ctermbg = opts.ctermbg and tonumber(opts.ctermbg) or d.ctermbg,
    bold = false,
    italic = false,
    underline = false,
    strikethrough = false,
    reverse = false,
    standout = false,
    nocombine = false,
  }

  -- Apply attributes
  if opts.attr and opts.attr ~= "NONE" then
    for _, a in ipairs(vim.split(opts.attr, ",")) do
      hl_opts[a] = true
    end
  end

  -- Apply highlight safely
  vim.api.nvim_set_hl(0, group, hl_opts)
end

hl("Normal", { fg = c.guifg, bg = c.guibg, ctermfg = d.ctermfg, ctermbg = d.ctermbg })

hl("CursorLine", { bg = with_alpha(c.gui01, 0.2) })
hl("Yank", { bg = with_alpha(c.gui0D, 0.24) })
hl("MiniCursorword", { bg = with_alpha(c.gui0D, 0.24) })
hl("MatchParen", { bg = with_alpha(c.gui0D, 0.24) })
hl("VirtColumn", { fg = with_alpha(c.gui05, 0.10) })
hl("Visual", { bg = with_alpha(c.gui0D, 0.36) })

-- GIT
-- hl(0, "GitSignsCurrentLineBlame", { fg = "#788CA6" })

-- SNACKS
-- hl(0, "SnacksPicker", { bg = "#2F343E", fg = "#E6E6E6" })
-- hl(0, "SnacksPickerTitle", { bg = "#2F343E", fg = "#ABB2BF" })
-- hl(0, "SnacksPickerBorder", { bg = "#2F343E", fg = "#3C414C" })
-- hl(0, "SnacksPickerPrompt", { fg = "#98C379" })
-- hl(0, "SnacksPickerListCursorLine", { bg = "#363C46" })

-- SYNTAX HIGHLIGHTING
-- hl(0, "Special", { fg = hex(vim.g.tinted_gui0D) }) -- @attribute
-- hl(0, "Boolean", { fg = hex(vim.g.tinted_gui09) }) -- @boolean
-- hl(0, "Comment", { fg = "#5d636f" }) -- @comment
-- hl(0, "@comment.documentation", { fg = "#878e98" }) -- @comment.doc
-- hl(0, "Constant", { fg = "#dfc184" }) -- @constant
-- hl(0, "@constructor", { fg = "#73ade9", bold = false })
-- hl(0, "@embedded", { fg = "#dce0e5" })
-- hl(0, "Italic", { fg = "#74ade8" }) -- @emphasis
-- hl(0, "Bold", { fg = "#bf956a" }) -- @emphasis.string
-- hl(0, "@enum", { fg = "#d07277" })
-- hl(0, "Function", { fg = "#73ade9" })
-- hl(0, "@function", { link = "Function" })
-- hl(0, "@hint", { fg = "#788CA6" })
-- hl(0, "Statement", { fg = "#b477cf", bold = false }) -- Keyword, @keyword
-- hl(0, "Repeat", { fg = "#b477cf", bold = false }) -- Repeat, Condition, Loop
-- hl(0, "@keyword.import", { link = "@keyword" })
-- hl(0, "Label", { link = "Tag" }) -- @label
-- hl(0, "@link_text", { fg = "#73ade9" })
-- hl(0, "@link_uri", { fg = "#6eb4bf" })
-- hl(0, "Number", { fg = "#bf956a" }) -- @number
-- hl(0, "Operator", { fg = "#6eb4bf" }) -- @operator
-- hl(0, "@predictive", { fg = "#5a6a87" })
-- hl(0, "PreProc", { fg = "#dce0e5" }) -- @preproc
-- hl(0, "Normal", { fg = "#dce0e5" }) -- @primary
-- hl(0, "@variable.member", { fg = "#d07277" }) -- @property
-- hl(0, "String", { fg = "#a1c181" }) -- @string
-- hl(0, "Tag", { fg = "#74ade8" }) -- @tag
-- hl(0, "Type", { fg = "#6eb4bf" }) -- @type
-- hl(0, "Identifier", { fg = "#dce0e5" }) -- @variable
-- hl(0, "Special", { fg = "#dce0e5" }) -- @variable

-- Test transparency with 50% alpha
hl("TestTransparency", {
  fg = "#ff000080", -- Red with 50% alpha
  bg = "#00ff0080", -- Green with 50% alpha
})

-- Test transparent foreground without background
hl("TestTransparentFG", {
  fg = "#ff000080", -- Red with 50% alpha
  -- No bg specified, should blend with default background (#282c34)
})

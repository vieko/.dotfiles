local M = {}

-- === COLOR UTILITIES ===
local function hex_to_rgb(hex)
  if not hex or not hex:match("^#?[0-9A-Fa-f]+$") then
    error("Invalid hex color format")
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

local function with_alpha(hex, alpha)
  -- Validate inputs
  if not hex then
    error("with_alpha: hex color cannot be nil")
    return nil
  end
  if not alpha then
    error("with_alpha: alpha value cannot be nil")
    return nil
  end
  if type(alpha) ~= "number" then
    error("with_alpha: alpha must be a number between 0 and 1")
    return nil
  end

  -- Ensure hex starts with #
  hex = ensure_hash(hex)
  if not hex then
    error("with_alpha: invalid hex color format")
    return nil
  end

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
  local blended_r = blend(fr, br, alpha)
  local blended_g = blend(fg, bg, alpha)
  local blended_b = blend(fb, bb, alpha)

  -- Return blended color in #RRGGBB format
  return string.format("#%02x%02x%02x", blended_r, blended_g, blended_b)
end

-- === GLOBALS ===
local colors = {
  gui00 = "#282c34", -- Default Background
  gui01 = "#3b414d", -- #3f4451 Lighter Background (Status bars)
  gui02 = "#454a56", -- #4f5666 Selection Background
  gui03 = "#5d636f", -- #545862 Comments, Invisibles, Line Highlighting
  gui04 = "#878a98", -- #9196a1 Dark Foreground (Status bars)
  gui05 = "#acb2be", -- #abb2bf Default, Caret, Delimiters, Operators
  gui06 = "#dce0e5", -- #e6e6e6 Light Foreground (Not often used)
  gui07 = "#ffffff", -- Lightest Foreground (Not often used)
  gui08 = "#d07277", -- #e05561  Variables, XML Tags, Markup Links, Lists
  gui09 = "#bf956a", -- #d18f52 Integers, Boolean, XML Attributes
  gui0A = "#dfc184", -- #e6b965 Classes, Markup Bold, Search Background
  gui0B = "#a1c181", -- #8cc265 Strings, Inherited Class, Markup Code
  gui0C = "#6eb4bf", -- #42b3c2 Support, RegEx, Escape Chars, Quotes
  gui0D = "#74ade8", -- #4aa5f0 Functions, Methods, IDs, Headings
  gui0E = "#b477cf", -- #c162de Keywords, Storage, Selector, Markup
  gui0F = "#b1574b", -- #bf4034 Deprecated Methods and Functions
  gui10 = "#21252b", -- Darker Background
  gui11 = "#181a1f", -- The Darkest Background
  gui12 = "#ff616e", -- Red
  gui13 = "#f0a45d", -- Yellow
  gui14 = "#a5e075", -- Green
  gui15 = "#4cd1e0", -- Cyan
  gui16 = "#4dc4ff", -- Blue
  gui17 = "#de73ff", -- Purple
  gui18 = "#2e343e", -- Surface
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

local defaults = {
  guifg = colors.gui05,
  guibg = colors.gui00,
  ctermfg = colors.cterm05,
  ctermbg = colors.cterm00,
  -- from zed theme
  ui = {
    background = colors.gui01,
    surface = {
      background = colors.gui18,
    },
    element = {
      background = colors.gui01,
      hover = colors.gui01,
      active = colors.gui02,
      selected = colors.gui02,
      disabled = colors.gui18,
    },
  },
  element = {
    statusbar = {
      background = colors.gui01,
    },
    titlebar = {
      background = colors.gui01,
      inactive = colors.gui18,
    },
    toolbar = {
      background = colors.gui00,
    },
    tabbar = {
      background = colors.gui18,
      active = colors.gui00,
      inactive = colors.gui18,
    },
    panel = {
      background = colors.gui18,
    },
    search = {
      match = "#74ade866",
    },
  },
  editor = {
    foreground = colors.gui05,
    background = colors.gui00,
    gutter = {
      background = colors.gui08,
    },
    subheader = {
      background = colors.gui18,
    },
    line = {
      active = with_alpha(colors.gui0D, 0.24),
      highlighted = with_alpha(colors.gui0D, 0.24),
      number = {
        base = "#4e5a5f",
        active = "#d0d4da",
        hover = "#acb0b4",
      },
    },
    invisible = colors.gui04,
  },
  text = {
    base = colors.gui06,
    muted = colors.gui05,
    placeholder = colors.gui04,
    disabled = colors.gui04,
    accent = colors.gui0D,
  },
  icon = {
    base = colors.gui06,
    muted = colors.gui05,
    placeholder = colors.gui04,
    disabled = colors.gui04,
    accent = colors.gui0D,
  },
  border = {
    base = "#464b57",
    variant = "#363c46",
    focused = "#47679e",
    selected = "#293b5b",
    transparent = "NONE",
    disabled = "#414754",
  },
  hint = "#788CA6",
  predictive = "#5a6a87",
  delimiter = "#b2b9c6",
}

-- === HIGHLIGHT UTILITIES ===
local function hl(group, opts)
  if type(group) ~= "string" then
    error("highlight group must be a string")
    return
  end

  -- Handle linking if opts is a string or has link property
  if type(opts) == "string" then
    vim.api.nvim_set_hl(0, group, { link = opts })
    return
  end

  -- Set defaults
  opts = vim.tbl_extend("keep", opts or {}, {
    fg = nil,
    bg = nil,
    sp = nil,
    ctermfg = nil,
    ctermbg = nil,
    attr = nil,
    link = nil,
  })

  -- Handle link option
  if opts.link then
    vim.api.nvim_set_hl(0, group, { link = opts.link })
    return
  end

  -- Get default background color
  local default_bg = colors.gui00

  -- Pre-process background color first
  if opts.bg then
    if opts.bg == "NONE" then
      -- Case 1: bg is "NONE" - keep as is
      opts.bg = "NONE"
    elseif #opts.bg == 9 then
      -- Case 4: bg has alpha - blend with default
      opts.bg = blend_color(opts.bg, default_bg)
    else
      -- Case 3: bg is regular hex - ensure proper format
      opts.bg = ensure_hash(opts.bg)
    end
  end
  -- Case 2: bg not provided - remains nil

  -- Then process foreground color
  if opts.fg then
    if opts.fg == "NONE" then
      -- Case 5: fg is "NONE" - keep as is
      opts.fg = "NONE"
    elseif #opts.fg == 9 then
      -- Case 8,9: fg has alpha - blend with bg or default
      local blend_bg = opts.bg ~= "NONE" and opts.bg or default_bg
      opts.fg = blend_color(opts.fg, blend_bg)
    else
      -- Case 7: fg is regular hex - ensure proper format
      opts.fg = ensure_hash(opts.fg)
    end
  end
  -- Case 6: fg not provided - remains nil

  -- Process special color (sp) for undercurl/underline
  if opts.sp then
    if opts.sp == "NONE" then
      opts.sp = "NONE"
    else
      opts.sp = ensure_hash(opts.sp)
    end
  end

  local hl_opts = {
    fg = opts.fg,
    bg = opts.bg,
    sp = opts.sp,
    ctermfg = opts.ctermfg and tonumber(opts.ctermfg) or nil,
    ctermbg = opts.ctermbg and tonumber(opts.ctermbg) or nil,
    bold = opts.bold or false,
    italic = opts.italic or false,
    underline = opts.underline or false,
    undercurl = opts.undercurl or false,
    strikethrough = opts.strikethrough or false,
    reverse = opts.reverse or false,
    standout = opts.standout or false,
    nocombine = opts.nocombine or false,
  }

  -- Apply attributes from attr string if present
  if opts.attr and opts.attr ~= "NONE" then
    for _, a in ipairs(vim.split(opts.attr, ",")) do
      hl_opts[a] = true
    end
  end

  -- Apply highlight safely
  vim.api.nvim_set_hl(0, group, hl_opts)
end

local function link(from, to)
  vim.api.nvim_set_hl(0, from, { link = to })
end

-- === HIGHLIGHT GROUPS ===
local function setup_editor_highlights()
  -- vim editor
  hl("Yank", { bg = defaults.editor.line.highlighted })
  hl("ColorColumn", { bg = with_alpha(colors.gui01, 0.2), ctermbg = colors.cterm01 })
  hl("Conceal", { fg = colors.gui0D, ctermfg = colors.cterm0D })
  hl("CurSearch", { fg = defaults.guibg, bg = colors.gui0D, ctermfg = defaults.ctermbg, ctermbg = colors.cterm0D })
  hl("Cursor", { fg = defaults.guibg, bg = colors.gui0D })
  link("lCursor", "Cursor")
  link("CursorIM", "Cursor")
  hl("CursorColumn", { bg = with_alpha(colors.gui01, 0.2) })
  hl("CursorLine", { bg = with_alpha(colors.gui01, 0.2) })
  hl("Directory", { fg = colors.gui0D, ctermfg = colors.cterm0D })
  hl(
    "EndOfBuffer",
    { fg = defaults.guibg, bg = defaults.transparent, ctermfg = defaults.ctermfg, ctermbg = defaults.transparent }
  )
  hl("ErrorMsg", { fg = colors.gui08, ctermfg = colors.cterm08 })
  hl("WinSeparator", { fg = colors.gui01, bg = defaults.guibg, ctermfg = colors.cterm01, ctermbg = defaults.ctermbg })

  hl("Folded", { fg = colors.gui0D, bg = defaults.guibg, ctermfg = colors.cterm0D, ctermbg = defaults.ctermbg })
  hl(
    "FoldColumn",
    { fg = colors.gui01, bg = defaults.transparent, ctermfg = colors.cterm01, ctermbg = defaults.transparent }
  )
  hl(
    "SignColumn",
    { fg = colors.gui01, bg = defaults.transparent, ctermfg = colors.cterm01, ctermbg = defaults.transparent }
  )
  link("IncSearch", "CurSearch")
  link("Substitute", "Search")
  hl("LineNr", {
    fg = defaults.editor.line.number.base,
    bg = defaults.transparent,
    ctermfg = colors.cterm02,
    ctermbg = defaults.transparent,
  })
  link("LineNrAbove", "LineNr")
  link("LineNrBelow", "LineNr")
  hl("CursorLineNr", {
    fg = defaults.editor.line.number.active,
    bg = defaults.guibg,
    ctermfg = defaults.ctermfg,
    ctermbg = defaults.ctermbg,
    bold = true,
  })
  hl("CursorLineFold", { fg = colors.gui01, bg = defaults.guibg, ctermfg = colors.cterm01, ctermbg = defaults.ctermbg })
  link("CursorLIneSign", "SignColumn")
  hl("MatchParen", { bg = defaults.editor.line.active })
  hl("ModeMsg", { fg = colors.gui05, ctermfg = colors.cterm05 })
  link("MsgArea", "None")
  link("MsgSeparator", "WinSeparator")
  hl("MoreMsg", { fg = colors.gui0B, ctermfg = colors.cterm0B })
  hl("NonText", { fg = colors.gui03, ctermfg = colors.cterm03 })
  hl("Normal", { fg = defaults.guifg, bg = defaults.guibg, ctermfg = defaults.ctermfg, ctermbg = defaults.ctermbg })
  hl("NormalFloat", { fg = colors.gui06, bg = colors.gui01, ctermfg = colors.cterm06, ctermbg = colors.cterm01 })
  hl(
    "FloatBorder",
    { fg = defaults.border.base, bg = colors.transparent, ctermfg = colors.cterm06, ctermbg = colors.transparent }
  )
  link("FloatTitle", "Title")
  link("FloatFooter", "FloatTitle")
  link("NormalNC", "None")
  hl("PMenu", { fg = colors.gui05, bg = colors.gui01, ctermfg = colors.cterm05, termbg = colors.cterm01 })
  hl("PMenuSel", { fg = colors.gui06, bg = colors.gui02, ctermfg = colors.cterm06, termbg = colors.cterm02 })
  link("PMenuKind", "PMenu")
  link("PMenuKindSel", "PMenuSel")
  link("PMenuExtra", "PMenu")
  link("PMenuExtraSel", "PMenuSel")
  hl("PMenuSbar", { bg = colors.gui03, ctermbg = colors.cterm03 })
  hl("PMenuThumb", { bg = colors.gui04, ctermbg = colors.cterm04 })
  hl("PMenuMatch", { fg = colors.gui0C, ctermfg = colors.cterm0C })
  hl("PMenuMatchSel", { fg = colors.gui15, bg = colors.gui02, ctermfg = colors.cterm15, ctermbg = colors.cterm02 })
  hl("Search", { bg = defaults.element.search.match, ctermbg = colors.cterm0D })
  link("SnippetTabstop", "Visual")
  hl("SpecialKey", { fg = colors.gui03, ctermfg = colors.cterm03 })
  hl("Question", { fg = colors.gui0D, ctermfg = colors.cterm0D })
  hl("QuickFixLine", { bg = colors.gui01, ctermbg = colors.cterm01 })
  hl("StatusLine", { fg = colors.gui04, bg = colors.gui01, ctermfg = colors.cterm04, ctermbg = colors.cterm01 })
  hl("StatusLineNC", { fg = colors.gui03, bg = colors.gui01, ctermfg = colors.cterm03, ctermbg = colors.cterm01 })
  link("StatusLineTerm", "StatusLine")
  link("StatusLineTermNC", "StatusLineNC")
  link("TabLine", "StatusLine")
  hl("TabLineSel", { fg = colors.gui01, bg = colors.gui04, ctermfg = colors.cterm01, ctermbg = colors.cterm04 })
  link("TabLineFill", "StatusLine")
  hl("Title", { fg = colors.gui0D, ctermfg = colors.cterm0D })
  hl("Visual", { bg = with_alpha(colors.gui0D, 0.36) })
  -- hl("Visual", { bg = colors.gui02, ctermbg = colors.cterm02 })
  link("VisualNOS", "Visual")
  hl("WarningMsg", { fg = colors.gui09, ctermfg = colors.cterm09 })
  hl("Whitespace", { fg = colors.gui04, ctermfg = colors.cterm04 })
  hl("WildMenu", { fg = defaults.guibg, bg = colors.gui05, ctermfg = defaults.ctermbg, ctermbg = colors.cterm05 })
  link("WinBar", "StatusLine")
  link("WinBarNC", "StatusLineNC")
  -- spelling
  hl("SpellBad", { sp = colors.gui08, undercurl = true, ctermfg = "", ctermbg = colors.cterm12 })
  hl("SpellLocal", { sp = colors.gui15, undercurl = true, ctermfg = "", ctermbg = colors.cterm15 })
  hl("SpellCap", { sp = colors.gui16, undercurl = true, ctermfg = "", ctermbg = colors.cterm16 })
  hl("SpellRare", { sp = colors.gui0E, undercurl = true, ctermfg = "", ctermbg = colors.cterm0E })
  -- vim terminal
  hl("TermCursor", { fg = defaults.guibg, bg = colors.gui0D, ctermfg = defaults.ctermbg, ctermbg = colors.cterm0D })
  hl("TermCursorNC", { fg = colors.gui04, bg = colors.gui01, ctermfg = colors.cterm04, ctermbg = colors.cterm01 })
  -- vim diff
  hl("DiffAdd", { fg = colors.gui14, bg = colors.gui01, ctermfg = colors.cterm14, ctermbg = colors.cterm01 })
  hl("DiffChange", { fg = colors.gui04, bg = colors.gui01, ctermfg = colors.cterm04, ctermbg = colors.cterm01 })
  hl("DiffDelete", { fg = colors.gui02, bg = colors.guibg, ctermfg = colors.cterm02, ctermbg = colors.ctermbg })
  hl("DiffText", { fg = colors.gui16, bg = colors.gui01, ctermfg = colors.cterm16, ctermbg = colors.cterm01 })
end

local function setup_standard_syntax_highlights()
  hl("Comment", { fg = colors.gui03, ctermfg = colors.cterm03 })
  hl("Constant", { fg = colors.gui09, ctermfg = colors.cterm09 })
  hl("String", { fg = colors.gui0B, ctermfg = colors.cterm0B })
  hl("Character", { fg = colors.gui0C, ctermfg = colors.cterm0C })
  hl("Number", { fg = colors.gui09, ctermfg = colors.cterm09 })
  hl("Boolean", { fg = colors.gui09, ctermfg = colors.cterm09 })
  hl("Float", { fg = colors.gui09, ctermfg = colors.cterm09 })
  -- spec wants Identifier mapped to base08
  hl("Identifier", { fg = colors.gui06, ctermfg = colors.cterm06 })
  hl("Function", { fg = colors.gui0D, ctermfg = colors.cterm0D })
  hl("Statement", { fg = colors.gui0E, ctermfg = colors.cterm0E, bold = true })
  hl("Conditional", { fg = colors.gui0E, ctermfg = colors.cterm0E })
  hl("Repeat", { fg = colors.gui0E, ctermfg = colors.cterm0E })
  hl("Label", { fg = colors.gui0E, ctermfg = colors.cterm0E })
  hl("Operator", { fg = colors.gui0C, ctermfg = colors.cterm0C })
  link("Keyword", "Statement")
  hl("Exception", { fg = colors.gui0E, ctermfg = colors.cterm0E })
  hl("PreProc", { fg = colors.gui0C, ctermfg = colors.cterm0C })
  hl("Include", { fg = colors.gui0C, ctermfg = colors.cterm0C })
  hl("Define", { fg = colors.gui0C, ctermfg = colors.cterm0C })
  hl("Macro", { fg = colors.gui0C, ctermfg = colors.cterm0C })
  hl("PreCondit", { fg = colors.gui0C, ctermfg = colors.cterm0C })
  hl("Type", { fg = colors.gui0A, ctermfg = colors.cterm0A })
  hl("StorageClass", { fg = colors.gui0A, ctermfg = colors.cterm0A })
  hl("Structure", { fg = colors.gui0A, ctermfg = colors.cterm0A })
  hl("Typedef", { fg = colors.gui0A, ctermfg = colors.cterm0A })
  hl("Special", { fg = colors.gui0C, ctermfg = colors.cterm0C })
  hl("SpecialChar", { fg = colors.gui0A, ctermfg = colors.cterm0A })
  hl("Tag", { fg = colors.gui09, ctermfg = colors.cterm09 })
  hl("Delimiter", { fg = colors.gui05, ctermfg = colors.cterm05 })
  hl("SpecialComment", { fg = colors.gui0A, ctermfg = colors.cterm0A })
  hl("Debug", { fg = colors.gui08, ctermfg = colors.cterm08 })
  hl("Underlined", { underline = true })
  link("Ignore", "Normal")
  hl("Error", { fg = colors.gui08, bg = colors.guibg, ctermfg = colors.cterm08, ctermbg = colors.ctermbg, bold = true })
  hl("Todo", { fg = colors.gui0C, ctermfg = colors.cterm0C })
  hl("Added", { fg = colors.gui14, ctermfg = colors.cterm14 })
  hl("Changed", { fg = colors.gui16, ctermfg = colors.cterm16 })
  hl("Removed", { fg = colors.gui12, ctermfg = colors.cterm12 })
end

local function setup_treesitter_highlights()
  link("@variable", "Identifier")
  hl("@variable.builtin", { fg = colors.gui05, ctermfg = colors.cterm05 })
  link("@variable.parameter", "Identifier")
  link("@variable.parameter.builtin", "@variable.builtin")
  hl("@variable.member", { fg = colors.gui04, ctermfg = colors.cterm04 })
  link("@constant", "Constant")
  hl("@constant.builtin", { fg = colors.gui09, ctermfg = colors.cterm09 })
  link("@constant.macro", "Constant")
  link("@module", "Identifier")
  hl("@module.builtin", { fg = colors.gui05, ctermfg = colors.cterm05 })
  link("@label", "Tag")
  link("@string", "String")
  link("@string.documentation", "String")
  link("@string.regexp", "SpecialComment")
  link("@string.escape", "SpecialComment")
  link("@string.special", "SpecialComment")
  link("@string.special.symbol", "SpecialComment")
  hl("@string.special.path", { fg = colors.gui0D, ctermfg = colors.cterm0D })
  hl("@string.special.url", { fg = colors.gui08, ctermfg = colors.cterm08 })
  link("@character", "Character")
  link("@character.special", "SpecialChar")
  link("@boolean", "Boolean")
  link("@number", "Number")
  link("@number.float", "Float")
  link("@type", "Type")
  hl("@type.builtin", { fg = colors.gui0A, ctermfg = colors.cterm0A })
  link("@type.definition", "Typedef")
  link("@attribute", "Special")
  hl("@attribute.builtin", { fg = colors.gui0C, ctermfg = colors.cterm0C })
  link("@property", "@variable.member")
  hl("@function", { fg = colors.gui16, ctermfg = colors.cterm16 })
  hl("@function.builtin", { fg = colors.gui16, ctermfg = colors.cterm16 })
  link("@function.call", "@function")
  link("@function.macro", "Macro")
  link("@function.method", "Function")
  link("@function.method.call", "@function.method")
  hl("@constructor", { fg = colors.gui0D, ctermfg = colors.cterm0D, bold = false })
  link("@operator", "Operator")
  link("@keyword", "Keyword")
  link("@keyword.coroutine", "Repeat")
  link("@keyword.function", "Keyword")
  link("@keyword.operator", "Operator")
  hl("@keyword.import", { fg = colors.gui0E, ctermfg = colors.cterm0E })
  link("@keyword.type", "Keyword")
  link("@keyword.modifier", "Repeat")
  link("@keyword.repeat", "Repeat")
  link("@keyword.return", "Keyword")
  link("@keyword.debug", "Debug")
  link("@keyword.exception", "Exception")
  link("@keyword.conditional", "Conditional")
  link("@keyword.ternary", "Conditional")
  link("@keyword.directive", "PreProc")
  link("@keyword.directive.define", "Define")
  link("@punctuation.delimiter", "Delimiter")
  link("@punctuation.bracket", "Delimiter")
  link("@punctuation.special", "Special")
  link("@comment", "Comment")
  link("@comment.documentation", "Comment")
  hl("@comment.error", { fg = colors.gui08, ctermfg = colors.cterm08 })
  hl("@comment.warning", { fg = colors.gui09, ctermfg = colors.cterm09 })
  hl("@comment.note", { fg = colors.gui0D, ctermfg = colors.cterm0D })
  hl("@comment.todo", { fg = colors.gui0C, ctermfg = colors.cterm0C })
  hl("@markup.strong", { bold = true })
  hl("@markup.italic", { italic = true })
  hl("@markup.strikethrough", { strikethrough = true })
  hl("@markup.underline", { underline = true })
  link("@markup.heading", "Title")
  link("@markup.quote", "String")
  link("@markup.math", "Special")
  hl("@markup.link", { fg = colors.gui08, ctermfg = colors.cterm08 })
  link("@markup.link.label", "@markup.link")
  link("@markup.link.url", "Identifier")
  hl("@markup.raw", { fg = colors.gui04, ctermfg = colors.cterm04 })
  link("@markup.raw.block", "Identifier")
  link("@markup.list", "SpecialChar")
  link("@markup.list.checked", "DiagnosticOk")
  link("@markup.list.unchecked", "DiagnosticError")
  link("@diff.plus", "Added")
  link("@diff.minus", "Removed")
  link("@diff.delta", "Changed")
  link("@tag", "Tag")
  hl("@tag.builtin", { fg = colors.gui09, ctermfg = colors.cterm09 })
  link("@tag.attribute", "Special")
  link("@tag.delimiter", "Delimiter")
end

local function setup_semantic_tokens_highlights()
  link("@lsp.type.class", "@type")
  link("@lsp.type.comment", "@comment")
  link("@lsp.type.decorator", "@attribute")
  link("@lsp.type.enum", "@type")
  link("@lsp.type.enumMember", "@constant")
  link("@lsp.type.event", "@type")
  link("@lsp.type.function", "@function")
  link("@lsp.type.interface", "@type")
  link("@lsp.type.keyword", "@keyword")
  link("@lsp.type.macro", "@function.macro")
  link("@lsp.type.method", "@function.method")
  link("@lsp.type.modifier", "@type.modifier")
  link("@lsp.type.namespace", "@module")
  link("@lsp.type.number", "@number")
  link("@lsp.type.operator", "@operator")
  link("@lsp.type.parameter", "@variable.parameter")
  link("@lsp.type.property", "@property")
  link("@lsp.type.regexp", "@string.regexp")
  link("@lsp.type.string", "@string")
  link("@lsp.type.struct", "@type")
  link("@lsp.type.type", "@type")
  link("@lsp.type.typeParameter", "@variable.parameter")
  link("@lsp.type.variable", "@variable")
  link("@lsp.mod.defaultLibrary", "None")
  link("@lsp.mod.deprecated", "DiagnosticDeprecated")
  -- RUST
  link("@lsp.type.builtinType.rust", "@type.builtin")
  link("@lsp.type.escapeSequence.rust", "@string.escape")
  link("@lsp.type.formatSpecifier.rust", "@operator")
  link("@lsp.type.lifetime.rust", "@attribute")
  link("@lsp.type.punctuation.rust", "@punctuation.delimiter")
  link("@lsp.type.selfKeyword.rust", "@variable.builtin")
  link("@lsp.type.selfTypeKeyword.rust", "@type.builtin")
  link("@lsp.mod.attribute", "None")
  link("@lsp.mod.controlFlow", "@keyword.repeat")
  link("@lsp.mod.intraDocLink.rust", "@markup.link")
  link("@lsp.typemod.generic.injected.rust", "@variable")
  link("@lsp.typemod.operator.controlFlow.rust", "@operator")
  link("@lsp.typemod.function.associated.rust", "@function.method")
  -- LUA
  link("@lsp.typemod.keyword.documentation.lua", "@tag")
  -- MARKDOWN
  link("@lsp.type.class.markdown", "@lsp")
  -- NOT SYNTAX
  link("LspReferenceText", "Search")
  hl("LspReferenceRead", { bg = colors.gui14, fg = colors.gui01, ctermbg = colors.cterm14, ctermfg = colors.cterm01 })
  hl("LspReferenceWrite", { bg = colors.gui12, fg = colors.gui01, ctermbg = colors.cterm12, ctermfg = colors.cterm01 })
  link("LspCodeLens", "NonText")
  link("LspCodeLensSeparator", "LspCodeLens")
  link("LspInlayHint", "NonText")
  link("LspSignatureActiveParameter", "Visual")
end

local function setup_diagnostics_highlights()
  hl("DiagnosticError", { fg = colors.gui08, ctermfg = colors.cterm08 })
  hl("DiagnosticWarn", { fg = colors.gui09, ctermfg = colors.cterm09 })
  hl("DiagnosticInfo", { fg = colors.gui0C, ctermfg = colors.cterm0C })
  hl("DiagnosticHint", { fg = colors.gui0D, ctermfg = colors.cterm0D })
  hl("DiagnosticOk", { fg = colors.gui0B, ctermfg = colors.cterm0B })
  hl(
    "DiagnosticUnderlineError",
    { sp = colors.gui08, ctermbg = defaults.ctermbg, ctermfg = colors.cterm08, underline = true }
  )
  hl(
    "DiagnosticUnderlineWarn",
    { sp = colors.gui09, ctermbg = defaults.ctermbg, ctermfg = colors.cterm09, underline = true }
  )
  hl(
    "DiagnosticUnderlineInfo",
    { sp = colors.gui0C, ctermbg = defaults.ctermbg, ctermfg = colors.cterm0C, underline = true }
  )
  hl(
    "DiagnosticUnderlineHint",
    { sp = colors.gui0D, ctermbg = defaults.ctermbg, ctermfg = colors.cterm0D, underline = true }
  )
  hl(
    "DiagnosticUnderlineOk",
    { sp = colors.gui0B, ctermbg = defaults.ctermbg, ctermfg = colors.cterm0B, underline = true }
  )

  hl(
    "DiagnosticFloatingError",
    { fg = colors.gui08, bg = colors.gui01, ctermfg = colors.cterm08, ctermbg = colors.cterm01 }
  )
  hl(
    "DiagnosticFloatingWarn",
    { fg = colors.gui09, bg = colors.gui01, ctermfg = colors.cterm09, ctermbg = colors.cterm01 }
  )
  hl(
    "DiagnosticFloatingInfo",
    { fg = colors.gui0C, bg = colors.gui01, ctermfg = colors.cterm0C, ctermbg = colors.cterm01 }
  )
  hl(
    "DiagnosticFloatingHint",
    { fg = colors.gui0D, bg = colors.gui01, ctermfg = colors.cterm0D, ctermbg = colors.cterm01 }
  )
  hl(
    "DiagnosticFloatingOk",
    { fg = colors.gui0B, bg = colors.gui01, ctermfg = colors.cterm0B, ctermbg = colors.cterm01 }
  )
  hl("DiagnosticDeprecated", { ctermfg = colors.cterm0F, ctermbg = colors.cterm0F, strikethrough = true })
  link("DiagnosticUnnecessary", "Comment")
end

local function setup_syntax_files_highlights()
  -- C
  hl("cOperator", { fg = colors.gui0C, ctermfg = colors.cterm0C })
  hl("cPreCondit", { fg = colors.gui0E, ctermfg = colors.cterm0E })
  -- CSS
  hl("cssBraces", { fg = colors.gui05, ctermfg = colors.cterm05 })
  hl("cssClassName", { fg = colors.gui0E, ctermfg = colors.cterm0E })
  hl("cssColor", { fg = colors.gui0C, ctermfg = colors.cterm0C })
  -- C#
  hl("csClass", { fg = colors.gui0A, ctermfg = colors.cterm0A })
  hl("csAttribute", { fg = colors.gui0A, ctermfg = colors.cterm0A })
  hl("csModifier", { fg = colors.gui0E, ctermfg = colors.cterm0E })
  hl("csType", { fg = colors.gui08, ctermfg = colors.cterm08 })
  hl("csUnspecifiedStatement", { fg = colors.gui0D, ctermfg = colors.cterm0D })
  hl("csContextualStatement", { fg = colors.gui0E, ctermfg = colors.cterm0E })
  hl("csNewDecleration", { fg = colors.gui08, ctermfg = colors.cterm08 })
  -- Git
  hl("GitAddSign", { fg = colors.gui14, ctermfg = colors.cterm14 })
  hl("GitChangeSign", { fg = colors.gui04, ctermfg = colors.cterm04 })
  hl("GitDeleteSign", { fg = colors.gui12, ctermfg = colors.cterm12 })
  hl("GitChangeDeleteSign", { fg = colors.gui12, ctermfg = colors.cterm12 })
  -- Gitcommit
  hl("gitcommitOverflow", { fg = colors.gui08, ctermfg = colors.cterm08 })
  hl("gitcommitSummary", { fg = colors.gui0B, ctermfg = colors.cterm0B })
  hl("gitcommitComment", { fg = colors.gui03, ctermfg = colors.cterm03 })
  hl("gitcommitUntracked", { fg = colors.gui03, ctermfg = colors.cterm03 })
  hl("gitcommitDiscarded", { fg = colors.gui03, ctermfg = colors.cterm03 })
  hl("gitcommitSelected", { fg = colors.gui03, ctermfg = colors.cterm03 })
  hl("gitcommitHeader", { fg = colors.gui17, ctermfg = colors.cterm17 })
  hl("gitcommitSelectedType", { fg = colors.gui16, ctermfg = colors.cterm16 })
  hl("gitcommitUnmergedType", { fg = colors.gui16, ctermfg = colors.cterm16 })
  hl("gitcommitDiscardedType", { fg = colors.gui16, ctermfg = colors.cterm16 })
  hl("gitcommitBranch", { fg = colors.gui13, ctermfg = colors.cterm13, bold = true })
  hl("gitcommitUntrackedFile", { fg = colors.gui0A, ctermfg = colors.cterm0A })
  hl("gitcommitUnmergedFile", { fg = colors.gui08, ctermfg = colors.cterm08, bold = true })
  hl("gitcommitDiscardedFile", { fg = colors.gui08, ctermfg = colors.cterm08, bold = true })
  hl("gitcommitSelectedFile", { fg = colors.gui0B, ctermfg = colors.cterm0B, bold = true })
  -- Gitsigns
  hl("GitSignsAddInline", { fg = colors.gui01, bg = colors.gui14, ctermfg = colors.cterm01, ctermbg = colors.cterm14 })
  hl(
    "GitSignsAddLnInline",
    { fg = colors.gui01, bg = colors.gui14, ctermfg = colors.cterm01, ctermbg = colors.cterm14 }
  )
  hl("GitSignsAddPreview", { fg = colors.gui14, bg = colors.gui01, ctermfg = colors.cterm14, ctermbg = colors.cterm01 })
  hl(
    "GitSignsDeleteInline",
    { fg = colors.gui01, bg = colors.gui12, ctermfg = colors.cterm01, ctermbg = colors.cterm12 }
  )
  hl(
    "GitSignsDeleteLnInline",
    { fg = colors.gui01, bg = colors.gui12, ctermfg = colors.cterm01, ctermbg = colors.cterm12 }
  )
  hl(
    "GitSignsDeleteVirtLn",
    { fg = colors.gui12, bg = colors.gui01, ctermfg = colors.cterm12, ctermbg = colors.cterm01 }
  )
  hl(
    "GitSignsDeletePreview",
    { fg = colors.gui12, bg = colors.gui01, ctermfg = colors.cterm12, ctermbg = colors.cterm01 }
  )
  hl(
    "GitSignsChangeInline",
    { fg = colors.gui01, bg = colors.gui14, ctermfg = colors.cterm01, ctermbg = colors.cterm14 }
  )
  hl(
    "GitSignsChangeLnInline",
    { fg = colors.gui01, bg = colors.gui16, ctermfg = colors.cterm01, ctermbg = colors.cterm16 }
  )
  hl("GitSignsCurrentLineBlame", { fg = defaults.hint })
  -- HTML
  hl("htmlBold", { fg = colors.gui05, ctermfg = colors.cterm0A, bold = true })
  hl("htmlItalic", { fg = colors.gui05, ctermfg = colors.cterm17 })
  hl("htmlEndTag", { fg = colors.gui05, ctermfg = colors.cterm05 })
  hl("htmlTag", { fg = colors.gui05, ctermfg = colors.cterm05 })
  -- JavaScript
  hl("javaScript", { fg = colors.gui05, ctermfg = colors.cterm05 })
  hl("javaScriptBraces", { fg = colors.gui05, ctermfg = colors.cterm05 })
  hl("javaScriptNumber", { fg = colors.gui09, ctermfg = colors.cterm09 })
  -- Mail
  hl("mailQuoted1", { fg = colors.gui0A, ctermfg = colors.cterm0A })
  hl("mailQuoted2", { fg = colors.gui0B, ctermfg = colors.cterm0B })
  hl("mailQuoted3", { fg = colors.gui0E, ctermfg = colors.cterm0E })
  hl("mailQuoted4", { fg = colors.gui0C, ctermfg = colors.cterm0C })
  hl("mailQuoted5", { fg = colors.gui0D, ctermfg = colors.cterm0D })
  hl("mailQuoted6", { fg = colors.gui0A, ctermfg = colors.cterm0A })
  hl("mailURL", { fg = colors.gui0D, ctermfg = colors.cterm0D })
  hl("mailEmail", { fg = colors.gui0D, ctermfg = colors.cterm0D })
  -- Markdown
  hl("markdownCode", { fg = colors.gui0B, ctermfg = colors.cterm0B })
  hl("markdownError", { fg = colors.gui05, bg = colors.guibg, ctermfg = colors.cterm05, ctermbg = colors.ctermbg })
  hl("markdownCodeBlock", { fg = colors.gui0B, ctermfg = colors.cterm0B })
  hl("markdownHeadingDelimiter", { fg = colors.gui0D, ctermfg = colors.cterm0D })
  -- PHP
  hl("phpMemberSelector", { fg = colors.gui05, ctermfg = colors.cterm05 })
  hl("phpComparison", { fg = colors.gui05, ctermfg = colors.cterm05 })
  hl("phpParent", { fg = colors.gui05, ctermfg = colors.cterm05 })
  hl("phpMethodsVar", { fg = colors.gui0C, ctermfg = colors.cterm0C })
  -- Python
  hl("pythonOperator", { fg = colors.gui0E, ctermfg = colors.cterm0E })
  hl("pythonRepeat", { fg = colors.gui0E, ctermfg = colors.cterm0E })
  hl("pythonInclude", { fg = colors.gui0E, ctermfg = colors.cterm0E })
  hl("pythonStatement", { fg = colors.gui0E, ctermfg = colors.cterm0E })
  -- Ruby
  hl("rubyAttribute", { fg = colors.gui0D, ctermfg = colors.cterm0D })
  hl("rubyConstant", { fg = colors.gui0A, ctermfg = colors.cterm0A })
  hl("rubyInterpolationDelimiter", { fg = colors.gui0F, ctermfg = colors.cterm0F })
  hl("rubyRegexp", { fg = colors.gui0C, ctermfg = colors.cterm0C })
  hl("rubySymbol", { fg = colors.gui0B, ctermfg = colors.cterm0B })
  hl("rubyStringDelimiter", { fg = colors.gui0B, ctermfg = colors.cterm0B })
  -- SASS
  hl("sassidChar", { fg = colors.gui08, ctermfg = colors.cterm08 })
  hl("sassClassChar", { fg = colors.gui09, ctermfg = colors.cterm09 })
  hl("sassInclude", { fg = colors.gui0E, ctermfg = colors.cterm0E })
  hl("sassMixing", { fg = colors.gui0E, ctermfg = colors.cterm0E })
  hl("sassMixinName", { fg = colors.gui0D, ctermfg = colors.cterm0D })
  -- Java
  hl("javaOperator", { fg = colors.gui0D, ctermfg = colors.cterm0D })
end

local function setup_plugins_highlights()
  -- CMP
  link("CmpItemAbbrDeprecated", "Deprecated")
  link("CmpItemAbbrMatch", "PMenuMatch")
  link("CmpItemAbbrMatchFuzzy", "PMenuMatch")
  link("CmpItemKindClass", "@lsp.type.class")
  link("CmpItemKindColor", "@lsp.type.keyword")
  link("CmpItemKindConstant", "@constant")
  link("CmpItemKindConstructor", "@constructor")
  link("CmpItemKindEnum", "@lsp.type.enum")
  link("CmpItemKindEnumMember", "@lsp.type.enumMember")
  link("CmpItemKindEvent", "@lsp.type.event")
  link("CmpItemKindField", "@lsp.type.property")
  link("CmpItemKindFile", "@string.special.path")
  link("CmpItemKindFolder", "@string.special.path")
  link("CmpItemKindFunction", "@lsp.type.function")
  link("CmpItemKindInterface", "@lsp.type.interface")
  link("CmpItemKindKeyword", "@lsp.type.keyword")
  link("CmpItemKindMethod", "@lsp.type.method")
  link("CmpItemKindModule", "@lsp.type.namespace")
  link("CmpItemKindOperator", "@lsp.type.operator")
  link("CmpItemKindProperty", "@lsp.type.property")
  link("CmpItemKindReference", "@lsp.type.variable")
  link("CmpItemKindSnippet", "@lsp.type.string")
  link("CmpItemKindStruct", "@lsp.type.struct")
  link("CmpItemKindText", "@lsp.type.string")
  link("CmpItemKindTypeParameter", "@lsp.type.typeParameter")
  link("CmpItemKindUnit", "@lsp.type.namespace")
  link("CmpItemKindValue", "@constant")
  link("CmpItemKindVariable", "@lsp.type.variable")
  -- LAZY
  hl("LazyNormal", { fg = defaults.guifg, bg = defaults.transparent })
  -- MASON
  hl("MasonNormal", { fg = defaults.guifg, bg = defaults.transparent })
  hl("MasonBackdrop", { bg = colors.gui00 })
  -- SNACKS
  hl("SnacksBackdrop", { bg = colors.gui00 })
  hl("SnacksNormal", { bg = defaults.ui.surface.background, fg = defaults.guifg })
  hl("SnacksPicker", { bg = defaults.ui.surface.background, fg = defaults.guifg })
  hl("SnacksPickerTitle", { bg = defaults.ui.surface.background, fg = colors.gui05 })
  hl("SnacksPickerBorder", { bg = defaults.ui.surface.background, fg = defaults.border.base })
  hl("SnacksPickerPrompt", { fg = colors.gui0B, bg = defaults.ui.surface.background })
  hl("SnacksPickerListCursorLine", { bg = defaults.editor.line.active })
  -- MISC
  hl("MiniCursorword", { bg = defaults.editor.line.active })
  hl("VirtColumn", { fg = with_alpha(colors.gui05, 0.10) })
  -- BUFFERLINE
  -- hl("BufferLineBackground", { fg = defaults.guifg, bg = defaults.ui.surface.background })
end

local function setup_zed_tweaks()
  -- SYNTAX HIGHLIGHTING
  hl("Special", { fg = colors.gui0D }) -- @attribute
  hl("Boolean", { fg = colors.gui09, ctermfg = colors.cterm09 }) -- @boolean
  hl("Comment", { fg = colors.gui03, ctermfg = colors.cterm03 }) -- @comment
  hl("@comment.documentation", { fg = colors.gui04, ctermfg = colors.cterm04 }) -- @comment.documentation
  hl("Constant", { fg = colors.gui0A, ctermfg = colors.cterm0A }) -- @constant
  hl("@constructor", { fg = colors.gui0D, ctermfg = colors.cterm0D })
  hl("@embedded", { fg = colors.gui06 })
  hl("Italic", { fg = colors.gui0D }) -- @emphasis
  hl("@emphasis", "Italic") -- Link to Itali
  hl("Bold", { fg = colors.gui09, bold = true }) -- @emphasis.strong
  hl("@emphasis.strong", "Bold") -- Link to Bold
  hl("@enum", { fg = colors.gui08 })
  hl("Function", { fg = colors.gui0D, ctermfg = colors.cterm0D })
  hl("@function", "Function") -- Link to Function
  hl("@hint", { fg = defaults.hint, bold = true })
  hl("Statement", { fg = colors.gui0E, ctermfg = colors.cterm0E }) -- Keyword
  hl("@keyword", "Statement") -- Link to Statement
  hl("@keyword.import", "@keyword") -- Link to @keyword
  hl("Tag", { fg = colors.gui0D, ctermfg = colors.cterm0D }) -- @tag
  hl("Label", "Tag") -- @label
  hl("Identifier", { fg = colors.gui06, cftermfg = colors.cterm06 }) -- @variable
  hl("@link_text", { fg = colors.gui0D, italic = true })
  hl("@link_uri", { fg = colors.gui0C })
  hl("Number", { fg = colors.gui09, ctermfg = colors.cterm09 }) -- @number
  hl("Operator", { fg = colors.gui0C, ctermfg = colors.cterm0C }) -- @operator
  hl("@predictive", { fg = defaults.predictive, italic = true })
  hl("PreProc", { fg = colors.gui05, ctermfg = colors.cterm05 }) -- @preproc
  hl("@preproc", "PreProc") -- Link to PreProc
  hl("@primary", { fg = colors.gui05 })
  hl("@variable.member", { fg = colors.gui08, ctermfg = colors.cterm08 }) -- @property
  hl("Delimiter", { fg = colors.gui05, ctermfg = colors.cterm05 }) -- @punctuation
  hl("@punctuation.bracket", { fg = defaults.delimiter, ctermfg = colors.gui06 })
  hl("@punctuation.delimiter", { fg = defaults.delimiter, ctermfg = colors.gui06 })
  hl("@punctuation.list_marker", { fg = colors.gui08, ctermfg = colors.cterm08 })
  hl("@punctuation.special", { fg = colors.gui0F, ctermfg = colors.cterm0F })
  hl("String", { fg = colors.gui0B, ctermfg = colors.cterm0B }) -- @string
  hl("@string.escape", { fg = colors.gui04, ctermfg = colors.cterm04 })
  hl("@string.regex", { fg = colors.gui09, ctermfg = colors.cterm09 })
  hl("@string.special", { fg = colors.gui09, ctermfg = colors.cterm09 })
  hl("@string.special.symbol", { fg = colors.gui09, ctermfg = colors.cterm09 })
  hl("@string.special.url", "@link_uri")
  hl("@string.special.path", "@link_text")
  hl("@text.literal", { fg = colors.gui0B, ctermfg = colors.cterm0B }) -- @string
  hl("Title", { fg = colors.gui08, ctermfg = colors.cterm08 }) -- @string
  hl("@title", "Title") -- Link to Title
  hl("Type", { fg = colors.gui0C, ctermfg = colors.cterm0C }) -- @type
  hl("@variable", { fg = colors.gui06, ctermfg = colors.cterm06 })
  hl("@variable.special", { fg = colors.gui09, ctermfg = colors.cterm09 })
  hl("@variant", { fg = colors.gui0D, ctermfg = colors.cterm0D })
end

function M.setup()
  setup_editor_highlights()
  setup_standard_syntax_highlights()
  setup_treesitter_highlights()
  setup_semantic_tokens_highlights()
  setup_diagnostics_highlights()
  setup_syntax_files_highlights()
  setup_plugins_highlights()
  setup_zed_tweaks()
end

-- === EXPORTS ===
M.colors = colors
M.defaults = defaults
M.hl = hl
M.link = link

return M

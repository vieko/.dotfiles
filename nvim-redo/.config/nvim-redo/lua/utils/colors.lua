local function to_hex(color)
  if type(color) == "number" then
    return string.format("#%06X", color) -- Convert number to uppercase hex
  elseif type(color) == "string" and color:match("^#?%x%x%x%x%x%x$") then
    return "#" .. color:gsub("#", ""):upper() -- Ensure '#' prefix & uppercase
  end
  return "#AAAAAA" -- Fallback if nil or unexpected type
end

return {
  to_hex = to_hex,
}

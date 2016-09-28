local M, module = {}, ...

function M.decode(chunk)
  package.loaded[module]=nil
  if #chunk < 2 then return end
  local second = string.byte(chunk, 2)
  local len = bit.band(second, 0x7f)
  local offset
  if len == 126 then
    if #chunk < 4 then return end
    len = bit.bor(
      bit.lshift(string.byte(chunk, 3), 8),
      string.byte(chunk, 4))
    offset = 4
  elseif len == 127 then
    if #chunk < 10 then return end
    len = bit.bor(
      -- Ignore lengths longer than 32bit
      bit.lshift(string.byte(chunk, 7), 24),
      bit.lshift(string.byte(chunk, 8), 16),
      bit.lshift(string.byte(chunk, 9), 8),
      string.byte(chunk, 10))
    offset = 10
  else
    offset = 2
  end
  local mask = bit.band(second, 0x80) > 0
  if mask then
    offset = offset + 4
  end
  if #chunk < offset + len then return end

  local first = string.byte(chunk, 1)
  local payload = string.sub(chunk, offset + 1, offset + len)
  assert(#payload == len, "Length mismatch")
  if mask then
    payload = crypto.mask(payload, string.sub(chunk, offset - 3, offset))
  end
  local extra = string.sub(chunk, offset + len + 1)
  local opcode = bit.band(first, 0xf)
  return extra, payload, opcode
end

return M
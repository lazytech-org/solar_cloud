local M, module = {}, ...

function M.encode(mess, opcode)
  package.loaded[module]=nil
  local opcode = opcode or 2
--      assert(type(opcode) == "number", "opcode must be number")
--      assert(type(mess) == "string", "payload must be string")
  local head = string.char(
    bit.bor(0x80, opcode),
    bit.bor(#mess < 126 and #mess or #mess < 0x10000 and 126 or 127)
  )
  if #mess >= 0x10000 then
    head = head .. string.char(
    0,0,0,0, -- 32 bit length is plenty, assume zero for rest
    bit.band(bit.rshift(#mess, 24), 0xff),
    bit.band(bit.rshift(#mess, 16), 0xff),
    bit.band(bit.rshift(#mess, 8), 0xff),
    bit.band(#mess, 0xff)
  )
  elseif #mess >= 126 then
    head = head .. string.char(bit.band(bit.rshift(#mess, 8), 0xff), bit.band(#mess, 0xff))
  end
  collectgarbage()
  return head .. mess
end

return M
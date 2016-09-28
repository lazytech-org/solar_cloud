local M, module = {}, ...

M.dpulses = 0

function M.read_temp(sname, pin, addr, _tab)
  ow.reset(pin)
  ow.select(pin, addr)
  ow.write(pin, 0x44, 1)
--  tmr.alarm(pin + 1, 1000 * (pin -1), tmr.ALARM_SINGLE, function () read_pin(sname, pin, addr, _tab) end)
end

function M.read_reg(dev_addr, len, ...)
  package.loaded[module]=nil
  i2c.start(0)
  i2c.address(0, dev_addr, i2c.TRANSMITTER)
  i2c.write(0, ...)
  i2c.stop(0)
  i2c.start(0)
  i2c.address(0, dev_addr, i2c.RECEIVER)
  local c = i2c.read(0, len)
  i2c.stop(0)
  return c
end

function M.read_pw(...)
  return
end

function M.read_pow(sname, pin, _tab)
  local val = M.read_reg(0x48, 2, 0)
  local u = 0
  local t = 0
  if (string.byte(val) > 127) then
    u = ((255 - string.byte(val)) * 256 - (255 - string.byte(val, 2)) * 1024) / 32768
  else
    u = ((string.byte(val) * 256 + string.byte(val, 2)) * 1024) / 32768
  end
  -- t = u * 12 / 10 -- 12 volts x 10 ampères / 1000
  t = u * conf.phot_volts / conf.phot_amp
  print("wH: " .. t)
  local m = 0
  for i, v in ipairs(_tab) do
    if i < 5 then
      _tab[i] = _tab[i+1]
      m =  m + _tab[i]
    --print(_tab[i])
    else
      _tab[i] = t
      m = m + t
    end
  end
  newVal[sname] = m/5
end

function M.read_dm(sname, pin, ignored, _tab)
  local t = 0
  M.dpulses = 0
  --local _tab = data
  gpio.mode(pin, gpio.INT)    
  
  local function pulseadd(level)
    M.dpulses = M.dpulses + 1
    gpio.trig(pin, level == gpio.HIGH  and "down" or "up")
  end
  
--  tmr.alarm(5, 1000, tmr.ALARM_SINGLE, update_data)
  gpio.trig(pin, "down", pulseadd)
end

function M.read_dpin(sname, pin, _tab)
  local t = 0
  gpio.trig(pin)
  -- print("pulses= " .. dpulses)
  t = (M.dpulses * 10) / 75
  print("liters/h= " .. t)
  local m = 0
    for i, v in ipairs(_tab) do
      if i < 5 then
        _tab[i] = _tab[i+1]
        m =  m + _tab[i]
      --print(_tab[i])
      else
        _tab[i] = t
        m = m + t
      end
    end
-- Uncomment for test
---[[
  if pumping and m < 5 then
    m = 100
  end
--]]
  newVal[sname] = m/5
  if ((m/5) > 0) and (lastRead["temp_stock"] ~= nil) then
    if lastRead["temp_therm"] ~= nil then
      local val = ((m/5) * (lastRead["temp_therm"] - lastRead["temp_stock"]) * 1163) / 1000
      if val < 0 then val = 0 end
      newVal["ptherm"] = val
      if produced then
        produced = produced + (val /100)
        newVal["produced"] = produced
        print("produced: " .. produced)
      end
    end
    if lastRead["temp_hyb"] ~= nil then
      local val = ((m/5) * (lastRead["temp_hyb"] - lastRead["temp_stock"]) * 1163) / 1000
      if val < 0 then val = 0 end
      newVal["phyb"] = val
      if produced then
        produced = produced + (val / 100)
        newVal["produced"] = produced
        print("produced: " .. produced)
      end
    end
  end
end

function M.read_tpin(sname, pin, addr, _tab)
  -- print("reading")
  local t = 0
  ow.reset(pin)
  ow.select(pin, addr)
  ow.write(pin,0xBE,1)
  local data = nil
  data = string.char(ow.read(pin))
  for i = 1, 8 do
    data = data .. string.char(ow.read(pin))
  end
  local crc = ow.crc8(string.sub(data,1,8))
  if crc == data:byte(9) then
    t = (data:byte(1) + data:byte(2) * 256) * 625
    t1 = t / 10000
    t2 = t % 10000
    print(sname .. " Temperature="..t1.."."..t2.." C")
    t = t1
  else
    newVal[sname] = 0
    newVal["errors"] = newVal["errors"] + 1
    if tmr.state(3) == nil then
      tmr.alarm(3, 10000, tmr.ALARM_SINGLE, function () require("setup").init() end)
    end
    return
  end
  local m = 0
  for i, v in ipairs(_tab) do
    if i < 5 then
      _tab[i] = _tab[i+1]
      m =  m + _tab[i]
      --print(_tab[i])
    else
      _tab[i] = t
      m = m + t
    end
  end
  newVal[sname] = m/5            
end

function M.collect_data()
  --print("collecting")
  package.loaded[module]=nil
  busy = busy + 1
  for fct, _sensors in pairs(readers) do
    for sname, params in pairs(_sensors) do
      if dpins[1] == params[1] then
        M.read_dpin(sname, params[1], params[3])
      elseif ppins[1] == params[1] then
        M.read_pow(sname,params[1], params[3])
      else
        for _, p in pairs(tpins) do
          if params[1] == p then
            M.read_tpin(sname, params[1], params[2], params[3])
            break
          end
         end
      end
    end
  end
  collectgarbage()
  busy = busy - 1
end

function M.check_values()
  package.loaded[module]=nil
  tmr.softwd(90)
  busy = busy + 1
  if uptime then
    uptime[4] = uptime[4] + conf.interval
    if uptime[4] > 59 then
      uptime[3] = uptime[3] + 1
      uptime[4] = uptime[4] - 60
      if uptime[3] > 59 then
        uptime[2] = uptime[2] + 1
        uptime[3] = 0
        if uptime[2] > 23 then
          uptime[1] = uptime[1] + 1
          uptime[2] = 0
        end
      end
    end
    newVal["uptime"] = uptime
    print("uptime: " .. uptime[4])
  end
  for key, value in pairs(newVal) do
    if ((lastRead[key] ~= value) or key == "uptime") then
      if dataToSend == nil then
        dataToSend = {}
      end
      dataToSend[key] = value
      lastRead[key] = value
    end
  end
  local armed = false
  for fct, _sensors in pairs(readers) do
    for _name, params in pairs(_sensors) do
      if (not armed) and (dpins[1] == params[1]) then
        armed = true
        --print("armed")
        tmr.alarm(2, 1000, tmr.ALARM_SINGLE, function() require("sensors").collect_data() end)
      end
      M[fct](_name, params[1], params[2], params[3])
    end
  end
  collectgarbage()
  busy = busy - 1
end

return M

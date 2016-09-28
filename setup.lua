local M, module = {}, ...

function M.init()
  package.loaded[module]=nil
  local sensor_errors = 0
  --missing = false
  tmr.unregister(0)
  gpio.mode(conf.srpumppin, gpio.OUTPUT)
  gpio.write(conf.srpumppin, gpio.LOW)
  gpio.mode(conf.srevpin, gpio.OUTPUT)
  gpio.write(conf.srevpin, gpio.LOW)
  gpio.mode(conf.srrespin, gpio.OUTPUT)
  gpio.write(conf.srrespin, gpio.LOW)
  newVal["heating"] = 0
  newVal["pumping"] = 0
  newVal["ptherm"] = 0
  newVal["hybrid"] = 0
  newVal["phyb"] = 0
  print("Entering sensors setup...")
  print('power sensor')
  i2c.setup(0, conf.ads_sda, conf.ads_scl, i2c.SLOW)
  local i2c_config = require("sensors").read_reg(0x48, 2, 1)
  if string.byte(i2c_config, 1) == 255 then
    print("Power sensor not found...")
  else
    i2c_config = require("sensors").read_reg(0x48, 2, 1, 215, 3) -- 1101 0111 0000 0011
    ppins[1] = conf.ads_sda
    readers["read_pw"]["wH"] = {conf["ads_sda"], nil, powphot}
  end
  -- i2c_config = require("sensors").read_reg(0x48, 2, 1, 199, 3)
  print("Temp sensors")
  for pin_name, tmp in pairs({["tstockpin"] = {tempstock, "temp_stock"},
                              ["tthermpin"] = {temptherm, "temp_therm"},
                              ["thybpin"] = {temphyb, "temp_hyb"}}) do
    ow.setup(conf[pin_name])
    local count = 0
    local addr
    repeat
      count = count + 1
      addr = ow.reset_search(conf[pin_name])
      addr = ow.search(conf[pin_name])
      tmr.wdclr()
    until (addr ~= nil) or (count > 100)
    if addr == nil then
      print("No sensor found for " .. pin_name)
      newVal[tmp[2]] = 0
      sensor_errors = sensor_errors + 1
    else
      local crc = ow.crc8(string.sub(addr,1,7))
      if crc == addr:byte(8) then
        if (addr:byte(1) == 0x10) or (addr:byte(1) == 0x28) then
          readers["read_temp"][tmp[2]] = {conf[pin_name], addr, tmp[1]}
          print("sensor " .. tmp[2] .. " found")
          local found = false
          for i, p in ipairs(tpins) do
            if conf[pin_name] == p then
              found = true
            end
          end
          if not found then
            tpins[#tpins +1] = conf[pin_name]
          end
        else
          print("Sensor " .. tmp[2] .. " nor recognized")
          sensor_errors = sensor_errors + 1
        end
      else
        print("Bad crc for sensor " .. tmp[2])
        sensor_errors = sensor_errors + 1
      end
    end
  end
  print("Flow sensor")
  if (conf["dmpin"] ~= nil) and (dpins[1] ~= conf["dmpin"]) then
    dpins[1] = conf["dmpin"]
    readers["read_dm"]["liters_by_hour"] = {conf["dmpin"], nil, dm}
    print("Set Flow Sensor (pin " .. conf["dmpin"] .. ")")
  end
  if sensor_errors > 0 then
    tmr.alarm(3, 30000, tmr.ALARM_SINGLE, function () require("setup").init() end)
    print("Not all sensors detected, scheduling new discovery in 30s")
  end
  newVal["errors"] = sensor_errors
  tmr.alarm(0, conf.interval * 1000, tmr.ALARM_AUTO, function () if busy > 1 then return end require("sensors").check_values() end)
  if not started then
    started = true
    tmr.alarm(4, conf.delay_min * 3000, tmr.ALARM_AUTO, function () if busy > 2 then return end require("system").manage() end)
  end
  collectgarbage()
end

return M
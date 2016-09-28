local M, module = {}, ...

function M.manage()
  package.loaded[module]=nil
  busy = busy + 1
  local wsta = wifi.sta.status()
  print("manage")
  if wsta == 0 then
    if wifi.sta.getip() == nil then
      print("try to connect")
      wifi.sta.connect()
    end
  end
  if wsta ~= 5 then
    print("not connected")
    if wifi_mode == 1 then
      node.restart()
      return
    end
  else
    print("Connected")
    if wifi_mode == 0 then
      node.restart()
      return
    end
  end
  if lastRead["errors"] > 2 then
    print("Not enough sensors, skipping")
    collectgarbage()
    busy = busy - 1
    return
  end
  if newVal["temp_stock"] ~= nil and newVal["temp_therm"] ~= nil then
    if pumping then
      if (newVal["temp_therm"] - newVal["temp_stock"]) < 1 then
        print("stopping pump")
        newVal["pumping"] = 0
        newVal["ptherm"] = 0
        gpio.write(conf.srpumppin, gpio.LOW)
        pumping = false
        if hyb_on then
          print("Disabling hybrid panel")
          gpio.write(conf.srevpin, gpio.LOW)
          hyb_on = false
          newVal["hybrid"] = 0
          newVal["phyb"] = 0
        end
      end
    elseif (newVal["temp_therm"] - newVal["temp_stock"]) > 4 then
        print("starting pump")
        pumping = true
        newVal["pumping"] = 1
        gpio.write(conf.srpumppin, gpio.HIGH)
        if (newVal["temp_therm"] > conf.consign + 5) and heating then
          print("cutting supply resistance")
          gpio.write(conf.srrespin, gpio.LOW)
          heating = false
          newVal["heating"] = 0
        end
    end
    if (newVal["temp_stock"] < conf.consign) and (not heating) then
      print("Starting supply resistance")
      gpio.write(conf.srrespin, gpio.HIGH)
      heating = true
      newVal["heating"] = 1
    elseif (newVal["temp_stock"] > conf.consign) and heating then
      print("Stopping supply resistance")
      gpio.write(conf.srrespin, gpio.LOW)
      heating = false
      newVal["heating"] = 0
    end
    if (newVal["temp_hyb"] ~= nil) then
      if (not hyb_on) and (newVal["temp_hyb"] - newVal["temp_stock"]) > 4 then
        print("Activating hybrid panel")
        gpio.write(conf.srevpin, gpio.HIGH)
        hyb_on = true
        newVal["hybrid"] = 1
      elseif hyb_on and ((newVal["temp_hyb"] - newVal["temp_stock"]) < 0) then
        print("Disabling hybrid panel")
        gpio.write(conf.srevpin, gpio.LOW)
        hyb_on = false
        newVal["hybrid"] = 0
      end
    end
  end
  collectgarbage()
  busy = busy - 1
end
 
return M

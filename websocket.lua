local M, module = {}, ...


  

function M.onMessage(payload, opcode, socket)
  package.loaded[module]=nil
  
  local sent = false
  
  local function write_conf()
    print("write conf")
    if file.open('config.json', "w") then
      file.writeline(cjson.encode(conf))
      file.close()
    else
      print("Write config failed\n")
    end
  end

  local function send_scan(t)
    local s = {wifi_scan = {}}
    local i = 0
    local min = {0, ""}
    for bssid,v in pairs(t) do
        local ssid, rssi, authmode, channel = string.match(v, "([^,]+),([^,]+),([^,]+),([^,]*)")
        if i < 5 then
          i = i + 1
          s["wifi_scan"][ssid] = {tonumber(rssi),tonumber(authmode)}
        else
          socket.send(require("wsencode").encode(cjson.encode(s), 1))
          sent = true
          s = {wifi_scan = {}}
          i = 0
        end
    end
    if i > 0 then
      socket.send(require("wsencode").encode(cjson.encode(s), 1))
    end
--      tmr.alarm(6, 500, tmr.ALARM_SINGLE, socket.purge)
    --print(cjson.encode(s))
    collectgarbage()
--    socket.send(cjson.encode(s), 1)
  end
  
  if opcode == 1 then
    if payload:find("{+.}?") then -- json
      local t_ = cjson.decode(payload)
      for k, t in pairs(t_) do
        if k == "conf" then
          print("conf")
          if socket.auth then
            print("auth")
            if t == "{}" then
              print("sending config")
              socket.send(require("wsencode").encode(cjson.encode(conf), 1))
              sent = true
            else
              print("set config")
              local w = false
              for k, v in pairs(t) do
                print(k)
                if conf[k] ~= nil then
                  w = true
                  if tonumber(v) ~= nil then
                    conf[k] = tonumber(v)
                  else
                    conf[k] = v
                  end
                elseif k == "wifi" then
                  if t["wifi"]["ssid"] then
                    local ssid, password, bssid_set, bssid = wifi.sta.getconfig()
                    conf.wifissid = ssid
                    conf.wifipwd = password
                    write_conf()
                    if t["wifi"]["pwd"] then
                      if #t["wifi"]["pwd"] < 8 then
                        print("bad pwd")
                        socket.send(require("wsencode").encode('{"error": "key length"}', 1))
                        sent = true
                      else
                        wifi.sta.config(t["wifi"]["ssid"], t["wifi"]["pwd"])
                        print("wifi configured")
                      end
                    else
                      wifi.sta.config(t["wifi"]["ssid"])
                    end
--                    tmr.alarm(6, 15000, tmr.ALARM_SINGLE, function () 
--                      local s = wifi.sta.status()
--                      print(s)
--                      if not (s == 5 or s == 4) then
--                        print("wifi config failed")
--                        wifi.sta.config(ssid, password)
--                      else
--                        print("wifi OK")
--                        conf.wifissid = nil
--                        conf.wifipwd = nil
--                        write_conf()
--                      end
--                      ssid = nil
--                      password = nil
--                      bssid_set = nil
--                      bssid = nil
--                    end)
                  else
                    print("scanning")
                    local status, err = pcall(function () wifi.sta.getap(1, send_scan) end)
                    if not status then
                      wifi.setmode(wifi.STATIONAP)
                      local status, err = pcall(function () wifi.sta.getap(1, send_scan) end)
                      if not status then
                        socket.send(require("wsencode").encode('{"wifi_scan": {}}', 1))
                      end
                    end
                    collectgarbage()
                  end
                end
              end
              print(w)
              if w then
                write_conf()
              end
            end
         else
          if t ~= "{}" then
            for key, val in pairs(t) do
              if key == "pass" then
                print(val)
                if val == "5e884898da28047151d0e56f8dc6292773603d0d6aabbdd62a11ef721d1542d8" then
                  socket.auth = true
                  socket.send(require("wsencode").encode('{"auth": true}', 1))
                  sent = true
                  return
                end
              end
            end
          end
          --socket.send(require("wsencode").encode("Not Authorized", 1))
        end
        end
        collectgarbage()
      end
    elseif payload == "ls" then
      local list = file.list()
      local lines = {}
      for k, v in pairs(list) do
        lines[#lines + 1] = k .. ": " .. v
--            print(k)
      end
      socket.send(require("wsencode").encode(table.concat(lines, "\n"), 1))
      sent = true
      return
    elseif payload == "bye" then
      socket.close()
    else
      print("unknown: " .. payload)
      socket.send(require("wsencode").encode("unknown command\n", 1))
      sent = true
    end
  end
--  if not sent then
--    busy = busy - 1
--  end
  collectgarbage()
end


return M
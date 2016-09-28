print("LazyTech/Solable SolarCloud")
print(node.heap())
wifi_mode = 0
local ap = wifi.ap.getip()
local dns = nil
if ap then
    print(wifi.ap.getip())
    uptime = {0,0,0,0}
    produced = 0
--    print(node.heap())
--    local i1,i2,i3,i4=ap:match("(%d+)%.(%d+)%.(%d+)%.(%d+)")
--    local x00=string.char(0)
--    local x01=string.char(1)
--    dns_str1=string.char(128)..x00..x00..x01..x00..x01..x00..x00..x00..x00
--    local dns_str2=x00..x01..x00..x01..string.char(192)..string.char(12)..x00..x01..x00..x01..x00..x00..string.char(3)..x00..x00..string.char(4)
--    local dns_strIP=string.char(i1)..string.char(i2)..string.char(i3)..string.char(i4)
--    strEnd = dns_str2 .. dns_strIP
--    print(node.heap())
--    print(node.heap())
else
    wifi_mode = 1
    local ip = wifi.sta.getip()
    print(ip)
    tmr.alarm(1, 30000, tmr.ALARM_AUTO, function ()
      if busy > 1 then
        return
      end
      require("http_client").post()
      collectgarbage()
    end)
    local i = 0
    for v in string.gmatch(ip, "%d+") do
      i = i + 1
      newVal["ip" .. i] = v
    end
    i = nil
    ip = nil
end

collectgarbage()
print(node.heap())

--if wifi_mode == 0 then
--  dns = net.createServer(net.UDP,10)
--  dns:listen(53)
--  dns:on("receive", function(c, data) if busy > 1 then return end require("dns_liar").receive(c, data) end)
--  print("DNS Server is now listening")
--end

local ws = net.createServer(net.TCP, 120):listen(conf.port, function(c) 
  if busy < 3 + wifi_mode then
    require("webserver").listen(c, 60)
  else
    c:on("sent", function () c:close() end)
    c:send("HTTP/1.1 429 Too Many requests\r\nConnection: Close\r\n\r\n")
  end
  collectgarbage()
end)

print(node.heap())


-- Board Setup
--  wifi.sta.config("CEEI-Wifi-Access","c33i-W1F1")
--  wifi.sta.config("VF8125","fuyez pauvres fous")
newVal = {}
lastRead = {errors = 0}
tempstock = {0,0,0,0,0}
temptherm = {0,0,0,0,0}
temphyb = {0,0,0,0,0}
dm = {0,0,0,0,0}
powgen = {0,0,0,0,0}
powphot = {0,0,0,0,0}
readers = {read_temp = {}, read_dm = {}, read_pw = {}}
ppins = {}
tpins = {}
dpins = {}
ppins = {}
busy = 0
started = false

local compileAndRemoveIfNeeded = function(f)
   if file.open(f) then
      file.close()
      print('Compiling:', f)
      node.compile(f)
      file.remove(f)
      collectgarbage()
   end
end

local write_conf = function (f, t)
  if file.open(f, "w") then
    file.writeline(cjson.encode(t))
    file.close()
  else
    print("Write " .. f .. " failed")
  end
end

local serverFiles = {
   'dns_liar.lua',
   'main.lua',
   'system.lua',
   'sensors.lua',
   'webserver.lua',
   'websocket.lua',
   'wsencode.lua',
   'wsdecode.lua',
   'ws_check.lua',
   'http_client.lua',
   'setup.lua'
}
for i, f in ipairs(serverFiles) do compileAndRemoveIfNeeded(f) end

compileAndRemoveIfNeeded = nil
serverFiles = nil
collectgarbage()
if file.open('config.json', "r") then
  local ok
  ok, conf = pcall(function () return cjson.decode(file.readline()) end)
  file.close()
  if not ok then
    file.remove('config.json')
    print("bad config file reset to default config")
    tmr.alarm(0, 500, tmr.ALARM_SINGLE, node.restart)
  end
else
  conf = {host = "http://emoncms.org",
          consign = 40,
          interval = 6,
          tstockpin = 3,
          apssid = "Solar_Cloud",
          tthermpin = 1,
          thybpin = 2,
          ads_sda = 4,
          ads_scl = 5,
          phot_pin = 1,
          phot_volts = 12,
          phot_amp = 10,
          dmpin = 7,
          srpumppin = 0,
          srevpin = 6,
          srrespin = 8,
          delta_t = 4,
          delay_min = 15,
          port = 80}
  write_conf("config.json", conf)
end
if file.open('secret.json', "r") then
  secret = cjson.decode(file.readline())
  file.close()
else
  secret = {apikey = "YOUR EMON CMS API KEY HERE",
            appwd = "lazytech",
            admpwd = "password"}
  write_conf("secret.json", secret)
end

require("setup").init()
print(node.heap())

wifi.setmode(wifi.STATIONAP)
attempts = 20

tmr.alarm(6,1000,1,function()
  ip = wifi.sta.getip()
  attempts = attempts - 1
  if ip or attempts < 1 then
    tmr.unregister(6)
    attemps = nil
    if not ip then
      if conf.wifissid ~= nil then
        print("restoring old wifi settings")
        if conf.wifipwd ~= nil then
          wifi.sta.config(conf.wifissid, conf.wifipwd)
        else
          wifi.sta.config(conf.wifissid)
        end
      end
      cfg={}
      cfg.ssid=conf.apssid
      cfg.pwd=secret.appwd
      cfg.auth=wifi.AUTH_WPA_PSK
      wifi.ap.config(cfg)
    else
      wifi.setmode(wifi.STATION)
    end
    if conf.wifissid ~= nil then
      conf.wifissid = nil
      conf.wifipwd = nil
      write_conf("config.json", conf)
    end
    write_conf = nil
    local s,err = pcall(function() dofile("main.lc") end)
    if not s then print(err) end
  end
end)
tmr.softwd(90)
collectgarbage()
print(node.heap())


    

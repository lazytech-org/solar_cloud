local M, module = {}, ...

function M.listen(c, t)
    print("Incoming Connection")
    package.loaded[module]=nil
    local conn = c
    busy = busy +1
    local buffer = nil
    local socket = {}
    local response = {}
    local sending = false
    local _file = nil
    local wsclose = false
    local filelist = {["index.html"] = "text/html; charset=utf-8", ["admin.html"] = "text/html; charset=utf-8",
                      ["background.svg"] = "image/svg+xml", ["style.css"] = "text/css",
                      ["icons.png"] = "image/png", ["admin.js"] = "application/javascript",
                      ["sha256.min.js"] = "application/javascript", ["AvenirLTStd-Book.otf"] = "application/font-sfnt",
                      ["AvenirLTStd-Black.otf"] = "application/font-sfnt",
                      ["Calculator.ttf"] = "application/x-font-ttf",["favicon.ico"] = "image/x-icon"}
        
    local function send_many()
      print('M')
      conn:send(table.remove(response, 1))
    end
        
    function socket.purge()
      print("p?")
      sending = false
      if #response > 0 then
        print("P!")
        send_many()
      end
    end
    
    function socket.send(data)
      response[#response +1] = data
      if sending then
        print("b")
      else
        sending = true
        send_many()
      end
      collectgarbage()
    end
    
    function socket.close()
      wsclose = true
      print("closing")
      socket.send(require("wsencode").encode("bye", 8))
    end
    
    
    local function send_file()
      -- Try to send file as fast without filling all memory
      print("F")
      file.open(_file[1])
      file.seek("set", _file[2])
      local size = 1024 -- max
      if busy > 1 then
        size = 1024 / busy
      else
        if busy < 1 then
          print("wtf?")
          busy = 1
        end
      end
      local b = file.read(size) 
      if #b < size then
        _file = nil
        if wifi_mode == 0 then
          wifi.setmode(wifi.STATIONAP)
        end
      else
        _file[2] = _file[2] + size
      end
      file.close()
      conn:send(b)
      b = nil
      size = nil
    end
    
    local function serve_file(fname, mime, compressed)
      print("Serving: " .. fname .. " mimetype is: " .. mime)
      if wifi_mode == 0 then
        if wifi.getmode() == wifi.STATIONAP then
          wifi.setmode(wifi.SOFTAP)
        end
      end
      local realname
      if compressed then
        realname = "_" .. fname .. ".gz"
      else
        realname = "_" .. fname
      end
      if file.exists(realname) then
        tmr.softwd(120)
        sending = true
        _file = {realname, 0}
        response = {"HTTP/1.1 200 OK\r\n"}
        response[#response + 1] = "Server: Lazytech-MiniHTTP\r\n"
        response[#response + 1] = "Content-Type:" .. mime .. "\r\n"
        if compressed then
          response[#response + 1] = "Cache-Control: max-age=2592000\r\nContent-Encoding: gzip\r\n"
        else
          response[#response + 1] = "Cache-Control: private, no-store\r\n"
        end
        response[#response + 1] = "Connection: Close\r\n\r\n"
        send_many(conn, false)
      else
        print("File not found")
        conn:send("HTTP/1.1 404 Not Found\r\nConnection: Close\r\n\r\n")
        close = true
      end
    end
    
    conn:on('disconnection', function(c)
      if busy > 0 then
        busy = busy - 1
      end
      if buffer then
        print("websocket disconnected")
        wsconnected = false
        if wifi_mode == 0 then
          tmr.unregister(1)
        end
      else
        print("Request closed")
      end
      socket = nil
      conn = nil
      response = nil
      buffer = nil
      tmr.softwd(150)
      collectgarbage()
      end)
       
    conn:on('sent', function(connection, payload)
      if #response > 0 then
        send_many()
        collectgarbage()
      elseif _file then
        send_file()
        collectgarbage()
      else
        sending = false
        if not buffer then
          conn:close()
        else
          socket.purge()
          if wsclose then
            print("wsclose!")
            conn:close()
          end
        end
      end
      collectgarbage()
    end)

    conn:on("receive", function(_, chunk)
    
      local compressed = nil
      
      if buffer then
        buffer = buffer .. chunk
        while true do
          local extra, payload, opcode = require("wsdecode").decode(buffer)
          if not extra then return end
          buffer = extra
          require("websocket").onMessage(payload, opcode, socket)
        end
--        require("websocket").receive(socket, buffer)
        socket.purge()
      else
        local e = chunk:find("\r\n", 1, true)
        if not e then return nil end
        local line = chunk:sub(1, e - 1)
        local r = {}
        _, e, r.method, r.request = line:find("^([A-Z]+) (.-) HTTP/[1-9]+.[0-9]+$")
--        _, e, method = string.find(chunk, "([A-Z]+) /[^\r]* HTTP/%d%.%d\r\n")
        method = nil
--        local _, e, method, request = string.find(chunk, "([A-Z]+) /[^\r]* HTTP/[1-9]+.[0-9]+$")
        local key, name, value
        while true do
          _, e, name, value = string.find(chunk, "([^ ]+): *([^\r]+)\r\n", e + 1)
          if not e then break end
          if string.lower(name) == "sec-websocket-key" then
            r.key = value
          end
          if string.lower(name) == "accept-encoding" then
            for w in string.gmatch(value,"%a+") do
              if w == "gzip" then
                print("compressed")
                compressed = true
              end
            end
          end
        end
        if r.method == "GET" and r.key then
          local guid = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
          local function acceptKey(key)
            return crypto.toBase64(crypto.hash("sha1", key .. guid))
          end
          buffer = ''
          if wsconnected then
            if busy > 0 then
              busy = busy -1 -- try to serve severall ws connections ...
            end
          else
            wsconnected = true
          end
          sending = true
          socket.send("HTTP/1.1 101 Switching Protocols\r\n")
          socket.send("Upgrade: websocket\r\n")
          socket.send("Connection: Upgrade\r\n")
          socket.send("Sec-WebSocket-Accept: " .. acceptKey(r.key) .. "\r\n")
          socket.send("\r\n")
          socket.purge()
          if wifi_mode == 0 then
            tmr.alarm(1, conf.interval * 2000, tmr.ALARM_AUTO, function () require("ws_check").check_data(socket) end)
          end
        else
          if r.method ~= "GET" then
            conn:on("sent", function(conn) conn:close() end)
            socket.send("HTTP/1.1 400 Bad Request\r\nConnection: Close\r\n\r\n")
          else
            print(r.request)
            if r.request == "/" then
              r.request = '/index.html'
            end
            r.request = string.sub(r.request,2)
            print(r.request)
            if filelist[r.request] then
              serve_file(r.request, filelist[r.request], compressed)
            else
              socket.send("HTTP/1.1 404 Not Found\r\nConnection: Close\r\n\r\n")
            end
          end
        end
      end
    collectgarbage()
  end)
end

return M
    
  

  










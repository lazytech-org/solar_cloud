local M, module = {}, ...

function M.check_data(socket)
  package.loaded[module]=nil
  if socket then
    if dataToSend then
        local data_str = cjson.encode(dataToSend)
        print("sending data: ")
        print(data_str)
        socket.send(require("wsencode").encode(data_str, 1))
        data_str = nil
        dataToSend = nil
    else
        print("nothing to send")
    end
    socket.purge()
  end
  if wifi.sta.status() == 5 then
    node.restart()
  end
end

return M
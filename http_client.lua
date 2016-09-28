local M, module = {}, ...

function M.post()
  package.loaded[module]=nil
  busy = busy + 1
  --print("http post")
  if dataToSend then
--    busy = true
    local params =  "/input/post.json?node=2&json=" .. cjson.encode(dataToSend) .. "&apikey=" .. secret.apikey
    print("sending: " .. params)
    http.post(conf.host .. params, nil, {}, function (code, data)
--      busy = false
      if code < 0 then
        print("request to http host failed")
      else
        for k, v in pairs(dataToSend) do
          if k ~= "ptherm" and k ~= "phyb" then
            dataToSend[k] = nil
          end
        end
        --dataToSend = nil
        --print('Sent')
      end
    end)
  else
    print("Nothing to send")
  end
  collectgarbage()
  busy = busy - 1
end

return M

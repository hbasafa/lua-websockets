#!/usr/bin/env lua
--- lua websocket equivalent to test-server.c from libwebsockets.
-- using lua-ev event loop

function run_websocket_server()
    package.path = '../src/?.lua;../src/?/?.lua;'..package.path
    local ev = require'ev'
    local websocket = require'websocket'
    local loop = ev.Loop.default
    

    -- websocket
    local server = websocket.server.ev.listen
    {
      protocols = {
        ['lws-mirror-protocol'] = function(ws)
          ws:on_message(
            function(ws,data,opcode)
              if opcode == websocket.TEXT then
                ws:broadcast(data)
              end
            end)
        end,
        ['dumb-increment-protocol'] = function(ws)

          ws:on_message(
            function(ws,message,opcode)
              if opcode == websocket.TEXT then
                if message:match('reset') then
                  print("websocket reset.")
                end
              end
            end)
          ws:on_close(
            function()
              print("websocket closed.")
            end)

          test_ubus(ws)
        end
      },
      port = 12345
    }

    print("Server is running...")
    loop:loop()


end

function test_ubus(ws)
  local ubus = require('ubus') 
  local uloop = require('uloop')
  local json = require('cjson')

  uloop.init()

  -- Establish connection
  local conn = ubus.connect()
  if not conn then
      error("Failed to connect to ubusd")
  end

  -- set events
  local events = {}

  events['phone'] = function(msg)
      ws:broadcast(tostring(msg))
  end

  events['phone.call'] = function(msg)
    if msg ~= nil and msg.method == "add_device" then
      ws:broadcast(json.encode(msg))
    end
  end

  conn:listen(events)
  uloop.run()
end

run_websocket_server()

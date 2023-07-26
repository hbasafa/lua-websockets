#!/usr/bin/env lua
-- lua websocket equivalent to test-server.c from libwebsockets.
-- using copas as server framework

function run_websocket_server()
    package.path = '../src/?.lua;../src/?/?.lua;'..package.path
    local copas = require'copas'
    local socket = require'socket'

    local clients = {}

    local websocket = require'websocket'
    local server = websocket.server.copas.listen
    {
      protocols = {
        ['lws-mirror-protocol'] = function(ws)
          while true do
            local msg,opcode = ws:receive()
            if not msg then
              ws:close()
              return
            end
            if opcode == websocket.TEXT then
              ws:broadcast(msg)
            end
          end
        end,
        ['dumb-increment-protocol'] = function(ws)
          clients[ws] = 0
          while true do
            local message,opcode = ws:receive()
            if not message then
              ws:close()
              clients[ws] = nil
              return
            end
            if opcode == websocket.TEXT then
              if message:match('reset') then
                clients[ws] = 0
              end
            end
          end
        end
      },
      port = 12345
    }

    -- this fairly complex mechanism is required due to the
    -- lack of copas timers...
    -- sends periodically the 'dumb-increment-protocol' count
    -- to the respective client.

    copas.addthread(
      function()
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
              for ws,number in pairs(clients) do
                ws:send(json.encode(msg))
              end
            end
          end
        
          conn:listen(events)
          uloop.run()
      end
    )

    print("Server is running...")
    copas.loop()


end

run_websocket_server()

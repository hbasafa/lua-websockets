#!/usr/bin/env lua
--- lua websocket equivalent to test-server.c from libwebsockets.
-- using lua-ev event loop

function run_websocket_server()
    package.path = '../src/?.lua;../src/?/?.lua;'..package.path
    local ev = require'ev'
    local ubus = require('ubus')
    local uloop = require('uloop')
    local websocket = require'websocket'

    -- ubus
    uloop.init()
    local conn = ubus.connect() 

    if not conn then
        error("Failed to connect to ubusd")
    end

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

          -- set events
          local events = {}

          print("hello")

          -- events['phone.call'] = function(msg)
          --   if msg ~= nil and msg.method ~= "add_device" then
          --     print(msg)
          --     ws:broadcast(msg)
          --   end
          -- end
          

          events['phone'] = function(msg)
              print(msg)
              ws:broadcast(msg)
          end
          conn:listen(events)

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
        end
      },
      port = 12345
    }

    print("Server is running...")
    uloop.run()

end

function test_ubus()
  local ubus, uloop = require('ubus'), require('uloop')

  uloop.init()

  -- Establish connection
  local conn = ubus.connect()
  if not conn then
      error("Failed to connect to ubusd")
  end

  -- set events
  local events = {}

  events['phone'] = function(msg)
      print(msg)
  end
  conn:listen(events)
  uloop.run()
end

-- run_websocket_server()
test_ubus()

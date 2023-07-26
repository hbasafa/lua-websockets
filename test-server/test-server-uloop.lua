#!/usr/bin/env lua
-- ## libubox-lua echo server
-- This implements a basic echo server via Websockets protocol. Once you are connected with the server, all messages you send will be returned ('echoed') by the server immediately.

package.path = '../src/?.lua;../src/?/?.lua;'..package.path

require'uloop'

local echo_handler = function(ws)
  local message = ws:receive()
  if message then
    ws:send(message)
  else
    ws:close()
    return
  end
end

uloop.init()

local server = require'websocket'.server.uloop.listen
{
  port = 8080,
  protocols = {
    echo = echo_handler
  },
  default = echo_handler
}
uloop.run()

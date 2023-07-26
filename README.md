
# About

This project provides Lua modules for [Websocket Version 13](http://tools.ietf.org/html/rfc6455) conformant clients and servers. 
[![Build Status](https://travis-ci.org/lipp/lua-websockets.svg?branch=master)](https://travis-ci.org/lipp/lua-websockets)
[![Coverage Status](https://coveralls.io/repos/lipp/lua-websockets/badge.png?branch=add-coveralls)](https://coveralls.io/r/lipp/lua-websockets?branch=master)

The minified version is only ~10k bytes in size.

Clients are available in three different flavours:

  - synchronous
  - coroutine based ([copas](http://keplerproject.github.com/copas))
  - asynchronous ([lua-ev](https://github.com/brimworks/lua-ev))

Servers are available as two different flavours:

  - coroutine based ([copas](http://keplerproject.github.com/copas))
  - asynchronous ([lua-ev](https://github.com/brimworks/lua-ev))


A webserver is NOT part of lua-websockets. If you are looking for a feature rich webserver framework, have a look at [orbit](http://keplerproject.github.com/orbit/) or others. It is no problem to work with a "normal" webserver and lua-websockets side by side (two processes, different ports), since websockets are not subject of the 'Same origin policy'.

# Usage
## copas echo server
This implements a basic echo server via Websockets protocol. Once you are connected with the server, all messages you send will be returned ('echoed') by the server immediately.

```lua
local copas = require'copas'

-- create a copas webserver and start listening
local server = require'websocket'.server.copas.listen
{
  -- listen on port 8080
  port = 8080,
  -- the protocols field holds
  --   key: protocol name
  --   value: callback on new connection
  protocols = {
    -- this callback is called, whenever a new client connects.
    -- ws is a new websocket instance
    echo = function(ws)
      while true do
        local message = ws:receive()
        if message then
           ws:send(message)
        else
           ws:close()
           return
        end
      end
    end
  }
}

-- use the copas loop
copas.loop()
```

## lua-ev echo server
This implements a basic echo server via Websockets protocol. Once you are connected with the server, all messages you send will be returned ('echoed') by the server immediately.

```lua
local ev = require'ev'

-- create a copas webserver and start listening
local server = require'websocket'.server.ev.listen
{
  -- listen on port 8080
  port = 8080,
  -- the protocols field holds
  --   key: protocol name
  --   value: callback on new connection
  protocols = {
    -- this callback is called, whenever a new client connects.
    -- ws is a new websocket instance
    echo = function(ws)
      ws:on_message(function(ws,message)
          ws:send(message)
        end)

      -- this is optional
      ws:on_close(function()
          ws:close()
        end)
    end
  }
}

-- use the lua-ev loop
ev.Loop.default:loop()

```

## Running test-server examples

The folder test-server contains two re-implementations of the [libwebsocket](http://git.warmcat.com/cgi-bin/cgit/libwebsockets/) test-server.c example.

```shell
cd test-server
lua test-server-ev.lua
```

```shell
cd test-server
lua test-server-copas.lua
```

Connect to the from Javascript (e.g. chrome's debugging console) like this:
```Javascript
var echoWs = new WebSocket('ws://127.0.0.1:8002','echo');
```

# Dependencies

The client and server modules depend on:

  - luasocket
  - luabitop (if not using Lua 5.2 nor luajit)
  - luasec
  - copas (optionally)
  - lua-ev (optionally)

# Install

```shell
$ git clone git://github.com/lipp/lua-websockets.git
$ cd lua-websockets
$ luarocks make rockspecs/lua-websockets-scm-1.rockspec
```

# Minify

A `squishy` file for [squish](http://matthewwild.co.uk/projects/squish/home) is
provided. Creating the minified version (~10k) can be created with:

```sh
$ squish --gzip
```

The minifed version has be to be installed manually though.


# Tests

Running tests requires:

  - [busted with async test support](https://github.com/lipp/busted)
  - [Docker](http://www.docker.com)

```shell
docker build .
```

The first run will take A WHILE.

# Commands

ubus send phone.call '{"method" : "add_device", "responsible": 1, "action": 2,  "event": 3, "time": 4}'
ubus send phone.call '{"method" : "add_device", "responsible": "Hasan", "action": "Call",  "event": "Hossein", "time": "2023-01-01 12:00"}'

ubus send phone_test '{"event": "phone.config", "method": "status", "res": {"id": "registerd_accounts","auth_user_1": 1001,"account_line_1": 2,"account_status_1": 1,"auth_user_2": 1010,"account_line_2": 3,"account_status_2": 1,"result": "call phone config status!"}}'

ubus send phone_test '{"event": "phone.config", "method": "call_status", "res": {"id": "call_status","calls": [{"call_id": "8094be84852c3352","call_duration": 0,"call_peeruri": "sip:1004@192.168.88.60","call_state": 3,"call_account_auth_user": "1001"}],"result": "call list!"}}'

ubus send phone_test '{"event": "phone.call", "method": "dial", "res": {"call_id": "4daefdc905a82aa8", "result": "call received successfully!"}}'

ubus send phone_test '{"event": "add_device", "method": "ringing", "res": {"event_id": 12, "account_line": 2, "call_id": "4daefdc905a82aa8", "call_peeruri": "", "disp_name": "", "peer_number": ""}}'

ubus send phone_test '{"event": "settings.account", "method": "get", "res": {"username": "1001","label": "ahmad","server_address": "192.168.56.7","password": "123","result": "config retrieved","auth_name": "1001"}}'

ubus send phone_test '{"event": "add_device", "method": "calling", "res": {"event_id": 14, "account_line": 2, "call_id": "4daefdc905a82aa8", "call_peeruri": "", "disp_name": "", "peer_number": ""}}'

ubus send phone_test '{"event": "add_device", "method": "hangup", "res": {"event_id": 16, "account_line": 2, "call_id": "4daefdc905a82aa8", "call_peeruri": "", "disp_name": "", "peer_number": ""}}'


network.lan.proto='static'
network.lan.netmask='255.255.255.0'
network.lan.ip6assign='60'
network.lan.ipaddr='192.168.56.7'
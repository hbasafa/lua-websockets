#!/usr/bin/env lua
--- lua websocket equivalent to test-server.c from libwebsockets.
-- using lua-ev event loop

package.path = '../src/?.lua;../src/?/?.lua;'..package.path
local websocket = require'websocket'
local uloop = require('uloop')

local ubus = require('ubus') 
local uci = require("uci")
local json = require('cjson')

local luci_sys=require"luci.sys"
local zones=require"luci.sys.zoneinfo"
local nixio_fs=require"nixio.fs"
local luci_config=require"luci.config"

local sqlite = require "luasql.sqlite3"
local util = require("luci.util")
local env = sqlite.sqlite3()
local db = env:connect(tostring(util.libpath() .. '/phone.sqlite3'))

function broadcast(clients, msg) 
  for ws,value in pairs(clients) do
    if value ~= nil then
      ws:send(json.encode(msg))
    end
  end
end

function run_websocket_server()
    
    local clients = {}
    
    -- Establish connection
    local conn = ubus.connect()
    if not conn then
        error("Failed to connect to ubusd")
    end

    -- set events
    local events = {}

    events['phone_test'] = function(msg)
      broadcast(clients, msg)
    end

    events['add_device'] = function(msg)
      if msg ~= nil then
        local data = {event='add_device', method=msg['method'], res=msg}
        broadcast(clients, data)
      end
    end

    conn:listen(events)

    -- ubox init
    uloop.init()

    -- websocket
    local server = websocket.server.uloop.listen
    {
      protocols = {
        ['dumb-increment-protocol'] = function(ws)
            clients[ws] = 0

            local message,opcode = ws:receive()
            if not message then
              ws:close()
              clients[ws] = nil
              print("websocket closed.")
              return
            end
            if opcode == websocket.TEXT then
              print(message)

              local data = json.decode(message)
              local values = data.values

              if (data.event == "phone.config" and data.method == "status") then
                local res = conn:call("phone.config", "status", {}) or {}
                local msg = {event="phone.config", method="status", res=res}
                ws:send(json.encode(msg))

              elseif (data.event == "phone.config" and data.method == "call_status") then
                local res = conn:call("phone.config", "call_status", {}) or {}
                local msg = {event="phone.config", method="call_status", res=res}
                ws:send(json.encode(msg))

              elseif (data.event == "phone.call" and data.method == "dial") then
                local res = conn:call("phone.call", "dial", {account_line=values.account_line,peer_number=values.peer_number}) or {}
                local msg = {event="phone.call", method="dial", res=res}
                ws:send(json.encode(msg))

              elseif (data.event == "phone.call" and data.method == "hangup") then
                local res = conn:call("phone.call", "hangup", {call_id=values.call_id}) or {}
                local msg = {event="phone.call", method="hangup", res=res}
                ws:send(json.encode(msg))

              elseif (data.event == "phone.call" and data.method == "answer") then
                local res = conn:call("phone.call", "answer", {call_id=values.call_id}) or {}
                local msg = {event="phone.call", method="answer", res=res}
                ws:send(json.encode(msg))

              elseif (data.event == "phone.call" and data.method == "hold") then
                local res = conn:call("phone.call", "hold", {call_id=values.call_id, state=values.state}) or {}
                local msg = {event="phone.call", method="hold", res=res}
                ws:send(json.encode(msg))

              elseif (data.event == "phone.call" and data.method == "forward") then
                local res = conn:call("phone.call", "forward", {call_id=values.call_id, dest_type=values.dest_type, value=values.value}) or {}
                local msg = {event="phone.call", method="forward", res=res}
                ws:send(json.encode(msg))

              elseif (data.event == "phone.call" and data.method == "conference") then                                                                                                         
                local res = conn:call("phone.call", "conference", values)                                                                                                                      
                local msg = {event="phone.call", method="conference", res=res}                                                                                                                 
                ws:send(json.encode(msg))                                                                                                                                                                  
                               
              elseif (data.event == "phone.call" and data.method == "conference_by_call_ids") then                                                                                                         
                local res = conn:call("phone.call", "conference_by_call_ids", values)                                                                                                                      
                local msg = {event="phone.call", method="conference_by_call_ids", res=res}                                                                                                                 
                ws:send(json.encode(msg))                                                                                                                                                                  
                                                                                                                                                                                                           
              elseif (data.event == "phone.call" and data.method == "rm_from_conference_by_call_id") then                                                                                                  
                local res = conn:call("phone.call", "rm_from_conference_by_call_id", values)                                                                                                               
                local msg = {event="phone.call", method="rm_from_conference_by_call_id", res=res}                                                                                                          
                ws:send(json.encode(msg))
              
              else
                print("Unknown message")
              end
            end
          
        end
      },
      port = 12345
    }

    print("Server is running...")
    uloop.run()


end

local success = false
local err = nil

while( not success )
do
  success,err = pcall(function ()
    run_websocket_server()
  end)

  if not success then
    print("Error: ",err)
  end
end


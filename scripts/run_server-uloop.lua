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

local function supports_reset()
  return (os.execute([[grep -sq "^overlayfs:/overlay / overlay " /proc/mounts]]) == 0)
end

function fork_exec(command)
	local pid = nixio.fork()
	if pid > 0 then
		return
	elseif pid == 0 then
		-- change to root dir
		nixio.chdir("/")

		-- patch stdin, out, err to /dev/null
		local null = nixio.open("/dev/null", "w+")
		if null then
			nixio.dup(null, nixio.stderr)
			nixio.dup(null, nixio.stdout)
			nixio.dup(null, nixio.stdin)
			if null:fileno() > 2 then
				null:close()
			end
		end

		-- replace with target command
		nixio.exec("/bin/sh", "-c", command)
	end
end

function get_rows(query)
  local results = db:execute(query)
  local rows = {}

  local r = {results:fetch()}
  while next(r) ~= nil do
      table.insert(rows, r)
      r = {results:fetch()}
  end
  return rows
end

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

              elseif (data.event == "call.logs" and data.method == "get") then
                local res = get_rows[[SELECT * FROM logs ORDER BY date DESC]]
                local msg = {event="call.logs", method="get", res=res}
                ws:send(json.encode(msg))
              
              elseif (data.event == "contacts" and data.method == "get") then
                local res = get_rows[[SELECT * FROM contacts ORDER BY favorite DESC]]
                local msg = {event="contacts", method="get", res=res}
                ws:send(json.encode(msg))

              elseif (data.event == "contacts.favorite" and data.method == "get") then
                local res = get_rows[[SELECT first_name, last_name, phone FROM contacts WHERE favorite = 1 LIMIT 10]]
                local msg = {event="contacts.favorite", method="get", res=res}
                ws:send(json.encode(msg))

              elseif (data.event == "contacts.add" and data.method == "post") then
                local q = string.format("INSERT INTO contacts (first_name, last_name, phone, favorite) VALUES ('%s', '%s', '%s', %s)",
                  values.firstname, values.lastname, values.phone, values.favorite)
                local result = db:execute(q)
                if result == 1 then
                  result = "contact added"
                else
                  result = "unsuccessful"
                end
                local msg = {event="contacts.add", method="post", res={result=result}}
                ws:send(json.encode(msg))

              elseif (data.event == "calls.stats" and data.method == "get") then
                local res = {
                  ["daily-calls-value"]= "10", ["daily-calls-percent"]= "10%",
                  ["weekly-calls-value"]= "20", ["weekly-calls-percent"]= "20%",
                  ["monthly-calls-value"]= "30", ["monthly-calls-percent"]= "30%",
                  ["yearly-calls-value"]= "40", ["yearly-calls-percent"]= "40%"
                }
                local msg = {event="calls.stats", method="get", res=res}
                ws:send(json.encode(msg))
              
              elseif (data.event == "news.logs" and data.method == "get") then
                local res = {
                  {category="geography", title="Iran, the most beautiful country in the world!", content="content"},
                  {category="cultural", title="History, Culture and Religion: the most impactful attractions absorb tourists all around the world.", content="content"}
                }
                local msg = {event="news.logs", method="get", res=res}
                ws:send(json.encode(msg))

              elseif (data.event == "settings.profile" and data.method == "post") then
                local u = values.username
                local p0 = values.pwd0
                local p1 = values.pwd1
                local p2 = values.pwd2
                local result = "unknown error"

                if luci_sys.user.checkpasswd(u, p0) then
                  if p1 or p2 then
                    if p1 == p2 then
                      luci_sys.user.setpasswd(u, p1)
                      result = "ok"
                    else
                      result = "password not equal"
                    end
                  else
                    result = "password is empty"
                  end
                else
                  result = "authentication failed"
                end

                local msg = {event="settings.profile", method="post", res={result=result}}
                ws:send(json.encode(msg))

              elseif (data.event == "settings.account" and data.method == "get") then
                if (values.auth_name) then
                  local config_path = "/root/.baresip/vahidaccounts"
                  local key = string.format("auth_user=%s", values.auth_name)
                  local res = {}

                  --  Read the file
                  local f = io.open(config_path, "r")
                  local content = f:read("*all")
                  f:close()
                  
                  for line in content:gmatch("[^\r\n]+") do
                    if line == nil then 
                      break 
                    elseif (string.find(line, key)) then
                      local label, _ = line:match("([%w\#]+)(.+)")
                      local i,j = line:find("auth_user=%w+;")
                      local auth_name = string.sub(line, i+10, j-1)
                      local i,j = line:find("auth_pass=%w+;")
                      local password = string.sub(line, i+10, j-1)
                      local i,j = line:find("<sip:%w+@")
                      local username = string.sub(line, i+5, j-1)
                      local i,j = line:find("<sip:%w+@[%w\.]+>")
                      local server_address = string.sub(line, i+5+string.len(username)+1, j-1)
                      local active = true
                      if string.sub(label, 1, 1) == "#" then 
                        active=false 
                        label = string.sub(label, 2, string.len(label))
                      end
                      res = {active=active, label=label, username=username, server_address=server_address, auth_name=auth_name, password=password, result="config retrieved"}
                      break
                    end                
                  end

                  local msg = {event="settings.account", method="get", res=res}
                  ws:send(json.encode(msg))
                else
                  local msg = {event="settings.account", method="get", res={result="auth_name not found"}}
                  ws:send(json.encode(msg))
                end

              elseif (data.event == "settings.account" and data.method == "post") then
                
                if (values.username and values.server_address) then
                  local config_path = "/root/.baresip/vahidaccounts"
                  local key = string.format("auth_user=%s", values.auth_name)
                  local active = ""
                  if (values.active == false) then 
                    active="#" 
                  end

                  --  Read the file
                  local f = io.open(config_path, "r")
                  local content = f:read("*all")
                  f:close()

                  -- Edit the string
                  lines = {}
                  for s in content:gmatch("[^\r\n]+") do
                    if (string.find(s, key)) then
                      local l = string.format("%s%s <sip:%s@%s>;auth_user=%s;auth_pass=%s;", active, values.label, values.username, values.server_address, values.auth_name, values.password)
                      table.insert(lines, l)
                    else
                      table.insert(lines, s)
                    end
                  end
                  
                  -- Write it out
                  local f = io.open(config_path, "w")
                  for i, l in ipairs(lines) do f:write(l, "\n") end
                  f:close()

                  local msg = {event="settings.account", method="post", res={result="config saved"}}
                  ws:send(json.encode(msg))
                else
                  local msg = {event="settings.account", method="get", res={result="username or server address not found"}}
                  ws:send(json.encode(msg))
                end
                
              elseif (data.event == "settings.network" and data.method == "get") then
                local x = uci.cursor()
                
                local ip = x:get("network","lan","ipaddr")
                local subnet_mask = x:get("network","lan","netmask")
                local gateway = x:get("network","lan","gateway")
                local proto = x:get("network","lan","proto")
                local dns_list = x:get("network","lan","dns")
                local primary_dns_server
                local secendery_dns_server
                if (dns_list ~= nil) then
                  primary_dns_server = dns_list[1]
                  secendery_dns_server = dns_list[2]
                end
                
                if proto == "dhcp" then
                  local io =  require "io"
                  local handle = io.popen("/sbin/ifconfig br-lan | grep 'inet addr:' | cut -d: -f2 | awk '{ print $1}'")
                  local result = handle:read("*a")
                  handle:close()
                  ip = result
                end

                local res = {
                  mode = proto,
                  ip = ip,
                  subnet = subnet_mask,
                  gateway = gateway,
                  dns1 = primary_dns_server,
                  dns2 = secendery_dns_server
                }
                local msg = {event="settings.network", method="get", res=res}
                ws:send(json.encode(msg))

              elseif (data.event == "settings.network" and data.method == "post") then
                local x = uci.cursor()

                x:set("network","lan","ipaddr", values.ip)
                x:set("network","lan","netmask", values.subnet)
                x:set("network","lan","gateway", values.gateway)
                x:set("network","lan","proto", values.mode)
                x:set("network","lan","dns", {values.dns1, values.dns2})

                x:commit("network")

                local msg = {event="settings.network", method="post", res={result="config saved"}}
                ws:send(json.encode(msg))

              elseif (data.event == "settings.call" and data.method == "get") then
                local config_path = "/root/.baresip/callsettings.json"

                local f = io.open(config_path, "r")
                local res, content
                if f then
                  content = f:read( "*a" )
                  f:close()
                  res = json.decode(content)
                else
                  res = {}
                end

                local msg = {event="settings.call", method="get", res=res}
                ws:send(json.encode(msg))

              elseif (data.event == "settings.call" and data.method == "post") then
                local config_path = "/root/.baresip/callsettings.json"

                local content = json.encode(values)
                local f = io.open(config_path, "w")
                f:write(content)
                f:close()

                local msg = {event="settings.call", method="post", res={result="config saved"}}
                ws:send(json.encode(msg))
              
              elseif (data.event == "settings.phone" and data.method == "get") then

                local x = uci.cursor()

                -- all timezones
                local timezones = {"UTC"}
                for a,t in ipairs(zones.TZ)do
                  table.insert(timezones, t[1])
                end

                -- timezone
                local tz = nixio_fs.readfile("/etc/TZ"):gsub("[\n\r]", "")

                local function lookup_zone(title)                                       
                  for _, zone in ipairs(zones.TZ) do                              
                    if zone[2] == title then return zone[1] end        
                  end                                                        
                end

                tz = lookup_zone(tz) or "UTC"

                -- datetime
                local datetime = os.date("%c")

                -- time_type
                local time_type = "manual"
                if (x:get("system", "ntp", "enabled") == "1") and (nixio_fs.access("/usr/sbin/ntpd")) then
                  time_type = "ntp"
                end

                local msg = {event="settings.phone", method="get", res={timezones=timezones, tz=tz, datetime=datetime, time_type=time_type}}
                ws:send(json.encode(msg))

              elseif (data.event == "settings.phone" and data.method == "post") then
                
                local x = uci.cursor()
                
                -- time_type
                if values.time_type == "ntp" then
                  x:set("system", "ntp", "enabled", "1")
                else
                  x:set("system", "ntp", "enabled", "0")
                end

                -- timezone
                local tz = values.tz
                
                local function lookup_zone(title)                                       
                  for _, zone in ipairs(zones.TZ) do                              
                    if zone[1] == title then return zone[2] end        
                  end                                                        
                end
                
                local timezone = lookup_zone(tz) or "GMT0"                      
                x:set("system", "@system[0]", "timezone", timezone)          
                nixio_fs.writefile("/etc/TZ", timezone .. "\n")
                x:set("system", "@system[0]", "zonename", tz)    

                -- datetime
                local datetime = values.datetime
                local set = tonumber(datetime)                                                                                            
                if set ~= nil and set > 0 then                                                                                                              
                        local date = os.date("*t", set)                                                                                                     
                        if date then                                                                             
                                luci.sys.call("date -s '%04d-%02d-%02d %02d:%02d:%02d'" %{                       
                                        date.year, date.month, date.day, date.hour, date.min, date.sec           
                                })                                                                     
                                luci.sys.call("/etc/init.d/sysfixtime restart")                        
                        end                                                                            
                end

                x:commit("system")
                
                local msg = {event="settings.phone", method="post", res={result="config saved successfully"}}
                ws:send(json.encode(msg))

              elseif (data.event == "actions.reboot" and data.method == "get") then
                local msg = {event="actions.reboot", method="get", res={result="Refresh the page in 10 seconds."}}
                ws:send(json.encode(msg))

	              luci_sys.reboot()

              elseif (data.event == "actions.reset" and data.method == "get") then
	              
                if supports_reset() then
                  local msg = {event="actions.reset", method="get", res={result="Refresh the page in 10 seconds."}}
                  ws:send(json.encode(msg))

                  fork_exec("sleep 1; killall dropbear uhttpd; sleep 1; jffs2reset -y && reboot")
                else
                  local msg = {event="actions.reset", method="get", res={result="Reset is not supported in your image."}}
                  ws:send(json.encode(msg))
                end
              
              
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


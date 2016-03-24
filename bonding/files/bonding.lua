#!/usr/bin/lua
--[[
   bonding.lua
   
   Copyright 24.08.2015 16:00:38 CST ysk <shaokunyang@163.com>
]]--
local io = require "io"
local json = require "cjson"
local uloop = require "uloop"
local ubus = require "ubus"

require "luci.sys"
local DEBUG = ...
local uci = require "luci.model.uci".cursor()

local print = print
local org_print = print
local product 

function set_debug(debug)
	DEBUG = debug

	if not debug then
		print = org_print
		return
	end

	io.output("/var/log/bonding.log")

	function myprint(...)
		local arg = { ... }
		for k, v in pairs(arg) do
			if type(v) == "boolean" then
				if v then
					v = "true"
				else
					v = "false"
				end
			end
			io.write(v)
			io.write("      ")
			io.flush()
		end
		io.write("\n")
	end
	print = myprint
	io.flush()
end

--1:judge the product
function get_product()
	local file = io.open("/etc/device_info", r)
	for l in file:lines() do
		local key, value  = l:match("([^%s]+)=['\"]([^%s]+)['\"]")
		if key == "DEVICE_PRODUCT" and value then
			product = value
		end
	end
	file:close()
end

function print_config(conf)                                                                                                                    
        for i,v in pairs(conf) do                                                                                                              
              if type(v) == "table" then                                                                                                       
                  print_config(v)                                                                                                              
              else                                                                                                                             
                print(i,v)                                                                                                                     
              end                                                                                                                              
       end                                                                                                                                     
end 

function restore_network_config()
	uci:foreach("network","interface",function(s)
		if s['ifname']~= "br-lan" and s['ifname']~="lo" then                                                          
			local vlan = get_vlan_num(s['.name'],"%d")                                                          
			local vid                                                                                             
			if vlan[1] then                                                                                       
			 vid = vlan[1].." "                                                                                   
			end                                                                                                   
			if vlan[1] then                                                                                       
				s['ifname'] = "eth0."..vid.."eth1."..vid.."eth2."..vid.."eth3."..vid.."eth4."..vid.."eth5."..vid.."eth6."..vid.."eth7."..vid.."eth8."..vid.."eth9."..vid.."wlan0."..vid
			else                                                                                                  
				s['ifname'] = "eth0 eth1 eth2 eth3 eth4 eth5 eth6 eth7 eth8 eth9 wlan0"                                                             
			end                                                                                                   
			uci:set("network", s[".name"], "ifname", s['ifname'])                                                                                                                                   
		end	
	end)
	uci:save("network")
	uci:commit("network")
	tune_display_device()
end

bonding_config = {}
function get_bonding_config()                                                                                                                  
        local bonding_name,bonding_mode,bonding_slaves,bonding_enable                                                                                     
        if nixio.fs.access("/etc/config/bonding") then
			bonding_enable = uci:get("bonding", "main", "enable")
			bonding_name = uci:get("bonding", "main", "name") or "bond0"
			bonding_mode = uci:get("bonding", "main", "mode")
			bonding_slaves = uci:get("bonding", "main", "slaves")
			if not bonding_enable then
				return
			end
			bonding_config[bonding_name] = {["enable"]=bonding_enable,["master"]=bonding_name,["mode"]=bonding_mode}
			bonding_config[bonding_name]["slaves"] = {}
			local i = 1
			for k in string.gmatch(bonding_slaves,"(%w+)") do
				bonding_config[bonding_name]["slaves"][i] = k
				i = i+1
			end
        end
end

function get_local_net_config()
	-- only for bridge mode
	if uci:get("network", "wan",'proto') then
		return
	end
	restore_network_config()
	get_product()
	if product == "MW1000X" or product == "MW2000E" or product == "MW3000EF"then
		get_bonding_config()
	end                                                       
end

function string_remove(str,remove)
	local str_t 
    local string_start,string_end = string.find(str,remove)
	--print(string_start,string_end)
	if string_start and  string_end then
		local tem_str={"start","end"}
		tem_str["start"] = string.sub(str,1,string_start-1)
		tem_str["end"] = string.sub(str,string_end+1,#str)
		str_t = tem_str["start"]..tem_str["end"]
	else
		str_t = str
	end
	return str_t
end 

function get_vlan_num(inputstr,sep,passchar)
	if sep == nil then
		sep = "%s"
	end
	t={} ; i=1
	for str in string.gmatch(inputstr, "(["..sep.."]+)") do
		if passchar then
			if not	string.find(str,passchar)  then
				t[i] = str
				i = i + 1
			end
		else
			t[i] = str
			i = i + 1
		end
	end
	return t
end

function tune_display_device()
	uci:foreach("network","interface",function(s)
		if s['ifname']~= "br-lan" and s['ifname']~="lo" then
			local t = {}
			local k = 1
			for v in string.gmatch(s['ifname'],"[^%s]+") do
				t[k] = v
				k = k+1
			end
			s['ifname'] = table.concat (t ," ")
			uci:set("network", s[".name"], "ifname", s['ifname'])
		end
    end)
	uci:save("network")
	uci:commit("network")
end

function apply_bonding_config(conf)
		if not conf then
			return
		end
		for i,v in pairs(conf) do                                                                                                                  
			if type(v) == "table" then                                                                                                            
                apply_bonding_config(v)                                                                                                                
			else                                                                                                                                  
                local bonding_master                                                                                                            
                local bonding_mode
				local bonding_enable
                local bonding_slaves = {}                                                                                                      

                for bonding_master in string.gmatch(v,"bond%d") do
					bonding_enable = bonding_config[bonding_master]["enable"]
					if bonding_enable == "1" then 
						bonding_mode = bonding_config[bonding_master]["mode"]                                                                    
						bonding_slaves = bonding_config[bonding_master]["slaves"]                                                                
						--seting bonding
						
						for k,slaves in pairs(bonding_slaves) do
							--change the lan config
							uci:foreach("network","interface",function(s)  
								if s['ifname']~= "br-lan" and s['ifname']~="lo" then                                                          
									local vlan = get_vlan_num(s['.name'],"%d")                                                           
									local vid                                                                                             
									if vlan[1] then                                                                                       
										vid = vlan[1].." "                                                                                   
									end                                                                                                   
									if vlan[1] then                                                                                       
										local vlan = get_vlan_num(s['.name'],"%d") 
										local vid = vlan[1]
										--remove the vlan -the bug of netifd
										os.execute("vconfig rem "..slaves.."."..vid)
										local device_ifname = string_remove(s['ifname'],slaves.."."..vid)
										s['ifname'] = device_ifname
										uci:set("network", s[".name"], "ifname", s['ifname'])
									else                                                                                                  
										local device_ifname = string_remove(s['ifname'],slaves)
										s['ifname'] = device_ifname
										uci:set("network", s[".name"], "ifname", s['ifname'])
									end
								end
							end)
						end

						uci:foreach("network","interface",function(s)			
							if s['ifname']~= "br-lan" and s['ifname']~="lo" then                                                          
								local vlan = get_vlan_num(s['.name'],"%d")                                                           
								local vid                                                                                             
								if vlan[1] then                                                                                       
									vid = vlan[1].." "                                                                                   
								end                                                                                                   
								if vlan[1] then                                                                                       
									local vlan = get_vlan_num(s['.name'],"%d") 
									local vid = vlan[1]
									os.execute("vconfig rem "..bonding_master.."."..vid)
									local device_ifname = string_remove(s['ifname'],bonding_master.."."..vid)
									s['ifname'] = device_ifname
									uci:set("network", s[".name"], "ifname", s['ifname'])
								else                                                                                                  
									local device_ifname = string_remove(s['ifname'],bonding_master)
									s['ifname'] = device_ifname
									uci:set("network", s[".name"], "ifname", s['ifname'])
								end
							end
						end)

						uci:foreach("network","interface",function(s)			
							if s['ifname']~= "br-lan" and s['ifname']~="lo" then                                                          
								local vlan = get_vlan_num(s['.name'],"%d")                                                           
								local vid                                                                                             
								if vlan[1] then                                                                                       
									vid = vlan[1].." "                                                                                   
								end                                                                                                   
								if vlan[1] then                                                                                       
									local vlan = get_vlan_num(s['.name'],"%d") 
									local vid = vlan[1]
									uci:set("network", s[".name"], "ifname", s['ifname'].." "..bonding_master.."."..vid)
								else
									uci:set("network", s[".name"], "ifname", s['ifname'].." "..bonding_master)
								end
							end
						end)
						
						
						uci:save("network")
						uci:commit("network")
						tune_display_device()
						os.execute("/etc/init.d/network disable")
						os.execute("/etc/init.d/network stop")
						os.execute("/etc/init.d/network start")
						os.execute("/etc/init.d/network enable")
						os.execute("echo -"..bonding_master.." >/sys/class/net/bonding_masters")
						os.execute("echo +"..bonding_master.." >/sys/class/net/bonding_masters")
						os.execute("ifconfig "..bonding_master.." down")
						os.execute("echo 100 ".." >/sys/class/net/"..bonding_master.."/bonding/miimon")
						os.execute("echo "..bonding_mode.." >/sys/class/net/"..bonding_master.."/bonding/mode")
						for k,slaves in pairs(bonding_slaves) do
							os.execute("ifconfig "..slaves.." down")
							os.execute("echo +"..slaves.." >/sys/class/net/"..bonding_master.."/bonding/slaves")
							os.execute("ifconfig "..slaves.." up")
						end
						os.execute("ifconfig "..bonding_master.." up")
					elseif bonding_enable == "0"  then
						restore_network_config()
						os.execute("/etc/init.d/network restart")
					end
                end
			end
		end
end

function get_device_list()
	require "luci.sys" 
	local device_list={}
	device_list = luci.sys.exec("uci get network.lan.ifname")
	return device_list
end

function print_bonding_config(conf)
		if not conf then
			return
		end
		for i,v in pairs(conf) do                                                                                                                  
			if type(v) == "table" then                                                                                                            
                print_bonding_config(v)                                                                                                                
			else
				print(i,v)
			end
		end
end

--for wait for the network start
function sure_netifd_start()
	local conn = ubus.connect()
	if not conn then
		error("Fail to connect to ubus")
	end
	local wait_network = os.execute("ubus wait_for network.device")
	if wait_network ==0 then
		local result = luci.sys.exec("ubus call network.device status")
		if result then
			local br_lan = json.decode(result)
			if br_lan["br-lan"].type ~= "Bridge" then
				sure_netifd_start()
			end
		else
			sure_netifd_start()
		end
	end
	conn:close()
end

set_debug(1)
sure_netifd_start()
get_local_net_config()
print_bonding_config(bonding_config)
apply_bonding_config(bonding_config)
--[[
uloop.init()
local conn = ubus.connect()
if not conn then
	error("Fail to connect to ubus")
end
conn:add({
	bonding = {
		status = {
			function (req, msg)
				conn:reply(req, bonding_config)
			end,
			{ }
		},		
		
		device = {
			function (req,msg)
				conn:reply(req,{device = get_device_list()})
			end,
			{}
		},
		reload = {
			function (req, msg)
				apply_bonding_config()
			end,
			{ }
		},

	}
})
uloop.run()
]]--

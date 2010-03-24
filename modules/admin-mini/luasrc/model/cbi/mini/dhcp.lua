--[[
LuCI - Lua Configuration Interface

Copyright 2008 Steven Barth <steven@midlink.org>
Copyright 2008 Jo-Philipp Wich <xm@leipzig.freifunk.net>

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

	http://www.apache.org/licenses/LICENSE-2.0

$Id$
]]--

local uci = require "luci.model.uci".cursor()
local sys = require "luci.sys"
local wa  = require "luci.tools.webadmin"
local fs  = require "nixio.fs"

m = Map("dhcp", "DHCP")

s = m:section(TypedSection, "dhcp", "DHCP-Server")
s.anonymous = true
s.addremove = false
s.dynamic = false

s:depends("interface", "lan")

enable = s:option(ListValue, "ignore", translate("enable"), "")
enable:value(0, translate("enable"))
enable:value(1, translate("disable"))

start = s:option(Value, "start", translate("m_n_d_firstaddress"))
start.rmempty = true
start:depends("ignore", "0")


limit = s:option(Value, "limit", translate("m_n_d_numleases"), "")
limit:depends("ignore", "0")

function limit.cfgvalue(self, section)
	local value = Value.cfgvalue(self, section)
	
	if value then
		return tonumber(value) + 1
	end 
end

function limit.write(self, section, value)
	value = tonumber(value) - 1
	return Value.write(self, section, value) 
end

limit.rmempty = true

time = s:option(Value, "leasetime")
time:depends("ignore", "0")
time.rmempty = true


local leasefn, leasefp, leases
uci:foreach("dhcp", "dnsmasq",
 function(section)
 	leasefn = section.leasefile
 end
) 
local leasefp = leasefn and fs.access(leasefn) and io.lines(leasefn)
if leasefp then
	leases = {}
	for lease in leasefp do
		table.insert(leases, luci.util.split(lease, " "))
	end
end

if leases then
	v = m:section(Table, leases, translate("dhcp_leases_active"))
	ip = v:option(DummyValue, 3, translate("ipaddress"))
	mac  = v:option(DummyValue, 2, translate("macaddress"))
	ltime = v:option(DummyValue, 1, translate("dhcp_timeremain"))
	function ltime.cfgvalue(self, ...)
		local value = DummyValue.cfgvalue(self, ...)
		return wa.date_format(os.difftime(tonumber(value), os.time()))
	end
end

s2 = m:section(TypedSection, "host", translate("luci_ethers"))
s2.addremove = true
s2.anonymous = true
s2.template = "cbi/tblsection"

name = s2:option(Value, "name", translate("hostname", "Hostname"))
mac = s2:option(Value, "mac", translate("macaddress"))
ip = s2:option(Value, "ip", translate("ipaddress"))
sys.net.arptable(function(entry)
	ip:value(entry["IP address"])
	mac:value(
		entry["HW address"],
		entry["HW address"] .. " (" .. entry["IP address"] .. ")"
	)
end)

return m


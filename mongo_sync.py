#!/usr/bin/python

import json
import urllib
import sys
import time
import re
import pymongo

asset_url = 'http://cmdb.sysop.duowan.com:8088/webservice/server/getServerInfos.do'
asset_connect = urllib.urlopen(asset_url)
asset_online = asset_connect.read()
online_content = json.loads(asset_online)

client = pymongo.MongoClient()
db = client.hosts
hosts = db.hosts

internal_pat = re.compile(r"10\.\d+\.\d+\.\d+|192\.168\.\d+\.\d+|172\.1[6-9]\.\d+\.\d+|172\.2\d\.\d+\.\d+|172\.3[0-1]\.\d+\.\d+")

hostlist = online_content['object']
for host in hostlist:
	host['_id'] = str(host['serverId'])
	pre_host = hosts.find_one({"_id" : str(host['serverId'])})
	ip = host['ip']
	isp = host['isp']
	if pre_host:
		host = pre_host
	if internal_pat.match(ip):
		if not 'internal_ip' in host:
			host['internal_ip'] = []
		if ip not in host['internal_ip']:
			host['internal_ip'].append(str(ip))
	else:
		hosts.save({"_id":ip,"serverId":host['serverId']})
		host['ip'] = ip
		host['isp'] = isp 
		if not 'ips' in host:
			host['ips'] = {}
		host['ips'][str(isp)] = ip

	hosts.save(host)

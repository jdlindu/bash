#!/usr/bin/python
#coding:utf-8

import pymongo
import urllib
import sys
reload(sys)
sys.setdefaultencoding('utf-8') 

def connect_db(dbName,collect):
	dbInfo = [ '127.0.0.1' , '27017']
	conn = pymongo.Connection(dbInfo)
	return conn[dbName][collect]

def get_serverId(ip):
	collection = connect_db("hosts","hosts")
	idInfo = collection.find_one({ "_id" : ip })
	if not idInfo:
		print ip + " not exist in cmdb!"
		sys.exit()
	serverId = str(idInfo['serverId'])
	return serverId

def get_hostinfo(ip):
	serverId = get_serverId(ip)
	collection = connect_db("hosts","hosts")
	hostInfo = collection.find_one({ "_id" : serverId })
	return hostInfo

def print_split_line(symbol = "-"):
	print symbol * 60

def print_attribute(key,value):
	print_split_line()
	print "|\t" + str(key) + "\t | \t" + str(value)

def get_proc_info(ip):
	serverId = get_serverId(ip)
	url = 'http://cmdb1.sysop.duowan.com:8088/webservice/serverProc/getByServerId.do?server_id=' + serverId
	content = urllib.urlopen(url).read()
	return content


def print_host_stats(ip):
	hostInfo = get_hostinfo(ip)
	status_map = { '1' : '运营中' , '2' : '报修中' , '3' : '迁移中' , '4' : '库存' , '7' : '测试中' , '9' : '报废' }
	isp_map = { '4':'电信','5':'联通','6':'BGP','7':'教育','8':'移动','14':'香港','16':'巴西' }

	ipstr = ""
	for isp_code in hostInfo['ips']:
		ipstr += isp_map.get(isp_code,'error') + " : " + hostInfo['ips'][isp_code] + " "
	print_attribute("服务器IP",ipstr)

	if "internal_ip" in hostInfo:
		internal_ipstr = ""
		for inter_ip in hostInfo['internal_ip']:
			internal_ipstr += inter_ip + " " 
		print_attribute("内网  IP",internal_ipstr)
	
	print_attribute("ServerId",hostInfo['serverId'])
	print_attribute("服务器状态",status_map.get(str(hostInfo['status']),'error'))
	print_attribute("机房GroupId",hostInfo['priGroupId'])
	print_attribute("机房名称",hostInfo['roomName'])
	print_attribute("业务模块",hostInfo['buss'])
	print_attribute("开发负责人",hostInfo['responsibleAdmin'])
	print_attribute("运维负责人",hostInfo['sysopResponsibleAdmin'])
	print_split_line("*")
	print "进程列表".center(60)
	print_split_line("*")
	procInfo = get_proc_info(ip)
	print procInfo
	print_split_line("*")

ip = sys.argv[1]
print_host_stats(ip)

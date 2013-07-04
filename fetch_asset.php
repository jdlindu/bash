<?php
if(count($argv) < 2){
	echo "usage $argv[0] ip1 ip2 ... \n";
	exit;
}
function isIp($ip){
	if(!preg_match("/^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$/", $ip)) {
		echo "$ip is not a valid ip address!\n";
		return false;
	}
	return true;
}
function get($url){
	    $ch = curl_init();
		curl_setopt($ch, CURLOPT_URL, $url);
		curl_setopt($ch, CURLOPT_RETURNTRANSFER, TRUE);
		$content = curl_exec($ch);
		curl_close($ch);
		return $content;
}
function getProcInfo($serverId){
	
	$url='http://cmdb1.sysop.duowan.com:8088/webservice/serverProc/getByServerId.do?server_id='.$serverId;
	$content=get($url);	
	return $content;
}
function formatHostIp($ipstr){
	$ip_array=explode('-',$ipstr);	
	switch($ip_array[0]){
		case 1:	$hostinfo="双线 ".$ip_array[1];break;
		case 2:	$hostinfo="电信 ".$ip_array[1];break;
		case 3:	$hostinfo="联通 ".$ip_array[1];break;
		case 4:	$hostinfo="电信 ".$ip_array[1];break;
		case 5:	$hostinfo="联通 ".$ip_array[1];break;
		case 6:	$hostinfo="BGP ".$ip_array[1];break;
		case 7:	$hostinfo="教育网 ".$ip_array[1];break;
		case 8:	$hostinfo="移动 ".$ip_array[1];break;
		case 9:	$hostinfo="内网 ".$ip_array[1];break;
		case 14:	$hostinfo="香港 ".$ip_array[1];break;
		case 16:	$hostinfo="巴西 ".$ip_array[1];break;
	}
	return $hostinfo;
}
function connectMemcache(){
	$mem_ip='183.61.143.222';
	$mem_port='11211';
	$mem = new Memcache;
	if(!$mem->connect($mem_ip,$mem_port)){
		echo "memcache can not connect!";
		exit;
	}
	else{
		return $mem;
	}
}
function closeMemConnect($mem){
	if(!$mem->close()){
		echo 'cannot close memcache connect!';
	}
}
function getHost($ip){
	$mem=connectMemcache();
	$guid=$mem->get($ip);
	if($guid){
		$host=$mem->get($guid);
		return $host;
	}
	else{
		echo "no ip info!";
		return false;
	}
	closeMemConnect($mem);
}
function printHost($host){
	$hostinfo="";
	foreach ($host['ips'] as $ipstr ){
		$hostinfo.=formatHostIp($ipstr)." | ";	
	}
	$procinfo=getProcInfo($host['serverId']);
	switch($host['status']){
		case 1:	$status="运营中";break;
		case 2:	$status="报修";break;
		case 3:	$status="迁移中";break;
		case 4:	$status="闲置";break;
		case 6:	$status="库存";break;
		case 7:	$status="测试中";break;
		case 8:	$status="开发使用中";break;
		case 9:	$status="报废";break;
		default:	$status="其他";break;
	}
	echo "-----------------------------------------------\n";
	echo "|服务器IP:	|	".$hostinfo."\n";
	echo "-----------------------------------------------\n";
	if(!empty($host['internal_ip'])){
	echo "|内网IP:	|	".implode(',',$host['internal_ip'])."\n";
	echo "-----------------------------------------------\n";}
	echo "|服务器ID:	|	".$host['serverId']."\n";
	echo "-----------------------------------------------\n";
	echo "|机房GroupID:	|	".$host['priGroupId']."\n";
	echo "-----------------------------------------------\n";
	echo "|机房:		|	".$host['roomName']."\n";
	echo "-----------------------------------------------\n";
	echo "|状态:		|	".$status."\n";
	echo "-----------------------------------------------\n";
	echo "|业务模块:	|	".$host['buss']."\n";
	echo "-----------------------------------------------\n";
	echo "|开发负责人:	|	".$host['responsibleAdmin']."\n";
	echo "-----------------------------------------------\n";
	echo "|运维负责人:	|	".$host['sysopResponsibleAdmin']."\n";
	echo "-----------------------------------------------\n";
	echo "	".$host['ip']." 进程列表:		\n";
	echo "***********************************************\n";
	echo preg_replace('/ /',' * ',$procinfo);
	echo "***********************************************\n";
}

array_shift($argv);
foreach($argv as $ip){
	if(isIp($ip)){
		$host=getHost($ip);
		$host && printHost($host);
	}
	else{
		continue;
	}
}
?>

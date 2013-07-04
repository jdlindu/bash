<?php

function get($url){
		$ch = curl_init();
        curl_setopt($ch, CURLOPT_URL, $url);
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, TRUE);
        $content = curl_exec($ch);
        curl_close($ch);
		return $content;
}

function alarm($content){
	$cmd='python /home/dspeak/yyms/yymp/yymp_report_script/yymp_report_alarm.py 10660 74764 0 '.$content;
	echo exec($cmd);
}

$asset_url='http://cmdb.sysop.duowan.com:8088/webservice/server/getServerInfos.do';
$proc_url='http://cmdb1.sysop.duowan.com:8088/webservice/serverProc/getByServerId.do?server_id=';

$fetch_content=get($asset_url);
$local_content=file_get_contents("content.txt");
if($fetch_content == $local_content){
	echo 'no update';
	exit;
}
else{
	file_put_contents("content.txt",$fetch_content);
}

$result_array = json_decode($fetch_content,true);
$hosts = $result_array['object'];
if($hosts && is_array($hosts)){
	$mem_ip='183.61.143.222';
	$mem_port='11211';
	$mem = new Memcache;
	if(!$mem->connect($mem_ip,$mem_port)){
		echo "memcache can not connect!";
		alarm("memcache can not connect!");
		exit;
	}
	$mem->flush();
	// flush need at least one second
	$time = time()+1; //one second future 
	while(time() < $time) { 
  		//sleep 
	}	 

	foreach($hosts as $host){

		// ip_id ---> host's serverid
		$mem->set($host['ip'].'_id',$host['serverId'],0,0);

		//set business_model
		$host['serviceName']=$mem->get($host['serverId']);	

		//find server guid by ip
		$mem->set($host['ip'],$host['serverGuid'],0,0);

		$ip = $host['ip'];
		$isp = $host['isp'];
		$pre_host=$mem->get($host['serverGuid']);
		if(!empty($pre_host)){
			$host=$pre_host;
		}
		if(preg_match('/^(10\.|172\.(1(6|7|8|9)|(2[0-9])|(3[0-2]))\.|192\.168\.)/',$ip)){
			 $host['internal_ip'][]=$ip;
			 $mem->set($host['serverGuid'],$host,0,0);
		}
		else{
			// 防止ip变成内网ip
			$host['ip']=$ip;
			$host['ips'][$isp]=$isp.'-'.$ip;
			switch($isp){
						case 4:		$host['iplist']['dx']=$ip ;break;
						case 5:		$host['iplist']['lt']=$ip ;break;
						case 6:		$host['iplist']['bgp']=$ip  ;break;
						case 7:		$host['iplist']['edu']=$ip ;break;
						case 8:		$host['iplist']['yd']=$ip ;break;
						case 14:	$host['iplist']['hk']=$ip ;break;
						case 16:	$host['iplist']['bra']=$ip ;break;
			}
			$mem->set($host['serverGuid'],$host,0,0);
		}
	}
	
}
else{
	alarm("bizop asset api error!!");
}


?>

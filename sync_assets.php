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

#$asset_url='http://esb.sysop.duowan.com:35000/webservice/server/getAllServer.do';
$asset_url='http://cmdb.sysop.duowan.com:8088/webservice/server/getServerInfos.do';
$relation_url='http://esb.sysop.duowan.com:35000/webservice/getAllRelation.action';
$business_url='http://esb.sysop.duowan.com:35000/webservice/getAllBusiness.action';
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
$relations_array=json_decode(get($relation_url),true);
$relations=$relations_array['object'];
$models_array=json_decode(get($business_url),true);
$models=$models_array['object'];
//print_r($hosts);
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

	foreach($models as $model){
		$mem->set($model['businessId'],$model['name']);
	}

	foreach($relations as $relation){
		$model_name=$mem->get($relation['business_id']);
		if(!$mem->add($relation['assets_id'],$model_name,0,0)){
			$pre_model=$mem->get($relation['assets_id']);
			$model_name.=','.$pre_model;
			$mem->set($relation['assets_id'],$model_name,0,0);
		}
	}

	foreach($hosts as $host){
		// skip internel ip
		if(preg_match('/^10\./',$host['ip'])){
			continue;	
		}

		// ip_id ---> host's serverid
		$mem->set($host['ip'].'_id',$host['serverId'],0,0);
		//$fetch_proc_url= $proc_url.$host['serverId'];
		//$proc=system("curl -s $fetch_proc_url ");
		//echo $proc;
		//set business_model
		$host['serviceName']=$mem->get($host['serverId']);	
		//find server guid by ip
		$mem->set($host['ip'],$host['serverGuid'],0,0);
		$host['ip1']=$host['isp'].'-'.$host['ip'];
		if(!$mem->add($host['serverGuid'],$host,0,0)){
			$pre_host=$mem->get($host['serverGuid']);
			// in case one machine have three ips
			if(array_key_exists('ip2',$pre_host)){
				$pre_host['ip3']=$host['isp'].'-'.$host['ip'];
			}
			else{
				$pre_host['ip2']=$host['isp'].'-'.$host['ip'];
			}
			$mem->set($host['serverGuid'],$pre_host,0,0);
		}
	}
	
}
else{
	alarm("bizop asset api error!!");
}


?>

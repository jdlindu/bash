<?php

function get($url){
	$ch = curl_init();
        curl_setopt($ch, CURLOPT_URL, $url);
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, TRUE);
        $content = curl_exec($ch);
        curl_close($ch);
	$result_array = json_decode($content,true);
        return $result_array['object'];
}

$asset_url='http://esb.sysop.duowan.com:35000/webservice/server/getAllServer.do';
$hosts=get($asset_url);
//print_r($hosts);
if($hosts){
	$mem_ip='127.0.0.1';
	$mem_port='11211';
	$mem = new Memcache;
	if(!$mem->connect($mem_ip,$mem_port)){
		echo "memcache can not connect!";
		exit;
	}
	$mem->flush();
	$time = time()+1; //one second future 
	while(time() < $time) { 
  		//sleep 
	}	 
	foreach($hosts as $host){
		if(preg_match('/^10\./',$host['ip'])){
			continue;	
		}
		$mem->set($host['ip'],$host['guid'],0,0);
		if(!$mem->add($host['guid'],$host,0,0)){
			$pre_host=$mem->get($host['guid']);
			// in case one machine have three ips
			if(array_key_exists('ip2',$pre_host)){
				$pre_host['ip3']=$host['ip'];
			}
			$pre_host['ip2']=$host['ip'];
			$mem->set($host['guid'],$pre_host,0,0);
		}
	}
		
}


?>

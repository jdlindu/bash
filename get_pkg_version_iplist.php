<?php
if(count($argv) < 2){
	echo "usage $argv[0] pkgname versionname \n";
	exit;
}
function get($url){
	    $ch = curl_init();
		curl_setopt($ch, CURLOPT_URL, $url);
		curl_setopt($ch, CURLOPT_RETURNTRANSFER, TRUE);
		$content = curl_exec($ch);
		curl_close($ch);
		return $content;
}
function get_all_pakages(){
		$url='http://yydeploy.sysop.duowan.com:9097/webservice/package/listPackages.do';
		$content_json=get($url);
		$content=json_decode($content_json,true);
		foreach($content['object'] as $pkg){
			$pkglist[]=$pkg['name'];
		}
		return $pkglist;
}
function check_pkgname($pkgname){
		$pkglist=array();
		$url='http://yydeploy.sysop.duowan.com:9097/webservice/package/listPackages.do';
		$content_json=get($url);
		$content=json_decode($content_json,true);
		//print_r($content);
		foreach($content['object'] as $pkg){
			if(strpos($pkg['name'],$pkgname)!==false){
				$pkglist[]=$pkg['name'];
			}
		}
		return $pkglist;
}
function list_version_instance($versioninfo){
	echo "包名\t\t\t\t版本号\t\t\t版本ID\t\t实例数量\n";
	foreach($versioninfo['object'] as $version){
		$url='http://yydeploy.sysop.duowan.com:9097/webservice/package/cutVersinIntanceIP.do?schName='.$version['packageName'].'&versionId='.$version['versionId'];
		$content_json=get($url);
		$content=json_decode($content_json,true);
		if(count($content['object']) > 0){
			echo $version['packageName']."\t\t".$version['version']."\t\t".$version['versionId']."\t\t".count($content['object'])."\n";
		}
	}
	
}
function get_versioninfo($pkg_name){
	
	$version_url='http://yydeploy.sysop.duowan.com:9097/webservice/package/listVersion.do?name='.$pkg_name;
	$versioninfo_json=get($version_url);
	$versioninfo=json_decode($versioninfo_json,true);
	return $versioninfo;
}

function get_versionid_by_name($version_name,$versioninfo){
	
	foreach($versioninfo['object'] as $version){
		if ($version['version']==  $version_name){
			return $version['versionId'];
		}
		else{
			continue;
		}
	}	

}

function get_version_ip($pkg_name,$version_id){

	$versionip_url='http://yydeploy.sysop.duowan.com:9097/webservice/package/cutVersinIntanceIP.do?schName='.$pkg_name.'&versionId='.$version_id;
	$version_ip_json=get($versionip_url);
	$version_iplist=json_decode($version_ip_json,true);
	return $version_iplist;
}

array_shift($argv);
$pkg_name=$argv[0];
$version_name="";
isset($argv[1]) && $version_name=$argv[1];

$versioninfo=get_versioninfo($pkg_name);
if(empty($versioninfo['object'])){
	echo "包名不存在！你是不是要找这些包\n";
	$pkglist=check_pkgname($pkg_name);
	if(!empty($pkglist)){
		echo implode("\n",$pkglist);
		echo "\n";
		exit;
	}
	else{
//		$pkglist=check_pkgname(substr($pkg_name,0,strlen($pkg_name)-4));
		$pkglist=check_pkgname(substr($pkg_name,0,4));
		echo implode("\n",$pkglist);
		echo "\n";
		exit;	
	}
}

if(!$version_name){

	echo "请选择你要找的版本:\n";
	list_version_instance($versioninfo);
	exit;
}
$version_id=get_versionid_by_name($version_name,$versioninfo);
if(!$version_id){
	echo "没有此版本！\n看看下面有没有你要找的版本吧\n";
	list_version_instance($versioninfo);
	exit;
}

$version_iplist=get_version_ip($pkg_name,$version_id);
echo preg_replace('/,.*/', '', implode("\n",$version_iplist['object']));
echo "\n";
?>

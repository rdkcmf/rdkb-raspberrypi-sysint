<?php
/*
 * If not stated otherwise in this file or this component's Licenses.txt file the 
 * following copyright and licenses apply:
 *
 * Copyright 2016 RDK Management
 *
 * Licensed under the Apache License, Version 2.0 (the License);
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and 
 * limitations under the License.
*/
?>
﻿<?php
ini_set('upload_tmp_dir','/var/tmp/');
$target = "/var/tmp/";
$target = $target.basename($_FILES['file']['name']);
if($_FILES["file"]["error"]>0){
	echo "Return Code: ".$_FILES["file"]["error"];
	exit;
} else {
		if(move_uploaded_file($_FILES['file']['tmp_name'], $target)){
			exec('sh /lib/rdk/confPhp restore '.$target,$output,$return_restore);
			$key_dec=$_POST['decryption_key'];
			if($key_dec ==''){
				echo "<script type='text/javascript'>alert('Please enter a valid secure key');window.location.href='upload_user_settings1.php';</script>";
			}
			else{
			$incorrect_key = "bad decrypt";
			$incorrect_key1 = "error";
			exec('openssl enc -d -aes-256-cbc -in /nvram/syscfg.enc -out /nvram/syscfg.db -k '.$key_dec.' 2>&1',$key_check,$return_var);
			$key_check=print_r($key_check,true);
			if (strpos($key_check,$incorrect_key) == false || strpos($key_check,$incorrect_key1) == false){
				exec('openssl enc -d -aes-256-cbc -in /nvram/bbhm_bak_cfg.enc -out /nvram/bbhm_bak_cfg.xml -k '.$key_dec);
                        	exec('openssl enc -d -aes-256-cbc -in /nvram/bbhm_cur_cfg.enc -out /nvram/bbhm_cur_cfg.xml -k '.$key_dec);
                        	exec('openssl enc -d -aes-256-cbc -in /nvram/hostapd0.enc -out /nvram/hostapd0.conf -k '.$key_dec);
                        	exec('openssl enc -d -aes-256-cbc -in /nvram/hostapd1.enc -out /nvram/hostapd1.conf -k '.$key_dec);
				exec('echo "CONF_RECOVER_STATUS_NEED_REBOOT" > /tmp/confPhp.status');
				if ($return_restore==-1) echo "Error when to restore configuration!";
				else {
					sleep(1);
					do {
						sleep(1);
						exec('sh /lib/rdk/confPhp status',$output,$return_var);
					} while ($return_var==1);
				}
				if($return_var == 2){
					setStr("Device.X_CISCO_COM_DeviceControl.RebootDevice","Device",true);
					echo "Rebooting...";
					echo "<script>setTimeout(function(){ window.close();}, 5000);</script>";
					echo "<p> <font color=red font face='arial' size='2pt'>This page will automatically close in 5 seconds</font> </p>";
				}
			}
			else{
				exec('mv /nvram/syscfg.db.prev /nvram/syscfg.db');
                		exec('mv /nvram/bbhm_cur_cfg.xml.prev /nvram/bbhm_cur_cfg.xml');
                		exec('mv /nvram/bbhm_bak_cfg.xml.prev /nvram/bbhm_bak_cfg.xml');
                		exec('mv /nvram/hostapd0.conf.prev /nvram/hostapd0.conf');
                		exec('mv /nvram/hostapd1.conf.prev /nvram/hostapd1.conf');
				echo "<script>type='text/javascript'>alert('Please check the secure key entered! Restore failure');window.location.href='upload_user_settings1.php';</script>";
			}
			exec('rm /nvram/syscfg.enc /nvram/bbhm_cur_cfg.enc /nvram/bbhm_bak_cfg.enc /nvram/hostapd0.enc /nvram/hostapd1.enc');
			}
		}
		else { echo "Error when to restore configuration!"; }
}
?>

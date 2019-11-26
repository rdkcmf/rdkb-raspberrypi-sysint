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
//$key_dec="e0e0e0e0f1f1f1f1";
$target = $target.basename($_FILES['file']['name']);
//echo $target;
if($_FILES["file"]["error"]>0){
	echo "Return Code: ".$_FILES["file"]["error"];
	exit;
} else {
		if(move_uploaded_file($_FILES['file']['tmp_name'], $target)){
			exec('sh /lib/rdk/confPhp restore '.$target,$output,$return_restore);
			//exec('openssl enc -des-ecb -K '.$key_dec.' -d -in '.$target.'.gz -out '.$target);
			if ($return_restore==-1) echo "Error when to restore configuraion!";
			else {
				sleep(1);
				do {
					sleep(1);
					exec('sh /lib/rdk/confPhp status',$output,$return_var);
				} while ($return_var==1);
			}
		}
		else { echo "Error when to restore configuraion!"; }
}
?>

<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<!-- $Id: header.php 3167 2010-03-03 18:11:27Z slemoine $ -->

<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en">
<head>
    <title>XFINITY</title>

</head>
<body>
    <!--Main Container - Centers Everything-->
	<div id="container">
		<div id="main-content">
		<?php
		echo "<h3>target $target</h3>";
		switch ($return_var) {
		case 1:
			echo "<h3>Error, get restore status failure</h3>";
			break;
		case 2:
			echo "<h3>Need Reboot to restore the saved configuration.</h3>";
			setStr("Device.X_CISCO_COM_DeviceControl.RebootDevice","Device",true);
			break;
		case 3:
			echo "<h3>Error, restore configuration failure!</h3>";
			break;
		default:
			echo "<h3>Restore configuration Failure! Please try later. </h3>";
			break;
		}
		?>
		</div>
	</div>
</body>
</html>

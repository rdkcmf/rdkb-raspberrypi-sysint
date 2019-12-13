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
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd"> 
<html xmlns="http://www.w3.org/1999/xhtml"> 
<head> 
    <title>XFINITY</title>

        <!--CSS-->
        <link rel="stylesheet" type="text/css" media="screen" href="cmn/css/common-min.css" />
        <link rel="stylesheet" type="text/css" media="print" href="cmn/css/print.css" />

        <!--Character Encoding-->
        <meta http-equiv="Content-Type" content="text/html;charset=utf-8" />

    <script type="text/javascript" src="./cmn/js/lib/jquery-1.9.1.js"></script>
    <script type="text/javascript" src="./cmn/js/lib/jquery-migrate-1.2.1.js"></script>
    <script type="text/javascript" src="./cmn/js/lib/jquery.validate.js"></script>
    <script type="text/javascript" src="./cmn/js/lib/jquery.alerts.js"></script>
        <script type="text/javascript" src="./cmn/js/lib/jquery.alerts.progress.js"></script>

        <script type="text/javascript" src="./cmn/js/utilityFunctions.js"></script>
    <script type="text/javascript" src="./cmn/js/comcast.js"></script>
        <script type="text/javascript">

     $(document).ready(function() {

                $('#restoreBtn').click(function(e){

                e.preventDefault();

                jConfirm(
                "Alert: Are you sure you want to Restore User settings? "+"<br/><br/><strong>WARNING:</strong> User settings from the uploaded backup file will be restored!<br/>Previous settings will be lost!"
                ,"Restore User Settings"
                ,function(ret) {
                if(ret) {

                        var path=document.getElementById('id1').value;
                        if((path==null || path=="")){
                                alert("Please Select a file to Restore the Configuration!");
                        }
                        else{
                                $('form').submit();
                        }
                } } );

         });

         $("#id1").focus();

         });

        </script>
</head>
<body style="background-color: #ffffff;">
        <form enctype="multipart/form-data" action="upload_user_settings2.php" method="post">
                <input id="id1" name="file" type="file" style="border: solid 1px;">   </input>
		</br>
		<label for="dec_key"><?php echo _("Secure key:")?></label> <input type="password" value="" name="decryption_key" id="dec_key" autocomplete="off" onblur="this.setAttribute('readonly', 'readonly');" onfocus="this.removeAttribute('readonly');" readonly/>
                </br>
                </br>
                <input id="restoreBtn" type="button" value="Restore"> </input>
        </form>
</body>
</html>

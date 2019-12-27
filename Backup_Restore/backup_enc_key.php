<?php
/*
 If not stated otherwise in this file or this component's Licenses.txt file the
 following copyright and licenses apply:

 Copyright 2018 RDK Management

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

 http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
*/
?>
<?php include('includes/header.php'); ?>
<?php include('includes/utility.php'); ?>
<div id="sub-header">
<?php include('includes/userbar.php'); ?>
</div><!-- end #sub-header -->
<?php include('includes/nav.php'); ?>
 <!--Character Encoding-->
        <meta http-equiv="Content-Type" content="text/html;charset=utf-8" />

    <script type="text/javascript" src="./cmn/js/lib/jquery-1.9.1.js"></script>
    <script type="text/javascript" src="./cmn/js/lib/jquery-migrate-1.2.1.js"></script>
    <script type="text/javascript" src="./cmn/js/lib/jquery.validate.js"></script>
    <script type="text/javascript" src="./cmn/js/lib/jquery.alerts.js"></script>
        <script type="text/javascript" src="./cmn/js/lib/jquery.alerts.progress.js"></script>

	<script src="//ajax.aspnetcdn.com/ajax/jquery.validate/1.9/jquery.validate.min.js"></script>
        <script type="text/javascript" src="./cmn/js/utilityFunctions.js"></script>
    <script type="text/javascript" src="./cmn/js/comcast.js"></script>


<script type="text/javascript">
$(document).ready(function() {
	gateway.page.init("Troubleshooting > Backup User Settings > Backup", "nav-backup-user");
	$("#backup_secure").validate({
                debug: true,
                rules: {
                        secure_key: {
                                required: true
                                ,minlength: 5
                        }
                },
                submitHandler:function(form){
                        click_save();
                }
	});
	$("#backup_secure").on("submit", function(){
		$("#backup_secure").validate();
 	})
	$("#cancel_key").click(function() {
                window.location.href = "backup_user_settings.php";
        });
});
function click_save()
	{
		var secure_key = $('#secure_key').val();
		var jsConfig = '{"key": "'+secure_key+'"}';
                        $.ajax({
                                type: "POST",
                                url: "actionHandler/ajax_at_saving_backup_key.php",
                                data: { configInfo: jsConfig },
				dataType:"json",
                                success: function(msg){
                                       		popUp("download_user_settings.php");
                                       		jHide();
						window.location.href = "backup_user_settings.php";
                                },
                                error: function(){
                                        jHide();
                                        jAlert("<?php echo _("Failure, please try again.")?>");
                                }
                        });
        }
function popUp(URL) {
        day = new Date();
        id = day.getTime();
        eval("page" + id + " = window.open(URL, '" + id + "', 'toolbar=0,scrollbars=0,location=0,statusbar=0,menubar=0,resizable=0,width=700,height=4i00,left = 320.5,top = 105');");
        }

</script>
<div id="content">
<h1>Troubleshooting > Backup User Settings > Backup</h1>
<form method="post" id="backup_secure">
	<div class="module forms" id="secure">
		<h2>Secure Key</h2>
		<h3>Enter secure key to backup files</h3>
		<div class="form-row odd password">
			<label for="secure_key"><?php echo _("Secure key:")?></label> <input type="password" value="" name="secure key" id="secure_key" autocomplete="off" minlength="5" required onblur="this.setAttribute('readonly', 'readonly');" onfocus="this.removeAttribute('readonly');" readonly/>
		</div>
	</div> <!-- end .module -->
	<div class="form-row form-btn">
		<input type="submit" class="btn submit" value="<?php echo _("Save")?>"/>
                <input id="cancel_key" type="reset" value="<?php echo _("Cancel")?>" class="btn alt" />
        </div>
</form>
</div><!-- end #content -->
<?php include('includes/footer.php'); ?>

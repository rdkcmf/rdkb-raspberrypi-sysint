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
<?php include('includes/header.php'); ?>

<!-- $Id: restore_reboot.php 3159 2010-01-11 20:10:58Z slemoine $ -->

<div id="sub-header">
	<?php include('includes/userbar.php'); ?>
</div><!-- end #sub-header -->

<?php include('includes/nav.php'); ?>


<script type="text/javascript">
$(document).ready(function() {
    gateway.page.init("Troubleshooting > Backup User Settings", "nav-backup-user");
});

function checkForRebooting() {
	$.ajax({
		type: "GET",
		url: "index.php",
		timeout: 10000,
		success: function() {
			/* goto login page */
			window.location.href = "index.php";
		},
		error: function() {
			/* retry after 2 minutes */
			setTimeout(checkForRebooting, 2 * 60 * 1000);
		}
	});
}

</script>
<div id="content">
  	<h1>Troubleshooting > Backup User Settings</h1>
	<div id="educational-tip">
		<p class="tip">Backup User Settings.</p>
		<p class="hidden">If you want to take a backup of the current user settings, press <strong>BACKUP</strong> to backup and download the file to your local </p>
		<p class="hidden">NOTE:<strong> BACKUP </strong>will save all your settings (passwords, parental controls, firewall) to a file which will be downloaded to your local.</p>

	</div>
	<form>
	<div class="module forms" id="backup">
		<h2>Backup User Settings</h2>
		<div id="div1" class="form-row">
			<span class="readonlyLabel"><a href="backup_enc_key.php?id=btn1" class="btn" title="Backup User settings" style="text-transform : none;">BACKUP</a></span>
                        <span class="value">Press "Backup User Settings" to save current user settings. <span style="padding-left:231px">All your current settings will be saved as a backup file in <span style="padding-left:231px">your local. </span></span></span>
                </div>
	</div> <!-- end .module -->
	</form>
</div><!-- end #content -->
<?php include('includes/footer.php'); ?>

jQuery(document).ready(function() {
	adminLockTimeLogging();
	checkLockTimeLogging();
});

function adminLockTimeLogging(){
	jQuery("#project_custom_field_values_15").change(function(){
		checkLockTimeLogging();
	});
}

function checkLockTimeLogging(){

	if(jQuery("#project_custom_field_values_15 option:selected").val() == "Admin"){
		var now = new Date(new Date().getFullYear()-1, 11, 31)
		var year = now.getFullYear();
		var month = now.getMonth() + 1;
		var date = now.getDate();
		var nowDate = year + "-" + month + "-" + date;
		lockDateElement = jQuery("#project_lock_time_logging");
		if(lockDateElement.val() == ""){
			lockDateElement.val(nowDate);
		}
		jQuery("span#lock_time_logging").show();
	} else {
		jQuery("span#lock_time_logging").hide();
		jQuery("#project_lock_time_logging").val("");
	}
}
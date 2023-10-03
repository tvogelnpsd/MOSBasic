#!/bin/zsh

################################################################
#
#	iosdump.sh  
#		Script pulls all iPads from Mosyle and sorts them out 
#		into other files.  These files are utilized after the
#		fact by other scripts.
#
#		JCS - 9/28/2021  -v2
#
################################################################
source "$BAGCLI_WORKDIR/config"
source "$BAGCLI_WORKDIR/common"
IFS=$'\n'


CMDRAN="iOSdump"

if [ "$MB_DEBUG" = "Y" ]; then
	echo "Variable 1-> $1"
	echo "Variable 2-> $2"
	echo "Variable 3-> $3"
	echo "Variable 4-> $4"
fi

################################
#            DO WORK           #
################################
#Remove any prior works generated by this script
rm -Rf "$TEMPOUTPUTFILE_Stu"
rm -Rf "$TEMPOUTPUTFILE_Teachers"
rm -Rf "$TEMPOUTPUTFILE_Limbo"
rm -Rf "$TEMPOUTPUTFILE_Shared"
rm -Rf "$TEMPOUTPUTFILE_MERGEDIOS"

#Initialize the base count variable. This will be
#used to figure out what page we are on and where
#we end up.
THECOUNT=0

# Connect to Mosyle API multiple times (for each page) so we
# get all of the available data.
while true; do
	let "THECOUNT=$THECOUNT+1"
	THEPAGE="$THECOUNT"
	content="{\"accessToken\":\"$APIKey\",\"options\":{\"os\":\"ios\",\"specific_columns\":\"deviceudid,serial_number,device_name,tags,asset_tag,userid,enrollment_type,username,date_app_info\",\"page\":$THEPAGE}}"
	cli_log "iOS CLIENTS-> Asking MDM for Page $THEPAGE data...."

	##This has been changed from running inside a variable to file output because there are some characers which mess the old
	#way up.  By downloading straight to file we avoid all that nonsense. -JCS 5/23/2022
	curl -s -k -X POST -d $content 'https://managerapi.mosyle.com/v2/listdevices' -o /tmp/MOSBasicRAW-iOS-Page$THEPAGE.txt

	#Detect we just loaded a page with no content and stop.
	LASTPAGE=$(cat "/tmp/MOSBasicRAW-iOS-Page$THEPAGE.txt" | grep DEVICES_NOTFOUND)
	if [ -n "$LASTPAGE" ]; then
		let "THECOUNT=$THECOUNT-1"
		cli_log "iOS CLIENTS-> Yo we are at the end of the list (Last good page was $THECOUNT)"
		break
	fi

	#TokenFailures
	LASTPAGE=$(cat "/tmp/MOSBasicRAW-iOS-Page$THEPAGE.txt" | grep 'accessToken Required')
	if [ -n "$LASTPAGE" ]; then
		let "THECOUNT=$THECOUNT-1"
		cli_log "MAC CLIENTS-> AccessToken error..."
		break
	fi
	
	#Are we on more pages then our max (IE something wrong)
	if [ "$THECOUNT" -gt "$MAXPAGECOUNT" ]; then 
		cli_log "MAC CLIENTS-> We have hit $THECOUNT pages...  Greater then our max.  Something is wrong."
		break
	fi

	#Preprocess the file.  We need to remove {"status":"OK","response": so can do operations with our python json to csv converter.  Yes
	#I know this is still janky but hay I'm getting there.
	cat /tmp/MOSBasicRAW-iOS-Page$THEPAGE.txt  | cut -d ':' -f 3- | sed 's/.$//' > /tmp/MOSBasicRAW-iOS-TEMPSPOT.txt
	mv -f /tmp/MOSBasicRAW-iOS-TEMPSPOT.txt /tmp/MOSBasicRAW-iOS-Page$THEPAGE.txt
	
	#Call our python json to csv routine.  Output will be tab delimited so we can maintain our "tags" together.
	$PYTHON2USE $BAGCLI_WORKDIR/modules/json2csv.py devices /tmp/MOSBasicRAW-iOS-Page$THEPAGE.txt "$TEMPOUTPUTFILE_MERGEDIOS"
done

# # #Build file of all this data now that we've sorted it out and parsed it.
# # #we still need the single/individual files for legacy support of other
# # #scripts but going forward the merge'd file will be the way to go.  
# NOTE these files only create if you set the LEGACYFILES variable in your config
# as I'm the only one who I think has scripts using them I didn't add this to the config
# as it will eventually be phased out - JCS 5/24/22
if [ "$LEGACYFILES" = "Y" ]; then
	cli_log "iOS CLIENTS-> Legacy Files support is enabled.  Creating legacy files for Student, Teacher, Limbo, and Shared."
	cat  "$TEMPOUTPUTFILE_MERGEDIOS" | grep "Student" > "$TEMPOUTPUTFILE_Stu"
	cat  "$TEMPOUTPUTFILE_MERGEDIOS" | grep "Teacher" > "$TEMPOUTPUTFILE_Teachers"
	cat  "$TEMPOUTPUTFILE_MERGEDIOS" | grep "Staff" >> "$TEMPOUTPUTFILE_Teachers"
	cat  "$TEMPOUTPUTFILE_MERGEDIOS" | grep "Leader" >> "$TEMPOUTPUTFILE_Teachers"
	cat  "$TEMPOUTPUTFILE_MERGEDIOS" | grep "GENERAL" > "$TEMPOUTPUTFILE_Limbo"
	cat  "$TEMPOUTPUTFILE_MERGEDIOS" | grep "SHARED" > "$TEMPOUTPUTFILE_Shared"
fi



#At this point I would run a follow up script to used the data we parsed above. All data above ends up 
#in an csv style sheet so its easy to use the "cut" command to parse that data.
if [ ! "$MB_DEBUG" = "Y" ]; then
	#Unless we are debugging then we need to cleanup after ourselves
	rm -f /tmp/MOSBasicRAW-iOS-*.txt
else
	cli_log "iOS CLIENTS-> DEBUG IS ENABLED.  NOT CLEANING UP REMAINING FILES!!!!"
fi
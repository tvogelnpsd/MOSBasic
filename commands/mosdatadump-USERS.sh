#!/bin/zsh

################################################################
#
#	userdump.sh  
#		Script pulls users from Mosyle and sorts them out 
#		into a single file.  
#
#		JCS - 9/28/2021  -v1
#
################################################################
source "$BAGCLI_WORKDIR/config"
source "$BAGCLI_WORKDIR/common"
IFS=$'\n'


CMDRAN="userdump"

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
rm -Rf "$TEMPOUTPUTFILE_Users"

rm -Rf /tmp/TEMP.json

#Initialize the base count variable. This will be
#used to figure out what page we are on and where
#we end up.
THECOUNT=0

# Connect to Mosyle API multiple times (for each page) so we
# get all of the available data.
while true; do
	let "THECOUNT=$THECOUNT+1"
	THEPAGE="$THECOUNT"
	#content="{\"accessToken\":\"$APIKey\",\"options\":{\"specific_columns\":\"deviceudid,serial_number,device_name,tags,asset_tag,userid,date_app_info\",\"page\":$THEPAGE}}"
	content="{\"accessToken\":\"$APIKey\",\"options\":{\"specific_columns\":[\"id\",\"name\",\"managedappleid\",\"type\"],\"page\":$THEPAGE}}"

	output=$(curl -s -k -X POST -d 'content='$content 'https://managerapi.mosyle.com/v2/listusers') >> $LOG
	
	#echo "$output"



	#Detect we just loaded a page with no content and stop.
	LASTPAGE=$(echo $output | grep 'users":\[\]')
	if [ -n "$LASTPAGE" ]; then
		let "THECOUNT=$THECOUNT-1"
		cli_log "Yo we are at the end of the list (Last good page was $THECOUNT)"
		break
	fi

	echo " "
	cli_log "Page $THEPAGE data."
	echo "-----------------------"
	# #Now take the JSON data we received and parse it into tab
	# #delimited output.
	#
	#Right from the git go exclude any results which are for General (Limbo) iPads, Shared iPads, Staff iPads, or Teacher iPads.
	#This creates the list of student iPads
	echo "$output"| awk 'BEGIN{FS=",";RS="},{"}{print $0}' |  perl -pe 's/.*"id":"?(.*?)"?,"name":"(.*?)","managedappleid":"?(.*?)"?,"type":"?(.*?)",*.*/\1\t\2\t\3\t\4/' >> "$TEMPOUTPUTFILE_Users"
	
done


#At this point I would run a follow up script to used the data we parsed above. All data above ends up 
#in an csv style sheet so its easy to use the "cut" command to parse that data.

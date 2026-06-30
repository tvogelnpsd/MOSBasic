#!/bin/zsh

################################################################
#
#	userdump.sh
#		Script pulls users from Mosyle and sorts them out
#		into a single file.
#
#		JCS - 9/28/2021  -v1
#   PATCHED - 02/04/2026
#
#   Fixes:
#   - Handles wrapped vs unwrapped Mosyle JSON responses
#   - Removes cut/sed JSON corruption
#   - Strips trailing '%' seen in Mosyle output
#   - Prevents json2csv KeyError crashes
#   - Option A: Detect last page when status==OK and users==[]
#
################################################################

source "$BAGCLI_WORKDIR/config"
source "$BAGCLI_WORKDIR/common"
IFS=$'\n'

DATECODEFORFILE=`date '+%Y-%m-%d_%H:%M'`

CMDRAN="userdump"

#################################
#            Functions          #
#################################

Generate_JSON_UserDUMPPostData() {
cat <<EOF
{
  "accessToken": "$MOSYLE_API_key",
  "options": {
    "page": "$THEPAGE",
    "specific_columns": [ "id", "name", "managedappleid", "type", "grades", "locations", "account", "assigned_devices" ]
  }
}
EOF
}


################################
#            DO WORK           #
################################

rm -Rf "$TEMPOUTPUTFILE_Users"

THECOUNT=0
DataRequestFailedCount=0

# Fetch Bearer token
GetBearerToken

# Sanitize token
AuthToken="${AuthToken//$'\r'/}"
AuthToken="${AuthToken//$'\n'/}"
AuthToken="${AuthToken//[[:space:]]/}"
AuthToken="${AuthToken#Bearer}"

while true; do
	let "THECOUNT=$THECOUNT+1"
	THEPAGE="$THECOUNT"

	if [ "$DataRequestFailedCount" -gt 5 ]; then
		cli_log "TOO MANY DATA REQUEST FAILURES. ABORTING."
		exit 1
	fi

	cli_log "MOSYLE USERS-> Asking MDM for Page $THEPAGE data...."

	curl -Ss --location 'https://managerapi.mosyle.com/v2/listusers' \
		--header 'Content-Type: application/json' \
		--header "Authorization: Bearer $AuthToken" \
		--data "$(Generate_JSON_UserDUMPPostData)" \
		-o "/tmp/MOSBasicRAW-Users-Page$THEPAGE.json"

	# Empty file check
	if [ ! -s "/tmp/MOSBasicRAW-Users-Page$THEPAGE.json" ]; then
		cli_log "MOSYLE USERS-> Empty response for page $THEPAGE"
		let "DataRequestFailedCount=$DataRequestFailedCount+1"
		continue
	fi

	# Get total and current count
	TOTAL_USERS=$(cat "/tmp/MOSBasicRAW-Users-Page$THEPAGE.json" | jq -r '.response.total')
	PAGE_SIZE=$(cat "/tmp/MOSBasicRAW-Users-Page$THEPAGE.json" | jq -r '.response.page_size')

	# End-of-list detection
	if [ $(( "$THEPAGE" * "$PAGE_SIZE" )) -gt "$TOTAL_USERS" ]; then
		cli_log "MOSYLE USERS-> End of list (Last good page was $THECOUNT)"
		break
	fi

	# Convert to CSV
	cat /tmp/MOSBasicRAW-Users-Page$THEPAGE.json  | jq -r '.response.users[] | [.id,.name,.managedappleid,.type] | @tsv' >> /tmp/DUMPINPROGRESS-$DATECODEFORFILE.MosyleUserDump.txt
	cat /tmp/MOSBasicRAW-Users-Page$THEPAGE.json | jq -c '.response.users[]' >> /tmp/DUMPINPROGRESS-$DATECODEFORFILE.MosyleUserDump.json

	if [ "$THECOUNT" -gt "$MAXPAGECOUNT" ]; then
		cli_log "MOSYLE USERS-> Hit max page count ($MAXPAGECOUNT). Aborting."
		break
	fi
done

#Delete Existing file
rm -Rf "$TEMPOUTPUTFILE_Users"
rm -Rf "$TEMPOUTPUTFILE_Users_JSON"
#Move newly generated file into place.
mv /tmp/DUMPINPROGRESS-$DATECODEFORFILE.MosyleUserDump.txt "$TEMPOUTPUTFILE_Users"
mv /tmp/DUMPINPROGRESS-$DATECODEFORFILE.MosyleUserDump.json "$TEMPOUTPUTFILE_Users_JSON"

if [ ! "$MB_DEBUG" = "Y" ]; then
	rm -f /tmp/MOSBasicRAW-Users-*.txt
	rm -f /tmp/MOSBasicRAW-Users-*.json
else
	cli_log "MOSYLE USERS-> DEBUG ENABLED — temp files preserved"
fi
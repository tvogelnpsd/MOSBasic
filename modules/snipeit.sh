#!/bin/zsh

####File with IncidentIQ Keys in the form of:
# apitoken="S0M3KeY"
# baseurl="https://<YOUR SNIPE IT URL>.com/api/v1
source $LOCALCONF/.SnipeIT
#apitoken, siteid, and baseurl all come from the source file above

USERLOOKUP=TRUE
USERLOOKUP() {
	USER2Search="$1"
	Auth=$(echo "Authorization: Bearer $apitoken")
	Query="$baseurl/users?username=$USER2Search"

	if [ "$MB_DEBUG" = "Y" ]; then
		echo "${Orange}$Query${reset}"
	fi

	#Do initial query with Serial # and cache the result
	InitialQuery=$(curl -s -H "$Auth" "$Query")
	#echo "$InitialQuery"

	if [ "$MB_DEBUG" = "Y" ]; then
		echo "${Orange}$InitialQuery${reset}"
	fi

	Username=$(echo "$USER2Search")


	FirstName=$(echo "$InitialQuery" | jq -r '.rows[].first_name' )
	
	LastName=$(echo "$InitialQuery" | jq -r '.rows[].last_name' )
	
	SchoolIdNumber="NOTSUPPORT"
	
	SnipeID=$(echo "$InitialQuery" | jq -r .'rows[].id')
	
	Grade=$(echo "$InitialQuery" | jq -r '.rows[].department.name' )
	#Returns graduating year or "Staff" if staff member
	
	Homeroom="NOTSUPPORT"
	
	LocationName=$(echo "$InitialQuery" | jq -r '.rows[].location.name' )
	if [ "$MB_DEBUG" = "Y" ]; then
		echo "${Orange}DEBUG===> First name: $FirstName"
		echo "DEBUG===> Last name: $LastName"
		echo "DEBUG===> Snipe-IT ID: $SnipeID"
		echo "DEBUG===> Grade: $Grade"
		echo "DEBUG===> Location: $LocationName${reset}"
	fi
}

GETSERIAL=TRUE
GetSerialFromTag() {
	Tag2Lookup="$1"

	Auth=$(echo "Authorization: Bearer $apitoken")
	Query="$baseurl/hardware/bytag/$Tag2Lookup"

	InitialQuery=$(curl -s -H "$Auth" "$Query")
	
	DeviceSerial=$(echo "$InitialQuery" | jq -r '.serial')
	
	if [ -z "$DeviceSerial" ]; then
		RETURNSERIAL="EPICFAIL"
		cli_log "SnipeIT doesnt know Tag2Lookup!"
		
	else
		RETURNSERIAL="$DeviceSerial"
	fi
	
		
}

DEVICELOOKUP=FALSE
DEVICELOOKUP() {
	Tag2Lookup="$1"

	Auth=$(echo "Authorization: Bearer $apitoken")
	Query="$baseurl/hardware/bytag/$Tag2Lookup"


}

TICKETLOOKUP=FALSE
TICKETLOOKUP() {
	echo "Sorry this feature is not ready yet!"
	exit 1
}

SUBMITTICKET=FALSE
SUBMITTICKET() {
	echo "Sorry this feature is not ready yet!"
	exit 1
}

INVENTORYASSIGN=TRUE
INVENTORYASSIGNDEVICE() {
	#Assumues asset tag and username given
	Tag2Assign="$1"
	User2Assign="$2"
	Auth=$(echo "Authorization: Bearer $apitoken")
	TagQuery=$(curl -s -H "$Auth" "$baseurl/hardware/bytag/$Tag2Assign")
	UserQuery=$(curl -s -H "$Auth" "$baseurl/users?username=$User2Assign")

	DEVICE_ID=$(echo "$TagQuery" | jq -r '.id')
	USER_ID=$(echo "$UserQuery" | jq -r '.rows[].id')

	Generate_JSON_SnipeAssign(){
		cat <<EOF
	{"checkout_to_type": "user",
	"status_id": 2,
	"assigned_user": $USER_ID
}
EOF
	}

	if [ "$MB_DEBUG" = "Y" ]; then
		echo "${Orange}Snipe Device ID: $DEVICE_ID"
		echo "Snipe User ID: $USER_ID"
		echo "Snipe Data JSON:"
		echo "$(Generate_JSON_SnipeAssign)${reset}"
	fi

	SNIPEOUTPUT=$(curl -s -H "$Auth" "$baseurl/hardware/$DEVICE_ID/checkout" -H "accept: application/json" -H "content-type: application/json" --data "$(Generate_JSON_SnipeAssign)")
}

INVENTORYUNASSIGN=FALSE
INVENTORYUNASSIGNDEVICE() {
	echo "Sorry this feature is not ready yet!"
	exit 1
}
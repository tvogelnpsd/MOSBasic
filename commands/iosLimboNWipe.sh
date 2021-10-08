#!/bin/zsh

################################################################
#
#	iosLimboNWipe.sh  
#		Script takes input of asset tag, looks up serial, then
#		tells Mosyle to Limbo the device and wipe the device.
#
#		JCS - 9/30/2021  -v1
#
################################################################


source "$BAGCLI_WORKDIR/config"
source "$BAGCLI_WORKDIR/common"
IFS=$'\n'


CMDRAN="iOSLimboNWipe"

echo "Variable 1-> $1"
echo "Variable 2-> $2"
echo "Variable 3-> $3"
echo "Variable 4-> $4"

#Delete our file of previous scanned devices if it exists
rm -Rf /tmp/Scand2Wipe.txt
rm -Rf /tmp/Scand2Wipe_Serialz.txt

#############################
#          Do Work          #
#############################
#This would be a routine for doing Scan and Go based on $1 equaling --scan
if [ "$1" = "--scan" ]; then

	#prompt User to scan.
	echo "${Green}Please scan an asset tag.  When you've scanned"
	echo "them all just press ENTER to give me a blank${reset}"

	read scannedin
	echo "$scannedin" > /tmp/Scand2Wipe.txt
	
	#Do a loop and keep taking scan data until we get null
	while true; do
		
		read scannedin
		echo "$scannedin" >> /tmp/Scand2Wipe.txt
		
		if [ -z "$scannedin" ]; then
			echo "${Green} Last code scanned.  Proceeding."
			break
		fi
	done
	
	cat "/tmp/Scand2Wipe.txt" | while read TAG_GIVEN; do
		
		echo "DEBUG-> This is where we lookup $TAG_GIVEN"
		
		if [ -z "$TAG_GIVEN" ]; then
			echo "DEBUG-> Blank tag <$TAG_GIVEN> scanned.  Skipping."
			break
		fi
		
		SerialFromTag

		if [ "$RETURNSERIAL" = "EPICFAIL" ]; then
			echo "${Red}Cant find $TAG_GIVEN in cached Mosyle data.  EPIC FAIL${reset}"
			echo "${Red}Skipping $TAG_GIVEN.  EPIC FAIL${reset}"
		else
			echo "Asset tag $TAG_GIVEN is $RETURNSERIAL"
			echo "$RETURNSERIAL" >> /tmp/Scand2Wipe_Serialz.txt

			#if this is our first entry just fill the variable
			if [ -z "$UDiDs" ]; then
				UDiDs="$UDID"
			else
				#all others are additons to the variable
				UDiDs=$(echo "$UDiDs,$UDID")
			fi
		fi
	done
		

#This would be a routine for doing a bunch of devices from file based on $1 equaling --mass
# and $2 equaling where to find a file.  File would be asset tag per line.
elif [ "$1" = "--mass" ]; then
		echo "MASS ABILITY IS NOT YET READY..  Fail.. for now."

#This Routine is for doing a single asset tag.
#Pull all serials from file and parse to get UDiD numbers.
else 
	TAG_GIVEN="$1"

	SerialFromTag

	if [ "$RETURNSERIAL" = "EPICFAIL" ]; then
		echo "${Red}Cant find $1 in cached Mosyle data.  EPIC FAIL${reset}"
	
	else
		echo "Asset tag $TAG_GIVEN is $RETURNSERIAL"
		echo "$RETURNSERIAL" >> /tmp/Scand2Wipe_Serialz.txt
		
	#if this is our first entry just fill the variable
		if [ -z "$UDiDs" ]; then
			UDiDs="$UDID"
		else
			#all others are additons to the variable
			UDiDs=$(echo "$UDiDs,$UDID")
		fi
	fi
fi

#echo "UDIDs--> $UDiDs"

#At this point we are almost ready to do the wipe and limbo
if [ -z "$UDIDs" ]; then

	echo "Proceeding to Wipe the following:"
	echo "----------------------------------"
	cat /tmp/Scand2Wipe_Serialz.txt
	
	echo "Are you sure <Y/N>"
	
	read shouldwedoit
	
	if [ "$shouldwedoit" = "Y" ]; then
		echo "Making it So #1."
		#Call out to Mosyle MDM to submit list of UDIDs which need Limbo'd
		content="{\"accessToken\":\"$APIKey\",\"elements\":[{\"devices\":\"$UDiDs\",\"operation\":\"change_to_limbo\"}]}"
		curl  -s -k -X POST -d 'content='$content 'https://managerapi.mosyle.com/v2/bulkops'

		content="{\"accessToken\":\"$APIKey\",\"elements\":[{\"devices\":\"$UDiDs\",\"operation\":\"wipe_devices\"}]}"
		curl  -s -k -X POST -d 'content='$content 'https://managerapi.mosyle.com/v2/bulkops'
		
		exit 0
		
	else
		echo "Its ok... we all get cold feet sometimes...."
		exit 1
	fi
else
	echo "No UDIDs are in cache.  Cant continue"
	exit 1
fi

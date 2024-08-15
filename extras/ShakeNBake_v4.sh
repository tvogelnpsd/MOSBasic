#!/bin/zsh
#
# ShakeNBake.sh
###################
# Based on JCSmillie's ShakeNBake_V3.sh
# Utilize cfgutil and leverage Mosyle MDM Api to mass process
# ipads.  Process also relies on MOSBasic for some data files
# as well as configurations.  -- JCS Summer 22'
############
#
###PROFILE TO BE USED ON LOANER DEVICES - This has to be a wifi profile which cna get on to 
###a provisioning network.  If your not doing Shared iPads this can be ignored.
LOANERWIFIPROFILE="/Users/Shared/ShakeNBake/Profiles/GSD-Loaner-Wifi.mobileconfig"
###PROFILE TO BE USED ON LIMBO DEVICES - This has to be a wifi profile which cna get on to 
###a provisioning network.
LIMBOWIFIPROFILE="/Users/Shared/ShakeNBake/Profiles/NP-EAGLES_Student.mobileconfig"

#Location for log output
LOGLOCATION="/Users/Shared/ShakeNBake/Logs"
#Location for Markerfile storage.  These are files SNB creates
#along the way to keep track of where it is at in the process.
TMPLOCATION="/Users/Shared/ShakeNBake/MarkerFiles"
#This option is for use with LoanerMonitor.sh... for the public
#version it should be ignored.
EXTRACFGS="/Users/Shared/ShakeNBake/config"

#This file is for local options like enable debug and setting prep Mode
#	DEBUG="Y"				<--Enable Debug
#	DEPLOYMODE="LOANER"		<-Set Deploy mode to Loaner.  Options are LOANER/WIPEONLY
#
#With no file or arguments we assume debug no and Deploymode is standard wipe, temp wifi profile, and DEP finish.
#
#		No Argument goes through DEP setup and uses regular wifi profile
#
#	Loaner profile should be for our network that is everywhere.  We don't want
#	students to login to our primary network as themselves for simplicity.
#
#	Regular wifi profile would be for a network that only exists 


#Options above (DEBUG / DEPLOYMODE ) can also be kept in a local file so that
#updates to this script can be done without worry of loosing changes.
#
# NOTE-> IF DEBUG IS ENABLED IN MOSBasic it will also be enabled here.
if [ -f "$EXTRACFGS/localcfgs.txt" ]; then
	source "$EXTRACFGS/localcfgs.txt"
fi

GENERALLOG="$LOGLOCATION/ShakeNBake.log"


BAGCLI_WORKDIR=$(readlink /usr/local/bin/mosbasic)
#Remove our command name from the output above
BAGCLI_WORKDIR=${BAGCLI_WORKDIR//mosbasic/}

#Make sure we have a location on MOSBasic commands.
if [ -z "$BAGCLI_WORKDIR" ]; then
	echo "You don't appear to have MOSBasic fully installed.  FAIL"
	exit 1
fi


export BAGCLI_WORKDIR
source "$BAGCLI_WORKDIR/config"
source "$BAGCLI_WORKDIR/common"

################################
#          FUNCTIONS           #
################################
log_line() {
        LINE=$1
        TODAY=$(date '+%a %x %X')
        
		if [ "$DEBUG" = "Y" ]; then
			#Print on stdout
	        echo "${Magenta}$TODAY =====>$LINE"
			echo "$ECID / $UDID / $buildVersion / $locationID${reset}"
		fi			
		
        #Log to file
        echo "ShakeNBake_V2.sh ++> $TODAY =====> $LINE" >> "$GENERALLOG"
		
		#If we have an ECID at this point also put data
		#into seperate log.
		if [ -n "$UDID" ]; then
        	echo "ShakeNBake_V2.sh ++> $TODAY =====> $LINE" >> "$LOGLOCATION/CFGUTIL_LOG_$UDID.txt"
		fi
}

RestoreDevice() {
	
	#If device is booted (IE NOT DFU OR FAC RESTORE) and WE CAN PAIR THEN TRY TO ERASE.
	#Without trust you cant pair.  Without pairing you can't erase so if no dont even try.		
	if [ "$Devicebootstate" = "Booted" ]; then
		if  [ "$Devicepairingstate" = "yes" ]; then
			HayLookAtMe "We appear to have AC2 TRUST - ATTEMPTING ERASE"
			#Try to Erase First
			DoIT=$(cfgutil --ecid "$ECID" erase  2>/dev/null )
			

			if [ "$?" = "1" ]; then
				log_line "ERASE: Epic Fail on $ECID / $UDID.    Can't continue.  Put iPad in DFU or Factory Recovery Mode and try again."
				HayLookAtMe "iPad Update ${Red}Fail..  Put in DFU mode and try again."
				rm -Rf "$TMPLOCATION/CFGUTIL_$ECID.txt"
				exit 1

			else
				log_line "ERASE Success ($UDID) - Next Steps will happen when iPad boots back up."
				HayLookAtMe "TRUST ERASE successful!"
				rm -Rf "$TMPLOCATION/CFGUTIL_$ECID.txt"
				HayLookAtMe "Take a breath...  Waiting a few before moving on so iPad can catch up."
				sleep 60
				#exit 1

			fi
		elif [ "$IN_MOSYLE" = "TRUE" ]; then
			#If we are here its because the iPad is Booted, but not paired.
			log_line "RESTORE: $ECID / ($UDID) appears to be in a booted but not paired. ($Devicebootstate / $Devicepairingstate)."
			HayLookAtMe "No AC2 TRUST.  Trying Mosyle wipe."
			#Attempt to do an OTA wipe.  If iPad has checked into Mosyle in less than 12 hrs its a fair chance it works
			#out...
			WipeOTAMosyle
		else
			log_line "RESTORE: $ECID / ($UDID) appears to be in a booted but not paired. ($Devicebootstate / $Devicepairingstate)."
			HayLookAtMe "No AC2 TRUST.  Device not found in Mosyle data."
			log_line "RESTORE: Epic Fail on $ECID.  Can't continue.  Put iPad in DFU or Factory Recovery Mode and try again."
		    rm -Rf "$TMPLOCATION/CFGUTIL_$ECID.txt"
		    HayLookAtMe "iPad Update ${Red}Fail..  Put in DFU mode and try again."
		    exit 1
		fi
		
	elif  [ "$Devicebootstate" = "DFU" ] || [ "$Devicebootstate" = "Restore" ]; then
		HayLookAtMe "iPad is in DFU/Restore Mode...."
		log_line "RESTORE: $ECID / ($UDID) device in DFU/Restore mode.  Jumping right to restore attempt."
		FullPressWipe=$(cfgutil --ecid "$ECID" restore  2>/dev/null )

		if [ "$?" = "1" ]; then
			log_line "RESTORE: Epic Fail on $ECID / ($UDID).  Can't continue.  Put iPad in DFU or Factory Recovery Mode and try again."
			rm -Rf "$TMPLOCATION/CFGUTIL_$ECID.txt"
			HayLookAtMe "iPad Update ${Red}Fail..  Put in DFU mode and try again."
			exit 1

		else
			log_line "RESTORE Success ($UDID) - Next Steps will happen when iPad boots back up."
			HayLookAtMe "Restore SUCCESS."
			rm -Rf "$TMPLOCATION/CFGUTIL_$ECID.txt"
			exit 0
		fi
		
	else
		log_line "RESTORE: Epic Fail on $ECID.  Can't continue.  Put iPad in DFU or Factory Recovery Mode and try again."
		rm -Rf "$TMPLOCATION/CFGUTIL_$ECID.txt"
		HayLookAtMe "iPad Update ${Red}Fail..  Put in DFU mode and try again."
		exit 1
		
	fi
}

CheckBuildVersion() {
	#This chunk of code is all new.  Back in April 22' an AppleSE inquired about how do I know a device needs
	#updated or note.  Originally I had a manual table listed of build numbers.  This table had to be updated
	#every time a new version comes out though.  Instead now we ask Apple for a list of all device types and
	#what version of iPadOS they should have.  Ask the iPad what firmware it has, compare, and act.  
	
	#Make sure we have a data file from Apple about currently available iOS/iPadOS versions.
	#NOTE-> This function comes from MOSBasic/Common
	GetAppleUpdateData
	
	#User CFGUTIL to figure out the Model (by deviceType ID) and current
	#version of iPadOS running.
	deviceType=$(cfgutil --ecid "$ECID" get deviceType 2</dev/null)
	firmwareVersion=$(cfgutil --ecid "$ECID" get firmwareVersion 2</dev/null)

	if [ "$DEBUG" = "Y" ]; then
		echo "We are looking at a device with type ($deviceType) running firmware version ($firmwareVersion)"
	fi

	#Cat the fie of Apple update data.  Use AWK to print out everything until we hit the device we
	#have.  Now AWK again to find out waht the latest version attributed is.  Use cut to get us down to just
	#a variable.
	#AwkWithDeviceVariable=$(echo "{print} /$deviceType/ {exit}")
	#GetOSVersion=$(cat /tmp/data.json | awk "$AwkWithDeviceVariable" | grep ProductVersion | cut -d ':' -f 2 | cut -d '"' -f 2 | sort -n | tail -1)

    # Switched this to use jq to parse JSON
    GetOSVersion=$(cat /tmp/data.json | jq --arg DEV $deviceType -r '.PublicAssetSets.iOS[] | select(.SupportedDevices | contains([$DEV])) | .ProductVersion' | sort | tail -1)

	#Test data we got back.
	if [ -z "$GetOSVersion" ]; then
		echo "Lookup of supported iOS/iPadOS didn't work.  Cant check update status."
	elif [ "$DEBUG" = "Y" ]; then
		echo "Apple updates site says $deviceType should be running $GetOSVersion"
	fi


	autoload is-at-least

	#If versions match we can mobe on
	if [ "$firmwareVersion" = "$GetOSVersion" ]; then
		echo "iPad is running latest available ($firmwareVersion.)  No update necessary."
		UPDATE="FALSE"

	elif is-at-least "$firmwareVersion" "$GetOSVersion"; then
		echo "This iPad needs updated. OS installed ($firmwareVersion) is older then what is should be ($GetOSVersion)"
		UPDATE="TRUE"
		
	else
		echo "Couldn't get a lock on what we should do ($firmwareVersion/$GetOSVersion) so no update will be called for."
		UPDATE="FALSE"
	fi
}

iPadOSInstallVersion() {
	#buildVersion comes from cfgutil exec -a <script> like UDID and ECID does.
	log_line "($ECID) Our Build Version is=> ($buildVersion)"
	
	#Call build version check above
	CheckBuildVersion
	if [ "$UPDATE" = "TRUE" ]; then
		
		HayLookAtMe "iPad needs updated ($buildVersion)"

		if [ "$RWeActivated" = "Unactivated" ]; then

			#Somehow we have an unactivated iPad that isnt up to date.  Update it
			JustUpdate=$(cfgutil --ecid "$ECID" update 2>/dev/null)

			if [ "$?" = "1" ]; then
				log_line "RESTORE/UPDATE: Epic Fail on $ECID / ($UDID).  Can't continue.  Put iPad in DFU or Factory Recovery Mode and try again."
				rm -Rf "$TMPLOCATION/CFGUTIL_$ECID.txt"
			
				HayLookAtMe "iPad Update ${Red}Fail..  Put in DFU mode and try again."
				exit 1

			else
				log_line "RESTORE/UPDATE: Success ($UDID) - Next Steps will happen when iPad boots back up."
				rm -Rf "$TMPLOCATION/CFGUTIL_$ECID.txt"
				HayLookAtMe "iPad Update SUCCESS.."
			
				#Dont exit..  CFGUTIL doesnt see restore when done to an awake ipad as
				#a reconnection.
				#exit 0
			fi

		else
			#Call to RESTORE the iPad
			FullPressWipe=$(cfgutil --ecid "$ECID" restore 2>/dev/null)

			if [ "$?" = "1" ]; then
				log_line "RESTORE/UPDATE: Epic Fail on $ECID / ($UDID).  Can't continue.  Put iPad in DFU or Factory Recovery Mode and try again."
				rm -Rf "$TMPLOCATION/CFGUTIL_$ECID.txt"

				HayLookAtMe "iPad Update ${Red}Fail..  Put in DFU mode and try again."
				exit 1

			else
				log_line "RESTORE/UPDATE: Success ($UDID) - Next Steps will happen when iPad boots back up."
				rm -Rf "$TMPLOCATION/CFGUTIL_$ECID.txt"
				HayLookAtMe "iPad Update SUCCESS.."

				#Dont exit..  CFGUTIL doesnt see restore when done to an awake ipad as
				#a reconnection.
				#exit 0
			fi
		fi
	
	else
		HayLookAtMe "iPadOS is current ($firmwareVersion)"
	fi
}

InstallProfileDevice() {
	#$CFGUTIL restore
	DoIT=$(cfgutil --ecid "$ECID" install-profile "$TEMPORARYWIFIPROFILE" 2>/dev/null | tail -1)
	 log_line "INSTALL-WIFI: Error Code Status ($?)"
	 log_line "INSTALL-WIFI: Results: $DoIT"
	
	log_line "$DoIT"
	
	log_line "INSTALL-WIFI: WiFi Profile Installed on $ECID, waiting for it to initialize.."
	
	#We need to monitor this... Its a step that can fail and then put us into an infinite loop.
	WAITCounter="0"
	
	#Loop until we can talk to device successfully.
	while true ; do
	
		#Escape hatch..  if we wait 60s and its still not activated FAIL.
		if [ "$WAITCounter" -gt 60 ]; then
			log_line "INSTALL-WIFI: Something went wrong with $Refer2MeAs.  We've waited $WAITCounter seconds.  Aborting preparation!"
			rm -Rf "$TMPLOCATION/CFGUTIL_$ECID.txt"
			exit 1
		fi
	
		#Check to see if iPad is activated
		RWeActivated=$(cfgutil --ecid "$ECID" get activationState 2>/dev/null)

		#If iPad is activated lets move on.
		if [ "$RWeActivated" = "Activated" ]; then
			log_line "INSTALL-WIFI: $Refer2MeAs is activated.  Moving on!"
			break
			
		else
			#If we are here its because the device is not activated..
			#Lets wait..
			log_line "INSTALL-WIFI: Waiting for $ECID to come back to us.... ($Devicepairingstate)"
			sleep 5
			#Add 5 seconds to the WaitCounter
			(( WAITCounter=WAITCounter+5 ))
			log_line "INSTALL-WIFI: We have waited $WAITCounter seconds on $ECID so far..."
		fi
	done
}

PrepareDevice() {
	#We need to monitor this... Its a step that can fail and then put us into an infinite loop.
	WAITCounter="0"
	#Loop until we can talk to device successfully.
		while true ; do
			#Prepare Device
			
			if [ "$WAITCounter" -gt 60 ]; then
				log_line "PREPARE: Something is wroung with $Refer2MeAs.  We've waited $WAITCounter seconds.  Aborting prepare!"
				rm -Rf "$TMPLOCATION/CFGUTIL_$ECID.txt"
				HayLookAtMe "$Refer2MeAs never came back.  DFU and try again..."
				exit 1
			fi
			
			GetDeviceState=$(/usr/local/bin/cfgutil --ecid "$ECID" get bootedState isPaired 2>/dev/null)
			Devicebootstate=$(echo "$GetDeviceState" | grep -a1 bootedState: | tail -1)
			Devicepairingstate=$(echo "$GetDeviceState" | grep -a1 isPaired: | tail -1)
			
			log_line "$ECID--> ($Devicebootstate) / ($Devicepairingstate)"
			
			#if iPad is Booted and paired we should be able to finish --THIS SHOULD BE AND but I couldnt get it to work:(
			if [ "$Devicebootstate" = "Booted" ]; then
				log_line "CHECK FOR BOOTED STATUS"
				if  [ "$Devicepairingstate" = "yes" ]; then
					log_line "CHECK FOR PAIRING STATE YES"
					DoIT=$(cfgutil --ecid "$ECID" prepare --dep --skip-language --skip-region  2>/dev/null)
				
					if [ "$?" = "0" ]; then
						log_line "PREPARE: Welcome back $ECID.  Continuing...."
						break
						
					else
						log_line "PREPARE: $ECID ($Refer2MeAs) is prepared.. but double check it."
						break
					fi
				else
					log_line "PREPARE: Waiting for $ECID to come back to us.... (booted, not paired)"
					sleep 5
					#Add 5 seconds to the WaitCounter
					(( WAITCounter=WAITCounter+5 ))
					log_line "PREPARE: We have waited $WAITCounter seconds on $ECID so far..."
					HayLookAtMe "Waiting for $Refer2MeAs to come back..."
			fi
				
			else
				#If we are here its because the device is either not booted or not paired.
				#Lets wait..
				log_line "PREPARE: Waiting for $ECID to come back to us...."
				sleep 5
				#Add 5 seconds to the WaitCounter
				(( WAITCounter=WAITCounter+5 ))
				log_line "PREPARE: We have waited $WAITCounter seconds on $ECID so far..."
				HayLookAtMe "Waiting for $Refer2MeAs to come back..."
			fi
		done
}

###THIS REALLY SHOULD BE REWROTE TO LEAN ON MOSBasic instead of going it alone.  If we rely on MOSBasic
###As our code evolves over there we automatically benefit here.
WipeOTAMosyle() {
	#Build Query.  Just asking for current data on last beat, lostmode status, and location data if we can get it.

	GetCurrentInfo-ios

	#Figure out how many hours ago last beat was
	current_time=$(date +%s)
	hoursago=$(expr "$current_time" - "$LASTCHECKIN_RAW" )
	hoursago=$(expr "$hoursago" / 3600 )	

	log_line "Hours Ago-> ($hoursago)"
	
	if [ "$hoursago" -lt 12 ]; then
		log_line "WIPE VIA MOSYLE: $ECID / ($UDID) iPad last checked in $hoursago, less than 12..  Attempting Over the Air Wipe."
		HayLookAtMe "Last check in $hoursago ago.  Attempting OTA Wipe."

		export RTS_ENABLED="N"

		CMDStatus=$(mosbasic ioswipe "$Refer2MeAs")
		
		log_line "WIPE VIA MOSYLE: $ECID / ($UDID) OTA wipe device sent...  All we can do now is hope.  Give it 5..  Doesn't work out"
		log_line "then Put iPad in DFU or Factory Recovery Mode and try again."
		HayLookAtMe "OTA Wipe sent...  Give it a few.  If nothing happens try DFU mode."
		
		#Remove our tmp file so when iPad comes back... if it comes back we start the cycle over again.
		rm -Rf "$TMPLOCATION/CFGUTIL_$ECID.txt"
		exit 1
		
	else
		log_line "WIPE VIA MOSYLE: $ECID / ($UDID) / $DeviceSerialNumber / $ASSETTAG iPad last checked in $hoursago, more than 12..  Not attempting Over the Air Wipe."
		log_line "WIPE VIA MOSYLE: Epic Fail on $ECID.  Can't continue.  Put iPad in DFU or Factory Recovery Mode and try again."
		rm -Rf "$TMPLOCATION/CFGUTIL_$ECID.txt"
		HayLookAtMe "Last check in way too many hours ago ($hoursago) not trying OTA Wipe...  ${Red}EPIC FAIL!"
		exit 1
	fi
}

MosyleTidyUp() {
	if [ "$ISSHARED" = "TRUE" ]; then
		log_line "MosyleTidyUp: $Refer2MeAs is a Shared iPad.  Will not Limbo."
		HayLookAtMe "Shared iPad.  Not sending to Limbo."
	else
		log_line "MosyleTidyUp: Sending $Refer2MeAs to Limbo"
		
        CMDStatus=$(mosbasic ioslimbo "$Refer2MeAs" | tail -n 1)

		if echo "$CMDStatus" | grep -qi "Fail" ; then
			log_line "$CMDStatus"
			HayLookAtMe "Sending iPad to Limbo ${Red}FAILED!"
			

		elif echo "$CMDStatus" | grep -qi "Success" ; then
			log_line "$CMDStatus"
			HayLookAtMe "Sending iPad to Limbo."
		fi
	fi

	#Send commands to Mosyle to disable Lost Mode.
	#Often we wipe devices which are returned from kids who have left
	#the district.  This stops us from doing one more step.
    CMDStatus=$(mosbasic lostmodeoff "$Refer2MeAs" | tail -n 1)

	log_line "MosyleTidyUp: Told Mosyle to Remove Lost mode for $Refer2MeAs -- RESULT-> $CMDStatus"
	
	HayLookAtMe "Disabling Lost Mode.."
}


HayLookAtMe() {
	
	RIGHTNOW=$(date '+%r')
	
	echo "${Green}$RIGHTNOW / ${White}$Refer2MeAs--> ${Yellow}$1${reset}"

}

################################
#   Pre Can we do Work Checks  #
################################

# Check that directory structure is in place
if [ ! -d "/Users/Shared/ShakeNBake" ]; then
    mkdir -p "$LOGLOCATION"
    mkdir -p "$TMPLOCATION"
    mkdir -p "$EXTRACFGS"
    mkdir -p "/Users/Shared/ShakeNBake/Profiles"
fi

log_line "DEPLOY--> $1"
echo "${Cyan}$ECID / $UDID / $buildVersion  <--Has entered the Fray...${reset}"

#Note the pid of this running script.
PIDOFME="$$"

log_line "Pid of this script is $PIDOFME"

#Which Wifi profile to use
if [ "$DEPLOYMODE" = "WIPEONLY" ]; then
	log_line "WIPE ONLY MODE SPECIED. Will wipe and go no further."
	JustWipe="Y"
elif [ "$DEPLOYMODE" = "LOANER" ]; then
	log_line "Loaner Mode Specified.  Will act accordingly."
	#This network is our normal use network.  Because this is a loaner we want this
	#iPad always on this network (district wide network)


	#Make sure our wifi profile is available
	if [ ! -r "$LOANERWIFIPROFILE" ]; then
		log_line "Wifi profile $LOANERWIFIPROFILE to be used but can't be found.  EPIC FAIL."
		exit 1
		
	else
		JustWipe="N"
		TEMPORARYWIFIPROFILE="$LOANERWIFIPROFILE"
	fi
	
else
	#This profile is for a temporary network that only exists in the IT office. 
	log_line "No deploy method specified (WIPEONLY/LOANER) so assuming normal operation."
	if [ ! -r "$LIMBOWIFIPROFILE" ]; then
		log_line "Wifi profile $LIMBOWIFIPROFILE to be used but can't be found.  EPIC FAIL."	
		exit 1
	else
		TEMPORARYWIFIPROFILE="$LIMBOWIFIPROFILE"
	fi
fi


#Make sure ECID is not blank.  If it is we can't do anything.  As we are launched
#by CFGUTIL I can't see how this could happen, but best to make sure.
if [ -z "$ECID" ]; then
	log_line "ECID doesn't appear to have been handed off to this script.  Can't continue."
	exit 1
else
	log_line "ECID provided was $ECID."
fi

#Are we working on this device already?  Dont want to operate on the same device twice.  This
#can happen when a device resets then comes back.  The script that started the action is waiting
#for it to come back.
if [ -f "$TMPLOCATION/CFGUTIL_$ECID.txt" ]; then
	log_line "EPIC FAIL: $ECID appears to already be involved with another process.  Skipping."
	
	Refer2MeAs="$ECID"
	
	if [ "$DEPLOYMODE" = "LOANER" ]; then
		HayLookAtMe "Loaner Mode enabled, This device is currently Ready to Deploy. ${Green}Skipping."
		exit 0
	else
		HayLookAtMe "Already involved with another process. ${Red}EPIC FAIL!"
		exit 1
	fi
	
else
	touch "$TMPLOCATION/CFGUTIL_$ECID.txt"
fi

#Get Booted State of device.  Erase only works if its booted.  If its not booted
#dont wase our time trying.
GetDeviceState=$(/usr/local/bin/cfgutil --ecid "$ECID" get bootedState isPaired 2>/dev/null )
Devicebootstate=$(echo "$GetDeviceState" | grep -a1 bootedState: | tail -1)
Devicepairingstate=$(echo "$GetDeviceState" | grep -a1 isPaired: | tail -1)

#ID That iPad...  If we cant get a confirmed hit from MOSBasic that its a known
#device then use UDID as ID.  We will need more logic in the future when dealing with
#NEW devices.. but we will cross that bridge when we get there.
if [ -z "$UDID" ]; then
	log_line "Device wont tell us its UDID.  Attempting to jump right to Restore."
	
	if [ ! "$Devicebootstate" = "Booted" ]; then
			HayLookAtMe "iPad is not booted....  Passing forward."
			
	else

		Refer2MeAs="$ECID"
		HayLookAtMe "No UDID detected... Wait 30s before we do anything."
		sleep 30

		GETUDID=$(cfgutil --ecid "$ECID" get UDID)

		if [ -z "$GETUDID" ]; then
			HayLookAtMe "We waited 30s and still can't get UDID..  Going for the Hail Mary and doing a restore."
			#Call restore routine.
			RestoreDevice

		else
			UDID="$GETUDID"

			#NOTE THIS FILE WE ARE LOOKING THROUGH COMES FROM MOSBasic.  
			FoundItIOS=$(cat "$TEMPOUTPUTFILE_MERGEDIOS" | cut -d$'\t' -f 1,2,5 | grep "$UDID")
			#Strip FoundIt down to JUST THE SERIAL #
			ASSETTAG=$(echo "$FoundItIOS" | cut -d$'\t' -f 3)
			DeviceSerialNumber=$(echo "$FoundItIOS" | cut -d$'\t' -f 2)

			log_line "$ECID / $UDID / $ASSETTAG / $DeviceSerialNumber"

			if [ -z "$FoundItIOS" ]; then
				log_line "IDTHATIPAD: Couldn't find $UDID in MOSBasic cache files."
				Refer2MeAs="$UDID"
				IN_MOSYLE="FALSE"

				HayLookAtMe "From here forward $ECID will be known as $Refer2MeAs"

			else
				Refer2MeAs="$ASSETTAG"
				IN_MOSYLE="TRUE"

				HayLookAtMe "From here forward $ECID will be known as $Refer2MeAs"
			fi

		fi
	fi
else
	
	#Find by Asset Tag, Serial, or Username.  Same Search actually works both ways.
	#NOTE THIS FILE WE ARE LOOKING THROUGH COMES FROM MOSBasic.
	FoundItIOS=$(cat "$TEMPOUTPUTFILE_MERGEDIOS" | cut -d$'\t' -f 1,2,5 | grep "$UDID")

	if [ -z "$FoundItIOS" ]; then
		log_line "IDTHATIPAD: Couldn't find $UDID in MOSBasic cache files."
        DeviceSerialNumber=$(cfgutil --ecid "$ECID" get serialNumber 2> /dev/null)
		Refer2MeAs="$DeviceSerialNumber"
		IN_MOSYLE="FALSE"
		HayLookAtMe "From here forward $ECID will be known as $Refer2MeAs"

	else
    	#Strip FoundIt down to JUST THE SERIAL #
	    ASSETTAG=$(echo "$FoundItIOS" | cut -d$'\t' -f 3)
	    DeviceSerialNumber=$(echo "$FoundItIOS" | cut -d$'\t' -f 2)
		Refer2MeAs="$ASSETTAG"
		IN_MOSYLE="TRUE"
		HayLookAtMe "From here forward $ECID will be known as $Refer2MeAs"
	fi

    log_line "$ECID / $UDID / $ASSETTAG / $DeviceSerialNumber"

fi

#
################################
#            DO WORK           #
################################
HayLookAtMe "Initial iPad Status Check"

log_line "IPAD STATUS: Checking iPad current Status $ECID"

if [ "$Devicebootstate" = "Booted" ]; then
    if [ "$Devicepairingstate" = "yes" ]; then
    	#Do a Quick Check on the iPad we just got..  If its unactivated we don't need to 
    	#wipe it..  Otherwise always wipe.

    	RWeActivated=$(cfgutil --ecid "$ECID" get activationState 2> /dev/null)

    	if [ "$RWeActivated" = "Unactivated" ]; then
	    	log_line "IPAD STATUS: $ECID appears to be in a wiped state."
		    HayLookAtMe "iPad is wiped. Continuing"
			iPadOSInstallVersion

    	else
	    	#All other cases perform restore action.
	    	log_line "RESTORE: Activated Status ($RWeActivated)"
	    
       		iPadOSInstallVersion
        	RestoreDevice
    	fi
	else
		# Device isn't paired.  Need to try OTA wipe
		log_line "IPAD STATUS: $ECID is not paired.  Going straight to wipe"
		RestoreDevice
	fi

else
    log_line "IPAD STATUS: $ECID is booted into $Devicebootstate mode.  Going straight to wipe"
    RestoreDevice
fi	

log_line "RESTORE: Restore step success on $ECID"

#Call Mosyle TidyUp function.  This will put iPad into
#Limbo (as long as its not shared,) clear back log commands,
# and disable lost mode.  We do DLM blindy.. if its not enabled
# we wasted a few seconds of API time and if it is enabled well
# we stopped ourself some irritation later.
MosyleTidyUp

if [ "$JustWipe" = "Y" ]; then
	log_line "Just Wipe Mode enabled.  $ECID ($ASSETTAG / $DeviceSerialNumber) not being prepared any further."
	HayLookAtMe "Wipe Only..  This iPad is DONE!"
	
else
	#Step 4
	log_line "INSTALL_WIFI: Preparing to install wifi profile on $ECID ($ASSETTAG / $DeviceSerialNumber)"
	HayLookAtMe "Installing WiFi profile $TEMPORARYWIFIPROFILE"
	InstallProfileDevice

	log_line "INSTALL_WIFI: Wifi Profile deployed to $ECID ($ASSETTAG / $DeviceSerialNumber)"
	#Step 5
	log_line "PREPARE: Preparing to finialize $ECID ($ASSETTAG / $DeviceSerialNumber)"
	HayLookAtMe "Running HELLO SCREEN prep steps"
	PrepareDevice

	log_line "PREPARE: $ECID ($ASSETTAG / $DeviceSerialNumber) has finished prepare step..  Its up to MDM now."
	HayLookAtMe "iPad ${Green}COMPLETE."
fi



#Every bad error status has an exit code.  If we got this far asssume success.
if [ -z "$ASSETTAG" ]; then
	log_line "iPad with serial number $DeviceSerialNumber has completed!"
else
	INVENTORYUNASSIGNDEVICE "$ASSETTAG"
	
	Snipe_Status=$(echo "$SNIPEOUTPUT" | jq -r '.status')
					
	if [ "$Snipe_Status" = "error" ]; then
		SnipeError=$(echo "$SNIPEOUTPUT" | jq -r '.messages')
		echo "${Red}Error checking iPad $Refer2MeAs in:"
		echo "$SnipeError${reset}"
		else
		log_line "iPad $Refer2MeAs successfully checked in"						
		fi 

	log_line "iPad with asset tag $Refer2MeAs has completed!"
	# Check in from inventory

fi

if [ "$DEPLOYMODE" = "LOANER" ]; then
	log_line "This is a loaner device.  Not deleting temporary marker file."
	HayLookAtMe "iPad is a loaner ${Green}KEEPING MARKER FILE."
else
		#Remove our holder file so if we unplug the iPad and plug it back
	#in then it will wipe all over again.
	rm -Rf "$TMPLOCATION/CFGUTIL_$ECID.txt"
fi


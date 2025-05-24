#!/bin/sh

##############################################################
##                                                          ##
##     ___   ___   _ __   _ __   _ __ ___    ___   _ __     ##
##    / __| / _ \ | '_ \ | '_ \ | '_ ` _ \  / _ \ | '_ \    ##
##   | (__ | (_) || | | || | | || | | | | || (_) || | | |   ##
##    \___| \___/ |_| |_||_| |_||_| |_| |_| \___/ |_| |_|   ##
##                                                          ##
##            https://github.com/jackyaz/connmon   test         ##
##                                                          ##
##############################################################
# Last Modified: 2025-Feb-03
#-------------------------------------------------------------

##############        Shellcheck directives      #############
# shellcheck disable=SC1090
# shellcheck disable=SC2009
# shellcheck disable=SC2012
# shellcheck disable=SC2016
# shellcheck disable=SC2018
# shellcheck disable=SC2019
# shellcheck disable=SC2039
# shellcheck disable=SC2059
# shellcheck disable=SC2086
# shellcheck disable=SC2155
# shellcheck disable=SC2174
# shellcheck disable=SC2181
# shellcheck disable=SC3003
# shellcheck disable=SC3018
# shellcheck disable=SC3043
# shellcheck disable=SC3045
##############################################################

### Start of script variables ###
readonly SCRIPT_NAME="connmon"
readonly SCRIPT_VERSION="v3.0.3"
SCRIPT_BRANCH="develop"
SCRIPT_REPO="https://raw.githubusercontent.com/AMTM-OSR/$SCRIPT_NAME/$SCRIPT_BRANCH"
readonly SCRIPT_DIR="/jffs/addons/$SCRIPT_NAME.d"
readonly SCRIPT_WEBPAGE_DIR="$(readlink /www/user)"
readonly SCRIPT_WEB_DIR="$SCRIPT_WEBPAGE_DIR/$SCRIPT_NAME"
readonly SHARED_DIR="/jffs/addons/shared-jy"
readonly SHARED_REPO="https://raw.githubusercontent.com/AMTM-OSR/shared-jy/master"
readonly SHARED_WEB_DIR="$SCRIPT_WEBPAGE_DIR/shared-jy"
readonly EMAIL_DIR="/jffs/addons/amtm/mail"
readonly EMAIL_CONF="$EMAIL_DIR/email.conf"
readonly EMAIL_REGEX="^(([A-Za-z0-9]+((\.|\-|\_|\+)?[A-Za-z0-9]?)*[A-Za-z0-9]+)|[A-Za-z0-9]+)@(([A-Za-z0-9]+)+((\.|\-|\_)?([A-Za-z0-9]+)+)*)+\.([A-Za-z]{2,})+$"

[ -z "$(nvram get odmpid)" ] && ROUTER_MODEL="$(nvram get productid)" || ROUTER_MODEL="$(nvram get odmpid)"
[ -f /opt/bin/sqlite3 ] && SQLITE3_PATH=/opt/bin/sqlite3 || SQLITE3_PATH=/usr/sbin/sqlite3

##----------------------------------------##
## Modified by Martinski W. [2025-Jan-04] ##
##----------------------------------------##
readonly scriptVersRegExp="v[0-9]{1,2}([.][0-9]{1,2})([.][0-9]{1,2})"

# For daily CRON job to trim database #
readonly defTrimDB_Hour=3
readonly defTrimDB_Mins=1

readonly oneKByte=1024
readonly oneMByte=1048576
readonly oneGByte=1073741824
readonly SHARE_TEMP_DIR="/opt/share/tmp"

### End of script variables ###

### Start of output format variables ###
readonly CRIT="\\e[41m"
readonly ERR="\\e[31m"
readonly WARN="\\e[33m"
readonly PASS="\\e[32m"
readonly BOLD="\\e[1m"
readonly SETTING="${BOLD}\\e[36m"
readonly UNDERLINE="\\e[4m"
readonly CLEARFORMAT="\\e[0m"

##-------------------------------------##
## Added by Martinski W. [2024-Dec-21] ##
##-------------------------------------##
readonly REDct="\033[1;31m\033[1m"
readonly GRNct="\033[1;32m\033[1m"
readonly CLEARct="\033[0m"

### End of output format variables ###

# Give priority to built-in binaries #
export PATH="/bin:/usr/bin:/sbin:/usr/sbin:$PATH"

##----------------------------------------##
## Modified by Martinski W. [2024-Dec-21] ##
##----------------------------------------##
# $1 = print to syslog, $2 = message to print, $3 = log level
Print_Output()
{
	local prioStr  prioNum
	if [ $# -gt 2 ] && [ -n "$3" ]
	then prioStr="$3"
	else prioStr="NOTICE"
	fi
	if [ "$1" = "true" ]
	then
		case "$prioStr" in
		    "$CRIT") prioNum=2 ;;
		     "$ERR") prioNum=3 ;;
		    "$WARN") prioNum=4 ;;
		    "$PASS") prioNum=6 ;; #INFO#
		          *) prioNum=5 ;; #NOTICE#
		esac
		logger -t "$SCRIPT_NAME" -p $prioNum "$2"
	fi
	printf "${BOLD}${3}%s${CLEARFORMAT}\n\n" "$2"
}

Firmware_Version_Check()
{
	if nvram get rc_support | grep -qF "am_addons"; then
		return 0
	else
		return 1
	fi
}

### Code for these functions inspired by https://github.com/Adamm00 - credit to @Adamm ###
Check_Lock()
{
	if [ -f "/tmp/$SCRIPT_NAME.lock" ]
	then
		ageoflock="$(($(/bin/date "+%s") - $(/bin/date "+%s" -r "/tmp/$SCRIPT_NAME.lock")))"
		if [ "$ageoflock" -gt 600 ]  #10 minutes#
		then
			Print_Output true "Stale lock file found (>600 seconds old) - purging lock" "$ERR"
			kill "$(sed -n '1p' "/tmp/$SCRIPT_NAME.lock")" >/dev/null 2>&1
			Clear_Lock
			echo "$$" > "/tmp/$SCRIPT_NAME.lock"
			return 0
		else
			Print_Output true "Lock file found (age: $ageoflock seconds) - ping test likely currently running" "$ERR"
			if [ $# -eq 0 ] || [ -z "$1" ]
			then
				exit 1
			else
				if [ "$1" = "webui" ]; then
					echo 'var connmonstatus = "LOCKED";' > "$SCRIPT_WEB_DIR/detect_connmon.js"
					exit 1
				fi
				return 1
			fi
		fi
	else
		echo "$$" > "/tmp/$SCRIPT_NAME.lock"
		return 0
	fi
}

Clear_Lock()
{
	rm -f "/tmp/$SCRIPT_NAME.lock" 2>/dev/null
	return 0
}

##----------------------------------------##
## Modified by Martinski W. [2025-Feb-02] ##
##----------------------------------------##
Set_Version_Custom_Settings()
{
	SETTINGSFILE="/jffs/addons/custom_settings.txt"
	case "$1" in
		local)
			if [ -f "$SETTINGSFILE" ]
			then
				if [ "$(grep -c "^connmon_version_local" "$SETTINGSFILE")" -gt 0 ]
				then
					if [ "$2" != "$(grep "^connmon_version_local" "$SETTINGSFILE" | cut -f2 -d' ')" ]
					then
						sed -i "s/^connmon_version_local.*/connmon_version_local $2/" "$SETTINGSFILE"
					fi
				else
					echo "connmon_version_local $2" >> "$SETTINGSFILE"
				fi
			else
				echo "connmon_version_local $2" >> "$SETTINGSFILE"
			fi
		;;
		server)
			if [ -f "$SETTINGSFILE" ]
			then
				if [ "$(grep -c "^connmon_version_server" "$SETTINGSFILE")" -gt 0 ]
				then
					if [ "$2" != "$(grep "^connmon_version_server" "$SETTINGSFILE" | cut -f2 -d' ')" ]
					then
						sed -i "s/^connmon_version_server.*/connmon_version_server $2/" "$SETTINGSFILE"
					fi
				else
					echo "connmon_version_server $2" >> "$SETTINGSFILE"
				fi
			else
				echo "connmon_version_server $2" >> "$SETTINGSFILE"
			fi
		;;
	esac
}

##----------------------------------------##
## Modified by Martinski W. [2025-Jan-04] ##
##----------------------------------------##
Update_Check()
{
	echo 'var updatestatus = "InProgress";' > "$SCRIPT_WEB_DIR/detect_update.js"
	doupdate="false"
	localver="$(grep "SCRIPT_VERSION=" "/jffs/scripts/$SCRIPT_NAME" | grep -m1 -oE "$scriptVersRegExp")"
	[ -n "$localver" ] && Set_Version_Custom_Settings local "$localver"
	curl -fsL --retry 4 --retry-delay 5 "$SCRIPT_REPO/404/$SCRIPT_NAME.sh" | grep -qF "jackyaz" || \
    { Print_Output true "404 error detected - stopping update" "$ERR"; return 1; }
	serverver="$(curl -fsL --retry 4 --retry-delay 5 "$SCRIPT_REPO/version/$SCRIPT_NAME.sh" | grep "SCRIPT_VERSION=" | grep -m1 -oE "$scriptVersRegExp")"
	if [ "$localver" != "$serverver" ]
	then
		doupdate="version"
		Set_Version_Custom_Settings server "$serverver"
		changelog="$(curl -fsL --retry 4 --retry-delay 5 "$SCRIPT_REPO/files/CHANGELOG.md" | sed -n "/$serverver"'/,/##/p' | head -n -1 | sed 's/## //')"
		echo 'var changelog = "<div style=\"width:350px;\"><b>Changelog</b><br />'"$(echo "$changelog" | tr '\n' '|' | sed 's/|/<br \/>/g')"'</div>"' > "$SCRIPT_WEB_DIR/detect_changelog.js"
		echo 'var updatestatus = "'"$serverver"'";'  > "$SCRIPT_WEB_DIR/detect_update.js"
	else
		localmd5="$(md5sum "/jffs/scripts/$SCRIPT_NAME" | awk '{print $1}')"
		remotemd5="$(curl -fsL --retry 4 --retry-delay 5 "$SCRIPT_REPO/md5/$SCRIPT_NAME.sh" | md5sum | awk '{print $1}')"
		if [ "$localmd5" != "$remotemd5" ]
		then
			doupdate="md5"
			Set_Version_Custom_Settings server "$serverver-hotfix"
			echo 'var updatestatus = "'"$serverver-hotfix"'";'  > "$SCRIPT_WEB_DIR/detect_update.js"
		fi
	fi
	if [ "$doupdate" = "false" ]; then
		echo 'var updatestatus = "None";'  > "$SCRIPT_WEB_DIR/detect_update.js"
	fi
	echo "$doupdate,$localver,$serverver"
}

##----------------------------------------##
## Modified by Martinski W. [2025-Jan-04] ##
##----------------------------------------##
Update_Version()
{
	if [ $# -eq 0 ] || [ -z "$1" ]
	then
		updatecheckresult="$(Update_Check)"
		isupdate="$(echo "$updatecheckresult" | cut -f1 -d',')"
		localver="$(echo "$updatecheckresult" | cut -f2 -d',')"
		serverver="$(echo "$updatecheckresult" | cut -f3 -d',')"

		if [ "$isupdate" = "version" ]
		then
			Print_Output true "New version of $SCRIPT_NAME available - $serverver" "$PASS"
			changelog="$(curl -fsL --retry 4 --retry-delay 5 "$SCRIPT_REPO/files/CHANGELOG.md" | sed -n "/$serverver"'/,/##/p' | head -n -1 | sed 's/## //')"
			printf "${BOLD}${UNDERLINE}Changelog\\n${CLEARFORMAT}%s\\n\\n" "$changelog"
		elif [ "$isupdate" = "md5" ]; then
			Print_Output true "MD5 hash of $SCRIPT_NAME does not match - hotfix available - $serverver" "$PASS"
		fi

		if [ "$isupdate" != "false" ]
		then
			printf "\n${BOLD}Do you want to continue with the update? (y/n)${CLEARFORMAT}  "
			read -r confirm
			case "$confirm" in
				y|Y)
					printf "\n"
					Update_File CHANGELOG.md
					Update_File README.md
					Update_File LICENSE
					Update_File shared-jy.tar.gz
					Update_File connmonstats_www.asp
					Download_File "$SCRIPT_REPO/update/$SCRIPT_NAME.sh" "/jffs/scripts/$SCRIPT_NAME" && \
					Print_Output true "$SCRIPT_NAME successfully updated" "$PASS"
					chmod 0755 "/jffs/scripts/$SCRIPT_NAME"
					Set_Version_Custom_Settings local "$serverver"
					Set_Version_Custom_Settings server "$serverver"
					Clear_Lock
					PressEnter
					exec "$0"
					exit 0
				;;
				*)
					printf "\n"
					Clear_Lock
					return 1
				;;
			esac
		else
			Print_Output true "No updates available - latest is $localver" "$WARN"
			Clear_Lock
		fi
	fi

	if [ "$1" = "force" ]
	then
		serverver="$(curl -fsL --retry 4 --retry-delay 5 "$SCRIPT_REPO/version/$SCRIPT_NAME.sh" | grep "SCRIPT_VERSION=" | grep -m1 -oE "$scriptVersRegExp")"
		Print_Output true "Downloading latest version ($serverver) of $SCRIPT_NAME" "$PASS"
		Update_File CHANGELOG.md
		Update_File README.md
		Update_File LICENSE
		Update_File shared-jy.tar.gz
		Update_File connmonstats_www.asp
		Download_File "$SCRIPT_REPO/update/$SCRIPT_NAME.sh" "/jffs/scripts/$SCRIPT_NAME" && \
		Print_Output true "$SCRIPT_NAME successfully updated" "$PASS"
		chmod 0755 "/jffs/scripts/$SCRIPT_NAME"
		Set_Version_Custom_Settings local "$serverver"
		Set_Version_Custom_Settings server "$serverver"
		Clear_Lock
		if [ $# -lt 2 ] || [ -z "$2" ]
		then
			PressEnter
			exec "$0"
		elif [ "$2" = "unattended" ]
		then
			exec "$0" postupdate
		fi
		exit 0
	fi
}

Update_File()
{
	if [ "$1" = "connmonstats_www.asp" ]
	then
		tmpfile="/tmp/$1"
		Download_File "$SCRIPT_REPO/files/$1" "$tmpfile"
		if ! diff -q "$tmpfile" "$SCRIPT_DIR/$1" >/dev/null 2>&1
		then
			if [ -f "$SCRIPT_DIR/$1" ]
			then
				Get_WebUI_Page "$SCRIPT_DIR/$1"
				sed -i "\\~$MyPage~d" /tmp/menuTree.js
				rm -f "$SCRIPT_WEBPAGE_DIR/$MyPage" 2>/dev/null
			fi
			Download_File "$SCRIPT_REPO/files/$1" "$SCRIPT_DIR/$1"
			Print_Output true "New version of $1 downloaded" "$PASS"
			Mount_WebUI
		fi
		rm -f "$tmpfile"
	elif [ "$1" = "shared-jy.tar.gz" ]
	then
		if [ ! -f "$SHARED_DIR/$1.md5" ]
		then
			Download_File "$SHARED_REPO/$1" "$SHARED_DIR/$1"
			Download_File "$SHARED_REPO/$1.md5" "$SHARED_DIR/$1.md5"
			tar -xzf "$SHARED_DIR/$1" -C "$SHARED_DIR"
			rm -f "$SHARED_DIR/$1"
			Print_Output true "New version of $1 downloaded" "$PASS"
		else
			localmd5="$(cat "$SHARED_DIR/$1.md5")"
			remotemd5="$(curl -fsL --retry 4 --retry-delay 5 "$SHARED_REPO/$1.md5")"
			if [ "$localmd5" != "$remotemd5" ]
			then
				Download_File "$SHARED_REPO/$1" "$SHARED_DIR/$1"
				Download_File "$SHARED_REPO/$1.md5" "$SHARED_DIR/$1.md5"
				tar -xzf "$SHARED_DIR/$1" -C "$SHARED_DIR"
				rm -f "$SHARED_DIR/$1"
				Print_Output true "New version of $1 downloaded" "$PASS"
			fi
		fi
	elif [ "$1" = "CHANGELOG.md" ]
	then
		tmpfile="/tmp/$1"
		Download_File "$SCRIPT_REPO/files/$1" "$tmpfile"
		if ! diff -q "$tmpfile" "$SCRIPT_DIR/$1" >/dev/null 2>&1; then
			Download_File "$SCRIPT_REPO/files/$1" "$SCRIPT_DIR/$1"
		fi
		rm -f "$tmpfile"
	elif [ "$1" = "README.md" ] || [ "$1" = "LICENSE" ]
	then
		tmpfile="/tmp/$1"
		Download_File "$SCRIPT_REPO/files/$1" "$tmpfile"
		if ! diff -q "$tmpfile" "$SCRIPT_DIR/$1" >/dev/null 2>&1; then
			Download_File "$SCRIPT_REPO/files/$1" "$SCRIPT_DIR/$1"
		fi
		rm -f "$tmpfile"
	else
		return 1
	fi
}

Validate_Number()
{
	if [ "$1" -eq "$1" ] 2>/dev/null; then
		return 0
	else
		return 1
	fi
}

Validate_IP()
{
	if expr "$1" : '[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*$' >/dev/null; then
		for i in 1 2 3 4; do
			if [ "$(echo "$1" | cut -d. -f$i)" -gt 255 ]; then
				Print_Output false "Octet $i ($(echo "$1" | cut -d. -f$i)) - is invalid, must be less than 255" "$ERR"
				return 1
			fi
		done
	else
		Print_Output false "$1 - is not a valid IPv4 address, valid format is 1.2.3.4" "$ERR"
		return 1
	fi
}

Validate_Domain()
{
	if ! nslookup "$1" >/dev/null 2>&1; then
		Print_Output false "$1 cannot be resolved by nslookup, please ensure you enter a valid domain name" "$ERR"
		return 1
	else
		return 0
	fi
}

##----------------------------------------##
## Modified by Martinski W. [2025-Jan-18] ##
##----------------------------------------##
Conf_FromSettings()
{
	SETTINGSFILE="/jffs/addons/custom_settings.txt"
	TMPFILE="/tmp/connmon_settings.txt"

	if [ -f "$SETTINGSFILE" ]
	then
		if [ "$(grep "^connmon_" $SETTINGSFILE | grep -v "version" -c)" -gt 0 ]
		then
			Print_Output true "Updated settings from WebUI found, merging into $SCRIPT_CONF" "$PASS"
			cp -a "$SCRIPT_CONF" "${SCRIPT_CONF}.bak"
			grep "^connmon_" "$SETTINGSFILE" | grep -v "version" > "$TMPFILE"
			sed -i "s/^connmon_//g;s/ /=/g" "$TMPFILE"
			while IFS='' read -r line || [ -n "$line" ]
			do
				SETTINGNAME="$(echo "$line" | cut -f1 -d'=' | awk '{print toupper($1)}')"
				SETTINGVALUE="$(echo "$line" | cut -f2 -d'=')"
				if [ "$SETTINGNAME" = "NOTIFICATIONS_EMAIL_LIST" ]  || \
				   [ "$SETTINGNAME" = "NOTIFICATIONS_WEBHOOK_LIST" ] || \
				   [ "$SETTINGNAME" = "NOTIFICATIONS_PUSHOVER_LIST" ]
				then
					SETTINGVALUE="$(echo "$SETTINGVALUE" | sed 's~||||~,~g')"
				fi
				sed -i "s~$SETTINGNAME=.*~$SETTINGNAME=$SETTINGVALUE~" "$SCRIPT_CONF"
			done < "$TMPFILE"

			grep '^connmon_version' "$SETTINGSFILE" > "$TMPFILE"
			sed -i "\\~connmon_~d" "$SETTINGSFILE"
			mv -f "$SETTINGSFILE" "${SETTINGSFILE}.bak"
			cat "${SETTINGSFILE}.bak" "$TMPFILE" > "$SETTINGSFILE"
			rm -f "$TMPFILE"
			rm -f "${SETTINGSFILE}.bak"

			if diff "$SCRIPT_CONF" "${SCRIPT_CONF}.bak" | grep -q "STORAGELOCATION="
			then
				STORAGEtype="$(ScriptStorageLocation check)"
				if [ "$STORAGEtype" = "jffs" ]
				then
				    ## Check if enough free space is available in JFFS ##
				    if _Check_JFFS_SpaceAvailable_ "$SCRIPT_STORAGE_DIR"
				    then ScriptStorageLocation jffs
				    else ScriptStorageLocation usb
				    fi
				elif [ "$STORAGEtype" = "usb" ]
				then
				    ScriptStorageLocation usb
				fi
				Create_Symlinks
			fi
			if diff "$SCRIPT_CONF" "${SCRIPT_CONF}.bak" | grep -qE "(SCHDAYS|SCHHOUR|SCHMINS|AUTOMATICMODE=)"
			then
				Auto_Cron delete 2>/dev/null
				AutomaticMode check && Auto_Cron create 2>/dev/null
				_UpdateAutomaticModeState_
			fi
			if diff "$SCRIPT_CONF" "${SCRIPT_CONF}.bak" | grep -qE "(OUTPUTTIMEMODE=|DAYSTOKEEP=|LASTXRESULTS=)"
			then
				Generate_CSVs
			fi
			Print_Output true "Merge of updated settings from WebUI completed successfully" "$PASS"
		else
			Print_Output false "No updated settings from WebUI found, no merge into $SCRIPT_CONF necessary" "$PASS"
		fi
	fi
}

EmailConf_FromSettings()
{
	SETTINGSFILE="/jffs/addons/custom_settings.txt"
	TMPFILE="/tmp/email_settings.txt"
	if [ -f "$SETTINGSFILE" ]
    then
		Print_Output true "Updated email settings from WebUI found, merging into $EMAIL_CONF" "$PASS"
		cp -a "$EMAIL_CONF" "$EMAIL_CONF.bak"
		grep "email_" "$SETTINGSFILE" > "$TMPFILE"
		sed -i "s/email_//g;s/ /=/g" "$TMPFILE"
		while IFS='' read -r line || [ -n "$line" ]
		do
			SETTINGNAME="$(echo "$line" | cut -f1 -d'=' | awk '{print toupper($1)}')"
			SETTINGVALUE="$(echo "$line" | cut -f2- -d'=' | sed 's/=/ /g')"
			if [ "$SETTINGNAME" = "PASSWORD" ]; then
				Email_Encrypt_Password "$SETTINGVALUE"
			else
				sed -i "s~$SETTINGNAME=.*~$SETTINGNAME=\"$SETTINGVALUE\"~" "$EMAIL_CONF"
			fi
		done < "$TMPFILE"
		sed -i "\\~email_~d" "$SETTINGSFILE"
		rm -f "$TMPFILE"
		Print_Output true "Merge of updated email settings from WebUI completed successfully" "$PASS"
	fi
}

##----------------------------------------##
## Modified by Martinski W. [2024-Dec-21] ##
##----------------------------------------##
Create_Dirs()
{
	if [ ! -d "$SCRIPT_DIR" ]; then
		mkdir -p "$SCRIPT_DIR"
	fi

	if [ ! -d "$SCRIPT_STORAGE_DIR" ]; then
		mkdir -p "$SCRIPT_STORAGE_DIR"
	fi

	if [ ! -d "$CSV_OUTPUT_DIR" ]; then
		mkdir -p "$CSV_OUTPUT_DIR"
	fi

	if [ ! -d "$SHARED_DIR" ]; then
		mkdir -p "$SHARED_DIR"
	fi

	if [ ! -d "$SCRIPT_WEBPAGE_DIR" ]; then
		mkdir -p "$SCRIPT_WEBPAGE_DIR"
	fi

	if [ ! -d "$SCRIPT_WEB_DIR" ]; then
		mkdir -p "$SCRIPT_WEB_DIR"
	fi

	if [ ! -d "$EMAIL_DIR" ]; then
		mkdir -p "$EMAIL_DIR"
	fi

	if [ ! -d "$USER_SCRIPT_DIR" ]; then
		mkdir -p "$USER_SCRIPT_DIR"
	fi

	if [ ! -d "$SHARE_TEMP_DIR" ]
	then
		mkdir -m 777 -p "$SHARE_TEMP_DIR"
		export SQLITE_TMPDIR TMPDIR
	fi
}

Create_Symlinks()
{
	ln -sf "$SCRIPT_STORAGE_DIR/connstatstext.js" "$SCRIPT_WEB_DIR/connstatstext.js" 2>/dev/null
	ln -sf "$SCRIPT_STORAGE_DIR/lastx.csv" "$SCRIPT_WEB_DIR/lastx.htm" 2>/dev/null

	ln -sf "$EMAIL_CONF" "$SCRIPT_WEB_DIR/email_config.htm" 2>/dev/null
	ln -sf "$SCRIPT_CONF" "$SCRIPT_WEB_DIR/config.htm" 2>/dev/null
	ln -sf "$SCRIPT_DIR/CHANGELOG.md" "$SCRIPT_WEB_DIR/changelog.htm" 2>/dev/null
	ln -sf "$SCRIPT_STORAGE_DIR/.cron" "$SCRIPT_WEB_DIR/cron.js" 2>/dev/null
	ln -sf "$SCRIPT_STORAGE_DIR/.customactioninfo" "$SCRIPT_WEB_DIR/customactioninfo.htm" 2>/dev/null
	ln -sf "$SCRIPT_STORAGE_DIR/.customactionlist" "$SCRIPT_WEB_DIR/customactionlist.htm" 2>/dev/null
	ln -sf "$SCRIPT_STORAGE_DIR/.emailinfo" "$SCRIPT_WEB_DIR/emailinfo.htm" 2>/dev/null

	ln -sf "$CSV_OUTPUT_DIR" "$SCRIPT_WEB_DIR/csv" 2>/dev/null

	if [ ! -d "$SHARED_WEB_DIR" ]; then
		ln -s "$SHARED_DIR" "$SHARED_WEB_DIR" 2>/dev/null
	fi
}

##----------------------------------------##
## Modified by Martinski W. [2025-Jan-04] ##
##----------------------------------------##
Conf_Exists()
{
	local PINGFREQUENCY  AUTOMATEDopt

	if [ -f "$SCRIPT_CONF" ]
	then
		dos2unix "$SCRIPT_CONF"
		chmod 0644 "$SCRIPT_CONF"
		sed -i -e 's/"//g' "$SCRIPT_CONF"
		if grep -q "^AUTOMATED=.*" "$SCRIPT_CONF"
		then
			AUTOMATEDopt="$(Conf_Parameters check AUTOMATED)"
			sed -i 's/^AUTOMATED=.*$/AUTOMATICMODE='"$AUTOMATEDopt"'/' "$SCRIPT_CONF"
		fi
		if ! grep -q "^AUTOMATICMODE=" "$SCRIPT_CONF"; then
			echo "AUTOMATICMODE=true" >> "$SCRIPT_CONF"
		fi
		if ! grep -q "^PINGDURATION=" "$SCRIPT_CONF"; then
			echo "PINGDURATION=30" >> "$SCRIPT_CONF"
		fi
		if grep -q "SCHEDULESTART" "$SCRIPT_CONF"
		then
			if ! grep -q "^SCHDAYS=" "$SCRIPT_CONF"; then
				echo "SCHDAYS=*" >> "$SCRIPT_CONF"
			fi
			echo "SCHHOURS=*" >> "$SCRIPT_CONF"
			PINGFREQUENCY="$(Conf_Parameters check PINGFREQUENCY)"
			echo "SCHMINS=*/$PINGFREQUENCY" >> "$SCRIPT_CONF"
			sed -i '/SCHEDULESTART/d;/SCHEDULEEND/d;/PINGFREQUENCY/d;' "$SCRIPT_CONF"
			Auto_Cron delete 2>/dev/null
		fi
		if grep -q "OUTPUTDATAMODE" "$SCRIPT_CONF"; then
			sed -i '/OUTPUTDATAMODE/d;' "$SCRIPT_CONF"
		fi
		if ! grep -q "^OUTPUTTIMEMODE=" "$SCRIPT_CONF"; then
			echo "OUTPUTTIMEMODE=unix" >> "$SCRIPT_CONF"
		fi
		if ! grep -q "^DAYSTOKEEP=" "$SCRIPT_CONF"; then
			echo "DAYSTOKEEP=30" >> "$SCRIPT_CONF"
		fi
		if ! grep -q "^LASTXRESULTS=" "$SCRIPT_CONF"; then
			echo "LASTXRESULTS=10" >> "$SCRIPT_CONF"
		fi
		if ! grep -q "^EXCLUDEFROMQOS=" "$SCRIPT_CONF"; then
			echo "EXCLUDEFROMQOS=true" >> "$SCRIPT_CONF"
		fi
		if ! grep -q "^STORAGELOCATION=" "$SCRIPT_CONF"; then
			echo "STORAGELOCATION=jffs" >> "$SCRIPT_CONF"
		fi
		if ! grep -q "^NOTIFICATIONS" "$SCRIPT_CONF"
		then
			{
				echo "NOTIFICATIONS_EMAIL=false"
				echo "NOTIFICATIONS_WEBHOOK=false"
				echo "NOTIFICATIONS_PUSHOVER=false"
				echo "NOTIFICATIONS_CUSTOM=false"
				echo "NOTIFICATIONS_HEALTHCHECK=false"
				echo "NOTIFICATIONS_INFLUXDB=false"
				echo "NOTIFICATIONS_PINGTEST=None"
				echo "NOTIFICATIONS_PINGTHRESHOLD=None"
				echo "NOTIFICATIONS_JITTERTHRESHOLD=None"
				echo "NOTIFICATIONS_LINEQUALITYTHRESHOLD=None"
				echo "NOTIFICATIONS_PINGTHRESHOLD_VALUE=30"
				echo "NOTIFICATIONS_JITTERTHRESHOLD_VALUE=15"
				echo "NOTIFICATIONS_LINEQUALITYTHRESHOLD_VALUE=75"
				echo "NOTIFICATIONS_EMAIL_LIST="
				echo "NOTIFICATIONS_HEALTHCHECK_UUID="
				echo "NOTIFICATIONS_WEBHOOK_LIST="
				echo "NOTIFICATIONS_PUSHOVER_LIST="
				echo "NOTIFICATIONS_PUSHOVER_API="
				echo "NOTIFICATIONS_PUSHOVER_USERKEY="
				echo "NOTIFICATIONS_INFLUXDB_HOST="
				echo "NOTIFICATIONS_INFLUXDB_PORT=8086"
				echo "NOTIFICATIONS_INFLUXDB_DB=connmon"
				echo "NOTIFICATIONS_INFLUXDB_VERSION=1.8"
				echo "NOTIFICATIONS_INFLUXDB_USERNAME="
				echo "NOTIFICATIONS_INFLUXDB_PASSWORD="
				echo "NOTIFICATIONS_INFLUXDB_APITOKEN="
			} >> "$SCRIPT_CONF"
		fi

		return 0
	else
		{
		  echo "PINGSERVER=8.8.8.8"; echo "OUTPUTTIMEMODE=unix"
		  echo "STORAGELOCATION=jffs"; echo "PINGDURATION=30"; echo "AUTOMATICMODE=true"
		  echo "SCHDAYS=*"; echo "SCHHOURS=*"; echo "SCHMINS=*/3"
		  echo "DAYSTOKEEP=30"; echo "LASTXRESULTS=10"; echo "EXCLUDEFROMQOS=true"
		  echo "NOTIFICATIONS_EMAIL=false"; echo "NOTIFICATIONS_WEBHOOK=false"
		  echo "NOTIFICATIONS_PUSHOVER=false"; echo "NOTIFICATIONS_CUSTOM=false"
		  echo "NOTIFICATIONS_HEALTHCHECK=false"; echo "NOTIFICATIONS_INFLUXDB=false"
		  echo "NOTIFICATIONS_PINGTEST=None"; echo "NOTIFICATIONS_PINGTHRESHOLD=None"
		  echo "NOTIFICATIONS_JITTERTHRESHOLD=None"; echo "NOTIFICATIONS_LINEQUALITYTHRESHOLD=None"
		  echo "NOTIFICATIONS_PINGTHRESHOLD_VALUE=30"; echo "NOTIFICATIONS_JITTERTHRESHOLD_VALUE=15"
		  echo "NOTIFICATIONS_LINEQUALITYTHRESHOLD_VALUE=75"
		  echo "NOTIFICATIONS_EMAIL_LIST="; echo "NOTIFICATIONS_HEALTHCHECK_UUID="
		  echo "NOTIFICATIONS_WEBHOOK_LIST="; echo "NOTIFICATIONS_PUSHOVER_LIST="
		  echo "NOTIFICATIONS_PUSHOVER_API="; echo "NOTIFICATIONS_PUSHOVER_USERKEY="
		  echo "NOTIFICATIONS_INFLUXDB_HOST="; echo "NOTIFICATIONS_INFLUXDB_PORT=8086"
		  echo "NOTIFICATIONS_INFLUXDB_DB=connmon"
		  echo "NOTIFICATIONS_INFLUXDB_VERSION=1.8"; echo "NOTIFICATIONS_INFLUXDB_USERNAME="
		  echo "NOTIFICATIONS_INFLUXDB_PASSWORD="; echo "NOTIFICATIONS_INFLUXDB_APITOKEN="
        } > "$SCRIPT_CONF"
		return 1
	fi
}

##----------------------------------------##
## Modified by Martinski W. [2024-Dec-21] ##
##----------------------------------------##
PingServer()
{
	case "$1" in
		update)
			exitOK=false
			while true
			do
				ScriptHeader
				printf "\n${BOLD}Current ping destination: ${GRNct}%s${CLEARFORMAT}\n\n" "$(PingServer check)"
				if "$exitOK"
				then PressEnter ; break
				fi
				printf "1.   Enter IP Address\n"
				printf "2.   Enter Domain Name\n"
				printf "e.   Return to Main Menu\n"
				printf "\n${BOLD}Choose an option:${CLEARFORMAT}  "
				read -r pingoption

				case "$pingoption" in
					1)
						while true
						do
							printf "\n${BOLD}Please enter an IP address (e=Exit):${CLEARFORMAT}  "
							read -r ipoption
							if [ "$ipoption" = "e" ]
							then
								break
							elif Validate_IP "$ipoption"
							then
								sed -i 's/^PINGSERVER=.*$/PINGSERVER='"$ipoption"'/' "$SCRIPT_CONF"
								exitOK=true ; break
							fi
						done
					;;
					2)
						while true
						do
							printf "\n${BOLD}Please enter a domain name (e=Exit):${CLEARFORMAT}  "
							read -r domainoption
							if [ "$domainoption" = "e" ]
							then
								break
							elif Validate_Domain "$domainoption"
							then
								sed -i 's/^PINGSERVER=.*$/PINGSERVER='"$domainoption"'/' "$SCRIPT_CONF"
								exitOK=true ; break
							fi
						done
					;;
					e) break
					;;
					*)
						printf "\n${BOLD}${ERR}Please choose a valid option.${CLEARFORMAT}\n\n"
						PressEnter
					;;
				esac
			done
			echo
		;;
		check)
			PINGSERVER="$(Conf_Parameters check PINGSERVER)"
			echo "${PINGSERVER:=8.8.8.8}"
		;;
	esac
}

##----------------------------------------##
## Modified by Martinski W. [2024-Dec-21] ##
##----------------------------------------##
PingDuration()
{
	case "$1" in
		update)
			pingSecs="$(PingDuration check)"
			exitLoop=false
			while true
			do
				ScriptHeader
				printf "${BOLD}Current number of seconds for ping tests: ${GRNct}${pingSecs}${CLEARct}\n"
				printf "\n${BOLD}Please enter the maximum number of seconds\nto run the ping tests [10-60] (e=Exit):${CLEARFORMAT}  "
				read -r pingdur_choice
				if [ -z "$pingdur_choice" ] && \
				   echo "$pingSecs" | grep -qE "^([1-9][0-9])$" && \
				   [ "$pingSecs" -ge 10 ] && [ "$pingSecs" -le 60 ]
				then
					exitLoop=true
					break
				elif [ "$pingdur_choice" = "e" ]
				then
					exitLoop=true
					break
				elif ! Validate_Number "$pingdur_choice"
				then
					printf "\n${ERR}Please enter a valid number [10-60].${CLEARFORMAT}\n"
					PressEnter
				elif [ "$pingdur_choice" -lt 10 ] || [ "$pingdur_choice" -gt 60 ]
				then
					printf "\n${ERR}Please enter a number between 10 and 60.${CLEARFORMAT}\n"
					PressEnter
				else
					pingSecs="$pingdur_choice"
					break
				fi
			done

			if "$exitLoop"
			then
				echo ; return 1
			else
				PINGDURATION="$pingSecs"
				sed -i 's/^PINGDURATION=.*$/PINGDURATION='"$PINGDURATION"'/' "$SCRIPT_CONF"
				echo ; return 0
			fi
		;;
		check)
			PINGDURATION="$(Conf_Parameters check PINGDURATION)"
			echo "${PINGDURATION:=30}"
		;;
	esac
}

##----------------------------------------##
## Modified by Martinski W. [2024-Dec-21] ##
##----------------------------------------##
DaysToKeep()
{
	case "$1" in
		update)
			daysToKeep="$(DaysToKeep check)"
			exitLoop=false
			while true
			do
				ScriptHeader
				printf "${BOLD}Current number of days to keep data: ${GRNct}${daysToKeep}${CLEARct}\n\n"
				printf "${BOLD}Please enter the maximum number of days\nto keep the data for [5-365] (e=Exit):${CLEARFORMAT}  "
				read -r daystokeep_choice
				if [ -z "$daystokeep_choice" ] && \
				   echo "$daysToKeep" | grep -qE "^([1-9][0-9]{0,2})$" && \
				   [ "$daysToKeep" -ge 5 ] && [ "$daysToKeep" -le 365 ]
				then
					exitLoop=true
					break
				elif [ "$daystokeep_choice" = "e" ]
				then
					exitLoop=true
					break
				elif ! Validate_Number "$daystokeep_choice"
				then
					printf "\n${ERR}Please enter a valid number [5-365].${CLEARFORMAT}\n"
					PressEnter
				elif [ "$daystokeep_choice" -lt 5 ] || [ "$daystokeep_choice" -gt 365 ]
				then
					printf "\n${ERR}Please enter a number between 5 and 365.${CLEARFORMAT}\n"
					PressEnter
				else
					daysToKeep="$daystokeep_choice"
					break
				fi
			done

			if "$exitLoop"
			then
				echo ; return 1
			else
				DAYSTOKEEP="$daysToKeep"
				sed -i 's/^DAYSTOKEEP=.*$/DAYSTOKEEP='"$DAYSTOKEEP"'/' "$SCRIPT_CONF"
				echo ; return 0
			fi
		;;
		check)
			DAYSTOKEEP="$(Conf_Parameters check DAYSTOKEEP)"
			echo "${DAYSTOKEEP:=30}"
		;;
	esac
}

##----------------------------------------##
## Modified by Martinski W. [2024-Dec-21] ##
##----------------------------------------##
LastXResults()
{
	case "$1" in
		update)
			lastXResults="$(LastXResults check)"
			exitLoop=false
			while true
			do
				ScriptHeader
				printf "${BOLD}Current number of results to display: ${GRNct}${lastXResults}${CLEARct}\n\n"
				printf "${BOLD}Please enter the maximum number of results\nto display in the WebUI [5-100] (e=Exit):${CLEARFORMAT}  "
				read -r lastx_choice
				if [ -z "$lastx_choice" ] && \
				   echo "$lastXResults" | grep -qE "^([1-9][0-9]{0,2})$" && \
				   [ "$lastXResults" -ge 5 ] && [ "$lastXResults" -le 100 ]
				then
					exitLoop=true
					break
				elif [ "$lastx_choice" = "e" ]
				then
					exitLoop=true
					break
				elif ! Validate_Number "$lastx_choice"
				then
					printf "\n${ERR}Please enter a valid number [5-100].${CLEARFORMAT}\n"
					PressEnter
				elif [ "$lastx_choice" -lt 5 ] || [ "$lastx_choice" -gt 100 ]
				then
					printf "\n${ERR}Please enter a number between 5 and 100.${CLEARFORMAT}\n"
					PressEnter
				else
					lastXResults="$lastx_choice"
					break
				fi
			done

			if "$exitLoop"
			then
				echo ; return 1
			else
				LASTXRESULTS="$lastXResults"
				sed -i 's/^LASTXRESULTS=.*$/LASTXRESULTS='"$LASTXRESULTS"'/' "$SCRIPT_CONF"
				Generate_LastXResults
				echo ; return 0
			fi
		;;
		check)
			LASTXRESULTS="$(Conf_Parameters check LASTXRESULTS)"
			echo "${LASTXRESULTS:=10}"
		;;
	esac
}

##----------------------------------------##
## Modified by Martinski W. [2025-Jan-18] ##
##----------------------------------------##
Auto_ServiceEvent()
{
	local theScriptFilePath="/jffs/scripts/$SCRIPT_NAME"
	case $1 in
		create)
			if [ -f /jffs/scripts/service-event ]
			then
				STARTUPLINECOUNT="$(grep -c '# '"$SCRIPT_NAME" /jffs/scripts/service-event)"
				STARTUPLINECOUNTEX="$(grep -cx 'if echo "$2" | /bin/grep -q "'"$SCRIPT_NAME"'"; then { '"$theScriptFilePath"' service_event "$@" & }; fi # '"$SCRIPT_NAME" /jffs/scripts/service-event)"

				if [ "$STARTUPLINECOUNT" -gt 1 ] || { [ "$STARTUPLINECOUNTEX" -eq 0 ] && [ "$STARTUPLINECOUNT" -gt 0 ]; }
				then
					sed -i -e '/# '"$SCRIPT_NAME"'/d' /jffs/scripts/service-event
				fi

				if [ "$STARTUPLINECOUNTEX" -eq 0 ]
				then
					{
					  echo 'if echo "$2" | /bin/grep -q "'"$SCRIPT_NAME"'"; then { '"$theScriptFilePath"' service_event "$@" & }; fi # '"$SCRIPT_NAME"
					} >> /jffs/scripts/service-event
				fi
			else
				{
				  echo "#!/bin/sh" ; echo
				  echo 'if echo "$2" | /bin/grep -q "'"$SCRIPT_NAME"'"; then { '"$theScriptFilePath"' service_event "$@" & }; fi # '"$SCRIPT_NAME"
				  echo
				} > /jffs/scripts/service-event
				chmod 0755 /jffs/scripts/service-event
			fi
		;;
		delete)
			if [ -f /jffs/scripts/service-event ]
			then
				STARTUPLINECOUNT="$(grep -c '# '"$SCRIPT_NAME" /jffs/scripts/service-event)"
				if [ "$STARTUPLINECOUNT" -gt 0 ]; then
					sed -i -e '/# '"$SCRIPT_NAME"'/d' /jffs/scripts/service-event
				fi
			fi
		;;
	esac
}

##----------------------------------------##
## Modified by Martinski W. [2025-Jan-18] ##
##----------------------------------------##
Auto_Startup()
{
	local theScriptFilePath="/jffs/scripts/$SCRIPT_NAME"
	case $1 in
		create)
			if [ -f /jffs/scripts/services-start ]
			then
				STARTUPLINECOUNT="$(grep -c '# '"$SCRIPT_NAME" /jffs/scripts/services-start)"

				if [ "$STARTUPLINECOUNT" -gt 0 ]; then
					sed -i -e '/# '"$SCRIPT_NAME"'/d' /jffs/scripts/services-start
				fi
			fi
			if [ -f /jffs/scripts/post-mount ]
			then
				STARTUPLINECOUNT="$(grep -c '# '"$SCRIPT_NAME" /jffs/scripts/post-mount)"
				STARTUPLINECOUNTEX="$(grep -cx '\[ -x "${1}/entware/bin/opkg" \] && \[ -x '"$theScriptFilePath"' \] && '"$theScriptFilePath"' startup "$@" & # '"$SCRIPT_NAME" /jffs/scripts/post-mount)"

				if [ "$STARTUPLINECOUNT" -gt 1 ] || { [ "$STARTUPLINECOUNTEX" -eq 0 ] && [ "$STARTUPLINECOUNT" -gt 0 ]; }
				then
					sed -i -e '/# '"$SCRIPT_NAME"'/d' /jffs/scripts/post-mount
					STARTUPLINECOUNT=0
				fi

				if [ "$STARTUPLINECOUNTEX" -eq 0 ]
				then
					{
					  echo '[ -x "${1}/entware/bin/opkg" ] && [ -x '"$theScriptFilePath"' ] && '"$theScriptFilePath"' startup "$@" & # '"$SCRIPT_NAME"
					} >> /jffs/scripts/post-mount
				fi
			else
				{
				  echo "#!/bin/sh" ; echo
				  echo '[ -x "${1}/entware/bin/opkg" ] && [ -x '"$theScriptFilePath"' ] && '"$theScriptFilePath"' startup "$@" & # '"$SCRIPT_NAME"
				  echo
				} > /jffs/scripts/post-mount
				chmod 0755 /jffs/scripts/post-mount
			fi
		;;
		delete)
			if [ -f /jffs/scripts/services-start ]
			then
				STARTUPLINECOUNT="$(grep -c '# '"$SCRIPT_NAME" /jffs/scripts/services-start)"
				if [ "$STARTUPLINECOUNT" -gt 0 ]; then
					sed -i -e '/# '"$SCRIPT_NAME"'/d' /jffs/scripts/services-start
				fi
			fi
			if [ -f /jffs/scripts/post-mount ]
			then
				STARTUPLINECOUNT="$(grep -c '# '"$SCRIPT_NAME" /jffs/scripts/post-mount)"
				if [ "$STARTUPLINECOUNT" -gt 0 ]; then
					sed -i -e '/# '"$SCRIPT_NAME"'/d' /jffs/scripts/post-mount
				fi
			fi
		;;
	esac
}

##----------------------------------------##
## Modified by Martinski W. [2025-Jan-18] ##
##----------------------------------------##
Auto_Cron()
{
	local theScriptFilePath="/jffs/scripts/$SCRIPT_NAME"
	case $1 in
		create)
			STARTUPLINECOUNT="$(cru l | grep -c "#${SCRIPT_NAME}#")"
			if [ "$STARTUPLINECOUNT" -gt 0 ]; then
				cru d "${SCRIPT_NAME}"
			fi
			STARTUPLINECOUNTGEN="$(cru l | grep -c "${SCRIPT_NAME}_generate")"
			CRU_SCHHOUR="$(Conf_Parameters check SCHHOURS)"
			CRU_SCHMINS="$(Conf_Parameters check SCHMINS)"
			STARTUPLINECOUNTEXGEN="$(cru l | grep "${SCRIPT_NAME}_generate" | grep -c "^$CRU_SCHMINS $CRU_SCHHOUR [*] [*]")"
			if [ "$STARTUPLINECOUNTGEN" -gt 0 ] && [ "$STARTUPLINECOUNTEXGEN" -eq 0 ]
			then
				cru d "${SCRIPT_NAME}_generate"
				STARTUPLINECOUNTGEN="$(cru l | grep -c "${SCRIPT_NAME}_generate")"
			fi
			if [ "$STARTUPLINECOUNTGEN" -eq 0 ]
			then
				CRU_SCHDAYS="$(Conf_Parameters check SCHDAYS | sed 's/Sun/0/;s/Mon/1/;s/Tues/2/;s/Wed/3/;s/Thurs/4/;s/Fri/5/;s/Sat/6/;')"
				cru a "${SCRIPT_NAME}_generate" "$CRU_SCHMINS $CRU_SCHHOUR * * $CRU_SCHDAYS $theScriptFilePath generate"
				echo "$CRU_SCHMINS $CRU_SCHHOUR * * $CRU_SCHDAYS" > "$SCRIPT_STORAGE_DIR/.cron"
			fi

			STARTUPLINECOUNTTRIM="$(cru l | grep -c "${SCRIPT_NAME}_trimDB")"
			STARTUPLINECOUNTEXTRIM="$(cru l | grep "${SCRIPT_NAME}_trimDB" | grep -c "^$defTrimDB_Mins $defTrimDB_Hour [*] [*]")"
			if [ "$STARTUPLINECOUNTTRIM" -gt 0 ] && [ "$STARTUPLINECOUNTEXTRIM" -eq 0 ]
			then
				cru d "${SCRIPT_NAME}_trimDB"
				STARTUPLINECOUNTTRIM="$(cru l | grep -c "${SCRIPT_NAME}_trimDB")"
			fi
			if [ "$STARTUPLINECOUNTTRIM" -eq 0 ]; then
				cru a "${SCRIPT_NAME}_trimDB" "$defTrimDB_Mins $defTrimDB_Hour * * * $theScriptFilePath trimdb"
			fi
		;;
		delete)
			STARTUPLINECOUNT="$(cru l | grep -c "#${SCRIPT_NAME}#")"
			if [ "$STARTUPLINECOUNT" -gt 0 ]; then
				cru d "$SCRIPT_NAME"
			fi
			STARTUPLINECOUNTGEN="$(cru l | grep -c "#${SCRIPT_NAME}_generate#")"
			if [ "$STARTUPLINECOUNTGEN" -gt 0 ]; then
				cru d "${SCRIPT_NAME}_generate"
			fi
			STARTUPLINECOUNTTRIM="$(cru l | grep -c "#${SCRIPT_NAME}_trimDB#")"
			if [ "$STARTUPLINECOUNTTRIM" -gt 0 ]; then
				cru d "${SCRIPT_NAME}_trimDB"
			fi
		;;
	esac
}

##----------------------------------------##
## Modified by Martinski W. [2025-Jan-04] ##
##----------------------------------------##
Download_File()
{ /usr/sbin/curl -LSs --retry 4 --retry-delay 5 --retry-connrefused "$1" -o "$2" ; }

Get_WebUI_Page()
{
	MyPage="none"
	for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20
	do
		page="/www/user/user$i.asp"
		if [ -f "$page" ] && [ "$(md5sum < "$1")" = "$(md5sum < "$page")" ]; then
			MyPage="user$i.asp"
			return
		elif [ "$MyPage" = "none" ] && [ ! -f "$page" ]; then
			MyPage="user$i.asp"
		fi
	done
}

### function based on @dave14305's FlexQoS webconfigpage function ###
Get_WebUI_URL(){
	urlpage=""
	urlproto=""
	urldomain=""
	urlport=""

	urlpage="$(sed -nE "/$SCRIPT_NAME/ s/.*url\: \"(user[0-9]+\.asp)\".*/\1/p" /tmp/menuTree.js)"
	if [ "$(nvram get http_enable)" -eq 1 ]; then
		urlproto="https"
	else
		urlproto="http"
	fi
	if [ -n "$(nvram get lan_domain)" ]; then
		urldomain="$(nvram get lan_hostname).$(nvram get lan_domain)"
	else
		urldomain="$(nvram get lan_ipaddr)"
	fi
	if [ "$(nvram get ${urlproto}_lanport)" -eq 80 ] || [ "$(nvram get ${urlproto}_lanport)" -eq 443 ]; then
		urlport=""
	else
		urlport=":$(nvram get ${urlproto}_lanport)"
	fi

	if echo "$urlpage" | grep -qE "user[0-9]+\.asp"; then
		echo "${urlproto}://${urldomain}${urlport}/${urlpage}" | tr "A-Z" "a-z"
	else
		echo "WebUI page not found"
	fi
}
### ###

### locking mechanism code credit to Martineau (@MartineauUK) ###
Mount_WebUI()
{
	Print_Output true "Mounting WebUI tab for $SCRIPT_NAME" "$PASS"
	LOCKFILE=/tmp/addonwebui.lock
	FD=386
	eval exec "$FD>$LOCKFILE"
	flock -x "$FD"
	Get_WebUI_Page "$SCRIPT_DIR/connmonstats_www.asp"
	if [ "$MyPage" = "none" ]; then
		Print_Output true "Unable to mount $SCRIPT_NAME WebUI page, exiting" "$CRIT"
		flock -u "$FD"
		return 1
	fi
	cp -f "$SCRIPT_DIR/connmonstats_www.asp" "$SCRIPT_WEBPAGE_DIR/$MyPage"
	echo "$SCRIPT_NAME" > "$SCRIPT_WEBPAGE_DIR/$(echo $MyPage | cut -f1 -d'.').title"

	if [ "$(/bin/uname -o)" = "ASUSWRT-Merlin" ]
	then
		if [ ! -f /tmp/index_style.css ]; then
			cp -f /www/index_style.css /tmp/
		fi

		if ! grep -q '.menu_Addons' /tmp/index_style.css ; then
			echo ".menu_Addons { background: url(ext/shared-jy/addons.png); }" >> /tmp/index_style.css
		fi

		umount /www/index_style.css 2>/dev/null
		mount -o bind /tmp/index_style.css /www/index_style.css

		if [ ! -f /tmp/menuTree.js ]; then
			cp -f /www/require/modules/menuTree.js /tmp/
		fi

		sed -i "\\~$MyPage~d" /tmp/menuTree.js

		if ! grep -q 'menuName: "Addons"' /tmp/menuTree.js ; then
			lineinsbefore="$(( $(grep -n "exclude:" /tmp/menuTree.js | cut -f1 -d':') - 1))"
			sed -i "$lineinsbefore"'i,\n{\nmenuName: "Addons",\nindex: "menu_Addons",\ntab: [\n{url: "javascript:var helpwindow=window.open('"'"'/ext/shared-jy/redirect.htm'"'"')", tabName: "Help & Support"},\n{url: "NULL", tabName: "__INHERIT__"}\n]\n}' /tmp/menuTree.js
		fi

		sed -i "/url: \"javascript:var helpwindow=window.open('\/ext\/shared-jy\/redirect.htm'/i {url: \"$MyPage\", tabName: \"$SCRIPT_NAME\"}," /tmp/menuTree.js

		umount /www/require/modules/menuTree.js 2>/dev/null
		mount -o bind /tmp/menuTree.js /www/require/modules/menuTree.js

		if [ ! -f /tmp/start_apply.htm  ]; then
			cp -f /www/start_apply.htm /tmp/
		fi
		if ! grep -q 'addon_settings' /tmp/start_apply.htm ; then
			sed -i "/}else if(action_script == \"start_sig_check\"){/i }else if(action_script.indexOf(\"addon_settings\") != -1){ \/\/ do nothing" /tmp/start_apply.htm
		fi
		umount /www/start_apply.htm 2>/dev/null
		mount -o bind /tmp/start_apply.htm /www/start_apply.htm
	fi
	flock -u "$FD"
	Print_Output true "Mounted $SCRIPT_NAME WebUI page as $MyPage" "$PASS"
}

ExcludeFromQoS()
{
	case "$1" in
	enable)
		sed -i 's/^EXCLUDEFROMQOS=.*$/EXCLUDEFROMQOS=true/' "$SCRIPT_CONF"
	;;
	disable)
		sed -i 's/^EXCLUDEFROMQOS=.*$/EXCLUDEFROMQOS=false/' "$SCRIPT_CONF"
	;;
	check)
		EXCLUDEFROMQOS="$(Conf_Parameters check EXCLUDEFROMQOS)"
		echo "${EXCLUDEFROMQOS:=true}"
	;;
	esac
}

##----------------------------------------##
## Modified by Martinski W. [2024-Dec-21] ##
##----------------------------------------##
AutomaticMode()
{
	case "$1" in
		enable)
			if AutomaticMode check
			then
			    printf "\nAutomatic ping tests are already ${GRNct}ENABLED${CLEARct}.\n\n"
			    return 0
			fi
			sed -i 's/^AUTOMATICMODE=.*$/AUTOMATICMODE=true/' "$SCRIPT_CONF"
			Auto_Cron create 2>/dev/null
			printf "Automatic ping tests are now ${GRNct}ENABLED${CLEARct}.\n\n"
			_UpdateAutomaticModeState_
		;;
		disable)
			if ! AutomaticMode check
			then
			    printf "\nAutomatic ping tests are already ${REDct}DISABLED${CLEARct}.\n\n"
			    return 0
			fi
			sed -i 's/^AUTOMATICMODE=.*$/AUTOMATICMODE=false/' "$SCRIPT_CONF"
			Auto_Cron delete 2>/dev/null
			printf "Automatic ping tests are now ${REDct}DISABLED${CLEARct}.\n\n"
			_UpdateAutomaticModeState_
		;;
		check)
			AUTOMATICMODE="$(Conf_Parameters check AUTOMATICMODE)"
			if [ "${AUTOMATICMODE:=true}" = "true" ]
			then return 0; else return 1; fi
		;;
	esac
}

##----------------------------------------##
## Modified by Martinski W. [2024-Dec-21] ##
##----------------------------------------##
CronTestSchedule()
{
	case "$1" in
		update)
			sed -i 's/^SCHDAYS=.*$/SCHDAYS='"$(echo "$2" | sed 's/0/Sun/;s/1/Mon/;s/2/Tues/;s/3/Wed/;s/4/Thurs/;s/5/Fri/;s/6/Sat/;')"'/' "$SCRIPT_CONF"
			sed -i 's~^SCHHOURS=.*$~SCHHOURS='"$3"'~' "$SCRIPT_CONF"
			sed -i 's~^SCHMINS=.*$~SCHMINS='"$4"'~' "$SCRIPT_CONF"
			Auto_Cron delete 2>/dev/null
			AutomaticMode check && Auto_Cron create 2>/dev/null
		;;
		check)
			SCHDAYS="$(Conf_Parameters check SCHDAYS)"
			SCHHOURS="$(Conf_Parameters check SCHHOURS)"
			SCHMINS="$(Conf_Parameters check SCHMINS)"
			echo "${SCHDAYS:=*}|${SCHHOURS:=*}|${SCHMINS:=*/3}"
		;;
	esac
}

##----------------------------------------##
## Modified by Martinski W. [2025-Jan-30] ##
##----------------------------------------##
ScriptStorageLocation()
{
	case "$1" in
		usb)
			printf "Please wait..."
			sed -i 's/^STORAGELOCATION=.*$/STORAGELOCATION=usb/' "$SCRIPT_CONF"
			mkdir -p "/opt/share/$SCRIPT_NAME.d/"
			rm -f "/jffs/addons/$SCRIPT_NAME.d/connstats.db-shm"
			rm -f "/jffs/addons/$SCRIPT_NAME.d/connstats.db-wal"
			mv -f "/jffs/addons/$SCRIPT_NAME.d/csv" "/opt/share/$SCRIPT_NAME.d/" 2>/dev/null
			mv -f "/jffs/addons/$SCRIPT_NAME.d/config" "/opt/share/$SCRIPT_NAME.d/" 2>/dev/null
			mv -f "/jffs/addons/$SCRIPT_NAME.d/config.bak" "/opt/share/$SCRIPT_NAME.d/" 2>/dev/null
			mv -f "/jffs/addons/$SCRIPT_NAME.d/connstatstext.js" "/opt/share/$SCRIPT_NAME.d/" 2>/dev/null
			mv -f "/jffs/addons/$SCRIPT_NAME.d/lastx.csv" "/opt/share/$SCRIPT_NAME.d/" 2>/dev/null
			mv -f "/jffs/addons/$SCRIPT_NAME.d"/connstats.db* "/opt/share/$SCRIPT_NAME.d/" 2>/dev/null
			mv -f "/jffs/addons/$SCRIPT_NAME.d/.indexcreated" "/opt/share/$SCRIPT_NAME.d/" 2>/dev/null
			mv -f "/jffs/addons/$SCRIPT_NAME.d/.newcolumns" "/opt/share/$SCRIPT_NAME.d/" 2>/dev/null
			mv -f "/jffs/addons/$SCRIPT_NAME.d/.cron" "/opt/share/$SCRIPT_NAME.d/" 2>/dev/null
			mv -f "/jffs/addons/$SCRIPT_NAME.d/.customactioninfo" "/opt/share/$SCRIPT_NAME.d/" 2>/dev/null
			mv -f "/jffs/addons/$SCRIPT_NAME.d/.customactionlist" "/opt/share/$SCRIPT_NAME.d/" 2>/dev/null
			mv -f "/jffs/addons/$SCRIPT_NAME.d/.emailinfo" "/opt/share/$SCRIPT_NAME.d/" 2>/dev/null
			mv -f "/jffs/addons/$SCRIPT_NAME.d/userscripts.d" "/opt/share/$SCRIPT_NAME.d/" 2>/dev/null
			SCRIPT_CONF="/opt/share/${SCRIPT_NAME}.d/config"
			CONNSTATS_DB="/opt/share/${SCRIPT_NAME}.d/connstats.db"
			CSV_OUTPUT_DIR="/opt/share/${SCRIPT_NAME}.d/csv"
			ScriptStorageLocation load true
			sleep 2
			;;
		jffs)
			printf "Please wait..."
			sed -i 's/^STORAGELOCATION=.*$/STORAGELOCATION=jffs/' "$SCRIPT_CONF"
			mkdir -p "/jffs/addons/$SCRIPT_NAME.d/"
			mv -f "/opt/share/$SCRIPT_NAME.d/csv" "/jffs/addons/$SCRIPT_NAME.d/" 2>/dev/null
			mv -f "/opt/share/$SCRIPT_NAME.d/config" "/jffs/addons/$SCRIPT_NAME.d/" 2>/dev/null
			mv -f "/opt/share/$SCRIPT_NAME.d/config.bak" "/jffs/addons/$SCRIPT_NAME.d/" 2>/dev/null
			mv -f "/opt/share/$SCRIPT_NAME.d/connstatstext.js" "/jffs/addons/$SCRIPT_NAME.d/" 2>/dev/null
			mv -f "/opt/share/$SCRIPT_NAME.d/lastx.csv" "/jffs/addons/$SCRIPT_NAME.d/" 2>/dev/null
			mv -f "/opt/share/$SCRIPT_NAME.d"/connstats.db* "/jffs/addons/$SCRIPT_NAME.d/" 2>/dev/null
			mv -f "/opt/share/$SCRIPT_NAME.d/.indexcreated" "/jffs/addons/$SCRIPT_NAME.d/" 2>/dev/null
			mv -f "/opt/share/$SCRIPT_NAME.d/.newcolumns" "/jffs/addons/$SCRIPT_NAME.d/" 2>/dev/null
			mv -f "/opt/share/$SCRIPT_NAME.d/.cron" "/jffs/addons/$SCRIPT_NAME.d/" 2>/dev/null
			mv -f "/opt/share/$SCRIPT_NAME.d/.customactioninfo" "/jffs/addons/$SCRIPT_NAME.d/" 2>/dev/null
			mv -f "/opt/share/$SCRIPT_NAME.d/.customactionlist" "/jffs/addons/$SCRIPT_NAME.d/" 2>/dev/null
			mv -f "/opt/share/$SCRIPT_NAME.d/.emailinfo" "/jffs/addons/$SCRIPT_NAME.d/" 2>/dev/null
			mv -f "/opt/share/$SCRIPT_NAME.d/userscripts.d" "/jffs/addons/$SCRIPT_NAME.d/" 2>/dev/null
			SCRIPT_CONF="/jffs/addons/${SCRIPT_NAME}.d/config"
			CONNSTATS_DB="/jffs/addons/${SCRIPT_NAME}.d/connstats.db"
			CSV_OUTPUT_DIR="/jffs/addons/${SCRIPT_NAME}.d/csv"
			ScriptStorageLocation load true
			sleep 2
			;;
		check)
			STORAGELOCATION="$(Conf_Parameters check STORAGELOCATION)"
			echo "${STORAGELOCATION:=jffs}"
			;;
		load)
			STORAGELOCATION="$(ScriptStorageLocation check)"
			if [ "$STORAGELOCATION" = "usb" ]
			then
				SCRIPT_STORAGE_DIR="/opt/share/${SCRIPT_NAME}.d"
			elif [ "$STORAGELOCATION" = "jffs" ]
			then
				SCRIPT_STORAGE_DIR="/jffs/addons/${SCRIPT_NAME}.d"
			fi
			chmod 777 "$SCRIPT_STORAGE_DIR"
			CONNSTATS_DB="$SCRIPT_STORAGE_DIR/connstats.db"
			CSV_OUTPUT_DIR="$SCRIPT_STORAGE_DIR/csv"
			USER_SCRIPT_DIR="$SCRIPT_STORAGE_DIR/userscripts.d"
			if [ $# -gt 1 ] && [ "$2" = "true" ]
			then _UpdateJFFS_FreeSpaceInfo_ ; fi
			;;
	esac
}

OutputTimeMode()
{
	case "$1" in
		unix)
			sed -i 's/^OUTPUTTIMEMODE=.*$/OUTPUTTIMEMODE=unix/' "$SCRIPT_CONF"
			Generate_CSVs
		;;
		non-unix)
			sed -i 's/^OUTPUTTIMEMODE=.*$/OUTPUTTIMEMODE=non-unix/' "$SCRIPT_CONF"
			Generate_CSVs
		;;
		check)
			OUTPUTTIMEMODE="$(Conf_Parameters check OUTPUTTIMEMODE)"
			echo "${OUTPUTTIMEMODE:=unix}"
		;;
	esac
}

##----------------------------------------##
## Modified by Martinski W. [2025-Jan-04] ##
##----------------------------------------##
WriteStats_ToJS()
{
	if [ $# -lt 4 ] ; then return 1 ; fi

	if [ -f "$2" ]
	then
	    sed -i -e '/^}/d;/^function/d;/^document.getElementById/d;/^databaseResetDone/d;' "$2"
	    awk 'NF' "$2" > "${2}.tmp"
	    mv -f "${2}.tmp" "$2"
	fi
	printf "\nfunction %s(){\n" "$3" >> "$2"
	html='document.getElementById("'"$4"'").innerHTML="'

	while IFS='' read -r line || [ -n "$line" ]
	do html="${html}${line}"
	done < "$1"
	html="$html"'"'

	if [ $# -lt 5 ] || [ -z "$5" ]
	then printf "%s\n}\n" "$html" >> "$2"
	else printf "%s;\n%s\n}\n" "$html" "$5" >> "$2"
	fi
}

##----------------------------------------------------------------------
## $1 fieldname $2 tablename $3 frequency (hours) $4 length (days) 
## $5 outputfile $6 outputfrequency $7 sqlfile $8 timestamp
##----------------------------------------------------------------------
##----------------------------------------##
## Modified by Martinski W. [2024-Dec-21] ##
##----------------------------------------##
WriteSql_ToFile()
{
	timenow="$8"
	maxcount="$(echo "$3" "$4" | awk '{printf ((24*$2)/$1)}')"

	if ! echo "$5" | grep -q "day"
	then
		{
			echo ".mode csv"
			echo ".headers on"
			echo ".output ${5}_${6}.htm"
			echo "PRAGMA temp_store=1;"
			echo "SELECT '$1' Metric,Min(strftime('%s',datetime(strftime('%Y-%m-%d %H:00:00',datetime([Timestamp],'unixepoch'))))) Time,IFNULL(Avg([$1]),'NaN') Value FROM $2 WHERE ([Timestamp] >= strftime('%s',datetime($timenow,'unixepoch','-$maxcount hour'))) GROUP BY strftime('%m',datetime([Timestamp],'unixepoch')),strftime('%d',datetime([Timestamp],'unixepoch')),strftime('%H',datetime([Timestamp],'unixepoch')) ORDER BY [Timestamp] DESC;"
		} > "$7"
	else
		{
			echo ".mode csv"
			echo ".headers on"
			echo ".output ${5}_${6}.htm"
			echo "PRAGMA temp_store=1;"
			echo "SELECT '$1' Metric,Max(strftime('%s',datetime([Timestamp],'unixepoch','start of day'))) Time,IFNULL(Avg([$1]),'NaN') Value FROM $2 WHERE ([Timestamp] > strftime('%s',datetime($timenow,'unixepoch','start of day','+1 day','-$maxcount day'))) GROUP BY strftime('%m',datetime([Timestamp],'unixepoch')),strftime('%d',datetime([Timestamp],'unixepoch')) ORDER BY [Timestamp] DESC;"
		} > "$7"
	fi
}

##-------------------------------------##
## Added by Martinski W. [2024-Nov-23] ##
##-------------------------------------##
_GetFileSize_()
{
   local sizeUnits  sizeInfo  fileSize
   if [ $# -eq 0 ] || [ -z "$1" ] || [ ! -s "$1" ]
   then echo 0; return 1 ; fi

   if [ $# -lt 2 ] || [ -z "$2" ] || \
      ! echo "$2" | grep -qE "^(B|KB|MB|GB|HR|HRx)$"
   then sizeUnits="B" ; else sizeUnits="$2" ; fi

   _GetNum_() { printf "%.1f" "$(echo "$1" | awk "{print $1}")" ; }

   case "$sizeUnits" in
       B|KB|MB|GB)
           fileSize="$(ls -1l "$1" | awk -F ' ' '{print $3}')"
           case "$sizeUnits" in
               KB) fileSize="$(_GetNum_ "($fileSize / $oneKByte)")" ;;
               MB) fileSize="$(_GetNum_ "($fileSize / $oneMByte)")" ;;
               GB) fileSize="$(_GetNum_ "($fileSize / $oneGByte)")" ;;
           esac
           echo "$fileSize"
           ;;
       HR|HRx)
           fileSize="$(ls -1lh "$1" | awk -F ' ' '{print $3}')"
           sizeInfo="${fileSize}B"
           if [ "$sizeUnits" = "HR" ]
           then echo "$sizeInfo" ; return 0 ; fi
           sizeUnits="$(echo "$sizeInfo" | tr -d '.0-9')"
           case "$sizeUnits" in
               MB) fileSize="$(_GetFileSize_ "$1" KB)"
                   sizeInfo="$sizeInfo [${fileSize}KB]"
                   ;;
               GB) fileSize="$(_GetFileSize_ "$1" MB)"
                   sizeInfo="$sizeInfo [${fileSize}MB]"
                   ;;
           esac
           echo "$sizeInfo"
           ;;
       *) echo 0 ;;
   esac
   return 0
}

##-------------------------------------##
## Added by Martinski W. [2024-Dec-21] ##
##-------------------------------------##
_Get_JFFS_Space_()
{
   local typex  total  usedx  freex  totalx
   local sizeUnits  sizeType  sizeInfo  sizeNum
   local jffsMountStr  jffsUsageStr  percentNum  percentStr

   if [ $# -lt 1 ] || [ -z "$1" ] || \
      ! echo "$1" | grep -qE "^(ALL|USED|FREE)$"
   then sizeType="ALL" ; else sizeType="$1" ; fi

   if [ $# -lt 2 ] || [ -z "$2" ] || \
      ! echo "$2" | grep -qE "^(KB|KBP|MBP|GBP|HR|HRx)$"
   then sizeUnits="KB" ; else sizeUnits="$2" ; fi

   _GetNum_() { printf "%.2f" "$(echo "$1" | awk "{print $1}")" ; }

   jffsMountStr="$(mount | grep '/jffs')"
   jffsUsageStr="$(df -kT /jffs | grep -E '.*[[:blank:]]+/jffs$')"

   if [ -z "$jffsMountStr" ] || [ -z "$jffsUsageStr" ]
   then echo "**ERROR**: JFFS is *NOT* mounted." ; return 1
   fi
   if echo "$jffsMountStr" | grep -qE "[[:blank:]]+[(]?ro[[:blank:],]"
   then echo "**ERROR**: JFFS is mounted READ-ONLY." ; return 2
   fi

   typex="$(echo "$jffsUsageStr" | awk -F ' ' '{print $2}')"
   total="$(echo "$jffsUsageStr" | awk -F ' ' '{print $3}')"
   usedx="$(echo "$jffsUsageStr" | awk -F ' ' '{print $4}')"
   freex="$(echo "$jffsUsageStr" | awk -F ' ' '{print $5}')"
   totalx="$total"
   if [ "$typex" = "ubifs" ] && [ "$((usedx + freex))" -ne "$total" ]
   then totalx="$((usedx + freex))" ; fi

   if [ "$sizeType" = "ALL" ] ; then echo "$totalx" ; return 0 ; fi

   case "$sizeUnits" in
       KB|KBP|MBP|GBP)
           case "$sizeType" in
               USED) sizeNum="$usedx"
                     percentNum="$(printf "%.1f" "$(_GetNum_ "($usedx * 100 / $totalx)")")"
                     percentStr="[${percentNum}%]"
                     ;;
               FREE) sizeNum="$freex"
                     percentNum="$(printf "%.1f" "$(_GetNum_ "($freex * 100 / $totalx)")")"
                     percentStr="[${percentNum}%]"
                     ;;
           esac
           case "$sizeUnits" in
                KB) sizeInfo="$sizeNum"
                    ;;
               KBP) sizeInfo="${sizeNum}.0KB $percentStr"
                    ;;
               MBP) sizeNum="$(_GetNum_ "($sizeNum / $oneKByte)")"
                    sizeInfo="${sizeNum}MB $percentStr"
                    ;;
               GBP) sizeNum="$(_GetNum_ "($sizeNum / $oneMByte)")"
                    sizeInfo="${sizeNum}GB $percentStr"
                    ;;
           esac
           echo "$sizeInfo"
           ;;
       HR|HRx)
           jffsUsageStr="$(df -hT /jffs | grep -E '.*[[:blank:]]+/jffs$')"
           case "$sizeType" in
               USED) usedx="$(echo "$jffsUsageStr" | awk -F ' ' '{print $4}')"
                     sizeInfo="${usedx}B"
                     ;;
               FREE) freex="$(echo "$jffsUsageStr" | awk -F ' ' '{print $5}')"
                     sizeInfo="${freex}B"
                     ;;
           esac
           if [ "$sizeUnits" = "HR" ]
           then echo "$sizeInfo" ; return 0 ; fi
           sizeUnits="$(echo "$sizeInfo" | tr -d '.0-9')"
           case "$sizeUnits" in
               KB) sizeInfo="$(_Get_JFFS_Space_ "$sizeType" KBP)" ;;
               MB) sizeInfo="$(_Get_JFFS_Space_ "$sizeType" MBP)" ;;
               GB) sizeInfo="$(_Get_JFFS_Space_ "$sizeType" GBP)" ;;
           esac
           echo "$sizeInfo"
           ;;
       *) echo 0 ;;
   esac
   return 0
}

##----------------------------------------##
## Modified by Martinski W. [2025-Feb-03] ##
##----------------------------------------##
##------------------------------------------------------##
## Check JFFS free space *before* moving files from USB ##
##------------------------------------------------------##
_Check_JFFS_SpaceAvailable_()
{
   local requiredSpace  jffsAllxSpace  jffsFreeSpace  jffsMinxSpace
   if [ $# -eq 0 ] || [ -z "$1" ] || [ ! -d "$1" ] ; then return 0 ; fi

   [ "$1" = "/jffs/addons/${SCRIPT_NAME}.d" ] && return 0

   if ! jffsAllxSpace="$(_Get_JFFS_Space_ ALL KB)" ; then return 1 ; fi
   if ! jffsFreeSpace="$(_Get_JFFS_Space_ FREE KB)" ; then return 1 ; fi
   requiredSpace="$(du -kc "$1" | grep -w 'total$' | awk -F ' ' '{print $1}')"

   jffsAllxSpace="$(echo "$jffsAllxSpace" | awk '{printf("%s", $1 * 1024);}')"
   jffsFreeSpace="$(echo "$jffsFreeSpace" | awk '{printf("%s", $1 * 1024);}')"
   requiredSpace="$(echo "$requiredSpace" | awk '{printf("%s", $1 * 1024);}')"

   ## Make sure remaining JFFS free space is at least 20% of total space ##
   jffsMinxSpace="$(echo "$jffsAllxSpace" | awk '{printf("%d", $1 * 20 / 100);}')"
   requiredSpace="$(echo "$requiredSpace $jffsMinxSpace" | awk -F ' ' '{printf("%s", $1 + $2);}')"

   if [ "$(echo "$requiredSpace $jffsFreeSpace" | awk -F ' ' '{print ($1 < $2)}')" -eq 1 ]
   then return 0 ; fi

   requiredSpace="$(du -hc "$1" | grep -w 'total$' | awk -F ' ' '{print $1}')"
   errorMsg1="Not enough free space [$(_Get_JFFS_Space_ FREE HR)] available in JFFS."
   errorMsg2="Minimum storage space required: $requiredSpace"
   Print_Output true "${errorMsg1} ${errorMsg2}" "$CRIT"
   return 1
}

##----------------------------------------##
## Modified by Martinski W. [2024-Dec-23] ##
##----------------------------------------##
_UpdateJFFS_FreeSpaceInfo_()
{
   local jffsFreeSpace
   local outJSfile="$SCRIPT_STORAGE_DIR/connstatstext.js"
   [ ! -d "$SCRIPT_STORAGE_DIR" ] && return 1

   jffsFreeSpace="$(_Get_JFFS_Space_ FREE HRx)"

   if [ ! -s "$outJSfile" ]
   then
       echo "var jffsAvailableSpace = '${jffsFreeSpace}';" >> "$outJSfile"
   elif ! grep -q "^var jffsAvailableSpace =.*" "$outJSfile"
   then
       sed -i "1 i var jffsAvailableSpace = '${jffsFreeSpace}';" "$outJSfile"
   else
       sed -i "s/^var jffsAvailableSpace =.*/var jffsAvailableSpace = '${jffsFreeSpace}';/" "$outJSfile"
   fi
}

##----------------------------------------##
## Modified by Martinski W. [2024-Dec-23] ##
##----------------------------------------##
_UpdateAutomaticModeState_()
{
   local automaticModeStatus
   local outJSfile="$SCRIPT_STORAGE_DIR/connstatstext.js"
   [ ! -d "$SCRIPT_STORAGE_DIR" ] && return 1

   if AutomaticMode check
   then automaticModeStatus="ENABLED"
   else automaticModeStatus="DISABLED"
   fi

   if [ ! -s "$outJSfile" ]
   then
       echo "var automaticModeState = '${automaticModeStatus}';" >> "$outJSfile"
   elif ! grep -q "^var automaticModeState =.*" "$outJSfile"
   then
       sed -i "3 i var automaticModeState = '${automaticModeStatus}';" "$outJSfile"
   else
       sed -i "s/^var automaticModeState =.*/var automaticModeState = '${automaticModeStatus}';/" "$outJSfile"
   fi
}

##----------------------------------------##
## Modified by Martinski W. [2024-Dec-23] ##
##----------------------------------------##
_UpdateDatabaseFileSizeInfo_()
{
   local databaseFileSize
   local outJSfile="$SCRIPT_STORAGE_DIR/connstatstext.js"
   [ ! -d "$SCRIPT_STORAGE_DIR" ] && return 1

   databaseFileSize="$(_GetFileSize_ "$CONNSTATS_DB" HRx)"

   if [ ! -s "$outJSfile" ]
   then
       echo "var sqlDatabaseFileSize = '${databaseFileSize}';" >> "$outJSfile"
   elif ! grep -q "^var sqlDatabaseFileSize =.*" "$outJSfile"
   then
       sed -i "1 i var sqlDatabaseFileSize = '${databaseFileSize}';" "$outJSfile"
   else
       sed -i "s/^var sqlDatabaseFileSize =.*/var sqlDatabaseFileSize = '${databaseFileSize}';/" "$outJSfile"
   fi
   _UpdateJFFS_FreeSpaceInfo_
   _UpdateAutomaticModeState_
}

##----------------------------------------##
## Modified by Martinski W. [2025-Jan-28] ##
##----------------------------------------##
_ApplyDatabaseSQLCmds_()
{
    local errorCount=0  maxErrorCount=5  callFlag
    local triesCount=0  maxTriesCount=25  sqlErrorMsg
    local tempLogFilePath="/tmp/connMonStats_TMP_$$.LOG"

    if [ $# -gt 1 ] && [ -n "$2" ]
    then callFlag="$2"
    else callFlag="err"
    fi

    resultStr=""
    foundError=false ; foundLocked=false
    rm -f "$tempLogFilePath"

    while [ "$errorCount" -lt "$maxErrorCount" ] && \
          [ "$((triesCount++))" -lt "$maxTriesCount" ]
    do
        if "$SQLITE3_PATH" "$CONNSTATS_DB" < "$1" >> "$tempLogFilePath" 2>&1
        then foundError=false ; foundLocked=false ; break
        fi
        sqlErrorMsg="$(cat "$tempLogFilePath")"
        if echo "$sqlErrorMsg" | grep -qE "^(Parse error|Runtime error|Error:)"
        then
            if echo "$sqlErrorMsg" | grep -qE "^(Parse|Runtime) error .*: database is locked"
            then
                echo -n > "$tempLogFilePath"  ##Clear for next error found##
                foundLocked=true ; sleep 2 ; continue
            fi
            errorCount="$((errorCount + 1))"
            foundError=true ; foundLocked=false
            Print_Output true "SQLite3 failure[$callFlag]: $sqlErrorMsg" "$ERR"
            echo -n > "$tempLogFilePath"  ##Clear for next error found##
        fi
        [ "$triesCount" -ge "$maxTriesCount" ] && break
        [ "$errorCount" -ge "$maxErrorCount" ] && break
        sleep 1
    done

    rm -f "$tempLogFilePath"
    if "$foundError"
    then resultStr="reported error(s)."
    elif "$foundLocked"
    then resultStr="found database locked."
    else resultStr="completed successfully."
    fi
    if "$foundError" || "$foundLocked"
    then
        Print_Output true "SQLite process ${resultStr}" "$ERR"
    fi
}

##----------------------------------------##
## Modified by Martinski W. [2025-Jan-29] ##
##----------------------------------------##
_Optimize_Database_()
{
   renice 15 $$
   local foundError  foundLocked  resultStr

   Print_Output true "Running database analysis and optimization..." "$PASS"
   {
      echo "PRAGMA temp_store=1;"
      echo "PRAGMA journal_mode=TRUNCATE;"
      echo "PRAGMA analysis_limit=0;"
      echo "PRAGMA cache_size=-20000;"
      echo "ANALYZE connstats;"
      echo "VACUUM;"
   } > /tmp/connmon-trim.sql
   _ApplyDatabaseSQLCmds_ /tmp/connmon-trim.sql opt1

   rm -f /tmp/connmon-trim.sql
   if "$foundError" || "$foundLocked"
   then Print_Output true "Database analysis and optimization ${resultStr}" "$ERR"
   else Print_Output true "Database analysis and optimization ${resultStr}" "$PASS"
   fi
   renice 0 $$
}

##----------------------------------------##
## Modified by Martinski W. [2025-Jan-29] ##
##----------------------------------------##
_Trim_Database_()
{
   renice 15 $$
   TZ="$(cat /etc/TZ)"
   export TZ
   timeNow="$(date +'%s')"

   local foundError  foundLocked  resultStr

   Print_Output true "Trimming records from database..." "$PASS"
   {
      echo "PRAGMA temp_store=1;"
      echo "PRAGMA journal_mode=TRUNCATE;"
      echo "PRAGMA cache_size=-20000;"
      echo "DELETE FROM [connstats] WHERE [Timestamp] < strftime('%s',datetime($timeNow,'unixepoch','-$(DaysToKeep check) day'));"
   } > /tmp/connmon-trim.sql
   _ApplyDatabaseSQLCmds_ /tmp/connmon-trim.sql trm1

   rm -f /tmp/connmon-trim.sql
   if "$foundError" || "$foundLocked"
   then Print_Output true "Database record trimming ${resultStr}" "$ERR"
   else Print_Output true "Database record trimming ${resultStr}" "$PASS"
   fi
   renice 0 $$
}

##----------------------------------------##
## Modified by Martinski W. [2025-Jan-29] ##
##----------------------------------------##
Run_PingTest()
{
	if [ ! -f /opt/bin/xargs ] && [ -x /opt/bin/opkg ]
	then
		Print_Output true "Installing findutils from Entware" "$PASS"
		opkg update
		opkg install findutils
	fi
	if [ -n "$PPID" ]; then
		ps | grep -v grep | grep -v $$ | grep -v "$PPID" | grep -i "$SCRIPT_NAME" | grep generate | awk '{print $1}' | xargs kill -9 >/dev/null 2>&1
	else
		ps | grep -v grep | grep -v $$ | grep -i "$SCRIPT_NAME" | grep generate | awk '{print $1}' | xargs kill -9 >/dev/null 2>&1
	fi
	Create_Dirs
	Conf_Exists
	Auto_Startup create 2>/dev/null
	if AutomaticMode check
	then Auto_Cron create 2>/dev/null
	else Auto_Cron delete 2>/dev/null
	fi
	Auto_ServiceEvent create 2>/dev/null
	ScriptStorageLocation load
	Create_Symlinks

	pingfile=/tmp/pingfile.txt
	resultfile="$SCRIPT_WEB_DIR/ping-result.txt"
	pingduration="$(PingDuration check)"
	pingtarget="$(PingServer check)"
	pingtargetip=""
	completepingtarget=""
	rm -f "$resultfile"
	rm -f "$pingfile"

	echo 'var connmonstatus = "InProgress";' > "$SCRIPT_WEB_DIR/detect_connmon.js"

	Print_Output false "$pingduration second ping test to $pingtarget starting..." "$PASS"

	if ! expr "$pingtarget" : '[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*$' >/dev/null && nslookup "$pingtarget" >/dev/null 2>&1
	then
		pingtargetip="$(dig +short +answer "$pingtarget" | head -n 1)"
		completepingtarget="$pingtarget ($pingtargetip)"
	else
		pingtargetip="$pingtarget"
		completepingtarget="$pingtarget"
	fi

	stoppedqos="false"
	if [ "$(ExcludeFromQoS check)" = "true" ]
	then
		if [ "$(nvram get qos_enable)" -eq 1 ] && [ "$(nvram get qos_type)" -eq 1 ]
		then
			for ACTION in -D -A ; do
				iptables "$ACTION" OUTPUT -p icmp -j MARK --set-xmark 0x80000000/0xC0000000 2>/dev/null
				iptables -t mangle "$ACTION" OUTPUT -p icmp -j MARK --set-xmark 0x80000000/0xC0000000 2>/dev/null
				iptables -t mangle "$ACTION" POSTROUTING -p icmp -j MARK --set-xmark 0x80000000/0xC0000000 2>/dev/null
				stoppedqos="true"
			done
		elif [ "$(nvram get qos_enable)" -eq 1 ] && [ "$(nvram get qos_type)" -ne 1 ] && [ -f /tmp/qos ]; then
			/tmp/qos stop >/dev/null 2>&1
			stoppedqos="true"
		elif [ "$(nvram get qos_enable)" -eq 0 ] && [ -f /jffs/addons/cake-qos/cake-qos ]; then
			/jffs/addons/cake-qos/cake-qos stop >/dev/null 2>&1
			stoppedqos="true"
		fi
	fi

	ping -w "$pingduration" "$pingtargetip" > "$pingfile"

	if [ "$stoppedqos" = "true" ]
	then
		if [ "$(nvram get qos_enable)" -eq 1 ] && [ "$(nvram get qos_type)" -eq 1 ]; then
			iptables -D OUTPUT -p icmp -j MARK --set-xmark 0x80000000/0xC0000000 2>/dev/null
			iptables -t mangle -D OUTPUT -p icmp -j MARK --set-xmark 0x80000000/0xC0000000 2>/dev/null
			iptables -t mangle -D POSTROUTING -p icmp -j MARK --set-xmark 0x80000000/0xC0000000 2>/dev/null
		elif [ "$(nvram get qos_enable)" -eq 1 ] && [ "$(nvram get qos_type)" -ne 1 ] && [ -f /tmp/qos ]; then
			/tmp/qos start >/dev/null 2>&1
		elif [ "$(nvram get qos_enable)" -eq 0 ] && [ -f /jffs/addons/cake-qos/cake-qos ]; then
			/jffs/addons/cake-qos/cake-qos start >/dev/null 2>&1
		fi
	fi

	ScriptStorageLocation load

	PREVPING=0
	TOTALDIFF=0
	COUNTER=1
	PINGLIST="$(grep seq= "$pingfile")"
	PINGCOUNT="$(echo "$PINGLIST" | sed '/^\s*$/d' | wc -l)"
	DIFFCOUNT="$((PINGCOUNT - 1))"
	if [ "$PINGCOUNT" -gt 0 ]
	then
		until [ "$COUNTER" -gt "$PINGCOUNT" ]
		do
			CURPING="$(echo "$PINGLIST" | sed -n "$COUNTER"p | cut -f4 -d"=" | cut -f1 -d" ")"

			if [ "$COUNTER" -gt 1 ]
			then
				DIFF="$(echo "$CURPING" "$PREVPING" | awk '{printf "%4.3f\n",$1-$2}')"
				NEG="$(echo "$DIFF" 0 | awk '{ if ($1 < $2) print "neg"; else print "pos"}')"
				if [ "$NEG" = "neg" ]; then DIFF="$(echo "$DIFF" "-1" | awk '{printf "%4.3f\n",$1*$2}')"; fi
				TOTALDIFF="$(echo "$TOTALDIFF" "$DIFF" | awk '{printf "%4.3f\n",$1+$2}')"
			fi
			PREVPING="$CURPING"
			COUNTER="$((COUNTER + 1))"
		done
	fi

	TZ="$(cat /etc/TZ)"
	export TZ

	timenow="$(/bin/date +'%s')"
	timenowfriendly="$(/bin/date +"%c")"

	ping=0
	jitter=0
	linequal=0

	if [ "$PINGCOUNT" -gt 1 ]
	then
		ping="$(tail -n 1 "$pingfile"  | cut -f4 -d"/")"
		jitter="$(echo "$TOTALDIFF" "$DIFFCOUNT" | awk '{printf "%4.3f\n",$1/$2}')"
		pkt_trans="$(tail -n 2 "$pingfile" | head -n 1 | cut -f1 -d"," | cut -f1 -d" ")"
		pkt_rec="$(tail -n 2 "$pingfile" | head -n 1 | cut -f2 -d"," | cut -f2 -d" ")"
		linequal="$(echo "$pkt_rec" "$pkt_trans" | awk '{printf "%4.3f\n",100*$1/$2}')"
	fi

	Process_Upgrade

	{
	   echo "PRAGMA temp_store=1;"
	   echo "PRAGMA journal_mode=TRUNCATE;"
	   echo "CREATE TABLE IF NOT EXISTS [connstats] ([StatID] INTEGER PRIMARY KEY NOT NULL,[Timestamp] NUMERIC NOT NULL,[Ping] REAL NOT NULL,[Jitter] REAL NOT NULL,[LineQuality] REAL NOT NULL,[PingTarget] TEXT NOT NULL,[PingDuration] NUMERIC);"
	   echo "INSERT INTO connstats ([Timestamp],[Ping],[Jitter],[LineQuality],[PingTarget],[PingDuration]) values($timenow,$ping,$jitter,$linequal,'$completepingtarget',$pingduration);"
	} > /tmp/connmon-stats.sql
	_ApplyDatabaseSQLCmds_ /tmp/connmon-stats.sql png1

	echo 'var connmonstatus = "GenerateCSV";' > "$SCRIPT_WEB_DIR/detect_connmon.js"
	Generate_CSVs

	_UpdateDatabaseFileSizeInfo_

	echo "Stats last updated: $timenowfriendly" > /tmp/connstatstitle.txt
	WriteStats_ToJS /tmp/connstatstitle.txt "$SCRIPT_STORAGE_DIR/connstatstext.js" setConnmonStatsTitle statstitle
	Print_Output false "Test results: Ping $ping ms - Jitter - $jitter ms - Line Quality ${linequal}%" "$PASS"

	{
		printf "Ping test result\n"
		printf "\nPing %s ms - Jitter - %s ms - Line Quality %s %%\n" "$ping" "$jitter" "$linequal"
	} >> "$resultfile"

	rm -f "$pingfile"
	rm -f /tmp/connstatstitle.txt

	TriggerNotifications PingTest "$timenowfriendly" "$ping ms" "$jitter ms" "$linequal %" "$timenow"

	if [ "$(echo "$ping" "$(Conf_Parameters check NOTIFICATIONS_PINGTHRESHOLD_VALUE)" | awk '{print ($1 > $2)}')" -eq 1 ]; then
		TriggerNotifications PingThreshold "$timenowfriendly" "$ping ms" "$(Conf_Parameters check NOTIFICATIONS_PINGTHRESHOLD_VALUE) ms"
	fi

	if [ "$(echo "$jitter" "$(Conf_Parameters check NOTIFICATIONS_JITTERTHRESHOLD_VALUE)" | awk '{print ($1 > $2)}')" -eq 1 ]; then
		TriggerNotifications JitterThreshold "$timenowfriendly" "$jitter ms" "$(Conf_Parameters check NOTIFICATIONS_JITTERTHRESHOLD_VALUE) ms"
	fi

	if [ "$(echo "$linequal" "$(Conf_Parameters check NOTIFICATIONS_LINEQUALITYTHRESHOLD_VALUE)" | awk '{print ($1 < $2)}')" -eq 1 ]; then
		TriggerNotifications LineQualityThreshold "$timenowfriendly" "$linequal %" "$(Conf_Parameters check NOTIFICATIONS_LINEQUALITYTHRESHOLD_VALUE) %"
	fi
	echo 'var connmonstatus = "Done";' > "$SCRIPT_WEB_DIR/detect_connmon.js"
}

##----------------------------------------##
## Modified by Martinski W. [2024-Dec-21] ##
##----------------------------------------##
Generate_CSVs()
{
	Process_Upgrade
	renice 15 $$
	OUTPUTTIMEMODE="$(OutputTimeMode check)"
	TZ="$(cat /etc/TZ)"
	export TZ

	timenow="$(/bin/date +"%s")"
	timenowfriendly="$(/bin/date +"%c")"

	metriclist="Ping Jitter LineQuality"

	for metric in $metriclist
	do
		{
			echo ".mode csv"
			echo ".headers on"
			echo ".output $CSV_OUTPUT_DIR/${metric}_raw_daily.htm"
			echo "PRAGMA temp_store=1;"
			echo "SELECT '$metric' Metric,[Timestamp] Time,[$metric] Value FROM connstats WHERE ([Timestamp] >= strftime('%s',datetime($timenow,'unixepoch','-1 day'))) ORDER BY [Timestamp] DESC;"
		} > /tmp/connmon-stats.sql
		_ApplyDatabaseSQLCmds_ /tmp/connmon-stats.sql gnr1

		{
			echo ".mode csv"
			echo ".headers on"
			echo ".output $CSV_OUTPUT_DIR/${metric}_raw_weekly.htm"
			echo "PRAGMA temp_store=1;"
			echo "SELECT '$metric' Metric,[Timestamp] Time,[$metric] Value FROM connstats WHERE ([Timestamp] >= strftime('%s',datetime($timenow,'unixepoch','-7 day'))) ORDER BY [Timestamp] DESC;"
		} > /tmp/connmon-stats.sql
		_ApplyDatabaseSQLCmds_ /tmp/connmon-stats.sql gnr2

		{
			echo ".mode csv"
			echo ".headers on"
			echo ".output $CSV_OUTPUT_DIR/${metric}_raw_monthly.htm"
			echo "PRAGMA temp_store=1;"
			echo "SELECT '$metric' Metric,[Timestamp] Time,[$metric] Value FROM connstats WHERE ([Timestamp] >= strftime('%s',datetime($timenow,'unixepoch','-30 day'))) ORDER BY [Timestamp] DESC;"
		} > /tmp/connmon-stats.sql
		_ApplyDatabaseSQLCmds_ /tmp/connmon-stats.sql gnr3

		WriteSql_ToFile "$metric" connstats 1 1 "$CSV_OUTPUT_DIR/${metric}_hour" daily /tmp/connmon-stats.sql "$timenow"
		_ApplyDatabaseSQLCmds_ /tmp/connmon-stats.sql gnr4

		WriteSql_ToFile "$metric" connstats 1 7 "$CSV_OUTPUT_DIR/${metric}_hour" weekly /tmp/connmon-stats.sql "$timenow"
		_ApplyDatabaseSQLCmds_ /tmp/connmon-stats.sql gnr5

		WriteSql_ToFile "$metric" connstats 1 30 "$CSV_OUTPUT_DIR/${metric}_hour" monthly /tmp/connmon-stats.sql "$timenow"
		_ApplyDatabaseSQLCmds_ /tmp/connmon-stats.sql gnr6

		WriteSql_ToFile "$metric" connstats 24 1 "$CSV_OUTPUT_DIR/${metric}_day" daily /tmp/connmon-stats.sql "$timenow"
		_ApplyDatabaseSQLCmds_ /tmp/connmon-stats.sql gnr7

		WriteSql_ToFile "$metric" connstats 24 7 "$CSV_OUTPUT_DIR/${metric}_day" weekly /tmp/connmon-stats.sql "$timenow"
		_ApplyDatabaseSQLCmds_ /tmp/connmon-stats.sql gnr8

		WriteSql_ToFile "$metric" connstats 24 30 "$CSV_OUTPUT_DIR/${metric}_day" monthly /tmp/connmon-stats.sql "$timenow"
		_ApplyDatabaseSQLCmds_ /tmp/connmon-stats.sql gnr9

		rm -f "$CSV_OUTPUT_DIR/${metric}daily.htm"
		rm -f "$CSV_OUTPUT_DIR/${metric}weekly.htm"
		rm -f "$CSV_OUTPUT_DIR/${metric}monthly.htm"
	done

	rm -f /tmp/connmon-stats.sql
	Generate_LastXResults

	{
	   echo ".mode csv"
	   echo ".headers on"
	   echo ".output $CSV_OUTPUT_DIR/CompleteResults.htm"
	   echo "PRAGMA temp_store=1;"
	   echo "SELECT [Timestamp],[Ping],[Jitter],[LineQuality],[PingTarget],[PingDuration] FROM connstats WHERE ([Timestamp] >= strftime('%s',datetime($timenow,'unixepoch','-$(DaysToKeep check) day'))) ORDER BY [Timestamp] DESC;"
    } > /tmp/connmon-complete.sql
	_ApplyDatabaseSQLCmds_ /tmp/connmon-complete.sql gnr10

	rm -f /tmp/connmon-complete.sql
	sed -i 's/"//g' "$CSV_OUTPUT_DIR/CompleteResults.htm"

	dos2unix "$CSV_OUTPUT_DIR/"*.htm

	tmpoutputdir="/tmp/${SCRIPT_NAME}results"
	mkdir -p "$tmpoutputdir"
	mv "$CSV_OUTPUT_DIR/CompleteResults.htm" "$tmpoutputdir/CompleteResults.htm"

	if [ "$OUTPUTTIMEMODE" = "unix" ]
	then
		find "$tmpoutputdir/" -name '*.htm' -exec sh -c 'i="$1"; mv -- "$i" "${i%.htm}.csv"' _ {} \;
	elif [ "$OUTPUTTIMEMODE" = "non-unix" ]
	then
		for i in "$tmpoutputdir/"*".htm"
		do
			awk -F"," 'NR==1 {OFS=","; print} NR>1 {OFS=","; $1=strftime("%Y-%m-%d %H:%M:%S", $1); print }' "$i" > "$i.out"
		done

		find "$tmpoutputdir/" -name '*.htm.out' -exec sh -c 'i="$1"; mv -- "$i" "${i%.htm.out}.csv"' _ {} \;
		rm -f "$tmpoutputdir/"*.htm
	fi

	mv "$tmpoutputdir/CompleteResults.csv" "$CSV_OUTPUT_DIR/CompleteResults.htm"
	rm -f "$CSV_OUTPUT_DIR/connmondata.zip"
	rm -rf "$tmpoutputdir"
	renice 0 $$
}

##----------------------------------------##
## Modified by Martinski W. [2024-Dec-21] ##
##----------------------------------------##
Generate_LastXResults()
{
	rm -f "$SCRIPT_STORAGE_DIR/connjs.js"
	rm -f "$SCRIPT_STORAGE_DIR/lastx.htm"
	{
		echo ".mode csv"
		echo ".output /tmp/conn-lastx.csv"
		echo "PRAGMA temp_store=1;"
		echo "SELECT [Timestamp],[Ping],[Jitter],[LineQuality],[PingTarget],[PingDuration] FROM connstats ORDER BY [Timestamp] DESC LIMIT $(LastXResults check);"
	} > /tmp/conn-lastx.sql
	_ApplyDatabaseSQLCmds_ /tmp/conn-lastx.sql gls1

	rm -f /tmp/conn-lastx.sql
	sed -i 's/"//g' /tmp/conn-lastx.csv
	mv /tmp/conn-lastx.csv "$SCRIPT_STORAGE_DIR/lastx.csv"
}

##----------------------------------------##
## Modified by Martinski W. [2024-Dec-21] ##
##----------------------------------------##
Reset_DB()
{
	SIZEAVAIL="$(df -kP "$SCRIPT_STORAGE_DIR" | awk -F ' ' '{print $4}' | tail -n 1)"
	SIZEDB="$(ls -l "$CONNSTATS_DB" | awk -F ' ' '{print $5}')"
	SIZEAVAIL="$(echo "$SIZEAVAIL" | awk '{printf("%s", $1 * 1024);}')"

	if [ "$(echo "$SIZEAVAIL $SIZEDB" | awk '{print ($1 < $2)}')" -eq 1 ]
	then
		Print_Output true "Database size exceeds available space. $(ls -lh "$CONNSTATS_DB" | awk '{print $5}')B is required to create backup." "$ERR"
		return 1
	else
		Print_Output true "Sufficient free space to back up database, proceeding..." "$PASS"
		if ! cp -a "$CONNSTATS_DB" "${CONNSTATS_DB}.bak"; then
			Print_Output true "Database backup failed, please check storage device" "$WARN"
		fi

		Print_Output false "Please wait..." "$PASS"
        {
		   echo "PRAGMA temp_store=1;"
		   echo "DELETE FROM [connstats];" 
        } > /tmp/connmon-stats.sql
		_ApplyDatabaseSQLCmds_ /tmp/connmon-stats.sql rst1
		rm -f /tmp/connmon-stats.sql

		## Clear/Reset all CSV files ##
		Generate_CSVs

		## Show "reset" messages on webGUI ##
		timeDateNow="$(/bin/date +"%c")"
		extraJScode='databaseResetDone += 1;'
		echo "Resetting stats: $timeDateNow" > /tmp/connstatstitle.txt
		WriteStats_ToJS /tmp/connstatstitle.txt "$SCRIPT_STORAGE_DIR/connstatstext.js" setConnmonStatsTitle statstitle "$extraJScode"
		rm -f /tmp/connstatstitle.txt
		sleep 2
		Print_Output true "Database reset complete" "$WARN"
		{
		   sleep 4
           _UpdateDatabaseFileSizeInfo_
		   timeDateNow="$(/bin/date +"%c")"
		   extraJScode='databaseResetDone = 0;'
		   echo "Stats were reset: $timeDateNow" > /tmp/connstatstitle.txt
		   WriteStats_ToJS /tmp/connstatstitle.txt "$SCRIPT_STORAGE_DIR/connstatstext.js" setConnmonStatsTitle statstitle "$extraJScode"
		   rm -f /tmp/connstatstitle.txt
		} &
	fi
}

##----------------------------------------##
## Modified by Martinski W. [2024-Dec-21] ##
##----------------------------------------##
Process_Upgrade()
{
    local foundError  foundLocked  resultStr

	rm -f "$SCRIPT_STORAGE_DIR/.tableupgraded"
	if [ ! -f "$SCRIPT_STORAGE_DIR/.indexcreated" ]
	then
		renice 15 $$
		Print_Output true "Creating database table indexes..." "$PASS"
		{
		  echo "PRAGMA temp_store=1;"
		  echo "PRAGMA cache_size=-20000;"
		  echo "CREATE INDEX IF NOT EXISTS idx_time_ping ON connstats (Timestamp,Ping);" 
		} > /tmp/connmon-upgrade.sql
		_ApplyDatabaseSQLCmds_ /tmp/connmon-upgrade.sql prc1
 
		{
		  echo "PRAGMA temp_store=1;"
		  echo "PRAGMA cache_size=-20000;"
		  echo "CREATE INDEX IF NOT EXISTS idx_time_jitter ON connstats (Timestamp,Jitter);" 
		} > /tmp/connmon-upgrade.sql
		_ApplyDatabaseSQLCmds_ /tmp/connmon-upgrade.sql prc2

		{
		  echo "PRAGMA temp_store=1;"
		  echo "PRAGMA cache_size=-20000;"
		  echo "CREATE INDEX IF NOT EXISTS idx_time_linequality ON connstats (Timestamp,LineQuality);"
		} > /tmp/connmon-upgrade.sql
		_ApplyDatabaseSQLCmds_ /tmp/connmon-upgrade.sql prc3

		rm -f /tmp/connmon-upgrade.sql
		touch "$SCRIPT_STORAGE_DIR/.indexcreated"
		Print_Output true "Database ready, continuing..." "$PASS"
		renice 0 $$
	fi
	if [ ! -f "$SCRIPT_STORAGE_DIR/.newcolumns" ]
	then
		{
		  echo "PRAGMA temp_store=1;"
		  echo "PRAGMA cache_size=-20000;"
		  echo "ALTER TABLE connstats ADD COLUMN PingTarget [TEXT] NOT NULL DEFAULT '';"
		} > /tmp/connmon-upgrade.sql
		_ApplyDatabaseSQLCmds_ /tmp/connmon-upgrade.sql prc4

		{
		  echo "PRAGMA temp_store=1;"
		  echo "PRAGMA cache_size=-20000;"
		  echo "ALTER TABLE connstats ADD COLUMN PingDuration [NUMERIC];"
		} > /tmp/connmon-upgrade.sql
		_ApplyDatabaseSQLCmds_ /tmp/connmon-upgrade.sql prc5

		rm -f /tmp/connmon-upgrade.sql
		touch "$SCRIPT_STORAGE_DIR/.newcolumns"
	fi
	if [ ! -f "$SCRIPT_STORAGE_DIR/lastx.csv" ]; then
		Generate_LastXResults
	fi
	if [ ! -f /opt/bin/dig ] && [ -x /opt/bin/opkg ]
	then
		opkg update
		opkg install bind-dig
	fi
	if [ ! -f "$SCRIPT_STORAGE_DIR/.cron" ]; then
		cru l | grep "${SCRIPT_NAME}_generate" | cut -f1-5 -d' ' > "$SCRIPT_STORAGE_DIR/.cron"
	fi
	if [ ! -f "$SCRIPT_STORAGE_DIR/.customactioninfo" ]; then
		CustomAction_Info silent
	fi
	if [ ! -f "$SCRIPT_STORAGE_DIR/.customactionlist" ]; then
		CustomAction_List silent
	fi
	if [ ! -f "$SCRIPT_STORAGE_DIR/.emailinfo" ]; then
		Email_Header silent
	fi
	if [ ! -f /tmp/start_apply.htm  ]
	then
		cp -f /www/start_apply.htm /tmp/
		if ! grep -q 'addon_settings' /tmp/start_apply.htm
		then
			sed -i "/}else if(action_script == \"start_sig_check\"){/i }else if(action_script.indexOf(\"addon_settings\") != -1){ \/\/ do nothing" /tmp/start_apply.htm
		fi
		umount /www/start_apply.htm 2>/dev/null
		mount -o bind /tmp/start_apply.htm /www/start_apply.htm
	fi
	if [ ! -f "$SCRIPT_DIR/README.md" ]; then
		Update_File README.md
	fi
	if [ ! -f "$SCRIPT_DIR/CHANGELOG.md" ]; then
		Update_File CHANGELOG.md
	fi
	if [ ! -f "$SCRIPT_DIR/LICENSE" ]; then
		Update_File LICENSE
	fi
	if [ ! -f "$SCRIPT_STORAGE_DIR/connstatstext.js" ]
	then
		echo "Stats last updated: Not yet updated" > /tmp/connstatstitle.txt
		WriteStats_ToJS /tmp/connstatstitle.txt "$SCRIPT_STORAGE_DIR/connstatstext.js" setConnmonStatsTitle statstitle
	fi
	_UpdateDatabaseFileSizeInfo_
}

Shortcut_Script()
{
	case $1 in
		create)
			if [ -d /opt/bin ] && [ ! -f "/opt/bin/$SCRIPT_NAME" ] && \
			   [ -f "/jffs/scripts/$SCRIPT_NAME" ]
			then
				ln -s "/jffs/scripts/$SCRIPT_NAME" /opt/bin
				chmod 0755 "/opt/bin/$SCRIPT_NAME"
			fi
		;;
		delete)
			if [ -f "/opt/bin/$SCRIPT_NAME" ]; then
				rm -f "/opt/bin/$SCRIPT_NAME"
			fi
		;;
	esac
}

PressEnter()
{
	while true
	do
		printf "Press <Enter> key to continue..."
		read -rs key
		case "$key" in
			*) break ;;
		esac
	done
	return 0
}

Email_ConfExists()
{
	if [ -f "$EMAIL_CONF" ]
	then
		dos2unix "$EMAIL_CONF"
		chmod 0644 "$EMAIL_CONF"
		. "$EMAIL_CONF"
		return 0
	else
		{
			echo "# Email settings (mail envelope) #"
			echo "FROM_ADDRESS=\"\""
			echo "TO_NAME=\"\""
			echo "TO_ADDRESS=\"\""
			echo "FRIENDLY_ROUTER_NAME=\"\""
			echo ""
			echo "# Email credentials #"
			echo "USERNAME=\"\""
			echo "# Encrypted Password is stored in emailpw.enc file."
			echo "emailPwEnc=\"\""
			echo ""
			echo "# Server settings #"
			echo "SMTP=\"\""
			echo "PORT=\"\""
			echo "PROTOCOL=\"\""
			echo "SSL_FLAG=\"\""
		} > "$EMAIL_CONF"
		return 1
	fi
}

Email_Header()
{
	if [ -z "$1" ]
	then
		printf "If you have Two Factor Authentication (2FA) enabled you need to\\n"
		printf "use an App password.\\n\\n"
		printf "${BOLD}Common SMTP Server settings${CLEARFORMAT}\\n"
		printf "%s\\n" "------------------------------------------------"
		printf "Provider    Server                 Port Protocol\\n"
		printf "%s\\n" "------------------------------------------------"
		printf "Gmail       smtp.gmail.com         465  smtps\\n"
		printf "mail.com    smtp.mail.com          587  smtp\\n"
		printf "Yahoo!      smtp.mail.yahoo.com    465  smtps\\n"
		printf "outlook.com smtp-mail.outlook.com  587  smtp\\n"
		printf "%s\\n\\n" "------------------------------------------------"
	fi

	{
		printf "If you have Two Factor Authentication (2FA) enabled you need to use an App password.\\n\\n"
		printf "Common SMTP Server settings\\n"
		printf "%s\\n" "------------------------------------------------"
		printf "Provider    Server                 Port Protocol\\n"
		printf "%s\\n" "------------------------------------------------"
		printf "Gmail       smtp.gmail.com         465  smtps\\n"
		printf "mail.com    smtp.mail.com          587  smtp\\n"
		printf "Yahoo!      smtp.mail.yahoo.com    465  smtps\\n"
		printf "outlook.com smtp-mail.outlook.com  587  smtp\\n"
		printf "%s" "------------------------------------------------"
	} > "$SCRIPT_STORAGE_DIR/.emailinfo"
}

Email_EmailAddress()
{
	EMAIL_ADDRESS=""
	while true
	do
		printf "\\n${BOLD}Enter email address:${CLEARFORMAT}  "
		read -r EMAIL_ADDRESS
		if [ "$EMAIL_ADDRESS" = "e" ]; then
			EMAIL_ADDRESS=""
			break
		elif ! echo "$EMAIL_ADDRESS" | grep -qE "$EMAIL_REGEX"; then
			printf "\\n${ERR}Please enter a valid email address${CLEARFORMAT}\\n"
		else
			printf "${BOLD}${WARN}Is this correct? (y/n):${CLEARFORMAT}  "
			read -r CONFIRM_INPUT
			case "$CONFIRM_INPUT" in
				y|Y)
					if [ "$1" = "From" ]; then
						sed -i 's/^FROM_ADDRESS=.*$/FROM_ADDRESS="'"$EMAIL_ADDRESS"'"/' "$EMAIL_CONF"
					elif [ "$1" = "To" ]; then
						sed -i 's/^TO_ADDRESS=.*$/TO_ADDRESS="'"$EMAIL_ADDRESS"'"/' "$EMAIL_CONF"
					elif [ "$1" = "Override" ]; then
						NOTIFICATIONS_EMAIL_LIST="$(Email_Recipients check),$EMAIL_ADDRESS"
						NOTIFICATIONS_EMAIL_LIST="$(echo "$NOTIFICATIONS_EMAIL_LIST" | sed 's/,,/,/g;s/,$//;s/^,//')"
						sed -i 's/^NOTIFICATIONS_EMAIL_LIST=.*$/NOTIFICATIONS_EMAIL_LIST='"$NOTIFICATIONS_EMAIL_LIST"'/' "$SCRIPT_CONF"
					fi
					break
				;;
				*)
					:
				;;
			esac
		fi
	done
}

Email_RouterName()
{
	FRIENDLY_ROUTER_NAME=""
	while true
	do
		printf "\\n${BOLD}Enter friendly router name:${CLEARFORMAT}  "
		read -r FRIENDLY_ROUTER_NAME
		if [ "$FRIENDLY_ROUTER_NAME" = "e" ]; then
			FRIENDLY_ROUTER_NAME=""
			break
		elif [ "$(printf "%s" "$FRIENDLY_ROUTER_NAME" | wc -m)" -lt 2 ] || [ "$(printf "%s" "$FRIENDLY_ROUTER_NAME" | wc -m)" -gt 16 ]; then
			printf "\\n${ERR}Router friendly name must be between 2 and 16 characters${CLEARFORMAT}\\n"
		elif echo "$FRIENDLY_ROUTER_NAME" | grep -q "^-" || echo "$FRIENDLY_ROUTER_NAME" | grep -q "^_"; then
			printf "\\n${ERR}Router friendly name must not start with dash (-) or underscore (_)${CLEARFORMAT}\\n"
		elif echo "$FRIENDLY_ROUTER_NAME" | grep -q "[-]$" || echo "$FRIENDLY_ROUTER_NAME" | grep -q "_$"; then
			printf "\\n${ERR}Router friendly name must not end with dash (-) or underscore (_)${CLEARFORMAT}\\n"
		elif ! echo "$FRIENDLY_ROUTER_NAME" | grep -qE "^[a-zA-Z0-9_\-]*$"; then
			printf "\\n${ERR}Router friendly name must not contain special characters other than dash (-) or underscore (_)${CLEARFORMAT}\\n"
		else
			printf "${BOLD}${WARN}Is this correct? (y/n):${CLEARFORMAT}  "
			read -r CONFIRM_INPUT
			case "$CONFIRM_INPUT" in
				y|Y)
					sed -i 's/^FRIENDLY_ROUTER_NAME=.*$/FRIENDLY_ROUTER_NAME="'"$FRIENDLY_ROUTER_NAME"'"/' "$EMAIL_CONF"
					break
				;;
				*)
					:
				;;
			esac
		fi
	done
}

Email_Server(){
	SMTP=""
	while true; do
		printf "\\n${BOLD}Enter SMTP Server:${CLEARFORMAT}  "
		read -r SMTP
		if [ "$SMTP" = "e" ]; then
			SMTP=""
			break
		elif ! Validate_Domain "$SMTP"; then
			printf "\\n${ERR}Domain cannot be resolved by nslookup, please ensure you enter a valid domain name${CLEARFORMAT}\\n"
		else
			printf "${BOLD}${WARN}Is this correct? (y/n):${CLEARFORMAT}  "
			read -r CONFIRM_INPUT
			case "$CONFIRM_INPUT" in
				y|Y)
					sed -i 's/^SMTP=.*$/SMTP="'"$SMTP"'"/' "$EMAIL_CONF"
					break
				;;
				*)
					:
				;;
			esac
		fi
	done
}

Email_Protocol(){
	while true; do
		printf "\\n${BOLD}Please choose the protocol for your email provider:${CLEARFORMAT}\\n"
		printf "    1. smtp\\n"
		printf "    2. smtps\\n\\n"
		printf "Choose an option:  "
		read -r protomenu

		case "$protomenu" in
			1)
				sed -i 's/^PROTOCOL=.*$/PROTOCOL="smtp"/' "$EMAIL_CONF"
				break
			;;
			2)
				sed -i 's/^PROTOCOL=.*$/PROTOCOL="smtps"/' "$EMAIL_CONF"
				break
			;;
			e)
				break
			;;
			*)
				printf "\\n${ERR}Please enter a valid choice (1-2)${CLEARFORMAT}\\n"
			;;
		esac
	done
}

Email_SSL()
{
	SSL_FLAG=""
	while true; do
		printf "\\n${BOLD}Please choose the SSL security level:${CLEARFORMAT}\\n"
		printf "    1. Secure (recommended)\\n"
		printf "    2. Insecure (choose this if you see SSL errors)\\n\\n"
		printf "Choose an option:  "
		read -r protomenu

		case "$protomenu" in
			1)
				sed -i 's/^SSL_FLAG=.*$/SSL_FLAG=""/' "$EMAIL_CONF"
				break
			;;
			2)
				sed -i 's/^SSL_FLAG=.*$/SSL_FLAG="--insecure"/' "$EMAIL_CONF"
				break
			;;
			e)
				SSL_FLAG="e"
				break
			;;
			*)
				printf "\\n${ERR}Please enter a valid choice (1-2)${CLEARFORMAT}\\n"
			;;
		esac
	done
}

Email_Password()
{
	PASSWORD=""
	while true; do
		printf "\\n${BOLD}Enter Password:${CLEARFORMAT}  "
		read -r PASSWORD
		if [ "$PASSWORD" = "e" ]; then
			PASSWORD=""
			break
		else
			printf "${BOLD}${WARN}Is this correct? (y/n):${CLEARFORMAT}  "
			read -r CONFIRM_INPUT
			case "$CONFIRM_INPUT" in
				y|Y)
					Email_Encrypt_Password "$PASSWORD"
					PASSWORD=""
					break
				;;
				*)
					:
				;;
			esac
		fi
	done
}

Email_Encrypt_Password()
{
	PWENCFILE="$EMAIL_DIR/emailpw.enc"
	emailPwEnc="$(grep "emailPwEnc=" "$EMAIL_CONF" | cut -f2 -d"=" | sed 's/""//')"
	if [ -f /usr/sbin/openssl11 ]; then
		printf "$1" | /usr/sbin/openssl11 aes-256-cbc $emailPwEnc -out "$PWENCFILE" -pass pass:ditbabot,isoi
	else
		printf "$1" | /usr/sbin/openssl aes-256-cbc $emailPwEnc -out "$PWENCFILE" -pass pass:ditbabot,isoi
	fi
}

Email_Decrypt_Password()
{
	PWENCFILE="$EMAIL_DIR/emailpw.enc"
	if /usr/sbin/openssl aes-256-cbc -d -in "$PWENCFILE" -pass pass:ditbabot,isoi >/dev/null 2>&1 ; then
		# old OpenSSL 1.0.x
		PASSWORD="$(/usr/sbin/openssl aes-256-cbc -d -in "$PWENCFILE" -pass pass:ditbabot,isoi 2>/dev/null)"
	elif /usr/sbin/openssl aes-256-cbc -d -md md5 -in "$PWENCFILE" -pass pass:ditbabot,isoi >/dev/null 2>&1 ; then
		# new OpenSSL 1.1.x non-converted password
		PASSWORD="$(/usr/sbin/openssl aes-256-cbc -d -md md5 -in "$PWENCFILE" -pass pass:ditbabot,isoi 2>/dev/null)"
	elif /usr/sbin/openssl aes-256-cbc $emailPwEnc -d -in "$PWENCFILE" -pass pass:ditbabot,isoi >/dev/null 2>&1 ; then
		# new OpenSSL 1.1.x converted password with -pbkdf2 flag
		PASSWORD="$(/usr/sbin/openssl aes-256-cbc $emailPwEnc -d -in "$PWENCFILE" -pass pass:ditbabot,isoi 2>/dev/null)"
	fi
	echo "$PASSWORD"
}

Email_Recipients()
{
	case "$1" in
	update)
		while true; do
			ScriptHeader

			printf "${BOLD}${UNDERLINE}Email Recipients Override List${CLEARFORMAT}\\n\\n"
			NOTIFICATIONS_EMAIL_LIST="$(Email_Recipients check)"
			if [ "$NOTIFICATIONS_EMAIL_LIST" = "" ]; then
				NOTIFICATIONS_EMAIL_LIST="Generic To Address will be used"
			fi
			printf "Currently: ${SETTING}${NOTIFICATIONS_EMAIL_LIST}${CLEARFORMAT}\\n\\n"
			printf "Available options:\\n"
			printf "1.    Update list\\n"
			printf "2.    Clear list\\n"
			printf "e.    Go back\\n\\n"
			printf "Choose an option:  "
			read -r emailrecipientmenu
			case "$emailrecipientmenu" in
				1)
					Email_EmailAddress Override
				;;
				2)
					sed -i 's/^NOTIFICATIONS_EMAIL_LIST=.*$/NOTIFICATIONS_EMAIL_LIST=/' "$SCRIPT_CONF"
				;;
				e)
					break
				;;
				*)
					printf "\\n${BOLD}${ERR}Please choose a valid option${CLEARFORMAT}\\n\\n"
					PressEnter
				;;
			esac
		done
	;;
	check)
		NOTIFICATIONS_EMAIL_LIST="$(Conf_Parameters check NOTIFICATIONS_EMAIL_LIST)"
		echo "$NOTIFICATIONS_EMAIL_LIST"
	;;
	esac
}

# encode image for email inline
# $1 : image content id filename (match the cid:filename.png in html document)
# $2 : image content base64 encoded
# $3 : output file
Encode_Image()
{
	{
		echo "";
		echo "--MULTIPART-RELATED-BOUNDARY";
		echo "Content-Type: image/png;name=\"$1\"";
		echo "Content-Transfer-Encoding: base64";
		echo "Content-Disposition: inline;filename=\"$1\"";
		echo "Content-Id: <$1>";
		echo "";
		echo "$2";
	} >> "$3"
}

# encode text for email inline
# $1 : text content base64 encoded
# $2 : output file
Encode_Text()
{
	{
		echo "";
		echo "--MULTIPART-RELATED-BOUNDARY";
		echo "Content-Type: text/plain;name=\"$1\"";
		echo "Content-Transfer-Encoding: quoted-printable";
		echo "Content-Disposition: attachment;filename=\"$1\"";
		echo "";
		echo "$2";
	} >> "$3"
}

SendEmail()
{
	if ! Email_ConfExists; then
		return 1
	else
		EMAILSUBJECT="$1"
		EMAILCONTENTS="$2"
		if [ -n "$3" ]; then
			TO_ADDRESS="$3"
		fi
		if [ -z "$TO_ADDRESS" ]; then
			Print_Output false "No email recipient specified" "$ERR"
			return 1
		fi

		# html message to send #
		{
			echo "From: \"connmon\" <$FROM_ADDRESS>"
			echo "To: \"$TO_ADDRESS\" <$TO_ADDRESS>"
			echo "Subject: $EMAILSUBJECT"
			echo "Date: $(/bin/date -R)"
			echo "MIME-Version: 1.0"
			echo "Content-Type: multipart/mixed; boundary=\"MULTIPART-MIXED-BOUNDARY\""
			echo ""
			echo "--MULTIPART-MIXED-BOUNDARY"
			echo "Content-Type: multipart/related; boundary=\"MULTIPART-RELATED-BOUNDARY\""
			echo ""
			echo "--MULTIPART-RELATED-BOUNDARY"
			echo "Content-Type: multipart/alternative; boundary=\"MULTIPART-ALTERNATIVE-BOUNDARY\""
		} > /tmp/mail.txt

		#echo "<html><body><p><img src=\"cid:connmonlogo.png\"></p>$2" > /tmp/message.html
		echo "<html><body>$EMAILCONTENTS" > /tmp/message.html

		echo "</body></html>" >> /tmp/message.html

		message_base64="$(openssl base64 -A < /tmp/message.html)"
		rm -f /tmp/message.html

		{
			echo ""
			echo "--MULTIPART-ALTERNATIVE-BOUNDARY"
			echo "Content-Type: text/html; charset=utf-8"
			echo "Content-Transfer-Encoding: base64"
			echo ""
			echo "$message_base64"
			echo ""
			echo "--MULTIPART-ALTERNATIVE-BOUNDARY--"
			echo ""
		} >> /tmp/mail.txt

		#image_base64="$(openssl base64 -A < "connmonlogo.png")"
		#Encode_Image "connmonlogo.png" "$image_base64" /tmp/mail.txt

		#Encode_Text vnstat.txt "$(cat "$VNSTAT_OUTPUT_FILE")" /tmp/mail.txt

		{
			echo "--MULTIPART-RELATED-BOUNDARY--"
			echo ""
			echo "--MULTIPART-MIXED-BOUNDARY--"
		} >> /tmp/mail.txt

		PASSWORD="$(Email_Decrypt_Password)"

		curl -s --show-error --url "$PROTOCOL://$SMTP:$PORT" \
		--mail-from "$FROM_ADDRESS" --mail-rcpt "$TO_ADDRESS" \
		--upload-file /tmp/mail.txt \
		--ssl-reqd \
		--user "$USERNAME:$PASSWORD" $SSL_FLAG

		if [ $? -eq 0 ]; then
			echo ""
			Print_Output false "Email sent successfully" "$PASS"
			rm -f /tmp/mail.txt
			PASSWORD=""
			return 0
		else
			echo ""
			Print_Output true "Email failed to send" "$ERR"
			rm -f /tmp/mail.txt
			PASSWORD=""
			return 1
		fi
	fi
}

Webhook_Targets()
{
	case "$1" in
	update)
		while true; do
			ScriptHeader

			printf "${BOLD}${UNDERLINE}Discord Webhook List${CLEARFORMAT}\\n\\n"
			NOTIFICATIONS_WEBHOOK_LIST="$(Webhook_Targets check | sed 's~,~\n~g')"
			printf "Currently: ${SETTING}${NOTIFICATIONS_WEBHOOK_LIST}${CLEARFORMAT}\\n\\n"
			printf "Available options:\\n"
			printf "1.    Update list\\n"
			printf "2.    Clear list\\n"
			printf "e.    Go back\\n\\n"
			printf "Choose an option:  "
			read -r webhooktargetmenu
			case "$webhooktargetmenu" in
				1)
					Notification_String "Webhook Target"
				;;
				2)
					Conf_Parameters clear "Webhook Target"
				;;
				e)
					break
				;;
				*)
					printf "\\n${BOLD}${ERR}Please choose a valid option${CLEARFORMAT}\\n\\n"
					PressEnter
				;;
			esac
		done
	;;
	check)
		NOTIFICATIONS_WEBHOOK_LIST="$(Conf_Parameters check NOTIFICATIONS_WEBHOOK_LIST)"
		echo "$NOTIFICATIONS_WEBHOOK_LIST"
	;;
	esac
}

SendWebhook()
{
	WEBHOOKCONTENT="$1"
	WEBHOOKTARGET="$2"
	if [ -z "$WEBHOOKTARGET" ]; then
		Print_Output false "No Webhook URL specified" "$ERR"
		return 1
	fi

	curl -fsL --retry 4 --retry-delay 5 --output /dev/null -H "Content-Type: application/json" \
-d '{"username":"'"$SCRIPT_NAME"'","content":"'"$WEBHOOKCONTENT"'"}' "$WEBHOOKTARGET"

	if [ $? -eq 0 ]; then
		echo ""
		Print_Output false "Webhook sent successfully" "$PASS"
		return 0
	else
		echo ""
		Print_Output true "Webhook failed to send" "$ERR"
		return 1
	fi
}

Pushover_Devices()
{
	case "$1" in
	update)
		while true; do
			ScriptHeader

			printf "${BOLD}${UNDERLINE}Pushover Device List${CLEARFORMAT}\\n\\n"
			NOTIFICATIONS_PUSHOVER_LIST="$(Pushover_Devices check | sed 's~,~\n~g')"
			printf "Currently: ${SETTING}${NOTIFICATIONS_PUSHOVER_LIST}${CLEARFORMAT}\\n\\n"
			printf "Available options:\\n"
			printf "1.    Update list\\n"
			printf "2.    Clear list\\n"
			printf "e.    Go back\\n\\n"
			printf "Choose an option:  "
			read -r pushoverdevicemenu
			case "$pushoverdevicemenu" in
				1)
					Notification_String "Pushover Device"
				;;
				2)
					Conf_Parameters clear "Pushover Device"
				;;
				e)
					break
				;;
				*)
					printf "\\n${BOLD}${ERR}Please choose a valid option${CLEARFORMAT}\\n\\n"
					PressEnter
				;;
			esac
		done
	;;
	check)
		NOTIFICATIONS_PUSHOVER_LIST="$(Conf_Parameters check NOTIFICATIONS_PUSHOVER_LIST)"
		echo "$NOTIFICATIONS_PUSHOVER_LIST"
	;;
	esac
}

SendPushover()
{
	PUSHOVERCONTENT="$1"
	PUSHOVER_API="$(Conf_Parameters check NOTIFICATIONS_PUSHOVER_API)"
	PUSHOVER_USERKEY="$(Conf_Parameters check NOTIFICATIONS_PUSHOVER_USERKEY)"
	if [ -z "$PUSHOVER_API" ] || [ -z "$PUSHOVER_USERKEY" ]; then
		Print_Output false "No Pushover API or UserKey specified" "$ERR"
		return 1
	fi

	curl -fsL --retry 4 --retry-delay 5 --output /dev/null --form-string "token=$PUSHOVER_API" \
--form-string "user=$PUSHOVER_USERKEY" --form-string "message=$PUSHOVERCONTENT" https://api.pushover.net/1/messages.json

	if [ $? -eq 0 ]; then
		echo ""
		Print_Output false "Pushover sent successfully" "$PASS"
		return 0
	else
		echo ""
		Print_Output true "Pushover failed to send" "$ERR"
		return 1
	fi
}

SendHealthcheckPing()
{
	NOTIFICATIONS_HEALTHCHECK_UUID="$(Conf_Parameters check NOTIFICATIONS_HEALTHCHECK_UUID)"
	TESTFAIL=""
	if [ "$1" = "Fail" ]; then
		TESTFAIL="/fail"
	fi
	curl -fsL --retry 4 --retry-delay 5 --output /dev/null "https://hc-ping.com/${NOTIFICATIONS_HEALTHCHECK_UUID}${TESTFAIL}"
	if [ $? -eq 0 ]; then
		echo ""
		Print_Output false "Healthcheck ping sent successfully" "$PASS"
		return 0
	else
		echo ""
		Print_Output true "Healthcheck ping failed to send" "$ERR"
		return 1
	fi
}

SendToInfluxDB()
{
	TIMESTAMP="$1"
	PING="$2"
	JITTER="$3"
	LINEQUAL="$4"
	NOTIFICATIONS_INFLUXDB_HOST="$(Conf_Parameters check NOTIFICATIONS_INFLUXDB_HOST)"
	NOTIFICATIONS_INFLUXDB_PORT="$(Conf_Parameters check NOTIFICATIONS_INFLUXDB_PORT)"
	NOTIFICATIONS_INFLUXDB_DB="$(Conf_Parameters check NOTIFICATIONS_INFLUXDB_DB)"
	NOTIFICATIONS_INFLUXDB_VERSION="$(Conf_Parameters check NOTIFICATIONS_INFLUXDB_VERSION)"
	NOTIFICATIONS_INFLUXDB_PROTO="http"
	if [ "$NOTIFICATIONS_INFLUXDB_PORT" = "443" ]; then
		NOTIFICATIONS_INFLUXDB_PROTO="https"
	fi

	if [ "$NOTIFICATIONS_INFLUXDB_VERSION" = "1.8" ]; then
		INFLUX_AUTHHEADER="$(Conf_Parameters check NOTIFICATIONS_INFLUXDB_USERNAME):$(Conf_Parameters check NOTIFICATIONS_INFLUXDB_PASSWORD)"
	elif [ "$NOTIFICATIONS_INFLUXDB_VERSION" = "2.0" ]; then
		INFLUX_AUTHHEADER="$(Conf_Parameters check NOTIFICATIONS_INFLUXDB_APITOKEN)"
	fi

	curl -fsL --retry 4 --retry-delay 5 --output /dev/null -XPOST "$NOTIFICATIONS_INFLUXDB_PROTO://$NOTIFICATIONS_INFLUXDB_HOST:$NOTIFICATIONS_INFLUXDB_PORT/api/v2/write?bucket=$NOTIFICATIONS_INFLUXDB_DB&precision=s" \
--header "Authorization: Token $INFLUX_AUTHHEADER" --header "Accept-Encoding: gzip" \
--data-raw "ping value=$PING $TIMESTAMP
jitter value=$JITTER $TIMESTAMP
linequality value=$LINEQUAL $TIMESTAMP"

	if [ $? -eq 0 ]; then
		echo ""
		Print_Output false "Data sent to InfluxDB successfully" "$PASS"
		return 0
	else
		echo ""
		Print_Output true "Data failed to send to InfluxDB" "$ERR"
		return 1
	fi
}

ToggleNotificationTypes()
{
	case "$1" in
		enable)
			sed -i 's/^'"$2"'=.*$/'"$2"'=true/' "$SCRIPT_CONF"
		;;
		disable)
			sed -i 's/^'"$2"'=.*$/'"$2"'=false/' "$SCRIPT_CONF"
		;;
		check)
			NOTIFICATION_SETTING="$(Conf_Parameters check "$2")"
			if [ "$NOTIFICATION_SETTING" = "true" ]; then return 0; else return 1; fi
		;;
	esac
}

Conf_Parameters()
{
	case "$1" in
		update)
			case "$2" in
				"PingThreshold")
					sed -i 's/^NOTIFICATIONS_PINGTHRESHOLD_VALUE=.*$/NOTIFICATIONS_PINGTHRESHOLD_VALUE='"$3"'/' "$SCRIPT_CONF"
				;;
				"JitterThreshold")
					sed -i 's/^NOTIFICATIONS_JITTERTHRESHOLD_VALUE=.*$/NOTIFICATIONS_JITTERTHRESHOLD_VALUE='"$3"'/' "$SCRIPT_CONF"
				;;
				"LineQualityThreshold")
					sed -i 's/^NOTIFICATIONS_LINEQUALITYTHRESHOLD_VALUE=.*$/NOTIFICATIONS_LINEQUALITYTHRESHOLD_VALUE='"$3"'/' "$SCRIPT_CONF"
				;;
				"HealthcheckUUID")
					sed -i 's/^NOTIFICATIONS_HEALTHCHECK_UUID=.*$/NOTIFICATIONS_HEALTHCHECK_UUID='"$3"'/' "$SCRIPT_CONF"
				;;
				"Webhook Target")
					NOTIFICATIONS_WEBHOOK_LIST="$(Webhook_Targets check),$3"
					NOTIFICATIONS_WEBHOOK_LIST="$(echo "$NOTIFICATIONS_WEBHOOK_LIST" | sed 's~,,~,~g;s~,$~~;s~^,~~')"
					sed -i 's~^NOTIFICATIONS_WEBHOOK_LIST=.*$~NOTIFICATIONS_WEBHOOK_LIST='"$NOTIFICATIONS_WEBHOOK_LIST"'~' "$SCRIPT_CONF"
				;;
				"Pushover Device")
					NOTIFICATIONS_PUSHOVER_LIST="$(Pushover_Devices check),$3"
					NOTIFICATIONS_PUSHOVER_LIST="$(echo "$NOTIFICATIONS_PUSHOVER_LIST" | sed 's~,,~,~g;s~,$~~;s~^,~~')"
					sed -i 's~^NOTIFICATIONS_PUSHOVER_LIST=.*$~NOTIFICATIONS_PUSHOVER_LIST='"$NOTIFICATIONS_PUSHOVER_LIST"'~' "$SCRIPT_CONF"
				;;
				"Pushover API Token")
					sed -i 's/^NOTIFICATIONS_PUSHOVER_API=.*$/NOTIFICATIONS_PUSHOVER_API='"$3"'/' "$SCRIPT_CONF"
				;;
				"Pushover User Key")
					sed -i 's/^NOTIFICATIONS_PUSHOVER_USERKEY=.*$/NOTIFICATIONS_PUSHOVER_USERKEY='"$3"'/' "$SCRIPT_CONF"
				;;
				"InfluxDB Host")
					sed -i 's/^NOTIFICATIONS_INFLUXDB_HOST=.*$/NOTIFICATIONS_INFLUXDB_HOST='"$3"'/' "$SCRIPT_CONF"
				;;
				"InfluxDB Port")
					sed -i 's/^NOTIFICATIONS_INFLUXDB_PORT=.*$/NOTIFICATIONS_INFLUXDB_PORT='"$3"'/' "$SCRIPT_CONF"
				;;
				"InfluxDB Database")
					sed -i 's/^NOTIFICATIONS_INFLUXDB_DB=.*$/NOTIFICATIONS_INFLUXDB_DB='"$3"'/' "$SCRIPT_CONF"
				;;
				"InfluxDB Version")
					sed -i 's/^NOTIFICATIONS_INFLUXDB_VERSION=.*$/NOTIFICATIONS_INFLUXDB_VERSION='"$3"'/' "$SCRIPT_CONF"
				;;
				"InfluxDB Username")
					sed -i 's/^NOTIFICATIONS_INFLUXDB_USERNAME=.*$/NOTIFICATIONS_INFLUXDB_USERNAME='"$3"'/' "$SCRIPT_CONF"
				;;
				"InfluxDB Password")
					sed -i 's/^NOTIFICATIONS_INFLUXDB_PASSWORD=.*$/NOTIFICATIONS_INFLUXDB_PASSWORD='"$3"'/' "$SCRIPT_CONF"
				;;
				"InfluxDB API Token")
					sed -i 's/^NOTIFICATIONS_INFLUXDB_APITOKEN=.*$/NOTIFICATIONS_INFLUXDB_APITOKEN='"$3"'/' "$SCRIPT_CONF"
				;;
			esac
		;;
		clear)
			case "$2" in
				"Webhook Target")
					sed -i 's~^NOTIFICATIONS_WEBHOOK_LIST=.*$~NOTIFICATIONS_WEBHOOK_LIST=~' "$SCRIPT_CONF"
				;;
				"Pushover Device")
					sed -i 's~^NOTIFICATIONS_PUSHOVER_LIST=.*$~NOTIFICATIONS_PUSHOVER_LIST=~' "$SCRIPT_CONF"
				;;
			esac
		;;
		check)
			CONFIG_SETTING="$(grep "^${2}=" "$SCRIPT_CONF" | cut -f2 -d'=')"
			echo "$CONFIG_SETTING"
		;;
	esac
}

Validate_Float(){
	if echo "$1" | /bin/grep -oq "^[0-9]*\.\?[0-9]\?[0-9]$"; then
		return 0
	else
		return 1
	fi
}

Notification_String()
{
	NOTIFICATION_STRING=""
	while true
	do
		printf "\\n${BOLD}Enter $1:${CLEARFORMAT}  "
		read -r NOTIFICATION_STRING
		if [ "$NOTIFICATION_STRING" = "e" ]; then
			NOTIFICATION_STRING=""
			break
		else
			printf "${BOLD}${WARN}Is this correct? (y/n):${CLEARFORMAT}  "
			read -r CONFIRM_INPUT
			case "$CONFIRM_INPUT" in
				y|Y)
					if [ "$1" = "To name" ]; then
						sed -i 's/^TO_NAME=.*$/TO_NAME='"$NOTIFICATION_STRING"'/' "$EMAIL_CONF"
					elif [ "$1" = "Username" ]; then
						sed -i 's/^USERNAME=.*$/USERNAME='"$NOTIFICATION_STRING"'/' "$EMAIL_CONF"
					else
						Conf_Parameters update "$1" "$NOTIFICATION_STRING"
					fi
					break
				;;
				*)
					:
				;;
			esac
		fi
	done
}

Notification_Number()
{
	NOTIFICATION_NUMBER=""
	while true; do
		printf "\\n${BOLD}Enter $1:${CLEARFORMAT}  "
		read -r NOTIFICATION_NUMBER
		if [ "$NOTIFICATION_NUMBER" = "e" ]; then
			NOTIFICATION_NUMBER=""
			break
		elif ! Validate_Number "$NOTIFICATION_NUMBER"; then
			printf "\\n${ERR}Please enter a number${CLEARFORMAT}\\n"
		else
			printf "${BOLD}${WARN}Is this correct? (y/n):${CLEARFORMAT}  "
			read -r CONFIRM_INPUT
			case "$CONFIRM_INPUT" in
				y|Y)
					if [ "$1" = "Port" ]; then
						sed -i 's/^PORT=.*$/PORT="'"$NOTIFICATION_NUMBER"'"/' "$EMAIL_CONF"
					else
						Conf_Parameters update "$1" "$NOTIFICATION_NUMBER"
					fi
					break
				;;
				*)
					:
				;;
			esac
		fi
	done
}

Notification_Float()
{
	NOTIFICATION_FLOAT=""
	while true; do
		printf "\\n${BOLD}Enter $1:${CLEARFORMAT}  "
		read -r NOTIFICATION_FLOAT
		if [ "$NOTIFICATION_FLOAT" = "e" ]; then
			NOTIFICATION_FLOAT=""
			break
		elif ! Validate_Float "$NOTIFICATION_FLOAT"; then
			printf "\\n${ERR}Please enter a number${CLEARFORMAT}\\n"
		else
			printf "${BOLD}${WARN}Is this correct? (y/n):${CLEARFORMAT}  "
			read -r CONFIRM_INPUT
			case "$CONFIRM_INPUT" in
				y|Y)
					Conf_Parameters update "$1" "$NOTIFICATION_FLOAT"
					break
				;;
				*)
					:
				;;
			esac
		fi
	done
}

TriggerNotifications()
{
	TRIGGERTYPE="$1"
	DATETIME="$2"
	if [ "$TRIGGERTYPE" = "PingTest" ]; then
		PING="$3"
		JITTER="$4"
		LINEQUAL="$5"
		TIMESTAMP="$6"
	elif [ "$TRIGGERTYPE" = "PingThreshold" ]; then
		PING="$3"
		THRESHOLD="$4"
	elif [ "$TRIGGERTYPE" = "JitterThreshold" ]; then
		JITTER="$3"
		THRESHOLD="$4"
	elif [ "$TRIGGERTYPE" = "LineQualityThreshold" ]; then
		LINEQUAL="$3"
		THRESHOLD="$4"
	fi
	NOTIFICATIONMETHODS="$(NotificationMethods check "$TRIGGERTYPE")"
	IFS=$','
	for NOTIFICATIONMETHOD in $NOTIFICATIONMETHODS
	do
		NOTIFICATIONMETHOD_SETTING="$(echo "NOTIFICATIONS_${NOTIFICATIONMETHOD}" | tr "a-z" "A-Z")"
		if ToggleNotificationTypes check "$NOTIFICATIONMETHOD_SETTING"
		then
			if [ "$NOTIFICATIONMETHOD" = "Email" ]
			then
				NOTIFICATIONS_EMAIL_LIST="$(Email_Recipients check)"
				if [ -z "$NOTIFICATIONS_EMAIL_LIST" ]
				then
					if [ "$TRIGGERTYPE" = "PingTest" ]; then
						SendEmail "Ping test result from $SCRIPT_NAME - $DATETIME" "<p>Ping: $PING<br />Jitter: $JITTER<br />Line Quality: $LINEQUAL</p>"
					elif [ "$TRIGGERTYPE" = "PingThreshold" ]; then
						SendEmail "Ping threshold alert from $SCRIPT_NAME - $DATETIME" "<p>Ping $PING exceeds threshold of $THRESHOLD</p>"
					elif [ "$TRIGGERTYPE" = "JitterThreshold" ]; then
						SendEmail "Jitter threshold alert from $SCRIPT_NAME - $DATETIME" "<p>Jitter $JITTER exceeds threshold of $THRESHOLD</p>"
					elif [ "$TRIGGERTYPE" = "LineQualityThreshold" ]; then
						SendEmail "Line quality threshold alert from $SCRIPT_NAME - $DATETIME" "<p>Line quality $LINEQUAL exceeds threshold of $THRESHOLD</p>"
					fi
				else
					for EMAIL in $NOTIFICATIONS_EMAIL_LIST; do
						if [ "$TRIGGERTYPE" = "PingTest" ]; then
							SendEmail "Ping test result from $SCRIPT_NAME - $DATETIME" "<p>Ping: $PING<br />Jitter: $JITTER<br />Line Quality: $LINEQUAL</p>" "$EMAIL"
						elif [ "$TRIGGERTYPE" = "PingThreshold" ]; then
							SendEmail "Ping threshold alert from $SCRIPT_NAME - $DATETIME" "<p>Ping $PING exceeds threshold of $THRESHOLD</p>" "$EMAIL"
						elif [ "$TRIGGERTYPE" = "JitterThreshold" ]; then
							SendEmail "Jitter threshold alert from $SCRIPT_NAME - $DATETIME" "<p>Jitter $JITTER exceeds threshold of $THRESHOLD</p>" "$EMAIL"
						elif [ "$TRIGGERTYPE" = "LineQualityThreshold" ]; then
							SendEmail "Line quality threshold alert from $SCRIPT_NAME - $DATETIME" "<p>Line quality $LINEQUAL exceeds threshold of $THRESHOLD</p>" "$EMAIL"
						fi
					done
				fi
			elif [ "$NOTIFICATIONMETHOD" = "Webhook" ]; then
				NOTIFICATIONS_WEBHOOK_LIST="$(Webhook_Targets check)"
				for WEBHOOK in $NOTIFICATIONS_WEBHOOK_LIST; do
					if [ "$TRIGGERTYPE" = "PingTest" ]; then
						SendWebhook "Ping test result from $SCRIPT_NAME - $DATETIME\n\nPing: $PING\nJitter: $JITTER\nLine Quality: $LINEQUAL" "$WEBHOOK"
					elif [ "$TRIGGERTYPE" = "PingThreshold" ]; then
						SendWebhook "Ping threshold alert from $SCRIPT_NAME - $DATETIME\n\nPing $PING exceeds threshold of $THRESHOLD" "$WEBHOOK"
					elif [ "$TRIGGERTYPE" = "JitterThreshold" ]; then
						SendWebhook "Jitter threshold alert from $SCRIPT_NAME - $DATETIME\n\nJitter $JITTER exceeds threshold of $THRESHOLD" "$WEBHOOK"
					elif [ "$TRIGGERTYPE" = "LineQualityThreshold" ]; then
						SendWebhook "Line quality threshold alert from $SCRIPT_NAME - $DATETIME\n\nLine quality $LINEQUAL exceeds threshold of $THRESHOLD" "$WEBHOOK"
					fi
				done
			elif [ "$NOTIFICATIONMETHOD" = "Pushover" ]; then
				if [ "$TRIGGERTYPE" = "PingTest" ]; then
					SendPushover "Ping test result from $SCRIPT_NAME - $DATETIME"$'\n'$'\n'"Ping: $PING"$'\n'"Jitter: $JITTER"$'\n'"Line Quality: $LINEQUAL"
				elif [ "$TRIGGERTYPE" = "PingThreshold" ]; then
					SendPushover "Ping threshold alert from $SCRIPT_NAME - $DATETIME"$'\n'$'\n'"Ping $PING exceeds threshold of $THRESHOLD"
				elif [ "$TRIGGERTYPE" = "JitterThreshold" ]; then
					SendPushover "Jitter threshold alert from $SCRIPT_NAME - $DATETIME"$'\n'$'\n'"Jitter $JITTER exceeds threshold of $THRESHOLD"
				elif [ "$TRIGGERTYPE" = "LineQualityThreshold" ]; then
					SendPushover "Line quality threshold alert from $SCRIPT_NAME - $DATETIME"$'\n'$'\n'"Line quality $LINEQUAL exceeds threshold of $THRESHOLD"
				fi
			elif [ "$NOTIFICATIONMETHOD" = "Custom" ]; then
				FILES="$USER_SCRIPT_DIR/*.sh"
				for f in $FILES; do
					if [ -f "$f" ]; then
						Print_Output true "Executing user script: $f"
						if [ "$TRIGGERTYPE" = "PingTest" ]; then
							sh "$f" "$TRIGGERTYPE" "$DATETIME" "$PING" "$JITTER" "$LINEQUAL"
						elif [ "$TRIGGERTYPE" = "PingThreshold" ]; then
							sh "$f" "$TRIGGERTYPE" "$DATETIME" "$PING" "$THRESHOLD"
						elif [ "$TRIGGERTYPE" = "JitterThreshold" ]; then
							sh "$f" "$TRIGGERTYPE" "$DATETIME" "$JITTER" "$THRESHOLD"
						elif [ "$TRIGGERTYPE" = "LineQualityThreshold" ]; then
							sh "$f" "$TRIGGERTYPE" "$DATETIME" "$LINEQUAL" "$THRESHOLD"
						fi
					fi
				done
			fi
		fi
	done
	unset IFS

	if ToggleNotificationTypes check NOTIFICATIONS_HEALTHCHECK && [ "$TRIGGERTYPE" = "PingTest" ]; then
		NOTIFICATIONS_HEALTHCHECK_UUID="$(Conf_Parameters check NOTIFICATIONS_HEALTHCHECK_UUID)"
		TESTFAIL=""
		if [ "$(echo "$LINEQUAL" | cut -f1 -d' ' | cut -f1 -d'.')" -eq 0 ]; then
			SendHealthcheckPing "Fail"
		else
			SendHealthcheckPing "Pass"
		fi
	fi

	if ToggleNotificationTypes check NOTIFICATIONS_INFLUXDB && [ "$TRIGGERTYPE" = "PingTest" ]; then
		SendToInfluxDB "$TIMESTAMP" "$(echo "$PING" | cut -f1 -d' ')" "$(echo "$JITTER" | cut -f1 -d' ')" "$(echo "$LINEQUAL" | cut -f1 -d' ')"
	fi
}

Menu_EmailNotifications()
{
	while true
	do
		Email_ConfExists
		ScriptHeader
		NOTIFICATIONS_EMAIL=""
		if ToggleNotificationTypes check NOTIFICATIONS_EMAIL; then NOTIFICATIONS_EMAIL="${PASS}Enabled"; else NOTIFICATIONS_EMAIL="${ERR}Disabled"; fi
		NOTIFICATIONS_EMAIL_LIST="$(Email_Recipients check)"
		if [ "$NOTIFICATIONS_EMAIL_LIST" = "" ]; then
			NOTIFICATIONS_EMAIL_LIST="Generic To Address will be used"
		fi
		printf "1.    Toggle email notifications (subject to type configuration)\\n      Currently: ${BOLD}${NOTIFICATIONS_EMAIL}${CLEARFORMAT}\\n\\n"
		printf "2.    Set override list of email addresses for %s\\n      Currently: ${SETTING}${NOTIFICATIONS_EMAIL_LIST}${CLEARFORMAT}\\n\\n" "$SCRIPT_NAME"

		printf "\\n${BOLD}${UNDERLINE}Generic Email Configuration${CLEARFORMAT}\\n"
		Email_Header
		printf "c1.    Set From Address          Currently: ${SETTING}%s${CLEARFORMAT}\\n" "$FROM_ADDRESS"
		printf "c2.    Set To Address            Currently: ${SETTING}%s${CLEARFORMAT}\\n" "$TO_ADDRESS"
		printf "c3.    Set To name               Currently: ${SETTING}%s${CLEARFORMAT}\\n" "$TO_NAME"
		printf "c4.    Set Username              Currently: ${SETTING}%s${CLEARFORMAT}\\n" "$USERNAME"
		printf "c5.    Set Password\\n"
		printf "c6.    Set Friendly router name  Currently: ${SETTING}%s${CLEARFORMAT}\\n" "$FRIENDLY_ROUTER_NAME"
		printf "c7.    Set SMTP address          Currently: ${SETTING}%s${CLEARFORMAT}\\n" "$SMTP"
		printf "c8.    Set SMTP port             Currently: ${SETTING}%s${CLEARFORMAT}\\n" "$PORT"
		printf "c9.    Set SMTP protocol         Currently: ${SETTING}%s${CLEARFORMAT}\\n" "$PROTOCOL"
		printf "c10.   Set SSL requirement       Currently: ${SETTING}%s${CLEARFORMAT}\\n\\n" "$SSL_FLAG"
		printf "cs.    Send a test email\\n\\n"
		printf "e.     Go back\\n\\n"
		printf "${BOLD}##############################################################${CLEARFORMAT}\\n"
		printf "\\n"

		printf "Choose an option:  "
		read -r emailmenu
		case "$emailmenu" in
			1)
				if ToggleNotificationTypes check NOTIFICATIONS_EMAIL; then
					ToggleNotificationTypes disable NOTIFICATIONS_EMAIL
				else
					ToggleNotificationTypes enable NOTIFICATIONS_EMAIL
				fi
			;;
			2)
				Email_Recipients update
			;;
			c1)
				Email_EmailAddress From
			;;
			c2)
				Email_EmailAddress To
			;;
			c3)
				Notification_String "To name"
			;;
			c4)
				Notification_String Username
			;;
			c5)
				Email_Password
			;;
			c6)
				Email_RouterName
			;;
			c7)
				Email_Server
			;;
			c8)
				Notification_Number Port
			;;
			c9)
				Email_Protocol
			;;
			c10)
				Email_SSL
			;;
			cs)
				NOTIFICATIONS_EMAIL_LIST="$(Email_Recipients check)"
				if [ -z "$NOTIFICATIONS_EMAIL_LIST" ]; then
					SendEmail "Test email - $(/bin/date +"%c")" "This is a test email!"
				else
					for EMAIL in $NOTIFICATIONS_EMAIL_LIST; do
						SendEmail "Test email - $(/bin/date +"%c")" "This is a test email!" "$EMAIL"
					done
				fi
				printf "\\n"
				PressEnter
			;;
			e)
				break
			;;
			*)
				printf "\\n${BOLD}${ERR}Please choose a valid option${CLEARFORMAT}\\n\\n"
				PressEnter
			;;
		esac
	done
}

Menu_WebhookNotifications(){
	while true; do
		ScriptHeader
		NOTIFICATIONS_WEBHOOK=""
		if ToggleNotificationTypes check NOTIFICATIONS_WEBHOOK; then NOTIFICATIONS_WEBHOOK="${PASS}Enabled"; else NOTIFICATIONS_WEBHOOK="${ERR}Disabled"; fi
		NOTIFICATIONS_WEBHOOK_LIST="$(Webhook_Targets check | sed 's~,~\n~g')"
		printf "1.     Toggle Discord webhook notifications (subject to type configuration)\\n       Currently: ${BOLD}${NOTIFICATIONS_WEBHOOK}${CLEARFORMAT}\\n\\n"
		printf "2.     Set list of Discord webhook URLs for %s\\n       Current webhooks:\\n       ${SETTING}${NOTIFICATIONS_WEBHOOK_LIST}${CLEARFORMAT}\\n\\n" "$SCRIPT_NAME"
		printf "cs.    Send a test webhook notification\\n\\n"
		printf "e.     Go back\\n\\n"
		printf "${BOLD}##############################################################${CLEARFORMAT}\\n"
		printf "\\n"

		printf "Choose an option:  "
		read -r webhookmenu
		case "$webhookmenu" in
			1)
				if ToggleNotificationTypes check NOTIFICATIONS_WEBHOOK; then
					ToggleNotificationTypes disable NOTIFICATIONS_WEBHOOK
				else
					ToggleNotificationTypes enable NOTIFICATIONS_WEBHOOK
				fi
			;;
			2)
				Webhook_Targets update
			;;
			cs)
				NOTIFICATIONS_WEBHOOK_LIST="$(Webhook_Targets check)"
				if [ -z "$NOTIFICATIONS_WEBHOOK_LIST" ]; then
					printf "\\n"
					Print_Output false "No Webhook URL specified" "$ERR"
				fi
				IFS=$','
				for WEBHOOK in $NOTIFICATIONS_WEBHOOK_LIST; do
					SendWebhook "$(/bin/date +"%c")\n\nThis is a test webhook message!" "$WEBHOOK"
				done
				unset IFS
				printf "\\n"
				PressEnter
			;;
			e)
				break
			;;
			*)
				printf "\\n${BOLD}${ERR}Please choose a valid option${CLEARFORMAT}\\n\\n"
				PressEnter
			;;
		esac
	done
}

Menu_PushoverNotifications(){
	while true; do
		ScriptHeader
		NOTIFICATIONS_PUSHOVER=""
		if ToggleNotificationTypes check NOTIFICATIONS_PUSHOVER; then NOTIFICATIONS_PUSHOVER="${PASS}Enabled"; else NOTIFICATIONS_PUSHOVER="${ERR}Disabled"; fi
		NOTIFICATIONS_PUSHOVER_LIST="$(Pushover_Devices check)"
		if [ -z "$NOTIFICATIONS_PUSHOVER_LIST" ]; then
			NOTIFICATIONS_PUSHOVER_LIST="All devices"
		fi
		printf "1.     Toggle Pushover notifications (subject to type configuration)\\n       Currently: ${BOLD}${NOTIFICATIONS_PUSHOVER}${CLEARFORMAT}\\n\\n"
		printf "\\n${BOLD}${UNDERLINE}Pushover Configuration${CLEARFORMAT}\\n"
		printf "c1.    Set API token\\n       Currently: ${SETTING}%s${CLEARFORMAT}\\n\\n" "$(Conf_Parameters check NOTIFICATIONS_PUSHOVER_API)"
		printf "c2.    Set User key\\n       Currently: ${SETTING}%s${CLEARFORMAT}\\n\\n" "$(Conf_Parameters check NOTIFICATIONS_PUSHOVER_USERKEY)"
		printf "c3.    Set list of Pushover devices for %s\\n       Current devices: ${SETTING}${NOTIFICATIONS_PUSHOVER_LIST}${CLEARFORMAT}\\n\\n" "$SCRIPT_NAME"
		printf "cs.    Send a test pushover notification\\n\\n"
		printf "e.     Go back\\n\\n"
		printf "${BOLD}##############################################################${CLEARFORMAT}\\n"
		printf "\\n"

		printf "Choose an option:  "
		read -r pushovermenu
		case "$pushovermenu" in
			1)
				if ToggleNotificationTypes check NOTIFICATIONS_PUSHOVER; then
					ToggleNotificationTypes disable NOTIFICATIONS_PUSHOVER
				else
					ToggleNotificationTypes enable NOTIFICATIONS_PUSHOVER
				fi
			;;
			c1)
				Notification_String "Pushover API Token"
			;;
			c2)
				Notification_String "Pushover User Key"
			;;
			c3)
				Pushover_Devices update
			;;
			cs)
				SendPushover "$(/bin/date +"%c")"$'\n'$'\n'"This is a test pushover message!"
				printf "\\n"
				PressEnter
			;;
			e)
				break
			;;
			*)
				printf "\\n${BOLD}${ERR}Please choose a valid option${CLEARFORMAT}\\n\\n"
				PressEnter
			;;
		esac
	done
}

CustomAction_Info(){
	if [ -z "$1" ]; then
		printf "\\n${BOLD}${UNDERLINE}Scripts are passed arguments, which change depending on the type of trigger${CLEARFORMAT}\\n\\n"
		printf "${BOLD}${UNDERLINE}Trigger                 Argument1            Argument2         Argument3   Argument4           Argument5${CLEARFORMAT}\\n"
		printf "${BOLD}Tests${CLEARFORMAT}"'                   PingTest             FormattedDateTime "Ping ms"   "Jitter ms"         "Latency %%"'"\\n"
		printf "${BOLD}Ping thresholds${CLEARFORMAT}"'         PingThreshold        FormattedDateTime "Ping ms"   "ThresholdValue ms"'"\\n"
		printf "${BOLD}Jitter thresholds${CLEARFORMAT}"'       JitterThreshold      FormattedDateTime "Jitter ms" "ThresholdValue ms"'"\\n"
		printf "${BOLD}Line Quality thresholds${CLEARFORMAT}"' LineQualityThreshold FormattedDateTime "Latency %%" "ThresholdValue %%"'"\\n\\n"
		printf "A great example of a custom script would be to leverage the Apprise library ${BOLD}https://github.com/caronc/apprise${CLEARFORMAT}\\n"
		printf "This library provides easy integration with many notification schemes. See ${BOLD}https://github.com/caronc/apprise#popular-notification-services${CLEARFORMAT}\\n"
		printf "You can install apprise on your router by running:\\n\\n"
		printf "${BOLD}opkg install python3 python3-pip && /opt/bin/python3 -m pip install --upgrade pip${CLEARFORMAT}\\n\\n"
		printf "Apprise can then be leveraged at the command line as shown here: ${BOLD}https://github.com/caronc/apprise#command-line${CLEARFORMAT}\\n\\n"
		printf "e.     Go back\\n\\n"
		printf "${BOLD}##############################################################${CLEARFORMAT}\\n"
		printf "\\n"
	fi

	{
		printf "Scripts are passed arguments, which change depending on the type of trigger\\n\\n"
		printf "Trigger                 Argument1            Argument2         Argument3   Argument4           Argument5\\n"
		printf "Tests"'                   PingTest             FormattedDateTime "Ping ms"   "Jitter ms"         "Latency %%"'"\\n"
		printf "Ping thresholds"'         PingThreshold        FormattedDateTime "Ping ms"   "ThresholdValue ms"'"\\n"
		printf "Jitter thresholds"'       JitterThreshold      FormattedDateTime "Jitter ms" "ThresholdValue ms"'"\\n"
		printf "Line Quality thresholds"' LineQualityThreshold FormattedDateTime "Latency %%" "ThresholdValue %%"'"\\n\\n"
		printf "A great example of a custom script would be to leverage the Apprise library https://github.com/caronc/apprise\\n"
		printf "This library provides easy integration with many notification schemes. See https://github.com/caronc/apprise#popular-notification-services\\n"
		printf "You can install apprise on your router by running:\\n\\n"
		printf "opkg install python3 python3-pip && /opt/bin/python3 -m pip install --upgrade pip\\n\\n"
		printf "Apprise can then be leveraged at the command line as shown here: https://github.com/caronc/apprise#command-line\\n\\n"
	} > "$SCRIPT_STORAGE_DIR/.customactioninfo"
}

CustomAction_List(){
	if [ -z "$1" ]; then
		FILES="$USER_SCRIPT_DIR/*.sh"
		for f in $FILES; do
			if [ -f "$f" ]; then
				printf "${SETTING}%s${CLEARFORMAT}\\n" "$f"
			fi
		done
	fi
	printf "Scripts that will be run:\\n" > "$SCRIPT_STORAGE_DIR/.customactionlist"
	FILES="$USER_SCRIPT_DIR/*.sh"
	for f in $FILES; do
		if [ -f "$f" ]; then
			printf "%s\\n" "$f" >> "$SCRIPT_STORAGE_DIR/.customactionlist"
		fi
	done
}

Menu_CustomActions(){
	while true; do
		ScriptHeader
		NOTIFICATIONS_CUSTOM=""
		if ToggleNotificationTypes check NOTIFICATIONS_CUSTOM; then NOTIFICATIONS_CUSTOM="${PASS}Enabled"; else NOTIFICATIONS_CUSTOM="${ERR}Disabled"; fi
		printf "1.    Toggle custom actions and scripts (subject to type configuration)\\n      Currently: ${BOLD}${NOTIFICATIONS_CUSTOM}${CLEARFORMAT}\\n\\n"
		printf "Scripts that will be run:\\n"

		if [ -z "$(ls -A "$USER_SCRIPT_DIR")" ]; then
			printf "${SETTING}No scripts found in ${USER_SCRIPT_DIR}${CLEARFORMAT}\\n"
		else
			CustomAction_List
		fi

		CustomAction_Info

		printf "Choose an option:  "
		read -r custommenu
		case "$custommenu" in
			1)
				if ToggleNotificationTypes check NOTIFICATIONS_CUSTOM; then
					ToggleNotificationTypes disable NOTIFICATIONS_CUSTOM
				else
					ToggleNotificationTypes enable NOTIFICATIONS_CUSTOM
				fi
			;;
			cs)
				if [ -z "$(ls -A "$USER_SCRIPT_DIR")" ]; then
					printf "\\n${SETTING}No scripts found in ${USER_SCRIPT_DIR}${CLEARFORMAT}\\n\\n"
					PressEnter
				else
					printf "\\n"
					FILES="$USER_SCRIPT_DIR/*.sh"
					for f in $FILES; do
						if [ -f "$f" ]; then
							Print_Output false "Executing user script: $f"
							sh "$f" "$(/bin/date +%c)" "30 ms" "15 ms" "90%"
						fi
					done
					PressEnter
				fi
			;;
			e)
				break
			;;
			*)
				printf "\\n${BOLD}${ERR}Please choose a valid option${CLEARFORMAT}\\n\\n"
				PressEnter
			;;
		esac
	done
}

Menu_HealthcheckNotifications(){
	while true; do
		ScriptHeader
		NOTIFICATIONS_HEALTHCHECK=""
		if ToggleNotificationTypes check NOTIFICATIONS_HEALTHCHECK; then NOTIFICATIONS_HEALTHCHECK="${PASS}Enabled"; else NOTIFICATIONS_HEALTHCHECK="${ERR}Disabled"; fi
		printf "1.    Toggle healthchecks.io\\n      Currently: ${BOLD}${NOTIFICATIONS_HEALTHCHECK}${CLEARFORMAT}\\n\\n"
		printf "\\n${BOLD}${UNDERLINE}Healthcheck Configuration${CLEARFORMAT}\\n\\n"
		printf "c1.    Set Healthcheck UUID\\n       Currently: ${SETTING}%s${CLEARFORMAT}\\n\\n" "$(Conf_Parameters check NOTIFICATIONS_HEALTHCHECK_UUID)"
		printf "Cron schedule for Healthchecks.io configuration: ${SETTING}%s${CLEARFORMAT}\\n\\n" "$(cru l | grep "$SCRIPT_NAME" | cut -f1-5 -d' ')"
		printf "cs.    Send a test healthcheck notification\\n\\n"
		printf "e.     Go back\\n\\n"
		printf "${BOLD}##############################################################${CLEARFORMAT}\\n"
		printf "\\n"

		printf "Choose an option:  "
		read -r healthcheckmenu
		case "$healthcheckmenu" in
			1)
				if ToggleNotificationTypes check NOTIFICATIONS_HEALTHCHECK; then
					ToggleNotificationTypes disable NOTIFICATIONS_HEALTHCHECK
				else
					ToggleNotificationTypes enable NOTIFICATIONS_HEALTHCHECK
				fi
			;;
			c1)
				Notification_String HealthcheckUUID
			;;
			cs)
				SendHealthcheckPing "Pass"
				printf "\\n"
				PressEnter
			;;
			e)
				break
			;;
			*)
				printf "\\n${BOLD}${ERR}Please choose a valid option${CLEARFORMAT}\\n\\n"
				PressEnter
			;;
		esac
	done
}

Menu_InfluxDB(){
	while true; do
		ScriptHeader
		NOTIFICATIONS_INFLUXDB=""
		if ToggleNotificationTypes check NOTIFICATIONS_INFLUXDB; then NOTIFICATIONS_INFLUXDB="${PASS}Enabled"; else NOTIFICATIONS_INFLUXDB="${ERR}Disabled"; fi
		printf "1.    Toggle InfluxDB exporting\\n      Currently: ${BOLD}${NOTIFICATIONS_INFLUXDB}${CLEARFORMAT}\\n\\n"
		printf "\\n${BOLD}${UNDERLINE}InfluxDB Configuration${CLEARFORMAT}\\n\\n"
		printf "c1.    Set InfluxDB Host\\n       Currently: ${SETTING}%s${CLEARFORMAT}\\n\\n" "$(Conf_Parameters check NOTIFICATIONS_INFLUXDB_HOST)"
		printf "c2.    Set InfluxDB Port\\n       Currently: ${SETTING}%s${CLEARFORMAT}\\n\\n" "$(Conf_Parameters check NOTIFICATIONS_INFLUXDB_PORT)"
		printf "c3.    Set InfluxDB Database\\n       Currently: ${SETTING}%s${CLEARFORMAT}\\n\\n" "$(Conf_Parameters check NOTIFICATIONS_INFLUXDB_DB)"
		printf "c4.    Set InfluxDB Version\\n       Currently: ${SETTING}%s${CLEARFORMAT}\\n\\n" "$(Conf_Parameters check NOTIFICATIONS_INFLUXDB_VERSION)"
		printf "c5.    Set InfluxDB Username (v1.8+ only)\\n       Currently: ${SETTING}%s${CLEARFORMAT}\\n\\n" "$(Conf_Parameters check NOTIFICATIONS_INFLUXDB_USERNAME)"
		printf "c6.    Set InfluxDB Password (v1.8+ only)\\n\\n"
		printf "c7.    Set InfluxDB API Token (v2.x only)\\n       Currently: ${SETTING}%s${CLEARFORMAT}\\n\\n" "$(Conf_Parameters check NOTIFICATIONS_INFLUXDB_APITOKEN)"
		printf "cs.    Send test data to InfluxDB\\n\\n"
		printf "e.     Go back\\n\\n"
		printf "${BOLD}##############################################################${CLEARFORMAT}\\n"
		printf "\\n"

		printf "Choose an option:  "
		read -r healthcheckmenu
		case "$healthcheckmenu" in
			1)
				if ToggleNotificationTypes check NOTIFICATIONS_INFLUXDB; then
					ToggleNotificationTypes disable NOTIFICATIONS_INFLUXDB
				else
					ToggleNotificationTypes enable NOTIFICATIONS_INFLUXDB
				fi
			;;
			c1)
				Notification_String "InfluxDB Host"
			;;
			c2)
				Notification_Number "InfluxDB Port"
			;;
			c3)
				Notification_String "InfluxDB Database"
			;;
			c4)
				if [ "$(Conf_Parameters check NOTIFICATIONS_INFLUXDB_VERSION)" = "1.8" ]; then
					Conf_Parameters update "InfluxDB Version" "2.0"
				else
					Conf_Parameters update "InfluxDB Version" "1.8"
				fi
			;;
			c5)
				Notification_String "InfluxDB Username"
			;;
			c6)
				Notification_String "InfluxDB Password"
			;;
			c7)
				Notification_String "InfluxDB API Token"
			;;
			cs)
				SendToInfluxDB "$(/bin/date +%s)" 30 15 90
				printf "\\n"
				PressEnter
			;;
			e)
				break
			;;
			*)
				printf "\\n${BOLD}${ERR}Please choose a valid option${CLEARFORMAT}\\n\\n"
				PressEnter
			;;
		esac
	done
}

Menu_Notifications()
{
	while true
	do
		ScriptHeader
		printf "${BOLD}${UNDERLINE}Notification Types${CLEARFORMAT}\\n"
		printf "1.     Ping test\\n       Current methods: ${SETTING}$(NotificationMethods check PingTest)${CLEARFORMAT}\\n\\n"
		printf "2.     Ping threshold (values above this will trigger an alert)\\n       Current threshold: ${SETTING}$(Conf_Parameters check NOTIFICATIONS_PINGTHRESHOLD_VALUE) ms${CLEARFORMAT}\\n       Current methods: ${SETTING}$(NotificationMethods check PingThreshold)${CLEARFORMAT}\\n\\n"
		printf "3.     Jitter threshold (values above this will trigger an alert)\\n       Current threshold: ${SETTING}$(Conf_Parameters check NOTIFICATIONS_JITTERTHRESHOLD_VALUE) ms${CLEARFORMAT}\\n       Current methods: ${SETTING}$(NotificationMethods check JitterThreshold)${CLEARFORMAT}\\n\\n"
		printf "4.     Line Quality threshold (values below this will trigger an alert)\\n       Current threshold: ${SETTING}$(Conf_Parameters check NOTIFICATIONS_LINEQUALITYTHRESHOLD_VALUE) %%${CLEARFORMAT}\\n       Current methods: ${SETTING}$(NotificationMethods check LineQualityThreshold)${CLEARFORMAT}\\n\\n"
		printf "\\n${BOLD}${UNDERLINE}Notification Methods and Integrations${CLEARFORMAT}\\n"
		NOTIFICATION_SETTING=""
		if ToggleNotificationTypes check NOTIFICATIONS_EMAIL; then NOTIFICATION_SETTING="${PASS}Enabled"; else NOTIFICATION_SETTING="${ERR}Disabled"; fi
		printf "em.    Email (shared with other addons/scripts e.g. Diversion)\\n       Currently: ${BOLD}${NOTIFICATION_SETTING}${CLEARFORMAT}\\n\\n"
		if ToggleNotificationTypes check NOTIFICATIONS_WEBHOOK; then NOTIFICATION_SETTING="${PASS}Enabled"; else NOTIFICATION_SETTING="${ERR}Disabled"; fi
		printf "wb.    Discord webhook\\n       Currently: ${BOLD}${NOTIFICATION_SETTING}${CLEARFORMAT}\\n\\n"
		if ToggleNotificationTypes check NOTIFICATIONS_PUSHOVER; then NOTIFICATION_SETTING="${PASS}Enabled"; else NOTIFICATION_SETTING="${ERR}Disabled"; fi
		printf "po.    Pushover\\n       Currently: ${BOLD}${NOTIFICATION_SETTING}${CLEARFORMAT}\\n\\n"
		if ToggleNotificationTypes check NOTIFICATIONS_CUSTOM; then NOTIFICATION_SETTING="${PASS}Enabled"; else NOTIFICATION_SETTING="${ERR}Disabled"; fi
		printf "ca.    Custom actions and scripts\\n       Currently: ${BOLD}${NOTIFICATION_SETTING}${CLEARFORMAT}\\n\\n"
		if ToggleNotificationTypes check NOTIFICATIONS_HEALTHCHECK; then NOTIFICATION_SETTING="${PASS}Enabled"; else NOTIFICATION_SETTING="${ERR}Disabled"; fi
		printf "hc.    Healthchecks.io\\n       Currently: ${BOLD}${NOTIFICATION_SETTING}${CLEARFORMAT}\\n\\n"
		if ToggleNotificationTypes check NOTIFICATIONS_INFLUXDB; then NOTIFICATION_SETTING="${PASS}Enabled"; else NOTIFICATION_SETTING="${ERR}Disabled"; fi
		printf "id.    InfluxDB exporting\\n       Currently: ${BOLD}${NOTIFICATION_SETTING}${CLEARFORMAT}\\n\\n"
		printf "e.     Go back\\n\\n"
		printf "${BOLD}##############################################################${CLEARFORMAT}\\n"
		printf "\\n"

		printf "Choose an option:  "
		read -r notificationsmenu
		case "$notificationsmenu" in
			1)
				NotificationMethods update PingTest
			;;
			2)
				NotificationMethods update PingThreshold
			;;
			3)
				NotificationMethods update JitterThreshold
			;;
			4)
				NotificationMethods update LineQualityThreshold
			;;
			em)
				Menu_EmailNotifications
			;;
			wb)
				Menu_WebhookNotifications
			;;
			po)
				Menu_PushoverNotifications
			;;
			ca)
				Menu_CustomActions
			;;
			hc)
				Menu_HealthcheckNotifications
			;;
			id)
				Menu_InfluxDB
			;;
			e)
				break
			;;
			*)
				printf "\\n${BOLD}${ERR}Please choose a valid option${CLEARFORMAT}\\n\\n"
				PressEnter
			;;
		esac
	done
}

NotificationMethods()
{
	case "$1" in
		update)
			while true; do
				ScriptHeader
				printf "${BOLD}${UNDERLINE}${2}${CLEARFORMAT}\\n\\n"
				if [ "$2" = "PingThreshold" ] || [ "$2" = "JitterThreshold" ] || [ "$2" = "LineQualityThreshold" ]; then
					case "$2" in
						PingThreshold)
							PARAMETERNAME="NOTIFICATIONS_PINGTHRESHOLD_VALUE"
							UNIT="ms"
						;;
						JitterThreshold)
							PARAMETERNAME="NOTIFICATIONS_JITTERTHRESHOLD_VALUE"
							UNIT="ms"
						;;
						LineQualityThreshold)
							PARAMETERNAME="NOTIFICATIONS_LINEQUALITYTHRESHOLD_VALUE"
							UNIT="%%"
						;;
					esac
					printf "c1.    Set threshold value - Currently: ${SETTING}$(Conf_Parameters check "$PARAMETERNAME") $UNIT${CLEARFORMAT}\\n\\n"
				fi
				printf "Please choose the notification methods to enable\\n"
				printf "${BOLD}Currently enabled: ${SETTING}%s${CLEARFORMAT}\\n\\n" "$(NotificationMethods check "$2")"
				printf "1.     Email\\n"
				printf "2.     Webhook\\n"
				printf "3.     Pushover\\n"
				printf "4.     Custom\\n"
				printf "5.     None\\n\\n"
				printf "e.     Go back\\n\\n"
				printf "Choose an option:  "
				SETTINGNAME=""
				SETTINGVALUE=""
				read -r methodsmenu
				case "$methodsmenu" in
					1)
						SETTINGVALUE="Email"
					;;
					2)
						SETTINGVALUE="Webhook"
					;;
					3)
						SETTINGVALUE="Pushover"
					;;
					4)
						SETTINGVALUE="Custom"
					;;
					5)
						SETTINGVALUE="None"
					;;
					c1)
						Notification_Float "$2"
					;;
					e)
						break
					;;
					*)
						printf "\\n${BOLD}${ERR}Please choose a valid option${CLEARFORMAT}\\n\\n"
						PressEnter
					;;
				esac
				if [ "$methodsmenu" != "e" ] && [ "$methodsmenu" != "c1" ]; then
					case "$2" in
						PingTest)
							SETTINGNAME="NOTIFICATIONS_PINGTEST"
						;;
						PingThreshold)
							SETTINGNAME="NOTIFICATIONS_PINGTHRESHOLD"
						;;
						JitterThreshold)
							SETTINGNAME="NOTIFICATIONS_JITTERTHRESHOLD"
						;;
						LineQualityThreshold)
							SETTINGNAME="NOTIFICATIONS_LINEQUALITYTHRESHOLD"
						;;
					esac
					NOTIFICATION_SETTING="$(Conf_Parameters check "$SETTINGNAME")"
					if [ "$SETTINGVALUE" = "None" ]; then
						sed -i 's/^'"$SETTINGNAME"'=.*$/'"$SETTINGNAME"'=None/' "$SCRIPT_CONF"
					else
						if echo "$NOTIFICATION_SETTING" | grep -q "$SETTINGVALUE"; then
							NOTIFICATION_SETTING="$(echo "$NOTIFICATION_SETTING" | sed 's/'"$SETTINGVALUE"'//g;s/,,/,/g;s/,$//;s/^,//')"
							sed -i 's/^'"$SETTINGNAME"'=.*$/'"$SETTINGNAME"'='"$NOTIFICATION_SETTING"'/' "$SCRIPT_CONF"
						else
							NOTIFICATION_SETTING="$(echo "$SETTINGVALUE,$NOTIFICATION_SETTING" | sed 's/None//g;s/,,/,/g;s/,$//;s/^,//')"
							sed -i 's/^'"$SETTINGNAME"'=.*$/'"$SETTINGNAME"'='"$NOTIFICATION_SETTING"'/' "$SCRIPT_CONF"
						fi
						NOTIFICATION_SETTING="$(Conf_Parameters check "$SETTINGNAME")"
						if [ -z "$NOTIFICATION_SETTING" ]; then
							sed -i 's/^'"$SETTINGNAME"'=.*$/'"$SETTINGNAME"'=None/' "$SCRIPT_CONF"
						fi
					fi
				fi
			done
		;;
		check)
			case "$2" in
				PingTest)
					NOTIFICATION_SETTING="$(Conf_Parameters check NOTIFICATIONS_PINGTEST)"
					echo "$NOTIFICATION_SETTING"
				;;
				PingThreshold)
					NOTIFICATION_SETTING="$(Conf_Parameters check NOTIFICATIONS_PINGTHRESHOLD)"
					echo "$NOTIFICATION_SETTING"
				;;
				JitterThreshold)
					NOTIFICATION_SETTING="$(Conf_Parameters check NOTIFICATIONS_JITTERTHRESHOLD)"
					echo "$NOTIFICATION_SETTING"
				;;
				LineQualityThreshold)
					NOTIFICATION_SETTING="$(Conf_Parameters check NOTIFICATIONS_LINEQUALITYTHRESHOLD)"
					echo "$NOTIFICATION_SETTING"
				;;
			esac
		;;
	esac
}

ScriptHeader()
{
	clear
	printf "\\n"
	printf "${BOLD}##############################################################${CLEARFORMAT}\\n"
	printf "${BOLD}##     ___   ___   _ __   _ __   _ __ ___    ___   _ __     ##${CLEARFORMAT}\\n"
	printf "${BOLD}##    / __| / _ \ | '_ \ | '_ \ | '_   _ \  / _ \ | '_ \    ##${CLEARFORMAT}\\n"
	printf "${BOLD}##   | (__ | (_) || | | || | | || | | | | || (_) || | | |   ##${CLEARFORMAT}\\n"
	printf "${BOLD}##    \___| \___/ |_| |_||_| |_||_| |_| |_| \___/ |_| |_|   ##${CLEARFORMAT}\\n"
	printf "${BOLD}##                                                          ##${CLEARFORMAT}\\n"
	printf "${BOLD}##                   %s on %-18s           ##${CLEARFORMAT}\n" "$SCRIPT_VERSION" "$ROUTER_MODEL"
	printf "${BOLD}##                                                          ##${CLEARFORMAT}\\n"
	printf "${BOLD}##            https://github.com/jackyaz/connmon            ##${CLEARFORMAT}\\n"
	printf "${BOLD}##                                                          ##${CLEARFORMAT}\\n"
	printf "${BOLD}##############################################################${CLEARFORMAT}\\n"
	printf "\\n"
}

##-------------------------------------##
## Added by Martinski W. [2024-Nov-23] ##
##-------------------------------------##
_CronScheduleHourMinsInfo_()
{
   if [ $# -lt 2 ] || [ -z "$1" ] || [ -z "$2" ]
   then echo ; return 1 ; fi
   local schedHour="$1"  schedMins="$2"  schedInfoStr
   local freqHourNum  freqMinsNum  hasFreqHour  hasFreqMins

   _IsValidNumber_()
   {
      if echo "$1" | grep -qE "^[0-9]+$"
      then return 0 ; else return 1 ; fi
   }

   _Get12HourAmPm_()
   {
      if [ $# -eq 0 ] || [ -z "$1" ]
      then echo ; return 1 ; fi
      local theHour  theMins=""  ampmTag="AM"
      theHour="$1"
      if [ $# -eq 2 ] && [ -n "$2" ]
      then theMins="$2"
      fi
      if [ "$theHour" -eq 0 ]
      then theHour=12
      elif [ "$theHour" -eq 12 ]
      then ampmTag="PM"
      elif [ "$theHour" -gt 12 ]
      then
          ampmTag="PM" ; theHour="$((theHour - 12))"
      fi
      if [ -z "$theMins" ]
      then printf "%d $ampmTag" "$theHour"
      else printf "%d:%02d $ampmTag" "$theHour" "$theMins"
      fi
   }

   if echo "$schedHour" | grep -qE "^[*]/.*"
   then
       hasFreqHour=true
       freqHourNum="$(echo "$schedHour" | cut -f2 -d'/')"
   else
       hasFreqHour=false ; freqHourNum=""
   fi
   if echo "$schedMins" | grep -qE "^[*]/.*"
   then
       hasFreqMins=true
       freqMinsNum="$(echo "$schedMins" | cut -f2 -d'/')"
   else
       hasFreqMins=false ; freqMinsNum=""
   fi
   if [ "$schedHour" = "*" ] && [ "$schedMins" = "0" ]
   then
       schedInfoStr="Every hour"
   elif [ "$schedHour" = "*" ] && [ "$schedMins" = "*" ]
   then
       schedInfoStr="Every minute"
   elif [ "$schedHour" = "*" ] && _IsValidNumber_ "$schedMins"
   then
       schedInfoStr="Every hour at minute $schedMins"
   elif "$hasFreqHour" && [ "$schedMins" = "0" ]
   then
       schedInfoStr="Every $freqHourNum hours"
   elif "$hasFreqHour" && [ "$schedMins" = "*" ]
   then
       schedInfoStr="Every minute, every $freqHourNum hours"
   elif "$hasFreqHour" && _IsValidNumber_ "$schedMins"
   then
       schedInfoStr="Every $freqHourNum hours at minute $schedMins"
   elif "$hasFreqMins" && [ "$schedHour" = "*" ]
   then
       schedInfoStr="Every $freqMinsNum minutes"
   elif "$hasFreqHour" && "$hasFreqMins"
   then
       schedInfoStr="Every $freqMinsNum minutes, every $freqHourNum hours"
   elif "$hasFreqMins" && _IsValidNumber_ "$schedHour"
   then
       schedInfoStr="Hour: $(_Get12HourAmPm_ "$schedHour"), every $freqMinsNum minutes"
   elif _IsValidNumber_ "$schedHour" && _IsValidNumber_ "$schedMins"
   then
       schedInfoStr="Hour: $(_Get12HourAmPm_ "$schedHour" "$schedMins")"
   elif "$hasFreqHour"
   then
       schedInfoStr="Every $freqHourNum hours, Minutes: $schedMins"
   elif "$hasFreqMins"
   then
       schedInfoStr="Hours: ${schedHour}; every $freqMinsNum minutes"
   elif [ "$schedHour" = "*" ]
   then
       schedInfoStr="Every hour, Minutes: $schedMins"
   elif [ "$schedMins" = "*" ]
   then
       schedInfoStr="Hours: ${schedHour}; every minute"
   else
       schedInfoStr="Hours: ${schedHour}; Minutes: $schedMins"
   fi
   echo "$schedInfoStr"
}

##----------------------------------------##
## Modified by Martinski W. [2025-Jan-04] ##
##----------------------------------------##
MainMenu()
{
	local menuOption  STORAGE_MenuStr  automaticModeStatus

	if [ "$(ExcludeFromQoS check)" = "true" ]
	then EXCLUDEFROMQOS_MENU="excluded from"
	else EXCLUDEFROMQOS_MENU="included in"
	fi

	if AutomaticMode check
	then automaticModeStatus="${GRNct}ENABLED${CLEARct}"
	else automaticModeStatus="${CRIT} DISABLED ${CLEARct}"
	fi

	TEST_SCHEDULE="$(CronTestSchedule check)"
	CRON_SCHED_DAYS="$(echo "$TEST_SCHEDULE" | cut -f1 -d'|')"
	CRON_SCHED_HOUR="$(echo "$TEST_SCHEDULE" | cut -f2 -d'|')"
	CRON_SCHED_MINS="$(echo "$TEST_SCHEDULE" | cut -f3 -d'|')"
	if [ "$CRON_SCHED_DAYS" = "*" ]
	then TEST_SCHEDULE_DAYS="Every day"
	else TEST_SCHEDULE_DAYS="Days of Week: $CRON_SCHED_DAYS"
	fi
	TEST_SCHEDULE_MENU="$(_CronScheduleHourMinsInfo_ "$CRON_SCHED_HOUR" "$CRON_SCHED_MINS")"

	STORAGE_MenuStr="$(ScriptStorageLocation check | tr 'a-z' 'A-Z')"

	printf "WebUI for %s is available at:\n${SETTING}%s${CLEARFORMAT}\n\n" "$SCRIPT_NAME" "$(Get_WebUI_URL)"
	printf "1.    Check connection now\n"
    printf "      Database size: ${SETTING}%s${CLEARFORMAT}\n\n" "$(_GetFileSize_ "$CONNSTATS_DB" HRx)"
	printf "2.    Set preferred ping server\n"
    printf "      Currently: ${SETTING}%s${CLEARFORMAT}\n\n" "$(PingServer check)"
	printf "3.    Set ping test duration\n"
	printf "      Currently: ${SETTING}%s sec.${CLEARFORMAT}\n\n" "$(PingDuration check)"
	printf "4.    Toggle automatic ping tests\n"
	printf "      Currently: ${automaticModeStatus}${CLEARFORMAT}\n\n"
	printf "5.    Set schedule for automatic ping tests\n"
	printf "      Currently: ${SETTING}%s - %s${CLEARFORMAT}\n\n" "$TEST_SCHEDULE_MENU" "$TEST_SCHEDULE_DAYS"
	printf "6.    Toggle time output mode\n"
	printf "      Currently: ${SETTING}%s${CLEARFORMAT} time values will be used for CSV exports\n\n" "$(OutputTimeMode check)"
	printf "7.    Set number of ping test results to show in WebUI\n"
	printf "      Currently: ${SETTING}%s results will be shown${CLEARFORMAT}\n\n" "$(LastXResults check)"
	printf "8.    Set number of days data to keep in database\n"
	printf "      Currently: ${SETTING}%s days data will be kept${CLEARFORMAT}\n\n" "$(DaysToKeep check)"
	printf "s.    Toggle storage location for stats and config\n"
	printf "      Current location: ${SETTING}%s${CLEARFORMAT}\n" "$STORAGE_MenuStr"
    printf "      JFFS Available: ${SETTING}%s${CLEARFORMAT}\n\n" "$(_Get_JFFS_Space_ FREE HRx)"
	printf "q.    Toggle exclusion of %s ping tests from QoS\n" "$SCRIPT_NAME"
	printf "      Currently: %s ping tests are ${SETTING}%s${CLEARFORMAT} QoS\n\n" "$SCRIPT_NAME" "$EXCLUDEFROMQOS_MENU"
	printf "n.    Configure notifications and integrations for %s\n\n" "$SCRIPT_NAME"
	printf "u.    Check for updates\n"
	printf "uf.   Update %s with latest version (force update)\n\n" "$SCRIPT_NAME"
	printf "cl.   View changelog for %s (use q to exit)\n\n" "$SCRIPT_NAME"
	printf "r.    Reset %s database / delete all data\n\n" "$SCRIPT_NAME"
	printf "e.    Exit %s\n\n" "$SCRIPT_NAME"
	printf "z.    Uninstall %s\n" "$SCRIPT_NAME"
	printf "\n"
	printf "${BOLD}##############################################################${CLEARFORMAT}\n"
	printf "\n"

	while true
	do
		printf "Choose an option:  "
		read -r menuOption
		case "$menuOption" in
			1)
				printf "\n"
				if Check_Lock menu
				then
					Run_PingTest
					Clear_Lock
				fi
				PressEnter
				break
			;;
			2)
				printf "\n"
				PingServer update
				break
			;;
			3)
				printf "\n"
				PingDuration update && PressEnter
				break
			;;
			4)
				printf "\n"
				if Check_Lock menu
				then
				    if AutomaticMode check
				    then AutomaticMode disable
				    else AutomaticMode enable
				    fi
				    Clear_Lock
				    PressEnter
				fi
				break
			;;
			5)
				printf "\n"
				Menu_EditSchedule
				PressEnter
				break
			;;
			6)
				printf "\n"
				if [ "$(OutputTimeMode check)" = "unix" ]; then
					OutputTimeMode non-unix
				elif [ "$(OutputTimeMode check)" = "non-unix" ]; then
					OutputTimeMode unix
				fi
				break
			;;
			7)
				printf "\n"
				LastXResults update && PressEnter
				break
			;;
			8)
				printf "\n"
				DaysToKeep update && PressEnter
				break
			;;
			s)
				printf "\n"
				if Check_Lock menu
				then
					if [ "$(ScriptStorageLocation check)" = "jffs" ]
					then
					    ScriptStorageLocation usb
					elif [ "$(ScriptStorageLocation check)" = "usb" ]
					then
					    if ! _Check_JFFS_SpaceAvailable_ "$SCRIPT_STORAGE_DIR"
					    then
					        Clear_Lock
					        PressEnter
					        break
					    fi
					    ScriptStorageLocation jffs
					fi
					Create_Symlinks
					Clear_Lock
				fi
				break
			;;
			q)
				printf "\n"
				if [ "$(ExcludeFromQoS check)" = "true" ]; then
					ExcludeFromQoS disable
				elif [ "$(ExcludeFromQoS check)" = "false" ]; then
					ExcludeFromQoS enable
				fi
				break
			;;
			n)
				printf "\n"
				Menu_Notifications
				break
			;;
			u)
				printf "\n"
				if Check_Lock menu; then
					Update_Version
					Clear_Lock
				fi
				PressEnter
				break
			;;
			uf)
				printf "\n"
				if Check_Lock menu; then
					Update_Version force
					Clear_Lock
				fi
				PressEnter
				break
			;;
			cl)
				less "$SCRIPT_DIR/CHANGELOG.md"
				break
			;;
			r)
				printf "\n"
				if Check_Lock menu; then
					Menu_ResetDB
					Clear_Lock
				fi
				PressEnter
				break
			;;
			e)
				ScriptHeader
				printf "\n${BOLD}Thanks for using %s!${CLEARFORMAT}\n\n\n" "$SCRIPT_NAME"
				exit 0
			;;
			z)
				while true
				do
					printf "\n${BOLD}Are you sure you want to uninstall %s? (y/n)${CLEARFORMAT}  " "$SCRIPT_NAME"
					read -r confirm
					case "$confirm" in
						y|Y)
							Menu_Uninstall
							exit 0
						;;
						*)
							break
						;;
					esac
				done
			;;
			*)
				[ -n "$menuOption" ] && \
				printf "\n${REDct}INVALID input [$menuOption]${CLEARFORMAT}"
				printf "\nPlease choose a valid option.\n\n"
				PressEnter
				break
			;;
		esac
	done

	ScriptHeader
	MainMenu
}

Check_Requirements()
{
	CHECKSFAILED="false"

	if [ "$(nvram get jffs2_scripts)" -ne 1 ]
	then
		nvram set jffs2_scripts=1
		nvram commit
		Print_Output true "Custom JFFS Scripts enabled" "$WARN"
	fi

	if [ ! -f /opt/bin/opkg ]
	then
		Print_Output true "Entware NOT detected!" "$CRIT"
		CHECKSFAILED="true"
	fi

	if ! Firmware_Version_Check
	then
		Print_Output true "Unsupported firmware version detected" "$CRIT"
		Print_Output true "$SCRIPT_NAME requires Merlin 384.15/384.13_4 or Fork 43E5 (or later)" "$ERR"
		CHECKSFAILED="true"
	fi

	if [ "$CHECKSFAILED" = "false" ]
	then
		Print_Output true "Installing required packages from Entware" "$PASS"
		opkg update
		opkg install sqlite3-cli
		opkg install findutils
		opkg install bind-dig
		return 0
	else
		return 1
	fi
}

##----------------------------------------##
## Modified by Martinski W. [2025-Jan-29] ##
##----------------------------------------##
Menu_Install()
{
	ScriptHeader
	Print_Output true "Welcome to $SCRIPT_NAME $SCRIPT_VERSION, a script by JackYaz" "$PASS"
	sleep 1

	Print_Output true "Checking if your router meets the requirements for $SCRIPT_NAME" "$PASS"

	if ! Check_Requirements
    then
		Print_Output true "Requirements for $SCRIPT_NAME not met, please see above for the reason(s)" "$CRIT"
		PressEnter
		Clear_Lock
		rm -f "/jffs/scripts/$SCRIPT_NAME" 2>/dev/null
		exit 1
	fi

	Create_Dirs
	Conf_Exists
	Set_Version_Custom_Settings local "$SCRIPT_VERSION"
	Set_Version_Custom_Settings server "$SCRIPT_VERSION"
	ScriptStorageLocation load true
	Create_Symlinks

	Update_File CHANGELOG.md
	Update_File README.md
	Update_File connmonstats_www.asp
	Update_File shared-jy.tar.gz

	Auto_Startup create 2>/dev/null
	Auto_Cron delete 2>/dev/null
	AutomaticMode check && Auto_Cron create 2>/dev/null
	Auto_ServiceEvent create 2>/dev/null
	Shortcut_Script create

	{
	   echo "PRAGMA temp_store=1;"
	   echo "PRAGMA journal_mode=TRUNCATE;"
	   echo "CREATE TABLE IF NOT EXISTS [connstats] ([StatID] INTEGER PRIMARY KEY NOT NULL,[Timestamp] NUMERIC NOT NULL,[Ping] REAL NOT NULL,[Jitter] REAL NOT NULL,[LineQuality] REAL NOT NULL,[PingTarget] TEXT NOT NULL,[PingDuration] NUMERIC);" 
	} > /tmp/connmon-stats.sql
	_ApplyDatabaseSQLCmds_ /tmp/connmon-stats.sql ins1
	rm -f /tmp/connmon-stats.sql

	touch "$SCRIPT_STORAGE_DIR/.newcolumns"
	touch "$SCRIPT_STORAGE_DIR/lastx.csv"
	Process_Upgrade

	Run_PingTest

	Clear_Lock

	Download_File "$SCRIPT_REPO/install-success/LICENSE" "$SCRIPT_DIR/LICENSE"

	ScriptHeader
	MainMenu
}

##----------------------------------------##
## Modified by Martinski W. [2024-Dec-21] ##
##----------------------------------------##
Menu_Startup()
{
	if [ $# -eq 0 ] || [ -z "$1" ]
	then
		Print_Output true "Missing argument for startup, not starting $SCRIPT_NAME" "$ERR"
		exit 1
	elif [ "$1" != "force" ]
	then
		if [ ! -x "${1}/entware/bin/opkg" ]
		then
			Print_Output true "$1 does NOT contain Entware, not starting $SCRIPT_NAME" "$CRIT"
			exit 1
		else
			Print_Output true "$1 contains Entware, starting $SCRIPT_NAME" "$PASS"
		fi
	fi

	NTP_Ready
	Check_Lock

	if [ "$1" != "force" ]; then
		sleep 6
	fi

	Create_Dirs
	Conf_Exists
	ScriptStorageLocation load true
	Create_Symlinks
	Auto_Startup create 2>/dev/null
	if AutomaticMode check
	then Auto_Cron create 2>/dev/null
	else Auto_Cron delete 2>/dev/null
	fi
	Auto_ServiceEvent create 2>/dev/null
	Shortcut_Script create
	Mount_WebUI
	Clear_Lock
}

##-------------------------------------##
## Added by Martinski W. [2024-Dec-21] ##
##-------------------------------------##
_ValidateCronDAYSofWEEK_()
{
    if [ $# -eq 0 ] || [ -z "$1" ] ; then return 1 ; fi

    local cruDaysOK  cruDaysTmp1  cruDaysTmp2  tmpDay1  tmpDay2

    [ "$1" = "*" ] && return 0

    _DayOfWeekNameToDayNum_()
    { echo "$1" | sed 's/Sun/0/;s/Mon/1/;s/Tues/2/;s/Wed/3/;s/Thurs/4/;s/Fri/5/;s/Sat/6/;s/Tue/2/;s/Thu/4/;' ; }

    cruDaysOK=true
    cruDaysTmp1="$(_DayOfWeekNameToDayNum_ "$1")"
    cruDaysTmp1="$(echo "$cruDaysTmp1" | sed 's/,/ /g')"

    for tmpDay1 in $cruDaysTmp1
    do
        if echo "$tmpDay1" | grep -q '-'
        then
            if [ "$tmpDay1" = "-" ]
            then
                cruDaysOK=false
                printf "\n${ERR}Please enter a valid number between 0 and 6${CLEARFORMAT}\n"
                break
            fi
            cruDaysTmp2="$(echo "$tmpDay1" | sed 's/-/ /')"
            for tmpDay2 in $cruDaysTmp2
            do
                if ! echo "$tmpDay2" | grep -qE "^[0-6]$" || \
                   [ "$tmpDay2" -lt 0 ] || [ "$tmpDay2" -gt 6 ]
                then
                    cruDaysOK=false
                    printf "\n${ERR}Please enter valid numbers between 0 and 6${CLEARFORMAT}\n"
                    break
                fi
            done
            "$cruDaysOK" && continue || break
        elif ! echo "$tmpDay1" | grep -qE "^[0-6]$" || \
             [ "$tmpDay1" -lt 0 ] || [ "$tmpDay1" -gt 6 ]
        then
            cruDaysOK=false
            printf "\n${ERR}Please enter a valid number between 0 and 6, or comma-separated numbers${CLEARFORMAT}\n"
            break
        fi
   done

   "$cruDaysOK" && return 0 || return 1
}

##-------------------------------------##
## Added by Martinski W. [2024-Dec-21] ##
##-------------------------------------##
_ValidateCronFreqHOURS_()
{
    local cruHoursOK=true  isVerbose=true

    if [ $# -eq 0 ] || [ -z "$1" ]
    then return 1
    fi
    if [ $# -gt 1 ] && [ "$2" = "-quiet" ]
    then isVerbose=false
    fi
    if ! echo "$1" | grep -qE "^[1-9][0-9]?$" || \
       [ "$1" -lt 1 ] || [ "$1" -gt 24 ]
    then
        cruHoursOK=false
        "$isVerbose" && \
        printf "\n${ERR}Please enter a valid number between 1 and 24${CLEARFORMAT}\n"
    fi
    "$cruHoursOK" && return 0 || return 1
}

##-------------------------------------##
## Added by Martinski W. [2024-Dec-21] ##
##-------------------------------------##
_ValidateCronFreqMINS_()
{
    local cruMinsOK=true  isVerbose=true

    if [ $# -eq 0 ] || [ -z "$1" ]
    then return 1
    fi
    if [ $# -gt 1 ] && [ "$2" = "-quiet" ]
    then isVerbose=false
    fi
    if ! echo "$1" | grep -qE "^[1-9][0-9]?$" || \
       [ "$1" -lt 1 ] || [ "$1" -gt 30 ]
    then
        cruMinsOK=false
        "$isVerbose" && \
        printf "\n${ERR}Please enter a valid number between 1 and 30${CLEARFORMAT}\n"
    fi
    "$cruMinsOK" && return 0 || return 1
}

##-------------------------------------##
## Added by Martinski W. [2024-Dec-21] ##
##-------------------------------------##
_ValidateCronHOURS_()
{
    local cruHoursOK  cruHoursTmp1  cruHoursTmp2  cruHoursTmp3
    local tmpHour1  tmpHour2  isVerbose=true

    if [ $# -eq 0 ] || [ -z "$1" ]
    then return 1
    fi
    if [ $# -gt 1 ] && [ "$2" = "-quiet" ]
    then isVerbose=false
    fi
    [ "$1" = "*" ] && return 0

    cruHoursOK=true
    cruHoursTmp1="$(echo "$1" | sed 's/,/ /g')"

    for tmpHour1 in $cruHoursTmp1
    do
        if echo "$tmpHour1" | grep -q "-"
        then
            if [ "$tmpHour1" = "-" ]
            then
                cruHoursOK=false
                "$isVerbose" && \
                printf "\n${ERR}Please enter a valid number between 0 and 23${CLEARFORMAT}\n"
                break
            fi
            cruHoursTmp2="$(echo "$tmpHour1" | sed 's/-/ /')"
            for tmpHour2 in $cruHoursTmp2
            do
                if ! echo "$tmpHour2" | grep -qE "^(0|[1-9][0-9]?)$" || \
                   [ "$tmpHour2" -lt 0 ] || [ "$tmpHour2" -gt 23 ]
                then
                    cruHoursOK=false
                    "$isVerbose" && \
                    printf "\n${ERR}Please enter valid numbers between 0 and 23${CLEARFORMAT}\n"
                    break
                fi
            done
            "$cruHoursOK" && continue || break
        elif echo "$tmpHour1" | grep -q "[*]/.*"
        then
            cruHoursTmp3="$(echo "$tmpHour1" | sed 's/\*\///')"
            if ! echo "$cruHoursTmp3" | grep -qE "^[1-9][0-9]?$" || \
               [ "$cruHoursTmp3" -lt 2 ] || [ "$cruHoursTmp3" -gt 23 ]
            then
                cruHoursOK=false
                "$isVerbose" && \
                printf "\n${ERR}Please enter a valid frequency number between 2 and 23${CLEARFORMAT}\n"
                break
            fi
        elif ! echo "$tmpHour1" | grep -qE "^(0|[1-9][0-9]?)$" || \
             [ "$tmpHour1" -lt 0 ] || [ "$tmpHour1" -gt 23 ]
        then
            cruHoursOK=false
            "$isVerbose" && \
            printf "\n${ERR}Please enter a valid number between 0 and 23, or comma-separated numbers${CLEARFORMAT}\n"
            break
        fi
    done

    "$cruHoursOK" && return 0 || return 1
}

##-------------------------------------##
## Added by Martinski W. [2024-Dec-21] ##
##-------------------------------------##
_ValidateCronMINS_()
{
    local cruMinsOK  cruMinsTmp1  cruMinsTmp2  cruMinsTmp3
    local tmpMins1  tmpMins2  isVerbose=true

    if [ $# -eq 0 ] || [ -z "$1" ]
    then return 1
    fi
    if [ $# -gt 1 ] && [ "$2" = "-quiet" ]
    then isVerbose=false
    fi
    [ "$1" = "*" ] && return 0

    cruMinsOK=true
    cruMinsTmp1="$(echo "$1" | sed 's/,/ /g')"

    for tmpMins1 in $cruMinsTmp1
    do
        if echo "$tmpMins1" | grep -q "-"
        then
            if [ "$tmpMins1" = "-" ]
            then
                cruMinsOK=false
                "$isVerbose" && \
                printf "\n${ERR}Please enter a valid number between 0 and 59${CLEARFORMAT}\n"
                break
            fi
            cruMinsTmp2="$(echo "$tmpMins1" | sed 's/-/ /')"
            for tmpMins2 in $cruMinsTmp2
            do
                if ! echo "$tmpMins2" | grep -qE "^(0|[1-9][0-9]?)$" || \
                   [ "$tmpMins2" -lt 0 ] || [ "$tmpMins2" -gt 59 ]
                then
                    cruMinsOK=false
                    "$isVerbose" && \
                    printf "\n${ERR}Please enter valid numbers between 0 and 59${CLEARFORMAT}\n"
                    break
                fi
            done
            "$cruMinsOK" && continue || break
        elif echo "$tmpMins1" | grep -q "[*]/.*"
        then
            cruMinsTmp3="$(echo "$tmpMins1" | sed 's/\*\///')"
            if ! echo "$cruMinsTmp3" | grep -qE "^[1-9][0-9]?$" || \
               [ "$cruMinsTmp3" -lt 2 ] || [ "$cruMinsTmp3" -gt 30 ]
            then
                cruMinsOK=false
                "$isVerbose" && \
                printf "\n${ERR}Please enter a valid frequency number between 2 and 30${CLEARFORMAT}\n"
                break
            fi
        elif ! echo "$tmpMins1" | grep -qE "^(0|[1-9][0-9]?)$" || \
             [ "$tmpMins1" -lt 0 ] || [ "$tmpMins1" -gt 59 ]
        then
            cruMinsOK=false
            "$isVerbose" && \
            printf "\n${ERR}Please enter a valid number between 0 and 59, or comma-separated numbers${CLEARFORMAT}\n"
            break
        fi
    done

    "$cruMinsOK" && return 0 || return 1
}

##----------------------------------------##
## Modified by Martinski W. [2024-Dec-22] ##
##----------------------------------------##
Menu_EditSchedule()
{
	local exitMenu  testScheduleStr
	local cruDays  cruHour  cruMins  formatType
	local cruHoursStr  cruHoursTmp  cruMinsStr  cruMinsTmp

	_DayOfWeekNumToDayName_()
	{ echo "$1" | sed 's/0/Sun/;s/1/Mon/;s/2/Tue/;s/3/Wed/;s/4/Thu/;s/5/Fri/;s/6/Sat/;' ; }

	_GetSchedDaysHR_()
	{
	    local cruSchedDays="$1"
	    if [ "$1" = "*" ]
	    then cruSchedDays="Every day"
	    elif ! echo "$1" | grep -qE "^[*]/.*"
	    then cruSchedDays="$(_DayOfWeekNumToDayName_ "$1")" 
	    fi
	    echo "$cruSchedDays"
	}

	_GetScheduleHR_()
	{ echo "$(_CronScheduleHourMinsInfo_ "$1" "$2") - $(_GetSchedDaysHR_ "$3")" ; }

	_ValidateHoursRange_()
	{
		local cruHour1st  cruHour2nd  cruHourTmp
		cruHour1st="$(echo "$1" | cut -f1 -d'-')"
		cruHour2nd="$(echo "$1" | cut -f2 -d'-')"
		if [ "$cruHour1st" -eq "$cruHour2nd" ]
		then cruHourTmp="$cruHour1st"
		elif [ "$cruHour1st" -lt "$cruHour2nd" ]
		then cruHourTmp="$1"
		elif [ "$cruHour1st" -gt "$cruHour2nd" ]
		then cruHourTmp="0-${cruHour2nd},${cruHour1st}-23"
		fi
		echo "$cruHourTmp"
	}

	_ValidateMinsRange_()
	{
		local cruMins1st  cruMins2nd  cruMinsTmp
		cruMins1st="$(echo "$1" | cut -f1 -d'-')"
		cruMins2nd="$(echo "$1" | cut -f2 -d'-')"
		if [ "$cruMins1st" -eq "$cruMins2nd" ]
		then cruMinsTmp="$cruMins1st"
		elif [ "$cruMins1st" -lt "$cruMins2nd" ]
		then cruMinsTmp="$1"
		elif [ "$cruMins1st" -gt "$cruMins2nd" ]
		then cruMinsTmp="0-${cruMins2nd},${cruMins1st}-59"
		fi
		echo "$cruMinsTmp"
	}

	testScheduleStr="$(CronTestSchedule check)"
	cruDays="$(echo "$testScheduleStr" | cut -f1 -d'|')"
	cruHour="$(echo "$testScheduleStr" | cut -f2 -d'|')"
	cruMins="$(echo "$testScheduleStr" | cut -f3 -d'|')"
	exitMenu=false ; formatType=""

	## DAYS of the WEEK ##
	while true
	do
		ScriptHeader
		printf "${BOLD}Current schedule: ${GRNct}$(_GetScheduleHR_ "$cruHour" "$cruMins" "$cruDays")${CLEARct}\n"
		printf "\n${BOLD}Please enter the DAYS of the week when to run the ping tests.\n"
        printf "[${GRNct}0-6${CLEARct}], ${GRNct}0${CLEARct}=Sunday, ${GRNct}6${CLEARct}=Saturday, ${GRNct}*${CLEARct}=Every day, or comma-separated days.${CLEARFORMAT}"
        printf "\n\n${BOLD}Enter DAYS of the week (${GRNct}e${CLEARct}=Exit)${CLEARFORMAT}:  "
		read -r day_choice

		if [ "$day_choice" = "e" ]
		then
			exitMenu=true ; break
		elif [ -z "$day_choice" ]
		then
			if _ValidateCronDAYSofWEEK_ "$cruDays"
			then echo ; break ; fi
			PressEnter
		else
			if _ValidateCronDAYSofWEEK_ "$day_choice"
			then cruDays="$day_choice" ; echo ; break ; fi
			PressEnter
		fi
	done

	## FORMAT: "Custom" or "EveryX" ##
	if [ "$exitMenu" = "false" ]
	then
		while true
		do
			ScriptHeader
			printf "${BOLD}Please choose the method to specify the hour/minute(s)\nto run the ping tests:${CLEARFORMAT}\n\n"
			printf "    1. Every X hours/minutes\n"
			printf "    2. Custom\n"
			printf "    e. Exit to Main Menu\n\n"
			printf "Choose an option:  "
			read -r formatChoice

			case "$formatChoice" in
				1) formatType="everyx" ; echo ; break ;;
				2) formatType="custom" ; echo ; break ;;
				e) exitMenu=true ; break ;;
				*) printf "\n${ERR}Please enter a valid choice [1-2]${CLEARFORMAT}\n"
				   PressEnter ;;
			esac
		done
	fi

	if [ "$exitMenu" = "false" ]
	then
		if [ "$formatType" = "everyx" ]
		then
			while true
			do
				ScriptHeader
				printf "${BOLD}Please choose whether to specify every X hours or every X minutes\nto run the ping tests:${CLEARFORMAT}\n\n"
				printf "    1. Hours\n"
				printf "    2. Minutes\n"
				printf "    e. Exit to Main Menu\n\n"
				printf "Choose an option:  "
				read -r formatChoice

				case "$formatChoice" in
					1) formatType="hours" ; echo ; break ;;
					2) formatType="mins" ; echo ; break ;;
					e) exitMenu=true ; break ;;
					*) printf "\n${ERR}Please enter a valid choice [1-2]${CLEARFORMAT}\n"
					   PressEnter ;;
				esac
			done
		fi
	fi

	if [ "$exitMenu" = "false" ]
	then
		## EVERY X HOURS ##
		if [ "$formatType" = "hours" ]
		then
			while true
			do
				ScriptHeader
				printf "${BOLD}Current schedule: ${GRNct}$(_GetScheduleHR_ "$cruHour" "$cruMins" "$cruDays")${CLEARct}\n"
				printf "\n${BOLD}Please enter how often in HOURS to run the ping tests.\n"
				printf "Every X hours, where X is ${GRNct}1-24${CLEARct}, (${GRNct}e${CLEARct}=Exit)${CLEARFORMAT}:  "
				read -r hour_choice

				if [ "$hour_choice" = "e" ]
				then
					exitMenu=true ; break
				elif [ -z "$hour_choice" ]
				then
					if _ValidateCronHOURS_ "$cruHour" -quiet || \
					   _ValidateCronFreqHOURS_ "$cruHour" -quiet
					then echo ; break ; fi
					printf "\n${ERR}Please enter a number between 1 and 24${CLEARFORMAT}\n"
					PressEnter
				elif ! _ValidateCronFreqHOURS_ "$hour_choice"
				then
				    PressEnter
				elif [ "$hour_choice" -eq 24 ]
				then
					cruHour=0
					cruMins=0
					echo ; break
				elif [ "$hour_choice" -eq 1 ]
				then
					cruHour="*"
					cruMins=0
					echo ; break
				else
					cruHour="*/$hour_choice"
					cruMins=0
					echo ; break
				fi
			done

		## EVERY X MINUTES ##
		elif [ "$formatType" = "mins" ]
		then
			while true
			do
				ScriptHeader
				printf "${BOLD}Current schedule: ${GRNct}$(_GetScheduleHR_ "$cruHour" "$cruMins" "$cruDays")${CLEARct}\n"
				printf "\n${BOLD}Please enter how often in MINUTES to run the ping tests.\n"
				printf "Every X minutes, where X is ${GRNct}1-30${CLEARct}, (${GRNct}e${CLEARct}=Exit)${CLEARFORMAT}:  "
				read -r mins_choice

				if [ "$mins_choice" = "e" ]
				then
					exitMenu=true ; break
				elif [ -z "$mins_choice" ]
				then
					if _ValidateCronMINS_ "$cruMins" -quiet || \
					   _ValidateCronFreqMINS_ "$cruMins" -quiet
					then echo ; break ; fi
					printf "\n${ERR}Please enter a number between 1 and 30${CLEARFORMAT}\n"
					PressEnter
				elif ! _ValidateCronFreqMINS_ "$mins_choice"
				then
					PressEnter
				elif [ "$mins_choice" -eq 1 ]
				then
					cruMins="*"
					cruHour="*"
					echo ; break
				else
					cruMins="*/$mins_choice"
					cruHour="*"
					echo ; break
				fi
			done
		fi
	fi

	if [ "$exitMenu" = "false" ]
	then
		if [ "$formatType" = "custom" ]
		then
			## CUSTOM HOURS ##
			while true
			do
				ScriptHeader
				printf "${BOLD}Current schedule: ${GRNct}$(_GetScheduleHR_ "$cruHour" "$cruMins" "$cruDays")${CLEARct}\n"
				printf "\n${BOLD}Please enter the HOURS when to run the ping tests.\n"
				printf "[${GRNct}0-23${CLEARct}], ${GRNct}*${CLEARct}=Every hour, or comma-separated hours, (${GRNct}e${CLEARct}=Exit)${CLEARFORMAT}:  "
				read -r hour_choice

				if [ "$hour_choice" = "e" ]
				then
					exitMenu=true ; break
				elif [ -z "$hour_choice" ]
				then
					if _ValidateCronHOURS_ "$cruHour" -quiet || \
					   _ValidateCronFreqHOURS_ "$cruHour" -quiet
					then echo ; break ; fi
					printf "\n${ERR}Please enter a number between 0 and 23${CLEARFORMAT}\n"
					PressEnter
				else
					if _ValidateCronHOURS_ "$hour_choice"
					then
						if echo "$hour_choice" | grep -q "-"
						then
							if echo "$hour_choice" | grep -q ","
							then
								cruHour=""
								cruHoursStr="$(echo "$hour_choice" | sed 's/,/ /g')"
								for tmpHours in $cruHoursStr 
								do
								    if echo "$tmpHours" | grep -q "-"
								    then
								        cruHoursTmp="$(_ValidateHoursRange_ "$tmpHours")"
								        if [ -z "$cruHour" ]
								        then cruHour="$cruHoursTmp"
								        else cruHour="${cruHour},${cruHoursTmp}"
								        fi
								    else
								        if [ -z "$cruHour" ]
								        then cruHour="$tmpHours"
								        else cruHour="${cruHour},${tmpHours}"
								        fi
								    fi
								done
							else
								cruHour="$(_ValidateHoursRange_ "$hour_choice")"
							fi
						elif [ "$hour_choice" = "*/1" ]
						then
							cruHour="*"
						else
							cruHour="$hour_choice"
						fi
						echo ; break
					fi
					PressEnter
				fi
			done
		fi
	fi

	if [ "$exitMenu" = "false" ]
	then
		if [ "$formatType" = "custom" ]
		then
			## CUSTOM MINUTES ##
			while true
			do
				ScriptHeader
				printf "${BOLD}Current schedule: ${GRNct}$(_GetScheduleHR_ "$cruHour" "$cruMins" "$cruDays")${CLEARct}\n"
				printf "\n${BOLD}Please enter the MINUTES when to run the ping tests.\n"
				printf "[${GRNct}0-59${CLEARct}], ${GRNct}*${CLEARct}=Every minute, or comma-separated minutes, (${GRNct}e${CLEARct}=Exit)${CLEARFORMAT}:  "
				read -r mins_choice

				if [ "$mins_choice" = "e" ]
				then
					exitMenu=true ; break
				elif [ -z "$mins_choice" ]
				then
					if _ValidateCronMINS_ "$cruMins" -quiet || \
					   _ValidateCronFreqMINS_ "$cruMins" -quiet
					then echo ; break ; fi
					printf "\n${ERR}Please enter a number between 0 and 59${CLEARFORMAT}\n"
					PressEnter
				else
					if _ValidateCronMINS_ "$mins_choice"
					then
						if echo "$mins_choice" | grep -q "-"
						then
							if echo "$mins_choice" | grep -q ","
							then
								cruMins=""
								cruMinsStr="$(echo "$mins_choice" | sed 's/,/ /g')"
								for tmpMins in $cruMinsStr 
								do
								    if echo "$tmpMins" | grep -q "-"
								    then
								        cruMinsTmp="$(_ValidateMinsRange_ "$tmpMins")"
								        if [ -z "$cruMins" ]
								        then cruMins="$cruMinsTmp"
								        else cruMins="${cruMins},${cruMinsTmp}"
								        fi
								    else
								        if [ -z "$cruMins" ]
								        then cruMins="$tmpMins"
								        else cruMins="${cruMins},${tmpMins}"
								        fi
								    fi
								done
							else
								cruMins="$(_ValidateMinsRange_ "$mins_choice")"
							fi
						elif [ "$mins_choice" = "*/1" ]
						then
							cruMins="*"
						else
							cruMins="$mins_choice"
						fi
						echo ; break
					fi
					PressEnter
				fi
			done
		fi
	fi

	if [ "$exitMenu" = "false" ]
	then
		CronTestSchedule update "$cruDays" "$cruHour" "$cruMins"
		return 0
	else
		echo ; return 1
	fi
}

Menu_ResetDB()
{
	printf "${BOLD}\\e[33mWARNING: This will reset the %s database by deleting all database records.\\n" "$SCRIPT_NAME"
	printf "A backup of the database will be created if you change your mind.${CLEARFORMAT}\\n"
	printf "\\n${BOLD}Do you want to continue? (y/n)${CLEARFORMAT}  "
	read -r confirm
	case "$confirm" in
		y|Y)
			printf "\\n"
			Reset_DB
		;;
		*)
			printf "\\n${BOLD}\\e[33mDatabase reset cancelled${CLEARFORMAT}\\n\\n"
		;;
	esac
}

##----------------------------------------##
## Modified by Martinski W. [2024-Nov-23] ##
##----------------------------------------##
Menu_Uninstall()
{
	if [ -n "$PPID" ]
	then
		ps | grep -v grep | grep -v $$ | grep -v "$PPID" | grep -i "$SCRIPT_NAME" | grep generate | awk '{print $1}' | xargs kill -9 >/dev/null 2>&1
	else
		ps | grep -v grep | grep -v $$ | grep -i "$SCRIPT_NAME" | grep generate | awk '{print $1}' | xargs kill -9 >/dev/null 2>&1
	fi
	if [ -n "$PPID" ]
	then
		ps | grep -v grep | grep -v $$ | grep -v "$PPID" | grep -i "$SCRIPT_NAME" | grep trimdb | awk '{print $1}' | xargs kill -9 >/dev/null 2>&1
	else
		ps | grep -v grep | grep -v $$ | grep -i "$SCRIPT_NAME" | grep trimdb | awk '{print $1}' | xargs kill -9 >/dev/null 2>&1
	fi
	Print_Output true "Removing $SCRIPT_NAME..." "$PASS"
	Auto_Startup delete 2>/dev/null
	Auto_Cron delete 2>/dev/null
	Auto_ServiceEvent delete 2>/dev/null
	Shortcut_Script delete

	LOCKFILE=/tmp/addonwebui.lock
	FD=386
	eval exec "$FD>$LOCKFILE"
	flock -x "$FD"
	Get_WebUI_Page "$SCRIPT_DIR/connmonstats_www.asp"
	if [ -n "$MyPage" ] && [ "$MyPage" != "none" ] && [ -f /tmp/menuTree.js ]; then
		sed -i "\\~$MyPage~d" /tmp/menuTree.js
		umount /www/require/modules/menuTree.js
		mount -o bind /tmp/menuTree.js /www/require/modules/menuTree.js
		rm -f "$SCRIPT_WEBPAGE_DIR/$MyPage"
		rm -f "$SCRIPT_WEBPAGE_DIR/$(echo $MyPage | cut -f1 -d'.').title"
	fi
	flock -u "$FD"
	rm -f "$SCRIPT_DIR/connmonstats_www.asp" 2>/dev/null

	printf "\\n${BOLD}Do you want to delete %s config and stats? (y/n)${CLEARFORMAT}  " "$SCRIPT_NAME"
	read -r confirm
	case "$confirm" in
		y|Y)
			rm -rf "$SCRIPT_DIR" 2>/dev/null
			rm -rf "$SCRIPT_STORAGE_DIR" 2>/dev/null
		;;
		*)
			:
		;;
	esac

	SETTINGSFILE="/jffs/addons/custom_settings.txt"
	sed -i '/connmon_version_local/d' "$SETTINGSFILE"
	sed -i '/connmon_version_server/d' "$SETTINGSFILE"

	rm -rf "$SCRIPT_WEB_DIR" 2>/dev/null
	rm -f "/jffs/scripts/$SCRIPT_NAME" 2>/dev/null
	Clear_Lock
	Print_Output true "Uninstall completed" "$PASS"
}

NTP_Ready()
{
	if [ "$(nvram get ntp_ready)" -eq 0 ]
	then
		Check_Lock
		ntpwaitcount=0
		while [ "$(nvram get ntp_ready)" -eq 0 ] && [ "$ntpwaitcount" -lt 600 ]
		do
			ntpwaitcount="$((ntpwaitcount + 30))"
			Print_Output true "Waiting for NTP to sync..." "$WARN"
			sleep 30
		done
		if [ "$ntpwaitcount" -ge 600 ]
		then
			Print_Output true "NTP failed to sync after 10 minutes. Please resolve!" "$CRIT"
			Clear_Lock
			exit 1
		else
			Print_Output true "NTP synced, $SCRIPT_NAME will now continue" "$PASS"
			Clear_Lock
		fi
	fi
}

### function based on @Adamm00's Skynet USB wait function ###
##----------------------------------------##
## Modified by Martinski W. [2024-Dec-21] ##
##----------------------------------------##
Entware_Ready()
{
	local theSleepDelay=5  maxSleepTimer=100  sleepTimerSecs

	if [ ! -f /opt/bin/opkg ]
	then
		Check_Lock
		sleepTimerSecs=0

		while [ ! -f /opt/bin/opkg ] && [ "$sleepTimerSecs" -lt "$maxSleepTimer" ]
		do
			if [ "$((sleepTimerSecs % 10))" -eq 0 ]
			then
			    Print_Output true "Entware NOT found, sleeping for $theSleepDelay secs [$sleepTimerSecs secs]..." "$WARN"
			fi
			sleep "$theSleepDelay"
			sleepTimerSecs="$((sleepTimerSecs + theSleepDelay))"
		done
		if [ ! -f /opt/bin/opkg ]
		then
			Print_Output true "Entware NOT found and is required for $SCRIPT_NAME to run, please resolve." "$CRIT"
			Clear_Lock
			exit 1
		else
			Print_Output true "Entware found, $SCRIPT_NAME will now continue" "$PASS"
			Clear_Lock
		fi
	fi
}
### ###

### function based on @dave14305's FlexQoS about function ###
Show_About()
{
	cat <<EOF
About
  $SCRIPT_NAME is an internet connection monitoring tool for
  AsusWRT Merlin with charts for daily, weekly and monthly
  summaries.

License
  $SCRIPT_NAME is free to use under the GNU General Public License
  version 3 (GPL-3.0) https://opensource.org/licenses/GPL-3.0

Help & Support
  https://www.snbforums.com/forums/asuswrt-merlin-addons.60/?prefix_id=18

Source code
  https://github.com/jackyaz/$SCRIPT_NAME
EOF
	printf "\\n"
}
### ###

### function based on @dave14305's FlexQoS show_help function ###
Show_Help()
{
	cat <<EOF
Available commands:
  $SCRIPT_NAME about            explains functionality
  $SCRIPT_NAME update           checks for updates
  $SCRIPT_NAME forceupdate      updates to latest version (force update)
  $SCRIPT_NAME startup force    runs startup actions such as mount WebUI tab
  $SCRIPT_NAME install          installs script
  $SCRIPT_NAME uninstall        uninstalls script
  $SCRIPT_NAME generate         run ping test and save to database. also runs outputcsv
  $SCRIPT_NAME outputcsv        create CSVs from database, used by WebUI and export
  $SCRIPT_NAME trimdb           run maintenance on database (this runs automatically every night)
  $SCRIPT_NAME enable           enable automatic ping tests
  $SCRIPT_NAME disable          disable automatic ping tests
  $SCRIPT_NAME develop          switch to development branch
  $SCRIPT_NAME stable           switch to stable branch
EOF
	printf "\n"
}

### ###

##-------------------------------------##
## Added by Martinski W. [2024-Dec-21] ##
##-------------------------------------##
TMPDIR="$SHARE_TEMP_DIR"
SQLITE_TMPDIR="$TMPDIR"
export SQLITE_TMPDIR TMPDIR

if [ -f "/opt/share/$SCRIPT_NAME.d/config" ]
then SCRIPT_STORAGE_DIR="/opt/share/${SCRIPT_NAME}.d"
else SCRIPT_STORAGE_DIR="/jffs/addons/${SCRIPT_NAME}.d"
fi

SCRIPT_CONF="$SCRIPT_STORAGE_DIR/config"
CONNSTATS_DB="$SCRIPT_STORAGE_DIR/connstats.db"
CSV_OUTPUT_DIR="$SCRIPT_STORAGE_DIR/csv"
USER_SCRIPT_DIR="$SCRIPT_STORAGE_DIR/userscripts.d"

if [ $# -eq 0 ] || [ -z "$1" ]
then
	NTP_Ready
	Entware_Ready
	if [ ! -f /opt/bin/sqlite3 ] && [ -x /opt/bin/opkg ]
    then
		Print_Output true "Installing required version of sqlite3 from Entware" "$PASS"
		opkg update
		opkg install sqlite3-cli
	fi
	Create_Dirs
	Conf_Exists
	ScriptStorageLocation load true
	Create_Symlinks
	Auto_Startup create 2>/dev/null
	if AutomaticMode check
	then Auto_Cron create 2>/dev/null
	else Auto_Cron delete 2>/dev/null
	fi
	Auto_ServiceEvent create 2>/dev/null
	Shortcut_Script create
	Process_Upgrade
	ScriptHeader
	MainMenu
	exit 0
fi

##----------------------------------------##
## Modified by Martinski W. [2024-Dec-21] ##
##----------------------------------------##
case "$1" in
	install)
		Check_Lock
		Menu_Install
		exit 0
	;;
	startup)
		Menu_Startup "$2"
		exit 0
	;;
	generate)
		NTP_Ready
		Entware_Ready
		Check_Lock
		Run_PingTest
		Clear_Lock
		exit 0
	;;
	trimdb)
		NTP_Ready
		Entware_Ready
		Check_Lock
		_Trim_Database_
		_Optimize_Database_
		_UpdateDatabaseFileSizeInfo_
		Clear_Lock
		exit 0
	;;
	outputcsv)
		NTP_Ready
		Entware_Ready
		Check_Lock
		Generate_CSVs
		Clear_Lock
		exit 0
	;;
	enable)
		Entware_Ready
		Check_Lock
		AutomaticMode enable
		Clear_Lock
		exit 0
	;;
	disable)
		Check_Lock
		AutomaticMode disable
		Clear_Lock
		exit 0
	;;
	service_event)
		if [ "$2" = "start" ] && [ "$3" = "$SCRIPT_NAME" ]
		then
			rm -f "$SCRIPT_WEB_DIR/detect_connmon.js"
			rm -f /tmp/pingfile.txt
			rm -f "$SCRIPT_WEB_DIR/ping-result.txt"
			Check_Lock webui
			sleep 3
			Run_PingTest
			Clear_Lock
			exit 0
		elif [ "$2" = "start" ] && [ "$3" = "${SCRIPT_NAME}config" ]
		then
			Check_Lock webui
			echo 'var savestatus = "InProgress";' > "$SCRIPT_WEB_DIR/detect_save.js"
			sleep 3
			Conf_FromSettings
			echo 'var savestatus = "Success";' > "$SCRIPT_WEB_DIR/detect_save.js"
			Clear_Lock
			exit 0
		elif [ "$2" = "start" ] && [ "$3" = "${SCRIPT_NAME}emailconfig" ]
		then
			echo 'var savestatus = "InProgress";' > "$SCRIPT_WEB_DIR/detect_save.js"
			sleep 3
			EmailConf_FromSettings
			echo 'var savestatus = "Success";' > "$SCRIPT_WEB_DIR/detect_save.js"
			exit 0
		elif [ "$2" = "start" ] && [ "$3" = "${SCRIPT_NAME}checkupdate" ]
		then
			Update_Check
			exit 0
		elif [ "$2" = "start" ] && [ "$3" = "${SCRIPT_NAME}doupdate" ]
		then
			Update_Version force unattended
			exit 0
		elif [ "$2" = "start" ] && [ "$3" = "${SCRIPT_NAME}emailpassword" ]
		then
			if Email_ConfExists; then
				rm -f "$SCRIPT_WEB_DIR/password.htm"
				sleep 3
				Email_Decrypt_Password > "$SCRIPT_WEB_DIR/password.htm"
			fi
		elif [ "$2" = "start" ] && [ "$3" = "${SCRIPT_NAME}deleteemailpassword" ]
		then
			rm -f "$SCRIPT_WEB_DIR/password.htm"
		elif [ "$2" = "start" ] && [ "$3" = "${SCRIPT_NAME}customactionlist" ]
		then
			rm -f "$SCRIPT_STORAGE_DIR/.customactionlist"
			sleep 3
			CustomAction_List silent
			exit 0
		elif [ "$2" = "start" ] && [ "$3" = "${SCRIPT_NAME}TestEmail" ]
		then
			rm -f "$SCRIPT_WEB_DIR/detect_test.js"
			echo 'var teststatus = "InProgress";' > "$SCRIPT_WEB_DIR/detect_test.js"
			NOTIFICATIONS_EMAIL_LIST="$(Email_Recipients check)"
			if [ -z "$NOTIFICATIONS_EMAIL_LIST" ]; then
				if SendEmail "Test email - $(/bin/date +"%c")" "This is a test email!"; then
					echo 'var teststatus = "Success";' > "$SCRIPT_WEB_DIR/detect_test.js"
				else
					echo 'var teststatus = "Fail";' > "$SCRIPT_WEB_DIR/detect_test.js"
				fi
			else
				IFS=$','
				success="true"
				for EMAIL in $NOTIFICATIONS_EMAIL_LIST; do
					if ! SendEmail "Test email - $(/bin/date +"%c")" "This is a test email!" "$EMAIL"; then
						success="false"
					fi
				done
				if [ "$success" = "true" ]; then
					echo 'var teststatus = "Success";' > "$SCRIPT_WEB_DIR/detect_test.js"
				else
					echo 'var teststatus = "Fail";' > "$SCRIPT_WEB_DIR/detect_test.js"
				fi
			fi
			unset IFS
			exit 0
		elif [ "$2" = "start" ] && [ "$3" = "${SCRIPT_NAME}TestWebhooks" ]
		then
			rm -f "$SCRIPT_WEB_DIR/detect_test.js"
			echo 'var teststatus = "InProgress";' > "$SCRIPT_WEB_DIR/detect_test.js"
			NOTIFICATIONS_WEBHOOK_LIST="$(Webhook_Targets check)"
			if [ -z "$NOTIFICATIONS_WEBHOOK_LIST" ]; then
				echo 'var teststatus = "Fail";' > "$SCRIPT_WEB_DIR/detect_test.js"
			fi
			IFS=$','
			success="true"
			for WEBHOOK in $NOTIFICATIONS_WEBHOOK_LIST; do
				if ! SendWebhook "$(/bin/date +"%c")\n\nThis is a test webhook message!" "$WEBHOOK"; then
					success="false"
				fi
			done
			unset IFS
			if [ "$success" = "true" ]; then
				echo 'var teststatus = "Success";' > "$SCRIPT_WEB_DIR/detect_test.js"
			else
				echo 'var teststatus = "Fail";' > "$SCRIPT_WEB_DIR/detect_test.js"
			fi
			exit 0
		elif [ "$2" = "start" ] && [ "$3" = "${SCRIPT_NAME}TestPushover" ]
		then
			rm -f "$SCRIPT_WEB_DIR/detect_test.js"
			echo 'var teststatus = "InProgress";' > "$SCRIPT_WEB_DIR/detect_test.js"
			if SendPushover "$(/bin/date +"%c")"$'\n'$'\n'"This is a test pushover message!"; then
				echo 'var teststatus = "Success";' > "$SCRIPT_WEB_DIR/detect_test.js"
			else
				echo 'var teststatus = "Fail";' > "$SCRIPT_WEB_DIR/detect_test.js"
			fi
			exit 0
		elif [ "$2" = "start" ] && [ "$3" = "${SCRIPT_NAME}TestCustomActions" ]
		then
			rm -f "$SCRIPT_WEB_DIR/detect_test.js"
			echo 'var teststatus = "InProgress";' > "$SCRIPT_WEB_DIR/detect_test.js"
			if [ -z "$(ls -A "$USER_SCRIPT_DIR")" ]; then
				echo 'var teststatus = "Fail";' > "$SCRIPT_WEB_DIR/detect_test.js"
			else
				printf "\\n"
				FILES="$USER_SCRIPT_DIR/*.sh"
				for f in $FILES; do
					if [ -f "$f" ]; then
						sh "$f" "$(/bin/date +%c)" "30 ms" "15 ms" "90%"
					fi
				done
				echo 'var teststatus = "Success";' > "$SCRIPT_WEB_DIR/detect_test.js"
			fi
			exit 0
		elif [ "$2" = "start" ] && [ "$3" = "${SCRIPT_NAME}TestHealthcheck" ]
		then
			rm -f "$SCRIPT_WEB_DIR/detect_test.js"
			echo 'var teststatus = "InProgress";' > "$SCRIPT_WEB_DIR/detect_test.js"
			if SendHealthcheckPing "Pass"; then
				echo 'var teststatus = "Success";' > "$SCRIPT_WEB_DIR/detect_test.js"
			else
				echo 'var teststatus = "Fail";' > "$SCRIPT_WEB_DIR/detect_test.js"
			fi
			exit 0
		elif [ "$2" = "start" ] && [ "$3" = "${SCRIPT_NAME}TestInfluxDB" ]
		then
			rm -f "$SCRIPT_WEB_DIR/detect_test.js"
			echo 'var teststatus = "InProgress";' > "$SCRIPT_WEB_DIR/detect_test.js"
			if SendToInfluxDB "$(/bin/date +%s)" 30 15 90; then
				echo 'var teststatus = "Success";' > "$SCRIPT_WEB_DIR/detect_test.js"
			else
				echo 'var teststatus = "Fail";' > "$SCRIPT_WEB_DIR/detect_test.js"
			fi
			exit 0
		fi
		exit 0
	;;
	update)
		Update_Version
		exit 0
	;;
	forceupdate)
		Update_Version force
		exit 0
	;;
	postupdate)
		Create_Dirs
		Conf_Exists
		ScriptStorageLocation load
		Create_Symlinks
		Auto_Startup create 2>/dev/null
		if AutomaticMode check
		then Auto_Cron create 2>/dev/null
		else Auto_Cron delete 2>/dev/null
		fi
		Auto_ServiceEvent create 2>/dev/null
		Process_Upgrade
		Shortcut_Script create
		Set_Version_Custom_Settings local "$SCRIPT_VERSION"
		Set_Version_Custom_Settings server "$SCRIPT_VERSION"
		exit 0
	;;
	uninstall)
		Menu_Uninstall
		exit 0
	;;
	develop)
		SCRIPT_BRANCH="develop"
		SCRIPT_REPO="https://raw.githubusercontent.com/AMTM-OSR/$SCRIPT_NAME/$SCRIPT_BRANCH"
		Update_Version force
		exit 0
	;;
	stable)
		SCRIPT_BRANCH="master"
		SCRIPT_REPO="hhttps://raw.githubusercontent.com/AMTM-OSR/$SCRIPT_NAME/$SCRIPT_BRANCH"
		Update_Version force
		exit 0
	;;
	about)
		ScriptHeader
		Show_About
		exit 0
	;;
	help)
		ScriptHeader
		Show_Help
		exit 0
	;;
	*)
		ScriptHeader
		Print_Output false "Parameter [$*] is NOT recognised." "$ERR"
		Print_Output false "For a list of available commands run: $SCRIPT_NAME help" "$SETTING"
		exit 1
	;;
esac

#!/bin/sh

##############################################################
##                                                          ##
##     ___   ___   _ __   _ __   _ __ ___    ___   _ __     ##
##    / __| / _ \ | '_ \ | '_ \ | '_ ` _ \  / _ \ | '_ \    ##
##   | (__ | (_) || | | || | | || | | | | || (_) || | | |   ##
##    \___| \___/ |_| |_||_| |_||_| |_| |_| \___/ |_| |_|   ##
##                                                          ##
##           https://github.com/AMTM-OSR/connmon            ##
##      Forked from https://github.com/jackyaz/connmon      ##
##                                                          ##
##############################################################
# Last Modified: 2026-Feb-18
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
# shellcheck disable=SC3037
# shellcheck disable=SC3043
# shellcheck disable=SC3045
##############################################################

### Start of script variables ###
readonly SCRIPT_NAME="connmon"
readonly SCRIPT_VERSION="v3.0.11"
readonly SCRIPT_VERSTAG="26021800"
SCRIPT_BRANCH="develop"
SCRIPT_REPO="https://raw.githubusercontent.com/AMTM-OSR/$SCRIPT_NAME/$SCRIPT_BRANCH"
readonly SCRIPT_DIR="/jffs/addons/$SCRIPT_NAME.d"
readonly SCRIPT_WEBPAGE_DIR="$(readlink -f /www/user)"
readonly SCRIPT_WEB_DIR="$SCRIPT_WEBPAGE_DIR/$SCRIPT_NAME"
readonly SHARED_DIR="/jffs/addons/shared-jy"
readonly SHARED_REPO="https://raw.githubusercontent.com/AMTM-OSR/shared-jy/master"
readonly SHARED_WEB_DIR="$SCRIPT_WEBPAGE_DIR/shared-jy"
readonly TEMP_MENU_TREE="/tmp/menuTree.js"
readonly EMAIL_DIR="/jffs/addons/amtm/mail"
readonly EMAIL_CONF="$EMAIL_DIR/email.conf"
readonly EMAIL_REGEX="^(([A-Za-z0-9]+((\.|\-|\_|\+)?[A-Za-z0-9]?)*[A-Za-z0-9]+)|[A-Za-z0-9]+)@(([A-Za-z0-9]+)+((\.|\-|\_)?([A-Za-z0-9]+)+)*)+\.([A-Za-z]{2,})+$"

[ -z "$(nvram get odmpid)" ] && ROUTER_MODEL="$(nvram get productid)" || ROUTER_MODEL="$(nvram get odmpid)"
[ -f /opt/bin/sqlite3 ] && SQLITE3_PATH=/opt/bin/sqlite3 || SQLITE3_PATH=/usr/sbin/sqlite3

##----------------------------------------##
## Modified by Martinski W. [2025-Feb-16] ##
##----------------------------------------##
readonly scriptVersRegExp="v[0-9]{1,2}([.][0-9]{1,2})([.][0-9]{1,2})"
readonly webPageMenuAddons="menuName: \"Addons\","
readonly webPageHelpSupprt="tabName: \"Help & Support\"},"
readonly webPageFileRegExp="user([1-9]|[1-2][0-9])[.]asp"
readonly webPageLineTabExp="\{url: \"$webPageFileRegExp\", tabName: "
readonly webPageLineRegExp="${webPageLineTabExp}\"$SCRIPT_NAME\"\},"
readonly BEGIN_MenuAddOnsTag="/\*\*BEGIN:_AddOns_\*\*/"
readonly ENDIN_MenuAddOnsTag="/\*\*ENDIN:_AddOns_\*\*/"
readonly branchxStr_TAG="[Branch: $SCRIPT_BRANCH]"
readonly versionDev_TAG="${SCRIPT_VERSION}_${SCRIPT_VERSTAG}"
readonly versionMod_TAG="$SCRIPT_VERSION on $ROUTER_MODEL"
readonly curlErr1RegExp="invalid|unauthorized|error"
readonly curlErr2RegExp="404: Not Found|400 Bad Request|401 Unauthorized"
readonly curlErr3RegExp="$curlErr1RegExp|$curlErr2RegExp"
readonly curlOutLogFile="/tmp/var/tmp/temp_${SCRIPT_NAME}_curl_OUT.LOG"
readonly curlErrLogFile="/tmp/var/tmp/temp_${SCRIPT_NAME}_curl_ERR.LOG"
readonly tmpCurlSEPstr="-------------------------------------------------------"

# To support automatic script updates from AMTM #
doScriptUpdateFromAMTM=true

# For daily CRON job to trim database #
readonly defTrimDB_Hour=3
readonly defTrimDB_Mins=3

readonly oneHrSec=3600
readonly _12Hours=43200
readonly _24Hours=86400
readonly _36Hours=129600
readonly oneKByte=1024
readonly oneMByte=1048576
readonly ei8MByte=8388608
readonly ni9MByte=9437184
readonly tenMByte=10485760
readonly oneGByte=1073741824
readonly SHARE_TEMP_DIR="/opt/share/tmp"

##-------------------------------------##
## Added by Martinski W. [2025-Jun-04] ##
##-------------------------------------##
readonly sqlDBLogFileSize=102400
readonly sqlDBLogDateTime="%Y-%m-%d %H:%M:%S"
readonly sqlDBLogFileName="${SCRIPT_NAME}_DBSQL_DEBUG.LOG"

### End of script variables ###

### Start of output format variables ###
readonly CRIT="\\e[41m"
readonly ERR="\\e[31m"
readonly WARN="\\e[33m"
readonly PASS="\\e[32m"
readonly BOLD="\\e[1m"
readonly SETTING="${BOLD}\e[36m"
readonly UNDERLINE="\e[4m"
readonly CLEARFORMAT="\e[0m"
readonly BOLDUNDERLN="\e[1;4m"

##----------------------------------------##
## Modified by Martinski W. [2025-Feb-10] ##
##----------------------------------------##
readonly CLRct="\e[0m"
readonly REDct="\e[1;31m"
readonly GRNct="\e[1;32m"
readonly MGNTct="\e[1;35m"
readonly CritIREDct="\e[41m"
readonly CritBREDct="\e[30;101m"
readonly PassBGRNct="\e[30;102m"
readonly WarnBYLWct="\e[30;103m"
readonly WarnIMGNct="\e[45m"
readonly WarnBMGNct="\e[30;105m"
readonly menuSepStr="${BOLD}##############################################################${CLRct}"
isInteractive=false
[ -t 0 ] && ! tty | grep -qwi "NOT" && isInteractive=true

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
		logger -t "${SCRIPT_NAME}_[$$]" -p $prioNum "$2"
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
				if [ "$1" = "webui" ]
				then
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
	curl -fsL --retry 4 --retry-delay 5 "$SCRIPT_REPO/$SCRIPT_NAME.sh" | grep -qF "jackyaz" || \
    { Print_Output true "404 error detected - stopping update" "$ERR"; return 1; }
	serverver="$(curl -fsL --retry 4 --retry-delay 5 "$SCRIPT_REPO/$SCRIPT_NAME.sh" | grep "SCRIPT_VERSION=" | grep -m1 -oE "$scriptVersRegExp")"
	if [ "$localver" != "$serverver" ]
	then
		doupdate="version"
		Set_Version_Custom_Settings server "$serverver"
		changelog="$(curl -fsL --retry 4 --retry-delay 5 "$SCRIPT_REPO/CHANGELOG.md" | sed -n "/$serverver"'/,/##/p' | head -n -1 | sed 's/## //')"
		echo 'var changelog = "<div style=\"width:350px;\"><b>Changelog</b><br />'"$(echo "$changelog" | tr '\n' '|' | sed 's/|/<br \/>/g')"'</div>"' > "$SCRIPT_WEB_DIR/detect_changelog.js"
		echo 'var updatestatus = "'"$serverver"'";'  > "$SCRIPT_WEB_DIR/detect_update.js"
	else
		localmd5="$(md5sum "/jffs/scripts/$SCRIPT_NAME" | awk '{print $1}')"
		remotemd5="$(curl -fsL --retry 4 --retry-delay 5 "$SCRIPT_REPO/$SCRIPT_NAME.sh" | md5sum | awk '{print $1}')"
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
			changelog="$(curl -fsL --retry 4 --retry-delay 5 "$SCRIPT_REPO/CHANGELOG.md" | sed -n "/$serverver"'/,/##/p' | head -n -1 | sed 's/## //')"
			printf "${BOLD}${UNDERLINE}Changelog\\n${CLEARFORMAT}%s\\n\\n" "$changelog"
		elif [ "$isupdate" = "md5" ]
		then
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
					Download_File "$SCRIPT_REPO/$SCRIPT_NAME.sh" "/jffs/scripts/$SCRIPT_NAME" && \
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
		serverver="$(curl -fsL --retry 4 --retry-delay 5 "$SCRIPT_REPO/$SCRIPT_NAME.sh" | grep "SCRIPT_VERSION=" | grep -m1 -oE "$scriptVersRegExp")"
		Print_Output true "Downloading latest version ($serverver) of $SCRIPT_NAME" "$PASS"
		Update_File CHANGELOG.md
		Update_File README.md
		Update_File LICENSE
		Update_File shared-jy.tar.gz
		Update_File connmonstats_www.asp
		Download_File "$SCRIPT_REPO/$SCRIPT_NAME.sh" "/jffs/scripts/$SCRIPT_NAME" && \
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

##-------------------------------------##
## Added by Martinski W. [2026-Feb-18] ##
##-------------------------------------##
ScriptUpdateFromAMTM()
{
    if ! "$doScriptUpdateFromAMTM"
    then
        printf "Automatic script updates via AMTM are currently disabled.\n\n"
        return 1
    fi
    if [ $# -gt 0 ] && [ "$1" = "check" ]
    then return 0
    fi
    Update_Version force unattended
    return "$?"
}

##----------------------------------------##
## Modified by Martinski W. [2025-Feb-09] ##
##----------------------------------------##
Update_File()
{
	if [ "$1" = "connmonstats_www.asp" ]
	then
		tmpfile="/tmp/$1"
		if [ -f "$SCRIPT_DIR/$1" ]
		then
			Download_File "$SCRIPT_REPO/$1" "$tmpfile"
			if ! diff -q "$tmpfile" "$SCRIPT_DIR/$1" >/dev/null 2>&1
			then
				Get_WebUI_Page "$SCRIPT_DIR/$1"
				sed -i "\\~$MyWebPage~d" "$TEMP_MENU_TREE"
				rm -f "$SCRIPT_WEBPAGE_DIR/$MyWebPage" 2>/dev/null
				Download_File "$SCRIPT_REPO/$1" "$SCRIPT_DIR/$1"
				Print_Output true "New version of $1 downloaded" "$PASS"
				Mount_WebUI
			fi
			rm -f "$tmpfile"
		else
			Download_File "$SCRIPT_REPO/$1" "$SCRIPT_DIR/$1"
			Print_Output true "New version of $1 downloaded" "$PASS"
			Mount_WebUI
		fi
	elif [ "$1" = "shared-jy.tar.gz" ]
	then
		if [ ! -f "$SHARED_DIR/${1}.md5" ]
		then
			Download_File "$SHARED_REPO/$1" "$SHARED_DIR/$1"
			Download_File "$SHARED_REPO/${1}.md5" "$SHARED_DIR/${1}.md5"
			tar -xzf "$SHARED_DIR/$1" -C "$SHARED_DIR"
			rm -f "$SHARED_DIR/$1"
			Print_Output true "New version of $1 downloaded" "$PASS"
		else
			localmd5="$(cat "$SHARED_DIR/${1}.md5")"
			remotemd5="$(curl -fsL --retry 4 --retry-delay 5 "$SHARED_REPO/${1}.md5")"
			if [ "$localmd5" != "$remotemd5" ]
			then
				Download_File "$SHARED_REPO/$1" "$SHARED_DIR/$1"
				Download_File "$SHARED_REPO/${1}.md5" "$SHARED_DIR/${1}.md5"
				tar -xzf "$SHARED_DIR/$1" -C "$SHARED_DIR"
				rm -f "$SHARED_DIR/$1"
				Print_Output true "New version of $1 downloaded" "$PASS"
			fi
		fi
	elif [ "$1" = "CHANGELOG.md" ]
	then
		tmpfile="/tmp/$1"
		Download_File "$SCRIPT_REPO/$1" "$tmpfile"
		if ! diff -q "$tmpfile" "$SCRIPT_DIR/$1" >/dev/null 2>&1; then
			Download_File "$SCRIPT_REPO/$1" "$SCRIPT_DIR/$1"
		fi
		rm -f "$tmpfile"
	elif [ "$1" = "README.md" ] || [ "$1" = "LICENSE" ]
	then
		tmpfile="/tmp/$1"
		Download_File "$SCRIPT_REPO/$1" "$tmpfile"
		if ! diff -q "$tmpfile" "$SCRIPT_DIR/$1" >/dev/null 2>&1; then
			Download_File "$SCRIPT_REPO/$1" "$SCRIPT_DIR/$1"
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
## Modified by Martinski W. [2025-Dec-12] ##
##----------------------------------------##
Conf_FromSettings()
{
	SETTINGSFILE="/jffs/addons/custom_settings.txt"
	TEMP_FILE="/tmp/connmon_settings.txt"

	if [ -f "$SETTINGSFILE" ]
	then
		if [ "$(grep "^connmon_" $SETTINGSFILE | grep -Ecv '_version_[ls]')" -gt 0 ]
		then
			Print_Output true "Updated settings from WebUI found, merging into $SCRIPT_CONF" "$PASS"
			cp -a "$SCRIPT_CONF" "${SCRIPT_CONF}.bak"
			grep "^connmon_" "$SETTINGSFILE" | grep -Ev '_version_[ls]' > "$TEMP_FILE"
			sed -i "s/^connmon_//g;s/ /=/g" "$TEMP_FILE"
			while IFS='' read -r line || [ -n "$line" ]
			do
				SETTINGNAME="$(echo "$line" | cut -d'=' -f1 | awk '{print toupper($1)}')"
				SETTINGVALUE="$(echo "$line" | cut -d'=' -f2-)"
				if [ "$SETTINGNAME" = "NOTIFICATIONS_EMAIL_LIST" ]  || \
				   [ "$SETTINGNAME" = "NOTIFICATIONS_WEBHOOK_LIST" ] || \
				   [ "$SETTINGNAME" = "NOTIFICATIONS_PUSHOVER_LIST" ]
				then
					SETTINGVALUE="$(echo "$SETTINGVALUE" | sed 's~||||~,~g')"
				fi
				sed -i "s~$SETTINGNAME=.*~$SETTINGNAME=$SETTINGVALUE~" "$SCRIPT_CONF"
			done < "$TEMP_FILE"

			grep -E '^connmon_version_[ls]' "$SETTINGSFILE" > "$TEMP_FILE"
			sed -i "\\~connmon_~d" "$SETTINGSFILE"
			mv -f "$SETTINGSFILE" "${SETTINGSFILE}.bak"
			cat "${SETTINGSFILE}.bak" "$TEMP_FILE" > "$SETTINGSFILE"
			rm -f "$TEMP_FILE"
			rm -f "${SETTINGSFILE}.bak"

			if diff -U0 "$SCRIPT_CONF" "${SCRIPT_CONF}.bak" | grep -qE "[-+]STORAGELOCATION="
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
				Create_Dirs
				Conf_Exists
				Create_Symlinks
			fi
			if diff -U0 "$SCRIPT_CONF" "${SCRIPT_CONF}.bak" | grep -qE "(SCHDAYS|SCHHOUR|SCHMINS|AUTOMATICMODE=)"
			then
				Auto_Cron delete 2>/dev/null
				AutomaticMode check && Auto_Cron create 2>/dev/null
				_UpdateAutomaticModeState_
			fi
			if diff -U0 "$SCRIPT_CONF" "${SCRIPT_CONF}.bak" | grep -qE "(OUTPUTTIMEMODE=|DAYSTOKEEP=|LASTXRESULTS=)"
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

##----------------------------------------##
## Modified by Martinski W. [2025-Jul-20] ##
##----------------------------------------##
Create_Symlinks()
{
	ln -sf "$SCRIPT_WEB_DIR/ping-result.txt" "$SCRIPT_WEB_DIR/ping-result.htm" 2>/dev/null

	ln -sf "$EMAIL_CONF" "$SCRIPT_WEB_DIR/email_config.htm" 2>/dev/null
	ln -sf "$SCRIPT_CONF" "$SCRIPT_WEB_DIR/config.htm" 2>/dev/null
	ln -sf "$SCRIPT_DIR/CHANGELOG.md" "$SCRIPT_WEB_DIR/changelog.htm" 2>/dev/null

	ln -sf "$SCRIPT_STORAGE_DIR/lastx.csv" "$SCRIPT_WEB_DIR/lastx.htm" 2>/dev/null
	ln -sf "$SCRIPT_STORAGE_DIR/connstatstext.js" "$SCRIPT_WEB_DIR/connstatstext.js" 2>/dev/null
	ln -sf "$SCRIPT_STORAGE_DIR/.cron" "$SCRIPT_WEB_DIR/cron.js" 2>/dev/null
	ln -sf "$SCRIPT_STORAGE_DIR/.customactioninfo" "$SCRIPT_WEB_DIR/customactioninfo.htm" 2>/dev/null
	ln -sf "$SCRIPT_STORAGE_DIR/.customactionlist" "$SCRIPT_WEB_DIR/customactionlist.htm" 2>/dev/null
	ln -sf "$SCRIPT_STORAGE_DIR/.emailinfo" "$SCRIPT_WEB_DIR/emailinfo.htm" 2>/dev/null

	ln -sf "$CSV_OUTPUT_DIR" "$SCRIPT_WEB_DIR/csv" 2>/dev/null

	if [ ! -d "$SHARED_WEB_DIR" ]; then
		ln -s "$SHARED_DIR" "$SHARED_WEB_DIR" 2>/dev/null
	fi
}

##-------------------------------------##
## Added by Martinski W. [2025-Jun-06] ##
##-------------------------------------##
_GetConfigParam_()
{
   if [ $# -eq 0 ] || [ -z "$1" ]
   then echo '' ; return 1 ; fi

   local keyValue  checkFile
   local defValue="$([ $# -eq 2 ] && echo "$2" || echo '')"

   if [ ! -s "$SCRIPT_CONF" ]
   then echo "$defValue" ; return 0 ; fi

   if [ "$(grep -c "^${1}=" "$SCRIPT_CONF")" -gt 1 ]
   then  ## Remove duplicates. Keep ONLY the 1st key ##
       checkFile="${SCRIPT_CONF}.DUPKEY.txt"
       awk "!(/^${1}=/ && dup[/^${1}=/]++)" "$SCRIPT_CONF" > "$checkFile"
       if diff -q "$checkFile" "$SCRIPT_CONF" >/dev/null 2>&1
       then rm -f "$checkFile"
       else mv -f "$checkFile" "$SCRIPT_CONF"
       fi
   fi

   keyValue="$(grep "^${1}=" "$SCRIPT_CONF" | cut -d'=' -f2-)"
   echo "${keyValue:=$defValue}"
   return 0
}

##----------------------------------------##
## Modified by Martinski W. [2025-Dec-10] ##
##----------------------------------------##
Conf_Exists()
{
	local PINGFREQUENCY  AUTOMATEDopt  delCRON=false  sedNum  portNum

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
		if ! grep -q "^PINGSERVER=" "$SCRIPT_CONF"; then
			echo "PINGSERVER=8.8.8.8" >> "$SCRIPT_CONF"
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
			delCRON=true
		fi
		if ! grep -q "^SCHDAYS=" "$SCRIPT_CONF"; then
			echo "SCHDAYS=*" >> "$SCRIPT_CONF"
			delCRON=true
		fi
		if ! grep -q "^SCHHOURS=" "$SCRIPT_CONF"; then
			echo "SCHHOURS=*" >> "$SCRIPT_CONF"
			delCRON=true
		fi
		if ! grep -q "^SCHMINS=" "$SCRIPT_CONF"; then
			echo "SCHMINS=*/5" >> "$SCRIPT_CONF"
			delCRON=true
		fi
		if "$delCRON"
		then Auto_Cron delete 2>/dev/null
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
		if ! grep -q "^JFFS_MSGLOGTIME=" "$SCRIPT_CONF"; then
			echo "JFFS_MSGLOGTIME=0" >> "$SCRIPT_CONF"
		fi
		if ! grep -q "^NOTIFICATIONS_" "$SCRIPT_CONF"
		then
			{
				echo "NOTIFICATIONS_EMAIL=false"
				echo "NOTIFICATIONS_WEBHOOK=false"
				echo "NOTIFICATIONS_PUSHOVER=false"
				echo "NOTIFICATIONS_CUSTOM=false"
				echo "NOTIFICATIONS_HEALTHCHECK=false"
				echo "NOTIFICATIONS_INFLUXDB=false"
				echo "NOTIFICATIONS_PINGTEST=None"
				echo "NOTIFICATIONS_PINGTEST_FAILED=None"
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
				echo "NOTIFICATIONS_INFLUXDB_PROTO=http"
				echo "NOTIFICATIONS_INFLUXDB_DB=connmon"
				echo "NOTIFICATIONS_INFLUXDB_ORG=homenet"
				echo "NOTIFICATIONS_INFLUXDB_VERSION=2.0"
				echo "NOTIFICATIONS_INFLUXDB_USERNAME="
				echo "NOTIFICATIONS_INFLUXDB_PASSWORD="
				echo "NOTIFICATIONS_INFLUXDB_APITOKEN="
			} >> "$SCRIPT_CONF"
		fi
		if ! grep -q "^NOTIFICATIONS_PINGTEST_FAILED=" "$SCRIPT_CONF"
		then
			sedNum="$(grep -n '^NOTIFICATIONS_PINGTEST=' "$SCRIPT_CONF" | cut -d':' -f1)"
			[ -n "$sedNum" ] && sedNum="$((sedNum + 1))" && \
			sed -i "$sedNum i NOTIFICATIONS_PINGTEST_FAILED=None" "$SCRIPT_CONF"
		fi
		if ! grep -q "^NOTIFICATIONS_INFLUXDB_ORG=" "$SCRIPT_CONF"
		then
			sedNum="$(grep -n '^NOTIFICATIONS_INFLUXDB_DB=' "$SCRIPT_CONF" | cut -d':' -f1)"
			[ -n "$sedNum" ] && sedNum="$((sedNum + 1))" && \
			sed -i "$sedNum i NOTIFICATIONS_INFLUXDB_ORG=homenet" "$SCRIPT_CONF"
		fi
		if ! grep -q "^NOTIFICATIONS_INFLUXDB_PROTO=" "$SCRIPT_CONF"
		then
			sedNum="$(grep -n '^NOTIFICATIONS_INFLUXDB_PORT=' "$SCRIPT_CONF" | cut -d':' -f1)"
			portNum="$(grep '^NOTIFICATIONS_INFLUXDB_PORT=' "$SCRIPT_CONF" | cut -d'=' -f2)"
			[ "$portNum" = "443" ] && protoStr="https" || protoStr="http"
			[ -n "$sedNum" ] && sedNum="$((sedNum + 1))" && \
			sed -i "$sedNum i NOTIFICATIONS_INFLUXDB_PROTO=$protoStr" "$SCRIPT_CONF"
		fi
		return 0
	else
		{
		   echo "PINGSERVER=8.8.8.8"
		   echo "OUTPUTTIMEMODE=unix"
		   echo "STORAGELOCATION=jffs"
		   echo "PINGDURATION=30"
		   echo "AUTOMATICMODE=true"
		   echo "SCHDAYS=*"; echo "SCHHOURS=*"; echo "SCHMINS=*/5"
		   echo "JFFS_MSGLOGTIME=0"
		   echo "DAYSTOKEEP=30"
		   echo "LASTXRESULTS=10"
		   echo "EXCLUDEFROMQOS=true"
		   echo "NOTIFICATIONS_EMAIL=false"
		   echo "NOTIFICATIONS_WEBHOOK=false"
		   echo "NOTIFICATIONS_PUSHOVER=false"
		   echo "NOTIFICATIONS_CUSTOM=false"
		   echo "NOTIFICATIONS_HEALTHCHECK=false"
		   echo "NOTIFICATIONS_INFLUXDB=false"
		   echo "NOTIFICATIONS_PINGTEST=None"
		   echo "NOTIFICATIONS_PINGTEST_FAILED=None"
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
		   echo "NOTIFICATIONS_INFLUXDB_PROTO=http"
		   echo "NOTIFICATIONS_INFLUXDB_DB=connmon"
		   echo "NOTIFICATIONS_INFLUXDB_ORG=homenet"
		   echo "NOTIFICATIONS_INFLUXDB_VERSION=2.0"
		   echo "NOTIFICATIONS_INFLUXDB_USERNAME="
		   echo "NOTIFICATIONS_INFLUXDB_PASSWORD="
		   echo "NOTIFICATIONS_INFLUXDB_APITOKEN="
		} > "$SCRIPT_CONF"
		return 1
	fi
}

##----------------------------------------##
## Modified by Martinski W. [2025-Dec-15] ##
##----------------------------------------##
PingServer()
{
	case "$1" in
		update)
			exitOK=false
			while true
			do
				ScriptHeader
				printf " ${BOLD}Current ping server destination: ${GRNct}%s${CLRct}\n\n" "$(PingServer check)"
				if "$exitOK"
				then PressEnter ; break
				fi
				printf "  ${GRNct}1${CLRct}. Enter IP Address\n"
				printf "  ${GRNct}2${CLRct}. Enter Domain Name\n"
				printf "  ${GRNct}e${CLRct}. Go back\n"
				printf "\n${BOLD}Choose an option:${CLRct}  "
				read -r pingoption

				case "$pingoption" in
					1)
						while true
						do
							printf "\n${BOLD}Please enter an IP address (e=Exit):${CLRct}  "
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
							printf "\n${BOLD}Please enter a domain name (e=Exit):${CLRct}  "
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
						printf "\n${BOLD}${ERR}Please choose a valid option.${CLRct}\n\n"
						PressEnter
					;;
				esac
			done
			echo
		;;
		check)
			PINGSERVER="$(_GetConfigParam_ PINGSERVER '8.8.8.8')"
			echo "$PINGSERVER"
		;;
	esac
}

##----------------------------------------##
## Modified by Martinski W. [2025-Jun-06] ##
##----------------------------------------##
PingDuration()
{
	local MINvalue=10  MAXvalue=60  #Seconds#
	case "$1" in
		update)
			pingSecs="$(PingDuration check)"
			exitLoop=false
			while true
			do
				ScriptHeader
				printf " ${BOLD}Current number of seconds for ping tests: ${GRNct}${pingSecs}${CLRct}\n\n"
				printf " ${BOLD}Please enter the maximum number of seconds\n"
				printf " to run the ping tests [${GRNct}${MINvalue}-${MAXvalue}${CLRct}] (e=Exit):${CLRct}  "
				read -r pingdur_choice
				if [ -z "$pingdur_choice" ] && \
				   echo "$pingSecs" | grep -qE "^([1-9][0-9])$" && \
				   [ "$pingSecs" -ge "$MINvalue" ] && [ "$pingSecs" -le "$MAXvalue" ]
				then
					exitLoop=true
					break
				elif [ "$pingdur_choice" = "e" ]
				then
					exitLoop=true
					break
				elif ! Validate_Number "$pingdur_choice"
				then
					printf "\n${ERR}Please enter a valid number [${MINvalue}-${MAXvalue}].${CLRct}\n"
					PressEnter
				elif [ "$pingdur_choice" -lt "$MINvalue" ] || [ "$pingdur_choice" -gt "$MAXvalue" ]
				then
					printf "\n${ERR}Please enter a number between ${MINvalue} and ${MAXvalue}.${CLRct}\n"
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
			PINGDURATION="$(_GetConfigParam_ PINGDURATION 30)"
			echo "$PINGDURATION"
		;;
	esac
}

##----------------------------------------##
## Modified by Martinski W. [2025-Jun-06] ##
##----------------------------------------##
DaysToKeep()
{
	local MINvalue=15  MAXvalue=365  #Days#
	case "$1" in
		update)
			daysToKeep="$(DaysToKeep check)"
			exitLoop=false
			while true
			do
				ScriptHeader
				printf " ${BOLD}Current number of days to keep data: ${GRNct}${daysToKeep}${CLRct}\n\n"
				printf " ${BOLD}Please enter the maximum number of days\n"
				printf " to keep the data for [${GRNct}${MINvalue}-${MAXvalue}${CLRct}] (e=Exit):${CLRct}  "
				read -r daystokeep_choice
				if [ -z "$daystokeep_choice" ] && \
				   echo "$daysToKeep" | grep -qE "^([1-9][0-9]{1,2})$" && \
				   [ "$daysToKeep" -ge "$MINvalue" ] && [ "$daysToKeep" -le "$MAXvalue" ]
				then
					exitLoop=true
					break
				elif [ "$daystokeep_choice" = "e" ]
				then
					exitLoop=true
					break
				elif ! Validate_Number "$daystokeep_choice"
				then
					printf "\n${ERR}Please enter a valid number [${MINvalue}-${MAXvalue}].${CLRct}\n"
					PressEnter
				elif [ "$daystokeep_choice" -lt "$MINvalue" ] || [ "$daystokeep_choice" -gt "$MAXvalue" ]
				then
					printf "\n${ERR}Please enter a number between ${MINvalue} and ${MAXvalue}.${CLRct}\n"
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
			DAYSTOKEEP="$(_GetConfigParam_ DAYSTOKEEP 30)"
			echo "$DAYSTOKEEP"
		;;
	esac
}

##----------------------------------------##
## Modified by Martinski W. [2025-Jun-06] ##
##----------------------------------------##
LastXResults()
{
	local MINvalue=5  MAXvalue=100  #Results#
	case "$1" in
		update)
			lastXResults="$(LastXResults check)"
			exitLoop=false
			while true
			do
				ScriptHeader
				printf " ${BOLD}Current number of results to display: ${GRNct}${lastXResults}${CLRct}\n\n"
				printf " ${BOLD}Please enter the maximum number of results\n"
				printf " to display in the WebUI [${GRNct}${MINvalue}-${MAXvalue}${CLRct}] (e=Exit):${CLRct}  "
				read -r lastx_choice
				if [ -z "$lastx_choice" ] && \
				   echo "$lastXResults" | grep -qE "^([1-9][0-9]{0,2})$" && \
				   [ "$lastXResults" -ge "$MINvalue" ] && [ "$lastXResults" -le "$MAXvalue" ]
				then
					exitLoop=true
					break
				elif [ "$lastx_choice" = "e" ]
				then
					exitLoop=true
					break
				elif ! Validate_Number "$lastx_choice"
				then
					printf "\n${ERR}Please enter a valid number [${MINvalue}-${MAXvalue}].${CLRct}\n"
					PressEnter
				elif [ "$lastx_choice" -lt "$MINvalue" ] || [ "$lastx_choice" -gt "$MAXvalue" ]
				then
					printf "\n${ERR}Please enter a number between ${MINvalue} and ${MAXvalue}.${CLRct}\n"
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
			LASTXRESULTS="$(_GetConfigParam_ LASTXRESULTS 10)"
			echo "$LASTXRESULTS"
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
## Modified by Martinski W. [2025-Jun-06] ##
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
			CRU_SCHHOUR="$(_GetConfigParam_ SCHHOURS '*')"
			CRU_SCHMINS="$(_GetConfigParam_ SCHMINS '*/5')"
			STARTUPLINECOUNTEXGEN="$(cru l | grep "${SCRIPT_NAME}_generate" | grep -c "^$CRU_SCHMINS $CRU_SCHHOUR [*] [*]")"
			if [ "$STARTUPLINECOUNTGEN" -gt 0 ] && [ "$STARTUPLINECOUNTEXGEN" -eq 0 ]
			then
				cru d "${SCRIPT_NAME}_generate"
				STARTUPLINECOUNTGEN="$(cru l | grep -c "${SCRIPT_NAME}_generate")"
			fi
			if [ "$STARTUPLINECOUNTGEN" -eq 0 ]
			then
				CRU_SCHDAYS="$(_GetConfigParam_ SCHDAYS '*' | sed 's/Sun/0/;s/Mon/1/;s/Tues/2/;s/Wed/3/;s/Thurs/4/;s/Fri/5/;s/Sat/6/;')"
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

##-------------------------------------##
## Added by Martinski W. [2025-Feb-11] ##
##-------------------------------------##
_Check_WebGUI_Page_Exists_()
{
   local webPageStr  webPageFile  theWebPage

   if [ ! -f "$TEMP_MENU_TREE" ]
   then echo "NONE" ; return 1 ; fi

   theWebPage="NONE"
   webPageStr="$(grep -E -m1 "^$webPageLineRegExp" "$TEMP_MENU_TREE")"
   if [ -n "$webPageStr" ]
   then
       webPageFile="$(echo "$webPageStr" | grep -owE "$webPageFileRegExp" | head -n1)"
       if [ -n "$webPageFile" ] && [ -s "${SCRIPT_WEBPAGE_DIR}/$webPageFile" ]
       then theWebPage="$webPageFile" ; fi
   fi
   echo "$theWebPage"
}

##----------------------------------------##
## Modified by Martinski W. [2025-Jun-19] ##
##----------------------------------------##
Get_WebUI_Page()
{
	if [ $# -eq 0 ] || [ -z "$1" ] || [ ! -s "$1" ]
	then MyWebPage="NONE" ; return 1 ; fi

	local webPageFile  webPagePath

	MyWebPage="$(_Check_WebGUI_Page_Exists_)"

	for indx in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20
	do
		webPageFile="user${indx}.asp"
		webPagePath="${SCRIPT_WEBPAGE_DIR}/$webPageFile"

		if [ -s "$webPagePath" ] && \
		   [ "$(md5sum < "$1")" = "$(md5sum < "$webPagePath")" ]
		then
			MyWebPage="$webPageFile"
			break
		elif [ "$MyWebPage" = "NONE" ] && [ ! -s "$webPagePath" ]
		then
			MyWebPage="$webPageFile"
		fi
	done
}

### function based on @dave14305's FlexQoS webconfigpage function ###
##----------------------------------------##
## Modified by Martinski W. [2025-Feb-11] ##
##----------------------------------------##
Get_WebUI_URL()
{
	local urlPage  urlProto  urlDomain  urlPort  lanPort

	if [ ! -f "$TEMP_MENU_TREE" ]
	then
		echo "**ERROR**: WebUI page NOT mounted"
		return 1
	fi

	urlPage="$(sed -nE "/$SCRIPT_NAME/ s/.*url\: \"(user[0-9]+\.asp)\".*/\1/p" "$TEMP_MENU_TREE")"

	if [ "$(nvram get http_enable)" -eq 1 ]; then
		urlProto="https"
	else
		urlProto="http"
	fi
	if [ -n "$(nvram get lan_domain)" ]; then
		urlDomain="$(nvram get lan_hostname).$(nvram get lan_domain)"
	else
		urlDomain="$(nvram get lan_ipaddr)"
	fi

	lanPort="$(nvram get ${urlProto}_lanport)"
	if [ "$lanPort" -eq 80 ] || [ "$lanPort" -eq 443 ]
	then
		urlPort=""
	else
		urlPort=":$lanPort"
	fi

	if echo "$urlPage" | grep -qE "^${webPageFileRegExp}$" && \
	   [ -s "${SCRIPT_WEBPAGE_DIR}/$urlPage" ]
	then
		echo "${urlProto}://${urlDomain}${urlPort}/${urlPage}" | tr "A-Z" "a-z"
	else
		echo "**ERROR**: WebUI page NOT found"
	fi
}

##-------------------------------------##
## Added by Martinski W. [2025-Feb-16] ##
##-------------------------------------##
_CreateMenuAddOnsSection_()
{
   if grep -qE "^${webPageMenuAddons}$" "$TEMP_MENU_TREE" && \
      grep -qE "${webPageHelpSupprt}$" "$TEMP_MENU_TREE"
   then return 0 ; fi

   lineinsBefore="$(($(grep -n "^exclude:" "$TEMP_MENU_TREE" | cut -f1 -d':') - 1))"

   sed -i "$lineinsBefore""i\
${BEGIN_MenuAddOnsTag}\n\
,\n{\n\
${webPageMenuAddons}\n\
index: \"menu_Addons\",\n\
tab: [\n\
{url: \"javascript:var helpwindow=window.open('\/ext\/shared-jy\/redirect.htm')\", ${webPageHelpSupprt}\n\
{url: \"NULL\", tabName: \"__INHERIT__\"}\n\
]\n}\n\
${ENDIN_MenuAddOnsTag}" "$TEMP_MENU_TREE"
}

### locking mechanism code credit to Martineau (@MartineauUK) ###
##----------------------------------------##
## Modified by Martinski W. [2025-Jun-20] ##
##----------------------------------------##
Mount_WebUI()
{
	Print_Output true "Mounting WebUI tab for $SCRIPT_NAME" "$PASS"

	LOCKFILE=/tmp/addonwebui.lock
	FD=386
	eval exec "$FD>$LOCKFILE"
	flock -x "$FD"
	Get_WebUI_Page "$SCRIPT_DIR/connmonstats_www.asp"
	if [ "$MyWebPage" = "NONE" ]
	then
		Print_Output true "**ERROR** Unable to mount $SCRIPT_NAME WebUI page." "$CRIT"
		flock -u "$FD"
		return 1
	fi
	cp -fp "$SCRIPT_DIR/connmonstats_www.asp" "$SCRIPT_WEBPAGE_DIR/$MyWebPage"
	echo "$SCRIPT_NAME" > "$SCRIPT_WEBPAGE_DIR/$(echo "$MyWebPage" | cut -f1 -d'.').title"

	if [ "$(/bin/uname -o)" = "ASUSWRT-Merlin" ]
	then
		if [ ! -f /tmp/index_style.css ]; then
			cp -fp /www/index_style.css /tmp/
		fi

		if ! grep -q '.menu_Addons' /tmp/index_style.css
		then
			echo ".menu_Addons { background: url(ext/shared-jy/addons.png); }" >> /tmp/index_style.css
		fi

		umount /www/index_style.css 2>/dev/null
		mount -o bind /tmp/index_style.css /www/index_style.css

		if [ ! -f "$TEMP_MENU_TREE" ]; then
			cp -fp /www/require/modules/menuTree.js "$TEMP_MENU_TREE"
		fi
		sed -i "\\~$MyWebPage~d" "$TEMP_MENU_TREE"

		_CreateMenuAddOnsSection_

		sed -i "/url: \"javascript:var helpwindow=window.open('\/ext\/shared-jy\/redirect.htm'/i {url: \"$MyWebPage\", tabName: \"$SCRIPT_NAME\"}," "$TEMP_MENU_TREE"

		umount /www/require/modules/menuTree.js 2>/dev/null
		mount -o bind "$TEMP_MENU_TREE" /www/require/modules/menuTree.js

		if [ ! -f /tmp/start_apply.htm  ]; then
			cp -fp /www/start_apply.htm /tmp/
		fi
		if ! grep -q 'addon_settings' /tmp/start_apply.htm
		then
			sed -i "/}else if(action_script == \"start_sig_check\"){/i }else if(action_script.indexOf(\"addon_settings\") != -1){ \/\/ do nothing" /tmp/start_apply.htm
		fi
		umount /www/start_apply.htm 2>/dev/null
		mount -o bind /tmp/start_apply.htm /www/start_apply.htm
	fi
	flock -u "$FD"

	Print_Output true "Mounted $SCRIPT_NAME WebUI page as $MyWebPage" "$PASS"
}

##-------------------------------------##
## Added by Martinski W. [2025-Feb-11] ##
##-------------------------------------##
_CheckFor_WebGUI_Page_()
{
   if [ "$(_Check_WebGUI_Page_Exists_)" = "NONE" ]
   then Mount_WebUI ; fi
}

##----------------------------------------##
## Modified by Martinski W. [2025-Jun-06] ##
##----------------------------------------##
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
		EXCLUDEFROMQOS="$(_GetConfigParam_ EXCLUDEFROMQOS 'true')"
		echo "$EXCLUDEFROMQOS"
	;;
	esac
}

##----------------------------------------##
## Modified by Martinski W. [2025-Jun-06] ##
##----------------------------------------##
AutomaticMode()
{
	case "$1" in
		enable)
			if AutomaticMode check
			then
			    printf "\nAutomatic ping tests are already ${GRNct}ENABLED${CLRct}.\n\n"
			    return 0
			fi
			sed -i 's/^AUTOMATICMODE=.*$/AUTOMATICMODE=true/' "$SCRIPT_CONF"
			Auto_Cron create 2>/dev/null
			printf "Automatic ping tests are now ${GRNct}ENABLED${CLRct}.\n\n"
			_UpdateAutomaticModeState_
		;;
		disable)
			if ! AutomaticMode check
			then
			    printf "\nAutomatic ping tests are already ${REDct}DISABLED${CLRct}.\n\n"
			    return 0
			fi
			sed -i 's/^AUTOMATICMODE=.*$/AUTOMATICMODE=false/' "$SCRIPT_CONF"
			Auto_Cron delete 2>/dev/null
			printf "Automatic ping tests are now ${REDct}DISABLED${CLRct}.\n\n"
			_UpdateAutomaticModeState_
		;;
		check)
			AUTOMATICMODE="$(_GetConfigParam_ AUTOMATICMODE 'true')"
			if [ "$AUTOMATICMODE" = "true" ]
			then return 0; else return 1; fi
		;;
	esac
}

##----------------------------------------##
## Modified by Martinski W. [2025-Jun-06] ##
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
			SCHDAYS="$(_GetConfigParam_ SCHDAYS '*')"
			SCHHOURS="$(_GetConfigParam_ SCHHOURS '*')"
			SCHMINS="$(_GetConfigParam_ SCHMINS '*/5')"
			echo "${SCHDAYS}|${SCHHOURS}|${SCHMINS}"
		;;
	esac
}

##----------------------------------------##
## Modified by Martinski W. [2025-Nov-15] ##
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
			if [ -d "/opt/share/$SCRIPT_NAME.d/csv" ] && \
			   [ -d "/jffs/addons/$SCRIPT_NAME.d/csv" ]
			then rm -fr "/opt/share/$SCRIPT_NAME.d/csv"
			fi
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
			if [ -d "/opt/share/$SCRIPT_NAME.d/userscripts.d" ] && \
			   [ -d "/jffs/addons/$SCRIPT_NAME.d/userscripts.d" ]
			then rm -fr "/opt/share/$SCRIPT_NAME.d/userscripts.d"
			fi
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
			if [ -d "/opt/share/$SCRIPT_NAME.d/csv" ] && \
			   [ -d "/jffs/addons/$SCRIPT_NAME.d/csv" ]
			then rm -fr "/jffs/addons/$SCRIPT_NAME.d/csv"
			fi
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
			if [ -d "/opt/share/$SCRIPT_NAME.d/userscripts.d" ] && \
			   [ -d "/jffs/addons/$SCRIPT_NAME.d/userscripts.d" ]
			then rm -fr "/jffs/addons/$SCRIPT_NAME.d/userscripts.d"
			fi
			mv -f "/opt/share/$SCRIPT_NAME.d/userscripts.d" "/jffs/addons/$SCRIPT_NAME.d/" 2>/dev/null
			SCRIPT_CONF="/jffs/addons/${SCRIPT_NAME}.d/config"
			CONNSTATS_DB="/jffs/addons/${SCRIPT_NAME}.d/connstats.db"
			CSV_OUTPUT_DIR="/jffs/addons/${SCRIPT_NAME}.d/csv"
			ScriptStorageLocation load true
			sleep 2
			;;
		check)
			STORAGELOCATION="$(_GetConfigParam_ STORAGELOCATION jffs)"
			echo "$STORAGELOCATION"
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

##----------------------------------------##
## Modified by Martinski W. [2025-Jun-06] ##
##----------------------------------------##
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
			OUTPUTTIMEMODE="$(_GetConfigParam_ OUTPUTTIMEMODE unix)"
			echo "$OUTPUTTIMEMODE"
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
## Modified by Martinski W. [2025-Feb-05] ##
##----------------------------------------##
##--------------------------------------------------------##
## Minimum Reserved JFFS Available Free Space is roughly
## about 20% of total space or about 9MB to 10MB.
##--------------------------------------------------------##
_JFFS_MinReservedFreeSpace_()
{
   local jffsAllxSpace  jffsMinxSpace

   if ! jffsAllxSpace="$(_Get_JFFS_Space_ ALL KB)"
   then echo "$jffsAllxSpace" ; return 1 ; fi
   jffsAllxSpace="$(echo "$jffsAllxSpace" | awk '{printf("%s", $1 * 1024);}')"

   jffsMinxSpace="$(echo "$jffsAllxSpace" | awk '{printf("%d", $1 * 20 / 100);}')"
   if [ "$(echo "$jffsMinxSpace $ni9MByte" | awk -F ' ' '{print ($1 < $2)}')" -eq 1 ]
   then jffsMinxSpace="$ni9MByte"
   elif [ "$(echo "$jffsMinxSpace $tenMByte" | awk -F ' ' '{print ($1 > $2)}')" -eq 1 ]
   then jffsMinxSpace="$tenMByte"
   fi
   echo "$jffsMinxSpace" ; return 0
}

##----------------------------------------##
## Modified by Martinski W. [2025-Feb-05] ##
##----------------------------------------##
##--------------------------------------------------------##
## Check JFFS free space *BEFORE* moving files from USB.
##--------------------------------------------------------##
_Check_JFFS_SpaceAvailable_()
{
   local requiredSpace  jffsFreeSpace  jffsMinxSpace
   if [ $# -eq 0 ] || [ -z "$1" ] || [ ! -d "$1" ] ; then return 0 ; fi

   [ "$1" = "/jffs/addons/${SCRIPT_NAME}.d" ] && return 0

   if ! jffsFreeSpace="$(_Get_JFFS_Space_ FREE KB)" ; then return 1 ; fi
   if ! jffsMinxSpace="$(_JFFS_MinReservedFreeSpace_)" ; then return 1 ; fi
   jffsFreeSpace="$(echo "$jffsFreeSpace" | awk '{printf("%s", $1 * 1024);}')"

   requiredSpace="$(du -kc "$1" | grep -w 'total$' | awk -F ' ' '{print $1}')"
   requiredSpace="$(echo "$requiredSpace" | awk '{printf("%s", $1 * 1024);}')"
   requiredSpace="$(echo "$requiredSpace $jffsMinxSpace" | awk -F ' ' '{printf("%s", $1 + $2);}')"
   if [ "$(echo "$requiredSpace $jffsFreeSpace" | awk -F ' ' '{print ($1 < $2)}')" -eq 1 ]
   then return 0 ; fi

   ## Current JFFS Available Free Space is NOT sufficient ##
   requiredSpace="$(du -hc "$1" | grep -w 'total$' | awk -F ' ' '{print $1}')"
   errorMsg1="Not enough free space [$(_Get_JFFS_Space_ FREE HR)] available in JFFS."
   errorMsg2="Minimum storage space required: $requiredSpace"
   Print_Output true "${errorMsg1} ${errorMsg2}" "$CRIT"
   return 1
}

##-------------------------------------##
## Added by Martinski W. [2025-Jun-19] ##
##-------------------------------------##
_EscapeChars_()
{ printf "%s" "$1" | sed 's/[][\/$.*^&-]/\\&/g' ; }

##-------------------------------------##
## Added by Martinski W. [2025-Feb-05] ##
##-------------------------------------##
_WriteVarDefToJSFile_()
{
   if [ $# -lt 2 ] || [ -z "$1" ] || [ -z "$2" ]
   then return 1; fi

   local varValue  sedValue
   if [ $# -eq 3 ] && [ "$3" = "true" ]
   then
       varValue="$2"
   else
       varValue="'${2}'"
       sedValue="$(_EscapeChars_ "$varValue")"
   fi

   local targetJSfile="$SCRIPT_STORAGE_DIR/connstatstext.js"
   if [ ! -s "$targetJSfile" ]
   then
       echo "var $1 = ${varValue};" > "$targetJSfile"
   elif
      ! grep -q "^var $1 =.*" "$targetJSfile"
   then
       sed -i "1 i var $1 = ${varValue};" "$targetJSfile"
   elif
      ! grep -q "^var $1 = ${sedValue};" "$targetJSfile"
   then
       sed -i "s/^var $1 =.*/var $1 = ${sedValue};/" "$targetJSfile"
   fi
}

##-------------------------------------##
## Added by Martinski W. [2025-Feb-05] ##
##-------------------------------------##
_DelVarDefFromJSFile_()
{
   if [ $# -eq 0 ] || [ -z "$1" ] ; then return 1; fi

   local targetJSfile="$SCRIPT_STORAGE_DIR/connstatstext.js"
   if [ -s "$targetJSfile" ] && \
      grep -q "^var $1 =.*" "$targetJSfile"
   then
       sed -i "/^var $1 =.*/d" "$targetJSfile"
   fi
}

##----------------------------------------##
## Modified by Martinski W. [2025-Feb-05] ##
##----------------------------------------##
JFFS_WarningLogTime()
{
   case "$1" in
       update)
           sed -i 's/^JFFS_MSGLOGTIME=.*$/JFFS_MSGLOGTIME='"$2"'/' "$SCRIPT_CONF"
           ;;
       check)
           JFFS_MSGLOGTIME="$(_GetConfigParam_ JFFS_MSGLOGTIME 0)"
           if ! echo "$JFFS_MSGLOGTIME" | grep -qE "^[0-9]+$"
           then JFFS_MSGLOGTIME=0
           fi
           echo "$JFFS_MSGLOGTIME"
           ;;
   esac
}

##----------------------------------------##
## Modified by Martinski W. [2025-Feb-20] ##
##----------------------------------------##
_JFFS_WarnLowFreeSpace_()
{
   if [ $# -eq 0 ] || [ -z "$1" ] ; then return 0 ; fi
   local jffsWarningLogFreq  jffsWarningLogTime  storageLocStr
   local logPriNum  logTagStr  logMsgStr  currTimeSecs  currTimeDiff

   storageLocStr="$(ScriptStorageLocation check | tr 'a-z' 'A-Z')"
   if [ "$storageLocStr" = "JFFS" ]
   then
       if [ "$JFFS_LowFreeSpaceStatus" = "WARNING2" ]
       then
           logPriNum=2
           logTagStr="**ALERT**"
           jffsWarningLogFreq="$_12Hours"
       else
           logPriNum=3
           logTagStr="**WARNING**"
           jffsWarningLogFreq="$_24Hours"
       fi
   else
       if [ "$JFFS_LowFreeSpaceStatus" = "WARNING2" ]
       then
           logPriNum=3
           logTagStr="**WARNING**"
           jffsWarningLogFreq="$_24Hours"
       else
           logPriNum=4
           logTagStr="**NOTICE**"
           jffsWarningLogFreq="$_36Hours"
       fi
   fi
   jffsWarningLogTime="$(JFFS_WarningLogTime check)"

   currTimeSecs="$(date +'%s')"
   currTimeDiff="$(echo "$currTimeSecs $jffsWarningLogTime" | awk -F ' ' '{printf("%s", $1 - $2);}')"
   if [ "$currTimeDiff" -ge "$jffsWarningLogFreq" ]
   then
       JFFS_WarningLogTime update "$currTimeSecs"
       logMsgStr="${logTagStr} JFFS Available Free Space ($1) is getting LOW."
       logger -t "${SCRIPT_NAME}_[$$]" -p $logPriNum "$logMsgStr"
   fi
}

##----------------------------------------##
## Modified by Martinski W. [2025-Feb-20] ##
##----------------------------------------##
_UpdateJFFS_FreeSpaceInfo_()
{
   local jffsFreeSpaceHR  jffsFreeSpace  jffsMinxSpace
   [ ! -d "$SCRIPT_STORAGE_DIR" ] && return 1

   jffsFreeSpaceHR="$(_Get_JFFS_Space_ FREE HRx)"
   _DelVarDefFromJSFile_ "jffsAvailableSpace"
   _WriteVarDefToJSFile_ "jffsAvailableSpaceStr" "$jffsFreeSpaceHR"

   if ! jffsFreeSpace="$(_Get_JFFS_Space_ FREE KB)" ; then return 1 ; fi
   if ! jffsMinxSpace="$(_JFFS_MinReservedFreeSpace_)" ; then return 1 ; fi
   jffsFreeSpace="$(echo "$jffsFreeSpace" | awk '{printf("%s", $1 * 1024);}')"

   JFFS_LowFreeSpaceStatus="OK"
   ## Warning Level 1 if JFFS Available Free Space is LESS than Minimum Reserved ##
   if [ "$(echo "$jffsFreeSpace $jffsMinxSpace" | awk -F ' ' '{print ($1 < $2)}')" -eq 1 ]
   then
       JFFS_LowFreeSpaceStatus="WARNING1"
       ## Warning Level 2 if JFFS Available Free Space is LESS than 8.0MB ##
       if [ "$(echo "$jffsFreeSpace $ei8MByte" | awk -F ' ' '{print ($1 < $2)}')" -eq 1 ]
       then
           JFFS_LowFreeSpaceStatus="WARNING2"
       fi
       _JFFS_WarnLowFreeSpace_ "$jffsFreeSpaceHR"
   fi
   _WriteVarDefToJSFile_ "jffsAvailableSpaceLow" "$JFFS_LowFreeSpaceStatus"
}

##----------------------------------------##
## Modified by Martinski W. [2025-Feb-05] ##
##----------------------------------------##
_UpdateAutomaticModeState_()
{
   local automaticModeStatus
   [ ! -d "$SCRIPT_STORAGE_DIR" ] && return 1

   if AutomaticMode check
   then automaticModeStatus="ENABLED"
   else automaticModeStatus="DISABLED"
   fi
   _WriteVarDefToJSFile_ "automaticModeState" "$automaticModeStatus"
}

##----------------------------------------##
## Modified by Martinski W. [2025-Feb-05] ##
##----------------------------------------##
_UpdateDatabaseFileSizeInfo_()
{
   local databaseFileSize
   [ ! -d "$SCRIPT_STORAGE_DIR" ] && return 1

   _UpdateJFFS_FreeSpaceInfo_
   databaseFileSize="$(_GetFileSize_ "$CONNSTATS_DB" HRx)"
   _WriteVarDefToJSFile_ "sqlDatabaseFileSize" "$databaseFileSize"
   _UpdateAutomaticModeState_
}

##-------------------------------------##
## Added by Martinski W. [2025-Jun-04] ##
##-------------------------------------##
_SQLCheckDBLogFileSize_()
{
   if [ "$(_GetFileSize_ "$sqlDBLogFilePath")" -gt "$sqlDBLogFileSize" ]
   then
       cp -fp "$sqlDBLogFilePath" "${sqlDBLogFilePath}.BAK"
       echo -n > "$sqlDBLogFilePath"
   fi
}

_SQLGetDBLogTimeStamp_()
{ printf "[$(date +"$sqlDBLogDateTime")]" ; }

##----------------------------------------##
## Modified by Martinski W. [2025-Jul-20] ##
##----------------------------------------##
readonly errorMsgsRegExp="Parse error|Runtime error|Error:"
readonly corruptedBinExp="Illegal instruction|SQLite header and source version mismatch"
readonly sqlErrorsRegExp="($errorMsgsRegExp|$corruptedBinExp)"
readonly sqlLockedRegExp="(Parse|Runtime) error .*: database is locked"
readonly sqlCorruptedMsg="SQLite3 binary is likely corrupted. Remove and reinstall the Entware package."
##-----------------------------------------------------------------------
_ApplyDatabaseSQLCmds_()
{
    local errorCount=0  maxErrorCount=3  callFlag
    local triesCount=0  maxTriesCount=10  sqlErrorMsg
    local tempLogFilePath="/tmp/${SCRIPT_NAME}Stats_TMP_$$.LOG"
    local debgLogFilePath="/tmp/${SCRIPT_NAME}Stats_DEBUG_$$.LOG"
    local debgLogSQLcmds=false

    if [ $# -gt 1 ] && [ -n "$2" ]
    then callFlag="$2"
    else callFlag="err"
    fi

    resultStr=""
    foundError=false ; foundLocked=false
    rm -f "$tempLogFilePath" "$debgLogFilePath"

    while [ "$errorCount" -lt "$maxErrorCount" ] && \
          [ "$((triesCount++))" -lt "$maxTriesCount" ]
    do
        if "$SQLITE3_PATH" "$CONNSTATS_DB" < "$1" >> "$tempLogFilePath" 2>&1
        then foundError=false ; foundLocked=false ; break
        fi
        sqlErrorMsg="$(cat "$tempLogFilePath")"

        if echo "$sqlErrorMsg" | grep -qE "^$sqlErrorsRegExp"
        then
            if echo "$sqlErrorMsg" | grep -qE "^$sqlLockedRegExp"
            then
                foundLocked=true ; maxTriesCount=25
                echo -n > "$tempLogFilePath"  ##Clear for next error found##
                sleep 2 ; continue
            fi
            if echo "$sqlErrorMsg" | grep -qE "^($corruptedBinExp)"
            then  ## Corrupted SQLite3 Binary?? ##
                errorCount="$maxErrorCount"
                echo "$sqlCorruptedMsg" >> "$tempLogFilePath"
                Print_Output true "SQLite3 Fatal Error[$callFlag]: $sqlCorruptedMsg" "$CRIT"
            fi
            errorCount="$((errorCount + 1))"
            foundError=true ; foundLocked=false
            Print_Output true "SQLite3 Failure[$callFlag]: $sqlErrorMsg" "$ERR"
        fi

        if ! "$debgLogSQLcmds"
        then
           debgLogSQLcmds=true
           {
              echo "==========================================="
              echo "$(_SQLGetDBLogTimeStamp_) BEGIN [$callFlag]"
              echo "Database: $CONNSTATS_DB"
           } > "$debgLogFilePath"
        fi
        cat "$tempLogFilePath" >> "$debgLogFilePath"
        echo -n > "$tempLogFilePath"  ##Clear for next error found##
        [ "$triesCount" -ge "$maxTriesCount" ] && break
        [ "$errorCount" -ge "$maxErrorCount" ] && break
        sleep 1
    done

    if "$debgLogSQLcmds"
    then
       {
          echo "--------------------------------"
          cat "$1"
          echo "--------------------------------"
          echo "$(_SQLGetDBLogTimeStamp_) END [$callFlag]"
       } >> "$debgLogFilePath"
       cat "$debgLogFilePath" >> "$sqlDBLogFilePath"
    fi

    rm -f "$tempLogFilePath" "$debgLogFilePath"
    if "$foundError"
    then resultStr="reported error(s)."
    elif "$foundLocked"
    then resultStr="found database locked."
    else resultStr="completed successfully."
    fi
    if "$foundError" || "$foundLocked"
    then
        Print_Output true "SQLite process[$callFlag] ${resultStr}" "$ERR"
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
## Modified by Martinski W. [2025-Dec-10] ##
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

	pingFile="/tmp/pingfile.txt"
	resultFile="$SCRIPT_WEB_DIR/ping-result.txt"
	local pingDuration="$(PingDuration check)"
	local pingTarget="$(PingServer check)"
	local pingTestOK  pingTargetIP  fullPingTarget
	local stoppedQoS  nvramQoSenable  nvramQoStype

	rm -f "$pingFile" "$resultFile"

	echo 'var connmonstatus = "InProgress";' > "$SCRIPT_WEB_DIR/detect_connmon.js"

	if ! expr "$pingTarget" : '[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*$' >/dev/null && \
	   nslookup "$pingTarget" >/dev/null 2>&1
	then
		pingTargetIP="$(dig +short +answer "$pingTarget" | head -n 1)"
		fullPingTarget="$pingTarget ($pingTargetIP)"
	else
		pingTargetIP="$pingTarget"
		fullPingTarget="$pingTarget"
	fi

	stoppedQoS=false
	if [ "$(ExcludeFromQoS check)" = "true" ]
	then
		nvramQoStype="$(nvram get qos_type)"
		nvramQoSenable="$(nvram get qos_enable)"
		if [ "$nvramQoSenable" -eq 1 ] && [ "$nvramQoStype" -eq 1 ]
		then
			Print_Output true "Excluding QoS [Type: $nvramQoStype] from ping tests..." "$WARN"
			for ACTION in -D -A
			do
				iptables "$ACTION" OUTPUT -p icmp -j MARK --set-xmark 0x80000000/0xC0000000 2>/dev/null
				iptables -t mangle "$ACTION" OUTPUT -p icmp -j MARK --set-xmark 0x80000000/0xC0000000 2>/dev/null
				iptables -t mangle "$ACTION" POSTROUTING -p icmp -j MARK --set-xmark 0x80000000/0xC0000000 2>/dev/null
			done
 			sleep 3 ; stoppedQoS=true
			Print_Output true "QoS [Type: $nvramQoStype] is excluded." "$WARN"
		##
		elif [ "$nvramQoSenable" -eq 1 ] && [ "$nvramQoStype" -ne 1 ] && [ -f /tmp/qos ]
		then
			Print_Output true "Stopping QoS [Type: $nvramQoStype] for ping tests..." "$WARN"
			/tmp/qos stop >/dev/null 2>&1
			sleep 4 ; stoppedQoS=true
			Print_Output true "QoS [Type: $nvramQoStype] was stopped." "$WARN"
		##
		elif [ "$nvramQoSenable" -eq 0 ] && [ -f /jffs/addons/cake-qos/cake-qos ]
		then
			Print_Output true "Stopping CAKE QoS for ping tests..." "$WARN"
			/jffs/addons/cake-qos/cake-qos stop >/dev/null 2>&1
			sleep 4 ; stoppedQoS=true
			Print_Output true "CAKE QoS was stopped." "$WARN"
		fi
	fi

	Print_Output true "$pingDuration second ping test to $pingTarget starting..." "$PASS"

	if ping -w "$pingDuration" "$pingTargetIP" > "$pingFile"
	then pingTestOK=true
	else pingTestOK=false
	fi

	if [ "$stoppedQoS" = "true" ]
	then
		nvramQoStype="$(nvram get qos_type)"
		nvramQoSenable="$(nvram get qos_enable)"
		if [ "$nvramQoSenable" -eq 1 ] && [ "$nvramQoStype" -eq 1 ]
		then
			Print_Output true "Restarting QoS [Type: $nvramQoStype]..." "$WARN"
			iptables -D OUTPUT -p icmp -j MARK --set-xmark 0x80000000/0xC0000000 2>/dev/null
			iptables -t mangle -D OUTPUT -p icmp -j MARK --set-xmark 0x80000000/0xC0000000 2>/dev/null
			iptables -t mangle -D POSTROUTING -p icmp -j MARK --set-xmark 0x80000000/0xC0000000 2>/dev/null
			sleep 2 ; stoppedQoS=false
			Print_Output true "QoS [Type: $nvramQoStype] was restarted." "$WARN"
		##
		elif [ "$nvramQoSenable" -eq 1 ] && [ "$nvramQoStype" -ne 1 ] && [ -f /tmp/qos ]
		then
			Print_Output true "Restarting QoS [Type: $nvramQoStype]..." "$WARN"
			/tmp/qos start >/dev/null 2>&1
			sleep 3 ; stoppedQoS=false
			Print_Output true "QoS [Type: $nvramQoStype] was restarted." "$WARN"
		##
		elif [ "$nvramQoSenable" -eq 0 ] && [ -f /jffs/addons/cake-qos/cake-qos ]
		then
			Print_Output true "Restarting CAKE QoS..." "$WARN"
			/jffs/addons/cake-qos/cake-qos start >/dev/null 2>&1
			sleep 3 ; stoppedQoS=false
			Print_Output true "CAKE QoS was restarted." "$WARN"
		fi
	fi

	ScriptStorageLocation load

	PREVPING=0
	TOTALDIFF=0
	COUNTER=1
	PINGLIST="$(grep -E 'seq=.+ ttl=.+ time=.+' "$pingFile")"
	PINGCOUNT="$(echo "$PINGLIST" | sed '/^\s*$/d' | wc -l)"
	DIFFCOUNT="$((PINGCOUNT - 1))"

	if "$pingTestOK" && [ "$PINGCOUNT" -gt 0 ]
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
	timenowfriendly="$(/bin/date +'%c')"

	pkt_trans=0 ; pkt_recvd=0
	pingAvrge=0.0 ; jitterVal=0.0 ; lineQualt=0.0

	## Double-check to make sure we have all the required data ##
	if "$pingTestOK" && [ "$PINGCOUNT" -gt 1 ] && \
	   grep -qE 'round-trip min/avg/max =.+' "$pingFile" && \
	   grep -qE 'packets transmitted,.+ packets received,.+' "$pingFile"
	then
		pingAvrge="$(tail -n 1 "$pingFile" | cut -f4 -d'/')"
		jitterVal="$(echo "$TOTALDIFF" "$DIFFCOUNT" | awk '{printf "%4.3f\n",$1/$2}')"
		pkt_trans="$(tail -n 2 "$pingFile" | head -n 1 | cut -f1 -d',' | cut -f1 -d' ')"
		pkt_recvd="$(tail -n 2 "$pingFile" | head -n 1 | cut -f2 -d',' | cut -f2 -d' ')"
		lineQualt="$(echo "$pkt_recvd" "$pkt_trans" | awk '{printf "%4.3f\n",100*$1/$2}')"
	else
		pingTestOK=false
		Print_Output true "Ping test to '$fullPingTarget' from connmon failed." "$CRIT"
		{
		   printf "Ping test to '$fullPingTarget' failed.\n"
		   printf "Check if WAN interface and specified ping target are up.\n"
		} > "$resultFile"
		echo 'var connmonstatus = "Error";' > "$SCRIPT_WEB_DIR/detect_connmon.js"
		TriggerNotifications PingTestFailed "$timenowfriendly" "$fullPingTarget"
		rm -f "$pingFile"
	fi

	Process_Upgrade

	{
	   echo "PRAGMA temp_store=1;"
	   echo "PRAGMA journal_mode=TRUNCATE;"
	   echo "CREATE TABLE IF NOT EXISTS [connstats] ([StatID] INTEGER PRIMARY KEY NOT NULL,[Timestamp] NUMERIC NOT NULL,[Ping] REAL NOT NULL,[Jitter] REAL NOT NULL,[LineQuality] REAL NOT NULL,[PingTarget] TEXT NOT NULL,[PingDuration] NUMERIC);"
	   echo "INSERT INTO connstats ([Timestamp],[Ping],[Jitter],[LineQuality],[PingTarget],[PingDuration]) values($timenow,$pingAvrge,$jitterVal,$lineQualt,'$fullPingTarget',$pingDuration);"
	} > /tmp/connmon-stats.sql
	_ApplyDatabaseSQLCmds_ /tmp/connmon-stats.sql png1

	echo 'var connmonstatus = "GenerateCSV";' > "$SCRIPT_WEB_DIR/detect_connmon.js"
	Generate_CSVs

	_UpdateDatabaseFileSizeInfo_

	echo "Stats last updated: $timenowfriendly" > /tmp/connstatstitle.txt
	WriteStats_ToJS /tmp/connstatstitle.txt "$SCRIPT_STORAGE_DIR/connstatstext.js" setConnmonStatsTitle statstitle
	rm -f "$pingFile" /tmp/connstatstitle.txt

	if ! "$pingTestOK"
	then
		echo 'var connmonstatus = "Error";' > "$SCRIPT_WEB_DIR/detect_connmon.js"
		return 1
	fi

	Print_Output false "Test results: Ping $pingAvrge ms - Jitter $jitterVal ms - Line Quality ${lineQualt}%" "$PASS"
	{
		printf "Ping test results:\n"
		printf "\nPing %s ms - Jitter %s ms - Line Quality %s %%\n" "$pingAvrge" "$jitterVal" "$lineQualt"
	} > "$resultFile"

	TriggerNotifications PingTestOK "$timenowfriendly" "$pingAvrge ms" "$jitterVal ms" "$lineQualt %" "$timenow" "$fullPingTarget"

	if [ "$(echo "$pingAvrge" "$(Conf_Parameters check NOTIFICATIONS_PINGTHRESHOLD_VALUE)" | awk '{print ($1 > $2)}')" -eq 1 ]
	then
		TriggerNotifications PingThreshold "$timenowfriendly" "$pingAvrge ms" "$(Conf_Parameters check NOTIFICATIONS_PINGTHRESHOLD_VALUE) ms" "$fullPingTarget"
	fi

	if [ "$(echo "$jitterVal" "$(Conf_Parameters check NOTIFICATIONS_JITTERTHRESHOLD_VALUE)" | awk '{print ($1 > $2)}')" -eq 1 ]
	then
		TriggerNotifications JitterThreshold "$timenowfriendly" "$jitterVal ms" "$(Conf_Parameters check NOTIFICATIONS_JITTERTHRESHOLD_VALUE) ms" "$fullPingTarget"
	fi

	if [ "$(echo "$lineQualt" "$(Conf_Parameters check NOTIFICATIONS_LINEQUALITYTHRESHOLD_VALUE)" | awk '{print ($1 < $2)}')" -eq 1 ]
	then
		TriggerNotifications LineQualityThreshold "$timenowfriendly" "$lineQualt %" "$(Conf_Parameters check NOTIFICATIONS_LINEQUALITYTHRESHOLD_VALUE) %" "$fullPingTarget"
	fi
	echo 'var connmonstatus = "Done";' > "$SCRIPT_WEB_DIR/detect_connmon.js"
}

##----------------------------------------##
## Modified by Martinski W. [2025-Jun-20] ##
##----------------------------------------##
Generate_CSVs()
{
	local foundError  foundLocked  resultStr  sqlProcSuccess

	Process_Upgrade
	renice 15 $$

	OUTPUTTIMEMODE="$(OutputTimeMode check)"
	TZ="$(cat /etc/TZ)"
	export TZ
	timenow="$(/bin/date +"%s")"
	timenowfriendly="$(/bin/date +"%c")"

	metricList="Ping Jitter LineQuality"
	for metric in $metricList
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

	sqlProcSuccess=true
	{
	   echo ".mode csv"
	   echo ".headers on"
	   echo ".output $CSV_OUTPUT_DIR/CompleteResults.htm"
	   echo "PRAGMA temp_store=1;"
	   echo "SELECT [Timestamp],[Ping],[Jitter],[LineQuality],[PingTarget],[PingDuration] FROM connstats WHERE ([Timestamp] >= strftime('%s',datetime($timenow,'unixepoch','-$(DaysToKeep check) day'))) ORDER BY [Timestamp] DESC;"
    } > /tmp/connmon-complete.sql
	_ApplyDatabaseSQLCmds_ /tmp/connmon-complete.sql gnr10
	rm -f /tmp/connmon-complete.sql

	if "$foundError" || "$foundLocked" || \
	   [ ! -f "$CSV_OUTPUT_DIR/CompleteResults.htm" ]
	then sqlProcSuccess=false ; fi

	dos2unix "$CSV_OUTPUT_DIR/"*.htm

	tmpOutputDir="/tmp/${SCRIPT_NAME}results"
	mkdir -p "$tmpOutputDir"

	if [ -f "$CSV_OUTPUT_DIR/CompleteResults.htm" ]
	then
		sed -i 's/"//g' "$CSV_OUTPUT_DIR/CompleteResults.htm"
		mv -f "$CSV_OUTPUT_DIR/CompleteResults.htm" "$tmpOutputDir/CompleteResults.htm"
	fi

	if [ "$OUTPUTTIMEMODE" = "unix" ]
	then
		find "$tmpOutputDir/" -name '*.htm' -exec sh -c 'i="$1"; mv -- "$i" "${i%.htm}.csv"' _ {} \;
	elif [ "$OUTPUTTIMEMODE" = "non-unix" ]
	then
		for i in "$tmpOutputDir/"*".htm"
		do
			awk -F"," 'NR==1 {OFS=","; print} NR>1 {OFS=","; $1=strftime("%Y-%m-%d %H:%M:%S", $1); print }' "$i" > "$i.out"
		done

		find "$tmpOutputDir/" -name '*.htm.out' -exec sh -c 'i="$1"; mv -- "$i" "${i%.htm.out}.csv"' _ {} \;
		rm -f "$tmpOutputDir/"*.htm
	fi

	[ -f "$tmpOutputDir/CompleteResults.csv" ] && \
	mv -f "$tmpOutputDir/CompleteResults.csv" "$CSV_OUTPUT_DIR/CompleteResults.htm"

	rm -f "$CSV_OUTPUT_DIR/connmondata.zip"
	rm -rf "$tmpOutputDir"
	renice 0 $$
}

##----------------------------------------##
## Modified by Martinski W. [2025-Jun-20] ##
##----------------------------------------##
Generate_LastXResults()
{
	local foundError  foundLocked  resultStr  sqlProcSuccess

	rm -f "$SCRIPT_STORAGE_DIR/connjs.js"
	rm -f "$SCRIPT_STORAGE_DIR/lastx.htm"
	rm -f /tmp/connmon-lastx.csv

	sqlProcSuccess=true
	{
	   echo ".mode csv"
	   echo ".output /tmp/connmon-lastx.csv"
	   echo "PRAGMA temp_store=1;"
	   echo "SELECT [Timestamp],[Ping],[Jitter],[LineQuality],[PingTarget],[PingDuration] FROM connstats ORDER BY [Timestamp] DESC LIMIT $(LastXResults check);"
	} > /tmp/connmon-lastx.sql
	_ApplyDatabaseSQLCmds_ /tmp/connmon-lastx.sql glx1
	rm -f /tmp/connmon-lastx.sql

	if "$foundError" || "$foundLocked" || [ ! -f /tmp/connmon-lastx.csv ]
	then
		sqlProcSuccess=false
		Print_Output true "**ERROR**: Generate Last X Results Failed" "$ERR"
	fi

	if "$sqlProcSuccess"
	then
		sed -i 's/"//g' /tmp/connmon-lastx.csv
		mv -f /tmp/connmon-lastx.csv "$SCRIPT_STORAGE_DIR/lastx.csv"
	fi
}

##----------------------------------------##
## Modified by Martinski W. [2025-Feb-18] ##
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
        } > /tmp/connmon-reset.sql
		_ApplyDatabaseSQLCmds_ /tmp/connmon-reset.sql rst1
		rm -f /tmp/connmon-reset.sql

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
## Modified by Martinski W. [2025-Feb-05] ##
##----------------------------------------##
Process_Upgrade()
{
	local foundError  foundLocked  resultStr  doUpdateDB=false

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
		doUpdateDB=true
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
		doUpdateDB=true
	fi
	if [ ! -f "$SCRIPT_STORAGE_DIR/lastx.csv" ]
	then
		Generate_LastXResults
		doUpdateDB=true
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
		doUpdateDB=true
		echo "Stats last updated: Not yet updated" > /tmp/connstatstitle.txt
		WriteStats_ToJS /tmp/connstatstitle.txt "$SCRIPT_STORAGE_DIR/connstatstext.js" setConnmonStatsTitle statstitle
	fi
	"$doUpdateDB" && _UpdateDatabaseFileSizeInfo_
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

##----------------------------------------##
## Modified by Martinski W. [2025-Dec-08] ##
##----------------------------------------##
PressEnter()
{
	if ! "$isInteractive"
	then return 0
	fi
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
	if [ $# -eq 0 ] || [ -z "$1" ]
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
		printf "\n${BOLD}Enter email address:${CLEARFORMAT}  "
		read -r EMAIL_ADDRESS
		if [ "$EMAIL_ADDRESS" = "e" ]
		then
			EMAIL_ADDRESS=""
			break
		elif ! echo "$EMAIL_ADDRESS" | grep -qE "$EMAIL_REGEX"
		then
			printf "\n${ERR}Please enter a valid email address${CLEARFORMAT}\n"
		else
			printf "${BOLD}${WARN}Is this correct? (y/n):${CLEARFORMAT}  "
			read -r CONFIRM_INPUT
			case "$CONFIRM_INPUT" in
				y|Y)
					if [ "$1" = "From" ]
					then
						sed -i 's/^FROM_ADDRESS=.*$/FROM_ADDRESS="'"$EMAIL_ADDRESS"'"/' "$EMAIL_CONF"
					elif [ "$1" = "To" ]
					then
						sed -i 's/^TO_ADDRESS=.*$/TO_ADDRESS="'"$EMAIL_ADDRESS"'"/' "$EMAIL_CONF"
					elif [ "$1" = "Override" ]
					then
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
		if [ "$FRIENDLY_ROUTER_NAME" = "e" ]
		then
			FRIENDLY_ROUTER_NAME=""
			break
		elif [ "$(printf "%s" "$FRIENDLY_ROUTER_NAME" | wc -m)" -lt 2 ] || [ "$(printf "%s" "$FRIENDLY_ROUTER_NAME" | wc -m)" -gt 16 ]
		then
			printf "\\n${ERR}Router friendly name must be between 2 and 16 characters${CLEARFORMAT}\\n"
		elif echo "$FRIENDLY_ROUTER_NAME" | grep -q "^-" || echo "$FRIENDLY_ROUTER_NAME" | grep -q "^_"
		then
			printf "\\n${ERR}Router friendly name must not start with dash (-) or underscore (_)${CLEARFORMAT}\\n"
		elif echo "$FRIENDLY_ROUTER_NAME" | grep -q "[-]$" || echo "$FRIENDLY_ROUTER_NAME" | grep -q "_$"
		then
			printf "\\n${ERR}Router friendly name must not end with dash (-) or underscore (_)${CLEARFORMAT}\\n"
		elif ! echo "$FRIENDLY_ROUTER_NAME" | grep -qE "^[a-zA-Z0-9_\-]*$"
		then
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

Email_Server()
{
	SMTP=""
	while true
	do
		printf "\\n${BOLD}Enter SMTP Server:${CLEARFORMAT}  "
		read -r SMTP
		if [ "$SMTP" = "e" ]
		then
			SMTP=""
			break
		elif ! Validate_Domain "$SMTP"
		then
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

Email_Protocol()
{
	while true
	do
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
	while true
	do
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
	while true
	do
		printf "\n${BOLD}Enter Password:${CLEARFORMAT}  "
		read -r PASSWORD
		if [ "$PASSWORD" = "e" ]
		then
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
	if [ -f /usr/sbin/openssl11 ]
	then
		printf "$1" | /usr/sbin/openssl11 aes-256-cbc $emailPwEnc -out "$PWENCFILE" -pass pass:ditbabot,isoi
	else
		printf "$1" | /usr/sbin/openssl aes-256-cbc $emailPwEnc -out "$PWENCFILE" -pass pass:ditbabot,isoi
	fi
}

Email_Decrypt_Password()
{
	PWENCFILE="$EMAIL_DIR/emailpw.enc"
	if /usr/sbin/openssl aes-256-cbc -d -in "$PWENCFILE" -pass pass:ditbabot,isoi >/dev/null 2>&1
	then
		# old OpenSSL 1.0.x
		PASSWORD="$(/usr/sbin/openssl aes-256-cbc -d -in "$PWENCFILE" -pass pass:ditbabot,isoi 2>/dev/null)"
	elif /usr/sbin/openssl aes-256-cbc -d -md md5 -in "$PWENCFILE" -pass pass:ditbabot,isoi >/dev/null 2>&1
	then
		# new OpenSSL 1.1.x non-converted password
		PASSWORD="$(/usr/sbin/openssl aes-256-cbc -d -md md5 -in "$PWENCFILE" -pass pass:ditbabot,isoi 2>/dev/null)"
	elif /usr/sbin/openssl aes-256-cbc $emailPwEnc -d -in "$PWENCFILE" -pass pass:ditbabot,isoi >/dev/null 2>&1
	then
		# new OpenSSL 1.1.x converted password with -pbkdf2 flag
		PASSWORD="$(/usr/sbin/openssl aes-256-cbc $emailPwEnc -d -in "$PWENCFILE" -pass pass:ditbabot,isoi 2>/dev/null)"
	fi
	echo "$PASSWORD"
}

Email_Recipients()
{
	case "$1" in
	update)
		while true
		do
			ScriptHeader

			printf "${BOLD}${UNDERLINE}Email Recipients Override List${CLEARFORMAT}\\n\\n"
			NOTIFICATIONS_EMAIL_LIST="$(Email_Recipients check)"
			if [ "$NOTIFICATIONS_EMAIL_LIST" = "" ]
			then
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

##----------------------------------------##
## Modified by Martinski W. [2025-Dec-08] ##
##----------------------------------------##
SendEmail()
{
	if ! Email_ConfExists
	then return 1
	fi

	local curlCode
	EMAIL_SUBJECT="$1"
	EMAIL_CONTENTS="$2"
	if [ $# -gt 2 ] && [ -n "$3" ]
	then
		TO_ADDRESS="$3"
	fi
	if [ -z "$TO_ADDRESS" ]
	then
		Print_Output false "No email recipient specified" "$ERR"
		return 1
	fi

	# html message to send #
	{
		echo "From: \"connmon\" <$FROM_ADDRESS>"
		echo "To: \"$TO_ADDRESS\" <$TO_ADDRESS>"
		echo "Subject: $EMAIL_SUBJECT"
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

	##echo "<html><body><p><img src=\"cid:connmonlogo.png\"></p>$2" > /tmp/message.html
	echo "<html><body>$EMAIL_CONTENTS" > /tmp/message.html

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

	##image_base64="$(openssl base64 -A < "connmonlogo.png")"
	##Encode_Image "connmonlogo.png" "$image_base64" /tmp/mail.txt
	##Encode_Text vnstat.txt "$(cat "$VNSTAT_OUTPUT_FILE")" /tmp/mail.txt

	{
		echo "--MULTIPART-RELATED-BOUNDARY--"
		echo ""
		echo "--MULTIPART-MIXED-BOUNDARY--"
	} >> /tmp/mail.txt

	PASSWORD="$(Email_Decrypt_Password)"

	curl -s --show-error --url "${PROTOCOL}://${SMTP}:$PORT" \
	--mail-from "$FROM_ADDRESS" --mail-rcpt "$TO_ADDRESS" \
	--upload-file /tmp/mail.txt --user "${USERNAME}:$PASSWORD" \
	$SSL_FLAG --ssl-reqd --crlf
	curlCode="$?"

	"$isInteractive" && echo
	if [ "$curlCode" -eq 0 ]
	then
		Print_Output false "Email sent successfully" "$PASS"
	else
		Print_Output true "Email failed to send [Code: $curlCode]" "$ERR"
	fi

	PASSWORD=""
	rm -f /tmp/mail.txt
	return "$curlCode"
}

Webhook_Targets()
{
	case "$1" in
	update)
		while true
		do
			ScriptHeader

			printf "${BOLD}${UNDERLINE}Discord Webhook List${CLEARFORMAT}\n\n"
			NOTIFICATIONS_WEBHOOK_LIST="$(Webhook_Targets check | sed 's~,~\n~g')"
			printf "Currently: ${SETTING}${NOTIFICATIONS_WEBHOOK_LIST}${CLEARFORMAT}\n\n"
			printf "Available options:\n"
			printf "1.    Update list\n"
			printf "2.    Clear list\n"
			printf "e.    Go back\n\n"
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
					printf "\n${BOLD}${ERR}Please choose a valid option${CLEARFORMAT}\n\n"
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

##----------------------------------------##
## Modified by Martinski W. [2025-Dec-08] ##
##----------------------------------------##
SendWebhook()
{
	local curlCode
	WEBHOOK_CONTENT="$1"
	WEBHOOK_TARGET="$2"
	if [ -z "$WEBHOOK_TARGET" ]
	then
		Print_Output false "No Webhook URL target specified" "$ERR"
		return 1
	fi
	printf '' > "$curlOutLogFile"
	printf '' > "$curlErrLogFile"

	curl -vSL --retry 4 --retry-delay 5 --connect-timeout 60 -o "$curlOutLogFile" \
-H "Content-Type: application/json" \
-d '{"username":"'"$SCRIPT_NAME"'","content":"'"$WEBHOOK_CONTENT"'"}' "$WEBHOOK_TARGET" >> "$curlErrLogFile" 2>&1
	curlCode="$?"

	"$isInteractive" && echo
	if [ "$curlCode" -eq 0 ] && \
	   ! grep -qiE "$curlErr2RegExp" "$curlOutLogFile" && \
	   ! grep -qiE "$curlErr2RegExp" "$curlErrLogFile"
	then
		Print_Output false "Webhook sent successfully" "$PASS"
		##OFF## rm -f "$curlOutLogFile" "$curlErrLogFile" ##OFF##
	else
		[ "$curlCode" -eq 0 ] && curlCode=999
		Print_Output true "Webhook failed to send [Code: $curlCode]" "$ERR"
		if "$isInteractive" && \
		   { [ -s "$curlOutLogFile" ] || [ -s "$curlErrLogFile" ] ; }
		then
			PressEnter ; echo
			echo "$tmpCurlSEPstr"
			if [ -s "$curlOutLogFile" ] && \
			   grep -qiE "$curlErr3RegExp" "$curlOutLogFile"
			then
				cat "$curlOutLogFile" ; echo
				echo "$tmpCurlSEPstr"
			fi
			if [ -s "$curlErrLogFile" ]
			then
				cat "$curlErrLogFile" ; echo
				echo "$tmpCurlSEPstr"
			fi
		fi
	fi
	return "$curlCode"
}

Pushover_Devices()
{
	case "$1" in
	update)
		while true
		do
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

##----------------------------------------##
## Modified by Martinski W. [2025-Dec-08] ##
##----------------------------------------##
SendPushover()
{
	local curlCode
	PUSHOVER_MSG="$1"
	PUSHOVER_API="$(Conf_Parameters check NOTIFICATIONS_PUSHOVER_API)"
	PUSHOVER_USERKEY="$(Conf_Parameters check NOTIFICATIONS_PUSHOVER_USERKEY)"
	if [ -z "$PUSHOVER_API" ] || [ -z "$PUSHOVER_USERKEY" ]
	then
		Print_Output false "No Pushover API or UserKey specified" "$ERR"
		return 1
	fi
	printf '' > "$curlOutLogFile"
	printf '' > "$curlErrLogFile"

	curl -vSL --retry 4 --retry-delay 5 --connect-timeout 60 -o "$curlOutLogFile" \
--form-string "token=$PUSHOVER_API" \
--form-string "user=$PUSHOVER_USERKEY" \
--form-string "message=$PUSHOVER_MSG" https://api.pushover.net/1/messages.json >> "$curlErrLogFile" 2>&1
	curlCode="$?"

	"$isInteractive" && echo
	if [ "$curlCode" -eq 0 ] && \
	   ! grep -qiE "$curlErr2RegExp" "$curlOutLogFile" && \
	   ! grep -qiE "$curlErr2RegExp" "$curlErrLogFile"
	then
		Print_Output false "Pushover sent successfully" "$PASS"
		##OFF## rm -f "$curlOutLogFile" "$curlErrLogFile" ##OFF##
	else
		[ "$curlCode" -eq 0 ] && curlCode=999
		Print_Output true "Pushover failed to send [Code: $curlCode]" "$ERR"
		if "$isInteractive" && \
		   { [ -s "$curlOutLogFile" ] || [ -s "$curlErrLogFile" ] ; }
		then
			PressEnter ; echo
			echo "$tmpCurlSEPstr"
			if [ -s "$curlOutLogFile" ] && \
			   grep -qiE "$curlErr3RegExp" "$curlOutLogFile"
			then
				cat "$curlOutLogFile" ; echo
				echo "$tmpCurlSEPstr"
			fi
			if [ -s "$curlErrLogFile" ]
			then
				cat "$curlErrLogFile" ; echo
				echo "$tmpCurlSEPstr"
			fi
		fi
	fi
	return "$curlCode"
}

##----------------------------------------##
## Modified by Martinski W. [2025-Dec-08] ##
##----------------------------------------##
SendHealthcheckPing()
{
	local curlCode
	HEALTHCHECK_UUID="$(Conf_Parameters check NOTIFICATIONS_HEALTHCHECK_UUID)"
	TEST_FAIL=""
	if [ "$1" = "Fail" ]
	then
		TEST_FAIL="/fail"
	fi
	printf '' > "$curlOutLogFile"
	printf '' > "$curlErrLogFile"

	curl -vSL --retry 4 --retry-delay 5 --connect-timeout 60 -o "$curlOutLogFile" \
"https://hc-ping.com/${HEALTHCHECK_UUID}$TEST_FAIL" >> "$curlErrLogFile" 2>&1
	curlCode="$?"

	"$isInteractive" && echo
	if [ "$curlCode" -eq 0 ] && \
	   ! grep -qiE "$curlErr2RegExp" "$curlOutLogFile" && \
	   ! grep -qiE "$curlErr2RegExp" "$curlErrLogFile"
	then
		Print_Output false "Healthcheck ping sent successfully" "$PASS"
		##OFF## rm -f "$curlOutLogFile" "$curlErrLogFile" ##OFF##
	else
		[ "$curlCode" -eq 0 ] && curlCode=999
		Print_Output true "Healthcheck ping failed to send [Code: $curlCode]" "$ERR"
		if "$isInteractive" && \
		   { [ -s "$curlOutLogFile" ] || [ -s "$curlErrLogFile" ] ; }
		then
			PressEnter ; echo
			echo "$tmpCurlSEPstr"
			if [ -s "$curlOutLogFile" ] && \
			   grep -qiE "$curlErr3RegExp" "$curlOutLogFile"
			then
				cat "$curlOutLogFile" ; echo
				echo "$tmpCurlSEPstr"
			fi
			if [ -s "$curlErrLogFile" ]
			then
				cat "$curlErrLogFile" ; echo
				echo "$tmpCurlSEPstr"
			fi
		fi
	fi
	return "$curlCode"
}

##----------------------------------------##
## Modified by Martinski W. [2025-Dec-12] ##
##----------------------------------------##
SendToInfluxDB()
{
	local curlCode  dataTags  dataFields  pingTARGET  routerID

	TIMESTAMP="$1"
	PING="$2"
	JITTER="$3"
	LINEQUAL="$4"
	PING_TARGET="$5"
	INFLUXDB_BID="$(Conf_Parameters check NOTIFICATIONS_INFLUXDB_DB)"
	INFLUXDB_ORG="$(Conf_Parameters check NOTIFICATIONS_INFLUXDB_ORG)"
	INFLUXDB_HOST="$(Conf_Parameters check NOTIFICATIONS_INFLUXDB_HOST)"
	INFLUXDB_PORT="$(Conf_Parameters check NOTIFICATIONS_INFLUXDB_PORT)"
	INFLUXDB_PROTO="$(Conf_Parameters check NOTIFICATIONS_INFLUXDB_PROTO)"
	INFLUXDB_VERSION="$(Conf_Parameters check NOTIFICATIONS_INFLUXDB_VERSION)"

	if [ "$INFLUXDB_VERSION" = "1.8" ]
	then
		INFLUX_AUTHHEADER="$(Conf_Parameters check NOTIFICATIONS_INFLUXDB_USERNAME):$(Conf_Parameters check NOTIFICATIONS_INFLUXDB_PASSWORD)"
	elif [ "$INFLUXDB_VERSION" = "2.0" ]
	then
		INFLUX_AUTHHEADER="$(Conf_Parameters check NOTIFICATIONS_INFLUXDB_APITOKEN)"
	fi
	printf '' > "$curlOutLogFile"
	printf '' > "$curlErrLogFile"

	if ! echo "$PING_TARGET" | grep -qE '[ ]+'
	then pingTARGET="$PING_TARGET"
	else pingTARGET="$(echo "$PING_TARGET" | sed 's/ /\\ /')"
	fi

	if ! echo "$ROUTER_MODEL" | grep -qE '[ ]+'
	then routerID="$ROUTER_MODEL"
	else routerID="$(echo "$ROUTER_MODEL" | sed 's/ /_/g')"
	fi

	## Variable ping test results are assigned to InfluxDB "data fields" ##
	dataTags="Router=${routerID},Source=${SCRIPT_NAME}"
	dataFields="Jitter=${JITTER},LineQuality=${LINEQUAL},PingAvrg=${PING},PingServer=\"${PING_TARGET}\""

	curl -vSL --retry 4 --retry-delay 5 --connect-timeout 60 -o "$curlOutLogFile" \
"${INFLUXDB_PROTO}://${INFLUXDB_HOST}:${INFLUXDB_PORT}/api/v2/write?org=${INFLUXDB_ORG}&bucket=${INFLUXDB_BID}&precision=s" \
--header "Authorization: Token $INFLUX_AUTHHEADER" --header "Accept-Encoding: gzip" \
--data-raw "PingTest,$dataTags $dataFields $TIMESTAMP" >> "$curlErrLogFile" 2>&1
	curlCode="$?"

	"$isInteractive" && echo
	if [ "$curlCode" -eq 0 ] && \
	   ! grep -qiE "$curlErr2RegExp" "$curlOutLogFile" && \
	   ! grep -qiE "$curlErr2RegExp" "$curlErrLogFile"
	then
		Print_Output false "Data sent to InfluxDB successfully" "$PASS"
		##OFF## rm -f "$curlOutLogFile" "$curlErrLogFile" ##OFF##
	else
		[ "$curlCode" -eq 0 ] && curlCode=999
		Print_Output true "Data failed to send to InfluxDB [Code: $curlCode]" "$ERR"
		if "$isInteractive" && \
		   { [ -s "$curlOutLogFile" ] || [ -s "$curlErrLogFile" ] ; }
		then
			PressEnter ; echo
			echo "$tmpCurlSEPstr"
			if [ -s "$curlOutLogFile" ] && \
			   grep -qiE "$curlErr3RegExp" "$curlOutLogFile"
			then
				cat "$curlOutLogFile" ; echo
				echo "$tmpCurlSEPstr"
			fi
			if [ -s "$curlErrLogFile" ]
			then
				cat "$curlErrLogFile" ; echo
				echo "$tmpCurlSEPstr"
			fi
		fi
	fi
	return "$curlCode"
}

##----------------------------------------##
## Modified by Martinski W. [2025-Jun-06] ##
##----------------------------------------##
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
			NOTIFICATION_SETTING="$(_GetConfigParam_ "$2" 'false')"
			if [ "$NOTIFICATION_SETTING" = "true" ]
			then return 0; else return 1; fi
		;;
	esac
}

##----------------------------------------##
## Modified by Martinski W. [2025-Dec-10] ##
##----------------------------------------##
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
				"Healthcheck UUID")
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
				"InfluxDB Protocol")
					sed -i 's/^NOTIFICATIONS_INFLUXDB_PROTO=.*$/NOTIFICATIONS_INFLUXDB_PROTO='"$3"'/' "$SCRIPT_CONF"
				;;
				"InfluxDB Database ID")
					sed -i 's/^NOTIFICATIONS_INFLUXDB_DB=.*$/NOTIFICATIONS_INFLUXDB_DB='"$3"'/' "$SCRIPT_CONF"
				;;
				"InfluxDB Organization")
					sed -i 's/^NOTIFICATIONS_INFLUXDB_ORG=.*$/NOTIFICATIONS_INFLUXDB_ORG='"$3"'/' "$SCRIPT_CONF"
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
			CONFIG_SETTING="$(grep "^${2}=" "$SCRIPT_CONF" | cut -d'=' -f2-)"
			echo "$CONFIG_SETTING"
		;;
	esac
}

Validate_Float()
{
	if echo "$1" | /bin/grep -oq "^[0-9]*\.\?[0-9]\?[0-9]$"; then
		return 0
	else
		return 1
	fi
}

##----------------------------------------##
## Modified by Martinski W. [2025-Dec-07] ##
##----------------------------------------##
Notification_String()
{
	NOTIFICATION_STRING=""
	while true
	do
		printf "\n${BOLD}Enter ${1}:${CLRct}"
		if echo "$1" | grep -qE '.* API Token$'
		then printf "\n"
		else printf "  "
		fi
		read -r NOTIFICATION_STRING
		if [ "$NOTIFICATION_STRING" = "e" ]
		then
			NOTIFICATION_STRING=""
			break
		else
			printf "${BOLD}${WARN}Is this correct? (y/n):${CLRct}  "
			read -r CONFIRM_INPUT
			case "$CONFIRM_INPUT" in
				y|Y)
					if [ "$1" = "To name" ]
					then
						sed -i 's/^TO_NAME=.*$/TO_NAME='"$NOTIFICATION_STRING"'/' "$EMAIL_CONF"
					elif [ "$1" = "Username" ]
					then
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
	while true
	do
		printf "\n${BOLD}Enter ${1}:${CLRct}  "
		read -r NOTIFICATION_NUMBER
		if [ "$NOTIFICATION_NUMBER" = "e" ]; then
			NOTIFICATION_NUMBER=""
			break
		elif ! Validate_Number "$NOTIFICATION_NUMBER"; then
			printf "\n${ERR}Please enter a number${CLRct}\n"
		else
			printf "${BOLD}${WARN}Is this correct? (y/n):${CLRct}  "
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
	while true
	do
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

##----------------------------------------##
## Modified by Martinski W. [2025-Dec-11] ##
##----------------------------------------##
TriggerNotifications()
{
	local noteStr

	TRIGGERTYPE="$1"
	DATETIME="$2"
	PING_TARGET=""

	if [ "$TRIGGERTYPE" = "PingTestOK" ]
	then
		PING="$3"
		JITTER="$4"
		LINEQUAL="$5"
		TIMESTAMP="$6"
		PING_TARGET="$7"
	elif [ "$TRIGGERTYPE" = "PingTestFailed" ]
	then
		PING=0
		JITTER=0
		LINEQUAL=0
		PING_TARGET="$3"
	elif [ "$TRIGGERTYPE" = "PingThreshold" ]
	then
		PING="$3"
		THRESHOLD="$4"
		PING_TARGET="$5"
	elif [ "$TRIGGERTYPE" = "JitterThreshold" ]
	then
		JITTER="$3"
		THRESHOLD="$4"
		PING_TARGET="$5"
	elif [ "$TRIGGERTYPE" = "LineQualityThreshold" ]
	then
		LINEQUAL="$3"
		THRESHOLD="$4"
		PING_TARGET="$5"
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
					if [ "$TRIGGERTYPE" = "PingTestOK" ]
					then
						noteStr="<p>Ping: ${PING}<br/>Jitter: ${JITTER}<br/>Line Quality: ${LINEQUAL}<br/>Ping Server: ${PING_TARGET}<br/>Router: ${ROUTER_MODEL}</p>"
						SendEmail "Ping test result from $SCRIPT_NAME - $DATETIME" "$noteStr"
					elif [ "$TRIGGERTYPE" = "PingTestFailed" ]
					then
						noteStr="<p>Ping test to server '${PING_TARGET}' failed.<br/>Router: ${ROUTER_MODEL}</p>"
						SendEmail "Ping test failure alert from $SCRIPT_NAME - $DATETIME" "$noteStr"
					elif [ "$TRIGGERTYPE" = "PingThreshold" ]
					then
						noteStr="<p>Ping $PING exceeds threshold of ${THRESHOLD}<br/>Ping Server: ${PING_TARGET}<br/>Router: ${ROUTER_MODEL}</p>"
						SendEmail "Ping threshold alert from $SCRIPT_NAME - $DATETIME" "$noteStr"
					elif [ "$TRIGGERTYPE" = "JitterThreshold" ]
					then
						noteStr="<p>Jitter $JITTER exceeds threshold of ${THRESHOLD}<br/>Ping Server: ${PING_TARGET}<br/>Router: ${ROUTER_MODEL}</p>"
						SendEmail "Jitter threshold alert from $SCRIPT_NAME - $DATETIME" "$noteStr"
					elif [ "$TRIGGERTYPE" = "LineQualityThreshold" ]
					then
						noteStr="<p>Line quality $LINEQUAL exceeds threshold of ${THRESHOLD}<br/>Ping Server: ${PING_TARGET}<br/>Router: ${ROUTER_MODEL}</p>"
						SendEmail "Line quality threshold alert from $SCRIPT_NAME - $DATETIME" "$noteStr"
					fi
				else
					for EMAIL in $NOTIFICATIONS_EMAIL_LIST
					do
						if [ "$TRIGGERTYPE" = "PingTestOK" ]
						then
							noteStr="<p>Ping: ${PING}<br/>Jitter: ${JITTER}<br/>Line Quality: ${LINEQUAL}<br/>Ping Server: ${PING_TARGET}<br/>Router: ${ROUTER_MODEL}</p>"
							SendEmail "Ping test result from $SCRIPT_NAME - $DATETIME" "$noteStr" "$EMAIL"
						elif [ "$TRIGGERTYPE" = "PingTestFailed" ]
						then
							noteStr="<p>Ping test to server '${PING_TARGET}' failed.<br/>Router: ${ROUTER_MODEL}</p>"
							SendEmail "Ping test failure alert from $SCRIPT_NAME - $DATETIME" "$noteStr" "$EMAIL"
						elif [ "$TRIGGERTYPE" = "PingThreshold" ]
						then
							noteStr="<p>Ping $PING exceeds threshold of ${THRESHOLD}<br/>Ping Server: ${PING_TARGET}<br/>Router: ${ROUTER_MODEL}</p>"
							SendEmail "Ping threshold alert from $SCRIPT_NAME - $DATETIME" "$noteStr" "$EMAIL"
						elif [ "$TRIGGERTYPE" = "JitterThreshold" ]
						then
							noteStr="<p>Jitter $JITTER exceeds threshold of ${THRESHOLD}<br/>Ping Server: ${PING_TARGET}<br/>Router: ${ROUTER_MODEL}</p>"
							SendEmail "Jitter threshold alert from $SCRIPT_NAME - $DATETIME" "$noteStr" "$EMAIL"
						elif [ "$TRIGGERTYPE" = "LineQualityThreshold" ]
						then
							noteStr="<p>Line quality $LINEQUAL exceeds threshold of ${THRESHOLD}<br/>Ping Server: ${PING_TARGET}<br/>Router: ${ROUTER_MODEL}</p>"
							SendEmail "Line quality threshold alert from $SCRIPT_NAME - $DATETIME" "$noteStr" "$EMAIL"
						fi
					done
				fi
			elif [ "$NOTIFICATIONMETHOD" = "Webhook" ]
			then
				NOTIFICATIONS_WEBHOOK_LIST="$(Webhook_Targets check)"
				for WEBHOOK in $NOTIFICATIONS_WEBHOOK_LIST
				do
					if [ "$TRIGGERTYPE" = "PingTestOK" ]
					then
						noteStr="Ping: ${PING}\nJitter: ${JITTER}\nLine Quality: ${LINEQUAL}\nPing Server: ${PING_TARGET}\nRouter: $ROUTER_MODEL"
						SendWebhook "Ping test result from $SCRIPT_NAME - $DATETIME\n\n$noteStr" "$WEBHOOK"
					elif [ "$TRIGGERTYPE" = "PingTestFailed" ]
					then
						noteStr="Ping test to server ${PING_TARGET} failed.\nRouter: $ROUTER_MODEL"
						SendWebhook "Ping test failure alert from $SCRIPT_NAME - $DATETIME\n\n$noteStr" "$WEBHOOK"
					elif [ "$TRIGGERTYPE" = "PingThreshold" ]
					then
						noteStr="Ping $PING exceeds threshold of ${THRESHOLD}\nPing Server: ${PING_TARGET}\nRouter: $ROUTER_MODEL"
						SendWebhook "Ping threshold alert from $SCRIPT_NAME - $DATETIME\n\n$noteStr" "$WEBHOOK"
					elif [ "$TRIGGERTYPE" = "JitterThreshold" ]
					then
						noteStr="Jitter $JITTER exceeds threshold of ${THRESHOLD}\nPing Server: ${PING_TARGET}\nRouter: $ROUTER_MODEL"
						SendWebhook "Jitter threshold alert from $SCRIPT_NAME - $DATETIME\n\n$noteStr" "$WEBHOOK"
					elif [ "$TRIGGERTYPE" = "LineQualityThreshold" ]
					then
						noteStr="Line quality $LINEQUAL exceeds threshold of ${THRESHOLD}\nPing Server: ${PING_TARGET}\nRouter: $ROUTER_MODEL"
						SendWebhook "Line quality threshold alert from $SCRIPT_NAME - $DATETIME\n\n$noteStr" "$WEBHOOK"
					fi
				done
			elif [ "$NOTIFICATIONMETHOD" = "Pushover" ]
			then
				if [ "$TRIGGERTYPE" = "PingTestOK" ]
				then
					noteStr="Ping: $PING"$'\n'"Jitter: $JITTER"$'\n'"Line Quality: $LINEQUAL"$'\n'"Ping Server: $PING_TARGET"$'\n'"Router: $ROUTER_MODEL"
					SendPushover "Ping test result from $SCRIPT_NAME - $DATETIME"$'\n'$'\n'"$noteStr"
				elif [ "$TRIGGERTYPE" = "PingTestFailed" ]
				then
					noteStr="Ping test to server ${PING_TARGET} failed."$'\n'"Router: $ROUTER_MODEL"
					SendPushover "Ping test failure alert from $SCRIPT_NAME - $DATETIME"$'\n'$'\n'"$noteStr"
				elif [ "$TRIGGERTYPE" = "PingThreshold" ]
				then
					noteStr="Ping $PING exceeds threshold of $THRESHOLD"$'\n'"Ping Server: $PING_TARGET"$'\n'"Router: $ROUTER_MODEL"
					SendPushover "Ping threshold alert from $SCRIPT_NAME - $DATETIME"$'\n'$'\n'"$noteStr"
				elif [ "$TRIGGERTYPE" = "JitterThreshold" ]
				then
					noteStr="Jitter $JITTER exceeds threshold of $THRESHOLD"$'\n'"Ping Server: $PING_TARGET"$'\n'"Router: $ROUTER_MODEL"
					SendPushover "Jitter threshold alert from $SCRIPT_NAME - $DATETIME"$'\n'$'\n'"$noteStr"
				elif [ "$TRIGGERTYPE" = "LineQualityThreshold" ]
				then
					noteStr="Line quality $LINEQUAL exceeds threshold of $THRESHOLD"$'\n'"Ping Server: $PING_TARGET"$'\n'"Router: $ROUTER_MODEL"
					SendPushover "Line quality threshold alert from $SCRIPT_NAME - $DATETIME"$'\n'$'\n'"$noteStr"
				fi
			elif [ "$NOTIFICATIONMETHOD" = "Custom" ]
			then
				FILES="$USER_SCRIPT_DIR/*.sh"
				for shFile in $FILES
				do
					if [ -s "$shFile" ]
					then
						echo
						Print_Output true "Executing custom user script: $shFile" "$PASS"
						if [ "$TRIGGERTYPE" = "PingTestOK" ]
						then
							sh "$shFile" "$TRIGGERTYPE" "$DATETIME" "$PING" "$JITTER" "$LINEQUAL" "$PING_TARGET"
						elif [ "$TRIGGERTYPE" = "PingTestFailed" ]
						then
							sh "$shFile" "$TRIGGERTYPE" "$DATETIME" "$PING_TARGET"
						elif [ "$TRIGGERTYPE" = "PingThreshold" ]
						then
							sh "$shFile" "$TRIGGERTYPE" "$DATETIME" "$PING" "$THRESHOLD" "$PING_TARGET"
						elif [ "$TRIGGERTYPE" = "JitterThreshold" ]
						then
							sh "$shFile" "$TRIGGERTYPE" "$DATETIME" "$JITTER" "$THRESHOLD" "$PING_TARGET"
						elif [ "$TRIGGERTYPE" = "LineQualityThreshold" ]
						then
							sh "$shFile" "$TRIGGERTYPE" "$DATETIME" "$LINEQUAL" "$THRESHOLD" "$PING_TARGET"
						fi
					fi
				done
			fi
		fi
	done
	unset IFS

	if ToggleNotificationTypes check NOTIFICATIONS_HEALTHCHECK && [ "$TRIGGERTYPE" = "PingTestOK" ]
	then
		NOTIFICATIONS_HEALTHCHECK_UUID="$(Conf_Parameters check NOTIFICATIONS_HEALTHCHECK_UUID)"
		TESTFAIL=""
		if [ "$(echo "$LINEQUAL" | cut -d' ' -f1 | cut -d'.' -f1)" -eq 0 ]
		then SendHealthcheckPing "Fail"
		else SendHealthcheckPing "Pass"
		fi
	fi

	if ToggleNotificationTypes check NOTIFICATIONS_INFLUXDB && [ "$TRIGGERTYPE" = "PingTestOK" ]
	then
		PING="$(echo "$PING" | cut -d' ' -f1)"
		JITTER="$(echo "$JITTER" | cut -d' ' -f1)"
		LINEQUAL="$(echo "$LINEQUAL" | cut -d' ' -f1)"
		SendToInfluxDB "$TIMESTAMP" "$PING" "$JITTER" "$LINEQUAL" "$PING_TARGET"
	fi
}

##----------------------------------------##
## Modified by Martinski W. [2025-Dec-11] ##
##----------------------------------------##
Menu_EmailNotifications()
{
	local notificationsEMAIL  notificationsEMAIL_LIST  SSL_FlagStr  noteStr

	while true
	do
		Email_ConfExists
		ScriptHeader

		if ToggleNotificationTypes check NOTIFICATIONS_EMAIL
		then notificationsEMAIL="${PASS}Enabled"
		else notificationsEMAIL="${ERR}Disabled"
		fi
		notificationsEMAIL_LIST="$(Email_Recipients check)"
		if [ -z "$notificationsEMAIL_LIST" ]
		then
			notificationsEMAIL_LIST="Generic To Address will be used"
		fi
		if [ -z "$SSL_FLAG" ]
		then SSL_FlagStr="[Secure]"
		else SSL_FlagStr="$SSL_FLAG"
		fi

		printf "  ${GRNct}1${CLRct}. Toggle email notifications (subject to type configuration)\n"
		printf "     Currently: ${BOLD}${notificationsEMAIL}${CLRct}\n\n"
		printf "  ${GRNct}2${CLRct}. Set override list of email addresses for %s\n" "$SCRIPT_NAME"
		printf "     Currently: ${SETTING}${notificationsEMAIL_LIST}${CLRct}\n"

		printf "\n  ${BOLD}${GRNct}${UNDERLINE}Generic Email Configuration${CLRct}\n\n"
		Email_Header
		printf "  ${GRNct}c1${CLRct}. Set From Address          Currently: ${SETTING}%s${CLRct}\n" "$FROM_ADDRESS"
		printf "  ${GRNct}c2${CLRct}. Set To Address            Currently: ${SETTING}%s${CLRct}\n" "$TO_ADDRESS"
		printf "  ${GRNct}c3${CLRct}. Set To Name               Currently: ${SETTING}%s${CLRct}\n" "$TO_NAME"
		printf "  ${GRNct}c4${CLRct}. Set Username              Currently: ${SETTING}%s${CLRct}\n" "$USERNAME"
		printf "  ${GRNct}c5${CLRct}. Set Password\n"
		printf "  ${GRNct}c6${CLRct}. Set Friendly Router Name  Currently: ${SETTING}%s${CLRct}\n" "$FRIENDLY_ROUTER_NAME"
		printf "  ${GRNct}c7${CLRct}. Set SMTP Address          Currently: ${SETTING}%s${CLRct}\n" "$SMTP"
		printf "  ${GRNct}c8${CLRct}. Set SMTP Port             Currently: ${SETTING}%s${CLRct}\n" "$PORT"
		printf "  ${GRNct}c9${CLRct}. Set SMTP Protocol         Currently: ${SETTING}%s${CLRct}\n" "$PROTOCOL"
		printf " ${GRNct}c10${CLRct}. Set SSL Requirement       Currently: ${SETTING}%s${CLRct}\n\n" "$SSL_FlagStr"
		printf "  ${GRNct}cs${CLRct}. Send a test email\n\n"
		printf "   ${GRNct}e${CLRct}. Go back\n"
		printf "\n${menuSepStr}\n\n"

		printf "Choose an option:  "
		read -r emailmenu
		case "$emailmenu" in
			1)
				if ToggleNotificationTypes check NOTIFICATIONS_EMAIL
				then
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
				noteStr="<p>This is a test email!<br/>Router: ${ROUTER_MODEL}</p>"
				notificationsEMAIL_LIST="$(Email_Recipients check)"
				if [ -z "$notificationsEMAIL_LIST" ]
				then
					SendEmail "Test email from $SCRIPT_NAME - $(/bin/date +"%c")" "$noteStr"
				else
					for EMAIL in $notificationsEMAIL_LIST
					do
						SendEmail "Test email from $SCRIPT_NAME - $(/bin/date +"%c")" "$noteStr" "$EMAIL"
					done
				fi
				printf "\n"
				PressEnter
			;;
			e)
				break
			;;
			*)
				printf "\n${BOLD}${ERR}Please choose a valid option${CLRct}\n\n"
				PressEnter
			;;
		esac
	done
}

##----------------------------------------##
## Modified by Martinski W. [2025-Dec-11] ##
##----------------------------------------##
Menu_WebhookNotifications()
{
	local notificationsWEBHOOK  notificationsWEBHOOK_LIST  noteStr

	while true
	do
		ScriptHeader
		if ToggleNotificationTypes check NOTIFICATIONS_WEBHOOK
		then notificationsWEBHOOK="${PASS}Enabled"
		else notificationsWEBHOOK="${ERR}Disabled"
		fi
		notificationsWEBHOOK_LIST="$(Webhook_Targets check | sed 's~,~\n~g')"
		if [ -z "$notificationsWEBHOOK_LIST" ]
		then notificationsWEBHOOK_LIST="${ERR}[None specified]"
		fi

		printf "  ${GRNct}1${CLRct}. Toggle Discord webhook notifications (subject to type configuration)\n"
		printf "     Currently: ${BOLD}${notificationsWEBHOOK}${CLRct}\n\n"
		printf "  ${GRNct}2${CLRct}. Set list of Discord webhook URLs for %s\n" "$SCRIPT_NAME"
		printf "     Current webhooks:\n"
		printf "     ${SETTING}${notificationsWEBHOOK_LIST}${CLRct}\n\n"
		printf " ${GRNct}cs${CLRct}. Send a test webhook notification\n\n"
		printf "  ${GRNct}e${CLRct}. Go back\n"
		printf "\n${menuSepStr}\n\n"

		printf "Choose an option:  "
		read -r webhookmenu
		case "$webhookmenu" in
			1)
				if ToggleNotificationTypes check NOTIFICATIONS_WEBHOOK
				then
					ToggleNotificationTypes disable NOTIFICATIONS_WEBHOOK
				else
					ToggleNotificationTypes enable NOTIFICATIONS_WEBHOOK
				fi
			;;
			2)
				Webhook_Targets update
			;;
			cs)
				notificationsWEBHOOK_LIST="$(Webhook_Targets check)"
				if [ -z "$notificationsWEBHOOK_LIST" ]
				then
					printf "\n"
					Print_Output false "No Webhook URLs specified" "$ERR"
				fi
				IFS=$','
				noteStr="This is a test Webhook message!\nRouter: $ROUTER_MODEL"
				for WEBHOOK in $notificationsWEBHOOK_LIST
				do
					SendWebhook "Test message from $SCRIPT_NAME - $(/bin/date +"%c")\n\n$noteStr" "$WEBHOOK"
				done
				unset IFS
				printf "\n"
				PressEnter
			;;
			e)
				break
			;;
			*)
				printf "\n${BOLD}${ERR}Please choose a valid option${CLRct}\n\n"
				PressEnter
			;;
		esac
	done
}

##----------------------------------------##
## Modified by Martinski W. [2025-Dec-11] ##
##----------------------------------------##
Menu_PushoverNotifications()
{
	local notificationsPUSHOVER  notificationsPUSHOVER_LIST
	local pushoverUSER_KEY  pushoverAPI_TOKEN  noteStr

	while true
	do
		ScriptHeader
		if ToggleNotificationTypes check NOTIFICATIONS_PUSHOVER
		then notificationsPUSHOVER="${PASS}Enabled"
		else notificationsPUSHOVER="${ERR}Disabled"
		fi

		notificationsPUSHOVER_LIST="$(Pushover_Devices check)"
		if [ -z "$notificationsPUSHOVER_LIST" ]
		then notificationsPUSHOVER_LIST="All devices"
		fi

		pushoverUSER_KEY="$(Conf_Parameters check NOTIFICATIONS_PUSHOVER_USERKEY)"
		if [ -z "$pushoverUSER_KEY" ]
		then pushoverUSER_KEY="${ERR}[NONE defined]"
		else pushoverUSER_KEY="${SETTING}$pushoverUSER_KEY"
		fi

		pushoverAPI_TOKEN="$(Conf_Parameters check NOTIFICATIONS_PUSHOVER_API)"
		if [ -z "$pushoverAPI_TOKEN" ]
		then pushoverAPI_TOKEN="${ERR}[NONE defined]"
		else pushoverAPI_TOKEN="${SETTING}$pushoverAPI_TOKEN"
		fi

		printf "  ${GRNct}1${CLRct}. Toggle Pushover notifications (subject to type configuration)\n"
		printf "     Currently: ${BOLD}${notificationsPUSHOVER}${CLRct}\n\n"
		printf "     ${BOLD}${GRNct}${UNDERLINE}Pushover Configuration${CLRct}\n\n"
		printf " ${GRNct}c1${CLRct}. Set Pushover User Key\n"
		printf "     Currently: ${pushoverUSER_KEY}${CLRct}\n\n"
		printf " ${GRNct}c2${CLRct}. Set Pushover API Token\n"
		printf "     Currently: ${pushoverAPI_TOKEN}${CLRct}\n\n"
		printf " ${GRNct}c3${CLRct}. Set list of Pushover devices for %s\n" "$SCRIPT_NAME"
		printf "     Current devices: ${SETTING}${notificationsPUSHOVER_LIST}${CLRct}\n\n"
		printf " ${GRNct}cs${CLRct}. Send a test Pushover notification\n\n"
		printf "  ${GRNct}e${CLRct}. Go back\n"
		printf "\n${menuSepStr}\n\n"

		printf "Choose an option:  "
		read -r pushoverOption
		case "$pushoverOption" in
			1)
				if ToggleNotificationTypes check NOTIFICATIONS_PUSHOVER
				then
					ToggleNotificationTypes disable NOTIFICATIONS_PUSHOVER
				else
					ToggleNotificationTypes enable NOTIFICATIONS_PUSHOVER
				fi
			;;
			c1)
				Notification_String "Pushover User Key"
			;;
			c2)
				Notification_String "Pushover API Token"
			;;
			c3)
				Pushover_Devices update
			;;
			cs)
				noteStr="This is a test Pushover message!"$'\n'"Router: $ROUTER_MODEL"
				SendPushover "Test message from $SCRIPT_NAME - $(/bin/date +"%c")"$'\n'$'\n'"$noteStr"
				printf "\n"
				PressEnter
			;;
			e)
				break
			;;
			*)
				printf "\n${BOLD}${ERR}Please choose a valid option${CLRct}\n\n"
				PressEnter
			;;
		esac
	done
}

##----------------------------------------##
## Modified by Martinski W. [2025-Nov-14] ##
##----------------------------------------##
CustomAction_Info()
{
	if [ $# -eq 0 ] || [ -z "$1" ]
	then
		printf "\n${BOLD}${UNDERLINE}Custom user scripts are passed arguments, which change depending on the type of trigger.${CLRct}\n\n"
		printf "${BOLD}${GRNct}Trigger Event            Argument #1           Argument #2        Argument #3   Argument #4          Argument #5${CLRct}\n"
		printf "${BOLD}${GRNct}-----------------------  --------------------  -----------------  ------------  -------------------  ------------ ${CLRct}\n"
		printf "${BOLD}Ping Test Success${CLRct}"'        PingTestOK            "Date/Time Stamp"  "Ping ms"     "Jitter ms"          "Latency %%"'"\n"
		printf "${BOLD}Ping Test Failure${CLRct}"'        PingTestFailed        "Date/Time Stamp"  "PingTarget" '"\n"
		printf "${BOLD}Ping Thresholds${CLRct}"'          PingThreshold         "Date/Time Stamp"  "Ping ms"     "ThresholdValue ms"'"\n"
		printf "${BOLD}Jitter Thresholds${CLRct}"'        JitterThreshold       "Date/Time Stamp"  "Jitter ms"   "ThresholdValue ms"'"\n"
		printf "${BOLD}Line Quality Thresholds${CLRct}"'  LineQualityThreshold  "Date/Time Stamp"  "Latency %%"   "ThresholdValue %%"'"\n"
		printf "\nA great example of a custom script would be to leverage the Apprise library:\n"
		printf "${BOLD}https://github.com/caronc/apprise${CLRct}\n"
		printf "This library provides easy integration with many notification schemes.\n"
		printf "See ${BOLD}https://github.com/caronc/apprise#popular-notification-services${CLRct}\n"
		printf "You can install apprise on your router by running:\n\n"
		printf "${BOLD}opkg install python3 python3-pip && /opt/bin/python3 -m pip install --upgrade pip${CLRct}\n\n"
		printf "Apprise can then be leveraged at the command line as shown here:\n"
		printf "${BOLD}https://github.com/caronc/apprise#command-line${CLRct}\n\n"
		printf " ${GRNct}e${CLRct}. Go back\n"
		printf "\n${menuSepStr}\n\n"
	fi

	{
		printf "Custom user scripts are passed arguments, which change depending on the type of trigger.\n\n"
		printf "Trigger Event            Argument #1           Argument #2        Argument #3   Argument #4          Argument #5\n"
		printf "-----------------------  --------------------  -----------------  ------------  -------------------  ------------ \n"
		printf "Ping Test Success"'        PingTestOK            "Date/Time Stamp"  "Ping ms"     "Jitter ms"          "Latency %%"'"\n"
		printf "Ping Test Failure"'        PingTestFailed        "Date/Time Stamp"  "PingTarget" '"\n"
		printf "Ping Thresholds"'          PingThreshold         "Date/Time Stamp"  "Ping ms"     "ThresholdValue ms"'"\n"
		printf "Jitter Thresholds"'        JitterThreshold       "Date/Time Stamp"  "Jitter ms"   "ThresholdValue ms"'"\n"
		printf "Line Quality Thresholds"'  LineQualityThreshold  "Date/Time Stamp"  "Latency %%"   "ThresholdValue %%"'"\n"
		printf "\nA great example of a custom script would be to leverage the Apprise library:\n"
		printf "https://github.com/caronc/apprise \n"
		printf "This library provides easy integration with many notification schemes.\n"
		printf "See https://github.com/caronc/apprise#popular-notification-services \n"
		printf "You can install apprise on your router by running:\n\n"
		printf "opkg install python3 python3-pip && /opt/bin/python3 -m pip install --upgrade pip\n\n"
		printf "Apprise can then be leveraged at the command line as shown here:\n"
		printf "https://github.com/caronc/apprise#command-line \n\n"
	} > "$SCRIPT_STORAGE_DIR/.customactioninfo"
}

##----------------------------------------##
## Modified by Martinski W. [2025-Nov-14] ##
##----------------------------------------##
CustomAction_List()
{
	local shFileCount

	if [ $# -eq 0 ] || [ -z "$1" ]
	then
		shFileCount=0
		FILES="$USER_SCRIPT_DIR/*.sh"
		for shFile in $FILES
		do
			if [ -s "$shFile" ]
			then
				shFileCount="$((shFileCount + 1))"
				printf "${SETTING}%s${CLEARFORMAT}\n" "$shFile"
			fi
		done
		[ "$shFileCount" -eq 0 ] && \
		printf "\n${SETTING}No custom user scripts found in '${USER_SCRIPT_DIR}' directory.${CLEARFORMAT}\n"
	fi

	printf "Custom user scripts that will be run:\n"  > "$SCRIPT_STORAGE_DIR/.customactionlist"
	printf "-------------------------------------\n" >> "$SCRIPT_STORAGE_DIR/.customactionlist"

	shFileCount=0
	FILES="$USER_SCRIPT_DIR/*.sh"
	for shFile in $FILES
	do
		if [ -s "$shFile" ]
		then
			shFileCount="$((shFileCount + 1))"
			printf "%s\n" "$shFile" >> "$SCRIPT_STORAGE_DIR/.customactionlist"
		fi
	done
	[ "$shFileCount" -eq 0 ] && \
	printf "\nNo custom user scripts found in '${USER_SCRIPT_DIR}' directory.\n" >> "$SCRIPT_STORAGE_DIR/.customactionlist"
}

##----------------------------------------##
## Modified by Martinski W. [2025-Nov-14] ##
##----------------------------------------##
Menu_CustomActions()
{
	local notificationsCUSTOM

	while true
	do
		ScriptHeader
		if ToggleNotificationTypes check NOTIFICATIONS_CUSTOM
		then notificationsCUSTOM="${PASS}Enabled"
		else notificationsCUSTOM="${ERR}Disabled"
		fi

		printf " ${GRNct}1${CLRct}. Toggle custom actions and user scripts (subject to type configuration)\n"
		printf "    Currently: ${BOLD}${notificationsCUSTOM}${CLRct}\n\n"
		printf "Custom user scripts that will be run:\n"
		printf "-------------------------------------\n"

		if [ -z "$(ls -1A "$USER_SCRIPT_DIR"/*.sh 2>/dev/null)" ]
		then
			printf "\n${SETTING}No custom user scripts found in '${USER_SCRIPT_DIR}' directory.${CLRct}\n"
		else
			CustomAction_List
		fi
		CustomAction_Info

		printf "Choose an option:  "
		read -r custommenu
		case "$custommenu" in
			1)
				if ToggleNotificationTypes check NOTIFICATIONS_CUSTOM
				then
					ToggleNotificationTypes disable NOTIFICATIONS_CUSTOM
				else
					ToggleNotificationTypes enable NOTIFICATIONS_CUSTOM
				fi
			;;
			cs)
				if [ -z "$(ls -1A "$USER_SCRIPT_DIR"/*.sh 2>/dev/null)" ]
				then
					printf "\n${SETTING}No custom user scripts found in '${USER_SCRIPT_DIR}' directory.${CLRct}\n\n"
					PressEnter
				else
					shFileCount=0
					FILES="$USER_SCRIPT_DIR/*.sh"
					for shFile in $FILES
					do
						if [ -s "$shFile" ]
						then
							shFileCount="$((shFileCount + 1))"
							echo
							Print_Output false "Executing custom user script: $shFile" "$PASS"
							sh "$shFile" PingTestOK "$(/bin/date +%c)" '30 ms' '15 ms' '90%' '8.8.8.8'
						fi
					done
					[ "$shFileCount" -eq 0 ] && \
					printf "\n${SETTING}No custom user scripts found in '${USER_SCRIPT_DIR}' directory.${CLRct}\n\n"
					PressEnter
				fi
			;;
			e)
				break
			;;
			*)
				printf "\n${BOLD}${ERR}Please choose a valid option${CLRct}\n\n"
				PressEnter
			;;
		esac
	done
}

##----------------------------------------##
## Modified by Martinski W. [2025-Dec-10] ##
##----------------------------------------##
Menu_HealthcheckNotifications()
{
	local notificationsHEALTHCHECK  HEALTHCHECK_UUID  HEALTHCHECK_CRON

	while true
	do
		ScriptHeader
		if ToggleNotificationTypes check NOTIFICATIONS_HEALTHCHECK
		then notificationsHEALTHCHECK="${PASS}Enabled"
		else notificationsHEALTHCHECK="${ERR}Disabled"
		fi

		HEALTHCHECK_UUID="$(Conf_Parameters check NOTIFICATIONS_HEALTHCHECK_UUID)"
		if [ -z "$HEALTHCHECK_UUID" ]
		then HEALTHCHECK_UUID="${ERR}[NONE defined]"
		else HEALTHCHECK_UUID="${SETTING}$HEALTHCHECK_UUID"
		fi

		HEALTHCHECK_CRON="$(cru l | grep -E "#${SCRIPT_NAME}_generate#$" | cut -d' ' -f1-5)"
		if [ -z "$HEALTHCHECK_CRON" ]
		then HEALTHCHECK_CRON="${ERR}[NONE found]"
		else HEALTHCHECK_CRON="${SETTING}$HEALTHCHECK_CRON"
		fi

		printf "  ${GRNct}1${CLRct}. Toggle Healthchecks.io\n"
		printf "     Currently: ${BOLD}${notificationsHEALTHCHECK}${CLRct}\n\n"
		printf "     ${BOLD}${GRNct}${UNDERLINE}Healthcheck Configuration${CLRct}\n\n"
		printf " ${GRNct}c1${CLRct}. Set Healthcheck UUID\n"
		printf "     Currently: ${HEALTHCHECK_UUID}${CLRct}\n\n"
		printf "     Cron schedule for Healthchecks.io configuration:\n"
		printf "     ${HEALTHCHECK_CRON}${CLRct}\n\n"
		printf " ${GRNct}cs${CLRct}. Send a test Healthcheck notification\n\n"
		printf "  ${GRNct}e${CLRct}. Go back\n"
		printf "\n${menuSepStr}\n\n"

		printf "Choose an option:  "
		read -r healthcheckOption
		case "$healthcheckOption" in
			1)
				if ToggleNotificationTypes check NOTIFICATIONS_HEALTHCHECK
				then
					ToggleNotificationTypes disable NOTIFICATIONS_HEALTHCHECK
				else
					ToggleNotificationTypes enable NOTIFICATIONS_HEALTHCHECK
				fi
			;;
			c1)
				Notification_String "Healthcheck UUID"
			;;
			cs)
				SendHealthcheckPing "Pass"
				printf "\n"
				PressEnter
			;;
			e)
				break
			;;
			*)
				printf "\n${BOLD}${ERR}Please choose a valid option${CLRct}\n\n"
				PressEnter
			;;
		esac
	done
}

##----------------------------------------##
## Modified by Martinski W. [2025-Dec-10] ##
##----------------------------------------##
Menu_InfluxDB()
{
	local notificationsINFLUXDB  INFLUXDB_PROTO

	while true
	do
		ScriptHeader
		if ToggleNotificationTypes check NOTIFICATIONS_INFLUXDB
		then notificationsINFLUXDB="${PASS}Enabled"
		else notificationsINFLUXDB="${ERR}Disabled"
		fi
		INFLUXDB_PROTO="$(Conf_Parameters check NOTIFICATIONS_INFLUXDB_PROTO | tr 'a-z' 'A-Z')"

		printf "   ${GRNct}1${CLRct}. Toggle InfluxDB Exporting\n"
		printf "      Currently: ${BOLD}${notificationsINFLUXDB}${CLRct}\n\n"
		printf "      ${BOLD}${GRNct}${UNDERLINE}InfluxDB Configuration${CLRct}\n\n"
		printf "  ${GRNct}c1${CLRct}. Set InfluxDB Host\n"
		printf "      Currently: ${SETTING}%s${CLRct}\n\n" "$(Conf_Parameters check NOTIFICATIONS_INFLUXDB_HOST)"
		printf "  ${GRNct}c2${CLRct}. Set InfluxDB Port\n"
		printf "      Currently: ${SETTING}%s${CLRct}\n\n" "$(Conf_Parameters check NOTIFICATIONS_INFLUXDB_PORT)"
		printf "  ${GRNct}c3${CLRct}. Set InfluxDB Protocol\n"
		printf "      Currently: ${SETTING}%s${CLRct}\n\n" "$INFLUXDB_PROTO"
		printf "  ${GRNct}c4${CLRct}. Set InfluxDB Database ID\n"
		printf "      Currently: ${SETTING}%s${CLRct}\n\n" "$(Conf_Parameters check NOTIFICATIONS_INFLUXDB_DB)"
		printf "  ${GRNct}c5${CLRct}. Set InfluxDB Organization\n"
		printf "      Currently: ${SETTING}%s${CLRct}\n\n" "$(Conf_Parameters check NOTIFICATIONS_INFLUXDB_ORG)"
		printf "  ${GRNct}c6${CLRct}. Set InfluxDB Version\n"
		printf "      Currently: ${SETTING}%s${CLRct}\n\n" "$(Conf_Parameters check NOTIFICATIONS_INFLUXDB_VERSION)"
		printf "  ${GRNct}c7${CLRct}. Set InfluxDB Username (v1.8+ only)\n"
		printf "      Currently: ${SETTING}%s${CLRct}\n\n" "$(Conf_Parameters check NOTIFICATIONS_INFLUXDB_USERNAME)"
		printf "  ${GRNct}c8${CLRct}. Set InfluxDB Password (v1.8+ only)\n\n"
		printf "  ${GRNct}c9${CLRct}. Set InfluxDB API Token (v2.x only)\n"
		printf "      Currently: ${SETTING}%s${CLRct}\n\n" "$(Conf_Parameters check NOTIFICATIONS_INFLUXDB_APITOKEN)"
		printf "  ${GRNct}cs${CLRct}. Send test data to InfluxDB\n\n"
		printf "   ${GRNct}e${CLRct}. Go back\n"
		printf "\n${menuSepStr}\n\n"

		printf "Choose an option:  "
		read -r influxdbOption
		case "$influxdbOption" in
			1)
				if ToggleNotificationTypes check NOTIFICATIONS_INFLUXDB
				then
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
				if [ "$(Conf_Parameters check NOTIFICATIONS_INFLUXDB_PROTO)" = "https" ]
				then Conf_Parameters update "InfluxDB Protocol" "http"
				else Conf_Parameters update "InfluxDB Protocol" "https"
				fi
			;;
			c4)
				Notification_String "InfluxDB Database ID"
			;;
			c5)
				Notification_String "InfluxDB Organization"
			;;
			c6)
				if [ "$(Conf_Parameters check NOTIFICATIONS_INFLUXDB_VERSION)" = "1.8" ]
				then Conf_Parameters update "InfluxDB Version" "2.0"
				else Conf_Parameters update "InfluxDB Version" "1.8"
				fi
			;;
			c7)
				Notification_String "InfluxDB Username"
			;;
			c8)
				Notification_String "InfluxDB Password"
			;;
			c9)
				Notification_String "InfluxDB API Token"
			;;
			cs)
				SendToInfluxDB "$(/bin/date +%s)" 30 15 90 '8.8.8.8'
				echo
				PressEnter
			;;
			e)
				break
			;;
			*)
				printf "\n${BOLD}${ERR}Please choose a valid option${CLRct}\n\n"
				PressEnter
			;;
		esac
	done
}

##----------------------------------------##
## Modified by Martinski W. [2025-Dec-15] ##
##----------------------------------------##
Menu_Notifications()
{
	while true
	do
		ScriptHeader
		printf "  ${BOLD}${GRNct}${UNDERLINE}Notification Types${CLRct}\n\n"
		printf "   ${GRNct}1${CLRct}. Ping test success\n"
		printf "      Current methods: ${SETTING}$(NotificationMethods check PingTestOK)${CLRct}\n\n"
		printf "   ${GRNct}2${CLRct}. Ping test failure\n"
		printf "      Current methods: ${SETTING}$(NotificationMethods check PingTestFailed)${CLRct}\n\n"
		printf "   ${GRNct}3${CLRct}. Ping threshold (values above this will trigger an alert)\n"
		printf "      Current threshold: ${SETTING}$(Conf_Parameters check NOTIFICATIONS_PINGTHRESHOLD_VALUE) ms${CLRct}\n"
		printf "      Current methods: ${SETTING}$(NotificationMethods check PingThreshold)${CLRct}\n\n"
		printf "   ${GRNct}4${CLRct}. Jitter threshold (values above this will trigger an alert)\n"
		printf "      Current threshold: ${SETTING}$(Conf_Parameters check NOTIFICATIONS_JITTERTHRESHOLD_VALUE) ms${CLRct}\n"
		printf "      Current methods: ${SETTING}$(NotificationMethods check JitterThreshold)${CLRct}\n\n"
		printf "   ${GRNct}5${CLRct}. Line Quality threshold (values below this will trigger an alert)\n"
		printf "      Current threshold: ${SETTING}$(Conf_Parameters check NOTIFICATIONS_LINEQUALITYTHRESHOLD_VALUE) %%${CLRct}\n"
		printf "      Current methods: ${SETTING}$(NotificationMethods check LineQualityThreshold)${CLRct}\n\n"

		printf "\n  ${BOLD}${GRNct}${UNDERLINE}Notification Methods and Integrations${CLRct}\n\n"
		NOTIFICATION_SETTING=""
		if ToggleNotificationTypes check NOTIFICATIONS_EMAIL
		then NOTIFICATION_SETTING="${PASS}Enabled"
		else NOTIFICATION_SETTING="${ERR}Disabled"
		fi
		printf "  ${GRNct}em${CLRct}. Email (shared with other addons/scripts e.g. Diversion)\n"
		printf "      Currently: ${BOLD}${NOTIFICATION_SETTING}${CLRct}\n\n"
		if ToggleNotificationTypes check NOTIFICATIONS_WEBHOOK
		then NOTIFICATION_SETTING="${PASS}Enabled"
		else NOTIFICATION_SETTING="${ERR}Disabled"
		fi
		printf "  ${GRNct}wb${CLRct}. Discord webhook\n"
		printf "      Currently: ${BOLD}${NOTIFICATION_SETTING}${CLRct}\n\n"
		if ToggleNotificationTypes check NOTIFICATIONS_PUSHOVER
		then NOTIFICATION_SETTING="${PASS}Enabled"
		else NOTIFICATION_SETTING="${ERR}Disabled"
		fi
		printf "  ${GRNct}po${CLRct}. Pushover\n"
		printf "      Currently: ${BOLD}${NOTIFICATION_SETTING}${CLRct}\n\n"
		if ToggleNotificationTypes check NOTIFICATIONS_CUSTOM
		then NOTIFICATION_SETTING="${PASS}Enabled"
		else NOTIFICATION_SETTING="${ERR}Disabled"
		fi
		printf "  ${GRNct}ca${CLRct}. Custom actions and user scripts\n"
		printf "      Currently: ${BOLD}${NOTIFICATION_SETTING}${CLRct}\n\n"
		if ToggleNotificationTypes check NOTIFICATIONS_HEALTHCHECK
		then NOTIFICATION_SETTING="${PASS}Enabled"
		else NOTIFICATION_SETTING="${ERR}Disabled"
		fi
		printf "  ${GRNct}hc${CLRct}. Healthchecks.io\n"
		printf "      Currently: ${BOLD}${NOTIFICATION_SETTING}${CLRct}\n\n"
		if ToggleNotificationTypes check NOTIFICATIONS_INFLUXDB
		then NOTIFICATION_SETTING="${PASS}Enabled"
		else NOTIFICATION_SETTING="${ERR}Disabled"
		fi
		printf "  ${GRNct}id${CLRct}. InfluxDB exporting\n"
		printf "      Currently: ${BOLD}${NOTIFICATION_SETTING}${CLRct}\n\n"
		printf "   ${GRNct}e${CLRct}. Go back\n"
		printf "\n${menuSepStr}\n\n"

		printf "Choose an option:  "
		read -r notificationsmenu
		case "$notificationsmenu" in
			1)
				NotificationMethods update PingTestOK ;;
			2)
				NotificationMethods update PingTestFailed ;;
			3)
				NotificationMethods update PingThreshold ;;
			4)
				NotificationMethods update JitterThreshold ;;
			5)
				NotificationMethods update LineQualityThreshold ;;
			em)
				Menu_EmailNotifications ;;
			wb)
				Menu_WebhookNotifications ;;
			po)
				Menu_PushoverNotifications ;;
			ca)
				Menu_CustomActions ;;
			hc)
				Menu_HealthcheckNotifications ;;
			id)
				Menu_InfluxDB ;;
			e)
				break ;;
			*)
				printf "\n${BOLD}${ERR}Please choose a valid option${CLEARFORMAT}\n\n"
				PressEnter ;;
		esac
	done
}

##----------------------------------------##
## Modified by Martinski W. [2025-Dec-15] ##
##----------------------------------------##
NotificationMethods()
{
	case "$1" in
		update)
			while true
			do
				ScriptHeader
				printf " ${BOLD}${GRNct}${UNDERLINE}${2}${CLRct}\n\n"
				if [ "$2" = "PingThreshold" ]  || \
				   [ "$2" = "JitterThreshold" ] || \
				   [ "$2" = "LineQualityThreshold" ]
				then
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
					printf " ${GRNct}c1${CLRct}. Set threshold value - Currently: ${SETTING}$(Conf_Parameters check "$PARAMETERNAME") $UNIT${CLRct}\n\n"
				fi
				SETTINGNAME="" ; SETTINGVALUE=""

				printf " Please choose the notification methods to enable\n"
				printf " ${BOLD}Currently enabled: ${SETTING}%s${CLRct}\n\n" "$(NotificationMethods check "$2")"
				printf "  ${GRNct}1${CLRct}. Email\n"
				printf "  ${GRNct}2${CLRct}. Webhook\n"
				printf "  ${GRNct}3${CLRct}. Pushover\n"
				printf "  ${GRNct}4${CLRct}. Custom\n"
				printf "  ${GRNct}5${CLRct}. None\n\n"
				printf "  ${GRNct}e${CLRct}. Go back\n\n"
				printf "Choose an option:  "
				read -r methodsmenu
				case "$methodsmenu" in
					1)
						SETTINGVALUE="Email" ;;
					2)
						SETTINGVALUE="Webhook" ;;
					3)
						SETTINGVALUE="Pushover" ;;
					4)
						SETTINGVALUE="Custom" ;;
					5)
						SETTINGVALUE="None" ;;
					c1)
						Notification_Float "$2" ;;
					e)
						break ;;
					*)
						printf "\n${BOLD}${ERR}Please choose a valid option${CLEARFORMAT}\n\n"
						PressEnter ;;
				esac
				if [ "$methodsmenu" != "e" ] && [ "$methodsmenu" != "c1" ]
				then
					case "$2" in
						PingTestOK)
							SETTINGNAME="NOTIFICATIONS_PINGTEST" ;;
						PingTestFailed)
							SETTINGNAME="NOTIFICATIONS_PINGTEST_FAILED" ;;
						PingThreshold)
							SETTINGNAME="NOTIFICATIONS_PINGTHRESHOLD" ;;
						JitterThreshold)
							SETTINGNAME="NOTIFICATIONS_JITTERTHRESHOLD" ;;
						LineQualityThreshold)
							SETTINGNAME="NOTIFICATIONS_LINEQUALITYTHRESHOLD" ;;
					esac
					[ -n "$SETTINGNAME" ] && \
					NOTIFICATION_SETTING="$(Conf_Parameters check "$SETTINGNAME")"

					if [ "$SETTINGVALUE" = "None" ]
					then
						sed -i 's/^'"$SETTINGNAME"'=.*$/'"$SETTINGNAME"'=None/' "$SCRIPT_CONF"
					else
						if echo "$NOTIFICATION_SETTING" | grep -q "$SETTINGVALUE"
						then
							NOTIFICATION_SETTING="$(echo "$NOTIFICATION_SETTING" | sed 's/'"$SETTINGVALUE"'//g;s/,,/,/g;s/,$//;s/^,//')"
							sed -i 's/^'"$SETTINGNAME"'=.*$/'"$SETTINGNAME"'='"$NOTIFICATION_SETTING"'/' "$SCRIPT_CONF"
						else
							NOTIFICATION_SETTING="$(echo "$SETTINGVALUE,$NOTIFICATION_SETTING" | sed 's/None//g;s/,,/,/g;s/,$//;s/^,//')"
							sed -i 's/^'"$SETTINGNAME"'=.*$/'"$SETTINGNAME"'='"$NOTIFICATION_SETTING"'/' "$SCRIPT_CONF"
						fi
						NOTIFICATION_SETTING="$(Conf_Parameters check "$SETTINGNAME")"
						if [ -z "$NOTIFICATION_SETTING" ]
						then
							sed -i 's/^'"$SETTINGNAME"'=.*$/'"$SETTINGNAME"'=None/' "$SCRIPT_CONF"
						fi
					fi
				fi
			done
		;;
		check)
			case "$2" in
				PingTestOK)
					NOTIFICATION_SETTING="$(Conf_Parameters check NOTIFICATIONS_PINGTEST)"
					echo "$NOTIFICATION_SETTING"
				;;
				PingTestFailed)
					NOTIFICATION_SETTING="$(Conf_Parameters check NOTIFICATIONS_PINGTEST_FAILED)"
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

##-------------------------------------##
## Added by Martinski W. [2025-Oct-25] ##
##-------------------------------------##
_CenterTextStr_()
{
    if [ $# -lt 2 ] || [ -z "$1" ] || [ -z "$2" ] || \
       ! echo "$2" | grep -qE "^[1-9][0-9]+$"
    then echo ; return 1
    fi
    local stringLen="${#1}"
    local space1Len="$((($2 - stringLen)/2))"
    local space2Len="$space1Len"
    local totalLen="$((space1Len + stringLen + space2Len))"

    if [ "$totalLen" -lt "$2" ]
    then space2Len="$((space2Len + 1))"
    elif [ "$totalLen" -gt "$2" ]
    then space1Len="$((space1Len - 1))"
    fi
    if [ "$space1Len" -gt 0 ] && [ "$space2Len" -gt 0 ]
    then printf "%*s%s%*s" "$space1Len" '' "$1" "$space2Len" ''
    else printf "%s" "$1"
    fi
}

##----------------------------------------##
## Modified by Martinski W. [2025-Oct-25] ##
##----------------------------------------##
ScriptHeader()
{
	clear
	local spaceLen=56  colorCT
	[ "$SCRIPT_BRANCH" = "master" ] && colorCT="$GRNct" || colorCT="$MGNTct"
	echo
	printf "${BOLD}##############################################################${CLRct}\n"
	printf "${BOLD}##     ___   ___   _ __   _ __   _ __ ___    ___   _ __     ##${CLRct}\n"
	printf "${BOLD}##    / __| / _ \ | '_ \ | '_ \ | '_   _ \  / _ \ | '_ \    ##${CLRct}\n"
	printf "${BOLD}##   | (__ | (_) || | | || | | || | | | | || (_) || | | |   ##${CLRct}\n"
	printf "${BOLD}##    \___| \___/ |_| |_||_| |_||_| |_| |_| \___/ |_| |_|   ##${CLRct}\n"
	printf "${BOLD}##                                                          ##${CLRct}\n"
	printf "${BOLD}## ${GRNct}%s${CLRct}${BOLD} ##${CLRct}\n" "$(_CenterTextStr_ "$versionMod_TAG" "$spaceLen")"
	printf "${BOLD}## ${colorCT}%s${CLRct}${BOLD} ##${CLRct}\n" "$(_CenterTextStr_ "$branchxStr_TAG" "$spaceLen")"
	printf "${BOLD}##                                                          ##${CLRct}\n"
	printf "${BOLD}##           https://github.com/AMTM-OSR/connmon            ##${CLRct}\n"
	printf "${BOLD}##      Forked from https://github.com/jackyaz/connmon      ##${CLRct}\n"
	printf "${BOLD}##                                                          ##${CLRct}\n"
	printf "${BOLD}##############################################################${CLRct}\n\n"
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
## Modified by Martinski W. [2025-Dec-15] ##
##----------------------------------------##
_HandleInvalidMenuOption_()
{
	[ -n "$menuOption" ] && \
	printf "\n${REDct}INVALID input [$menuOption]${CLRct}"
	printf "\nPlease choose a valid option.\n\n"
}

##----------------------------------------##
## Modified by Martinski W. [2025-Dec-15] ##
##----------------------------------------##
_Menu_PingTestOptions_()
{
	local menuOption  exitMenu=false
	local OPTION_FOR_QOS  TEST_SCHED_LINE  TEST_SCHED_DAYS
	local TEST_SCHED_MENU  CRON_SCHED_DAYS  CRON_SCHED_HOUR  CRON_SCHED_MINS

	if [ "$(ExcludeFromQoS check)" = "true" ]
	then OPTION_FOR_QOS="excluded from"
	else OPTION_FOR_QOS="included in"
	fi

	TEST_SCHED_LINE="$(CronTestSchedule check)"
	CRON_SCHED_DAYS="$(echo "$TEST_SCHED_LINE" | cut -f1 -d'|')"
	CRON_SCHED_HOUR="$(echo "$TEST_SCHED_LINE" | cut -f2 -d'|')"
	CRON_SCHED_MINS="$(echo "$TEST_SCHED_LINE" | cut -f3 -d'|')"
	if [ "$CRON_SCHED_DAYS" = "*" ]
	then TEST_SCHED_DAYS="Every day"
	else TEST_SCHED_DAYS="Days of Week: $CRON_SCHED_DAYS"
	fi
	TEST_SCHED_MENU="$(_CronScheduleHourMinsInfo_ "$CRON_SCHED_HOUR" "$CRON_SCHED_MINS")"

	ScriptHeader
	printf " ${BOLDUNDERLN}${GRNct}Ping Test Options${CLRct}\n\n"

	printf "  ${GRNct}1${CLRct}. Set preferred ping server\n"
	printf "     Currently: ${SETTING}%s${CLRct}\n\n" "$(PingServer check)"
	printf "  ${GRNct}2${CLRct}. Set ping test duration\n"
	printf "     Currently: ${SETTING}%s sec.${CLRct}\n\n" "$(PingDuration check)"
	printf "  ${GRNct}3${CLRct}. Set schedule for automatic ping tests\n"
	printf "     Currently: ${SETTING}%s - %s${CLRct}\n\n" "$TEST_SCHED_MENU" "$TEST_SCHED_DAYS"
	printf "  ${GRNct}q${CLRct}. Toggle exclusion of %s ping tests from QoS\n" "$SCRIPT_NAME"
	printf "     Currently: %s ping tests are ${SETTING}%s${CLRct} QoS\n\n" "$SCRIPT_NAME" "$OPTION_FOR_QOS"
	printf "  ${GRNct}e${CLRct}. Return to Main Menu\n"
	printf "\n${menuSepStr}\n\n"

	while true
	do
		printf "Choose an option:  "
		read -r menuOption
		case "$menuOption" in
			1)
				printf "\n"
				PingServer update
				break
			;;
			2)
				printf "\n"
				PingDuration update && PressEnter
				break
			;;
			3)
				printf "\n"
				Menu_EditCronSchedule
				PressEnter
				break
			;;
			q)
				printf "\n"
				if [ "$(ExcludeFromQoS check)" = "true" ]
				then
					ExcludeFromQoS disable
				elif [ "$(ExcludeFromQoS check)" = "false" ]
				then
					ExcludeFromQoS enable
				fi
				break
			;;
			e) exitMenu=true
			   break
			;;
			*)
				_HandleInvalidMenuOption_
				PressEnter
				break
			;;
		esac
	done

	"$exitMenu" && return 0
	_Menu_PingTestOptions_
}

##----------------------------------------##
## Modified by Martinski W. [2025-Dec-15] ##
##----------------------------------------##
_Menu_DatabaseOptions_()
{
	local menuOption  exitMenu=false  storageLocStr
	local jffsFreeSpace  jffsFreeSpaceStr  jffsSpaceMsgTag

	storageLocStr="$(ScriptStorageLocation check | tr 'a-z' 'A-Z')"

	_UpdateJFFS_FreeSpaceInfo_
	jffsFreeSpace="$(_Get_JFFS_Space_ FREE HRx | sed 's/%/%%/')"
	if ! echo "$JFFS_LowFreeSpaceStatus" | grep -E "^WARNING[0-9]$"
	then
		jffsFreeSpaceStr="${SETTING}$jffsFreeSpace"
	else
		if [ "$storageLocStr" = "JFFS" ]
		then jffsSpaceMsgTag="${CritBREDct} <<< WARNING! "
		else jffsSpaceMsgTag="${WarnBMGNct} <<< NOTICE! "
		fi
		jffsFreeSpaceStr="${WarnBYLWct} $jffsFreeSpace ${CLRct}  ${jffsSpaceMsgTag}${CLRct}"
	fi

	ScriptHeader
	printf " ${BOLDUNDERLN}${GRNct}Database Options${CLRct}\n\n"

	printf "   ${GRNct}1${CLRct}. Toggle time output mode\n"
	printf "      Currently: ${SETTING}%s${CLRct} time values will be used for CSV exports\n\n" "$(OutputTimeMode check)"
	printf "   ${GRNct}2${CLRct}. Set number of ping test database results to show in WebUI\n"
	printf "      Currently: ${SETTING}%s results will be shown${CLRct}\n\n" "$(LastXResults check)"
	printf "   ${GRNct}3${CLRct}. Set maximum number of days data to keep in database\n"
	printf "      Currently: ${SETTING}%s days data will be kept${CLRct}\n\n" "$(DaysToKeep check)"
	printf "   ${GRNct}s${CLRct}. Toggle storage location for database stats and config\n"
	printf "      Current location: ${SETTING}%s${CLRct}\n" "$storageLocStr"
	printf "      JFFS Available: ${jffsFreeSpaceStr}${CLRct}\n\n"
	printf "  ${GRNct}rs${CLRct}. Reset %s database / delete all data\n\n" "$SCRIPT_NAME"
	printf "   ${GRNct}e${CLRct}. Return to Main Menu\n"
	printf "\n${menuSepStr}\n\n"

	while true
	do
		printf "Choose an option:  "
		read -r menuOption
		case "$menuOption" in
			1)
				printf "\n"
				if [ "$(OutputTimeMode check)" = "unix" ]
				then
					OutputTimeMode non-unix
				elif [ "$(OutputTimeMode check)" = "non-unix" ]
				then
					OutputTimeMode unix
				fi
				break
			;;
			2)
				printf "\n"
				LastXResults update && PressEnter
				break
			;;
			3)
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
			rs)
				printf "\n"
				if Check_Lock menu
				then
					Menu_ResetDB
					Clear_Lock
				fi
				PressEnter
				break
			;;
			e) exitMenu=true
			   break
			;;
			*)
				_HandleInvalidMenuOption_
				PressEnter
				break
			;;
		esac
	done

	"$exitMenu" && return 0
	_Menu_DatabaseOptions_
}

##----------------------------------------##
## Modified by Martinski W. [2025-Dec-15] ##
##----------------------------------------##
MainMenu()
{
	local menuOption  automaticModeStatus

	if AutomaticMode check
	then automaticModeStatus="${PassBGRNct} ENABLED ${CLRct}"
	else automaticModeStatus="${CritIREDct} DISABLED ${CLRct}"
	fi
	_UpdateJFFS_FreeSpaceInfo_

	printf " WebUI for %s is available at:\n" "$SCRIPT_NAME"
	printf " ${SETTING}%s${CLRct}\n\n" "$(Get_WebUI_URL)"

	printf "   ${GRNct}1${CLRct}. Check connection now\n"
	printf "      Database size: ${SETTING}%s${CLRct}\n\n" "$(_GetFileSize_ "$CONNSTATS_DB" HRx)"
	printf "   ${GRNct}2${CLRct}. Toggle automatic ping tests\n"
	printf "      Currently: ${automaticModeStatus}${CLRct}\n\n"
	printf "   ${GRNct}3${CLRct}. Configure ping test options\n\n"
	printf "   ${GRNct}4${CLRct}. Configure database options\n\n"
	printf "   ${GRNct}n${CLRct}. Configure notifications and integrations for %s\n\n" "$SCRIPT_NAME"
	printf "   ${GRNct}u${CLRct}. Check for updates\n"
	printf "  ${GRNct}uf${CLRct}. Update %s with latest version (force update)\n\n" "$SCRIPT_NAME"
	printf "  ${GRNct}cl${CLRct}. View changelog for %s (use q to exit)\n\n" "$SCRIPT_NAME"
	printf "   ${GRNct}e${CLRct}. Exit %s\n\n" "$SCRIPT_NAME"
	printf "   ${GRNct}z${CLRct}. Uninstall %s\n" "$SCRIPT_NAME"
	printf "\n${menuSepStr}\n\n"

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
			3)
				_Menu_PingTestOptions_
				break
			;;
			4)
				_Menu_DatabaseOptions_
				break
			;;
			n)
				printf "\n"
				Menu_Notifications
				break
			;;
			u)
				printf "\n"
				if Check_Lock menu
				then
					Update_Version
					Clear_Lock
				fi
				PressEnter
				break
			;;
			uf)
				printf "\n"
				if Check_Lock menu
				then
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
			e)
				ScriptHeader
				printf "\n${BOLD}Thanks for using %s!${CLRct}\n\n\n" "$SCRIPT_NAME"
				exit 0
			;;
			z)
				while true
				do
					printf "\n${BOLD}Are you sure you want to uninstall %s? (y/n)${CLRct}  " "$SCRIPT_NAME"
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
				_HandleInvalidMenuOption_
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
	ScriptStorageLocation load
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

	Download_File "$SCRIPT_REPO/LICENSE" "$SCRIPT_DIR/LICENSE"

	ScriptHeader
	MainMenu
}

##-------------------------------------##
## Added by Martinski W. [2025-Nov-04] ##
##-------------------------------------##
_SetParameters_()
{
    if [ -f "/opt/share/$SCRIPT_NAME.d/config" ]
    then SCRIPT_STORAGE_DIR="/opt/share/${SCRIPT_NAME}.d"
    else SCRIPT_STORAGE_DIR="/jffs/addons/${SCRIPT_NAME}.d"
    fi

    SCRIPT_CONF="$SCRIPT_STORAGE_DIR/config"
    CONNSTATS_DB="$SCRIPT_STORAGE_DIR/connstats.db"
    CSV_OUTPUT_DIR="$SCRIPT_STORAGE_DIR/csv"
    USER_SCRIPT_DIR="$SCRIPT_STORAGE_DIR/userscripts.d"
}

##----------------------------------------##
## Modified by Martinski W. [2025-May-13] ##
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
			Print_Output true "$1 contains Entware, $SCRIPT_NAME $SCRIPT_VERSION starting up" "$PASS"
		fi
	fi

	NTP_Ready
	Entware_Ready
	_SetParameters_
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
	Set_Version_Custom_Settings local "$SCRIPT_VERSION"
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
Menu_EditCronSchedule()
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
		printf " ${BOLD}Current schedule: ${GRNct}$(_GetScheduleHR_ "$cruHour" "$cruMins" "$cruDays")${CLRct}\n\n"
		printf " ${BOLD}Please enter the DAYS of the week when to run the ping tests.\n"
		printf " [${GRNct}0-6${CLRct}], ${GRNct}0${CLRct}=Sunday, ${GRNct}6${CLRct}=Saturday,"
		printf " ${GRNct}*${CLRct}=Every day, or comma-separated days.${CLRct}"
		printf "\n\n ${BOLD}Enter DAYS of the week (${GRNct}e${CLRct}=Exit)${CLRct}:  "
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
			printf " ${BOLD}Please choose the method to specify the hour/minute(s)\n"
			printf " to run the ping tests:${CLRct}\n\n"
			printf "  ${GRNct}1${CLRct}. Every X hours/minutes\n"
			printf "  ${GRNct}2${CLRct}. Custom\n"
			printf "  ${GRNct}e${CLRct}. Go back\n\n"
			printf "Choose an option:  "
			read -r formatChoice

			case "$formatChoice" in
				1) formatType="everyx" ; echo ; break ;;
				2) formatType="custom" ; echo ; break ;;
				e) exitMenu=true ; break ;;
				*) printf "\n${ERR}Please enter a valid choice [1-2]${CLRct}\n"
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
				printf " ${BOLD}Please choose whether to specify every X hours or every X minutes\n"
				printf " to run the ping tests:${CLRct}\n\n"
				printf "  ${GRNct}1${CLRct}. Hours\n"
				printf "  ${GRNct}2${CLRct}. Minutes\n"
				printf "  ${GRNct}e${CLRct}. Go back\n\n"
				printf "Choose an option:  "
				read -r formatChoice

				case "$formatChoice" in
					1) formatType="hours" ; echo ; break ;;
					2) formatType="mins" ; echo ; break ;;
					e) exitMenu=true ; break ;;
					*) printf "\n${ERR}Please enter a valid choice [1-2]${CLRct}\n"
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
				printf " ${BOLD}Current schedule: ${GRNct}$(_GetScheduleHR_ "$cruHour" "$cruMins" "$cruDays")${CLRct}\n\n"
				printf " ${BOLD}Please enter how often in HOURS to run the ping tests.\n"
				printf " Every X hours, where X is [${GRNct}1-24${CLRct}], (${GRNct}e${CLRct}=Exit)${CLRct}:  "
				read -r hour_choice

				if [ "$hour_choice" = "e" ]
				then
					exitMenu=true ; break
				elif [ -z "$hour_choice" ]
				then
					if _ValidateCronHOURS_ "$cruHour" -quiet || \
					   _ValidateCronFreqHOURS_ "$cruHour" -quiet
					then echo ; break ; fi
					printf "\n${ERR}Please enter a number between 1 and 24${CLRct}\n"
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
				printf " ${BOLD}Current schedule: ${GRNct}$(_GetScheduleHR_ "$cruHour" "$cruMins" "$cruDays")${CLRct}\n\n"
				printf " ${BOLD}Please enter how often in MINUTES to run the ping tests.\n"
				printf " Every X minutes, where X is [${GRNct}1-30${CLRct}], (${GRNct}e${CLRct}=Exit)${CLRct}:  "
				read -r mins_choice

				if [ "$mins_choice" = "e" ]
				then
					exitMenu=true ; break
				elif [ -z "$mins_choice" ]
				then
					if _ValidateCronMINS_ "$cruMins" -quiet || \
					   _ValidateCronFreqMINS_ "$cruMins" -quiet
					then echo ; break ; fi
					printf "\n${ERR}Please enter a number between 1 and 30${CLRct}\n"
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
				printf " ${BOLD}Current schedule: ${GRNct}$(_GetScheduleHR_ "$cruHour" "$cruMins" "$cruDays")${CLRct}\n\n"
				printf " ${BOLD}Please enter the HOURS when to run the ping tests.\n"
				printf " [${GRNct}0-23${CLRct}], ${GRNct}*${CLRct}=Every hour, or comma-separated hours, (${GRNct}e${CLRct}=Exit)${CLRct}:  "
				read -r hour_choice

				if [ "$hour_choice" = "e" ]
				then
					exitMenu=true ; break
				elif [ -z "$hour_choice" ]
				then
					if _ValidateCronHOURS_ "$cruHour" -quiet || \
					   _ValidateCronFreqHOURS_ "$cruHour" -quiet
					then echo ; break ; fi
					printf "\n${ERR}Please enter a number between 0 and 23${CLRct}\n"
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
				printf " ${BOLD}Current schedule: ${GRNct}$(_GetScheduleHR_ "$cruHour" "$cruMins" "$cruDays")${CLRct}\n\n"
				printf " ${BOLD}Please enter the MINUTES when to run the ping tests.\n"
				printf " [${GRNct}0-59${CLRct}], ${GRNct}*${CLRct}=Every minute, or comma-separated minutes, (${GRNct}e${CLRct}=Exit)${CLRct}:  "
				read -r mins_choice

				if [ "$mins_choice" = "e" ]
				then
					exitMenu=true ; break
				elif [ -z "$mins_choice" ]
				then
					if _ValidateCronMINS_ "$cruMins" -quiet || \
					   _ValidateCronFreqMINS_ "$cruMins" -quiet
					then echo ; break ; fi
					printf "\n${ERR}Please enter a number between 0 and 59${CLRct}\n"
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
	printf "${BOLD}${WARN}WARNING: This will reset the %s database by deleting all database records.\n" "$SCRIPT_NAME"
	printf "A backup of the database will be created if you change your mind.${CLRct}\n"
	printf "\n${BOLD}Do you want to continue? (y/n)${CLRct}  "
	read -r confirm
	case "$confirm" in
		y|Y)
			printf "\n"
			Reset_DB
		;;
		*)
			printf "\n${BOLD}${WARN}Database reset cancelled${CLRct}\n\n"
		;;
	esac
}

##-------------------------------------##
## Added by Martinski W. [2025-Feb-16] ##
##-------------------------------------##
_RemoveMenuAddOnsSection_()
{
   if [ $# -lt 2 ] || [ -z "$1" ] || [ -z "$2" ] || \
      ! echo "$1" | grep -qE "^[1-9][0-9]*$" || \
      ! echo "$2" | grep -qE "^[1-9][0-9]*$" || \
      [ "$1" -ge "$2" ]
   then return 1 ; fi
   local BEGINnum="$1"  ENDINnum="$2"

   if [ -n "$(sed -E "${BEGINnum},${ENDINnum}!d;/${webPageLineTabExp}/!d" "$TEMP_MENU_TREE")" ]
   then return 1
   fi
   sed -i "${BEGINnum},${ENDINnum}d" "$TEMP_MENU_TREE"
   return 0
}

##-------------------------------------##
## Added by Martinski W. [2025-Feb-16] ##
##-------------------------------------##
_FindandRemoveMenuAddOnsSection_()
{
   local BEGINnum  ENDINnum  retCode=1

   if grep -qE "^${BEGIN_MenuAddOnsTag}$" "$TEMP_MENU_TREE" && \
      grep -qE "^${ENDIN_MenuAddOnsTag}$" "$TEMP_MENU_TREE"
   then
       BEGINnum="$(grep -nE "^${BEGIN_MenuAddOnsTag}$" "$TEMP_MENU_TREE" | awk -F ':' '{print $1}')"
       ENDINnum="$(grep -nE "^${ENDIN_MenuAddOnsTag}$" "$TEMP_MENU_TREE" | awk -F ':' '{print $1}')"
       _RemoveMenuAddOnsSection_ "$BEGINnum" "$ENDINnum" && retCode=0
   fi

   if grep -qE "^${webPageMenuAddons}$" "$TEMP_MENU_TREE" && \
      grep -qE "${webPageHelpSupprt}$" "$TEMP_MENU_TREE"
   then
       BEGINnum="$(grep -nE "^${webPageMenuAddons}$" "$TEMP_MENU_TREE" | awk -F ':' '{print $1}')"
       ENDINnum="$(grep -nE "${webPageHelpSupprt}$" "$TEMP_MENU_TREE" | awk -F ':' '{print $1}')"
       if [ -n "$BEGINnum" ] && [ -n "$ENDINnum" ] && [ "$BEGINnum" -lt "$ENDINnum" ]
       then
           BEGINnum="$((BEGINnum - 2))" ; ENDINnum="$((ENDINnum + 3))"
           if [ "$(sed -n "${BEGINnum}p" "$TEMP_MENU_TREE")" = "," ] && \
              [ "$(sed -n "${ENDINnum}p" "$TEMP_MENU_TREE")" = "}" ]
           then
               _RemoveMenuAddOnsSection_ "$BEGINnum" "$ENDINnum" && retCode=0
           fi
       fi
   fi
   return "$retCode"
}

##----------------------------------------##
## Modified by Martinski W. [2025-Feb-16] ##
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
	if [ -n "$MyWebPage" ] && \
	   [ "$MyWebPage" != "NONE" ] && \
	   [ -f "$TEMP_MENU_TREE" ]
	then
		sed -i "\\~$MyWebPage~d" "$TEMP_MENU_TREE"
		rm -f "$SCRIPT_WEBPAGE_DIR/$MyWebPage"
		rm -f "$SCRIPT_WEBPAGE_DIR/$(echo "$MyWebPage" | cut -f1 -d'.').title"
		_FindandRemoveMenuAddOnsSection_
		umount /www/require/modules/menuTree.js
		mount -o bind "$TEMP_MENU_TREE" /www/require/modules/menuTree.js
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

##----------------------------------------##
## Modified by Martinski W. [2025-Feb-28] ##
##----------------------------------------##
NTP_Ready()
{
	local theSleepDelay=15  ntpMaxWaitSecs=600  ntpWaitSecs

	if [ "$(nvram get ntp_ready)" -eq 0 ]
	then
		Check_Lock
		ntpWaitSecs=0
		Print_Output true "Waiting for NTP to sync..." "$WARN"

		while [ "$(nvram get ntp_ready)" -eq 0 ] && [ "$ntpWaitSecs" -lt "$ntpMaxWaitSecs" ]
		do
			if [ "$ntpWaitSecs" -gt 0 ] && [ "$((ntpWaitSecs % 30))" -eq 0 ]
			then
			    Print_Output true "Waiting for NTP to sync [$ntpWaitSecs secs]..." "$WARN"
			fi
			sleep "$theSleepDelay"
			ntpWaitSecs="$((ntpWaitSecs + theSleepDelay))"
		done

		if [ "$ntpWaitSecs" -ge "$ntpMaxWaitSecs" ]
		then
			Print_Output true "NTP failed to sync after 10 minutes. Please resolve!" "$CRIT"
			Clear_Lock
			exit 1
		else
			Print_Output true "NTP has synced [$ntpWaitSecs secs]. $SCRIPT_NAME will now continue." "$PASS"
			Clear_Lock
		fi
	fi
}

### function based on @Adamm00's Skynet USB wait function ###
##----------------------------------------##
## Modified by Martinski W. [2025-Feb-28] ##
##----------------------------------------##
Entware_Ready()
{
	local theSleepDelay=5  maxSleepTimer=120  sleepTimerSecs

	if [ ! -f /opt/bin/opkg ]
	then
		Check_Lock
		sleepTimerSecs=0

		while [ ! -f /opt/bin/opkg ] && [ "$sleepTimerSecs" -lt "$maxSleepTimer" ]
		do
			if [ "$((sleepTimerSecs % 10))" -eq 0 ]
			then
			    Print_Output true "Entware NOT found. Wait for Entware to be ready [$sleepTimerSecs secs]..." "$WARN"
			fi
			sleep "$theSleepDelay"
			sleepTimerSecs="$((sleepTimerSecs + theSleepDelay))"
		done

		if [ ! -f /opt/bin/opkg ]
		then
			Print_Output true "Entware NOT found and is required for $SCRIPT_NAME to run, please resolve!" "$CRIT"
			Clear_Lock
			exit 1
		else
			Print_Output true "Entware found [$sleepTimerSecs secs]. $SCRIPT_NAME will now continue." "$PASS"
			Clear_Lock
		fi
	fi
}

### function based on @dave14305's FlexQoS about function ###
##----------------------------------------##
## Modified by Martinski W. [2025-May-13] ##
##----------------------------------------##
Show_About()
{
	printf "About ${MGNTct}${SCRIPT_VERS_INFO}${CLRct}\n"
	cat <<EOF
  $SCRIPT_NAME is an internet connection monitoring tool for
  AsusWRT Merlin with charts for daily, weekly and monthly
  summaries.

License
  $SCRIPT_NAME is free to use under the GNU General Public License
  version 3 (GPL-3.0) https://opensource.org/licenses/GPL-3.0

Help & Support
  https://www.snbforums.com/forums/asuswrt-merlin-addons.60/?prefix_id=18

Source code
  https://github.com/AMTM-OSR/$SCRIPT_NAME
EOF
	printf "\n"
}

### function based on @dave14305's FlexQoS show_help function ###
##----------------------------------------##
## Modified by Martinski W. [2025-May-13] ##
##----------------------------------------##
Show_Help()
{
	printf "HELP ${MGNTct}${SCRIPT_VERS_INFO}${CLRct}\n"
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
  $SCRIPT_NAME develop          switch to development branch version
  $SCRIPT_NAME stable           switch to stable/production branch version
EOF
	printf "\n"
}

##-------------------------------------##
## Added by Martinski W. [2024-Dec-21] ##
##-------------------------------------##
TMPDIR="$SHARE_TEMP_DIR"
SQLITE_TMPDIR="$TMPDIR"
export SQLITE_TMPDIR TMPDIR

if [ -d "$TMPDIR" ]
then sqlDBLogFilePath="${TMPDIR}/$sqlDBLogFileName"
else sqlDBLogFilePath="/tmp/var/tmp/$sqlDBLogFileName"
fi
_SQLCheckDBLogFileSize_

_SetParameters_
JFFS_LowFreeSpaceStatus="OK"
updateJFFS_SpaceInfo=false

if [ "$SCRIPT_BRANCH" = "master" ]
then SCRIPT_VERS_INFO=""
else SCRIPT_VERS_INFO="[$versionDev_TAG]"
fi

##----------------------------------------##
## Modified by Martinski W. [2025-Feb-11] ##
##----------------------------------------##
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
	ScriptStorageLocation load
	Create_Symlinks
	Auto_Startup create 2>/dev/null
	if AutomaticMode check
	then Auto_Cron create 2>/dev/null
	else Auto_Cron delete 2>/dev/null
	fi
	Set_Version_Custom_Settings local "$SCRIPT_VERSION"
	Auto_ServiceEvent create 2>/dev/null
	Shortcut_Script create
	_CheckFor_WebGUI_Page_
	Process_Upgrade
	ScriptHeader
	MainMenu
	exit 0
fi

##----------------------------------------##
## Modified by Martinski W. [2026-Feb-18] ##
##----------------------------------------##
case "$1" in
	install)
		Check_Lock
		Menu_Install
		exit 0
	;;
	startup)
		shift
		Menu_Startup "$@"
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
		updateJFFS_SpaceInfo=true
		if [ "$2" = "start" ] && [ "$3" = "$SCRIPT_NAME" ]
		then
			rm -f "$SCRIPT_WEB_DIR/detect_connmon.js"
			rm -f /tmp/pingfile.txt
			rm -f "$SCRIPT_WEB_DIR/ping-result.txt"
			Check_Lock webui
			sleep 3
			Run_PingTest
			updateJFFS_SpaceInfo=false
			Clear_Lock
		elif [ "$2" = "start" ] && [ "$3" = "${SCRIPT_NAME}config" ]
		then
			Check_Lock webui
			echo 'var savestatus = "InProgress";' > "$SCRIPT_WEB_DIR/detect_save.js"
			sleep 3
			Conf_FromSettings
			echo 'var savestatus = "Success";' > "$SCRIPT_WEB_DIR/detect_save.js"
			Clear_Lock
		elif [ "$2" = "start" ] && [ "$3" = "${SCRIPT_NAME}emailconfig" ]
		then
			echo 'var savestatus = "InProgress";' > "$SCRIPT_WEB_DIR/detect_save.js"
			sleep 3
			EmailConf_FromSettings
			echo 'var savestatus = "Success";' > "$SCRIPT_WEB_DIR/detect_save.js"
		elif [ "$2" = "start" ] && [ "$3" = "${SCRIPT_NAME}checkupdate" ]
		then
			Update_Check
		elif [ "$2" = "start" ] && [ "$3" = "${SCRIPT_NAME}doupdate" ]
		then
			Update_Version force unattended
		elif [ "$2" = "start" ] && [ "$3" = "${SCRIPT_NAME}emailpassword" ]
		then
			if Email_ConfExists
			then
				rm -f "$SCRIPT_WEB_DIR/password.htm"
				sleep 1
				Email_Decrypt_Password > "$SCRIPT_WEB_DIR/password.htm"
			fi
		elif [ "$2" = "start" ] && [ "$3" = "${SCRIPT_NAME}deleteemailpassword" ]
		then
			rm -f "$SCRIPT_WEB_DIR/password.htm"
		elif [ "$2" = "start" ] && [ "$3" = "${SCRIPT_NAME}customactionlist" ]
		then
			rm -f "$SCRIPT_STORAGE_DIR/.customactionlist"
			sleep 1
			CustomAction_List silent
		elif [ "$2" = "start" ] && [ "$3" = "${SCRIPT_NAME}TestEmail" ]
		then
			rm -f "$SCRIPT_WEB_DIR/detect_test.js"
			echo 'var teststatus = "InProgress";' > "$SCRIPT_WEB_DIR/detect_test.js"
			noteStr="<p>This is a test email!<br/>Router: ${ROUTER_MODEL}</p>"
			NOTIFICATIONS_EMAIL_LIST="$(Email_Recipients check)"
			if [ -z "$NOTIFICATIONS_EMAIL_LIST" ]
			then
				if SendEmail "Test email from $SCRIPT_NAME - $(/bin/date +"%c")" "$noteStr"
				then
					echo 'var teststatus = "Success";' > "$SCRIPT_WEB_DIR/detect_test.js"
				else
					echo 'var teststatus = "Fail";' > "$SCRIPT_WEB_DIR/detect_test.js"
				fi
			else
				IFS=$','
				success=true
				for EMAIL in $NOTIFICATIONS_EMAIL_LIST
				do
					if ! SendEmail "Test email from $SCRIPT_NAME - $(/bin/date +"%c")" "$noteStr" "$EMAIL"
					then
						success=false
					fi
				done
				if [ "$success" = "true" ]
				then
					echo 'var teststatus = "Success";' > "$SCRIPT_WEB_DIR/detect_test.js"
				else
					echo 'var teststatus = "Fail";' > "$SCRIPT_WEB_DIR/detect_test.js"
				fi
			fi
			unset IFS
		elif [ "$2" = "start" ] && [ "$3" = "${SCRIPT_NAME}TestWebhooks" ]
		then
			rm -f "$SCRIPT_WEB_DIR/detect_test.js"
			echo 'var teststatus = "InProgress";' > "$SCRIPT_WEB_DIR/detect_test.js"
			NOTIFICATIONS_WEBHOOK_LIST="$(Webhook_Targets check)"
			if [ -z "$NOTIFICATIONS_WEBHOOK_LIST" ]
			then
				echo 'var teststatus = "Fail";' > "$SCRIPT_WEB_DIR/detect_test.js"
			fi
			IFS=$','
			success=true
			noteStr="This is a test Webhook message!\nRouter: $ROUTER_MODEL"
			for WEBHOOK in $NOTIFICATIONS_WEBHOOK_LIST
			do
				if ! SendWebhook "Test message from $SCRIPT_NAME - $(/bin/date +"%c")\n\n$noteStr" "$WEBHOOK"
				then
					success=false
				fi
			done
			unset IFS
			if [ "$success" = "true" ]
			then
				echo 'var teststatus = "Success";' > "$SCRIPT_WEB_DIR/detect_test.js"
			else
				echo 'var teststatus = "Fail";' > "$SCRIPT_WEB_DIR/detect_test.js"
			fi
		elif [ "$2" = "start" ] && [ "$3" = "${SCRIPT_NAME}TestPushover" ]
		then
			rm -f "$SCRIPT_WEB_DIR/detect_test.js"
			echo 'var teststatus = "InProgress";' > "$SCRIPT_WEB_DIR/detect_test.js"
			noteStr="This is a test Pushover message!"$'\n'"Router: $ROUTER_MODEL"
			if SendPushover "Test message from $SCRIPT_NAME - $(/bin/date +"%c")"$'\n'$'\n'"$noteStr"
			then
				echo 'var teststatus = "Success";' > "$SCRIPT_WEB_DIR/detect_test.js"
			else
				echo 'var teststatus = "Fail";' > "$SCRIPT_WEB_DIR/detect_test.js"
			fi
		elif [ "$2" = "start" ] && [ "$3" = "${SCRIPT_NAME}TestCustomActions" ]
		then
			rm -f "$SCRIPT_WEB_DIR/detect_test.js"
			echo 'var teststatus = "InProgress";' > "$SCRIPT_WEB_DIR/detect_test.js"
			if [ -z "$(ls -1A "$USER_SCRIPT_DIR"/*.sh 2>/dev/null)" ]
			then
				echo 'var teststatus = "Fail";' > "$SCRIPT_WEB_DIR/detect_test.js"
			else
				printf "\n"
				shFileCount=0
				FILES="$USER_SCRIPT_DIR/*.sh"
				for shFile in $FILES
				do
					if [ -s "$shFile" ]
					then
						shFileCount="$((shFileCount + 1))"
						sh "$shFile" PingTestOK "$(/bin/date +%c)" '30 ms' '15 ms' '90%' '8.8.8.8'
					fi
				done
				if [ "$shFileCount" -eq 0 ]
				then
					echo 'var teststatus = "Fail";' > "$SCRIPT_WEB_DIR/detect_test.js"
				else
					echo 'var teststatus = "Success";' > "$SCRIPT_WEB_DIR/detect_test.js"
				fi
			fi
		elif [ "$2" = "start" ] && [ "$3" = "${SCRIPT_NAME}TestHealthcheck" ]
		then
			rm -f "$SCRIPT_WEB_DIR/detect_test.js"
			echo 'var teststatus = "InProgress";' > "$SCRIPT_WEB_DIR/detect_test.js"
			if SendHealthcheckPing "Pass"
			then
				echo 'var teststatus = "Success";' > "$SCRIPT_WEB_DIR/detect_test.js"
			else
				echo 'var teststatus = "Fail";' > "$SCRIPT_WEB_DIR/detect_test.js"
			fi
		elif [ "$2" = "start" ] && [ "$3" = "${SCRIPT_NAME}TestInfluxDB" ]
		then
			rm -f "$SCRIPT_WEB_DIR/detect_test.js"
			echo 'var teststatus = "InProgress";' > "$SCRIPT_WEB_DIR/detect_test.js"
			if SendToInfluxDB "$(/bin/date +%s)" 30 15 90 '8.8.8.8'
			then
				echo 'var teststatus = "Success";' > "$SCRIPT_WEB_DIR/detect_test.js"
			else
				echo 'var teststatus = "Fail";' > "$SCRIPT_WEB_DIR/detect_test.js"
			fi
		fi
		"$updateJFFS_SpaceInfo" && _UpdateJFFS_FreeSpaceInfo_
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
	amtmupdate)
		shift
		ScriptUpdateFromAMTM "$@"
		exit "$?"
	;;
	postupdate)
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
		SCRIPT_REPO="https://raw.githubusercontent.com/AMTM-OSR/$SCRIPT_NAME/$SCRIPT_BRANCH"
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

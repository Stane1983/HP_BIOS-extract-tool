#!/bin/bash

##################################################################################################################################
#                                                                                                                                #
# Copyright Stanislav Vlasic 2017                                                                                                #
#                                                                                                                                #
# Permission is hereby granted, free of charge, to any person obtaining a copy of this software                                  #
# and associated documentation files (the "Software"), to deal in the Software without restriction,                              #
# including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense,                          #
# and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so,                          #
# subject to the following conditions:                                                                                           #
#                                                                                                                                #
# The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software. #
#                                                                                                                                #
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED                  #
# TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL                  #
# THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,        #
# TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.       #
#                                                                                                                                #
##################################################################################################################################

param_count="$#"

# options
for i in "$@"
do
case $i in
    --file=*)
    FILE="${i#*=}"
    ;;
    --output=*)
    OUT_FOLDER="${i#*=}"
    ;;
    --help)
    SHOW_HELP=true
    ;;
    *)
    # unknown option
    ;;
esac
done

curr_folder=$(pwd)
curr_time=$(date +%Y%m%d%H%M%S)
curr_uid=$(id -u $SUDO_USER)
curr_gid=$(id -g $SUDO_USER)
tmp_folder="/tmp/HP-BIOS-$curr_time/"

FNT_BOLD="\033[1m"
FNT_RED="\033[0;31m"
FNT_GREEN="\033[0;32m"
FNT_RESET="\033[0m"

pr_error()
{
    error="ERROR: "
    message=$1
    echo -e "$FNT_BOLD$FNT_RED$error$FNT_RESET$message$FNT_RESET"
}

pr_info()
{
    info="INFO: "
    message=$1
    echo -e "$FNT_BOLD$FNT_GREEN$info$FNT_RESET$message$FNT_RESET"
}

check_show_help()
{
	if [ "$SHOW_HELP" = true -o "$param_count" = "0" ] ; then
		echo " "
		echo "HP BIOS extract tool v0.1"
		echo "========================="
		echo " "
		echo "This program is licensed under MIT license"
		echo " "
		echo "Commands:"
		echo " "
		echo " $0 parameters:"
		echo " "
		echo "  --file=<filename>       - File of executable downloaded from HP website"
		echo "  --output=<folder>       - Output folder for USB content (optional)"
		echo "                            NOTE: Must not contain trailing slash"
		echo "                            Default location: $curr_folder/USB-$curr_time"
		echo "  --help                  - This screen"
		echo " "
		exit 0
	fi
}

check_su()
{
    if [ ! "$(id -u)" = "0" ] ; then
      pr_error "This script must be run as root\n"
      exit 1
    fi
}

check_commands()
{
	cmd_cab=$(which cabextract)
	cmd_dmidecode=$(which dmidecode)
	cmd_awk=$(which awk)
	
	if [ "$cmd_cab" = "" ]; then
		pr_error "Command cabextract is not found on your system. Install it before running this script"
		exit 1
	fi
	if [ "$cmd_dmidecode" = "" ]; then
		pr_error "Command dmidecode is not found on your system. Install it before running this script"
		exit 1
	fi
	if [ "$cmd_awk" = "" ]; then
		pr_error "Command awk is not found on your system. Install it before running this script"
		exit 1
	fi
}

get_system_name()
{
	echo "$(dmidecode -t system |grep "Product Name:" | awk -F": " '/./{print $2}')"
}

get_bios_type()
{
	echo "$(dmidecode -t bios |grep "Version:" | awk '{print $2}')"
}

get_bios_version()
{
	var_printable=$1
	if [ "$var_printable" = true ] ; then
		echo "$(dmidecode -t bios |grep "Version:" | awk '{print $4}')"
	else
		echo "$(dmidecode -t bios |grep "Version:" | awk '{print $4}' | awk -F"." '/./{print $1 $2}')"
	fi
}

get_bios_info()
{
	echo " "
	echo "Your system"
	echo "==========="
	sys_name="$(get_system_name)"
	type="$(get_bios_type)"
	version="$(get_bios_version true)"
	echo "System:       $sys_name"
	echo "BIOS type:    $type"
	echo -e "BIOS version: $version\n"
}

check_file_exists()
{
	if [ ! -f $FILE ] ; then
		pr_error "Provided file name does not exist ($FILE)"
		exit 1
	fi
	if [ "$FILE" = "" ] ; then
		pr_error "HP executable file not provided"
		exit 1
	fi
}

check_out_folder()
{
	if [ ! "$OUT_FOLDER" = "" ] ; then
		mkdir -p "$OUT_FOLDER"
	else
		OUT_FOLDER="$curr_folder/USB-$curr_time"
		mkdir -p "$OUT_FOLDER"
	fi
}

extract_exe_do_work()
{
	mkdir -p "$tmp_folder"
	echo "Extracting content of archive..."
	cabextract  "$FILE" -q -d "$tmp_folder"
	usbupdate_exists=$(find "$tmp_folder" -type d -name BIOSUpdate)
	
	if [ "$usbupdate_exists" = "" ] ; then
		pr_error "Package does not contain BIOS update files"
		rm -rf "$tmp_folder"
		rm -rf "$OUT_FOLDER"
		exit 1
	else
		type="$(get_bios_type)"
		bios_file=$(find "$tmp_folder" -name "$type*.bin")
		
		if [ "$bios_file" = "" ] ; then
			pr_error "Package does not contain BIOS update file compatible with your machine"
			rm -rf "$tmp_folder"
			rm -rf "$OUT_FOLDER"
			exit 1
		else
			echo "Copying files..."
			mkdir -p "$OUT_FOLDER/Hewlett-Packard/BIOS/New"
			cp $bios_file $OUT_FOLDER/Hewlett-Packard/BIOS/New/
			cp -r $usbupdate_exists $OUT_FOLDER/Hewlett-Packard/
			rm -rf "$tmp_folder"
			chown "$curr_uid:$curr_gid" -R $OUT_FOLDER
			echo "Done!"
			echo " "
		fi
	fi
}

check_show_help
check_su
check_commands
get_bios_info
check_file_exists
check_out_folder
extract_exe_do_work

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

curr_folder=$(pwd)
curr_time=$(date +%Y%m%d%H%M%S)
curr_uid=$(id -u $SUDO_USER)
curr_gid=$(id -g $SUDO_USER)
tmp_folder="/tmp/HP-BIOS-$curr_time/"

FNT_BOLD="\033[1m"
FNT_RED="\033[0;31m"
FNT_GREEN="\033[0;32m"
FNT_RESET="\033[0m"

FILE=""
OUT_FOLDER="$curr_folder/USB-$curr_time"

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

die() {
  pr_error "$@"
  rm -rf "$tmp_folder"
  rm -rf "$OUT_FOLDER"
  exit 1
}

show_help()
{
  cat << EOF

HP BIOS extract tool v0.2
=========================

This program is licensed under MIT license

Usage: $0 [OPTIONS]

  --file=<filename>   - File of executable downloaded from HP website
  --output=<folder>   - Output folder for USB content (optional)
                        NOTE: Must not contain trailing slash
                        Default location: $curr_folder/USB-$curr_time
  --help              - This screen

EOF
exit 0
}

check_commands()
{
  for cmd in cabextract dmidecode awk; do
    which $cmd >/dev/null || die "Command $cmd is not found on your system. Install it before running this script"
  done
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
  sys_name="$(get_system_name)"
  type="$(get_bios_type)"
  version="$(get_bios_version true)"

  cat << EOF

Your system
===========
System:       $sys_name
BIOS type:    $type
BIOS version: $version

EOF
}

extract_exe_do_work()
{
  mkdir -p "$tmp_folder"

  echo "Extracting content of archive..."
  cabextract "$FILE" -q -d "$tmp_folder"
  cabextract "$tmp_folder/ROM.CAB" -q -d "$tmp_folder"

  type="$(get_bios_type)"
  usbupdate=$(find "$tmp_folder" -type d -name BIOSUpdate)
  bios_file=$(find "$tmp_folder" -name "*.bin")
  sig_file=$(find "$tmp_folder" -name "efibios.sig")
  ver_file=$(find "$tmp_folder" -name "ver.txt")

  [ -n "$usbupdate" ]         || die "Package does not contain BIOS update files"
  [ -n "$ver_file" ]          || die "Package does not contain a ver.txt"
  [ -n "$sig_file" ]          || die "Package does not contain a efibios.sig"
  [ -n "$bios_file" ]         || die "Package does not contain a BIOS *.bin file"
  grep -q "$type" "$ver_file" || die "Package does not contain a BIOS compatible with your machine"

  echo "Copying files..."
  mkdir -p            "$OUT_FOLDER/Hewlett-Packard/BIOS/New"
  cp    "$bios_file"  "$OUT_FOLDER/Hewlett-Packard/BIOS/New/$type.bin"
  cp    "$sig_file"   "$OUT_FOLDER/Hewlett-Packard/BIOS/New/$type.sig"
  cp -r "$usbupdate"  "$OUT_FOLDER/Hewlett-Packard/"
  chown "$curr_uid:$curr_gid" -R "$OUT_FOLDER"
  rm -rf "$tmp_folder"
  echo "Done!"
  echo " "
}

# Options

for o in "$@"; do
  case "$o" in
    --file=*)     FILE="${o#*=}";;
    --output=*)   OUT_FOLDER="${o#*=}";;
    --help)       show_help;;
    -h)           show_help;;
    *)            die "Unknown option: $o";;
  esac
done

[ "$#" = "0" ]         && show_help
[ -n "$FILE" ]         || die "HP executable file not provided"
[ -f "$FILE" ]         || die "Provided file name does not exist ($FILE)"
[ "$(id -u)" = "0" ]   || die "This script must be run as root"
mkdir -p "$OUT_FOLDER" || die "Cannot create output folder"

check_commands
get_bios_info
extract_exe_do_work

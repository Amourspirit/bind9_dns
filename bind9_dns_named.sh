#!/bin/bash
#region License

# The content of this file are licensed under the MIT License (https://opensource.org/licenses/MIT)
# MIT License
#
# Copyright (c) 2020 Paul Moss
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#
#endregion

#region Script Info
# Script to update one or more ip address with the free service duckdns.org
# Created by Paul Moss
# Created: 2020-06-26
# Updated: 2020-07-07
# File Name: bind9_dns_named.sh
# Version 0.5.0
# URL: https://github.com/Amourspirit/bind9_dns

#endregion
VER='0.5.0'
CONFIG_FILE="$HOME/.bind9/config.cfg"
TMP_IP_FILE='/tmp/current_ip_address'
# Age in minutes to keep ipaddress store in tmp file
MAX_IP_AGE=5
IP_URL='https://checkip.amazonaws.com/'
ZONE_LOCAL='/etc/bind/named.conf.local'
ZONE_MAIN='/etc/bind/named.conf'
IP=''
RESTOR=0
BACKUP_DIR='/tmp/bind9_dns_named'

#region functions
#region _ip_valid

# Test if a value is in the format of a valid IP4 Address
# Usage:
# if [[ $(_ip_valid $IP) ]]; then
#   echo 'IP is valid'
# else
#   echo 'Invalid IP'
# fi
function _ip_valid() {
    local _ip="$1"
    if (! [[ -z $_ip ]]) && [[ $_ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        echo 1
    fi
}
#endregion

#region _file_older
# Gets if a file is older then a time passed in as minutes
# @param1 file to check
# @param2 Age of file in minutes
# Return 1 if file is older then time passed in; Otherwise, null
function _file_older() {
    local _file="$1"
    local _min="$2"
    if ! [[ $(stat -c %Y -- "${_file}") -lt $(date +%s --date="${_min} min ago") ]]; then
        echo 1
    fi
}
#endregion

#region _trim

# function: _trim
# Param 1: the variable to trim whitespace from
# Usage:
#   while read line; do
#       if [[ "$line" =~ ^[^#]*= ]]; then
#           setting_name=$(_trim "${line%%=*}");
#           setting_value=$(_trim "${line#*=}");
#           SCRIPT_CONF[$setting_name]=$setting_value
#       fi
#   done < "$TMP_CONFIG_COMMON_FILE"
function _trim() {
    local var=$1
    var="${var#"${var%%[![:space:]]*}"}" # remove leading whitespace characters
    var="${var%"${var##*[![:space:]]}"}" # remove trailing whitespace characters
    echo -n "$var"
}
#endregion

#region _get_cfg_section

# Populates and array name and value or only values from a section of a config file
# @param: ByRef array (bash 4.3+). The array to populate.
#   Passed in a actual array name such as SCRTIP_CFG and not ${SCRIPT_CFG}
#   If @param 4 is non-zero value this array must be a value only array as shown in second example
# @param: The path to file configuration file containing the section to read.
# @param: The case sensitive name of the section to read from file
# @param: Optional: If set to non-zero then will fill array with values only. Default 0
# @return: 0 if no errors were encountered. 3 if there was no name and value to read. 2 if unable to read config file because it does not exist or no read permissin
# @requires: function _trim
# @example: name and values
# CONFIG_FILE="$HOME/.hidden_dir/main.cfg" # https://pastebin.com/2iEH2jE6
# # create an array that contains configuration values
# typeset -A ZONE_CONF # init array
# ZONE_CONF=( # set default values in config array
#     [ZONE_LOCAL]='${HOME}/scripts/bind9/tmp/named.conf.local'
#       [ZONE_NAME]='Far Zone'
# )
# _get_cfg_section ZONE_CONF ${CONFIG_FILE} 'BIND'
#
# ZONE_CONF[ZONE_LOCAL]=$(eval echo "${ZONE_CONF[ZONE_LOCAL]}")
# echo 'Local:' "${ZONE_CONF[ZONE_LOCAL]}"
# echo 'Name:' "${ZONE_CONF[ZONE_NAME]}"
# unset ZONE_CONF # done with array, release memory
#
# @example: values only
# DOMAINS_CONF=()
# _get_cfg_section DOMAINS_CONF ${CONFIG_FILE} 'DOMAINS' 1
# printf '%s\n' "${DOMAINS_CONF[@]}"
# unset DOMAINS_CONF # done with array, release memory
function _get_cfg_section() {
    local -n _arr=$1
    local _file=$2
    local _section=$3
    local _section_name=''
    local _name=''
    local _value=''
    local _tmp_config_common_file=''
    local _line=''
    local _retval=0
    local _a_type=0
    if ! [[ -z $4 ]]; then
        _a_type=$4
    fi
    if [[ -r "${_file}" ]]; then
        _tmp_config_common_file=$(mktemp) # make tmp file to hold section of config.ini style section in
        # sed in this case takes the value of section and reads the setion from contents of 'file'
        sed -n '0,/'"${_section}"']/d;/\[/,$d;/^$/d;p' "${_file}" >${_tmp_config_common_file}
        test -s "${_tmp_config_common_file}" # test to to see if it is greater then 0 in size
        if [ $? -eq 0 ]; then
            if [[ _a_type -ne 0 ]]; then
                # read the input of the tmp config file line by line
                while read _line; do
                    _value=$(_trim "${_line#*=}")
                    if ! [[ -z "${_value}" ]]; then
                        _arr+=("${_value}")
                    fi
                done <"${_tmp_config_common_file}"
                _retval="$?"
            else
                # read the input of the tmp config file line by line
                while read _line; do
                    if [[ "${_line}" =~ ^[^#]*= ]]; then
                        _name=$(_trim "${_line%%=*}")
                        _value=$(_trim "${_line#*=}")
                        _arr[$_name]="${_value}"
                    fi
                done <"${_tmp_config_common_file}"
                _retval="$?"
            fi
        else
            _retval=3
        fi
        unlink ${_tmp_config_common_file} # release the tmp file that is contains the current section values
    else
        _retval=2
    fi
    return ${_retval}
}
#endregion

#region _remove_nl_tab

# Removes tabs and line ending characters from string
# Usage: echo "${ACME}" | _remove_tab_nl
function _remove_nl_tab() {
    tr -d '\t\n\r'
}
#endregion

#region _path_dir

# Gets the directory from a path
# Usage:
# echo $(_path_dir '/this/is/my/path/file')
function _path_dir() {
    echo $(dirname $1)
}
#endregion

#region _path_file

# Gets the file name from a path
# Usage:
# echo $(_path_file '/this/is/my/path/file')
function _path_file() {
    echo $(basename $1)
}
#endregion

#region _int_assign()

# Assigns a interger value to first param if second param is a valid integer.
# @param: ByRef integer
# @param: The integer to assign to first param. Only gets assigned if valid integer
# @returns: returns 0 if second parameter was assigned to first parameter; Otherwise, 1
# example:
# myint=2; oth_int=10
# _int_assign myint $oth_int
# echo $myint
function _int_assign() {
    local -n int=$1
    local newval=$2
    # note: single [ ] is required
    [ "$newval" -eq "$newval" ] 2>/dev/null && int=$newval && return 0 || return 1
}
#endregion

#region _int_valid()

# Gets if valie is a valid integer
# @param: Value to test as integer
# @returns: 0 if param is a valid integer; Otherwise nothing
# $? will be 0 if param is a valid integer; Otherwise, 1
# @example
# i=-123
# if [[ $(_int_valid i) ]]; then
#     echo 'Integer valid:' $i
# else
#     echo 'Invalid integer'
# fi
function _int_valid() {
    local int=$1
    # note: single [ ] is required
    if [ "${int}" -eq "${int}" ] 2>/dev/null; then
        echo 0
        return 0
    else
        return 1
    fi
}
#endregion
#endregion

#region Read Configuraton from File
DOMAINS_ARR=()
test -r "${CONFIG_FILE}"
if [ $? -eq 0 ]; then
    # create an array that contains general configuration values
    typeset -A GEN_CONF # init array
    GEN_CONF=(# set default values in config array
        [IP_URL]="${IP_URL}"
        [MAX_IP_AGE]="${MAX_IP_AGE}"
        [TMP_IP_FILE]="${TMP_IP_FILE}"
        [BACKUP_DIR_NAMED]="${BACKUP_DIR}"
    )
    _get_cfg_section GEN_CONF ${CONFIG_FILE} 'GENERAL'
    IP_URL="${GEN_CONF[IP_URL]}"
    MAX_IP_AGE="${GEN_CONF[MAX_IP_AGE]}"
    TMP_IP_FILE="${GEN_CONF[TMP_IP_FILE]}"
    BACKUP_DIR="${GEN_CONF[BACKUP_DIR_NAMED]}"
    unset GEN_CONF # done with array, release memory

    # create an array that contains bind_conf configuration values
    typeset -A BIND_CONF # init array
    BIND_CONF=(# set default values in config array
        [ZONE_LOCAL]="${ZONE_LOCAL}"
        [ZONE_MAIN]="${ZONE_MAIN}"
    )
    _get_cfg_section BIND_CONF ${CONFIG_FILE} 'BIND_CONF'
    ZONE_LOCAL="${BIND_CONF[ZONE_LOCAL]}"
    ZONE_MAIN="${BIND_CONF[ZONE_MAIN]}"
    unset BIND_CONF # done with array, release memory

    _get_cfg_section DOMAINS_ARR ${CONFIG_FILE} 'DOMAINS' 1
fi
#endregion

#region getopts
HELP_USAGE=0
# if a parameter does not require an argument such as -h -v then do not follow with :
usage() {
    echo "$(basename $0) usage:" && grep "[[:space:]].)\ #" $0 | sed 's/#//' | sed -r 's/([a-z])\)/-\1/'
    if [[ $HELP_USAGE -eq 0 ]]; then
        exit 0
    fi
}
while getopts "hvrd:l:m:i:u:" arg; do
    case $arg in
    d) # Comma seperated domain name(s) such as www.domain.tld,lib.domain.tld,sales.domain.tld
        IFS=',' read -ra DOMAINS_ARR <<<"${OPTARG}"
        ;;
    l) # The full path to named.conf.local file. Default: /etc/bind/named.conf.local
        ZONE_LOCAL="${OPTARG}"
        ;;
    m) # The full path to named.conf file. Default: /etc/bind/named.conf
        ZONE_MAIN="${OPTARG}"
        ;;
    i) # The ip address to be used. Default the the ip address provided by: https://checkip.amazonaws.com/
        IP="${OPTARG}"
        if ! [[ $(_ip_valid "${IP}") ]]; then
            echo 'Not a valid ip address. Use IP 4 format'
            usage
            exit 1
        fi
        ;;
    u) # The url that will be used to query IP address. Default is https://checkip.amazonaws.com/
        IP_URL="${OPTARG}"
        ;;
    t) # The amount of time the IP address is cached in minutes. Default is 5
        _int_assign MAX_IP_AGE ${OPTARG}
        ;;
    r) # Restore files from backup if existing
        RESTOR=1
        ;;
    v) # Display version info
        echo "$(basename $0) version: ${VER}"
        exit 0
        ;;
    h) # Display help.
        HELP_USAGE=1
        usage
        HELP_INDENT='          '
        echo "${HELP_INDENT}"'Option -d is required if [DOMAINS] section of configuration file is void'
        echo "${HELP_INDENT}"'See Also: https://github.com/Amourspirit/bind9_dns'
        exit 0
        ;;
    esac
done
shift $((OPTIND - 1))
if [ ${#DOMAINS_ARR[@]} -eq 0 ]; then
    usage
fi
#endregion

#region get ip address

IP_VALID=0
if [[ $(_ip_valid "${IP}") ]]; then
    IP_VALID=1
fi
if [[ $IP_VALID -ne 1 ]] && [[ -r "${TMP_IP_FILE}" ]] && [[ $(_file_older "${TMP_IP_FILE}" "${MAX_IP_AGE}") ]]; then
    IP=$(_trim $(cat "${TMP_IP_FILE}"))
    IP_VALID=$(_ip_valid "${IP}")
    echo "${IP}" 'Optained ip address from tmp file'
fi
if [[ $IP_VALID -ne 1 ]]; then
    IP=$(wget -qT 20 -O - "${IP_URL}") && IP=$(_trim "$IP")
    IP_VALID=$(_ip_valid "${IP}")
    echo "${IP}" >"${TMP_IP_FILE}"
    echo "${IP}" 'Optained ip address Internet'
fi
if [[ $IP_VALID -ne 1 ]]; then
    echo 'Unable to optain valid ip address. Halting'
    exit 1
fi
#endregion

#region backup dir create/test
mkdir -p "${BACKUP_DIR}" # make dir to hold temp backups
test -d "${BACKUP_DIR}"
if [[ $? -ne 0 ]]; then
    echo 'Unable to create Backup up directory:' "${BACKUP_DIR}"
    echo 'Make sure the configuration is correct and you have write access'
    echo 'Terminating with Error'
    exit 1
fi
#endregion

#region Restore
if [[ $RESTOR -eq 1 ]]; then
    for DOMAIN_NAME in "${DOMAINS_ARR[@]}"; do
        D_NAME=$(_trim "${DOMAIN_NAME}")
        if [[ -z ${D_NAME} ]]; then
            continue
        fi

        FILE_PATH=$(cat "${ZONE_LOCAL}" |
            _remove_nl_tab |
            grep -oP "zone\s+\"${D_NAME}\".*?file\s\"[0-9a-z A-Z\/\.]*\";" |
            grep -oP '\/[0-9a-zA-Z\/.\s]*')

        # copy file into backup dir
        FILE_NAME=$(_path_file "${FILE_PATH}")
        TMP_BAK="${BACKUP_DIR}/${FILE_NAME}"
        if [[ -f "${TMP_BAK}" ]]; then
            \cp -f "${TMP_BAK}" "${FILE_PATH}"
            if [[ $? -ne 0 ]]; then
                # error copying file
                echo 'Failed to copy file:' "${TMP_BAK}" 'to' "${FILE_PATH}" '! skipping'
                continue
            fi
            echo 'Restored file:' "${FILE_PATH}" 'For Domain:' "${D_NAME}"
        fi
    done
    echo 'To Test configuration'
    echo '  named-checkconf' "${ZONE_MAIN}" "&& [[ \$? -eq 0 ]] && echo 'All Good' || echo 'Failed'"
    echo
    echo 'To Reload Bind'
    echo '  systemctl reload bind9 '
    echo
    echo 'To check Bind Status'
    echo '  systemctl status bind9'
    exit 0
fi
#endregion

#region test after read config
systemctl status bind9 >/dev/null 2>&1
if [[ $? -ne 0 ]]; then
    echo 'bind9 is not running. Halting'
    exit 1
fi

test -e "${TMP_IP_FILE}"
if [[ $? -ne 0 ]]; then
    touch "${TMP_IP_FILE}"
    if [[ $? -ne 0 ]]; then
        echo 'Unable to create Cache file for public ip address:' "${TMP_IP_FILE}"
        echo 'Make sure the configuration is correct and you have write access'
        echo 'Terminating with Error'
        exit 1
    fi
fi

if ! [[ $(_int_valid "${MAX_IP_AGE}") ]]; then
    echo 'Not a valid time for caching public IP address: MAX_IP_AGE'
    echo 'Terminating with Error'
    exit 1
fi

test -e "${ZONE_MAIN}"
if [ $? -eq 0 ]; then
    test -r "${ZONE_MAIN}"
    if [ $? -ne 0 ]; then
        echo 'No read permissions for ZONE_MAIN file:' "${ZONE_MAIN}"
        echo 'Exiting'
        exit 1
    fi
else
    echo 'Unable to locate ZONE_MAIN file:' "${ZONE_MAIN}"
    echo 'Exiting'
    exit 1
fi

test -e "${ZONE_LOCAL}"
if [ $? -eq 0 ]; then
    test -r "${ZONE_LOCAL}"
    if [ $? -ne 0 ]; then
        echo 'No read permissions for ZONE_LOCAL file:' "${ZONE_LOCAL}"
        echo 'Exiting'
        exit 1
    fi
else
    echo 'Unable to locate ZONE_LOCAL file:' "${ZONE_LOCAL}"
    echo 'Exiting'
    exit 1
fi
#endregion

IP_ESC=${IP//./\\.} # escape ipaddress

for DOMAIN_NAME in "${DOMAINS_ARR[@]}"; do
    D_NAME=$(_trim "${DOMAIN_NAME}")
    if [[ -z ${D_NAME} ]]; then
        continue
    fi
    # echo  DOMAIN_NAME
    IP_OLD=$(dig @127.0.0.1 -q "${D_NAME}" -t A +short) && IP_OLD=$(_trim "$IP_OLD")
    #validate IP address (makes sure Route 53 doesn't get updated with a malformed payload)
    if ! [[ $(_ip_valid "${IP_OLD}") ]]; then
        echo 'Unable to obtain ip address from local bind9'
        continue
    fi

    if [ "$IP_OLD" != "$IP" ]; then
        IP_OLD=${IP_OLD//./\\.} # escape ipaddress
        FILE_PATH=$(cat "${ZONE_LOCAL}" |
            _remove_nl_tab |
            grep -oP "zone\s+\"${D_NAME}\".*?file\s\"[0-9a-z A-Z\/\.]*\";" |
            grep -oP '\/[0-9a-zA-Z\/.\s]*')
        # check zone to see if it is valid
        named-checkzone "${D_NAME}" "${FILE_PATH}" >/dev/null 2>&1
        if [[ $? -ne 0 ]]; then
            echo 'zone' "${D_NAME}" 'did not pass; skipping'
            continue
        fi
        # copy file into backup dir
        FILE_NAME=$(_path_file "${FILE_PATH}")
        # DIR_NAME=$(_path_dir "${FILE_PATH}")
        \cp -f "${FILE_PATH}" "${BACKUP_DIR}"
        if [[ $? -ne 0 ]]; then
            # error copying file
            echo 'Failed to copy file:' "${FILE_NAME}" 'to' "${BACKUP_DIR}" '! skipping'
            continue
        fi
        # replace old ip with new ip address
        sed -i "s/$IP_OLD/$IP_ESC/g" "${FILE_PATH}"
        if [[ $? -eq 0 ]]; then
            echo 'Sucessfully updated IP address for file:' "${FILE_NAME}"
        else
            echo 'Failed to update IP address for file:' "${FILE_NAME}"
            \cp -f "${BACKUP_DIR}/${FILE_NAME}" "${FILE_PATH}"
            if [[ $? -eq 0 ]]; then
                echo 'Restored file:' "${FILE_NAME}"
            else
                echo 'Attempted but failed to restore:' "${FILE_NAME}"
            fi
            continue
        fi
        # check zone to see if it is valid after IP update
        named-checkzone "${D_NAME}" "${FILE_PATH}" >/dev/null 2>&1
        if [[ $? -ne 0 ]]; then
            echo 'zone' "${D_NAME}" 'did not pass after ip address update'
            \cp -f "${BACKUP_DIR}/${FILE_NAME}" "${FILE_PATH}"
            if [[ $? -eq 0 ]]; then
                echo 'Restored file:' "${FILE_NAME}"
            else
                echo 'Attempted but failed to restore:' "${FILE_NAME}"
            fi
            continue
        fi
    fi
done

named-checkconf "${ZONE_MAIN}" >/dev/null 2>&1
if [[ $? -eq 0 ]]; then
    # reload bind9
    systemctl reload bind9
    echo 'Finished updating ip address'
else
    echo 'Testing of configuraton failed for file:' "${ZONE_MAIN}"
    echo 'Bind has not been restarted!'
    echo 'Finished'
fi
exit 0

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

#endregion
#region script info
# Script to update one or more ip address with the free service duckdns.org
# Created by Paul Moss
# Created: 2020-06-26
# Updated: 2020-07-07
# File Name: bind9_dns.sh
# Version 0.5.1
# URL: https://github.com/Amourspirit/bind9_dns
#endregion

VER='0.5.1'
CONFIG_FILE="$HOME/.bind9/config.cfg"
TMP_IP_FILE='/tmp/current_ip_address'
IP_URL='https://checkip.amazonaws.com/'
ZONE_MAIN='/etc/bind/named.conf'
# Age in minutes to keep ipaddress store in tmp file
MAX_IP_AGE=5
IP=''
RESTOR=0
BACKUP_DIR='/tmp/bind9_dns'

source bind9_fn.sh

if ! [[ -r "${CONFIG_FILE}" ]]; then
    echo "File does not exist or no read permissions for bind9 config file: ${CONFIG_FILE}"
    exit 1
fi

HOST_FILE_ARR=()
typeset -A GEN_CONF # init array
GEN_CONF=(# set default values in config array
    [IP_URL]="${IP_URL}"
    [MAX_IP_AGE]="${MAX_IP_AGE}"
    [TMP_IP_FILE]="${TMP_IP_FILE}"
    [BACKUP_DIR]="${BACKUP_DIR}"
)
_get_cfg_section GEN_CONF ${CONFIG_FILE} 'GENERAL'
IP_URL="${GEN_CONF[IP_URL]}"
MAX_IP_AGE="${GEN_CONF[MAX_IP_AGE]}"
TMP_IP_FILE="${GEN_CONF[TMP_IP_FILE]}"
BACKUP_DIR="${GEN_CONF[BACKUP_DIR]}"
unset GEN_CONF # done with array, release memory

typeset -A DOMAIN_CONF # init array
DOMAIN_CONF=(# set default values in config array
    [LOOKUP]=''
)
_get_cfg_section DOMAIN_CONF ${CONFIG_FILE} 'DOMAIN'
DOMAIN_LOCAL="${DOMAIN_CONF[LOOKUP]}"
unset DOMAIN_CONF # done with array, release memory

# create an array that contains bind_conf configuration values
typeset -A BIND_CONF # init array
BIND_CONF=(# set default values in config array
    [ZONE_MAIN]="${ZONE_MAIN}"
)
_get_cfg_section BIND_CONF ${CONFIG_FILE} 'BIND_CONF'
ZONE_MAIN="${BIND_CONF[ZONE_MAIN]}"
unset BIND_CONF # done with array, release memory

_get_cfg_section HOST_FILE_ARR ${CONFIG_FILE} 'BIND_FILES' 1

#region getopts

HELP_USAGE=0
# if a parameter does not require an argument such as -h -v then do not follow with :
usage() {
    echo "$(basename $0) usage:" && grep "[[:space:]].)\ #" $0 | sed 's/#//' | sed -r 's/([a-z])\)/-\1/'
    if [[ $HELP_USAGE -eq 0 ]]; then
        exit 0
    fi
}
while getopts "hvrd:l:m:i:u:t:" arg; do
    case $arg in
    d) # The domain used to get the current local ip address from
        DOMAIN_LOCAL="${OPTARG}"
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
    t) # The amount of thime the IP address is cached in minutes. Default is 5
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
        echo "${HELP_INDENT}"'To avoid using command line switches set up the configuration file:' "${CONFIG_FILE}"
        echo "${HELP_INDENT}"'Command line switches will override any setting placed in' "${CONFIG_FILE}"
        echo "${HELP_INDENT}"'See Also: https://github.com/Amourspirit/bind9_dns'
        exit 0
        ;;
    esac
done
shift $((OPTIND - 1))
if [ ${#HOST_FILE_ARR[@]} -eq 0 ]; then
    usage
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
    for HOST_FILE in "${HOST_FILE_ARR[@]}"; do
        FILE_PATH=$(_trim "${HOST_FILE}")
        if [[ -z ${FILE_PATH} ]]; then
            continue
        fi

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
            echo 'Restored file:' "${FILE_PATH}" 'For Domain:' "${FILE_PATH}"
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
#endregion
systemctl status bind9 >/dev/null 2>&1
if [[ $? -ne 0 ]]; then
    echo 'bind9 is not running. Halting'
    exit 1
fi

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
    IP=$(wget -qT 20 -O - "${IP_URL}") && IP=$(_trim "${IP}")
    IP_VALID=$(_ip_valid "${IP}")
    echo "${IP}" >"${TMP_IP_FILE}"
    echo "${IP}" 'Optained ip address Internet'
fi
if [[ $IP_VALID -ne 1 ]]; then
    echo 'Unable to optain valid ip address. Halting'
    exit 1
fi

if [[ -z $DOMAIN_LOCAL && IP_VALID -eq 0 ]]; then
    echo 'LOOKUP domain must be provided in DOMAIN section of config file or passed in with the -d option'
    echo 'Set up configuration file:' "${CONFIG_FILE}"
    echo
    echo 'Example:'
    echo '[DOMAIN]'
    echo 'LOOKUP=www.domain.tld'
    exit 1
fi
if [ ${#HOST_FILE_ARR[@]} -eq 0 ]; then
    echo 'One or more file paths must be in the BIND_FILES section of config file'
    echo 'These are the host files to change the ip address in.'
    echo 'Set up configuration file:' "${CONFIG_FILE}"
    echo
    echo 'Example:'
    echo '[BIND_FILES]'
    echo '/var/lib/bind/www.domain.tld.hosts'
    echo '/var/lib/bind/sales.domain.tld.hosts'
    echo '/var/lib/bind/webinar.domain.tld.hosts'
    exit 1
fi

IP_OLD=$(dig @127.0.0.1 -q "${DOMAIN_LOCAL}" -t A +short) && IP_OLD=$(_trim "$IP_OLD")
#validate IP address (makes sure Route 53 doesn't get updated with a malformed payload)
if ! [[ $(_ip_valid "${IP_OLD}") ]]; then
    echo 'Unable to obtain ip address from local bind9. Domain:' "${DOMAIN_LOCAL}"
    exit 1
fi

if [ "$IP_OLD" != "$IP" ]; then
    IP=${IP//./\\.}         # escape ipaddress
    IP_OLD=${IP_OLD//./\\.} # escape ipaddress
    for FILE_CONF in "${HOST_FILE_ARR[@]}"; do
        _f=$(_trim "${FILE_CONF}")
        if [[ -z "${_f}" ]]; then
            continue
        fi
        _f=$(eval echo "${_f}")
        if [[ -w "${_f}" ]]; then
            # copy file into backup dir
            # FILE_NAME=$(_path_file "${_f}")
            \cp -f "${_f}" "${BACKUP_DIR}"
            sed -i "s/$IP_OLD/$IP/g" "${_f}"
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
fi

exit 0

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

#region _file_older()

# Gets if a file is older then a time passed in as minutes
# @param1 file to check
# @param2 Age of file in minutes
# @return 1 if file is older then time passed in; Otherwise, null
# @example:
# if [[ $(_file_older "${FILE}" 5) ]]; then;
#    echo 'File is older'
# fi
function _file_older() {
    local _file="$1"
    local _min="$2"
    if [[ $(stat -c %Y -- "${_file}") -lt $(date +%s --date="${_min} min ago") ]]; then
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
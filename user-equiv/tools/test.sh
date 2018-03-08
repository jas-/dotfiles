#!/bin/bash

# Define some defaults
users_list=
systems=
verbose=0
ret=0

# Define some default array's
declare -a hosts
declare -a users


# Help system function
function usage()
{
  # Handle error if present
  [ "${1}" != "" ] && error="${1}"

  # Print a friendly menu
  cat <<EOF
${error}

Tests SSH key authentication & cluvfy functionality

Usage ./test.sh [options]

  Options:
    -h  Show this message
    -v  Turn on verbosity

  Required:
    -u  Comma separated list of user accounts
    -s  Comma separated list of system accounts

EOF
}


# Set variables
while getopts "hu:s:v" OPTION ; do
  case $OPTION in
    h) usage && exit 1 ;;
    u) users_list=$OPTARG ;;
    s) systems=$OPTARG ;;
    v) verbose=1 ;;
    ?) usage && exit 1 ;;
  esac
done


# Make sure we have what we need
if [ "${users_list}" == "" ]; then
  usage "No users provided, must be a comma separated list of user accounts"
  exit 1
fi

# Make sure we have what we need
if [ "${systems}" == "" ]; then
  usage "No hosts provided, must be a comma separated list of target systems"
  exit 1
fi


# Convert lists to array's
users=( $(echo "${users_list}" | tr ',' ' ') )
hosts=( $(echo "${systems}" | tr ',' ' ') )


[ ${verbose} -gt 0 ] && echo "Testing SSH & cluvfy..."

# Attempt to find the cluvy tool on the target system
tool="$(find /u01 /u02 -type f -name "cluvfy" 2>/dev/null | egrep -v 'old|backup' | sort -u | tail -1)"

# Iterate ${users[@]}
for user in ${users[@]}; do

  # Iterate ${hosts[@]}
  for host in ${hosts[@]}; do

    # Ensure to export ${host} & ${systems} as an $ENV variable so it is accessible to the ${user} shell
    export host=${host}
    export systems=${systems}

    # Perform a user change to ${user} & test key authentication to ${host}
    test="$(su ${user} -c 'ssh -oBatchMode=yes ${host} "uname -n"' 2>/dev/null | grep -ic "${host}")"

    # Let the user know the results of SSH key authentication
    if [ ${test} -eq 0 ]; then
      [ ${verbose} -gt 0 ] && echo "  SSH key authentication failed for '${user}@${host}'"
      ret=1
      continue
    else
      [ ${verbose} -gt 0 ] && echo "  SSH key authentication succeeded for '${user}@${host}'"
    fi

    # If ${tools} is a valid file 
    if [ -f ${tool:=cluvfy} ]; then

      # Let the user know which tool the test is using
      [ ${verbose} -gt 0 ] && echo "  Found: ${tool}"

      # Let the user know which user & nodes are being tested
      [ ${verbose} -gt 0 ] && echo "  Testing: ${user} on ${systems}"

      # Change to ${user} & validate Oracle's user equivalence
      su ${user} -c "${tool} comp admprv -n ${systems} -o user_equiv 2>/dev/null"
      echo
    fi
  done
done

exit ${ret}

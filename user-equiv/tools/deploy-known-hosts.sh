#!/bin/bash

# Define some defaults
users=
systems=
verbose=0
ret=0
domain=".csd.disa.mil"

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

Acquires and updates target known_hosts

Usage ./deploy-known-hosts.sh [options]

  Options:
    -d  Domain [Default: ${domain}]
    -h  Show this message
    -v  Turn on verbosity

  Required:
    -u  Comma separated list of user accounts
    -s  Comma separated list of system accounts

EOF
}


# Set variables
while getopts "d:hu:s:v" OPTION ; do
  case $OPTION in
    d) domain=$OPTARG ;;
    h) usage && exit 1 ;;
    u) users=$OPTARG ;;
    s) systems=$OPTARG ;;
    v) verbose=1 ;;
    ?) usage && exit 1 ;;
  esac
done


# Make sure we have what we need
if [ "${users}" == "" ]; then
  usage "No users provided, must be a comma separated list of user accounts"
  exit 1
fi

# Make sure we have what we need
if [ "${systems}" == "" ]; then
  usage "No hosts provided, must be a comma separated list of target systems"
  exit 1
fi


# Convert lists to array's
users=( $(echo "${users}" | tr ',' ' ') )
hosts=( $(echo "${systems}" | tr ',' ' ') )

# Time stamp
ts="$(date +%Y%m%d-%H%M)"


[ ${verbose} -gt 0 ] && echo "Configuring known_hosts..."

# Iterate ${users[@]}
for user in ${users[@]}; do

  # Skip iteration if ${user} isn't on system
  if [ $(grep -c ^${user} /etc/passwd) -eq 0 ]; then
    [ ${verbose} -gt 0 ] && echo "  '${user}' missing, skipping..."
    ret=1
    continue
  fi

  # Get the users home directory
  home_dir="$(nawk -F: -v user="${user}" '$1 ~ user{print $6}' /etc/passwd)"
  
  # Skip iteration if ${user} doesn't have a ${home_dir}
  if [ "${home_dir}" == "" ]; then
    [ ${verbose} -gt 0 ] && echo   "Could not obtain '${user}' home directory, skipping..."
    ret=1
    continue
  fi

  # Create a value filename to work with
  bu="${home_dir}/.ssh/known_hosts"

  # Make sure the env is setup for ${user}
  [ ! -d $(dirname ${bu}) ] && mkdir $(dirname ${bu})

  # Backup the ${user} ${home_dir} known_hosts file
  [ -f ${bu} ] && cp -p ${bu} ${bu}-${ts} || touch ${bu}
  

  # Iterate ${hosts[@]}
  for host in ${hosts[@]}; do

    # Remove any ending 'm' in ${host}
    host="$(echo "${host}" | sed 's/.*m$//g')"

    # Acquire IP information from DNS A record(s)
    ip="$(nslookup ${host}${domain} 2>/dev/null| awk '$0 ~ /^Name:/{getline;print $2}')"

    # Acquire raw key from ${host}
    key="$(ssh-keyscan -H ${host}${domain} 2>/dev/null)"

    # If ${key} is NULL skip & notify
    if [ "${key}" == "" ]; then

      # Acquire raw key from ${host}
      key="$(ssh-keyscan -trsa ${host}${domain} 2>/dev/null)"

      # If ${key} is NULL skip & notify
      if [ "${key}" == "" ]; then

        [ ${verbose} -gt 0 ] && echo "  Could not obtain key information for '${host}${domain}'"
        ret=1
        continue
      fi
    fi

    # Get the type of key & public key component from ${key}
    key_type="$(echo "${key}" | nawk '$0 !~ /^#/{print $2}')"
    key_content="$(echo "${key}" | nawk '$0 !~ /^#/{print $3}')"
    
    # Formulate a replacement/new known_hosts entry
    key_value="${host},${ip} ${key_type} ${key_content}"

    # Replace the current known_host entry if it exists
    if [ $(grep -c "^${host}" ${bu}) -gt 0 ]; then
      sed "s|^${host}.*|${key_value}|g" ${bu} > ${bu}-${ts}.wc
    else
      cp -p ${bu} ${bu}-${ts}.wc
      echo "${key_value}" >> ${bu}-${ts}.wc
    fi
    
    # Look into ${home_dir}/.ssh/known_hosts-${ts}.wc to see if the ${key_value} exists before overwriting
    if [ $(grep -c "${key_value}" ${bu}-${ts}.wc) -eq 0 ]; then
      [ ${verbose} -gt 0 ] && echo "  An error occurred creating/updating host key for '${host}':"
      [ ${verbose} -gt 0 ] && echo "    ${key_value}"
      ret=1
      rm ${bu}-${ts}.wc
      continue
    fi
    
    # Since we made it this far copy the new known_hosts into place
    cp -p ${bu}-${ts}.wc ${bu} 2> /dev/null
    if [ $? -ne 0 ]; then
      [ ${verbose} -gt 0 ] && echo "  An occurred replacing ${bu} with modified entry"
      ret=1
      continue
    fi
    
    chown ${user}:$(groups ${user} | cut -d" " -f1) ${bu}
    chmod 0600 ${bu}
    [ ${verbose} -gt 0 ] && echo "  Updated ${bu} with key for ${host}"

  done

  # Convert ${bu} to a hashed version to further obscure known_hosts
  #su -c ${user} 'ssh-keygen -H 2>/dev/null'
done

exit ${ret}
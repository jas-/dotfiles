#!/bin/bash

# Define some defaults
algo="rsa"
users=
systems=
ret=0
verbose=0

# Some default array's
declare -a hosts
declare -a users
declare -a cusers
declare -a keys


# Help system function
function usage()
{
  # Handle error if present
  [ "${1}" != "" ] && error="${1}"

  # Print a friendly menu
  cat <<EOF
${error}

Acquires & distributes public SSH keys to target users & nodes

Usage ./deploy-authorized.sh [options]

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
    u) users=$OPTARG ;;
    s) systems=$OPTARG ;;
    v) verbose=1 ;;
    ?) usage && exit 1 ;;
  esac
done


# Make sure we have what we need
if [ "${users}" = "" ]; then
  usage "No users provided, must be a comma separated list of user accounts"
  exit 1
fi

# Make sure we have what we need
if [ "${systems}" = "" ]; then
  usage "No hosts provided, must be a comma separated list of target systems"
  exit 1
fi


# Convert lists to array's
users=( $(echo "${users}" | tr ',' ' ') )
hosts=( $(echo "${systems}" | tr ',' ' ') )

# Generate a filter of users for awk
filter="$(echo "${users[@]}" | tr ' ' '|')"

# Time stamp
ts="$(date +%Y%m%d-%H%M)"


# Be verbose if asked
[ ${verbose} -gt 0 ] && echo "Acquiring public keys..."


# Iterate ${hosts[@]}
for host in ${hosts[@]}; do

  # Temporary place holder
  ohost="${host}"

  # Check to see if we need an "m" appended ${host}
  online="$(ping -n 1 -w 10 -i 10 ${host} 2>/dev/null | awk '$0 ~ /^Reply/{print}' 2>/dev/null)"
  
  # Append the stupid M, grrr
  if [ "${online}" = "" ]; then
    host="${host}m"
  fi

  # Acquire array of users & their home directories on ${host}
  cusers=( $(awk -v filter="${filter}" -F: '$1 ~ filter{printf("%s:%s\n", $1, $6)}' //${host}/etc/passwd) )

  # Iterate ${users[@]}
  for user in ${users[@]}; do

    thome=
    home=
    user_path=

    # Get the ${user} home directory from ${cusers[@]}
    thome="$(echo "${cusers[@]}" | tr ' ' '\n' | grep "^${user}")"

    # make sure ${thome} isn't NULL
    if [ "${thome}" = "" ]; then
      [ ${verbose} -gt 0 ] && echo "  Unable to acquire home directory for ${user}, skipping..."
      ret=1
      continue
    fi

    # Extract the home path from ${thome}
    home="$(echo "${thome}" | cut -d: -f2)"

    # Formulate a path to the users .ssh folder
    user_path="//${host}/${home}/.ssh"

    # Test for existence of id_${algo}.pub
    if [ ! -f ${user_path}/id_${algo}.pub ]; then
      [ ${verbose} -gt 0 ] && echo "  '${user}' does not have an '${user_path}/id_${algo}.pub' file, skipping..."
      ret=1
      continue
    fi

    # Acquire the public key
    public="$(cat ${user_path}/id_${algo}.pub | tr ' ' '~')"
    
    # If ${public} is NULL notify and skip
    if [ "${public}" = "" ]; then
      [ ${verbose} -gt 0 ] && echo "  Error obtaining public key contents for '${user}' on '${ohost}', skipping..."
      ret=1
      continue
    fi

    # Create an entry in ${keys[@]}
    keys+=( "${ohost}:${user}:${home}:${public}" )

    # Notify the user
    [ ${verbose} -gt 0 ] && echo "  Acquired public key for '${user}' on '${ohost}'"
  done
done


# Be verbose if asked
[ ${verbose} -gt 0 ] && echo "Deploying public keys..."


# Iterate ${hosts[@]}
for host in ${hosts[@]}; do

  # Temporary place holder
  ohost="${host}"

  # Check to see if we need an "m" appended ${host}
  online="$(ping -n 1 -w 10 -i 10 ${host} 2>/dev/null | awk '$0 ~ /^Reply/{print}' 2>/dev/null)"
  
  # Append the stupid M, grrr
  if [ "${online}" = "" ]; then
    host="${host}m"
  fi

  # Iterate ${users[@]}
  for user in ${users[@]}; do

    # Extract all keys for ${host} from ${keys[@]}
    tkeys=( $(echo "${keys[@]}" | tr ' ' '\n' | grep -v "^${ohost}" | grep "${user}" | tr '\n' ' ') )

    # If ${#tkeys[@]} = 0 abort
    if [ ${#tkeys[@]} -eq 0 ]; then
      [ ${verbose} -gt 0 ] && echo "  '${#tkeys[@]}' found for '${user}', skipping..."
      ret=1
      continue
    fi
  
    # Iterate ${keys[@]}
    for key in ${tkeys[@]}; do
  
      # Cut up ${key} into chunks
      chost="$(echo "${key}" | cut -d: -f1)"
      user="$(echo "${key}" | cut -d: -f2)"
      home="$(echo "${key}" | cut -d: -f3)"
      pkey="$(echo "${key}" | cut -d: -f4 | tr '~' ' ')"
  
      # Define a path for ${user} on ${chost}
      path="//${host}/${home}"
      
      # If the ${path} doesn't exist notify & skip
      if [ ! -d ${path} ]; then
        [ ${verbose} -gt 0 ] && echo "  ''${path}' does not exist, skipping..."
        ret=1
        continue
      fi
      
      # Make ${path}/.ssh if it doesn't exist
      if [ ! -d ${path}/.ssh ]; then
        mkdir -p ${path}/.ssh
        chmod 0644 ${path}/.ssh
      fi
      
      # Make backup if ${path}/.ssh/authorized_keys exists
      if [ -f ${path}/.ssh/authorized_keys ]; then
        cp -p ${path}/.ssh/authorized_keys ${path}/.ssh/authorized_keys-${ts}
      else
        touch ${path}/.ssh/authorized_keys
        chmod 0644 ${path}/.ssh/authorized_keys
      fi
  
      # Look for ${user}@${chost} in ${path}/.ssh/authorized_keys
      if [ $(grep -c "${user}@${chost}" ${path}/.ssh/authorized_keys) -gt 0 ]; then
  
        # Edit ${path}/.ssh/authorized_keys-${ts}.wc
        sed "s|.*${user}@${chost}.*|${pkey}|g" ${path}/.ssh/authorized_keys > ${path}/.ssh/authorized_keys-${ts}.wc 
      else
  
        # Make a working copy
        cp -p ${path}/.ssh/authorized_keys ${path}/.ssh/authorized_keys-${ts}.wc
  
        # Create a new entry
        echo "${pkey}" >> ${path}/.ssh/authorized_keys-${ts}.wc
      fi
  
      # Validate ${pkey} exists in ${path}/.ssh/authorized_keys ${path}/.ssh/authorized_keys-${ts}.wc
      if [ $(grep -c "${pkey}" ${path}/.ssh/authorized_keys-${ts}.wc) -eq 0 ]; then
        
        # Let the user know there was an error updating/creating entry for ${pkey}
        [ ${verbose} -gt 0 ] && echo "  The public key for ${user}@${chost} does not exist in working copy, aborting..."
        rm ${path}/.ssh/authorized_keys-${ts}.wc
        ret=1
        continue
      fi
  
      # Since we made it this far we should have a valid ${pkey}
      mv -f ${path}/.ssh/authorized_keys-${ts}.wc ${path}/.ssh/authorized_keys
      chown ${user}:$(groups ${user} | cut -d" " -f1) ${path}/.ssh/authorized_keys
      chmod 0600 ${path}/.ssh/authorized_keys
      
      # Let the user know
      [ ${verbose} -gt 0 ] && echo "  Added public key for '${user}@${chost}' to '${path}/.ssh/authorized_keys'"
    done
  done
done

exit ${ret}  
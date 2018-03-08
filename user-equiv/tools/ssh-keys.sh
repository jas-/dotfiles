#!/bin/bash

# Define some defaults
users=
systems=
default_password=
default_algo="rsa"
default_bits="2048"
verbose=0
ret=0


# Help system function
function usage()
{
  # Handle error if present
  [ "${1}" != "" ] && error="${1}"

  # Print a friendly menu
  cat <<EOF
${error}

Facilitates creation of new SSH keys

Usage ./ssh-keys.sh [options]

  Options:
    -h  Show this message
    -a  Algorithm
        [ecdsa | ed25519 | dsa | rsa]
    -b  Bits for key
        [ecdsa: 256, 384, 521  | ed25519: ignored | dsa: 1024, 2048 | rsa: 1024, 2048, 4096]
    -p  Passphrase for private key
    -v  Turn on verbosity

  Required:
    -u  Comma separated list of user accounts
    -s  Comma separated list of system accounts

EOF
}


# Set variables
while getopts "ha:b:u:s:p:v" OPTION ; do
  case $OPTION in
    a) algo=$OPTARG ;;
    b) bits=$OPTARG ;;
    h) usage && exit 1 ;;
    u) users=$OPTARG ;;
    s) systems=$OPTARG ;;
    p) password=$OPTARG ;;
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
hosts="$(echo "${systems}" | tr ',' '|')"


# Get the hostname
hname="$(uname -n)"


# Time stamp
ts="$(date +%Y%m%d-%H%M)"


# Set ${algo}, ${bits} & ${password}
algo="${algo:=${default_algo}}"
bits="${bits:=${default_bits}}"
password="${password:=${default_password}}"


# Validate the ${algo} & ${bits} combination
case "${algo}" in
  rsa)
    if [[ ${bits} -ne 1024 ]] || [[ ${bits} -ne 2048 ]] || [[ ${bits} -ne 4096 ]]; then
      usage "Invalid key size for ${algo}"
      exit 1
    fi
    ;;
  dsa)
    if [[ ${bits} -ne 1024 ]] || [[ ${bits} -ne 2048 ]]; then
      usage "Invalid key size for ${algo}"
      exit 1
    fi
    ;;
  ecdsa)
    if [[ ${bits} -ne 256 ]] || [[ ${bits} -ne 384 ]] || [[ ${bits} -ne 521 ]]; then
      usage "Invalid key size for ${algo}"
      exit 1
    fi
    ;;
  ed25519)
    bits=
    continue ;;
  *)
    usage "Invalid algorithm specified"
    exit 1 ;;
esac


# Be verbose if asked
[ ${verbose} -gt 0 ] && echo "Creating new SSH keys..."

# Iterate ${users[@]}
for user in ${users[@]}; do

  # Be verbose if asked
  [ ${verbose} -gt 0 ] && echo "  Creating new key pair for '${user}'..."


  # Acquire the users home directory
  home="$(grep "^${user}" /etc/passwd | cut -d: -f6)"

  # Skip if ${home} is NULL & notify
  if [ "${home}" == "" ]; then
    [ ${verbose} -gt 0 ] && echo "  Error: Could not obtain home directory for '${user}', skipping..."
    ret=1
    continue
  fi

  # Check for running processes for ${user} that may indicate an active connection to ${hosts}
  proc=( $(netstat -au | grep ${user} | nawk -v filter="${hosts}" '$0 ~ filter{print $3}') )

  # If ${#proc[@]} > 0 abort and notify user
  if [ ${#proc[@]} -gt 0 ]; then

    [ ${verbose} -gt 0 ] && echo "  Error: Found '${#proc[@]}' PID's matching '${hosts}' running as '${user}', aborting new key creation..."
    ret=1
    continue
  fi


  # Perform backup of ${home}/.ssh if it exists
  if [ -d ${home}/.ssh ]; then
    echo "  Making backup of '${home}/.ssh'"
    ocwd="$(pwd)"
    cd ${home}
    tar -cf .ssh-$(date +%Y%m%d).tar .ssh
    gzip -f .ssh-$(date +%Y%m%d).tar
    rm -r .ssh/id* 2>/dev/null
    cd ${ocwd}
  fi

  # Create and set permissions on the .ssh folder
  group="$(groups "${user}" | cut -d" " -f1)"
  if [ ! -d ${home}/.ssh ]; then
    mkdir -p ${home}/.ssh
    chown ${user}:${group} ${home}/.ssh
    chmod 0700 ${home}/.ssh
  fi


  # Export the ${algo}, ${bits} & ${path}
  export algo=${algo}
  export bits=${bits}
  export path="${home}/.ssh/id_${algo}"


  # Change to ${user} & create a password less private key
  if [ "${password}" == "" ]; then
    su ${user} -c 'cat /dev/zero 2>/dev/null | ssh-keygen -q -f ${path} -t ${algo} -b ${bits} -N "" -C "${user}@${hname}"' &> /dev/null
  else
    su ${user} -c 'ssh-keygen -q -f ${path} -t ${algo} -b ${bits} -N "${password}" -C "${user}@${hname}"' &> /dev/null
  fi

  # Just in case the PRNG for ssh-keygen wasn't ready for a large primes
  wait

  # Validate key creation
  if [ ! -f ${home}/.ssh/id_${algo} ]; then
    [ ${verbose} -gt 0 ] && echo "  An error occurred generating private key for '${user}'"
    ret=1
    continue
  fi

  # Get the fingerprint associated with the public key
  fp="$(echo "${home}/.ssh/id_${algo}.pub" | ssh-keygen -l 2>/dev/null | awk '{print $2}')"

  # Let the user know
  [ ${verbose} -gt 0 ] && echo "  Generated key pair for '${user}' (${fp})"
done

exit ${ret}

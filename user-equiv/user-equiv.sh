#!/bin/bash

# Define some defaults
users=
systems=
default_password=
default_algo="rsa"
default_bits="2048"
verbose=0

# Help system function
function usage()
{
  # Handle error if present
  [ "${1}" != "" ] && error="${1}"

  # Print a friendly menu
  cat <<EOF
${error}

Facilitates Oracle user equivalence

Usage ./user-equiv.sh [options]

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


# Set ${algo}, ${bits} & ${password}
algo="${algo:=${default_algo}}"
bits="${bits:=${default_bits}}"
password="${password:=${default_password}}"

# Turn on the verbosity option for all tools if = 1
[ ${verbose} -eq 1 ] && verbose="-v" || verbose=


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


# Test for ${cwd}/tools/ssh-keys.sh
if [ ! -f ${cwd}/tools/ssh-keys.sh ]; then
  echo "Could not locate 'tools/ssh-keys.sh' script, aborting"
  exit 1
fi

# Run ${cwd}/tools/ssh-keys.sh
./${cwd}/tools/ssh-keys.sh -a ${algo} -b ${bits} -u ${users} -s ${systems} -p ${password} ${verbose}
if [ $? -ne 0 ]; then
  echo "An error occurred generating key pair, exiting"
  exit 1
fi


# Test for ${cwd}/tools/deploy-authorized.sh
if [ ! -f ${cwd}/tools/deploy-authorized.sh ]; then
  echo "Could not locate 'tools/deploy-authorized.sh' script, aborting"
  exit 1
fi

# Run ${cwd}/tools/deploy-authorized.sh
./${cwd}/tools/deploy-authorized.sh -a ${algo} -u ${users} -s ${systems} ${verbose}
if [ $? -ne 0 ]; then
  echo "An error occurred deploying public keys, exiting"
  exit 1
fi

# Test for ${cwd}/tools/deploy-known-hosts.sh
if [ ! -f ${cwd}/tools/deploy-known-hosts.sh ]; then
  echo "Could not locate 'tools/deploy-known-hosts.sh' script, aborting"
  exit 1
fi

# Run ${cwd}/tools/deploy-known-hosts.sh
./${cwd}/tools/deploy-known-hosts.sh -u ${users} -s ${systems} ${verbose}
if [ $? -ne 0 ]; then
  echo "An error occurred configuring known_hosts, exiting"
  exit 1
fi


# Test for ${cwd}/tools/test.sh
if [ ! -f ${cwd}/tools/test.sh ]; then
  echo "Could not locate 'tools/test.sh' script, aborting"
  exit 1
fi

# Run ${cwd}/tools/test.sh
./${cwd}/tools/test.sh -u ${users} -s ${systems} ${verbose}
if [ $? -ne 0 ]; then
  echo "An error occurred testing SSH & cluvfy functionality, exiting"
  exit 1
fi

exit 0

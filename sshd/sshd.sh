#!/bin/bash

# Makes changes to running SSHD service

# File to handle sshd service
file=/etc/ssh/sshd_config

# Declare an array of properties for ${file}
declare -a props
props+=('Protocol:2')
props+=('PermitRootLogin:no')
props+=('SyslogFacility:AUTH')
props+=('GSSAPIAuthentication:no')
props+=('GSSAPIKeyExchange:no')
props+=('Ciphers:aes256-ctr,aes192-ctr,aes128-ctr')
props+=('MACs:hmac-sha2-512,hmac-sha2-256,hmac-sha1')

# An array of sshd_config keys that require space separated values
declare -a exceptions
exceptions+=('AllowGroups')
exceptions+=('AllowUsers')
exceptions+=('DenyGroups')
exceptions+=('DenyUsers')

# Obtain the OS type
os=$(uname -a | grep -ic 'sun|solaris')


# Search a haystack for the supplied needle
function in_array()
{
  local args=("${@}")
  local needle="${args[0]}"
  local haystack=("${args[@]:1}")


  for i in ${haystack[@]}; do
    if [[ ${i} == ${needle} ]]; then
      echo 0 && return
    fi
  done

  echo 1
}


# Handle SMF restart
function solaris()
{
  # Define the svc for properties
  srvc="svc:/network/ssh:default"

  # Determine if ${srvc} is online
  if [ $(svcs -a | awk '$1 ~ /online/{print 1}' | grep -c ${srvc}) -eq 1 ]; then

    # Disable ${srvc}
    svcadm disable ${srvc}
  fi

  # Refresh the ${srvc}
  svccfg -s ${srvc} refresh

  # Handle errors
  if [ $? -ne 0 ]; then
    echo "Error: Unable to reload SMF/SVC configuration for '${srvc}'"
    exit 1
  fi

  echo "Ok: Reloaded configuration for '${srvc}'"

  svcadm enable ${srvc}

  # Handle errors
  if [ $? -ne 0 ]; then
    echo "Error: Unable to restart service '${srvc}'"
    exit 1
  fi
}


# Linux service restart function
function linux()
{
  # Define the svc for properties
  srvc="sshd"

  # Try to disable via systemctl first
  systemctl stop ${srvc}.service 2>/dev/null
  if [ $? -ne 0 ]; then
    if [ -f /etc/init.d/${srvc} ]; then
      /etc/init.d/${srvc} stop 2>/dev/null
    fi
  fi

  # Start via systemctl first
  systemctl start ${srvc}.service 2>/dev/null
  if [ $? -ne 0 ]; then
    if [ -f /etc/init.d/${srvc} ]; then
      /etc/init.d/${srvc} start 2>/dev/null
    fi
  fi

  # Check the process list for sshd & exit with error if unable to restart
  if [ $(ps -xaf | grep -c ${srvc}) -le 1 ]; then
    echo "Error: Unable to restart '${srvc}'"
    exit 1
  fi

}


# Make a backup of the configuration file
function backup()
{
  # Make sure it exists (it damn well should)
  if [ ! -f ${file} ]; then

    echo "Error: '${file}' missing, aborting"
    exit 1
  fi

  # Create a temeporary file name
  tfile=${file}.$(date +%Y%m%d-%H%M%S)

  # Make a backup
  cp -p ${file} ${tfile}

  echo "Ok: Created backup of '${file}' as '${tfile}'"
}


# Perform the requested configuraton changes
function make_change()
{
  # Iterate ${props[@]}
  for property in ${props[@]}; do

    # SPlit up ${property}
    key="$(echo "${property}" | cut -d: -f1)"
    value="$(echo "${property}" | cut -d: -f2)"

    # If ${key} exists in ${exceptions[@]} array format the value
    if [ $(in_array "${key}" "${exceptions[@]}") -eq 0 ]; then
      value="$(echo "${value}" | tr ',' ' ')"
    fi

    # Make the add/edit in ${file}
    if [ $(grep -c "^${key}" ${file}) -eq 1 ]; then
      sed "s|^${key}.*|${key} ${value}|g" ${file} > ${file}.wc
    else
      echo "${key} ${value}" >> ${file}.wc
    fi

    # Validate ${property}=${props[${property}]}
    if [ $(grep -c "^${key} ${value}$" ${file}.wc) -eq 1 ]; then

      echo "Ok: '${key} ${value}' exists in '${file}'"
      [ -f ${file}.wc ] && mv ${file}.wc ${file}
    else

      echo "Error: '${key} ${value}' was not set in '${file}'"
      [ -f ${file}.wc ] && rm ${file}.wc
    fi
  done
}


# Robot, do work
make_change

# Determine which startup facility we need to use
case ${os} in
  1) solaris && break ;;
  0) linux && break ;;
  *) echo "Manual restart of SSHD is required" && break ;;
esac

echo "Ok: Restarted for '${srvc}'"

# If an error occurred it would have bubbled up
exit 0

#!/bin/bash

# Define the encryption algo for gpg
algo="aes256"

# Define the gpg binary name (Solaris is gpg2)
gpg_name="gpg"

# Use ${gpg_name} to get full path of GPG
gpg=$(which ${gpg_name} 2>/dev/null)


# Validate GPG is installed
validate_gpg()
{
  if [ -z ${gpg} ]; then
    echo 1 && return 1
  fi

  echo 0 && return 0
}


# Help test file/directory for link & use target
function validate_inode()
{
  # Re-assign ${1} to a var local in scope
  local inode="${1}"

  # Account for symlinks
  if [[ -h ${inode} ]] || [[ -L ${inode} ]]; then
    inode="$(readlink -x ${inode})"
  fi

  # Test file
  if [[ ! -f ${inode} ]] && [[ ! -d ${inode} ]]; then
    echo 1 && return 1
  fi

  # Special case for folders
  if [ -d ${inode} ]; then

    # Fix for trailing slash
    if [ "${inode: -1}" == "/" ]; then
      inode="${inode:0:${#inode}-1}"
    fi

    # Create a tarball of the directory & rename it to ${inode}
    tar -cf ${inode}.tar ${inode} #2>/dev/null

    # Make sure it exists
    if [ ! -f ${inode}.tar ]; then
      echo 1 && return 1
    fi

    # Move it from ${inode}.tar to ${inode}
    rm -fr ${inode} && mv ${inode}.tar ${inode}
  fi

  echo ${inode} && return 0
}


# Get user input for passphrase
function get_passphrase()
{
  # Define a local in scope var for passphrase
  local pass

  # Force user to input passphrase
  read -sp "Enter passphrase for '${inode}': " pass

  # Test ${pass} for null & return 1
  if [ -z "${pass}" ]; then
    echo 1 && return 1
  fi

  # echo ${pass} & return 0
  echo "${pass}" && return 0
}


# Decrypt the inode
function decrypt_inode()
{
  # Re-assign ${1} to a var local in scope
  local inode="${1}"

  # Ensure GPG is installed on system
  if [ $(validate_gpg) -eq 1 ]; then
    printf "GPG is not installed\n"
    return 1
  fi

  # Get ${inode} path & name from validate_inode() function
  inode=$(validate_inode ${inode})

  # Perform inode validation using validate_inode ${inode}
  if [ $? -eq 1 ]; then
    return 1
  fi

  # Retrieve ${pass} from getpassphrase() function
  local pass="$(get_passphrase ${inode})"

  # Make sure 0 was returned along with a non-null ${pass}
  [[ $? -ne 0 ]] || [[ -z ${pass} ]] && return 1

  # Pass supplied ${pass} to GPG as a file descriptor & open ${inode}
  echo "${pass}" | ${gpg} --yes --no-tty --batch --passphrase-fd 0 \
    --decrypt --cipher-algo ${algo} -o ${inode} ${inode} 2>/dev/null

  # Test results of ${inode}
  if [[ $(file ${inode}) =~ 'encrypted' ]]; then
    printf "\nAn error occured decrypting '%s'\n" ${inode}
    return 1
  fi

  # Handle special case for archives
  if [[ $(file ${inode}) =~ 'archive' ]]; then

    # Extract ${inode}
    tar -xf ${inode}
  fi

  # Let the user know
  printf "\nDecrypted '%s'\n" ${inode}
}


# Encrypt the inode
function encypt_inode()
{
  # Re-assign ${1} to a var local in scope
  local inode="${1}"

  # Ensure GPG is installed on system
  if [ $(validate_gpg) -eq 1 ]; then
    printf "GPG is not installed\n"
    return 1
  fi

  # Get ${inode} path & name from validate_inode() function
  inode=$(validate_inode ${inode})

  # Perform inode validation using validate_inode ${inode}
  if [ $? -eq 1 ]; then
    return 1
  fi

  # Retrieve ${pass} from get_passphrase() function
  local pass="$(get_passphrase ${inode})"

  # Make sure 0 was returned along with a non-null ${pass}
  [[ $? -ne 0 ]] || [[ -z ${pass} ]] && return 1

  # Pass supplied ${pass} to GPG as a file descriptor & open ${inode}
  echo "${pass}" | ${gpg} --yes --no-tty --batch --passphrase-fd 0 \
    --symmetric --cipher-algo ${algo} -o ${inode}.gpg ${inode} 2>/dev/null

  # Test results of ${inode}
  if [[ ! $(file ${inode}.gpg) =~ 'encrypted' ]]; then
    printf "\nAn error occured encrypting '%s'\n" ${inode}
    return 1
  fi

  # Replace ${inode} with ${inode}.gpg
  mv ${inode}.gpg ${inode}

  # Let the user know
  printf "\nEncrypted '%s'\n" ${inode}
}


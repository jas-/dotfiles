#!/bin/bash

# Get the hostname
host="$(uname -n | nawk '{print toupper($0)}')"

# Define the domain associated with the hosts FQDN
domain=".localdomain"

# Defined algorithm & key size for private keys
declare -A pkey
pkey['Algorithm']="aes256"
pkey['KeySize']=2048
pkey['Hash']="sha512"
pkey['Password']=""

# Defined OID attributes for x509 CSR
declare -A oid_attr
oid_attr['Days']=365
oid_attr['Country']="US"
oid_attr['Province']=""
oid_attr['Locality']=""
oid_attr['OrganizationalUnit']=""
oid_attr['OrganizationalUnitName']=""
oid_attr['CommonName']="${host}${domain}"
oid_attr['Email']=""

# Define a target directory for key & csr
base_directory=/etc/PKI/${oid_attr['CommonName']}

# Prevent rebuilding x within x days
stop_rebuild=30

# Ignore ${stop_rebuild}
force=0

# Define the appname
appname="$(basename $0 | cut -d. -f1)"

# Define an empty ${priv_key} variable
priv_key=


# Template to handle CSR answers
#  Country
#  State/Province
#  Locality
#  Organizational
#  Org. Unit Name
#  Common name
#  Email
read -d '' x509_tpl <<"EOF"
{Country}
{Province}
{Locality}
{OrganizationalUnit}
{OrganizationalUnitName}
{CommonName}
{Email}


EOF


# Displays available arg list
function usage()
{
  # Handle error if present
  [ "${1}" != "" ] && error="${1}"

  # Print a friendly menu
  cat <<EOF
${appname} - Automated Private Key & CSR generator
${error}

Usage ./${appname} [options]

  Help:
    -h  Show this message

  Algorithm Specific:
    -a  Symmetric Algorithm   [Default: ${pkey['Algorithm']}]
    -H  Hashing Algorithm     [Default: ${pkey['Hash']}]
    -s  Key Size              [Default: ${pkey['KeySize']}]
    -p  Password              [Default: NULL]

  x509/Certificate Specific:
    -d  Days of validity      [Default: ${oid_attr['Days']}]
    -c  Country code          [Default: ${oid_attr['Country']}]
    -P  Province/State        [Default: ${oid_attr['Province']}]
    -l  Locality/City         [Default: ${oid_attr['Locality']}]
    -o  Company Name          [Default: ${oid_attr['OrganizationalUnit']}]
    -u  Department Name       [Default: ${oid_attr['OrganizationalUnitName']}]
    -n  Common Name/FQDN      [Default: ${oid_attr['CommonName']}]
    -e  Contact email         [Default: ${oid_attr['Email']}]

  Options:
    -F  Private key           [Default: NULL]
    -f  Force new key & CSR   [Default: false]
    -D  Output directory      [Default: ${base_directory}]

EOF
}

# Handle argument parsing
while getopts "a:c:d:D:e:fF:hH:l:n:o:p:P:u:" OPTION ; do
  case $OPTION in
    a) pkey['Algorithm']=$OPTARG ;;
    c) oid_attr['Country']=$OPTARG ;;
    d) oid_attr['Days']=$OPTARG ;;
    D) base_directory=$OPTARG ;;
    e) oid_attr['Email']=$OPTARG ;;
    f) force=1 ;;
    F) priv_key=$OPTARG ;;
    h) usage && exit 0 ;;
    H) pkey['Hash']=$OPTARG ;;
    l) oid_attr['Locality']=$OPTARG ;;
    n) oid_attr['CommonName']=$OPTARG ;;
    o) oid_attr['OrganizationalUnit']=$OPTARG ;;
    p) pkey['Password']=$OPTARG ;;
    P) oid_attr['Province']=$OPTARG ;;
    u) oid_attr['OrganizationalUnitName']=$OPTARG ;;
    ?) usage && exit 0 ;;
  esac
done


# Set ${priv_key}
priv_key="${priv_key:=${base_directory}/${oid_attr['CommonName']}.key}"

# If ${pkey['Password']} NULL use ${oid_attr['CommonName']}
pw="${pkey['Password']:=${oid_attr['CommonName']}}"

# Create an HMAC from ${pw} w/ 'openssl rand -hex 16' as a salt
random_pw="$(echo "${pw}" | openssl dgst -${pkey['Hash']} -hmac "$(openssl rand hex -16)" 2>/dev/null | nawk '{print $2}')"

# Create a time stamp
ts="$(date +%Y%m%d-%H%M%S)"


# Backup anything existing for ${base_directory}
if [ -d ${base_directory} ]; then

  # If ${base_directory} timestamp create date less than ${stop_rebuild}
  rebuild="$(find ${base_directory} -type f -name ${oid_attr['CommonName']}.csr -mtime -${stop_rebuild} 2>/dev/null)"
  if [[ "${rebuild}" != "" ]] && [[ ${force} -eq 0 ]]; then
    usage "Error: CSR created less than ${stop_rebuild} days ago, aborting"
    exit 1
  fi

  # Create an archive file
  tar -cf ${base_directory}/${oid_attr['CommonName']}-${ts}.tar ${base_directory} ${priv_key} 2>/dev/null
  if [ ! -f ${base_directory}/${oid_attr['CommonName']}-${ts}.tar ]; then
    echo "Error: Could not backup existing ${base_directory}, aborting"
    exit 1
  fi

  # Compress the archive
  gzip -f ${base_directory}/${oid_attr['CommonName']}-${ts}.tar 2>/dev/null
  if [ ! -f ${base_directory}/${oid_attr['CommonName']}-${ts}.tar.gz ]; then
    echo "Error: Could not compress the backup ${base_directory}/${oid_attr['CommonName']}-${ts}.tar, aborting"
    exit 1
  fi

  echo "Ok: Created archive of ${base_directory}"
fi


# If ${base_directory} doesn't exist make it
if [ ! -d ${base_directory} ]; then

  # Make the directory
  mkdir -p ${base_directory} 2>/dev/null
  if [ $? -ne 0 ]; then
    echo "Error: Could not create target; ${base_directory}"
    exit 1
  fi

  # Set some strict(er) permissions than the default
  chmod 0700 ${base_directory} 2>/dev/null
  if [ $? -ne 0 ]; then
    echo "Error: Could not set permissions on ${base_directory}"
    exit 1
  fi

  echo "Ok: Created ${base_directory}"
fi


# One last stupid fucking test
if [ ! -d ${base_directory} ]; then
  echo "Error: ${base_directory} is missing, aborting"
  exit 1
fi

# Perform replacement of ${x509_tpl} values with ${attributes[@]}
echo "${x509_tpl}" | \
  sed -e "s/{Country}/${oid_attr['Country']}/g" \
      -e "s/{Province}/${oid_attr['Province']}/g" \
      -e "s/{Locality}/${oid_attr['Locality']}/g" \
      -e "s/{OrganizationalUnit}/${oid_attr['OrganizationalUnit']}/g" \
      -e "s/{OrganizationalUnitName}/${oid_attr['OrganizationalUnitName']}/g" \
      -e "s/{CommonName}/${oid_attr['CommonName']}/g" \
      -e "s/{Email}/${oid_attr['Email']}/g" > ${base_directory}/.${oid_attr['CommonName']}.answer

# Handle missing answer file
if [ ! -f ${base_directory}/.${oid_attr['CommonName']}.answer ]; then
  usage "Error: No answer file created, aborting"
  exit 1
fi

# Add two line breaks to answer file
echo "" >> ${base_directory}/.${oid_attr['CommonName']}.answer
echo "" >> ${base_directory}/.${oid_attr['CommonName']}.answer


# If ${base_directory}/${oid_attr['CommonName']}.key is missing OR ${force} = true
if [[ ! -f ${priv_key} ]] || [[ ${force} -eq 1 ]]; then

  # Write a new password file
  touch ${base_directory}/${oid_attr['CommonName']}.pass

  # Set some strict permissions on the newly populated key
  chmod 0600 ${base_directory}/${oid_attr['CommonName']}.pass 2> /dev/null

  # Create the password file for later recovery & use in private key generation
  cat <<EOF > ${base_directory}/${oid_attr['CommonName']}.pass
${random_pw}
EOF

  # Generate a new private key based on configured ${pkey[@]} array attributes
  openssl genrsa -${pkey['Algorithm']} -passout file:${base_directory}/${oid_attr['CommonName']}.pass -out ${priv_key}.orig ${pkey['KeySize']}

  if [ $? -ne 0 ]; then
    echo "Error: An error occurred generating new private key"
    exit 1
  fi

  # Wait, just in case the PRNG wasn't ready
  wait

  # Handle missing private key
  if [ ! -f ${priv_key}.orig ]; then
    echo "Error: No private key created, aborting"
    exit 1
  fi

  # Strip pass work from ${priv_key}.orig
  openssl rsa -passin file:${base_directory}/${oid_attr['CommonName']}.pass -in ${priv_key}.orig -out ${priv_key}

  if [ $? -ne 0 ]; then
    echo "Error: An error occurred stripping pass phrase from private key"
    exit 1
  fi

  # Wait, just in case the PRNG wasn't ready
  wait

  # Handle missing private key
  if [ ! -f ${priv_key} ]; then
    echo "Error: No private key created, aborting"
    exit 1
  fi

  echo "Ok: Created new private key"
fi

# Use ${csr_tpl} to generate a new x509 CSR
cat ${base_directory}/.${oid_attr['CommonName']}.answer | \
  openssl req -new -key ${priv_key} -out ${base_directory}/${oid_attr['CommonName']}.csr \
    -days ${oid_attr['Days']} 2>/dev/null

if [ $? -ne 0 ]; then
  echo "Error: An error occurred creating the CSR"
  exit 1
fi

# Remove answer file
[ -f ${base_directory}/.${oid_attr['CommonName']}.answer ] && rm -f ${base_directory}/.${oid_attr['CommonName']}.answer

# Try to account for race conditions
wait

# Handle missing private key
if [ ! -f ${base_directory}/${oid_attr['CommonName']}.csr ]; then
  echo "Error: No CSR created, aborting"
  exit 1
fi


# Get details of new CSR
openssl req -text -in ${base_directory}/${oid_attr['CommonName']}.csr

# Set some strict permissions on everything
chown -R root:root ${base_directory} 2> /dev/null
chmod -R 0600 ${base_directory}/*.key* 2> /dev/null
chmod 0600 ${priv_key} 2> /dev/null
chmod 0644 ${base_directory}/*.csr 2> /dev/null

exit 0

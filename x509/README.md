# gen-csr.sh

Can be used to generate large amounts of PKI certificate signing requests with existing
or new private keys.

The tool takes into account the proper key deriving requisites defined in NIST SP 800-53

## Usage ##
Here is the currently argument list available for the tool. While the argument list can be used
to override defaults it is best to configure the defaults for simplicity of deployment (See `config`
section)

```sh
./gen-csr.sh

Usage ./${appname} [options]

  Help:
    -h  Show this message

  Algorithm Specific:
    -a  Symmetric Algorithm   [Default: aes256]
    -H  Hashing Algorithm     [Default: 2048]
    -s  Key Size              [Default: sha512]
    -p  Password              [Default: NULL]

  x509/Certificate Specific:
    -d  Days of validity      [Default: 365]
    -c  Country code          [Default: NULL]
    -P  Province/State        [Default: NULL]
    -l  Locality/City         [Default: NULL]
    -o  Company Name          [Default: NULL]
    -u  Department Name       [Default: NULL]
    -n  Common Name/FQDN      [Default: NULL]
    -e  Contact email         [Default: NULL]

  Options:
    -F  Private key           [Default: NULL]
    -f  Force new key & CSR   [Default: false]
    -D  Output directory      [Default: /etc/PKI/<systemname>]

```

## Config ##
Simple configuration of the tool in reference to algorithm, hash type & key size is available
with the following items:

```sh
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

```


## license ##

This software is licensed under the [MIT License](https://github.com/jas-/dotfiles/blob/master/LICENSE).

Copyright Jason Gerfen, 2004-2018.

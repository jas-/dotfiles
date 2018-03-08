# user-equiv

This tool is helpful for use as a bladelogic job but can be modified to handle additional
deployment methods.

It can handle multiple systems & multiple users. Each user account on each defined system
get their own private key to help with privilege isolation.

## Usage ##
Here is the currently supported options. These are used to call each subsequent script
found in the `tools` folder.

```sh
$ ./user-equiv.sh

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
```

## Tools ##

* `tools/ssh-keys.sh`           Generates a new private key per defined account on each defined system (creats backup of existing keys)
* `tools/deploy-authorized.sh`  (Bladelogic specific) Accumulates & deploys the public key for each user to each system (other then its own)
* `tools/deploy-known-hosts.sh` For each account and each system this tool acquires the necessary host id and populates `known_hosts`
* `tools/test.sh`               Performs two tests per account & per system; one test of SSH functionality and one for the Oracle cluster

## license ##

This software is licensed under the [MIT License](https://github.com/jas-/dotfiles/blob/master/LICENSE).

Copyright Jason Gerfen, 2004-2018.

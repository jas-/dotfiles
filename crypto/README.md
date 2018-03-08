# gpg.sh

Facilitates easy creation of shell alias to assist with encryption / decryption of file(s) & folder(s)

## Alias/Functions ##
The tool provides two `alias` function helpers;

* `encrypt_inode`
* `decrypt_inode`

## Installation ##
Simply create the necessary aliases by including `crypto/gpg.sh` into your `.bashrc` or `.profile`

`$ echo "source ~/crypto/gpg.sh" >> ~/.bashrc`

## Usage ##
Usage is simple; to encrypt use:

`$ encrypt_inode ~/path/to/file.txt` or `$ encrypt_inode ~/path/to/folder`

And to decrypt use:

`$ decrypt_inode ~/path/to/archive`


## license ##

This software is licensed under the [MIT License](https://github.com/jas-/dotfiles/blob/master/LICENSE).

Copyright Jason Gerfen, 2004-2018.

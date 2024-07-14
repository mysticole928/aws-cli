# Using PEM files

To use a .pem file with ssh, add the `-i` option and the name of the pem file.

```shell
ssh -i <file.pem> ec2-user@domain.name.fqdn
```

# Store SSH keys (PEM files) in MacOS keychain

## Everything in its place

Move the `.pem` file to the `.ssh` directory in the home folder.

Then edit (or create) the `config` file in the `.ssh` directory and add the following:

```
Host: *
  UseKeychain yes
  AddKeysToAgent yes
  IdentityFile ~./ssh/file.pem
```

It's possible to have multiple hosts in the `config` file.  

This file makes the ssh keys persist between reboots.

## Add the .pem file to the Keychain

Until MacOS 13 (Venture), the command to add a `.pem` file was:

```
ssh-add -K file.pem
```

In MacOS 13, this command still works.  However, there's a warning message:

```shell
WARNING: The -K and -A flags are deprecated and have been replaced
         by the --apple-use-keychain and --apple-load-keychain
         flags, respectively.  To suppress this warning, set the
         environment variable APPLE_SSH_ADD_BEHAVIOR as described in
         the ssh-add(1) manual page.
```

The updated command is:

```shell
ssh-add --apple-use-keychain file.pem
```



## Building a repository from source using gpm

gpm is both a package manager and a build tool which means you can use gpm to install a repository by building it from source.

For gpm, to be able to build a repository from source, it needs a file called `gpm.yaml` at the repository root.

example:
```shell
repository
        |- data
        |- lib
        |- README.md
        |- gpm.yaml # here
```

This file contains information about **type** of the repository that is whether the repository is a `cli` program or an `application`.

Next, it contains **build** instructions on what platforms are supported by the repository and instructions on how to build the repository on each of them.

Here is gpm's own [build specification](https://github.com/generic-package-manager/gpm/blob/main/gpm.yaml) to help you understand, it contains detailed description on how to write a build specification file.

You can test your build specification locally without even pushing the file by using the `--build-locally` option.s

### Can I write gpm.yaml for any repo?
Yes, if your repository contains a binary or script that can be installed as a package, then, you can write a build specification for it.

You can even clone any repo and write a build specification for it and then you can build the repository using `gpm --build-locally userid/repo`.

### What about Desktop Shortcuts?
gpm will itself create the desktop shortcut for any application that you are trying to install.
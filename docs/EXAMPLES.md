
## Cli Usage Examples

Hi there! follow this guide to understand how to use gpm.

As we know every repository on GitHub has a unique **owner** username.
for example: omegaui/cliptopia, here **omegaui** is the username and **cliptopia** is the repo name.

This technique allows multiple users to have the same repository name throughout GitHub.
for example: x/repo and y/repo can co-exist as they have different owners.

To install a repository using gpm, you need to put the full-qualified name of the repository you are trying to install.

For example, install rufus on Windows
```shell
gpm --install pbatard/rufus
```

But it's not compulsory, if you only provide the name of the repository, gpm will then query a search and bring you the
top 10 results based on the number of stars on the repository.

so, you can even run the same as:
```shell
gpm --install rufus
```

Run `gpm --help` to see more available options and flags.

## Building a repository
To build a repository from source, it should have `gpm.yaml` file at its root, a detailed set of instructions on this can
be found at the [build from source guide](https://github.com/generic-package-manager/gpm/blob/main/docs/BUILD_FROM_SOURCE.md).

Try running the following:
```shell
gpm --build omegaui/cliptopia
```

## Example Projects (using gpm)

- [Cliptopia](https://github.com/omegaui/cliptopia): Cliptopia is a beautiful state-of-the-art clipboard management software for linux desktops that turns your simple clipboard into a full-fledged ⚡power house⚡
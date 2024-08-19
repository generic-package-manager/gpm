![gpm-banner](https://github.com/user-attachments/assets/e1de1053-26d3-44be-9fcf-09348e4a4bd2)

<div align="center">
    <h3>Generic Package Manager</h3>
    <p>
        Directly install applications from their GitHub repository with out-of-the-box support for updates<br>using gpm, the package manager with the superpowers of a cross platform build tool.
    </p>
    <a href="https://github.com/generic-package-manager/gpm/blob/main/docs/EXAMPLES.md"><img src="https://img.shields.io/badge/Usage-Examples-pink?style=for-the-badge" alt="Examples"/></a>
</div>

## Getting Started

Hi! there, follow this guide to install `gpm` cli on your system.
At the end of this guide, you will find additional resources related to cli usage.

**Let's start**.
## Platform Compatibility
Here are the platforms currently supported by gpm:
- 🔥👌 Windows OS
- 🔥👌 Linux (Any)
- 🪵🚫 Mac OS (Not Supported, yet)

## Installation Methods
There are many ways to install `gpm`.

Choose the one which suits you the best:
- (1) Install directly from terminal
- (2) Install from releases
- (3) Install gpm using gpm (yeah, it's possible)
- (4) Build gpm using gpm

### (1) ⚡ Install directly from terminal
To use this method, make sure you have the requirements installed as per your os:

**For Windows**

**Requirements**: 
*pwsh (PowerShell)* on Windows OS
```shell
. { iwr -useb https://raw.githubusercontent.com/generic-package-manager/gpm/main/pyro/windows/install.ps1 } | iex
```

**For Linux**

**Requirements**: *curl* on Linux
```shell
curl --proto '=https' --tlsv1.2 -sSf https://raw.githubusercontent.com/generic-package-manager/gpm/main/pyro/linux/install.sh | bash
```

### (2) ⚡ Install from releases
This method is pretty easy but its not recommended as you won't recieve any update on `gpm cli` and you need to manually update your installation, in this method all you need to do is head over to [releases](https://github.com/generic-package-manager/gpm/releases/latest), and download the binary for your operating system.

Direct download links are provided below:

**For Windows**: Click to get [`gpm.exe`](https://github.com/generic-package-manager/gpm/releases/latest/download/gpm.exe) and [`gpm-binary-replacer.exe`](https://github.com/generic-package-manager/gpm/releases/latest/download/gpm-binary-replacer.exe)

**For Linux** : Click to get [`gpm.AppImage`](https://github.com/generic-package-manager/gpm/releases/latest/download/gpm.AppImage)

(**Important:** Rename **`gpm.AppImage`** to **`gpm`**)

After downloading the binary(s), place them at a location like **`~/tools/gpm`** and add the location to your system environment path variable.

### (3) ⚡ Install gpm using gpm
You can install gpm using gpm itself:

Step 1: Download the gpm binary for your operating system by following the steps in (2) method of installation.

Step 2: Run the downloaded binary as:

 **For Windows**
 
```shell
./gpm.exe --build generic-package-manager/gpm --yes
```

**For Linux**
 
```shell
./gpm --build generic-package-manager/gpm --yes
```

### (4) ⚡ Build gpm using gpm
`gpm` is written in dart, thus, it compiles to native code for the best performance.

For compiling gpm, You will require dart version **3.2.6** or above.

Additionally on Windows, you need to have pwsh (PowerShell) version **7.4.0**.

There are two ways to build gpm:

**Traditional**:

```shell
git clone https://github.com/generic-package-manager/gpm.git
cd gpm
# for windows
dart compile exe -o gpm.exe --target-os windows bin\gpm.dart
dart compile exe -o gpm-binary-replacer.exe --target-os windows bin\gpm_binary_replacer.dart
# for linux
dart compile exe -o gpm --target-os linux bin/gpm.dart
```

after completing the above steps, you will get the compiled `gpm` binary.

**Self Build and Install**:

You can even use gpm to build itself locally.
```shell
git clone https://github.com/generic-package-manager/gpm.git
cd gpm
./gpm-dev --build-locally generic-package-manager/gpm
```

> if you are encountering any issues in installing gpm, please create an issue [here](https://github.com/generic-package-manager/gpm/issues/new).

## Features

GPM brings the following:

- Any open source repository on GitHub is available to install as a package.

- As soon as you publish your repository on GitHub, its available for installing with gpm-cli.

- You can rollback the installed updates on any package.
    - `gpm --rollback obs-studio`

- You can even install a specific tag/version of any repository.
    - `gpm --install rufus --tag v4.0`

- You can control which apps should receive updates
    - `gpm --lock app-fleet` // lock updates

    - `gpm --unlock app-fleet` // unlock updates

- You can update any package individually or update all of them at once.
    - `gpm --update gpm` or `gpm --upgrade`

- You can even build a repository from source.
    - `gpm --build generic-package-manager/gpm` for more information on this see [building from source with gpm](/docs/BUILD_FROM_SOURCE.md).

    - You can even install a specific commit.
        - `gpm --build generic-package-manager/gpm --commit XXXXXXX`, where XXXXXXX is at least a 7 char commit hash.
    
    - You can even build a cloned repository locally.
        - `gpm --build-locally generic-package-manager/gpm`


## Usage

To install a repository run

```shell
gpm --install username/repo
```

Want a specific version installed?

```shell
gpm --install username/repo --tag <version>
```

I wanna build from source !!

```shell
gpm --build username/repo
```

Not the latest commit

```shell
gpm --build username/repo --commit <hash>
```

What about updates?

```shell
gpm --update username/repo
```

How to update them all?

```shell
gpm --upgrade
```

Oops! I don't need update on this package

```shell
gpm --lock username/repo
```

What!!! It worked better before the update

```shell
gpm --roll-back username/repo
```

But My repository is private

```shell
gpm --install username/repository --token <your_github_token>
```

## Build from source

#### Requirements
On Windows: **dart ^3.2.6 and pwsh ^7.4.0**

On Linux: **dart ^3.2.6**

```shell
# clone the repo
git clone https://github.com/generic-package-manager/gpm
cd gpm
```

```shell
# use gpm to build from source
# for windows
./gpm-dev.bat --build-locally generic-package-manager/gpm
# for linux
./gpm-dev --build-locally generic-package-manager/gpm
```


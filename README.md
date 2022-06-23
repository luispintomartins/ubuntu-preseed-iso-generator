# Ubuntu Preseed ISO Generator
A script to generate a fully-automated ISO image for installing Ubuntu onto a machine without human interaction. 
This uses the old preseed method for Ubuntu 18.04 and older.

## [Looking for the autoinstall version?](https://github.com/covertsh/ubuntu-autoinstall-generator)

### Behavior

Check out the usage information below for arguments. The basic idea is to take an unmodified Ubuntu ISO image, extract it, add some kernel command line parameters and a preseed file, then repack the data into a new ISO. Creating the preseed file itself is outside the scope of this tool.

There is an example preseed file ```example.seed``` in this repository which will install Ubuntu using US English settings and UTC time zone with a user named "User" and password "ubuntu". You could modify that file to create your own custom configuration. Unlike the server version of this script, there is currently no way to provide the preseed configuration on a separate volume during the installation - it must be baked into the ISO image.

This script can use an existing ISO image or download the latest daily 64-bit image from the Ubuntu project. Using a fresh ISO speeds things up because there won't be as many packages to update during the installation.

By default, the source ISO image is checked for integrity and authenticity using GPG. This can be disabled with ```-k```.

### Requirements
Tested on a host running Ubuntu 16.04.7 and 18.04.6.
- Utilities required:
    - ```p7zip-full```
    - ```mkisofs``` or ```genisoimage```

### Usage
```
Usage: ubuntu-preseed-iso-generator.sh [-h] [-k] [-v] [-V] [-r] [-p preseed-configuration-file] [-s source-iso-file] [-d destination-iso-file]

💁 This script will create fully-automated Ubuntu installation media using preseed.

Available options:

-h, --help              Print this help and exit
-v, --verbose           Print script debug info
-p, --preseed           Path to preseed configuration file.
-k, --no-verify         Disable GPG verification of the source ISO file. By default SHA256SUMS-$today and
                        SHA256SUMS-$today.gpg in ${script_dir} will be used to verify the authenticity and integrity
                        of the source ISO file. If they are not present the latest daily SHA256SUMS will be
                        downloaded and saved in ${script_dir}. The Ubuntu signing key will be downloaded and
                        saved in a new keyring in ${script_dir}
-V, --version           Select the Ubuntu version to choose from (default: ${ubuntu_version}).
-r, --use-release-iso   Use the current release ISO instead of the daily ISO. The file will be used if it already
                        exists.
-a, --additional-files  Specifies an optional folder which contains additional files, which will be copied to the iso root
-s, --source            Source ISO file. By default the latest daily ISO for Ubuntu ${ubuntu_version^} will be downloaded
                        and saved as ${script_dir}/${original_iso}
                        That file will be used by default if it already exists.
-d, --destination       Destination ISO file. By default ${script_dir}/ubuntu-preseed-$today.iso will be
                        created, overwriting any existing file.
```

### Example
```
user@testbox:~$ bash ubuntu-preseed-iso-generator.sh -p example.seed -d ubuntu-preseed-example.iso
[2022-08-27 18:48:39] 👶 Starting up...
[2022-08-27 18:48:39] 🔎 Checking for current release...
[2022-08-27 18:48:39] 💿 Current release is 18.04.6
[2022-08-27 18:48:39] 📁 Created temporary working directory /tmp/tmp.aDQdsgH5Nw
[2022-08-27 18:48:39] 🔎 Checking for required utilities...
[2022-08-27 18:48:39] 👍 All required utilities are installed.
[2022-08-27 18:48:39] 🌎 Downloading ISO image ubuntu-18.04.6-live-server-amd64.iso for Ubuntu Bionic...
[2022-08-27 18:49:13] 👍 Downloaded and saved to /tmp/tmp.aDQdsgH5Nw/ubuntu-18.04.6-live-server-amd64.iso
[2022-08-27 18:49:13] 🌎 Downloading SHA256SUMS & SHA256SUMS.gpg files...
[2022-08-27 18:49:13] 🌎 Downloading and saving Ubuntu signing key...
[2022-08-27 18:49:13] 👍 Downloaded and saved to /home/user/843938DF228D22F7B3742BC0D94AA3F0EFE21092.keyring
[2022-08-27 18:49:13] 🔐 Verifying /tmp/tmp.aDQdsgH5Nw/ubuntu-18.04.6-live-server-amd64.iso integrity and authenticity...
[2022-08-27 18:49:18] 👍 Verification succeeded.
[2022-08-27 18:49:18] 🔧 Extracting ISO image...
[2022-08-27 18:49:19] 👍 Extracted to /tmp/tmp.aDQdsgH5Nw
[2022-08-27 18:49:19] 🧩 Adding preseed parameters to kernel command line...
[2022-08-27 18:49:19] 👍 Added parameters to UEFI and BIOS kernel command lines.
[2022-08-27 18:49:19] 🧩 Adding preseed configuration file...
[2022-08-27 18:49:19] 👍 Added preseed file
[2022-08-27 18:49:19] 👷 Updating /tmp/tmp.aDQdsgH5Nw/md5sum.txt with hashes of modified files...
[2022-08-27 18:49:19] 👍 Updated hashes.
[2022-08-27 18:49:19] 📦 Repackaging extracted files into an ISO image...
[2022-08-27 18:49:58] 👍 Repackaged into /home/user/ubuntu-preseed-example.iso
[2022-08-27 18:49:58] ✅ Completed.
[2022-08-27 18:49:58] 🚽 Deleted temporary working directory /tmp/tmp.aDQdsgH5Nw
```

Now you can boot your target machine using ```ubuntu-preseed-example.iso``` and it will automatically install Ubuntu using the configuration from ```example.seed```.

### Thanks
This script is based on [this](https://betterdev.blog/minimal-safe-bash-script-template/) minimal safe bash template, and steps found in [this](https://askubuntu.com/questions/806820/how-do-i-create-a-completely-unattended-install-of-ubuntu-desktop-16-04-1-lts) Ask Ubuntu answer.


### License
MIT license.

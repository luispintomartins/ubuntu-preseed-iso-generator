#!/usr/bin/env bash
set -Eeuo pipefail

function cleanup() {
        trap - SIGINT SIGTERM ERR EXIT
        if [ -n "${tmpdir+x}" ]; then
                rm -rf "$tmpdir"
                log "🚽 Deleted temporary working directory $tmpdir"
        fi
}

trap cleanup SIGINT SIGTERM ERR EXIT
script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)
[[ ! -x "$(command -v date)" ]] && echo "💥 date command not found." && exit 1
today=$(date +"%Y-%m-%d")

function log() {
        echo >&2 -e "[$(date +"%Y-%m-%d %H:%M:%S")] ${1-}"
}

function die() {
        local msg=$1
        local code=${2-1} # Bash parameter expansion - default exit status 1. See https://wiki.bash-hackers.org/syntax/pe#use_a_default_value
        log "$msg"
        exit "$code"
}

usage() {
        cat <<EOF
Usage: $(basename "${BASH_SOURCE[0]}") [-h] [-k] [-v] [-V] [-r] [-p preseed-configuration-file] [-s source-iso-file] [-d destination-iso-file]

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
EOF
        exit
}

function parse_params() {
        # default values of variables set from params
        ubuntu_version="bionic"
        preseed_file=""
        download_url="https://cdimage.ubuntu.com/ubuntu-server/${ubuntu_version}/daily-live/current"
        download_iso="${ubuntu_version}-live-server-amd64.iso"
        original_iso="ubuntu-original-$today.iso"
        source_iso="${script_dir}/${original_iso}"
        additional_files_folder=""
        destination_iso="${script_dir}/ubuntu-preseed-$today.iso"
        sha_suffix="${today}"
        gpg_verify=1
        use_release_iso=0

        while :; do
                case "${1-}" in
                -h | --help) usage ;;
                -v | --verbose) set -x ;;
                -k | --no-verify) gpg_verify=0 ;;
                -V | --version)
                        ubuntu_version="${2-}"
                        shift
                        ;;
                -p | --preseed)
                        preseed_file="${2-}"
                        shift
                        ;;
                -r | --use-release-iso) use_release_iso=1 ;;
                -A | --additional-files)
                        additional_files_folder="${2-}"
                        shift
                        ;;
                -s | --source)
                        source_iso="${2-}"
                        shift
                        ;;
                -d | --destination)
                        destination_iso="${2-}"
                        shift
                        ;;
                -?*) die "Unknown option: $1" ;;
                *) break ;;
                esac
                shift
        done

        log "👶 Starting up..."

        # check required params and arguments
        [[ -z "${preseed_file}" ]] && die "💥 preseed file was not specified."
        [[ ! -f "$preseed_file" ]] && die "💥 preseed file could not be found."

        if [ "${source_iso}" != "${script_dir}/${original_iso}" ]; then
                [[ ! -f "${source_iso}" ]] && die "💥 Source ISO file could not be found."
        fi

        if [ "${use_release_iso}" -eq 1 ]; then
                download_url="https://releases.ubuntu.com/${ubuntu_version}"
                log "🔎 Checking for current release..."
                download_iso=$(curl -sSL "${download_url}" | grep -oP 'ubuntu-\d+\.\d+\.\d*.*-server-amd64\.iso' | head -n 1)
                original_iso="${download_iso}"
                source_iso="${script_dir}/${download_iso}"
                current_release=$(echo "${download_iso}" | cut -f2 -d-)
                sha_suffix="${current_release}"
                log "💿 Current release is ${current_release}"
        fi

        destination_iso=$(realpath "${destination_iso}")
        source_iso=$(realpath "${source_iso}")

        return 0
}

ubuntu_gpg_key_id="843938DF228D22F7B3742BC0D94AA3F0EFE21092"

parse_params "$@"

tmpdir=$(mktemp -d)

if [[ ! "$tmpdir" || ! -d "$tmpdir" ]]; then
        die "💥 Could not create temporary working directory."
else
        log "📁 Created temporary working directory $tmpdir"
fi

log "🔎 Checking for required utilities..."
[[ ! -x "$(command -v xorriso)" ]] && die "💥 xorriso is not installed."
[[ ! -x "$(command -v sed)" ]] && die "💥 sed is not installed."
[[ ! -x "$(command -v curl)" ]] && die "💥 curl is not installed."
[[ ! -x "$(command -v gpg)" ]] && die "💥 gpg is not installed."
[[ ! -f "/usr/lib/ISOLINUX/isohdpfx.bin" ]] && die "💥 isolinux is not installed."
log "👍 All required utilities are installed."

if [ ! -f "${source_iso}" ]; then
        log "🌎 Downloading ISO image ${download_iso} for Ubuntu ${ubuntu_version^}..."
        curl -fNsSL "${download_url}/${download_iso}" -o "${source_iso}" ||
                die "👿 The download of the ISO ${download_iso} failed."
        log "👍 Downloaded and saved to ${source_iso}"
else
        log "☑️ Using existing ${source_iso} file."
        if [ ${gpg_verify} -eq 1 ]; then
                if [ "${source_iso}" != "${script_dir}/${original_iso}" ]; then
                        log "⚠️ Automatic GPG verification is enabled. If the source ISO file is not the latest daily image, verification will fail!"
                fi
        fi
fi

if [ ${gpg_verify} -eq 1 ]; then
        if [ ! -f "${script_dir}/SHA256SUMS-${sha_suffix}" ]; then
                log "🌎 Downloading SHA256SUMS & SHA256SUMS.gpg files..."
                curl -fNsSL "${download_url}/SHA256SUMS" -o "${script_dir}/SHA256SUMS-${sha_suffix}" ||
                        die "👿 The download of the SHA256SUMS failed."
                curl -fNsSL "${download_url}/SHA256SUMS.gpg" -o "${script_dir}/SHA256SUMS-${sha_suffix}.gpg" ||
                        die "👿 The download of the SHA256SUMS.gpg failed."
        else
                log "☑️ Using existing SHA256SUMS-${sha_suffix} & SHA256SUMS-${sha_suffix}.gpg files."
        fi

        if [ ! -f "${script_dir}/${ubuntu_gpg_key_id}.keyring" ]; then
                log "🌎 Downloading and saving Ubuntu signing key..."
                gpg -q --no-default-keyring --keyring "${script_dir}/${ubuntu_gpg_key_id}.keyring" --keyserver "hkp://keyserver.ubuntu.com" --recv-keys "${ubuntu_gpg_key_id}"
                log "👍 Downloaded and saved to ${script_dir}/${ubuntu_gpg_key_id}.keyring"
        else
                log "☑️ Using existing Ubuntu signing key saved in ${script_dir}/${ubuntu_gpg_key_id}.keyring"
        fi

        log "🔐 Verifying ${source_iso} integrity and authenticity..."
        gpg -q --keyring "${script_dir}/${ubuntu_gpg_key_id}.keyring" --verify "${script_dir}/SHA256SUMS-${sha_suffix}.gpg" "${script_dir}/SHA256SUMS-${sha_suffix}" 2>/dev/null
        if [ $? -ne 0 ]; then
                rm -f "${script_dir}/${ubuntu_gpg_key_id}.keyring~"
                die "👿 Verification of SHA256SUMS signature failed."
        fi

        rm -f "${script_dir}/${ubuntu_gpg_key_id}.keyring~"
        digest=$(sha256sum "${source_iso}" | cut -f1 -d ' ')
        set +e
        grep -Fq "$digest" "${script_dir}/SHA256SUMS-${sha_suffix}"
        if [ $? -eq 0 ]; then
                log "👍 Verification succeeded."
                set -e
        else
                die "👿 Verification of ISO digest failed."
        fi
else
        log "🤞 Skipping verification of source ISO."
fi

log "🔧 Extracting ISO image..."
xorriso \
        -osirrox on \
        -indev "${source_iso}" \
        -extract / "$tmpdir" \
        &>/dev/null
chmod -R u+w "$tmpdir"
rm -rf "$tmpdir/"'[BOOT]'
log "👍 Extracted to $tmpdir"

log "🧩 Adding preseed parameters to kernel command line..."
# These are for UEFI mode
sed -i -e 's,file=/cdrom/preseed/ubuntu.*.seed .*,file=/cdrom/preseed/custom.seed auto=true debian-installer/locale=en_US keyboard-configuration/layoutcode=us languagechooser/language-name=English countrychooser/shortlist=US localechooser/supported-locales=en_US.UTF-8 priority=critical boot=casper automatic-ubiquity quiet splash noprompt noshell,g' "$tmpdir/boot/grub/grub.cfg"
sed -i -e 's,file=/cdrom/preseed/ubuntu.*.seed .*,file=/cdrom/preseed/custom.seed auto=true debian-installer/locale=en_US keyboard-configuration/layoutcode=us languagechooser/language-name=English countrychooser/shortlist=US localechooser/supported-locales=en_US.UTF-8 priority=critical boot=casper automatic-ubiquity quiet splash noprompt noshell,g' "$tmpdir/boot/grub/loopback.cfg"
# This one is used for BIOS mode
cat <<EOF > "$tmpdir/isolinux/txt.cfg"
default live-install
label live-install
  menu label ^Install Ubuntu
  kernel /casper/vmlinuz
  append  file=/cdrom/preseed/custom.seed auto=true priority=critical boot=casper automatic-ubiquity initrd=/casper/initrd quiet splash noprompt noshell ---
EOF
# reduce grub timeout to 1s
if grep -q "set timeout" "$tmpdir/boot/grub/grub.cfg"; then
        sed -i -e 's/set timeout=.*/set timeout=1/g' "$tmpdir/boot/grub/grub.cfg"
else
        echo "set timeout=1" >> "$tmpdir/boot/grub/grub.cfg"
fi
log "👍 Added parameters to UEFI and BIOS kernel command lines."

log "🧩 Adding preseed configuration file..."
cp "$preseed_file" "$tmpdir/preseed/custom.seed"
log "👍 Added preseed file"

if [[ -n "$additional_files_folder" ]]; then
  log "➕ Adding additional files to the iso image..."
  cp -R "$additional_files_folder/." "$tmpdir/"
  log "👍 Added additional files"
fi

log "👷 Updating $tmpdir/md5sum.txt with hashes of modified files..."
# Using the full list of hashes causes long delays at boot.
# For now, just include a couple of the files we changed.
md5=$(md5sum "$tmpdir/boot/grub/grub.cfg" | cut -f1 -d ' ')
echo "$md5  ./boot/grub/grub.cfg" > "$tmpdir/md5sum.txt"
md5=$(md5sum "$tmpdir/boot/grub/loopback.cfg" | cut -f1 -d ' ')
echo "$md5  ./boot/grub/loopback.cfg" >> "$tmpdir/md5sum.txt"
log "👍 Updated hashes."

log "📦 Repackaging extracted files into an ISO image..."
cd "$tmpdir"
xorriso \
        -as mkisofs \
                -r \
                -V "ubuntu-preseed-$today" \
                -J \
                -b isolinux/isolinux.bin \
                -c isolinux/boot.cat \
                -no-emul-boot \
                -boot-load-size 4 \
                -isohybrid-mbr /usr/lib/ISOLINUX/isohdpfx.bin \
                -boot-info-table \
                -input-charset utf-8 \
                -eltorito-alt-boot \
                -e boot/grub/efi.img \
                -no-emul-boot \
                -isohybrid-gpt-basdat \
                -o "${destination_iso}" \
                . \
        &>/dev/null
cd "$OLDPWD"
log "👍 Repackaged into ${destination_iso}"

die "✅ Completed." 0

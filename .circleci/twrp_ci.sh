#/bin/bash!
#
# Copyright (C) 2020 ItsVixano
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

# TWRP Compiler for ci/cd services by @itsVixano

MY_DIR="${BASH_SOURCE%/*}"
if [[ ! -d "$MY_DIR" ]]; then MY_DIR="$PWD"; fi

# Setup colour for the script
yellow='\033[0;33m'
white='\033[0m'
red='\033[0;31m'
green='\e[0;32m'

# Few env setup

CHATID="$chat"
API_BOT="$api"

# put device product/device name/device codename
VENDOR="xiaomi"
DEVICE="Redmi Note 5 pro"
CODENAME="whyred"

# Put the url for the device tree on github and branch
DEVICE_TREE="https://github.com/ItsVixano/android_device_xiaomi_whyred_twrp"
DEVICE_BRANCH="android-9.0"

# Check https://github.com/minimal-manifest-twrp/platform_manifest_twrp_omni branches for that
TWRP_VERSION="twrp-9.0"
USE_CUSTOM_MANIFEST="yes"

# manifest setup
if [ "$USE_CUSTOM_MANIFEST" = yes ];
then
	REPO_INIT="https://github.com/ItsVixano/platform_manifest_twrp_omni"
else
	REPO_INIT="https://github.com/minimal-manifest-twrp/platform_manifest_twrp_omni"
fi

# Telgram env setup
export BOT_MSG_URL="https://api.telegram.org/bot$API_BOT/sendMessage"
export BOT_BUILD_URL="https://api.telegram.org/bot$API_BOT/sendDocument"

tg_post_msg() {
        curl -s -X POST "$BOT_MSG_URL" -d chat_id="$2" \
        -d "parse_mode=html" \
        -d text="$1"
}

tg_post_build() {
        #Post MD5Checksum alongwith for easeness
        MD5CHECK=$(md5sum "$1" | cut -d' ' -f1)

        #Show the Checksum alongwith caption
        curl --progress-bar -F document=@"$1" "$BOT_BUILD_URL" \
        -F chat_id="$2" \
        -F "disable_web_page_preview=true" \
        -F "parse_mode=html" \
        -F caption="$3 build finished in $(($Diff / 60)) minutes and $(($Diff % 60)) seconds | <b>MD5 Checksum : </b><code>$MD5CHECK</code>"
}

tg_error() {
        curl --progress-bar -F document=@"$1" "$BOT_BUILD_URL" \
        -F chat_id="$2" \
        -F "disable_web_page_preview=true" \
        -F "parse_mode=html" \
        -F caption="$3Failed to build , check <code>error.log</code>"
}

# Setup build process

build_twrp() {
Start=$(date +"%s")

. build/envsetup.sh && lunch omni_"$CODENAME"-eng && export ALLOW_MISSING_DEPENDENCIES=true
mka recoveryimage | tee error.log

End=$(date +"%s")
Diff=$(($End - $Start))
}

export IMG="$MY_DIR"/TWRP/out/target/product/"$CODENAME"/recovery.img

# Init TWRP repo
mkdir TWRP && cd TWRP
repo init -u "$REPO_INIT" -b "$TWRP_VERSION" --depth=1
repo sync -c --force-sync --no-tags --no-clone-bundle --optimized-fetch --prune

# Clone device tree
git clone "$DEVICE_TREE" -b "$DEVICE_BRANCH" --depth=1 device/"$VENDOR"/"$CODENAME"/

# let's start building the image
tg_post_msg "<b>TWRP CI Build Triggered for $DEVICE</b>" "$CHATID"
build_twrp || error=true
DATE=$(date +"%Y%m%d")

	if [ -f "$IMG" ]; then
		echo -e "$green << Build completed in $(($Diff / 60)) minutes and $(($Diff % 60)) seconds >> \n $white"
	else
		echo -e "$red << Failed to compile the TWRP image , Check up error.log >>$white"
		tg_error "error.log" "$CHATID"
		rm -rf out
		rm -rf error.log
		exit 1
	fi

	if [ -f "$IMG" ]; then
		TWRP_IMGAGE="twrp-3.5.2_9-0-"$CODENAME"_"$DATE".img"
		mkdir sender
		mv "$IMG" sender/"$TWRP_IMGAGE"
		cd sender
		tg_post_build "$TWRP_IMGAGE" "$CHATID"
		exit
	fi

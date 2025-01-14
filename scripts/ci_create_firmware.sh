#!/bin/bash

#
# ci_create_firmware.sh
#
# Environment
#
# * `MIX_TARGET` - the target (rpi0, bbb, etc.)
# * `FW_SIGNING_KEY` - an optional key for signing firmware files
# * `DEPLOY_PATH` - where to put the firmware images
#

set -e

[[ -n "$MIX_TARGET" ]] || (echo "MIX_TARGET unset"; exit 1)
[[ -d "$DEPLOY_PATH" ]] || (echo "DEPLOY_PATH unset or directory doesn't exist"; exit 1)

FULL_FIRMWARE_FILENAME="nerves_livebook_${MIX_TARGET}.fw"
FULL_FIRMWARE_PATH="$DEPLOY_PATH/$FULL_FIRMWARE_FILENAME"
PREVIOUS_FIRMWARE_FILENAME="previous_${MIX_TARGET}.fw"
PREVIOUS_FIRMWARE_URL=https://github.com/fhunleth/nerves_livebook/releases/latest/download/nerves_livebook_${MIX_TARGET}.fw
SCRIPT_DIR=$(dirname "${BASH_SOURCE[0]}")

# Copy the firmware out of the build directory
cp _build/*/nerves/images/*.fw "$FULL_FIRMWARE_PATH"

# Sign the firmware image if there was a key
if [[ -n "$FW_SIGNING_KEY" ]]; then
    fwup -S --private-key "$FW_SIGNING_KEY" -i "$FULL_FIRMWARE_PATH" -o "$FULL_FIRMWARE_PATH"
fi

# Download the previous firmware so that the delta firmware image can be made
[[ -e "$PREVIOUS_FIRMWARE_FILENAME" ]] || wget -O "$PREVIOUS_FIRMWARE_FILENAME" $PREVIOUS_FIRMWARE_URL

# Compute the name of the delta firmware (z${UUID}_${MIX_TARGET}.fw)
#  The UUID is what should be running on the device.
#  The initial z is so that the delta updates get sorted last on GitHub Releases
#  The MIX_TARGET is to help the humans looking at the .fw files to see if one didn't get built

PREVIOUS_FIRMWARE_UUID=$(fwup -m -i "$PREVIOUS_FIRMWARE_FILENAME" | sed -rn 's/^meta-uuid="([a-f0-9\-]+)"$/\1/p')

DELTA_FIRMWARE_FILENAME="z${PREVIOUS_FIRMWARE_UUID}_${MIX_TARGET}.fw"
DELTA_FIRMWARE_PATH="$DEPLOY_PATH/$DELTA_FIRMWARE_FILENAME"

"$SCRIPT_DIR/create_delta_fw.sh" "$PREVIOUS_FIRMWARE_FILENAME" "$FULL_FIRMWARE_PATH" "$DELTA_FIRMWARE_PATH"

echo "Successfully created $DELTA_FIRMWARE_PATH"


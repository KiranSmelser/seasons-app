#!/usr/bin/env bash
#
# replace_image.sh — Replace a produce/recipe photo in the asset catalog
#
# Usage:
#   ./scripts/replace_image.sh <item_id> <path_to_image>
#
# Examples:
#   ./scripts/replace_image.sh tomato ~/Downloads/tomato.jpg
#   ./scripts/replace_image.sh kale ~/Downloads/better-kale.png

set -euo pipefail

ITEM_ID="${1:?Usage: $0 <item_id> <path_to_image>}"
IMAGE_PATH="${2:?Usage: $0 <item_id> <path_to_image>}"

ASSETS_DIR="$(cd "$(dirname "$0")/.." && pwd)/Seasons/Assets.xcassets"
IMAGESET_DIR="${ASSETS_DIR}/${ITEM_ID}.imageset"

# Validate imageset exists
if [[ ! -d "$IMAGESET_DIR" ]]; then
  echo "Error: No imageset found at ${IMAGESET_DIR}"
  echo "Available imagesets:"
  ls -1 "$ASSETS_DIR" | grep '\.imageset$' | sed 's/\.imageset$//'
  exit 1
fi

# Validate image file exists
if [[ ! -f "$IMAGE_PATH" ]]; then
  echo "Error: Image file not found: ${IMAGE_PATH}"
  exit 1
fi

# Get the file extension
EXT="${IMAGE_PATH##*.}"
FILENAME="${ITEM_ID}.${EXT}"

# Remove old image files (keep only Contents.json)
find "$IMAGESET_DIR" -type f ! -name 'Contents.json' -delete

# Copy new image
cp "$IMAGE_PATH" "${IMAGESET_DIR}/${FILENAME}"

# Write updated Contents.json
cat > "${IMAGESET_DIR}/Contents.json" <<EOF
{
  "images" : [
    {
      "filename" : "${FILENAME}",
      "idiom" : "universal",
      "scale" : "1x"
    },
    {
      "idiom" : "universal",
      "scale" : "2x"
    },
    {
      "idiom" : "universal",
      "scale" : "3x"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
EOF

echo "✓ Replaced ${ITEM_ID} image with ${IMAGE_PATH}"

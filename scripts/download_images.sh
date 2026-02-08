#!/usr/bin/env bash
#
# download_images.sh — Download stock photos from Pexels for Seasons app
#
# Usage:
#   ./scripts/download_images.sh YOUR_PEXELS_API_KEY
#
# Get a free API key at https://www.pexels.com/api/
#
# This script:
#   - Downloads square-oriented medium images (~350-400px) for all produce and recipe items
#   - Creates .imageset directories under Seasons/Assets.xcassets/ with Contents.json
#   - Skips items that already have an imageset (idempotent)
#   - Uses sleep 0.5 between requests (well within Pexels' 200 req/hour limit)

set -euo pipefail

API_KEY="${1:?Usage: $0 <PEXELS_API_KEY>}"
ASSETS_DIR="$(cd "$(dirname "$0")/.." && pwd)/Seasons/Assets.xcassets"

# --- Produce items: id → search term ---
declare -A PRODUCE_TERMS=(
  [strawberry]="fresh strawberries"
  [tomato]="fresh tomatoes"
  [apple]="fresh apples"
  [spinach]="fresh spinach leaves"
  [zucchini]="fresh zucchini"
  [blueberry]="fresh blueberries"
  [kale]="fresh kale"
  [basil]="fresh basil herb"
  [sweet_potato]="sweet potatoes"
  [peach]="fresh peaches"
  [butternut_squash]="butternut squash"
  [cilantro]="fresh cilantro herb"
  [watermelon]="fresh watermelon"
  [cantaloupe]="cantaloupe melon"
  [cherry]="fresh cherries"
  [grape]="fresh grapes"
  [pear]="fresh pears"
  [plum]="fresh plums"
  [raspberry]="fresh raspberries"
  [fig]="fresh figs"
  [pomegranate]="fresh pomegranate"
  [cranberry]="fresh cranberries"
  [persimmon]="persimmon fruit"
  [blackberry]="fresh blackberries"
  [carrot]="fresh carrots"
  [broccoli]="fresh broccoli"
  [corn]="fresh corn on the cob"
  [bell_pepper]="colorful bell peppers"
  [cucumber]="fresh cucumber"
  [green_bean]="fresh green beans"
  [cauliflower]="fresh cauliflower"
  [beet]="fresh beets"
  [asparagus]="fresh asparagus"
  [artichoke]="fresh artichoke"
  [eggplant]="fresh eggplant"
  [cabbage]="fresh cabbage"
  [radish]="fresh radishes"
  [turnip]="fresh turnip"
  [pumpkin]="pumpkin"
  [lettuce]="fresh lettuce"
  [mint]="fresh mint herb"
  [rosemary]="fresh rosemary herb"
  [parsley]="fresh parsley herb"
  [brussels_sprouts]="fresh brussels sprouts"
  [chives]="fresh chives herb"
  [collard_greens]="fresh collard greens"
  [dill]="fresh dill herb"
  [grapefruit]="fresh grapefruit"
  [leek]="fresh leeks"
  [lemon]="fresh lemons"
  [orange]="fresh oranges"
  [oregano]="fresh oregano herb"
  [parsnip]="fresh parsnips"
  [rhubarb]="fresh rhubarb stalks"
  [sage]="fresh sage herb"
  [swiss_chard]="fresh swiss chard"
  [thyme]="fresh thyme herb"
  [celery]="fresh celery stalks"
  [currant]="fresh currants"
  [garlic]="fresh garlic bulbs"
  [gooseberry]="fresh gooseberries"
  [honeyberry]="honeyberry fruit"
  [kohlrabi]="fresh kohlrabi"
  [okra]="fresh okra"
  [onion]="fresh onions"
  [potato]="fresh potatoes"
  [rutabaga]="fresh rutabaga"
  [snap_pea]="fresh snap peas"
  [tarragon]="fresh tarragon herb"
  [tart_cherry]="tart cherries"
)

download_image() {
  local id="$1"
  local search_term="$2"
  local imageset_dir="${ASSETS_DIR}/${id}.imageset"

  # Skip if imageset already exists
  if [[ -d "$imageset_dir" ]]; then
    echo "  ✓ Skipping $id (already exists)"
    return 0
  fi

  # Search Pexels API
  local encoded_term
  encoded_term=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$search_term'))")
  local response
  response=$(curl -sS -H "Authorization: $API_KEY" \
    "https://api.pexels.com/v1/search?query=${encoded_term}&orientation=square&per_page=1&size=small")

  # Extract medium image URL from response
  local image_url
  image_url=$(echo "$response" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    photos = data.get('photos', [])
    if photos:
        print(photos[0]['src']['medium'])
    else:
        print('')
except Exception:
    print('')
")

  if [[ -z "$image_url" ]]; then
    echo "  ✗ No image found for $id ($search_term)"
    return 0
  fi

  # Create imageset directory
  mkdir -p "$imageset_dir"

  # Download image
  curl -sS -L -o "${imageset_dir}/${id}.jpg" "$image_url"

  # Create Contents.json
  cat > "${imageset_dir}/Contents.json" <<CONTENTS_EOF
{
  "images" : [
    {
      "filename" : "${id}.jpg",
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
CONTENTS_EOF

  echo "  ✓ Downloaded $id"
  sleep 0.5
}

echo "=== Downloading produce images ==="
for id in "${!PRODUCE_TERMS[@]}"; do
  download_image "$id" "${PRODUCE_TERMS[$id]}"
done

echo ""
echo "Done! Downloaded images to ${ASSETS_DIR}"
echo "Run 'xcodegen generate' to include them in the project."

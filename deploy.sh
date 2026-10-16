#!/usr/bin/env bash
# Copy the addon into the WoW AddOns folder.
# Usage: ./deploy.sh            (defaults to the classic beta install)
#        WOW_ADDONS=/path/to/Interface/AddOns ./deploy.sh
set -euo pipefail

ADDON_NAME="Tally"
SRC_DIR="$(cd "$(dirname "$0")" && pwd)"
WOW_ADDONS="${WOW_ADDONS:-/Applications/World of Warcraft/_classic_beta_/Interface/AddOns}"
DEST="$WOW_ADDONS/$ADDON_NAME"

if [[ ! -d "$WOW_ADDONS" ]]; then
    echo "AddOns folder not found: $WOW_ADDONS" >&2
    exit 1
fi

# Only ship what the game loads; --delete removes files dropped from the repo.
rsync -a --delete \
    --include='*.toc' --include='*.lua' --include='*.xml' \
    --include='*/' --exclude='*' \
    --prune-empty-dirs \
    "$SRC_DIR/" "$DEST/"

echo "Deployed $ADDON_NAME -> $DEST"
ls -1 "$DEST"
echo "In game: /reload to pick up changes (new files need a full client restart)."

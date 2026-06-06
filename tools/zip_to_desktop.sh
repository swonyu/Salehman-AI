#!/bin/zsh
# Zips the project SOURCE to ~/Desktop/Salehman AI.zip — re-run anytime to refresh.
# Excludes the 1.1GB training kit, .git history, build artifacts, and model weights
# so the archive stays small and shareable.
set -e
SRC_PARENT="/Users/saleh/Desktop"
DEST="$HOME/Desktop/Salehman AI.zip"
cd "$SRC_PARENT"
rm -f "$DEST"
zip -r -q -X "$DEST" "Salehman AI" \
  -x "*/.git/*" "*/.claude/*" "*/salehman-training/*" "*/.build/*" "*/build/*" \
     "*/DerivedData/*" "*.gguf" "*.safetensors" "*.bin" "*.DS_Store" "*.xcuserstate"
echo "Created: $DEST  ($(du -h "$DEST" | cut -f1))"

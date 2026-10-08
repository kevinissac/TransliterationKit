#!/bin/sh
# Copies the root README and LICENSE into js/ for `npm pack`/`npm publish` (run via js's prepack).
# Relative image and licence links are rewritten to absolute ones so they work on npmjs.com.
set -e
cd "$(dirname "$0")/.."
sed -e 's#assets/logo.png#https://raw.githubusercontent.com/kevinissac/TransliterationKit/master/assets/logo.png#' \
    -e 's#(LICENSE)#(https://github.com/kevinissac/TransliterationKit/blob/master/LICENSE)#g' README.md > js/README.md
cp LICENSE js/LICENSE

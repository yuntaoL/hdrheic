#!/bin/zsh
# Build hdrheic and install the Lightroom Classic post-process action.
set -euo pipefail

root="${0:A:h}"
upstream="${HDRHEIC_UPSTREAM:-$HOME/projects/Generate_Apple_HDR_Photos}"
source_swift="$upstream/HDR_iOS17.swift"
bindir="$HOME/.local/bin"
lr_modules="$HOME/Library/Application Support/Adobe/Lightroom/Modules"
plugin_dest="$lr_modules/AppleHDR.lrplugin"

if [[ ! -f $source_swift ]]; then
  print -u2 "install: missing $source_swift"
  print -u2 "Clone https://github.com/HCYANG2000/Generate_Apple_HDR_Photos into ~/projects first."
  exit 1
fi

mkdir -p -- "$bindir" "$lr_modules"

print "Compiling encoder…"
swiftc -swift-version 5 -O -o "$bindir/hdrheic-encode" "$source_swift" \
  -framework Cocoa -framework CoreImage -framework ImageIO

print "Compiling metadata copy…"
swiftc -O -o "$bindir/hdrheic-meta" "$root/src/meta.swift" \
  -framework ImageIO -framework Foundation

cp "$root/bin/hdrheic" "$bindir/hdrheic"
chmod 755 "$bindir/hdrheic" "$bindir/hdrheic-encode" "$bindir/hdrheic-meta"

rm -rf -- "$plugin_dest"
cp -R "$root/AppleHDR.lrplugin" "$plugin_dest"

print ""
print "Installed:"
print "  $bindir/hdrheic"
print "  $plugin_dest"
print ""
print "New terminals pick up ~/.local/bin (already on PATH when that folder exists)."
print "Quit and reopen Lightroom Classic. Apple HDR HEIC should appear in Plug-in Manager."
print "In Export, under Post-Process Actions, select it and click Insert."

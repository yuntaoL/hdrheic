#!/bin/zsh
# Install the hdrheic command and the Lightroom Classic post-process action.
#
# Normal install, without cloning anything yourself:
#   curl -fsSL https://raw.githubusercontent.com/yuntaoL/hdrheic/main/install.sh | zsh
#
# That clones this repo to ~/.local/share/hdrheic, clones the converter next
# to it, compiles ~/.local/bin/hdrheic, and copies the plug-in into the
# folder Lightroom Classic loads.
#
# From a checkout you are editing, ./install.sh installs that checkout.
set -euo pipefail

repo_url="${HDRHEIC_REPO:-https://github.com/yuntaoL/hdrheic.git}"
converter_url="https://github.com/HCYANG2000/Generate_Apple_HDR_Photos.git"
owned_root="${HOME}/.local/share/hdrheic"
owned_root="${owned_root:A}"
owned_converter="${HOME}/.local/share/hdrheic-converter"
owned_converter="${owned_converter:A}"
bindir="$HOME/.local/bin"
lr_modules="$HOME/Library/Application Support/Adobe/Lightroom/Modules"
plugin_dest="$lr_modules/AppleHDR.lrplugin"

is_full_tree() {
  local dir=$1
  [[ -n $dir && -f $dir/bin/hdrheic && -f $dir/src/meta.swift && -d $dir/AppleHDR.lrplugin ]]
}

script_root=""
case $0 in
  zsh|-zsh|sh|-sh|bash|-bash) ;;
  *) script_root="${0:A:h}" ;;
esac

# Piped or downloaded alone: this file has no sibling sources. Clone our
# repo, then run the install.sh that came with it.
if ! is_full_tree "$script_root"; then
  if [[ -d $owned_root/.git ]]; then
    print "Updating $owned_root"
    git -C "$owned_root" pull --ff-only
  elif [[ -e $owned_root ]]; then
    print -u2 "install: $owned_root exists but is not a git checkout."
    print -u2 "install: move it aside and run the installer again."
    exit 1
  else
    print "Cloning hdrheic into $owned_root"
    mkdir -p -- "${owned_root:h}"
    git clone --depth 1 "$repo_url" "$owned_root"
  fi
  if ! is_full_tree "$owned_root"; then
    print -u2 "install: $owned_root does not contain hdrheic."
    exit 1
  fi
  export HDRHEIC_BOOTSTRAPPED=1
  exec "$owned_root/install.sh"
fi

# Running the private copy directly should update it before compiling.
# Re-exec so a changed install.sh is the one that continues.
if [[ $script_root == $owned_root && ${HDRHEIC_BOOTSTRAPPED:-} != 1 ]]; then
  print "Updating $owned_root"
  git -C "$owned_root" pull --ff-only
  export HDRHEIC_BOOTSTRAPPED=1
  exec "$owned_root/install.sh"
fi

root=$script_root

# HDRHEIC_CONVERTER is an existing Generate_Apple_HDR_Photos folder.
# HDRHEIC_UPSTREAM is the old name for that same path.
converter=""
converter_label=""
if [[ -n ${HDRHEIC_CONVERTER:-} ]]; then
  converter=$HDRHEIC_CONVERTER
  converter_label=HDRHEIC_CONVERTER
elif [[ -n ${HDRHEIC_UPSTREAM:-} ]]; then
  converter=$HDRHEIC_UPSTREAM
  converter_label=HDRHEIC_UPSTREAM
fi
if [[ -n $converter ]]; then
  if [[ ! -f $converter/HDR_iOS17.swift ]]; then
    print -u2 "install: $converter_label is set to $converter"
    print -u2 "install: that folder has no HDR_iOS17.swift."
    exit 1
  fi
  print "Using your converter: $converter"
else
  legacy="$HOME/Library/Application Support/hdrheic/Generate_Apple_HDR_Photos"
  if [[ ! -e $owned_converter && -d $legacy/.git ]]; then
    print "Moving converter to $owned_converter"
    mkdir -p -- "${owned_converter:h}"
    mv -- "$legacy" "$owned_converter"
    rmdir -- "${legacy:h}" 2>/dev/null || true
  fi
  converter=$owned_converter
  if [[ -d $converter/.git ]]; then
    print "Updating $converter"
    git -C "$converter" pull --ff-only
  elif [[ -e $converter ]]; then
    print -u2 "install: $converter exists but is not a git checkout."
    print -u2 "install: move it aside, or set HDRHEIC_CONVERTER to your own Generate_Apple_HDR_Photos folder."
    exit 1
  else
    print "Cloning the converter into $converter"
    mkdir -p -- "${converter:h}"
    git clone --depth 1 "$converter_url" "$converter"
  fi
fi

source_swift="$converter/HDR_iOS17.swift"

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
print "hdrheic source for this install:"
print "  $root"
print "Lightroom Classic loads the plug-in copy in Modules, not the source folder."
print "Quit and reopen Lightroom Classic. Apple HDR HEIC should appear in Plug-in Manager."
print "In Export, under Post-Process Actions, select it and click Insert."

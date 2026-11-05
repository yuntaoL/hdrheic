# hdrheic

Short command and a Lightroom Classic post-process action for [Generate_Apple_HDR_Photos](https://github.com/HCYANG2000/Generate_Apple_HDR_Photos).

One command installs it. You do not clone this repo or the converter yourself.

## Source

| Piece | Path |
| --- | --- |
| Command | `bin/hdrheic` |
| Metadata copy | `src/meta.swift` |
| Lightroom plug-in | `AppleHDR.lrplugin/` (`Info.lua`, `ExportFilter.lua`, `PluginInfoProvider.lua`) |
| Installer | `install.sh` |

`~/.local/bin/hdrheic` is the command. Lightroom Classic loads a copy of `AppleHDR.lrplugin` from its Modules folder. For a normal install, both of those come from `~/.local/share/hdrheic`.

## Command

```sh
hdrheic photo.tif
hdrheic photo.avif -m pq -q 0.9
hdrheic -b ~/Pictures/export
hdrheic --help
```

Default mode is `hlg`: 10-bit BT.2100 HLG, which is the one Apple Photos handles well. The file is written next to the input as `.heic`.

| Mode | What you get |
| --- | --- |
| `hlg` | 10-bit HLG, lossless. Default. |
| `pq` | 10-bit PQ. Uses `-q`. |
| `raw-hlg`, `raw-pq` | Camera RAW, opened by Core Image. |
| `p3`, `p3-max`, `sdr`, `sdr-max` | Display P3, not HDR. |

## Lightroom Classic

Plug-in: `~/Library/Application Support/Adobe/Lightroom/Modules/AppleHDR.lrplugin`

1. Quit Lightroom Classic and open it again.
2. File → Plug-in Manager. Apple HDR HEIC should already be loaded from the Modules folder. If it is not, click Add and choose that `.lrplugin` folder.
3. Export. In the left column, under Post-Process Actions, select **Apple HDR HEIC** and click **Insert**.
4. Set File Settings to the format you want to keep, such as AVIF with HDR Output on. The action does not change that format.
5. In the Apple HDR HEIC section, leave **Keep the exported file** checked to get both files (`photo.avif` and `photo.heic`). Uncheck it to keep only the HEIC.
6. **HEIC prefix** is optional. Leave it empty to reuse the export name. Set it to `HEIC-` and the HEIC is `HEIC-photo.heic`, so those files sort as their own group and are easy to drag into Photos. Include the space or hyphen yourself.

The converter reads the file Lightroom just wrote. AVIF, JPEG XL, PNG, TIFF, and JPEG all work. Pick HLG unless you specifically want PQ. Turn on HDR editing for the photo, and HDR Output in File Settings, or the HEIC has no highlight headroom.

Save an export preset after you insert the action if you want one click next time.

## Install

```sh
curl -fsSL https://raw.githubusercontent.com/yuntaoL/hdrheic/main/install.sh | zsh
```

The installer clones this repo to `~/.local/share/hdrheic` and the converter to `~/.local/share/hdrheic-converter`. It compiles `~/.local/bin/hdrheic` and copies the plug-in to the only place Lightroom Classic will load it:

`~/Library/Application Support/Adobe/Lightroom/Modules/AppleHDR.lrplugin`

The Modules folder is that installed copy. The files the installer owns are in `~/.local/share/hdrheic` (`bin/hdrheic`, `src/meta.swift`, and `AppleHDR.lrplugin/`). Run the same command again to update.

From a checkout you are editing, `./install.sh` installs that checkout and leaves it where it is.

To compile against a converter you already have:

```sh
HDRHEIC_CONVERTER=~/Generate_Apple_HDR_Photos ./install.sh
```

That folder must contain `HDR_iOS17.swift`. The installer does not modify it. `HDRHEIC_UPSTREAM` is the old name for the same setting.

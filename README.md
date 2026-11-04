# hdrheic

Short command and a Lightroom Classic post-process action for [Generate_Apple_HDR_Photos](https://github.com/HCYANG2000/Generate_Apple_HDR_Photos).

That repo is cloned, unmodified, at `~/projects/Generate_Apple_HDR_Photos`. This folder only wraps it. The encoder is still `HDR_iOS17.swift`. `hdrheic` compiles it once and gives it a shorter name.

## Source

| Piece | Path |
| --- | --- |
| Command | `bin/hdrheic` |
| Metadata copy | `src/meta.swift` |
| Lightroom plug-in | `AppleHDR.lrplugin/` (`Info.lua`, `ExportFilter.lua`, `PluginInfoProvider.lua`) |
| Installer | `install.sh` |

`~/.local/bin/hdrheic` and the Lightroom Modules copy are installed from these files. They are not a second source tree.

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
4. Export as usual. File naming, size, sharpening, and metadata still apply. The format menu does not: the action renders a 16-bit HDR TIFF, writes a `.heic`, and deletes the TIFF.

Pick HLG unless you specifically want PQ. Turn on HDR editing for the photo before export, or the TIFF has no highlight headroom to preserve.

Save an export preset after you insert the action if you want one click next time.

## Install again

```sh
~/projects/hdrheic/install.sh
```

The script recompiles `~/projects/Generate_Apple_HDR_Photos/HDR_iOS17.swift` and refreshes `~/.local/bin/hdrheic`.

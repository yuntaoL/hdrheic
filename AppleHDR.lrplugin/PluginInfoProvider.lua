return {
	sectionsForTopOfDialog = function(viewFactory, _)
		local f = viewFactory
		return {
			{
				title = "Apple HDR HEIC",
				f:column {
					spacing = 8,
					f:static_text {
						title = "Export post-process action. In the Export dialog, select Apple HDR HEIC under Post-Process Actions and click Insert.",
						width_in_chars = 55,
						height_in_lines = 2,
					},
					f:static_text {
						title = "Each photo is rendered as a 16-bit HDR TIFF, then written as a 10-bit BT.2100 HEIC for Apple Photos. The TIFF is removed.",
						width_in_chars = 55,
						height_in_lines = 2,
					},
					f:static_text {
						title = "Command line: hdrheic   (installed in ~/.local/bin)",
					},
				},
			},
		}
	end,
}

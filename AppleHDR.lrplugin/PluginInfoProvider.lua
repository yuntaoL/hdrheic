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
						title = "It converts whatever this export writes (AVIF, JPEG XL, PNG, TIFF, or JPEG) into a 10-bit HEIC. You can keep the exported file or remove it.",
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

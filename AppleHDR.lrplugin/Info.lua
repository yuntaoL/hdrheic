return {
	LrSdkVersion = 6.0,
	LrSdkMinimumVersion = 6.0,
	LrToolkitIdentifier = "com.yuntaolu.hdrheic",
	LrPluginName = "Apple HDR HEIC",
	LrPluginInfoUrl = "https://github.com/yuntaoL/hdrheic",
	LrPluginInfoProvider = "PluginInfoProvider.lua",
	VERSION = { major = 1, minor = 0, revision = 0, build = 0 },

	-- Shows up in the Export dialog under Post-Process Actions.
	-- Insert it once. Export then writes a .heic and does not keep the TIFF.
	LrExportFilterProvider = {
		title = "Apple HDR HEIC",
		file = "ExportFilter.lua",
		id = "appleHdrHeic",
		supportsVideo = false,
	},
}

local LrDialogs = import "LrDialogs"
local LrFileUtils = import "LrFileUtils"
local LrPathUtils = import "LrPathUtils"
local LrTasks = import "LrTasks"
local LrUUID = import "LrUUID"
local LrView = import "LrView"

local function quote(value)
	return "'" .. tostring(value):gsub("'", "'\\''") .. "'"
end

local function heicPathFor(path)
	local parent = LrPathUtils.parent(path)
	local leaf = LrPathUtils.leafName(path)
	local stem = leaf:gsub("%.[^%.]+$", "")
	if stem == leaf then
		stem = leaf
	end
	return LrPathUtils.child(parent, stem .. ".heic")
end

local function readText(path)
	if not LrFileUtils.exists(path) then
		return ""
	end
	local ok, text = pcall(LrFileUtils.readFile, path)
	if ok and text then
		return text
	end
	return ""
end

return {
	exportPresetFields = {
		{ key = "mode", default = "hlg" },
		{ key = "quality", default = 85 },
	},

	startDialog = function(propertyTable)
		if propertyTable.mode ~= "hlg" and propertyTable.mode ~= "pq" then
			propertyTable.mode = "hlg"
		end
		if type(propertyTable.quality) ~= "number" then
			propertyTable.quality = 85
		end
		propertyTable.qualityEnabled = propertyTable.mode ~= "hlg"
		propertyTable:addObserver("mode", function(properties)
			properties.qualityEnabled = properties.mode ~= "hlg"
		end)
	end,

	sectionForFilterInDialog = function(viewFactory, _)
		local f = viewFactory
		local bind = LrView.bind
		return {
			title = "Apple HDR HEIC",
			synopsis = bind {
				key = "mode",
				transform = function(value, fromTable)
					if not fromTable then
						return value
					end
					if value == "pq" then
						return "PQ"
					end
					return "HLG"
				end,
			},
			f:column {
				spacing = 8,
				f:static_text {
					title = "Renders a 16-bit HDR TIFF, writes a 10-bit HEIC beside your file name, and deletes the TIFF.",
					fill_horizontal = 1,
					height_in_lines = 2,
				},
				f:row {
					f:static_text {
						title = "HDR:",
						width_in_chars = 12,
						alignment = "right",
					},
					f:popup_menu {
						value = bind "mode",
						width_in_chars = 28,
						items = {
							{ title = "HLG (use this)", value = "hlg" },
							{ title = "PQ", value = "pq" },
						},
					},
				},
				f:row {
					f:static_text {
						title = "Quality:",
						width_in_chars = 12,
						alignment = "right",
						enabled = bind "qualityEnabled",
					},
					f:slider {
						value = bind "quality",
						min = 75,
						max = 100,
						integral = true,
						width_in_chars = 18,
						enabled = bind "qualityEnabled",
					},
					f:static_text {
						title = bind {
							key = "quality",
							transform = function(value, fromTable)
								if not fromTable then
									return value
								end
								return tostring(math.floor(tonumber(value) or 85)) .. "%"
							end,
						},
						enabled = bind "qualityEnabled",
						width_in_chars = 4,
					},
				},
				f:static_text {
					title = "HLG is lossless. PQ uses the quality slider. Below 75% can clip HDR highlights, so the slider starts there.",
					fill_horizontal = 1,
					height_in_lines = 2,
				},
			},
		}
	end,

	postProcessRenderedPhotos = function(_, filterContext)
		local props = filterContext.propertyTable
		local home = LrPathUtils.getStandardFilePath("home")
		local bin = LrPathUtils.child(home, ".local/bin/hdrheic")
		if not LrFileUtils.exists(bin) then
			LrDialogs.message(
				"Apple HDR HEIC",
				"Could not find " .. bin .. ".\nRun ~/projects/hdrheic/install.sh, then export again.",
				"critical"
			)
			return
		end

		local mode = props.mode or "hlg"
		if mode ~= "hlg" and mode ~= "pq" then
			mode = "hlg"
		end
		local quality = tonumber(props.quality) or 85
		if quality > 1 then
			quality = quality / 100
		end
		if quality < 0.75 then
			quality = 0.75
		end
		if quality > 1 then
			quality = 1
		end
		local qualityText = string.format("%.2f", quality)

		local renditionOptions = {
			filterSettings = function(_, exportSettings)
				-- File Settings in the dialog are ignored. HDR has to be a
				-- wide-gamut high-bit TIFF or the HEIC encoder has nothing to expand.
				exportSettings.LR_format = "TIFF"
				exportSettings.LR_export_bitDepth = 16
				exportSettings.LR_enableHDRDisplay = true
				-- Same token Lightroom stores for an HDR export preset.
				exportSettings.LR_export_colorSpace = "p3_hdr"
				exportSettings.LR_tiff_compressionMethod = "compressionMethod_None"
				exportSettings.LR_embeddedMetadataOption = "all"
				local tempDir = LrPathUtils.getStandardFilePath("temp")
				return LrPathUtils.child(tempDir, "hdrheic-" .. LrUUID.generateUUID() .. ".tif")
			end,
		}

		local errors = {}
		local renames = {}

		for sourceRendition, renditionToSatisfy in filterContext:renditions(renditionOptions) do
			local success, pathOrMessage = sourceRendition:waitForRender()
			if not success then
				renditionToSatisfy:renditionIsDone(false, pathOrMessage)
				table.insert(errors, tostring(pathOrMessage))
			else
				local tiffPath = pathOrMessage
				local destPath = renditionToSatisfy.destinationPath
				local heicPath = heicPathFor(destPath)
				local logPath = tiffPath .. ".log"
				-- The encoder keys off a .heic path. Lightroom still looks for
				-- destinationPath, so a copy is placed there until the export
				-- records success, then removed.
				local cmd = table.concat({
					quote(bin),
					quote(tiffPath),
					"-o",
					quote(heicPath),
					"-m",
					quote(mode),
					"-q",
					qualityText,
					">",
					quote(logPath),
					"2>&1",
				}, " ")
				local status = LrTasks.execute(cmd)
				if status ~= 0 or not LrFileUtils.exists(heicPath) then
					local detail = readText(logPath)
					if detail == "" then
						detail = "encoder failed (status " .. tostring(status) .. ")"
					end
					table.insert(errors, LrPathUtils.leafName(heicPath) .. ": " .. detail)
					renditionToSatisfy:renditionIsDone(false, detail)
				else
					if heicPath ~= destPath then
						if LrFileUtils.exists(destPath) then
							LrFileUtils.delete(destPath)
						end
						LrFileUtils.copy(heicPath, destPath)
						table.insert(renames, destPath)
					end
					renditionToSatisfy:renditionIsDone(true)
				end
				LrFileUtils.delete(tiffPath)
				LrFileUtils.delete(logPath)
			end
		end

		for _, destPath in ipairs(renames) do
			LrFileUtils.delete(destPath)
		end

		if #errors > 0 then
			LrDialogs.message("Apple HDR HEIC", table.concat(errors, "\n\n"), "warning")
		end
	end,
}

local LrDialogs = import "LrDialogs"
local LrFileUtils = import "LrFileUtils"
local LrPathUtils = import "LrPathUtils"
local LrTasks = import "LrTasks"
local LrUUID = import "LrUUID"
local LrView = import "LrView"

local function quote(value)
	return "'" .. tostring(value):gsub("'", "'\\''") .. "'"
end

local function isHeic(path)
	return path:lower():match("%.hei[cf]$") ~= nil
end

-- Drop path separators. A blank or all-whitespace prefix means "no prefix".
-- A trailing space or hyphen is kept, so "HEIC " and "HEIC-" both work.
local function filePrefix(value)
	if type(value) ~= "string" then
		return ""
	end
	local cleaned = value:gsub("[/\\:]", "")
	if cleaned:match("^%s*$") then
		return ""
	end
	return cleaned
end

-- Sibling HEIC next to the exported file: photo.avif -> photo.heic,
-- or HEIC-photo.heic when a prefix is set. An export that is already
-- HEIC becomes photo_hdr.heic so the source is not overwritten.
local function heicPathFor(path, prefix)
	local parent = LrPathUtils.parent(path)
	local leaf = LrPathUtils.leafName(path)
	local stem = leaf:gsub("%.[^%.]+$", "")
	if stem == leaf then
		stem = leaf
	end
	local suffix = isHeic(path) and "_hdr.heic" or ".heic"
	return LrPathUtils.child(parent, (prefix or "") .. stem .. suffix)
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

local function refreshSummary(properties)
	local modeLabel = properties.mode == "pq" and "PQ" or "HLG"
	local keepLabel = properties.keepOriginal == false and "HEIC only" or "keep original"
	local summary = modeLabel .. ", " .. keepLabel
	local prefix = filePrefix(properties.heicPrefix)
	if prefix ~= "" then
		summary = summary .. ", " .. prefix
	end
	properties.summary = summary
end

return {
	exportPresetFields = {
		{ key = "mode", default = "hlg" },
		{ key = "quality", default = 85 },
		{ key = "keepOriginal", default = true },
		{ key = "heicPrefix", default = "" },
	},

	startDialog = function(propertyTable)
		if propertyTable.mode ~= "hlg" and propertyTable.mode ~= "pq" then
			propertyTable.mode = "hlg"
		end
		if type(propertyTable.quality) ~= "number" then
			propertyTable.quality = 85
		end
		if propertyTable.keepOriginal == nil then
			propertyTable.keepOriginal = true
		end
		if type(propertyTable.heicPrefix) ~= "string" then
			propertyTable.heicPrefix = ""
		end
		propertyTable.qualityEnabled = propertyTable.mode ~= "hlg"
		refreshSummary(propertyTable)
		if not propertyTable.hdrheicWatching then
			propertyTable.hdrheicWatching = true
			propertyTable:addObserver("mode", function(properties)
				properties.qualityEnabled = properties.mode ~= "hlg"
				refreshSummary(properties)
			end)
			propertyTable:addObserver("keepOriginal", function(properties)
				refreshSummary(properties)
			end)
			propertyTable:addObserver("heicPrefix", function(properties)
				refreshSummary(properties)
			end)
		end
	end,

	sectionForFilterInDialog = function(viewFactory, _)
		local f = viewFactory
		local bind = LrView.bind
		return {
			title = "Apple HDR HEIC",
			synopsis = bind "summary",
			f:column {
				spacing = 8,
				f:static_text {
					title = "After export, converts that file to a 10-bit HEIC. File Settings stay as you set them: AVIF, JPEG XL, PNG, TIFF, or JPEG.",
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
				f:row {
					f:static_text {
						title = "HEIC prefix:",
						width_in_chars = 12,
						alignment = "right",
					},
					f:edit_field {
						value = bind "heicPrefix",
						width_in_chars = 24,
						immediate = true,
					},
				},
				f:static_text {
					title = "Optional. Leave empty to keep the export name. HEIC- writes HEIC-photo.heic, so the HEIC files sort together and are easy to drag into Photos.",
					fill_horizontal = 1,
					height_in_lines = 2,
				},
				f:checkbox {
					title = "Keep the exported file",
					value = bind "keepOriginal",
				},
				f:static_text {
					title = "Checked: the folder gets both files, such as photo.avif and photo.heic. Unchecked: only the HEIC is kept.",
					fill_horizontal = 1,
					height_in_lines = 2,
				},
				f:static_text {
					title = "HLG is lossless. PQ uses the quality slider. Enable HDR in Develop, and turn on HDR Output in File Settings, or the HEIC has no highlight headroom.",
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
		-- Missing value means keep. Only an explicit false removes the export.
		local keepOriginal = props.keepOriginal ~= false

		local errors = {}
		local removeAfter = {}

		for sourceRendition, renditionToSatisfy in filterContext:renditions{ stopIfCanceled = true } do
			local success, pathOrMessage = sourceRendition:waitForRender()
			if not success then
				renditionToSatisfy:renditionIsDone(false, pathOrMessage)
				table.insert(errors, tostring(pathOrMessage))
			else
				local renderedPath = pathOrMessage
				local exportPath = renditionToSatisfy.destinationPath or renderedPath
				local heicPath = heicPathFor(exportPath, filePrefix(props.heicPrefix))
				local logPath = LrPathUtils.child(
					LrPathUtils.getStandardFilePath("temp"),
					"hdrheic-" .. LrUUID.generateUUID() .. ".log"
				)
				local cmd = table.concat({
					quote(bin),
					quote(renderedPath),
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
					LrFileUtils.delete(logPath)
					if detail == "" then
						detail = "encoder failed (status " .. tostring(status) .. ")"
					end
					table.insert(errors, LrPathUtils.leafName(exportPath) .. ": " .. detail)
					renditionToSatisfy:renditionIsDone(false, detail)
				else
					LrFileUtils.delete(logPath)
					renditionToSatisfy:renditionIsDone(true)
					if not keepOriginal then
						-- The export file has to exist while Lightroom records success.
						if renderedPath ~= heicPath then
							table.insert(removeAfter, renderedPath)
						end
						if exportPath ~= heicPath and exportPath ~= renderedPath then
							table.insert(removeAfter, exportPath)
						end
					end
				end
			end
		end

		for _, path in ipairs(removeAfter) do
			if LrFileUtils.exists(path) then
				LrFileUtils.delete(path)
				if LrFileUtils.exists(path) then
					table.insert(errors, "HEIC was written, but the exported file could not be removed: " .. path)
				end
			end
		end

		if #errors > 0 then
			LrDialogs.message("Apple HDR HEIC", table.concat(errors, "\n\n"), "warning")
		end
	end,
}

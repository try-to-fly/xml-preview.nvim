local M = {}
local has_xml2lua, xml2lua = pcall(require, "xml2lua")
local has_handler, handler_module = pcall(require, "xmlhandler.tree")

local preview_win = nil
local preview_buf = nil

local function log_error(msg)
	vim.api.nvim_err_writeln("XML Preview Error: " .. msg)
end

local function update_preview_content(content)
	if preview_buf and vim.api.nvim_buf_is_valid(preview_buf) then
		vim.api.nvim_buf_set_lines(preview_buf, 0, -1, false, vim.split(content, "\n"))
		-- 设置折叠方法
		vim.api.nvim_buf_set_option(preview_buf, "foldmethod", "syntax")
		vim.api.nvim_buf_set_option(preview_buf, "foldenable", true)
	end
end

local function is_array(tbl)
	if type(tbl) ~= "table" then
		return false
	end
	local i = 0
	for _ in pairs(tbl) do
		i = i + 1
		if tbl[i] == nil then
			return false
		end
	end
	return i > 0 -- 确保空表不被视为数组
end

local function fix_keys(tbl, depth)
	depth = depth or 0

	if type(tbl) ~= "table" then
		return tbl
	end

	local fixed_tbl = {}
	if next(tbl) == nil then
		return {}
	elseif is_array(tbl) then
		for i, v in ipairs(tbl) do
			table.insert(fixed_tbl, fix_keys(v, depth + 1))
		end
	else
		for k, v in pairs(tbl) do
			if type(k) == "number" then
				k = tostring(k)
			elseif k == "_attr" then
				k = "attrs"
			end

			if type(v) == "table" and next(v) == nil then
				fixed_tbl[k] = {}
			else
				fixed_tbl[k] = fix_keys(v, depth + 1)
			end
		end
	end

	return fixed_tbl
end

local function ensure_empty_object(tbl)
	if type(tbl) ~= "table" then
		return tbl
	end

	local result = {}
	for k, v in pairs(tbl) do
		if type(v) == "table" and next(v) == nil then
			result[k] = vim.empty_dict() -- 使用 Neovim 的空字典
		else
			result[k] = ensure_empty_object(v)
		end
	end
	return result
end

local function xml_to_json(xml_content, callback)
	if not has_xml2lua or not has_handler then
		callback("Error: Required modules not found")
		return
	end

	vim.schedule(function()
		local status, result = pcall(function()
			local handler = handler_module:new()
			local parser = xml2lua.parser(handler)
			parser:parse(xml_content)

			local fixed_root = fix_keys(handler.root)

			local ensured_root = ensure_empty_object(fixed_root)

			return vim.fn.json_encode(ensured_root)
		end)

		if not status then
			callback("Error: Failed to parse XML\n" .. tostring(result))
			return
		end

		local json = result

		local formatted_json = vim.fn.system({ "jq", "." }, json)
		if vim.v.shell_error ~= 0 then
			callback("Error: Failed to format JSON\n" .. formatted_json)
		else
			callback(formatted_json)
		end
	end)
end

local function show_loading()
	update_preview_content("Loading...")
end

local function update_preview()
	local current_buf = vim.api.nvim_get_current_buf()
	local filetype = vim.bo[current_buf].filetype

	if filetype ~= "xml" then
		return
	end

	if not preview_buf or not vim.api.nvim_buf_is_valid(preview_buf) then
		preview_buf = vim.api.nvim_create_buf(false, true)
		vim.bo[preview_buf].buftype = "nofile"
		vim.bo[preview_buf].bufhidden = "hide"
		vim.bo[preview_buf].swapfile = false
		vim.bo[preview_buf].filetype = "json"

		-- 设置语法高亮和折叠方法
		vim.api.nvim_buf_set_option(preview_buf, "syntax", "json")
		vim.api.nvim_buf_set_option(preview_buf, "foldmethod", "syntax")
		vim.api.nvim_buf_set_option(preview_buf, "foldenable", true)
	end

	if not preview_win or not vim.api.nvim_win_is_valid(preview_win) then
		local current_win = vim.api.nvim_get_current_win()
		vim.cmd("vsplit")
		preview_win = vim.api.nvim_get_current_win()
		vim.api.nvim_win_set_buf(preview_win, preview_buf)
		vim.api.nvim_set_current_win(current_win)
	end

	show_loading()

	local content = vim.api.nvim_buf_get_lines(current_buf, 0, -1, false)
	local xml_content = table.concat(content, "\n")

	xml_to_json(xml_content, function(result)
		update_preview_content(result)
	end)
end

function M.setup()
	if not has_xml2lua then
		log_error("xml2lua module not found")
		return
	end
	if not has_handler then
		log_error("xmlhandler.tree module not found")
		return
	end

	vim.cmd([[
  augroup XmlPreview
  autocmd!
  autocmd BufEnter *.xml,*.rels lua require('xml_preview').update_preview()
  autocmd BufWritePost *.xml,*.rels lua require('xml_preview').update_preview()
  autocmd WinClosed * lua require('xml_preview').handle_win_closed()
  augroup END
]])
end

function M.update_preview()
	update_preview()
end

function M.handle_win_closed()
	if preview_win and not vim.api.nvim_win_is_valid(preview_win) then
		preview_win = nil
		preview_buf = nil
	end
end

return M

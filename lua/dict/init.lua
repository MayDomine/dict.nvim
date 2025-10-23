local function dwarn(msg) vim.notify(msg, vim.log.levels.WARN, { title = "dict" }) end
local wid

local M = {}

local function winclosed() wid = nil end

local get_cword = function()
    local wcur = vim.api.nvim_win_get_cursor(0)
    if not wcur then return end
    local line = vim.api.nvim_buf_get_lines(0, wcur[1] - 1, wcur[1], true)[1]
    local cpos = wcur[2] + 1
    if type(line) == "string" then
        local cchar = string.sub(line, cpos, cpos)
        if cchar == "" or string.match(cchar, "%s") or string.match(cchar, "%p") then
            return nil
        end
        return vim.fn.expand("<cword>")
    end
    return nil
end

local function replace()
    local wrd = get_cword()
    if wrd then
        vim.api.nvim_win_close(0, false)
        vim.cmd("normal! ciw" .. wrd)
        vim.cmd("stopinsert")
    end
end

---@class DictUserOpts
---@field dict? string Name of dictionary to restrict searches on

---@type DictUserOpts
M.opts = {
    dict = nil,
}

--- Setup
---@param config? DictUserOpts
function M.setup(config)
    if config then
        for k, v in pairs(config) do
            M.opts[k] = v
        end
    end
end

function M.lookup(wrd, dict)
    if not wrd then
        wrd = get_cword()
        if not wrd then return end
    end

    local a
    if not dict then
        dict = M.opts.dict
    end
    if dict then
        a, _ = io.popen("dict -d " .. dict .. " '" .. wrd .. "' 2>/dev/null", "r")
    else
        a, _ = io.popen("dict '" .. wrd .. "' 2>/dev/null", "r")
    end
    if not a then
        dwarn("Error running: " .. "dict '" .. wrd .. "'")
        return
    end
    local output = a:read("*a")
    local suc, ecd, cd
    suc, ecd, cd = a:close()
    if not suc then
        dwarn(
            "Error running dict: "
                .. tostring(suc)
                .. " "
                .. tostring(ecd)
                .. " "
                .. tostring(cd)
        )
        return
    end

    if output == "" then
        vim.api.nvim_echo(
            { { "dictd: no definitions found for " }, { wrd, "Identifier" } },
            false,
            {}
        )
        return
    end

    -- Pad space on the left
    output = string.gsub(output, "\n", "\n ")
    -- Minor improvement to WordNet
    output = string.gsub(output, "\n       ([a-z]+) 1: ", "\n     %1\n       1: ")
    -- Mark end of definition with non-separable space
    output = string.gsub(output, "\n \n From ", "\n \n From ")
    -- Mark beginning of pronunciation in Gcide
    output = string.gsub(output, "\\ %(", "\\ (")

    local outlines = vim.split("\n" .. output, "\n")

    if not M.b then
        M.b = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_set_option_value("buftype", "nofile", { scope = "local", buf = M.b })
        vim.api.nvim_set_option_value("bufhidden", "hide", { scope = "local", buf = M.b })
        vim.api.nvim_set_option_value("swapfile", false, { scope = "local", buf = M.b })
        vim.api.nvim_set_option_value("tabstop", 2, { scope = "local", buf = M.b })
        vim.api.nvim_set_option_value("undolevels", -1, { scope = "local", buf = M.b })
        vim.api.nvim_set_option_value("syntax", "dict", { scope = "local", buf = M.b })
        vim.keymap.set("n", "q", ":quit<CR>", { silent = true, buffer = M.b })
        vim.keymap.set("n", "<Esc>", ":quit<CR>", { silent = true, buffer = M.b })
        vim.keymap.set("n", "<Enter>", replace, { silent = false, buffer = M.b })
    end
    vim.api.nvim_buf_set_lines(M.b, 0, -1, true, outlines)

    if not wid then
        -- Center the window
        local nc = vim.o.columns
        local fcol = 2
        if nc > 82 then fcol = math.floor((nc - 80) / 2) end
        local wh = vim.api.nvim_win_get_height(0) - 2
        local fheight
        if wh > #outlines then
            fheight = #outlines
        else
            fheight = wh
        end
        local frow = math.floor((wh - fheight) / 2)

        local o = {
            relative = "win",
            width = 80,
            height = fheight,
            col = fcol,
            row = frow,
            anchor = "NW",
            style = "minimal",
            noautocmd = true,
        }
        wid = vim.api.nvim_open_win(M.b, true, o)
        vim.api.nvim_set_option_value(
            "winhl",
            "Normal:TelescopePreviewNormal",
            { win = wid }
        )
        vim.api.nvim_set_option_value("conceallevel", 3, { win = wid })
        vim.api.nvim_create_autocmd("WinClosed", { buffer = 0, callback = winclosed })
    end
    vim.api.nvim_win_set_cursor(wid, { 1, 0 })
end

return M


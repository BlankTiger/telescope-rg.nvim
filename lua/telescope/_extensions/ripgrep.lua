local Path = require("plenary.path")
local make_entry = require("telescope.make_entry")
local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local sorters = require("telescope.sorters")
local utils = require("telescope.utils")
Ripgrep_config = {
    path_display = { "absolute" },
}

local function split(txt, pattern)
    local tbl = {}
    local fpat = "(.-)" .. pattern
    local last_end = 1
    local s, e, cap = txt:find(fpat, 1)
    while s do
        if s ~= 1 or cap ~= "" then
            table.insert(tbl, cap)
        end
        last_end = e + 1
        s, e, cap = txt:find(fpat, last_end)
    end
    if last_end <= #txt then
        cap = txt:sub(last_end)
        table.insert(tbl, cap)
    end
    return tbl
end

local function get_opts(opts)
    local config = {}
    for k, v in pairs(Ripgrep_config) do
        config[k] = v
    end
    vim.tbl_extend("force", config, opts)
    return config
end

local ripgrep_text = function(opts)
    opts = get_opts(opts)
    local live_grepper = finders.new_job(function(prompt)
        if not prompt or prompt == "" then
            return nil
        end
        local rg_args = split(prompt, " ")
        return rg_args
    end, opts.entry_maker or make_entry.gen_from_vimgrep(opts))

    pickers
        .new(opts, {
            prompt_title = "Search",
            __locations_input = true,
            finder = live_grepper,
            previewer = conf.grep_previewer(opts),
            sorter = sorters.highlighter_only(opts),
            default_text = "rg --vimgrep ",
        })
        :find()
end

local ripgrep_files = function(opts)
    opts = get_opts(opts)
    local live_grepper = finders.new_job(function(prompt)
        if not prompt or prompt == "" then
            return nil
        end
        local rg_args = split(prompt, " ")
        return rg_args
    end, opts.entry_maker or make_entry.gen_from_file(opts))

    pickers
        .new(opts, {
            prompt_title = "Search files",
            __locations_input = true,
            finder = live_grepper,
            previewer = conf.file_previewer(opts),
            -- sorter = conf.file_sorter(opts),
            default_text = "rg --files -g ",
        })
        :find()
end

return require("telescope").register_extension({
    setup = function(ext_config, config)
        for k, v in pairs(ext_config) do
            Ripgrep_config[k] = v
        end
    end,
    exports = { ripgrep_text = ripgrep_text, ripgrep_files = ripgrep_files },
})

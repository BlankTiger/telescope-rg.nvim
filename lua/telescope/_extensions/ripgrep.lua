local Path = require("plenary.path")
local make_entry = require("telescope.make_entry")
local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local sorters = require("telescope.sorters")
local utils = require("telescope.utils")
Ripgrep_config = {
    default_args_text = "--vimgrep",
    default_args_files = "--files -g",
}

local function split(command)
    local cmd_split = {}
    local start = 1
    local in_quotes = false
    local curr_quotes = "\""
    for i = 1, #command do
        local c = command:sub(i, i)
        local next = ""

        if (c == "\"" or c == "'") and not in_quotes then
            in_quotes = true
            curr_quotes = c
            start = i
        elseif c == curr_quotes and in_quotes then
            in_quotes = false
            next = command:sub(start + 1, i - 1)
            start = i + 1
        end
        if in_quotes then
            goto continue
        end

        if c == " " then
            next = command:sub(start, i - 1)
            start = i + 1
        end

        if i == #command and next:len() == 0 then
            next = command:sub(start, i)
        end

        if next:len() > 0 then
            table.insert(cmd_split, next)
        end
        ::continue::
    end

    return cmd_split
end

local function get_opts(opts)
    local config = {}
    for k, v in pairs(Ripgrep_config) do
        config[k] = v
    end
    for k, v in pairs(opts) do
        config[k] = v
    end
    return config
end

local ripgrep_text = function(opts)
    opts = get_opts(opts)
    local live_grepper = finders.new_job(function(prompt)
        if not prompt or prompt == "" then
            return nil
        end
        local rg_args = split(prompt)
        return rg_args
    end, opts.entry_maker or make_entry.gen_from_vimgrep(opts))

    pickers
        .new(opts, {
            prompt_title = "Search",
            __locations_input = true,
            finder = live_grepper,
            previewer = conf.grep_previewer(opts),
            sorter = sorters.highlighter_only(opts),
            default_text = "rg " .. Ripgrep_config.default_args_text .. " ",
        })
        :find()
end

local ripgrep_files = function(opts)
    opts = get_opts(opts)
    local live_grepper = finders.new_job(function(prompt)
        if not prompt or prompt == "" then
            return nil
        end
        local rg_args = split(prompt)
        return rg_args
    end, opts.entry_maker or make_entry.gen_from_file(opts))

    pickers
        .new(opts, {
            prompt_title = "Search files",
            __locations_input = true,
            finder = live_grepper,
            previewer = conf.file_previewer(opts),
            -- sorter = conf.file_sorter(opts),
            default_text = "rg " .. Ripgrep_config.default_args_files .. " ",
        })
        :find()
end

return require("telescope").register_extension({
    setup = function(ext_config, config)
        for k, v in pairs(ext_config) do
            Ripgrep_config[k] = v
        end
        for k, v in pairs(config) do
            Ripgrep_config[k] = v
        end
    end,
    exports = { ripgrep_text = ripgrep_text, ripgrep_files = ripgrep_files },
})

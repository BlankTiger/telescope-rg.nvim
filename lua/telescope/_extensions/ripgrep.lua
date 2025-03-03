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

local function process_consecutive_search(args)
    -- Check if there are any || in the arguments
    local delimiter_indices = {}
    for i, arg in ipairs(args) do
        if arg == "||" then
            table.insert(delimiter_indices, i)
        end
    end

    if #delimiter_indices == 0 then
        return args
    end

    -- Sort the delimiter indices (just to be safe)
    table.sort(delimiter_indices)

    -- Extract all patterns
    local patterns = {}
    local first_pattern_index = delimiter_indices[1] - 1
    table.insert(patterns, args[first_pattern_index])

    for i, index in ipairs(delimiter_indices) do
        if index + 1 <= #args then
            table.insert(patterns, args[index + 1])
        end
    end

    -- Create a new set of arguments preserving everything up to the first pattern
    local new_args = {}
    for i = 1, first_pattern_index - 1 do
        table.insert(new_args, args[i])
    end

    -- Add multiline flag
    table.insert(new_args, "--multiline")

    -- Construct a regex for consecutive lines
    -- For two patterns, the regex would look like:
    -- pattern1[^\n]*\n[^\n]*pattern2
    local regex = ""
    for i, pattern in ipairs(patterns) do
        -- Escape the pattern to handle special regex characters
        local escaped_pattern = pattern:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")

        if i > 1 then
            -- Match the rest of the line after the previous pattern, then exactly one newline,
            -- then the start of the next line up to the current pattern
            regex = regex .. "[^\\n]*\\n[^\\n]*"
        end

        regex = regex .. escaped_pattern
    end

    -- Add the PCRE2 flag and the regex to the new arguments
    table.insert(new_args, "--pcre2")
    table.insert(new_args, "-e")
    table.insert(new_args, regex)

    return new_args
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

local function ripgrep_text(opts)
    opts = get_opts(opts)
    local path = ""
    if opts.curr_file_dir then
        path = vim.fn.expand("%:p:h")
        local start = "oil:///"
        if path:sub(1, #start) == start then
            path = path:sub(#start, #path)
        end
    end

    local live_grepper = finders.new_job(function(prompt)
        if not prompt or prompt == "" then
            return nil
        end

        local rg_args = split(prompt)
        rg_args = process_consecutive_search(rg_args)

        if path ~= "" then
            table.insert(rg_args, path)
        end
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

local function ripgrep_text_curr_file_dir(opts)
    opts = get_opts(opts)
    opts.curr_file_dir = true
    return ripgrep_text(opts)
end

local ripgrep_files = function(opts)
    opts = get_opts(opts)
    local live_grepper = finders.new_job(function(prompt)
        if not prompt or prompt == "" then
            return nil
        end

        local rg_args = split(prompt)
        rg_args = process_consecutive_search(rg_args)

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
    exports = {
        ripgrep_text = ripgrep_text,
        ripgrep_text_curr_file_dir = ripgrep_text_curr_file_dir,
        ripgrep_files = ripgrep_files,
    },
})

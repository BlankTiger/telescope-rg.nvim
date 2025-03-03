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

-- Helper function to calculate factorial
math.factorial = function(n)
    if n <= 1 then
        return 1
    else
        return n * math.factorial(n - 1)
    end
end

local function escape_pattern(pattern)
    -- Escape the pattern to handle special regex characters
    return pattern:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
end

-- Helper function to generate all permutations of patterns
local function generate_permutations(patterns)
    -- Base case
    if #patterns <= 1 then
        return { patterns }
    end

    local result = {}
    for i = 1, #patterns do
        -- Take the current pattern and generate permutations of the rest
        local first = patterns[i]
        local rest = {}
        for j = 1, #patterns do
            if j ~= i then
                table.insert(rest, patterns[j])
            end
        end

        -- Recursively generate permutations of the rest
        local sub_permutations = generate_permutations(rest)

        -- Add the current pattern to the front of each sub-permutation
        for _, perm in ipairs(sub_permutations) do
            local new_perm = { first }
            for _, p in ipairs(perm) do
                table.insert(new_perm, p)
            end
            table.insert(result, new_perm)
        end
    end

    return result
end

local function process_strict_consecutive(args, delimiter_indices)
    -- Sort the delimiter indices
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
    local regex = ""
    for i, pattern in ipairs(patterns) do
        local escaped_pattern = escape_pattern(pattern)

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

local function process_bidirectional_consecutive(args, delimiter_indices)
    -- Extract patterns between the || delimiters
    table.sort(delimiter_indices)

    local patterns = {}
    -- Add the first pattern (before the first delimiter)
    local first_pattern_index = delimiter_indices[1] - 1
    if first_pattern_index >= 1 then
        table.insert(patterns, args[first_pattern_index])
    end

    -- Add all patterns after each delimiter
    for i, index in ipairs(delimiter_indices) do
        if index + 1 <= #args and args[index + 1] ~= "||" then
            table.insert(patterns, args[index + 1])
        end
    end

    if #patterns < 2 then
        -- Not enough patterns to create a meaningful bidirectional search
        return args
    end

    -- Create a new set of arguments preserving everything up to the first pattern
    local new_args = {}
    for i = 1, first_pattern_index - 1 do
        table.insert(new_args, args[i])
    end

    -- Add multiline flag
    table.insert(new_args, "--multiline")

    -- Warn if there are many patterns (permutations grow factorially)
    if #patterns > 4 then
        print(
            "Warning: Using || with "
                .. #patterns
                .. " patterns will generate "
                .. math.factorial(#patterns)
                .. " permutations. This may impact performance."
        )
    end

    -- Generate all permutations of the patterns
    local permutations = generate_permutations(patterns)

    -- Construct a regex for each permutation and join with OR
    local regex_parts = {}
    for _, permutation in ipairs(permutations) do
        local regex_part = ""
        for i, pattern in ipairs(permutation) do
            local escaped_pattern = escape_pattern(pattern)

            if i > 1 then
                -- Match the rest of the line after the previous pattern, then exactly one newline,
                -- then the start of the next line up to the current pattern
                regex_part = regex_part .. "[^\\n]*\\n[^\\n]*"
            end

            regex_part = regex_part .. escaped_pattern
        end

        table.insert(regex_parts, regex_part)
    end

    -- Join all permutations with OR operator
    local regex = "(" .. table.concat(regex_parts, "|") .. ")"

    -- Add the PCRE2 flag and the regex to the new arguments
    table.insert(new_args, "--pcre2")
    table.insert(new_args, "-e")
    table.insert(new_args, regex)

    return new_args
end

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
    -- Check if there are any >> or || in the arguments
    local strict_delimiter_indices = {}
    local bidirectional_delimiter_indices = {}

    for i, arg in ipairs(args) do
        if arg == ">>" then
            table.insert(strict_delimiter_indices, i)
        elseif arg == "||" then
            table.insert(bidirectional_delimiter_indices, i)
        end
    end

    -- If no delimiters, return original args
    if #strict_delimiter_indices == 0 and #bidirectional_delimiter_indices == 0 then
        return args
    end

    -- We'll process one type of delimiter at a time
    -- Prioritize strict (>>) if both are present
    if #strict_delimiter_indices > 0 then
        return process_strict_consecutive(args, strict_delimiter_indices)
    else
        return process_bidirectional_consecutive(args, bidirectional_delimiter_indices)
    end
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

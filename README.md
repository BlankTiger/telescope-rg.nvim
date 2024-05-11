# <p align="center">telescope-rg.nvim</p>

[Telescope](https://github.com/nvim-telescope/telescope.nvim) extension gives user the ability to pick and choose [ripgrep](https://github.com/BurntSushi/ripgrep) options on the fly.


https://github.com/BlankTiger/telescope-rg.nvim/assets/16402420/8d72ffa5-e695-43b4-9a58-e75978cda2dd


# Requirements

- [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim)
- [ripgrep](https://github.com/BurntSushi/ripgrep)

# Installation

With [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
    "blanktiger/telescope-rg.nvim",
    dependencies = {
        "nvim-telescope/telescope.nvim",
        config = function()
            require("telescope").load_extension("ripgrep")
        end,
    },
    opts = { 
        -- your config goes here
    }
}
```

# Available pickers

You can configure two pickers that specialize in two different things:

```lua
-- FILE SEARCHER
vim.api.nvim_set_keymap("n", "<leader>sf", function()
    require("telescope").extensions.ripgrep.ripgrep_files({})
end, {})

-- TEXT SEARCHER
vim.api.nvim_set_keymap("n", "<leader>st", function()
    require("telescope").extensions.ripgrep.ripgrep_text({})
end, {})
```

return {
  {
    "folke/snacks.nvim",
    ---@type snacks.Config
    opts = {
      picker = {
        sources = {
          explorer = {
            auto_close = true,
            hidden = true,
            ignored = true,
            layout = {
              preset = "vertical",
            },
          },
        },
      },
    },
  },
}

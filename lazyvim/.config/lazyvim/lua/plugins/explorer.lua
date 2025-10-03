return {
  {
    "folke/snacks.nvim",
    ---@type snacks.Config
    opts = {
      picker = {
        sources = {
          explorer = {
            auto_close = true,
            layout = {
              preset = "vertical",
            },
          },
        },
      },
    },
  },
}

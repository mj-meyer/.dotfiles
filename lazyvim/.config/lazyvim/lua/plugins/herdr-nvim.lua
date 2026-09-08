return {
  -- Sidekick's CLI picker is not used here; free its default mapping for
  -- herdr-nvim's comment-to-agent action.
  {
    "folke/sidekick.nvim",
    keys = {
      { "<leader>as", false },
    },
  },
  {
    "ChmaraX/herdr-nvim",
    opts = {},
  },
}

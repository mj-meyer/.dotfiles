return {
  {
    "hrsh7th/nvim-cmp",
    dependencies = {
      { "kirasok/cmp-hledger", config = true },
    },
    opts = function(_, opts)
      table.insert(opts.sources, { name = "hledger" })
    end,
  },
}

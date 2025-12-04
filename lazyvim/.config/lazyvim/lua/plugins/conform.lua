return {
  {
    "stevearc/conform.nvim",
    opts = {
      formatters_by_ft = {
        javascript = { "dprint", "prettier" },
        javascriptreact = { "dprint", "prettier" },
        typescript = { "dprint", "prettier" },
        typescriptreact = { "dprint", "prettier" },
        json = { "dprint", "prettier" },
        jsonc = { "dprint", "prettier" },
        markdown = { "dprint", "prettier" },
        css = { "dprint", "prettier" },
        scss = { "dprint", "prettier" },
        html = { "prettier" },
        yaml = { "prettier" },
        -- Add any other file types you want to format
      },
      formatters = {
        dprint = {
          condition = function(ctx)
            return vim.fs.find({ "dprint.json" }, { path = ctx.filename, upward = true })[1]
          end,
        },
        prettier = {
          condition = function(ctx)
            return not vim.fs.find({ "dprint.json" }, { path = ctx.filename, upward = true })[1]
          end,
        },
      },
    },
  },
}

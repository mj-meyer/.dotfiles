return {
  {
    "ThePrimeagen/git-worktree.nvim",
    dependencies = { "nvim-telescope/telescope.nvim" },
    config = function()
      local Worktree = require("git-worktree")

      Worktree.setup({
        change_directory_command = "cd",
        update_on_change = false,
        clearjumps_on_change = true,
        autopush = false,
      })

      Worktree.on_tree_change(function(op, metadata)
        if op == Worktree.Operations.Create then
          -- Get absolute path (metadata.path may be relative)
          local worktree_path = vim.fn.fnamemodify(metadata.path, ":p"):gsub("/$", "")
          local session_name = vim.fn.fnamemodify(worktree_path, ":t")

          -- Add to zoxide
          vim.fn.system({ "zoxide", "add", worktree_path })

          -- Run project-specific setup script if exists
          local script = worktree_path .. "/.worktree-setup.sh"
          if vim.fn.filereadable(script) == 1 then
            vim.fn.jobstart({ "sh", script }, { cwd = worktree_path })
          end

          -- Create tmux session and switch to it
          vim.defer_fn(function()
            vim.fn.system(string.format([[tmux new-session -d -s "%s"]], session_name))
            vim.fn.system(string.format(
              [[tmux send-keys -t "%s" "cd '%s' && NVIM_APPNAME=LazyVim nvim" Enter]],
              session_name,
              worktree_path
            ))
            vim.fn.system(string.format([[tmux switch-client -t "%s"]], session_name))
          end, 1500)
        end
      end)

      require("telescope").load_extension("git_worktree")
    end,
    keys = {
      {
        "<leader>gww",
        function()
          require("telescope").extensions.git_worktree.git_worktrees()
        end,
        desc = "Switch Worktree",
      },
      {
        "<leader>gwc",
        function()
          require("telescope").extensions.git_worktree.create_git_worktree()
        end,
        desc = "Create Worktree",
      },
      {
        "<leader>gwp",
        function()
          local pickers = require("telescope.pickers")
          local finders = require("telescope.finders")
          local conf = require("telescope.config").values
          local actions = require("telescope.actions")
          local action_state = require("telescope.actions.state")

          -- Get repo from git remote (works from any worktree)
          local remote_url = vim.fn.system("git remote get-url origin 2>/dev/null"):gsub("%s+$", "")
          if remote_url == "" then
            vim.notify("Not in a git repo or no origin remote", vim.log.levels.ERROR)
            return
          end

          -- Extract owner/repo from remote URL
          local repo = remote_url:match("github%.com[:/](.+)%.git$") or remote_url:match("github%.com[:/](.+)$")
          if not repo then
            vim.notify("Could not parse GitHub repo from remote: " .. remote_url, vim.log.levels.ERROR)
            return
          end

          -- Fetch open PRs using gh cli with explicit repo
          local cmd = string.format(
            'gh pr list -R "%s" --json number,title,headRefName,author --jq \'.[] | "\\(.number)\\t\\(.headRefName)\\t\\(.author.login)\\t\\(.title)"\'',
            repo
          )
          local handle = io.popen(cmd)
          if not handle then
            vim.notify("Failed to run gh cli", vim.log.levels.ERROR)
            return
          end

          local result = handle:read("*a")
          handle:close()

          local prs = {}
          for line in result:gmatch("[^\n]+") do
            local number, branch, author, title = line:match("([^\t]+)\t([^\t]+)\t([^\t]+)\t(.+)")
            if number then
              table.insert(prs, {
                number = number,
                branch = branch,
                author = author,
                title = title,
                display = string.format("#%s [%s] %s - %s", number, author, branch, title),
              })
            end
          end

          if #prs == 0 then
            vim.notify("No open PRs found", vim.log.levels.WARN)
            return
          end

          pickers.new({}, {
            prompt_title = "Open PRs → Create Worktree",
            finder = finders.new_table({
              results = prs,
              entry_maker = function(entry)
                return {
                  value = entry,
                  display = entry.display,
                  ordinal = entry.display,
                }
              end,
            }),
            sorter = conf.generic_sorter({}),
            attach_mappings = function(prompt_bufnr, map)
              actions.select_default:replace(function()
                actions.close(prompt_bufnr)
                local selection = action_state.get_selected_entry()
                if selection then
                  local pr = selection.value

                  -- Get repo root (parent of .bare/.git where worktrees should live)
                  local git_common = vim.fn.system("git rev-parse --git-common-dir 2>/dev/null"):gsub("%s+$", "")
                  -- Make absolute (git-common-dir can return relative path)
                  local git_common_abs = vim.fn.fnamemodify(git_common, ":p"):gsub("/$", "")
                  local repo_root = vim.fn.fnamemodify(git_common_abs, ":h")

                  -- Create worktree path as sibling to other worktrees
                  local worktree_path = repo_root .. "/" .. pr.branch
                  require("git-worktree").create_worktree(worktree_path, pr.branch, "origin")
                end
              end)
              return true
            end,
          }):find()
        end,
        desc = "Worktree from PR",
      },
    },
  },
}

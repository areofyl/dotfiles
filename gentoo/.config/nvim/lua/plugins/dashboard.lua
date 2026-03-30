return {
  {
    "goolord/alpha-nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      local alpha = require("alpha")

      local macaroni_dir = vim.fn.expand("~/.emacs.d/macaroni")
      local num_frames = 13
      local frame_idx = 0
      local timer = nil
      local alpha_buf = nil

      -- Preload all frames
      local frames = {}
      for i = 0, num_frames - 1 do
        local path = string.format("%s/%03d.txt", macaroni_dir, i)
        local f = io.open(path, "r")
        if f then
          local lines = {}
          for line in f:lines() do
            table.insert(lines, line)
          end
          f:close()
          frames[i] = lines
        else
          frames[i] = {}
        end
      end

      -- Build centered frame lines for direct buffer write
      local function render_frame(idx)
        local art = frames[idx] or {}
        local width = vim.o.columns
        local height = vim.o.lines
        local content_height = #art + 3
        local top_pad = math.max(0, math.floor((height - content_height) / 2))
        local title = "aarav | neovim"

        local lines = {}
        for _ = 1, top_pad do
          table.insert(lines, "")
        end
        for _, line in ipairs(art) do
          local pad = math.max(0, math.floor((width - #line) / 2))
          table.insert(lines, string.rep(" ", pad) .. line)
        end
        table.insert(lines, "")
        local title_pad = math.max(0, math.floor((width - #title) / 2))
        table.insert(lines, string.rep(" ", title_pad) .. title)
        return lines
      end

      -- Initial static layout for alpha setup
      local dashboard = {
        layout = {
          { type = "padding", val = function()
            local frame = frames[0] or {}
            return math.max(0, math.floor((vim.o.lines - #frame - 3) / 2))
          end },
          {
            type = "text",
            val = function()
              local lines = {}
              for _, line in ipairs(frames[0] or {}) do
                table.insert(lines, line)
              end
              table.insert(lines, "")
              table.insert(lines, "aarav | neovim")
              return lines
            end,
            opts = { position = "center", hl = "GruvboxYellow" },
          },
        },
        opts = { margin = 0, noautocmd = false },
      }

      alpha.setup(dashboard)

      -- Highlight namespace for the macaroni coloring
      local ns = vim.api.nvim_create_namespace("macaroni")

      local function write_frame_to_buf()
        if not alpha_buf or not vim.api.nvim_buf_is_valid(alpha_buf) then
          stop_animation()
          return
        end
        local wins = vim.fn.win_findbuf(alpha_buf)
        if #wins == 0 then
          stop_animation()
          return
        end

        local lines = render_frame(frame_idx)
        vim.api.nvim_set_option_value("modifiable", true, { buf = alpha_buf })
        vim.api.nvim_buf_set_lines(alpha_buf, 0, -1, false, lines)
        vim.api.nvim_set_option_value("modifiable", false, { buf = alpha_buf })

        -- Apply highlight to all non-empty content
        vim.api.nvim_buf_clear_namespace(alpha_buf, ns, 0, -1)
        for i, line in ipairs(lines) do
          if #line > 0 then
            vim.api.nvim_buf_add_highlight(alpha_buf, ns, "GruvboxYellow", i - 1, 0, -1)
          end
        end
      end

      local function stop_animation()
        if timer then
          timer:stop()
          timer:close()
          timer = nil
        end
      end

      local function start_animation(buf)
        stop_animation()
        alpha_buf = buf
        timer = vim.uv.new_timer()
        timer:start(1000, 150, vim.schedule_wrap(function()
          if not alpha_buf or not vim.api.nvim_buf_is_valid(alpha_buf) then
            stop_animation()
            return
          end
          local wins = vim.fn.win_findbuf(alpha_buf)
          if #wins == 0 then
            stop_animation()
            return
          end
          frame_idx = (frame_idx + 1) % num_frames
          write_frame_to_buf()
        end))
      end

      vim.api.nvim_create_autocmd("User", {
        pattern = "AlphaReady",
        callback = function()
          -- Find the alpha buffer
          for _, buf in ipairs(vim.api.nvim_list_bufs()) do
            if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].filetype == "alpha" then
              start_animation(buf)
              return
            end
          end
        end,
      })

      vim.api.nvim_create_autocmd("BufUnload", {
        callback = function(ev)
          if vim.api.nvim_buf_is_valid(ev.buf) and vim.bo[ev.buf].filetype == "alpha" then
            stop_animation()
          end
        end,
      })
    end,
  },
}

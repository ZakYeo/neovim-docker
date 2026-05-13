# neovim-docker

[![CI](https://github.com/ZakYeo/neovim-docker/actions/workflows/ci.yml/badge.svg)](https://github.com/ZakYeo/neovim-docker/actions/workflows/ci.yml)
[![Live Docker Smoke](https://github.com/ZakYeo/neovim-docker/actions/workflows/live-docker.yml/badge.svg)](https://github.com/ZakYeo/neovim-docker/actions/workflows/live-docker.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

A Lua Neovim plugin for managing Docker from native buffers, with LazyVim-friendly defaults.

The default UI uses listed Neovim scratch buffers with unique meaningful `docker://` names, so Docker pages can appear in the user's preferred tab, bufferline, barbar, snacks, lualine, or other buffer UI. Telescope pickers and a floating dashboard are optional entrypoints.

## Features

- View containers, images, volumes, networks, Compose projects/services, and registry workflows.
- Tail live container logs with `docker logs --follow`.
- Start, stop, restart, inspect, remove, and exec into containers.
- Inspect/remove images, pull/push/tag registry images.
- Inspect/remove/prune volumes.
- Inspect/remove networks.
- Run core Compose actions through `docker compose`.
- Discover Compose files and existing Compose projects from Docker labels.
- Search/pull/tag/push images, show image history/layers, prune dangling images, and inspect registry status without storing credentials.
- Async/nonblocking Docker pages with loading state, cancellation, optional background refresh, filtering, sorting, action menu, help overlay, and status highlighting.
- Configurable default keymaps and custom UI open hook.

## Screenshots
<img width="1331" height="382" alt="image" src="https://github.com/user-attachments/assets/645500ff-4d11-4f55-aeed-7d4b1e8919d8" />
<br/>
<img width="2192" height="481" alt="image" src="https://github.com/user-attachments/assets/1dd06437-010f-409c-9fce-2053c7065255" />



## Requirements

- Neovim 0.8 or newer.
- Docker CLI available as `docker`.
- Docker Compose via `docker compose` for Compose pages.

## LazyVim / lazy.nvim

```lua
return {
  {
    "ZakYeo/neovim-docker",
    cmd = {
      "DockerDashboard",
      "DockerContainers",
      "DockerImages",
      "DockerVolumes",
      "DockerNetworks",
      "DockerCompose",
      "DockerComposeCwd",
      "DockerComposeProjects",
      "DockerComposeFiles",
      "DockerComposeContainers",
      "DockerRegistries",
      "DockerRegistryStatus",
      "DockerLogs",
      "DockerExec",
      "DockerPull",
      "DockerPush",
      "DockerTag",
      "DockerSearch",
      "DockerImageHistory",
      "DockerImagePrune",
      "DockerAction",
      "DockerTelescopeContainers",
      "DockerTelescopeImages",
      "DockerTelescopeVolumes",
    },
    keys = {
      { "<leader>Dd", "<cmd>DockerDashboard<cr>", desc = "Docker dashboard" },
      { "<leader>Dc", "<cmd>DockerContainers<cr>", desc = "Docker containers" },
      { "<leader>Di", "<cmd>DockerImages<cr>", desc = "Docker images" },
      { "<leader>Dv", "<cmd>DockerVolumes<cr>", desc = "Docker volumes" },
      { "<leader>Dn", "<cmd>DockerNetworks<cr>", desc = "Docker networks" },
      { "<leader>Dp", "<cmd>DockerCompose<cr>", desc = "Docker compose" },
      { "<leader>Dr", "<cmd>DockerRegistries<cr>", desc = "Docker registries" },
    },
    opts = {
      ui = {
        open_strategy = "current",
      },
    },
  },
}
```

### LazyVim which-key group

LazyVim users can add a which-key group with the current `opts.spec` pattern:

```lua
return {
  {
    "folke/which-key.nvim",
    opts = {
      spec = {
        { "<leader>D", group = "docker" },
      },
    },
  },
}
```

Docker page action menus use `vim.ui.select` by default, even when `which-key.nvim` is installed. To opt into buffer-local which-key action shortcuts, enable the integration in `neovim-docker` and let which-key trigger on the action-menu prefix. The plugin registers the Docker action mappings with `require("which-key").add`; it does not call `which-key.show` from a keymap.

```lua
return {
  {
    "zakye/neovim-docker",
    opts = {
      integrations = {
        which_key = {
          action_menu = true,
        },
      },
    },
  },
  {
    "folke/which-key.nvim",
    opts = {
      triggers = {
        { "<auto>", mode = "nixsotc" },
        { "a", mode = "n" }, -- match neovim-docker's default buffer action_menu key
      },
      spec = {
        { "<leader>D", group = "docker" },
      },
    },
  },
}
```

If you configure which-key outside plugin specs, use `add` for static Docker groups:

```lua
require("which-key").add({
  { "<leader>D", group = "docker" },
})
```

### Optional Telescope keys

Telescope is optional. If it is installed, these commands open picker-based entrypoints:

```lua
keys = {
  { "<leader>Dt", "<cmd>DockerTelescopeContainers<cr>", desc = "Docker containers picker" },
  { "<leader>DT", "<cmd>DockerTelescopeImages<cr>", desc = "Docker images picker" },
}
```

## Configuration

```lua
require("neovim-docker").setup({
  docker_cmd = "docker",
  compose_cmd = { "docker", "compose" },
  log_tail = 200, -- initial docker logs --tail value
  log_max_lines = 5000, -- retained live log lines; invalid values fall back to 5000
  exec_shell = "/bin/sh",
  timeout = 30000,
  refresh_interval = 0, -- set > 0 milliseconds for background refresh
  highlights = {
    logs = {
      error = "DiagnosticError",
      warn = "DiagnosticWarn",
      info = "DiagnosticInfo",
      debug = "Comment",
      trace = "Comment",
      success = "DiagnosticOk",
      npm_notice = "Special",
      timestamp = "Comment",
      source = "Identifier",
      http_2xx = "DiagnosticOk",
      http_3xx = "DiagnosticInfo",
      http_4xx = "DiagnosticWarn",
      http_5xx = "DiagnosticError",
    },
  },
  ui = {
    open_strategy = "current", -- current, split, vsplit, tab, float
    open = nil, -- custom function(page) for buffer/tab plugins
    float = {
      width = 0.8,
      height = 0.8,
      border = "rounded",
    },
  },
  integrations = {
    telescope = {
      enabled = "auto",
    },
    which_key = {
      enabled = "auto", -- auto, true, or false
      action_menu = false, -- opt into registering which-key page action shortcuts
    },
  },
  keymaps = {
    enabled = true,
  },
})
```

Docker pages are created as listed `nofile` buffers by default. Bufferline/tabline plugins that show listed buffers should pick them up with names like `docker://containers/docker-containers-12`; plugins configured to hide `nofile` buffers or custom URI schemes may need their filters adjusted in the parent app config.

Live log buffers consume ANSI color codes from container output and render those colors without showing raw escape characters. Lines without ANSI colors fall back to semantic highlighting for severity words, `npm notice` output, timestamps, Compose/service prefixes, success states, and standalone 2xx-5xx HTTP-style status numbers. Override `highlights.logs` to map semantic categories to your preferred colorscheme groups.

To route Docker pages into a favorite UI plugin, provide `ui.open`:

```lua
require("neovim-docker").setup({
  ui = {
    open = function(page)
      vim.api.nvim_set_current_buf(page.buf)
      -- Add bufferline/snacks/barbar-specific pinning or naming here.
    end,
  },
})
```

Custom `ui.open` hooks should display `page.buf` synchronously so Docker navigation can track the shown window. Return `false` when the hook intentionally declines to open the buffer; that page will not be added to navigation history.

Docker action menus use `vim.ui.select` by default. Set `integrations.which_key.action_menu = true` to register buffer-local which-key action shortcuts for Docker pages; configure which-key `opts.triggers` for the action-menu prefix if you want which-key to display those shortcuts.

## Commands

- `:DockerDashboard` opens the native dashboard.
- `:DockerDashboard!` opens the dashboard in a float.
- `:DockerContainers`, `:DockerImages`, `:DockerVolumes`, `:DockerNetworks`.
- `:DockerCompose` lists Compose services for the current working directory.
- `:DockerComposeCwd [dir]` lists Compose services from a chosen working directory.
- `:DockerComposeProjects` lists existing Compose projects discovered from Docker labels.
- `:DockerComposeFiles [dir]` discovers Compose files in a directory.
- `:DockerComposeContainers <project>` lists containers for a Compose project.
- `:DockerContainers` groups containers by Compose project when Docker Compose labels are present. Press `<CR>` on a project row to expand/collapse its containers; use `s`/`S`/`R`/`d` or the action menu on that row to start, stop, restart, up, or down the Compose project. The container action menu also includes `volumes` for jumping to `:DockerVolumes`. Press `<CR>` on a container row to inspect it.
- `:DockerRegistries` opens registry command guidance.
- `:DockerRegistryStatus` shows registry config status from Docker CLI state.
- `:DockerLogs <container>` tails live logs.
- `:DockerExec <container> [shell]` opens an interactive shell in a container.
- `:DockerPull <image>`, `:DockerPush <image>`, `:DockerTag <source> <target>`.
- `:DockerSearch <query>` searches Docker Hub.
- `:DockerImageHistory <image>` shows image history/layers.
- `:DockerImagePrune` prunes dangling images.
- `:DockerAction <action> <target>` runs an internal action directly.
- `:DockerTelescopeContainers`, `:DockerTelescopeImages`, and `:DockerTelescopeVolumes` use Telescope when installed.

## Native Buffer Keys

- `r`: refresh page.
- `i`: inspect selected item.
- `<CR>`: inspect/open the selected item, or expand/collapse a Compose project row in the container page.
- `/`: filter rows.
- `x`: clear filter.
- `o`: cycle sort column.
- `a`: open action menu.
- `?`: open help overlay.
- `<C-o>` / `<C-i>`: move backward/forward through Docker pages, details, help, and logs where the target buffer is still open.
- `b`: go back from the help overlay.
- `l`: tail selected container logs.
- `e`: exec shell into selected container.
- `s`: start selected item where supported, including Compose project rows in `:DockerContainers`.
- `S`: stop selected item where supported, including Compose project rows in `:DockerContainers`.
- `R`: restart selected item where supported, including Compose project rows in `:DockerContainers`.
- `d`: remove/delete/down selected item where supported, including Compose project rows in `:DockerContainers`.
- `p`: prune where supported.
- `q`: close page.

## Development

See [CONTRIBUTING.md](CONTRIBUTING.md) for the full local workflow.

Run tests with:

```sh
nvim --headless -u NONE --cmd 'set shadafile=NONE' -c 'set rtp+=.' -c 'luafile tests/run.lua' -c 'qa'
```

The tests mock Docker command execution, so they do not require a running Docker daemon.

With Docker Engine running, run a live smoke test with:

```sh
nvim --headless -u NONE --cmd 'set shadafile=NONE' -c 'set rtp+=.' -c 'luafile tests/live_smoke.lua' -c 'qa'
```

## License

MIT

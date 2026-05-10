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
  },
  keymaps = {
    enabled = true,
  },
})
```

Docker pages are created as listed `nofile` buffers by default. Bufferline/tabline plugins that show listed buffers should pick them up with names like `docker://containers/docker-containers-12`; plugins configured to hide `nofile` buffers or custom URI schemes may need their filters adjusted in the parent app config.

Live log buffers consume ANSI color codes from container output and render those colors without showing raw escape characters. Lines without ANSI colors fall back to semantic highlighting for severity words, timestamps, Compose/service prefixes, success states, and standalone 2xx-5xx HTTP-style status numbers. Override `highlights.logs` to map semantic categories to your preferred colorscheme groups.

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

## Commands

- `:DockerDashboard` opens the native dashboard.
- `:DockerDashboard!` opens the dashboard in a float.
- `:DockerContainers`, `:DockerImages`, `:DockerVolumes`, `:DockerNetworks`.
- `:DockerCompose` lists Compose services for the current working directory.
- `:DockerComposeCwd [dir]` lists Compose services from a chosen working directory.
- `:DockerComposeProjects` lists existing Compose projects discovered from Docker labels.
- `:DockerComposeFiles [dir]` discovers Compose files in a directory.
- `:DockerComposeContainers <project>` lists containers for a Compose project.
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
- `/`: filter rows.
- `x`: clear filter.
- `o`: cycle sort column.
- `a`: open action menu.
- `?`: open help overlay.
- `<C-o>` / `<C-i>`: move backward/forward through Docker pages, details, help, and logs where the target buffer is still open.
- `b`: go back from the help overlay.
- `l`: tail selected container logs.
- `e`: exec shell into selected container.
- `s`: start selected item where supported.
- `S`: stop selected item where supported.
- `R`: restart selected item where supported.
- `d`: remove/down selected item where supported.
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

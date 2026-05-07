# Contributing

Thanks for helping improve `neovim-docker`.

## Requirements

- Neovim 0.8 or newer
- Lua 5.1 `luac`
- Docker CLI for live smoke testing
- Optional: StyLua and Selene for local style checks

## Local Checks

Run the mocked test suite:

```sh
nvim --headless -u NONE --cmd 'set shadafile=NONE' -c 'set rtp+=.' -c 'luafile tests/run.lua' -c 'qa'
```

Run syntax and help checks:

```sh
luac -p lua/neovim-docker/*.lua plugin/neovim-docker.lua tests/*.lua
nvim --headless -u NONE --cmd 'set shadafile=NONE' -c 'helptags doc' -c 'qa'
```

Run style checks when tools are installed:

```sh
stylua --check lua plugin tests
selene lua plugin tests
```

Run the live Docker smoke test only when Docker Engine is available:

```sh
nvim --headless -u NONE --cmd 'set shadafile=NONE' -c 'set rtp+=.' -c 'luafile tests/live_smoke.lua' -c 'qa'
```

## Pull Requests

- Keep changes focused.
- Add or update tests for behavior changes.
- Update `README.md` and `doc/neovim-docker.txt` for user-facing commands, config, or keymaps.
- Regenerate help tags with `:helptags doc` when help docs change.


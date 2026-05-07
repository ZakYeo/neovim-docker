## Summary

-

## Verification

- [ ] `nvim --headless -u NONE --cmd 'set shadafile=NONE' -c 'set rtp+=.' -c 'luafile tests/run.lua' -c 'qa'`
- [ ] `luac -p lua/neovim-docker/*.lua plugin/neovim-docker.lua tests/*.lua`
- [ ] `nvim --headless -u NONE --cmd 'set shadafile=NONE' -c 'helptags doc' -c 'qa'`
- [ ] `stylua --check lua plugin tests`
- [ ] `selene lua plugin tests`
- [ ] Live Docker smoke, if Docker behavior changed

## Notes

-

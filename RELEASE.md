# Release Checklist

Use this checklist for a `v0.1.0` release.

1. Ensure the working tree is clean.
2. Run mocked tests:
   ```sh
   nvim --headless -u NONE --cmd 'set shadafile=NONE' -c 'set rtp+=.' -c 'luafile tests/run.lua' -c 'qa'
   ```
3. Run syntax and help checks:
   ```sh
   luac -p lua/neovim-docker/*.lua plugin/neovim-docker.lua tests/*.lua
   nvim --headless -u NONE --cmd 'set shadafile=NONE' -c 'helptags doc' -c 'qa'
   ```
4. Run style checks:
   ```sh
   stylua --check lua plugin tests
   selene lua plugin tests
   ```
5. Run the live Docker smoke test when Docker Engine is available:
   ```sh
   nvim --headless -u NONE --cmd 'set shadafile=NONE' -c 'set rtp+=.' -c 'luafile tests/live_smoke.lua' -c 'qa'
   ```
6. Confirm GitHub Actions CI is green.
7. Confirm `CHANGELOG.md` has the release date.
8. Create and push the tag:
   ```sh
   git tag -a v0.1.0 -m "v0.1.0"
   git push origin v0.1.0
   ```
9. Create a GitHub release from the tag and include changelog notes.

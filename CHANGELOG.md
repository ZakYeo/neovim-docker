# Changelog

All notable changes to this project will be documented in this file.

This project follows semantic versioning.

## [0.1.1] - 2026-05-10

### Fixed

- Fixed repeated Docker page opens failing with duplicate `docker://` buffer names.
- Added Docker-local back/forward navigation and an explicit help-page back action.
- Made Docker buffers listed by default so buffer/tabline plugins can display them.
- Bounded retained live log output while preserving `docker logs --follow`.
- Added native container-page log access through the visible `l logs` key hint.

## [0.1.0] - 2026-05-07

### Added

- Native-buffer Docker pages for containers, images, volumes, networks, Compose, registries, logs, and dashboards.
- Async Docker CLI backend with loading states, cancellation, timeout handling, and optional background refresh.
- Sortable and filterable Docker tables with status highlighting, help overlay, and action menus.
- Docker Compose project discovery, Compose file discovery, service/container pages, and service actions.
- Image and registry workflows for search, pull, tag, push, image history, image prune, and registry status.
- LazyVim/lazy.nvim examples, optional Telescope commands, health checks, Vim help docs, and tests.

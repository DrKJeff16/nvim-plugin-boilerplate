# nvim-plugin-boilerplate

> [!IMPORTANT]
> **This was NOT AI-generated!**

An annotated Neovim Lua plugin template with `pre-commit`, StyLua and `selene` configs,
with some useful GitHub actions included.

Not to be confused with [`ellisonleao/nvim-plugin-template`](https://github.com/ellisonleao/nvim-plugin-template)!

---

## Features

- A dynamic install script [`generate.sh`](./generate.sh) (see [Setup](#setup))
- Plenty of utilities you can use with your plugin ([`util.lua`](./lua/my-plugin/util.lua))
- Pre-documented Lua code
- Optional template file for `:checkhealth` ([`health.lua`](./lua/my-plugin/health.lua))
- CI utilities supported:
  - `pre-commit` config ([`.pre-commit-config.yaml`](./.pre-commit-config.yaml))
  - StyLua config ([`stylua.toml`](./stylua.toml))
  - `selene` config ([`selene.toml`](./selene.toml), [`vim.yml`](./vim.yml))
  - A bunch of useful GitHub Actions (see [`.github/workflows`](./.github/workflows))

---

## Setup

> [!NOTE]
> The script is subject to breaking changes in the future.
> Therefore please review the instructions below.

To configure the template simply run `generate.sh` in your terminal:

```bash
./generate.sh # Has to be run in the repository root!
```

It'll invoke many prompts so that you may structure your plugin as desired.

**The script will delete itself after a successful setup!**

---

## Structure

```
/lua
├── my-plugin.lua  <==  The main module
├── my-plugin/  <==  Folder containing all the plugin utils
│   ├── config.lua  <==  Configuration module. Contains your main `setup()` function
│   ├── health.lua  <==  Hooks for `:checkhealth` (OPTIONAL)
└   └── util.lua  <==  Utilities for the plugin
```

---

## License

[MIT](./LICENSE)

<!-- vim: set ts=2 sts=2 sw=2 et ai si sta: -->

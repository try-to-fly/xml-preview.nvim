# XML Preview

A Neovim plugin that provides a live JSON preview for XML files.
![xml-preview](https://github.com/user-attachments/assets/6c6af5df-ec61-4216-888d-622ab4751a61)

## Features

- Real-time conversion of XML to JSON
- Side-by-side preview of XML and JSON
- Automatic updates on file changes
- Syntax highlighting and folding for JSON preview

## Requirements

- [xml2lua](https://github.com/manoelcampos/xml2lua) Lua module
- `jq` command-line JSON processor

## Installation

Using [LazyVim](https://github.com/LazyVim/LazyVim):

```lua
{
  {
    "vhyrro/luarocks.nvim",
    enabled = true,
    priority = 1001,
    config = true,
    opts = {
      rocks = { "xml2lua" },
    },
  },
  {
    "try-to-fly/xml-preview.nvim",
    config = function()
      require("xml_preview").setup()
    end,
  },
}
```

## Usage

1. Open an XML file in Neovim.
2. The JSON preview will automatically appear in a split window.
3. The preview updates when you save the XML file or switch between buffers.

## License

MIT

vim-grammarous
==============

vim-grammarous is a powerful grammar checker for Vim.  Simply do `:GrammarousCheck` to see the powerful checking.  This plugin automatically downloads [LanguageTool](https://www.languagetool.org/), which requires Java 7+.

![screenshot](http://gifzo.net/FNmJMaFgjY.gif)


## Commands

- `:GrammarousCheck [--lang={lang}] [--(no-)preview]` : Execute the grammar checker for current buffer.
    1. It makes LanguageTool check grammar (It takes a while)
    2. It highlights the locations of detected grammar errors
    3. When you move the cursor on a location of error, it automatically shows the error with the information window.

- `:GrammarousReset` : Reset the current check.

## Mappings

### Mapping in the information window

You can use some mappings in the information window, which is opened to show the detail of an error when the cursor move on an error.

| Mappings | Description                              |
| -------- |:---------------------------------------- |
|   `q`    | Quit the info window                     |
|  `<CR>`  | Move to the location of the error        |
|   `f`    | Fix the error __automatically__          |
|   `r`    | Remove the error from the checked buffer |
|   `?`    | Show help of the mapping in info window  |

### `<Plug>` mappings to execute anywhere

| Mappings                                 | Description                                          |
| -----------------------------------------|:---------------------------------------------------- |
| `<Plug>(grammarous-move-to-info-window)` | Move the cursor to the info window                   |
| `<Plug>(grammarous-open-info-window)`    | Open the info window for under the cursor            |
| `<Plug>(grammarous-reset)`               | Reset the current check                              |
| `<Plug>(grammarous-fixit)`               | Fix the error under the cursor automatically         |
| `<Plug>(grammarous-fixall)`              | Fix all the errors in a current buffer automatically |
| `<Plug>(grammarous-close-info-window)`   | Close the information window from checked buffer     |
| `<Plug>(grammarous-remove-error)`        | Remove the error under the cursor                    |
## Fix examples

- [vim-themis](https://github.com/rhysd/vim-themis/commit/b2f838b29f47180ccee50488e01d6774a21d0c03)
- [unite.vim](https://github.com/rhysd/unite.vim/commit/5716eac38781e7a233c98f2a3d7aee8909326791)
- [vim-quickrun](https://github.com/rhysd/vim-quickrun/commit/236c753e0572266670d176e667054d55ad52a3f3)

## Automatic installation

This plugin attempts to install [LanguageTool](https://www.languagetool.org/) using `curl` or `wget` command at first time.  If it fails, you should install it manually.  Please download zip file of LanguageTool and extract it to `path/to/vim-grammarous/misc`.

## Requirements

- Java7 (jdk-1.7, jre-1.7, ...)
- [vimproc.vim](https://github.com/Shougo/vimproc.vim) (It will be optional)

## Contribution

If you find some bugs, please report it to [issues page](https://github.com/rhysd/vim-grammarous/issues).  Pull requests are welcome. None of them is too short.

## License

    Copyright (c) 2014 rhysd

    Permission is hereby granted, free of charge, to any person obtaining a copy
    of this software and associated documentation files (the "Software"), to deal
    in the Software without restriction, including without limitation the rights
    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
    of the Software, and to permit persons to whom the Software is furnished to do so,
    subject to the following conditions:

    The above copyright notice and this permission notice shall be included in all
    copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
    INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
    PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
    LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
    TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR
    THE USE OR OTHER DEALINGS IN THE SOFTWARE.


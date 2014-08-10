vim-grammarous
==============

vim-grammarous is a powerful grammar checker in Vim.  Simply do `:GrammarCheck` to see the powerful checking.  This plugin automatically downloads [LanguageTool](https://www.languagetool.org/), which requires Java 7+.

![screenshot](http://gifzo.net/FNmJMaFgjY.gif)


## Mappings in the information window

### The information window

You can use some mappings in the information window, which is opened to show the detail of an error when the cursor move on an error.

| Mappings | Description                       |
| -------- |:--------------------------------- |
|   `q`    | Quit the info window              |
|  `<CR>`  | Move to the location of the error |
|   `f`    | Fix the error __automatically__   |

### `<Plug>` mappings to execute anywhere

| Mappings                                 | Description                                  |
| --------                                 |:-------------------------------------------- |
| `<Plug>(grammarous-move-to-info-window)` | Move the cursor to the info window           |
| `<Plug>(grammarous-open-info-window)`    | Open the info window for under the cursor    |
| `<Plug>(grammarous-reset)`               | Reset the current check                      |
| `<Plug>(grammarous-fixit)`               | Fix the error under the cursor automatically |
| `<Plug>(grammarous-fixall)`              | Fix all the errors in a current buffer       |

## Fix examples

- [vim-themis](https://github.com/rhysd/vim-themis/commit/b2f838b29f47180ccee50488e01d6774a21d0c03)
- [unite.vim](https://github.com/rhysd/unite.vim/commit/5716eac38781e7a233c98f2a3d7aee8909326791)
- [vim-quickrun](https://github.com/rhysd/vim-quickrun/commit/236c753e0572266670d176e667054d55ad52a3f3)

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


let s:save_cpo = &cpo
set cpo&vim

let s:V = vital#of('grammarous')
let s:XML = s:V.import('Web.XML')
let s:O = s:V.import('OptionParser')

let g:grammarous#root = fnamemodify(expand('<sfile>'), ':p:h:h')
let g:grammarous#jar_dir = get(g:, 'grammarous#jar_dir', g:grammarous#root . '/misc')
let g:grammarous#jar_url = get(g:, 'grammarous#jar_url', 'https://languagetool.org/download/LanguageTool-2.6.zip')
let g:grammarous#java_cmd = get(g:, 'grammarous#java_cmd', 'java')
let g:grammarous#default_lang = get(g:, 'grammarous#default_lang', 'en')
let g:grammarous#info_window_height = get(g:, 'grammarous#info_window_height', 10)
let g:grammarous#info_win_direction = get(g:, 'grammarous#info_win_direction', 'botright')

" FIXME
let g:grammarous#disabled_rules = get(g:, 'grammarous#disabled_rules', ['WHITESPACE_RULE', 'EN_QUOTES'])

highlight default link GrammarousError SpellBad
highlight default link GrammarousInfoError ErrorMsg
highlight default link GrammarousInfoSection Keyword

augroup plugin-grammarous-auto-preview
    autocmd!
augroup END

function! grammarous#error(...)
    echohl ErrorMsg
    try
        if a:0 > 1
            let msg = 'vim-grammarous: ' . call('printf', a:000)
        else
            let msg = 'vim-grammarous: ' . a:1
        endif
        for l in split(msg, "\n")
            echomsg l
        endfor
    finally
        echohl None
    endtry
endfunction

function! s:find_jar(dir)
    return fnamemodify(findfile('languagetool-commandline.jar', a:dir . '/**'), ':p')
endfunction

function! s:prepare_jar(dir)
    let jar = s:find_jar(a:dir)
    if jar ==# ''
        if grammarous#downloader#download(a:dir)
            let jar = s:find_jar(a:dir)
        endif
    endif
    return jar
endfunction

function! s:init()
    if exists('s:jar_file')
        return s:jar_file
    endif

    if !exists('*matchaddpos')
        call grammarous#error('Vim 7.4p330+ is required for matchaddpos()')
        return ''
    endif

    try
        silent call vimproc#version()
    catch
        call grammarous#error('vimproc.vim is not found. Please install it from https://github.com/Shougo/vimproc.vim')
        return ''
    endtry

    if !executable(g:grammarous#java_cmd)
        call grammarous#error('"java" command is not found.  Please install java 1.7+ .')
        return ''
    endif

    " TODO:
    " Check java version

    let jar = s:prepare_jar(g:grammarous#jar_dir)
    if jar ==# ''
        call grammarous#error('Failed to get LanguageTool')
        return ''
    endif

    let s:jar_file = jar
    return jar
endfunction

function! s:make_text(text)
    if type(a:text) == type('')
        return a:text
    else
        return join(a:text, "\n")
    endif
endfunction

function! grammarous#invoke_check(...)
    let jar = s:init()
    if jar ==# ''
        return []
    endif

    if a:0 < 1
        call grammarous#error('Invalid argument')
        return []
    endif

    let lang = a:0 == 1 ? g:grammarous#default_lang : a:1
    let text = s:make_text(a:0 == 1 ? a:1 : a:2)

    let tmpfile = tempname()
    execute 'redir! >' tmpfile
        silent echon text
    redir END

    let cmd = printf(
                \ "%s -jar %s -c %s -d '%s' -l %s --api %s",
                \ g:grammarous#java_cmd,
                \ jar,
                \ &fileencoding ? &fileencoding : &encoding,
                \ join(g:grammarous#disabled_rules, ','),
                \ lang,
                \ tmpfile
                \ )

    let msg = printf("Checking grammater (lang: %s)...", lang)
    echomsg msg
    " FIXME: Do it in background
    let xml = vimproc#system(cmd)
    call delete(tmpfile)

    if vimproc#get_last_status()
        call grammarous#error("Command '%s' is failed:\n%s", cmd, xml)
        return []
    endif

    redraw! | echomsg msg . 'done!'
    return s:XML.parse(substitute(xml, "\n", '', 'g'))
endfunction

function! s:sunitize(s)
    return substitute(escape(a:s, "'\\"), ' ', '\\_\\s', 'g')
endfunction

function! grammarous#generate_highlight_pattern(error)
    let line = a:error.fromy + 1
    let prefix = a:error.contextoffset > 0 ? s:sunitize(a:error.context[: a:error.contextoffset-1]) : ''
    let rest = a:error.context[a:error.contextoffset :]
    let the_error = s:sunitize(rest[: a:error.errorlength-1])
    let rest = s:sunitize(rest[a:error.errorlength :])
    return '\V' . prefix . '\zs' . the_error . '\ze' . rest
endfunction

function! grammarous#get_errors_from_xml(xml)
    return map(filter(a:xml.childNodes(), 'v:val.name ==# "error"'), 'v:val.attr')
endfunction

function! s:matcherrpos(...)
    return matchaddpos('GrammarousError', [a:000], 999)
endfunction

function! s:highlight_error(from, to)
    if a:from[0] == a:to[0]
        return s:matcherrpos(a:from[0], a:from[1], a:to[1] - a:from[1])
    endif

    let ids = [s:matcherrpos(a:from[0], a:from[1], strlen(getline(a:from[0]))+1 - a:from[1])]
    let line = a:from[0] + 1
    while line != a:to[0]
        call add(ids, s:matcherrpos(line))
    endwhile
    call add(ids, s:matcherrpos(a:to[0], 1, a:to[1] - 1))
    return ids
endfunction

function! grammarous#highlight_errors_in_current_buffer(errs)
    return map(copy(a:errs), "
                \ s:highlight_error(
                \     [str2nr(v:val.fromy)+1, str2nr(v:val.fromx)+1],
                \     [str2nr(v:val.toy)+1, str2nr(v:val.tox)+1],
                \   )
                \ ")
endfunction

function! grammarous#reset_highlights()
    for m in filter(getmatches(), 'v:val.group ==# "GrammarousError"')
        call matchdelete(m.id)
    endfor
endfunction

function! grammarous#reset()
    call grammarous#reset_highlights()
    autocmd! plugin-grammarous-auto-preview
    unlet! b:grammarous_result b:grammarous_preview_winnr
endfunction

let s:opt_parser = s:O.new()
                     \.on('--lang=VALUE', 'language to check', {'default' : g:grammarous#default_lang})
                     \.on('--[no-]preview', 'enable auto preview', {'default' : 1})

function! grammarous#complete_opt(arglead, cmdline, cursorpos)
    return s:opt_parser.complete(a:arglead, a:cmdline, a:cursorpos)
endfunction

function! s:do_auto_preview()
    if exists('s:do_not_preview')
        unlet s:do_not_preview
        return
    endif
    if !exists('b:grammarous_result') || empty(b:grammarous_result)
        autocmd! plugin-grammarous-auto-preview
        return
    endif

    call grammarous#create_update_info_window_of(b:grammarous_result)
endfunction

function! grammarous#check_current_buffer(qargs)
    if exists('b:grammarous_result')
        call grammarous#reset_highlights()
        redraw!
    endif

    let parsed = s:opt_parser.parse(a:qargs, 1, "")

    let b:grammarous_auto_preview = parsed.preview
    if parsed.preview
        autocmd CursorMoved <buffer> call <SID>do_auto_preview()
    endif

    let b:grammarous_result = grammarous#get_errors_from_xml(grammarous#invoke_check(parsed.lang, getline(1, '$')))
    return grammarous#highlight_errors_in_current_buffer(b:grammarous_result)
endfunction

function! s:less_equal_position(p1, p2)
    if a:p1[0] != a:p2[0]
        return a:p1[0] <= a:p2[0]
    endif

    return a:p1[1] <= a:p2[1]
endfunction

function! grammarous#get_error_at(pos, errs)
    " XXX:
    " O(n).  I should use binary search?
    for e in a:errs
        let from = [e.fromy+1, e.fromx+1]
        let to = [e.toy+1, e.tox+1]
        if s:less_equal_position(from, a:pos) && s:less_equal_position(a:pos, to)
            return e
        endif
    endfor
    return {}
endfunction

function! s:get_info_buffer(e)
    return join(
        \ [
        \   "Error: " . a:e.category,
        \   "    " . a:e.msg,
        \   "",
        \   "Context:",
        \   "    " . a:e.context,
        \   "",
        \   "Correction:",
        \   "    " . split(a:e.replacements, '#')[0]
        \ ],
        \ "\n")
endfunction

function! s:quit_info_window()
    let s:do_not_preview = 1
    unlet! b:grammarous_preview_winnr
    quit!
    unlet b:grammarous_preview_winnr
endfunction

function! s:move_cursor_to(bufnr, line, col)
    let winnr = bufwinnr(a:bufnr)
    if winnr == -1
        return
    endif

    execute winnr . 'wincmd w'
    call cursor(a:line, a:col)
endfunction

function! s:open_info_window(e, bufnr)
    execute g:grammarous#info_win_direction g:grammarous#info_window_height . 'new'
    let b:grammarous_preview_original_bufnr = a:bufnr
    let b:grammarous_preview_error = a:e
    put =s:get_info_buffer(a:e)
    silent 1delete _
    execute 1
    syntax match GrammarousInfoSection "\%(Context\|Correction\):"
    syntax match GrammarousInfoError "Error:.*$"
    execute 'syntax match GrammarousError "' . grammarous#generate_highlight_pattern(a:e) . '"'
    setlocal nonumber bufhidden=wipe buftype=nofile readonly nolist nobuflisted noswapfile nomodifiable nomodified
    nnoremap <silent><buffer>q :<C-u>call <SID>quit_info_window()<CR>
    nnoremap <silent><buffer><CR> :<C-u>call <SID>move_cursor_to(b:grammarous_preview_original_bufnr, b:grammarous_preview_error.fromy+1, b:grammarous_preview_error.fromx+1)<CR>
    return winnr()
endfunction

function! grammarous#create_update_info_window_of(errs)
    let e = grammarous#get_error_at(getpos('.')[1 : 2], a:errs)
    if empty(e)
        return
    endif
    if exists('b:grammarous_preview_winnr')
        let w = winnr()
        execute b:grammarous_preview_winnr . 'wincmd w'
        wincmd c
        execute w . 'wincmd w'
    endif

    let winnr = s:open_info_window(e, bufnr('%'))
    wincmd p
    let b:grammarous_preview_winnr = winnr
endfunction

function! grammarous#create_and_jump_to_info_window_of(errs)
    call grammarous#create_update_info_window_of(a:errs)
    wincmd p
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo

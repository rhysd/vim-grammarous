let s:save_cpo = &cpo
set cpo&vim

let s:V = vital#of('grammarous')
let s:XML = s:V.import('Web.XML')
let s:O = s:V.import('OptionParser')

let g:grammarous#root = fnamemodify(expand('<sfile>'), ':p:h:h')
silent! lockvar g:grammarous#root
let g:grammarous#jar_dir = get(g:, 'grammarous#jar_dir', g:grammarous#root . '/misc')
let g:grammarous#jar_url = get(g:, 'grammarous#jar_url', 'https://languagetool.org/download/LanguageTool-2.6.zip')
let g:grammarous#java_cmd = get(g:, 'grammarous#java_cmd', 'java')
let g:grammarous#default_lang = get(g:, 'grammarous#default_lang', 'en')
let g:grammarous#info_window_height = get(g:, 'grammarous#info_window_height', 10)
let g:grammarous#info_win_direction = get(g:, 'grammarous#info_win_direction', 'botright')
let g:grammarous#use_fallback_highlight = get(g:, 'grammarous#use_fallback_highlight', !exists('*matchaddpos'))

" FIXME
let g:grammarous#disabled_rules = get(g:, 'grammarous#disabled_rules', ['WHITESPACE_RULE', 'EN_QUOTES'])

highlight default link GrammarousError SpellBad
highlight default link GrammarousInfoError ErrorMsg
highlight default link GrammarousInfoSection Keyword

augroup pluging-rammarous-highlight
    autocmd ColorScheme * highlight default link GrammarousError SpellBad
    autocmd ColorScheme * highlight default link GrammarousInfoError ErrorMsg
    autocmd ColorScheme * highlight default link GrammarousInfoSection Keyword
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
    return findfile('languagetool-commandline.jar', a:dir . '/**')
endfunction

function! s:prepare_jar(dir)
    let jar = s:find_jar(a:dir)
    if jar ==# ''
        if grammarous#downloader#download(a:dir)
            let jar = s:find_jar(a:dir)
        endif
    endif
    return fnamemodify(jar, ':p')
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

    let msg = printf("Checking grammater (lang: %s) ...", lang)
    echo msg
    " FIXME: Do it in background
    let xml = vimproc#system(cmd)
    call delete(tmpfile)

    if vimproc#get_last_status()
        call grammarous#error("Command '%s' is failed:\n%s", cmd, xml)
        return []
    endif

    let xml = substitute(xml, '&quot;', '"',  'g')
    let xml = substitute(xml, '&apos;', "'",  'g')
    let xml = substitute(xml, '&gt;',   '>',  'g')
    let xml = substitute(xml, '&lt;',   '<',  'g')
    let xml = substitute(xml, '&amp;',  '\&', 'g')

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

" XXX:
" This is bug of Vital.Web.XML? In some cases, key and value of element of
" b:grammarous_result may be the same and some keys may not exist.
function! s:is_valid_error(e)
    return empty(filter([
                \  'fromx',
                \  'fromy',
                \  'tox',
                \  'toy',
                \  'context',
                \  'contextoffset',
                \  'category',
                \  'msg',
                \  'replacements',
                \  'errorlength',
                \ ], '!has_key(a:e, v:val)'))
endfunction

function! grammarous#get_errors_from_xml(xml)
    return filter(map(filter(a:xml.childNodes(), 'v:val.name ==# "error"'), 'v:val.attr'), 's:is_valid_error(v:val)')
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

function! s:remove_3dots(str)
    return substitute(substitute(a:str, '\.\.\.$', '', ''), '\\V\zs\.\.\.', '', '')
endfunction

function! grammarous#highlight_errors_in_current_buffer(errs)
    if !g:grammarous#use_fallback_highlight
        for e in a:errs
            let e.id = s:highlight_error(
                    \   [str2nr(e.fromy)+1, str2nr(e.fromx)+1],
                    \   [str2nr(e.toy)+1, str2nr(e.tox)+1],
                    \ )
        endfor
    else
        for e in a:errs
            let e.id = matchadd(
                    \   "GrammarousError",
                    \   s:remove_3dots(grammarous#generate_highlight_pattern(e)),
                    \   999
                    \ )
        endfor
    endif
endfunction

function! grammarous#reset_highlights()
    for m in filter(getmatches(), 'v:val.group ==# "GrammarousError"')
        call matchdelete(m.id)
    endfor
endfunction

function! grammarous#reset()
    call grammarous#reset_highlights()
    silent! autocmd! plugin-grammarous-auto-preview
    call grammarous#close_info_window()
    unlet! b:grammarous_result b:grammarous_preview_bufnr
endfunction

let s:opt_parser = s:O.new()
                     \.on('--lang=VALUE', 'language to check', {'default' : g:grammarous#default_lang})
                     \.on('--[no-]preview', 'enable auto preview', {'default' : 1})

function! grammarous#complete_opt(arglead, cmdline, cursorpos)
    return s:opt_parser.complete(a:arglead, a:cmdline, a:cursorpos)
endfunction

function! s:do_auto_preview()
    let mode = mode()
    if mode ==? 'v' || mode ==# "\<C-v>"
        return
    endif

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
        augroup plugin-grammarous-auto-preview
            autocmd!
            autocmd CursorMoved <buffer> call <SID>do_auto_preview()
        augroup END
    endif

    let b:grammarous_result = grammarous#get_errors_from_xml(grammarous#invoke_check(parsed.lang, getline(1, '$')))

    redraw!
    if empty(b:grammarous_result)
        echomsg "Yay! No grammatical error is detected."
        return
    else
        let len = len(b:grammarous_result)
        echomsg printf("Detected %d grammatical error%s", len, len > 1 ? 's' : '')
        call grammarous#highlight_errors_in_current_buffer(b:grammarous_result)
    endif

endfunction

function! s:less_position(p1, p2)
    if a:p1[0] != a:p2[0]
        return a:p1[0] < a:p2[0]
    endif

    return a:p1[1] < a:p2[1]
endfunction

function! s:binary_search_by_pos(errors, the_pos, start, end)
    if a:start > a:end
        return {}
    endif

    let m = (a:start + a:end) / 2
    let from = [a:errors[m].fromy+1, a:errors[m].fromx+1]
    let to = [a:errors[m].toy+1, a:errors[m].tox]

    if s:less_position(a:the_pos, from)
        return s:binary_search_by_pos(a:errors, a:the_pos, a:start, m-1)
    endif

    if s:less_position(to, a:the_pos)
        return s:binary_search_by_pos(a:errors, a:the_pos, m+1, a:end)
    endif

    return a:errors[m]
endfunction

" Note:
" It believes all errors are sorted by its position
function! grammarous#get_error_at(pos, errs)
    return s:binary_search_by_pos(a:errs, a:pos, 0, len(a:errs)-1)
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
        \   "    " . split(a:e.replacements, '#')[0],
        \   "",
        \   "Press '?' in this window to show help",
        \ ],
        \ "\n")
endfunction

function! s:quit_info_window()
    let s:do_not_preview = 1
    quit!
    unlet b:grammarous_preview_bufnr
endfunction

function! grammarous#fixit(err, ...)
    if empty(a:err) || !s:move_to_checked_buf(a:err.fromy+1, a:err.fromx+1)
        return
    endif

    let sel_save = &l:selection
    let &l:selection = "inclusive"
    let save_g_reg = getreg('g', 1)
    let save_g_regtype = getregtype('g')
    try
        normal! v
        call cursor(a:err.toy+1, a:err.tox)
        normal! "gy
        let from = getreg('g')
        let to = split(a:err.replacements, '#')[0]
        call setreg('g', to, 'v')
        normal! gv"gp

        call grammarous#remove_error(a:err, get(a:, 1, b:grammarous_result))

        echomsg printf("Fixed: '%s' -> '%s'", from, to)
    finally
        call setreg('g', save_g_reg, save_g_regtype)
        let &l:selection = sel_save
    endtry
endfunction

function! grammarous#fixall(errs)
    for e in a:errs
        call grammarous#fixit(e)
    endfor
endfunction

function! s:map_remove_error_from_info_window()
    let e = b:grammarous_preview_error
    if !s:move_to_checked_buf(
        \ b:grammarous_preview_error.fromy+1,
        \ b:grammarous_preview_error.fromx+1 )
        return
    endif

    call grammarous#remove_error(e, b:grammarous_result)
endfunction

function! s:map_show_info_window_help()
    echo join([
            \   "| Mappings | Description                              |",
            \   "| -------- |:---------------------------------------- |",
            \   "|    q     | Quit the info window                     |",
            \   "|   <CR>   | Move to the location of the error        |",
            \   "|    f     | Fix the error automatically              |",
            \   "|    r     | Remove the error from the checked buffer |",
            \ ], "\n")
endfunction

function! s:open_info_window(e, bufnr)
    execute g:grammarous#info_win_direction g:grammarous#info_window_height . 'new'
    let b:grammarous_preview_original_bufnr = a:bufnr
    let b:grammarous_preview_error = a:e
    silent put =s:get_info_buffer(a:e)
    silent 1delete _
    execute 1
    syntax match GrammarousInfoSection "\%(Context\|Correction\):"
    syntax match GrammarousInfoError "Error:.*$"
    execute 'syntax match GrammarousError "' . grammarous#generate_highlight_pattern(a:e) . '"'
    setlocal nonumber bufhidden=wipe buftype=nofile readonly nolist nobuflisted noswapfile nomodifiable nomodified
    nnoremap <silent><buffer>q :<C-u>call <SID>quit_info_window()<CR>
    nnoremap <silent><buffer><CR> :<C-u>call <SID>move_to_checked_buf(b:grammarous_preview_error.fromy+1, b:grammarous_preview_error.fromx+1)<CR>
    nnoremap <buffer>f :<C-u>call grammarous#fixit(b:grammarous_preview_error)<CR>
    nnoremap <silent><buffer>r :<C-u>call <SID>map_remove_error_from_info_window()<CR>
    nnoremap <buffer>? :<C-u>call <SID>map_show_info_window_help()<CR>
    return bufnr('%')
endfunction

function! s:lookup_preview_bufnr()
    for b in tabpagebuflist()
        let the_buf = getbufvar(b, 'grammarous_preview_bufnr', -1)
        if the_buf != -1
            return the_buf
        endif
    endfor
    return -1
endfunction

function! s:move_to_pos(pos)
    let p = type(a:pos[0]) == type([]) ? a:pos[0] : a:pos
    return cursor(a:pos[0], a:pos[1]) != -1
endfunction

function! s:move_to(buf, pos)
    let winnr = bufwinnr(a:buf)
    if winnr == -1
        return 0
    endif

    execute winnr . 'wincmd w'
    return s:move_to_pos(a:pos)
endfunction

function! s:move_to_checked_buf(...)
    if exists('b:grammarous_result')
        return s:move_to_pos(a:000)
    endif

    if exists('b:grammarous_preview_original_bufnr')
        return s:move_to(b:grammarous_preview_original_bufnr, a:000)
    endif

    for b in tabpagebuflist()
        if !empty(getbufvar(b, 'grammarous_result', []))
            return s:move_to(b, a:000)
        endif
    endfor

    return 0
endfunction

function! grammarous#close_info_window()
    let cur_win = winnr()
    if exists('b:grammarous_preview_bufnr')
        let prev_win = bufwinnr(b:grammarous_preview_bufnr)
    else
        let the_buf = s:lookup_preview_bufnr()
        if the_buf == -1
            return 0
        endif
        let prev_win = bufwinnr(the_buf)
    endif

    if prev_win == -1
        return 0
    end

    execute prev_win . 'wincmd w'
    wincmd c
    execute cur_win . 'wincmd w'

    return 1
endfunction

function! grammarous#create_update_info_window_of(errs)
    let e = grammarous#get_error_at(getpos('.')[1 : 2], a:errs)
    if empty(e)
        return
    endif

    if exists('b:grammarous_preview_bufnr')
        call grammarous#close_info_window()
    endif

    let bufnr = s:open_info_window(e, bufnr('%'))
    wincmd p
    let b:grammarous_preview_bufnr = bufnr
endfunction

function! grammarous#create_and_jump_to_info_window_of(errs)
    call grammarous#create_update_info_window_of(a:errs)
    wincmd p
endfunction

function! grammarous#remove_error(e, errs)
    let ids = type(a:e.id) == type([]) ? a:e.id : [a:e.id]
    for i in ids
        if matchdelete(i) == -1
            return 0
        endif
    endfor

    for i in range(len(a:errs))
        if type(a:errs[i].id) == type(a:e.id) && a:errs[i].id == a:e.id
            call grammarous#close_info_window()
            unlet a:errs[i]
            return 1
        endif
    endfor

    return 0
endfunction

function! grammarous#remove_error_at(pos, errs)
    let e = grammarous#get_error_at(a:pos, a:errs)
    if empty(e)
        return 0
    endif

    return grammarous#remove_error(e, a:errs)
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo

let s:save_cpo = &cpo
set cpo&vim

let s:V = vital#of('grammarous')
let s:XML = s:V.import('Web.XML')
let s:O = s:V.import('OptionParser')
let s:P = s:V.import('Process')

let g:grammarous#root                            = fnamemodify(expand('<sfile>'), ':p:h:h')
silent! lockvar g:grammarous#root
let g:grammarous#jar_dir                         = get(g:, 'grammarous#jar_dir', g:grammarous#root . '/misc')
let g:grammarous#jar_url                         = get(g:, 'grammarous#jar_url', 'https://www.languagetool.org/download/LanguageTool-3.5.zip')
let g:grammarous#java_cmd                        = get(g:, 'grammarous#java_cmd', 'java')
let g:grammarous#default_lang                    = get(g:, 'grammarous#default_lang', 'en')
let g:grammarous#use_vim_spelllang               = get(g:, 'grammarous#use_vim_spelllang', 0)
let g:grammarous#info_window_height              = get(g:, 'grammarous#info_window_height', 10)
let g:grammarous#info_win_direction              = get(g:, 'grammarous#info_win_direction', 'botright')
let g:grammarous#use_fallback_highlight          = get(g:, 'grammarous#use_fallback_highlight', !exists('*matchaddpos'))
let g:grammarous#disabled_rules                  = get(g:, 'grammarous#disabled_rules', {'*' : ['WHITESPACE_RULE', 'EN_QUOTES']})
let g:grammarous#default_comments_only_filetypes = get(g:, 'grammarous#default_comments_only_filetypes', {'*' : 0})
let g:grammarous#enable_spell_check              = get(g:, 'grammarous#enable_spell_check', 0)
let g:grammarous#move_to_first_error             = get(g:, 'grammarous#move_to_first_error', 1)
let g:grammarous#hooks                           = get(g:, 'grammarous#hooks', {})
let g:grammarous#languagetool_cmd                = get(g:, 'grammarous#languagetool_cmd', '')

highlight default link GrammarousError SpellBad
highlight default link GrammarousInfoError ErrorMsg
highlight default link GrammarousInfoSection Keyword
highlight default link GrammarousInfoHelp Special

augroup pluging-rammarous-highlight
    autocmd ColorScheme * highlight default link GrammarousError SpellBad
    autocmd ColorScheme * highlight default link GrammarousInfoError ErrorMsg
    autocmd ColorScheme * highlight default link GrammarousInfoSection Keyword
    autocmd ColorScheme * highlight default link GrammarousInfoHelp Special
augroup END

function! grammarous#_import_vital_modules()
    return [s:XML, s:O, s:P]
endfunction

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

    if !executable(g:grammarous#java_cmd)
        call grammarous#error('"java" command not found.  Please install Java 8+ .')
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

function! grammarous#invoke_check(range_start, ...)
    if g:grammarous#languagetool_cmd ==# ''
        let jar = s:init()
        if jar ==# ''
            return []
        endif
    else
        let jar = ''
    endif

    if a:0 < 1
        call grammarous#error('Invalid argument')
        return []
    endif


    if g:grammarous#use_vim_spelllang
      " Convert vim spelllang to languagetool spelllang
      if len(split(&spelllang, '_')) == 1
        let lang = split(&spelllang, '_')[0]
      elseif len(split(&spelllang, '_')) == 2
        let lang = split(&spelllang, '_')[0].'-'.toupper(split(&spelllang, '_')[1])
      endif
    else
      let lang = a:0 == 1 ? g:grammarous#default_lang : a:1
    endif
    let text = s:make_text(a:0 == 1 ? a:1 : a:2)

    let tmpfile = tempname()
    execute 'redir! >' tmpfile
        let l = 1
        while l < a:range_start
            silent echo ""
            let l += 1
        endwhile
        silent echon text
    redir END

    let cmdargs = printf(
            \   '-c %s -d %s -l %s --api %s',
            \   &fileencoding ? &fileencoding : &encoding,
            \   string(join(get(g:grammarous#disabled_rules, &filetype, get(g:grammarous#disabled_rules, '*', [])), ',')),
            \   lang,
            \   substitute(tmpfile, '\\\s\@!', '\\\\', 'g')
            \ )

    if g:grammarous#languagetool_cmd !=# ''
        let cmd = printf('%s %s', g:grammarous#languagetool_cmd, cmdargs)
    else
        let cmd = printf('%s -jar %s %s', g:grammarous#java_cmd, substitute(jar, '\\\s\@!', '\\\\', 'g'), cmdargs)
    endif

    echo printf("Checking grammar (lang: %s) ...", lang)
    " FIXME: Do it in background
    let xml = s:P.system(cmd)
    call delete(tmpfile)

    if s:P.get_last_status()
        call grammarous#error("Command '%s' failed:\n%s", cmd, xml)
        return []
    endif

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

function! s:unescape_xml(str)
    let s = substitute(a:str, '&quot;', '"',  'g')
    let s = substitute(s, '&apos;', "'",  'g')
    let s = substitute(s, '&gt;',   '>',  'g')
    let s = substitute(s, '&lt;',   '<',  'g')
    return  substitute(s, '&amp;',  '\&', 'g')
endfunction

function! s:unescape_error(err)
    for e in ['context', 'msg', 'replacements']
        let a:err[e] = s:unescape_xml(a:err[e])
    endfor
    return a:err
endfunction

function! grammarous#get_errors_from_xml(xml)
    return map(filter(a:xml.childNodes(), 'v:val.name ==# "error"'), 's:unescape_error(v:val.attr)')
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
    call grammarous#info_win#stop_auto_preview()
    call grammarous#info_win#close()
    if exists('s:saved_spell')
        let &l:spell = s:saved_spell
        unlet s:saved_spell
    endif
    if has_key(g:grammarous#hooks, 'on_reset')
        call call(g:grammarous#hooks.on_reset, [b:grammarous_result], g:grammarous#hooks)
    endif
    unlet! b:grammarous_result b:grammarous_preview_bufnr
endfunction

let s:opt_parser = s:O.new()
    \.on('--lang=VALUE',               'language to check',   {'default' : g:grammarous#default_lang})
    \.on('--[no-]preview',             'enable auto preview', {'default' : 1})
    \.on('--[no-]comments-only',       'check comment only',  {'default' : ''})
    \.on('--[no-]move-to-first-error', 'move to first error', {'default' : g:grammarous#move_to_first_error})

function! grammarous#complete_opt(arglead, cmdline, cursorpos)
    return s:opt_parser.complete(a:arglead, a:cmdline, a:cursorpos)
endfunction

function! s:is_comment_only(option)
    if type(a:option) == type(0)
        return a:option
    endif

    return get(
        \   g:grammarous#default_comments_only_filetypes,
        \   &filetype,
        \   get(g:grammarous#default_comments_only_filetypes, '*', 0)
        \ )
endfunction

function! grammarous#check_current_buffer(qargs, range)
    if exists('b:grammarous_result')
        call grammarous#reset()
        redraw!
    endif

    let parsed = s:opt_parser.parse(a:qargs, a:range, "")
    if has_key(parsed, 'help')
        return
    endif

    let b:grammarous_auto_preview = parsed.preview
    if parsed.preview
        call grammarous#info_win#start_auto_preview()
    endif

    let b:grammarous_result
                \ = grammarous#get_errors_from_xml(
                \       grammarous#invoke_check(
                \           parsed.__range__[0],
                \           parsed.lang,
                \           getline(parsed.__range__[0], parsed.__range__[1])
                \       )
                \   )

    if s:is_comment_only(parsed['comments-only'])
        call filter(b:grammarous_result, 'synIDattr(synID(v:val.fromy+1, v:val.fromx+1, 0), "name") =~? "comment"')
    endif

    redraw!
    if empty(b:grammarous_result)
        echomsg "Yay! No grammatical errors detected."
        return
    else
        let len = len(b:grammarous_result)
        echomsg printf("Detected %d grammatical error%s", len, len > 1 ? 's' : '')
        call grammarous#highlight_errors_in_current_buffer(b:grammarous_result)
        if parsed['move-to-first-error']
            call cursor(b:grammarous_result[0].fromy+1, b:grammarous_result[0].fromx+1)
        endif
    endif

    if g:grammarous#enable_spell_check
        let s:saved_spell = &l:spell
        setlocal spell
    endif

    if has_key(g:grammarous#hooks, 'on_check')
        call call(g:grammarous#hooks.on_check, [b:grammarous_result], g:grammarous#hooks)
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

function! grammarous#fixit(err)
    if empty(a:err) || !grammarous#move_to_checked_buf(a:err.fromy+1, a:err.fromx+1)
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
        let to = split(a:err.replacements, '#', 1)[0]
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

function! s:move_to_pos(pos)
    let p = type(a:pos[0]) == type([]) ? a:pos[0] : a:pos
    return cursor(a:pos[0], a:pos[1]) != -1
endfunction

function! s:move_to(buf, pos)
    if a:buf != bufnr('%')
        let winnr = bufwinnr(a:buf)
        if winnr == -1
            return 0
        endif

        execute winnr . 'wincmd w'
    endif
    return s:move_to_pos(a:pos)
endfunction

function! grammarous#move_to_checked_buf(...)
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

function! grammarous#create_update_info_window_of(errs)
    let e = grammarous#get_error_at(getpos('.')[1 : 2], a:errs)
    if empty(e)
        return
    endif

    if exists('b:grammarous_preview_bufnr')
        let winnr = bufwinnr(b:grammarous_preview_bufnr)
        if winnr == -1
            let bufnr = grammarous#info_win#open(e, bufnr('%'))
        else
            execute winnr . 'wincmd w'
            let bufnr = grammarous#info_win#update(e)
        endif
    else
        let bufnr = grammarous#info_win#open(e, bufnr('%'))
    endif

    wincmd p
    let b:grammarous_preview_bufnr = bufnr
endfunction

function! grammarous#create_and_jump_to_info_window_of(errs)
    call grammarous#create_update_info_window_of(a:errs)
    wincmd p
endfunction

function! s:remove_error_highlight(e)
    let ids = type(a:e.id) == type([]) ? a:e.id : [a:e.id]
    for i in ids
        silent! if matchdelete(i) == -1
            return 0
        endif
    endfor
    return 1
endfunction

function! grammarous#remove_error(e, errs)
    if !s:remove_error_highlight(a:e)
        return 0
    endif

    for i in range(len(a:errs))
        if type(a:errs[i].id) == type(a:e.id) && a:errs[i].id == a:e.id
            call grammarous#info_win#close()
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

function! grammarous#disable_rule(rule, errs)
    call grammarous#info_win#close()

    " Note:
    " reverse() is needed because of removing elements in list
    for i in reverse(range(len(a:errs)))
        let e = a:errs[i]
        if e.ruleId ==# a:rule
            if !s:remove_error_highlight(e)
                return 0
            endif
            unlet a:errs[i]
        endif
    endfor

    echomsg "Disabled rule: " . a:rule

    return 1
endfunction

function! grammarous#disable_rule_at(pos, errs)
    let e = grammarous#get_error_at(a:pos, a:errs)
    if empty(e)
        return 0
    endif

    return grammarous#disable_rule(e.ruleId, a:errs)
endfunction

function! grammarous#move_to_next_error(pos, errs)
    for e in a:errs
        let p = [e.fromy+1, e.fromx+1]
        if s:less_position(a:pos, p)
            return s:move_to_pos(p)
        endif
    endfor
    call grammarous#error("No next error found.")
    return 0
endfunction

function! grammarous#move_to_previous_error(pos, errs)
    for e in reverse(copy(a:errs))
        let p = [e.fromy+1, e.fromx+1]
        if s:less_position(p, a:pos)
            return s:move_to_pos(p)
        endif
    endfor
    call grammarous#error("No previous error found.")
    return 0
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo

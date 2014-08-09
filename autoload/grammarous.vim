let s:save_cpo = &cpo
set cpo&vim

let s:V = vital#of('grammarous')
let s:XML = s:V.import('Web.XML')

let g:grammarous#root = fnamemodify(expand('<sfile>'), ':p:h:h')
let g:grammarous#jar_dir = get(g:, 'grammarous#jar_dir', g:grammarous#root . '/misc')
let g:grammarous#jar_url = get(g:, 'grammarous#jar_url', 'https://languagetool.org/download/LanguageTool-2.6.zip')
let g:grammarous#java_cmd = get(g:, 'grammarous#java_cmd', 'java')
let g:grammarous#default_lang = get(g:, 'grammarous#default_lang', 'en')

" FIXME
let g:grammarous#disabled_rules = get(g:, 'grammarous#disabled_rules', ['WHITESPACE_RULE', 'EN_QUOTES'])

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

    " FIXME: Do it in background
    let xml = vimproc#system(cmd)
    call delete(tmpfile)

    if vimproc#get_last_status()
        call grammarous#error("Command '%s' is failed:\n%s", cmd, xml)
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
    let the_error = s:sunitize(rest[: a:error.errorlength])
    let rest = s:sunitize(rest[a:error.errorlength+1 :])
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
    call add(ids, s:matcherrpos(a:to[0], 1, a:to[1]))
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

function! grammarous#check_current_buffer(...)
    let lang = a:0 > 0 ? a:1 : g:grammarous#default_lang

    let b:grammarous_result = grammarous#get_errors_from_xml(grammarous#invoke_check(lang, getline(1, '$')))
    return grammarous#highlight_errors_in_current_buffer(b:grammarous_result)
endfunction

" FIXME: Parse result

let &cpo = s:save_cpo
unlet s:save_cpo

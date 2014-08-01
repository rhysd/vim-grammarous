let s:save_cpo = &cpo
set cpo&vim

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
            echomsg 'vim-grammarous: ' . call('printf', a:000)
        else
            echomsg 'vim-grammarous: ' . a:1
        endif
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

function! grammarous#invoke_check(...)
    let jar = s:init()
    if jar ==# ''
        return ''
    endif

    if a:0 < 1
        call grammarous#error('Invalid argument')
        return ''
    endif

    let [lang, text] = a:0 == 1 ? [g:grammarous#default_lang, a:1] : [a:1, a:2]

    let tmpfile = tempname()
    execute 'redir! >' tmpfile
        silent echo text
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
        return ''
    endif

    return xml
endfunction

" FIXME: Parse result

let &cpo = s:save_cpo
unlet s:save_cpo

let s:save_cpo = &cpo
set cpo&vim

let s:source = {
            \ 'name' : 'grammarous',
            \ 'description' : 'Show result of grammar check by vim-grammarous',
            \ 'default_kind' : 'jump_list',
            \ 'default_action' : 'open',
            \ 'hooks' : {},
            \ 'syntax' : 'uniteSource__Grammarous',
            \ }

function! unite#sources#grammarous#define()
    return s:source
endfunction

function! s:source.hooks.on_init(args, context)
    call call('grammarous#check_current_buffer', a:args)
    let s:bufnr = bufnr('%')
endfunction

function! s:source.hooks.on_close(args, context)
    unlet! b:grammarous_result
    if get(a:context, 'no_quit', 0)
        execute bufwinnr(s:bufnr) . 'wincmd w'
        call grammarous#reset_highlights()
        wincmd p
    endif
endfunction

function! s:source.hooks.on_syntax(args, context)
    syntax match uniteSource__GrammarousKeyword "\%(Context\|Correct\):" contained containedin=uniteSource__Grammarous
    syntax keyword uniteSource__GrammarousError Error contained containedin=uniteSource__Grammarous
    highlight default link uniteSource__GrammarousKeyword Keyword
    highlight default link uniteSource__GrammarousError ErrorMsg
endfunction

function! s:source.change_candidates(args, context)
    return map(copy(b:grammarous_result), '{
                \   "word" : printf("Error:   %s\nContext: %s\nCorrect: %s", v:val.msg, v:val.context, substitute(v:val.replacements, "#", ", ", "g")),
                \   "action__buffer_nr" : s:bufnr,
                \   "action__line" : str2nr(v:val.fromy)+1,
                \   "action__col" : str2nr(v:val.fromx)+1,
                \   "is_multiline" : 1,
                \}')
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo

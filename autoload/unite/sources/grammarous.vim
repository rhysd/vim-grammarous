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
    if exists('b:unite') && has_key(b:unite, 'prev_bufnr')
        let a:context.source__checked_bufnr = b:unite.prev_bufnr
    else
        let a:context.source__checked_bufnr = bufnr('%')
    endif
    let a:context.source__checked_bufnr = getbufvar(a:context.source__checked_bufnr, 'grammarous_preview_original_bufnr', a:context.source__checked_bufnr)
endfunction

function! s:source.hooks.on_syntax(args, context)
    syntax match uniteSource__GrammarousKeyword "\%(Context\|Correct\):" contained containedin=uniteSource__Grammarous
    syntax keyword uniteSource__GrammarousError Error contained containedin=uniteSource__Grammarous
    highlight default link uniteSource__GrammarousKeyword Keyword
    highlight default link uniteSource__GrammarousError ErrorMsg
    for err in getbufvar(a:context.source__checked_bufnr, 'grammarous_result', [])
        call matchadd('GrammarousError', grammarous#generate_highlight_pattern(err), 999)
    endfor
endfunction

function! s:source.change_candidates(args, context)
    return map(copy(getbufvar(a:context.source__checked_bufnr, 'grammarous_result', [])), '{
                \   "word" : printf("Error:   %s\nContext: %s\nCorrect: %s", v:val.msg, v:val.context, split(v:val.replacements, "#")[0]),
                \   "action__buffer_nr" : a:context.source__checked_bufnr,
                \   "action__line" : str2nr(v:val.fromy)+1,
                \   "action__col" : str2nr(v:val.fromx)+1,
                \   "is_multiline" : 1,
                \}')
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo

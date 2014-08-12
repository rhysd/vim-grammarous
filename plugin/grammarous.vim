if (exists('g:loaded_grammarous') && g:loaded_grammarous) || &cp
    finish
endif

command! -nargs=* -complete=customlist,grammarous#complete_opt GrammarousCheck call grammarous#check_current_buffer(<q-args>)
command! -nargs=0 GrammarousReset call grammarous#reset()

nnoremap <silent><Plug>(grammarous-move-to-info-window) :<C-u>call grammarous#create_and_jump_to_info_window_of(b:grammarous_result)<CR>
nnoremap <silent><Plug>(grammarous-open-info-window) :<C-u>call grammarous#create_update_info_window_of(b:grammarous_result)<CR>
nnoremap <silent><Plug>(grammarous-reset) :<C-u>call grammarous#reset()<CR>
nnoremap <silent><Plug>(grammarous-fixit) :<C-u>call grammarous#fixit(grammarous#get_error_at(getpos('.')[1 : 2], b:grammarous_result))<CR>
nnoremap <silent><Plug>(grammarous-fixall) :<C-u>call grammarous#fixall(b:grammarous_result)<CR>
nnoremap <silent><Plug>(grammarous-close-info-window) :<C-u>call grammarous#close_info_window()<CR>
nnoremap <silent><Plug>(grammarous-remove-error) :<C-u>call grammarous#remove_error_at(getpos('.')[1 : 2], b:grammarous_result)<CR>
nnoremap <silent><Plug>(grammarous-disable-rule) :<C-u>call grammarous#disable_rule_at(getpos('.')[1 : 2], b:grammarous_result)<CR>

let g:loaded_grammarous = 1

command! -nargs=? GrammarousCheck call grammarous#check_current_buffer(<f-args>)
nnoremap <silent><Plug>(grammarous-move-to-info-window) :<C-u>call grammarous#create_and_jump_to_info_window_of(b:grammarous_result)<CR>
nnoremap <silent><Plug>(grammarous-open-info-window) :<C-u>call grammarous#create_update_info_window_of(b:grammarous_result)<CR>
nnoremap <silent><Plug>(grammarous-reset) :<C-u>call grammarous#reset()<CR>

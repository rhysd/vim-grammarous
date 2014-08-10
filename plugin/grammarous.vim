command! -nargs=? GrammarousCheck call grammarous#check_current_buffer(<f-args>)
nnoremap <silent><Plug>(grammarous-preview-current-pos-error) :<C-u>call grammarous#create_or_jump_to_info_window_of(b:grammarous_result)<CR>

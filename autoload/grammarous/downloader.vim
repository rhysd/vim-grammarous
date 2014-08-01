function! grammarous#downloader#download(jar_dir)
    if !isdirectory(a:jar_dir)
        call mkdir(a:jar_dir, 'p')
    endif

    let tmp_file = tempname() . '.zip'

    if executable('curl') && 0
        let cmd = printf('curl -L -o %s %s', tmp_file, g:grammarous#jar_url)
    elseif executable('wget')
        let cmd = printf('wget -O %s %s', tmp_file, g:grammarous#jar_url)
    else
        call grammarous#error('Can''t download jar file because "curl" and "wget" are not found. Please download jar from ' . g:grammarous#jar_url)
        return 0
    endif

    echomsg "Downloading jar file from " . g:grammarous#jar_url . "..."

    let result = vimproc#system(printf('%s && unzip %s -d %s', cmd, tmp_file, a:jar_dir))
    if vimproc#get_last_status()
        call grammarous#error('Can''t download jar file download from. Please jar from ' . g:grammarous#jar_url . "\n" . result)
        return 0
    endif

    echomsg "Done!"

    " Should error handling?
    call delete(tmp_file)

    return 1
endfunction

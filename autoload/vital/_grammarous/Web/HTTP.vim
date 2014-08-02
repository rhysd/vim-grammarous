let s:save_cpo = &cpo
set cpo&vim


function! s:_vital_loaded(V)
  let s:V = a:V
  let s:Prelude = s:V.import('Prelude')
  let s:Process = s:V.import('Process')
  let s:String = s:V.import('Data.String')
endfunction

function! s:_vital_depends()
  return ['Prelude', 'Data.String', 'Process']
endfunction

function! s:__urlencode_char(c)
  return printf("%%%02X", char2nr(a:c))
endfunction

function! s:decodeURI(str)
  let ret = a:str
  let ret = substitute(ret, '+', ' ', 'g')
  let ret = substitute(ret, '%\(\x\x\)', '\=printf("%c", str2nr(submatch(1), 16))', 'g')
  return ret
endfunction

function! s:escape(str)
  let result = ''
  for i in range(len(a:str))
    if a:str[i] =~# '^[a-zA-Z0-9_.~-]$'
      let result .= a:str[i]
    else
      let result .= s:__urlencode_char(a:str[i])
    endif
  endfor
  return result
endfunction

function! s:encodeURI(items)
  let ret = ''
  if s:Prelude.is_dict(a:items)
    for key in sort(keys(a:items))
      if strlen(ret)
        let ret .= "&"
      endif
      let ret .= key . "=" . s:encodeURI(a:items[key])
    endfor
  elseif s:Prelude.is_list(a:items)
    for item in sort(a:items)
      if strlen(ret)
        let ret .= "&"
      endif
      let ret .= item
    endfor
  else
    let ret = s:escape(a:items)
  endif
  return ret
endfunction

function! s:encodeURIComponent(items)
  let ret = ''
  if s:Prelude.is_dict(a:items)
    for key in sort(keys(a:items))
      if strlen(ret) | let ret .= "&" | endif
      let ret .= key . "=" . s:encodeURIComponent(a:items[key])
    endfor
  elseif s:Prelude.is_list(a:items)
    for item in sort(a:items)
      if strlen(ret) | let ret .= "&" | endif
      let ret .= item
    endfor
  else
    let items = iconv(a:items, &enc, "utf-8")
    let len = strlen(items)
    let i = 0
    while i < len
      let ch = items[i]
      if ch =~# '[0-9A-Za-z-._~!''()*]'
        let ret .= ch
      elseif ch == ' '
        let ret .= '+'
      else
        let ret .= '%' . substitute('0' . s:String.nr2hex(char2nr(ch)), '^.*\(..\)$', '\1', '')
      endif
      let i = i + 1
    endwhile
  endif
  return ret
endfunction

let s:default_settings = {
\   'method': 'GET',
\   'headers': {},
\   'client': ['python', 'curl', 'wget'],
\   'maxRedirect': 20,
\   'retry': 1,
\ }
function! s:request(...)
  let settings = {}
  for arg in a:000
    if s:Prelude.is_dict(arg)
      let settings = extend(settings, arg, 'keep')
    elseif s:Prelude.is_string(arg)
      if has_key(settings, 'url')
        let settings.method = settings.url
      endif
      let settings.url = arg
    endif
    unlet arg
  endfor
  call extend(settings, deepcopy(s:default_settings), 'keep')
  let settings.method = toupper(settings.method)
  if !has_key(settings, 'url')
    throw 'Vital.Web.HTTP.request(): "url" parameter is required.'
  endif
  if !s:Prelude.is_list(settings.client)
    let settings.client = [settings.client]
  endif
  let client = s:_get_client(settings)
  if empty(client)
    throw 'Vital.Web.HTTP.request(): Available client not found: '
    \    . string(settings.client)
  endif
  if has_key(settings, 'contentType')
    let settings.headers['Content-Type'] = settings.contentType
  endif
  if has_key(settings, 'param')
    if s:Prelude.is_dict(settings.param)
      let getdatastr = s:encodeURI(settings.param)
    else
      let getdatastr = settings.param
    endif
    if strlen(getdatastr)
      let settings.url .= '?' . getdatastr
    endif
  endif
  if has_key(settings, 'data')
    let settings.data = s:_postdata(settings.data)
    let settings.headers['Content-Length'] = len(join(settings.data, "\n"))
  endif
  let settings._file = {}

  let [header, content] = client.request(settings)

  for file in values(settings._file)
    if filereadable(file)
      call delete(file)
    endif
  endfor
  return s:_build_response(header, content)
endfunction

function! s:get(url, ...)
  let settings = {
  \    'url': a:url,
  \    'param': a:0 > 0 ? a:1 : {},
  \    'headers': a:0 > 1 ? a:2 : {},
  \ }
  return s:request(settings)
endfunction

function! s:post(url, ...)
  let settings = {
  \    'url': a:url,
  \    'data': a:0 > 0 ? a:1 : {},
  \    'headers': a:0 > 1 ? a:2 : {},
  \    'method': a:0 > 2 ? a:3 : 'POST',
  \ }
  return s:request(settings)
endfunction

function! s:_readfile(file)
  if filereadable(a:file)
    return join(readfile(a:file, 'b'), "\n")
  endif
  return ''
endfunction

function! s:_make_postfile(data)
  let fname = tr(tempname(),'\','/')
  call writefile(a:data, fname, 'b')
  return fname
endfunction

function! s:_postdata(data)
  if s:Prelude.is_dict(a:data)
    return [s:encodeURI(a:data)]
  elseif s:Prelude.is_list(a:data)
    return a:data
  else
    return split(a:data, "\n")
  endif
endfunction

function! s:_build_response(header, content)
  let response = {
  \   'header' : a:header,
  \   'content': a:content,
  \   'status': 0,
  \   'statusText': '',
  \   'success': 0,
  \ }

  if !empty(a:header)
    let status_line = get(a:header, 0)
    let matched = matchlist(status_line, '^HTTP/1\.\d\s\+\(\d\+\)\s\+\(.*\)')
    if !empty(matched)
      let [status, statusText] = matched[1 : 2]
      let response.status = status - 0
      let response.statusText = statusText
      let response.success = status =~# '^2'
      call remove(a:header, 0)
    endif
  endif
  return response
endfunction

function! s:_make_header_args(headdata, option, quote)
  let args = ''
  for [key, value] in items(a:headdata)
    if s:Prelude.is_windows()
      let value = substitute(value, '"', '"""', 'g')
    endif
    let args .= " " . a:option . a:quote . key . ": " . value . a:quote
  endfor
  return args
endfunction

function! s:parseHeader(headers)
  " FIXME: User should be able to specify the treatment method of the duplicate item.
  let header = {}
  for h in a:headers
    let matched = matchlist(h, '^\([^:]\+\):\s*\(.*\)$')
    if !empty(matched)
      let [name, value] = matched[1 : 2]
      let header[name] = value
    endif
  endfor
  return header
endfunction

" Clients
function! s:_get_client(settings)
  let candidates = a:settings.client
  let names = s:Prelude.is_list(candidates) ? candidates : [candidates]
  for name in names
    if has_key(s:clients, name) && s:clients[name].available(a:settings)
      return s:clients[name]
    endif
  endfor
  return {}
endfunction
let s:clients = {}

let s:clients.python = {}

function! s:clients.python.available(settings)
  if !has('python')
    return 0
  endif
  if has_key(a:settings, 'outputFile')
    " 'outputFile' is not supported yet
    return 0
  endif
  if get(a:settings, 'retry', 0) != 1
    " 'retry' is not supported yet
    return 0
  endif
  return 1
endfunction

function! s:clients.python.request(settings)
  " TODO: maxRedirect, retry, outputFile
  let header = ''
  let body = ''
  python << endpython
try:
    class DummyClassForLocalScope:
        def main():
            import vim, urllib2, socket
            def vimstr(s):
                return "'" + s.replace("\0", "\n").replace("'", "''") + "'"

            def vimlist2str(list):
                if not list:
                    return None
                return "\n".join([s.replace("\n", "\0") for s in list])

            def status(res):
                return "HTTP/1.0 %d %s\r\n" % (res.code, res.msg)

            def access():
                settings = vim.eval('a:settings')
                data = vimlist2str(settings.get('data'))
                timeout = settings.get('timeout')
                if timeout:
                    timeout = float(timeout)
                requestHeaders = settings.get('headers')
                director = urllib2.build_opener()
                if settings.has_key('username'):
                    passman = urllib2.HTTPPasswordMgrWithDefaultRealm()
                    passman.add_password(
                        None,
                        settings['url'],
                        settings['username'],
                        settings.get('password', ''))
                    basicauth = urllib2.HTTPBasicAuthHandler(passman)
                    digestauth = urllib2.HTTPDigestAuthHandler(passman)
                    director.add_handler(basicauth)
                    director.add_handler(digestauth)
                req = urllib2.Request(settings['url'], data, requestHeaders)
                req.get_method = lambda: settings['method']
                default_timeout = socket.getdefaulttimeout()
                try:
                    # for Python 2.5 or before
                    socket.setdefaulttimeout(timeout)
                    res = director.open(req, timeout=timeout)
                    socket.setdefaulttimeout(default_timeout)
                except urllib2.URLError as res:
                    socket.setdefaulttimeout(default_timeout)
                    # FIXME: We want body and headers if possible
                    return (status(res), '')
                except socket.timeout as e:
                    socket.setdefaulttimeout(default_timeout)
                    return ('', '')

                st = status(res)
                responseHeaders = st + ''.join(res.info().headers)
                return (responseHeaders, res.read())

            (header, body) = access()
            vim.command('let header = ' + vimstr(header))
            vim.command('let body = ' + vimstr(body))

        main()
        raise RuntimeError("Exit from local scope")

except RuntimeError as exception:
    if exception.args != ("Exit from local scope",):
        raise exception

endpython
  return [split(header, "\r\n"), body]
endfunction

let s:clients.curl = {}

function! s:clients.curl.available(settings)
  return executable(self._command(a:settings))
endfunction

function! s:clients.curl._command(settings)
  return get(get(a:settings, 'command', {}), 'curl', 'curl')
endfunction

function! s:clients.curl.request(settings)
  let quote = s:_quote()
  let command = self._command(a:settings)
  let a:settings._file.header = tr(tempname(),'\','/')
  let command .= ' --dump-header ' . quote . a:settings._file.header . quote
  let has_output_file = has_key(a:settings, 'outputFile')
  if has_output_file
    let output_file = a:settings.outputFile
  else
    let output_file = tr(tempname(),'\','/')
    let a:settings._file.content = output_file
  endif
  let command .= ' --output ' . quote . output_file . quote
  let command .= ' -L -s -k -X ' . a:settings.method
  let command .= ' --max-redirs ' . a:settings.maxRedirect
  let command .= s:_make_header_args(a:settings.headers, '-H ', quote)
  let timeout = get(a:settings, 'timeout', '')
  let command .= ' --retry ' . a:settings.retry
  if timeout =~# '^\d\+$'
    let command .= ' --max-time ' . timeout
  endif
  if has_key(a:settings, 'username')
    let auth = a:settings.username . ':' . get(a:settings, 'password', '')
    let command .= ' --anyauth --user ' . quote . auth . quote
  endif
  let command .= ' ' . quote . a:settings.url . quote
  if has_key(a:settings, 'data')
    let a:settings._file.post = s:_make_postfile(a:settings.data)
    let command .= ' --data-binary @' . quote . a:settings._file.post . quote
  endif

  call s:Process.system(command)

  let headerstr = s:_readfile(a:settings._file.header)
  let header_chunks = split(headerstr, "\r\n\r\n")
  let header = split(get(header_chunks, -1, ''), "\r\n")
  if has_output_file
    let content = ''
  else
    let content = s:_readfile(output_file)
  endif
  return [header, content]
endfunction

let s:clients.wget = {}

function! s:clients.wget.available(settings)
  return executable(self._command(a:settings))
endfunction

function! s:clients.wget._command(settings)
  return get(get(a:settings, 'command', {}), 'wget', 'wget')
endfunction

function! s:clients.wget.request(settings)
  let quote = s:_quote()
  let command = self._command(a:settings)
  let method = a:settings.method
  if method ==# 'HEAD'
    let command .= ' --spider'
  elseif method !=# 'GET' && method !=# 'POST'
    let a:settings.headers['X-HTTP-Method-Override'] = a:settings.method
  endif
  let a:settings._file.header = tr(tempname(),'\','/')
  let command .= ' -o ' . quote . a:settings._file.header . quote
  let has_output_file = has_key(a:settings, 'outputFile')
  if has_output_file
    let output_file = a:settings.outputFile
  else
    let output_file = tr(tempname(),'\','/')
    let a:settings._file.content = output_file
  endif
  let command .= ' -O ' . quote . output_file . quote
  let command .= ' --server-response -q -L '
  let command .= ' --max-redirect=' . a:settings.maxRedirect
  let command .= s:_make_header_args(a:settings.headers, '--header=', quote)
  let timeout = get(a:settings, 'timeout', '')
  let command .= ' --tries=' . a:settings.retry
  if timeout =~# '^\d\+$'
    let command .= ' --timeout=' . timeout
  endif
  if has_key(a:settings, 'username')
    let command .= ' --http-user=' . quote . a:settings.username . quote
  endif
  if has_key(a:settings, 'password')
    let command .= ' --http-password=' . quote . a:settings.password . quote
  endif
  let command .= ' ' . quote . a:settings.url . quote
  if has_key(a:settings, 'data')
    let a:settings._file.post = s:_make_postfile(a:settings.data)
    let command .= ' --post-file=' . quote . a:settings._file.post . quote
  endif

  call s:Process.system(command)

  if filereadable(a:settings._file.header)
    let header_lines = readfile(a:settings._file.header, 'b')
    call map(header_lines, 'matchstr(v:val, "^\\s*\\zs.*")')
    let headerstr = join(header_lines, "\n")
    let header_chunks = split(headerstr, '\n\zeHTTP/1\.\d')
    let header = split(get(header_chunks, -1, ''), "\n")
  else
    let header = []
  endif
  if has_output_file
    let content = ''
  else
    let content = s:_readfile(output_file)
  endif
  return [header, content]
endfunction

function! s:_quote()
  return &shellxquote == '"' ?  "'" : '"'
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo

" vim:set et ts=2 sts=2 sw=2 tw=0:

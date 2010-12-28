" Version:     0.0.1
" Last Modified: 28 Dec 2010
" Author:      basyura <basyrua at gmail.com>
" Licence:     The MIT License {{{
"     Permission is hereby granted, free of charge, to any person obtaining a copy
"     of this software and associated documentation files (the "Software"), to deal
"     in the Software without restriction, including without limitation the rights
"     to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
"     copies of the Software, and to permit persons to whom the Software is
"     furnished to do so, subject to the following conditions:
"
"     The above copyright notice and this permission notice shall be included in
"     all copies or substantial portions of the Software.
"
"     THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
"     IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
"     FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
"     AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
"     LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
"     OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
"     THE SOFTWARE.
" }}}
"
"
" variables
"
"   let g:unite_hiki_user     = 'user'
"   let g:unite_hiki_password = 'password'
"   let g:unite_hiki_server   = 'http://hiki.server'
" 
" source
"
function! unite#sources#hiki#define()
  return s:unite_source
endfunction
" cache
let s:candidates_cache  = []
"
let s:unite_source      = {}
let s:unite_source.name = 'hiki'
let s:unite_source.default_action = {'common' : 'open'}
let s:unite_source.action_table   = {}

highlight unite_hiki_ok guifg=white guibg=blue
" create list
function! s:unite_source.gather_candidates(args, context)
   
  if !exists('g:unite_hiki_server')
    echoerr 'you need to define g:unite_hiki_server'
  endif

  let option = s:parse_args(a:args)

  if option.exists_param
    let s:candidates_cache = []
  endif

  if !empty(s:candidates_cache)
    return s:candidates_cache
  endif

  if option.q != ''
    call s:info('now searching ' . option.q .  ' ...')
    let list = s:search(option.q)
  elseif option.recent 
    call s:info('now caching recent list ...')
    let list = s:recent()
  else
    call s:info('now caching page list ...')
    let list = s:get_page_list()
  endif

  let s:candidates_cache = 
        \ map(list , '{
        \ "word"         : v:val.word,
        \ "abbr"         : v:val.abbr,
        \ "source"       : "hiki",
        \ "source__hiki" : v:val,
        \ }')
  return s:candidates_cache

endfunction
"
" action table
"
let s:action_table = {}
let s:unite_source.action_table.common = s:action_table
" 
" action - open
"
let s:action_table.open = {'description' : 'open page'}
function! s:action_table.open.func(candidate)
  call s:load_page(a:candidate.source__hiki)
endfunction

"
" get_page_list
"
function! s:get_page_list()
  let res      = s:get(s:server_url() . '/?c=index')
  let ul_inner = s:HtmlUnescape(matchstr(res.content, '<ul>\zs.\{-}\ze</ul>'))
  let list = []
  for v in split(ul_inner , '<li>')
    let pare = {
          \ 'word' : iconv(matchstr(v , '.*>\zs.\{-}\ze</a') , 'euc-jp' , &enc) ,
          \ 'abbr' : iconv(matchstr(v , '.*>\zs.\{-}\ze</a') , 'euc-jp' , &enc) ,
          \ 'link'       : matchstr(v , 'a href="\zs.\{-}\ze\">')
          \ }
    if pare.word != ""
      call add(list , pare)
    endif
  endfor
  return list
endfunction


" from hatena.vim
function! s:HtmlUnescape(string) " HTMLエスケープを解除
    let string = a:string
    while match(string, '&#\d\+;') != -1
        let num = matchstr(string, '&#\zs\d\+\ze;')
        let string = substitute(string, '&#\d\+;', nr2char(num), '')
    endwhile
    let string = substitute(string, '&gt;'   , '>'  , 'g')
    let string = substitute(string, '&lt;'   , '<'  , 'g')
    let string = substitute(string, '&quot;' , '"'  , 'g')
    let string = substitute(string, '&amp;'  , '\&' , 'g')
    return string
endfunction
"
" login
"
function! s:login()
  " check
  if !exists('g:unite_hiki_user') || !exists('g:unite_hiki_password')
    echoerr 'you need to define g:unite_hiki_user and g:unite_hiki_password'
  endif

  call delete(s:cookie_path())
  let url   = s:server_url() . '/?c=login;p=FrontPage'
  let param = {
        \ 'name' : g:unite_hiki_user , 'password' : g:unite_hiki_password , 
        \ 'c' : 'login' , 'p' : ''
        \ }
  let res = s:post(url , param)
endfunction
"
" load page
"
function! s:load_page(source, ... )
  
  call s:info('now loading ...')

  let param   = a:0 > 0 ? a:000[0] : {}
  if !has_key(param , 'force')
    let param.force   = 0
  endif
  if !has_key(param , 'logined')
    let param.logined = 0
  endif

  if !param.logined
   " cookie を消してログインしなおさないと中身が取れないよ
   call s:login()
  endif

  let bufname = 'hiki ' . a:source.word
  let bufno   = bufnr(bufname . "$")
  " 強制上書きまたは隠れバッファ(ls!で表示されるもの)の場合
  " 一度消してから開きなおし
  if param.force || !buflisted(bufname)
  else
    execute 'buffer ' . bufno
    return
  endif

  let url  = s:server_url() . '/?c=edit;p=' . http#escape(a:source.word)
  let res  = s:get(url , {'cookie' : s:cookie_path()})
  let p          = matchstr(res.content , 'name="p"\s*value="\zs[^"]*\ze"')
  let c          = matchstr(res.content , 'name="c"\s*value="\zs[^"]*\ze"')
  let md5hex     = matchstr(res.content , 'name="md5hex"\s*value="\zs[^"]*\ze"')
  let session_id = matchstr(res.content , 'name="session_id"\s*value="\zs[^"]*\ze"')
  let page_title = matchstr(res.content , 'name="page_title"\s*value="\zs[^"]*\ze"')
  let contents   = s:HtmlUnescape(matchstr(res.content, '<textarea.\{-}name="contents"[^>]*>\zs.\{-}\ze</textarea>'))
  let keyword    = s:HtmlUnescape(matchstr(res.content, '<textarea.\{-}name="keyword"[^>]*>\zs.\{-}\ze</textarea>'))

  exec 'edit! ' . substitute(bufname , ' ' , '\\ ' , 'g')
  silent %delete _
  setlocal bufhidden=hide
  setlocal noswapfile
  setlocal filetype=hiki
  " autocmd
  augroup unite-hiki-load-page
    autocmd!
    autocmd BufWriteCmd <buffer> call <SID>update_contents()
  augroup END

  let b:autocmd_update = 1
  let b:data = {
        \ 'p'          : p ,
        \ 'c'          : c , 
        \ 'md5hex'     : md5hex , 
        \ 'session_id' : session_id , 
        \ 'page_title' : page_title , 
        \ 'keyword'    : keyword    ,
        \ 'update_timestamp' : 'on'
        \ }
  for line in split(contents , "\n")
    call append(line('$') , iconv(line , 'euc-jp' , &enc))
  endfor
  " cache source
  let b:unite_hiki_source = a:source
  " clear undo
  call s:clear_undo()
  setlocal nomodified
endfunction
"
" update_contents
"
function! s:update_contents()
  echohl unite_hiki_ok
  if input('update ? (y/n) : ') != 'y'
    return s:info('update was canceled')
  endif
  echohl None

  call s:login()

  let b:data.save       = 'save'
  let b:data.c          = b:data.c
  let b:data.p          = b:data.p
  let b:data.session_id = s:get_session_id()
  let b:data.contents   = s:get_contents()
  " http1.1 だと 100 で変えることがあるので http1.0 でポストする
  let res = s:post(s:server_url() . '/' , b:data)
  let status = split(res.header[0])[1]
  if status == '200' || status == '100'
    call s:load_page(b:unite_hiki_source , {'force' : 1 , 'logined' : 1})
    call s:info(b:data.p . ' - ' . res.header[0])
  else
    echoerr res.header[0]
  endif

endfunction
"
" search
" return [{title , link , description} , ... ]
"
function! s:search(key)
  let url = s:server_url() . '/?c=search&key=' . http#escape(iconv(a:key , &enc , 'euc-jp'))
  let res = s:get(url)
  let ul_inner = s:HtmlUnescape(matchstr(res.content, '<ul>\zs.\{-}\ze</ul>'))
  let list = []
  for v in split(ul_inner , '<li>')
    let pare = {
          \ 'word'        : iconv(matchstr(v , '.*>\zs.\{-}\ze</a') , 'euc-jp' , &enc) ,
          \ 'link'        : matchstr(v , 'a href="\zs.\{-}\ze\">') ,
          \ 'description' : iconv(matchstr(v , '.*\[\zs.\{-}\ze\]') , 'euc-jp' , &enc)
          \ }
    if pare.word != ""
      let pare.abbr = pare.word . ' ' . pare.description
      call add(list , pare)
    endif
  endfor
  return list
endfunction
"
" recent
" return [{title , link , diff_link , user} , ... ]
"
function! s:recent()
  let url = s:server_url() . '/?c=recent'
  let res = s:get(url)
  let ul_inner = s:HtmlUnescape(matchstr(res.content, '<ul>\zs.\{-}\ze</ul>'))
  let list = []
  for v in split(ul_inner , '<li>')
    let pare = {
          \ 'word'      : iconv(matchstr(v , ': <a href=.*>\zs.\{-}\ze</a> ') , 'euc-jp' , &enc) ,
          \ 'link'      : matchstr(v , 'a href="\zs.\{-}\ze\">') ,
          \ 'diff_link' : matchstr(v , '(<a href="\zs.\{-}\ze\">') ,
          \ 'user'      : iconv(matchstr(v , '.*by \zs.\{-}\ze ') , 'euc-jp' , &enc) 
          \ }
    if pare.word != ""
      let pare.abbr = pare.word . ' (' . pare.user . ')'
      call add(list , pare)
    endif
  endfor
  return list
endfunction
"
" - private functions -
"
"
" server_url
"
function! s:server_url()
  return substitute(g:unite_hiki_server , '/$' , '' , '')
endfunction
"
" get
"
function! s:get(url, ...)
  let param    = a:0 > 0 ? a:000[0] : {}
  return unite#hiki#http#get(a:url , param)
endfunction
"
" post
"
function! s:post(url, data)
  let params = {
        \ 'param'  : a:data ,
        \ 'cookie' : s:cookie_path() ,
        \ 'http10' : 1
        \ }
  return unite#hiki#http#post(a:url , params)
endfunction
"
" get session id
"
function! s:get_session_id()
  return split(readfile(s:cookie_path())[4])[6]
endfunction
"
" get contents
"
function! s:get_contents()
  return iconv(join(getline(1 , '$') , "\n") , &enc , 'euc-jp') . "\n"
endfunction
"
"
"
function! s:cookie_path()
  if exists('g:unite_hiki_cookie')
    return g:unite_hiki_cookie
  endif
  if exists('s:unite_hiki_cookie')
    return s:unite_hiki_cookie
  endif
  let s:unite_hiki_cookie = tempname()
  return s:unite_hiki_cookie
endfunction
"
" clear undo
"
function! s:clear_undo()
  let old_undolevels = &undolevels
  setlocal undolevels=-1
  execute "normal a \<BS>\<Esc>"
  let &l:undolevels = old_undolevels
  unlet old_undolevels
endfunction
"
"
"
function! s:parse_args(args)
  let convert_def = {
        \ '!'   : 'forcely'
        \ }
  let option = {
    \ 'exists_param' : 0 ,
    \ 'forcely'      : 0 , 
    \ 'recent'       : 0 , 
    \ 'q'            : ''
    \ }
  let exists_param = 0
  for arg in a:args
    let exists_param = 1
    let v = split(arg , '=')
    let v[0] = has_key(convert_def , v[0]) ? convert_def[v[0]] : v[0]
    let option[v[0]] = len(v) == 1 ? 1 : v[1]
  endfor
  let option.exists_param = exists_param
  return option
endfunction
"
" echo info log
"
function! s:info(msg)
  echohl unite_hiki_ok | echo a:msg | echohl None
  return 1
endfunction
"
" echo error log
"
function! s:error(msg)
  echohl ErrorMsg | echo a:msg | echohl None
  return 0
endfunction

" Version:     0.0.1
" Last Modified: 27 Dec 2010
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
"

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
" create list
function! s:unite_source.gather_candidates(args, context)
  " parse args
  "let option = unite#yarm#parse_args(a:args)
  " clear cache. option に判定メソッドを持たせたい
  "if len(option) != 0
  "  let s:candidates_cache = []
  "endif

  " return cache if exist
  if !empty(s:candidates_cache)
    return s:candidates_cache
  endif
  " cache issues
  call unite#yarm#info('now caching issues ...')
  
  if len(a:args) == 1
    let list = s:search(a:args[0])
  else
    let list = s:get_page_list()
  endif

  let s:candidates_cache = 
        \ map(list , '{
        \ "word"         : v:val.unite_word,
        \ "abbr"         : v:val.unite_abbr,
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
          \ 'unite_word' : iconv(matchstr(v , '.*>\zs.\{-}\ze</a') , 'euc-jp' , &enc) ,
          \ 'unite_abbr' : iconv(matchstr(v , '.*>\zs.\{-}\ze</a') , 'euc-jp' , &enc) ,
          \ 'link'       : matchstr(v , 'a href="\zs.\{-}\ze\">')
          \ }
    if pare.unite_word != ""
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
  call delete(g:hiki_cookie)
  let url   = s:server_url() . '/?c=login;p=FrontPage'
  let param = {
        \ 'name' : g:hiki_user , 'password' : g:hiki_password , 
        \ 'c' : 'login' , 'p' : ''
        \ }
  let res = s:post(url , param)
endfunction
"
" load page
"
function! s:load_page(source, ... )
  " cookie を消してログインしなおさないと中身が取れないよ
  call s:login()

  let param   = a:0 > 0 ? a:000[0] : {'force' : 0}

  let bufname = 'hiki ' . a:source.unite_word
  let bufno   = bufnr(bufname . "$")
  " 強制上書きまたは隠れバッファ(ls!で表示されるもの)の場合
  " 一度消してから開きなおし
  if param.force || !buflisted(bufname)
  else
    execute 'buffer ' . bufno
    return
  endif

  let url  = s:server_url() . '/?c=edit;p=' . http#escape(a:source.unite_word)
  let res  = s:get(url , {'cookie' : g:hiki_cookie})
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
  if !exists('b:autocmd_update')
    autocmd BufWriteCmd <buffer> call <SID>update_contents()
  endif
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
  call unite#yarm#clear_undo()
  setlocal nomodified
endfunction
"
" update_contents
"
function! s:update_contents()
  echohl yarm_ok
  if input('update ? (y/n) : ') != 'y'
    return unite#yarm#info('update was canceled')
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
    echo 'OK'
    call s:load_page(b:unite_hiki_source , {'force' : 1})
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
          \ 'unite_word'  : iconv(matchstr(v , '.*>\zs.\{-}\ze</a') , 'euc-jp' , &enc) ,
          \ 'link'        : matchstr(v , 'a href="\zs.\{-}\ze\">') ,
          \ 'description' : iconv(matchstr(v , '.*\[\zs.\{-}\ze\]') , 'euc-jp' , &enc)
          \ }
    if pare.unite_word != ""
      let pare.unite_abbr = pare.unite_word . ' ' . pare.description
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
          \ 'title'     : iconv(matchstr(v , ': <a href=.*>\zs.\{-}\ze</a> ') , 'euc-jp' , &enc) ,
          \ 'link'      : matchstr(v , 'a href="\zs.\{-}\ze\">') ,
          \ 'diff_link' : matchstr(v , '(<a href="\zs.\{-}\ze\">') ,
          \ 'user'      : iconv(matchstr(v , '.*by \zs.\{-}\ze ') , 'euc-jp' , &enc) 
          \ }
    call add(list , pare)
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
  return substitute(g:hiki_url , '/$' , '' , '')
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
        \ 'cookie' : g:hiki_cookie ,
        \ 'http10' : 1
        \ }
  return unite#hiki#http#post(a:url , params)
endfunction
"
" get session id
"
function! s:get_session_id()
  return split(readfile(g:hiki_cookie)[4])[6]
endfunction
"
" get contents
"
function! s:get_contents()
  return iconv(join(getline(1 , '$') , "\n") , &enc , 'euc-jp') . "\n"
endfunction

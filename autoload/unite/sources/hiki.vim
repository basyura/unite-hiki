" hiki source for unite.vim
" Version:     0.0.1
" Last Modified: 19 Dec 2010
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
    "let s:candidates_cache = []
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
  let res      = http#get(g:hiki_url . '/?c=index')
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
  let url   = g:hiki_url . '?c=login'
  let param = {
        \ 'name' : g:hiki_user , 'password' : g:hiki_password , 
        \ 'c' : 'login' , 'p' : ''
        \ }
  let res = unite#hiki#http#post(url , 
              \ {'param' : param , 'cookie' : g:hiki_cookie , 'location' : 0})
endfunction
"
" load page
"
function! s:load_page(source, ... )
  " cookie を消してログインしなおさないと中身が取れないよ
  call s:login()

  let param   = a:0 > 0 ? a:000[0] : {'force' : 0}

  let bufname = 'hiki_' . a:source.unite_word
  let bufno   = bufnr(bufname . "$")
  " 強制上書きまたは隠れバッファ(ls!で表示されるもの)の場合
  " 一度消してから開きなおし
  if param.force || !buflisted(bufname)
  else
    execute 'buffer ' . bufno
    return
  endif

  let url  = g:hiki_url . '?c=edit;p=' . http#escape(a:source.unite_word)
  let res  = unite#hiki#http#get(url , {'cookie' : g:hiki_cookie})
  let p          = matchstr(res.content , 'name="p"\s*value="\zs[^"]*\ze"')
  let c          = matchstr(res.content , 'name="c"\s*value="\zs[^"]*\ze"')
  let md5hex     = matchstr(res.content , 'name="md5hex"\s*value="\zs[^"]*\ze"')
  let session_id = matchstr(res.content , 'name="session_id"\s*value="\zs[^"]*\ze"')
  let page_title = matchstr(res.content , 'name="page_title"\s*value="\zs[^"]*\ze"')
  let contents   = s:HtmlUnescape(matchstr(res.content, '<textarea.\{-}name="contents"[^>]*>\zs.\{-}\ze</textarea>'))
  let keyword    = s:HtmlUnescape(matchstr(res.content, '<textarea.\{-}name="keyword"[^>]*>\zs.\{-}\ze</textarea>'))

  exec 'edit! ' . bufname
  silent %delete _
  setlocal bufhidden=hide
  setlocal noswapfile
  setlocal fileformat=unix
  if !exists('b:autocmd_update')
    autocmd BufWriteCmd <buffer> call <SID>update_contents()
  endif
  let b:autocmd_update = 1
"  setfiletype hiki
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

  let url  = g:hiki_url . '?c=edit;p=' . b:data.p
  let b:data.save      = 'Save'
  let b:data.contents  = iconv(join(getline(1 , '$') , "\n") , 
                                  \ &enc , 'euc-jp') . "\n"

  let res = unite#hiki#http#post(url , 
              \ {'param' : b:data , 'cookie' : g:hiki_cookie , 'location' : 0})

  echo 'OK'

  call s:load_page(b:unite_hiki_source , {'force' : 1})

endfunction
"
" search
" return [{title , link , description} , ... ]
"
function! s:search(key)
  let url = g:hiki_url . '/?c=search&key=' . http#escape(iconv(a:key , &enc , 'euc-jp'))
  let res = http#get(url)
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
  let url = g:hiki_url . '/?c=recent'
  let res = unite#hiki#http#get(url)
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

"call s:login()
"call s:edit('bash')
"for pare in s:get_page_list()
  "echo pare.title . ' ' . pare.link
"endfor
"for pare in s:search('ruby')
  "echo pare.title . ' ' . pare.link . ' ' . pare.description
"endfor
"for pare in s:recent()
  "echo pare.title . ' ' . pare.link . ' ' . pare.user . ' ' . pare.diff_link
"endfor

"let url  = g:hiki_url . '?c=login'
"let param = {
      "\ 'name' : g:hiki_user , 'password' : g:hiki_password , 
      "\ 'c' : 'login' , 'p' : ''
      "\ }
"let res = unite#hiki#http#post(url , {'param' : param , 'cookie' : 'd:/cookie' , 'location' : 0})
"echo iconv(res.content , 'euc-jp' , &enc)

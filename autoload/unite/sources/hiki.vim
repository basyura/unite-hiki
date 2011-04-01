" Version:     0.0.1
" Last Modified: 01 Apr 2011
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
"
highlight unite_hiki_ok guifg=white guibg=blue
" 
" source
"
function! unite#sources#hiki#define()
  return [
        \ s:source_list   , 
        \ s:source_search ,
        \ s:source_recent ,
        \ ]
endfunction

"function! unite#sources#hiki#define()
"  return map(['hiki' , 'hiki/list'  , 'hiki/search']  , '{
"      \ "name"           : v:val  ,
"      \ "default_action" : {"common" : "open"},
"      \ "action_table"   : {"common" : s:action_table}
"      \ }')
"endfunction
"
let s:action_table = {'open' : {'description' : 'open page'}}
function! s:action_table.open.func(candidate)
  call s:load_page(a:candidate)
endfunction

let s:source_list = {
      \ 'name'           : 'hiki/list' ,
      \ 'description'    : 'candidates from hiki page list' ,
      \ 'default_action' : {'common' : 'open'} ,
      \ 'action_table'   : {'common' : s:action_table}
      \ }

let s:source_search = {
      \ 'name'           : 'hiki/search' ,
      \ 'description'    : 'candidates from hiki search page list' ,
      \ 'default_action' : {'common' : 'open'} ,
      \ 'action_table'   : {'common' : s:action_table}
      \ }

let s:source_recent = {
      \ 'name'           : 'hiki/recent' ,
      \ 'description'    : 'candidates from hiki recent page list' ,
      \ 'default_action' : {'common' : 'open'} ,
      \ 'action_table'   : {'common' : s:action_table}
      \ }

function! s:source_list.gather_candidates(args, context)
  return s:get_page_list()
endfunction

function! s:source_list.change_candidates(args, context)
  if a:context.input == ''
    return []
  endif
  let input = substitute(a:context.input, '\*', '', 'g')
  return [{
        \ 'word'              : input  ,
        \ 'abbr'              : '[new page] ' . input ,
        \ 'source__link'      : unite#hiki#http#escape(input) ,
        \ 'source__is_exists' : 0
        \ }]
endfunction

function! s:source_search.gather_candidates(args, context)
  if len(a:args) == 0
    call s:error('need keyword : Unite hiki/search:keyword')
    return []
  end
  return s:to_candidates(s:search(join(a:args , ' ')) , 'hiki/search')
endfunction

function! s:source_recent.gather_candidates(args, context)
  return s:recent()
endfunction

function! s:to_candidates(list, source_name)
  return map(a:list , '{
        \ "word"              : v:val.word,
        \ "abbr"              : v:val.abbr,
        \ "source"            : a:source_name,
        \ "source__link"      : v:val.link,
        \ "source__is_exists" : 1
        \ }')
endfunction

"
" get_page_list
"
function! s:get_page_list()
  let res   = s:get(s:server_url() . '/?c=index')
  let inner = s:HtmlUnescape(matchstr(res.content, '<ul>\zs.\{-}\ze</ul>'))
  let list  = []
  for v in split(inner , '<li>')
    let source = {
          \ 'word' : iconv(matchstr(v , '.*>\zs.\{-}\ze</a') , 'euc-jp' , &enc) ,
          \ 'abbr' : iconv(matchstr(v , '.*>\zs.\{-}\ze</a') , 'euc-jp' , &enc) ,
          \ 'link' : matchstr(v , 'a href="\./?\zs.\{-}\ze\">')
          \ }
    if source.link == ''
      let source.link = 'FrontPage'
    endif
    if source.word != ""
      call add(list , source)
    endif
  endfor
  return s:to_candidates(list , 'hiki/list')
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
"
"
function! s:load_page_with_page_name(page_name)
  for candidate in s:get_page_list()
    if candidate.word == a:page_name
      call s:load_page(candidate)
      return
    endif
  endfor
  call s:error("no matched : " . a:page_name)
endfunction
"
" load page
"
function! s:load_page(candidate, ... )
  
  call s:info('now loading ...')

  let param   = a:0 > 0 ? a:000[0] : {}
  if !has_key(param , 'force')
    let param.force   = 0
  endif
  if !has_key(param , 'logined')
    let param.logined = 0
  endif

  if !param.logined
   call s:login()
  endif

  let bufname = a:candidate.word . ' (hiki)'
  let bufno   = bufnr(bufname . "$")
  " 強制上書きまたは隠れバッファ(ls!で表示されるもの)の場合
  " 一度消してから開きなおし
  if param.force || !buflisted(bufname)
  else
    execute 'buffer ' . bufno | redraw | call s:info('')
    return
  endif

  let url  = s:server_url() . '/?c=edit;p=' . a:candidate.source__link
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
  if !exists("b:unite_hiki_autocmd_load_page")
    autocmd BufWriteCmd <buffer> call <SID>update_contents()
    let b:unite_hiki_autocmd_load_page = 1
  endif

  let b:data = {
        \ 'word'       : a:candidate.word ,
        \ 'p'          : p ,
        \ 'c'          : c , 
        \ 'md5hex'     : md5hex , 
        \ 'session_id' : session_id , 
        \ 'page_title' : page_title , 
        \ 'keyword'    : keyword    ,
        \ 'update_timestamp' : 'on' ,
        \ 'is_exists'  : a:candidate.source__is_exists
        \ }
  for line in split(contents , "\n")
    call append(line('$') , iconv(line , 'euc-jp' , &enc))
  endfor
  " cache source
  let b:unite_hiki_candidate = a:candidate
  " clear undo
  call s:clear_undo() | setlocal nomodified | redraw | call s:info('')
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
  let res    = s:post(s:server_url() . '/' , b:data)
  let status = split(res.header[0])[1]
  " 更新に失敗した場合はメッセージを通知して終了
  if status != '200'
    return s:error(res.header[0])
  end
  if res.content !~ '<meta http-equiv="refresh" content='
    return s:error('update error. maybe conflict.')
  endif
  " 削除の場合は閉じた上で候補の一覧から削除する
  if b:data.is_exists && b:data.contents == ''
    " 表示されない
    call s:info(b:data.word . ' is deleted - ' . res.header[0])
    bd!
    return
  endif
  " 新規の場合は一覧に追加する
  if !b:data.is_exists
    let source = {
          \ 'word'              : b:data.word ,
          \ 'abbr'              : b:data.word ,
          \ 'source'            : 'hiki' ,
          \ 'source__link'      : unite#hiki#http#escape(b:data.word) ,
          \ 'source__is_exists' : 1 ,
          \ }
    call s:load_page(source , {'force' : 1 , 'logined' : 1})
    call s:info(b:data.word . ' is created - ' . res.header[0])
    return
  endif
  " 通常更新
  call s:load_page(b:unite_hiki_candidate , {'force' : 1 , 'logined' : 1})
  call s:info(b:data.word . ' - ' . res.header[0])

endfunction
"
" search
" return [{title , link , description} , ... ]
"
function! s:search(key)
  let url   = s:server_url() . '/?c=search&key=' . http#escape(iconv(a:key , &enc , 'euc-jp'))
  let res   = s:get(url)
  let inner = s:HtmlUnescape(matchstr(res.content, '<ul>\zs.\{-}\ze</ul>'))
  let list  = []
  for v in split(inner , '<li>')
    let source = {
          \ 'word'        : iconv(matchstr(v , '.*>\zs.\{-}\ze</a')    , 'euc-jp' , &enc) ,
          \ 'link'        : matchstr(v , 'a href="\./?.*p=\zs.\{-}\ze&.*">') ,
          \ 'description' : iconv(matchstr(v , '.*\[\zs.\{-}\ze\]')    , 'euc-jp' , &enc)
          \ }
    if source.link == ''
      let source.link = 'FrontPage'
    endif
    if source.word != ""
      let source.abbr = s:ljust(source.word , 15) . ' - ' . source.description
      call add(list , source)
    endif
  endfor
  return list
endfunction
"
" recent
" return [{title , link , diff_link , user} , ... ]
"
function! s:recent()
  let res   = s:get(s:server_url() . '/?c=recent')
  let inner = s:HtmlUnescape(matchstr(res.content, '<ul>\zs.\{-}\ze</ul>'))
  let list  = []
  for v in split(inner , '<li>')
    let source = {
          \ 'word'      : iconv(matchstr(v , ': <a href=.*>\zs.\{-}\ze</a> ') , 'euc-jp' , &enc) ,
          \ 'link'      : matchstr(v , '<a href="\./?\=\zs.\{-}\ze\">') ,
          \ 'diff_link' : matchstr(v , '(<a href="\zs.\{-}\ze\">') ,
          \ 'user'      : iconv(matchstr(v , '.*by \zs.\{-}\ze ') , 'euc-jp' , &enc) 
          \ }
    if source.link == ''
      let source.link = 'FrontPage'
    endif
    if source.word != ""
      let source.abbr = source.word . ' (' . source.user . ')'
      call add(list , source)
    endif
  endfor
  return s:to_candidates(list , 'hiki/recent')
endfunction
"
" autocmd
"
augroup unite-hiki-filetype
  autocmd!
  autocmd FileType hiki call s:hiki_settings()
augroup END
"
"
"
function s:hiki_settings()
  nmap <silent> <buffer> <CR> :call <SID>hiki_buffer_enter_action()<CR>
endfunction
"
"
"
function s:hiki_buffer_enter_action()
  let matched = matchlist(expand('<cWORD>') , 'https\?://\S\+')
  if len(matched) != 0
    let url = s:erase_blanket(matched[0])
    echohl yarm_ok | execute "OpenBrowser " . url | echohl None
    return
  endif
  " get syntax id
  let hiid = synIDattr(synID(line('.'),col('.'),1),'name')
  " open issue
  if hiid =~ 'unite_hiki_page_link' || hiid =~ 'unite_hiki_page_block'
    " 正規表現で切り出せなかった
    let page = s:erase_blanket(expand('<cWORD>'))
    call s:load_page_with_page_name(page)
  else
    execute "normal! \n"
  endif
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
  let param = a:0 > 0 ? a:000[0] : {}
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
  return iconv(join(getline(1 , '$') , "\n") , &enc , 'euc-jp')
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
"
" padding  ljust
"
function! s:ljust(str, size, ...)
  let str = a:str
  let c   = a:0 > 0 ? a:000[0] : ' '
  while 1
    if strwidth(str) >= a:size
      return str
    endif
    let str .= c
  endwhile
  return str
endfunction
"
"
"
function! s:erase_blanket(word)
   return substitute(substitute(a:word , "^[[" , "" , "") ,
                   \ "]]$" , "" , "")
endfunction

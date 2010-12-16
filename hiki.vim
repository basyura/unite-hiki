" unite-hiki
" hiki の各ページを RU できる unite plugin
"
" from hatena.vim
function! s:HtmlUnescape(string) " HTMLエスケープを解除
    let string = a:string
    while match(string, '&#\d\+;') != -1
        let num = matchstr(string, '&#\zs\d\+\ze;')
        let string = substitute(string, '&#\d\+;', nr2char(num), '')
    endwhile
    let string = substitute(string, '&gt;',   '>', 'g')
    let string = substitute(string, '&lt;',   '<', 'g')
    let string = substitute(string, '&quot;', '"', 'g')
    let string = substitute(string, '&amp;',  '\&', 'g')
    return string
endfunction
"
" login
"
function! s:login()
  let url   = g:hiki_url . '?c=login'
  let param = {
        \ 'name' : g:hiki_user , 'password' : g:hiki_password , 
        \ 'c' : 'login' , 'p' : ''
        \ }
  let res = unite#hiki#http#post(url , {'param' : param , 'cookie' : 'd:/cookie' , 'location' : 0})
  "echo res.content
endfunction
"
" edit
"
function! s:edit(page)
  let url  = g:hiki_url . '?c=edit;p=' . a:page
  let res  = unite#hiki#http#get(url , {'cookie' : g:hiki_cookie})
  "echo res.content
  let p          = matchstr(res.content , 'name="p"\s*value="\zs[^"]*\ze"')
  let c          = matchstr(res.content , 'name="c"\s*value="\zs[^"]*\ze"')
  let md5hex     = matchstr(res.content , 'name="md5hex"\s*value="\zs[^"]*\ze"')
  let session_id = matchstr(res.content , 'name="session_id"\s*value="\zs[^"]*\ze"')
  let page_title = matchstr(res.content , 'name="page_title"\s*value="\zs[^"]*\ze"')
  let contents   = s:HtmlUnescape(matchstr(res.content, '<textarea.\{-}name="contents"[^>]*>\zs.\{-}\ze</textarea>'))
  let keyword    = s:HtmlUnescape(matchstr(res.content, '<textarea.\{-}name="keyword"[^>]*>\zs.\{-}\ze</textarea>'))

  exec 'edit! hiki'
  silent %delete _
  setlocal bufhidden=hide
  setlocal noswapfile
"  setlocal fileencoding=euc-jp
  setlocal fileformat=unix
  if !exists('b:autocmd_put_issue')
    autocmd BufWriteCmd <buffer> call <SID>update_contents()
  endif
  let b:autocmd_put_issue = 1
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
endfunction
"
" update_contents
"
function! s:update_contents()
  let url  = g:hiki_url . '?c=edit;p=' . b:data.p
  let b:data.save      = 'Save'
  let b:data.contents  = iconv(join(getline(1 , '$') , "\n") , 
                                  \ &enc , 'euc-jp')
  let res = unite#hiki#http#post(url , {'param' : b:data , 'cookie' : g:hiki_cookie , 'location' : 0})

endfunction
"
" get_page_list
" return [{title , link} , ... ]
"
function! s:get_page_list()
  let res      = unite#hiki#http#get(g:hiki_url . '/?c=index')
  let ul_inner = s:HtmlUnescape(matchstr(res.content, '<ul>\zs.\{-}\ze</ul>'))
  let list = []
  for v in split(ul_inner , '<li>')
    let pare = {
          \ 'title' : iconv(matchstr(v , '.*>\zs.\{-}\ze</a') , 'euc-jp' , &enc) ,
          \ 'link'  : matchstr(v , 'a href="\zs.\{-}\ze\">')
          \ }
    call add(list , pare)
  endfor
  return list
endfunction
"
" search
" return [{title , link , description} , ... ]
"
function! s:search(key)
  let url = g:hiki_url . '/?c=search&key=' . unite#hiki#http#escape(iconv(a:key , &enc , 'euc-jp'))
  let res = unite#hiki#http#get(url)
  let ul_inner = s:HtmlUnescape(matchstr(res.content, '<ul>\zs.\{-}\ze</ul>'))
  let list = []
  for v in split(ul_inner , '<li>')
    let pare = {
          \ 'title' : iconv(matchstr(v , '.*>\zs.\{-}\ze</a') , 'euc-jp' , &enc) ,
          \ 'link'  : matchstr(v , 'a href="\zs.\{-}\ze\">') ,
          \ 'description' : iconv(matchstr(v , '.*\[\zs.\{-}\ze\]') , 'euc-jp' , &enc)
          \ }
    call add(list , pare)
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

call s:login()
call s:edit('bash')
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



if exists('b:current_syntax')
  finish
endif


setlocal conceallevel=2
setlocal concealcursor=nc

syntax match unite_hiki_page_link "\[\[.\{-1,}\]\]" contains=unite_hiki_page_block
syntax match unite_hiki_page_block /\[\[/ contained conceal
syntax match unite_hiki_page_block /\]\]/ contained conceal

syntax match unite_hiki_plugin "{{.\{-1,}}}"

syntax match unite_hiki_link       "\<http://\S\+"
syntax match unite_hiki_link       "\<https://\S\+"

syntax match unite_hiki_title1      "^!.*"        contains=unite_hiki_title1_mark
syntax match unite_hiki_title1_mark "^!\s*"    contained conceal
syntax match unite_hiki_title2      "^!!.*"       contains=unite_hiki_title2_mark
syntax match unite_hiki_title2_mark "^!!\s*"   contained conceal
syntax match unite_hiki_title3      "^!!!.*"      contains=unite_hiki_title3_mark
syntax match unite_hiki_title3_mark "^!!!\s*"  contained conceal


syntax match unite_hiki_pre  "^ \zs.*\ze"
syntax region unite_hiki_pre_block start="<<<"  end=">>>"

highlight default link unite_hiki_page_link  Underlined
highlight default link unite_hiki_page_block Statement

highlight default link unite_hiki_link       Underlined
highlight unite_hiki_title1  guifg=orange  gui=reverse
highlight unite_hiki_title2  guifg=orange  gui=underline
highlight unite_hiki_title3  guifg=orange

highlight unite_hiki_pre        guifg=#ffbbf0
highlight unite_hiki_pre_block  guifg=#ffbbf0

highlight unite_hiki_plugin guifg=#ffbbf0
highlight unite_hiki_ok guifg=white guibg=blue

let b:current_syntax = 'hiki'

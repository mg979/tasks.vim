" ========================================================================###
" Description: Task tags handling
" File:        tags.vim
" Author:      Gianmaria Bajo <mg1979@git.gmail.com>
" License:     MIT
" Created:     dom 22 novembre 2020 07:30:02
" Modified:    dom 22 novembre 2020 07:30:02
" ========================================================================###

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Tasks tags
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

function! tasks#tags#apply(name, reset) abort
    if a:reset
        call tasks#tags#unset()
    elseif !empty(a:name)
        call tasks#tags#set(a:name)
    endif
    call tasks#tags#current()
endfunction

""
" Echo current tag in the command line.
""
function! tasks#tags#current() abort
    let tag = tasks#tags#get()
    redraw
    echon s:ut.badge() 'current tag is: ' s:ut.color(tag)
endfunction

""
" Return current tag.
""
function! tasks#tags#get() abort
    return g:tasks['__tag__']
endfunction

""
" Set tag to a new value.
""
function! tasks#tags#set(tag) abort
    let g:tasks['__tag__'] = a:tag
endfunction

""
" Reset project tag to default.
""
function! tasks#tags#unset() abort
    let g:tasks['__tag__'] = 'default'
endfunction

""
" Command line completion for tasks tags.
""
function! tasks#tags#complete(A, C, P) abort
    try
        return filter(sort(s:get_know_tags()), 'v:val=~#a:A')
    catch
        return []
    endtry
endfunction

""
" Get the list of tags names that are known globally or for current
" project.
""
function! s:get_know_tags() abort
    " call tasks#get()
    return g:tasks['__known_tags__']
endfunction

""
" Loop among available tags.
""
function! tasks#tags#loop() abort
    call tasks#get(1)
    try
        let tags = s:get_know_tags()
        let curr = index(tags, g:tasks['__tag__'])
        let new  = (curr + 1) % len(tags)
        call tasks#tags#set(tags[new])
    catch
    endtry
    call tasks#tags#current()
endfunction



"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

let s:ut = tasks#util#init()

" vim: et sw=4 ts=4 sts=4 fdm=indent fdn=1

" ========================================================================###
" Description: Task profiles handling
" File:        profiles.vim
" Author:      Gianmaria Bajo <mg1979@git.gmail.com>
" License:     MIT
" Created:     dom 22 novembre 2020 07:30:02
" Modified:    dom 22 novembre 2020 07:30:02
" ========================================================================###

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Tasks profiles
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

function! tasks#profiles#apply(name, reset) abort
    if a:reset
        call tasks#profiles#unset()
    elseif !empty(a:name)
        call tasks#profiles#set(a:name)
    endif
    call tasks#profiles#current()
endfunction

""
" Echo current profile in the command line.
""
function! tasks#profiles#current() abort
    let profile = tasks#profiles#get()
    redraw
    echon s:ut.badge() 'current profile is: ' s:ut.color(profile)
endfunction

""
" Return current profile.
""
function! tasks#profiles#get() abort
    return g:tasks['__profile__']
endfunction

""
" Set profile to a new value.
""
function! tasks#profiles#set(profile) abort
    let g:tasks['__profile__'] = a:profile
endfunction

""
" Reset project profile to default.
""
function! tasks#profiles#unset() abort
    let g:tasks['__profile__'] = 'default'
endfunction

""
" Command line completion for tasks profiles.
""
function! tasks#profiles#complete(A, C, P) abort
    try
        return filter(sort(s:get_know_profiles()), 'v:val=~#a:A')
    catch
        return []
    endtry
endfunction

""
" Get the list of profiles names that are known globally or for current
" project.
""
function! s:get_know_profiles() abort
    " call tasks#get()
    return g:tasks['__known_tags__']
endfunction

""
" Loop among available profiles.
""
function! tasks#profiles#loop() abort
    call tasks#get(1)
    try
        let profiles = s:get_know_profiles()
        let curr = index(profiles, g:tasks['__profile__'])
        let np   = len(profiles)
        if np > 1
            if curr == np - 1
                let curr = 0
            else
                let curr += 1
            endif
        endif
        call tasks#profiles#set(profiles[curr])
    catch
    endtry
    call tasks#profiles#current()
endfunction



"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

let s:ut = tasks#util#init()

" vim: et sw=4 ts=4 sts=4 fdm=indent fdn=1

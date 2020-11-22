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
    if profile == v:null
        echon s:ut.badge() 'not a managed project'
    else
        echon s:ut.badge() 'current profile is: ' s:ut.color(profile)
    endif
endfunction

""
" Return current profile, or v:null.
""
function! tasks#profiles#get() abort
    let p = tasks#project(0)
    return !empty(p) ? p.profile : v:null
endfunction

""
" Set profile to a new value.
""
function! tasks#profiles#set(profile) abort
    let p = tasks#project(0)
    if !empty(p)
        let p.profile = a:profile
        return v:true
    else
        return v:false
    endif
endfunction

""
" Reset project profile to default.
""
function! tasks#profiles#unset() abort
    let p = tasks#project(0)
    if !empty(p)
        let p.profile = 'default'
        return v:true
    else
        return v:false
    endif
endfunction

""
" Command line completion for tasks profiles.
""
function! tasks#profiles#complete(A, C, P) abort
    try
        return filter(sort(tasks#get().info.profiles), 'v:val=~#a:A')
    catch
        return []
    endtry
endfunction

""
" Loop among available profiles.
""
function! tasks#profiles#loop() abort
    try
        let p = tasks#project(0)
        let curr = index(p.info.profiles, p.profile)
        let np   = len(p.info.profiles)
        if np > 1
            if curr == np - 1
                let curr = 0
            else
                let curr += 1
            endif
        endif
        call tasks#profiles#set(p.info.profiles[curr])
    catch
    endtry
    call tasks#profiles#current()
endfunction



"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

let s:ut = tasks#util#init()

" vim: et sw=4 ts=4 sts=4 fdm=indent fdn=1

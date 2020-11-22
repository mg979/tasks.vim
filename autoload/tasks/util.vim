" ========================================================================###
" Description: common utility functions
" File:        util.vim
" Author:      Gianmaria Bajo <mg1979@git.gmail.com>
" License:     MIT
" Created:     sab 21 novembre 2020 14:51:42
" Modified:    sab 21 novembre 2020 14:51:42
" ========================================================================###

function! tasks#util#init() abort
    return s:Util
endfunction

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

let s:Util = { 'Vars': {} }

let s:v = s:Util.Vars

let s:v.is_windows = has('win32') || has('win64') || has('win16') || has('win95')
let s:uname        = s:v.is_windows ? '' : systemlist('s:uname')[0]
let s:v.is_linux   = s:uname == 'Linux'
let s:v.is_macos   = s:uname == 'Darwin'
let s:v.is_wsl     = exists('$WSLENV')

let s:v.pospat     = '<top>|<bottom>|<left>|<right>'

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

""
" Basename of the working directory.
""
function! s:Util.basedir() abort
    return fnamemodify(getcwd(), ':t')
endfunction


""
" Base filetype.
""
function! s:Util.ft() abort
    return empty(&ft) ? '' : split(&ft, '\.')[0]
endfunction


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" vim: et sw=4 ts=4 sts=4 fdm=marker
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
let s:uname        = s:v.is_windows ? '' : systemlist('uname')[0]
let s:v.is_linux   = s:uname == 'Linux'
let s:v.is_macos   = s:uname == 'Darwin'
let s:v.is_wsl     = exists('$WSLENV')

let s:v.pospat     = '<top>|<bottom>|<left>|<right>|<vertical>'

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

""
" Basename of the working directory.
""
function! s:Util.basedir() abort
    return fnamemodify(expand(getcwd()), ':t')
endfunction


""
" Base filetype.
""
function! s:Util.ft() abort
    return empty(&ft) ? 'noft' : split(&ft, '\.')[0]
endfunction


""
" Badge for messages in the command line.
""
function! s:Util.badge(...) abort
    redraw
    if a:0
        echohl WarningMsg | echon '[tasks] ' | echohl None
    else
        echohl Delimiter  | echon '[tasks] ' | echohl None
    endif
    return ''
endfunction


""
" Echo colored text in the command line.
""
function! s:Util.color(txt) abort
    echohl String | exe 'echon' string(a:txt) | echohl None
    return ''
endfunction


""
" No tasks available for current project/filetye.
""
function! s:Util.no_tasks(prj) abort
    if empty(a:prj) || empty(a:prj.tasks)
        echon self.badge() 'no tasks'
        return v:true
    endif
    return v:false
endfunction



"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Configuration files paths
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

""
" Path for the project configuration.
""
function! s:Util.local_ini() abort
    return getcwd() . '/' . get(g:, 'async_taskfile_local', '.tasks')
endfunction


""
" Path for the global configuration.
""
function! s:Util.global_ini() abort
    if exists('s:global_ini') && s:global_ini != ''
        return s:global_ini
    endif

    let f = get(g:, 'async_taskfile_global', 'tasks.ini')
    let In = { dir -> filereadable(expand(dir).'/'.f) }
    let Is = { dir -> expand(dir).'/'.f }

    if has('nvim')
        let [c, d] = [stdpath('config'), stdpath('data')]
        let s:global_ini =
                    \ In(c)  ? Is(c) :
                    \ In(d)  ? Is(d) :
                    \ In(d .. '/site') ? Is(d .. '/site') : ''
    else
        let s:global_ini =
                    \ In('$HOME/.vim')     ? Is('$HOME/.vim') :
                    \ In('$HOME/vimfiles') ? Is('$HOME/vimfiles') : ''
    endif

    if s:global_ini == ''
        let dir = fnamemodify(expand($MYVIMRC), ':p:h')
        if filereadable(dir . '/' . f)
            let s:global_ini = dir . '/' . f
        endif
    endif
    return s:global_ini
endfunction


""
" Search recursively for a local tasks file in parent directories.
""
function! s:Util.find_root() abort
    return findfile(get(g:, 'async_taskfile_local', '.tasks'))
endfunction


""
" Confirm root change.
""
function! s:Util.change_root(root) abort
    return !empty(a:root) &&
                \ confirm('Change directory to ' . a:root . '?', "&Yes\n&No") == 1
endfunction







"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" vim: et sw=4 ts=4 sts=4 fdm=marker

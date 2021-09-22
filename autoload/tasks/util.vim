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
    return findfile(get(g:, 'async_taskfile_local', '.tasks'), ".;")
endfunction


""
" Path for the global configuration.
""
function! s:Util.global_ini() abort
    if exists('s:global_ini') && s:global_ini != ''
        return s:global_ini
    endif

    let f = get(g:, 'async_taskfile_global', 'tasks.ini')
    let l:In = { dir -> filereadable(expand(dir).'/'.f) }
    let l:Is = { dir -> expand(dir).'/'.f }

    let s:global_ini = has('nvim') &&
                \ l:In(stdpath('data'))  ? l:Is(stdpath('data')) :
                \ l:In('$HOME/.vim')     ? l:Is('$HOME/.vim') :
                \ l:In('$HOME/vimfiles') ? l:Is('$HOME/vimfiles') : ''

    if s:global_ini == ''
        let dir = fnamemodify(expand($MYVIMRC), ':p:h')
        if filereadable(dir . '/' . f)
            let s:global_ini = dir . '/' . f
        endif
    endif
    return s:global_ini
endfunction


""
" Basename of the working directory.
""
function! s:Util.basedir() abort
    return fnamemodify(self.find_root(), ':t')
endfunction


""
" Search recursively for a local tasks file in parent directories.
""
function! s:Util.find_root() abort
    let f = self.local_ini()
    return empty(f) ? '' : fnamemodify(f, ':p:h')
endfunction


""
" Set the working directory for the task.
""
function! s:Util.setwd(dir)
  let tcd = exists(':tcd') == 2 && haslocaldir(-1, 0)
  let lcd = haslocaldir(winnr(), tabpagenr()) == 1
  if lcd
      lcd `=a:dir`
  elseif tcd
      tcd `=a:dir`
  else
      cd `=a:dir`
  endif
endfunction







"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" vim: et sw=4 ts=4 sts=4 fdm=marker

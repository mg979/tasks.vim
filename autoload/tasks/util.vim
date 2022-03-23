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
    return getcwd() . '/.tasks'
endfunction


""
" Reset global ini locations so that they are fetched again.
""
fun! s:Util.reset_paths()
    unlet! s:global_ini
endfun


""
" Path for the global configuration.
""
function! s:Util.global_ini() abort
    if exists('s:global_ini') && s:global_ini isnot v:null
        return s:global_ini
    endif

    let [all, root] = [{'fts': {}}, v:null]

    let [f, d] = ['tasks.ini', 'tasks.d']
    let In = { dir -> filereadable(expand(dir).'/'.f)
                \  || isdirectory(expand(dir).'/'.d) }

    if has('nvim')
        let places = [stdpath('config'),
                    \ stdpath('data'),
                    \ stdpath('data') .. '/site']
    else
        let places = [expand('$HOME/.vim'),
                    \ expand('$HOME/vimfiles'),
                    \ fnamemodify(expand($MYVIMRC), ':p:h')]
    endif

    for path in places
        if In(path)
            let root = path
            break
        endif
    endfor

    if root is v:null
        return v:null
    endif

    if filereadable(root .. '/' .. f)
        let all.base = root .. '/' .. f
    endif
    if isdirectory(root .. '/' .. d)
        for path in glob(root .. '/' .. d .. '/*.tasks', 0, 1)
            let ft = fnamemodify(path, ':t:r')
            let all.fts[ft] = path
        endfor
    endif
    let s:global_ini = all
    return all
endfunction


""
" Search recursively for a local tasks file in parent directories.
""
function! s:Util.find_root() abort
    let f = findfile('.tasks', '.;')
    return f == '' ? '' : fnamemodify(f, ':p:h')
endfunction


""
" Confirm root change.
""
function! s:Util.confirm_change_root(root) abort
    return !empty(a:root) &&
                \ confirm('Change directory to ' . a:root . '?', "&Yes\n&No") == 1
endfunction







"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" vim: et sw=4 ts=4 sts=4 fdm=marker

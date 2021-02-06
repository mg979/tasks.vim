" ========================================================================###
" Description: rotate files in project
" File:        rotate.vim
" Author:      Gianmaria Bajo <mg1979@git.gmail.com>
" License:     MIT
" Created:     sab 06 febbraio 2021 13:47:03
" Modified:    sab 06 febbraio 2021 13:47:03
" ========================================================================###

function! tasks#rotate#next() abort
    " Edit the next file in the list. {{{1
    let files = s:get_files('next')
    if empty(files)
        return get(g:, 'tasks_rotate_next_fallback', '')
    endif
    let ix = index(files, @%)
    let n = len(files)
    let i = ix + 2 > n ? 1 : ix + 2
    if ix == n - 1 || ix == -1
        let file = files[0]
        let str = printf(":echohl Special | echo '[%d/%d] ' | echohl None | echon execute('file')[1:]", i, n)
        return ":\<C-u>silent edit " . fnameescape(file) . "\<CR>" . str . "\<CR>"
    else
        let file = files[ix + 1]
        let str = printf(":echohl Special | echo '[%d/%d] ' | echohl None | echon execute('file')[1:]", i, n)
        return ":\<C-u>silent edit " . fnameescape(file) . "\<CR>" . str . "\<CR>"
    endif
endfunction "}}}


function! tasks#rotate#prev() abort
    " Edit the previous file in the list. {{{1
    let files = s:get_files('prev')
    if empty(files)
        return get(g:, 'tasks_rotate_prev_fallback', '')
    endif
    let ix = index(files, @%)
    let n = len(files)
    if ix <= 0
        let file = files[-1]
        let str = printf(":echohl Special | echo '[%d/%d] ' | echohl None | echon execute('file')[1:]", n, n)
        return ":\<C-u>silent edit " . fnameescape(file) . "\<CR>" . str . "\<CR>"
    else
        let file = files[ix - 1]
        let str = printf(":echohl Special | echo '[%d/%d] ' | echohl None | echon execute('file')[1:]", ix, n)
        return ":\<C-u>silent edit " . fnameescape(file) . "\<CR>" . str . "\<CR>"
    endif
endfunction "}}}


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Helpers
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

function! s:get_files(type)
    " Return the list of files to rotate. {{{1
    let prj = tasks#project(1)
    if empty(prj)
        if empty(get(g:, 'tasks_rotate_'. a:type .'_fallback', ''))
            echon s:ut.badge() 'not in a managed project'
        endif
        return []
    endif
    if !has_key(prj, 'info') || !has_key(prj.info, 'filerotate')
        if empty(get(g:, 'tasks_rotate_'. a:type .'_fallback', ''))
            echon s:ut.badge() 'files to rotate have not been defined'
        endif
        return []
    endif
    let globs = split(prj.info.filerotate, ',')
    let files = []
    for g in globs
        let files += glob(g, 0, 1)
    endfor
    if empty(files)
        if empty(get(g:, 'tasks_rotate_'. a:type .'_fallback', ''))
            echon s:ut.badge() 'no files to rotate with currently defined globs'
        endif
        return []
    endif
    return files
endfunction "}}}



"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Script variables
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

let s:ut   = tasks#util#init()


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" vim: et sw=4 ts=4 sts=4 fdm=marker

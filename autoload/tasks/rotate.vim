" ========================================================================###
" Description: rotate files in project
" File:        rotate.vim
" Author:      Gianmaria Bajo <mg1979@git.gmail.com>
" License:     MIT
" Created:     sab 06 febbraio 2021 13:47:03
" Modified:    sab 27 febbraio 2021 06:48:47
" ========================================================================###

function! tasks#rotate#file(n) abort
    " Edit the next file in the list. {{{1
    let s:fallback = a:n > 0 ? 'tasks_rotate_next_fallback' : 'tasks_rotate_prev_fallback'
    let file = s:file(a:n)
    if empty(file)
        return get(g:, s:fallback, '')
    endif
    let str = printf(":echohl Special | echo '[%d/%d] ' | echohl None | echon execute('file')[1:]",
                \    file[0], file[1])
    return ":\<C-u>silent edit " . file[2] . "\<CR>" . str . "\<CR>"
endfunction "}}}


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Helpers
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

function! s:get_globs()
    " Return the globs of files to rotate. {{{1
    let prj = tasks#project(1)
    if empty(prj)
        if empty(get(g:, s:fallback, ''))
            echon s:ut.badge() 'not in a managed project'
        endif
        return []
    endif
    if !has_key(prj, 'info') || !has_key(prj.info, 'filerotate')
        if empty(get(g:, s:fallback, ''))
            echon s:ut.badge() 'files to rotate have not been defined'
        endif
        return []
    endif
    return split(prj.info.filerotate, ',')
endfunction "}}}


function! s:get_files()
    " Return the list of files to rotate. {{{1
    let globs = s:get_globs()
    let path = substitute(getcwd(),'[\\/]$','','')
    let files = []
    for g in globs
        let files += split(glob(path."/".g),"\n")
    endfor
    call map(files,'substitute(v:val,"[\\/]$","","")')
    call filter(files,'v:val !~# "[\\\\/]\\.\\.\\=$"')

    if !empty(&wildignore)
        let wildignores = substitute(escape(&wildignore, '~.*$^'), ',', '$\\|', 'g') .'$'
        call filter(files, 'v:val !~# wildignores')
    endif

    if !empty(&suffixes)
        let filter_suffixes = substitute(escape(&suffixes, '~.*$^'), ',', '$\\|', 'g') .'$'
        call filter(files, 'v:val !~# filter_suffixes')
    endif

    if empty(files)
        if empty(get(g:, s:fallback, ''))
            echon s:ut.badge() 'no files to rotate with currently defined globs'
        endif
        return []
    endif
    return files
endfunction "}}}


function! s:file(num) abort
    " Return the file to rotate. {{{1
    let file = expand('%:p')
    if empty(file)
        return []
    endif
    let files = s:get_files()
    if empty(files)
        return []
    endif
    let max = len(files)
    let n = (index(files, file) + a:num) % max
    " [index+1, max, filename]: index and max are used to display current position
    return [n < 0 ? max + n + 1 : n + 1, max, fnameescape(fnamemodify(files[n], ':.'))]
endfunction "}}}


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Script variables
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

let s:ut   = tasks#util#init()


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" vim: et sw=4 ts=4 sts=4 fdm=marker

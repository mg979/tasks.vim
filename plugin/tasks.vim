" ========================================================================///
" Description: Tasks management inspired by asynctasks.vim
" File:        tasks.vim
" Author:      Gianmaria Bajo <mg1979@git.gmail.com>
" Url:         https://
" License:     MIT
" Created:     Fri 11 September 2020 12:41:04
" Modified:    Fri 11 September 2020 12:41:04
" ========================================================================///

" GUARD {{{1
if v:version < 800
    finish
endif

if exists('g:loaded_tasks')
    finish
endif
let g:loaded_tasks = 1
" }}}

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

let g:tasks = {}

command! -nargs=1 -complete=customlist,tasks#complete Task call tasks#run(<q-args>)

command! -bar -bang Tasks call tasks#list(<bang>0)

if get(g:, 'tasks_mappings', 1)
    let s:main = get(g:, 'tasks_main_key', '<F6>')
    exe 'nnoremap <silent>' s:main ':<C-u>call <sid>choose_task()<cr>'
endif

function! s:choose_task() abort
    if &ft == 'vim'
        update
        source %
        redraw
        echo ':source %'
        return
    endif
    echohl Special | echo '<F5>' | echohl None | echon ' project-run'
    echohl Special | echo '<F6>' | echohl None | echon ' project-build'
    echohl Special | echo '<F7>' | echohl None | echon ' file-run'
    echohl Special | echo '<F8>' | echohl None | echon ' file-build'
    echo ''
    let ch = getchar()
    if ch == "\<F5>"
        Task project-run
    elseif ch == "\<F6>"
        Task project-build
    elseif ch == "\<F7>"
        Task file-run
    elseif ch == "\<F8>"
        Task file-build
    else
        redraw
    endif
endfunction




"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" vim: et sw=4 ts=4 sts=4 fdm=marker

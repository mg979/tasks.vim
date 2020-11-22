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

command! -bang -nargs=? -complete=customlist,tasks#profiles TasksProfile call tasks#profile(<q-args>, <bang>0)

nnoremap <silent> <Plug>(Tasks-Choose)      :<C-u>call tasks#choose()<cr>
nnoremap <silent> <Plug>(Tasks-Profiles)    :<C-u>call tasks#loop_profiles()<cr>


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" vim: et sw=4 ts=4 sts=4 fdm=marker

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

command! -nargs=1 -complete=customlist,async#tasks#complete Task call async#tasks#run(<q-args>)



"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" vim: et sw=2 ts=2 sts=2 fdm=marker

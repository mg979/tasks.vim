" ========================================================================///
" Description: Projects loader
" File:        projects.vim
" Author:      Gianmaria Bajo <mg1979@git.gmail.com>
" License:     MIT
" Created:     Sat 19 September 2020 20:16:53
" Modified:    Sat 19 September 2020 20:16:53
" ========================================================================///

" GUARD {{{1
if v:version < 800
    finish
endif

if exists('g:loaded_projects')
    finish
endif
let g:loaded_projects = 1
" }}}

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

let g:projects = {}

command! -nargs=1 -complete=customlist,projects#complete Project call projects#open(<q-args>)


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" vim: et sw=4 ts=4 sts=4 fdm=marker

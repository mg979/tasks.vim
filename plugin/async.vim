" ========================================================================///
" Description: Run asynch commands, output to buffer or quickfix
" Author:      Gianmaria Bajo ( mg1979@git.gmail.com )
" File:        async.vim
" License:     MIT
" Modified:    lun 07 ottobre 2019 07:19:25
" ========================================================================///

"GUARD {{{1
if exists('g:loaded_async')
  finish
endif
let g:loaded_async = 1
"}}}

" System:    Run a shell command asynchronously.
" Echo:      Echo the output of an asynchronous shell command to the command line.
" StopJobs:  Stop all jobs. With a bang, jobs are killed.
" Jobs:      List all running jobs.
" Make:      Run :make asynchronously.
" LMake:     ,,  :lmake   ,,
" Grep:      ,,  :grep    ,,
" LGrep:     ,,  :lgrep   ,,
" GrepAdd:   ,,  :grepadd ,,
" LGrepAdd:  ,,  :grepadd ,,
"
" For Make/Grep commands, with BANG will not jump to the first error/match

command! -nargs=1       System    call async#cmd(<q-args>, 'buffer')
command! -nargs=1       Echo      call async#cmd(<q-args>, 'cmdline')

command! -bang          StopJobs  call async#stop(<bang>0)
command!                Jobs      call async#list()

command! -nargs=? -bang Make      call async#make(<q-args>, {'jump': !<bang>0})
command! -nargs=? -bang LMake     call async#make(<q-args>, {'locl': 1, 'jump': !<bang>0})

command! -nargs=1 -bang Grep      call async#make(<q-args>, {'grep': 1, 'jump': !<bang>0})
command! -nargs=1 -bang LGrep     call async#make(<q-args>, {'grep': 1, 'jump': !<bang>0, 'locl': 1})
command! -nargs=1 -bang GrepAdd   call async#make(<q-args>, {'grep': 1, 'jump': !<bang>0, 'append': 1})
command! -nargs=1 -bang LGrepAdd  call async#make(<q-args>, {'grep': 1, 'jump': !<bang>0, 'locl': 1, 'append': 1})

command! -nargs=1 -complete=customlist,async#tasks#complete Task call async#tasks#run(<q-args>)

" vim: et sw=2 ts=2 sts=2 fdm=marker

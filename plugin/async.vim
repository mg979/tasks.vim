" ========================================================================///
" Description: Run asynch commands
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

" Async:     Run a shell command asynchronously in headless mode.
" AsyncBuf:  Run a shell command asynchronously and print output in a buffer.
" AsyncCmd:  Echo the output of an asynchronous shell command to the command line.
" StopJobs:  Stop all jobs. With a bang, jobs are killed (vim only).
" Jobs:      List all running jobs. List finished jobs with BANG.
" Make:      Run :make asynchronously.
" LMake:     ,,  :lmake   ,,
" Grep:      ,,  :grep    ,,
" LGrep:     ,,  :lgrep   ,,
" GrepAdd:   ,,  :grepadd ,,
" LGrepAdd:  ,,  :grepadd ,,
"
" System, Async and Echo accept a BANG (will write out/err to temp files).
" For Make/Grep commands, with BANG will not jump to the first error/match, and
" will not open the qfix window.

command! -nargs=1 -bang AsyncBuf  call async#cmd(<q-args>, 'buffer', {'writelogs': <bang>0})
command! -nargs=1 -bang AsyncCmd  call async#cmd(<q-args>, 'cmdline', {'writelogs': <bang>0})
command! -nargs=1 -bang Async     call async#cmd(<q-args>, 'headless', {'writelogs': <bang>0})

command! -bang          StopJobs  call async#stop(0, <bang>0)
command! -bang          Jobs      call async#list(<bang>0)
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Command-line completion for ":Make"
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

if executable('awk')
  let s:MakeCompletionCmd =  "make -qp | awk -F':' '/^[a-zA-Z0-9][^$#\/\t=]*:([^=]|$)/ {split($1, targets, / /); for (target in targets) if (targets[target] != \"Makefile\" && !seen[targets[target]]++) print targets[target]}'"

  if has('win32') && executable('sh')
    let s:MakeCompletionCmd = 'sh -c ' .. shellescape(s:MakeCompletionCmd)
  else
    unlet s:MakeCompletionCmd
  endif
endif

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Command-line completion for ":Make"
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

if executable('awk')
  let s:MakeCompletionCmd =  "make -qp | awk -F':' '/^[a-zA-Z0-9][^$#\/\t=]*:([^=]|$)/ {split($1, targets, / /); for (target in targets) if (targets[target] != \"Makefile\" && !seen[targets[target]]++) print targets[target]}'"

  if has('win32') && executable('sh')
    let s:MakeCompletionCmd = 'sh -c ' .. shellescape(s:MakeCompletionCmd)
  else
    unlet s:MakeCompletionCmd
  endif
endif

""=============================================================================
" Function: async#make_complete
" Command-line completion for ":Make"
" @param ...: command-completion-custom arguments
" Returns: list of completion items
""=============================================================================
if exists('s:MakeCompletionCmd')
  " From https://dev.to/pbnj/how-to-get-make-target-tab-completion-in-vim-4mj1
  function! async#make_complete(ArgLead, CmdLine, CursorPos) abort
    if &makeprg == 'make' && exists('s:MakeCompletionCmd')
      " test if 'make' can actually do anything here
      call system('make -q')
      if v:shell_error == 2
        return []
      endif
      let targets = systemlist(s:MakeCompletionCmd)
      return filter(targets, 'v:val =~ "^' .. a:1 .. '" && v:val != "makefile"')
    endif
    return []
  endfunction
else
  " From https://github.com/jiangyinzuo/vimrc/commit/29a7f3f4686c4ea8246c2f149f698fd01d7cdba4
  function! async#make_complete(ArgLead, CmdLine, CursorPos) abort
    if &makeprg !=? 'make'
      return []
    endif
	  let makefiles = glob('[Mm]akefile', 1, 1) + glob('GNUmakefile', 1, 1) +
          \ glob('*.mk', 1, 1)
    if !empty(makefiles) && filereadable(makefiles[0])
	    let makefile = makefiles[0]
	  else
      return []
	  endif
	  let lines = readfile(makefile)
	  let targets = []

	  for line in lines
		  if line =~ '^\w\+:'
			  let target = matchstr(line, '^\w\+')
			  if target =~ '^' . a:ArgLead
				  call add(targets, target)
			  endif
		  endif
	  endfor

	  return uniq(targets)
  endfunction
endif

command! -nargs=? -bang -complete=customlist,async#make_complete Make      call async#qfix(<q-args>, {'nojump': <bang>0})
command! -nargs=? -bang -complete=customlist,async#make_complete LMake     call async#qfix(<q-args>, {'nojump': <bang>0, 'locl': 1})

command! -nargs=1 -bang -complete=compiler Compiler  call async#compiler(<q-args>, {'nojump': <bang>0})
command! -nargs=1 -bang -complete=compiler LCompiler call async#compiler(<q-args>, {'nojump': <bang>0, 'locl': 1})

command! -nargs=1 -bang Grep      call async#qfix(<q-args>, {'nojump': <bang>0, 'grep': 1})
command! -nargs=1 -bang LGrep     call async#qfix(<q-args>, {'nojump': <bang>0, 'grep': 1, 'locl': 1})
command! -nargs=1 -bang GrepAdd   call async#qfix(<q-args>, {'nojump': <bang>0, 'grep': 1, 'append': 1})
command! -nargs=1 -bang LGrepAdd  call async#qfix(<q-args>, {'nojump': <bang>0, 'grep': 1, 'locl': 1, 'append': 1})

" vim: et sw=2 ts=2 sts=2 fdm=marker

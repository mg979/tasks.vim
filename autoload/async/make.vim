"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Command-line completion for ":Make"
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

if executable('awk') && !has('win32')
  let s:MakeCompletionCmd =  "make -qp | awk -F':' "
              \ .. "'/^[a-zA-Z0-9][^$#\/\t=]*:([^=]|$)/ {split($1, targets, / /); "
              \ .. "for (target in targets) if (targets[target] != \"Makefile\""
              \ .. "&& !seen[targets[target]]++) print targets[target]}'"

endif

""=============================================================================
" Function: async#make_complete
" Command-line completion for ":Make"
" @param ...: command-completion-custom arguments
" Returns: list of completion items
""=============================================================================
if exists('s:MakeCompletionCmd')
  " From https://dev.to/pbnj/how-to-get-make-target-tab-completion-in-vim-4mj1
  function! async#make#complete(ArgLead, CmdLine, CursorPos) abort
    if &makeprg !=# 'make'
      return []
    endif
    " test if 'make' can actually do anything here
    call system('make -q')
    if v:shell_error == 2
        return []
    endif
    let targets = systemlist(s:MakeCompletionCmd)
    return filter(targets, 'v:val =~ "^' .. a:ArgLead .. '" && v:val != "makefile"')
  endfunction
else
  " From https://github.com/jiangyinzuo/vimrc/commit/29a7f3f4686c4ea8246c2f149f698fd01d7cdba4
  function! async#make#complete(ArgLead, CmdLine, CursorPos) abort
    if &makeprg !=# 'make'
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
        if target =~ '^' .. a:ArgLead
          call add(targets, target)
        endif
      endif
    endfor

    return uniq(targets)
  endfunction
endif

" vim: et sw=2 ts=2 sts=2 fdm=marker

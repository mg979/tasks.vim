if exists('b:did_ftplugin')
  finish
endif
let b:did_ftplugin = 1

set commentstring=#\ %s

au BufWritePost <buffer> call s:update()

fun! s:update() abort
  if expand('%:t') ==# get(g:, 'async_taskfile_global', 'tasks.ini')
    if has_key(g:tasks, 'global')
      let g:tasks.global.invalidated = 1
    else
      call tasks#global(1)
    endif
    return
  elseif @% != get(g:, 'async_taskfile_local', '.tasks')
    return
  endif
  let prj = expand('%:p:h:t')
  if has_key(g:tasks, prj)
    let g:tasks[prj].invalidated = 1
  else
    call tasks#project(1)
  endif
endfun


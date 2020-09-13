if exists('b:did_ftplugin')
  finish
endif
let b:did_ftplugin = 1

let &commentstring = '# %s'

au BufWritePost <buffer> call s:update()

fun! s:update() abort
  if @% != get(g:, 'async_taskfile_local', '.tasks')
    return
  endif
  let prj = expand('%:p:h:t')
  if has_key(g:tasks, prj)
    let g:tasks[prj].invalidated = 1
  else
    call async#tasks#project(1)
  endif
endfun


exe printf('autocmd BufNewFile,BufReadPost %s,%s set filetype=tasks',
      \    get(g:, 'async_taskfile_local', '.tasks'),
      \    get(g:, 'async_taskfile_global', 'tasks.ini'))


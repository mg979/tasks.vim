exe printf('autocmd BufNewFile,BufReadPost %s set filetype=projects',
            \    get(g:, 'async_taskfile_projects', 'projects.ini'))

" ========================================================================///
" Description: Run asynch commands, output to buffer or quickfix
" Author:      Gianmaria Bajo ( mg1979@git.gmail.com )
" File:        async.vim
" License:     MIT
" Modified:    mar 08 settembre 2020 01:14:28
" ========================================================================///

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Jobs are stored in a global dictionary. To support both vim and nvim,
" incremental ids are used: for each new job, a new id is added to the global
" dictionary. Parallel jobs are possible. For each entry, values are:
"
"  'id': the id
"  'pid': the process id
"  'job': the job object/handle
"  'cmd': the argument for the job starter
"  'opts': options for the job starter
"  'out': initially empty, will be filled with the stdout
"  'err': initially empty, will be filled with the stderr
"  'title': the command as requested by the user
"
" The main function is async#cmd() and it accepts two extra dictionaries that
" can contain options for the job_start() function, and user options that are
" stored in the global dictionary, and that can be used later in custom
" callbacks that must be provided with the user optional dictionary.
" While the user options can contain any field, the job options dict is
" restricted to supported fields (because vim doesn't accept extra fields,
" contrary to nvim).
"
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

let g:async_jobs = {}
let g:async_finished_jobs = {}
let s:id = 0

""=============================================================================
" Function: async#cmd
" Run a shell cmd asynchronously.
" @param cmd:  the command
" @param mode: quickfix, buffer, terminal, external, cmdline or headless
" @param ...:  extra args, can be one or two dicts
"              - first is 'useropts' (user data stored in g:async_jobs[id])
"              - second is 'jobopts' (merged with job options)
" Returns: the id of the job if successful, or 0
""=============================================================================
fun! async#cmd(cmd, mode, ...) abort
  " {{{1
  let useropts = s:user_opts(a:000, a:mode)
  let jobopts = a:0 > 1 ? a:2 : {}
  let expanded = async#expand(a:cmd, get(useropts, 'args', ''))
  let cmd = s:make_cmd(expanded, a:mode, get(jobopts, 'env', {}))
  if empty(cmd)
    return 0
  else
    let opts = extend(s:job_opts(useropts), jobopts)
    let job = s:job_start(cmd, opts, useropts)
    let s:id += 1
    let g:async_jobs[s:id] = extend({
          \ 'job': job, 'cmd': cmd, 'opts': opts,
          \ 'id': s:id, 'pid': s:pid(job), 'title': a:cmd,
          \ 'status': 'running', 'out': [], 'err': [],
          \}, useropts)
    return s:id
  endif
endfun "}}}

""=============================================================================
" Function: async#qfix
" Run a job and populate quickfix with results.
" @param args:  the args for the command
" @param ...:   optional dicts as for async#cmd (useropts, jobopts).
" Returns: the id of the job
""=============================================================================
fun! async#qfix(args, ...) abort
  "{{{1
  let user = extend(s:default_opts(), a:0 ? a:1 : {})
  let user.args = a:args

  " pattern for QuickFixCmdPre and QuickFixCmdPost
  if user.qfautocmd == ''
    let user.qfautocmd = user.grep ? 'grep' : 'make'
  endif

  if user.compiler != '' && s:set_compiler(user) == v:false
    echohl ErrorMsg
    echo 'E666: compiler not supported:' a:opts.compiler
    echohl None
    return v:null
  endif

  exe (user.locl ? 'lclose' : 'cclose')

  let opts = extend({}, a:0 > 1 ? a:2 : {})
  let user.cmd = user.grep ? user.gprg : user.prg
  return async#cmd(user.cmd, 'quickfix', user, opts)
endfun "}}}


""=============================================================================
" Function: async#compiler
" @param args: the compiler name, followed by the optional command
" @param opts: user options
" @param ...:  job options (optional)
" Returns: the id of the job
""=============================================================================
fun! async#compiler(args, opts, ...) abort
  "{{{1
  let args = split(a:args)
  let opts = extend({ 'compiler': args[0] }, a:opts)
  return async#qfix(join(args[1:]), opts, a:0 ? a:1 : {})
endfun "}}}


""=============================================================================
" Function: async#stop
" @param id:   the id of the job to stop. If 0, all jobs are stopped.
" @param ...:  kill rather than terminate. Vim only.
" Returns: the id of the stopped job, or 0 if all jobs are stopped.
""=============================================================================
fun! async#stop(id, ...) abort
  " {{{1
  for id in (a:id ? [a:id] : keys(g:async_jobs))
    if has('nvim')
      let job = str2nr(g:async_jobs[id].job)
      call jobstop(job)
    else
      let job = g:async_jobs[id].job
      call job_stop(job, a:0 ? 'kill' : 'term')
    endif
  endfor
  if a:id
    return a:id
  endif
endfun "}}}


""=============================================================================
" Function: async#list
" List running jobs. Input for id of job to terminate.
""=============================================================================
fun! async#list(finished) abort
  " {{{1
  if a:finished
    call s:list_finished_jobs()
    return
  endif
  let jobs = []
  let limit = &columns - 4 - 9 - 8 - 5
  for id in keys(g:async_jobs)
    try
      let J = g:async_jobs[id]
      let pid = has('nvim') ? jobpid(str2nr(J.job)) : job_info(J.job).process
      call add(jobs, printf('%-4s%-9s%-8s%-'.limit.'s', id, pid, J.status, J.cmd))
    catch
      call async#remove_job(J.job)
    endtry
  endfor
  if empty(jobs)
    echo 'No running jobs'
    return
  endif
  echohl Title
  echo 'id  process  status  command'
  echohl None
  for j in jobs
    echo j
  endfor
  let id = s:prompt_id(0)
  if id && confirm('Stop job with id '. id, "&Yes\n&No") == 1
    call async#stop(id, 0)
  endif
endfun

fun! s:list_finished_jobs() abort
  if empty(g:async_finished_jobs)
    echo 'No finished jobs'
    return
  endif
  echohl Title
  echo 'id  process  status  command'
  echohl None
  let J = g:async_finished_jobs
  for id in sort(keys(J))
    let limit = &columns - 4 - 9 - 8 - 5
    let cmd = async#expand(J[id].cmd)
    echo printf('%-4s%-9s%-8s%-'.limit.'s', id, J[id].pid, J[id].status, cmd)
  endfor
  if s:py != ''
    let id = s:prompt_id(1)
    if id
      call s:job_as_json(g:async_finished_jobs[id])
    endif
  endif
endfun "}}}



"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
"                                                                             "
"                              On exit callbacks                              "
"                                                                             "
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

""=============================================================================
" Function: s:cb_buffer
" Called when the job has exited, creates a buffer with the output.
" @param job:    the job object
"
" job user options specific for buffer mode:
"  'pos'   position     'split', 'top', 'bottom'(default), 'left', 'right'
"  'ft'    filetype     ''
""=============================================================================
fun! s:cb_buffer(job) abort
  " {{{1
  let job = a:job
  let pos = s:get_pos(job, 'bottom')
  let title = substitute(job.title, '%', '%%', 'g')
  let has_out = job.out != [] && job.out != ['']
  let has_err = job.err != [] && job.err != ['']

  if has_out && has_err
    call s:buf_out(job, pos, title)
    call s:buf_err(job, '', title)
  elseif has_out
    call s:buf_out(job, pos, title)
  else
    call s:buf_err(job, pos, title)
  endif
endfun

""
" s:buf_out: create buffer with stdout
""
fun! s:buf_out(job, pos, title) abort
  let job = a:job
  exe a:pos len(job.out) . 'new'
  setlocal bt=nofile bh=wipe noswf nobl

  if get(job, 'ft', '') != ''
    exe 'setfiletype' job.ft
  endif
  silent put =job.out
  call s:buf_trim()
  let &l:statusline = '%#Visual# STDOUT %#StatusLine# ' . a:title
endfun

""
" s:buf_err: create buffer with stderr
""
fun! s:buf_err(job, pos, title) abort
  let job = a:job
  exe a:pos len(job.err) . 'new'
  setlocal bt=nofile bh=wipe noswf nobl
  silent put =job.err
  call s:buf_trim()
  let &l:statusline = '%#ErrorMsg# STDERR %#StatusLine# ' . a:title
endfun

""
" s:buf_trim: remove blanks from top and bottom of buffer
""
fun! s:buf_trim() abort
  if search('\S', 'n')
    while getline('$') == '' | $d _ | endwhile
    while getline(1) == ''   | 1d _ | endwhile
  endif
endfun "}}}


""=============================================================================
" Function: s:cb_make
" Called when the job has exited, populates the qfix list
" @param job:    the job object
""=============================================================================
fun! s:cb_quickfix(job) abort
  " {{{1
  let [job, status] = [a:job, a:job.status]

  " cexpr only wants global errorformat, backup and clear local one
  let [bvar, gvar] = [&l:errorformat, &errorformat]
  setlocal errorformat=
  let &errorformat = job.grep ? job.gfm : job.efm

  exe 'silent doautocmd QuickFixCmdPre' job.qfautocmd
  let cxpr =  job.locl ? 'l' : 'c'
  let cxpr .= job.append ? 'add' : job.nojump ? 'get' : ''
  let cxpr .= 'expr'
  exe cxpr 'job.out + job.err'
  if job.locl
    call setloclist(0, [], 'r', {'title': job.cmd})
  else
    call setqflist([], 'r', {'title': job.cmd})
  endif
  exe 'silent doautocmd QuickFixCmdPost' job.qfautocmd

  " restore errorformat values
  let &l:errorformat = bvar
  let &errorformat = gvar

  " empty list and status > 0 indicates some failure, maybe a wrong command
  let failure = status && (job.locl ? empty(getloclist(1)) : empty(getqflist()))

  if job.grep
    if status > 1 || status == 1 && !empty(job.err)
      call s:echo([job.cmd] + job.err, 'WarningMsg')
    elseif status == 1
      echo 'No results'
    else
      echo 'Found' (len(job.out) + len(job.err)) 'matches'
    endif

  elseif !status && empty(job.err)
    echo "Success:" job.cmd

  elseif failure
    call s:echo(['Exit status: '. status, 'Command: '. job.cmd]
          \ + job.out + job.err, 'WarningMsg')

  elseif job.openqf
    silent redraw!
    exe (job.locl ? 'lopen' : 'botright copen')
    if !job.focus
      wincmd p
    endif

  elseif job.nojump
    call s:echo(['Exit status: '. status, 'Command: '. job.cmd], 'WarningMsg')
  endif
endfun "}}}


""=============================================================================
" Function: s:cb_cmdline
" Echo the output of an asynchronous shell command to the command line.
" @param job:    the job object
""=============================================================================
fun! s:cb_cmdline(job) abort
  " {{{1
  if a:job.status
    if !empty(a:job.err)
      call s:echo(a:job.err, 'ErrorMsg')
    elseif !empty(a:job.out)
      call s:echo(a:job.out, 'ErrorMsg')
    endif
  else
    if !empty(a:job.err)
      call s:echo(a:job.err)
    elseif !empty(a:job.out)
      call s:echo(a:job.out)
    endif
  endif
endfun "}}}


""=============================================================================
" Function: s:cb_headless
" Nothing to do here.
" @param job: the job object
""=============================================================================
fun! s:cb_headless(job)
  " {{{1
  return
endfun "}}}


""=============================================================================
" Function: s:cb_terminal
" Set the terminal window statusline to reflect the exit status.
" @param job: the job object
""=============================================================================
fun! s:cb_terminal(job) abort
  "{{{1
  if !has('nvim')
    let win = bufwinnr(a:job.termbuf)
    if win > 0
      let hl = a:job.status ? '%#ErrorMsg#' : '%#DiffAdd#'
      call setwinvar(win, '&statusline', hl . 'Exit status: ' . a:job.status)
    endif
  endif
endfun "}}}


""=============================================================================
" Function: s:cb_external
" Not much to do here... there's nothing useful that can be saved.
" @param job:    the job object
""=============================================================================
fun! s:cb_external(job) abort
  "{{{1
  return
endfun "}}}



"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
"                                                                             "
"                               Public helpers                                "
"                                                                             "
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

""=============================================================================
" Function: async#expand
" Expand filename modfiers/variables in a given string.
" Include args and perform expansions for the Make/Grep commands.
" @param cmd:  generally &makeprg or &grepprg
" @param args: the command arguments
" Returns: the full command
""=============================================================================
fun! async#expand(cmd, ...) abort
  "{{{1
  " normally a placeholder for args isn't included, we must add it
  if a:0 && match(a:cmd, '\V$*') < 0
    let cmd = a:cmd . ' ' . a:1
  else
    let cmd = substitute(a:cmd, '\$\*', a:0 ? a:1 : '', 'g')
  endif
  if s:is_windows
    let cmd = substitute(cmd, '%\([A-Z_]\+\)%', '$\1', 'g')
  endif
  " from https://github.com/edkolev/vim-amake and
  " from tpope's vim-dispatch https://github.com/tpope/vim-dispatch
  let flags = '<\=\%(:[p8~.htre]\|:g\=s\(.\).\{-\}\1.\{-\}\1\)*'
  let expandable = '\\*\%(<\w\+>\|%\|#\d*\)' . flags
  let cmd = substitute(cmd, expandable, '\=expand(submatch(0))', 'g')
  if s:is_windows
    let cmd = substitute(cmd, '\$\([A-Z_]\+\)\>', '%\1%', 'g')
  endif
  return substitute(cmd, '^\s*\|\s*$', '', 'g')
endfun "}}}


""=============================================================================
" Function: async#remove_job
" Remove a job from the global dictionary, when job has exited.
" @param job: the job to remove
" Returns: the removed entry
""=============================================================================
fun! async#remove_job(job) abort
  "{{{1
  for id in keys(g:async_jobs)
    if g:async_jobs[id].job == a:job
      return remove(g:async_jobs, id)
    endif
  endfor
endfun "}}}


""=============================================================================
" Function: async#finish
" Add finished job to the global table, and store its exit status.
" @param exit_cb: the actual exit callback
" @param job:     the finished job id/object
" @param status:  the exit status of the job
" @param ...:     the event type (passed by nvim, unused)
""=============================================================================
fun! async#finish(exit_cb, job, status, ...) abort
  "{{{1
  let job = s:no_trailing_blanks(async#remove_job(a:job))
  let job.status = a:status
  call a:exit_cb(job)
  if !empty(s:cmdscripts)
    for f in s:cmdscripts
      call timer_start(1000, { t -> delete(f) })
    endfor
  endif
  call s:write_logs(job)
  if !job.keepouts
    unlet job.out
    unlet job.err
  endif
  let job.cmd = type(job.cmd) == v:t_string ? job.cmd : join(job.cmd)
  let g:async_finished_jobs[job.id] = job
endfun "}}}


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
"                                                                             "
"                                   Helpers                                   "
"                                                                             "
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" Default user options {{{1
"  'prg'        makeprg                      default: &makeprg
"  'gprg'       grepprg                      default: &grepprg
"  'efm'        errorformat                  default: &errorformat
"  'gfm'        grepformat                   default: &grepformat
"  'compiler'   run :compiler x              default: ''
"  'qfautocmd'  quickfix autocommands        default: ''
"  'env'        environmental variables      default: {}
"  'grep'       use grepprg, not makeprg     default: 0
"  'locl'       use loclist, not qfix        default: 0
"  'focus'      focus on qf window           default: 0
"  'nojump'     don't jump to first item     default: 0
"  'openqf'     open qfix window             default: 0
"  'nosave'     don't :update before cmd     default: 0
"  'wall'       do :wall before cmd          default: 0
"  'keepouts'   keep out/err in memory       default: 0
"  'writelogs'  write out/err to logfiles    default: 0
"  'outfile'    file where to write out      default: ''
"  'errfile'    file where to write err      default: ''
"  'termonquit' when quitting vim            default: 0
fun! s:default_opts()
  return {
        \ 'prg': &makeprg,
        \ 'gprg': &grepprg,
        \ 'efm': &errorformat,
        \ 'gfm': &grepformat,
        \ 'qfautocmd': '',
        \ 'compiler': '',
        \ 'append': 0,
        \ 'locl': 0,
        \ 'grep': 0,
        \ 'focus': 0,
        \ 'nojump': 0,
        \ 'openqf': 0,
        \ 'nosave': 0,
        \ 'wall': 0,
        \ 'keepouts': 0,
        \ 'writelogs': 0,
        \ 'outfile': '',
        \ 'errfile': '',
        \ 'termonquit': 0,
        \}
endfun

""
" Create dictionary with user options {{{1
" @param args: if not empty, useropts dict is the first element
"              if a third arg is present, it's the exit callback
" @param mode: the mode of the command
" @return: the useropts dictionary
""
function! s:user_opts(args, mode) abort
  let useropts = extend(s:default_opts(), empty(a:args) ? {} : a:args[0])
  let useropts.mode = a:mode
  if len(a:args) > 2
    let useropts.on_exit = a:args[2]
  endif
  if get(useropts, 'wall', 0)
    silent! wall
  elseif !get(useropts, 'nosave', 0)
    update
  endif
  return useropts
endfunction

" Set compiler {{{1
" Execute :compiler, store the options that it set, then restore the old ones.
function! s:set_compiler(opts)
  " store old settings, and also if it's buffer-local or not
  let _prg  = [getbufvar(bufnr(''), '&makeprg'),     &l:makeprg != '']
  let _gprg = [getbufvar(bufnr(''), '&grepprg'),     &l:grepprg != '']
  let _efm  = [getbufvar(bufnr(''), '&errorformat'), &l:errorformat != '']
  let _gfm  = [getbufvar(bufnr(''), '&grepformat'),  &l:grepformat != '']
  " apply compiler settings, but only to get values, then restore original
  " since we run :compiler without bang, it will use buffer-local settings
  " when restoring, clear the setting unless previous was also buffer-local
  try
    exe 'compiler' a:opts.compiler
  catch /E666:/
    return v:false
  endtry
  let a:opts.prg  = getbufvar(bufnr(''), '&makeprg')
  let a:opts.gprg = getbufvar(bufnr(''), '&grepprg')
  let a:opts.efm  = getbufvar(bufnr(''), '&errorformat')
  let a:opts.gfm  = getbufvar(bufnr(''), '&grepformat')
  let &l:makeprg     = _prg[1]  ? _prg[0] : ''
  let &l:grepprg     = _gprg[1] ? _gprg[0] : ''
  let &l:errorformat = _efm[1]  ? _efm[0] : ''
  let &l:grepformat  = _gfm[1]  ? _gfm[0] : ''
  return v:true
endfunction

" Job command {{{1
""
" Function: s:make_cmd
" @param cmd:  the command to run
" @param mode: one of 'quickfix', 'buffer', 'terminal', 'cmdline', 'external'
" @param env:  environmental variables to set (for terminal and external mode)
" Returns: the full command for the job_start() function
""
fun! s:make_cmd(cmd, mode, env) abort
  let cmd = a:cmd

  if a:mode == 'terminal'
    return s:is_windows ? s:get_env(a:env) . cmd :
          \has('nvim')  ? ['sh', '-c', s:get_env(a:env) . cmd]
          \             : ['sh', '-c', cmd]

  elseif a:mode == 'external'
    return s:is_windows ? 'start cmd.exe /K ' . s:tempscript(cmd, a:env, 0)
          \             : s:unix_term(a:env, cmd)
  else
    return s:is_windows ? 'cmd.exe /C ' . s:get_env(a:env) . cmd
          \             : ['sh', '-c', cmd]
  endif
endfun

""
" s:unix_term: command to start an external terminal in unix environment
""
fun! s:unix_term(env, cmd) abort
  let X = systemlist('xset q &>/dev/null && echo 1 || echo 0')[0]
  if get(g:, 'async_unix_terminal', '') != ''
    return split(g:async_unix_terminal) + [a:cmd]
  elseif X && executable('urxvt')
    return ['urxvt', '-hold', '-e', 'sh', '-c', a:cmd]
  elseif X && executable('xfce4-terminal')
    return ['xfce4-terminal', '-H', '-e', 'sh', '-c', a:cmd]
  elseif s:is_wsl
    return ['sh', '-c', 'cmd.exe /c start cmd.exe /K wsl.exe ' . s:tempscript(a:cmd, a:env, 1)]
  else
    return v:null
  endif
endfun

""
" s:tempscript: make windows script that contains env variables and command
""
fun! s:tempscript(cmd, env, wsl) abort
  let lines = []
  if a:wsl
    for var in keys(a:env)
      let lines += [var . '=' . string(a:env[var])]
    endfor
    let lines += [a:cmd]
  else
    let lines += ['@echo OFF']
    for var in keys(a:env)
      let lines += ['set ' . var . '=' . a:env[var] . "\r"]
    endfor
    let lines += [a:cmd]
    let lines += ['@echo ON']
  endif
  let fname = tempname() . (a:wsl ? '.sh' : '.bat')
  call add(s:cmdscripts, fname)
  call writefile(lines, fname)
  return a:wsl ? ('sh ' . fname) : fname
endfun

" Environmental variables {{{1
""
" Function: s:get_env
" @param env: the dictionary with the env variables
" Returns: a string with the concatenated commands to set the variables
""
fun! s:get_env(env) abort
  let E = a:env
  let env = ''
  let pre = s:is_windows ? 'set ' : ''
  for k in keys(E)
    " in Windows we must set the env vars here or it won't work...
    if s:is_windows
      exe 'let $'.k . '=' . string(E[k])
    endif
    let env .= printf('%s=%s && ', pre . k, string(E[k]))
  endfor
  return env
endfun

" Start job {{{1
""
" s:job_start: start a job and return its id
""
fun! s:job_start(cmd, opts, useropts) abort
  if a:useropts.mode == 'terminal'
    return s:term_start(a:cmd, a:opts, a:useropts)
  else
    return has('nvim') ? jobstart(a:cmd, a:opts) : job_start(a:cmd, a:opts)
  endif
endfun

""
" s:term_start: start job in an embedded terminal
""
fun! s:term_start(cmd, opts, useropts) abort
  if has('nvim')
    new +setlocal\ bt=nofile\ bh=wipe\ noswf\ nobl
  endif
  let job = has('nvim') ? termopen(a:cmd, a:opts)
        \               : term_getjob(term_start(a:cmd, a:opts))
  let a:useropts.termbuf = bufnr('')
  let pos = get(a:useropts, 'pos', '')
  if index(['top', 'bottom', 'left', 'right', 'vertical'], pos) >= 0
    exe 'wincmd' {'top': 'K', 'bottom': 'J', 'left': 'H', 'right': 'L',
          \       'vertical': &splitright ? 'L' : 'H'}[pos]
  endif
  if has('nvim') && get(a:useropts, 'startinsert', 1)
    startinsert
  endif
  return job
endfun


" Create dictionary with job options {{{1
" @param useropts: the user options dictionary
" @return: the job options dictionary
""
fun! s:job_opts(useropts) abort
  let Callback = get(a:useropts, 'on_exit', function('s:cb_' . a:useropts.mode))
  if has('nvim')
    let opts = {
          \ "on_exit": function('async#finish', [Callback]),
          \ 'on_stdout': function('s:nvim_out'),
          \ 'on_stderr': function('s:nvim_err'),
          \ 'stdout_buffered' : 1,
          \ 'stderr_buffered' : 1,
          \}
  else
    let opts = {
          \ "exit_cb": function('async#finish', [Callback]),
          \ 'out_cb': function('s:vim_out'),
          \ 'err_cb': function('s:vim_err'),
          \ 'in_io': a:useropts.grep ? 'null' : 'pipe',
          \ 'err_io': 'pipe',
          \}
  endif
  return opts
endfun

" Scan ids for the requested job {{{1

""=============================================================================
" Function: s:get_job
" @param job: a job handler
" Returns: the entry in g:async_jobs for the requested job
""=============================================================================
fun! s:get_job(job) abort
  for id in keys(g:async_jobs)
    if g:async_jobs[id]['job'] == a:job
      return g:async_jobs[id]
    endif
  endfor
  return {'out': [], 'err': []}
endfun

""=============================================================================
" Function: s:get_job_with_channel
" @param channel: the channel in use
" Returns: the entry in g:async_jobs for the requested channel
""=============================================================================
fun! s:get_job_with_channel(channel) abort
  for id in keys(g:async_jobs)
    if ch_getjob(a:channel) == g:async_jobs[id]['job']
      return g:async_jobs[id]
    endif
  endfor
  return {'out': [], 'err': []}
endfun

" Output handlers {{{1
fun! s:nvim_out(job, out, ...) abort
  if a:out != ['']
    let job = s:get_job(a:job)
    let job['out'] = map(a:out, 'substitute(v:val, ''\r'', "","")')
  endif
endfun

fun! s:nvim_err(job, err, ...) abort
  if a:err != ['']
    let job = s:get_job(a:job)
    let job['err'] = map(a:err, 'substitute(v:val, ''\r'', "","")')
  endif
endfun

fun! s:vim_out(channel, line) abort
  let job = s:get_job_with_channel(a:channel)
  call add(job['out'], a:line)
endfun

fun! s:vim_err(channel, line) abort
  let job = s:get_job_with_channel(a:channel)
  call add(job['err'], a:line)
endfun

" Write log files with out/err if requested {{{1
" @param job: the job object
""
function! s:write_logs(job) abort
  if !a:job.writelogs
    return
  endif
  let fn = a:job.outfile == '' ? tempname() : expand(a:job.outfile)
  let a:job.outfile = fn
  if writefile(a:job.out, fn) == -1
    echom 'Error writing log for stdout to' fn
  endif
  let fn = a:job.errfile == '' ? tempname() : expand(a:job.errfile)
  let a:job.errfile = fn
  if writefile(a:job.err, fn) == -1
    echom 'Error writing log for stderr to' fn
  endif
endfunction

" Echo output to the command line {{{1
" @param list: a list of lines
" @param ...: will be 'err' if echoerr is to be used
""
fun! s:echo(list, ...)
  if empty(a:list)
    return
  endif
  call filter(a:list, { k,v -> v != '' })
  let txt = map(a:list, { k,v -> ':echom ' . string(v) })
  if a:0
    call insert(txt, ':echohl ' . a:1)
    call insert(txt, ':echohl None', 2)
  endif
  let @" = join(txt, "\n")
  call feedkeys(':exe @' . "\n", 'n')
endfun

" Remove trailing empty lines from output {{{1
" @param job: the job object
" @return: the output without starting or ending blanks
""
fun! s:no_trailing_blanks(job) abort
  " nvim output often has a trailing empty line
  if !empty(a:job.out) && a:job.out[-1] == ''
    call remove(a:job.out, -1)
  endif
  if !empty(a:job.err) && a:job.err[-1] == ''
    call remove(a:job.err, -1)
  endif
  return a:job
endfun

" Return the PID for the job {{{1
fun! s:pid(job) abort
  return has('nvim') ? jobpid(a:job) : job_info(a:job).process
endfun

" Get the position for buffer/terminal mode {{{1
fun! s:get_pos(job, default) abort
  let pos = get(a:job, 'pos', a:default)
  if pos == 'bottom'    | return 'botright'
  elseif pos == 'right' | return 'vertical botright'
  elseif pos == 'left'  | return 'vertical topleft'
  elseif pos == 'top'   | return 'topleft'
  else                  | return pos
  endif
endfun

" Render the job dict as json in a scratch buffer. {{{1
fun! s:job_as_json(dict) abort
  let data = s:normalize_dict(deepcopy(a:dict))
  let json = json_encode(data)
  vnew +setlocal\ bt=nofile\ bh=wipe\ noswf\ nobl
  wincmd H
  put =json
  1d _
  exe '%!' . s:py . ' -m json.tool'
  setfiletype json
endfun

fun! s:normalize_dict(dict)
  for k in keys(a:dict)
    if type(a:dict[k]) != v:t_string && type(a:dict[k]) != v:t_number
      let a:dict[k] = string(a:dict[k])
    elseif type(a:dict[k]) == v:t_dict
      call s:normalize_dict(a:dict[k])
    endif
  endfor
  return a:dict
endfun

" Prompt for a job id and check its validity. {{{1

fun! s:prompt_id(finished) abort
  let id = input('> ')
  if empty(id)
    return v:null
  endif
  let dict = a:finished ? g:async_finished_jobs : g:async_jobs
  if !has_key(dict, id)
    redraw
    echo 'Invalid id:' id
    return v:null
  endif
  return id
endfun

" When quitting vim, perform action on running jobs. {{{1

fun! s:on_vim_quit() abort
  if !empty(g:async_jobs)
    echo 'There are running jobs.'
    for id in keys(g:async_jobs)
      if g:async_jobs[id].termonquit ||
            \confirm('Stop job with id '. id, "&Yes\n&No") == 1
        call async#stop(id, 0)
      endif
    endfor
  endif
endfun

"}}}

let s:is_windows = has('win32') || has('win64') || has('win16') || has('win95')
let s:uname      = s:is_windows ? '' : systemlist('uname')[0]
let s:is_linux   = s:uname == 'Linux'
let s:is_macos   = s:uname == 'Darwin'
let s:is_wsl     = exists('$WSLENV')
let s:py         = executable('python') ? 'python' : executable('python3') ? 'python3' : ''
let s:cmdscripts = []

augroup async-stopjobs
  au!
  autocmd VimLeavePre * call s:on_vim_quit()
augroup END

" vim: et sw=2 ts=2 sts=2 fdm=marker

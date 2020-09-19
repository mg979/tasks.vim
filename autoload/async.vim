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
" callbacks that must be provided with the first optional dictionary.
"
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

let g:async_jobs = {}
let g:async_finished_jobs = {}
let s:id = 0

""=============================================================================
" Function: async#cmd
" Run a shell cmd asynchronously.
" @param cmd:  the command
" @param mode: quickfix, buffer, terminal, external or cmdline
" @param ...:  extra args, can be one or two dicts
"              - first is 'useropts' (user data stored in g:async_jobs[id])
"              - second is 'jobopts' (merged with job options)
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
    let opts = extend(s:job_opts(a:mode), jobopts)
    let job = s:job_start(cmd, opts, useropts)
    let s:id += 1
    let g:async_jobs[s:id] = extend({
          \ 'job': job, 'cmd': cmd, 'opts': opts,
          \ 'id': s:id, 'pid': s:pid(job), 'title': a:cmd,
          \ 'status': 'running', 'out': [], 'err': [],
          \}, s:default_opts(useropts))
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
  let user = extend(s:default_opts(a:0 ? a:1 : {}), {'args': a:args})

  " pattern for QuickFixCmdPre and QuickFixCmdPost
  if user.qfautocmd == ''
    let user.qfautocmd = user.grep ? 'grep' : 'make'
  endif

  " store old settings
  let [user._prg, user._gprg, user._efm] = [&makeprg, &grepprg, &errorformat]

  " apply compiler settings, but only to get values, then restore original
  if user.compiler != ''
    exe 'compiler' user.compiler
    let [user.prg, user.gprg, user.efm] = [&makeprg, &grepprg, &errorformat]
    let [&makeprg, &grepprg, &errorformat] = [user._prg, user._gprg, user._efm]
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


""
" Function: async#stop
" @param id:   the id of the job to stop. If 0, all jobs are stopped.
" @param kill: kill rather than terminate. Vim only.
" Returns: the id of the stopped job, or 0 if all jobs are stopped.
""
fun! async#stop(id, ...) abort
  " {{{1
  for id in (a:id ? [a:id] : keys(g:async_jobs))
    if has('nvim')
      let job = str2nr(g:async_jobs[id].job)
      call jobstop(job)
    else
      let job = job_info(g:async_jobs[id].job)
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
  let id = input('> ')
  if id != '' && confirm('Stop job with id '.id, "&Yes\n&No") == 0
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
  for id in keys(J)
    let limit = &columns - 4 - 9 - 8 - 5
    echo printf('%-4s%-9s%-8s%-'.limit.'s', id, J[id].pid, J[id].status, J[id].cmd)
  endfor
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
" @param status: the exit status of the job
" @param ...:    the event type (passed by nvim, unused)
"
" job user options specific for buffer mode:
"  'pos'   position     'split', 'top', 'bottom'(default), 'left', 'right'
"  'ft'    filetype     ''
""=============================================================================
fun! s:cb_buffer(job, status, ...) abort
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
" @param status: the exit status of the job
" @param ...:    the event type (passed by nvim, unused)
""=============================================================================
fun! s:cb_quickfix(job, status, ...) abort
  " {{{1
  let job = a:job
  if job.silent
    let [job.noopen, job.nofocus, job.nojump] = [1, 1, 1]
  endif

  let &errorformat = job.efm

  exe 'silent doautocmd QuickFixCmdPre' job.qfautocmd
  let cxpr =  job.locl ? 'l' : 'c'
  let cxpr .= job.append ? 'add' : job.nojump ? 'get' : ''
  let cxpr .= 'expr'
  exe cxpr 'job.out + job.err'
  exe 'silent doautocmd QuickFixCmdPost' job.qfautocmd

  let &errorformat = job._efm

  call setqflist([], "r", job)
  if job.grep && a:status
    if a:status > 1 || a:status == 1 && !empty(job.err)
      call s:echo([job.cmd] + job.err, 'WarningMsg')
    elseif a:status == 1
      echo 'No results'
    endif
  else
    if !job.grep && !a:status
      echo "Success:" job.cmd
    elseif !job.noopen
      silent redraw!
      exe (job.locl ? 'lopen' : 'botright copen')
      if job.nofocus
        wincmd p
      endif
    elseif job.grep
      echo 'Found' (len(job.out) + len(job.err)) 'matches'
    else
      call s:echo(['Failure: '. job.cmd], 'WarningMsg')
    endif
  endif
endfun "}}}


""=============================================================================
" Function: s:cb_cmdline
" Echo the output of an asynchronous shell command to the command line.
" @param job:    the job object
" @param status: the exit status of the job
" @param ...:    the event type (passed by nvim, unused)
""=============================================================================
fun! s:cb_cmdline(job, status, ...) abort
  " {{{1
  if a:status
    call s:echo(a:job.err, 'ErrorMsg')
  elseif !empty(a:job.err)
    call s:echo(a:job.err)
  else
    call s:echo(a:job.out)
  endif
endfun "}}}


""=============================================================================
" Function: s:cb_terminal
" Remove the job but set buffer variables so that out/err are saved.
" @param job:    the job object
" @param status: the exit status of the job
" @param ...:    the event type (passed by nvim, unused)
"
" job.pos can be: 'split'(default), 'top', 'bottom', 'left', 'right'
""=============================================================================
fun! s:cb_terminal(job, status, ...) abort
  "{{{1
  let b:job_out = a:job.out
  let b:job_err = a:job.err
endfun "}}}


""=============================================================================
" Function: s:cb_external
" Not much to do here... there's nothing useful that can be saved.
" @param job:    the job object
" @param status: the exit status of the job
" @param ...:    the event type (passed by nvim, unused)
""=============================================================================
fun! s:cb_external(job, status, ...) abort
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
" @param func:   the actual exit callback
" @param job:    the finished job id/object
" @param status: the exit status of the job
" @param ...:    the event type (passed by nvim, unused)
""=============================================================================
fun! async#finish(func, job, status, ...) abort
  let job = s:no_trailing_blanks(async#remove_job(a:job))
  call a:func(job, a:status, a:000)
  if !empty(s:cmdscripts)
    for f in s:cmdscripts
      call timer_start(1000, { t -> delete(f) })
    endfor
  endif
  unlet job.out
  unlet job.err
  let job.status = a:status
  let job.cmd = type(job.cmd) == v:t_string ? job.cmd : join(job.cmd)
  let g:async_finished_jobs[job.id] = job
endfun


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
"                                                                             "
"                                   Helpers                                   "
"                                                                             "
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" Default user options {{{1
"  'prg'        makeprg                      default: &makeprg
"  'gprg'       grepprg                      default: &grepprg
"  'efm'        errorformat                  default: &errorformat
"  'compiler'   run :compiler x              default: ''
"  'qfautocmd'  quickfix autocommands        default: ''
"  'env'        environmental variables      default: {}
"  'grep'       use grepprg, not makeprg     default: 0
"  'locl'       use loclist, not qfix        default: 0
"  'nofocus'    keep focus on window         default: 0
"  'nojump'     don't jump to first item     default: 0
"  'noopen'     don't open qfix window       default: 0
"  'silent'     the 3 above combined         default: 0
"  'repeat'     repeat every n seconds       default: 0
"  'update'     do :update before cmd        default: 0
"  'wall'       do :wall before cmd          default: 0
fun! s:default_opts(useropts)
  return extend({
        \ 'prg': &makeprg,
        \ 'gprg': &grepprg,
        \ 'efm': &errorformat,
        \ 'qfautocmd': '',
        \ 'compiler': '',
        \ 'append': 0,
        \ 'locl': 0,
        \ 'grep': 0,
        \ 'silent': 0,
        \ 'nofocus': 0,
        \ 'nojump': 0,
        \ 'noopen': 0,
        \ 'repeat': 0,
        \ 'update': 0,
        \ 'wall': 0,
        \}, a:useropts)
endfun

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
  let env = s:get_env(a:env)

  if a:mode == 'terminal'
    return s:is_windows ? env . cmd :
          \has('nvim')  ? ['sh', '-c', env . cmd]
          \             : ['sh', '-c', cmd]

  elseif a:mode == 'external'
    return s:is_windows ? 'start cmd.exe /K ' . s:tempscript(a:cmd, a:env, 0)
          \             : s:unix_term(a:env, cmd)
  else
    return s:is_windows ? 'cmd.exe /C ' . cmd
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
  let job = has('nvim') ? termopen(a:cmd, a:opts) : term_getjob(term_start(a:cmd, a:opts))
  exe 'wincmd' {'top': 'K', 'bottom': 'J', 'left': 'H', 'right': 'L'}[a:useropts.pos]
  if has('nvim') && get(a:useropts, 'startinsert', 0)
    startinsert
  endif
  return job
endfun


" Create dictionary with job options {{{1
" @param mode: the output mode
" @return: the job options dictionary
""
fun! s:job_opts(mode) abort
  if has('nvim')
    let opts = {
          \ "on_exit": function('async#finish', [function("s:cb_".a:mode)]),
          \ 'on_stdout': function('s:nvim_out'),
          \ 'on_stderr': function('s:nvim_err'),
          \ 'stdout_buffered' : 1,
          \ 'stderr_buffered' : 1,
          \}
  else
    let opts = {
          \ "exit_cb": function('async#finish', [function("s:cb_".a:mode)]),
          \ 'out_cb': function('s:vim_out'),
          \ 'err_cb': function('s:vim_err'),
          \ 'in_io': 'null',
          \ 'err_io': 'pipe',
          \}
    if a:mode == 'terminal'
      unlet opts.in_io
      unlet opts.err_io
    endif
  endif
  return opts
endfun

""
" Create dictionary with user options {{{1
" @param args: if not empty, command useropts is the first element
" @param mode: the mode of the command
" @return: the useropts dictionary
""
function! s:user_opts(args, mode) abort
  let useropts = empty(a:args) ? {} : a:args[0]
  let useropts.mode = a:mode
  if get(useropts, 'wall', 0)
    silent! wall
  elseif get(useropts, 'update', 0)
    update
  endif
  return useropts
endfunction

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

" Echo output to the command line {{{1
" @param list: a list of lines
" @param ...: will be 'err' if echoerr is to be used
""
fun! s:echo(list, ...)
  call filter(a:list, { k,v -> v != '' })
  let txt = map(a:list, { k,v -> ':echo ' . string(v) . "\n" })
  if a:0
    let txt = [':echohl ' . a:1 . "\n"] + txt + [':echohl None' . "\n"]
  endif
  let @" = join(txt, '')
  call feedkeys(':exe @' . "\n")
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
"}}}

let s:is_windows = has('win32') || has('win64') || has('win16') || has('win95')
let s:uname      = s:is_windows ? '' : systemlist('uname')[0]
let s:is_linux   = s:uname == 'Linux'
let s:is_macos   = s:uname == 'Darwin'
let s:is_wsl     = exists('$WSLENV')
let s:cmdscripts = []

" vim: et sw=2 ts=2 sts=2 fdm=marker

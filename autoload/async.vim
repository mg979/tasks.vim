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
"  'job': the job object
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
" These user options supported for the given mode mode:
"------------------------------------------------------------------------------
"  'pos'   terminal position       term          '' (normal split)
"  'pos'   buffer position         buffer        'botright'
"  'ft'    filetype                buffer        ''
"  'ex'    ex commands             buffer        []
"
" Useful values for 'pos' are only: 'botright [vertical]', 'topleft [vertical]'
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

let g:async_jobs = {}
let g:async_finished_jobs = {}
let s:id = 0

""=============================================================================
" Function: async#cmd
" Run a shell cmd asynchronously.
"
" @param cmd:  the command
" @param mode: quickfix, buffer, terminal, external or cmdline
" @param ...:  extra args, can be one or two dicts
"              - first is 'useropts' (user data stored in g:async_jobs[id])
"              - second is 'jobopts' (merged with job options)
""=============================================================================
fun! async#cmd(cmd, mode, ...) abort
  " {{{1
  let useropts = a:0 ? a:1 : {}
  let useropts.mode = a:mode
  let jobopts = a:0 > 1 ? a:2 : {}
  let cmd = s:make_cmd(a:cmd, a:mode)
  let opts = extend(s:job_opts(a:mode), jobopts)
  let job = s:job_start(cmd, opts, useropts)
  let s:id += 1
  let g:async_jobs[s:id] = extend({
        \ 'job': job, 'cmd': cmd, 'opts': opts,
        \ 'id': s:id, 'pid': s:pid(job),
        \ 'out': [],  'err': [],
        \ 'title': a:cmd
        \}, useropts)
  return s:id
endfun "}}}


""=============================================================================
" Function: async#make
" Run a job and populate quickfix with results.
" @param args:  the args for the make command
" @param ...:   optional dicts as for async#cmd (useropts, jobopts).
"
" Valid user options are:
"  'prg'        makeprg                      default: &makeprg
"  'gprg'       grepprg                      default: &grepprg
"  'efm'        errorformat                  default: &errorformat
"  'compiler'   run :compiler x              default: ''
"  'grep'       use grepprg, not makeprg     default: 0
"  'locl'       use loclist, not qfix        default: 0
"  'focus'      keep focus on quickfix       default: 1
"  'jump'       jump to first item           default: 1
"  'open'       open qfix window             default: 1
"  'append'     append errors to list        default: 0
""=============================================================================
fun! async#make(args, ...) abort
  "{{{1
  let user = extend({
        \     'prg': &makeprg,
        \     'gprg': &grepprg,
        \     'efm': &errorformat,
        \     'compiler': '',
        \     'append': 0,
        \     'locl': 0,
        \     'grep': 0,
        \     'focus': 1,
        \     'jump': 1,
        \     'open': 1,
        \     'args': a:args,
        \}, a:0 ? a:1 : {})

  " store old settings
  let [user._prg, user._gprg, user._efm] = [&makeprg, &grepprg, &errorformat]

  " apply compiler settings, but only to get values, then restore original
  if user.compiler != ''
    exe 'compiler' user.compiler
    let [user.prg, user.gprg, user.efm] = [&makeprg, &grepprg, &errorformat]
    let [&makeprg, &grepprg, &errorformat] = [user._prg, user._gprg, user._efm]
  endif

  let user.cmd = async#expand_args(user.grep ? user.gprg : user.prg, user.args)

  if !user.grep
    silent! wall
  endif

  exe (user.locl ? 'lclose' : 'cclose')

  let opts = extend({}, a:0 > 1 ? a:2 : {})
  call async#cmd(user.cmd, 'make', user, opts)
endfun "}}}


""=============================================================================
" Function: async#stop
" Stop all jobs. With a bang, jobs are killed.
" @param kill: kill rather than terminate. Vim only.
""=============================================================================
fun! async#stop(kill) abort
  " {{{1
  for id in keys(g:async_jobs)
    if has('nvim')
      let job = str2nr(g:async_jobs[id].job)
      call jobstop(job)
    else
      let job = job_info(g:async_jobs[id].job)
      call job_stop(job, a:kill ? 'kill' : 'term')
    endif
  endfor
endfun "}}}


""=============================================================================
" Function: async#list
" List running jobs.
""=============================================================================
fun! async#list() abort
  " {{{1
  if empty(g:async_jobs)
    echo 'No running jobs'
    return
  endif
  echohl Title
  echo 'process     command'
  echohl None
  for id in keys(g:async_jobs)
    try
      if has('nvim')
        let job = str2nr(g:async_jobs[id].job)
        echo printf('%-12s%s', jobpid(job), g:async_jobs[id].cmd)
      else
        let job = job_info(g:async_jobs[id].job)
        echo printf('%-12s%s', job.process, job.cmd)
      endif
    catch
      call async#remove_job(job)
    endtry
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
" @param job:    the job object.
" @param status: the exit status for the job.
" @param ...:    the event type (passed by nvim, unused)
""=============================================================================
fun! s:cb_buffer(job, status, ...) abort
  " {{{1
  let job = async#remove_job(a:job)

  " create buffer
  exe get(job, 'pos', 'botright') (len(job.out) + len(job.err)) . 'new'
  setlocal bt=nofile bh=wipe noswf nobl

  " set buffer options and execute user commands
  let &l:statusline = job.title
  if has_key(job, 'ft')
    exe 'setfiletype' job.ft
  endif
  if has_key(job, 'ex')
    if type(job.ex) == v:t_string
      exe job.ex
    else
      for l in job.ex
        exe l
      endfor
    endif
  endif

  " put text and delete empty lines at top and bottom
  if job.out != [] && job.out != ['']
    silent put ='--- stdout'
    call matchadd('Identifier', '\%' . (line('.')-1) . 'l^--- stdout$')
    silent put =job.out
  endif
  if job.err != [] && job.err != ['']
    silent put ='--- stderr'
    call matchadd('WarningMsg', '\%' . (line('.')-1) . 'l^--- stderr$')
    silent put =job.err
  endif
  if search('\S', 'n')
    while getline('$') == '' | $d _ | endwhile
    while getline(1) == ''   | 1d _ | endwhile
  endif
  call s:finished_job(job, a:status)
endfun "}}}


""=============================================================================
" Function: s:cb_make
" Called when the job has exited, populates the qfix list
" @param job:    the job object.
" @param status: the exit status for the job.
" @param ...:    the event type (passed by nvim, unused)
""=============================================================================
fun! s:cb_make(job, status, ...) abort
  " {{{1
  let job = s:no_trailing_blanks(async#remove_job(a:job))

  let &errorformat = job.efm

  exe 'silent doautocmd QuickFixCmdPre' (job.grep ? 'grep' : 'make')
  let cxpr =  job.locl ? 'l' : 'c'
  let cxpr .= job.append ? 'add' : !job.jump ? 'get' : ''
  let cxpr .= 'expr'
  exe cxpr 'job.out + job.err'
  exe 'silent doautocmd QuickFixCmdPost' (job.grep ? 'grep' : 'make')

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
    elseif job.open
      silent redraw!
      exe (job.locl ? 'lopen' : 'botright copen')
      if !job.focus
        wincmd p
      endif
    elseif job.grep
      echo 'Found' (len(job.out) + len(job.err)) 'matches'
    else
      call s:echo(['Failure: '. job.cmd], 'WarningMsg')
    endif
  endif
  call s:finished_job(job, a:status)
endfun "}}}


""=============================================================================
" Function: s:cb_cmdline
" Echo the output of an asynchronous shell command to the command line.
" @param job:    the job object.
" @param status: the exit status for the job.
" @param ...:    the event type (passed by nvim, unused)
""=============================================================================
fun! s:cb_cmdline(job, status, ...) abort
  " {{{1
  let job = async#remove_job(a:job)

  if a:status
    call s:echo(job.err, 'ErrorMsg')
  elseif !empty(job.err)
    call s:echo(job.err)
  else
    call s:echo(job.out)
  endif
  call s:finished_job(job, a:status)
endfun "}}}


""=============================================================================
" Function: s:cb_term
" Remove the job but set buffer variables so that out/err are saved.
" @param job:    the job object.
" @param status: the exit status for the job.
" @param ...:    the event type (passed by nvim, unused)
""=============================================================================
fun! s:cb_term(job, status, ...) abort
  let job = async#remove_job(a:job)
  let b:job_out = job.out
  let b:job_err = job.err
  call s:finished_job(job, a:status)
endfun


""=============================================================================
" Function: s:cb_external
" Not much to do here... there's nothing useful that can be saved.
" @param job:    the job object.
" @param status: the exit status for the job.
" @param ...:    the event type (passed by nvim, unused)
""=============================================================================
fun! s:cb_external(job, status, ...) abort
  let job = async#remove_job(a:job)
  call s:finished_job(job, a:status)
endfun


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
"                                                                             "
"                               Public helpers                                "
"                                                                             "
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

""=============================================================================
" Function: async#expand_args
" Include args and perform expansions for the Make/Grep commands.
" @param cmd:  generally &makeprg or &grepprg
" @param args: the command arguments
" @return: the full command
""=============================================================================
fun! async#expand_args(cmd, args) abort
  "{{{1
  " normally a placeholder for args isn't included, we must add it
  let cmd = a:cmd
  if a:args != '' && match(a:cmd, '\V$*') < 0
    let cmd .= ' $*'
  endif
  " from https://github.com/edkolev/vim-amake and
  " from tpope's vim-dispatch https://github.com/tpope/vim-dispatch
  let cmd = substitute(cmd, '\$\*', a:args, 'g')
  let flags = '<\=\%(:[p8~.htre]\|:g\=s\(.\).\{-\}\1.\{-\}\1\)*'
  let expandable = '\\*\%(<\w\+>\|%\|#\d*\)' . flags
  let cmd = substitute(cmd, expandable, '\=expand(submatch(0))', 'g')
  return substitute(cmd, '^\s*\|\s*$', '', 'g')
endfun "}}}


""=============================================================================
" Function: async#remove_job
" Remove a job from the global dictionary, when job has exited.
" @param job: the job to remove
" @return: the removed entry
""=============================================================================
fun! async#remove_job(job) abort
  "{{{1
  for id in keys(g:async_jobs)
    if g:async_jobs[id].job == a:job
      return remove(g:async_jobs, id)
    endif
  endfor
endfun "}}}




"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
"                                                                             "
"                                   Helpers                                   "
"                                                                             "
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" Job command {{{1
fun! s:make_cmd(cmd, mode) abort
  let cmd = substitute(a:cmd, '\s*$', '', '')
  if a:mode == 'term'
    return cmd
  elseif a:mode == 'external'
    let unix = get(g:, 'async_unix_term', 'x-terminal-emulator')
    return   has('win32')      ? 'start cmd.exe /K ' . cmd
          \: exists('$WSLENV') ? 'cmd.exe /c start cmd.exe /K ' . cmd
          \                    : [unix, '-e', cmd]
  else
    return has('win32') ? 'cmd.exe /C ' . cmd
          \             : ['sh', '-c', cmd]
  endif
endfun

" Start job {{{1
fun! s:job_start(cmd, opts, useropts) abort
  if a:useropts.mode == 'term'
    return s:term_start(a:cmd, a:opts, a:useropts)
  else
    return has('nvim') ? jobstart(a:cmd, a:opts) : job_start(a:cmd, a:opts)
  endif
endfun

fun! s:term_start(cmd, opts, useropts) abort
  if has('nvim')
    new +setlocal\ bt=nofile\ bh=wipe\ noswf\ nobl
  endif
  let job = has('nvim') ? termopen(a:cmd, a:opts) : term_getjob(term_start(a:cmd, a:opts))
  let pos = get(a:useropts, 'pos'. '')
  if pos != ''
    let vert = pos =~ 'vert'
    if pos =~ 'bo'
      exe 'wincmd' (vert ? 'H' : 'J')
    elseif pos =~ 'to'
      exe 'wincmd' (vert ? 'L' : 'K')
    endif
  endif
  if has('nvim') && get(a:useropts, 'startinsert', 0)
    startinsert
  endif
  return job
endfun


" Create dictionary with job options {{{1
fun! s:job_opts(mode) abort
  if has('nvim')
    let opts = {
          \ "on_exit": function("s:cb_".a:mode,),
          \ 'on_stdout': function('s:nvim_out'),
          \ 'on_stderr': function('s:nvim_err'),
          \ 'stdout_buffered' : 1,
          \ 'stderr_buffered' : 1,
          \}
  else
    let opts = {
          \ "exit_cb": function("s:cb_".a:mode,),
          \ 'out_cb': function('s:vim_out'),
          \ 'err_cb': function('s:vim_err'),
          \ 'in_io': 'null',
          \ 'err_io': 'out',
          \}
    if a:mode == 'term'
      unlet opts.in_io
      unlet opts.err_io
    endif
  endif
  return opts
endfun

" Scan ids for the requested job {{{1

""=============================================================================
" Function: s:get_job
" @param job: a job handler
" @return: the entry in g:async_jobs for the requested job
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
" Vim implementation of jobs makes things difficult here. It's not possible for
" the job callbacks to know the job they belong to...
"
" @param channel: the channel in use
" @return: the entry in g:async_jobs for the requested channel
""=============================================================================
fun! s:get_job_with_channel(channel) abort
  for id in keys(g:async_jobs)
    let channel = job_getchannel(g:async_jobs[id]['job'])
    if channel == a:channel
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

" Echo some output to the command line {{{1
fun! s:echo(list, ...)
  " @param list: a list of lines
  " @param ...: will be 'err' if echoerr is to be used
  call filter(a:list, { k,v -> v != '' })
  let txt = map(a:list, { k,v -> ':echo ' . string(v) . "\n" })
  if a:0
    let txt = [':echohl ' . a:1 . "\n"] + txt + [':echohl None' . "\n"]
  endif
  let @" = join(txt, '')
  call feedkeys(':exe @' . "\n")
endfun

" Remove trailing empty lines from output {{{1
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

" Add finished job to the global table {{{1
fun! s:finished_job(job, status) abort
  unlet a:job.out
  unlet a:job.err
  let g:async_finished_jobs[a:job.id] = a:job
  let g:async_finished_jobs[a:job.id].status = a:status
endfun

"}}}

" vim: et sw=2 ts=2 sts=2 fdm=marker

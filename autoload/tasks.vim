" ========================================================================///
" Description: Tasks management inspyred by asynctasks.vim
" File:        tasks.vim
" Author:      Gianmaria Bajo <mg1979@git.gmail.com>
" License:     MIT
" Created:     mar 08 settembre 2020 01:58:09
" Modified:    mar 08 settembre 2020 01:58:09
" ========================================================================///


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Constructors
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Tasks can be defined at global level or per project. Project-local tasks
" override global tasks with the same name.
"
" When one tries to run a task, the global file and the local file are parsed
" and merged. The parsed tasks are stored in the global table g:tasks.
"
" When a tasks file (global or local) is edited and saved, it is invalidated,
" so that the next time that one tries to run a command, invalidated files
" will be parsed again.
"
" The g:tasks table has the following structure:
"
"   g:tasks = {
"     global = {
"         tasks,        DICT
"         invalidated,  BOOL
"     },
"     project_1 = {
"         env,          DICT
"         tasks,        DICT
"         invalidated,  BOOL
"         profile,      STRING
"     },
"     ...
"   }
"
" No profile can be defined for the global tasks. It's a project thing.
" Elements in x.tasks have the following structure:
"
"   taskname = {
"     local,            BOOL
"     fields,           DICT
"     profile,          STRING
"     warnings,         LIST        TODO
"   }
"
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

function! s:new_task(local) abort
    let t = {}
    let t.local = a:local
    let t.fields = {}
    return t
endfunction


function! s:new_project(local) abort
    let p = { 'tasks': {}, 'invalidated': 0, 'env': {} }
    if a:local
        let p.env = { 'ROOT': getcwd(), 'PRJNAME': s:project_name() }
        let p.profile = 'default'
        let p.info = { 'name': s:project_name() }
    endif
    return p
endfunction


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Tasks getters
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

function! tasks#get(...) abort
    let reload = a:0 && a:1
    let global = tasks#global(reload)
    let gtasks = deepcopy(global.tasks)
    let dict = extend(global, tasks#project(reload))
    call extend(dict.tasks, gtasks, 'keep')
    return dict
endfunction


function! tasks#project(reload) abort
    let prj = s:project_name()
    if !a:reload && has_key(g:tasks, prj) && !g:tasks[prj].invalidated
        return g:tasks[prj]
    endif
    let f = s:get_local_ini()
    if !filereadable(f)
        return {}
    endif
    let g:tasks[prj] = s:parse(f, 1)
    return g:tasks[prj]
endfunction


function! tasks#global(reload) abort
    if !a:reload && has_key(g:tasks, 'global') && !g:tasks.global.invalidated
        return g:tasks.global
    endif
    let f = s:get_global_ini()
    if !filereadable(f)
        return {}
    endif
    let g:tasks.global = s:parse(f, 0)
    return g:tasks.global
endfunction


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Parse configuration files
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

""
" Function: s:parse
" Parse and validate a tasks file.
"
" @param path:     path of the tasks file
" @param is_local: true if it's project-local tasks file
" Returns: the validated task
""
function! s:parse(path, is_local) abort
    if a:path == ''
        return {}
    endif
    let lines = readfile(a:path)
    let current = v:null
    let p = s:new_project(a:is_local)
    for line in lines
        if match(line, '^;') == 0 || empty(line)
            continue
        elseif match(line, s:envpat) == 0 && a:is_local
            let p.tasks['__env__'] = s:new_task(1)
            let current = p.tasks['__env__']
        elseif match(line, s:taskpat) == 1
            let task = matchstr(line, s:taskpat)
            let p.tasks[task] = s:new_task(a:is_local)
            let p.tasks[task].profile = match(line, s:profpat) > 0 ?
                        \               matchstr(line, s:profpat) : 'default'
            let current = p.tasks[task]
        elseif current isnot v:null
            for pat in values(s:patterns)
                if match(line, pat) == 0
                    let item = matchstr(line, pat)
                    let current.fields[item] = substitute(line, item . '=', '', '')
                    break
                endif
            endfor
        endif
    endfor
    call filter(p.tasks, function('s:validate_task', [p]))
    return s:clear_tasks_names(p)
endfunction


" TODO: :Project, :Compile commands
" TODO: test environmental variables expansion
" TODO: assign score to commands to see which one should be chosen
" TODO: cwd, prjname
" TODO: success/fail hooks

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Validate tasks
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

""
" Function: s:validate_task (filter function)
" @param project: the project (or the global ini) the task belong to
" @param name:    name of the task (key of the project.tasks element)
" @param values:  content of project.tasks[name]
" Returns: true if the task is valid
""
function! s:validate_task(project, name, values) abort
    let [p, n, v] = [a:project, a:name, a:values]
    if s:is_env(p, n, v)            | return v:false | endif
    if s:is_projects_info(p, n, v)  | return v:false | endif
    if s:failing_conditions(n)      | return v:false | endif
    if s:wrong_profile(p, n, v)     | return v:false | endif
    if s:no_valid_fields(v.fields)  | return v:false | endif
    if s:no_command(v.fields)       | return v:false | endif
    return v:true
endfunction


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Special sections
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
""
" These are not real tasks, so they will be removed from the tasks dict after
" they've been found, and their fields will be stored in the root of the
" project dict. They are:
"
"   #info       local to project, it contains informations about the project
"   #env        local to project, it contains environmental variables that will
"               be set before the command is executed
""

function! s:is_env(project, name, task) abort
    if !a:task.local || a:name !=# '__env__'
        return v:false
    endif
    call extend(a:project.env, a:task.fields)
    return v:true
endfunction


function! s:is_projects_info(project, name, task) abort
    if !a:task.local || a:name !=# 'info'
        return v:false
    endif
    call extend(a:project.info, a:task.fields)
    return v:true
endfunction


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Actual tasks validation
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

function! s:failing_conditions(item) abort
    " / is the delimiter for systems and other conditions to satisfy
    " if conditions are separated by '+' they must all be satisfied
    " if conditions are separated by ',' any of them is enough
    if match(a:item, '/') > 0
        let l:Has = { cond -> cond !~? '\clinux\|windows\|macos\|wsl' && has(cond) }
        let [_, conds] = split(a:item, '/')
        if match(conds, '+') >= 0
            for cond in split(conds, '+')
                if     cond ==? 'linux'   && !s:is_linux   | return v:true
                elseif cond ==? 'macos'   && !s:is_macos   | return v:true
                elseif cond ==? 'windows' && !s:is_windows | return v:true
                elseif cond ==? 'wsl'     && !s:is_wsl     | return v:true
                elseif !l:Has(cond)                        | return v:true
                endif
            endfor
        else
            for cond in split(conds, ',')
                if l:Has(cond)                            | return v:false
                elseif cond ==? 'linux'   && s:is_linux   | return v:false
                elseif cond ==? 'macos'   && s:is_macos   | return v:false
                elseif cond ==? 'windows' && s:is_windows | return v:false
                elseif cond ==? 'wsl'     && s:is_wsl     | return v:false
                endif
            endfor
            return v:true
        endif
    endif
    return v:false
endfunction


function! s:wrong_profile(project, taskname, task) abort
    if !a:task.local
        return v:false
    endif
    return a:project.profile != a:task.profile
endfunction


function! s:no_valid_fields(fields) abort
    call filter(a:fields, function("s:valid_fields"))
    return empty(a:fields)
endfunction


function! s:no_command(fields) abort
    for f in keys(a:fields)
        if f =~ '^command'
            return v:false
        endif
    endfor
    return v:true
endfunction


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Validate fields
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

function! s:valid_fields(key, val) abort
    for f in keys(s:fields)
        if a:key =~ f
            return s:fields[f](a:key, a:val)
        endif
    endfor
    return v:false
endfunction


function! s:validate_output(key, val) abort
    if a:val =~ '^terminal'
        return a:val =~ '^\vterminal(:('.s:pospat.'))?(:\d+)?$'
    elseif a:val =~ '^buffer'
        return a:val =~ '^\vbuffer(:('.s:pospat.'))?(:\d+)?$'
    elseif a:val =~ '^external'
        return a:val =~ '^external\(:[[:alnum:]_-]\+\)\?$'
    else
        return index(['quickfix', 'cmdline', 'headless'], a:val) >= 0
    endif
endfunction


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Validate command
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

function! s:valid_filetype(key) abort
    let fts = split(substitute(a:key, '.*:', '', ''), ',')
    return index(fts, s:ft()) >= 0
endfunction


function! s:validate_command(key, val) abort
    if match(a:key, '/') > 0 && s:failing_conditions(a:key)
        return v:false
    endif
    " / is the delimiter for systems and other conditions to satisfy
    let k = substitute(a:key, '/.*', '', '')
    " : is the delimiter for the filetype filter
    if match(k, ':') > 0
        return s:valid_filetype(k)
    endif
    return k ==# 'command'
endfunction



"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Run task
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

""
" Main command to run a task. Will call async#cmd.
""
function! tasks#run(args) abort
    redraw
    let prj = tasks#get(1)
    if empty(prj)
        let root = s:find_root()
        if s:change_root(root)
            lcd `=root`
            let prj = tasks#get(1)
        endif
    endif
    if s:no_tasks(prj)
        return
    endif
    let tasks = prj.tasks
    let a = split(a:args)
    let name = a[0]
    let args = len(a) > 1 ? join(a[1:]) : ''

    if !has_key(tasks, name)
        echon s:badge() 'not a valid task'
        return
    endif

    let task = tasks[name]
    let cmd = s:choose_command(task)

    let mode = s:get_cmd_mode(task)
    let opts = extend(s:get_pos(mode),
                \     s:get_opts(get(task.fields, 'options', '')))
    let useropts = extend({
                \ 'prg': cmd,
                \ 'gprg': cmd,
                \ 'efm': get(task.fields, 'efm', &errorformat),
                \ 'compiler': get(task.fields, 'compiler', ''),
                \ 'ft': get(task.fields, 'syntax', ''),
                \}, opts)
    let jobopts = {
                \ 'env': prj.env,
                \ 'cwd': s:get_cwd(task),
                \}
    let mode = substitute(mode, ':.*', '', '')
    if mode == 'quickfix'
        call async#qfix(args, useropts, jobopts)
    else
        call async#cmd(cmd . ' ' . args, mode, useropts, jobopts)
    endif
endfunction

""
" Choose the most appropriate command for the task.
""
function! s:choose_command(task) abort
    let [cmdpat, cmppat, ft] = ['^command', '^compiler', '\<' . s:ft() . '\>']

    " try 'compiler' first, then 'command'
    let cmds = filter(copy(a:task.fields), 'v:key =~ cmppat')
    if empty(cmds)
        let cmds = filter(copy(a:task.fields), 'v:key =~ cmdpat')
    endif
    " loop all the commands and choose the one with the highest score
    " score is based on specificity for system (/) and filetype (:)
    let best = [0, '']
    for cmd in keys(cmds)
        let score = (cmd =~ '/') + (cmd =~ ':')
        if score >= best[0]
            let best = [score, cmds[cmd]]
        endif
    endfor

    " clear all commands from task, the chosen command will be set instead
    call filter(a:task.fields, 'v:key !~ cmdpat')
    return best[1] != '' ? best[1] : &makeprg
endfunction

""
" If the task defines a cwd, it should be expanded.
" Expand also $ROOT and $PRJNAME because they aren't set in vim environment.
""
function! s:get_cwd(task) abort
    if has_key(a:task.fields, 'cwd')
        let cwd = async#expand(a:task.fields.cwd)
        if s:is_windows
            let cwd = substitute(cwd, '%\([A-Z_]\+\)%', '$\1', 'g')
        endif
        let cwd = substitute(cwd, '\$ROOT\>', '\=getcwd()', 'g')
        let cwd = substitute(cwd, '\$PRJNAME\>', '\=s:project_name()', 'g')
        let cwd = substitute(cwd, '\(\$[A-Z_]\+\)\>', '\=expand(submatch(1))', 'g')
        return cwd
    else
        return getcwd()
    endif
endfunction

""
" Mode is either 'quickfix', 'buffer', 'terminal', 'external' or 'cmdline'.
""
function! s:get_cmd_mode(task) abort
    let mode = filter(copy(a:task.fields), { k,v -> k =~ '^output' })
    return len(mode) > 0 ? values(mode)[0] : 'quickfix'
endfunction

""
" Buffer and terminal modes can define position after ':'
""
function! s:get_pos(mode) abort
    if a:mode !~ '\v^(buffer|terminal):'.s:pospat
        return {}
    else
        return {'pos': substitute(a:mode, '^\w\+:', '', '')}
    endif
endfunction

""
" Options defined in the 'options' field.
""
function! s:get_opts(opts_string) abort
    if a:opts_string == ''
        return {}
    endif
    let opts = {}
    let vals = split(a:opts_string, ',')
    " all options have a default of 0
    for v in vals
        let opts[v] = 1
    endfor
    return opts
endfunction

""
" Command line completion for tasks.
""
function! tasks#complete(A, C, P) abort
    let valid = keys(get(tasks#get(), 'tasks', {}))
    return filter(sort(valid), 'v:val=~#a:A')
endfunction


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Tasks profiles
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

""
" Echo current profile in the command line.
""
function! tasks#current_profile() abort
    let profile = tasks#get_profile()
    redraw
    if profile == v:null
        echon s:badge() 'not a managed project'
    else
        echon s:badge() 'current profile is: ' s:color(profile)
    endif
endfunction

""
" Return current profile, or v:null.
""
function! tasks#get_profile() abort
    let p = tasks#project(0)
    return !empty(p) ? p.profile : v:null
endfunction

""
" Set profile to a new value.
""
function! tasks#set_profile(profile) abort
    let p = tasks#project(0)
    if !empty(p)
        let p.profile = a:profile
        return v:true
    else
        return v:false
    endif
endfunction

""
" Reset project profile to default.
""
function! tasks#unset_profile(prj) abort
    let p = tasks#project()
    if !empty(p)
        let p.profile = 'default'
        return v:true
    else
        return v:false
    endif
endfunction



"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" List tasks
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

""
" Display tasks in the command line, or in json format.
""
function! tasks#list(as_json) abort
    if a:as_json
        call s:tasks_as_json()
        return
    endif
    let prj = tasks#get(1)
    if s:no_tasks(prj)
        return
    endif
    echohl Comment
    echo "Task\t\t\tProfile\t\tOutput\t\tCommand"
    for t in keys(prj.tasks)
        echohl Constant
        echo t . repeat(' ', 24 - strlen(t))
        echohl String
        let p = prj.tasks[t].local ? prj.profile : 'global'
        echon p . repeat(' ', 16 - strlen(p))
        echohl PreProc
        let out = split(get(prj.tasks[t].fields, 'output', 'quickfix'), ':')[0]
        echon out . repeat(' ', 16 - strlen(out))
        echohl None
        let cmd = s:choose_command(prj.tasks[t])
        let n = &columns - 66 < strlen(cmd) ? '' : 'n'
        exe 'echo' . n string(cmd)
    endfor
    echohl None
endfunction

""
" Display tasks in a buffer, in json format.
""
function! s:tasks_as_json() abort
    let py =        executable('python3') ? 'python3'
                \ : executable('python')  ? 'python' : ''
    if py == ''
        echon s:badge() 'no python executable found in $PATH'
        return
    endif
    let [ft, f] = [&ft, @%]
    let json = json_encode(tasks#get(1))
    vnew +setlocal\ bt=nofile\ bh=wipe\ noswf\ nobl
    silent! XTabNameBuffer Tasks
    wincmd H
    put =json
    1d _
    exe '%!' . py . ' -m json.tool'
    setfiletype json
    let &l:statusline = '%#PmenuSel# Tasks %#Pmenu# ft=' .
                \       ft . ' %#Statusline# ' . f
endfunction



"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Choose task with mapping
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

""
" Choose among available tasks (called with mapping).
""
function! tasks#choose() abort
    let i = get(g:, 'tasks_mapping_starts_at', 5)
    let prj = tasks#get(1)
    if s:no_tasks(prj)
        return
    endif
    let Keys = { 1: "\<F1>", 2: "\<F2>", 3: "\<F3>", 4: "\<F4>",
                \5: "\<F5>", 6: "\<F6>", 7: "\<F7>", 8: "\<F8>",
                \9: "\<F9>"}
    let dict = {}
    echohl Comment
    echo "Key\tTask\t\t\tProfile\t\tOutput\t\tCommand"
    for t in keys(prj.tasks)
        let dict[Keys[i]] = t
        echohl Special
        echo '<F'.i.'>' . "\t"
        echohl Constant
        echon t . repeat(' ', 24 - strlen(t))
        echohl String
        let l = prj.tasks[t].local ? prj.profile : 'global'
        echon l . repeat(' ', 16 - strlen(l))
        echohl PreProc
        let out = split(get(prj.tasks[t].fields, 'output', 'quickfix'), ':')[0]
        echon out . repeat(' ', 16 - strlen(out))
        echohl None
        let cmd = s:choose_command(prj.tasks[t])
        if &columns - 74 < strlen(cmd)
            let cmd = cmd[:(&columns - 74)] . '…'
        endif
        echon cmd
        let i += 1
        if i > 12
            let i = 1
        endif
    endfor
    echo ''
    let ch = getchar()
    if index(keys(dict), ch) >= 0
        exe 'Task' dict[ch]
    else
        redraw
    endif
endfunction




"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Get configuration files
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

""
" Path for the global configuration.
""
function! s:get_global_ini() abort
    if exists('s:global_ini') && s:global_ini != ''
        return s:global_ini
    endif

    let f = get(g:, 'async_taskfile_global', 'tasks.ini')
    let l:In = { dir -> filereadable(expand(dir).'/'.f) }
    let l:Is = { dir -> expand(dir).'/'.f }

    let s:global_ini = has('nvim') &&
                \ l:In(stdpath('data'))  ? l:Is(stdpath('data')) :
                \ l:In('$HOME/.vim')     ? l:Is('$HOME/.vim') :
                \ l:In('$HOME/vimfiles') ? l:Is('$HOME/vimfiles') : ''

    if s:global_ini == ''
        let dir = fnamemodify(expand($MYVIMRC), ':p:h')
        if filereadable(dir . '/' . f)
            let s:global_ini = dir . '/' . f
        endif
    endif
    return s:global_ini
endfunction

""
" Path for the project configuration.
""
function! s:get_local_ini() abort
    return get(g:, 'async_taskfile_local', '.tasks')
endfunction



"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Helpers
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

""
" Basename of the working directory.
""
function! s:project_name() abort
    return fnamemodify(getcwd(), ':t')
endfunction

function! s:clear_tasks_names(prj) abort
    if empty(a:prj)
        return {}
    endif
    let renamed_tasks = {}
    for t in keys(a:prj.tasks)
        let rt = s:task_name(t)
        if t != rt
            let renamed_tasks[rt] = remove(a:prj.tasks, t)
        endif
    endfor
    call extend(a:prj.tasks, renamed_tasks)
    return a:prj
endfunction

""
" Strip the conditions modifiers from the task name.
""
function! s:task_name(taskname) abort
    let tn = a:taskname
    if match(tn, '/') > 0
        let tn = split(tn, '/')[0]
    endif
    return tn
endfunction

""
" Echo colored text in the command line.
""
function! s:color(txt) abort
    echohl String | exe 'echon' string(a:txt) | echohl None
    return ''
endfunction

""
" Badge for messages in the command line.
""
function! s:badge(...) abort
    redraw
    if a:0
        echohl WarningMsg | echon '[tasks] ' | echohl None
    else
        echohl Delimiter  | echon '[tasks] ' | echohl None
    endif
    return ''
endfunction

""
" No tasks available for current project/filetye
""
function! s:no_tasks(prj) abort
    if empty(a:prj) || empty(a:prj.tasks)
        echon s:badge() 'no tasks'
        return v:true
    endif
    return v:false
endfunction

""
" Base filetype.
""
function! s:ft() abort
    return empty(&ft) ? '' : split(&ft, '\.')[0]
endfunction

""
" Search recursively for a local tasks file in parent directories.
""
function! s:find_root() abort
    let dir = expand('%:p:h')
    let fname = s:get_local_ini()
    while v:true
        if filereadable(dir . '/' . fname )
            return dir
        elseif fnamemodify(dir, ':p:h:h') == dir
            break
        else
            let dir = fnamemodify(dir, ':p:h:h')
        endif
    endwhile
    return v:null
endfunction

""
" Confirm root change.
""
function! s:change_root(root) abort
    return a:root != v:null &&
                \ confirm('Change directory to ' . a:root . '?', "&Yes\n&No") == 1
endfunction





"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Patterns and script variables
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

let s:is_windows = has('win32') || has('win64') || has('win16') || has('win95')
let s:uname      = s:is_windows ? '' : systemlist('uname')[0]
let s:is_linux   = s:uname == 'Linux'
let s:is_macos   = s:uname == 'Darwin'
let s:is_wsl     = exists('$WSLENV')

let s:taskpat  = '\v^\[\zs\.?(\l+-?\l+)+(\/(\w+,?)+)?\ze](\s+\@\w+)?$'
let s:profpat  = '\v]\s+\@\zs\w+'
let s:envpat   = '^#\(\<env\>\|\<environment\>\)$'
let s:pospat   = '<top>|<bottom>|<left>|<right>'
let s:optspat  = '<grep>|<locl>|<append>|<nofocus>|<nojump>|<noopen>|'.
            \    '<update>|<wall>|<keepouts>|<writelogs>'

let s:patterns = {
            \ 'command':      '\v^command(:(\w+,?)+)?(\/(\w+,?)+)?\ze\=',
            \ 'cwd':          '^cwd\ze=',
            \ 'output':       '^output\ze=',
            \ 'compiler':     '^compiler\ze=',
            \ 'success':      '^success\ze=',
            \ 'fail':         '^fail\ze=',
            \ 'syntax':       '^syntax\ze=',
            \ 'options':      '^options\ze=',
            \ 'errorformat':  '^errorformat\ze=',
            \ 'env':          '\C^[A-Z_]\+\ze=',
            \ 'outfile':      '^outfile\ze=',
            \ 'errfile':      '^errfile\ze=',
            \}

let s:fields = {
            \ 'command':     function('s:validate_command'),
            \ 'cwd':         { k,v -> v =~ '\%(\f\|/\)\+' },
            \ 'output':      function('s:validate_output'),
            \ 'compiler':    { k,v -> v =~ '\w\+' },
            \ 'options':     { k,v -> v =~ '\v(('.s:optspat.'),?)+$' },
            \ 'success':     { k,v -> v:true },
            \ 'fail':        { k,v -> v:true },
            \ 'syntax':      { k,v -> v =~ '\w\+\(\.\w\+\)\?' },
            \ 'errorformat': { k,v -> v:true },
            \ 'outfile':     { k,v -> v =~ '\f\+' },
            \ 'errfile':     { k,v -> v =~ '\f\+' },
            \}





"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" vim: et sw=4 ts=4 sts=4 fdm=marker

" ========================================================================///
" Description: Tasks management inspired by asynctasks.vim
" File:        tasks.vim
" Author:      Gianmaria Bajo <mg1979@git.gmail.com>
" License:     MIT
" Created:     mar 08 settembre 2020 01:58:09
" Modified:    mar 08 settembre 2020 01:58:09
" ========================================================================///


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Tasks getters
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

""
" Get valid tasks, fetched from both global and project-local config files.
" Configuration files are parsed, then merged. Tasks are a nested, so they will
" have to be merged independently, giving precedence to project-local tasks.
" If in a managed project, allow global tasks if they have the 'always' tag.
"
" @param ...: force reloading of config files
" @return: the merged dictionary with tasks
""
function! tasks#get(...) abort
    "{{{1
    " known tags will be regenerated
    let g:tasks['__known_tags__'] = ['default']
    let reload = a:0 && a:1
    let global = deepcopy(tasks#global(reload))
    let local = deepcopy(tasks#project(reload))
    let gtasks = empty(global) ? {} : deepcopy(global.tasks)
    let genv = empty(global) ? {} : copy(global.env)
    if !empty(local)
        call filter(gtasks, "v:val.always")
    endif
    let all = extend(global, local)
    if !empty(all)
        call extend(all.tasks, gtasks, 'keep')
        call extend(all.env, genv, 'keep')
        let all.env = s:expand_env(all.env)
        return all
    endif
    return {}
endfunction "}}}


function! tasks#project(reload) abort
    " Get the project-local tasks dictionary. {{{1
    let prj = s:ut.basedir()
    if !a:reload && has_key(g:tasks, prj)
        return g:tasks[prj]
    endif
    let f = s:get_local_ini()
    if !filereadable(f)
        return {}
    endif
    let g:tasks[prj] = tasks#parse#do(readfile(f), 1)
    return g:tasks[prj]
endfunction "}}}


function! tasks#global(reload) abort
    " Get the global tasks dictionary. {{{1
    if !a:reload && has_key(g:tasks, 'global')
        return g:tasks.global
    endif
    let f = s:get_global_ini()
    if !filereadable(f)
        return {}
    endif
    let g:tasks.global = tasks#parse#do(readfile(f), 0)
    return g:tasks.global
endfunction "}}}


" TODO: :Project, :Compile commands
" TODO: test environmental variables expansion
" TODO: assign score to commands to see which one should be chosen
" TODO: cwd, prjname
" TODO: success/fail hooks



"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Run task
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

function! tasks#run(args) abort
    " Main command to run a task. Will call async#cmd. {{{1
    redraw
    let prj = tasks#get()
    if empty(prj)
        let root = s:find_root()
        if s:change_root(root)
            lcd `=root`
            let prj = tasks#get()
        endif
    endif
    if s:no_tasks(prj)
        return
    endif
    let tasks = prj.tasks
    let a = split(a:args)
    let name = a[0]

    if !has_key(tasks, name)
        echon s:ut.badge() 'not a valid task'
        return
    endif

    let task = tasks[name]
    let cmd = s:choose_command(task)
    let args = len(a) > 1 ? join(a[1:]) : get(task.fields, 'args', '')
    let mode = s:get_cmd_mode(task)
    let options = get(task.fields, 'options', [])

    if mode ==# 'vim'
        call s:execute_vim_command(cmd, args, options)
        return
    endif

    let opts = extend(s:get_pos(mode), s:get_opts(options))
    let useropts = extend({
                \ 'makeprg': cmd,
                \ 'grepprg': cmd,
                \ 'errorformat': get(task.fields, 'errorformat', s:bvar('&errorformat')),
                \ 'grepformat': get(task.fields, 'grepformat', s:bvar('&grepformat')),
                \ 'compiler': get(task.fields, 'compiler', ''),
                \ 'ft': get(task.fields, 'syntax', ''),
                \}, opts)
    let jobopts = {
                \ 'env': prj.env,
                \ 'cwd': s:get_cwd(prj, task),
                \}
    let mode = substitute(mode, ':.*', '', '')
    if mode == 'quickfix'
        call async#qfix(args, useropts, jobopts)
    else
        call async#cmd(cmd . ' ' . args, mode, useropts, jobopts)
    endif
endfunction "}}}


function! s:execute_vim_command(cmd, args, options)
    " It's a vim command, execute as-is. {{{1
    if index(a:options, 'wall') >= 0
        wall
    elseif index(a:options, 'nosave') == -1
        update
    endif
    if a:args != ''
        execute a:cmd . ' ' . a:args
    else
        execute a:cmd
    endif
endfunction "}}}


function! s:expand_env(env)
    " Expand special environmental variables. {{{1
    "
    " The two patterns may be combined:
    "
    " pattern VAR:= means vim filename modifiers are expanded, the variable is then
    "               assigned in the environment.
    "
    " pattern @VAR= means the content will be substituted in all other
    "               environmental variables that contain it. The variable is NOT
    "               assigned in the environment.
    for k in keys(a:env)
        if k =~ ':$'
            let nk = k[:-2]
            let nv = async#expand(a:env[k])
            unlet a:env[k]
            let a:env[nk] = nv
        endif
    endfor
    for k in keys(a:env)
        if k =~ '^@'
            let v = a:env[k]
            call map(a:env, 'substitute(v:val, "\\V" . k, v, "g")')
            unlet a:env[k]
        endif
    endfor
    return a:env
endfunction "}}}


function! s:choose_command(task) abort
    " Choose the most appropriate command for the task. {{{1
    let [cmdpat, cmppat, ft] = ['^command', '^compiler', '\<' . s:ut.ft() . '\>']

    " try 'compiler' first, then 'command'
    let cmds = filter(copy(a:task.fields), 'v:key =~ cmppat')
    if empty(cmds)
        let cmds = filter(copy(a:task.fields), 'v:key =~ cmdpat')
    endif
    " loop all the commands and choose the one with the highest score
    " score is based on specificity for system (/) and filetype (:)
    " best has elements: [key, command, score]
    let best = ['', '', 0]
    for key in keys(cmds)
        let score = (key =~ '/') + (key =~ ':')
        if score >= best[2]
            let best = [key, cmds[key], score]
        endif
    endfor

    " clear all commands from task, the chosen command will be set instead
    call filter(a:task.fields, 'v:key !~ cmdpat')
    call filter(a:task.fields, 'v:key !~ cmppat')
    if best[1] != ''
        let a:task.fields[best[0]] = best[1]
        return best[1]
    endif
    return index(get(a:task.fields, 'options', []), 'grep') >= 0
                \ ? s:bvar('&grepprg')
                \ : s:bvar('&makeprg')
endfunction "}}}


function! s:get_cwd(prj, task) abort
    " If the task defines a cwd, it should be expanded. {{{1
    " Expand also $ROOT and $PRJNAME because they aren't set in vim environment.
    if has_key(a:task.fields, 'cwd')
        let cwd = async#expand(a:task.fields.cwd)
        if s:v.is_windows
            let cwd = substitute(cwd, '%\([A-Z_]\+\)%', '$\1', 'g')
        endif
        let cwd = s:expand_builtin_envvars(cwd, a:prj, 0)
        let cwd = substitute(cwd, '\(\$[A-Z_]\+\)\>', '\=expand(submatch(1))', 'g')
        return cwd
    else
        return expand(getcwd())
    endif
endfunction "}}}


function! s:expand_task_cmd(task, prj)
    " Returns task command with expanded env variables and vim placeholders. {{{1
    let cmd = async#expand(s:choose_command(a:task))
    let args = get(a:task.fields, 'args', '')
    let args = empty(args) ? '' : ' ' . async#expand(args)
    return s:expand_builtin_envvars(cmd . args, a:prj, a:task.local)
endfunction "}}}


function! s:expand_builtin_envvars(string, prj, expand_prjname) abort
    " Expand built-in variables $ROOT and $PRJNAME. {{{1
    let s = substitute(a:string, '\$ROOT\>', '\=expand(getcwd())', 'g')
    if a:expand_prjname
        let s = substitute(s, '\$PRJNAME\>', '\=a:prj.info.name', 'g')
    endif
    return s
endfunction "}}}


function! s:get_cmd_mode(task) abort
    " Either 'quickfix', 'buffer', 'terminal', 'external', 'cmdline' or 'vim'. {{{1
    let mode = filter(copy(a:task.fields), { k,v -> k =~ '^output' })
    return len(mode) > 0 ? values(mode)[0] : 'quickfix'
endfunction "}}}


function! s:get_pos(mode) abort
    " Buffer and terminal modes can define position after ':' {{{1
    if a:mode !~ '\v^(buffer|terminal):'.s:v.pospat
        return {}
    else
        return {'pos': substitute(a:mode, '^\w\+:', '', '')}
    endif
endfunction "}}}


function! s:get_opts(opts) abort
    " All options have a default of 0. {{{1
    " Options defined in the 'options' field will be set to 1.
    let opts = {}
    for v in a:opts
        let opts[v] = 1
    endfor
    return opts
endfunction "}}}


function! tasks#complete(A, C, P) abort
    " Command line completion for tasks. {{{1
    let valid = keys(get(tasks#get(), 'tasks', {}))
    return filter(sort(valid), 'v:val=~#a:A')
endfunction "}}}


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" List tasks
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

function! tasks#list(as_json) abort
    " Display tasks in the command line, or in json format. {{{1
    let prj = tasks#get(1)
    if s:no_tasks(prj)
        return
    endif
    if a:as_json
        call s:tasks_as_json(prj)
        return
    endif
    call s:cmdline_bar(prj)
    echohl Comment
    echo "Task\t\t\t\tTag\t\tOutput\t\tCommand"
    for t in sort(keys(prj.tasks))
        let T = prj.tasks[t]
        ""
        " --------------------------- [ task name ] ---------------------------
        ""
        echohl Constant
        echo t . repeat(' ', 32 - strlen(t))
        ""
        " --------------------------- [ task tag ] ----------------------------
        ""
        echohl String
        let p = T.tag == 'default'
                    \ ? T.local ? 'project' : 'global'
                    \ : T.tag
        echon p . repeat(' ', 16 - strlen(p))
        ""
        " -------------------------- [ output type ] --------------------------
        ""
        echohl PreProc
        let out = split(get(T.fields, 'output', 'quickfix'), ':')[0]
        echon out . repeat(' ', 16 - strlen(out))
        ""
        " ------------------------- [ task command ] -------------------------
        ""
        echohl None
        let cmd = s:expand_task_cmd(T, prj)
        let n = &columns - 66 < strlen(cmd) ? '' : 'n'
        exe 'echo' . n string(cmd)
    endfor
    echohl None
endfunction "}}}


function! s:cmdline_bar(prj) abort
    " Top bar for command-line tasks list. {{{1
    echohl QuickFixLine
    let header = has_key(a:prj, 'info') ?
                \'Project: '. a:prj.info.name : 'Global tasks'
    let right   = repeat(' ', &columns - 10 - strlen(header))
    echon '      ' . header . '   ' . right
endfunction "}}}


function! s:tasks_as_json(prj) abort
    " Display tasks in a buffer, in json format. {{{1
    let py =        executable('python3') ? 'python3'
                \ : executable('python')  ? 'python' : ''
    if py == ''
        echon s:ut.badge() 'no python executable found in $PATH'
        return
    endif
    let [ft, f] = [&ft, @%]
    let json = json_encode(a:prj)
    vnew +setlocal\ bt=nofile\ bh=wipe\ noswf\ nobl
    silent! XTabNameBuffer Tasks
    wincmd H
    put =json
    1d _
    exe '%!' . py . ' -m json.tool'
    setfiletype json
    let &l:statusline = '%#PmenuSel# Tasks %#Pmenu# ft=' .
                \       ft . ' %#Statusline# ' . f
endfunction "}}}



"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Choose task with mapping
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

""
" Choose among available tasks (called with mapping).
" @param ...: prompt for extra args
""
function! tasks#choose(...) abort
    "{{{1
    let prj = tasks#get(1)
    if s:no_tasks(prj)
        return
    endif
    let use_F = get(g:, 'tasks_mapping_use_Fn_keys', 6)
    if use_F && len(keys(prj.tasks)) == 1
        let f = substitute("\<F6>", '6$', use_F, '')
        let Keys = { 1: f}
        let l:PnKey = { c -> '<F'. use_F .'>' . "\t"}
    elseif use_F && len(keys(prj.tasks)) <= 8
        let Keys = { 1: "\<F5>", 2: "\<F6>", 3: "\<F7>", 4: "\<F8>",
                    \5: "\<F9>", 6: "\<F10>", 7: "\<F11>", 8: "\<F12>"}
        let l:PnKey = { c -> '<F'.(c+4).'>' . "\t"}
    elseif use_F && len(keys(prj.tasks)) <= 12
        let Keys = { 1: "\<F1>", 2: "\<F2>", 3: "\<F3>", 4: "\<F4>",
                    \5: "\<F5>", 6: "\<F6>", 7: "\<F7>", 8: "\<F8>",
                    \9: "\<F9>", 10: "\<F10>", 11: "\<F11>", 12: "\<F12>"}
        let l:PnKey = { c -> '<F'.c.'>' . "\t"}
    else
        let Keys = {}
        for i in range(1, 26)
            let Keys[i] = nr2char(96 + i)
        endfor
        let l:PnKey = { c -> Keys[c] . "\t"}
    endif
    let dict = {}
    let i = 1
    call s:cmdline_bar(prj)
    echohl Comment
    echo "Key\tTask\t\t\t\tTag\t\tOutput\t\tCommand"
    for t in sort(keys(prj.tasks))
        let T = prj.tasks[t]
        if has_key(T.fields, 'mapping')
            let Keys[i] = T.fields.mapping
            let map = T.fields.mapping ."\t"
        else
            let map = l:PnKey(i)
        endif
        let dict[Keys[i]] = t
        ""
        " ---------------------------- [ mapping ] ----------------------------
        ""
        echohl Special
        echo map
        ""
        " --------------------------- [ task name ] ---------------------------
        ""
        echohl Constant
        echon t . repeat(' ', 32 - strlen(t))
        ""
        " --------------------------- [ task tag ] ----------------------------
        ""
        echohl String
        let p = T.tag == 'default'
                    \ ? T.local ? 'project' : 'global'
                    \ : T.tag
        echon p . repeat(' ', 16 - strlen(p))
        ""
        " -------------------------- [ output type ] --------------------------
        ""
        echohl PreProc
        let out = split(get(T.fields, 'output', 'quickfix'), ':')[0]
        echon out . repeat(' ', 16 - strlen(out))
        ""
        " ------------------------- [ task command ] -------------------------
        ""
        echohl None
        let cmd = s:expand_task_cmd(T, prj)
        if &columns - 84 < strlen(cmd)
            let cmd = cmd[:(&columns - 84)] . '…'
        endif
        echon cmd
        let i += 1
    endfor
    echo ''
    let ch = getchar()
    let ch = ch > 0 ? nr2char(ch) : ch
    if index(keys(dict), ch) >= 0
        if a:0
            redraw
            echohl Delimiter  | echo 'Command: ' | echohl None
            echon s:expand_task_cmd(prj.tasks[dict[ch]], prj)
            let args = input('args: ')
            if empty(args) && confirm('Run with no arguments?', "&Yes\n&No") != 1
                redraw
                echo 'Canceled'
                return
            endif
        else
            let args = ''
        endif
        exe 'Task' dict[ch] args
    else
        redraw
    endif
endfunction "}}}




"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Get configuration files
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""


function! s:get_global_ini() abort
    " Path for the global configuration. {{{1
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
endfunction "}}}


function! s:get_local_ini() abort
    " Path for the project configuration. {{{1
    return getcwd() . '/' . get(g:, 'async_taskfile_local', '.tasks')
endfunction "}}}



"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Helpers
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""


function! s:no_tasks(prj) abort
    " No tasks available for current project/filetye. {{{1
    if empty(a:prj) || empty(a:prj.tasks)
        echon s:ut.badge() 'no tasks'
        return v:true
    endif
    return v:false
endfunction "}}}


function! s:find_root() abort
    " Search recursively for a local tasks file in parent directories. {{{1
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
endfunction "}}}


function! s:change_root(root) abort
    " Confirm root change. {{{1
    return a:root != v:null &&
                \ confirm('Change directory to ' . a:root . '?', "&Yes\n&No") == 1
endfunction "}}}





"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Script variables
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

let s:ut   = tasks#util#init()
let s:v    = s:ut.Vars
let s:bvar = { v -> getbufvar(bufnr(''), v) }


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" vim: ft=vim et ts=4 sw=4 fdm=marker

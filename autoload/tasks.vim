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
        let all.info = extend(get(all, 'globinfo', {}), get(all, 'info', {}))
        silent! unlet all.globinfo
        return all
    endif
    return {}
endfunction "}}}


function! tasks#project(reload) abort
    " Get the project-local tasks dictionary. {{{1
    let root = s:ut.find_root()
    if empty(root)
        return {}
    endif
    let prj = s:ut.basedir()
    if !a:reload && has_key(g:tasks, prj)
        return g:tasks[prj]
    endif
    let g:tasks[prj] = tasks#parse#do(readfile(s:ut.local_ini()), 1)
    let g:tasks[prj].root = root
    return g:tasks[prj]
endfunction "}}}


function! tasks#global(reload) abort
    " Get the global tasks dictionary. {{{1
    if !a:reload && has_key(g:tasks, 'global')
        return g:tasks.global
    endif
    let f = s:ut.global_ini()
    if !filereadable(f)
        return {}
    endif
    let g:tasks.global = tasks#parse#do(readfile(f), 0)
    let g:tasks.global.root = getcwd()
    return g:tasks.global
endfunction "}}}



"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Other public functions
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

function! tasks#expand_cmd(task, prj)
    " Returns task command with expanded env variables and vim placeholders. {{{1
    let cmd = async#expand(s:choose_command(a:task))
    let args = get(a:task.fields, 'args', '')
    let args = empty(args) ? '' : ' ' . async#expand(args)
    return s:expand_builtin_envvars(cmd . args, a:prj, a:task.local)
endfunction "}}}


function! tasks#complete(A, C, P) abort
    " Command line completion for tasks. {{{1
    let valid = keys(get(tasks#get(), 'tasks', {}))
    return filter(sort(valid), 'v:val=~#a:A')
endfunction "}}}



"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Run task
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

function! tasks#run(args, ...) abort
    " Main command to run a task. Will call async#cmd. {{{1
    redraw
    let prj = tasks#get()

    if !empty(prj) && prj.root != getcwd()
        let [olddir, oldbuf] = [getcwd(), bufnr('')]
        call s:ut.setwd(prj.root)
    else
        let olddir = v:null
    endif

    if s:ut.no_tasks(prj)
        if !a:0 || !a:1
            redraw
            throw '[vim-tasks] not a valid task'
        endif
        return
    endif
    let tasks = prj.tasks
    let a = split(a:args)
    let name = a[0]

    if !has_key(tasks, name)
        if !a:0 || !a:1
            throw '[vim-tasks] not a valid task'
        else
            echon s:ut.badge() 'not a valid task'
        endif
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
                \ 'unlisted': task.unlisted,
                \ 'discard': task.discard,
                \ 'hidden': task.hidden,
                \ 'wd': prj.root,
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

    if olddir isnot v:null && bufnr('') == oldbuf
        call s:ut.setwd(olddir)
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
        return a:prj.root
    endif
endfunction "}}}


function! s:expand_builtin_envvars(string, prj, expand_prjname) abort
    " Expand built-in variables $ROOT and $PRJNAME. {{{1
    let s = substitute(a:string, '\$ROOT\>', '\=a:prj.root', 'g')
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



"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Script variables
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

let s:ut   = tasks#util#init()
let s:v    = s:ut.Vars
let s:bvar = { v -> getbufvar(bufnr(''), v) }


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" vim: ft=vim et ts=4 sw=4 fdm=marker

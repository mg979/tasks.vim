" ========================================================================###
" Description: Script defining the Task class
" File:        task.vim
" Author:      Gianmaria Bajo <mg1979@git.gmail.com>
" License:     MIT
" Created:     sab 21 novembre 2020 08:51:08
" Modified:    sab 21 novembre 2020 08:51:08
" ========================================================================###

function! tasks#task#new(project, local, name) abort
    let t = {}
    let t.validate = function('s:validate_task')
    let t.local = a:local
    let t.fields = {}
    let t.type = s:type(a:name)
    let t.patterns = s:patterns_{t.type}
    let a:project.tasks[a:name] = t
    return t
endfunction

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

let s:Task = {}

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Validate tasks
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

""
" Function: s:validate_task (filter function)
" @param project: the configuration file (local or global) the task belong to
" @param name:    name of the task (key of the project.tasks element)
" Returns: true if the task is valid
""
function! s:validate_task(project, name) abort dict
    let [p, n, t] = [a:project, a:name, self]
    if s:is_env(p, n, t)            | return v:false | endif
    if s:is_projects_info(p, n, t)  | return v:false | endif
    if s:failing_conditions(n)      | return v:false | endif
    if s:no_valid_fields(t.fields)  | return v:false | endif

    call s:clean_up_task(t)
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
    if a:task.type != 'env'
        return v:false
    endif
    call extend(a:project.env, a:task.fields)
    return v:true
endfunction


function! s:is_projects_info(project, name, task) abort
    if a:task.type != 'info'
        return v:false
    endif
    let info = a:project.info
    call extend(info, a:task.fields)
    let info.profiles = split(get(info, 'profiles', 'default'), ',')
    if index(info.profiles, 'default') < 0
        call insert(info.profiles, 'default')
    endif
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
                if     cond ==? 'linux'   && !s:v.is_linux   | return v:true
                elseif cond ==? 'macos'   && !s:v.is_macos   | return v:true
                elseif cond ==? 'windows' && !s:v.is_windows | return v:true
                elseif cond ==? 'wsl'     && !s:v.is_wsl     | return v:true
                elseif !l:Has(cond)                          | return v:true
                endif
            endfor
        else
            for cond in split(conds, ',')
                if l:Has(cond)                              | return v:false
                elseif cond ==? 'linux'   && s:v.is_linux   | return v:false
                elseif cond ==? 'macos'   && s:v.is_macos   | return v:false
                elseif cond ==? 'windows' && s:v.is_windows | return v:false
                elseif cond ==? 'wsl'     && s:v.is_wsl     | return v:false
                endif
            endfor
            return v:true
        endif
    endif
    return v:false
endfunction


""
" Check the validity of the entered fields. One 'command' must be defined.
""
function! s:no_valid_fields(fields) abort
    call filter(a:fields, function("s:valid_field"))
    return empty(a:fields) || s:no_command(a:fields)
endfunction


""
" Check that one 'command' field has been defined for the task.
""
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

""
" The field name can contain modifiers, therefore regex must be used in the
" comparison with the 's:fields' dict key. The field is valid if:
"
"   s:fields[matched field]()   -> must return true
""
function! s:valid_field(key, val) abort
    for f in keys(s:fields)
        if a:key =~ f
            return s:fields[f](a:key, a:val)
        endif
    endfor
    return v:false
endfunction


function! s:validate_output(key, val) abort
    if a:val =~ '^terminal'
        return a:val =~ '^\vterminal(:('.s:v.pospat.'))?(:\d+)?$'
    elseif a:val =~ '^buffer'
        return a:val =~ '^\vbuffer(:('.s:v.pospat.'))?(:\d+)?$'
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
    return index(fts, s:ut.ft()) >= 0
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
" Clean-up
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

""
" Clean up task from invalid/unnecessary fields.
""
function! s:clean_up_task(task) abort
    let t = a:task
    " remove private fields
    unlet t.validate
    unlet t.type
    unlet t.patterns
    " remove invalid options
    if has_key(t.fields, 'options')
        let t.fields.options = split(t.fields.options, ',')
        call filter(t.fields.options, 'index(s:options, v:val) >= 0')
    endif
endfunction


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Script variables and task fields patterns
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

let s:ut = tasks#util#init()
let s:v  = s:ut.Vars

let s:type = { n -> n == '__env__' ? 'env' : n == '__info__' ? 'info' : 'task' }

let s:patterns_env = {
            \ 'envvar': '\C^[A-Z_]\+\ze=',
            \}

let s:patterns_info = {
            \ 'name': '^name\ze=',
            \ 'description': '^description\ze=',
            \ 'profiles': '^profiles\ze=',
            \}

let s:patterns_task = {
            \ 'command':      '\v^command(:(\w+,?)+)?(\/(\w+,?)+)?\ze\=',
            \ 'cwd':          '^cwd\ze=',
            \ 'output':       '^output\ze=',
            \ 'compiler':     '^compiler\ze=',
            \ 'success':      '^success\ze=',
            \ 'fail':         '^fail\ze=',
            \ 'syntax':       '^syntax\ze=',
            \ 'options':      '^options\ze=',
            \ 'errorformat':  '^errorformat\ze=',
            \ 'outfile':      '^outfile\ze=',
            \ 'errfile':      '^errfile\ze=',
            \}

let s:options = [
            \'grep', 'locl', 'append',
            \'nofocus', 'nojump', 'noopen',
            \'nosave', 'wall', 'keepouts',
            \'writelogs', 'termonquit',
            \]

let s:fields = {
            \ 'command':     function('s:validate_command'),
            \ 'cwd':         { k,v -> v =~ '\%(\f\|/\)\+' },
            \ 'output':      function('s:validate_output'),
            \ 'compiler':    { k,v -> v =~ '\w\+' },
            \ 'success':     { k,v -> v:true },
            \ 'fail':        { k,v -> v:true },
            \ 'syntax':      { k,v -> v =~ '\w\+\(\.\w\+\)\?' },
            \ 'options':     { k,v -> v:true },
            \ 'errorformat': { k,v -> v:true },
            \ 'outfile':     { k,v -> v =~ '\f\+' },
            \ 'errfile':     { k,v -> v =~ '\f\+' },
            \}







"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" vim: et sw=4 ts=4 sts=4 fdm=indent fdn=1

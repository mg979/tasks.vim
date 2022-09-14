" ========================================================================###
" Description: Script for tasks validation
" File:        task.vim
" Author:      Gianmaria Bajo <mg1979@git.gmail.com>
" License:     MIT
" Created:     sab 21 novembre 2020 08:51:08
" Modified:    sab 21 novembre 2020 08:51:08
" ========================================================================###

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Script variables
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

let s:ut = tasks#util#init()
let s:v  = s:ut.Vars
let s:valid_sections = ['info', 'infoglobal', 'env']


""-----------------------------------------------------------------------------
" Function: tasks#task#new
"
" This function receives a parsed section of the configuration file (either
" a special section or a proper task), and must validate all the parsed fields.
"
" @param project: the object of the project the task belongs to
" @param local:   if it's a local task
" @param name:    string with the name of the task/special section
" Returns: the task/section object
""-----------------------------------------------------------------------------
function! tasks#task#new(project, local, name) abort
    let t = {}
    let t.validate = function('s:validate_task')
    let t.local = a:local ? v:true : v:false
    let t.fields = {}
    let t.type = s:type(a:name)
    let t.patterns = s:patterns_{t.type}
    let a:project.tasks[a:name] = t
    let a:project.haslocalcfg = t.local
    return t
endfunction

function! s:type(name)
    let type = substitute(a:name, '^__\|__$', '', 'g')
    return index(s:valid_sections, type) >= 0 ? type : 'task'
endfunction



"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Validate tasks
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

""
" Function: s:validate_task (filter function)
"
" Special sections (env, info...) will not be considered valid tasks, but they
" are processed and merged into the project root.
" This is the validate() filter function used at the end of tasks#parse#do().
"
" @param project: the configuration file (local or global) the task belong to
" @param name:    name of the task/section (key of the project.tasks element)
" Returns: true if the task/section is valid
""
function! s:validate_task(project, name) abort dict
    let [p, n, t] = [a:project, a:name, self]
    if s:is_env_section(p, n, t)    | return v:false | endif
    if s:is_spec_section(p, n, t)   | return v:false | endif
    if s:failing_conditions(n)      | return v:false | endif
    if s:no_valid_fields(t.fields)  | return v:false | endif
    if s:failing_fields(t.fields)   | return v:false | endif

    call s:clean_up_task(t)
    return v:true
endfunction



"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Special sections
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
""
" These are not real tasks, so they will not be validated, but their fields
" will be stored in the root of the project dict, instead. They are:
"
"   #project    local to project, it contains informations about the project,
"               plus project-specific options
"   #global     same purpose as #project, but only valid in global configuration
"               currently there is little use for this, see s:patterns_infoglobal
"   #env        local to project, it contains environmental variables that will
"               be set before the command is executed
""

function! s:is_env_section(project, name, task) abort
    if a:task.type != 'env'
        return v:false
    endif
    call extend(a:project.env, a:task.fields)
    return v:true
endfunction


function! s:is_spec_section(project, name, task) abort
    let local = a:project.haslocalcfg
    if local && a:task.type != 'info' || !local && a:task.type != 'infoglobal'
        return v:false
    endif
    let info = local ? a:project.info : a:project.infoglobal
    call extend(info, a:task.fields)
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
        let Has = { cond -> cond !~? '\clinux\|windows\|macos\|wsl' && has(cond) }
        let [_, conds] = split(a:item, '/')
        if match(conds, '+') >= 0
            for cond in split(conds, '+')
                if     cond ==? 'linux'   && !s:v.is_linux   | return v:true
                elseif cond ==? 'macos'   && !s:v.is_macos   | return v:true
                elseif cond ==? 'windows' && !s:v.is_windows | return v:true
                elseif cond ==? 'wsl'     && !s:v.is_wsl     | return v:true
                elseif !Has(cond)                            | return v:true
                endif
            endfor
        else
            for cond in split(conds, ',')
                if Has(cond)                                | return v:false
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


function! s:failing_fields(fields)
    if has_key(a:fields, 'ifexists')
        for v in split(a:fields.ifexists, ',')
            if filereadable(v) || isdirectory(v) || expand(v) != v
                return v:false
            endif
        endfor
        return v:true
    endif
    return v:false
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
        return a:val =~ '^\vterminal(:.*)?$'
    elseif a:val =~ '^buffer'
        return a:val =~ '^\vbuffer(:.*)?$'
    elseif a:val =~ '^external'
        return a:val =~ '^external\(:[[:alnum:]_-]\+\)\?$'
    else
        return index(['quickfix', 'cmdline', 'headless', 'vim'], a:val) >= 0
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
"   TASK FIELDS PATTERNS
"
" The s:patterns_* variables hold valid patterns for each section. If a line
" contained in a section matches a pattern, it is a valid field.
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

""
" The only valid pattern for fields in the #env section are capitalized
" environmental variables, optionally preceded by @/& modifiers, see:
" :help tasks-environment
""
let s:patterns_env = {
            \ 'envvar': '\C^[@&]\?[A-Z_]\+:\?\ze=',
            \}

""
" Valid patterns for fields in the #project section.
" Note: 'options' is unused.
""
let s:patterns_info = {
            \ 'name': '^name\ze=',
            \ 'description': '^description\ze=',
            \ 'options': '^options\ze=',
            \ 'filerotate': '^filerotate\ze=',
            \}

""
" Valid patterns for fields in the #global section.
" Note: 'options' is unused.
""
let s:patterns_infoglobal = {
            \ 'options': '^options\ze=',
            \}

""
" Valid patterns for task fields and their values.
""
let s:patterns_task = {
            \ 'command':      '\v^command(:(\w+,?)+)?(\/(\w+,?)+)?\ze\=',
            \ 'cwd':          '^cwd\ze=',
            \ 'output':       '^output\ze=',
            \ 'compiler':     '^compiler\ze=',
            \ 'success':      '^success\ze=',
            \ 'fail':         '^fail\ze=',
            \ 'syntax':       '^syntax\ze=',
            \ 'args':         '^args\ze=',
            \ 'options':      '^options\ze=',
            \ 'mapping':      '^mapping\ze=',
            \ 'errorformat':  '^errorformat\ze=',
            \ 'grepformat':   '^grepformat\ze=',
            \ 'outfile':      '^outfile\ze=',
            \ 'errfile':      '^errfile\ze=',
            \ 'ifexists':     '^ifexists\ze=',
            \}

""
" Valid values for the 'options' field of tasks sections.
" NOTE: also #project and #global support an 'options' field, but it is
" currently unused.
""
let s:options = [
            \'grep', 'locl', 'append',
            \'focus', 'nojump', 'openqf',
            \'nosave', 'wall', 'keepouts',
            \'writelogs', 'noquit', 'noenv',
            \]

""
" Once a task line matches a pattern, it can be a valid field, but it must also
" satisfy a condition, different for every type of field.
""
let s:fields = {
            \ 'command':     function('s:validate_command'),
            \ 'cwd':         { k,v -> v =~ '\%(\f\|/\)\+' },
            \ 'output':      function('s:validate_output'),
            \ 'compiler':    { k,v -> v =~ '\w\+' },
            \ 'success':     { k,v -> v:true },
            \ 'fail':        { k,v -> v:true },
            \ 'syntax':      { k,v -> v =~ '\w\+\(\.\w\+\)\?' },
            \ 'args':        { k,v -> v:true },
            \ 'mapping':     { k,v -> v =~ '^.$\|^f[1-9]$\|^f1[0-2]$' },
            \ 'options':     { k,v -> v:true },
            \ 'errorformat': { k,v -> v:true },
            \ 'grepformat':  { k,v -> v:true },
            \ 'outfile':     { k,v -> v =~ '\f\+' },
            \ 'errfile':     { k,v -> v =~ '\f\+' },
            \ 'ifexists':    { k,v -> v:true },
            \}







"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" vim: et sw=4 ts=4 sts=4 fdm=indent fdn=1

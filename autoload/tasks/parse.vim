" ========================================================================###
" Description: parse global/project-local configuration files
" File:        parse.vim
" Author:      Gianmaria Bajo <mg1979@git.gmail.com>
" License:     MIT
" Created:     sab 21 novembre 2020 11:46:08
" Modified:    sab 21 novembre 2020 11:46:08
" ========================================================================###

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Parse configuration files
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Tasks can be defined at global level or per project. Project-local tasks
" override global tasks with the same name.
"
" When one tries to run a task, the global file and the local file are parsed
" and merged. The parsed tasks are stored in the global table g:tasks.
"
" The g:tasks table has the following structure:
"
"   g:tasks = {
"     global = {
"         tasks,        DICT
"     },
"     project_1 = {
"         info,         DICT
"         env,          DICT
"         tasks,        DICT
"     },
"     ...
"   }
"
" Elements in x.tasks have the following structure:
"
"   taskname = {
"     local,            BOOL
"     fields,           DICT
"     tag,              STRING
"     warnings,         LIST        TODO
"   }
"
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Function: tasks#parse#do
" Parse and validate a tasks config file.
"
" @param lines: lines of the tasks file
" @param local: true if it's a project-local tasks file
"
" Returns: the validated tasks for the parsed configuration file
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! tasks#parse#do(lines, local) abort
    "{{{1
    if empty(a:lines)
        return {}
    endif
    let p = s:new_config(a:local)
    let l:NewSection = function('tasks#task#new', [p, a:local])
    let current = v:null

    for line in a:lines
        if empty(line) || match(line, '^;') == 0
            continue

        elseif match(line, s:envsect) == 0
            let current = l:NewSection('__env__')

        elseif a:local && match(line, s:infosect) == 0
            let current = l:NewSection('__info__')

        elseif !a:local && match(line, s:globsect) == 0
            let current = l:NewSection('__info__')

        elseif match(line, s:tasksect) == 1
            """""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
            " before creating a task, we check its tag, or we could overwrite
            " a valid task with one with the same name, if the tag is wrong,
            " ignore the section's fields. We also check for the 'always' tag.
            """""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
            let always = a:local || line =~ '\s\+@always\>'
            if always
                let line = substitute(line, '\s\+@always\>', '', 'g')
            endif
            let tag = s:get_tag(line)
            if s:wrong_tag(tag)
                let current = v:null
                continue
            endif
            let current = l:NewSection(matchstr(line, s:tasksect))
            let current.tag = tag
            if !a:local
                let current.always = always
            endif

        elseif current isnot v:null
            for pat in values(current.patterns)
                if match(line, pat) == 0
                    let item = matchstr(line, pat)
                    let current.fields[item] = substitute(line, item . '=', '', '')
                    break
                endif
            endfor
        endif
    endfor
    call filter(p.tasks, { k,v -> v.validate(p,k)})
    call s:update_prjname(p, a:local)
    return s:filter_tasks_by_os(p)
endfunction "}}}


""
" If the task is project-local, task tag must match the current one.
""
function! s:get_tag(line) abort
    "{{{1
    if a:line =~ s:tagpat
        let tag = matchstr(a:line, s:tagpat)
        if index(g:tasks['__known_tags__'], tag) < 0
            call add(g:tasks['__known_tags__'], tag)
        endif
        return tag
    endif
    return 'default'
endfunction "}}}



""
" If the task is project-local, task tag must match the current one.
""
function! s:wrong_tag(tag) abort
    "{{{1
    return g:tasks['__tag__'] !=# a:tag
endfunction "}}}



"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Helpers
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

""
" Constructor for project/global configuration.
""
function! s:new_config(local) abort
    "{{{1
    let p = { 'tasks': {}, 'env': {'ROOT': expand(getcwd())} }
    if a:local
        call extend(p.env, {'PRJNAME': s:ut.basedir()})
        let p.info = { 'name': s:ut.basedir() }
    else
        let p.info = {}
    endif
    return p
endfunction "}}}

""
" Update the PRJNAME env variable to match the project's name.
""
function! s:update_prjname(prj, local) abort
    "{{{1
    if a:local
        let a:prj.env['PRJNAME'] = a:prj.info.name
    endif
endfunction "}}}

""
" Remove modifiers from task names, selecting the most appropriate for the
" current OS.
""
function! s:filter_tasks_by_os(prj) abort
    "{{{1
    if s:v.is_wsl
        " if using WSL and the same task is also defined for Linux, prefer WSL
        " version.
        let ks = keys(a:prj.tasks)
        for t in ks
            if match(t, '\c/wsl') >= 0
                let name = split(t, '/')[0]
                let linux = match(ks, name . '/\clinux')
                if linux >= 0
                    call remove(a:prj.tasks, ks[linux])
                endif
            endif
        endfor
    endif
    let renamed_tasks = {}
    for t in keys(a:prj.tasks)
        let rt = split(t, '/')[0]
        if t != rt
            let renamed_tasks[rt] = remove(a:prj.tasks, t)
        endif
    endfor
    call extend(a:prj.tasks, renamed_tasks)
    return a:prj
endfunction "}}}


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Script variables
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
let s:tagpat  = '\v]\s+\@\zs\w+'
" let s:tagpat  = '\v]\s+\zs\(\@\w+\s*\)\+'

let s:tasksect = '\v^\[\zs\.?(\w+-?\w+)+(\/(\w+,?)+)?\ze](\s+\@\w+)*\s*$'
let s:envsect  = '^#env\(ironment\)\?$'
let s:infosect = '^#project$'
let s:globsect = '^#global$'

let s:ut = tasks#util#init()
let s:v  = s:ut.Vars




"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" vim: et sw=4 ts=4 sts=4 fdm=marker

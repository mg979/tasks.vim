" ========================================================================///
" Description: Tasks management inspyred by asynctasks.vim
" File:        tasks.vim
" Author:      Gianmaria Bajo <mg1979@git.gmail.com>
" License:     MIT
" Created:     mar 08 settembre 2020 01:58:09
" Modified:    mar 08 settembre 2020 01:58:09
" ========================================================================///

function! async#tasks#get() abort
    return s:merge_configs(s:get_global_ini(), s:get_local_ini())
endfunction


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Parse configuration files
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

""
" s:merge_configs: merge global and local configuration files
""
function! s:merge_configs(global, local) abort
    return extend(s:parse(a:global), s:parse(a:local))
endfunction


function! s:parse(path) abort
    if a:path == ''
        return {}
    endif
    let p = s:patterns
    let lines = readfile(a:path)
    let current = v:null
    let tasks = {}
    for line in lines
        if match(line, '^#') == 0
            continue
        elseif match(line, s:taskpat) == 1
            let task = matchstr(line, s:taskpat)
            let tasks[task] = {}
            let current = tasks[task]
        elseif current isnot v:null
            for pat in values(s:patterns)
                if match(line, pat) == 0
                    let item = matchstr(line, pat)
                    let current[item] = substitute(line, item . '=', '', '')
                endif
            endfor
        endif
    endfor
    return filter(tasks, function('s:validate_task'))
endfunction


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Validate tasks
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

function! s:validate_task(name, values) abort
    let [n, v] = [a:name, a:values]
    if s:failing_conditions(n) | return v:false | endif
    if s:wrong_profile(n)      | return v:false | endif
    if s:no_valid_entries(v)   | return v:false | endif
    return v:true
endfunction


function! s:no_valid_entries(entries) abort
    call filter(a:entries, function("s:valid_entries"))
    return empty(a:entries)
endfunction


function! s:failing_conditions(item) abort
    " / is the delimiter for systems and other conditions to satisfy
    " if conditions are separated by '+' they must all be satisfied
    " if conditions are separated by ',' any of them is enough
    if match(a:item, '/') > 0
        let [_, conds] = split(a:item, '/')
        if match(conds, '+')
            for cond in split(conds, '+')
                if     cond ==? 'linux'   && !s:is_linux   | return v:false
                elseif cond ==? 'macos'   && !s:is_macos   | return v:false
                elseif cond ==? 'windows' && !s:is_windows | return v:false
                elseif !has(cond)                          | return v:false
                endif
            endfor
        elseif match(conds, ',') >= 0
            for cond in split(conds, ',')
                if has(cond)                              | return v:true
                elseif cond ==? 'linux'   && s:is_linux   | return v:true
                elseif cond ==? 'macos'   && s:is_macos   | return v:true
                elseif cond ==? 'windows' && s:is_windows | return v:true
                endif
            endfor
        endif
    endif
    return v:false
endfunction


function! s:wrong_profile(task) abort
    " : is the delimiter for the profile (default, debug, etc)
    if match(a:task, ':') > 0
        let [_, profile] = split(a:task, ':')
        return profile != s:get_tasks_profile()
    endif
    return v:false
endfunction


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Validate entries
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

function! s:valid_entries(key, val) abort
    for e in keys(s:entries)
        if a:key =~ e
            let l:key = e
            break
        endif
    endfor
    return !exists('l:key') ? v:false
                \           : s:entries[l:key](a:key, a:val)
endfunction


function! s:validate_output(key, val) abort
    for m in ['buffer', 'cmdline', 'terminal', 'quickfix']
        if a:val =~ m
            return a:val == m
        endif
    endfor
    return a:val =~ '^external\(:[[:alnum:]_-]\+\)\?$'
endfunction


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Validate command
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

function! s:valid_filetype(key) abort
    let fts = split(substitute(a:key, '.*:', '', ''), ',')
    return index(fts, split(&ft, '\.')[0]) >= 0
endfunction


function! s:validate_command(key, val) abort
    if match(a:key, '/') > 0 && s:failing_conditions(a:key)
        return v:false
    endif
    let k = substitute(a:key, '/.*', '', '')
    if match(k, ':') > 0
        return s:valid_filetype(k)
    endif
    return a:key ==# 'command'
endfunction



"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Tasks profiles
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

function! async#tasks#get_profile(prj) abort
    return has_key(g:tasks, a:prj) ? g:tasks[a:prj].profile
                \                  : v:null
endfunction

function! async#tasks#set_profile(prj, profile) abort
    if has_key(g:tasks, a:prj)
        let g:tasks[a:prj].profile = a:profile
        return v:true
    else
        return v:false
    endif
endfunction

function! async#tasks#unset_profile(prj) abort
    if has_key(g:tasks, a:prj)
        unlet g:tasks[a:prj].profile
        return v:true
    else
        return v:false
    endif
endfunction




"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Get configuration files
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

""
" s:get_global_ini: return the path for the global configuration
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
" s:get_local_ini: return the path for the project configuration
""
function! s:get_local_ini() abort
    let f = get(g:, 'async_taskfile_local', '.tasks')
    return filereadable(f) ? f : ''
endfunction



"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Helpers
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

function! s:project_name() abort
    return fnamemodify(getcwd(), ':t')
endfunction





"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Patterns and script variables
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" global index for tasks settings
let g:tasks = {}

let s:is_windows = has('win32') || has('win64') || has('win16') || has('win95')
let s:is_linux   = !s:is_windows && systemlist('uname')[0] == 'Linux'
let s:is_macos   = !s:is_windows && !s:is_linux && systemlist('uname')[0] == 'Darwin'

let s:taskpat  = '\v^\[\zs\.?(\l+-?\l+)+(:\w+)?(\/(\w+,?)+)?\ze]'
let s:patterns = {
            \ 'command':      '\v^command(:(\w+,?)+)?(\/(\w+,?)+)?\ze\=',
            \ 'cwd':          '^cwd\ze=',
            \ 'output':       '^output\ze=',
            \ 'compiler':     '^compiler\ze=',
            \ 'success':      '^success\ze=',
            \ 'fail':         '^fail\ze=',
            \ 'errorformat':  '^errorformat\ze=',
            \ 'options':      '^options\ze=',
            \}

let s:entries = {
            \ 'command':     function('s:validate_command'),
            \ 'cwd':         { k,v -> v:true },
            \ 'output':      function('s:validate_output'),
            \ 'compiler':    { k,v -> v =~ '\w\+' },
            \ 'success':     { k,v -> v:true },
            \ 'fail':        { k,v -> v:true },
            \ 'pos':         { k,v -> v =~ '^\(top\|bottom\|left\|right\)$' },
            \ 'ft':          { k,v -> v =~ '\w\+' },
            \ 'errorformat': { k,v -> v:true },
            \ 'options':     { k,v -> v =~ '\%(\w\+,\?\)\+' },
            \}





"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" vim: et sw=4 ts=4 sts=4 fdm=marker

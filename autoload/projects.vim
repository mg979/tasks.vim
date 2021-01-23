" ========================================================================###
" Description: Project opener
" File:        projects.vim
" Author:      Gianmaria Bajo <mg1979@git.gmail.com>
" License:     MIT
" Created:     Sat 19 September 2020 17:39:14
" Modified:    Sat 19 September 2020 17:39:14
" ========================================================================###

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Update and open projects
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

""
" Update the projects dictionary.
""
function! projects#update() abort
    let f = s:get_projects_ini()
    let g:projects = filereadable(f) ? s:parse_projects(readfile(f)) : {}
    return g:projects
endfunction


""
" Open a project, in current or in new session.
""
function! projects#open(prj) abort
    let prj = get(g:projects, a:prj, {})
    if empty(prj)
        return v:null
    endif
    call s:open_cwd(prj)
    if !empty(prj.items)
        let opened_first = 0
        for i in prj.items
            if i.type == 'file'
                let cmd = opened_first ? i.cmd : 'edit'
                exe cmd . ' ' . fnameescape(i.item)
                let opened_first = 1
            elseif i.type == 'args'
                exe i.cmd . ' ' . i.item
            endif
        endfor
    endif
endfunction


""
" If there are no files to open, open the cwd in the file browser.
""
function! s:open_cwd(p) abort
    if !a:p.has_files
        let cmd = tabpagenr('$') == 1 && winnr('$') == 1 ? 'edit ' : 'tabedit '
        exe cmd . fnameescape(a:p.cwd)
    else
        exe (tabpagenr('$') == 1 && winnr('$') == 1 ? 'enew' : 'tabnew')
        setlocal buftype=nofile bufhidden=wipe
    endif
    let cmd = exists(':tcd') == 2 ? 'tcd ' : 'lcd '
    exe cmd . fnameescape(a:p.cwd)
endfunction


""
" Command line completion for projects.
""
function! projects#complete(A, C, P) abort
    return filter(sort(keys(g:projects)), 'v:val=~#a:A')
endfunction



"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Parse projects
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

""
" Function: s:parse_projects
" Parse and validate defined projects.
" @param lines: lines of the projects ini
" Returns: the validated projects
""
function! s:parse_projects(lines) abort
    let current = v:null
    for line in a:lines
        if match(line, '^#') == 0 || empty(line)
            continue
        elseif match(line, s:prjpat) == 1
            let prj = matchstr(line, s:prjpat)
            let g:projects[prj] = {'items': [], 'has_files': 0}
            let current = g:projects[prj]
        elseif current isnot v:null
            for pat in values(s:patterns)
                if match(line, pat) == 0
                    let item = matchstr(line, pat)
                    let val  = substitute(line, matchstr(line, pat) . '=', '', '')
                    call s:add_item(current, item, val)
                endif
            endfor
        endif
    endfor
    call filter(g:projects, function('s:validate_project'))
    return g:projects
endfunction


""
" Add a project item: either cwd, a file or an args command
""
function! s:add_item(prj, item, val) abort
    if a:item =~ '^cwd' && s:validate_cwd(a:item, a:val)
        let a:prj.cwd = a:val
    elseif index(['argglobal', 'arglocal'], a:item) >= 0
        call add(a:prj.items, {'item': a:val, 'type': 'args', 'cmd': a:item})
    else
        let a:prj.has_files = 1
        call add(a:prj.items, {'item': a:val, 'type': 'file', 'cmd': a:item})
    endif
endfunction


""
" cwd must be defined.
""
function! s:validate_project(key, val) abort
    if !has_key(a:val, 'cwd')
        return v:false
    endif
    return v:true
endfunction


""
" Check validity of cwd, if OS-specific.
""
function! s:validate_cwd(key, val) abort
    if match(a:key, '/') > 0
        let [_, conds] = split(a:key, '/')
        for cond in split(conds, ',')
            if     cond ==? 'linux'   && s:is_linux   | return v:true
            elseif cond ==? 'macos'   && s:is_macos   | return v:true
            elseif cond ==? 'windows' && s:is_windows | return v:true
            elseif cond ==? 'wsl'     && s:is_wsl     | return v:true
            endif
        endfor
        return v:false
    endif
    return v:true
endfunction




"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Helpers
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

""
" the path for the projects configuration
""
function! s:get_projects_ini() abort
    if exists('s:projects_ini') && s:projects_ini != ''
        return s:projects_ini
    endif

    let f = get(g:, 'async_taskfile_projects', 'projects.ini')
    let l:In = { dir -> filereadable(expand(dir).'/'.f) }
    let l:Is = { dir -> expand(dir).'/'.f }

    let s:projects_ini = has('nvim') &&
                \ l:In(stdpath('data'))  ? l:Is(stdpath('data')) :
                \ l:In('$HOME/.vim')     ? l:Is('$HOME/.vim') :
                \ l:In('$HOME/vimfiles') ? l:Is('$HOME/vimfiles') : ''

    if s:projects_ini == ''
        let dir = fnamemodify(expand($MYVIMRC), ':p:h')
        if filereadable(dir . '/' . f)
            let s:projects_ini = dir . '/' . f
        endif
    endif
    return s:projects_ini
endfunction


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Patterns and script variables
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

let g:projects = projects#update()

let s:prjpat   = '^\[\zs\w\+\ze\]'

let s:is_windows = has('win32') || has('win64') || has('win16') || has('win95')
let s:uname      = s:is_windows ? '' : systemlist('uname')[0]
let s:is_linux   = s:uname == 'Linux'
let s:is_macos   = s:uname == 'Darwin'
let s:is_wsl     = exists('$WSLENV')

let s:patterns = {
            \ 'cwd':          '\v^cwd(\/(\w+,?)+)?\ze\=',
            \ 'edit':         '^edit\ze=\f\+',
            \ 'split':        '^split\ze=\f\+',
            \ 'vsplit':       '^vsplit\ze=\f\+',
            \ 'tabedit':      '^tabedit\ze=\f\+',
            \ 'argglobal':    '^argglobal\ze=.\+',
            \ 'arglocal':     '^arglocal\ze=.\+',
            \}

" vim: et sw=4 ts=4 sts=4 fdm=marker

" ========================================================================///
" Description: list and choose tasks
" File:        list.vim
" Author:      Gianmaria Bajo <mg1979@git.gmail.com>
" License:     MIT
" Created:     mercoledì set 01, 2021 09:24:09 CEST
" Modified:    2021 set 01 09:24:09
" ========================================================================///

""
" Display tasks in the command line, or in json format.
""
function! tasks#list#show(as_json) abort
    "{{{1
    let prj = tasks#get(1)
    if s:ut.no_tasks(prj)
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
        let cmd = tasks#expand_cmd(T, prj)
        let n = &columns - 66 < strlen(cmd) ? '' : 'n'
        exe 'echo' . n string(cmd)
    endfor
    echohl None
    call getchar()
    call feedkeys("\r", 'n')
endfunction "}}}



"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Choose task with mapping
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

""
" Choose among available tasks (called with mapping).
" @param ...: prompt for extra args
""
function! tasks#list#choose(...) abort
    "{{{1
    let prj = tasks#get(1)
    if s:ut.no_tasks(prj)
        return
    endif
    let available = s:available_tasks(prj)
    if empty(available)
        return
    endif
    let dict = {}
    call s:cmdline_bar(prj)
    echohl Comment
    echo "Key\tTask\t\t\t\tTag\t\tOutput\t\tCommand"
    for task in s:mapped_tasks(available, prj)
        let t = task.name
        let T = prj.tasks[t]
        let dict[task.actualkey] = t
        ""
        " ---------------------------- [ mapping ] ----------------------------
        ""
        echohl Special
        echo task.printkey
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
        let cmd = tasks#expand_cmd(T, prj)
        if &columns - 84 < strlen(cmd)
            let cmd = cmd[:(&columns - 84)] . '…'
        endif
        echon cmd
    endfor
    echo ''
    let ch = getchar()
    let ch = ch > 0 ? nr2char(ch) : ch
    if index(keys(dict), ch) >= 0
        if a:0
            redraw
            echohl Delimiter  | echo 'Command: ' | echohl None
            echon tasks#expand_cmd(prj.tasks[dict[ch]], prj)
            let args = input('args: ', '', 'file')
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
" Mappings generation for tasks
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

let s:next_available = 97 "letter 'a'

let s:Key  = { map -> [s:keys[map][0] . "\t", s:keys[map][1]] }
let s:Seen = { n, is_fn -> is_fn ? has_key(s:seenF, n) : has_key(s:seenA, n) }

function! s:get_fkey(n)
    let n = a:n
    if !s:Seen(n, 1)
        let s:seenF[n] = v:true
        return s:Key('f' .. n)
    elseif n < 12
        for x in range(n + 1, 12) " up to <F12>
            if !s:Seen(x, 0)
                let s:seenF[x] = v:true
                return s:Key('f' .. x)
            endif
        endfor
        return s:get_alphakey(s:next_available)
    else
        return s:get_alphakey(s:next_available)
    endif
endfunction

function! s:get_alphakey(n)
    let n = a:n
    if !s:Seen(n, 0)
        let s:seenA[n] = v:true
        return s:Key(nr2char(n))
    else
        for x in range(97, 126) "from 'a' to '~'
            if !s:Seen(x, 0)
                let s:next_available = x
                break
            endif
        endfor
        let s:seenA[s:next_available] = v:true
        return s:Key(nr2char(s:next_available))
    endif
endfunction

function! s:mapped_tasks(tasks, prj)
    let [tasks, s:seenF, s:seenA] = [[], {}, {}]
    for t in a:tasks
        let task = {'name': t}
        let T = a:prj.tasks[t]
        if has_key(T.fields, 'mapping') && has_key(s:keys, T.fields.mapping)
            if T.fields.mapping =~ 'f\d\+'
                let [pk, ak] = s:get_fkey(matchstr(T.fields.mapping, '\d\+'))
            else
                let [pk, ak] = s:get_alphakey(char2nr(T.fields.mapping))
            endif
        else
            let [pk, ak] = s:get_alphakey(s:next_available)
        endif
        let task.printkey = pk
        let task.actualkey = ak
        call add(tasks, task)
    endfor
    return tasks
endfunction


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Helpers
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

let s:ut   = tasks#util#init()
let s:v    = s:ut.Vars
let s:bvar = { v -> getbufvar(bufnr(''), v) }

function! s:available_tasks(prj)
    let available = filter(sort(keys(a:prj.tasks)),
                \          '!get(a:prj.tasks[v:val], "hidden", v:false) &&
                \           !get(a:prj.tasks[v:val], "unmapped", v:false)')
    if empty(available)
        echon s:ut.badge() 'no tasks'
    endif
    return available
endfunction

function! s:cmdline_bar(prj) abort
    " Top bar for command-line tasks list. {{{1
    redraw
    echohl QuickFixLine
    let header = has_key(a:prj.info, 'name') ?
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


let s:keys = {'f1': ['<F1>', "\<F1>"], 'f2': ['<F2>', "\<F2>"],   'f3': ['<F3>', "\<F3>"],   'f4': ['<F4>', "\<F4>"],
            \ 'f5': ['<F5>', "\<F5>"], 'f6': ['<F6>', "\<F6>"],   'f7': ['<F7>', "\<F7>"],   'f8': ['<F8>', "\<F8>"],
            \ 'f9': ['<F9>', "\<F9>"], 'f10': ['<F10>', "\<F10>"], 'f11': ['<F11>', "\<F11>"], 'f12': ['<F12>', "\<F12>"]}

for s:n in range(33, 126)
    let s:ch = nr2char(s:n)
    let s:keys[s:ch] = [s:ch, s:ch]
endfor

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" vim: ft=vim et ts=4 sw=4 fdm=marker

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
    let Keys = s:get_keys(prj, len(available))
    let dict = {}
    let i = 1
    call s:cmdline_bar(prj)
    echohl Comment
    echo "Key\tTask\t\t\t\tTag\t\tOutput\t\tCommand"
    for t in available
        let T = prj.tasks[t]
        if has_key(T.fields, 'mapping')
            let Keys[i] = T.fields.mapping
            let map = T.fields.mapping ."\t"
        else
            let map = s:get_key(Keys, i)
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
        let cmd = tasks#expand_cmd(T, prj)
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
            echon tasks#expand_cmd(prj.tasks[dict[ch]], prj)
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
" Helpers
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

let s:ut   = tasks#util#init()
let s:v    = s:ut.Vars
let s:bvar = { v -> getbufvar(bufnr(''), v) }

let s:Fnk = { 1: "\<F1>", 2: "\<F2>",   3: "\<F3>",   4: "\<F4>",
            \ 5: "\<F5>", 6: "\<F6>",   7: "\<F7>",   8: "\<F8>",
            \ 9: "\<F9>", 10: "\<F10>", 11: "\<F11>", 12: "\<F12>"}

let s:Fn5 = { 1: "\<F5>", 2: "\<F6>",  3: "\<F7>",  4: "\<F8>",
            \ 5: "\<F9>", 6: "\<F10>", 7: "\<F11>", 8: "\<F12>"}


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


function! s:get_keys(prj, available)
    let n = a:available
    let F6 = has_key(a:prj.info, 'options') && a:prj.info.options =~ '\<f6key\>'
    let Fn = has_key(a:prj.info, 'options') && a:prj.info.options =~ '\<fnkeys\>'

    if F6 && n == 1

        let keys = { 1: "\<F6>"}
        let s:get_key = { k,c -> '<F6>' . "\t"}

    elseif F6 && n <= 8

        let keys = s:Fn5
        let s:get_key = { k,c -> '<F'.(c+4).'>' . "\t"}

    elseif (Fn || F6) && n <= 12

        let keys = s:Fnk
        let s:get_key = { k,c -> '<F'.c.'>' . "\t"}

    else
        let keys = {}
        for i in range(1, 26)
            let keys[i] = nr2char(96 + i)
        endfor
        let s:get_key = { k,c -> k[c] . "\t"}
    endif

    return keys
endfunction

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" vim: ft=vim et ts=4 sw=4 fdm=marker

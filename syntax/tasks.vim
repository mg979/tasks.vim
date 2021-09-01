runtime syntax/dosini.vim

syn clear dosiniHeader
syn clear dosiniComment
syn match TaskComment  "^;.*$"
syn region TaskName   start="^\s*\[" end="\]" contains=TaskOs nextgroup=TaskTag
syn match TasksError '^[^;\[]\+\ze=\?.*'
syn match TaskTag '\s\+@\w\+' contained nextgroup=TaskTag

let s:cmd  = '%(<command>(:(\w+,?)+)?(\/(\w+,?)+)?)'
let s:keys = [
            \'cwd', 'output', 'compiler',
            \'success', 'fail', 'syntax',
            \'errorformat', 'grepformat',
            \'options', 'args', 'mapping',
            \'outfile', 'errfile',
            \'name', 'description', 'filerotate',
            \]
exe printf("syn match TasksField '\\v\\C^%s|<%s>|<[A-Z_]+>\\ze\\=.+'", s:cmd, join(s:keys, '>|<'))

syn match TasksSect   '^#\v(<env>|<environment>|<project>|<global>)'
syn match TasksEnvVar '\${\?[A-Z_]\+}\?' containedin=dosiniValue nextgroup=TaskString
syn match TaskString  '.*' contained contains=TasksEnvVar
syn match TaskOs      '/\zs.*\ze]' contained
syn match TasksEnvField '\C^[A-Z_]\+\ze:\?='
syn match TasksEnvRepl '\C^@[A-Z_]\+\ze:\?='
syn match TasksEnvRepl '@[A-Z_]\+' containedin=dosiniValue nextgroup=TaskString

if has('win32')
    syn match TasksEnvVar '%[A-Z_]\+%' containedin=dosiniValue nextgroup=TaskString
else
    syn match TasksEnvVar '\%(\%(Windows\|\<win\d\d\>\).\{-}\)\@<=%[A-Z_]\+%' containedin=dosiniValue nextgroup=TaskString
endif

hi default link TasksSect   Constant
hi default link TasksEnvVar Identifier
hi default link TasksError  WarningMsg
hi default link TasksField  dosiniLabel
hi default link TasksEnvField  dosiniLabel
hi default link TasksEnvRepl   Function
hi default link TaskName    Special
hi default link TaskTag     Constant
hi default link TaskComment Comment
hi default link TaskString  String
hi default link TaskOs      Identifier

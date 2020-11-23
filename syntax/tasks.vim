runtime syntax/dosini.vim

syn clear dosiniHeader
syn clear dosiniComment
syn match TaskComment  "^;.*$"
syn region TaskName   start="^\s*\[" end="\]" nextgroup=TaskProfile
syn match TasksError '^[^;\[]\+\ze=\?.*'
syn match TaskProfile '\s\+@\w\+' contained

let s:cmd  = '%(<command>(:(\w+,?)+)?(\/(\w+,?)+)?)'
let s:keys = [
            \'cwd', 'output', 'compiler',
            \'success', 'fail', 'syntax',
            \'errorformat', 'options',
            \'outfile', 'errfile',
            \'name', 'description', 'profiles',
            \]
exe printf("syn match TasksField '\\v\\C^%s|<%s>|<[A-Z_]+>\\ze\\=.+'", s:cmd, join(s:keys, '>|<'))

syn match TasksSect   '^#\(\<env\>\|\<environment\>\|\<info\>\)'
syn match TasksEnvVar '\${\?[A-Z_]\+}\?' containedin=dosiniValue
syn match TasksEnvVar '\%(\%(Windows\|\<win\d\d\>\).\{-}\)\@<=%[A-Z_]\+%' containedin=dosiniValue

hi default link TasksSect   Constant
hi default link TasksEnvVar Identifier
hi default link TasksError  WarningMsg
hi default link TasksField  dosiniLabel
hi default link TaskName    Special
hi default link TaskProfile Constant
hi default link TaskComment Comment

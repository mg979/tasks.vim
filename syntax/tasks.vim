runtime syntax/dosini.vim

syn match TasksEnv '\${\?[A-Z_]\+}\?' containedin=dosiniValue
syn match TasksEnv '\%(\%(Windows\|\<win\d\d\>\).\{-}\)\@<=%[A-Z_]\+%' containedin=dosiniValue

hi default link TasksEnv Identifier

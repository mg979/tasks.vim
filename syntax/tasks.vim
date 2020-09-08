runtime syntax/dosini.vim

syn match TasksEnv '\${\?[A-Z_]\+}\?' containedin=dosiniValue
syn match TasksEnv '<\w\+>' containedin=dosiniValue

hi default link TasksEnv Identifier

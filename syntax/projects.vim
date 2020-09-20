runtime syntax/dosini.vim

syn match ProjectsError '^.\+\ze=.*'
syn match ProjectsField '\v^%(cwd%(/%(%(\c<windows>|<linux>|<macos>|<wsl>),?)+)?|edit|split|vsplit|tabedit|system|argglobal|arglocal)\ze\=.+'

hi default link ProjectsError WarningMsg
hi default link ProjectsField dosiniLabel

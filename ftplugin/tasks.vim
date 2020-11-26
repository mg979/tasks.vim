if exists('b:did_ftplugin')
  finish
endif
let b:did_ftplugin = 1

set commentstring=;\ %s

au BufWritePost <buffer> call tasks#get(1)


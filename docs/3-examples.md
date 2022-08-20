---
layout: docpage
title: examples
---

If you didn't read yet the [tasks](2-tasks.html) section, you probably
won't be able to make much sense out of the following examples.

### open terminal or explorer window

These commands would open a new explorer window, or a new terminal window, at
the current file position, or at the current working directory respectively.

In Linux you should replace the terminal application with the one you're
actually using. Note that in Linux I unset vim environmental variables, or they
would carry over to the new window.
```ini
[explorer-dir] @always @hidden
command/Linux=unset VIM && unset VIMRUNTIME && xdg-open %:h
command/Windows=start explorer.exe %:h
command/MacOs=open "%:h"
output=headless

[explorer-root] @always @hidden
command/Linux=unset VIM && unset VIMRUNTIME && xdg-open $ROOT
command/Windows=start explorer.exe $ROOT
command/MacOs=open "$ROOT"
output=headless

[terminal-dir] @always @hidden
command/Linux=unset VIM && unset VIMRUNTIME && xfce4-terminal --working-directory "%:p:h"
command/Windows=start cmd.exe /k "%:p:h"
command/MacOs=open -a iTerm "%:p:h"
output=headless

[terminal-root] @always @hidden
command/Linux=unset VIM && unset VIMRUNTIME && xfce4-terminal --working-directory "$ROOT"
command/Windows=start cmd.exe /k "%ROOT%"
command/MacOs=open -a iTerm "$ROOT"
output=headless
```
Also note that they are marked as _@always_ and _@hidden_, meaning the tasks
are always valid, also when a project tasks file is present, but they never
show up with the __Tasks-Choose__ plug, that is used to launch a task with
a mapping. They are only accessible through the `:Task` command (autocompletion
still works with hidden tasks), so that you can still setup mappings for them.

These mappings would replicate the ones of the `vim-gtfo` plugin:
```vim
nnoremap got :Task terminal-dir<cr>
nnoremap goT :Task terminal-root<cr>
nnoremap gof :Task explorer-dir<cr>
nnoremap goF :Task explorer-root<cr>
```

### markdown preview
```ini
[markdown-preview] @always
command:markdown=grip --user-content --quiet -b "%"
output=headless
options=writelogs
```
A global task, and requires the [grip](https://github.com/joeyespo/grip) executable.

This task will open the browser for a live preview of a markdown file.
Mode is _headless_, so no quickfix is populated, and no terminal is spawned.
It will write logs to disk when terminated.

### convert quotes
```ini
[convert-quotes] @always
command:noft,text/Linux,MacOs=%!iconv -f utf-8 -t ascii//translit
output=vim
```
Inspired by [this reddit post](https://www.reddit.com/r/vim/comments/k10psl/how_to_convert_smart_quotes_and_other_fancy/).

The command is specific for text files, or files with no filetype set (`noft`
is used in this case). It works in Linux and Mac, not in Windows.

Note the use of the _vim_ output mode, so that the task is actually a vim ex
command and not an external process.

### build, run and test

A simple program that expects some data from stdin. It defines custom mappings
for the __Tasks-Choose__ plug.
```ini
#info
name=the program's name
description=the program's description

#environment
EXE=program_name

[project-build]
command=make
mapping=b

[project-clean]
command=make clean
output=cmdline
mapping=c

[project-run]
command=./$EXE < some_default_file
output=terminal
mapping=r

[project-run] @test
command=./$EXE < some_test_file
output=terminal
mapping=t

[project-build-and-run]
command=make 1>/dev/null && ./$EXE < some_default_file
output=terminal
mapping=a
```

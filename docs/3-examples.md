---
layout: docpage
title: examples
---

If you didn't read yet the [tasks](1-tasks.html) section, you probably
won't be able to make much sense out of the following examples.

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
command:noft,text/Linux=%!iconv -f utf-8 -t ascii//translit
output=vim
```
Inspired by [this reddit post](https://www.reddit.com/r/vim/comments/k10psl/how_to_convert_smart_quotes_and_other_fancy/).

The command is specific for text files, or files with no filetype set (`noft`
is used in this case). It is also Linux-specific, so you won't see it in other
OS.

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

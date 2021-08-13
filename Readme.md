[tasks.vim](https://mg979.github.io/tasks.vim/), a rewrite of [asynctasks.vim](https://github.com/skywind3000/asynctasks.vim), is a (neo)vim plugin to manage and run global and project-local tasks, like starting builds and running tests.
It comprises

- [async.vim](https://github.com/mg979/tasks.vim/blob/master/docs/1-async.md) to handle async tasks, and
- [tasks.vim](https://github.com/mg979/tasks.vim/blob/master/docs/2-tasks.md), the task manager itself.

## Features

- can handle parallel jobs
- expands vim filename modifiers (`%`, `%:p`, etc) in commands
- configuration files written in a format similar to `ini` files
- global and project-local configurations
- tasks can be filetype and OS specific
- multiple output modes: embedded terminal, quickfix window, and others
- tasks tags for profile switching


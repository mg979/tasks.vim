---
title: home
layout: home
---

## Introduction

This is the web documentation for
[tasks.vim](https://github.com/mg979/tasks.vim), a (neo)vim plugin written to
manage and run global and project-local tasks, like starting builds, executing
tests and the like.

This plugin is heavily inspired by
[asynctasks.vim](https://github.com/skywind3000/asynctasks.vim), of which it
can be considered a rewrite.

## Features

- can handle parallel jobs
- expands vim filename modifiers (`%`, `%:p`, etc) in commands
- configuration files written in a format similar to `ini` files
- global and project-local configurations
- tasks can be filetype and OS specific
- multiple output modes: embedded terminal, quickfix window, and others
- tasks tags for profile switching

## Modules

It comprises two main modules:

- `async.vim`: handles async tasks and provides a handful of commands
- `tasks.vim`: the task manager itself

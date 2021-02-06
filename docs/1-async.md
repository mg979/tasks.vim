---
layout: docpage
title: async
---

_async.vim_ is the module that handles asynchronous jobs for both vim (>= 8.1)
and neovim.



## What is a job?

In this context, with _job_ is meant an external process that is started
within vim, with different purposes (building an executable, running tests,
performing a lint on the current buffer, executing a script, etc).

As you maybe will know, vim has a command (`:make`) that executes a system
process, defined by the `makeprg` option, then captures its output with
a format defined by the `errorformat` option, and fills the quickfix window
with the results (possibly build errors, or of any other type). The
default `makeprg` is `make`, hence the name of the command.

Vim has also the `:compiler` command, that sets `makeprg` and `errorformat`
to predefined values, so that simple build systems can be defined this way.

The `:make` command is synchronous, that is, the whole editor is frozen while
the external process runs.

If you ever used the `:grep` command, you'll possibly know that it uses similar
settings (`grepprg` and `grepformat`) to produce its results. As a matter of
fact, they work very similarly, and also the `:grep` command is synchronous.

Starting from version 8.0 (and neovim did before it), vim supports asynchronous
jobs, but all default commands still work synchronously, and implementation of
asynchronous commands is left to plugins. There's also the fact that vim and
neovim implementation of jobs is different and incompatible, so plugins must
handle that on their own.

This module provides both a way to start and manage jobs, and an unified
interface that works in the same way for vim and neovim.


## What does this module do?

This module provides:

- a series of commands that let `:make` and `:grep` work asynchronously.

- a job indexing system, so that you can have an overview of currently running
  jobs (to stop them if needed), and also finished jobs (to check their exit
  status).

- functions that will start asynchronous jobs, with many possible
  customizations.

Out of the three, if you are a regular user you'll be probably interested in
the first one, and the second one at most. The third one requires some
understanding of how vim and neovim handle jobs, so it's not exactly for the
average vim user. But it's what the second module (_tasks.vim_) is for: an
easy-to-use interface to define job commands and their options.


## Commands

### :Make commands

|Command   |Args|Bang|Description                                                    |
|----------|----|----|---------------------------------------------------------------|
|Make      |  ? |  ? | run `:make` asynchronously and populate quickfix with results |
|LMake     |  ? |  ? | same, but use the location list for the current window        |

Unless _!_ (bang) is used, you will be brought to the first error.

Any extra argument is passed as-is to the `:make` command.



### :Compiler commands

|Command   |Args|Bang|Description                            |
|----------|----|----|---------------------------------------|
|Compiler  |  1 |  1 | execute `:compiler`, then `:Make`     |
|LCompiler |  1 |  1 | same, but use `:LMake`                |

Unless _!_ (bang) is used, you will be brought to the first error.

Differently from vim, with the `:Compiler` commands changes to `&makeprg` and
`&errorformat` are temporary, that is, they are reset to the previous values
after the command is issued.

The first argument of the command is the compiler type, any other argument will
be passed to the :Make command that is run after it.

They can be used for one-shot lintings, for example on a python buffer:

    :Compiler pylint %



### :Grep commands

|Command   |Args|Bang|Description                                                     |
|----------|----|----|----------------------------------------------------------------|
|Grep      |  1 |  1 | run `:grep` asynchronously and populate quickfix with results  |
|GrepAdd   |  1 |  1 | append to list instead of creating a new one                   |
|LGrep     |  1 |  1 | as `:Grep`, but use the location list for the current window   |
|LGrepAdd  |  1 |  1 | as for `:GrepAdd`                                              |

Unless _!_ (bang) is used, you will be brought to the first match.

As for `:Make`, they are wrappers around `:grep`, that is, they expect the same
kind of arguments that `:grep` would expect (switches, quotes, etc).



### :Jobs command

The `:Jobs` command will list current running jobs, and prompt for a job id to
terminate.

`:Jobs!` will show finished jobs, and prompt for a job id for which
you want to see the full details (a system python installation is needed).



### Other commands

|Command   |Args|Bang|Description                                                     |
|----------|----|----|----------------------------------------------------------------|
|Async     | 1  | 1  | run a command asynchronously in headless mode                  |
|AsyncBuf  | 1  | 1  | run a command asynchronously and print output in a buffer      |
|AsyncCmd  | 1  | 1  | echo the output of an asynchronous command to the command line |

Even in headless mode, the job is managed and can be accessed with `:Jobs[!]`.

Output and errors are not retained to spare memory (who knows how big they
are), but if BANG is used, both stdout and stderr are written to log files in
temporary locations. You can then get their location with the `:Jobs!` command
(or directly from the global index). More on this where job options are
discussed in detail.


## Internals

The rest of the documentation for this module is of no use for the regular
user, because it describes how jobs are run and indexed, and the options they
use. Most options can be set with the interface offered by _tasks.vim_.


### g:async_jobs

Running jobs are stored in a global dictionary. To support both vim and nvim,
incremental _ids_ are used: for each new job, a new id is added to the global
dictionary. Parallel jobs are possible. For each entry, values are:

|----------|---------------------------------------------------------|
| id       | the id (same as the key)                                |
| pid      | the process id                                          |
| job      | the job object/handle                                   |
| title    | the command as requested by the user, used as title     |
| cmd      | the argument for the job starter                        |
| opts     | options for the job starter                             |
| out      | a list, initially empty, will be filled with the stdout |
| err      | same for stderr                                         |

This table can then be extended by user options passed to the function that
starts the job.


### g:async_finished_jobs

When a job terminates, it is removed from _g:async_jobs_ and added to
_g:async_finished_jobs_, stripped of its _out_ and _err_, to make it lighter.

If it is needed to retrieve the _stdout_ and _stderr_ at a later stage, logging
to disk should be enabled in advance, because after a job has terminated and
added to this variable, they are removed from memory.

As stated before, the command `:Jobs!` can pretty print the selected _id_ from
this table for you.


### Functions

__Function__: async#cmd(cmd, mode, ...)

Starts an asynchronous process.
The first of the two optional dictionaries contains user options, that are
stored in the global dictionary, and that can be used later in custom
callbacks. The second one can contain vim job options.
While the user options can contain any field, the job options dictionary is
restricted to supported fields (because vim doesn't accept extra fields,
contrary to nvim).

    @param cmd:  the command
    @param mode: quickfix, buffer, terminal, external, cmdline or headless
    @param ...:  can be one or two dicts
                 - first is 'useropts' (user data stored in g:async_jobs[id])
                 - second is 'jobopts' (merged with job options)
    Returns: the id of the job if successful, or 0


---

__Function__: async#qfix(args, ...)

Runs a job and populate quickfix with results.

    @param args:  the args for the command
    @param ...:   optional dicts as for async#cmd (useropts, jobopts)
    Returns: the id of the job if successful, or 0


---

__Function__: async#compiler(args, ...)

Sets `compiler`, then executes the job in quickfix mode.

    @param args: the compiler name, followed by any argument
    @param ...:  optional dicts as for async#cmd (useropts, jobopts)
    Returns: the id of the job if successful, or 0


---

__Function__: async#stop(id, ...)

Stops jobs.

    @param id:   the id of the job to stop. If 0, all jobs are stopped.
    @param ...:  kill rather than terminate. Vim only.
    Returns: the id of the stopped job, or 0 if all jobs are stopped.


---

__Function__: async#list(finished)

Lists running or finished jobs. Prompts for id of running job to
terminate/finished job to pretty print.

    @param finished: list finished jobs, not running jobs.


---

__Function__: async#expand(cmd, ...)

Expands filename modfiers/variables in a given string.
Includes args and performs expansions for the Make/Grep commands.

    @param cmd:  generally &makeprg or &grepprg
    @param args: the command arguments
    Returns: the full command


---

__Function__: async#remove_job(job)

Removes a job from the global dictionary, when job has exited.

    @param job: the job to remove
    Returns: the removed entry


---

__Function__: async#finish(exit_cb, job, status, ...)

Adds finished job to the global table, and stores its exit status.

    @param exit_cb: the actual exit callback
    @param job:     the finished job id/object
    @param status:  the exit status of the job
    @param ...:     the event type (passed by nvim, unused)



### User options

Most functions that can start a job accept a dictionary with user options as
optional argument. This is a list of valid options with their defaults.
You can see that most options have a default of 0, or an empty string.

| Option     | Description                  | Default      |
|------------|------------------------------|--------------|
| `grep`       | use grepprg, not makeprg     | 0            |
| `makeprg`    | makeprg                      | &makeprg     |
| `grepprg`    | grepprg                      | &grepprg     |
| `errorformat`| errorformat                  | &errorformat |
| `grepformat` | grepformat                   | &grepformat  |
| `compiler`   | run :compiler x              | ''           |
| `qfautocmd`  | quickfix autocommands        | _read below_ |
| `env`        | environmental variables      | {}           |
| `locl`       | use loclist, not qfix        | 0            |
| `openqf`     | open qfix window             | 0            |
| `focus`      | focus on qf window           | 0            |
| `nojump`     | don't jump to first item     | 0            |
| `append`     | append to qfix, don't add    | 0            |
| `nosave`     | don't :update before cmd     | !grep        |
| `wall`       | do :wall before cmd          | 0            |
| `keepouts`   | keep out/err in memory       | 0            |
| `writelogs`  | write out/err to logfiles    | 0            |
| `outfile`    | file where to write out      | ''           |
| `errfile`    | file where to write err      | ''           |
| `termonquit` | when quitting vim            | 0            |

Options explained:

___grep___: should be set to 1 (true) when running a command like `grep`, `rg`
and the like. Quickfix output and exit status are handled accordingly.

___makeprg___, ___grepprg___, ___errorformat___, ___grepformat___: these are
the settings that control the command to run, and the errorformat for the
quickfix window. The grep variants are used if _grep_ is true. Note that they
only matter when calling `async#qfix`, because the command provided to
`async#cmd` is executed as-is.

___compiler___: if not an empty string, will run the `:compiler` command with
this value as argument, and then use the new values of _makeprg_ and
_errorformat_. Old values are immediately restored.

___qfautocmd___: a pattern for the `QuickFixCmdPre/Post` autocommands. Default
value is _grep_ or _make_, depending on the _grep_ option. Read `:help
QuickFixCmdPre` for more informations.

___nosave___, ___wall___: by default the current buffer is updated before
executing the command, _nosave_ prevents this. Other buffers are not updated,
set option _wall_ to 1 for this. Exception: when using the _grep_ option,
_nosave_ is true by default.

___openqf___, ___focus___, ___nojump___, ___append___: by default, quickfix is
not opened, not focused if opened, the cursor will jump to the first
error/match, and lines are added, not appended.

___keepouts___: keep stdout and stderr in memory, stored in
_g:async_finished_jobs_, for easier retrieval.

__writelogs__, __outfile__, __errfile__: if _writelogs_ is true, logs will be
written to files, whose names are obtained with `tempname()`, unless you
provide specific paths (_outfile_ and _errfile_).

__termonquit__: when quitting vim, if a job is still running, you are prompted
if you want to terminate it or not. This option bypasses this prompt and
automatically terminates the job when quitting.


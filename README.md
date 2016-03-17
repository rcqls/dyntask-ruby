# DynTask

First of all, inspiration DynTask comes from the filewatcher project. The goal is a bit different since the goal is to provide a very basic system to manage chainable tasks.


## Kinds of task

when depending on source (and/or output) file or content to be copied in some particular path, one may be interested in:

* local task: everything is executed inside the same computer. This allows to write task in any path different from the source file path.
* remote task: when using docker or dropbox-like tools, a synchronized task can be executed in a different computer or docker container. As a constraint, the source (and/or output) file path and the task file path have to be defined relatively to a common root independently in any synchronized computers supposed to execute the tasks. Obviously, the task file and source file can be in the same directory which is the simplest case.

The goal of such approach is to watch only one folder containing task file with predefined extension and not subdirectories which makes the watching less reactive.

## Main actions to perform

* dyn
* dyn-cli
* pdflatex
* pandoc


## Examples

```{bash}
## To specify a folder to watch with specific tasks
dyntask-init default <dyndoc-project-folder>:dyn,pandoc,dyn_cli

## Optional for pandoc task
dyntask-init pandoc-extra dir --force /dyndoc-library/pandoc-extra
##
dyntask-init pandoc-extra wget
```

## How this works

* add_task: to push task
* save_tasks: to save all the pushed tasks
* read_tasks: read first task and pop to the stack of tasks

# GitImproved


## What's This?

GitImproved is a wrapper script for Git command.
It provides a much better interface than Git.

* Intuitive
* Easy to understand
* Fewer commands

Links:

* Document: <https://kwatch.github.io/git-improved/>
* GitHub: <https://github.com/kwatch/git-improved>
* Changes: <https://github.com/kwatch/git-improved/CHANGES.md>


### Table of Contents

<!-- TOC/ -->


## Install

GitImproved requires Ruby >= 2.3.

```console
$ gem install git-improved
$ gi --version
1.0.0
```


## Quick Example

```console
## help
$ gi -h | less                # help message
$ gi -l | less                # list actions
$ gi -h commit:create         # help of an action

## create a repo
$ mkdir mysample              # or: gi repo:clone github:<user>/<repo>
$ cd mysample
$ gi repo:init -u yourname -e yourname@gmail.com

## add files
$ vi README.md                # create a new file
$ gi track README.md          # register files into the repository
$ gi                          # show current status
$ gi cc "add README file"     # commit changes

## edit files
$ vi README.md                # update an existing file
$ gi stage .                  # add changes into staging area
$ gi                          # show current status
$ gi staged                   # show changes in staging area
$ gi cc "update README file"  # commit changes

## upload changes
$ gi repo:remote:seturl github:yourname/mysample
$ gi push                     # upload local commits to remote repo
```


## Actions


### Branch

```
branch:checkout     : create a new local branch from a remote branch
branch:create       : create a new branch, not switch to it
                      (alias: branch)
branch:current      : show current branch name
branch:delete       : delete a branch
branch:echo         : print CURR/PREV/PARENT branch name
branch:fork         : create a new branch and switch to it
                      (alias: fork)
branch:join         : merge current branch into previous or other branch
                      (alias: join)
branch:list         : list branches
                      (alias: branches)
branch:merge        : merge previous or other branch into current branch
                      (alias: merge)
branch:parent       : show parent branch name (EXPERIMENTAL)
branch:previous     : show previous branch name
branch:rebase       : rebase (move) current branch on top of other branch
branch:rename       : rename the current branch to other name
branch:reset        : change commit-id of current HEAD
branch:switch       : switch to previous or other branch
                      (alias: sw, switch)
branch:update       : git pull && git stash && git rebase && git stash pop
                      (alias: update)
branch:upstream     : print upstream repo name of current branch
```


### Commit

```
commit:apply        : apply a commit to curr branch (known as 'cherry-pick')
commit:correct      : correct the last commit
                      (alias: correct)
commit:create       : create a new commit
                      (alias: cc, commit)
commit:fixup        : correct the previous commit
                      (alias: fixup)
commit:revert       : create a new commit which reverts the target commit
commit:rollback     : cancel recent commits up to the target commit-id
commit:show         : show commits in current branch
                      (alias: commits)
```


### Config

```
config              : list/get/set/delete config values
config:alias        : list/get/set/delete aliases of 'git' (not of 'gi')
config:setuser      : set user name and email
```


### File

```
file:blame          : print commit-id, author, and timestap of each line
file:changes        : show changes of files
                      (alias: changes)
file:delete         : delete files or directories
file:egrep          : find by pattern
file:list           : list (un)tracked/ignored/missing files
                      (alias: files)
file:move           : move files into a directory
file:rename         : rename a file or directory to new name
file:restore        : restore files (= clear changes)
file:track          : register files into the repository
                      (alias: register, track)
```


### Help

```
help                : print help message (of action if specified)
```


### History

```
history             : show commit history in various format
                      (alias: hist (with '-F graph'))
history:edit:cancel : cancel (or abort) `git rebase -i`
history:edit:resume : resume (= conitnue) suspended `git rebase -i`
history:edit:skip   : skip current commit and resume
history:edit:start  : start `git rebase -i` to edit commit history
                      (alias: histedit)
history:notuploaded : show commits not uploaded yet
```


### Misc

```
misc:initfile       : generate a init file, or print to stdout if no args
```


### Repo

```
repo:clone          : copy a repository ('github:<user>/<repo>' is available)
repo:create         : create a new directory and initialize it as a git repo
repo:init           : initialize git repository with empty initial commit
repo:remote         : list/get/set/delete remote repository
repo:remote:origin  : get/set/delete origin (= default remote repository)
```


### Staging

```
staging:add         : add changes of files into staging area
                      (alias: pick (with '-p'), stage)
staging:clear       : delete all changes in staging area
                      (alias: unstage)
staging:edit        : edit changes in staging area
staging:show        : show changes in staging area
                      (alias: staged)
```


### Stash

```
stash:drop          : delete latest changes from stash
stash:list          : list stash history
stash:pop           : restore latest changes from stash
stash:put           : save current changes into stash
stash:show          : show changes on stash
```


### Status

```
status:compact      : show status in compact format
                      (alias: status)
status:default      : show status in default format
status:here         : same as 'stats:compact .'
status:info         : show various infomation of current status
```


### Sync

```
sync:both           : download and upload commits
                      (alias: sync)
sync:pull           : download commits from remote and apply them to local
                      (alias: dl, download, pull)
sync:push           : upload commits to remote
                      (alias: push, up, upload)
```


### Tag

```
tag                 : list/show/create/delete tags
tag:create          : create a new tag
tag:delete          : delete a tag
tag:download        : download tags
tag:list            : list tags
                      (alias: tags)
tag:upload          : upload tags
```


## Aliases

```
branch              : alias for 'branch:create'
fork                : alias for 'branch:fork'
join                : alias for 'branch:join'
branches            : alias for 'branch:list'
merge               : alias for 'branch:merge'
sw                  : alias for 'branch:switch'
switch              : alias for 'branch:switch'
update              : alias for 'branch:update'
correct             : alias for 'commit:correct'
cc                  : alias for 'commit:create'
commit              : alias for 'commit:create'
fixup               : alias for 'commit:fixup'
commits             : alias for 'commit:show'
changes             : alias for 'file:changes'
files               : alias for 'file:list'
register            : alias for 'file:track'
track               : alias for 'file:track'
hist                : alias for 'history -F graph'
histedit            : alias for 'history:edit:start'
pick                : alias for 'staging:add -p'
stage               : alias for 'staging:add'
unstage             : alias for 'staging:clear'
staged              : alias for 'staging:show'
status              : alias for 'status:compact'
sync                : alias for 'sync:both'
dl                  : alias for 'sync:pull'
download            : alias for 'sync:pull'
pull                : alias for 'sync:pull'
push                : alias for 'sync:push'
up                  : alias for 'sync:push'
upload              : alias for 'sync:push'
tags                : alias for 'tag:list'
```


## License and Copyright

* $License: MIT License $
* $Copyright: copyright(c) 2023 kwatch@gmail.com $

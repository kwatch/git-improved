# GitImproved


## What's This?

GitImproved is a wrapper script of Git command.
It provides much better interface than Git.

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
$ gi --help | less      # help message
```


## Quick Example

```console
$ mkdir mysample              # or: gi repo:clone github:<user>/<repo>
$ cd mysample
$ gi repo:init -u yourname -e yourname@gmail.com
$ vi README.md                # create a new file
$ gi track README.md          # register files into the repository
$ gi cc "add README file"     # commit changes
$ vi README.md                # update an existing file
$ gi stage .                  # add changes into staging area
$ gi staged                   # show changes in staging area
$ gi cc "update README file"  # commit changes
$ gi repo:remote:seturl github:yourname/mysample
$ gi up                       # upload local commits to remote repo
```


## License and Copyright

* $License: MIT License $
* $Copyright: copyright(c) 2023 kwatch@gmail.com $

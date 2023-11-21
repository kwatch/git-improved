#!/usr/bin/env ruby
# -*- coding: utf-8 -*-
# frozen_string_literal: true

###
### $Release: 0.0.0 $
### $Copyright: copyright(c) 2023 kwatch@gmail.com $
### $License: MIT License $
###

require 'benry/cmdapp'
#require 'benry/unixcommand'    # lazy load


if (RUBY_VERSION.split('.').collect(&:to_i) <=> [2, 6]) < 0
  Kernel.module_eval do
    alias __orig_system system
    def system(*args, **kws)
      if kws.delete(:exception)
        __orig_system(*args, **kws)  or
          raise "Command failed: #{args.join(' ')}"
      else
        __orig_system(*args, **kws)
      end
    end
  end
end


module GitImproved

  VERSION = "$Version: 0.0.0 $".split()[1]
  ENVVAR_STARTUP = "GI_STARTUP"


  class GitConfig

    def initialize()
      @prompt                  = "[#{File.basename($0)}]$ "
      @default_action          = "status:here"   # or: "status:info"
      @initial_branch          = "main"   # != 'master'
      @initial_commit_message  = "Initial commit (empty)"
      @gitignore_items         = ["*~", "*.DS_Store", "tmp", "*.pyc"]
      @history_graph_format    = "%C(auto)%h %ad <%al> | %d %s"
     #@history_graph_format    = "\e[32m%h %ad\e[0m <%al> \e[2m|\e[0m\e[33m%d\e[0m %s"
      @history_graph_options   = ["--graph", "--date=short", "--decorate"]
    end

    attr_accessor :prompt
    attr_accessor :default_action
    attr_accessor :initial_branch
    attr_accessor :initial_commit_message
    attr_accessor :gitignore_items
    attr_accessor :history_graph_format
   #attr_accessor :history_graph_format
    attr_accessor :history_graph_options

  end


  GIT_CONFIG = GitConfig.new

  APP_CONFIG = Benry::CmdApp::Config.new("Git Improved", VERSION).tap do |c|
    c.option_topic          = true
    c.option_quiet          = true
    c.option_color          = true
    c.option_dryrun         = true
    c.format_option         = "  %-19s : %s"
    c.format_action         = "  %-19s : %s"
    c.backtrace_ignore_rexp = /\/gi(?:t-improved\.rb)?:/
    c.help_postamble        = {
      "Example:" => <<END,
  $ mkdir mysample              # or: gi repo:clone github:<user>/<repo>
  $ cd mysample
  $ gi repo:init -u yourname -e yourname@gmail.com
  $ vi README.md                   # create a new file
  $ gi track README.md             # track files into the repository
  $ gi cc "add README file"        # commit changes
  $ vi README.md                   # update an existing file
  $ gi stage .                     # add changes into staging area
  $ gi staged                      # show changes in staging area
  $ gi cc -m "update README file"  # commit changes
  $ gi repo:remote:origin github:yourname/mysample
  $ gi up                          # upload local commits to remote repo
END
      "Document:" => "  https://kwatch.github.io/git-improved/",
    }
  end


  class GitCommandFailed < Benry::CmdApp::CommandError

    def initialize(git_command=nil)
      super "Git command failed: #{git_command}"
      @git_command = git_command
    end

    attr_reader :git_commit

  end


  module ActionHelper

    def git(*args)
      argstr = args.collect {|s| _qq(s) }.join(" ")
      echoback("git #{argstr}")
      return if $DRYRUN_MODE
      out = $SUBPROCESS_OUTPUT || nil
      if out
        system(["git", "git"], *args, out: out, err: out)  or
          raise GitCommandFailed, "git #{argstr}"
      else
        system(["git", "git"], *args)  or
          raise GitCommandFailed, "git #{argstr}"
      end
    end

    def git!(*args)
      git(*args)
    rescue GitCommandFailed
      false
    end

    def system!(command)
      out = $SUBPROCESS_OUTPUT || nil
      if out
        system command, exception: true, out: out, err: out
      else
        system command, exception: true
      end
    end

    protected

    def curr_branch()
      return `git rev-parse --abbrev-ref HEAD`.strip()
    end

    def prev_branch()
      #s = `git rev-parse --symbolic-full-name @{-1}`.strip()
      #return s.split("/").last
      return `git rev-parse --abbrev-ref @{-1}`.strip()
    end

    def parent_branch()
      # ref: https://stackoverflow.com/questions/3161204/
      #   git show-branch -a \
      #   | sed 's/].*//' \
      #   | grep '\*' \
      #   | grep -v "\\[$(git branch --show-current)\$" \
      #   | head -n1 \
      #   | sed 's/^.*\[//'
      curr = curr_branch()
      end_str = "[#{curr}\n"
      output = `git show-branch -a`
      output.each_line do |line|
        line = line.sub(/\].*/, '')
        next unless line =~ /\*/
        next if line.end_with?(end_str)
        parent = line.sub(/^.*?\[/, '').strip()
        return parent
      end
      return nil
    end

    def resolve_branch(branch)
      case branch
      when "CURR"   ; return curr_branch()
      when "PREV"   ; return prev_branch()
      when "PARENT" ; return parent_branch()
      when "-"      ; return prev_branch()
      else          ; return branch
      end
    end

    def resolve_except_prev_branch(branch)
      if branch == nil || branch == "-" || branch == "PREV"
        return "-"
      else
        return resolve_branch(branch)
      end
    end

    def resolve_repository_url(url)
      case url
      when /^github:/
        url =~ /^github:(?:\/\/)?([^\/]+)\/([^\/]+)$/  or
          raise action_error("Invalid GitHub URL: #{url}")
        user = $1; project = $2
        return "git@github.com:#{user}/#{project}.git"
      when /^gitlab:/
        url =~ /^gitlab:(?:\/\/)?([^\/]+)\/([^\/]+)$/  or
          raise action_error("Invalid GitLub URL: #{url}")
        user = $1; project = $2
        return "git@gitlab.com:#{user}/#{project}.git"
      else
        return url
      end
    end

    def remote_repo_of_branch(branch)
      branch_ = Regexp.escape(branch)
      output = `git config --get-regexp '^branch\\.#{branch_}\\.remote'`
      arr = output.each_line.grep(/^branch\..*?\.remote (.*)/) { $1 }
      remote = arr.empty? ? nil : arr[0]
      return remote
    end

    def color_mode?
      return $stdout.tty?
    end

    def ask_to_user(question)
      print "#{question} "
      $stdout.flush()
      answer = $stdin.readline().strip()
      return answer.empty? ? nil : answer
    end

    def ask_to_user!(question)
      answer = ""
      while answer.empty?
        print "#{question}: "
        $stdout.flush()
        answer = $stdin.read().strip()
      end
      return answer
    end

    def confirm(question, default_yes: true)
      if default_yes
        return _confirm(question, "[Y/n]", "Y") {|ans| ans !~ /\A[nN]/ }
      else
        return _confirm(question, "[y/N]", "N") {|ans| ans !~ /\A[yY]/ }
      end
    end

    private

    def _confirm(question, prompt, default_answer, &block)
      print "#{question} #{prompt}: "
      $stdout.flush()
      answer = $stdin.readline().strip()
      anser = default_answer if answer.empty?
      return yield(answer)
    end

    def _qq(str, force: false)
      if force || str =~ /\A[-+\w.,:=%\/^@]+\z/
        return str
      elsif str =~ /\A(-[-\w]+=)/
        return $1 + _qq($')
      else
        #return '"' + str.gsub(/[$!`\\"]/) { "\\#{$&}" } + '"'
        return '"' + str.gsub(/[$!`\\"]/, "\\\\\\&") +  '"'
      end
    end

    def _same_commit_id?(branch1, branch2)
      arr = `git rev-parse #{branch1} #{branch2}`.split()
      return arr[0] == arr[1]
    end

  end


  class GitAction < Benry::CmdApp::Action
    #include Benry::UnixCommand        ## include lazily
    include ActionHelper

    protected

    def prompt()
      return "[gi]$ "
    end

    def echoback(command)
      e1, e2 = color_mode?() ? ["\e[2m", "\e[0m"] : ["", ""]
      puts "#{e1}#{prompt()}#{command}#{e2}" unless $QUIET_MODE
      #puts "#{e1}#{super}#{e2}" unless $QUIET_MODE
    end

    def _lazyload_unixcommand()
      require 'benry/unixcommand'
      GitAction.class_eval {
        include Benry::UnixCommand
        remove_method :mkdir, :cd, :touch
      }
    end
    private :_lazyload_unixcommand

    def sys(*args)
      if $DRYRUN_MODE
        echoback args.join(' ')
      else
        _lazyload_unixcommand()
        super
      end
    end

    def sys!(*args)
      if $DRYRUN_MODE
        echoback args.join(' ')
      else
        _lazyload_unixcommand()
        super
      end
    end

    def mkdir(*args)
      if $DRYRUN_MODE
        echoback "mkdir #{args.join(' ')}"
      else
        _lazyload_unixcommand()
        super
      end
    end

    def cd(dir, &block)
      if $DRYRUN_MODE
        echoback "cd #{dir}"
        if File.directory?(dir)
          Dir.chdir dir, &block
        else
          yield if block_given?()
        end
        echoback "cd -" if block_given?()
      else
        _lazyload_unixcommand()
        super
      end
    end

    def touch(*args)
      if $DRYRUN_MODE
        echoback "touch #{args.join(' ')}"
      else
        _lazyload_unixcommand()
        super
      end
    end

    public


    ##
    ## status:
    ##
    category "status:" do

      @action.("same as 'stats:compact .'", important: true)
      def here()
        git "status", "-sb", "."
      end

      @action.("show various infomation of current status")
      def info(path=".")
        #command = "git status -sb #{path} | awk '/^\\?\\? /{print $2}' | sed 's!/$!!' | xargs ls -dF --color"
        command = "git status -sb #{path} | sed -n 's!/$!!;/^??/s/^?? //p' | xargs ls -dF --color"
        #command = "git status -sb #{path} | perl -ne 'print if s!^\\?\\? (.*?)/?$!\\1!' | xargs ls -dF --color"
        #command = "git status -sb #{path} | ruby -ne \"puts \\$1 if /^\\?\\? (.*?)\\/?$/\" | xargs ls -dF --color"
        echoback command
        system! command
        git "status", "-sb", "-uno", path
        #run_action "branch:echo", "CURR"
      end

      status_optset = optionset {
        @option.(:trackedonly, "-U", "ignore untracked files")
      }

      @action.("show status in compact format")
      @optionset.(status_optset)
      def compact(*path, trackedonly: false)
        opts = trackedonly ? ["-uno"] : []
        git "status", "-sb", *opts, *path
      end

      @action.("show status in default format")
      @optionset.(status_optset)
      def default(*path, trackedonly: false)
        opts = trackedonly ? ["-uno"] : []
        git "status", *opts, *path
      end

    end

    define_alias "status", "status:compact"


    ##
    ## branch:
    ##
    category "branch:" do

      @action.("list branches")
      @option.(:all   , "-a, --all"   , "list both local and remote branches (default)")
      @option.(:remote, "-r, --remote", "list remote branches")
      @option.(:local , "-l, --local" , "list local branches")
      def list(all: false, remote: false, local: false)
        opt = remote ? "-r" : local ? "-l" : "-a"
        git "branch", opt
      end

      @action.("switch to previous or other branch", important: true)
      def switch(branch=nil)
        branch = resolve_except_prev_branch(branch)
        git "checkout", branch
        #git "switch", branch
      end

      @action.("create a new branch, not switch to it")
      @option.(:on, "--on=<commit>", "commit-id on where the new branch will be created")
      @option.(:switch, "-w, --switch", "switch to the new branch after created")
      def create(branch, on: nil, switch: false)
        args = on ? [on] : []
        git "branch", branch, *args
        git "checkout", branch if switch
      end

      @action.("create a new branch and switch to it", important: true)
      @option.(:on, "--on=<commit>", "commit-id on where the new branch will be created")
      def fork(branch, on: nil)
        args = on ? [on] : []
        git "checkout", "-b", branch, *args
      end

      mergeopts = optionset {
        @option.(:delete     , "-d, --delete", "delete the current branch after merged")
        @option.(:fastforward, "    --ff", "use fast-forward merge")
        @option.(:reuse      , "-M", "reuse commit message (not invoke text editor for it)")
      }

      @action.("merge current branch into previous or other branch", important: true)
      @optionset.(mergeopts)
      def join(branch=nil, delete: false, fastforward: false, reuse: false)
        into_branch = resolve_branch(branch || "PREV")
        __merge(curr_branch(), into_branch, true, fastforward, delete, reuse)
      end

      @action.("merge previous or other branch into current branch")
      @optionset.(mergeopts)
      def merge(branch=nil, delete: false, fastforward: false, reuse: false)
        merge_branch = resolve_branch(branch || "PREV")
        __merge(merge_branch, curr_branch(), false, fastforward, delete, reuse)

      end

      def __merge(merge_branch, into_branch, switch, fastforward, delete, reuse)
        b = proc {|s| "'\e[1m#{s}\e[0m'" }   # bold font
        #msg = "Merge #{b.(merge_branch)} branch into #{b.(into_branch)}?"
        msg = switch \
            ? "Merge current branch #{b.(merge_branch)} into #{b.(into_branch)}." \
            : "Merge #{b.(merge_branch)} branch into #{b.(into_branch)}."
        if confirm(msg + " OK?")
          _check_fastforward_merge_available(into_branch, merge_branch)
          opts = fastforward ? ["--ff-only"] : ["--no-ff"]
          opts << "--no-edit" if reuse
          git "checkout", into_branch if switch
          git "merge", *opts, (switch ? "-" : merge_branch)
          git "branch", "-d", merge_branch if delete
        else
          puts "** Not joined."     if switch
          puts "** Not merged." unless switch
        end
      end
      private :__merge

      def _check_fastforward_merge_available(parent_branch, child_branch)
        parent, child = parent_branch, child_branch
        cmd = "git merge-base --is-ancestor #{parent} #{child}"
        result_ok = system cmd
        result_ok  or
          raise action_error("Cannot merge '#{child}' branch; rebase it onto '#{parent}' in advance.")
      end
      private :_check_fastforward_merge_available

      @action.("create a new local branch from a remote branch")
      @option.(:remote, "--remote=<remote>", "remote repository name (default: origin)")
      def checkout(branch, remote: "origin")
        local_branch = branch
        remote_branch = "#{remote}/#{branch}"
        git "checkout", "-b", local_branch, remote_branch
      end

      @action.("rename the current branch to other name")
      @option.(:target,  "-t <branch>", "target branch instead of current branch")
      def rename(new_branch, target: nil)
        old_branch = target || curr_branch()
        git "branch", "-m", old_branch, new_branch
      end

      @action.("delete a branch")
      @option.(:force,  "-f, --force", "delete forcedly even if not merged")
      @option.(:remote, "-r, --remote[=origin]", "delete a remote branch")
      def delete(branch, force: false, remote: nil)
        if branch == nil
          branch = curr_branch()
          yes = confirm "Are you sure to delete current branch '#{branch}'?", default_yes: false
          return unless yes
          git "checkout", "-" unless remote
        else
          branch = resolve_branch(branch)
        end
        if remote
          remote = "origin" if remote == true
          opts = force ? ["-f"] : []
          #git "push", *opts, remote, ":#{branch}"
          git "push", "--delete", *opts, remote, branch
        else
          opts = force ? ["-D"] : ["-d"]
          git "branch", *opts, branch
        end
      end

      @action.("change commit-id of current HEAD")
      @option.(:restore, "--restore", "restore files after reset")
      def reset(commit, restore: false)
        opts = []
        opts << "--hard" if restore
        git "reset", *opts, commit
      end

      @action.("rebase (move) current branch on top of other branch")
      @option.(:from, "--from=<commit-id>", "commit-id where current branch started")
      def rebase(branch_onto, branch_upstream=nil, from: nil)
        br_onto = resolve_branch(branch_onto)
        if from
          git "rebase", "--onto=#{br_onto}", from+"^"
        elsif branch_upstream
          git "rebase", "--onto=#{br_onto}", resolve_branch(branch_upstream)
        else
          git "rebase", br_onto
        end
      end

      @action.("git pull && git stash && git rebase && git stash pop")
      @option.(:rebase, "-b, --rebase", "rebase if prev branch updated")
      def update(branch=nil, rebase: false)
        if curr_branch() == GIT_CONFIG.initial_branch
          git "pull"
          return
        end
        #
        branch ||= prev_branch()
        remote = remote_repo_of_branch(branch)  or
          raise action_error("Previous branch '#{branch}' has no remote repo. (Hint: run `gi branch:upstream -t #{branch} origin`.)")
        puts "[INFO] previous: #{branch}, remote: #{remote}" unless $QUIET_MODE
        #
        git "fetch"
        file_changed    = ! `git diff`.empty?
        remote_updated  = ! _same_commit_id?(branch, "#{remote}/#{branch}")
        rebase_required = ! `git log --oneline HEAD..#{branch}`.empty?
        if remote_updated || (rebase && rebase_required)
          git "stash", "push", "-q" if file_changed
          if remote_updated
            git "checkout", "-q", branch
            #git "reset", "--hard", "#{remote}/#{branch}"
            git "pull"
            git "checkout", "-q", "-"
          end
          git "rebase", branch      if rebase
          git "stash", "pop", "-q"  if file_changed
        end
      end

      @action.("print upstream repo name of current branch")
      def upstream()
        #git! "rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{u}"
        branch = curr_branch()
        echoback "git config --get-regexp '^branch\\.#{branch}\\.remote' | awk '{print $2}'"
        output = `git config --get-regexp '^branch\\.#{branch}\\.remote'`
        output.each_line {|line| puts line.split()[1] }
      end

      @action.("show current branch name")
      def current()
        git "rev-parse", "--abbrev-ref", "HEAD"
        #git "symbolic-ref", "--short", "HEAD"
        #git "branch", "--show-current"
      end

      @action.("show previous branch name")
      def previous()
        #git "rev-parse", "--symbolic-full-name", "@{-1}"
        git "rev-parse", "--abbrev-ref", "@{-1}"
      end

      @action.("show parent branch name (EXPERIMENTAL)")
      def parent()
        # ref: https://stackoverflow.com/questions/3161204/
        command = <<~'END'
          git show-branch -a \
          | sed 's/].*//' \
          | grep '\*' \
          | grep -v "\\[$(git branch --show-current)\$" \
          | head -n1 \
          | sed 's/^.*\[//'
        END
        echoback(command.gsub(/\\\n/, '').strip())
        puts parent_branch()
      end

      @action.("print CURR/PREV/PARENT branch name")
      def echo(branch)
        case branch
        when "CURR"      ; run_action "current"
        when "PREV", "-" ; run_action "previous"
        when "PARENT"    ; run_action "parent"    # (EXPERIMENTAL)
        else             ; git "rev-parse", "--abbrev-ref", branch
        end
      end

    end

    define_alias("branches", "branch:list")
    define_alias("branch"  , "branch:create")
    define_alias("switch"  , "branch:switch")
    define_alias("sw"      , "branch:switch")
    define_alias("fork"    , "branch:fork")
    define_alias("join"    , "branch:join")
    define_alias("merge"   , "branch:merge")
    define_alias("update"  , "branch:update")


    ##
    ## file:
    ##
    category "file:" do

      @action.("list (un)tracked/ignored/missing files")
      @option.(:filtertype, "-F <filtertype>", "one of:", detail: <<~END)
                              - tracked   : only tracked files (default)
                              - untracked : only not-tracked files
                              - ignored   : ignored files by '.gitignore'
                              - missing   : tracked but missing files
                            END
      @option.(:full, "--full", "show full list")
      def list(path=".", filtertype: "tracked", full: false)
        method_name = "__file__list__#{filtertype}"
        respond_to?(method_name, true)  or (
          s = self.private_methods.grep(/^__file__list__(.*)/) { $1 }.join('/')
          raise option_error("#{filtertype}: Uknown filter type (expected: #{s}})")
        )
        __send__(method_name, path, full)
      end

      private

      def __file__list__tracked(path, full)
        paths = path ? [path] : []
        git "ls-files", *paths
      end

      def __file__list__untracked(path, full)
        opt = full ? " -u" : nil
        echoback "git status -s#{opt} #{path} | grep '^?? '"
        output = `git status -s#{opt} #{path}`
        puts output.each_line().grep(/^\?\? /)
      end

      def __file__list__ignored(path, full)
        opt = full ? "--ignored=matching" : "--ignored"
        echoback "git status -s #{opt} #{path} | grep '^!! '"
        output = `git status -s #{opt} #{path}`
        puts output.each_line().grep(/^!! /)
      end

      def __file__list__missing(path, full)
        paths = path ? [path] : []
        git "ls-files", "--deleted", *paths
      end

      public

      ## TODO: should move to 'file:' category?
      @action.("register files into the repository", important: true)
      @option.(:force, "-f, --force", "allow to track ignored files")
      @option.(:recursive, "-r, --recursive", "track files under directories")
      #@option.(:allow_empty_dir, "-e, --allow-empty-dir", "create '.gitkeep' to track empty directory")
      def track(file, *file2, force: false, recursive: false)
        files = [file] + file2
        files.each do |x|
          output = `git ls-files -- #{x}`
          output.empty?  or
            raise action_error("#{x}: Already tracked.")
        end
        files.each do |x|
          if File.directory?(x)
            recursive  or
              raise action_error("#{x}: File expected, but is a directory (specify `-r` or `--recursive` otpion to track files under the directory).")
          end
        end
        opts = force ? ["-f"] : []
        git "add", *opts, *files
      end

      @action.("show changes of files", important: true)
      def changes(*path)
        git "diff", *path
      end

      @action.("move files into a directory")
      @option.(:to, "--to=<dir>", "target directory")
      def move(file, *file2, to: nil)
        dir = to
        dir != nil  or
          raise option_error("Option `--to=<dir>` required.")
        File.exist?(dir)  or
          raise option_error("--to=#{dir}: Directory not exist (create it first).")
        File.directory?(dir)  or
          raise option_error("--to=#{dir}: Not a directory (to rename files, use 'file:rename' action instead).")
        files = [file] + file2
        git "mv", *files, dir
      end

      @action.("rename a file or directory to new name")
      def rename(old_file, new_file)
        ! File.exist?(new_file)  or
          raise action_failed("#{new_file}: Already exist.")
        git "mv", old_file, new_file
      end

      @action.("delete files or directories")
      @option.(:recursive, "-r, --recursive", "delete files recursively.")
      def delete(file, *file2, recursive: false)
        files = [file] + file2
        opts = recursive ? ["-r"] : []
        git "rm", *opts, *files
      end

      @action.("restore files (= clear changes)", important: true)
      def restore(*path)
        if path.empty?
          git "reset", "--hard"
          #git "checkout", "--", "."           # path required
        else
          #git "reset", "--hard", "--", *path  #=> fatal: Cannot do hard reset with paths.
          git "checkout", "--", *path
        end
      end

      @action.("print commit-id, author, and timestap of each line")
      @option.(:range, "-L <N1,N2|:func>", "range (start,end) or function name")
      def blame(path, *path2, range: nil)
        paths = [path] + path2
        opts = []
        opts << "-L" << range if range
        git "blame", *opts, *paths
      end

      @action.("find by pattern")
      def egrep(pattern, commit=nil)
        args = []
        args << commit if commit
        git "grep", "-E", pattern, *args
      end

    end

    define_alias("files"    , "file:list")
    #define_alias("ls"       , "file:list")
    define_alias("track"    , "file:track")
    define_alias("register" , "file:track")
    define_alias("changes"  , "file:changes")
    #define_alias("move"     , "file:move")
    #define_alias("rename"   , "file:rename")
    #define_alias("delete"   , "file:delete")
    #define_alias("restore"  , "file:restore")


    ##
    ## staging:
    ##
    category "staging:" do

      @action.("add changes of files into staging area", important: true)
      @option.(:pick, "-p, --pick", "pick up changes interactively")
      #@option.(:update, "-u, --update", "add all changes of tracked files")
      def add(path, *path2, pick: false) # , update: false
        paths = [path] + path2
        paths.each do |x|
          next if File.directory?(x)
          output = `git ls-files #{x}`
          ! output.strip.empty?  or
            raise action_error("#{x}: Not tracked yet (run 'track' action instead).")
        end
        #
        opts = []
        opts << "-p" if pick
        opts << "-u" unless pick
        git "add", *opts, *paths
      end

      @action.("show changes in staging area", important: true)
      def show(*path)
        git "diff", "--cached", *path
      end

      @action.("edit changes in staging area")
      def edit(*path)
        git "add", "--edit", *path
      end

      @action.("delete all changes in staging area", important: true)
      def clear(*path)
        args = path.empty? ? [] : ["--"] + path
        git "reset", "HEAD", *args
      end

    end

    define_alias("stage"    , "staging:add")
    define_alias("staged"   , "staging:show")
    define_alias("unstage"  , "staging:clear")
    define_alias("pick"     , ["staging:add", "-p"])


    ##
    ## commit:
    ##
    category "commit:" do

      @action.("create a new commit", important: true)
      @option.(:message, "-m, --message=<message>", "commit message")
      def create(*path, message: nil)
        opts = message ? ["-m", message] : []
        args = path.empty? ? [] : ["--", *path]
        git "commit", *opts, *args
      end

      @action.("correct the last commit", important: true)
      @option.(:reuse, "-M", "reuse commit message (not invoke text editor for it)")
      def correct(reuse: false)
        opts = reuse ? ["--no-edit"] : []
        git "commit", "--amend", *opts
      end

      @action.("correct the previous commit")
      @option.(:histedit, "-e, --histedit", "start 'history:edit' action after fixup commit created")
      def fixup(commit, histedit: nil)
        git "commit", "--fixup=#{commit}"
        if histedit
          run_once "history:edit:start", "#{commit}^"
        end
      end

      @action.("apply a commit to curr branch (known as 'cherry-pick')")
      def apply(commit, *commit2)
        commits = [commit] + commit2
        git "cherry-pick", *commits
      end

      @action.("show commits in current branch", important: true)
      @option.(:count, "-n <N>", "show latest N commits", type: Integer)
      @option.(:file, "-f, --file=<path>", "show commits related to file")
      def show(commit=nil, count: nil, file: nil)
        if count && commit
          git "show", "#{commit}~#{count}..#{commit}"
        elsif count
          git "show", "HEAD~#{count}..HEAD"
        elsif commit
          git "show", commit
        elsif file
          git "log", "-p", "--", file
        else
          git "log", "-p"
        end
      end

      @action.("create a new commit which reverts the target commit")
      @option.(:count, "-n <N>", "show latest N commits", type: Integer)
      @option.(:mainline, "--mainline=<N>", "parent number (necessary to revert merge commit)")
      @option.(:reuse, "-M", "reuse commit message (not invoke text editor for it)")
      def revert(*commit, count: nil, mainline: nil, reuse: false)
        commits = commit
        opts = []
        opts << "--no-edit" if reuse
        opts << "-m" << mainline.to_s if mainline
        if count
          commits.length <= 1  or
            raise action_error("Multiple commits are not allowed when '-n' option specified.")
          commit = commits.empty? ? "HEAD" : commits[0]
          git "revert", *opts, "#{commit}~#{count}..#{commit}"
        elsif ! commits.empty?
          git "revert", *opts, *commits
        else
          raise action_error("`<commit-id>` or `-n <N>` option required.")
        end
      end

      @action.("cancel recent commits up to the target commit-id", important: true)
      @option.(:count  , "-n <N>"   , "cancel recent N commits", type: Integer)
      @option.(:restore, "--restore", "restore files after rollback")
      def rollback(commit=nil, count: nil, restore: false)
        opts = restore ? ["--hard"] : []
        if commit && count
          raise action_failed("Commit-id and `-n` option are exclusive.")
        elsif commit
          git "reset", *opts, commit
        elsif count
          git "reset", *opts, "HEAD~#{count}"
        else
          git "reset", *opts, "HEAD^"
        end
      end

    end

    define_alias("commit"  , "commit:create")
    define_alias("cc"      , "commit:create")
    define_alias("correct" , "commit:correct")
    define_alias("fixup"   , "commit:fixup")
    define_alias("commits" , "commit:show")
   #define_alias("rollback", "commit:rollback")


    ##
    ## history:
    ##
    category "history:", action: "show" do

      @action.("show commit history in various format", important: true)
      @option.(:all, "-a, --all"   , "show history of all branches")
      @option.(:format, "-F, --format=<format>", "default/compact/detailed/graph")
      @option.(:author, "-u, --author", "show author name before '@' of email address (only for 'graph' format)")
      def show(*path, all: false, format: "default", author: false)
        opts = []
        HISTORY_SHOW_OPTIONS.key?(format)  or
          raise option_error("#{format}: Unknown format.")
        val = HISTORY_SHOW_OPTIONS[format]
        case val
        when nil    ;
        when String ; opts << val
        when Array  ; opts.concat(val)
        when Proc   ; opts.concat([val.call(author: author)].flatten)
        else
          raise TypeError.new("HISTORY_SHOW_OPTIONS[#{format.inspect}]: Unexpected type value: #{val.inspect}")
        end
        opts = ["--all"] + opts if all
        ## use 'git!' to ignore pipe error when pager process quitted
        git! "log", *opts, *path
      end

      HISTORY_SHOW_OPTIONS = {
        "default"  => nil,
        "compact"  => "--oneline",
        "detailed" => "--format=fuller",
        "graph"    => proc {|author: false, **_kws|
          fmt = GIT_CONFIG.history_graph_format
          fmt = fmt.sub(/ ?<?%a[eEnNlL]>? ?/, ' ') unless author
          opts = ["--format=#{fmt}"] + GIT_CONFIG.history_graph_options
          opts
        },
      }

      @action.("show commits not uploaded yet")
      def notuploaded()
        git "cherry", "-v"
      end

      ## history:edit
      category "edit:" do

        @action.("start `git rebase -i` to edit commit history", important: true)
        @option.(:count  , "-n, --num=<N>", "edit last N commits")
        #@option.(:stash, "-s, --stash", "store current changes into stash temporarily")
        def start(commit=nil, count: nil)
          if commit && count
            raise action_error("Commit-id and `-n` option are exclusive.")
          elsif commit
            nil
            arg = "#{commit}^"
          elsif count
            arg = "HEAD~#{count}"
          else
            raise action_error("Commit-id or `-n` option required.")
          end
          git "rebase", "-i", "--autosquash", arg
        end

        @action.("resume (= conitnue) suspended `git rebase -i`")
        def resume()
          git "rebase", "--continue"
        end

        @action.("skip current commit and resume")
        def skip()
          git "rebase", "--skip"
        end

        @action.("cancel (or abort) `git rebase -i`")
        def cancel()
          git "rebase", "--abort"
        end

      end

    end

    define_alias "hist"      , ["history", "-F", "graph"]
    #define_alias "history"   , "history:show"
    define_alias "histedit"  , "history:edit:start"
    #define_alias "histedit:resume", "history:edit:resume"
    #define_alias "histedit:skip"  , "history:edit:skip"
    #define_alias "histedit:cancel", "history:edit:cancel"


    ##
    ## repo:
    ##
    category "repo:" do

      def _config_user_and_email(user, email)
        if user == nil && `git config --get user.name`.strip().empty?
          user = ask_to_user "User name:"
        end
        git "config", "user.name" , user   if user
        if email == nil && `git config --get user.email`.strip().empty?
          email = ask_to_user "Email address:"
        end
        git "config", "user.email", email  if email
      end
      private :_config_user_and_email

      def _generate_gitignore_file(filename)
        items = GIT_CONFIG.gitignore_items
        sep = "> "
        items.each do |x|
          echoback "echo %-14s %s %s" % ["'#{x}'", sep, filename]
          sep = ">>"
        end
        content = (items + [""]).join("\n")
        File.write(filename, content, encoding: 'utf-8')
      end
      private :_generate_gitignore_file

      initopts = optionset() {
        @option.(:initial_branch, "-b, --branch=<branch>", "branch name (default: '#{GIT_CONFIG.initial_branch}')")
        @option.(:user , "-u, --user=<user>", "user name")
        @option.(:email, "-e, --email=<email>", "email address")
        @option.(:initial_commit, "-x", "not create an empty initial commit", value: false)
      }

      @action.("initialize git repository with empty initial commit", important: true)
      @optionset.(initopts)
      def init(user: nil, email: nil, initial_branch: nil, initial_commit: true)
        ! File.exist?(".git")  or
          raise action_error("Directory '.git' already exists.")
        branch ||= GIT_CONFIG.initial_branch
        git "init", "--initial-branch=#{branch}"
        _config_user_and_email(user, email)
        if initial_commit
          git "commit", "--allow-empty", "-m", GIT_CONFIG.initial_commit_message
        end
        filename = ".gitignore"
        _generate_gitignore_file(filename) unless File.exist?(filename)
      end

      @action.("create a new directory and initialize it as a git repo")
      @optionset.(initopts)
      def create(name, user: nil, email: nil, initial_branch: nil, initial_commit: true)
        dir = name
        mkdir dir
        cd dir do
          run_once "init", user: user, email: email, initial_branch: initial_branch, initial_commit: initial_commit
        end
      end

      @action.("copy a repository ('github:<user>/<repo>' is available)")
      @optionset.(initopts.select(:user, :email))
      def clone(url, dir=nil, user: nil, email: nil)
        url = resolve_repository_url(url)
        args = dir ? [dir] : []
        files = Dir.glob("*")
        git "clone", url, *args
        newdir = (Dir.glob("*") - files)[0] || dir
        cd newdir do
          _config_user_and_email(user, email)
        end if newdir
      end

      ## repo:remote:
      category "remote:", action: "handle" do

        @action.("list/get/set/delete remote repository", usage: [
                   "                   # list",
                   "<name>             # get",
                   "<name> <url>       # set ('github:user/repo' is avaialble)",
                   "<name> \"\"          # delete",
                 ], postamble: {
                   "Example:" => <<~'END'.gsub(/^/, "  "),
                     $ gi repo:remote                             # list
                     $ gi repo:remote origin                      # get
                     $ gi repo:remote origin github:user1/repo1   # set
                     $ gi repo:remote origin ""                   # delete
                   END
                 })
        def handle(name=nil, url=nil)
          url = resolve_repository_url(url) if url
          if name == nil
            git "remote", "-v"
          elsif url == nil
            git "remote", "get-url", name
          elsif url == ""
            git "remote", "remove", name
          elsif `git remote`.split().include?(name)
            git "remote", "set-url", name, url
          else
            git "remote", "add", name, url
          end
        end

        @action.("get/set/delete origin (= default remote repository)", usage: [
                   "            # get",
                   "<url>       # set ('github:user/repo' is avaialble)",
                   "\"\"          # delete",
                 ], postamble: {
                   "Example:" => <<~'END'.gsub(/^/, "  "),
                     $ gi repo:remote:origin                      # get
                     $ gi repo:remote:origin github:user1/repo1   # set
                     $ gi repo:remote:origin ""                   # delete
                   END
                 })
        def origin(url=nil)
          run_action "repo:remote", "origin", url
        end

      end

    end


    ##
    ## tag:
    ##
    category "tag:", action: "handle" do

      @action.("list/show/create/delete tags", important: true, usage: [
                 "                  # list",
                 "<tag>             # show commit-id of the tag",
                 "<tag> <commit>    # create a tag on the commit",
                 "<tag> HEAD        # create a tag on current commit",
                 "<tag> \"\"          # delete a tag",
               ])
      @option.(:remote, "-r, --remote[=origin]", "list/delete tags on remote (not for show/create)")
      def handle(tag=nil, commit=nil, remote: nil)
        if tag == nil               # list
          if remote
            #git "show-ref", "--tags"
            git "ls-remote", "--tags"
          else
            git "tag", "-l"
          end
        elsif commit == nil         # show
          ! remote  or
            raise option_error("Option '-r' or '--remote' is not available for showing tag.")
          git "rev-parse", tag
        elsif commit == ""          # delete
          if remote
            remote = "origin" if remote == true
            #git "push", "--delete", remote, tag     # may delete same name branch
            git "push", remote, ":refs/tags/#{tag}"
          else
            git "tag", "--delete", tag
          end
        else                        # create
          ! remote  or
            raise option_error("Option '-r' or '--remote' is not available for creating tag.")
          git "tag", tag, commit
        end
      end

      @action.("list tags", hidden: true)
      @option.(:remote, "-r, --remote", "list remote tags")
      def list(remote: false)
        if remote
          #git "show-ref", "--tags"
          git "ls-remote", "--tags"
        else
          git "tag", "-l"
        end
      end

      ##--
      #@action.("create a new tag", important: true)
      #@option.(:on, "--on=<commit>", "commit-id where new tag created on")
      #def create(tag, on: nil)
      #  args = on ? [on] : []
      #  git "tag", tag, *args
      #end
      #
      #@action.("delete a tag")
      #@option.(:remote, "-r, --remote[=origin]", "delete from remote repository")
      #def delete(tag, *tag2, remote: nil)
      #  tags = [tag] + tag2
      #  if remote
      #    remote = "origin" if remote == true
      #    tags.each do |tag|
      #      #git "push", "--delete", remote, tag     # may delete same name branch
      #      git "push", remote, ":refs/tags/#{tag}"  # delete a tag safely
      #    end
      #  else
      #    git "tag", "-d", *tags
      #  end
      #end
      ##++

      @action.("upload tags")
      def upload()
        git "push", "--tags"
      end

      @action.("download tags")
      def download()
        git "fetch", "--tags", "--prune-tags"
      end

    end

    define_alias("tags", "tag:list")


    ##
    ## sync:
    ##
    category "sync:" do

      uploadopts = optionset {
        @option.(:upstream, "-u <remote>"  , "set upstream")
        @option.(:origin  , "-U"           , "same as '-u origin'")
        @option.(:force   , "-f, --force"  , "upload forcedly")
      }

      @action.("download and upload commits")
      @optionset.(uploadopts)
      def both(upstream: nil, origin: false, force: false)
        run_action "pull"
        run_action "push", upstream: upstream, origin: origin, force: force
      end

      @action.("upload commits to remote")
      @optionset.(uploadopts)
      def push(upstream: nil, origin: false, force: false)
        branch = curr_branch()
        upstream ||= "origin" if origin
        upstream ||= _ask_remote_repo(branch)
        #
        opts = []
        opts << "-f" if force
        if upstream
          git "push", *opts, "-u", upstream, branch  # branch name is required
        else
          git "push", *opts
        end
      end

      def _ask_remote_repo(branch)
        output = `git config --get-regexp '^branch\.'`
        has_upstream = output.each_line.any? {|line|
          line =~ /\Abranch\.(.*)\.remote / && $1 == branch
        }
        return nil if has_upstream
        remote = ask_to_user "Enter the remote repo name (default: \e[1morigin\e[0m) :"
        return remote && ! remote.empty? ? remote : "origin"
      end
      private :_ask_remote_repo

      @action.("download commits from remote and apply them to local")
      @option.(:apply, "-N, --not-apply", "just download, not apply", value: false)
      def pull(apply: true)
        if apply
          git "pull", "--prune"
        else
          git "fetch", "--prune"
        end
      end

    end

    define_alias("sync"     , "sync:both")
    define_alias("push"     , "sync:push")
    define_alias("upload"   , "sync:push")
    define_alias("up"       , "sync:push")
    define_alias("pull"     , "sync:pull")
    define_alias("download" , "sync:pull")
    define_alias("dl"       , "sync:pull")


    ##
    ## stash:
    ##
    category "stash:" do

      @action.("list stash history")
      def list()
        git "stash", "list"
      end

      @action.("show changes on stash")
      @option.(:num, "-n <N>", "show N-th changes on stash (1-origin)", type: Integer)
      #@option.(:index, "-x, --index=<N>", "show N-th changes on stash (0-origin)", type: Integer)
      def show(num: nil)
        args = num ? ["stash@{#{num - 1}}"] : []
        git "stash", "show", "-p", *args
      end

      @action.("save current changes into stash", important: true)
      @option.(:message, "-m <message>", "message")
      @option.(:pick, "-p, --pick"     , "pick up changes interactively")
      def put(*path, message: nil, pick: false)
        opts = []
        opts << "-m" << message if message
        opts << "-p" if pick
        args = path.empty? ? [] : ["--"] + path
        git "stash", "push", *opts, *args
      end

      @action.("restore latest changes from stash", important: true)
      @option.(:num, "-n <N>", "pop N-th changes on stash (1-origin)", type: Integer)
      def pop(num: nil)
        args = num ? ["stash@{#{num - 1}}"] : []
        git "stash", "pop", *args
      end

      @action.("delete latest changes from stash")
      @option.(:num, "-n, --num=<N>", "drop N-th changes on stash (1-origin)", type: Integer)
      def drop(num: nil)
        args = num ? ["stash@{#{num - 1}}"] : []
        git "stash", "drop", *args
      end

    end


    ##
    ## config:
    ##
    category "config:", action: "handle" do

      optset = optionset() {
        @option.(:global, "-g, --global", "handle global config")
        @option.(:local , "-l, --local" , "handle repository local config")
      }

      def _build_config_options(global, local)
        opts = []
        opts << "--global" if global
        opts << "--local"  if local
        return opts
      end

      @action.("list/get/set/delete config values", usage: [
                 "                # list",
                 "<key>           # get",
                 "<key> <value>   # set",
                 "<key> \"\"        # delete",
                 "<prefix>        # filter by prefix",
               ], postamble: {
                 "Example:" => (<<~END).gsub(/^/, "  "),
                   $ gi config                      # list
                   $ gi config core.editor          # get
                   $ gi config core.editor vim      # set
                   $ gi config core.editor ""       # delete
                   $ gi config core.                # filter by prefix
                   $ gi config .                    # list top level prefixes
                 END
               })
      @optionset.(optset)
      def handle(key=nil, value=nil, global: false, local: false)
        opts = _build_config_options(global, local)
        if key == nil                     # list
          git "config", *opts, "--list"
        elsif value == nil                # get or filter
          case key
          when "."                          # list top level prefixes
            echoback "gi config | awk -F. 'NR>1{d[$1]++}END{for(k in d){print(k\"\\t(\"d[k]\")\")}}' | sort"
            d = {}
            `git config -l #{opts.join(' ')}`.each_line do |line|
              d[$1] = (d[$1] || 0) + 1 if line =~ /^(\w+\.)/
            end
            d.keys.sort.each {|k| puts "#{k}\t(#{d[k]})" }
          when /\.$/                        # list (filter)
            pat = "^"+key.gsub('.', '\\.')
            #git "config", *opts, "--get-regexp", pat  # different with `config -l`
            echoback "git config -l #{opts.join(' ')} | grep '#{pat}'"
            `git config -l #{opts.join(' ')}`.each_line do |line|
              print line if line.start_with?(key)
            end
          else                              # get
            #git "config", "--get", *opts, key
            git "config", *opts, key
          end
        elsif value == ""                 # delete
          git "config", *opts, "--unset", key
        else                              # set
          git "config", *opts, key, value
        end
      end

      @action.("set user name and email", usage: [
                  "<user> <u@email> # set user name and email",
                  "<user@email>     # set email (contains '@')",
                  "<user>           # set user (not contain '@')",
                ])
      @optionset.(optset)
      def setuser(user, email=nil, global: false, local: false)
        opts = _build_config_options(global, local)
        if email == nil && user =~ /@/
          email = user
          user  = nil
        end
        user  = nil if user  == '-'
        email = nil if email == '-'
        git "config", *opts, "user.name" , user   if user
        git "config", *opts, "user.email", email  if email
      end

      @action.("list/get/set/delete aliases of 'git' (not of 'gi')", usage: [
                 "                 # list",
                 "<name>           # get",
                 "<name> <value>   # set",
                 "<name> \"\"        # delete",
               ])
      def alias(name=nil, value=nil)
        if value == ""      # delete
          git "config", "--global", "--unset", "alias.#{name}"
        elsif value != nil  # set
          git "config", "--global", "alias.#{name}", value
        elsif name != nil   # get
          git "config", "--global", "alias.#{name}"
        else                # list
          command = "git config --get-regexp '^alias\\.' | sed -e 's/^alias\\.//;s/ /\\t= /'"
          echoback(command)
          output = `git config --get-regexp '^alias.'`
          print output.gsub(/^alias\.(\S+) (.*)/) { "%s\t= %s" % [$1, $2] }
        end
      end


    end


    ##
    ## misc:
    ##
    category "misc:" do

      @action.("generate a startup file, or print to stdout if no args",
               usage: [
                 "<filename>     # generate a file",
                 "               # print to stdout",
               ])
      def startupfile(filename=nil)
        str = File.read(__FILE__, encoding: "utf-8")
        code = str.split(/^__END__\n/, 2)[1]
        code = code.gsub(/%SCRIPT%/, APP_CONFIG.app_command)
        code = code.gsub(/%ENVVAR_STARTUP%/, ENVVAR_STARTUP)
        #
        if ! filename || filename == "-"
          print code
        elsif File.exist?(filename)
          raise action_error("#{filename}: File already exists (remove it before generating new file).")
        else
          File.write(filename, code, encoding: 'utf-8')
          puts "[OK] #{filename} generated." unless $QUIET_MODE
        end
      end

    end


  end


  Benry::CmdApp.module_eval do
    define_abbrev("b:"  , "branch:")
    define_abbrev("c:"  , "commit:")
    define_abbrev("C:"  , "config:")
    define_abbrev("g:"  , "staging:")
    define_abbrev("f:"  , "file:")
    define_abbrev("r:"  , "repo:")
    define_abbrev("r:r:", "repo:remote:")
    define_abbrev("h:"  , "history:")
    define_abbrev("h:e:", "history:edit:")
    define_abbrev("histedit:", "history:edit:")
   #define_abbrev("t:"  , "tag:")
   #define_abbrev("s:"  , "status:")
   #define_abbrev("y:"  , "sync:")
   #define_abbrev("T:"  , "stash:")
  end


  class AppHelpBuilder < Benry::CmdApp::ApplicationHelpBuilder

    def build_help_message(*args, **kwargs)
      @_omit_actions_part = true
      return super
    ensure
      @_omit_actions_part = false
    end

    def section_actions(*args, **kwargs)
      if @_omit_actions_part
        text ="  (Too long to show. Run `#{@config.app_command} -l` to list all actions.)"
        return render_section(header(:HEADER_ACTIONS), text)
      else
        return super
      end
    end

  end


  def self.main(argv=ARGV)
    errmsg = _load_setup_file(ENV[ENVVAR_STARTUP])
    if errmsg
      $stderr.puts "\e[31m[ERROR]\e[0m #{errmsg}"
     return 1
    end
    #
    APP_CONFIG.default_action = GIT_CONFIG.default_action
    app_help_builder = AppHelpBuilder.new(APP_CONFIG)
    app = Benry::CmdApp::Application.new(APP_CONFIG, nil, app_help_builder)
    return app.main(argv)
  end

  def self._load_setup_file(filename)
    return nil if filename == nil || filename.empty?
    filename = File.expand_path(filename)
    File.exist?(filename)  or
      return "#{filename}: Setup file specified but not exist."
    require File.absolute_path(filename)
    return nil
  end
  private_class_method :_load_setup_file


end


if __FILE__ == $0
  exit GitImproved.main()
end


__END__
# coding: utf-8
# frozen_string_literal: true

##
## @(#) Setup file for '%SCRIPT%' command.
##
## This file is loaded by '%SCRIPT%' command only if $%ENVVAR_STARTUP% is set,
## for example:
##
##     $ gi hello
##     [ERROR] hello: Action not found.
##
##     $ export %ENVVAR_STARTUP%="~/.gi_setup.rb"
##     $ gi hello
##     Hello, world!
##

module GitImproved


  ##
  ## Configuration example
  ##
  GIT_CONFIG.tap do |c|
    #c.prompt                  = "[gi]$ "
    #c.default_action          = "status:here"   # or: "status:info"
    #c.initial_branch          = "main"   # != 'master'
    #c.initial_commit_message  = "Initial commit (empty)"
    #c.gitignore_items         = ["*~", "*.DS_Store", "tmp/*", "*.pyc"]
    #c.history_graph_format    = "%C(auto)%h %ad <%al> | %d %s"
    ##c.history_graph_format    = "\e[32m%h %ad\e[0m <%al> \e[2m|\e[0m\e[33m%d\e[0m %s"
    #c.history_graph_options   = ["--graph", "--date=short", "--decorate"]
  end


  ##
  ## Custom alias example
  ##
  GitAction.class_eval do

    ## `gi br <branch>` == `gi breanch:create -w <branch>`
    define_alias "br", ["branch:create", "-w"]

  end


  ##
  ## Custom action example
  ##
  GitAction.class_eval do

    #category "example:" do

      langs = ["en", "fr", "it"]

      @action.("print greeting message")
      @option.(:lang, "-l, --lang=<lang>", "language (en/fr/it)", enum: langs)
      def hello(name="world", lang: "en")
        case lang
        when "en"  ; puts "Hello, #{name}!"
        when "fr"  ; puts "Bonjour, #{name}!"
        when "it"  ; puts "Chao, #{name}!"
        else
          raise option_error("#{lang}: Unknown language.")
        end
      end

    #end

    #define_alias "hello", "example:hello"

  end


end

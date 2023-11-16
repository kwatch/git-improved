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


module GitImproved

  VERSION = "$Version: 0.0.0 $".split()[1]
  ENVVAR_SETUP = "GI_SETUP"


  class GitConfig

    def initialize()
      @values = {}
    end

    def each(&block)
      return enum_for(:each) unless block_given?()
      @values.each(&block)
    end

    def [](key)
      return @values[key]
    end

    def []=(key, val)
      @values[key] = val
      return val
    end

    def has?(key)
      return @values.key?(key)
    end

    def method_missing(meth, *args)
      if meth.to_s.end_with?('=') && args.length == 1
        key = meth.to_s.chomp('=').intern
        @values[key] = args[0]
        return @values[key]
      elsif @values.key?(meth) && args.empty?
        return @values[meth]
      else
        super
      end
    end

  end


  GIT_CONFIG = GitConfig.new.tap do |c|
    c.prompt                  = "[#{File.basename($0)}]$ "
    c.default_action          = "status:here"   # or: "status:info"
    c.initial_branch          = "main"   # != 'master'
    c.initial_commit_message  = "Initial commit (empty)"
    c.gitignore_items         = ["*~", "*.DS_Store", "tmp/*", "*.pyc"]
    c.history_graph_format    = "%C(auto)%h %ad <%al> | %d %s"
   #c.history_graph_format    = "\e[32m%h %ad\e[0m <%al> \e[2m|\e[0m\e[33m%d\e[0m %s"
    c.history_graph_options   = ["--graph", "--date=short", "--decorate"]
  end

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
  $ vi README.md                # create a new file
  $ gi track README.md          # register files into the repository
  $ gi cc "add README file"     # commit changes
  $ vi README.md                # update an existing file
  $ gi stage .                  # add changes into staging area
  $ gi staged                   # show changes in staging area
  $ gi cc "update README file"  # commit changes
  $ gi repo:remote:seturl github:yourname/mysample
  $ gi up                       # upload local commits to remote repo
END
      "Document:" => "  https://kwatch.github.io/git-improved/",
    }
  end


  class GitAction < Benry::CmdApp::Action
    #include Benry::UnixCommand        ## include lazily


    class GitCommandFailed < Benry::CmdApp::CommandError

      def initialize(git_command=nil)
        super "Git command failed: #{git_command}"
        @git_command = git_command
      end

      attr_reader :git_commit

    end

    protected

    def prompt()
      return "[gi]$ "
    end

    def echoback(command)
      e1, e2 = _color_mode?() ? ["\e[2m", "\e[0m"] : ["", ""]
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

    private

    def _curr_branch()
      return `git rev-parse --abbrev-ref HEAD`.strip()
    end

    def _prev_branch()
      #s = `git rev-parse --symbolic-full-name @{-1}`.strip()
      #return s.split("/").last
      return `git rev-parse --abbrev-ref @{-1}`.strip()
    end

    def _parent_branch()
      # ref: https://stackoverflow.com/questions/3161204/
      #   git show-branch -a \
      #   | sed 's/].*//' \
      #   | grep '\*' \
      #   | grep -v "\\[$(git branch --show-current)\$" \
      #   | head -n1 \
      #   | sed 's/^.*\[//'
      curr = _curr_branch()
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

    def _resolve_branch(branch)
      case branch
      when "CURR"   ; return _curr_branch()
      when "PREV"   ; return _prev_branch()
      when "PARENT" ; return _parent_branch()
      when "-"      ; return _prev_branch()
      else          ; return branch
      end
    end

    def _resolve_except_prev_branch(branch)
      if branch == nil || branch == "-" || branch == "PREV"
        return "-"
      else
        return _resolve_branch(branch)
      end
    end

    def _resolve_repository_url(url)
      case url
      when /^github:/
        url =~ /^github:(?:\/\/)?([^\/]+)\/([^\/]+)$/  or
          raise action_error("Invalid GitHub url: #{url}")
        user = $1; project = $2
        return "git@github.com:#{user}/#{project}.git"
      when /^gitlab:/
        url =~ /^gitlab:(?:\/\/)?([^\/]+)\/([^\/]+)$/  or
          raise action_error("Invalid GitLub url: #{url}")
        user = $1; project = $2
        return "git@gitlab.com:#{user}/#{project}.git"
      else
        return url
      end
    end

    def _load_startup_file()
      filename = ENV['GI_STARTUP']
      if filename && ! filename.empty?
        load filename
      end
    end

    def _confirm(question, default_yes: true)
      if default_yes
        return __confirm(question, "[Y/n]", "Y") {|ans| ans !~ /\A[nN]/ }
      else
        return __confirm(question, "[y/N]", "N") {|ans| ans !~ /\A[yY]/ }
      end
    end

    def __confirm(question, prompt, default_answer, &block)
      print "#{question} #{prompt}: "
      $stdout.flush()
      answer = $stdin.readline().strip()
      anser = default_answer if answer.empty?
      return yield(answer)
    end

    def _ask_to_user(question)
      print "#{question} "
      $stdout.flush()
      answer = $stdin.readline().strip()
      return answer.empty? ? nil : answer
    end

    def _ask_to_user!(question)
      answer = ""
      while answer.empty?
        print "#{question}: "
        $stdout.flush()
        answer = $stdin.read().strip()
      end
      return answer
    end

    def _color_mode?
      return $stdout.tty?
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

    public

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
        #run_action "branch:current"
      end

      status_optset = optionset {
        @option.(:registeredonly, "-U", "ignore unregistered files")
      }

      @action.("show status in compact format")
      @optionset.(status_optset)
      def compact(*path, registeredonly: false)
        opts = registeredonly ? ["-uno"] : []
        git "status", "-sb", *opts, *path
      end

      @action.("show status in default format")
      @optionset.(status_optset)
      def default(*path, registeredonly: false)
        opts = registeredonly ? ["-uno"] : []
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
        puts _parent_branch()
      end

      @action.("switch to previous or other branch", important: true)
      def switch(branch=nil)
        branch = _resolve_except_prev_branch(branch)
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
        into_branch = _resolve_branch(branch || "PREV")
        __merge(_curr_branch(), into_branch, true, fastforward, delete, reuse)
      end

      @action.("merge previous or other branch into current branch")
      @optionset.(mergeopts)
      def merge(branch=nil, delete: false, fastforward: false, reuse: false)
        merge_branch = _resolve_branch(branch || "PREV")
        __merge(merge_branch, _curr_branch(), false, fastforward, delete, reuse)

      end

      def __merge(merge_branch, into_branch, switch, fastforward, delete, reuse)
        b = proc {|s| "'\e[1m#{s}\e[0m'" }   # bold font
        #msg = "Merge #{b.(merge_branch)} branch into #{b.(into_branch)}?"
        msg = switch \
            ? "Merge current branch #{b.(merge_branch)} into #{b.(into_branch)}." \
            : "Merge #{b.(merge_branch)} branch into #{b.(into_branch)}."
        if _confirm(msg + " OK?")
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
        old_branch = target || _curr_branch()
        git "branch", "-m", old_branch, new_branch
      end

      @action.("delete a branch")
      @option.(:force,  "-f, --force", "delete forcedly even if not merged")
      @option.(:remote, "-r, --remote[=origin]", "delete a remote branch")
      def delete(branch, force: false, remote: nil)
        if branch == nil
          branch = _curr_branch()
          yes = _confirm "Are you sure to delete current branch '#{branch}'?", default_yes: false
          return unless yes
          git "checkout", "-" unless remote
        else
          branch = _resolve_branch(branch)
        end
        if remote
          remote = "origin" if remote == true
          opts = force ? ["-f"] : []
          #git "push", *opts, remote, ":#{branch}"
          git "push", "--delete", *opts, remote, branch
        else
          opts = force ? ["-d"] : ["-D"]
          git "branch", *opts, branch
        end
      end

      @action.("rebase (move) current branch on top of other branch")
      @option.(:from, "--from=<commit-id>", "commit-id where current branch started")
      def rebase(branch_onto, branch_upstream=nil, from: nil)
        br_onto = _resolve_branch(branch_onto)
        if from
          git "rebase", "--onto=#{br_onto}", from+"^"
        elsif branch_upstream
          git "rebase", "--onto=#{br_onto}", _resolve_branch(branch_upstream)
        else
          git "rebase", br_onto
        end
      end

      @action.("git pull && git stash && git rebase && git stash pop")
      def update(branch=nil)
        git "pull"
        if _curr_branch() == GIT_CONFIG.initial_branch
          return
        end
        branch ||= _prev_branch()
        output = `git diff`
        changed = ! output.empty?
        git "stash", "push" if changed
        git "rebase", branch
        git "stash", "pop"  if changed
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
    define_alias("curr"    , "branch:current")
    define_alias("prev"    , "branch:previous")


    ##
    ## file:
    ##
    category "file:" do

      @action.("list (un)registered/ignored/missing files")
      @option.(:filtertype, "-F <filtertype>", "one of:", detail: <<~END)
                              - registered   : only registered files (default)
                              - unregistered : only not-registered files
                              - ignored      : ignored files by '.gitignore'
                              - missing      : registered but missing files
                            END
      @option.(:full, "--full", "show full list")
      def list(path=".", filtertype: "registered", full: false)
        method_name = "__file__list__#{filtertype}"
        respond_to?(method_name, true)  or (
          s = self.private_methods.grep(/^__file__list__(.*)/) { $1 }.join('/')
          raise option_error("#{filtertype}: Uknown filter type (expected: #{s}})")
        )
        __send__(method_name, path, full)
      end

      private

      def __file__list__registered(path, full)
        paths = path ? [path] : []
        git "ls-files", *paths
      end

      def __file__list__unregistered(path, full)
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
      @option.(:force, "-f, --force", "allow to register ignored files")
      @option.(:recursive, "-r, --recursive", "register files under directories")
      #@option.(:allow_empty_dir, "-e, --allow-empty-dir", "create '.gitkeep' to register empty directory")
      def register(file, *file2, force: false, recursive: false)
        files = [file] + file2
        files.each do |x|
          output = `git ls-files -- #{x}`
          output.empty?  or
            raise action_error("#{x}: Already registered.")
        end
        files.each do |x|
          if File.directory?(x)
            recursive  or
              raise action_error("#{x}: File expected, but is a directory (specify `-r` or `--recursive` otpion to register files under the directory).")
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

    end

    define_alias("files"    , "file:list")
    #define_alias("ls"       , "file:list")
    define_alias("register" , "file:register")
    define_alias("track"    , "file:register")
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
      #@option.(:update, "-u, --update", "add all changes of registered files")
      def add(path, *path2, pick: false) # , update: false
        paths = [path] + path2
        paths.each do |x|
          next if File.directory?(x)
          output = `git ls-files #{x}`
          ! output.strip.empty?  or
            raise action_error("#{x}: Not registered yet (run 'register' action instead).")
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
      def create(message=nil)
        opts = message ? ["-m", message] : []
        git "commit", *opts
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
      @option.(:mainline, "-m <N>", "parent number (necessary to revert merge commit)")
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
    define_alias("rollback", "commit:rollback")


    ##
    ## history:
    ##
    category "history:" do

      @action.("show commit history in various format")
      @option.(:all, "-a, --all"   , "show history of all branches")
      @option.(:format, "-F, --format=<format>", "default/compact/detailed/graph",
                        enum: ["default", "compact", "detailed", "graph"])
      @option.(:author, "-u, --author", "show author name before '@' of email address (only for graph format)")
      def show(*path, all: false, format: "default", author: false)
        opts = all ? ["--all"] : []
        case format
        when "default"
          nil
        when "compact"
          opts << "--oneline"
        when "detailed"
          opts << "--format=fuller"
        when "graph"
          fmt = GIT_CONFIG.history_graph_format
          fmt = fmt.sub(/ ?<?%a[eEnNlL]>? ?/, ' ') unless author
          opts << "--format=#{fmt}"
          opts.concat(GIT_CONFIG.history_graph_options)
        else
          raise "** assertion failed: format=#{format.inspect}"
        end
        ## use 'git!' to ignore pipe error when pager process quitted
        git! "log", *opts, *path
      end

      histopt = optionset {
        @option.(:all, "-a, --all"   , "show history of all branches")
      }

      def _show_hist(paths, all, opt)
        opts = [opt].flatten.compact()
        opts << "--all" if all
        ## use 'git!' to ignore pipe error when pager process quitted
        git! "log", *opts, *paths
      end

      @action.("show commit history in default format")
      @optionset.(histopt)
      def default(*path, all: false)
        _show_hist(path, all, nil)
      end

      @action.("show history in compact format")
      @optionset.(histopt)
      def compact(*path, all: false)
        _show_hist(path, all, "--oneline")
      end

      @action.("show commit history in detailed format")
      @optionset.(histopt)
      def detailed(*path, all: false)
        _show_hist(path, all, "--format=fuller")
      end

      @action.("show commit history with branch graph", important: true)
      @optionset.(histopt)
      @option.(:author, "-u, --author", "show author name before '@' of email address")
      def graph(*path, all: false, author: false)
        fmt = GIT_CONFIG.history_graph_format
        fmt = fmt.sub(/ ?<?%a[eEnNlL]>? ?/, ' ') unless author
        opts = ["--format=#{fmt}"] + GIT_CONFIG.history_graph_options
        _show_hist(path, all, opts)
      end

      @action.("show commits not uploaded yet")
      def notuploaded()
        git "cherry", "-v"
      end

      ## history:edit
      category "edit:" do

        @action.("start `git rebase -i` to edit commit history", important: true)
        @option.(:count  , "-n, --num=<N>", "edit last N commits")
        @option.(:stash, "-s, --stash", "store current changes into stash temporarily")
        def start(commit=nil, count: nil, stash: false)
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
          git "stash", "push" if stash
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

    define_alias "hist"      , "history:graph"
    define_alias "history"   , "history:default"
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
          user = _ask_to_user "User name:"
        end
        git "config", "user.name" , user   if user
        if email == nil && `git config --get user.email`.strip().empty?
          email = _ask_to_user "Email address:"
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
        url = _resolve_repository_url(url)
        args = dir ? [dir] : []
        git "clone", url, *args
        _config_user_and_email(user, email)
      end

      ## repo:remote:
      category "remote:" do

        @action.("list remote repositories")
        def list()
          git "remote", "--verbose"
        end

        @action.("set remote repo url ('github:<user>/<proj>' available")
        @option.(:name, "--name=<name>", "remote repository name (default: 'origin')")
        def seturl(url, name: "origin")
          url = _resolve_repository_url(url)
          remote_names = `git remote`.strip().split()
          if remote_names.include?(name)
            git "remote", "set-url", name, url
          else
            git "remote", "add", name, url
          end
        end

        @action.("delete remote repository")
        def delete(name=nil)
          if name == nil
            name = "origin"
            if $stdin.tty?
              q = "Are you sure to delete remote repo '\e[1m#{name}\e[0m'?"
              return unless _confirm(q)
            end
          end
          git "remote", "rm", name
        end

      end

    end


    ##
    ## tag:
    ##
    category "tag:" do

      @action.("list tags", important: true)
      @option.(:remote, "-r, --remote", "list remote tags")
      def list(remote: false)
        if remote
          #git "show-ref", "--tags"
          git "ls-remote", "--tags"
        else
          git "tag", "-l"
        end
      end

      @action.("create a new tag", important: true)
      @option.(:on, "--on=<commit>", "commit-id where new tag created on")
      def create(tag, on: nil)
        args = on ? [on] : []
        git "tag", tag, *args
      end

      @action.("delete a tag")
      @option.(:remote, "-r, --remote[=origin]", "delete from remote repository")
      def delete(tag, *tag2, remote: nil)
        tags = [tag] + tag2
        if remote
          remote = "origin" if remote == true
          tags.each do |tag|
            #git "push", "--delete", remote, tag     # may delete same name branch
            git "push", remote, ":refs/tags/#{tag}"  # delete a tag safely
          end
        else
          git "tag", "-d", *tags
        end
      end

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

      @action.("upload commits")
      @option.(:origin, "    --origin" , "set upstream to origin")
      @option.(:force , "-f, --force"  , "upload forcedly")
      def upload(origin: false, force: false)
        opts = force ? ["-f"] : []
        if origin
          git "push", *opts, "-u", "origin", _curr_branch()
        else
          git "push", *opts
        end
      end

      @action.("download commits from remote and apply them to local")
      @option.(:apply, "-N, --not-apply", "just download, not apply", value: false)
      def download(apply: true)
        if apply
          git "pull", "--prune"
        else
          git "fetch", "--prune"
        end
      end

      @action.("download and upload commits")
      def both()
        run_action "download"
        run_action "upload"
      end

    end

    define_alias("sync"     , "sync:both")
    define_alias("upload"   , "sync:upload")
    define_alias("up"       , "sync:upload")
    define_alias("download" , "sync:download")
    define_alias("dl"       , "sync:download")


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
      def push(*path, message: nil, pick: false)
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
                 "                # list config values",
                 "<key>           # get config value",
                 "<key> <value>   # set config value",
                 "<key> \"\"        # delete config value",
               ])
      @optionset.(optset)
      def handle(key=nil, value=nil, global: false, local: false)
        opts = _build_config_options(global, local)
        if key == nil                     # list
          git "config", *opts, "--list"
        elsif value == nil                # get
          #git "config", "--get", *opts, key
          git "config", *opts, key
        elsif value == ""                 # delete
          git "config", *opts, "--unset", key
        else                              # set
          git "config", *opts, key, value
        end
      end

      @action.("list config items")
      @optionset.(optset)
      def list(global: false, local: false)
        opts = _build_config_options(global, local)
        git "config", *opts, "--list"
      end

      @action.("show config value")
      @optionset.(optset)
      def get(key, global: false, local: false)
        opts = _build_config_options(global, local)
        #git "config", "--get", *opts, key
        git "config", *opts, key
      end

      @action.("set config value")
      @optionset.(optset)
      def set(key, value, global: false, local: false)
        opts = _build_config_options(global, local)
        git "config", *opts, key, value
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

      @action.("delete config item")
      @optionset.(optset)
      def delete(key, global: false, local: false)
        opts = _build_config_options(global, local)
        git "config", "--unset", *opts, key
      end

      @action.("list/get/set/delete aliases of 'git' (not of 'gi')", usage: [
                 "                 # list aliases",
                 "<name>           # get an alias",
                 "<name> <value>   # set an alias",
                 "<name> \"\"        # delete an alias",
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

      @action.("generate a setup file, or print to stdout if no args",
               usage: [
                 "<filename>     # generate a file",
                 "               # print to stdout",
               ])
      def setupfile(filename=nil)
        str = File.read(__FILE__, encoding: "utf-8")
        code = str.split(/^__END__\n/, 2)[1]
        code = code.gsub(/%SCRIPT%/, APP_CONFIG.app_command)
        code = code.gsub(/%ENVVAR_SETUP%/, ENVVAR_SETUP)
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

    def build_actions_part(*args, **kwargs)
      if @_omit_actions_part
        text ="  (Too long to show. Run `#{@config.app_command} -l` to list all actions.)"
        return build_section(_header(:HEADER_ACTIONS), text)
      else
        return super
      end
    end

  end


  def self.main(argv=ARGV)
    errmsg = _load_setup_file(ENV[ENVVAR_SETUP])
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
## This file is loaded by '%SCRIPT%' command only if $%ENVVAR_SETUP% is set,
## for example:
##
##     $ gi hello
##     [ERROR] hello: Action not found.
##
##     $ export %ENVVAR_SETUP%="~/.gi_setup.rb"
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

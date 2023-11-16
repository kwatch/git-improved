# -*- coding: utf-8 -*-
# frozen_string_literal: true


require_relative "shared"


Oktest.scope do


  topic GitImproved::GitAction do

    before_all do
      @pwd = Dir.pwd()
      @dir = "_repo#{rand().to_s[2..6]}"
      Dir.mkdir @dir
      Dir.chdir @dir
      system "git init -q -b main"                   , exception: true
      system "git config user.name user1"            , exception: true
      system "git config user.email user1@gmail.com" , exception: true
      system "git commit --allow-empty -q -m 'Initial commit (empty)'", exception: true
      $initial_commit_id = `git rev-parse HEAD`.strip()
    end

    after_all do
      Dir.chdir @pwd
      Benry::UnixCommand.echoback_off do
        Benry::UnixCommand.rm :rf, @dir
      end
    end

    before do
      system! "git checkout -q main"
    end


    topic 'branch:' do

      topic 'branch:checkout' do
        spec "create a new local branch from a remote branch" do
          ## TODO
          dryrun_mode do
            sout = main "branch:checkout", "remoterepo"
            ok {unesc(sout)} == <<~"END"
              [gi]$ git checkout -b remoterepo origin/remoterepo
            END
          end
        end
      end

      topic 'branch:create' do
        spec "create a new branch, not switch to it" do
          br = "br7625"
          capture_subprocess() do
            sout = main "branch:create", br
            ok {unesc(sout)} == <<~'END'
              [gi]$ git branch br7625
            END
          end
          ok {`git branch`} =~ /br7625/
          curr = curr_branch()
          ok {curr} != br
          ok {curr} == "main"
        end
      end

      topic 'branch:current' do
        spec "show current branch name" do
          output = capture_subprocess() do
            sout = main "branch:current"
            ok {unesc(sout)} == <<~'END'
              [gi]$ git rev-parse --abbrev-ref HEAD
            END
          end
          ok {output} == "main\n"
        end
      end

      topic 'branch:delete' do
        spec "delete a branch" do
          br = "br6993"
          system! "git branch #{br}"
          ok {`git branch`} =~ /#{br}/
          capture_subprocess() do
            sout = main "branch:delete", br
            ok {unesc(sout)} == <<~'END'
              [gi]$ git branch -D br6993
            END
          end
          ok {`git branch`} !~ /#{br}/
        end
      end

      topic 'branch:fork' do
        spec "create a new branch and switch to it" do
          br = "br2555"
          ok {curr_branch()} == "main"
          capture_subprocess() do
            sout = main "branch:fork", br
            ok {unesc(sout)} == <<~'END'
              [gi]$ git checkout -b br2555
            END
          end
          ok {curr_branch()} == br
        end
      end

      topic 'branch:join' do
        spec "merge current branch into previous or other branch" do
          br = "br0807"
          system! "git checkout -q -b #{br}"
          ok {curr_branch()} == br
          system! "git commit --allow-empty -q -m 'test'"
          capture_subprocess do
            sout = main "branch:join", stdin: "\n"
            ok {unesc(sout)} == <<~'END'
              Merge current branch 'br0807' into 'main'. OK? [Y/n]: [gi]$ git checkout main
              [gi]$ git merge --no-ff -
            END
          end
          ok {curr_branch()} == "main"
        end
      end

      topic 'branch:list' do
        spec "list branches" do
          output = capture_subprocess() do
            system! "git branch br1845x"
            system! "git branch br1845y"
            sout = main "branch:list"
            ok {unesc(sout)} == <<~'END'
              [gi]$ git branch -a
            END
          end
          ok {output} =~ /^\* main$/
          ok {output} =~ /^  br1845x$/
          ok {output} =~ /^  br1845y$/
        end
      end

      topic 'branch:merge' do
        spec "merge previous or other branch into current branch" do
          br = "br7231"
          system! "git branch -q #{br}"
          system! "git checkout -q #{br}"
          system! "git commit --allow-empty -q -m 'test commit on #{br}'"
          system! "git checkout -q main"
          capture_subprocess() do
            sout = main "branch:merge", stdin: "\n"
            ok {unesc(sout)} == <<~'END'
              Merge 'br7231' branch into 'main'. OK? [Y/n]: [gi]$ git merge --no-ff br7231
            END
          end
          ok {`git log -1 --oneline`} =~ /\A\h{7} Merge branch '#{br}'$/
          ok {`git log --oneline`} =~ /test commit on #{br}/
        end
      end

      topic 'branch:parent' do
        spec "show parent branch name (EXPERIMENTAL)" do
          br = "br6488"
          system! "git commit --allow-empty -q -m 'for #{br} #1'"
          system! "git checkout -q -b #{br}"
          system! "git commit --allow-empty -q -m 'for #{br} #2'"
          ok {curr_branch()} == br
          capture_subprocess() do
            sout = main "branch:parent"
            ok {unesc(sout)} == <<~'END'
              [gi]$ git show-branch -a | sed 's/].*//' | grep '\*' | grep -v "\\[$(git branch --show-current)\$" | head -n1 | sed 's/^.*\[//'
              main
            END
          end
          system! "git checkout -q -b #{br}x"
          ok {curr_branch()} == "#{br}x"
          capture_subprocess() do
            sout = main "branch:parent"
            ok {unesc(sout)} == <<~'END'
              [gi]$ git show-branch -a | sed 's/].*//' | grep '\*' | grep -v "\\[$(git branch --show-current)\$" | head -n1 | sed 's/^.*\[//'
              br6488
            END
          end
        end
      end

      topic 'branch:previous' do
        spec "show previous branch name" do
          br = "br0183"
          #
          system! "git checkout -q -b #{br}"
          output = capture_subprocess() do
            sout = main "branch:previous"
            ok {unesc(sout)} == <<~'END'
              [gi]$ git rev-parse --abbrev-ref "@{-1}"
            END
          end
          ok {output} == "main\n"
          #
          system! "git checkout -q -b #{br}xx"
          output = capture_subprocess() do
            sout = main "branch:previous"
            ok {unesc(sout)} == <<~'END'
              [gi]$ git rev-parse --abbrev-ref "@{-1}"
            END
          end
          ok {output} == "#{br}\n"
        end
      end

      topic 'branch:rebase' do
        before do
          _reset_all_commits()
        end
        def _prepare(base_branch)
          br = base_branch
          system! "git checkout -q -b #{br}dev"
          system! "git commit --allow-empty -q -m 'on #{br}dev #1'"
          system! "git commit --allow-empty -q -m 'on #{br}dev #2'"
          #
          system! "git checkout -q -b #{br}fix"
          system! "git commit --allow-empty -q -m 'on #{br}fix #3'"
          system! "git commit --allow-empty -q -m 'on #{br}fix #4'"
          #
          system! "git checkout -q #{br}dev"
          system! "git commit --allow-empty -q -m 'on #{br}dev #5'"
          system! "git commit --allow-empty -q -m 'on #{br}dev #6'"
          #
          system! "git checkout -q main"
          system! "git commit --allow-empty -q -m 'on main #7'"
          system! "git commit --allow-empty -q -m 'on main #8'"
        end
        spec "rebase (move) current branch on top of other branch" do
          br = "br7108"
          _prepare(br)
          #
          system! "git checkout -q #{br}dev"
          system! "git checkout -q #{br}fix"
          ok {`git log --oneline`} =~ partial_regexp(<<~"END")
            {==\\h{7}==} on #{br}fix #4
            {==\\h{7}==} on #{br}fix #3
            {==\\h{7}==} on #{br}dev #2
            {==\\h{7}==} on #{br}dev #1
            {==\\h{7}==} Initial commit (empty)
          END
          #
          output = capture_subprocess() do
            sout = main "branch:rebase", "-"
            ok {unesc(sout)} == <<~"END"
              [gi]$ git rebase #{br}dev
            END
          end
          ok {output}.end_with?("Successfully rebased and updated refs/heads/#{br}fix.\n")
          ok {`git log --oneline`} =~ partial_regexp(<<~"END")
            {==\\h{7}==} on #{br}fix #4
            {==\\h{7}==} on #{br}fix #3
            {==\\h{7}==} on #{br}dev #6
            {==\\h{7}==} on #{br}dev #5
            {==\\h{7}==} on #{br}dev #2
            {==\\h{7}==} on #{br}dev #1
            {==\\h{7}==} Initial commit (empty)
          END
        end
        spec "second arg represents upstream branch." do
          br = "br5419"
          _prepare(br)
          #
          system! "git checkout -q #{br}fix"
          ok {`git log --oneline`} =~ partial_regexp(<<~"END")
            {==\\h{7}==} on #{br}fix #4
            {==\\h{7}==} on #{br}fix #3
            {==\\h{7}==} on #{br}dev #2
            {==\\h{7}==} on #{br}dev #1
            {==\\h{7}==} Initial commit (empty)
          END
          #
          ok {curr_branch()} == "#{br}fix"
          output = capture_subprocess() do
            sout = main "branch:rebase", "main", "#{br}dev"
            ok {unesc(sout)} == <<~"END"
              [gi]$ git rebase --onto=main #{br}dev
            END
          end
          ok {output}.end_with?("Successfully rebased and updated refs/heads/#{br}fix.\n")
          ok {`git log --oneline`} =~ partial_regexp(<<~"END")
            {==\\h{7}==} on #{br}fix #4
            {==\\h{7}==} on #{br}fix #3
            {==\\h{7}==} on main #8
            {==\\h{7}==} on main #7
            {==\\h{7}==} Initial commit (empty)
          END
        end
        spec "option '--from' specifies commit-id to start." do
          br = "br3886"
          _prepare(br)
          #
          system! "git checkout -q #{br}dev"
          ok {`git log --oneline`} =~ partial_regexp(<<~"END")
            {==\\h{7}==} on #{br}dev #6
            {==\\h{7}==} on #{br}dev #5
            {==\\h{7}==} on #{br}dev #2
            {==\\h{7}==} on #{br}dev #1
            {==\\h{7}==} Initial commit (empty)
          END
          `git log --oneline` =~ /^(\h+) on #{br}dev #2/
          commit_id = $1
          ok {commit_id} != nil
          #
          output = capture_subprocess() do
            sout = main "branch:rebase", "-", "--from=#{commit_id}"
            ok {unesc(sout)} == <<~"END"
              [gi]$ git rebase --onto=main #{commit_id}^
            END
          end
          ok {output}.end_with?("Successfully rebased and updated refs/heads/br3886dev.\n")
          ok {`git log --oneline`} =~ partial_regexp(<<~"END")
            {==\\h{7}==} on #{br}dev #6
            {==\\h{7}==} on #{br}dev #5
            {==\\h{7}==} on #{br}dev #2
            {==\\h{7}==} on main #8
            {==\\h{7}==} on main #7
            {==\\h{7}==} Initial commit (empty)
          END
        end
      end

      topic 'branch:rename' do
        spec "rename the current branch to other name" do
          br = "br4571"
          system! "git checkout -q -b #{br}"
          ok {curr_branch()} == br
          output = capture_subprocess() do
            sout = main "branch:rename", "#{br}fix"
            ok {unesc(sout)} == <<~'END'
              [gi]$ git branch -m br4571 br4571fix
            END
          end
          ok {output} == ""
          ok {curr_branch()} == "#{br}fix"
        end
      end

      topic 'branch:switch' do
        spec "switch to previous or other branch" do
          br = "br3413"
          system! "git branch -q #{br}"
          ok {curr_branch()} == "main"
          #
          output = capture_subprocess() do
            sout = main "branch:switch", br
            ok {unesc(sout)} == <<~"END"
              [gi]$ git checkout #{br}
            END
          end
          ok {output} == "Switched to branch '#{br}'\n"
          ok {curr_branch()} == br
          #
          output = capture_subprocess() do
            sout = main "branch:switch"
            ok {unesc(sout)} == <<~"END"
              [gi]$ git checkout -
            END
          end
          ok {output} == "Switched to branch 'main'\n"
          ok {curr_branch()} == "main"
        end
      end

      topic 'branch:update' do
        spec "git pull && git stash && git rebase && git stash pop" do
          ## TODO
          dryrun_mode do
            sout = main "branch:update"
            ok {unesc(sout)} == "[gi]$ git pull\n"
          end
        end
      end

    end


    topic 'commit:' do

      topic 'commit:apply' do
        before do
          _reset_all_commits()
        end
        spec "apply a commit to curr branch (known as 'cherry-pick')" do
          br = "br7479"
          file = "file2214.txt"
          dummy_file(file, "A\nB\nC\nD\nE\n")
          system! "git add #{file}"
          system! "git commit -q -m 'add #{file}'"
          system! "git checkout -q -b #{br}"
          writefile(file, "A\nB\nC\nD\nE\nF\n")    # append F
          system! "git add -u ."
          system! "git commit -q -m 'append F'"
          writefile(file, "A\nB\nT\nD\nE\nF\n")    # replace C with T
          system! "git add -u ."
          system! "git commit -q -m 'replace C with T'"
          commit_id = `git rev-parse HEAD`[0..6]
          writefile(file, "A\nB\nT\nD\nE\nF\nG\n") # append G
          system! "git add -u ."
          system! "git commit -q -m 'append G'"
          #
          system! "git checkout -q main"
          output = capture_subprocess() do
            sout = main "commit:apply", commit_id
            ok {unesc(sout)} == <<~"END"
              [gi]$ git cherry-pick #{commit_id}
            END
          end
          ok {`git log --oneline`} =~ partial_regexp(<<~"END")
            {==\\h{7}==} replace C with T
            {==\\h{7}==} add #{file}
            {==\\h{7}==} Initial commit (empty)
          END
          ok {readfile(file)} == "A\nB\nT\nD\nE\n"  # C is replaced with T
        end
      end

      topic 'commit:correct' do
        before do
          _reset_all_commits()
        end
        spec "correct the last commit" do
          file = "file4043.txt"
          dummy_file(file, "A\nB\n")
          system! "git add #{file}"
          system! "git commit -q -m 'add #{file}'"
          #
          writefile(file, "A\nB\nC\n")
          system! "git add -u ."
          commit_id = `git rev-parse HEAD`
          output = capture_subprocess() do
            sout = main "commit:correct", "-M"
            ok {unesc(sout)} == <<~"END"
              [gi]$ git commit --amend --no-edit
            END
          end
          ok {output} =~ /^ 1 file changed, 3 insertions\(\+\)$/
          ok {`git rev-parse HEAD`} != commit_id
          ok {`git log -1 --oneline`} =~ /\A\h{7} add #{file}\n\z/
        end
      end

      topic 'commit:create' do
        spec "create a new commit" do
          file = "file9247.txt"
          dummy_file(file, "A\nB\n")
          system! "git add #{file}"
          output = capture_subprocess() do
            sout = main "commit:create", "add '#{file}'"
            ok {unesc(sout)} == <<~"END"
              [gi]$ git commit -m "add '#{file}'"
            END
          end
          ok {output} =~ /^ 1 file changed, 2 insertions\(\+\)$/
          ok {`git log -1 --oneline`} =~ /\A\h{7} add '#{file}'\n\z/
        end
      end

      topic 'commit:fixup' do
        spec "correct the previous commit" do
          file = "file4150"
          file1 = file + "xx"
          file2 = file + "yy"
          #
          dummy_file(file1, "A\nB\n")
          system! "git add #{file1}"
          system! "git commit -q -m \"add '#{file1}'\""
          commit_id = `git rev-parse HEAD`[0..6]
          #
          dummy_file(file2, "X\nY\n")
          system! "git add #{file2}"
          system! "git commit -q -m \"add '#{file2}'\""
          #
          writefile(file1, "A\nB\nC\n")
          system! "git add #{file1}"
          output = capture_subprocess() do
            sout = main "commit:fixup", commit_id
            ok {unesc(sout)} == <<~"END"
              [gi]$ git commit --fixup=#{commit_id}
            END
          end
          ok {output} =~ /\[main \h{7}\] fixup! add '#{file1}'/
          ok {`git log -3 --oneline`} =~ partial_regexp(<<~"END")
            {==\\h{7}==} fixup! add '#{file1}'
            {==\\h{7}==} add '#{file2}'
            {==\\h{7}==} add '#{file1}'
          END
        end
      end

      topic 'commit:revert' do
        def _prepare(file1, file2)
          dummy_file(file1, "A\nB\n")
          system! "git add #{file1}"
          system! "git commit -q -m \"add '#{file1}'\""
          #
          dummy_file(file2, "X\nY\n")
          system! "git add #{file2}"
          system! "git commit -q -m \"add '#{file2}'\""
        end
        spec "create a new commit which reverts the target commit" do
          file = "file3518"
          file1 = file + "xx"
          file2 = file + "yy"
          _prepare(file1, file2)
          commit_id = `git rev-parse HEAD^`[0..6]
          #
          output = capture_subprocess() do
            sout = main "commit:revert", commit_id, "-M"
            ok {unesc(sout)} == <<~"END"
              [gi]$ git revert --no-edit #{commit_id}
            END
          end
          ok {output} =~ /\A\[main \h{7}\] Revert "add '#{file1}'"$/
          ok {`git log -3 --oneline`} =~ partial_regexp(<<~"END")
            {==\\h{7}==} Revert "add '#{file1}'"
            {==\\h{7}==} add '#{file2}'
            {==\\h{7}==} add '#{file1}'
          END
        end
      end

      topic 'commit:rollback' do
        def _prepare(file)
          dummy_file(file, "A\n")
          system! "git add #{file}"
          system! "git commit -q -m 'add #{file}'"
          #
          writefile(file, "A\nB\n")
          system! "git add #{file}"
          system! "git commit -q -m 'append B'"
          #
          writefile(file, "A\nB\nC\n")
          system! "git add #{file}"
          system! "git commit -q -m 'append C'"
          #
          writefile(file, "A\nB\nC\nD\n")
          system! "git add #{file}"
          system! "git commit -q -m 'append D'"
        end
        spec "cancel recent commits up to the target commit-id" do
          file = "file0710.txt"
          _prepare(file)
          #
          ok {`git log -4 --oneline`} =~ partial_regexp(<<~"END")
            {==\\h{7}==} append D
            {==\\h{7}==} append C
            {==\\h{7}==} append B
            {==\\h{7}==} add #{file}
          END
          #
          output = capture_subprocess() do
            sout = main "commit:rollback", "-n2"
            ok {unesc(sout)} == <<~"END"
              [gi]$ git reset "HEAD~2"
            END
          end
          ok {output} =~ /^M\t#{file}$/
          ok {`git log -2 --oneline`} =~ partial_regexp(<<~"END")
            {==\\h{7}==} append B
            {==\\h{7}==} add #{file}
          END
          #
          output = capture_subprocess() do
            sout = main "commit:rollback"
            ok {unesc(sout)} == <<~"END"
              [gi]$ git reset HEAD^
            END
          end
          ok {output} =~ /^M\t#{file}$/
          ok {`git log -1 --oneline`} =~ partial_regexp(<<~"END")
            {==\\h{7}==} add #{file}
          END
        end
      end

      topic 'commit:show' do
        def _prepare(file)
          dummy_file(file, "A\n")
          system! "git add #{file}"
          system! "git commit -q -m 'add #{file}'"
          #
          writefile(file, "A\nB\n")
          system! "git add #{file}"
          system! "git commit -q -m 'append B'"
          #
          writefile(file, "A\nB\nC\n")
          system! "git add #{file}"
          system! "git commit -q -m 'append C'"
          #
          writefile(file, "A\nB\nC\nD\n")
          system! "git add #{file}"
          system! "git commit -q -m 'append D'"
        end
        spec "show commits in current branch" do
          file = "file2610.tmp"
          _prepare(file)
          commit_id = `git rev-parse HEAD^^`.strip()[0..6]
          output = capture_subprocess() do
            sout = main "commit:show", "-n1", commit_id
            ok {unesc(sout)} == <<~"END"
              [gi]$ git show "#{commit_id}~1..#{commit_id}"
            END
          end
          ok {output} =~ partial_regexp(<<~"END")
            commit {==\\h{40}==}
            Author: user1 <user1@gmail.com>
            Date:   {==.*==}
            
                append B
            
            diff --git a/#{file} b/#{file}
            index {==\\h{7}==}..{==\\h{7}==} {==\\d+==}
            --- a/#{file}
            +++ b/#{file}
            @@ -1 +1,2 @@
             A
            +B
          END
        end
        spec "option '-n <N>' specifies the number of commits." do
          file = "file9485.txt"
          _prepare(file)
          #
          output = capture_subprocess() do
            sout = main "commit:show", "-n1"
            ok {unesc(sout)} == <<~"END"
              [gi]$ git show "HEAD~1..HEAD"
            END
          end
          ok {output} =~ partial_regexp(<<~"END")
            commit {==\\h{40}==}
            Author: user1 <user1@gmail.com>
            Date:   {==.*==}
            
                append D
            
            diff --git a/#{file} b/#{file}
            index {==\\h{7}==}..{==\\h{7}==} {==\\d+==}
            --- a/#{file}
            +++ b/#{file}
            @@ -1,3 +1,4 @@
             A
             B
             C
            +D
          END
          #
          output = capture_subprocess() do
            sout = main "commit:show", "-n2"
            ok {unesc(sout)} == <<~"END"
              [gi]$ git show "HEAD~2..HEAD"
            END
          end
          ok {output} =~ partial_regexp(<<~"END")
            commit {==\\h{40}==}
            Author: user1 <user1@gmail.com>
            Date:   {==.*==}
            
                append D
            
            diff --git a/#{file} b/#{file}
            index {==\\h{7}==}..{==\\h{7}==} {==\\d+==}
            --- a/#{file}
            +++ b/#{file}
            @@ -1,3 +1,4 @@
             A
             B
             C
            +D

            commit {==\\h{40}==}
            Author: user1 <user1@gmail.com>
            Date:   {==.*==}
            
                append C
            
            diff --git a/#{file} b/#{file}
            index {==\\h{7}==}..{==\\h{7}==} {==\\d+==}
            --- a/#{file}
            +++ b/#{file}
            @@ -1,2 +1,3 @@
             A
             B
            +C
          END
        end
      end

    end


    topic 'config:' do

      topic 'config' do
        spec "list/get/set/delete config values" do
          at_end { system! "git config user.name user1" }
          ## list
          output = capture_subprocess() do
            sout = main "config"
            ok {unesc(sout)} == <<~'END'
              [gi]$ git config --list
            END
          end
          ok {output} =~ /^user\.name=user1$/
          ok {output} =~ /^user\.email=user1@gmail\.com$/
          ## get
          output = capture_subprocess() do
            sout = main "config", "user.name"
            ok {unesc(sout)} == <<~'END'
              [gi]$ git config user.name
            END
          end
          ok {output} == "user1\n"
          ## set
          output = capture_subprocess() do
            sout = main "config", "user.name", "user2"
            ok {unesc(sout)} == <<~'END'
              [gi]$ git config user.name user2
            END
          end
          ok {output} == ""
          ok {`git config --get user.name`} == "user2\n"
          ## delete
          output = capture_subprocess() do
            sout = main "config", "user.name", ""
            ok {unesc(sout)} == <<~'END'
              [gi]$ git config --unset user.name
            END
          end
          ok {output} == ""
          ok {`git config --local --get user.name`} == ""
        end
      end

      topic 'config:alias' do
        spec "list/get/set/delete aliases of 'git' (not of 'gi')" do
          ## list
          output = capture_subprocess() do
            sout = main "config:alias"
            ok {unesc(sout)}.start_with?(<<~'END')
              [gi]$ git config --get-regexp '^alias\.' | sed -e 's/^alias\.//;s/ /\t= /'
            END
            lines = unesc(sout).each_line().to_a()
            lines.shift()
            ok {lines}.all? {|line| line =~ /^\S+\t= .*/ }
          end
          ok {output} == ""
          ## set
          output = capture_subprocess() do
            sout = main "config:alias", "br", "checkout -b"
            ok {unesc(sout)} == <<~'END'
              [gi]$ git config --global alias.br "checkout -b"
            END
          end
          ok {output} == ""
          ## get
          output = capture_subprocess() do
            sout = main "config:alias", "br"
            ok {unesc(sout)} == <<~'END'
              [gi]$ git config --global alias.br
            END
          end
          ok {output} == "checkout -b\n"
          ## delete
          ok {`git config --get alias.br`} == "checkout -b\n"
          ok {`git config --list`} =~ /^alias\.br=/
          output = capture_subprocess() do
            sout = main "config:alias", "br", ""
            ok {unesc(sout)} == <<~'END'
              [gi]$ git config --global --unset alias.br
            END
          end
          ok {output} == ""
          ok {`git config --get alias.br`} == ""
          ok {`git config --list`} !~ /^alias\.br=/
        end
      end

      topic 'config:delete' do
        spec "delete config item" do
          at_end { system! "git config user.email user1@gmail.com" }
          ok {`git config --local --list`} =~ /^user\.email=/
          output = capture_subprocess() do
            sout = main "config:delete", "user.email"
            ok {unesc(sout)}.start_with?(<<~'END')
              [gi]$ git config --unset user.email
            END
          end
          ok {output} == ""
          ok {`git config --local --get user.email`} == ""
          ok {`git config --local --list`} !~ /^user\.email=/
        end
      end

      topic 'config:get' do
        spec "show config value" do
          output = capture_subprocess() do
            sout = main "config:get", "user.email"
            ok {unesc(sout)}.start_with?(<<~'END')
              [gi]$ git config user.email
            END
          end
          ok {output} == "user1@gmail.com\n"
        end
      end

      topic 'config:list' do
        spec "list config items" do
          output = capture_subprocess() do
            sout = main "config:list"
            ok {unesc(sout)}.start_with?(<<~'END')
              [gi]$ git config --list
            END
          end
          lines = output.each_line.to_a()
          ok {lines}.all? {|line| line =~ /^\S+=.*/ }
        end
      end

      topic 'config:set' do
        spec "set config value" do
          at_end { system! "git config user.name user1" }
          output = capture_subprocess() do
            sout = main "config:set", "user.name", "user5"
            ok {unesc(sout)}.start_with?(<<~'END')
              [gi]$ git config user.name user5
            END
          end
          ok {output} == ""
          ok {`git config --get user.name`} == "user5\n"
        end
      end

      topic 'config:setuser' do
        spec "set user name and email" do
          at_end {
            system! "git config user.name user1"
            system! "git config user.email user1@gmail.com"
          }
          ## user and email
          output = capture_subprocess() do
            sout = main "config:setuser", "user6", "user6@gmail.com"
            ok {unesc(sout)}.start_with?(<<~'END')
              [gi]$ git config user.name user6
              [gi]$ git config user.email user6@gmail.com
            END
          end
          ok {output} == ""
          ok {`git config --get user.name`} == "user6\n"
          ok {`git config --get user.email`} == "user6@gmail.com\n"
          ## user
          output = capture_subprocess() do
            sout = main "config:setuser", "user7"
            ok {unesc(sout)}.start_with?(<<~'END')
              [gi]$ git config user.name user7
            END
          end
          ok {output} == ""
          ok {`git config --get user.name`} == "user7\n"
          ok {`git config --get user.email`} == "user6@gmail.com\n"
          ## email
          output = capture_subprocess() do
            sout = main "config:setuser", "user8@gmail.com"
            ok {unesc(sout)}.start_with?(<<~'END')
              [gi]$ git config user.email user8@gmail.com
            END
          end
          ok {output} == ""
          ok {`git config --get user.name`} == "user7\n"
          ok {`git config --get user.email`} == "user8@gmail.com\n"
          ## '-'
          output = capture_subprocess() do
            sout = main "config:setuser", "-", "user9@gmail.com"
            ok {unesc(sout)}.start_with?(<<~'END')
              [gi]$ git config user.email user9@gmail.com
            END
          end
          ok {output} == ""
          ok {`git config --get user.name`} == "user7\n"
          ok {`git config --get user.email`} == "user9@gmail.com\n"
        end
      end

    end


    topic 'file:' do

      topic 'file:changes' do
        before do
          system! "git reset -q --hard"
        end
        spec "show changes of files" do
          file = "file1569.tmp"
          dummy_file(file, "A\n")
          system! "git add #{file}"
          system! "git commit -q -m 'add #{file}'"
          writefile(file, "A\nB\n")
          output = capture_subprocess() do
            sout = main "file:changes"
            ok {unesc(sout)} == <<~"END"
              [gi]$ git diff
            END
          end
          ok {output} =~ partial_regexp(<<~"END")
            diff --git a/#{file} b/#{file}
            index {==\\h{7}==}..{==\\h{7}==} {==\\d+==}
            --- a/#{file}
            +++ b/#{file}
            @@ -1 +1,2 @@
             A
            +B
          END
        end
      end

      topic 'file:delete' do
        spec "delete files or directories" do
          file = "file7807.tmp"
          dummy_file(file, "A\n")
          system! "git add #{file}"
          system! "git commit -q -m 'add #{file}'"
          ok {file}.file_exist?
          output = capture_subprocess() do
            sout = main "file:delete", file
            ok {unesc(sout)} == <<~"END"
              [gi]$ git rm #{file}
            END
          end
          ok {output} == "rm 'file7807.tmp'\n"
          ok {file}.not_exist?
        end
      end

      topic 'file:list' do
        before do
          _reset_all_commits()
        end
        spec "list (un)registered/ignored/missing files" do
          file1 = "file1154.txt"
          file2 = "file1154.css"
          file3 = "file1154.json"
          file4 = "file1154.json~"
          dummy_file(file1, "A\n")
          dummy_file(file2, "B\n")
          dummy_file(file3, "C\n")
          dummy_file(file4, "C\n")
          system! "git add #{file1}"
          system! "git add #{file2}"
          system! "git commit -q -m 'add #{file1} and #{file2}'"
          writefile(".gitignore", "*~\n")
          at_end { rm_rf ".gitignore" }
          ## registered
          output = capture_subprocess() do
            sout = main "file:list"
            ok {unesc(sout)} == "[gi]$ git ls-files .\n"
          end
          ok {output} == <<~'END'
            file1154.css
            file1154.txt
          END
          ## unregistered
          output = capture_subprocess() do
            sout = main "file:list", "-F", "unregistered"
            ok {unesc(sout)} == <<~'END'
              [gi]$ git status -s . | grep '^?? '
              ?? .gitignore
              ?? file1154.json
            END
          end
          ok {output} == ""
          ## ignored
          output = capture_subprocess() do
            sout = main "file:list", "-F", "ignored"
            ok {unesc(sout)} == <<~'END'
              [gi]$ git status -s --ignored . | grep '^!! '
              !! file1154.json~
            END
          end
          ok {output} == ""
          ## missing
          File.unlink(file1)
          output = capture_subprocess() do
            sout = main "file:list", "-F", "missing"
            ok {unesc(sout)} == <<~'END'
              [gi]$ git ls-files --deleted .
            END
          end
          ok {output} == <<~"END"
            file1154.txt
          END
        end
      end

      topic 'file:move' do
        spec "move files into a directory" do
          file1 = "file3304.css"
          file2 = "file3304.js"
          file3 = "file3304.html"
          dir   = "file3304.d"
          dummy_file(file1, "A\n")
          dummy_file(file2, "B\n")
          dummy_file(file3, "C\n")
          dummy_dir(dir)
          system! "git add #{file1} #{file2} #{file3}"
          system! "git commit -q -m 'add #{file1}, #{file2} and #{file3}'"
          #
          output = capture_subprocess() do
            sout = main "file:move", file1, file3, "--to=#{dir}"
            ok {unesc(sout)} == "[gi]$ git mv #{file1} #{file3} #{dir}\n"
          end
          ok {output} == ""
          ok {file1}.not_exist?
          ok {file2}.file_exist?
          ok {file3}.not_exist?
        end
      end

      topic 'file:register' do
        spec "register files into the repository" do
          file = "file2717.tmp"
          dummy_file(file, "A\n")
          #
          ok {`git ls-files .`} !~ /^#{file}$/
          output = capture_subprocess() do
            sout = main "file:register", file
            ok {unesc(sout)} == "[gi]$ git add #{file}\n"
          end
          ok {output} == ""
          ok {`git ls-files .`} =~ /^#{file}$/
        end
      end

      topic 'file:rename' do
        spec "rename a file or directory to new name" do
          file = "file3365.tmp"
          dummy_file(file, "A\n")
          system! "git add #{file}"
          system! "git commit -q -m 'add #{file}'"
          #
          ok {file}.file_exist?
          ok {file+".bkup"}.not_exist?
          output = capture_subprocess() do
            sout = main "file:rename", file, file+".bkup"
            ok {unesc(sout)} == "[gi]$ git mv #{file} #{file}.bkup\n"
          end
          ok {output} == ""
          ok {file}.not_exist?
          ok {file+".bkup"}.file_exist?
        end
      end

      topic 'file:restore' do
        before do
          system! "git reset -q --hard HEAD"
        end
        spec "restore files (= clear changes)" do
          file = "file2908.txt"
          dummy_file(file, "A\n")
          system! "git add #{file}"
          system! "git commit -q -m 'add #{file}'"
          writefile(file, "A\nB\n")
          ok {`git diff`} =~ partial_regexp(<<~"END")
            diff --git a/file2908.txt b/file2908.txt
            index {==\\h{7}==}..{==\\h{7}==} {==\\d+==}
            --- a/file2908.txt
            +++ b/file2908.txt
            @@ -1 +1,2 @@
             A
            +B
          END
          #
          output = capture_subprocess() do
            sout = main "file:restore"
            ok {unesc(sout)} == "[gi]$ git reset --hard\n"
          end
          ok {output} =~ partial_regexp(<<~"END")
            HEAD is now at {==\\h{7}==} add #{file}
          END
          ok {`git diff`} == ""
        end
      end

    end


    topic 'help' do
      spec "print help message (of action if specified)" do
        sout = main "help"
        ok {sout} == <<~"END"
\e[1mgi\e[0m \e[2m(0.0.0)\e[0m --- Git Improved

\e[1;34mUsage:\e[0m
  $ \e[1mgi\e[0m [<options>] <action> [<arguments>...]

\e[1;34mOptions:\e[0m
  -h, --help          : print help message (of action if specified)
  -V, --version       : print version
  -l, --list          : list actions and aliases
  -L <topic>          : list of a topic (action|alias|category|abbrev)
  -a, --all           : list hidden actions/options, too
  -q, --quiet         : quiet mode
  --color[=<on|off>]  : color mode
  -X, --dryrun        : dry-run mode (not run; just echoback)

\e[1;34mActions:\e[0m
  (Too long to show. Run `gi -l` to list all actions.)

\e[1;34mExample:\e[0m
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

\e[1;34mDocument:\e[0m
  https://kwatch.github.io/git-improved/
END
      end
      spec "prints help message of action if action name specified." do
        sout = main "help", "config"
        ok {sout} == <<~"END"
\e[1mgi config\e[0m --- list/get/set/delete config values

\e[1;34mUsage:\e[0m
  $ \e[1mgi config\e[0m [<options>]                 # list config values
  $ \e[1mgi config\e[0m [<options>] <key>           # get config value
  $ \e[1mgi config\e[0m [<options>] <key> <value>   # set config value
  $ \e[1mgi config\e[0m [<options>] <key> ""        # delete config value

\e[1;34mOptions:\e[0m
  -g, --global        : handle global config
  -l, --local         : handle repository local config
END
      end
    end


    topic 'history:' do

      def _prepare(basefile)
        file1 = "#{basefile}.rb"
        file2 = "#{basefile}.py"
        dummy_file(file1, "A\n")
        dummy_file(file2, "B\n")
        system! "git add #{file1}"
        system! "git commit -q -m 'add #{file1}'"
        system! "git add #{file2}"
        system! "git commit -q -m 'add #{file2}'"
        return file1, file2
      end

      topic 'history:compact' do
        before do
          _reset_all_commits()
        end
        spec "show history in compact format" do
          file1, file2 = _prepare("file5624")
          output = capture_subprocess() do
            sout = main "history:compact"
            ok {unesc(sout)} == "[gi]$ git log --oneline\n"
          end
          ok {output} =~ partial_regexp(<<~"END")
            {==\\h{7}==} add #{file2}
            {==\\h{7}==} add #{file1}
            {==\\h{7}==} Initial commit (empty)
          END
        end
      end

      topic 'history:default' do
        before do
          _reset_all_commits()
        end
        spec "show commit history in default format" do
          file1, file2 = _prepare("file8460")
          output = capture_subprocess() do
            sout = main "history:default"
            ok {unesc(sout)} == "[gi]$ git log\n"
          end
          ok {output} =~ partial_regexp(<<~"END")
            commit {==\\h{40}==}
            Author: user1 <user1@gmail.com>
            Date:   {==.*==}
            
                add #{file2}
            
            commit {==\\h{40}==}
            Author: user1 <user1@gmail.com>
            Date:   {==.*==}
            
                add #{file1}
            
            commit {==\\h{40}==}
            Author: user1 <user1@gmail.com>
            Date:   {==.*==}
            
                Initial commit (empty)
          END
        end
      end

      topic 'history:detailed' do
        before do
          _reset_all_commits()
        end
        spec "show commit history in detailed format" do
          file1, file2 = _prepare("file0632")
          output = capture_subprocess() do
            sout = main "history:detailed"
            ok {unesc(sout)} == "[gi]$ git log --format=fuller\n"
          end
          ok {output} =~ partial_regexp(<<~"END")
            commit {==\\h{40}==}
            Author:     user1 <user1@gmail.com>
            AuthorDate: {==.*==}
            Commit:     user1 <user1@gmail.com>
            CommitDate: {==.*==}
            
                add #{file2}
            
            commit {==\\h{40}==}
            Author:     user1 <user1@gmail.com>
            AuthorDate: {==.*==}
            Commit:     user1 <user1@gmail.com>
            CommitDate: {==.*==}
            
                add #{file1}
            
            commit {==\\h{40}==}
            Author:     user1 <user1@gmail.com>
            AuthorDate: {==.*==}
            Commit:     user1 <user1@gmail.com>
            CommitDate: {==.*==}
            
                Initial commit (empty)
          END
        end
      end

      topic 'history:edit:cancel' do
        spec "cancel (or abort) `git rebase -i`" do
          ## TODO
          dryrun_mode do
            sout = main "history:edit:cancel"
            ok {unesc(sout)} == "[gi]$ git rebase --abort\n"
          end
        end
      end

      topic 'history:edit:resume' do
        spec "resume (= conitnue) suspended `git rebase -i`" do
          ## TODO
          dryrun_mode do
            sout = main "history:edit:resume"
            ok {unesc(sout)} == "[gi]$ git rebase --continue\n"
          end
        end
      end

      topic 'history:edit:skip' do
        spec "skip current commit and resume" do
          ## TODO
          dryrun_mode do
            sout = main "history:edit:skip"
            ok {unesc(sout)} == "[gi]$ git rebase --skip\n"
          end
        end
      end

      topic 'history:edit:start' do
        spec "start `git rebase -i` to edit commit history", tag: "curr" do
          ## TODO
          dryrun_mode do
            sout = main "history:edit:start", "-n2"
            ok {unesc(sout)} == "[gi]$ git rebase -i --autosquash \"HEAD~2\"\n"
          end
        end
      end

      topic 'history:graph' do
        before do
          _reset_all_commits()
        end
        spec "show commit history with branch graph", tag: "curr" do
          file1, file2 = _prepare("file6071")
          output = capture_subprocess() do
            sout = main "history:graph"
            ok {unesc(sout)} == <<~"END"
              [gi]$ git log --format="%C(auto)%h %ad | %d %s" --graph --date=short --decorate
            END
          end
          today = Time.now.strftime("%Y-%m-%d")
          ok {output} =~ partial_regexp(<<~"END")
            * {==\\h{7}==} #{today} |  (HEAD -> main) add #{file2}
            * {==\\h{7}==} #{today} |  add #{file1}
            * {==\\h{7}==} #{today} |  {==(?:\(.*?\) )?==}Initial commit (empty)
          END
        end
      end

      topic 'history:notuploaded' do
        spec "show commits not uploaded yet" do
          ## TODO
          dryrun_mode do
            sout = main "history:notuploaded"
            ok {unesc(sout)} == <<~"END"
              [gi]$ git cherry -v
            END
          end
        end
      end

      topic 'history:show' do
        before do
          _reset_all_commits()
        end
        spec "show commit history in various format" do
          file1, file2 = _prepare("file2146")
          ## compact
          output = capture_subprocess() do
            sout = main "history:show", "-F", "compact"
            ok {unesc(sout)} == "[gi]$ git log --oneline\n"
          end
          ok {output} =~ partial_regexp(<<~"END")
            {==\\h{7}==} add #{file2}
            {==\\h{7}==} add #{file1}
            {==\\h{7}==} Initial commit (empty)
          END
          ## default
          output = capture_subprocess() do
            sout = main "history:show"
            ok {unesc(sout)} == <<~"END"
              [gi]$ git log
            END
          end
          ok {output} =~ partial_regexp(<<~"END")
            commit {==\\h{40}==}
            Author: user1 <user1@gmail.com>
            Date:   {==.*==}
            
                add #{file2}
            
            commit {==\\h{40}==}
            Author: user1 <user1@gmail.com>
            Date:   {==.*==}
            
                add #{file1}
            
            commit {==\\h{40}==}
            Author: user1 <user1@gmail.com>
            Date:   {==.*==}
            
                Initial commit (empty)
          END
          ## detailed
          output = capture_subprocess() do
            sout = main "history:show", "-F", "detailed"
            ok {unesc(sout)} == "[gi]$ git log --format=fuller\n"
          end
          ok {output} =~ partial_regexp(<<~"END")
            commit {==\\h{40}==}
            Author:     user1 <user1@gmail.com>
            AuthorDate: {==.*==}
            Commit:     user1 <user1@gmail.com>
            CommitDate: {==.*==}
            
                add #{file2}
            
            commit {==\\h{40}==}
            Author:     user1 <user1@gmail.com>
            AuthorDate: {==.*==}
            Commit:     user1 <user1@gmail.com>
            CommitDate: {==.*==}
            
                add #{file1}
            
            commit {==\\h{40}==}
            Author:     user1 <user1@gmail.com>
            AuthorDate: {==.*==}
            Commit:     user1 <user1@gmail.com>
            CommitDate: {==.*==}
            
                Initial commit (empty)
          END
          ## graph
          output = capture_subprocess() do
            sout = main "history:show", "-F", "graph"
            ok {unesc(sout)} == <<~"END"
              [gi]$ git log --format="%C(auto)%h %ad | %d %s" --graph --date=short --decorate
            END
          end
          today = Time.now.strftime("%Y-%m-%d")
          ok {output} =~ partial_regexp(<<~"END")
            * {==\\h{7}==} #{today} |  (HEAD -> main) add #{file2}
            * {==\\h{7}==} #{today} |  add #{file1}
            * {==\\h{7}==} #{today} |  {==(?:\(.*?\) )?==}Initial commit (empty)
          END
        end
      end

    end


    topic 'misc:' do

      topic 'misc:setupfile' do
        spec "generate a setup file" do
          file = "file1533.rb"
          at_end { rm_rf file }
          ok {file}.not_exist?
          sout = main "misc:setupfile", file
          ok {sout} == "[OK] file1533.rb generated.\n"
          ok {file}.file_exist?
          ok {readfile(file)} =~ /def hello\(name="world", lang: "en"\)/
          ok {`ruby -wc #{file}`} == "Syntax OK\n"
        end
        spec "print to stdout if no args" do
          [[], ["-"]].each do |args|
            sout = main "misc:setupfile", *args
            ok {sout} =~ /def hello\(name="world", lang: "en"\)/
            file = dummy_file(nil, sout)
            ok {`ruby -wc #{file}`} == "Syntax OK\n"
          end
        end
      end

    end


    topic 'repo:' do

      topic 'repo:clone' do
        spec "copy a repository ('github:<user>/<repo>' is available)" do
          ## TODO
          dir = "repo7594"
          at_end { rm_rf dir }
          Dir.mkdir dir
          Dir.chdir dir do
            dryrun_mode do
              sout = main "repo:create", dir, "-u", "user1", "-e", "user1@gmail.com"
              ok {unesc(sout)} == <<~"END"
                [gi]$ mkdir repo7594
                [gi]$ cd repo7594
                [gi]$ git init --initial-branch=main
                [gi]$ git config user.name user1
                [gi]$ git config user.email user1@gmail.com
                [gi]$ git commit --allow-empty -m "Initial commit (empty)"
                [gi]$ echo '*~'           >  .gitignore
                [gi]$ echo '*.DS_Store'   >> .gitignore
                [gi]$ echo 'tmp/*'        >> .gitignore
                [gi]$ echo '*.pyc'        >> .gitignore
                [gi]$ cd -
              END
            end
          end
        end
      end

      topic 'repo:create' do
        spec "create a new directory and initialize it as a git repo" do
          dir = "repo1364"
          at_end { rm_rf dir }
          ok {dir}.not_exist?
          capture_subprocess() do
            sout = main "repo:create", dir, "-uuser1", "-ename1@gmail.com"
            ok {unesc(sout)} == <<~'END'
              [gi]$ mkdir repo1364
              [gi]$ cd repo1364
              [gi]$ git init --initial-branch=main
              [gi]$ git config user.name user1
              [gi]$ git config user.email name1@gmail.com
              [gi]$ git commit --allow-empty -m "Initial commit (empty)"
              [gi]$ echo '*~'           >  .gitignore
              [gi]$ echo '*.DS_Store'   >> .gitignore
              [gi]$ echo 'tmp/*'        >> .gitignore
              [gi]$ echo '*.pyc'        >> .gitignore
              [gi]$ cd -
            END
          end
          ok {dir}.dir_exist?
        end
      end

      topic 'repo:init' do
        spec "initialize git repository with empty initial commit" do
          dir = "repo4984"
          at_end { rm_rf dir }
          Dir.mkdir dir
          Dir.chdir dir do
            ok {".git"}.not_exist?
            capture_subprocess() do
              sout = main "repo:init", "-uuser1", "-euser1@gmail.com"
              ok {unesc(sout)} == <<~'END'
                [gi]$ git init --initial-branch=main
                [gi]$ git config user.name user1
                [gi]$ git config user.email user1@gmail.com
                [gi]$ git commit --allow-empty -m "Initial commit (empty)"
                [gi]$ echo '*~'           >  .gitignore
                [gi]$ echo '*.DS_Store'   >> .gitignore
                [gi]$ echo 'tmp/*'        >> .gitignore
                [gi]$ echo '*.pyc'        >> .gitignore
              END
            end
            ok {".git"}.dir_exist?
          end
        end
      end

      topic 'repo:remote' do
        spec "list/get/set/delete remote repository" do
          ## list (empty)
          output = capture_subprocess() do
            sout = main "repo:remote"
            ok {unesc(sout)} == "[gi]$ git remote -v\n"
          end
          ok {output} == ""
          ## set (add)
          output = capture_subprocess() do
            sout = main "repo:remote", "origin", "github:user1/repo1"
            ok {unesc(sout)} == <<~"END"
              [gi]$ git remote add origin git@github.com:user1/repo1.git
            END
          end
          ok {output} == ""
          ## get
          output = capture_subprocess() do
            sout = main "repo:remote", "origin"
            ok {unesc(sout)} == "[gi]$ git remote get-url origin\n"
          end
          ok {output} == "git@github.com:user1/repo1.git\n"
          ## set
          output = capture_subprocess() do
            sout = main "repo:remote", "origin", "gitlab:user2/repo2"
            ok {unesc(sout)} == <<~"END"
              [gi]$ git remote set-url origin git@gitlab.com:user2/repo2.git
            END
          end
          ok {output} == ""
          ## list
          output = capture_subprocess() do
            sout = main "repo:remote"
            ok {unesc(sout)} == "[gi]$ git remote -v\n"
          end
          ok {output} == <<~"END"
            origin	git@gitlab.com:user2/repo2.git (fetch)
            origin	git@gitlab.com:user2/repo2.git (push)
          END
          ## delete
          output = capture_subprocess() do
            sout = main "repo:remote", "origin", ""
            ok {unesc(sout)} == "[gi]$ git remote remove origin\n"
          end
          ok {output} == ""
          ## list (empty)
          output = capture_subprocess() do
            sout = main "repo:remote"
            ok {unesc(sout)} == "[gi]$ git remote -v\n"
          end
          ok {output} == ""
        end
      end

      topic 'repo:remote:origin' do
        spec "get/set/delete origin (= default remote repository)" do
          ## get (empty)
          output = capture_subprocess() do
            sout, serr, status = main! "repo:remote:origin"
            ok {status} != 0
            ok {unesc(sout)} == "[gi]$ git remote get-url origin\n"
            ok {serr} == "\e[31m[ERROR]\e[0m Git command failed: git remote get-url origin\n"
          end
          ok {output} == "error: No such remote 'origin'\n"
          ## set (add)
          output = capture_subprocess() do
            sout = main "repo:remote:origin", "github:user1/repo1"
            ok {unesc(sout)} == <<~"END"
              [gi]$ git remote add origin git@github.com:user1/repo1.git
            END
          end
          ok {output} == ""
          ## get
          output = capture_subprocess() do
            sout = main "repo:remote:origin"
            ok {unesc(sout)} == "[gi]$ git remote get-url origin\n"
          end
          ok {output} == "git@github.com:user1/repo1.git\n"
          ## set
          output = capture_subprocess() do
            sout = main "repo:remote:origin", "gitlab:user2/repo2"
            ok {unesc(sout)} == <<~"END"
              [gi]$ git remote set-url origin git@gitlab.com:user2/repo2.git
            END
          end
          ok {output} == ""
          ## get
          output = capture_subprocess() do
            sout = main "repo:remote:origin"
            ok {unesc(sout)} == "[gi]$ git remote get-url origin\n"
          end
          ok {output} == "git@gitlab.com:user2/repo2.git\n"
          ## delete
          output = capture_subprocess() do
            sout = main "repo:remote:origin", ""
            ok {unesc(sout)} == "[gi]$ git remote remove origin\n"
          end
          ok {output} == ""
          ## get (empty)
          output = capture_subprocess() do
            sout, serr, status = main! "repo:remote:origin"
            ok {status} != 0
            ok {unesc(sout)} == "[gi]$ git remote get-url origin\n"
            ok {serr} == "\e[31m[ERROR]\e[0m Git command failed: git remote get-url origin\n"
          end
          ok {output} == "error: No such remote 'origin'\n"
        end
      end

      topic 'repo:remote:delete' do
        spec "delete remote repository" do
          system! "git remote add origin git@github.com/user1/repo1.git"
          ok {`git remote`} == "origin\n"
          #
          output = capture_subprocess() do
            sout = main "repo:remote:delete", "origin"
            ok {unesc(sout)} == "[gi]$ git remote rm origin\n"
          end
          ok {output} == ""
          ok {`git remote`} == ""
        end
      end

      topic 'repo:remote:list' do
        spec "list remote repositories" do
          at_end {
            system! "git remote remove origin"
            system! "git remote remove backup"
          }
          output = capture_subprocess() do
            system! "git remote add origin https://github.com/user1/repo1.git"
            system! "git remote add backup https://gitlab.com/user1/repo1.git"
            sout = main "repo:remote:list"
            ok {unesc(sout)} == <<~'END'
              [gi]$ git remote --verbose
            END
          end
          ok {output} == <<~'END'
            backup	https://gitlab.com/user1/repo1.git (fetch)
            backup	https://gitlab.com/user1/repo1.git (push)
            origin	https://github.com/user1/repo1.git (fetch)
            origin	https://github.com/user1/repo1.git (push)
          END
        end
      end

      topic 'repo:remote:seturl' do
        spec "set remote repo url ('github:<user>/<proj>' available)" do
          ok {`git remote -v`} == ""
          output = capture_subprocess() do
            sout = main "repo:remote:seturl", "github:user3039/repo3039"
            ok {unesc(sout)} == <<~'END'
              [gi]$ git remote add origin git@github.com:user3039/repo3039.git
            END
          end
          ok {output} == ""
          ok {`git remote -v`} == <<~'END'
            origin	git@github.com:user3039/repo3039.git (fetch)
            origin	git@github.com:user3039/repo3039.git (push)
          END
        end
      end

    end


    topic 'staging:' do

      topic 'staging:add' do
        before do
          _reset_all_commits()
          system! "git reset HEAD"
        end
        spec "add changes of files into staging area" do
          file = "file7198.txt"
          dummy_file file, "AAA\n"
          system! "git add #{file}"
          system! "git commit -q -m 'add #{file}'"
          system! "echo BBB >> #{file}"
          ok {`git diff --cached`} == ""
          output = capture_subprocess() do
            sout = main "staging:add", "."
            ok {unesc(sout)} == <<~'END'
              [gi]$ git add -u .
            END
          end
          diff = `git diff --cached`
          ok {`git diff --cached`} =~ partial_regexp(<<~'END')
            diff --git a/file7198.txt b/file7198.txt
            index {==\h{7}==}..{==\h{7}==} {==\d+==}
            --- a/file7198.txt
            +++ b/file7198.txt
            @@ -1 +1,2 @@
             AAA
            +BBB
          END
          ok {output} == ""
        end
      end

      topic 'staging:clear' do
        spec "delete all changes in staging area" do
          file = "file3415.txt"
          dummy_file file, "AAA\n"
          output = capture_subprocess() do
            system! "git add #{file}"
            ok {`git diff --cached`} != ""
            sout = main "staging:clear"
            ok {unesc(sout)} == <<~'END'
              [gi]$ git reset HEAD
            END
            ok {`git diff --cached`} == ""
          end
        end
      end

      topic 'staging:edit' do
        spec "edit changes in staging area" do
          ## TODO
          dryrun_mode do
            sout = main "staging:edit"
            ok {unesc(sout)} == "[gi]$ git add --edit\n"
          end
        end
      end

      topic 'staging:show' do
        spec "show changes in staging area" do
          file = "file2794.txt"
          dummy_file file, "AAA\n"
          output = capture_subprocess() do
            system! "git add #{file}"
            sout = main "staging:show"
            ok {unesc(sout)} == <<~'END'
              [gi]$ git diff --cached
            END
          end
          ok {output} =~ partial_regexp(<<~'END')
            diff --git a/file2794.txt b/file2794.txt
            new file mode 100644
            index 0000000..{==\h{7}==}
            --- /dev/null
            +++ b/file2794.txt
            @@ -0,0 +1 @@
            +AAA
          END
        end
      end

    end


    topic 'stash:' do

      after do
        system! "git stash clear"
      end

      def dummy_stash1(file1)
        dummy_file file1, "AAA\n"
        system! "git add #{file1}"
        system! "git commit -q -m 'add #{file1}'"
        system! "echo BBB >> #{file1}"
        system! "git stash push -q"
        return file1
      end

      def dummy_stash2(file2)
        dummy_file file2, "DDD\n"
        system! "git add #{file2}"
        system! "git commit -q -m 'add #{file2}'"
        system! "echo EEE >> #{file2}"
        system! "git stash push -q"
        return file2
      end

      topic 'stash:drop' do
        spec "delete latest changes from stash" do
          file1 = dummy_stash1("file7294x.txt")
          file2 = dummy_stash2("file7294y.txt")
          ok {`git stash list`} =~ partial_regexp(<<~'END')
            stash@{0}: WIP on main: {==\h{7}==} add file7294y.txt
            stash@{1}: WIP on main: {==\h{7}==} add file7294x.txt
          END
          output = capture_subprocess() do
            sout = main "stash:drop"
            ok {unesc(sout)} == <<~'END'
              [gi]$ git stash drop
            END
          end
          ok {output} =~ /\ADropped refs\/stash@\{0\} \(\w+\)$/
          ok {`git stash list`} =~ partial_regexp(<<~'END')
            stash@{0}: WIP on main: {==\h{7}==} add file7294x.txt
          END
        end
      end

      topic 'stash:list' do
        spec "list stash history" do
          file1 = dummy_stash1("file3562x.txt")
          file2 = dummy_stash2("file3562y.txt")
          output = capture_subprocess() do
            sout = main "stash:list"
            ok {unesc(sout)} == <<~'END'
              [gi]$ git stash list
            END
          end
          ok {output} =~ partial_regexp(<<~'END')
            stash@{0}: WIP on main: {==\h{7}==} add file3562y.txt
            stash@{1}: WIP on main: {==\h{7}==} add file3562x.txt
          END
        end
      end

      topic 'stash:pop' do
        spec "restore latest changes from stash" do
          file1 = dummy_stash1("file7779x.txt")
          file2 = dummy_stash2("file7779y.txt")
          ok {readfile(file1)} == "AAA\n"
          ok {readfile(file2)} == "DDD\n"
          #
          output = capture_subprocess() do
            sout = main "stash:pop"
            ok {unesc(sout)} == <<~'END'
            [gi]$ git stash pop
            END
          end
          ok {output} != ""
          ok {readfile(file1)} == "AAA\n"
          ok {readfile(file2)} == "DDD\nEEE\n"
          #
          output = capture_subprocess() do
            sout = main "stash:pop"
            ok {unesc(sout)} == <<~'END'
            [gi]$ git stash pop
            END
          end
          ok {output} != ""
          ok {readfile(file1)} == "AAA\nBBB\n"
          ok {readfile(file2)} == "DDD\nEEE\n"
        end
      end

      topic 'stash:push' do
        spec "save current changes into stash" do
          file1 = dummy_stash1("file4591.txt")
          system! "git stash clear"
          ok {`git diff`} == ""
          system! "echo KKK >> #{file1}"
          ok {`git diff`} != ""
          ok {`git stash list`} == ""
          output = capture_subprocess() do
            sout = main "stash:push"
            ok {unesc(sout)} == <<~'END'
              [gi]$ git stash push
            END
          end
          ok {output} != ""
          ok {`git diff`} == ""
          ok {`git stash list`} =~ partial_regexp(<<~'END')
            stash@{0}: WIP on main: {==\h{7}==} add file4591.txt
          END
        end
      end

      topic 'stash:show' do
        spec "show changes on stash" do
          _reset_all_commits()    # !!!
          file1 = dummy_stash1("file9510x.txt")
          file2 = dummy_stash2("file9510y.txt")
          expected_regexp = partial_regexp(<<~'END')
            diff --git a/file9510y.txt b/file9510y.txt
            index {==\h{7}==}..{==\h{7}==} {==\d+==}
            --- a/file9510y.txt
            +++ b/file9510y.txt
            @@ -1 +1,2 @@
             DDD
            +EEE
          END
          #
          output = capture_subprocess() do
            sout = main "stash:show"
            ok {unesc(sout)} == <<~'END'
              [gi]$ git stash show -p
            END
          end
          ok {output} =~ expected_regexp
          #
          output = capture_subprocess() do
            sout = main "stash:show", "-n", "1"
            ok {unesc(sout)} == <<~'END'
              [gi]$ git stash show -p "stash@{0}"
            END
          end
          ok {output} =~ expected_regexp
          #
          output = capture_subprocess() do
            sout = main "stash:show", "-n2"
            ok {unesc(sout)} == <<~'END'
              [gi]$ git stash show -p "stash@{1}"
            END
          end
          ok {output} =~ partial_regexp(<<~'END')
            diff --git a/file9510x.txt b/file9510x.txt
            index {==\h{7}==}..{==\h{7}==} {==\d+==}
            --- a/file9510x.txt
            +++ b/file9510x.txt
            @@ -1 +1,2 @@
             AAA
            +BBB
          END
        end
      end

    end


    topic 'status:' do

      before do
        _reset_all_commits()
        #
        file1 = "file8040.txt"     # registered, modified
        file2 = "file8040.css"     # registered
        file3 = "file8040.html"    # not registered
        dummy_file(file1, "A\n")
        dummy_file(file2, "B\n")
        dummy_file(file3, "C\n")
        system! "git add #{file1} #{file2}"
        system! "git commit -q -m 'add #{file1} and #{file2}'"
        writefile(file1, "AA\n")
        @file1 = file1; @file2 = file2, @file3 = file3
      end

      topic 'status:compact' do
        spec "show status in compact format" do
          output = capture_subprocess() do
            sout = main "status:compact"
            ok {unesc(sout)} == "[gi]$ git status -sb\n"
          end
          ok {output} == <<~'END'
            ## main
             M file8040.txt
            ?? file8040.html
          END
        end
      end

      topic 'status:default' do
        spec "show status in default format" do
          output = capture_subprocess() do
            sout = main "status:default"
            ok {unesc(sout)} == "[gi]$ git status\n"
          end
          ok {output} == <<~'END'
On branch main
Changes not staged for commit:
  (use "git add <file>..." to update what will be committed)
  (use "git restore <file>..." to discard changes in working directory)
	modified:   file8040.txt

Untracked files:
  (use "git add <file>..." to include in what will be committed)
	file8040.html

no changes added to commit (use "git add" and/or "git commit -a")
          END
        end
      end

      topic 'status:here' do
        spec "same as 'stats:compact .'" do
          output = capture_subprocess() do
            sout = main "status:here"
            ok {unesc(sout)} == "[gi]$ git status -sb .\n"
          end
          ok {output} == <<~'END'
            ## main
             M file8040.txt
            ?? file8040.html
          END
        end
      end

      topic 'status:info' do
        spec "show various infomation of current status" do
          output = capture_subprocess() do
            sout = main "status:info"
            ok {unesc(sout)} == <<~'END'
              [gi]$ git status -sb . | sed -n 's!/$!!;/^??/s/^?? //p' | xargs ls -dF --color
              [gi]$ git status -sb -uno .
            END
          end
          ok {output} == <<~'END'
            file8040.html
            ## main
             M file8040.txt
          END
        end
      end

    end


    topic 'sync:' do

      topic 'sync:both' do
        spec "download and upload commits" do
          ## TODO
          dryrun_mode do
            sout = main "sync:both"
            ok {unesc(sout)} == <<~"END"
              [gi]$ git pull --prune
              [gi]$ git push
            END
          end
        end
      end

      topic 'sync:download' do
        spec "download commits from remote and apply them to local" do
          ## TODO
          dryrun_mode do
            sout = main "sync:download"
            ok {unesc(sout)} == "[gi]$ git pull --prune\n"
          end
        end
      end

      topic 'sync:upload' do
        spec "upload commits" do
          ## TODO
          dryrun_mode do
            sout = main "sync:upload"
            ok {unesc(sout)} == "[gi]$ git push\n"
          end
        end
      end

    end


    topic 'tag:' do

      before do
        system! "git tag --list | xargs git tag --delete >/dev/null"
      end

      topic 'tag:create' do
        spec "create a new tag" do
          tag = "tg6740"
          output = capture_subprocess() do
            sout = main "tag:create", tag
            ok {unesc(sout)} == "[gi]$ git tag #{tag}\n"
          end
          ok {output} == ""
          ok {`git tag --list`} == <<~"END"
            #{tag}
          END
        end
      end

      topic 'tag:delete' do
        spec "delete a tag" do
          tag = "tg6988"
          system! "git tag #{tag}"
          ok {`git tag --list`}.include?(tag)
          output = capture_subprocess() do
            sout = main "tag:delete", tag
            ok {unesc(sout)} == "[gi]$ git tag -d tg6988\n"
          end
          ok {output} =~ /\ADeleted tag '#{tag}' \(was \h{7}\)\n\z/
          ok {`git tag --list`}.NOT.include?(tag)
        end
      end

      topic 'tag:download' do
        spec "download tags" do
          ## TODO
          dryrun_mode do
            sout = main "tag:download"
            ok {unesc(sout)} == "[gi]$ git fetch --tags --prune-tags\n"
          end
        end
      end

      topic 'tag:list' do
        spec "list tags" do
          tag1 = "tg3352xx"
          tag2 = "tg3352yy"
          system! "git tag #{tag1}"
          system! "git tag #{tag2}"
          output = capture_subprocess() do
            sout = main "tag:list"
            ok {unesc(sout)} == "[gi]$ git tag -l\n"
          end
          ok {output} == <<~"END"
            #{tag1}
            #{tag2}
          END
        end
      end

      topic 'tag:upload' do
        spec "upload tags" do
          ## TODO
          dryrun_mode do
            sout = main "tag:upload"
            ok {unesc(sout)} == "[gi]$ git push --tags\n"
          end
        end
      end

    end


  end


end
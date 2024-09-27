# -*- coding: utf-8 -*-
# frozen_string_literal: true

require 'tempfile'

require 'oktest'

require 'git-improved'
require 'benry/unixcommand'


Oktest.global_scope do
  include Benry::UnixCommand


  GitImproved::APP_CONFIG.app_command = "gi"


  def main(*args, stdin: "", tty: false)
    output, sout, serr, status = main!(*args, stdin: stdin, tty: tty)
    ok {serr} == ""
    ok {status} == 0
    return output, sout
  end

  def main!(*args, stdin: "", tty: false)
    status = sout = serr = nil
    output = capture_subprocess do
      sout, serr = capture_sio(stdin, tty: tty) do
        status = GitImproved.main(args)
      end
    end
    return output, sout, serr, status
  end

  def capture_subprocess(&block)
    prev = $SUBPROCESS_OUTPUT
    return Tempfile.open("capture.", nil) do |f|
      $SUBPROCESS_OUTPUT = f
      begin
        yield
      rescue => exc
        raise
      ensure
        $SUBPROCESS_OUTPUT = prev
        f.rewind()
        output = f.read()
        STDOUT.print output if exc
      end
      output
    end
  end

  def unesc(str)
    return str.gsub(/\e\[.*?m/, '')
  end

  def readfile(file)
    return File.read(file, encoding: 'utf-8')
  end

  def writefile(file, content)
    return File.write(file, content, encoding: 'utf-8')
  end

  def system!(*args)
    system(*args, exception: true)
  end

  def rm_rf(dir)
    echoback_off do
      rm :rf, dir
    end
  end

  def dryrun_mode(&block)
    $DRYRUN_MODE = true
    yield
  ensure
    $DRYRUN_MODE = false
  end

  def curr_branch()
    return `git branch --show-current`.strip()
  end

  def get_commit_id(name="HEAD", width: 7)
    commit_id = `git rev-parse #{name}`.strip()
    return commit_id[0...width]
  end

  def _reset_all_commits()
    system! "git reset -q --hard #{$initial_commit_id}"
  end

  def delete_all_branches_except_main()
    branch_names = `git branch -l`.sub(/^\* .*\n/, '').sub(/^.*main\n/, '').split()
    system! "git branch -D -q #{branch_names.join(' ')}"
  end

end

# -*- coding: utf-8 -*-


defined? PROJECT    or abort "PROJECT required."
defined? RELEASE    or abort "RELEASE required."


desc "start release operation interactively"
task :release do
  do_release()
end

def do_release()
  RELEASE != '0.0.0'  or abort "** ERROR: 'RELEASE=X.X.X' required."
  commands = []
  guide_message(PROJECT, RELEASE).scan(/^  \$ (.*)/) do |command,|
    commands << command
  end
  run_shell_commands(commands)
end

def run_shell_commands(commands)
  dirs = []
  commands.each do |command|
    optional = command =~ /\# optional/
    y_n = optional ? "y/N" : "Y/n"
    puts ""
    puts "\e[34m$ #{command}\e[0m"
    print "\e[2m? [#{y_n}/!(command)/q(uit)]>\e[0m "
    answer = $stdin.gets().strip()
    if answer.empty?
      answer = optional ? "N" : "Y"
    end
    case answer
    when /^[Yy]/
      case command
      when /^cd -( +|$)/
        dir = dirs.pop()
        puts "cd -\t\t# #{dir}"
        Dir.chdir dir
      when /^cd (\S+)/
        dir = $1
        dirs.push(Dir.pwd)
        puts "cd #{dir}"
        Dir.chdir dir
      else
        sh command
      end
    when /^[Nn]/
      next
    when /^[!](.*)/
      cmd = $1.strip()
      if cmd.empty?
        print "\e[2menter command: \e[0m"
        cmd = $stdin.gets().strip()
      end
      if !cmd.empty?
        #sh cmd
        puts cmd
        system cmd
      end
      redo
    when /^[Qq]/
      break
    else
      puts "\e[31mUnexpected answer. Retry.\e[0m"
      redo
    end
  end
  nil
end


desc "show release operations"
task :'release:guide' do
  do_release_guide()
end

def do_release_guide()
  RELEASE != '0.0.0'  or abort "** ERROR: 'RELEASE=X.X.X' required."
  puts guide_message(PROJECT, RELEASE)
end

def guide_message(project, release)
  target = "#{project}-#{release}"
  tag    = "#{project}-#{release}"
  return <<END
How to release:

  $ git diff .
  $ git status .
  $ which ruby
  $ rake test
  $ rake test:all
  $ specid diff lib test
  $ chkruby lib test
  $ rake doc
  $ rake doc:export RELEASE=#{release}
  $ rake readme:execute			# optional
  $ rake readme:toc			# optional
  $ rake package RELEASE=#{release}
  $ rake package:extract		# confirm files in gem file
  $ (cd #{target}/data; find . -type f)
  $ (cd #{target}/data; ag '(Release|Copyright|License):')
  $ gem install #{target}.gem	# confirm gem package
  $ gem uninstall #{project}
  $ gem push #{target}.gem	# publish gem to rubygems.org
  $ git tag #{tag}		# or: git tag ruby-#{tag}
  $ git push --tags
  $ rake clean
  $ mkdir -p archive/ && mv #{target}.gem archive/
  $ cd ../docs/
  $ git add #{project}.html
  $ git commit -m "[main] docs: update '#{project}.html'"
  $ git push
END
end

# -*- coding: utf-8 -*-


PROJECT   = "git-improved"
RELEASE   = ENV['RELEASE'] || "0.0.0"
COPYRIGHT = "copyright(c) 2023-2024 kwatch@gmail.com"
LICENSE   = "MIT License"

#RUBY_VERSIONS = ["3.2", "3.1", "3.0", "2.7", "2.6", "2.5", "2.4", "2.3"]

Dir.glob('./task/*-task.rb').sort.each {|x| require x }

def do_doc()
  x = PROJECT
  md2 = "../benry-ruby/docs/md2"
  sh "#{md2} --md docs/#{x}.mdx > README.md"
  sh "#{md2}      docs/#{x}.mdx > docs/index.html"
end

desc "copy '*.task' files"
task :copytask do
  sh "cp -a ../benry-ruby/task ."
end

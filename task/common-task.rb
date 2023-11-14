# -*- coding: utf-8 -*-


defined? PROJECT    or abort "PROJECT required."
defined? RELEASE    or abort "RELEASE required."
defined? COPYRIGHT  or abort "COPYRIGHT required."
defined? LICENSE    or abort "LICENSE required."

RELEASE =~ /\A\d+\.\d+\.\d+/  or abort "RELEASE=#{RELEASE}: invalid release number."


require 'rake/clean'
CLEAN << "build"
CLEAN.concat Dir.glob("#{PROJECT}-*.gem").collect {|x| x.sub(/\.gem$/, '') }
CLOBBER.concat Dir.glob("#{PROJECT}-*.gem")


task :default do
  sh "rake -T", verbose: false
end unless Rake::Task.task_defined?(:default)


desc "create 'README.md' and 'doc/*.html'"
task :doc do
  x = PROJECT
  cd "doc" do
    sh "../../docs/md2 --md #{x}.mdx > ../README.md"
    sh "../../docs/md2 #{x}.mdx > #{x}.html"
  end
end

desc "copy 'doc/*.html' to '../docs/'"
task 'doc:export' do
  RELEASE != '0.0.0'  or abort "** ERROR: 'RELEASE=X.X.X' required."
  x = PROJECT
  cp "doc/#{x}.html", "../docs/"
  edit_file!("../docs/#{x}.html")
end


desc "edit metadata in files"
task :edit do
  do_edit()
end

def do_edit()
  filenames = target_files() + Dir.glob("doc/*.mdx")
  filenames.each do |fname|
    edit_file!(fname)
  end
end

def target_files()
  $_target_files ||= begin
    spec_src = File.read("#{PROJECT}.gemspec", encoding: 'utf-8')
    spec = eval spec_src
    spec.name == PROJECT  or
      abort "** ERROR: '#{PROJECT}' != '#{spec.name}' (project name in gemspec file)"
    spec.files
  end
  return $_target_files
end

def edit_file!(filename, verbose: true)
  changed = edit_file(filename) do |s|
    s = s.gsub(/\$Release[:].*?\$/,   "$"+"Release: #{RELEASE} $")
    s = s.gsub(/\$Copyright[:].*?\$/, "$"+"Copyright: #{COPYRIGHT} $")
    s = s.gsub(/\$License[:].*?\$/,   "$"+"License: #{LICENSE} $")
    s
  end
  if verbose
    puts "[C] #{filename}"     if changed
    puts "[U] #{filename}" unless changed
  end
  return changed
end

def edit_file(filename)
  File.open(filename, 'rb+') do |f|
    s1 = f.read()
    s2 = yield s1
    if s1 != s2
      f.rewind()
      f.truncate(0)
      f.write(s2)
      true
    else
      false
    end
  end
end


desc nil
task :'relink' do
  Dir.glob("task/*.rb").each do |x|
    src = "../" + x
    next if File.identical?(src, x)
    rm x
    ln src, x
  end
end

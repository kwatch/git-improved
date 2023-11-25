# -*- coding: utf-8 -*-

README_FILE      = "README.md"       unless defined? README_FILE
README_EXTRACT   = /^[Ff]ile: +(\S+)/ unless defined? README_EXTRACT
README_CODESTART = /^```\w+$/        unless defined? README_CODESTART
README_CODEEND   = /^```$/           unless defined? README_CODEEND
README_DESTDIR   = "tmp/readme"      unless defined? README_DESTDIR

require 'rake/clean'
CLEAN << "README.html"


def readme_extract_callback(filename, str)
  return str
end


namespace :readme do


  desc "retrieve scripts from #{README_FILE}"
  task :retrieve do
    do_readme_retrieve()
  end

  def do_readme_retrieve()
    dir = README_DESTDIR
    if File.exist?(dir)
      rm_rf "#{dir}/*"
    else
      mkdir_p dir
    end
    s = File.read(README_FILE, encoding: 'utf-8')
    filename = nil
    buf = nil
    s.each_line do |line|
      case line
      when README_EXTRACT
        filename = $1
        next
      when README_CODESTART
        if filename
          buf = []
        end
        next
      when README_CODEEND
        if filename && buf
          newfile = "#{dir}/#{filename}"
          unless File.exist?(File.dirname(newfile))
            mkdir_p File.dirname(newfile)
          end
          str = readme_extract_callback(filename, buf.join())
          File.write(newfile, str, encoding: 'utf-8')
          puts "[retrieve] #{newfile}"
        end
        filename = nil
        buf = nil
        next
      end
      #
      if buf
        buf << line
      end
    end
  end


  desc "execute code in readme file"
  task :execute => :retrieve do
    do_readme_execute()
  end

  def do_readme_execute()
    Dir.glob(README_DESTDIR+'/**/*.rb').sort.each do |fpath|
      puts "========================================"
      sh "ruby -I lib #{fpath}" do end
    end
  end


  desc "usage: rake increment range=1..10 add=+1"
  task :increment do
    range = ENV['range']  or raise "Arugment 'range=...' required."
    add   = ENV['add']    or raise "Argument 'add=...' required."
    range =~ /\A\d+\.\.\.?\d+\z/  or raise "#{range}: invalid range."
    add   =~ /\A[-+]\d+\z/        or raise "#{add}: invalid add."
    range = eval range
    add   = eval add
    Dir.glob("doc/*.mdx").each do |filename|
      File.open(filename, 'r+', encoding: 'utf-8') do |f|
        s1 = f.read()
        s2 = s1.gsub(/\b(ex)(\d+)(\.\w+)/) {
          x = $2
          n = x.to_i
          w = x.length
          if range === n
            n_s = "%0#{w}d" % (n + add)
            puts "* #{$1}#{x}#{$3} -> #{$1}#{n_s}#{$3}"
            "#{$1}#{n_s}#{$3}"
          else
            $&
          end
        }
        if s1 != s2
          f.rewind()
          f.truncate(0)
          f.write(s2)
        end
      end
    end
  end

  desc "builds table of contents"
  task :toc do
    do_readme_toc()
  end

  def do_readme_toc()
    url = ENV['README_URL']  or abort "$README_URL required."
    mkdir "tmp" unless Dir.exist?("tmp")
    htmlfile = "tmp/README.html"
    sh "curl -s -o #{htmlfile} #{url}"
    #rexp = /<h(\d) dir="auto"><a id="(.*?)" class="anchor".*><\/a>(.*)<\/h\1>/
    rexp = /<h(\d) id="user-content-.*?" dir="auto"><a class="heading-link" href="#(.*?)">(.*)<svg/
    html_str = File.read(htmlfile, encoding: 'utf-8')
    buf = []
    html_str.scan(rexp) do
      level = $1.to_i
      id = $2
      title = $3
      next if title =~ /Table of Contents/
      title = title.gsub(/<\/?code>/, '`')
      anchor = id.sub(/^user-content-/, '')
      indent = "  " * (level - 1)
      buf << "#{indent}* <a href=\"##{anchor}\">#{title}</a>\n"
    end
    buf.shift() if buf[0] && buf[0] =~ /^\* /
    toc_str = buf.join()
    #
    mdfile = README_FILE
    changed = File.open(mdfile, "r+", encoding: 'utf-8') do |f|
      s1 = f.read()
      s2 = s1.sub(/(<!-- TOC -->\n).*(<!-- \/TOC -->\n)/m) {
        [$1, toc_str, $2].join("\n")
      }
      if s1 != s2
        f.rewind()
        f.truncate(0)
        f.write(s2)
        true
      else
        false
      end
    end
    puts "[changed] #{mdfile}"          if changed
    puts "[not changed] #{mdfile}"  unless changed
  end


end

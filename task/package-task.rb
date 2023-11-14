# -*- coding: utf-8 -*-


desc "create package (*.gem)"
task :package do
  do_package()
end

def do_package()
  RELEASE != '0.0.0'  or abort "** ERROR: 'RELEASE=X.X.X' required."
  ## copy
  dir = "build"
  rm_rf dir if File.exist?(dir)
  mkdir dir
  target_files().each do |file|
    dest = File.join(dir, File.dirname(file))
    mkdir_p dest, :verbose=>false unless File.exist?(dest)
    cp file, "#{dir}/#{file}"
  end
  ## edit
  Dir.glob("#{dir}/**/*").each do |file|
    next unless File.file?(file)
    edit_file!(file, verbose: false)
  end
  ## build
  chdir dir do
    sh "gem build #{PROJECT}.gemspec"
  end
  mv "#{dir}/#{PROJECT}-#{RELEASE}.gem", "."
  rm_rf dir
end


desc "extract latest gem file"
task :'package:extract' do
  do_package_extract()
end

def do_package_extract()
  gemfile = Dir.glob("#{PROJECT}-*.gem").sort_by {|x| File.mtime(x) }.last
  dir = gemfile.sub(/\.gem$/, '')
  rm_rf dir if File.exist?(dir)
  mkdir dir
  mkdir "#{dir}/data"
  cd dir do
    sh "tar xvf ../#{gemfile}"
    sh "gunzip *.gz"
    cd "data" do
      sh "tar xvf ../data.tar"
    end
  end
end


desc "upload gem file to rubygems.org"
task :publish do
  do_publish()
end

def do_publish()
  RELEASE != '0.0.0'  or abort "** ERROR: 'RELEASE=X.X.X' required."
  gemfile = "#{PROJECT}-#{RELEASE}.gem"
  print "** Are you sure to publish #{gemfile}? [y/N]: "
  answer = $stdin.gets().strip()
  if answer.downcase == "y"
    sh "gem push #{gemfile}"
    #sh "git tag ruby-#{PROJECT}-#{RELEASE}"
    sh "git tag #{PROJECT}-#{RELEASE}"
    sh "#git push"
    sh "#git push --tags"
  end
end

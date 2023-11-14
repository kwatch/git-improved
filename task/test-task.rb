# -*- coding: utf-8 -*-


unless defined?(RUBY_VERSIONS)
  RUBY_VERSIONS = (
    if ENV['RUBY_VERSIONS']
      ENV['RUBY_VERSIONS'].split()
    else
      ["3.2", "3.1", "3.0", "2.7", "2.6", "2.5", "2.4", "2.3"]
    end
  )
end


desc "run test"
task :test do
  do_test()
end

def do_test()
  run_test()
end

def run_test(ruby=nil, &b)
  run_oktest(ruby, &b)
end

def run_minitest(ruby=nil, &b)
  files = File.exist?("test/run_all.rb") \
          ? ["test/run_all.rb"] \
          : Dir.glob("test/**/*_test.rb")
  if ruby
    sh(ruby, *files, &b)
  else
    ruby(*files, &b)
  end
end

def run_oktest(ruby=nil, &b)
  argstr = "-r oktest -e Oktest.main -- test -sp"
  if ruby
    sh("#{ruby} #{argstr}", &b)
  else
    ruby(argstr, &b)
  end
end


desc "run test in different ruby versions"
task :'test:all' do
  do_test_all()
end

def do_test_all()
  ENV['VS_HOME']  or
    abort "[ERROR] rake test:all: '$VS_HOME' environment var required."
  vs_home = ENV['VS_HOME'].split(/[:;]/).first
  ruby_versions = RUBY_VERSIONS
  test_all(vs_home, ruby_versions)
end

def test_all(vs_home, ruby_versions)
  header = proc {|s| "\033[0;36m=============== #{s} ===============\033[0m" }
  error  = proc {|s| "\033[0;31m** #{s}\033[0m" }
  comp   = proc {|x, y| x.to_s.split('.').map(&:to_i) <=> y.to_s.split('.').map(&:to_i) }
  ruby_versions.each do |ver|
    dir = Dir.glob("#{vs_home}/ruby/#{ver}.*/").sort_by(&comp).last
    puts ""
    if dir
      puts header.("#{ver} (#{dir})")
      run_test("#{dir}/bin/ruby") do |ok, res|
        $stderr.puts error.("test failed") unless ok
      end
      sleep 0.2
    else
      puts header.(ver)
      $stderr.puts error.("ruby #{ver} not found")
      sleep 1.0
    end
  end
end

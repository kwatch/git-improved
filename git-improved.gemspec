# -*- coding: utf-8 -*-

Gem::Specification.new do |spec|
  spec.name            = "git-improved"
  spec.version         = "$Release: 0.0.0 $".split()[1]
  spec.author          = "kwatch"
  spec.email           = "kwatch@gmail.com"
  spec.platform        = Gem::Platform::RUBY
  spec.homepage        = "https://kwatch.github.io/git-improved/"
  spec.summary         = "Improved interface for Git command"
  spec.description     = <<-"END"
Git-Improved is a wrapper script for Git command.
It provides much better interface than Git.

See #{spec.homepage} for details.
END
  spec.license         = "MIT"
  spec.files           = Dir[
                           "README.md", "MIT-LICENSE", "CHANGES.md",
                           "#{spec.name}.gemspec",
                           "lib/**/*.rb", "test/**/*.rb", "bin/*",
                           "doc/*.html", "doc/css/*.css",
                         ]
  spec.executables     = ["gi"]
  spec.bindir          = "bin"
  spec.require_path    = "lib"
  spec.test_files      = Dir["test/**/*_test.rb"]   # or: ["test/run_all.rb"]
  #spec.extra_rdoc_files = ["README.md", "CHANGES.md"]

  spec.required_ruby_version = ">= 2.3"
  spec.add_runtime_dependency     "benry-cmdapp"    , "~> 1"
  spec.add_development_dependency "oktest"          , "~> 1"
end

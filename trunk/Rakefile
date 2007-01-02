require 'spec/rake/spectask'
require 'spec/rake/verify_rcov'

Spec::Rake::SpecTask.new(:spec) do |t|
  t.spec_files = FileList['tests/*_spec.rb']
  t.spec_opts = ["--format", "specdoc", "--require", "tests/rspec_ext.rb", "--require", "tests/rspec_helper.rb", "--color"]
  t.rcov = true
end

RCov::VerifyTask.new(:verify_rcov => :spec) do |t|
  t.threshold = 99.0
end

task :default  => :verify_rcov

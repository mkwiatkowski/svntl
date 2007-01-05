require 'spec/rake/spectask'
require 'spec/rake/verify_rcov'

spec_files = FileList['tests/*_spec.rb']
spec_opts = ["--format", "specdoc", "--require", "tests/rspec_ext.rb", "--require", "tests/rspec_helper.rb", "--color"]

Spec::Rake::SpecTask.new(:spec) do |t|
  t.spec_files = spec_files
  t.spec_opts = spec_opts
end

Spec::Rake::SpecTask.new(:spec_with_rcov) do |t|
  t.spec_files = spec_files
  t.spec_opts = spec_opts
  t.rcov = true
end

RCov::VerifyTask.new(:verify_rcov => :spec_with_rcov) do |t|
  t.threshold = 99.7
end

task :default  => :verify_rcov

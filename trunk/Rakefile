require 'spec/rake/spectask'
require 'spec/rake/verify_rcov'
require 'rake/rdoctask'

def egrep(pattern)
  Dir['**/*.rb'].each do |filename|
    IO.readlines(filename).each_with_index do |line, count|
      puts "#{filename}:#{count+1}:#{line}" if line =~ pattern
    end
  end
end

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
  t.threshold = 99.9
end

Rake::RDocTask.new do |t|
  t.rdoc_files.include("svntl.rb")
  t.rdoc_dir = "rdoc"
  t.options << "--diagram"
  t.options << "--inline-source"
end

desc "Look for TODO and FIXME tags in the code"
task :todo do
  egrep /(FIXME|TODO)/
end

task :default  => :verify_rcov

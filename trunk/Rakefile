require 'spec/rake/spectask'

Spec::Rake::SpecTask.new(:spec) do |t|
  t.spec_files = FileList['tests/*_spec.rb']
  t.spec_opts = ["--format", "specdoc"]
end

task :default  => :spec

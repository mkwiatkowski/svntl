# svntl

Application for generating subversion graphical statistics, like a graph of LOC changes in time, etc. 

![svntl rb_loc_per_commit](https://cloud.githubusercontent.com/assets/51481/7879879/af8b3cd4-05f4-11e5-912f-23bcc43fa943.png)

# Example output of svntl.

## LOC per commit statistics

For repository trunk:

![svntl rb_loc_per_commit_small](https://cloud.githubusercontent.com/assets/51481/7879964/793dc6b4-05f5-11e5-9b21-597cabecc9ad.png)

For a single file:

![svntl_loc_per_commit_small](https://cloud.githubusercontent.com/assets/51481/7879971/857ce6f8-05f5-11e5-8db4-faf72206d587.png)

# Software requirements for running/developing svntl.

## User requirements

  * [Ruby](http://www.ruby-lang.org/)
  * [Gruff](http://nubyonrails.com/pages/gruff)
  * [Open4](http://codeforpeople.com/lib/ruby/open4/)

## Development requirements

  * All user requirements
  * [Rake](http://rake.rubyforge.org/)
  * [RSpec](http://rspec.rubyforge.org/) >= 0.7
  * [RCov](http://eigenclass.org/hiki.rb?rcov) >= 0.7
  * [XML Builder](http://builder.rubyforge.org/)

# Other existing open-source projects for generating subversion statistics.

| *Project name* | *Language* | *License* |
|----------------|------------|-----------|
| [SubStats](http://www.molgard.eu/substats/) | Ruby | GPL |
| [StatSVN](http://www.statsvn.org/) | Java | LGPL |
| [MPY SVN STATS](http://mpy-svn-stats.berlios.de/) | Python | GPL |
| [CVSAnalY](http://cvsanaly.tigris.org/) | Python | GPL |

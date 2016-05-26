DirCrawl
========

This crawls a directory of files and runs a block of code on each file. It
writes the output to a JSON with all the output as well as a single file
(which the parser can then reuse parts of).

### Installing

```
gem install dircrawl
```

### Running

1. Make blocks of the code you want to run and a block for including that
code.

```
block = lambda do |file, num1, num2|
  f = File.read(file)
  t = TestParser.new(f, num1, num2)
  t.run
end

include = lambda do
  load 'test_parser.rb'
end
```

2. Call dircrawl-

```
d = DirCrawl.new("/input/path", "/output/path", "ignore files including",
block, include, "args for", "block")
puts d.get_output
```

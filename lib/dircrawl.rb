require 'json'
require 'pry'

class DirCrawl
  def initialize(path, output_dir, ignore_includes, process_block, include_block, *args)
    @path = path
    @output_dir = output_dir
    @ignore_includes = ignore_includes
    include_block.call
    @process_block = process_block
    @output = Array.new
    crawl_dir(path, *args)
  end

  # Figure out where to write it
  def get_write_dir(dir, file)
    dir_save = dir.gsub(@path, @output_dir)
    return dir_save+"/"+file
  end

  # Create if they don't exist
  def create_write_dirs(dir)
    dirs = dir.split("/")
    dirs.delete("")
    overallpath = ""
    dirs.each do |d|
      Dir.mkdir(overallpath+"/"+d) if !File.directory?(overallpath+"/"+d)
      overallpath += ("/"+d)
    end
  end
  
  # Crawl dir and call block for each file
  def crawl_dir(dir, *args)
    Dir.foreach(dir) do |file|
      next if file == '.' or file == '..'
      # Go to next dir
      if File.directory?(dir+"/"+file)
        crawl_dir(dir+"/"+file, *args)

      # Process file
      elsif !file.include?(@ignore_includes)
        processed = @process_block.call(dir+"/"+file, *args)
        @output.push(JSON.parse(processed))

        # Write to file
        create_write_dirs(dir.gsub(@path, @output_dir))
        File.write(get_write_dir(dir, file), processed)
      end
    end
  end

  # Get the output array
  def get_output
    return JSON.pretty_generate(@output)
  end
end

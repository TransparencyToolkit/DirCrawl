require 'json'
require 'pry'
require 'harvesterreporter'

# Crawls a directory of files and runs a block of code on it
class DirCrawl
  def initialize(path_params, process_block, include_block, extras_block, cm_hash, *args)
    # Set the params for the path
    @path = path_params[:path]
    @output_dir = path_params[:output_dir]
    @ignore_includes = path_params[:ignore_includes]
    @failure_mode = path_params[:failure_mode]

    # Setup the blocks to run
    include_block.call
    @process_block = process_block
    @extras_block = extras_block

    # Setup the Harvester reporter to report the results
    @reporter = HarvesterReporter.new(cm_hash)
    crawl_dir(@path, *args)
  end

  # Crawls the directory sppecified
  def crawl_dir(dir, *args)
    Dir.foreach(dir) do |file|
      # Skip . or .. files
      next if file == '.' or file == '..'

      # Recurse into directories
      if File.directory?(dir+"/"+file)
        crawl_dir("#{dir}/#{file}", *args)

      # Process file
      elsif !file.include?(@ignore_includes)
        begin
          output_results(process_file(dir, file, *args), dir, file)
        rescue Exception => e
          handle_failure(e, dir, file, *args)
        end
      end
    end
  end

  # Process a file using the blocks given
  def process_file(dir, file, *args)
    create_write_dirs(dir.gsub(@path, @output_dir))

    # Run blocks to process the file
    if !File.exist?(get_write_path(dir, file))
      @extras_block.call("#{@output_dir}/") if !@extras_block.empty?
      return @process_block.call("#{dir}/#{file}", *args)
    else # Use already existing file
      puts "Processed file exists, skipping: #{dir}/#{file}"
      return File.read(get_write_path(dir, file))
    end
  end

  # Output the results to Harvester and file dir
  def output_results(processed, dir, file)
    @reporter.report_results([JSON.parse(processed)], "#{dir}/#{file}")
    File.write(get_write_path(dir, file), processed)
  end

  # Create if they don't exist
  def create_write_dirs(dir)
    dirs = dir.split("/")
    dirs.delete("")

    # Go through and create all subdirs
    overallpath = ""
    dirs.each do |d|
      Dir.mkdir(overallpath+"/"+d) if !File.directory?(overallpath+"/"+d)
      overallpath += ("/"+d)
    end
  end

  # Figure out where to write the file
  def get_write_path(dir, file)
    dir_save = dir.gsub(@path, @output_dir)
    return "#{dir_save}/#{file}.json"
  end

  # Handle different failure modes
  def handle_failure(error, dir, file, *args)
    if @failure_mode == "debug"
      binding.pry
    elsif @failure_mode == "log"
      error_file = "#{dir}/#{file}\n"
      IO.write(@output_dir+"/error_log.txt", error_file, mode: 'a')
    end
  end
end

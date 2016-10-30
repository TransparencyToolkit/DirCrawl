require 'json'
require 'pry'
require 'curb'
require 'selenium-webdriver'
require 'uri'

class DirCrawl
  def initialize(path, output_dir, ignore_includes, save, process_block, include_block, extras_block, failure_mode, cm_hash, *args)
    @path = path
    @output_dir = output_dir
    @ignore_includes = ignore_includes
    include_block.call
    @process_block = process_block
    @extras_block = extras_block
    @failure_mode = failure_mode
    @output = Array.new
    @save = save

    # Handle crawler manager info
    @cm_url = cm_hash[:crawler_manager_url] if cm_hash
    @selector_id = cm_hash[:selector_id] if cm_hash

    # Crawl
    crawl_dir(path, *args)
  end

  # Figure out where to write it
  def get_write_dir(dir, file)
    dir_save = dir.gsub(@path, @output_dir)
    return dir_save+"/"+file+".json"
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
        report_status("Going to next directory: " + dir+"/"+file)
        crawl_dir(dir+"/"+file, *args)

      # Process file
      elsif !file.include?(@ignore_includes)

	# Create Dirs
        create_write_dirs(dir.gsub(@path, @output_dir))

        begin
		# Process Extras
		if @extras_block != ""
			extras = @extras_block.call(@output_dir+"/")
		end

		# Process Main
                if !File.exist?(get_write_dir(dir, file))
                  processed = @process_block.call(dir+"/"+file, *args)
                else
                  processed = File.read(get_write_dir(dir, file))
                end

        rescue Exception => e # really catch any failures
          report_status("Error on file "+file+": "+e.to_s)
          if @failure_mode == "debug"
            binding.pry
          elsif @failure_mode == "log"
            IO.write(@output_dir+"/error_log.txt", file+"\n", mode: 'a')
          end
        end
                
        # Only save in output if specified (to handle large dirs)
        report_results([JSON.parse(processed)], dir+"/"+file)
        
        # Write to file
        File.write(get_write_dir(dir, file), processed)
      end
    end
  end

  # Figure out how to report results
  def report_results(results, path)
    if @cm_url
      report_incremental(results, path)
    else
      report_batch(results)
    end
  end

  # Report all results in one JSON
  def report_batch(results)
    results.each do |result|
      @output.push(result)
    end
  end

  # Report Harvester status message
  def report_status(status_msg)
    if @cm_url
      curl_url = @cm_url+"/update_status"
      c = Curl::Easy.http_post(curl_url,
                               Curl::PostField.content('selector_id', @selector_id),
                               Curl::PostField.content('status_message', status_msg))
    end
  end

  # Report results back to Harvester incrementally
  def report_incremental(results, path)
    curl_url = @cm_url+"/relay_results"
    c = Curl::Easy.http_post(curl_url,
                             Curl::PostField.content('selector_id', @selector_id),
                             Curl::PostField.content('status_message', "Processed " + path),
                             Curl::PostField.content('results', JSON.pretty_generate(results)))
  end

  # Get the output array
  def get_output
    return JSON.pretty_generate(@output)
  end
end

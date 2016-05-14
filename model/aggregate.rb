  # -----------------
  # Dependencies
  #-------------------
  require 'rubygems'
  require 'bundler'
  Bundler.require(:default)
  require "./config/redis"
  require './model/duplicate'
  require './model/store'
  # -------------

class Aggregate
  attr_accessor :uri, :downloader, :store
  def initialize uri
    puts "Initializing aggregator with #{uri}".colorize(:yellow)
    self.uri = uri
    # Initialize download worker pool
    self.downloader = Workers::Pool.new(size: 20, on_exception: proc { |e|
      puts "[Exception] #{e.class}: #{e.message}".colorize(:red)
    })
  end

  # -- Download files, from link
  def download links
    # Start downloading files in pool
    links.map do |file|
      next if Duplicate.downloaded? file
      downloader.perform do
        link = "#{self.uri}/#{file}"
        puts "Worker thread #{Thread.current.object_id} is downloading #{file}. Wait".colorize(:blue)
        # Create new agent for each worker
        browser = Mechanize.new
        browser.pluggable_parser.default = Mechanize::Download
        browser.get(link).save("./tmp/#{file}")
        puts "Done. #{file}".colorize(:green)
        Duplicate.save! file # Don't redownload file
        self.enqueue(file)
      end
    end

    # Cool down
    downloader.dispose(10) do
      puts "[Downloader] Worker thread #{Thread.current.object_id} is shutting down.".colorize(:yellow)
    end
  end

  # -- Extract links to download from page
  def extract!
    browser = Mechanize.new
    puts "Fetching #{uri}".colorize(:yellow)
    page = browser.get(uri) rescue nil
    data = page.links_with(:href => /zip/).map(&:text)
    puts "Extracted #{data.size} links from page".colorize(:green); ap data

    data
  end


  #-- Extract and store (Redis)
  def fetch_and_store!
    # Get links from page
    # Download files from links concurrently
    download self.extract!
  end

  #-- Store files in (Redis)
  def enqueue file
    # Create background worker
    worker = Workers::Worker.new(on_exception: proc { |e|
      puts "[Enqueue] #{e.class}: #{e.message}".colorize(:red)
    })
    # Extract files and store in redis
    worker.perform do
      zipped = "./tmp/#{file}"
      Zip::File.open(zipped) do |zip|
        # Handle entries one by one
        zip.each do |xml|
          extracted = "./tmp/#{xml.name}"
          puts "Extracting #{xml.name} from #{file}".colorize(:yellow)
          xml.extract(extracted)
          # Get xml content
          content = xml.get_input_stream.read
          Store.save!(content, xml.name)
          # Remove xml file
          File.delete(extracted)
        end

        # Remove zip file
        File.delete(zipped)
      end
    end

    # Cool down
    worker.dispose(10) do
      puts "[Enqueue] Worker thread #{Thread.current.object_id} is shutting down.".colorize(:yellow)
    end
  end

end
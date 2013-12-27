require 'rubygems'
require 'nokogiri'
require 'open-uri'
require 'csv'
require 'active_support/core_ext'

THREAD_COUNT = 32	# Tweak thread count to maximize local performance.

def main
	gem_list = get_remote_list()
	if gem_list.empty?
		raise "No remote gems found!"
	else
		p "Total gems found from remote: #{gem_list.size}"
	end

	write_history_header()

	mutex = Mutex.new
	THREAD_COUNT.times.map {
	  Thread.new(gem_list) do |gem_list|
	    while current_gem = mutex.synchronize { gem_list.pop }
	    	p "Starting on gem #{current_gem}"
	      page = Nokogiri::HTML(open("http://rubygems.org/gems/#{current_gem}/versions"))
	      versions = parse_version_history(page, current_gem)
	      mutex.synchronize {
	      	begin
						write_history(versions)
					rescue Exception => e
						p "Failed to write #{current_gem}. Exception: #{e}"
					end
	      }
	    end
	  end
	}.each(&:join)
end

# Uses local gem command to get full gem list from rubygems.
# Returns array of gem names as strings.
def get_remote_list
	begin
		raw_gem_string = `gem list --remote`
	rescue Exception => e
		p "Could not make remote gem list call."
	end

	if raw_gem_string
		parse_gem_string(raw_gem_string)
	else
		[]
	end
end

# Parses the raw gem name string that comes back from rubygems.
def parse_gem_string(gems)
	gems = gems.split("\n")
	gems = gems.map{|g| g.split(" ").first }
end

# Uses Nokogiri to parse the rubygems page and pull out gem history.
# Returns an array of arrays.
#   Each inner array contains name, version number, date published, size in bytes.
def parse_version_history(page, gem_name)
	versions = []
	page.css("div.versions ol li").each do |version|
		number = version.css("a").text
		date   = version.css("small").text
		size   = version.css("span.size").text.gsub("(", "").gsub(")", "")
		size, type = size.split(" ")
		size_bytes = case(type)
		when "KB" || "kb"
			size.to_i.kilobytes
		when "MB" || "mb"
			size.to_i.megabytes
		else
			raise "Size type not handled! Please make a case for: #{type}"
		end

		versions << [gem_name, number, date, size_bytes]
	end

	return versions
end

# Writes the header names to the CSV file.
def write_history_header()
	CSV.open("gem_history.csv", "ab") do |csv|
		csv << ['name', 'version number', 'date', 'size']
	end
end

# Appends the version array to the CSV file.
def write_history(versions)
  CSV.open("gem_history.csv", "ab") do |csv|
		versions.each do |v|
  		csv << v
  	end
	end
end

main()
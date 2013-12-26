require 'rubygems'
require 'nokogiri'
require 'open-uri'
require 'csv'
require 'active_support/core_ext'

def main
	gem_list = get_remote_list()
	if gem_list.empty?
		raise "No remote gems found!"
	else
		p "Total gems found from remote: #{gem_list.size}"
	end

	write_history_headers()
	gem_list.each do |g|
		begin
			p "Starting on gem #{g}"
			page = Nokogiri::HTML(open("http://rubygems.org/gems/#{g}/versions"))
			versions = parse_version_history(page, g)
			write_history(versions)
		rescue Exception => e
			p "Failed to parse gem #{g}. Exception: #{e}"
		end
	end
end

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

def parse_gem_string(gems)
	gems = gems.split("\n")
	gems = gems.map{|g| g.split(" ").first }
end

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

	versions
end

def write_history(versions)
  CSV.open("gem_history.csv", "ab") do |csv|
  	versions.each do |v|
	  	csv << v
	  end
	end
end

def write_history_headers
	CSV.open("gem_history.csv", "wb") do |csv|
		['name', 'version number', 'date', 'size']
	end
end

main()
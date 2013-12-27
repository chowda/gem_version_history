require 'rubygems'
require 'nokogiri'
require 'open-uri'
require 'csv'
require 'active_support/core_ext'

def main
	gem_list = get_remote_list()
	total_gems = gem_list.size
	if gem_list.empty?
		raise "No remote gems found!"
	else
		p "Total gems found from remote: #{total_gems}"
	end

	version_holder = []
	current_position = 1
	gem_list[0,100].each do |g|
		current_position += 1
		p "on # #{g}| (#{(current_position / total_gems.to_f) * 100}%)" if current_position % 10 == 0
		begin
			page = Nokogiri::HTML(open("http://rubygems.org/gems/#{g}/versions"))
			version_holder << versions = parse_version_history(page, g)
		rescue Exception => e
			p "Failed to parse gem #{g}. Exception: #{e}"
		end
	end

	write_history(version_holder)
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
  	csv << ['name', 'version number', 'date', 'size']
  	versions.each do |version|
  		version.each do |v|
	  		csv << v
	  	end
	  end
	end
end

main()
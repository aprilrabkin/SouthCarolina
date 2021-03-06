require 'mechanize'
require "rest_client"
require 'pry-nav'
require 'nokogiri'
require 'csv'

class Scraper 
	attr_reader :ids, :table, :rows, :ids, :newpage
	def initialize
		@rows = []
	end

	def get_ocd_ids
		page = RestClient.get("https://raw.githubusercontent.com/opencivicdata/ocd-division-ids/master/identifiers/country-us/census_autogenerated/us_census_places.csv")
		noko = Nokogiri::HTML(page)
		@ids = noko.text.lines.select do |line|
			line =~ /state:sc/
		end.reject do |line|
			line =~ /place:/
		end.map do |line|
			line.gsub(/,.+/, '').gsub(/\n/, '')
		end 
	end 

	def scrape_each_county_page
		i = 0
		while i < 45 do #Abbeville to York County
			agent = Mechanize.new 
			page = agent.get("http://www.scvotes.org/how_to_register_absentee_voting")
			link = page.parser.css('.leaf')[i].search('a')[0].attribute('href')
			@newpage = agent.get(link.value).parser
			parse_county
			i += 1
		end
	end

	def parse_county

		county_name = newpage.css('#title').text 

		office = newpage.css('.content').inner_html.scan(/(#{county_name}.*)/).flatten.first.gsub(/<.*/,"")

		phone = newpage.css('.content').inner_html.scan(/\(\d{3}\)\s\d{3}-\d{4}/).flatten.first

		officeA = office.gsub("County ", "").strip
		if newpage.css('.content').css('a').select{|a| a.text == officeA}.count > 0 
			if newpage.css('.content').css('a').select{|a| a.text == officeA}.first.values.count > 0
				website = newpage.css('.content').css('a').select do |a| 
					a.text == officeA 
				end.first.values.first
			end
		else
			website = "" 
		end



		id = @ids.find do |i| #should make this it's own method called match_ocd-id
			if county_name
				name = county_name.rstrip.gsub(" County", "").gsub(" ", "_")
			end
			i =~ /county:#{name}/i
		end || ""
		
		@rows << [county_name + " County", "South Carolina", office, phone, website, id]

	end			

	def write_into_CSV_file
		CSV.open("spreadsheet.csv", "wb") do |csv|
			@rows.map do |line|
				csv << line
			end
		end
	end

end

a = Scraper.new
a.get_ocd_ids
a.scrape_each_county_page
a.write_into_CSV_file

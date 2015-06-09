require 'pry'
require 'nokogiri'
require 'open-uri'
require 'stringio'
require 'date'
require 'csv'

module Inspectr
  class PageScraper

   attr_reader :pages, :inspections, :form_links

    def initialize
      @base = "http://ga.healthinspections.us/georgia/"
      init = Nokogiri::HTML(open("http://ga.healthinspections.us/georgia/search.cfm?start=1921&1=1&f=s&r=name&s=&inspectionType=&sd=01/01/2015&ed=06/06/2015&useDate=YES&county=Fulton&"))
      @pages = self.all_pages(init)
      @inspections = nil
    end

    def all_pages(init) 
      pages = init.css("td.body a[href*='search.cfm']")
      @pages = pages.map do |page|
        @base + page['href']
      end
    end

    def inspection_links(link)
      page_link_data = Nokogiri::HTML(open(link)) 
      links = page_link_data.css("td.body a:contains('Grade')")
      links.map do |inspection|
        @base + inspection['href']
      end
    end

    def all_inspections(write_file,start,finish)
      File.open(write_file,"w") do |f|
        (start..finish).each_with_index do |x,index|
          puts "adding #{index+1}..."
          f.puts self.inspection_links(self.pages[x])
        sleep(2.8)
        end
      end
      erase_duplicates(write_file)
    end

    def erase_duplicates(write_file)
      array = IO.readlines(write_file).uniq
      File.open(write_file, "w") do |f|
        array.each do |link|
          f.puts link
        end
      end
    end
  end


  class FormScraper

    attr_reader :form_array 

    def initialize(file)
      @inspection_array = self.file_to_array(file)
      @base = "http://ga.healthinspections.us/"
    end

    def file_to_array(file)
      array = []
      File.open(file) do |f|
        f.each_line do |l|
          array << l.strip
        end
      end
      array
    end

    def get_form_links(write_file,start,up_to)
      inspections = @inspection_array[start..finish]
      File.open(write_file, "w") do |f|
        inspections.each_with_index do |inspection,index|
          puts "importing data: #{index + 1} out of #{inspections.length}..."
          doc = Nokogiri::HTML(open(inspection))
          form_link = doc.css("a:contains('View Form')").attribute('href').value
          form_link = form_link[3..form_link.length] #removes ../ from every link
          form_url = @base + form_link
          f.puts form_url
          sleep(2.8)
        end
      end
    end

    def get_form_data(read_file, write_file,start,up_to)
      form_array = self.file_to_array(read_file)
      form_array = form_array[start..up_to]
      CSV.open(write_file, "wb") do |csv|
        form_array.each_with_index do |form_link, index|
          doc = Nokogiri::HTML(open(form_link))
          puts "importing data: #{index + 1} out of #{form_array.length}..."

          restaurant_name = self.restaurant_info(doc,"Establishment").strip.tr('^A-Za-z0-9& ','')
          inspection_date = self.restaurant_info(doc,"Date").strip
          inspection_date = Date.strptime(inspection_date, "%m/%d/%Y").strftime('%Y/%m/%d')
          street = self.restaurant_info(doc,"Address").strip

          city = self.restaurant_info(doc,"City/State").strip
          city = city[0..-4] #removes state from string with index

          state = self.restaurant_info(doc,"City/State").split(" ")
          state = state.last

          permit = self.restaurant_info(doc,"Permit #").strip

          zipcode = self.restaurant_info(doc,"Zipcode").strip
          # current_grade = self.restaurant_score("#div_grade",doc)
          current_score = self.restaurant_score("#div_finalScore",doc).to_i

          csv << [permit, restaurant_name,street,city,state,zipcode,inspection_date,current_score]
          sleep(2.7)
        end
      end
    end


    def restaurant_info(doc,name)
      result = doc.at_css("b.eleven:contains('#{name}')").parent
      result = result.text.strip
      result = result[name.length..result.length]
    end

    def restaurant_score(div_id,doc)
      result = doc.css(div_id).text.strip
    end

  end

end

app = Inspectr::FormScraper.new("lib/links/inspection_links/2015_inspections.txt")

# app.get_form_links("lib/links/form_links/2015-forms_part_2.txt",1910,1911)
app.get_form_data("lib/links/form_links/2015-forms.txt","form_data_2015_part1.csv",0,999)
# form_links = app.get_form_links(1001,10000) #gets form links
# puts form_links
# generated inspection links for Fulton County

# app = Inspectr::PageScraper.new
# app.all_inspections("test.txt",0,96)
# puts inspections






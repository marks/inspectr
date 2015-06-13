require 'pry'
require 'nokogiri'
require 'open-uri'
require 'stringio'
require 'date'
require 'csv'

module Inspectr
  class PageScraper

   attr_reader :pages, :inspections, :form_links

    def initialize(start_date="01/01/2014", end_date="01/01/2014")
      @base = "http://ga.healthinspections.us/georgia/"
      init = Nokogiri::HTML(open("http://ga.healthinspections.us/georgia/search.cfm?start=1&1=1&f=s&r=name&s=&inspectionType=&sd=#{start_date}&ed=#{end_date}&useDate=YES&county=Fulton&"))
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
          puts "adding links for page #{index+1}..."
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

    def get_form_links(write_file)
      File.open(write_file, "w") do |f|
        @inspection_array.each_with_index do |inspection,index|
          puts "getting form link: #{index + 1} out of #{@inspection_array.length}..."
          doc = Nokogiri::HTML(open(inspection))
          form_link = doc.css("a:contains('View Form')").attribute('href').value
          form_link = form_link[3..form_link.length] #removes ../ from every link
          form_url = @base + form_link
          f.puts form_url
          sleep(2.8)
        end
      end
    end

    def get_form_data(read_file, write_file)
      form_array = self.file_to_array(read_file)
      CSV.open(write_file, "wb") do |csv|
        csv << ["business_id","name","address","city","state","postal_code","date","score","grade"]
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

          current_grade = self.restaurant_score("#div_grade",doc).strip

          csv << [permit, restaurant_name,street,city,state,zipcode,inspection_date,current_score,current_grade]
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
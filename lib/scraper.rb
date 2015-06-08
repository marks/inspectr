require 'pry'
require 'nokogiri'
require 'open-uri'
require 'stringio'
require 'json'

module Inspectr
  class PageScraper

   attr_reader :pages, :inspections, :form_links

    def initialize
      @base = "http://ga.healthinspections.us/georgia/"
      init = Nokogiri::HTML(open("http://ga.healthinspections.us/georgia/search.cfm?1=1&f=s&r=name&s=&inspectionType=&sd=05/07/2015&ed=06/06/2015&useDate=NO&county=Fulton"))
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

    def all_inspections(start,finish)
      array = []
      (start..finish).each do |x|
        array << self.inspection_links(self.pages[x])
      sleep(2.5)
      end
      @inspections = array.flatten
    end

  end

  class FormScraper

    attr_reader :form_links

    def initialize(file)
      @file = file
      @form_files = self.file_to_array
      @base = "http://ga.healthinspections.us/"
      @form_links = []
      @restaurants = []
    end

    def file_to_array
      array = []
      File.open(@file) do |f|
        f.each_line do |l|
          array << l.strip
        end
      end
      array
    end

    def get_form_links
      inspections = @form_array[0..10]
      inspections.each do |inspection|
        doc = Nokogiri::HTML(open(inspection))
        form_link = doc.css("a:contains('View Form')").attribute('href').value
        form_link = form_link[3..form_link.length] #removes ../ from every link
        form_url = @base + form_link
        @form_links << form_url
        sleep(2.7)
      end
      @form_links
   end

    def get_form_data
      @form_links.each do |form_link|
        doc = Nokogiri::HTML(open(form_link))

        restaurant_name = self.restaurant_info(doc,"Establishment").strip
        inspection_date = self.restaurant_info(doc,"Date").strip
        street = self.restaurant_info(doc,"Address").strip

        city = self.restaurant_info(doc,"City/State").strip
        city = city[0..-4] #removes state from string with index

        state = self.restaurant_info(doc,"City/State").split(" ")
        state = state.last

        zipcode = self.restaurant_info(doc,"Zipcode").strip
        current_grade = self.restaurant_score("#div_grade",doc)
        current_score = self.restaurant_score("#div_finalScore",doc).to_i

        json = {
          name: restaurant_name
          date: inspection_date
          street: street
          city: city
          state: state
          zipcode: zipcode
          grade: current_grade
          score: current_score
        }.to_json

        @restaurants << json
        sleep(2.7)
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

  # class Restaurant

  #   attr_reader :name, :date, :street, :state 
    
  #   def initialize(args)
  #     @name = args['name']
  #     @date = args['date']
  #     @street = args['street']
  #     @city = args['city']
  #     @state = args['state']
  #     @zipcode = args['zipcode']
  #     @current_grade = args['grade']
  #     @current_score  = args['score']
  #   end

  #   def as_json 
  #     {
  #       name: self.
  #     }

  #   end

  # end
end

app = Inspectr::FormScraper.new("lib/links/links1-100.txt")
form_links = app.get_form_links
puts form_links
# generated inspection links for Fulton County
# app = Inspectr::PageScraper.new
# app.all_inspections(900,988)
# puts app.inspections





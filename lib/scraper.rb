require 'pry'
require 'nokogiri'
require 'open-uri'
require 'stringio'
require 'date'
require 'csv'
require 'retriable'

module Inspectr
  class PageScraper

   attr_reader :pages, :inspections, :form_links

    def initialize(base="http://ga.healthinspections.us/georgia/", start_date="01/01/2014", end_date="01/01/2014")
      @base = base
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
      begin
        Retriable.retriable on: OpenURI::HTTPError, tries: 5, base_interval: 1.5 do
          page_link_data = Nokogiri::HTML(open(link)) 
          links = page_link_data.css("td.body a:contains('Grade')")
          links.map do |inspection|
            @base + inspection['href']
          end
        end
      rescue => e
        # run this if retriable ends up re-rasing the exception
        puts "!!! we were unable to get data from #{link}"
      end
    end

    def all_inspections(write_file,start,finish)
      File.open(write_file,"w") do |f|
        (start..finish).each_with_index do |x,index|
          puts "adding links for page #{index+1}..."
          f.puts self.inspection_links(self.pages[x])
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

    def initialize(file, base="http://ga.healthinspections.us/")
      @inspection_array = self.file_to_array(file)
      @base = base
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
          begin
            Retriable.retriable on: OpenURI::HTTPError, tries: 5, base_interval: 1.5 do
              puts "getting form link: #{index + 1} out of #{@inspection_array.length} (#{inspection})..."
              doc = Nokogiri::HTML(open(inspection))
              form_link = doc.css("a:contains('View Form')").attribute('href').value
              form_link = form_link[3..form_link.length] #removes ../ from every link
              form_url = @base + form_link
              f.puts form_url
            end
          rescue => e
            # run this if retriable ends up re-rasing the exception
            puts "!!! we were unable to get data from #{inspection}"
          end
        end
      end
    end

    def get_form_data(read_file, write_file)
      form_array = self.file_to_array(read_file)
      CSV.open(write_file, "wb") do |csv|
        csv << ["business_id","name","address","city","state","postal_code","date","score","grade","1-2","2-1A","2-1B","2-1C","2-2A","2-2B","2-2C","2-2D","3-1A","3-1B","3-1C","4-1A","4-1B","4-2A","4-2B","5-1A","5-1B","5-2","6-1A","6-1B","6-1C","6-1D","6-2","7-1","8-2A","8-2B","9-2","10A","10B","10C","10D","11A","11B","11C","11D","12A","12B","12C","12D","13A","13B","14A","14B","14C","14D","15A","15B","15C","16A","16B","16C","17A","17B","17C","17D","18"]
        form_array.each_with_index do |form_link, index|
        begin
          Retriable.retriable on: OpenURI::HTTPError, tries: 5, base_interval: 1.5 do
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

            current_score = self.restaurant_score("#div_finalScore",doc).to_i

            current_grade = self.restaurant_score("#div_grade",doc).strip

            # compliance data
            comp_data = Hash.new
            compliance_columns_1_to_9 = ["","in compliance","not in compliance","not applicable","not observed","","corrected on-site during inspection","repeat violation of the same code provision"]
            compliance_columns_10_to_18 = ["","not in compliance","","corrected on-site during inspection","repeat violation of the same code provision"]

            doc.css("img[src=\"../../images/circle_closed2.jpg\"]").each do |filled_circle|
              row = filled_circle.parent.parent
              row_desc = row.css("td:nth(6)").text.to_s.strip # GA form sections 1-9
              row_desc = row.css("td:nth(3)").text.to_s.strip if row_desc == "" # GA form sections 10-18
              next if row_desc == "" 

              row_id = row_desc.scan(/(.*)\. /)[0][0]
              row_id_n = row_id.scan(/^(\d+)-?/)[0][0].to_i

              filled_columns = []
              row.css("td").each_with_index do |col,i|
                if row_id_n <= 9
                  filled_columns << compliance_columns_1_to_9[i] if col.to_s.match('circle_closed2.jpg')
                elsif row_id_n >= 10
                  filled_columns << compliance_columns_10_to_18[i] if col.to_s.match('circle_closed2.jpg')
                end
              end
              # actually set the value for the compliance row 
              comp_data[row_id] = filled_columns.join(" - ")
            end
            # add inspection report's data to CSV
            csv << [permit, restaurant_name, street, city, state, zipcode, inspection_date, current_score, current_grade, comp_data["1-2"],comp_data["2-1A"],comp_data["2-1B"],comp_data["2-1C"],comp_data["2-2A"],comp_data["2-2B"],comp_data["2-2C"],comp_data["2-2D"],comp_data["3-1A"],comp_data["3-1B"],comp_data["3-1C"],comp_data["4-1A"],comp_data["4-1B"],comp_data["4-2A"],comp_data["4-2B"],comp_data["5-1A"],comp_data["5-1B"],comp_data["5-2"],comp_data["6-1A"],comp_data["6-1B"],comp_data["6-1C"],comp_data["6-1D"],comp_data["6-2"],comp_data["7-1"],comp_data["8-2A"],comp_data["8-2B"],comp_data["9-2"],comp_data["10A"],comp_data["10B"],comp_data["10C"],comp_data["10D"],comp_data["11A"],comp_data["11B"],comp_data["11C"],comp_data["11D"],comp_data["12A"],comp_data["12B"],comp_data["12C"],comp_data["12D"],comp_data["13A"],comp_data["13B"],comp_data["14A"],comp_data["14B"],comp_data["14C"],comp_data["14D"],comp_data["15A"],comp_data["15B"],comp_data["15C"],comp_data["16A"],comp_data["16B"],comp_data["16C"],comp_data["17A"],comp_data["17B"],comp_data["17C"],comp_data["17D"],comp_data["18"]]
          end
        rescue => e
          # run this if retriable ends up re-rasing the exception
          puts "!!! we were unable to get data from #{form_link}"
        end
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
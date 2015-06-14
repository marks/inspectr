require './lib/scraper.rb'

# 0) set a name for this scraping session.. for example "2015_inspections" and make sure that folder exists
scraping_key = "2015_GA_inspections"
folder_for_session = "data/#{scraping_key}"
FileUtils.mkdir_p(folder_for_session)

# 1) get inspection pages
page_scraper = Inspectr::PageScraper.new("http://ga.healthinspections.us/georgia/","01/01/2015","06/01/2015")
page_scraper.all_inspections("#{folder_for_session}/inspection_links.txt",0,0) # pages to get links for

# 2) get actual inspection data
form_scraper = Inspectr::FormScraper.new("#{folder_for_session}/inspection_links.txt","http://ga.healthinspections.us/")
form_scraper.get_form_links("#{folder_for_session}/form_links.txt")
form_scraper.get_form_data("#{folder_for_session}/form_links.txt","#{folder_for_session}/data.csv")
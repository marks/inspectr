require './lib/scraper.rb'

# 0) set a name for this scraping session.. for example "2015_inspections" and make sure that folder exists
scraping_key = "2015_inspections"
folder_for_session = "data/#{scraping_key}"
FileUtils.mkdir_p(folder_for_session)

# 1) get inspection pages
page_scraper = Inspectr::PageScraper.new("01/01/2015","06/01/2015")
page_scraper.all_inspections("#{folder_for_session}/inspection_links.txt",0,1) # pages to get links for

# 2) get actual inspection data
form_scraper = Inspectr::FormScraper.new("#{folder_for_session}/inspection_links.txt")
form_scraper.get_form_links("#{folder_for_session}/form_links.txt",0,10)
form_scraper.get_form_data("#{folder_for_session}/form_links.txt","#{folder_for_session}/data.csv",0,10)
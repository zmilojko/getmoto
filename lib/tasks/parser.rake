def process_page(url, cat: [], file: nil, exc_file: exc_file, this_is_page: false)
  puts "#{" "*2*cat.length}processing #{url}"
  
  page = Scan.find_by url: url
  doc = Nokogiri::HTML(page.content)
  
  if doc.search('title')[0].text == "301 Moved Permanently"
    puts "#{" "*2*cat.length}  PAGE MOVED PERMANENTLY"
    exc_file.write <<-EXCEPTION
    {
      "url": "#{url}",
      "exception": "301 Moved Permanently",
      "details": ["#{doc.search('a')[0].attributes["href"].value}"]
    },
    EXCEPTION
    exc_file.flush
    return
  end
  
  cat1 = Array.new(cat)
  cat1 << url.match(/\/([^\/]+)-\d+$/)[1] unless this_is_page
  # Does this page have subcategories:
  elem_list = doc.search('span[class="category"]')
  unless elem_list.empty?
    elem_list.each do |span|
      process_page span.children[0].attributes['href'].value, cat: cat1, file: file, exc_file: exc_file
    end
  else
    #this page contains a list of product, but there might be other 'pages' in the bottom
    #process products first
    puts "#{" "*2*cat.length}  processing products from: #{url}"
    process_product_page doc, url, cat1, file, exc_file

    # now scan pages 2-N, if you are on page 1
    page_list = doc.search('div[id="paging-num"]')
    unless page_list.empty? or page_list[0].children[0].nil? or page_list[0].children[0].attributes['class'].nil?
      if page_list[0].children[0].attributes['class'].value == 'current'
        # Take the last child, use it as a pattern
        last_url = page_list[0].children.last.search('a')[0].attributes["href"].value
        # should look like "/verkkokauppa/client/index/page:7?id=556"
        max_page = last_url.match(/page:(\d+)\?id/)[1].to_i
        (2..max_page).each do |page_num|
          new_page_url = last_url.gsub(/page:\d+\?id/,"page:#{page_num}?id")
          puts "#{" "*2*cat.length}  processing product subpage: #{new_page_url}"
          process_page new_page_url, cat: cat1, file: file, exc_file: exc_file, this_is_page: true
        end
      end
    end  
  end
end

def process_product_page(doc, url, cat, file, exc_file)
  prod_table = doc.search('table[class="products-listing"]')[0]
  prod_table.children.each_with_index do |tr, index|
    h4_list = tr.search('h4')
    unless h4_list.blank?
      h4 = h4_list[0]
      name = h4.search('a').text
      product_url = h4.search('a')[0].attributes["href"].value
      puts "#{" "*2*cat.length}    writing product: #{product_url}"
      begin
        pid = product_url.match(/\-(\d+\-\d+)\/?$/)[1]
      rescue
        puts "#{" "*2*cat.length}  PAGE MOVED PERMANENTLY"
        exc_file.write <<-EXCEPTION
        {
          "url": "#{url}",
          "exception": "PRODUCT URL NOT FORMED WELL",
          "details": [
            "#{url}",
            "#{product_url}",
          ]
        },
        EXCEPTION
        exc_file.flush
        next
      end
      begin
        price = tr.children[9].text.strip
        price = price.gsub(",",".").match(/\d*\.?\d+/)[0]
      rescue
        price = 0
      end
      image_id = tr.children[1].search('img')[0].attributes["src"].value.gsub("50x50","120x120")
      file.write <<-OBJECT
      {
        "shop": "mustapekka",
        "url": "#{product_url}",
        "pid": "#{pid.downcase}",
        "name": "#{name.gsub("\\","\\\\").gsub("\"","\\\"").downcase}",
        "price": #{price},
        "image_id": "#{image_id}",
        "compatibility": [],
        "categories": [[#{cat.map{|x| %("#{x.strip.downcase.gsub("\\","\\\\").gsub("\"","\\\"")}")}.join(",")}]],
        "details": []
      },
      OBJECT
    end
  end
end
  
namespace :parser do
  desc "outputs the log to results/res, use as rake parser:parse"
  task :parse => :environment do
    first_page = Scan.first
    doc = Nokogiri::HTML(first_page.content)
    elem_list = doc.search('//li[contains(@class, "nav-icon")]')
    File.open(Rails.root.join("results/results"),'wb:UTF-8') do |file|
      File.open(Rails.root.join("results/exceptions"),'wb:UTF-8') do |exc_file|
        file.write "[\n"
        elem_list.each do |li|
          process_page li.children[1].attributes['href'].value, file: file, exc_file: exc_file
        end
        file.write "]"
      end
    end  
  end
end
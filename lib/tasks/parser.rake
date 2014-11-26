def process_page(url, maker: nil, model: nil, details: [], file: nil)
  my_file = file
  page = Scan.find_by url: url
  html_doc = Nokogiri::HTML(page.content)
  if !(elem_list = html_doc.search('div[class="varaosalista"]')).empty?
    if !elem_list.search('th:contains("Tuote")').empty?
      #Analyze product
      tbody = elem_list.search 'table'
      cat = selite = nil
      tbody.children.each do |tr|
        if !(name_node = tr.search('td[class="varaosatuote"]')).empty?
          pid = tr.search('a').text.gsub(/[-€]/,"").strip
          name = name_node.text.strip
          sopivus = tr.children[5].text.strip
          price = tr.children[7].text.strip
          begin
            price = price.gsub(",",".").match(/\d*\.?\d+/)[0]
          rescue
            price = 0
          end
          #this is product info
          raise "no category" if cat.nil?
          raise "no maker" if maker.nil?
          raise "no model" if model.nil?
          my_file.write <<-OBJECT
  {
    "shop": "motonet",
    "pid": "#{pid}",
    "name": "#{name.gsub("\\","\\\\").gsub("\"","\\\"")}",
    "price": #{price},
    "image_id": "#{pid}",
    "compatibility": [
      {"brand": "#{maker.gsub("\\","\\\\").gsub("\"","\\\"")}", "models": ["#{model.gsub("\\","\\\\").gsub("\"","\\\"")}"]}
    ],
    "categories": [
      [#{cat.split(":").map{|x| %("#{x.strip.gsub("\\","\\\\").gsub("\"","\\\"")}")}.join(",")}]
    ],
    "details": [
      [#{details.map{|x| %("#{x.strip.gsub("\\","\\\\").gsub("\"","\\\"")}")}.join(",")}]
    ]
  },
  OBJECT
        elsif !(name_node = tr.search('td[class="tuoteotsikko"]')).empty?
          cat = tr.children[0].text.strip
          selite = nil
        elsif !(name_node = tr.search('td[class="selite"]')).empty?
          selite = tr.children[0].text.strip
        end
      end
    else
      #Analyze category
      now_start = false
      count = 0
      elem_list.children.each do |elem|
        case elem.name
        when "a"
          link = elem.attributes["href"].value
          if link != url
            maker2 = maker
            model2 = model
            # This is a subcategory link
            last = link.match(/\/([^\/]+)\/?$/)[1]
            if maker2.nil?
              if file.nil? and not my_file.nil?
                my_file.write "]\n"
                my_file.close
                my_file = nil
              end
              maker2 = last
              my_file = File.open(Rails.root.join("results/#{maker2}"),'wb:UTF-8')
              my_file.write "[\n"
            elsif model2.nil?
              model2 = last.gsub(/-(19|20)\d{2}\-((19|20)\d{2})?/,"")
              model2 = model2.gsub(/-\d{2}\-(\d{2})?/,"")
            end
            process_page link, 
                        maker: maker2, 
                        model: model2, 
                        details: Array.new(details) << last,
                        file: my_file
          end
        when "h1"
          now_start = true
        when "h2"
          now_start = true
        end
      end
    end
  else
    raise "WRONG PAGE FOUND! #{url}"
  end
end

namespace :parser do
  desc "outputs the log, use as rake parser:parse > filename"
  task :parse => :environment do
    process_page Scan.first.url
  end
end
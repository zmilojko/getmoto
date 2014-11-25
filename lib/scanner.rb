require 'net/http'
require 'fileutils'
STDOUT.sync = true


# host = "teksti.motonet.fi"
# start scanning with handle_url = "varaosat/etusivu"
# trigger with: 
#   load 'scanner.rb';s=ShopScanner.new "teksti.motonet.fi";s.handle_url "varaosat/etusivu"

# ActiveRecord::Base.logger.level = 1

class ShopScanner
  def initialize host
    raise "ShopScanner requires Scan model" unless defined? Scan and
        Scan.new.is_a? ActiveRecord::Base
    @host = host
  end
  
  attr_accessor :host
  
  def full_url url
    if url[0] == "/"
      url = url[1..-1]
    end
    if url[0..2] == "fi/"
      url = url[3..-1]
    end
    if url[-1] == "/"
      url = url[0..-2]
    end
    "http://#{@host}/fi/#{url}"
  end
  
  def self.ver
    "1.2.3"
  end

  def connect url
    @http = Net::HTTP.new(@host, 80)
    @http.use_ssl = false
    r = @http.get(url)
    @cookie = {'Cookie'=>r.to_hash['set-cookie'].collect{|ea|ea[/^.*?;/]}.join}
    r.body
  end

  def get_page url
    connect url if @http.nil?
    resp = @http.get url,@cookie
    page = resp.body
  end
  
  def handle_url url
    raise "url should be without host, start without /" if 
      url.include? "http"
    
    s0 = Scan.find_or_create_by url: url
    s0.last_visited = nil
    s0.save!
      
    #first, get the page
    puts "trying to get page: #{full_url url}"
    page = get_page full_url url
    
    s0.content = page.force_encoding("UTF-8")
    #s0.save!
    
    #File.open "xxxx.txt", "w:UTF-8" do 
    #  |f| f.write page.force_encoding("UTF-8") 
    #end
    
    #second, analyze the page, and create requests for new pages
    html_doc = Nokogiri::HTML(page)
    
    # Scan.find_or_create_by(url: url)
    elem_list = html_doc.search 'div[class="varaosalista"]'
    
    now_start = false
    count = 0

    ActiveRecord::Base.transaction do
      elem_list.children.each do |elem|
        case elem.name
        when "a"
          link = elem.attributes["href"].value
          if link != url
            # This will create it
            s1 = Scan.find_or_create_by url: link
            s1.last_visited = nil
            s1.save!
            count += 1
          end
        when "h1"
          now_start = true
        when "h2"
          now_start = true
        end
      end
    end
    puts "  => queued #{count} new urls for later"
    
    s0.last_visited = DateTime.now
    s0.save!
    puts "  => done."
  end
  
  def handle_next
    s = Scan.find_by last_visited: nil
    handle_url s.url unless s.nil?
    s
  end
  
  def keep_handling
    loop { break unless handle_next }
  end
end


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
    "http#{@ssl ? "s" : ""}://#{@host}/#{url}"
  end
  
  def self.ver
    "1.2.3"
  end

  def connect(url, ssl: false)
    @http = Net::HTTP.new(@host, ssl ? 443 : 80)
    @ssl = ssl
    @http.use_ssl = ssl
    r = @http.get(full_url url)
    begin
      @cookie = {'Cookie'=>r.to_hash['set-cookie'].collect{|ea|ea[/^.*?;/]}.join}
    rescue
      @cookie = nil
    end
    r.body
  end

  def get_page url
    connect(url, ssl: true) if @http.nil?
    resp = @http.get full_url(url), @cookie
    page = resp.body
  end
  
  def analyze_doc(url, doc)
    list = []
    if url == "verkkokauppa/apple_tuotteet-576"
      elem_list = doc.search('//li[contains(@class, "nav-icon")]')
      elem_list.each do |li|
	list << li.children[1].attributes['href'].value
      end
    end
    
    # Now search for all categories, if they exist on this page
    elem_list = doc.search('span[class="category"]')
    elem_list.each do |span|
      list << span.children[0].attributes['href'].value
    end
    
    if list.empty?
      #here we want to scane products, but we should first scan multiple pages
      # mark pages other than 1, if you are on page one!
      page_list = doc.search('div[id="paging-num"]')
      unless page_list.empty? or page_list[0].children[0].nil? or page_list[0].children[0].attributes['class'].nil?
        if page_list[0].children[0].attributes['class'].value == 'current'
          # Take the last child, use it as a pattern
          last_url = page_list[0].children.last.search('a')[0].attributes["href"].value
          # should look like "/verkkokauppa/client/index/page:7?id=556"
          max_page = last_url.match(/page:(\d+)\?id/)[1].to_i
          (2..max_page).each do |page_num|
            new_page_url = last_url.gsub(/page:\d+\?id/,"page:#{page_num}?id")
            list << new_page_url
            puts "    => scheduled page: #{new_page_url}"
          end
        end
      end
      
      # ok, well, this all went fine, now let's actually analyze the pages
      product_list = doc.search('h4')
      product_list.each do |p|
        begin
          # let's be happy without actual product pages.
          #list << p.children[0].attributes['href'].value
        rescue
        end
      end
    end
    ActiveRecord::Base.transaction do
      list.each do |elem|
        s1 = Scan.find_or_create_by url: elem
        s1.last_visited = nil
        s1.save!
      end
    end
    list.count
  end
  
  def handle_next
    s = Scan.find_by last_visited: nil
    puts "getting next"
    if s.nil?
      nil
    else
      s.last_visited = nil
      
      #first, get the page
      
      page = get_page s.url
      puts "get: #{full_url s.url}"
      doc = nil
      s.content = page.force_encoding("UTF-8")
      s.save!
      doc = Nokogiri::HTML(page)
      count = analyze_doc s.url, doc
      puts "  => queued #{count} new urls for later"
   
      s.last_visited = DateTime.now
      s.save!
      puts "  => done."
      true
    end
  end
  
  def keep_handling
    loop { break unless handle_next }
  end
end


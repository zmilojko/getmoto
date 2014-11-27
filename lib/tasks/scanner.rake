namespace :scanner do
  desc "scans forever until stopped with CTRL+C"
  task :scan => :environment do
    # Following is needed to load the Scan model, if it is available.
    Scan
    require 'scanner'
    scanner = ShopScanner.new "mustapekka.fi"
    scanner.keep_handling
    puts "Believe it or not, we are done!"
  end
  
  desc 'create one unvisited url that can be used to start from. Invoke with rake scanner:seed["varaosat/etusivu"])'
  task :seed, [:url] => :environment do |t, args|
    puts "Seeding with #{args[:url]}"
    Scan.find_or_create_by url: args[:url], last_visited: nil
  end
end
require 'slop'
require_relative '../lib/product'
require_relative '../lib/leasefeed'

begin
  opts = Slop.parse strict: true do |opt|
    opt.string '-p', '--product', 'product id', required: true
    opt.bool   '-n', '--nomail', 'suppress sending emails to subscribers'
    opt.bool   '-t', '--testing'
    opt.bool   '-h', '--help' do
      puts opts
    end
  end
rescue Slop::Error => e
  puts e
  puts 'Try -h or --help'
  exit
end

ENV['GREENSUB_TEST'] = opts[:testing] ? '1' : '0'
ENV['GREENSUB_NOMAIL'] = opts[:nomail] ? '1' : '0'

logfile = File.open("log/indiv.log", File::WRONLY | File::APPEND | File::CREAT)
LOG = Logger.new(logfile, 'monthly', datetime_format: '%Y-%m-%d %H:%M:%S')
LOG.sev_threshold = Logger::INFO

product = Product.new( opts[:product] )
feed = HEBLeaseFeed.new(product)
feed.fetch
feed.parse

# frozen_string_literal: true
require 'typhoeus'
require 'nokogiri'
require_relative 'lease'
require_relative 'subscriber'

class LeaseFeed
  attr_accessor :datastream, :product

  def initialize(prod)
    @product = prod
  end
end

class HEBLeaseFeed < LeaseFeed
  #move to parent class and use config?
  def fetch
    config = YAML.load_file('config/leasefeeds.yaml')
    url = config['heb']['source']
    username = config['heb']['username']
    password = config['heb']['password']
    request = Typhoeus::Request.new(url, userpwd: "#{username}:#{password}")

    request.on_complete do |response|
      if response.success?
        LOG.info {"Download succeeded from #{url}"}
      elsif response.timed_out?
        LOG.error {"Download timed out: #{url}"}
      elsif response.code == 0
        LOG.error {response.return_message}
      else
        LOG.error {"HTTP request failed: " + response.code.to_s}
      end
    end

    request.run
    response = request.response
    @datastream = Nokogiri::XML(response.body)
  end

  #knows how to create the subscriber and determine the action
  def parse
    xml = @datastream
    feed_records = xml.xpath('/ACLSExport/acls')
    feed_records.each do |fr|
      subscriber = Individual.new( fr.xpath('email').text )
      subscriber.lastname = fr.xpath('lastname').text
      subscriber.firstname = fr.xpath('firstname').text
      subscriber.phone = fr.xpath('phone').text

      lease = Lease.new(@product, subscriber)
      fr.xpath('expirationdate').text
      exp = fr.xpath('expirationdate').text.split('-')
      if Date.valid_date?(exp[0].to_i,exp[1].to_i,exp[2].to_i)
        expiration_date = Date.parse(fr.xpath('expirationdate').text)
        lease.authorize if Date.today < expiration_date
        lease.expire(expiration_date)
      end
    end
  end
end

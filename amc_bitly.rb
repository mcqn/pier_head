#!/usr/bin/ruby
#
# amc_bitly - Simple class to access the bit.ly API to shorten URLs
#
# (c) Copyright 2009-2013 MCQN Ltd.

# Pull in our API key and username
require 'pier_head_keys'

class BitLy
  Username = BITLY_USERNAME
  APIKey = BITLY_API_KEY
  APIVersion = "2.0.1"

  def BitLy.shorten(long_url)
    resp = Net::HTTP.get_response("api.bit.ly", "/shorten?version=#{APIVersion}&longUrl="+long_url+"&login=#{Username}&apiKey=#{APIKey}")

    # Parse it looking for the short URL
    short_url = nil
    resp.body.each do |line|
      # Rather than parse the JSON, we'll just look for the "shortUrl" line
      matchinfo = line.match(/"shortUrl": "(\S*)",/)
      unless matchinfo.nil?
        # Found it, the short URL will be the matched info
puts "bit.ly matched on line: "+line
        short_url = matchinfo[1]
      end
    end

    if short_url.nil?
      # Something went wrong, just return the long one and hope that's okay
      long_url
    else
      # We've successfully shortened the URL
      short_url
    end
  end
end


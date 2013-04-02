#!/usr/bin/ruby
#
# pier_head - a script to Tweet whenever a ship is due to arrive at or leave
# the cruise liner terminal at the Pier Head in Liverpool
#
# (c) Copyright 2012-2013 MCQN Ltd.

require 'rubygems'
require 'time'
require 'net/http'
#require 'net/https'
require 'ri_cal'
require 'twitter'
#require 'nokogiri'
require 'sqlite3'
require 'tzinfo'
include TZInfo
require 'pier_head_keys'
require 'amc_bitly'

# Rather insecure way to get round the "can't post to Twitter" problem
OpenSSL::SSL::VERIFY_PEER = OpenSSL::SSL::VERIFY_NONE

# Expects the secret stuff to be in pier_head_keys.rb
Twitter.configure do |config|
  config.consumer_key = TWITTER_CONSUMER_KEY
  config.consumer_secret = TWITTER_CONSUMER_SECRET
  config.oauth_token = TWITTER_OAUTH_KEY
  config.oauth_token_secret = TWITTER_OAUTH_SECRET
end

def build_message(ship_name, short_url, arriving, minutes_before_activity)
  message = ""
  if minutes_before_activity > 0
    # Use the generic announcement
    time_message = minutes_before_activity.to_s+" minutes"
    if minutes_before_activity == 30
      time_message = " half an hour"
    end
    direction_message = "arriving"
    if arriving == 0
      direction_message = "leaving"
    end
    message = "#{ship_name} will be #{direction_message} in #{time_message}.  See #{short_url} for current position"
    # extra 29 because t.co URLs tend to be 20 chars, short_url tends to be 49 chars
    if message.length > 140+29 
      # Try something a bit shorter
      message = "#{ship_name} will be #{direction_message} #{time_message}.  See #{short_url}"
      if message.length > 140+29
        # Still too long
        message = "#{ship_name} will be #{direction_message} #{time_message}"
        if message.length > 140
          puts "####### That's one hell of a long ship"
          puts message
        end
      end
    end
  else
    # The ship is just arriving or leaving, send a more customised message
    if arriving == 1
      message = "Welcome to Liverpool #{ship_name}. We hope you enjoy your visit"
    else
      message = "So fare thee well, #{ship_name}, when you return united we will be..."
    end
  end
  message
end

def check_for_activity(database, time, minutes_before_activity)
  # Work out the limits for our time slot
  time_from = time
  time_to = time + (5*60)
  #puts "Looking from "+time_from.to_s+" to "+time_to.to_s
  #puts "which is any between "+time_from.to_i.to_s+" to "+time_to.to_i.to_s

  # Look for ships arriving
  database.execute("select rowid, * from schedules where eta >= ? and eta < ?", [time_from.to_i, time_to.to_i]).each do |arrival|
    # Tweet about it
    announce_activity(database, arrival[3], 1, minutes_before_activity)
  end

  # Look for ships departing
  database.execute("select rowid, * from schedules where etd >= ? and etd < ?", [time_from.to_i, time_to.to_i]).each do |arrival|
    # Tweet about it
    announce_activity(database, arrival[3], 0, minutes_before_activity)
  end
end

def announce_activity(database, ship_name, direction, minutes_before_activity)
  #database.execute("select rowid, * from ships where name = '?'", [ship_name]).each do |ship|
  database.execute("select rowid, * from ships where name = '#{ship_name}'").each do |ship|
    short_url = ""
    unless ship[3].nil? || ship[3].empty?
      short_url = BitLy.shorten(ship[3])
    end
    message = build_message(ship[1], short_url, direction, minutes_before_activity)
    puts message
    # Tweet about it
    begin
      Twitter.update(message)
    rescue Timeout::Error
      puts Time.now.to_s+" Timeout::Error when tweeting."
      sleep 40
    rescue
      # Not much we can do if something goes wrong, just wait for a bit
      # and then carry on
      puts Time.now.to_s+" Something went wrong when tweeting.  Error was:"
      puts $!
      sleep 40
    end
  end
end

## Open the database of ship info
db = SQLite3::Database.new "pier_head.db"

## Get the ical feed of visits
uri = URI.parse("https://views.scraperwiki.com/run/liverpool_cruise_call_schedule_icalendar/")
http = Net::HTTP.new(uri.host, 443)
http.use_ssl = true
request = Net::HTTP::Get.new(uri.request_uri)
resp = http.request(request)

cals = RiCal.parse_string(resp.body)

# Work out which 5 minute run we're working in
now = Time.now.gmtime
#now = Time.parse("2012-06-11 06:45:00")
#now = Time.parse("2012-07-20 23:00:02+0100")
puts "now was "+now.to_s
now = now-now.sec # start of the minute
now = now - (now.min*60) + (5*60*(now.min/5))

puts "now is now "+now.to_s

cals.each do |cal|
  cal.events.each do |ev|
    # Work out the ship's name
    ship = ""
    # It'll either be "<ship> (<line>) calls at..."
    if ev.summary.match(/(.+) \(.+\) calls at/)
      ship = ev.summary.match(/(.+) \(.+\) calls at/)[1]
    # or "<ship> calls at..."
    elsif ev.summary.match(/(.+) calls at/)
      ship = ev.summary.match(/(.+) calls at/)[1]
    end
    # The times are all in local time, so convert to UTC for comparisons
    tz = TZInfo::Timezone.get("Europe/London")
    start_time = tz.local_to_utc(ev.start_time)
    finish_time = tz.local_to_utc(ev.finish_time)
    #puts ev.summary
    #puts ship
    #puts start_time.to_s+" - "+finish_time.to_s
    #puts
    puts "   Finish time "+finish_time.to_s
    puts "  Looking from "+(now+(0*60)).to_datetime.to_s
    puts "    Looking to "+(now+(5*60)).to_datetime.to_s
    puts
    puts "     start_time.inspect: "+start_time.inspect
    puts "    finish_time.inspect: "+finish_time.inspect
    puts "            now.inspect: "+now.inspect
    puts "now.to_datetime.inspect: "+now.to_datetime.inspect
    puts

    # Look for ships arriving
    [30, 15, 0].each do |mins_before_activity|
      if (start_time >= (now+(mins_before_activity*60)).to_datetime) && (start_time < (now+((mins_before_activity+5)*60)).to_datetime)
        puts "Would've found a start"
	puts
      end
      if (start_time.to_s >= (now+(mins_before_activity*60)).to_datetime.to_s) && (start_time.to_s < (now+((mins_before_activity+5)*60)).to_datetime.to_s)
        puts "Ship arriving in "+mins_before_activity.to_s
	puts
        announce_activity(db, ship, 1, mins_before_activity)
      end
    end
    # And now look for ships departing
    [30, 15, 0].each do |mins_before_activity|
      if (finish_time >= (now+(mins_before_activity*60)).to_datetime) && (finish_time < (now+((mins_before_activity+5)*60)).to_datetime)
        puts "Would've found a finish"
	puts
      end
      if (finish_time.to_s >= (now+(mins_before_activity*60)).to_datetime.to_s) && (finish_time.to_s < (now+((mins_before_activity+5)*60)).to_datetime.to_s)
        puts "Ship leaving in "+mins_before_activity.to_s
	puts
        announce_activity(db, ship, 0, mins_before_activity)
      end
    end
  end
end

exit


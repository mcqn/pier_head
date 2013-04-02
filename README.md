pier_head
=========

Simple ruby script to announce cruise ship arrivals and departures at the Pier Head in Liverpool on Twitter

Expects to be called regularly (e.g. every 15 minutes via cron) to see if any events need to be announced.  Basic usage:

 1. cp pier_head_keys.example.rb pier_head_keys.rb
 1. Edit pier_head_keys.rb with your Twitter OAuth and Bit.ly API key details
 1. Every 15 minutes, run pier_head.rb

For more information see https://twitter.com/Pier_Head

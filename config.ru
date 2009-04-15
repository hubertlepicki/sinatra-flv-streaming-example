#!/usr/bin/env rackup
require File.dirname(__FILE__) + "/application"
require 'rack/contrib'
use Rack::Static, :urls => ["/index.html", "/flash", "/javascripts"], :root => "public"
use Rack::Evil
run Application

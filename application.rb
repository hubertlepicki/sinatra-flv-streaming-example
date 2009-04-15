require 'rubygems'
require 'sinatra'
require 'fileutils'

STORAGE_PATH = File.dirname(__FILE__) + "/public"

# This class is returned to Rack adapter as response.
# Rack callse "each" on it to get response body
# and sends individual responses to the client.
# This way we avoid loading whole file to memory
class FlvStream
  def initialize(filename, start_pos)
    @filename = filename
    @file = File.new(filename, "rb")
    @start_pos = start_pos
    @file.seek(@start_pos)
  end

  def each
    if @start_pos > 0
      yield "FLV\x01\x01\x00\x00\x00\x09\x00\x00\x00\x09" # If we are not starting from beggining
                                                          # we must prepend FLV header to output
      @start_pos = 0 
    end

    begin (chunk = @file.read(4*1024)) # Go and experiment with best buffer size for you
      yield chunk
    end while chunk.size == 4*1024
  end

  def length
    File.size(@filename) - @start_pos
  end
end

class Application < Sinatra::Base
  set :public, "public"

  # Catch everyting and serve as stream
  get %r((.*)) do |path|
    path = File.expand_path(STORAGE_PATH + path)
    status(401) && return unless path =~ Regexp.new(STORAGE_PATH)
    flv = FlvStream.new(path, params[:start].to_i)
    throw :response, [200, {'Content-Type' => 'application/x-flv', "Content-Length" => flv.length.to_s}, flv]
  end
end

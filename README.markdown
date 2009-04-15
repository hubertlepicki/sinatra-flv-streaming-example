FLV pseudostreaming implemented using Sinatra and Rack::Evil
------------------------------------------------------------

There are many ways you could implement FLV video streaming. The most "proper" way to do it is to use RTMP (Flash Media) Server, which you can purchase directly from Adobe. A few cheaper/free/open source alternatives exist. For me, most promissing one is [Mammoth](http://mammoth-project.org/), but it's still in early stage of development. However, most popular alternative is [Red5](http://osflash.org/red5), however I didn't find it either easy to configure or being reliable at serving files. Some big guys are using it, but it takes time and experience to set it up and maintain properly.

Here comes pseudostreaming
--------------------------

FLV pseudostreaming is a technique that allows you to simulate FLV streaming, without use of RTMP protocol. Most popular player that supports pseudostreaming if [Flowplayer](http://flowplayer.org), and they also give you nice overview of this method on [their site](http://flowplayer.org/plugins/streaming/pseudostreaming.html).

Implementations for pseudostreaming exist for Ngnix, [Lighttpd](http://blog.lighttpd.net/articles/2006/03/09/flv-streaming-with-lighttpd), Apache or [PHP](http://richbellamy.com/wiki/Flash_Streaming_to_FlowPlayer_using_only_PHP), and it's probably best if you use ones written in C (fastest). However, when you can't use Lighttpd or need to integrate FLV streaming directly into your Ruby apps, you can use mine solution.

How it works?
-------------

Pseudostreaming of FLV files is possible when you insert special frame index into file header. Most popular tool to do it is [flvtool2](http://osflash.org/flvtool2), and yes - it's written in Ruby and available as ruby gem!

    $ gem install flvtool2

To append FLV data to your movie file, use command:

    $ flvtool2 -U video_file.flv

When player starts to buffer video file via standard HTTP protocol, first thing send out is metadata that sits in file header, and pseudostreaming is possible.

But applications that serve FLV files with pseudostreaming support, must respond to specified URI scheme, that accepts "start=XXX" parameter to make it work. XXX is just an offset in bytes from beginning of file, so our application must seek to given byte and start sending output from there. It is implemented almost identical in PHP, or C (in both Ngnix and Lighttpd), and we are going to do it in Ruby.

For example, if we seek to the middle of video, Flowplayer calculates that position should be, say 2343443 bytes from start, and sends request to: http://myserver.com/myvideofile.flv?start=2343443. We need to output file from this position. Dead easy.

Not quite dead easy
-------------------

There is one problem with Ruby applications that use Rack (Rails included) - how do we actually stream a file? We could use send_file or send_data methods from within Rails, but Rack architecture forces our file to be buffered in memory, which is something we don't want to do fir 1.5GB movies.

To work this around, we will use Rack::Evil module that allows us to throw and catch custom object that will be processed as HTTP response.

First, let's get Rack::Evil, which is part of rack-contrib:

    $ gem install rack-contrib

In your config.ru file or config/environment.rb you need to enable Rack::Evil:

    require 'rack/contrib'
    ...
    use Rack::Evil
    ...

Now, in your application, in place where you need to output a file, you must construct object that responds to "each" method. You will throw this object and Rack::Evil will catch it, and call "each" on it. Each content that yields from this method, will be sent directly to user. If we implement actual file reading inside "each" method - we avoid loading whole file to memory.

    ...
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
   ...

Easy! For more information look into application.rb and config.ru files! Have fun!


Notes
-----

This is just an example how to use it, you shouldn't use this code in production but develop your own solution based on this ideas.

You must not use Rack modules like mine responseassembler that iterates on response object and process it to one string - this way you'll end up with loading all video file to memory at once.

Flowplayer binaries distributed with this source code are licensed under GPLv3, and you should read their licensing policy before using it on your site [read more](http://flowplayer.org).

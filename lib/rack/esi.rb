require 'open-uri'
require 'rack/utils'
require 'cgi'

# See http://www.w3.org/TR/edge-arch
# http://www.w3.org/TR/esi-lang
module Rack
  class ESI
    def initialize(app, opts = {})
      @app = app
      @mime_types = opts[:mime_types] || %w(application/xhtml+xml text/html text/xml application/xml)
    end

    def call(env)
      # We're cloning the environment because we want to send the includes a fresh copy of it
      # In Rails 2.3.5 + Mongrel, I was having problems unless this was done.
      original_env = env.clone
      response = @app.call(env)
      return response if !applies_to? response

      status, header, body = response

      body = process_esi(join_body(body), original_env)
      header['Content-Length'] = Rack::Utils.bytesize(body).to_s

      [status, header, [body]]
    rescue Exception => ex
      if env['rack.errors']
        env['rack.errors'].puts "#{ex.class}: #{ex.message}"
        env['rack.errors'].puts ex.backtrace.map { |l| "\t" + l }
        env['rack.errors'].flush
      end
      [500, {}, [ex.message]]
    end

    private

    # Process esi commands
    # TODO: Implement more commands if they are needed
    def process_esi(body, env)
      body.gsub!(/<esi:remove>.*?<\/esi:remove>|<esi:comment[^>]*\/>|\s*xmlns:esi=("[^"]+"|'[^']+')/, '')
      body.gsub!(/<esi:include([^>]*)(\/>|>\s*<\/esi:include>)/) do
        attr = attributes($1)
        raise ArgumentError, 'esi:include misses src attribute' if attr['src'].to_s.empty?
        fragment_status, fragment_header, fragment_body = get_fragment(env, attr['src'])
        if fragment_status != 200 && !attr['alt'].to_s.empty?
          fragment_status, fragment_header, fragment_body = get_fragment(env, attr['alt'])
          if fragment_status != 200
            raise RuntimeError, "esi:include failed to include alt fragment #{attr['alt']} (Error #{fragment_status})" if attr['onerror'] != 'continue'
          end
        end
        if fragment_status != 200
          raise RuntimeError, "esi:include failed to include fragment #{attr['src']} (Error #{fragment_status})" if attr['onerror'] != 'continue'
        else
          join_body(fragment_body)
        end
      end
      body
    end

    # Fetch fragment from backend
    def get_fragment(env, src)
      if src =~ %r{^\w+://}
        get_remote_fragment(env, src)
      else
        get_local_fragment(env, src)
      end
    rescue Exception => ex
      [500, {}, '']
    end

    def get_local_fragment(env, src)
      uri = env['REQUEST_URI'] || env['PATH_INFO']
      i = uri.index('?')
      uri = src + (i ? uri[i..-1] : '')
      inclusion_env = env.merge('PATH_INFO' => src,
                                'REQUEST_PATH' => src,
                                'REQUEST_URI' => uri,
                                'REQUEST_METHOD' => 'GET')
      inclusion_env.delete('rack.request')
      @app.call(inclusion_env)
    end

    def get_remote_fragment(env, src)
      uri = URI.parse(src)
      raise ArgumentError, "Invalid URI #{src} for fragment inclusion" if !uri.respond_to? :read
      content = uri.read
      headers = Hash[*content.meta.map do |key, value|
        [key.split('-').map {|x| x.capitalize }.join('-'), value]
      end.flatten]
      [200, headers, [content]]
    end

    # Parse xml attributes
    def attributes(attrs)
      Hash[*attrs.scan(/\s*([^=]+)=("[^"]+"|'[^']+')\s*/).map {|a,b| [a, CGI.unescapeHTML(b[1...-1])] }.flatten]
    end

    # Check if esi processing applies to response
    def applies_to?(response)
      status, header, body = response

      # Some stati don't have to be processed
      return false if [301, 302, 303, 307].include?(status)

      # Check mime type
      return false if @mime_types.all? do |type|
        !header['Content-Type'].to_s.include?(type)
      end

      # Find ESI tags
      response[2] = [body = join_body(body)]
      body.include?('<esi:')
    end

    # Join response body
    def join_body(body)
      result = ''
      body.each { |part| result << part }
      result.force_encoding('binary') if RUBY_VERSION > '1.9'
      result
    end
  end
end

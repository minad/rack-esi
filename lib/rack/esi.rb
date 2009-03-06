# See http://www.w3.org/TR/edge-arch
# http://www.w3.org/TR/esi-lang
module Rack
  class ESI
    def initialize(app, opts = {})
      @app = app
      @mime_types = opts[:mime_types] || %w(application/xhtml+xml text/html text/xml application/xml)
      @no_cache = opts[:no_cache] || false
    end

    def call(env)
      response = @app.call(env)
      return response if !applies_to? response

      status, header, body = response

      body = process_esi(body.first, env)

      header['Content-Length'] = body.size.to_s

      if @no_cache
        # Client side caching information is removed because it might not apply to the whole document
	# TODO: Think about a better way to do this without destroying caching information
	# maybe merging "Cache-Control" headers from every fragment
        header.reject! {|key,value| %w(cache-control expires last-modified etag).include?(key.to_s.downcase) }
      end

      [status, header, [body]]
    end

    private

    # Process esi commands
    # TODO: Implement more commands if they are needed
    def process_esi(body, env)
      body.gsub!(/<esi:remove>.*?<\/esi:remove>|<esi:comment[^>]*\/>|\s*xmlns:esi=("[^"]+"|'[^']+')/, '')
      body.gsub!(/<esi:include([^>]*)\/>/) do
        attr = attributes($1)
        raise ArgumentError, 'esi:include misses src attribute' if attr['src'].to_s.empty?
        fragment_status, fragment_header, fragment_body = get_fragment(env, attr['src'])
        if fragment_status != 200 && !attr['alt'].to_s.empty?
          fragment_status, fragment_header, fragment_body = get_fragment(env, attr['alt'])
        end
        if fragment_status != 200 && attr['onerror'] != 'continue'
          raise RuntimeError, "esi:include failed to include fragment #{attr['src']}"
        end
        join_body(fragment_body)
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
      env['rack.errors'].write("Failed to fetch fragment #{src}: #{ex.message}") if env['rack.errors']
      [500,{},nil]
    end

    def get_local_fragment(env, src)
      uri = env['REQUEST_URI'] || env['PATH_INFO']
      i = uri.index('?')
      uri = src + (i ? uri[i..-1] : '')
      inclusion_env = env.merge('PATH_INFO' => src,
                                'REQUEST_PATH' => src,
                                'REQUEST_URI' => uri,
                                'REQUEST_METHOD' => 'GET')
      @app.call(inclusion_env)
    end

    def get_remote_fragment(env, src)
      require 'open-uri'
      [200, {}, open(src).read]
    end

    # Parse xml attributes
    def attributes(attrs)
      Hash[*attrs.split(/\s+/).map {|x| x =~ /^([^=]+)=("[^"]+"|'[^']+')$/ ? [$1, $2[1...-1]] : nil }.compact.flatten]
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
      parts = ''
      body.each { |part| parts << part }
      parts
    end
  end
end

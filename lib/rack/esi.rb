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
      status, header, body = response = @app.call(env)
      return response if !applies_to?(header)

      processed_body = join_body(body)

      if !processed_body.include?('<esi:')
        body.rewind if body.respond_to?(:rewind) rescue nil
        return response
      end

      processed_body = process_esi(processed_body, env)

      header['Content-Length'] = processed_body.size.to_s

      if @no_cache
        # Client side caching information is removed because it might not apply to the whole document
        header.reject! {|key,value| %w(cache-control expires last-modified etag).include?(key.to_s.downcase) }
      end

      [status, header, [processed_body]]
    end

    private

    # Process esi commands
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
      uri = env['REQUEST_URI'] || env['PATH_INFO']
      i = uri.index('?')
      uri = src + (i ? uri[i..-1] : '')
      inclusion_env = env.merge('PATH_INFO' => src,
                                'REQUEST_PATH' => src,
                                'REQUEST_URI' => uri,
                                'REQUEST_METHOD' => 'GET')
      @app.call(inclusion_env)
    rescue
      [500,{},nil]
    end

    # Parse xml attributes
    def attributes(attrs)
      Hash[*attrs.split(/\s+/).map {|x| x =~ /^([^=]+)=("[^"]+"|'[^']+')$/ ? [$1, $2[1...-1]] : nil }.compact.flatten]
    end

    # Check if esi processing applies to response
    def applies_to?(header)
      @mime_types.any? do |type|
        header['Content-Type'].to_s.include?(type)
      end
    end

    # Join response body
    def join_body(body)
      parts = ''
      body.each { |part| parts << part }
      parts
    end
  end
end

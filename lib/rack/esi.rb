require 'open-uri'

# See http://www.w3.org/TR/edge-arch
# http://www.w3.org/TR/esi-lang
module Rack
  class ESI
    def initialize(app, opts = {})
      @app = app
      @mime_types = opts[:mime_types] || %w(application/xhtml+xml text/html text/xml application/xml)
      @no_cache = opts[:no_cache] || false
      @merge_cache = opts[:merge_cache] || false
    end

    def call(env)
      response = @app.call(env)
      return response if !applies_to? response

      status, header, body = response

      headers, body = process_esi(body.first, env)
      header['Content-Length'] = body.size.to_s

      if @no_cache
        destroy_cache_headers(header)
      elsif @merge_cache
        merge_cache_headers(header, headers)
      end

      [status, header, [body]]
    end

    private

    # Merge all caching headers
    def merge_cache_headers(result, headers)
      headers << result

      last_modified = headers.map { |h| h['Last-Modified'] }.compact.map {|t| Time.httpdate(t) }.sort.last
      result['Last-Modified'] = last_modified.httpdate if last_modified

      last_modified = headers.map { |h| h['Expires'] }.compact.map {|t| Time.httpdate(t) }.sort.first
      result['Expires'] = last_modified.httpdate if last_modified

      cache_controls = headers.map { |h| (h['Cache-Control'] || 'no-cache').split(/\s*,\s*/) }.flatten

      cache = []
      cache << 'no-cache' if cache_controls.include?('no-cache')
      cache << 'no-store' if cache_controls.include?('no-store')
      cache << 'private' if cache_controls.include?('private')
      cache << 'must-revalidate' if cache_controls.include?('must-revalidate')

      max_age = cache_controls.select {|c| c =~ /^(max-age|s-maxage)/ }.map { |c| c.split('=')[1].to_i }.sort.first
      cache << "max-age=#{max_age}" << "s-maxage=#{max_age}" if max_age

      result['Cache-Control'] = cache.join(', ')
    end

    # Caching headers are destroyed because they might not apply to the whole document
    def destroy_cache_headers(header)
      header.reject! {|key,value| %w(cache-control expires last-modified etag).include?(key.to_s.downcase) }
    end

    # Process esi commands
    # TODO: Implement more commands if they are needed
    def process_esi(body, env)
      headers = []
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
        headers << fragment_header
        join_body(fragment_body)
      end
      [headers, body]
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
      [200, headers, content]
    end

    # Parse xml attributes
    def attributes(attrs)
      Hash[*attrs.scan(/\s*([^=]+)=("[^"]+"|'[^']+')\s*/).map {|a,b| [a, b[1...-1]] }.flatten]
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

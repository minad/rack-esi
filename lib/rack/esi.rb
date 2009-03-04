# See http://www.w3.org/TR/edge-arch
# http://www.w3.org/TR/esi-lang
module Rack
  class ESI
    def initialize(app)
      @app = app
    end

    def call(env)
      env.delete 'HTTP_IF_NONE_MATCH'
      env.delete 'HTTP_IF_MODIFIED_SINCE'

      status, header, body = response = @app.call(env)
      return response if !xml?(header)

      body = join_body(body)

      return response unless body.include?('<esi:')

      body = process_esi(body, env)

      header['Content-Length'] = body.size.to_s
      [status, header, [body]]
    end

    private

    def process_esi(body, env)
      body.gsub!(/<esi:remove>.*?<\/esi:remove>|<esi:comment[^>]*\/>|\s*xmlns:esi=("[^"]+"|'[^']+')/, '')
      body.gsub!(/<esi:include\s+src=("[^"]+"|'[^']+')\s*\/>/) do
        src = $1[1..-2]
        uri = env['REQUEST_URI'] || env['PATH_INFO']
        i = uri.index('?')
        uri = src + (i ? uri[i..-1] : '')
        inclusion_env = env.merge('PATH_INFO' => src,
                                  'REQUEST_PATH' => src,
                                  'REQUEST_URI' => uri,
                                  'REQUEST_METHOD' => 'GET')
        join_body(@app.call(inclusion_env)[2]) # FIXME: Check the status
      end
      body
    end

    def xml?(header)
      # FIXME: Use another pattern
      header['Content-Type'].to_s =~ /(ht|x)ml/
    end

    def join_body(body)
      parts = ''
      body.each { |part| parts << part }
      parts
    end
  end
end

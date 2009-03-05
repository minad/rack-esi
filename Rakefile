require 'hoe'

namespace('notes') do
  task('todo')      do; system('ack TODO');      end
  task('fixme')     do; system('ack FIXME');     end
  task('hack')      do; system('ack HACK');      end
  task('warning')   do; system('ack WARNING');   end
  task('important') do; system('ack IMPORTANT'); end
end

desc 'Show annotations'
task('notes' => %w(notes:todo notes:fixme notes:hack notes:warning notes:important))

Hoe.new "rack-esi", '0.1.2' do |x|
  x.developer 'Christoffer Sawicki', 'christoffer.sawicki@gmail.com'
  x.developer 'Daniel Mendler', 'mail@daniel-mendler.de'
end


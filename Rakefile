require 'hoe'

namespace("tasks") do
  desc("Show TODOs")
  task("todo") do
    system("ack TODO:")
  end

  desc("Show FIXMEs")
  task("fixme") do
    system("ack FIXME:")
  end
end

desc("Show TODOs and FIXMEs")
task("tasks" => ["tasks:todo", "tasks:fixme"])

Hoe.new "rack-esi", '0.1' do |x|
  x.developer 'Christoffer Sawicki', 'christoffer.sawicki@gmail.com'
  x.developer 'Daniel Mendler', 'mail@daniel-mendler.de'
end


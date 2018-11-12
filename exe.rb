require 'json'

ARGV.each do|a|
  puts "Argument: #{a}"
end

json = JSON.parse(File.read('ecs-task.json'))
puts "#{json}"

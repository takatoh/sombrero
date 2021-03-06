require 'boot'
require 'model/photo'

ds = Photo.order_by("id")
photos = ds.all

photos.each do |p|
  puts "#{p[:id]}:"
  puts "  url:         #{p[:url]}"
  puts "  pate url:    #{p[:page_url]}"
  puts "  size:        #{p[:width]}x#{p[:height]}"
  puts "  file size:   #{p[:filesize]}"
  puts "  md5:         #{p[:md5]}"
  puts "  path:        #{p[:path]}"
  puts "  sample path: #{p[:sample_path]}"
  puts "  thumb path:  #{p[:thumbnail_path]}"
end


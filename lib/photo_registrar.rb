#
#  PhotoRegistrar  -  Register to database and store to filesystem.
#
#  options:
#    :ignore_media_type
#    :keep
#    :force
#


require 'fileutils'
require 'pathname'
require 'digest/md5'

require 'model'
require 'file_fetcher'
require 'photo_storage'


class PhotoRegistrar

  class Rejection < StandardError
    attr_reader :details

    def initialize(mes = nil, opt = {})
      super(mes)
      @details = opt
    end
  end


  def initialize(options = {})
    @options = options
  end


  def clip(photo_info)
    c = FileFetcher.fetch(
      photo_info[:url],
      :ignore_media_type => @options[:ignore_media_type]
    )
    fname = Pathname.new("./tmp") + chop_query(c[:filename])
    if File.extname(fname).empty?
      ext = /format=([a-z]+)/.match(c[:filename])[1]
      fname = fname.sub_ext("." + ext)
    end
    File.open(fname, "wb"){|f| f.write(c[:body])}

    post(fname, photo_info)
  end


  def post(file, photo_info)
    file = Pathname.new(file) if file.instance_of?(String)
    width, height = image_size(file)
    if small_image?(width, height)
      raise Rejection.new(
        "Small photo: #{width}x#{height}",
        {
          :url  => photo_info[:url],
          :size => "#{width}x#{height}"
        }
      )
    end

    content = File.open(file, "rb"){|f| f.read}
    md5 = Digest::MD5.hexdigest(content)

    photo =  Photo.find(:md5 => md5)
    if photo
      url_posted = photo.url_posted?(photo_info[:url])
      if url_posted || !(@options[:force])
        raise Rejection.new(
          "Already exist: #{md5}",
          {
            :url        => photo_info[:url],
            :page_url   => photo_info[:page_rul],
            :tags       => photo_info[:tags],
            :url_posted => url_posted,
            :md5        => md5,
            :photo      => photo
          }
        )
      end
    else
      storage = PhotoStorage.new(SOMBRERO_CONFIG["storage"])
      filename = md5 + File.extname(file)
      path, thumbnail_path, sample_path = storage.store(content, filename)
      photo = Photo.create(
        {
          :width          => width,
          :height         => height,
          :filesize       => content.size,
          :md5            => md5,
          :path           => path,
          :sample_path    => sample_path,
          :thumbnail_path => thumbnail_path,
          :posted_date    => Time.now
        }
      )
    end
    photo.add_tags(photo_info[:tags])
    photo.save

    post = Post.create(
      {
        :url         => photo_info[:url],
        :page_url    => photo_info[:page_url],
        :posted_date => Time.now
      }
    )
    post.photo = photo
    post.save
    img = nil
    photo
  ensure
    FileUtils.rm(file) if file.exist? && !@options[:keep]
  end


  def add_tags(file, tags)
    file = Pathname.new(file) if file.instance_of?(String)
    content = File.open(file, "rb"){|f| f.read}
    md5 = Digest::MD5.hexdigest(content)
    photo =  Photo.find(:md5 => md5)
    added_tags = photo.add_tags(tags)
    photo.save
    if added_tags && !added_tags.empty?
      added_tags.map(&:name).join(" ")
    else
      nil
    end
  end


  private

  def small_image?(w, h)
    min_width = SOMBRERO_CONFIG["minimum_photo_width"]
    min_height = SOMBRERO_CONFIG["minimum_photo_height"]
    w < min_width || h < min_height
  end


  def chop_query(url)
    url.sub(/[\?\:].+\z/, "")
  end


  def image_size(file)
    `identify -format "%[width] %[height]" #{file}`.split(" ").map(&:to_i)
  end

end   # of class PhotoRegistrar

class CreatePhotos < Sequel::Migration
  def up
    create_table :photos do
      primary_key :id
      integer     :width
      integer     :height
      integer     :filesize
      string      :md5

      string      :path
      string      :sample_path
      string      :thumbnail_path

      timestamp   :posted_date
    end
  end

  def down
    drop_table :photos
  end
end



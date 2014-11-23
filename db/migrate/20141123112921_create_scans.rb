class CreateScans < ActiveRecord::Migration
  def change
    create_table :scans do |t|
      t.string :url
      t.string :type
      t.string :content
      t.datetime :last_visited

      t.timestamps
    end
    add_index(:scans, :url, unique: true)
  end
end

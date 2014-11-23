class CreateScans < ActiveRecord::Migration
  def change
    create_table :scans do |t|
      t.string :url
      t.string :type
      t.text :content, limit: 4294967295
      t.datetime :last_visited

      t.timestamps
    end
    add_index(:scans, :url, unique: true)
    change_column :scans, :content, :text, :limit => 4294967295
  end
end

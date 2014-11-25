class AddIndexToScans < ActiveRecord::Migration
  def change
    add_index(:scans, :last_visited, unique: false)
  end
end

# ============================================================================
# FILE: db/migrate/20241127000001_create_rounds.rb
# NOTE: Replace timestamp with current: rails g migration CreateRounds
# ============================================================================
class CreateRounds < ActiveRecord::Migration[7.1]
  def change
    create_table :rounds do |t|
      t.string :name, null: false
      t.integer :roi, null: false
      t.integer :jackpot_percent, null: false
      t.bigint :pot, default: 0
      t.bigint :minimum_deposit, null: false
      t.bigint :maximum_deposit, null: false
      t.integer :expiration, null: false
      t.integer :decay, null: false
      t.integer :state, default: 0
      t.integer :house_initial_fee, null: false
      t.integer :house_pot_fee, null: false
      t.integer :house_deposit_fee, null: false
      t.bigint :total_deposits, default: 0
      t.string :first_payout_address, null: false
      t.boolean :job_exists, default: false
      t.string :jackpot_address

      t.timestamps
    end
    
    add_index :rounds, :name, unique: true
    add_index :rounds, :jackpot_address, unique: true
    add_index :rounds, :state
  end
end

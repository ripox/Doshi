# ============================================================================
# FILE: db/migrate/20241127000002_create_deposits.rb
# NOTE: Replace timestamp with current: rails g migration CreateDeposits
# ============================================================================
class CreateDeposits < ActiveRecord::Migration[7.1]
  def change
    create_table :deposits do |t|
      t.references :round, null: false, foreign_key: true
      t.string :deposit_address, null: false
      t.string :payout_address, null: false
      t.boolean :confirmed, default: false
      t.bigint :amount
      t.string :ip, null: false
      t.string :user_agent
      t.string :payout_txid
      t.boolean :paid, default: false
      t.datetime :confirmed_at
      t.string :deposit_txid

      t.timestamps
    end
    
    add_index :deposits, :deposit_address, unique: true
    add_index :deposits, :confirmed
    add_index :deposits, :paid
    add_index :deposits, :confirmed_at
  end
end

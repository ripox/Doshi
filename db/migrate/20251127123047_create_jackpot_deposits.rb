# ============================================================================
# FILE: db/migrate/20241127000003_create_jackpot_deposits.rb
# NOTE: Replace timestamp with current: rails g migration CreateJackpotDeposits
# ============================================================================
class CreateJackpotDeposits < ActiveRecord::Migration[7.1]
  def change
    create_table :jackpot_deposits do |t|
      t.references :round, null: false, foreign_key: true
      t.bigint :amount, null: false
      t.string :deposit_txid, null: false

      t.timestamps
    end
    
    add_index :jackpot_deposits, :deposit_txid, unique: true
  end
end
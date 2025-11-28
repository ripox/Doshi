# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.1].define(version: 2025_11_28_102258) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "deposits", force: :cascade do |t|
    t.bigint "round_id", null: false
    t.string "deposit_address", null: false
    t.string "payout_address", null: false
    t.boolean "confirmed", default: false
    t.bigint "amount"
    t.string "ip", null: false
    t.string "user_agent"
    t.string "payout_txid"
    t.boolean "paid", default: false
    t.datetime "confirmed_at"
    t.string "deposit_txid"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["confirmed"], name: "index_deposits_on_confirmed"
    t.index ["confirmed_at"], name: "index_deposits_on_confirmed_at"
    t.index ["deposit_address"], name: "index_deposits_on_deposit_address", unique: true
    t.index ["paid"], name: "index_deposits_on_paid"
    t.index ["round_id"], name: "index_deposits_on_round_id"
  end

  create_table "jackpot_deposits", force: :cascade do |t|
    t.bigint "round_id", null: false
    t.bigint "amount", null: false
    t.string "deposit_txid", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["deposit_txid"], name: "index_jackpot_deposits_on_deposit_txid", unique: true
    t.index ["round_id"], name: "index_jackpot_deposits_on_round_id"
  end

  create_table "rounds", force: :cascade do |t|
    t.string "name", null: false
    t.integer "roi", null: false
    t.integer "jackpot_percent", null: false
    t.bigint "pot", default: 0
    t.bigint "minimum_deposit", null: false
    t.bigint "maximum_deposit", null: false
    t.integer "expiration", null: false
    t.integer "decay", null: false
    t.integer "state", default: 0
    t.integer "house_initial_fee", null: false
    t.integer "house_pot_fee", null: false
    t.integer "house_deposit_fee", null: false
    t.bigint "total_deposits", default: 0
    t.string "first_payout_address", null: false
    t.boolean "job_exists", default: false
    t.string "jackpot_address"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["jackpot_address"], name: "index_rounds_on_jackpot_address", unique: true
    t.index ["name"], name: "index_rounds_on_name", unique: true
    t.index ["state"], name: "index_rounds_on_state"
  end

  add_foreign_key "deposits", "rounds"
  add_foreign_key "jackpot_deposits", "rounds"
end

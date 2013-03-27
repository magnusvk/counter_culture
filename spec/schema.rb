# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended to check this file into your version control system.

ActiveRecord::Schema.define(:version => 20120522160158) do

  create_table "companies", :force => true do |t|
    t.string   "name"
    t.integer  "industry_id"
    t.integer  "reviews_count",       :default => 0, :null => false
    t.integer  "using_count",         :default => 0, :null => false
    t.integer  "tried_count",         :default => 0, :null => false
    t.integer  "managers_count",      :default => 0, :null => false
  end

  create_table "industries", :force => true do |t|
    t.string   "name"
    t.integer  "reviews_count",       :default => 0, :null => false
    t.integer  "rexiews_count",       :default => 0, :null => false
    t.integer  "using_count",         :default => 0, :null => false
    t.integer  "tried_count",         :default => 0, :null => false
  end

  create_table "products", :force => true do |t|
    t.string   "name"
    t.integer  "reviews_count",       :default => 0, :null => false
    t.integer  "rexiews_count",       :default => 0, :null => false
    t.integer  "category_id"
  end

  create_table "reviews", :force => true do |t|
    t.string   "review_type",                :default => "using"
    t.string   "some_text"
    t.integer  "user_id"
    t.integer  "product_id"
  end

  create_table "users", :force => true do |t|
    t.string   "name"
    t.integer  "company_id"
    t.integer  "manages_company_id"
    t.integer  "reviews_count",       :default => 0, :null => false
    t.integer  "using_count",         :default => 0, :null => false
    t.integer  "tried_count",         :default => 0, :null => false
  end

  create_table "categories", :force => true do |t|
    t.string   "name"
    t.integer  "products_count",       :default => 0, :null => false
  end

end

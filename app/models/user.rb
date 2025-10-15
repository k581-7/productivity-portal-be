ActiveRecord::Base.extend ActiveRecord::Enum

class User < ApplicationRecord
  enum :role, { developer: 0, leader: 1, junior: 2, guest: 3 }

  has_many :daily_prods
  has_many :suppliers, foreign_key: 'assigned_pic_id'
  has_many :summary_dashboards

  has_many :prod_entries_entered, class_name: 'ProdEntry', foreign_key: 'entered_by_user_id'
  has_many :prod_entries_assigned, class_name: 'ProdEntry', foreign_key: 'assigned_user_id'
end
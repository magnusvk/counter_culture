class PurchaseOrder < ActiveRecord::Base

  has_many :purchase_order_items, dependent: :destroy
end

class PurchaseOrder < ActiveRecord::Base
  attribute :total_amount, :money

  has_many :purchase_order_items, dependent: :destroy

  if PapertrailSupport.supported_here?
    has_paper_trail
  end
end

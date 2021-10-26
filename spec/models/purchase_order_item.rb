class PurchaseOrderItem < ActiveRecord::Base

  belongs_to :purchase_order
  counter_culture :purchase_order, column_name: 'total_amount', delta_column: 'amount'

  if PapertrailSupport.supported_here?
    has_paper_trail
  end
end

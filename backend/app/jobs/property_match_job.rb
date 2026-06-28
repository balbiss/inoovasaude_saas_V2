class PropertyMatchJob < ApplicationJob
  queue_as :default

  def perform(_property_id)
    # Não utilizado no InoovaSaúde (clínicas)
  end
end

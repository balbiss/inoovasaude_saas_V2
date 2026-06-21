class ServicesController < ApplicationController
  before_action :set_service, only: %i[show update destroy]

  def index
    @services = current_user.account.services.with_attached_image.order(:name)
    render json: @services.map { |s| serialize(s) }
  end

  def show
    render json: serialize(@service)
  end

  def create
    @service = current_user.account.services.new(service_params)
    @service.image.attach(params[:service][:image]) if params.dig(:service, :image).present?
    if @service.save
      render json: serialize(@service), status: :created
    else
      render json: @service.errors, status: :unprocessable_entity
    end
  end

  def update
    @service.image.attach(params[:service][:image]) if params.dig(:service, :image).present?
    if params.dig(:service, :remove_image) == 'true'
      @service.image.purge
    end
    if @service.update(service_params)
      render json: serialize(@service)
    else
      render json: @service.errors, status: :unprocessable_entity
    end
  end

  def destroy
    @service.destroy!
    head :no_content
  end

  private

  def set_service
    @service = current_user.account.services.with_attached_image.find(params[:id])
  end

  def service_params
    params.require(:service).permit(:name, :description, :duration_minutes, :price, :category, :status)
  end

  def serialize(s)
    host = ENV['API_HOST'] || 'http://localhost:3000'
    s.as_json.merge(
      image_url: s.image.attached? ? Rails.application.routes.url_helpers.rails_blob_url(s.image, host: host) : nil
    )
  end
end

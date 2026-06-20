class ServicesController < ApplicationController
  before_action :set_service, only: %i[show update destroy]

  def index
    @services = current_user.account.services.order(:name)
    render json: @services
  end

  def show
    render json: @service
  end

  def create
    @service = current_user.account.services.new(service_params)
    if @service.save
      render json: @service, status: :created
    else
      render json: @service.errors, status: :unprocessable_entity
    end
  end

  def update
    if @service.update(service_params)
      render json: @service
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
    @service = current_user.account.services.find(params[:id])
  end

  def service_params
    params.require(:service).permit(:name, :description, :duration_minutes, :price, :category, :status)
  end
end

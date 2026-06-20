class ProfessionalsController < ApplicationController
  before_action :set_professional, only: %i[show update destroy]

  def index
    @professionals = current_user.account.professionals.order(:name)
    render json: @professionals
  end

  def show
    render json: @professional
  end

  def create
    @professional = current_user.account.professionals.new(professional_params)
    if @professional.save
      render json: @professional, status: :created
    else
      render json: @professional.errors, status: :unprocessable_entity
    end
  end

  def update
    if @professional.update(professional_params)
      render json: @professional
    else
      render json: @professional.errors, status: :unprocessable_entity
    end
  end

  def destroy
    @professional.destroy!
    head :no_content
  end

  private

  def set_professional
    @professional = current_user.account.professionals.find(params[:id])
  end

  def professional_params
    params.require(:professional).permit(:name, :specialty, :council_number, :phone, :email, :bio, :status)
  end
end

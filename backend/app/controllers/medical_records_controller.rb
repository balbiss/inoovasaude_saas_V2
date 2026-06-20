class MedicalRecordsController < ApplicationController
  before_action :set_record, only: %i[show update destroy]

  def index
    scope = current_user.account.medical_records.includes(:patient, :professional, :appointment)
    scope = scope.where(patient_id: params[:patient_id]) if params[:patient_id]
    scope = scope.where(professional_id: params[:professional_id]) if params[:professional_id]
    render json: scope.order(created_at: :desc).as_json(
      include: {
        patient:      { only: %i[id name phone] },
        professional: { only: %i[id name specialty] },
        appointment:  { only: %i[id appointment_date start_time] }
      }
    )
  end

  def show
    render json: @record.as_json(
      include: {
        patient:      { only: %i[id name phone] },
        professional: { only: %i[id name specialty] }
      }
    )
  end

  def create
    @record = current_user.account.medical_records.new(record_params)
    @record.recorded_by_id = current_user.id
    if @record.save
      render json: @record, status: :created
    else
      render json: @record.errors, status: :unprocessable_entity
    end
  end

  def update
    if @record.update(record_params)
      render json: @record
    else
      render json: @record.errors, status: :unprocessable_entity
    end
  end

  def destroy
    @record.destroy!
    head :no_content
  end

  private

  def set_record
    @record = current_user.account.medical_records.find(params[:id])
  end

  def record_params
    params.require(:medical_record).permit(
      :patient_id, :professional_id, :appointment_id,
      :chief_complaint, :diagnosis, :prescription, :notes
    )
  end
end

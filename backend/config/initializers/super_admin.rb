if Rails.env.production? && ENV['SUPER_ADMIN_EMAIL'].present?
  Rails.application.config.after_initialize do
    begin
      next unless ActiveRecord::Base.connection.table_exists?(:users)
      next if User.exists?(email: ENV['SUPER_ADMIN_EMAIL'])

      account = Account.find_or_create_by(name: 'InoovaSaúde') do |a|
        a.subscription_status = 'active'
        a.trial_ends_at = 100.years.from_now
      end

      User.create!(
        email:                 ENV['SUPER_ADMIN_EMAIL'],
        password:              ENV['SUPER_ADMIN_PASSWORD'],
        password_confirmation: ENV['SUPER_ADMIN_PASSWORD'],
        first_name:            'Super',
        last_name:             'Admin',
        role:                  :admin,
        account:               account
      )

      Rails.logger.info "[SuperAdmin] Criado com sucesso: #{ENV['SUPER_ADMIN_EMAIL']}"
    rescue => e
      Rails.logger.error "[SuperAdmin] Erro ao criar: #{e.message}"
    end
  end
end

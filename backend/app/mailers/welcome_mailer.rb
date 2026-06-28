class WelcomeMailer < ApplicationMailer
  DEPT_LABELS = {
    'medico'     => 'Médico(a)',
    'secretaria' => 'Secretária',
    'suporte'    => 'Suporte',
    'financeiro' => 'Financeiro',
    'admin'      => 'Administrador'
  }.freeze

  def company_welcome(user, account)
    @user      = user
    @account   = account
    @login_url = "#{ENV.fetch('FRONTEND_URL', 'https://crmchat.visitaia.com.br')}/login"
    @app_name  = ENV.fetch('APP_NAME', 'InoovaSaúde')

    mail(
      to:      user.email,
      subject: "🎉 Sua clínica está pronta no #{@app_name}!"
    )
  end

  def welcome(user, plain_password)
    @user           = user
    @plain_password = plain_password
    @dept_label     = DEPT_LABELS[user.role] || 'Profissional'
    @login_url      = "#{ENV.fetch('FRONTEND_URL', 'https://crmchat.visitaia.com.br')}/login"
    @app_name       = ENV.fetch('APP_NAME', 'VisitaIA CRM')

    mail(
      to:      user.email,
      subject: "Bem-vindo(a) ao #{@app_name}! Seus dados de acesso"
    )
  end
end

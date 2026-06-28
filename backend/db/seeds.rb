# Clear existing data
MedicalRecord.destroy_all
Appointment.destroy_all
Professional.destroy_all
Service.destroy_all
Message.destroy_all
Conversation.destroy_all
Contact.destroy_all
User.destroy_all
Account.destroy_all

# Account
account = Account.create!(
  name: 'Clínica Saúde Total',
  subscription_status: 'active',
  trial_ends_at: 30.days.from_now
)

# Usuário owner (secretaria/admin)
owner = User.create!(
  account: account,
  email: 'admin@clinica.com',
  password: '123456',
  password_confirmation: '123456',
  first_name: 'Guilherme',
  last_name: 'Balbis',
  role: :secretaria
)

# Atendente
atendente = User.create!(
  account: account,
  email: 'atendente@clinica.com',
  password: '123456',
  password_confirmation: '123456',
  first_name: 'Maria',
  last_name: 'Silva',
  role: :medico
)

# Profissionais
prof1 = Professional.create!(
  account: account,
  name: 'Dr. Carlos Mendes',
  specialty: 'Médico',
  council_number: 'CRM 12345-SP',
  phone: '(11) 99001-0001',
  email: 'carlos@clinica.com',
  bio: 'Clínico geral com 15 anos de experiência.',
  status: 'active'
)

prof2 = Professional.create!(
  account: account,
  name: 'Dra. Ana Oliveira',
  specialty: 'Psicólogo',
  council_number: 'CRP 06/78901',
  phone: '(11) 99002-0002',
  email: 'ana@clinica.com',
  bio: 'Psicóloga clínica, especialista em TCC.',
  status: 'active'
)

prof3 = Professional.create!(
  account: account,
  name: 'Dra. Fernanda Costa',
  specialty: 'Nutricionista',
  council_number: 'CRN 3-45678',
  phone: '(11) 99003-0003',
  email: 'fernanda@clinica.com',
  bio: 'Nutricionista com foco em emagrecimento e reeducação alimentar.',
  status: 'active'
)

# Serviços
serv1 = Service.create!(
  account: account,
  name: 'Consulta Clínica Geral',
  description: 'Consulta médica clínica geral, retorno em 30 dias.',
  duration_minutes: 30,
  price: 150.00,
  category: 'Consulta',
  status: 'active'
)

serv2 = Service.create!(
  account: account,
  name: 'Sessão de Psicologia',
  description: 'Sessão de psicoterapia individual (TCC).',
  duration_minutes: 50,
  price: 200.00,
  category: 'Terapia',
  status: 'active'
)

serv3 = Service.create!(
  account: account,
  name: 'Consulta Nutricional',
  description: 'Avaliação nutricional completa com plano alimentar.',
  duration_minutes: 60,
  price: 180.00,
  category: 'Nutrição',
  status: 'active'
)

serv4 = Service.create!(
  account: account,
  name: 'Retorno / Acompanhamento',
  description: 'Consulta de retorno para acompanhamento do tratamento.',
  duration_minutes: 20,
  price: 80.00,
  category: 'Retorno',
  status: 'active'
)

# Pacientes
paciente1 = Contact.create!(
  account: account,
  name: 'João Pedro Alves',
  email: 'joao@example.com',
  phone: '+55 11 98888-0001',
  funnel_stage: 'agendado',
  temperature: 'quente',
  source: 'whatsapp',
  blood_type: 'A+',
  health_notes: 'Hipertenso, usa losartana 50mg.',
  health_plan: 'Unimed'
)

paciente2 = Contact.create!(
  account: account,
  name: 'Maria Fernanda Santos',
  email: 'mfernanda@example.com',
  phone: '+55 11 97777-0002',
  funnel_stage: 'compareceu',
  temperature: 'morno',
  source: 'instagram',
  blood_type: 'O+',
  allergies: 'Dipirona',
  health_plan: 'Bradesco Saúde'
)

paciente3 = Contact.create!(
  account: account,
  name: 'Carlos Eduardo Lima',
  email: 'carlos.lima@example.com',
  phone: '+55 11 96666-0003',
  funnel_stage: 'novo_paciente',
  temperature: 'frio',
  source: 'indicacao',
  health_notes: 'Ansiedade e insônia.'
)

paciente4 = Contact.create!(
  account: account,
  name: 'Renata Souza',
  email: 'renata@example.com',
  phone: '+55 11 95555-0004',
  funnel_stage: 'retorno',
  temperature: 'quente',
  source: 'whatsapp',
  health_plan: 'SulAmérica',
  health_plan_number: '123456789'
)

# Agendamentos
apt1 = Appointment.create!(
  account: account,
  contact: paciente1,
  professional: prof1,
  service: serv1,
  user: owner,
  appointment_date: Date.today + 1,
  start_time: '09:00',
  end_time: '09:30',
  status: 'agendado',
  consultation_type: 'presencial',
  notes: 'Paciente com queixa de dor de cabeça frequente.'
)

apt2 = Appointment.create!(
  account: account,
  contact: paciente2,
  professional: prof2,
  service: serv2,
  user: atendente,
  appointment_date: Date.today + 1,
  start_time: '10:00',
  end_time: '10:50',
  status: 'confirmado',
  consultation_type: 'online',
  notes: 'Sessão semanal de TCC.'
)

apt3 = Appointment.create!(
  account: account,
  contact: paciente4,
  professional: prof3,
  service: serv3,
  user: owner,
  appointment_date: Date.today - 3,
  start_time: '14:00',
  end_time: '15:00',
  status: 'compareceu',
  consultation_type: 'presencial',
  notes: 'Primeira consulta nutricional.'
)

# Prontuário
MedicalRecord.create!(
  account: account,
  patient: paciente4,
  professional: prof3,
  appointment: apt3,
  recorded_by_id: owner.id,
  chief_complaint: 'Deseja emagrecer 10kg e melhorar hábitos alimentares.',
  diagnosis: 'Sobrepeso (IMC 27.5). Alimentação hipercalórica.',
  prescription: 'Plano alimentar de 1800 kcal/dia. Restrição de açúcar e frituras.',
  notes: 'Retorno em 30 dias para avaliação de resultados.'
)

# Inbox WhatsApp (simulado)
inbox = Inbox.create!(
  name: 'WhatsApp Clínica',
  provider: 'whatsapp',
  phone_number: '+55 11 99000-0000'
)

# Conversa de exemplo
conv1 = Conversation.create!(
  account: account,
  contact: paciente1,
  user: atendente,
  inbox: inbox,
  status: :open,
  source: 'whatsapp',
  unread_count: 1
)

Message.create!(
  account: account,
  conversation: conv1,
  sender_type: 'Contact',
  sender_id: paciente1.id,
  text: 'Boa tarde! Queria confirmar minha consulta de amanhã às 9h.',
  status: :read,
  created_at: 30.minutes.ago
)

Message.create!(
  account: account,
  conversation: conv1,
  sender_type: 'User',
  sender_id: atendente.id,
  text: 'Olá João! Consulta confirmada com Dr. Carlos Mendes amanhã às 09:00. Até lá! 😊',
  status: :sent,
  created_at: 25.minutes.ago
)

conv2 = Conversation.create!(
  account: account,
  contact: paciente3,
  user: owner,
  inbox: inbox,
  status: :open,
  source: 'whatsapp',
  unread_count: 0
)

Message.create!(
  account: account,
  conversation: conv2,
  sender_type: 'Contact',
  sender_id: paciente3.id,
  text: 'Olá, gostaria de marcar uma consulta com psicóloga.',
  status: :read,
  created_at: 2.hours.ago
)

puts "✅ Seed concluído!"
puts "   Login: admin@clinica.com / 123456"
puts "   Pacientes: #{Contact.count}"
puts "   Profissionais: #{Professional.count}"
puts "   Serviços: #{Service.count}"
puts "   Agendamentos: #{Appointment.count}"
puts "   Prontuários: #{MedicalRecord.count}"

<template>
  <div v-if="isOpen" class="modal-overlay" @click.self="close">
    <div class="modal-sidebar">
      <div class="modal-header">
        <div class="title-section">
          <h2>Editar contato - {{ contact?.name }}</h2>
          <p class="subtitle">Alterar detalhes do contato</p>
        </div>
        <button class="close-btn" @click="close">&times;</button>
      </div>

      <div class="modal-body">
        <form @submit.prevent="save">
          
          <div class="form-section">
            <h3>Dados Pessoais</h3>
            <div class="form-group avatar-group">
              <label>Avatar do Contato</label>
              <div class="avatar-preview">
                <img v-if="contact?.avatar_url" :src="contact.avatar_url" alt="Avatar" />
                <div v-else class="avatar-placeholder">
                  {{ contact?.name?.substring(0, 2).toUpperCase() || 'NA' }}
                </div>
              </div>
            </div>

            <div class="form-group">
              <label>Nome Completo</label>
              <input type="text" v-model="formData.name" placeholder="Nome do contato" required autocomplete="off" />
            </div>

            <div class="form-row">
              <div class="form-group half">
                <label>CPF</label>
                <input type="text" v-model="formData.cpf" placeholder="000.000.000-00" autocomplete="off" />
              </div>
              <div class="form-group half">
                <label>Data de Nascimento</label>
                <input type="date" v-model="formData.birth_date" autocomplete="off" />
              </div>
            </div>

            <div class="form-group">
              <label>Endereço de e-mail</label>
              <input type="email" v-model="formData.email" placeholder="Insira o endereço de e-mail do contato" autocomplete="off" />
            </div>

            <div class="form-row">
              <div class="form-group half">
                <label>Número de Telefone</label>
                <div class="phone-input-wrapper">
                  <select class="country-select">
                    <option value="BR">BR ▾</option>
                  </select>
                  <input type="text" v-model="formData.phone" placeholder="+5511999999999" autocomplete="off" />
                </div>
              </div>
              <div class="form-group half">
                <label>Profissão</label>
                <input type="text" v-model="formData.profession" placeholder="Ex: Engenheiro" autocomplete="off" />
              </div>
            </div>
          </div>

          <div class="form-section">
            <h3>Informações de Saúde</h3>

            <div class="form-row">
              <div class="form-group half">
                <label>Plano de Saúde</label>
                <input type="text" v-model="formData.health_plan" placeholder="Ex: Unimed, Hapvida" autocomplete="off" />
              </div>
              <div class="form-group half">
                <label>Número do Plano</label>
                <input type="text" v-model="formData.health_plan_number" placeholder="Nº da carteirinha" autocomplete="off" />
              </div>
            </div>

            <div class="form-row">
              <div class="form-group half">
                <label>Tipo Sanguíneo</label>
                <select v-model="formData.blood_type">
                  <option value="">Não informado</option>
                  <option>A+</option><option>A-</option>
                  <option>B+</option><option>B-</option>
                  <option>AB+</option><option>AB-</option>
                  <option>O+</option><option>O-</option>
                </select>
              </div>
              <div class="form-group half">
                <label>Alergias</label>
                <input type="text" v-model="formData.allergies" placeholder="Ex: Dipirona, Penicilina" autocomplete="off" />
              </div>
            </div>

            <div class="form-group">
              <label>Observações de Saúde</label>
              <textarea v-model="formData.health_notes" placeholder="Histórico médico relevante, condições crônicas, etc." rows="3"></textarea>
            </div>
          </div>

          <div class="form-section">
            <h3>Outras Informações</h3>
            <div class="form-group">
              <label>Descrição</label>
              <textarea v-model="formData.bio" placeholder="Insira a descrição do contato" rows="3"></textarea>
            </div>

            <div class="form-group">
              <label>Nome da empresa</label>
              <input type="text" v-model="formData.company_name" placeholder="Digite o nome da empresa" autocomplete="off" />
            </div>
          </div>

          <div class="form-section">
            <h3>Atributos Personalizados</h3>
            <p style="font-size: 0.85rem; color: #6b7280; margin-bottom: 12px; margin-top: -10px;">
              Crie campos adicionais livremente (ex: Cor do carro, Hobby, Renda do cônjuge).
            </p>
            <div v-for="(attr, index) in formData.customAttributesArray" :key="index" class="form-row" style="margin-bottom: 10px; align-items: flex-end;">
              <div class="form-group" style="flex: 1; margin-bottom: 0;">
                <label v-if="index === 0">Nome do Campo</label>
                <input type="text" v-model="attr.key" placeholder="Ex: Possui Pets?" autocomplete="off" />
              </div>
              <div class="form-group" style="flex: 1; margin-bottom: 0;">
                <label v-if="index === 0">Valor</label>
                <input type="text" v-model="attr.value" placeholder="Ex: Sim, 2 cachorros" autocomplete="off" />
              </div>
              <button type="button" @click="formData.customAttributesArray.splice(index, 1)" class="btn-cancel" style="padding: 10px; height: 38px; border-color: #ef4444; color: #ef4444; display: flex; align-items: center; justify-content: center;" title="Remover">
                Remover
              </button>
            </div>
            <button type="button" @click="formData.customAttributesArray.push({key: '', value: ''})" style="background: none; border: none; color: #3b82f6; cursor: pointer; font-weight: 500; font-size: 0.9rem; padding: 0; margin-top: 5px;">
              + Adicionar novo atributo
            </button>
          </div>

          <div class="form-section">
            <h3>Endereço Completo</h3>
            
            <div class="form-group">
              <label>CEP</label>
              <div class="cep-wrapper">
                <input type="text" v-model="formData.cep" @blur="buscarCep" placeholder="00000-000" autocomplete="off" />
                <div v-if="loadingCep" class="cep-spinner"></div>
              </div>
              <small v-if="cepError" class="cep-error">{{ cepError }}</small>
            </div>

            <div class="form-row">
              <div class="form-group flex-2">
                <label>Rua / Logradouro</label>
                <input type="text" v-model="formData.street" placeholder="Nome da rua" autocomplete="off" />
              </div>
              <div class="form-group flex-1">
                <label>Número</label>
                <input type="text" v-model="formData.address_number" placeholder="Nº" autocomplete="off" />
              </div>
            </div>

            <div class="form-row">
              <div class="form-group half">
                <label>Complemento</label>
                <input type="text" v-model="formData.address_complement" placeholder="Ex: Apto 101" autocomplete="off" />
              </div>
              <div class="form-group half">
                <label>Bairro</label>
                <input type="text" v-model="formData.neighborhood" placeholder="Bairro" autocomplete="off" />
              </div>
            </div>

            <div class="form-row">
              <div class="form-group half">
                <label>Cidade</label>
                <input type="text" v-model="formData.city" placeholder="Cidade" autocomplete="off" />
              </div>
              <div class="form-group half">
                <label>Estado</label>
                <input type="text" v-model="formData.state" placeholder="Estado (UF)" autocomplete="off" />
              </div>
            </div>
            
            <div class="form-group" style="margin-top: 10px;">
              <label>País</label>
              <input type="text" v-model="formData.country" placeholder="Digite o país" autocomplete="off" />
            </div>
          </div>

        </form>
      </div>

      <div class="modal-footer">
        <button type="button" class="btn-cancel" @click="close">Cancelar</button>
        <button type="button" class="btn-primary" @click="save" :disabled="loading">
          {{ loading ? 'Salvando...' : 'Salvar Alterações' }}
        </button>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, watch } from 'vue'
import { useConversationsStore } from '../store/conversations'
import Swal from 'sweetalert2'

const props = defineProps({
  isOpen: Boolean,
  contact: Object
})

const emit = defineEmits(['close'])
const store = useConversationsStore()

const formData = ref({
  name: '',
  email: '',
  phone: '',
  bio: '',
  company_name: '',
  country: '',
  city: '',
  cpf: '',
  birth_date: '',
  profession: '',
  health_plan: '',
  health_plan_number: '',
  blood_type: '',
  allergies: '',
  health_notes: '',
  cep: '',
  street: '',
  neighborhood: '',
  state: '',
  address_number: '',
  address_complement: '',
  customAttributesArray: []
})
const loading = ref(false)
const loadingCep = ref(false)
const cepError = ref('')

const buscarCep = async () => {
  if (!formData.value.cep) return;
  const cleanCep = formData.value.cep.replace(/\D/g, '');
  if (cleanCep.length !== 8) {
    cepError.value = 'CEP inválido.';
    return;
  }
  
  cepError.value = '';
  loadingCep.value = true;
  
  try {
    const res = await fetch(`https://viacep.com.br/ws/${cleanCep}/json/`);
    const data = await res.json();
    
    if (data.erro) {
      cepError.value = 'CEP não encontrado.';
    } else {
      formData.value.street = data.logradouro || '';
      formData.value.neighborhood = data.bairro || '';
      formData.value.city = data.localidade || '';
      formData.value.state = data.uf || '';
      if (!formData.value.country) formData.value.country = 'Brasil';
    }
  } catch (err) {
    cepError.value = 'Erro ao buscar o CEP.';
  } finally {
    loadingCep.value = false;
  }
}

watch(() => props.contact, (newContact) => {
  if (newContact) {
    formData.value = {
      name: newContact.name || '',
      email: newContact.email || '',
      phone: newContact.phone || '',
      bio: newContact.bio || '',
      company_name: newContact.company_name || '',
      country: newContact.country || '',
      city: newContact.city || '',
      cpf: newContact.cpf || '',
      birth_date: newContact.birth_date || '',
      profession: newContact.profession || '',
      health_plan: newContact.health_plan || '',
      health_plan_number: newContact.health_plan_number || '',
      blood_type: newContact.blood_type || '',
      allergies: newContact.allergies || '',
      health_notes: newContact.health_notes || '',
      cep: newContact.cep || '',
      street: newContact.street || '',
      neighborhood: newContact.neighborhood || '',
      state: newContact.state || '',
      address_number: newContact.address_number || '',
      address_complement: newContact.address_complement || '',
      customAttributesArray: newContact.custom_attributes ? Object.keys(newContact.custom_attributes).map(k => ({ key: k, value: newContact.custom_attributes[k] })) : []
    }
  }
}, { immediate: true })

const close = () => {
  emit('close')
}

const save = async () => {
  if (!props.contact) return
  loading.value = true
  
  const { customAttributesArray, ...rest } = formData.value
  const custom_attributes = {}
  customAttributesArray.forEach(attr => {
    if (attr.key && attr.key.trim()) {
      custom_attributes[attr.key.trim()] = attr.value
    }
  })
  const dataToSave = { ...rest, custom_attributes }

  try {
    await store.updateContact(props.contact.id, dataToSave)
    close()
  } catch (error) {
    Swal.fire({ toast: true, position: 'top-end', icon: 'error', title: 'Erro ao salvar contato.', showConfirmButton: false, timer: 3500 })
  } finally {
    loading.value = false
  }
}
</script>

<style scoped>
.modal-overlay {
  position: fixed;
  top: 0; left: 0; right: 0; bottom: 0;
  background: rgba(0,0,0,0.4);
  display: flex;
  justify-content: flex-end;
  z-index: 1000;
}

.modal-sidebar {
  background: #f8f9fa;
  width: 450px;
  max-width: 100%;
  height: 100%;
  display: flex;
  flex-direction: column;
  box-shadow: -4px 0 15px rgba(0,0,0,0.1);
  animation: slideInRight 0.3s ease-out;
}

@keyframes slideInRight {
  from { transform: translateX(100%); }
  to { transform: translateX(0); }
}

.modal-header {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  padding: 24px;
  background: white;
  border-bottom: 1px solid #e9ecef;
}

.title-section h2 {
  margin: 0 0 4px 0;
  font-size: 1.15rem;
  color: #1f2937;
  font-weight: 600;
}

.title-section .subtitle {
  margin: 0;
  font-size: 0.85rem;
  color: #6b7280;
}

.close-btn {
  background: none;
  border: none;
  font-size: 1.5rem;
  cursor: pointer;
  color: #6b7280;
  padding: 0;
  line-height: 1;
}

.modal-body {
  flex: 1;
  overflow-y: auto;
  padding: 24px;
  background: #f8f9fa;
}

.form-section {
  background: white;
  padding: 20px;
  border-radius: 8px;
  border: 1px solid #e5e7eb;
  margin-bottom: 24px;
}

.form-section h3 {
  margin: 0 0 16px 0;
  font-size: 0.95rem;
  color: #1f2937;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.5px;
  border-bottom: 1px solid #f3f4f6;
  padding-bottom: 8px;
}

.form-row {
  display: flex;
  gap: 16px;
  margin-bottom: 20px;
}

.form-group {
  margin-bottom: 20px;
}

.form-row .form-group {
  margin-bottom: 0;
  flex: 1;
}

.form-group.half {
  flex: 1;
}

.form-group label {
  display: block;
  margin-bottom: 8px;
  font-size: 0.85rem;
  color: #374151;
  font-weight: 500;
}

.form-group input, .form-group textarea, .form-group select {
  width: 100%;
  padding: 10px 12px;
  border: 1px solid #e5e7eb;
  border-radius: 6px;
  font-size: 0.95rem;
  background: #f3f4f6;
  color: #1f2937;
  transition: all 0.2s;
}

.form-group input:focus, .form-group textarea:focus {
  outline: none;
  border-color: #3b82f6;
  background: white;
  box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
}


.phone-input-wrapper {
  display: flex;
  gap: 8px;
}

.country-select {
  padding: 8px;
  border: 1px solid #e5e7eb;
  border-radius: 6px;
  background: white;
  color: #374151;
  font-size: 0.9rem;
}

.flex-2 {
  flex: 2 !important;
}

.flex-1 {
  flex: 1 !important;
}

.cep-wrapper {
  position: relative;
  display: flex;
  align-items: center;
}

.cep-wrapper input {
  width: 100%;
}

.cep-spinner {
  position: absolute;
  right: 10px;
  width: 16px;
  height: 16px;
  border: 2px solid #e5e7eb;
  border-top-color: #3b82f6;
  border-radius: 50%;
  animation: spin 1s linear infinite;
}

@keyframes spin {
  to { transform: rotate(360deg); }
}

.cep-error {
  color: #ef4444;
  font-size: 0.8rem;
  margin-top: 4px;
  display: block;
}

.avatar-preview {
  width: 64px;
  height: 64px;
  border-radius: 50%;
  overflow: hidden;
  background: #e5e7eb;
  display: flex;
  align-items: center;
  justify-content: center;
}

.avatar-preview img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.avatar-placeholder {
  color: #6b7280;
  font-weight: 600;
  font-size: 1.2rem;
}

.modal-footer {
  padding: 16px 24px;
  background: white;
  border-top: 1px solid #e9ecef;
  display: flex;
  justify-content: flex-end;
  gap: 12px;
}

.btn-cancel {
  background: transparent;
  border: 1px solid #d1d5db;
  padding: 8px 16px;
  border-radius: 6px;
  cursor: pointer;
  color: #374151;
  font-weight: 500;
  font-size: 0.9rem;
}

.btn-cancel:hover {
  background: #f3f4f6;
}

.btn-primary {
  background: var(--primary, #3b82f6);
  color: white;
  border: none;
  padding: 8px 16px;
  border-radius: 6px;
  cursor: pointer;
  font-weight: 500;
  font-size: 0.9rem;
}

.btn-primary:hover {
  background: var(--primary-dark, #2563eb);
}

.btn-primary:disabled {
  opacity: 0.7;
  cursor: not-allowed;
}
</style>

<script setup>
import { ref, onMounted, computed } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { ArrowLeft, Save, FlaskConical, ImagePlus, Trash2 } from 'lucide-vue-next'
import api from '../api'
import Swal from 'sweetalert2'

const router = useRouter()
const route  = useRoute()
const isEdit = computed(() => !!route.params.id)

const CATEGORIES = [
  'Consulta', 'Retorno', 'Avaliação', 'Procedimento', 'Exame',
  'Terapia', 'Cirurgia', 'Tratamento Estético', 'Sessão', 'Outro'
]

const form = ref({
  name: '',
  description: '',
  duration_minutes: 30,
  price: '',
  category: '',
  status: 'active',
})

const imageFile    = ref(null)   // File object selecionado
const imagePreview = ref(null)   // URL para preview
const existingUrl  = ref(null)   // URL já salva no servidor
const removeImage  = ref(false)  // flag para remover
const isSaving     = ref(false)
const fileInput    = ref(null)

onMounted(async () => {
  if (isEdit.value) {
    try {
      const { data } = await api.get(`/services/${route.params.id}`)
      Object.assign(form.value, data)
      existingUrl.value = data.image_url || null
    } catch {
      Swal.fire({ toast: true, position: 'top-end', icon: 'error', title: 'Erro ao carregar serviço.', showConfirmButton: false, timer: 3000 })
      router.push('/servicos')
    }
  }
})

const onFileChange = (e) => {
  const file = e.target.files[0]
  if (!file) return
  if (file.size > 5 * 1024 * 1024) {
    Swal.fire({ toast: true, position: 'top-end', icon: 'warning', title: 'Imagem máximo 5MB.', showConfirmButton: false, timer: 3000 })
    return
  }
  imageFile.value    = file
  imagePreview.value = URL.createObjectURL(file)
  removeImage.value  = false
}

const clearImage = () => {
  imageFile.value    = null
  imagePreview.value = null
  existingUrl.value  = null
  removeImage.value  = true
  if (fileInput.value) fileInput.value.value = ''
}

const currentImage = computed(() => imagePreview.value || existingUrl.value)

const save = async () => {
  if (!form.value.name) {
    Swal.fire({ toast: true, position: 'top-end', icon: 'warning', title: 'Nome é obrigatório.', showConfirmButton: false, timer: 3000 })
    return
  }
  isSaving.value = true
  try {
    const fd = new FormData()
    Object.entries(form.value).forEach(([k, v]) => {
      if (v !== null && v !== undefined) fd.append(`service[${k}]`, v)
    })
    if (imageFile.value) fd.append('service[image]', imageFile.value)
    if (removeImage.value) fd.append('service[remove_image]', 'true')

    const config = { headers: { 'Content-Type': 'multipart/form-data' } }

    if (isEdit.value) {
      await api.put(`/services/${route.params.id}`, fd, config)
    } else {
      await api.post('/services', fd, config)
    }
    Swal.fire({ toast: true, position: 'top-end', icon: 'success', title: isEdit.value ? 'Serviço atualizado!' : 'Serviço cadastrado!', showConfirmButton: false, timer: 2500 })
    router.push('/servicos')
  } catch (e) {
    const msg = e.response?.data ? Object.values(e.response.data).flat().join(', ') : 'Erro ao salvar.'
    Swal.fire({ toast: true, position: 'top-end', icon: 'error', title: msg, showConfirmButton: false, timer: 4000 })
  } finally {
    isSaving.value = false
  }
}
</script>

<template>
  <div class="form-page">
    <div class="form-header">
      <button class="btn-back" @click="router.push('/servicos')">
        <ArrowLeft class="icon-sm" /> Voltar
      </button>
      <h1>
        <FlaskConical class="header-icon" />
        {{ isEdit ? 'Editar Serviço' : 'Novo Serviço' }}
      </h1>
    </div>

    <div class="form-card">
      <div class="form-layout">

        <!-- Coluna esquerda: foto -->
        <div class="image-col">
          <div class="image-label">Foto do Serviço</div>

          <div class="image-box" @click="fileInput.click()" :class="{ 'has-image': currentImage }">
            <img v-if="currentImage" :src="currentImage" alt="Preview" class="image-preview" />
            <div v-else class="image-placeholder">
              <ImagePlus :size="36" />
              <span>Clique para adicionar foto</span>
              <small>JPG, PNG ou WEBP — máx. 5MB</small>
            </div>
          </div>

          <input ref="fileInput" type="file" accept="image/*" class="hidden-input" @change="onFileChange" />

          <div class="image-actions">
            <button class="btn-upload" @click="fileInput.click()">
              <ImagePlus :size="14" /> {{ currentImage ? 'Trocar foto' : 'Adicionar foto' }}
            </button>
            <button v-if="currentImage" class="btn-remove-img" @click="clearImage">
              <Trash2 :size="14" /> Remover
            </button>
          </div>
        </div>

        <!-- Coluna direita: campos -->
        <div class="fields-col">
          <div class="form-grid">
            <div class="form-group full">
              <label>Nome do Serviço *</label>
              <input v-model="form.name" type="text" placeholder="Ex: Consulta médica, Limpeza de pele..." />
            </div>

            <div class="form-group">
              <label>Categoria</label>
              <select v-model="form.category">
                <option value="">Selecione...</option>
                <option v-for="c in CATEGORIES" :key="c" :value="c">{{ c }}</option>
              </select>
            </div>

            <div class="form-group">
              <label>Status</label>
              <select v-model="form.status">
                <option value="active">Ativo</option>
                <option value="inactive">Inativo</option>
              </select>
            </div>

            <div class="form-group">
              <label>Duração (minutos)</label>
              <input v-model.number="form.duration_minutes" type="number" min="5" step="5" placeholder="30" />
            </div>

            <div class="form-group">
              <label>Preço (R$)</label>
              <input v-model="form.price" type="number" step="0.01" min="0" placeholder="150.00" />
            </div>

            <div class="form-group full">
              <label>Descrição</label>
              <textarea v-model="form.description" rows="4" placeholder="Descreva o serviço, benefícios, como funciona..."></textarea>
            </div>
          </div>
        </div>

      </div>

      <div class="form-actions">
        <button class="btn-secondary" @click="router.push('/servicos')">Cancelar</button>
        <button class="btn-primary" @click="save" :disabled="isSaving">
          <Save class="icon-sm" />
          {{ isSaving ? 'Salvando...' : 'Salvar Serviço' }}
        </button>
      </div>
    </div>
  </div>
</template>

<style scoped>
.form-page { padding: 24px; }
.form-header { display: flex; align-items: center; gap: 16px; margin-bottom: 24px; }
.form-header h1 { display: flex; align-items: center; gap: 8px; font-size: 1.4rem; font-weight: 700; color: var(--text-main); }
.header-icon { width: 24px; height: 24px; color: var(--primary); }
.btn-back { display: flex; align-items: center; gap: 4px; background: var(--bg-secondary); border: 1px solid var(--border-color); border-radius: 8px; padding: 6px 12px; font-size: 0.85rem; cursor: pointer; color: var(--text-main); }

.form-card { background: var(--bg-secondary); border: 1px solid var(--border-color); border-radius: 12px; padding: 28px; }

.form-layout { display: grid; grid-template-columns: 260px 1fr; gap: 32px; align-items: start; }

/* Coluna da foto */
.image-col { display: flex; flex-direction: column; gap: 12px; }
.image-label { font-size: 0.78rem; font-weight: 600; color: var(--text-muted); text-transform: uppercase; letter-spacing: 0.05em; }
.image-box {
  width: 100%; aspect-ratio: 1; border: 2px dashed var(--border-color); border-radius: 12px;
  display: flex; align-items: center; justify-content: center; cursor: pointer;
  overflow: hidden; background: var(--bg-primary); transition: border-color 0.2s;
}
.image-box:hover { border-color: var(--primary); }
.image-box.has-image { border-style: solid; border-color: var(--border-color); }
.image-preview { width: 100%; height: 100%; object-fit: cover; }
.image-placeholder { display: flex; flex-direction: column; align-items: center; gap: 8px; color: var(--text-muted); padding: 20px; text-align: center; }
.image-placeholder span { font-size: 0.9rem; font-weight: 500; }
.image-placeholder small { font-size: 0.75rem; }
.hidden-input { display: none; }
.image-actions { display: flex; gap: 8px; flex-wrap: wrap; }
.btn-upload { display: flex; align-items: center; gap: 5px; background: var(--bg-tertiary); border: 1px solid var(--border-color); border-radius: 7px; padding: 6px 12px; font-size: 0.82rem; cursor: pointer; color: var(--text-main); }
.btn-upload:hover { border-color: var(--primary); color: var(--primary); }
.btn-remove-img { display: flex; align-items: center; gap: 5px; background: #fee2e2; border: 1px solid #fca5a5; border-radius: 7px; padding: 6px 12px; font-size: 0.82rem; cursor: pointer; color: #991b1b; }

/* Campos */
.fields-col {}
.form-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 16px; }
.form-group { display: flex; flex-direction: column; gap: 6px; }
.form-group.full { grid-column: 1 / -1; }
.form-group label { font-size: 0.78rem; font-weight: 600; color: var(--text-muted); text-transform: uppercase; letter-spacing: 0.05em; }
.form-group input, .form-group select, .form-group textarea { background: var(--bg-primary); border: 1px solid var(--border-color); border-radius: 8px; padding: 8px 12px; color: var(--text-main); font-size: 0.9rem; width: 100%; box-sizing: border-box; }
.form-group input:focus, .form-group select:focus, .form-group textarea:focus { outline: none; border-color: var(--primary); }

.form-actions { display: flex; justify-content: flex-end; gap: 10px; margin-top: 24px; padding-top: 20px; border-top: 1px solid var(--border-color); }
.btn-primary { display: flex; align-items: center; gap: 6px; background: var(--primary); color: #fff; border: none; border-radius: 8px; padding: 10px 20px; font-size: 0.9rem; font-weight: 600; cursor: pointer; }
.btn-primary:disabled { opacity: 0.6; cursor: not-allowed; }
.btn-secondary { background: var(--bg-tertiary); border: 1px solid var(--border-color); border-radius: 8px; padding: 10px 20px; font-size: 0.9rem; cursor: pointer; color: var(--text-main); }
.icon-sm { width: 16px; height: 16px; }

@media (max-width: 700px) {
  .form-layout { grid-template-columns: 1fr; }
  .image-box { aspect-ratio: 16/9; }
}
</style>
